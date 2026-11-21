-- B6-EXIT bundle B: a refund's life, a conversation's life and an invoice's settlement are produced by
-- the table, so the table door records them exactly as the RPC door does.
--
-- `authenticated` holds table-level INSERT and UPDATE on `public.refunds`, `public.conversations` and
-- `public.payment_allocations`, and `app.record_refund`, `app.advance_refund`,
-- `app.advance_conversation` and `app.record_payment` are SECURITY INVOKER through those same grants,
-- so PostgREST serves each table beside its RPC. Measured at `7c5975a` on the local stack in
-- rolled-back transactions (Workbench data/records/batch6/exit-bundle-b/repro-7c5975a.sql):
--   * RFD-3: an aal2 finance_manager inserted a refund `requested`, then moved it `approved` and
--     `completed` at the table: 0 events. The RPC door recorded refund_requested, refund_approved and
--     refund_completed (warning) with their reasons. `completed_at` is already server-stamped on both
--     doors by `app.guard_refund_integrity`.
--   * CHAT-2: an employee moved a conversation `open -> assigned -> closed -> open` at the table: no
--     transition event (only conversation_started), `closed_at` left null after the close, and the
--     reopen accepted with no reason. The RPC recorded assigned, closed and reopened, all at `info`,
--     where canon 26 and 27 require a reopen reason and make `conversation_escalated` and
--     `conversation_reopened` warnings. The employee's direct escalate was already refused 42501 by
--     the per-edge transition guard: authority needs no change.
--   * PAY-5 / FIN-11: an aal2 owner inserted a 5000 payment and a 5000 allocation against a 5000
--     invoice: the invoice stayed `issued`, 0 invoice events, and `payment_recorded` reported
--     `invoice_new_status` `issued`. `app.record_payment` alone derived `paid` and emitted
--     invoice_paid, so the settlement belonged to one door instead of the table.
--
-- THE SHAPE is SPEC-262's (`20261011090000`): SECURITY INVOKER guard and producers; one AFTER producer
-- per event, and its RPC loses its own `record_event`, so no act is recorded twice; the RPC's reason
-- reaches the guard and the producer through SPEC-237's transaction-local `app.transition_reason`
-- (`20260928160000`), which the producer consumes. The conversation guard is signed-in only (canon 35
-- principle 6): it stamps `closed_at` as the RPC does and refuses a reopen without a reason. The
-- settlement producer is record_payment's own derivation moved onto `payment_allocations`: under the
-- same per-invoice advisory lock it sums the allocations, sets `paid` / `partially_paid` and emits
-- invoice_paid / invoice_partially_paid with the same payload. Its invoice UPDATE runs as the caller,
-- exactly as record_payment's did, so `app.enforce_status_transition` still charges RECORD_PAYMENT and
-- `app.guard_financial_capability` still prices it. A raised allocation re-derives forward; nothing
-- walks a settled invoice back (no such edge exists). The trigger sorts after
-- `payment_allocations_emit_created`, so the allocation is recorded before the settlement it causes.
--
-- NOT CHANGED: every grant, policy, permission charge, state transition and other trigger; the
-- reasons and payloads each event already carried; the refund severities (completed stays warning);
-- record_payment's validations, lock, outstanding check and inserts.

-- ===================================================================== RFD-3 refunds
create or replace function app.emit_refund_requested()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    perform app.record_event(
        new.tenant_id, 'refund_requested', 'refund', new.id,
        case when (select auth.uid()) is null then null else app.current_user_id() end,
        null, new.refund_status_code, new.refund_reason_code,
        jsonb_build_object('customer_id', new.customer_id, 'booking_id', new.booking_id,
                           'amount', new.amount, 'currency_code', new.currency_code),
        'info');
    return null;
end;
$$;
revoke execute on function app.emit_refund_requested() from public;

create trigger refunds_emit_requested
after insert on public.refunds
for each row execute function app.emit_refund_requested();

create or replace function app.emit_refund_transition()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_reason text := nullif(current_setting('app.transition_reason', true), '');
    v_event text;
