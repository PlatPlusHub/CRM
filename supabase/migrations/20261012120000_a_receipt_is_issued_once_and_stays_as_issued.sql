-- Batch 6 Slice 41 -- receipts. RCPT-1, RCPT-2, RCPT-3 and RCPT-4.
--
-- A receipt is proof that money was received (canon 24: it links a customer payment). It carries
-- the number the tenant's receipt sequence gave it and the moment it was issued, and canon 25
-- tracks its external tax submission. `app.issue_receipt` wrote all of that correctly by
-- construction; the table door, which `authenticated` may INSERT and UPDATE, guaranteed none of it.
--
-- MEASURED at `f6c30d0` on the local stack, in rolled-back transactions:
--   * RCPT-1. An `employee` holding neither CREATE_RECEIPT nor VIEW_FINANCIAL_DOCUMENTS, who sees
--     the receipt only because its payment is on a booking they own, renumbered an issued receipt
--     to FAKE-0001, backdated it two years, wrote an external submission id, and moved it from
--     its 600 payment onto a 900 payment of the same booking -- every UPDATE landed, and none left
--     an event. `app.guard_financial_capability` compares only `external_submission_status_code`
--     on a receipt UPDATE. The `receipt_issued` event still named the 600 payment.
--   * RCPT-2. `app.issue_receipt` issued a receipt -- proof of money RECEIVED -- for an outbound
--     supplier payment. Nothing reads the payment's direction.
--   * RCPT-3. An owner holding CREATE_RECEIPT inserted a receipt at the table door numbered
--     `RCP-<year>-X1`, issued 400 days ago, and no `receipt_issued` event was written: the number,
--     the date and the evidence are all the caller's.
--   * RCPT-4. After that one row, `app.issue_receipt` failed for the whole tenant for the rest of
--     the year ("invalid input syntax for type integer"), because it parses every `RCP-<year>-%`
--     number it finds. One malformed door number stops every receipt.
--
-- THE INVARIANT: a receipt is issued only for a customer payment; its number comes from the
-- tenant's sequence under the sequence's lock and its issue time from the server, on every door;
-- it is born unsubmitted; once issued, its payment, number, issue time and origin never change;
-- its tax-submission fields change only with CREATE_RECEIPT; and every receipt is born with its
-- `receipt_issued` event (canon 27, canon 30: financial actions are never overwritten silently;
-- there is no DELETE grant).
--
-- NO session-less exemption for the integrity rules: this is integrity, not authorization (FIN-8,
-- FIN-10 and PAY-6's distinction), and a system write is recorded as one (a NULL actor). The
-- capability check keeps canon 35 principle 6's platform path, as every guard here does. The
-- functions are SECURITY DEFINER for BOOK-1's reason -- under INVOKER the payment read would be
-- RLS-filtered.
-- NOT CHANGED: every grant, policy, permission, `app.guard_financial_capability`, the catalog and
-- subscription gates, the unique keys on (tenant, number) and (tenant, payment), and the event
-- visibility rule.

-- ------------------------------------------------------------------------------------------------
-- 1. The row. Issued for a customer payment, numbered and timed by the server, fixed once issued.
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_receipt_issue()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_direction text;
    v_year text;
    v_seq bigint;
begin
    if tg_op = 'UPDATE' then
        if new.id             is distinct from old.id
        or new.tenant_id      is distinct from old.tenant_id
        or new.payment_id     is distinct from old.payment_id
        or new.receipt_number is distinct from old.receipt_number
        or new.issued_at      is distinct from old.issued_at
        or new.created_by     is distinct from old.created_by
        or new.created_at     is distinct from old.created_at then
            raise exception
                'receipt %: its payment, number, issue time and origin are fixed when it is issued',
                old.id using errcode = '23514';
        end if;
        -- The tax-submission record is the one part of a receipt that changes after issue. Its
        -- status is already charged by app.guard_financial_capability; the id and times beside it
        -- are the same record and need the same capability.
        if (new.external_submission_id   is distinct from old.external_submission_id
         or new.external_submitted_at    is distinct from old.external_submitted_at
         or new.external_response_at     is distinct from old.external_response_at)
           and (select auth.uid()) is not null then
            perform app.authorize('CREATE_RECEIPT');
        end if;
        return new;
    end if;

    -- The composite foreign key is the authority on the payment's existence in this tenant; the
    -- lookup is for its DIRECTION, which no key can supply.
    select p.payment_direction_code into v_direction
    from public.payments p
    where p.id = new.payment_id and p.tenant_id = new.tenant_id;
    if not found then
        return new;
    end if;
    if v_direction is distinct from 'customer_payment' then
        raise exception
            'a receipt is proof that money was received: payment % is a %, not a customer payment',
            new.payment_id, v_direction using errcode = '23514';
    end if;

    new.issued_at := now();
    new.external_submission_id := null;
    new.external_submission_status_code := null;
    new.external_submitted_at := null;
    new.external_response_at := null;

    -- Per-(tenant, year) sequence, under the key app.issue_receipt has always taken; gaps are
    -- acceptable, collisions are not (the unique key on (tenant_id, receipt_number) stays). Only
    -- numbers of exactly this shape are read, so no stored text can stop the sequence.
    v_year := to_char(new.issued_at, 'YYYY');
    perform pg_advisory_xact_lock(hashtextextended(new.tenant_id::text || ':RCP:' || v_year, 0));
    select coalesce(max(substring(r.receipt_number from '^RCP-[0-9]{4}-([0-9]+)$')::bigint), 0) + 1
      into v_seq
    from public.receipts r
    where r.tenant_id = new.tenant_id
      and r.receipt_number like 'RCP-' || v_year || '-%';
    new.receipt_number := 'RCP-' || v_year || '-' || lpad(v_seq::text, 4, '0');
    return new;
end
$fn$;

comment on function app.guard_receipt_issue() is
    'RCPT-1..4: a receipt is issued only for a customer payment; its number (the tenant''s per-year sequence, under its lock) and issue time are derived on every door, never accepted; it is born unsubmitted; once issued its payment, number, issue time and origin are fixed; its tax-submission id and times change only with CREATE_RECEIPT. No session-less exemption for integrity.';

revoke all on function app.guard_receipt_issue() from public;

create trigger receipts_guard_issue
    before insert or update on public.receipts
    for each row execute function app.guard_receipt_issue();

-- ------------------------------------------------------------------------------------------------
-- 2. The evidence. One producer of receipt_issued, on every door.
-- ------------------------------------------------------------------------------------------------
create or replace function app.emit_receipt_issued()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_pay record;
begin
    select p.customer_id, p.currency_code, p.amount into v_pay
    from public.payments p
    where p.id = new.payment_id and p.tenant_id = new.tenant_id;

    perform app.record_event(
        new.tenant_id, 'receipt_issued', 'receipt', new.id,
        null,                -- actor: record_event derives it authoritatively (WP-00)
        null, 'issued', null,
        jsonb_build_object('receipt_number', new.receipt_number, 'payment_id', new.payment_id,
                           'customer_id', v_pay.customer_id, 'currency_code', v_pay.currency_code,
                           'amount', v_pay.amount),
        'info'
    );
    return null;
end
$fn$;

comment on function app.emit_receipt_issued() is
    'RCPT-3: the single producer of receipt_issued, with the number, payment, customer, currency and amount. Actor and time come from app.record_event.';

revoke all on function app.emit_receipt_issued() from public;

create trigger receipts_emit_issued
    after insert on public.receipts
    for each row execute function app.emit_receipt_issued();

-- ------------------------------------------------------------------------------------------------
-- 3. The RPC. Its checks and refusals are unchanged; the number, the time and the event now come
--    from the row's own triggers, so the RPC and the door can no longer disagree.
-- ------------------------------------------------------------------------------------------------
create or replace function app.issue_receipt(p_payment_id uuid)
returns uuid
language plpgsql
set search_path = ''
as $function$
declare
    v_tenant uuid := app.current_tenant_id();
    v_receipt_id uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    perform 1 from public.payments
    where id = p_payment_id and tenant_id = v_tenant;
    if not found then
        raise exception 'payment is not in your tenant';
    end if;

    if exists (select 1 from public.receipts
               where payment_id = p_payment_id and tenant_id = v_tenant) then
        raise exception 'a receipt already exists for this payment';
    end if;

    perform app.authorize('CREATE_RECEIPT');

    -- receipt_number is NOT NULL and is assigned by receipts_guard_issue, a BEFORE trigger, so it
    -- is named by nobody here.
    insert into public.receipts (tenant_id, payment_id)
    values (v_tenant, p_payment_id)
    returning id into v_receipt_id;

    return v_receipt_id;
end;
$function$;
