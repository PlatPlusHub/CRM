-- Phase-8 Activation Closure: CONV-8 -- a qualified lead and a booking are recorded on every door.
--
-- `app.map_outcomes_to_conversions` turns `lead_qualified` into the `qualified_lead` offline conversion
-- and `booking_created` into `booking_created`. Each event had one producer, its RPC. `authenticated`
-- holds UPDATE on `leads` and INSERT on `bookings`, and the state machine lets the assigned handler move
-- a contacted lead to `qualified` at the table door, so the same business act done there was silent:
-- MEASURED with a consented Google Ads click on every lead, the handler's direct qualification and an
-- employee's direct booking produced no event and no conversion, while the RPCs produced both.
--
-- THE SHAPE is SPEC-215's (`supplier_created`) and USR-1's: one AFTER trigger is the single producer
-- of the event and the RPC loses its own `record_event`, so no act is recorded twice. `app.record_event`
-- takes the actor from the session and stamps the time, so neither door can name another actor or
-- backdate the event; session-less writes are recorded with a null actor.
--   * `booking_created` fires AFTER INSERT on `bookings`. Its payload keys are the ones
--     `app.create_booking` wrote, read from the row it wrote them into.
--   * `lead_qualified` fires AFTER UPDATE OF `lead_status_code` when a lead ENTERS `qualified`. A lead
--     cannot be born qualified by a signed-in caller (LEAD-2), so the transition is the business act.
--     `app.advance_lead` accepts a free-text reason for the transition; it now hands that reason to
--     the trigger through a transaction-local setting, which the trigger consumes and clears. The
--     reason is caller-supplied text on either door, so the channel carries no authority.
--
-- NOT CHANGED: every grant, policy, guard, state transition, the mapper, and every other event of
-- `app.advance_lead`. BOOK-10 (`booking_issued`) and PAY-3 (`payment_recorded`) are their own contracts.

create or replace function app.emit_booking_created()
returns trigger
language plpgsql
security definer
set search_path to ''
as $fn$
begin
    perform app.record_event(
        new.tenant_id, 'booking_created', 'booking', new.id, app.current_user_id(),
        null, new.booking_status_code, null,
        jsonb_build_object('lead_id', new.lead_id, 'customer_id', new.customer_id,
                           'booking_reference', new.booking_reference, 'quotation_id', new.quotation_id),
        'info');
    return null;
end;
$fn$;

revoke execute on function app.emit_booking_created() from public;

create trigger bookings_emit_created
    after insert on public.bookings
    for each row execute function app.emit_booking_created();

create or replace function app.emit_lead_qualified()
returns trigger
language plpgsql
security definer
set search_path to ''
as $fn$
declare
    v_reason text := nullif(current_setting('app.transition_reason', true), '');
begin
    perform app.record_event(
        new.tenant_id, 'lead_qualified', 'lead', new.id, app.current_user_id(),
        old.lead_status_code, new.lead_status_code, v_reason, null, 'info');
    -- Consumed: a later qualification in the same transaction carries only its own reason.
    perform set_config('app.transition_reason', '', true);
    return null;
end;
$fn$;

revoke execute on function app.emit_lead_qualified() from public;

create trigger leads_emit_qualified
    after update of lead_status_code on public.leads
    for each row
    when (new.lead_status_code = 'qualified' and old.lead_status_code is distinct from 'qualified')
    execute function app.emit_lead_qualified();

CREATE OR REPLACE FUNCTION app.create_booking(p_customer_id uuid DEFAULT NULL::uuid, p_lead_id uuid DEFAULT NULL::uuid, p_title text DEFAULT NULL::text, p_branch_id uuid DEFAULT NULL::uuid, p_department_id uuid DEFAULT NULL::uuid, p_travel_start_date date DEFAULT NULL::date, p_travel_end_date date DEFAULT NULL::date, p_destination_country_code text DEFAULT NULL::text, p_destination_city text DEFAULT NULL::text, p_booking_reference text DEFAULT NULL::text, p_quotation_id uuid DEFAULT NULL::uuid)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_customer uuid;
    v_branch uuid;
    v_department uuid;
    v_title text;
    v_ref text;
    v_booking uuid;
    v_rc record;
    v_quote record;
    -- Scalar mirror of v_quote.customer_id. NULL when no quotation was supplied, which is what makes
    -- the two references below safe; see this migration's header.
    v_quote_customer uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('CREATE_BOOKING');

    -- ADDITIVE (quotation workflow): an accepted quotation may anchor the booking.
    if p_quotation_id is not null then
        select * into v_quote from public.quotations
        where id = p_quotation_id and tenant_id = v_tenant;
        if not found then
            raise exception 'quotation is not in your tenant';
        end if;
        if v_quote.quotation_status_code <> 'accepted' then
            raise exception 'only an accepted quotation can produce a booking (status: %)',
                v_quote.quotation_status_code;
        end if;
        v_quote_customer := v_quote.customer_id;
    end if;

    if p_lead_id is not null then
        -- Consume the handoff contract (single source of booking-eligibility). Do not re-derive.
        select * into v_rc from app.lead_booking_readiness(p_lead_id);
        if not v_rc.is_ready then
            raise exception 'lead is not booking-ready: %', v_rc.reason_code;
        end if;
        v_customer   := v_rc.customer_id;
        v_branch     := coalesce(p_branch_id, v_rc.branch_id);
        v_department := coalesce(p_department_id, v_rc.department_id);
        v_title      := coalesce(p_title, v_rc.title);
    else
        -- ADDITIVE: the quotation can supply the customer on the direct path.
        v_customer   := coalesce(p_customer_id, v_quote_customer);
        v_branch     := p_branch_id;
        v_department := p_department_id;
        v_title      := p_title;
        if v_customer is null then
            raise exception 'a customer is required to create a booking';
        end if;
    end if;

    -- ADDITIVE: whichever path resolved the customer, it must match the quotation's customer.
    if p_quotation_id is not null and v_customer <> v_quote_customer then
        raise exception 'customer does not match the quotation customer';
    end if;

    if v_branch is null or v_department is null then
        raise exception 'branch and department are required';
    end if;
    if v_title is null then
        raise exception 'a booking title is required';
    end if;

    -- Customer, and department-within-branch-within-tenant, must all be in the caller's tenant.
    if not exists (
        select 1 from public.customers where id = v_customer and tenant_id = v_tenant
    ) then
        raise exception 'customer is not in your tenant';
    end if;
    if not exists (
        select 1 from public.departments d
        where d.id = v_department and d.branch_id = v_branch and d.tenant_id = v_tenant
    ) then
        raise exception 'department does not belong to branch in your tenant';
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    -- Human-readable reference (no uniqueness constraint in the schema; make it practically unique).
    v_ref := coalesce(
        p_booking_reference,
        'BK-' || to_char(now(), 'YYYYMMDD') || '-' || upper(left(replace(gen_random_uuid()::text, '-', ''), 8))
    );

    insert into public.bookings (
        tenant_id, branch_id, department_id, owner_user_id, owner_department_id, owner_branch_id,
        lead_id, quotation_id, customer_id, booking_status_code, title, booking_reference,
        travel_start_date, travel_end_date, destination_country_code, destination_city, created_by
    )
    values (
        v_tenant, v_branch, v_department, v_actor, v_department, v_branch,
        p_lead_id, p_quotation_id, v_customer, 'draft', v_title, v_ref,
        p_travel_start_date, p_travel_end_date, p_destination_country_code, p_destination_city, v_actor
    )
    returning id into v_booking;

    -- CONV-8: `booking_created` is produced by `bookings_emit_created` on every door, from this row.
    return v_booking;
