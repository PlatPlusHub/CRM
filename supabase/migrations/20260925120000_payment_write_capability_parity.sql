-- SPEC-221 / PAY-2. Charge RECORD_PAYMENT when an authenticated direct UPDATE changes
-- a payment's economic identity, just as INSERT and amount changes already do.
-- Preserve the existing trigger, RPC signatures, RLS and session-less behavior.
create or replace function app.guard_financial_capability()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
    v_perm text;
    v_cols text[];
    v_new  jsonb;
    v_old  jsonb;
    v_col  text;
    v_changed boolean := false;
begin
    -- Platform/system paths (canon 35 principle 6), consistent with every other guard here.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- THE MONEY COLUMNS ARE NAMED, NOT REFERENCED. A `case tg_table_name when 'payments' then
    -- new.amount ... when 'invoices' then new.total_amount ...` reads correctly and does not work:
    -- plpgsql binds EVERY referenced NEW field as a query parameter before the CASE chooses a
    -- branch, so the invoices path still tries to resolve `new.amount` and fails on a table that
    -- has no such column. That is the hazard SPEC-159-A already hit and documented; the first draft
    -- of this migration walked straight back into it and `38_class_a_events_test.sql` caught it.
    -- `to_jsonb` compares by NAME, which is the shape `app.enforce_document_subscription_gate`
    -- already uses for exactly this reason.
    v_perm := case tg_table_name
                  when 'payments'            then 'RECORD_PAYMENT'
                  when 'payment_allocations' then 'RECORD_PAYMENT'
                  when 'receipts'            then 'CREATE_RECEIPT'
                  when 'refunds'             then 'RECORD_REFUND'
                  when 'invoices'            then 'CREATE_INVOICE'
                  when 'quotation_items'     then 'CREATE_QUOTATION'
              end;
    -- FIN-6: the STATUS of a financial document is as consequential as its amount, and on the two
    -- tables below it was governed by nothing -- no transition machine in canon, no rows in
    -- app.status_transitions, and this guard's UPDATE branch deliberately ignoring it.
    -- `refunds` and `quotation_items` are absent from this widening on purpose: their status IS
    -- governed, by enforce_status_transition against canon-defined machines.
    v_cols := case tg_table_name
                  when 'payments'            then array['amount', 'payment_direction_code', 'customer_id',
                                                       'supplier_id', 'booking_id', 'booking_item_id',
                                                       'financial_account_id', 'currency_code',
                                                       'payment_method_code', 'paid_at', 'exchange_rate_id']
                  when 'payment_allocations' then array['allocated_amount']
                  -- FIN-6b: this said array['amount'] since FIN-3, and `receipts` HAS NO `amount`
                  -- COLUMN -- the money lives on the payment. `to_jsonb(new) ->> 'amount'` is NULL
                  -- on both sides, `NULL is distinct from NULL` is false, so the UPDATE branch of
                  -- this guard has been INERT for receipts from the day it shipped. The `to_jsonb`
                  -- comparison that fixed SPEC-159-A's plpgsql binding hazard also removed the
                  -- compiler's ability to catch a column name that does not exist; assertion 10 of
                  -- `68_financial_status_capability_test` now checks every name in this map against
                  -- the catalog, so the next typo fails loudly instead of silently guarding nothing.
                  when 'receipts'            then array['external_submission_status_code']
                  when 'refunds'             then array['amount']
                  when 'invoices'            then array['total_amount', 'status_code',
                                                        'external_submission_status_code']
                  when 'quotation_items'     then array['unit_price', 'quantity']
              end;

    if v_perm is null then
        -- A table was attached to this trigger without being given a permission. Refusing is the
        -- only safe reading: silently returning NEW would create the exact unguarded write path
        -- this migration exists to close.
        raise exception 'guard_financial_capability has no permission mapping for %', tg_table_name
            using errcode = 'insufficient_privilege';
    end if;

    if tg_op = 'INSERT' then
        perform app.authorize(v_perm);
        return new;
    end if;

    -- UPDATE: a change to the money itself, or to a status that nothing else governs, needs the
    -- write capability. Everything else on these rows is governed by the authority it already had.
    v_new := to_jsonb(new);
    v_old := to_jsonb(old);
    foreach v_col in array v_cols loop
        if (v_new ->> v_col) is distinct from (v_old ->> v_col) then
            v_changed := true;
        end if;
    end loop;

    if v_changed then
        perform app.authorize(v_perm);
    end if;

    return new;
end
$function$;
