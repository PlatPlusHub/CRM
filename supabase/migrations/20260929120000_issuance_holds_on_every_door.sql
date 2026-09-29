-- Phase-8 Activation Closure: BOOK-10 -- issuance holds on every door.
--
-- `app.map_outcomes_to_conversions` turns `booking_issued` into `ticket_issued`. Every rule of
-- issuance lived in `app.advance_booking` alone, while `authenticated` holds INSERT and UPDATE on
-- `bookings` and `app.enforce_status_transition` makes the status door a governed one (the canon 26
-- edge and its permission, ISSUE_BOOKING for issuance). MEASURED at `2496591`, rolled back, with a
-- consented Google Ads click on every lead:
--   * a branch manager with a per-user deny on ALLOW_ISSUE_WITH_NEGATIVE_BALANCE, refused by the RPC
--     for a customer owing 5000 EGP, issued the same booking by UPDATE -- no `booking_issued`, no
--     `booking_item_risk_flag_created`, no `ticket_issued`;
--   * an owner's direct issue of a booking nothing was owed on recorded no `booking_issued`, so it
--     never became `ticket_issued`; a session-less issue recorded nothing either;
--   * an archived booking the RPC refuses ("booking is archived") was issued, and another cancelled,
--     by UPDATE;
--   * an employee holding CREATE_BOOKING and not ISSUE_BOOKING INSERTed a booking born `issued`:
--     no transition, no permission, no issuance event (ENTRY-1's `bookings` instance).
--
-- THE SHAPE. One table trigger, `bookings_enforce_lifecycle`, becomes the single authority for the
-- rules `app.advance_booking` held that a table write can express, and the single producer of the
-- issuance events. It is AFTER, not BEFORE, so it judges a row the state machine, capability and
-- step-up triggers have already passed (the refusal order is the RPC's), and immediate, not deferred,
-- because nothing issuance reads is written after the booking in the same transaction.
--   * Entry (ENTRY-1): a signed-in caller creates a booking at `draft`, the state `app.create_booking`
--     writes and canon 26 starts from. Session-less platform paths are exempt, LEAD-2's rule, since
--     `app.enforce_status_transition` already exempts them from the whole graph.
--   * Archived: an archived booking's status does not move. The RPC's rule for every transition,
--     moved here whole rather than copied, and held on every path because it is integrity (ADR-0025).
--   * Issuance, on ENTRY into `issued` (from `in_progress` or `reissue`, the two edges canon 26
--     allows): the customer's balance for this booking comes from `app.customer_balance`, the single
--     authority (ADR-0021); if any currency is owed, a signed-in caller must hold
--     ALLOW_ISSUE_WITH_NEGATIVE_BALANCE (ADR-0020). Every value is read from OLD -- the booking as it
--     stood before this write, exactly what the RPC read -- so a customer rebound in the same
--     statement cannot move the balance being judged. Then `booking_issued` is recorded with the RPC's
--     payload keys, and, when owed and signed in, `booking_item_risk_flag_created` with the permission
--     used and the balance snapshot. The override and its risk record are authorization, so a
--     session-less path is exempt from both (ADR-0025); `booking_issued` is recorded on every path.
-- SECURITY INVOKER, unlike the SPEC-237/238 emitters: the balance the override is judged on stays
-- the one the caller can read, exactly as in the RPC, which is invoker too. `app.record_event` is
-- SECURITY DEFINER and owns the actor and time. `app.advance_booking` hands its reason to the trigger
-- through SPEC-237's transaction-local `app.transition_reason`, which the trigger consumes.
--
-- NOT CHANGED: every grant, policy, `app.status_transitions`, `app.enforce_status_transition`, the
-- mapper, the other transition events of `app.advance_booking`, and its cancellation-reason and
-- `cancelled_at`/`completed_at` rules, which a table write cannot carry (the remainder of BOOK-10).

create or replace function app.enforce_booking_lifecycle()
returns trigger
language plpgsql
set search_path to ''
as $fn$
declare
    v_signed_in boolean := (select auth.uid()) is not null;
    v_reason text;
    v_owes boolean := false;
    v_snapshot jsonb;
begin
    if tg_op = 'INSERT' then
        if v_signed_in and new.booking_status_code is distinct from 'draft' then
            raise exception
                'a booking is created at ''draft'' (canon 26); it was created as ''%'' -- use '
                'app.advance_booking to move it', new.booking_status_code
                using errcode = '23514';
        end if;
        return null;
    end if;

    if new.booking_status_code is not distinct from old.booking_status_code then
        return null;
    end if;

    if old.is_archived then
        raise exception 'booking is archived';
    end if;

    if new.booking_status_code <> 'issued' then
        return null;
    end if;

    v_reason := nullif(current_setting('app.transition_reason', true), '');
    -- Consumed: a later issuance in the same transaction carries only its own reason.
    perform set_config('app.transition_reason', '', true);

    if v_signed_in then
        select coalesce(bool_or(cb.outstanding_balance > 0), false),
               coalesce(jsonb_agg(jsonb_build_object(
                   'currency_code', cb.currency_code,
                   'outstanding_balance', cb.outstanding_balance) order by cb.currency_code), '[]'::jsonb)
          into v_owes, v_snapshot
        from app.customer_balance(old.customer_id, old.id) cb;

        if v_owes then
            perform app.authorize('ALLOW_ISSUE_WITH_NEGATIVE_BALANCE');
        end if;
    end if;

    perform app.record_event(
        new.tenant_id, 'booking_issued', 'booking', new.id, app.current_user_id(),
        old.booking_status_code, new.booking_status_code, v_reason,
        jsonb_build_object('customer_id', old.customer_id, 'lead_id', old.lead_id,
                           'booking_reference', old.booking_reference),
        'info');

    if v_owes then
        perform app.record_event(
            new.tenant_id, 'booking_item_risk_flag_created', 'booking', new.id, app.current_user_id(),
            null, 'issued', v_reason,
            jsonb_build_object('permission_used', 'ALLOW_ISSUE_WITH_NEGATIVE_BALANCE',
                               'customer_id', old.customer_id,
                               'customer_balance_snapshot', v_snapshot),
            'risk');
    end if;

    return null;
end;
$fn$;

revoke execute on function app.enforce_booking_lifecycle() from public;

create trigger bookings_enforce_lifecycle
    after insert or update of booking_status_code on public.bookings
    for each row execute function app.enforce_booking_lifecycle();

create or replace function app.advance_booking(p_booking_id uuid, p_to_status text, p_reason text default null::text)
returns text
language plpgsql
set search_path to ''
as $function$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_bk record;
    v_event text;
    v_perm text;
    v_is_cancel boolean;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    select id, booking_status_code, customer_id, lead_id, booking_reference
      into v_bk
    from public.bookings
    where id = p_booking_id and tenant_id = v_tenant;
    if not found then
        raise exception 'booking is not in your tenant';
    end if;
    -- BOOK-10: "booking is archived" is refused by `bookings_enforce_lifecycle` on every door.

    -- Canonical allowed transitions (26 Booking State Machine) with per-transition authority + event.
    -- The full lifecycle is now implemented; no transition is deferred.
    select t.ev, t.perm into v_event, v_perm
    from (values
        ('draft',            'pending_approval', 'booking_submitted_for_approval', 'CREATE_BOOKING'),
        ('draft',            'cancelled',        'booking_cancelled',              'CREATE_BOOKING'),
        ('pending_approval', 'cancelled',        'booking_cancelled',              'CREATE_BOOKING'),
        ('pending_approval', 'confirmed',        'booking_confirmed',              'APPROVE_BOOKING'),
        ('confirmed',        'in_progress',      'booking_in_progress',            'CREATE_BOOKING'),
        ('confirmed',        'cancelled',        'booking_cancelled',              'CANCEL_BOOKING'),
        ('in_progress',      'completed',        'booking_completed',              'CREATE_BOOKING'),
        ('in_progress',      'issued',           'booking_issued',                 'ISSUE_BOOKING'),
        ('in_progress',      'cancelled',        'booking_cancelled',              'CANCEL_BOOKING'),
        ('issued',           'completed',        'booking_completed',              'CREATE_BOOKING'),
        ('issued',           'void',             'booking_voided',                 'CANCEL_BOOKING'),
        ('issued',           'refunded',         'booking_refunded',               'REFUND_BOOKING'),
        ('issued',           'reissue',          'booking_reissue_started',        'REISSUE_BOOKING'),
        ('reissue',          'issued',           'booking_issued',                 'ISSUE_BOOKING'),
        ('void',             'completed',        'booking_completed',              'CREATE_BOOKING'),
        ('refunded',         'completed',        'booking_completed',              'CREATE_BOOKING')
    ) as t(frm, to_s, ev, perm)
    where t.frm = v_bk.booking_status_code and t.to_s = p_to_status;

    if v_event is null then
        raise exception 'transition not allowed: % -> %', v_bk.booking_status_code, p_to_status;
    end if;

    v_is_cancel := (p_to_status = 'cancelled');

    -- 27: booking_cancelled requires a cancellation reason (enforced uniformly on every cancel edge).
    if v_is_cancel and (p_reason is null or btrim(p_reason) = '') then
        raise exception 'cancellation requires a reason';
    end if;

    perform app.authorize(v_perm);

    -- BOOK-10: issuance -- the negative-balance override (ADR-0020), `booking_issued` and the risk
    -- flag -- is `bookings_enforce_lifecycle`'s on every door; this RPC only hands it the caller's
    -- reason for the transaction's next issuance.
    if p_to_status = 'issued' then
        perform set_config('app.transition_reason', coalesce(p_reason, ''), true);
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    update public.bookings
    set booking_status_code = p_to_status,
        cancelled_at = case when v_is_cancel then now() else cancelled_at end,
        completed_at = case when p_to_status = 'completed' then now() else completed_at end,
        updated_at = now()
    where id = p_booking_id;

    -- Publish the canonical booking event (orchestration boundary). cancelled/void/refunded/reissue are
    -- 'warning' (27); progress/completion are 'info'.
    if p_to_status <> 'issued' then
    perform app.record_event(
        v_tenant, v_event, 'booking', p_booking_id, v_actor,
        v_bk.booking_status_code, p_to_status, p_reason,
        jsonb_build_object('customer_id', v_bk.customer_id, 'lead_id', v_bk.lead_id,
                           'booking_reference', v_bk.booking_reference),
        case when p_to_status in ('cancelled', 'void', 'refunded', 'reissue') then 'warning' else 'info' end
    );
    end if;

    return p_to_status;
end;
$function$;
