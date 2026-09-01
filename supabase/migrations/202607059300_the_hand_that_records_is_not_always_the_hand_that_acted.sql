-- ATTR-2 -- the actor attributions that survived three previous sweeps.
--
-- ================================================================================================
-- WHAT WAS REPRODUCED, AND WHY EACH ONE IS A DEFECT RATHER THAN A DESIGN
--
-- Every column closed here has EXACTLY ONE producer, and that producer already sets it to the
-- authenticated caller. None of them accepts an actor as a parameter. So a direct write naming
-- somebody else is not a business fact ORVION can express through any authorized path -- it is
-- forgery, and the RPC door and the table door simply disagreed. This is the two-door rule
-- (`AGENTS.md §6`) applied to attribution, exactly as ATTR-1, ASGN-2, FX-2, FX-3 and FX-4 applied it
-- before it. Reproduced behaviourally, each with a live positive AND negative control:
--
--   A  `payments.received_by`      a finance_manager who GENUINELY HOLDS RECORD_PAYMENT inserted a
--                                  payment recording the EMPLOYEE as the receiver -- while ATTR-1's
--                                  trigger corrected `created_by` to the finance_manager in the
--                                  SAME STATEMENT. One column derived, the other accepted verbatim.
--   B  `payments.received_by`      an employee who does NOT hold RECORD_PAYMENT, refused 42501 when
--                                  changing `amount` (so the guard is live), then succeeded --
--                                  UPDATE 1 -- changing ONLY `received_by`. Rewriting who received
--                                  money required no capability at all, because
--                                  `guard_financial_capability` watches `amount` and nothing else.
--   C  `lead_interactions.user_id` the assigned handler recorded a phone call attributed to the
--                                  OWNER. `guard_lead_interaction_authority` enforces AUTHORITY and
--                                  never ATTRIBUTION: it asks whether the caller may write here,
--                                  then accepts whatever actor the caller names.
--   D  `customers.first_registered_user_id`
--                                  an employee created a customer registered to the OWNER, while
--                                  `created_by` was corrected to the employee. ASGN-2's exact shape:
--                                  `freeze_first_registration` guards UPDATE only, so the column
--                                  LOOKED governed and nothing constrained INSERT.
--   E  `customer_identity_merges.merged_by`
--                                  the owner, who holds MERGE_CUSTOMER_IDENTITY, recorded the merge
--                                  as performed by the employee.
--   F  `booking_items.cancelled_by` / `no_show_recorded_by`
--                                  an employee who does NOT hold CANCEL_BOOKING stamped both columns
--                                  with the owner's identity on an item still `confirmed` -- an
--                                  attribution for a cancellation that never happened.
--
-- TWO OF THESE WERE INVISIBLE TO THE DETECTOR THAT WAS SUPPOSED TO FIND THEM. `83_actor_attribution
-- _test.sql` assertion 22 asks the schema for every column ending `_by`, which is still a NAME
-- PATTERN -- and `lead_interactions.user_id` and `customers.first_registered_user_id` carry an actor
-- without one. That is ASGN-2's lesson repeating for the fourth time: `lead_assignments` carried
-- `created_by`'s meaning under a different name and a name-shaped sweep could not see it. The
-- replacement predicate asks for FOREIGN KEYS TO `public.users` on tables `authenticated` can write,
-- which is a structural question rather than a lexical one; it is pinned as assertion 23.
--
-- ================================================================================================
-- DELIBERATELY NOT DERIVED, AND EACH FOR A DIFFERENT REASON
--
--   `invoices.voided_by`, `journal_entries.voided_by`  -- VOID-1, an OPEN OWNER DECISION. Nothing
--      writes them and `app.status_transitions` has no rows for either table; voiding is not
--      implemented. Migration `202607056500` already reached this conclusion and it still holds:
--      deriving an attribution for an action nobody can perform would dress a missing capability as
--      a solved one. Register row 262 listed them among "eight actor columns accepted from the
--      caller", which is true as a schema fact and misleading as a work item -- corrected there.
--
--   `payments.verified_by`  -- the same shape, and newly measured: NO function writes it, and there
--      is NO `VERIFY_PAYMENT` permission in `public.permissions` at all. Canon 07 DOES define a
--      two-person money workflow ("Finance verifies the bank account") -- but ORVION implements it
--      through `approval_requests`, whose `requested_by` and `reviewed_by` are already derived by
--      `app.derive_approval_requester` and `app.derive_approval_reviewer`. So `verified_by` and
--      `verified_at` duplicate a capability that already has a home. Recorded as VERIFY-1.
--
--   `tenant_license_activations.consumed_by`  -- MEASURED, not assumed: the table is granted to
--      `postgres` and `service_role` ONLY. No tenant caller can reach it by any door, and its only
--      writer, `app.redeem_license_token`, is SECURITY DEFINER and already derives the session
--      actor. A trigger here would guard a door that does not exist.
--
--   `customers.last_interaction_user_id`  -- no writer anywhere. Dead structure, recorded as DEAD-3,
--      not an attribution defect.
--
-- ================================================================================================
-- WHY FIVE DEDICATED FUNCTIONS AND NOT ONE GENERIC DERIVER
--
-- A single `app.derive_actor()` taking the column name as a TRIGGER ARGUMENT would be shorter and
-- would deliberately rebuild **MEAS-1**: a detector reading function bodies is blind to codes
-- carried in trigger arguments, which is precisely how a whole class of enforcement went unmeasured
-- once already. Every existing deriver in this repository is per-column for the same reason
-- (`derive_created_by`, `derive_proof_uploader`, `derive_approval_reviewer`,
-- `derive_exchange_rate_setter`, `derive_role_assignment_actor`, `derive_message_sender`). FX-2 also
-- established that widening `derive_created_by`, which twenty tables depend on, is the CUST-1 shape
-- and is not done. The idiom below is unchanged from those: DERIVE, DO NOT VALIDATE (WP-00), and
-- leave session-less platform paths alone (canon 35 principle 6).
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- payments.received_by
-- INSERT derives; UPDATE freezes. Freezing is safe and was measured: NO function in `app` or
-- `public` updates `public.payments` at all, so the RPC path cannot collide with it. That is the
-- same argument ATTR-1 made before freezing `created_by` on twenty tables.
-- ------------------------------------------------------------------------------------------------
create or replace function app.derive_payment_receiver()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    if tg_op = 'INSERT' then
        new.received_by := app.current_user_id();
    else
        new.received_by := old.received_by;
    end if;
    return new;