begin
    -- Consumed: a later transition in the same transaction carries only its own reason.
    perform set_config('app.transition_reason', '', true);
    v_event := case new.refund_status_code
        when 'approved' then 'refund_approved'
        when 'rejected' then 'refund_rejected'
        when 'cancelled' then 'refund_cancelled'
        when 'processing' then 'refund_processing'
        when 'completed' then 'refund_completed'
    end;
    if v_event is null then
        return null;
    end if;
    perform app.record_event(
        new.tenant_id, v_event, 'refund', new.id,
        case when (select auth.uid()) is null then null else app.current_user_id() end,
        old.refund_status_code, new.refund_status_code, v_reason,
        jsonb_build_object('customer_id', new.customer_id, 'amount', new.amount,
                           'currency_code', new.currency_code),
        case when new.refund_status_code = 'completed' then 'warning' else 'info' end);
    return null;
end;
$$;
revoke execute on function app.emit_refund_transition() from public;

create trigger refunds_emit_transition
after update of refund_status_code on public.refunds
for each row
when (new.refund_status_code is distinct from old.refund_status_code)
execute function app.emit_refund_transition();

-- The complete current SECURITY INVOKER RPC, removing only its event call.
create or replace function app.record_refund(
    p_customer_id uuid,
    p_amount numeric,
    p_currency_code text,
    p_refund_reason_code text,
    p_booking_id uuid default null,
    p_original_payment_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_refund_id uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    if p_amount is null or p_amount <= 0 then
        raise exception 'refund amount must be greater than zero';
    end if;
    if not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'refund_reason_code' and code = p_refund_reason_code
    ) then
        raise exception 'unknown refund_reason: %', p_refund_reason_code;
    end if;

    perform 1 from public.customers where id = p_customer_id and tenant_id = v_tenant;
    if not found then
        raise exception 'customer is not in your tenant';
    end if;
    if p_booking_id is not null then
        perform 1 from public.bookings where id = p_booking_id and tenant_id = v_tenant;
        if not found then
            raise exception 'booking is not in your tenant';
        end if;
    end if;
    if p_original_payment_id is not null then
        perform 1 from public.payments where id = p_original_payment_id and tenant_id = v_tenant;
        if not found then
            raise exception 'original payment is not in your tenant';
        end if;
    end if;

    perform app.authorize('RECORD_REFUND');

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    -- RFD-3: `refund_requested` is produced by `refunds_emit_requested` on every door.
    insert into public.refunds (
        tenant_id, payment_direction_code, original_payment_id, customer_id, booking_id,
        refund_reason_code, currency_code, amount, refund_status_code, requested_at, created_by
    ) values (
        v_tenant, 'customer_refund', p_original_payment_id, p_customer_id, p_booking_id,
        p_refund_reason_code, p_currency_code, p_amount, 'requested', now(), v_actor
    ) returning id into v_refund_id;

    return v_refund_id;
end;
$$;

-- The complete current SECURITY INVOKER RPC, removing only its event call; its reason reaches
-- `refunds_emit_transition` through `app.transition_reason`.
create or replace function app.advance_refund(
    p_refund_id uuid,
    p_to_status text,
    p_reason text default null
)
returns text
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_rf record;
    v_event text;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    select id, refund_status_code, customer_id, amount, currency_code
      into v_rf
    from public.refunds
    where id = p_refund_id and tenant_id = v_tenant;
    if not found then
        raise exception 'refund is not in your tenant';
    end if;

    select t.ev into v_event
    from (values
        ('requested',  'approved',   'refund_approved'),
        ('requested',  'rejected',   'refund_rejected'),
        ('requested',  'cancelled',  'refund_cancelled'),
        ('approved',   'processing', 'refund_processing'),
        ('approved',   'completed',  'refund_completed'),
        ('approved',   'cancelled',  'refund_cancelled'),
        ('processing', 'completed',  'refund_completed'),
        ('processing', 'cancelled',  'refund_cancelled')
    ) as t(frm, to_s, ev)
    where t.frm = v_rf.refund_status_code and t.to_s = p_to_status;

    if v_event is null then
        raise exception 'refund transition not allowed: % -> %', v_rf.refund_status_code, p_to_status;
    end if;

    perform app.authorize('RECORD_REFUND');

    perform set_config('app.transition_reason', coalesce(p_reason, ''), true);
    update public.refunds
    set refund_status_code = p_to_status,
        completed_at = case when p_to_status = 'completed' then now() else completed_at end,
        updated_at = now()
    where id = p_refund_id;

    return p_to_status;
end;
$$;

