-- Batch 6 Slice 40 -- payment_allocations. PAY-6, PAY-7, PAY-8, FIN-12, PAY-10 and PAY-11.
--
-- An allocation is the row that says WHICH invoice a payment settled and HOW MUCH of it. Canon 24
-- and 31: it links one payment to one invoice; one payment may be spread over several invoices and
-- one invoice paid by several payments; its `currency_code` is the currency the payment was made
-- in; `exchange_rate_id` and `allocated_amount_invoice_currency` are present exactly when that
-- currency differs from the invoice's; and the invoice's allocated total, in the invoice's
-- currency, may not exceed what the invoice is worth. `app.record_payment` writes all of that
-- correctly by construction -- it creates the payment and its allocation together, from the
-- invoice -- and the table door, which canon makes the only way to split one payment over several
-- invoices, guaranteed none of it.
--
-- MEASURED at `1d25f40` on the local stack, in rolled-back transactions:
--   * PAY-6. An `employee` holding neither RECORD_PAYMENT nor VIEW_FINANCIAL_DOCUMENTS, who sees
--     no payment at all and sees the allocation only because the invoice is on a booking they own,
--     moved a 600 EGP allocation from customer C1's invoice to customer C2's, then to a DRAFT
--     invoice, then onto a supplier payment, and rewrote its currency to USD -- every UPDATE
--     landed. `app.guard_financial_capability` compares only `allocated_amount` on UPDATE, and
--     PAY-1's invoice-state rule fires on INSERT only, so a RECORD_PAYMENT holder could also move a
--     paid allocation onto a draft invoice. Consequence, measured: with C1's 600 moved to C2, the
--     owner's `app.record_payment` took another 1000 from C1 for a 1000 invoice (C1 now 600 in
--     credit), refused C2's genuine 1000 ("exceeds invoice outstanding 400"), and then marked C2's
--     invoice `paid` on 400 of C2's money.
--   * PAY-7. An owner holding RECORD_PAYMENT, at the table door: a 600 payment was allocated 1600;
--     a supplier payment settled a customer invoice; an allocation claimed USD from an EGP payment.
--     Nothing ties an allocation to its own payment.
--   * PAY-8. A 100 USD payment allocated to an EGP invoice with no rate was counted as 100 EGP by
--     the ceiling and by `app.record_payment`. FA-2 (owner decision 2026-09-09) is that a currency
--     difference is never silent.
--   * FIN-12. Two sessions each allocated 600 to the same 1000 invoice at the door; each passed
--     FIN-10's ceiling and both committed: 1200 against 1000. `app.record_payment` serialises on
--     `pg_advisory_xact_lock(hashtextextended(invoice_id::text, 0))`; the ceiling took no lock, so
--     a door allocation raced both the RPC and other door allocations.
--
--   * PAY-10. Setting an allocation from 600 to 0 wrote that row and nothing else -- no event, no
--     other table (pg_stat_xact_user_tables) -- so the 600, who removed it and when were gone; and
--     `payment_allocation_created` carried none of the invoice, payment and amount canon 27 requires.
--   * PAY-11. Zeroing the allocation that had paid a 1000 invoice in full left the invoice `paid`
--     with 0 allocated. `app.record_payment` then refused it ("is paid"), a door allocation to it was
--     refused, and paid -> issued and paid -> voided were both refused: canon 26 gives `paid` no
--     exit, and canon 26/31 derive that status from these rows. The invoice was lost to collection.
--
-- THE INVARIANT: an allocation spends its own customer payment, in that payment's currency, on an
-- invoice of the payment's own customer; it never makes the payment settle more than it is, or the
-- invoice receive more than it is worth in the invoice's own currency, or less than its recorded
-- status says it received; a currency difference carries its exchange rate; once written, the
-- allocation stays where it was put -- only its amount can be corrected, by RECORD_PAYMENT as
-- before -- and every amount it is born with or corrected to is an event (canon 30: do not
-- overwrite financial actions silently; there is no DELETE grant).
--
-- NO session-less exemption anywhere here: this is integrity, not authorization (FIN-8, FIN-10 and
-- FA-2's distinction), and a system write is recorded as one (a NULL actor). The functions are
-- SECURITY DEFINER for BOOK-1's reason -- under INVOKER their reads would be RLS-filtered, blindest
-- against exactly the caller they must stop.
-- NOT CHANGED: every grant, policy, permission, the capability guard, PAY-1's invoice-state rule,
-- the event visibility rule (`payment_allocation` is already its own branch of `audit_read`) and
-- the invoice status `app.record_payment` derives -- nothing here moves a status (PAY-5 and FIN-11
-- stay open; FIN-7 owns status derivation on the door).

-- ------------------------------------------------------------------------------------------------
-- 1. The row. Fixed once written; its conversion evidence is judged against the invoice's currency
--    in FA-2's exact shape, and the invoice-currency amount is derived, never accepted.
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_payment_allocation_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_invoice_currency text;
    v_rate numeric;
    v_from text;
    v_to   text;
begin
    if tg_op = 'UPDATE' then
        if new.id               is distinct from old.id
        or new.tenant_id        is distinct from old.tenant_id
        or new.payment_id       is distinct from old.payment_id
        or new.invoice_id       is distinct from old.invoice_id
        or new.currency_code    is distinct from old.currency_code
        or new.exchange_rate_id is distinct from old.exchange_rate_id
        or new.created_by       is distinct from old.created_by
        or new.created_at       is distinct from old.created_at then
            raise exception
                'payment allocation %: its payment, invoice, currency, rate and origin are fixed when it is written; only its amount can be corrected',
                old.id using errcode = '23514';
        end if;
        -- An UPDATE that leaves the amount alone changes no money: the derived amount stays the one
        -- it was written with, even if its exchange_rates row has been edited since.
        if new.allocated_amount is not distinct from old.allocated_amount then
            new.allocated_amount_invoice_currency := old.allocated_amount_invoice_currency;
            return new;
        end if;
    end if;

    -- The composite foreign key is the authority on the invoice's existence in this tenant; the
    -- lookup is for its DENOMINATION, which no key can supply.
    select i.currency_code into v_invoice_currency
    from public.invoices i
    where i.id = new.invoice_id and i.tenant_id = new.tenant_id;
    if not found then
        return new;
    end if;

    if new.currency_code = v_invoice_currency then
        if new.exchange_rate_id is not null then
            raise exception
                'allocation currency % already matches the invoice currency: no conversion applies, so no exchange rate may be attached',
                new.currency_code using errcode = '23514';
        end if;
        new.allocated_amount_invoice_currency := null;
        return new;
    end if;

    if new.exchange_rate_id is null then
        raise exception
            'cross-currency allocation refused: a % allocation to a % invoice requires an explicit exchange_rate_id (FA-2)',
            new.currency_code, v_invoice_currency using errcode = '23514';
    end if;

    select er.rate, er.from_currency_code, er.to_currency_code into v_rate, v_from, v_to
    from public.exchange_rates er
    where er.id = new.exchange_rate_id and er.tenant_id = new.tenant_id;
    if not found then
        raise exception 'exchange rate is not in your tenant' using errcode = '23514';
    end if;
    if v_from is distinct from new.currency_code or v_to is distinct from v_invoice_currency then
        raise exception 'exchange rate converts % -> %, but this allocation converts % -> %',
            v_from, v_to, new.currency_code, v_invoice_currency using errcode = '23514';
    end if;
    if v_rate is null or v_rate <= 0 or v_rate = 'NaN'::numeric or v_rate >= 'Infinity'::numeric then
        raise exception 'exchange rate must be positive and finite (got %)', v_rate using errcode = '23514';
    end if;

    new.allocated_amount_invoice_currency := new.allocated_amount * v_rate;
    return new;
end
$fn$;

comment on function app.guard_payment_allocation_link() is
    'PAY-6/PAY-8: an allocation''s payment, invoice, currency, rate and origin are fixed once written (only its amount is corrected, by RECORD_PAYMENT); a currency different from the invoice''s requires an exchange_rates row for exactly that pair (FA-2), and the invoice-currency amount is derived from it when the amount is written, never accepted. No session-less exemption: integrity, not authorization.';

revoke all on function app.guard_payment_allocation_link() from public;

create trigger payment_allocations_guard_link
    before insert or update on public.payment_allocations
    for each row execute function app.guard_payment_allocation_link();

-- ------------------------------------------------------------------------------------------------
-- 2. The payment's side, at COMMIT (FIN-8 and FIN-10's idiom): a payment's allocations are its own
--    customer money, in its currency, never more than it is. Fired from both tables, because a
--    payment can be outgrown by its allocations GROWING or by the payment SHRINKING or changing
--    beneath them -- the half a trigger on the allocations alone would miss. Serialised per
--    payment, so two transactions cannot each spend the same remainder.
-- ------------------------------------------------------------------------------------------------
create or replace function app.enforce_payment_allocation_coherence()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_payment uuid;
    v_pay record;
    v_set record;