end
$fn$;

revoke execute on function app.derive_payment_receiver() from public;

create trigger payments_derive_receiver
    before insert or update on public.payments
    for each row execute function app.derive_payment_receiver();

-- ------------------------------------------------------------------------------------------------
-- lead_interactions.user_id
-- The interaction record IS the act of contacting the lead, so its actor is the caller who recorded
-- it. `app.record_lead_interaction` already sets exactly this value; the trigger only makes the
-- direct door agree. Authority remains entirely with `app.guard_lead_interaction_authority` -- this
-- function decides WHO IS RECORDED, never WHETHER THE WRITE IS ALLOWED.
-- ------------------------------------------------------------------------------------------------
create or replace function app.derive_interaction_actor()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    if tg_op = 'INSERT' then
        new.user_id := app.current_user_id();
    else
        new.user_id := old.user_id;
    end if;
    return new;
end
$fn$;

revoke execute on function app.derive_interaction_actor() from public;

create trigger lead_interactions_derive_actor
    before insert or update on public.lead_interactions
    for each row execute function app.derive_interaction_actor();

-- ------------------------------------------------------------------------------------------------
-- customer_identity_merges.merged_by
-- An append-only audit log of a destructive operation. `app.merge_customer_identity` is SECURITY
-- DEFINER and derives the session actor already.
-- ------------------------------------------------------------------------------------------------
create or replace function app.derive_merge_actor()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    if tg_op = 'INSERT' then
        new.merged_by := app.current_user_id();
    else
        new.merged_by := old.merged_by;
    end if;
    return new;
