-- Migration: "who did this" is derived, never accepted
-- Batch 6, table-by-table audit — second slice of the same sweep (FX-3, FX-4).
--
-- THE CLASS. ORVION derives actor columns from the session rather than trusting the caller: twenty
-- tables carry `app.derive_created_by`, `subscription_payment_proofs` carries `derive_proof_uploader`,
-- `approval_requests` carries `derive_approval_reviewer`, and ASGN-2 added `derive_assignment_actor`
-- for `lead_assignments` one package ago. This migration finishes the class.
--
-- HOW THESE TWO WERE FOUND, AND WHY THE SEARCH ITSELF IS THE LESSON. A sweep for actor columns using
-- the hand-written list ('created_by','set_by','uploaded_by','recorded_by','issued_by') reported
-- exactly ONE gap and looked complete. Adding `assigned_by` produced a second (FX-3). Widening it
-- again to `reviewed_by` produced a third (FX-4). A detector's blind spot is indistinguishable from
-- a clean result, which is why `83_actor_attribution_test.sql` now asks the SCHEMA the question
-- instead of asking a list — and why that assertion, not this migration, is the durable part.
--
-- ---------------------------------------------------------------------------------------------
-- FX-3 — `user_role_assignments.assigned_by`. REPRODUCED, same actor, same transaction, two doors:
--     app.assign_user_role(...)              -> assigned_by = the OWNER who called it   (correct)
--     direct INSERT with assigned_by set     -> assigned_by = THE MANAGER BEING PROMOTED
--     direct INSERT with it omitted          -> assigned_by = NULL, no granter at all
-- The RPC derives `v_actor` from `auth.uid()`; nothing made the table do the same (ADR-0024, and the
-- same shape as ASGN-2). Severity is the highest in this sweep because this column has real
-- consumers — `assign_user_role`, `revoke_user_role`, and the `role_assigned` event emitter — and
-- because what was forgeable is the trail of who exercised privilege. Authorization is NOT affected:
-- SPEC-138 still requires MANAGE_USERS on every write and a negative control proves an employee is
-- refused. This is the WP-00 forgery class applied to the privilege trail.
--
-- ---------------------------------------------------------------------------------------------
-- FX-4 — `subscription_payment_proofs.reviewed_by`. **NOT REACHABLE TODAY, and recorded as such
-- rather than dressed up as a defect.** Measured: no role holds `REVIEW_SUBSCRIPTION_PAYMENT`, so
-- the UPDATE policy that requires it can never be satisfied by a tenant caller; and
-- `app.platform_review_payment_proof` sets `status_code`, `reviewed_at` and `review_notes` but never
-- `reviewed_by` — it runs session-less as the Platform Owner, where WP-00 requires the actor to be
-- NULL rather than invented. So the column has no writer at all and NULL is the correct value today.
--
-- It is guarded anyway, and the reason is specific rather than defensive: canon 28 assigns
-- `REVIEW_SUBSCRIPTION_PAYMENT` to owner / ceo / finance_manager, and the seed simply has not granted
-- it. The day it is granted, the tenant-side UPDATE becomes reachable and this column becomes
-- forgeable — with nothing to notice. Guarding it now costs one object and no behaviour, and it lets
-- the class assertion hold with NO exemption list, which is worth more than the trigger: an
-- exemption list is a place for the next gap to hide.
--
-- ENFORCEMENT LAYER (ADR-0025). Attribution is a statement about the SESSION, not about the row, so
-- a CHECK cannot express it — it must be a trigger, on the table, because the table is the door that
-- was wrong. The session-less exemption is REQUIRED, not merely permitted: `app.provision_tenant`
-- inserts the founding owner's role assignment as `service_role` with no session, and its own body
-- records why ("WP-00 requires actor NULL on that path"). Both functions copy
-- `app.derive_created_by`'s semantics verbatim so they cannot drift from it in meaning.
--
-- Dedicated functions rather than a generalised one: `app.derive_created_by` hard-codes a column
-- neither table has, and widening a function twenty tables depend on to serve two is the CUST-1
-- shape — a structurally reasonable change that silently alters twenty consumers.

-- ---------------------------------------------------------------------------------------------
-- 1. FX-3.
-- ---------------------------------------------------------------------------------------------
create or replace function app.derive_role_assignment_actor()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'INSERT' then
        new.assigned_by := app.current_user_id();
    else
        -- Immutable once written. Verified before relying on it: `app.assign_user_role` only
        -- INSERTs, and `app.revoke_user_role` updates `is_active`/`ends_at`, never `assigned_by`.
        new.assigned_by := old.assigned_by;
    end if;

    return new;
end
$fn$;
revoke all on function app.derive_role_assignment_actor() from public;

create trigger user_role_assignments_derive_actor
    before insert or update on public.user_role_assignments
    for each row execute function app.derive_role_assignment_actor();

-- ---------------------------------------------------------------------------------------------
-- 2. FX-4.
-- ---------------------------------------------------------------------------------------------
create or replace function app.derive_proof_reviewer()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    -- The platform review path is session-less by design and records no ORVION actor. This is the
    -- branch that keeps that true.
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'INSERT' then
        new.reviewed_by := app.current_user_id();
    else
        -- On UPDATE the reviewer is stamped the first time and frozen thereafter, so a second
        -- review cannot silently overwrite who performed the first.
        new.reviewed_by := coalesce(old.reviewed_by, app.current_user_id());
    end if;

    return new;
end
$fn$;
revoke all on function app.derive_proof_reviewer() from public;

create trigger subscription_payment_proofs_derive_reviewer
    before insert or update on public.subscription_payment_proofs
    for each row execute function app.derive_proof_reviewer();
