-- Batch 6 slice 4 (DEP-1, DEP-2, DEP-3) -- a department stays in its branch, and changes only with
-- the RPC's authority and a record on every door.
--
-- =================================================================================================
-- THE MEASURED DEFECTS (2026-11-11 at 2e05d41 on the local stack, committed probe fixtures)
--
-- DEP-1 `app.create_department` charges `app.authorize('MANAGE_DEPARTMENTS')` (permission AND
--      step-up); the table's RLS charges `app.has_permission` only. A `ceo` at `aal1` was refused by
--      the RPC, then created a department, renamed and re-typed another, deactivated it and moved a
--      third to another branch, all by direct INSERT and UPDATE. A member of STEPUP-1.
-- DEP-2 The only `department_created` producer is the RPC: the door's INSERT recorded nothing, and no
--      UPDATE (rename, re-type, deactivation, branch move) has ever been recorded on any door.
-- DEP-3 A department's branch could be moved. Every writer that files work under a department
--      (`app.create_lead`, `app.create_booking`, `app.assign_user_branch`, `app.link_internal_supplier`)
--      requires the department to belong to the row's branch, but 17 of the 18 inbound foreign keys
--      reference (tenant_id, id) only. Moving an unplaced department left its lead at (old branch,
--      department), a pair `app.create_lead` now refuses; the department's new-branch employee could
--      not see it, and no department-queue reader can ever be placed at the old pair again (the RPC
--      and SPEC-300's composite FK both refuse it). Only a placed department was pinned (SPEC-300 FK).
--
-- =================================================================================================
-- THE REPAIR, IN THE SPEC-203 / SPEC-300 SHAPE: authority is a precondition and runs BEFORE; the
-- record is a fact and runs AFTER.
--
-- 1. `app.guard_department_write`, BEFORE INSERT OR UPDATE:
--    - a department's branch is fixed for life (DEP-3): an UPDATE that changes `branch_id` is refused
--      23514 on every path, with or without a session. A "move" is a new department in the other
--      branch. With the branch fixed, the tenant is fixed too (the (tenant_id, branch_id) FK).
--    - `app.authorize('MANAGE_DEPARTMENTS')` on every session write, every column (DEP-1). No session
--      (migrations, seeds, provisioning, service_role): no charge, as in every sibling guard.
-- 2. `app.emit_department_change`, AFTER INSERT OR UPDATE, session writes only (a platform write
--    recorded nothing before and records nothing now):
--    - INSERT records `department_created` with the RPC's exact arguments and payload. The RPC's own
--      `app.record_event` call is removed in the same migration, so the act is recorded once on
--      either door (one producer, the SUP-5 shape).
--    - UPDATE records the NEW code `department_changed` (info) with the previous and current name,
--      type and active flag, when one of them moves; an UPDATE that moves none records nothing.
--
-- DELETE is not included: `authenticated` holds no DELETE on this table, so `scope_delete` is inert.
-- POSITION, not changed here (a behaviour addition to five RPCs, the UBA-4 precedent): `is_active`
-- binds nothing; `app.create_lead` and `app.assign_user_branch` accepted an inactive department, and
-- no function reads `departments.is_active`, `name` or `department_type_code`.
-- NOT CHANGED: every grant and policy, `enforce_catalog_codes`, `departments_set_updated_at`, and the
-- RPC's checks and insert.
-- Hosted rows at the time of writing (read-only, ledger 256): 0 departments on Primary and on
-- Founder Secondary.
-- =================================================================================================

-- Vocabulary. `sort_order` 937 is MEASURED: `event_type` holds 189 rows, maximum 936. Canon 27 gains
-- the matching entry.
insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
select null::uuid, 'event_type', 'department_changed', 'Department Changed', 937, true, true
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = 'event_type' and cv.code = 'department_changed' and cv.tenant_id is null
);

-- `old` is read only inside the UPDATE branch (the SPEC-159-A 55000 failure mode).
create or replace function app.guard_department_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if tg_op = 'UPDATE' then
        if new.branch_id is distinct from old.branch_id then
            raise exception 'a department belongs to one branch for life; create a department in the other branch'
                using errcode = '23514';
        end if;
    end if;
    if (select auth.uid()) is null then
        return new;
    end if;
    perform app.authorize('MANAGE_DEPARTMENTS');
    return new;
end;
$fn$;

revoke execute on function app.guard_department_write() from public;

create trigger departments_guard_write
    before insert or update on public.departments
    for each row execute function app.guard_department_write();

create or replace function app.emit_department_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_prev jsonb;
    v_next jsonb;
begin
    if (select auth.uid()) is null then
        return null;
    end if;

    if tg_op = 'INSERT' then
        perform app.record_event(
            new.tenant_id, 'department_created', 'department', new.id, null,
            null, case when new.is_active then 'active' else 'inactive' end, null,
            jsonb_build_object('branch_id', new.branch_id, 'department_type_code', new.department_type_code,
                               'name', new.name),
            'info');
        return null;
    end if;

    v_prev := jsonb_build_object('name', old.name, 'department_type_code', old.department_type_code,
        'is_active', old.is_active);
    v_next := jsonb_build_object('name', new.name, 'department_type_code', new.department_type_code,
        'is_active', new.is_active);
    if v_prev = v_next then
        return null;
    end if;

    perform app.record_event(
        new.tenant_id, 'department_changed', 'department', new.id, null,
        case when old.is_active then 'active' else 'inactive' end,
        case when new.is_active then 'active' else 'inactive' end, null,
        jsonb_build_object('branch_id', new.branch_id, 'previous', v_prev, 'current', v_next),
        'info');
    return null;
end;
$fn$;

revoke execute on function app.emit_department_change() from public;

create trigger departments_emit_change
    after insert or update on public.departments
    for each row execute function app.emit_department_change();

-- The RPC's checks and insert are unchanged; its `department_created` is now the trigger's.
create or replace function app.create_department(p_branch_id uuid, p_department_type_code text, p_name text)
returns uuid
language plpgsql
set search_path = ''
as $function$
declare
    v_tenant uuid := app.current_tenant_id();
    v_department uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('MANAGE_DEPARTMENTS');

    if not exists (
        select 1 from public.branches where id = p_branch_id and tenant_id = v_tenant
    ) then
        raise exception 'branch is not in your tenant';
    end if;

    if not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'department_type' and code = p_department_type_code
    ) then
        raise exception 'unknown department_type_code: %', p_department_type_code;
    end if;

    insert into public.departments (tenant_id, branch_id, department_type_code, name, is_active)
    values (v_tenant, p_branch_id, p_department_type_code, p_name, true)
    returning id into v_department;

    return v_department;
end;
$function$;