end
$fn$;

revoke execute on function app.derive_merge_actor() from public;

create trigger customer_identity_merges_derive_actor
    before insert or update on public.customer_identity_merges
    for each row execute function app.derive_merge_actor();

-- ------------------------------------------------------------------------------------------------
-- customers.first_registered_user_id
-- INSERT only. UPDATE is already governed by `app.freeze_first_registration`, which RAISES rather
-- than silently reverting -- the stronger response, and it is kept. One gap it left is closed here:
-- it refuses a change only when the OLD value is non-null, so a row created session-less with NULL
-- could later be filled in by any direct writer. Deriving from NULL closes that without weakening
-- the freeze, and trigger order guarantees it: `customers_derive_...` sorts before
-- `customers_freeze_...`, so the freeze still sees `old` unchanged.
-- ------------------------------------------------------------------------------------------------
create or replace function app.derive_first_registration_actor()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    if tg_op = 'INSERT' then
        new.first_registered_user_id := app.current_user_id();
    elsif old.first_registered_user_id is null then
        new.first_registered_user_id := app.current_user_id();
    end if;
    return new;
end
$fn$;

revoke execute on function app.derive_first_registration_actor() from public;

create trigger customers_derive_first_registration_actor
    before insert or update on public.customers
    for each row execute function app.derive_first_registration_actor();

-- ------------------------------------------------------------------------------------------------
-- booking_items.cancelled_by / no_show_recorded_by
-- These are ACTION attributions, so unlike the four above they are not INSERT-time facts and
-- `derive_created_by`'s shape would be wrong for them (ATTR-1 said so, and left them alone for
-- exactly that reason). The rule is read off the only producer: `app.advance_booking_item` sets
-- `cancelled_by` precisely when the item moves to `cancelled`, and `no_show_recorded_by` precisely
-- when it moves to `no_show`. Mirroring that ties the attribution to the act, which is what makes
-- scenario F unrepresentable rather than merely re-attributed -- re-attributing it would have
-- recorded the employee as the canceller of an item that was never cancelled, trading one false
-- statement for another.
--
-- Both statuses are TERMINAL in `app.status_transitions` (no row leaves `cancelled` or `no_show`),
-- so carrying `old` forward on every other update makes the value immutable once earned.
-- ------------------------------------------------------------------------------------------------
create or replace function app.derive_booking_item_action_actor()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_actor uuid;
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    v_actor := app.current_user_id();

    if tg_op = 'INSERT' then
        new.cancelled_by := case when new.base_status_code = 'cancelled' then v_actor end;
        new.no_show_recorded_by := case when new.base_status_code = 'no_show' then v_actor end;
        return new;
    end if;

    if new.base_status_code = 'cancelled' and old.base_status_code is distinct from 'cancelled' then
        new.cancelled_by := v_actor;
    else
        new.cancelled_by := old.cancelled_by;
    end if;

    if new.base_status_code = 'no_show' and old.base_status_code is distinct from 'no_show' then
        new.no_show_recorded_by := v_actor;
    else
        new.no_show_recorded_by := old.no_show_recorded_by;
    end if;

    return new;
end
$fn$;

revoke execute on function app.derive_booking_item_action_actor() from public;

-- Fires AFTER `booking_items_enforce_status_transition` would have rejected an illegal move? No --
-- both are BEFORE triggers and this one sorts first by name. That is harmless and deliberate: this
-- function only ever copies `old` forward or stamps the caller, so if the transition guard then
-- rejects the statement, nothing was written. Attribution never decides whether a write is allowed.
create trigger booking_items_derive_action_actor
    before insert or update on public.booking_items
    for each row execute function app.derive_booking_item_action_actor();
