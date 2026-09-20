-- ================================================================================================
-- SPEC-203 -- A membership change costs the same authority, and leaves the same trace, through
-- every door.
--
-- USR-1 -- `public.users` is the only member of the canon-34 identity-and-access family with no
-- emitter at all. Measured against the clean baseline: one actor created a membership, deactivated
-- a colleague and unbound a third human from their membership by direct DML, and the tenant's
-- event count stayed at 3 -> 3. The same `user_created` fact through `app.create_tenant_user`
-- moved it 3 -> 4, because that function calls `app.record_event` inside itself. That is the
-- RPC-only-producer shape `202607055100` already removed from `app.assign_user_role`.
--
-- USR-2 -- the same administrative act costs a step-up through the RPC and nothing through the
-- table. `app.authorize` is permission AND MFA; the four RLS policies on this table call
-- `app.has_permission`, which is permission only. Measured: one actor holding MANAGE_USERS with
-- `app.mfa_satisfied()` false was refused 42501 by `app.create_tenant_user` and, in the same
-- transaction, successfully ran the equivalent direct INSERT, a direct deactivation and a direct
-- identity re-point.
--
-- The precedent is `app.emit_role_change` (`202607055100`) and it is reused in shape and in actor
-- resolution -- authority charged only when a session exists, actor from `app.current_user_id()`,
-- and exactly one producer of the event. What does NOT transfer is its single-trigger form, and
-- the reason is measured rather than stylistic: `public.users.is_active` is an input to
-- `app.current_user_id()` and therefore to `app.has_permission`, so an authority check evaluated
-- AFTER the statement is evaluated against a world the statement has already changed, and an
-- administrator deactivating their own membership would be refused `permission denied:
-- MANAGE_USERS`. `user_role_assignments` has no such self-reference. Authority is a precondition
-- and runs BEFORE; the record is a fact and runs AFTER.
--
-- DELETE is deliberately excluded from both triggers. `authenticated` holds no DELETE on this
-- table (the grants are INSERT, SELECT, UPDATE), and `public.events` carries
-- FOREIGN KEY (tenant_id, actor_user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT, so
-- there is no reachable tenant-user delete door and no measured defect on one. DELETE has not
-- earned inclusion merely because the sibling trigger names it.
--
-- What this migration does NOT do, stated so the boundary is mechanical: it does not add
-- `app.guard_write_capability` to this table (that guard decides a full bypass from
-- `new.assigned_user_id`, the LEAD-1 defect, and this table has no such column), it does not alter
-- `users_enforce_identity_binding`, and it does not alter any RLS policy.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- Vocabulary. `sort_order` 932, 933 and 934 are MEASURED, not chosen by pattern: `event_type`
-- currently holds 184 rows whose maximum `sort_order` is 931, and 166/167/168 -- the values the
-- cancelled SPEC-195 froze for these same three codes -- are already held by `refund_approved`,
-- `refund_rejected` and `refund_cancelled`. The three rows are seeded under an EXISTING catalog
-- type, so `catalog_types` does not move: 71 stays 71 and `catalog_values` goes 618 -> 621.
-- ------------------------------------------------------------------------------------------------
insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
select null::uuid, v.type_code, v.code, v.label, v.ord, true, true
from (values
        ('event_type', 'user_deactivated',     'User Deactivated',     932),
        ('event_type', 'user_reactivated',     'User Reactivated',     933),
        ('event_type', 'user_identity_bound',  'User Identity Bound',  934)
     ) as v(type_code, code, label, ord)
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = v.type_code and cv.code = v.code and cv.tenant_id is null
);

-- ------------------------------------------------------------------------------------------------
-- USR-2. Authority, charged BEFORE the statement.
--
-- `app.authorize`, not `app.has_permission`: that single substitution is what makes the direct-DML
-- door cost exactly what the RPC door costs. It is charged UNCONDITIONALLY on every path and every
-- column -- there is no relationship test, no ownership test and nothing read from the attacking
-- statement's own image that decides whether the check happens.
--
-- Two exemptions exist, and both are narrow enough to name:
--
-- 1. NO SESSION. Platform paths -- `app.provision_tenant`, migrations, service_role -- carry no
--    session and are outside per-table enforcement, exactly as in SPEC-145/149,
--    `app.enforce_archive_authority` and `app.emit_role_change`. They are still AUDITED by the
--    AFTER trigger; the exemption is from the permission check, never from the record.
--
-- 2. THE SELF-CLAIM. `app.activate_membership()` lets an ordinary employee bind their own verified
--    identity to an unclaimed membership, and that employee holds no MANAGE_USERS. Without this
--    carve-out the claim becomes impossible for the only people it exists for.
--
-- The carve-out reads `new`, which is the shape of BOOK-5 / LEAD-1 / PAX-3, so it was ATTACKED
-- rather than argued. It is admissible only because it is not what decides the outcome:
-- `users_enforce_identity_binding` independently requires the membership's email to match the
-- bound identity's email in `auth.users`, which the attacker does not control. An administrator at
-- aal1 pointing an unclaimed executive membership at their own identity is refused 23514 by that
-- constraint; renaming the row under the same statement is still refused 23514; and moving
-- `email`, `is_active`, `is_platform_user` or the tenant takes the statement out of the carve-out
-- entirely and is refused 42501. An employee without MANAGE_USERS never reaches the carve-out at
-- all, because RLS refuses them first.
--
-- `old` is read only inside the `tg_op = 'UPDATE'` branch. plpgsql binds every referenced variable
-- as a query parameter before the statement runs, so reading a field of an unassigned RECORD
-- raises 55000 before any guard can short-circuit -- the failure mode SPEC-159-A hit, and the
-- reason `app.emit_role_change` branches on `tg_op` into scalars.
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_membership_authority()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'UPDATE' then
        if old.auth_user_id is null
           and new.auth_user_id = (select auth.uid())
           and new.tenant_id        is not distinct from old.tenant_id
           and new.email            is not distinct from old.email
           and new.is_active        is not distinct from old.is_active
           and new.is_platform_user is not distinct from old.is_platform_user
        then
            return new;
        end if;
    end if;

    perform app.authorize('MANAGE_USERS');

    return new;
