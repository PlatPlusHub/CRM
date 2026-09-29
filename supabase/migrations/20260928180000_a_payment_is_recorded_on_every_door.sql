-- Phase-8 Activation Closure: PAY-3 -- a payment is recorded on every door.
--
-- `app.map_outcomes_to_conversions` turns `payment_recorded` into `payment_received`, the one Google
-- Ads conversion that carries revenue, and finds the payment's lead through the booking it names or
-- the invoice its event names (CONV-7). `payment_recorded` and `supplier_payment_recorded` each had
-- one producer, their RPC. `authenticated` holds INSERT on `payments` and `payment_allocations`, and
-- PAY-1, PAY-2 and FIN-10 made that door a governed one (RECORD_PAYMENT, invoice state, ceiling), so
-- the same act done there was silent: MEASURED with a consented Google Ads click on every lead, a
-- customer payment allocated to an issued invoice and one naming its booking produced no event and no
-- conversion, and a supplier payment no event, while the RPCs produced them.
--
-- THE SHAPE is SPEC-215's and SPEC-237's -- one trigger is the single producer and the RPCs lose
-- their own `record_event` -- with one difference, forced by the data: a payment is linked to the
-- invoice it pays by `payment_allocations`, a row that can only be written AFTER the payment (it
-- carries the payment's id). An immediate trigger would therefore record every invoice payment with
-- no invoice, and the mapper could not attribute it. So the trigger is a DEFERRABLE INITIALLY
-- DEFERRED constraint trigger -- FIN-8, FIN-10 and ASGN-5's idiom -- and records the payment at
-- COMMIT, when its allocations exist:
--   * `customer_payment` -> `payment_recorded`, with the RPC's payload keys: `invoice_id` is the one
--     invoice the payment is allocated to (null when it is allocated to none or to several -- the
--     mapper then uses `payments.booking_id`), `invoice_new_status` that invoice's status when the
--     payment is recorded, `amount` and `currency_code` the payment's own;
--   * `supplier_payment` -> `supplier_payment_recorded`, with the RPC's payload keys read from the row.
-- The refund directions have no RPC and no event on this table, and get none here (PAY-4's area).
-- `app.record_event` takes the actor from the session and stamps the time; a deferred trigger runs
-- inside the same transaction, so the actor is the one who wrote the payment. An allocation made in
-- a LATER transaction does not re-record the payment: the event states what the payment was linked
-- to when it was recorded, as every creation event here does.
--
-- NOT CHANGED: every grant, policy, guard, invoice rule, the mapper and the invoice status events of
-- `app.record_payment`. BOOK-10 (`booking_issued`) is its own contract.

create or replace function app.emit_payment_recorded()
returns trigger
language plpgsql
security definer
set search_path to ''
as $fn$
declare
    v_invoices uuid[];
    v_invoice uuid;
    v_status text;
begin
    if new.payment_direction_code = 'supplier_payment' then
        perform app.record_event(
            new.tenant_id, 'supplier_payment_recorded', 'payment', new.id, app.current_user_id(),
            null, 'supplier_payment', new.reference_number,
            jsonb_build_object('supplier_id', new.supplier_id, 'booking_id', new.booking_id,
                               'amount', new.amount, 'currency_code', new.currency_code),
            'info');
        return null;
    end if;

    select array_agg(distinct pa.invoice_id) into v_invoices
    from public.payment_allocations pa
    where pa.payment_id = new.id and pa.tenant_id = new.tenant_id;
    if cardinality(v_invoices) = 1 then
        v_invoice := v_invoices[1];
        select i.status_code into v_status
        from public.invoices i
        where i.id = v_invoice and i.tenant_id = new.tenant_id;
    end if;

    perform app.record_event(
        new.tenant_id, 'payment_recorded', 'payment', new.id, app.current_user_id(),
        null, 'customer_payment', new.reference_number,
        jsonb_build_object('invoice_id', v_invoice, 'amount', new.amount,
                           'currency_code', new.currency_code, 'invoice_new_status', v_status),
        'info');
    return null;
end;
$fn$;

revoke execute on function app.emit_payment_recorded() from public;

create constraint trigger payments_emit_recorded
    after insert on public.payments
    deferrable initially deferred
    for each row
    when (new.payment_direction_code in ('customer_payment', 'supplier_payment'))
    execute function app.emit_payment_recorded();

CREATE OR REPLACE FUNCTION app.record_payment(p_invoice_id uuid, p_amount numeric, p_payment_method_code text, p_paid_at timestamp with time zone DEFAULT now(), p_reference_number text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_inv record;
    v_already numeric;
    v_remaining numeric;
    v_new_total numeric;
    v_new_status text;
    v_payment_id uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    if p_amount is null or p_amount <= 0 then
        raise exception 'payment amount must be greater than zero';
    end if;
    if not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'payment_method' and code = p_payment_method_code
    ) then
        raise exception 'unknown payment_method: %', p_payment_method_code;
    end if;

    select id, customer_id, currency_code, total_amount, status_code, voided_at, is_archived
      into v_inv
    from public.invoices
    where id = p_invoice_id and tenant_id = v_tenant;
    if not found then
        raise exception 'invoice is not in your tenant';
    end if;
    if v_inv.is_archived or v_inv.voided_at is not null then
        raise exception 'invoice is archived or voided';
    end if;
    if v_inv.status_code not in ('issued', 'partially_paid', 'overdue') then
        raise exception 'only an issued/partially_paid/overdue invoice can be paid (is %)', v_inv.status_code;
    end if;

    perform app.authorize('RECORD_PAYMENT');

    -- Serialise allocation for this invoice so concurrent payments cannot over-allocate.
    perform pg_advisory_xact_lock(hashtextextended(p_invoice_id::text, 0));

    select coalesce(sum(pa.allocated_amount), 0) into v_already
    from public.payment_allocations pa
    where pa.invoice_id = p_invoice_id and pa.tenant_id = v_tenant;

    v_remaining := v_inv.total_amount - v_already;
    if p_amount > v_remaining then
        raise exception 'payment % exceeds invoice outstanding % (total %, already allocated %)',
            p_amount, v_remaining, v_inv.total_amount, v_already;
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    insert into public.payments (
        tenant_id, payment_direction_code, customer_id, currency_code,
        payment_method_code, reference_number, amount, paid_at, received_by, created_by
    ) values (
        v_tenant, 'customer_payment', v_inv.customer_id, v_inv.currency_code,
        p_payment_method_code, p_reference_number, p_amount, p_paid_at, v_actor, v_actor
    ) returning id into v_payment_id;

    insert into public.payment_allocations (
        tenant_id, payment_id, invoice_id, allocated_amount, currency_code, created_by
    ) values (
        v_tenant, v_payment_id, p_invoice_id, p_amount, v_inv.currency_code, v_actor
    );

    v_new_total := v_already + p_amount;
    v_new_status := case when v_new_total >= v_inv.total_amount then 'paid' else 'partially_paid' end;

    update public.invoices
    set status_code = v_new_status,
        updated_at = now()
    where id = p_invoice_id;

    -- PAY-3: `payment_recorded` is produced at commit by `payments_emit_recorded` on every door,
    -- from this payment and the allocation above.

    -- Invoice status transition event (issued/overdue/partially_paid -> partially_paid|paid).
    perform app.record_event(
        v_tenant,
        case when v_new_status = 'paid' then 'invoice_paid' else 'invoice_partially_paid' end,
        'invoice', p_invoice_id, v_actor,
        v_inv.status_code, v_new_status, null,
        jsonb_build_object('payment_id', v_payment_id, 'allocated_total', v_new_total,
                           'total_amount', v_inv.total_amount),
        'info'
    );

    return v_payment_id;
end;
$function$;

CREATE OR REPLACE FUNCTION app.record_supplier_payment(p_supplier_id uuid, p_amount numeric, p_currency_code text, p_payment_method_code text, p_booking_id uuid DEFAULT NULL::uuid, p_paid_at timestamp with time zone DEFAULT now(), p_reference_number text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_payment_id uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    if p_amount is null or p_amount <= 0 then
        raise exception 'payment amount must be greater than zero';
    end if;
    if not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'payment_method' and code = p_payment_method_code
    ) then
        raise exception 'unknown payment_method: %', p_payment_method_code;
    end if;

    perform 1 from public.suppliers where id = p_supplier_id and tenant_id = v_tenant;
    if not found then
        raise exception 'supplier is not in your tenant';
    end if;
    if p_booking_id is not null then
        perform 1 from public.bookings where id = p_booking_id and tenant_id = v_tenant;
        if not found then
            raise exception 'booking is not in your tenant';
        end if;
    end if;

    perform app.authorize('RECORD_PAYMENT');

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    insert into public.payments (
        tenant_id, payment_direction_code, supplier_id, booking_id, currency_code,
        payment_method_code, reference_number, amount, paid_at, received_by, created_by
    ) values (
        v_tenant, 'supplier_payment', p_supplier_id, p_booking_id, p_currency_code,
        p_payment_method_code, p_reference_number, p_amount, p_paid_at, v_actor, v_actor
    ) returning id into v_payment_id;

    -- PAY-3: `supplier_payment_recorded` is produced at commit by `payments_emit_recorded` on every
    -- door, from this row.

    return v_payment_id;
end;
$function$;
