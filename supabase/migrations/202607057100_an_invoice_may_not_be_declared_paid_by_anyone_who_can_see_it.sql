-- FIN-6 -- an invoice could be marked PAID by anyone who could see it.
--
-- ================================================================================================
-- FOUND WHILE RESOLVING SEC-2, AND IT IS THE HALF OF SEC-2 THAT IS NOT A BUSINESS DECISION
--
-- SEC-2 asked whether editing an existing record needs a capability. Reading the evidence split the
-- question in two, and only one half is a policy question:
--
--   * DESCRIPTIVE fields (a lead's title, a customer's name) -- INTENTIONAL. ORVION governs
--     mutation by CONSEQUENCE, not by table. The permission catalog contains only SPECIFIC mutation
--     permissions -- `EDIT_LOCKED_COST` (one field, after lock) and `UPDATE_BOOKING_ITEM_STATUS`
--     (one status) -- and no generic EDIT_<entity> anywhere; no RPC among the 71 exposed endpoints
--     updates a descriptive field; canon 28 names no such permission. RLS scope is deliberately the
--     whole control there.
--
--   * CONSEQUENCE-BEARING fields with no guard -- DEFECTS, not decisions. This migration closes the
--     proven one.
--
-- REPRODUCED. An `employee` holding CREATE_INVOICE = f and RECORD_PAYMENT = f, on an invoice they
-- can see because it belongs to their own booking:
--
--     mark a 50,000 EGP invoice 'paid' with no payment  ->  SUCCEEDED, status_after = paid
--     change the invoice AMOUNT                          ->  REFUSED: permission denied: CREATE_INVOICE
--
-- The second line is the control that makes the first conclusive: the guard is present and working,
-- it simply does not cover the status. `app.guard_financial_capability` charges the capability on
-- UPDATE "only when a MONETARY column changes" -- deliberately, so that status advances and
-- verification stamps kept their existing authority (FIN-3's header says so). For `refunds` and
-- `quotation_items` that reasoning holds, because their status IS separately governed by
-- `app.enforce_status_transition`. For `invoices` it does not: `app.status_transitions` has ZERO
-- rows for invoices, and canon 26 defines no Invoice State Machine at all -- so the status was
-- governed by nothing.
--
-- What that buys an employee: declaring a customer's invoice settled without any money arriving.
-- `customer_outstanding` and every balance derived from invoice status then report a debt as paid.
--
-- ================================================================================================
-- THE FIX, AND WHY IT INVENTS NOTHING
--
-- The status columns join the list of columns whose change requires the permission the table
-- ALREADY charges. Nothing new is decided: `invoices` already charges CREATE_INVOICE for its
-- amount, and that is what its status now costs too.
--
-- No legitimate path breaks, and this was checked BEFORE writing rather than after: the only
-- writers of `invoices.status_code` are `app.issue_invoice` and `app.record_payment`, and
-- CREATE_INVOICE and RECORD_PAYMENT are held by exactly the same three roles -- ceo, finance_manager
-- and owner. A finance user advancing an invoice already holds what this charges.
--
-- `external_submission_status_code` is included on both `invoices` and `receipts` for the same
-- reason one column over (§26): it is the Egyptian e-invoicing submission state. Falsely marking a
-- document as submitted to the tax authority is the same class of misstatement as falsely marking
-- it paid, and it was equally unguarded.
--
-- DELIBERATELY NOT CHANGED:
--   * `refunds.refund_status_code` and the quotation status -- both already governed by
--     `enforce_status_transition` with canon-defined machines. Adding them here would charge the
--     same permission twice and imply the transition table is insufficient, which it is not.
--   * The absence of an Invoice State Machine. Canon defines sixteen machines and no invoice one;
--     inventing the legal transitions would be inventing business policy. This guards WHO may change
--     the status, not WHICH changes are legal -- recorded as FIN-7.
-- ================================================================================================

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
                  when 'payments'            then array['amount']
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