end;
$fn$;

-- ------------------------------------------------------------------------------------------------
-- USR-1 / IDENT-2. The record, written AFTER the statement.
--
-- The actor is RESOLVED, not passed as null. `app.create_tenant_user` today looks up the acting
-- membership and records it, so an emitter that always passed null would LOSE attribution while
-- claiming to add auditing. This reuses `app.emit_role_change`'s own idiom instead.
--
-- One property falls out of that resolver and is pinned by an assertion rather than left to be
-- rediscovered: an administrator deactivating their OWN membership records a null actor, because
-- `app.current_user_id()` requires `is_active` and an AFTER trigger observes the post-image. That
-- is stated here because it is a consequence, not an accident.
--
-- Returns null: the row is already written and an AFTER FOR EACH ROW trigger's return value is
-- ignored.
-- ------------------------------------------------------------------------------------------------
create or replace function app.emit_membership_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_actor uuid := app.current_user_id();
begin
    if tg_op = 'INSERT' then
        perform app.record_event(
            new.tenant_id, 'user_created', 'user', new.id, v_actor,
            null, 'active', null,
            jsonb_build_object('email', new.email, 'has_auth_link', new.auth_user_id is not null),
            'info');

        return null;
    end if;

    -- Membership viability. This is the transition that decides whether a human can act at all,
    -- which is why it is `security` and not `info`.
    if new.is_active is distinct from old.is_active then
        perform app.record_event(
            new.tenant_id,
            case when new.is_active then 'user_reactivated' else 'user_deactivated' end,
            'user', new.id, v_actor,
            case when old.is_active then 'active' else 'inactive' end,
            case when new.is_active then 'active' else 'inactive' end,
            null,
            jsonb_build_object('email', new.email),
            'security');
    end if;

    -- Identity re-binding. Moving `auth_user_id` transfers a role-bearing membership to a
    -- different human; before this it was the least visible privileged act on the table.
    if new.auth_user_id is distinct from old.auth_user_id then
        perform app.record_event(
            new.tenant_id, 'user_identity_bound', 'user', new.id, v_actor,
            old.auth_user_id::text,
            new.auth_user_id::text,
            null,
            jsonb_build_object('email', new.email),
            'security');
    end if;

    return null;
end;
$fn$;

revoke execute on function app.guard_membership_authority() from public;
revoke execute on function app.emit_membership_change() from public;

create trigger users_guard_membership_authority
    before insert or update on public.users
    for each row execute function app.guard_membership_authority();

create trigger users_emit_membership_change
    after insert or update on public.users
    for each row execute function app.emit_membership_change();

comment on function app.guard_membership_authority() is
    'USR-2: charges app.authorize(''MANAGE_USERS'') -- permission AND step-up -- on every membership '
    'write, so direct DML costs exactly what app.create_tenant_user costs. Exempts only the '
    'session-less platform path and the app.activate_membership self-claim, the latter bounded by '
    'users_enforce_identity_binding, which reads auth.users rather than the caller''s own image.';

comment on function app.emit_membership_change() is
    'USR-1/IDENT-2: the single producer of user_created, user_deactivated, user_reactivated and '
    'user_identity_bound. Actor resolved via app.current_user_id(), as app.emit_role_change does.';

-- ------------------------------------------------------------------------------------------------
-- The RPC loses its own emission. There is now exactly ONE producer of `user_created`, and it sits
-- on the table where every path must pass. Leaving the call here would have produced TWO events
-- for one membership -- measured under the prototype, which is why this removal is causally
-- required and not cosmetic.
--
-- Everything else about this function is unchanged and deliberately so: the tenant check, the
-- `app.authorize('MANAGE_USERS')` call, the insert and the return all remain. The `v_actor`
-- declaration and its lookup go with the `record_event` call they existed to feed.
-- ------------------------------------------------------------------------------------------------
create or replace function app.create_tenant_user(
    p_full_name text,
    p_email text,
    p_phone text default null,
    p_auth_user_id uuid default null
)
returns uuid
language plpgsql
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_user uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('MANAGE_USERS');

    insert into public.users (tenant_id, auth_user_id, full_name, email, phone, is_active)
    values (v_tenant, p_auth_user_id, p_full_name, p_email, p_phone, true)
    returning id into v_user;

    -- `user_created` is emitted by users_emit_membership_change, not from here.

    return v_user;
end;
$fn$;