begin
    -- Named through to_jsonb, not NEW.<col>: plpgsql binds every referenced NEW field before a
    -- CASE chooses its branch (the SPEC-159-A hazard), and the two tables share no id column.
    v_payment := case tg_table_name
                   when 'payments'            then coalesce((to_jsonb(new) ->> 'id')::uuid,
                                                            (to_jsonb(old) ->> 'id')::uuid)
                   when 'payment_allocations' then coalesce((to_jsonb(new) ->> 'payment_id')::uuid,
                                                            (to_jsonb(old) ->> 'payment_id')::uuid)
                 end;
    if v_payment is null then
        return null;
    end if;

    perform pg_advisory_xact_lock(hashtextextended(v_payment::text, 0));

    select p.payment_direction_code, p.customer_id, p.currency_code, p.amount into v_pay
    from public.payments p
    where p.id = v_payment;
    if not found then
        return null;
    end if;

    select count(*) as n,
           coalesce(sum(pa.allocated_amount), 0) as allocated,
           coalesce(bool_or(pa.currency_code is distinct from v_pay.currency_code), false) as foreign_currency,
           coalesce(bool_or(i.customer_id is distinct from v_pay.customer_id), false) as foreign_customer
      into v_set
    from public.payment_allocations pa
    join public.invoices i on i.id = pa.invoice_id and i.tenant_id = pa.tenant_id
    where pa.payment_id = v_payment;
    if v_set.n = 0 then
        return null;
    end if;

    if v_pay.payment_direction_code is distinct from 'customer_payment' then
        raise exception 'payment % is a % and cannot settle a customer invoice',
            v_payment, v_pay.payment_direction_code using errcode = '23514';
    end if;
    if v_set.foreign_currency then
        raise exception 'payment % is in % and an allocation of it claims another currency',
            v_payment, v_pay.currency_code using errcode = '23514';
    end if;
    if v_set.foreign_customer then
        raise exception 'payment % settles an invoice of a customer other than the payment''s own',
            v_payment using errcode = '23514';
    end if;
    if v_set.allocated > v_pay.amount then
        raise exception
            'payment % is over-allocated: % allocated from a payment of % (a payment cannot settle more than it is)',
            v_payment, v_set.allocated, v_pay.amount using errcode = '23514';
    end if;

    return null;