-- ===================================================================== CHAT-2 conversations
create or replace function app.guard_conversation_transition()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_reason text;
    v_entered boolean;
begin
    -- Session-less platform writes keep their latitude (canon 35 principle 6).
    if (select auth.uid()) is null then
        return new;
    end if;
    v_entered := new.conversation_status_code is distinct from old.conversation_status_code;
    if v_entered and old.conversation_status_code = 'closed' and new.conversation_status_code = 'open' then
        v_reason := nullif(btrim(current_setting('app.transition_reason', true)), '');
        if v_reason is null then
            raise exception 'a closed conversation is reopened with a reason (canon 26, 27); use app.advance_conversation with p_reason'
                using errcode = '23514';
        end if;
    end if;
    -- The server stamps closed_at, as app.advance_conversation does.
    new.closed_at := case
        when v_entered and new.conversation_status_code = 'closed' then now()
        when v_entered and new.conversation_status_code = 'open' then null
        else old.closed_at
    end;
    return new;
end;
$$;
revoke execute on function app.guard_conversation_transition() from public;

create trigger conversations_guard_transition
before update on public.conversations
for each row execute function app.guard_conversation_transition();

create or replace function app.emit_conversation_transition()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_reason text := nullif(current_setting('app.transition_reason', true), '');
    v_reopen boolean := old.conversation_status_code = 'closed'
                        and new.conversation_status_code = 'open';
    v_event text;
begin
    -- Consumed: a later transition in the same transaction carries only its own reason.
    perform set_config('app.transition_reason', '', true);
    v_event := case
        when v_reopen then 'conversation_reopened'
        else case new.conversation_status_code
            when 'assigned' then 'conversation_assigned'
            when 'escalated' then 'conversation_escalated'
            when 'closed' then 'conversation_closed'
        end
    end;
    -- 26_state_machines.md: the pending_* moves require no event.
    if v_event is null then
        return null;
    end if;
    perform app.record_event(
        new.tenant_id, v_event, 'conversation', new.id,
        case when (select auth.uid()) is null then null else app.current_user_id() end,
        old.conversation_status_code, new.conversation_status_code, v_reason, null,
        case when v_reopen or new.conversation_status_code = 'escalated' then 'warning' else 'info' end);
    return null;
end;
$$;
revoke execute on function app.emit_conversation_transition() from public;

create trigger conversations_emit_transition
after update of conversation_status_code on public.conversations
for each row
when (new.conversation_status_code is distinct from old.conversation_status_code)
execute function app.emit_conversation_transition();

