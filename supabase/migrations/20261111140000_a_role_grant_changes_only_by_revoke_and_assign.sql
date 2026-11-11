-- Batch 6 slice 5 (URA-1, URA-2, URA-3) -- a role grant's holder, role, scope and start are fixed
-- once written; a session changes a grant only by ending it or starting it, which is charged and
-- recorded.
--
-- =================================================================================================
-- THE MEASURED DEFECTS (2026-11-11 at 03009ec on the local stack, committed probe fixtures)
--
-- `app.emit_role_change` (RBAC-1) charges `app.authorize('MANAGE_USERS')` and records
-- `role_assigned` / `role_removed` only when a row's liveness (`is_active`, `ends_at`) changes. An
-- UPDATE that keeps a row live returns before the charge and the record, and the table's RLS charges
-- `app.has_permission('MANAGE_USERS')` only, so:
-- URA-1 A `ceo` at `aal1`, refused by `app.assign_user_role`, re-pointed an employee's live grant to
--      `owner`, moved the owner's grant to another user, moved and widened a branch scope, and
--      pushed a live owner grant's `starts_at` a year ahead (suspending it) and back, all by direct
--      UPDATE.
-- URA-2 None of those changes was recorded, and at `aal2` neither was a trainee grant re-pointed to
--      `ceo`: the security stream showed no privilege change.
-- URA-3 ADMIN-2's zero-owner protection held only for revocation: a tenant's lone owner re-pointed
--      their own grant to `employee` and left the tenant with no MANAGE_USERS holder at all.
--
-- =================================================================================================
-- THE REPAIR: `app.guard_role_assignment_change`, BEFORE UPDATE, session writes only (no session --
-- migrations, seeds, provisioning, service_role -- no check, as in every sibling guard):
--   - a grant's tenant, holder, role, scope, branch, department, start, id and creation time are
--     fixed (23514). Changing any of them is a revoke (`app.revoke_user_role`) and a new assignment
--     (`app.assign_user_role`), each step-up charged and recorded by `app.emit_role_change`.
--   - while a grant stays live, its `ends_at` is fixed too (23514): the end moves only when the change
--     ends the grant (or the grant is not live after it).
-- What a session can still change is `is_active` and `ends_at` across liveness, which
-- `app.emit_role_change` already charges and records; with the grant's identity fixed, ADMIN-2's
-- AFTER re-charge refuses a lone owner's self-demotion on every path again. `assigned_by` stays
-- fixed by `app.derive_role_assignment_actor`.
-- POSITION, not changed here: a grant issued with a future `starts_at` records `role_assigned` when
-- it is issued (the grant decision); nothing records the moment it starts. A `platform` scope is
-- accepted from a tenant session and read by nothing.
-- NOT CHANGED: every grant, policy and RPC, `app.emit_role_change` and
-- `app.derive_role_assignment_actor`.
-- Hosted rows at the time of writing (read-only, ledger 257): 0 assignments on Primary and on
-- Founder Secondary.
-- =================================================================================================

-- `old` and `new` are both read: the trigger is UPDATE only.
create or replace function app.guard_role_assignment_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    if (new.id, new.tenant_id, new.user_id, new.role_id, new.scope_type, new.branch_id,
        new.department_id, new.starts_at, new.created_at)
       is distinct from
       (old.id, old.tenant_id, old.user_id, old.role_id, old.scope_type, old.branch_id,
        old.department_id, old.starts_at, old.created_at) then
        raise exception 'a role grant''s holder, role, scope and start are fixed; revoke it and assign a new one'
            using errcode = '23514';
    end if;
    if new.ends_at is distinct from old.ends_at
       and old.is_active and (old.ends_at is null or old.ends_at > now())
       and new.is_active and (new.ends_at is null or new.ends_at > now()) then
        raise exception 'a live role grant''s end moves only by ending it; revoke it and assign a new one'
            using errcode = '23514';
    end if;
    return new;
end;
$fn$;

revoke execute on function app.guard_role_assignment_change() from public;

create trigger user_role_assignments_guard_change
    before update on public.user_role_assignments
    for each row execute function app.guard_role_assignment_change();