end
$fn$;

comment on function app.enforce_payment_allocation_coherence() is
    'PAY-7: at commit, a payment''s allocations must be of a customer_payment, in the payment''s currency, against invoices of the payment''s own customer, and sum to no more than the payment. Fired from payment_allocations (INSERT/UPDATE) and payments (UPDATE); serialised per payment by an advisory lock. No session-less exemption: integrity, not authorization.';

revoke all on function app.enforce_payment_allocation_coherence() from public;

create constraint trigger payment_allocations_within_payment_amount
    after insert or update on public.payment_allocations
    deferrable initially deferred
    for each row execute function app.enforce_payment_allocation_coherence();

create constraint trigger payments_amount_covers_allocations
    after update on public.payments
    deferrable initially deferred
    for each row execute function app.enforce_payment_allocation_coherence();

-- ------------------------------------------------------------------------------------------------
-- 3. The invoice's side (FIN-10), now serialised on the key `app.record_payment` already takes, and
--    counted in the invoice's currency. With the lock the second of two racing transactions waits
--    for the first to commit and then sums its allocation too; the sum runs in a later statement
--    than the lock, so under READ COMMITTED (PostgREST's and every RPC's level) it reads that commit.
--    PAY-11: the same sum bounds the allocations from BELOW by what the invoice's recorded status
--    asserts. `paid` and `partially_paid` are derived from these rows (canon 26/31) and canon 26 has
--    no transition back out of either, so an allocation write that would leave an invoice `paid` on
--    less than its total, or `partially_paid` on nothing, is that forbidden transition made through
--    the other door -- refused, not repaired: this function moves no status (FIN-7's question).
-- ------------------------------------------------------------------------------------------------
create or replace function app.enforce_invoice_allocation_ceiling()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_invoice uuid;
    v_total numeric;
    v_status text;
    v_allocated numeric;
begin
    -- DELETE carries no NEW. On `invoices` the row IS the invoice; on `payment_allocations` it is
    -- the invoice the row points at.
    v_invoice := case tg_table_name
                   when 'invoices'            then coalesce((to_jsonb(new) ->> 'id')::uuid,
                                                            (to_jsonb(old) ->> 'id')::uuid)
                   when 'payment_allocations' then coalesce((to_jsonb(new) ->> 'invoice_id')::uuid,
                                                            (to_jsonb(old) ->> 'invoice_id')::uuid)
                 end;
    if v_invoice is null then
        return null;
    end if;

    -- FIN-12: the same key app.record_payment takes, so the RPC and the door serialise together.
    -- Only an allocation write takes it: an invoice's total is frozen once issued (INV-5) and only
    -- an issued invoice can be allocated to (PAY-1), so the invoice side has no race to close, and
    -- locking there would only queue every invoice edit behind a payment in flight.
    if tg_table_name = 'payment_allocations' then
        perform pg_advisory_xact_lock(hashtextextended(v_invoice::text, 0));
    end if;

    -- The invoice may have been removed in this same transaction; there is then nothing to exceed.
    select i.total_amount, i.status_code into v_total, v_status
    from public.invoices i where i.id = v_invoice;
    if not found then
        return null;
    end if;

    -- PAY-8: in the invoice's currency. The guard above makes the converted amount present exactly
    -- when the allocation's currency differs from the invoice's.
    select coalesce(sum(coalesce(pa.allocated_amount_invoice_currency, pa.allocated_amount)), 0) into v_allocated
    from public.payment_allocations pa
    where pa.invoice_id = v_invoice;

    if v_allocated > v_total then
        raise exception
            'invoice % is over-allocated: % allocated against a total of % (an invoice cannot be paid more than it is worth)',
            v_invoice, v_allocated, v_total using errcode = '23514';
    end if;

    -- PAY-11: judged where an allocation was written, never on the invoice door, where which status
    -- an invoice may declare is FIN-7's.
    if tg_table_name = 'payment_allocations' then
        if v_status = 'paid' and v_allocated < v_total then
            raise exception
                'invoice % is paid and its allocations would total % of %: an allocation that settled it cannot be reduced (canon 26: no transition leaves paid)',
                v_invoice, v_allocated, v_total using errcode = '23514';
        end if;
        if v_status = 'partially_paid' and v_allocated <= 0 then
            raise exception
                'invoice % is partially_paid and its allocations would total 0: an allocation that settled it cannot be removed (canon 26: no transition returns it to issued)',
                v_invoice using errcode = '23514';
        end if;
    end if;

    return null;
end;
$fn$;

comment on function app.enforce_invoice_allocation_ceiling() is
    'FIN-10/FIN-12/PAY-8/PAY-11: at commit, an invoice''s allocations, in its own currency, total no more than the invoice is worth and -- after an allocation write -- no less than its recorded paid/partially_paid status asserts. Serialised per invoice on app.record_payment''s key for allocation writes. Moves no status. No session-less exemption: integrity, not authorization.';

-- ------------------------------------------------------------------------------------------------
-- 4. `app.record_payment`, its complete current definition with one change: the invoice's
--    already-allocated total is read in the invoice's currency (PAY-8), so its outstanding check
--    and the `paid` / `partially_paid` it derives agree with the ceiling.
-- ------------------------------------------------------------------------------------------------
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

-- ------------------------------------------------------------------------------------------------
-- 5. PAY-10: the allocation's history, on the event spine every other financial fact uses
--    (append-only, actor and time stamped by `app.record_event`, readable exactly when the allocation
--    is). One producer for both facts, fired from the table so the RPC and the door record alike:
--    `payment_allocation_created` now carries what canon 27 requires of it -- the invoice, the
--    payment and the allocated amount -- and `payment_allocation_amount_changed` records each real
--    change of money with the amounts before and after. An UPDATE that changes no money records
--    nothing; a refused write records nothing, because its event rolls back with it.
--    Vocabulary: `sort_order` 935 is MEASURED -- `event_type` holds 187 rows whose maximum is 934 --
--    and the row is seeded under an EXISTING catalog type, so `catalog_types` stays 71 and
--    `catalog_values` goes 622 -> 623.
-- ------------------------------------------------------------------------------------------------
insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
select null::uuid, 'event_type', 'payment_allocation_amount_changed', 'Payment Allocation Amount Changed', 935, true, true
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = 'event_type' and cv.code = 'payment_allocation_amount_changed'
      and cv.tenant_id is null
);