-- The complete current SECURITY INVOKER RPC, removing only its event call; its reason reaches the
-- guard and `conversations_emit_transition` through `app.transition_reason`.
create or replace function app.advance_conversation(
    p_conversation_id uuid,
    p_to_status text,
    p_reason text default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_status text;
    v_event text;
    v_perm text;
    v_matched boolean := false;
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;

    select conversation_status_code into v_status
    from public.conversations where id = p_conversation_id and tenant_id = v_tenant;
    if v_status is null then raise exception 'conversation not found in your tenant'; end if;

    -- 26_state_machines.md, Conversation State Machine. ev is null where canon requires no event.
    select true, t.ev, t.perm into v_matched, v_event, v_perm
    from (values
        ('open',             'assigned',         'conversation_assigned',  'SEND_MESSAGE'),
        ('assigned',         'pending_customer',  null,                    'SEND_MESSAGE'),
        ('assigned',         'pending_internal',  null,                    'SEND_MESSAGE'),
        ('pending_customer', 'assigned',         'conversation_assigned',  'SEND_MESSAGE'),
        ('pending_internal', 'assigned',         'conversation_assigned',  'SEND_MESSAGE'),
        ('assigned',         'escalated',        'conversation_escalated', 'ESCALATE_CONVERSATION'),
        ('escalated',        'assigned',         'conversation_assigned',  'ESCALATE_CONVERSATION'),
        ('assigned',         'closed',           'conversation_closed',    'CLOSE_CONVERSATION'),
        ('pending_customer', 'closed',           'conversation_closed',    'CLOSE_CONVERSATION'),
        ('escalated',        'closed',           'conversation_closed',    'CLOSE_CONVERSATION'),
        ('closed',           'open',             'conversation_reopened',  'CLOSE_CONVERSATION')
    ) as t(frm, to_s, ev, perm)
    where t.frm = v_status and t.to_s = p_to_status;

    if not v_matched then
        raise exception 'invalid conversation transition % -> %', v_status, p_to_status; end if;
    perform app.authorize(v_perm);

    perform set_config('app.transition_reason', coalesce(p_reason, ''), true);
    update public.conversations
    set conversation_status_code = p_to_status,
        closed_at = case when p_to_status = 'closed' then now()
                         when p_to_status = 'open' then null else closed_at end,
        updated_at = now()
    where id = p_conversation_id and tenant_id = v_tenant;
end;
$$;

-- ===================================================================== PAY-5 / FIN-11 settlement
create or replace function app.derive_invoice_payment_status()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_inv record;
    v_total numeric;
    v_new text;
begin
    -- Forward only: a raised allocation re-derives; a lowered one never walks a settlement back.
    if tg_op = 'UPDATE' and coalesce(new.allocated_amount_invoice_currency, new.allocated_amount)
                            <= coalesce(old.allocated_amount_invoice_currency, old.allocated_amount) then
        return null;
    end if;
    -- A zero allocation settles nothing: it moves no status and records no settlement.
    if tg_op = 'INSERT' and coalesce(new.allocated_amount_invoice_currency, new.allocated_amount) <= 0 then
        return null;
    end if;

    -- record_payment's own serialisation: concurrent allocations to one invoice settle in turn.
    perform pg_advisory_xact_lock(hashtextextended(new.invoice_id::text, 0));

    select id, status_code, total_amount into v_inv
    from public.invoices
    where id = new.invoice_id and tenant_id = new.tenant_id;
    if not found or v_inv.status_code not in ('issued', 'partially_paid', 'overdue') then
        return null;
    end if;

    select coalesce(sum(coalesce(pa.allocated_amount_invoice_currency, pa.allocated_amount)), 0)
      into v_total
    from public.payment_allocations pa
    where pa.invoice_id = new.invoice_id and pa.tenant_id = new.tenant_id;

    v_new := case when v_total >= v_inv.total_amount then 'paid' else 'partially_paid' end;

    update public.invoices
    set status_code = v_new,
        updated_at = now()
    where id = new.invoice_id and tenant_id = new.tenant_id;
    if not found then
        -- Fail closed: an allocation never stands beside an invoice its writer could not settle.
        raise exception 'invoice % could not be settled by this caller', new.invoice_id
            using errcode = '42501';
    end if;

    perform app.record_event(
        new.tenant_id,
        case when v_new = 'paid' then 'invoice_paid' else 'invoice_partially_paid' end,
        'invoice', new.invoice_id,
        case when (select auth.uid()) is null then null else app.current_user_id() end,
        v_inv.status_code, v_new, null,
        jsonb_build_object('payment_id', new.payment_id, 'allocated_total', v_total,
                           'total_amount', v_inv.total_amount),
        'info');
    return null;
end;
$$;
revoke execute on function app.derive_invoice_payment_status() from public;

create trigger payment_allocations_settle_invoice
after insert or update of allocated_amount, allocated_amount_invoice_currency on public.payment_allocations
for each row execute function app.derive_invoice_payment_status();

-- The complete current SECURITY INVOKER RPC, removing only its settlement: the invoice status and its
-- event are produced by `payment_allocations_settle_invoice` from the allocation below.
create or replace function app.record_payment(
    p_invoice_id uuid,
    p_amount numeric,
    p_payment_method_code text,
    p_paid_at timestamptz default now(),
    p_reference_number text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_inv record;
    v_already numeric;
    v_remaining numeric;
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

    select coalesce(sum(coalesce(pa.allocated_amount_invoice_currency, pa.allocated_amount)), 0) into v_already
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

    -- PAY-5 / FIN-11: `payment_allocations_settle_invoice` moves the invoice to partially_paid / paid
    -- and records invoice_partially_paid / invoice_paid on every door.
    insert into public.payment_allocations (
        tenant_id, payment_id, invoice_id, allocated_amount, currency_code, created_by
    ) values (
        v_tenant, v_payment_id, p_invoice_id, p_amount, v_inv.currency_code, v_actor
    );

    -- PAY-3: `payment_recorded` is produced at commit by `payments_emit_recorded` on every door,
    -- from this payment and the allocation above.

    return v_payment_id;
end;
$$;
