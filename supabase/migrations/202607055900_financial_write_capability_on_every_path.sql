-- FIN-3 -- money could be recorded by anyone who could see the booking it belonged to.
--
-- ================================================================================================
-- REPRODUCED BEFORE FIXED. An `employee` -- `RECORD_PAYMENT = false`, `RECORD_REFUND = false` --
-- acting as `authenticated` by direct DML against a booking they own:
--
--     insert into public.payments (tenant_id, payment_direction_code, customer_id, booking_id,
--                                  amount, currency_code, payment_method_code, paid_at)
--     values (..., 'customer_payment', ..., 999999, 'EGP', 'cash', now());
--
--     FORGED PAYMENT ROWS BY EMPLOYEE WITHOUT RECORD_PAYMENT: 1
--
-- `app.record_payment` charges `RECORD_PAYMENT`, which is held by ceo, finance_manager and owner
-- only. The table accepted the row from someone holding none of it.
--
-- ================================================================================================
-- THE PATTERN, AND WHY IT LOOKED ENFORCED
--
-- Every money table's policy DOES mention a permission, which is why an automated sweep counting
-- "policies referencing has_permission" scored them as guarded. Read one and the illusion breaks:
--
--     payments      with check: tenant AND ( has_permission('VIEW_FINANCIAL_DOCUMENTS')
--                                            OR booking is visible OR booking item is visible )
--     receipts      with check: tenant AND ( has_permission('VIEW_FINANCIAL_DOCUMENTS')
--                                            OR the payment is visible )
--     refunds       with check: tenant AND ( has_permission('VIEW_FINANCIAL_DOCUMENTS')
--                                            OR booking is visible ... )
--     invoices, payment_allocations: the same shape.
--
-- The permission named is a READ permission, and it sits in an OR with a pure visibility test. So
-- the effective rule is "you may write money about anything you can see" -- the RLS-1 pattern
-- (a read predicate authorizing writes) recurring in the one family where it costs the most.
--
-- `quotation_items` does not even do that: `tenant AND the parent quotation is visible`. Any
-- colleague who can see a quotation could add a line at any price.
--
-- ORVION ALREADY KNOWS THE RIGHT PATTERN, which is what makes this an omission rather than a design
-- choice. `journal_entries` and `journal_entry_lines` require the actual write capability:
--
--     with check: tenant AND has_permission('CREATE_JOURNAL_ENTRY')
--
-- The ledger was guarded correctly and the cash was not.
--
-- ================================================================================================
-- THE FIX, AND WHY IT INVENTS NOTHING
--
-- Each table is charged EXACTLY the permission its own RPC already charges -- read out of the
-- functions, not chosen by me:
--
--     app.record_payment           -> RECORD_PAYMENT        -> payments, payment_allocations
--     app.record_supplier_payment  -> RECORD_PAYMENT        -> payments
--     app.issue_receipt            -> CREATE_RECEIPT        -> receipts
--     app.record_refund            -> RECORD_REFUND         -> refunds
--     app.create_invoice           -> CREATE_INVOICE        -> invoices
--     app.add_quotation_item       -> CREATE_QUOTATION      -> quotation_items
--
-- So direct DML now costs what the documented path always cost. No permission is invented, no role
-- gains anything, and every RPC keeps working unchanged -- it charges the same permission a moment
-- before the trigger does.
--
-- A TRIGGER RATHER THAN A POLICY AMENDMENT. These are `for ALL` policies whose expressions are long
-- and shared between USING and WITH CHECK; amending them means retranscribing ten branches by hand,
-- which is exactly how PP-2 lost one. A trigger is additive, changes no existing expression, and
-- follows the closest precedent in the codebase -- `app.guard_booking_item_financials`, which
-- protects the other half of the same money model.
--
-- SCOPE: INSERT always, and UPDATE only when a monetary column actually changes. Status advances,
-- reference numbers and verification stamps keep the authority they already have (status
-- transitions, archive authority) -- this migration adds capability where money is created or
-- altered, and nowhere else.
--
-- SYSTEM PATHS are exempt from the CHECK, never from the write itself: `app.provision_tenant`,
-- cron, the storage executor and every migration run session-less, exactly as in
-- `app.guard_booking_item_financials` and `app.enforce_archive_authority`.
-- ================================================================================================

create or replace function app.guard_financial_capability()
returns trigger
language plpgsql
set search_path = ''
as $fn$
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
    v_cols := case tg_table_name
                  when 'payments'            then array['amount']
                  when 'payment_allocations' then array['allocated_amount']
                  when 'receipts'            then array['amount']
                  when 'refunds'             then array['amount']
                  when 'invoices'            then array['total_amount']
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

    -- UPDATE: only a change to the money itself needs the write capability. Everything else on
    -- these rows is governed by the authority it already had.
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
$fn$;

revoke execute on function app.guard_financial_capability() from public;

create trigger payments_guard_financial_capability
    before insert or update on public.payments
    for each row execute function app.guard_financial_capability();

create trigger payment_allocations_guard_financial_capability
    before insert or update on public.payment_allocations
    for each row execute function app.guard_financial_capability();

create trigger receipts_guard_financial_capability
    before insert or update on public.receipts
    for each row execute function app.guard_financial_capability();

create trigger refunds_guard_financial_capability
    before insert or update on public.refunds
    for each row execute function app.guard_financial_capability();

create trigger invoices_guard_financial_capability
    before insert or update on public.invoices
    for each row execute function app.guard_financial_capability();

create trigger quotation_items_guard_financial_capability
    before insert or update on public.quotation_items
    for each row execute function app.guard_financial_capability();

-- ================================================================================================
-- FIN-4 -- an approval request could name someone else as its requester.
--
-- `approval_requests.scope_insert` checks only `tenant_id = current_tenant_id()`. `requested_by` is
-- an ordinary caller-supplied column, so any tenant user could open a request and attribute it to a
-- colleague -- and the approval record is the evidence of who asked for the exception.
--
-- The fix is WP-00's shape, and deliberately not a permission: DERIVE, DO NOT VALIDATE. Whatever
-- the caller sends for `requested_by` is overwritten with the caller's own id, so the forgery is
-- unrepresentable rather than merely refused, on the RPC path and the direct path alike.
--
-- Which PERMISSION should govern opening each approval type is a separate question and is NOT
-- answered here: `scope_update` already switches on `approval_type_code` for the decision, and the
-- corresponding map for requests would need canon per type. Recorded as FIN-5 rather than guessed.
-- Attribution is fixed now because it needs no such decision.
-- ================================================================================================

create or replace function app.derive_approval_requester()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    new.requested_by := app.current_user_id();
    return new;
end
$fn$;

revoke execute on function app.derive_approval_requester() from public;

create trigger approval_requests_derive_requester
    before insert on public.approval_requests
    for each row execute function app.derive_approval_requester();