create or replace function app.emit_payment_allocation_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    perform app.record_event(
        new.tenant_id,
        case tg_op when 'INSERT' then 'payment_allocation_created' else 'payment_allocation_amount_changed' end,
        'payment_allocation',
        new.id,
        null,                -- actor: record_event derives it authoritatively (WP-00)
        null, null, null,
        jsonb_build_object('payment_id', new.payment_id,
                           'invoice_id', new.invoice_id,
                           'currency_code', new.currency_code,
                           'exchange_rate_id', new.exchange_rate_id,
                           'allocated_amount', new.allocated_amount,
                           'allocated_amount_invoice_currency', new.allocated_amount_invoice_currency)
        || case when tg_op = 'UPDATE' then
               jsonb_build_object('previous_allocated_amount', old.allocated_amount,
                                  'previous_allocated_amount_invoice_currency', old.allocated_amount_invoice_currency)
           else '{}'::jsonb end,
        case tg_op when 'INSERT' then 'info' else 'warning' end
    );
    return null;
end
$fn$;

comment on function app.emit_payment_allocation_event() is
    'PAY-10: the single producer of payment_allocation_created (with the invoice, payment, currency, rate and amounts canon 27 requires) and payment_allocation_amount_changed (with the amounts before and after). Actor and time come from app.record_event.';

revoke all on function app.emit_payment_allocation_event() from public;

drop trigger payment_allocations_emit_created on public.payment_allocations;

create trigger payment_allocations_emit_created
    after insert on public.payment_allocations
    for each row execute function app.emit_payment_allocation_event();

create trigger payment_allocations_emit_amount_changed
    after update on public.payment_allocations
    for each row
    when (old.allocated_amount is distinct from new.allocated_amount
          or old.allocated_amount_invoice_currency is distinct from new.allocated_amount_invoice_currency)
    execute function app.emit_payment_allocation_event();