end;
$function$;

CREATE OR REPLACE FUNCTION app.advance_lead(p_lead_id uuid, p_to_status text, p_reason text DEFAULT NULL::text, p_closure_reason_code text DEFAULT NULL::text)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_assigned uuid;
    v_status text;
    v_event text;
    v_is_closure boolean;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    select assigned_user_id, lead_status_code
      into v_assigned, v_status
    from public.leads
    where id = p_lead_id and tenant_id = v_tenant;
    if not found then
        raise exception 'lead is not in your tenant';
    end if;

    -- Canonical allowed transitions (26_state_machines Lead State Machine), excluding
    -- new->assigned / assigned->contacted / assigned->assigned (owned by other RPCs),
    -- won->converted (deferred: customer link) and terminal reopening (deferred).
    select t.ev, t.is_closure
      into v_event, v_is_closure
    from (values
        ('new',           'spam',          'lead_marked_spam',         true),
        ('new',           'duplicate',     'lead_marked_duplicate',    true),
        ('assigned',      'lost',          'lead_lost',                true),
        ('assigned',      'duplicate',     'lead_marked_duplicate',    true),
        ('contacted',     'qualified',     'lead_qualified',           false),
        ('contacted',     'lost',          'lead_lost',                true),
        ('contacted',     'spam',          'lead_marked_spam',         true),
        ('qualified',     'quotation_sent','lead_quotation_sent',      false),
        ('qualified',     'won',           'lead_won',                 false),
        ('qualified',     'lost',          'lead_lost',                true),
        ('quotation_sent','negotiation',   'lead_negotiation_started', false),
        ('quotation_sent','won',           'lead_won',                 false),
        ('quotation_sent','lost',          'lead_lost',                true),
        ('negotiation',   'won',           'lead_won',                 false),
        ('negotiation',   'lost',          'lead_lost',                true)
    ) as t(frm, to_s, ev, is_closure)
    where t.frm = v_status and t.to_s = p_to_status;

    if v_event is null then
        raise exception 'transition not allowed: % -> %', v_status, p_to_status;
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    if v_is_closure then
        perform app.authorize('CLOSE_LEAD');
        if p_closure_reason_code is null then
            raise exception 'closure requires a closure_reason_code';
        end if;
        if not exists (
            select 1 from public.catalog_values
            where catalog_type_code = 'lead_closure_reason' and code = p_closure_reason_code
        ) then
            raise exception 'unknown lead_closure_reason: %', p_closure_reason_code;
        end if;
    else
        if not (v_actor is not null and v_actor = v_assigned)
           and not app.has_permission('ASSIGN_LEAD') then
            raise exception 'permission denied: not the assigned handler and lacks ASSIGN_LEAD'
                using errcode = '42501';
        end if;
        if not app.mfa_satisfied() then
            raise exception 'multi-factor authentication required for this role' using errcode = '42501';
        end if;
    end if;

    -- CONV-8: `lead_qualified` is produced by `leads_emit_qualified` on every door; this RPC only
    -- hands it the caller's reason for the transaction's next qualification.
    if v_event = 'lead_qualified' then
        perform set_config('app.transition_reason', coalesce(p_reason, ''), true);
    end if;

    update public.leads
    set lead_status_code = p_to_status,
        closure_reason_code = case when v_is_closure then p_closure_reason_code else closure_reason_code end,
        closed_at = case when v_is_closure then now() else closed_at end,
        updated_at = now()
    where id = p_lead_id;

    if v_event <> 'lead_qualified' then
    perform app.record_event(
        v_tenant, v_event, 'lead', p_lead_id, v_actor, v_status, p_to_status, p_reason,
        case when v_is_closure
             then jsonb_build_object('closure_reason_code', p_closure_reason_code)
             else null end,
        case when v_is_closure then 'warning' else 'info' end
    );
    end if;

    return p_to_status;
end;
$function$;
