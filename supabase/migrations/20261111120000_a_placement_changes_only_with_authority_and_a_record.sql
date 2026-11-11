-- SPEC-300 (Batch 6 Slice 45, USR-3, UBA-1, UBA-3, UBA-5) -- a placement changes only with the
-- RPC's authority, leaves a record on every door, and is internally consistent.
--
-- =================================================================================================
-- THE MEASURED DEFECTS (2026-11-11 at 90a3a72 on the local stack, committed probe fixtures)
--
-- USR-3 `app.assign_user_branch` charges `app.authorize('MANAGE_USERS')` (permission AND step-up);
--      the table's RLS charges `app.has_permission` only. A `ceo` at `aal1` was refused by the RPC,
--      then added a branch by direct INSERT and moved a colleague's primary BR1/D1 -> BR2/D2 by
--      direct UPDATE. The same actor was refused 42501 on `user_role_assignments`. (USR-3 also names
--      `user_permission_grants`; that half is a different surface and stays OPEN.)
-- UBA-1 `user_branch_assignments_emit_transfer` is AFTER INSERT only. A direct UPDATE re-pointed a
--      primary to another branch, ended it, and handed the row to another user: read scope moved
--      three times, 0 events.
-- UBA-3 The RPC refuses a department of another branch; the table accepted BR1 with D2 of BR2, and
--      `app.visible_department_ids()` then returned D2.
-- UBA-5 The table accepted `ends_at` a day before `starts_at`.
--
-- =================================================================================================
-- THE REPAIR, IN THE SPEC-203 SHAPE (`20260920120000`): authority is a precondition and runs
-- BEFORE; the record is a fact and runs AFTER.
--
-- 1. `app.guard_placement_authority`, BEFORE INSERT OR UPDATE: `app.authorize('MANAGE_USERS')` on
--    every session write, every column. No session (migrations, seeds, provisioning, service_role):
--    no charge, as in every sibling guard. The RPC's own charge stays; a second check is free.
-- 2. `app.emit_user_branch_transfer` also fires AFTER UPDATE when a column a reader consumes moves
--    (user_id, branch_id, department_id, is_primary, starts_at, ends_at). It records the NEW code
--    `user_branch_assignment_changed` (severity security: a read-scope input moved outside the RPC)
--    with the previous and current placement; a row handed to another user records it for both
--    users. Not `user_branch_transfer_completed`: a transfer is "end the old primary, insert the new
--    one", and test 38 pins one transfer = one `_completed`; reusing it would count every end as a
--    transfer. The INSERT branch is unchanged.
-- 3. A department belongs to the placement's branch: a composite FK
--    (tenant_id, branch_id, department_id) -> departments (tenant_id, branch_id, id). MATCH SIMPLE,
--    so a placement without a department is unaffected.
-- 4. `ends_at >= starts_at` as a CHECK.
--
-- DELETE is not included: `authenticated` holds no DELETE on this table (SPEC-203's reasoning).
-- POSITIONS, not changed here (behaviour additions, recorded under UBA-1 with their reopening
-- triggers): no RPC transfers or ends a placement (a new primary while one is open is refused 23505
-- by `user_branch_assignments_one_primary_idx`, so a transfer is a guarded, recorded table write),
-- and the RPC places onto an inactive branch or an inactive user.
-- NOT CHANGED: every grant, policy, the RPC body, `derive_created_by`, `enforce_catalog_codes`.
-- Hosted rows at the time of writing (read-only, ledger 255): 0 placements on Primary and on
-- Founder Secondary, so the FK and the CHECK meet no existing row.
-- =================================================================================================

-- Vocabulary. `sort_order` 936 is MEASURED: `event_type` holds 188 rows, maximum 935. Seeded under the
-- existing catalog type, as SPEC-203 did; canon 27 gains the matching entry.
insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
select null::uuid, 'event_type', 'user_branch_assignment_changed', 'User Branch Assignment Changed', 936, true, true
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = 'event_type' and cv.code = 'user_branch_assignment_changed' and cv.tenant_id is null
);

create or replace function app.guard_placement_authority()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    perform app.authorize('MANAGE_USERS');
    return new;
end;
$fn$;

revoke execute on function app.guard_placement_authority() from public;

create trigger user_branch_assignments_guard_authority
    before insert or update on public.user_branch_assignments
    for each row execute function app.guard_placement_authority();

-- `old` is read only inside the UPDATE branch (the SPEC-159-A 55000 failure mode).
create or replace function app.emit_user_branch_transfer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_prev jsonb;
    v_next jsonb;
begin
    if tg_op = 'INSERT' then
        if exists (
            select 1 from public.user_branch_assignments prior
            where prior.tenant_id = new.tenant_id
              and prior.user_id   = new.user_id
              and prior.id       <> new.id
        ) then
            perform app.record_event(
                new.tenant_id, 'user_branch_transfer_completed', 'user', new.user_id,
                null, null, null, new.transfer_type_code,
                jsonb_build_object('branch_id', new.branch_id, 'department_id', new.department_id),
                'info');
        end if;
        return null;
    end if;

    v_prev := jsonb_build_object('user_id', old.user_id, 'branch_id', old.branch_id,
        'department_id', old.department_id, 'is_primary', old.is_primary,
        'starts_at', old.starts_at, 'ends_at', old.ends_at);
    v_next := jsonb_build_object('user_id', new.user_id, 'branch_id', new.branch_id,
        'department_id', new.department_id, 'is_primary', new.is_primary,
        'starts_at', new.starts_at, 'ends_at', new.ends_at);
    if v_prev = v_next then
        return null;
    end if;

    perform app.record_event(
        new.tenant_id, 'user_branch_assignment_changed', 'user', new.user_id,
        null, null, null, null,
        jsonb_build_object('assignment_id', new.id, 'previous', v_prev, 'current', v_next),
        'security');
    if new.user_id is distinct from old.user_id then
        perform app.record_event(
            new.tenant_id, 'user_branch_assignment_changed', 'user', old.user_id,
            null, null, null, null,
            jsonb_build_object('assignment_id', new.id, 'previous', v_prev, 'current', v_next),
            'security');
    end if;
    return null;
end;
$fn$;

revoke execute on function app.emit_user_branch_transfer() from public;

drop trigger if exists user_branch_assignments_emit_transfer on public.user_branch_assignments;
create trigger user_branch_assignments_emit_transfer
    after insert or update on public.user_branch_assignments
    for each row execute function app.emit_user_branch_transfer();

alter table public.departments
    add constraint departments_tenant_id_branch_id_id_key unique (tenant_id, branch_id, id);

alter table public.user_branch_assignments
    add constraint user_branch_assignments_department_in_branch_fkey
        foreign key (tenant_id, branch_id, department_id)
        references public.departments (tenant_id, branch_id, id)
        on delete restrict on update no action,
    add constraint user_branch_assignments_ends_after_start_check
        check (ends_at is null or ends_at >= starts_at);
