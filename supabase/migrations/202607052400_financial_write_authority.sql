-- Migration: financial_write_authority
-- Plan reference: SPEC-145. Enforces the finance permissions at the table, so they hold when the RPC
-- is bypassed.
--
-- WHAT WAS ACTUALLY TRUE. `authenticated` held INSERT and UPDATE on every finance table, and none of
-- them carried anything but a tenant check. An ordinary employee could:
--
--   * set an exchange rate -- which silently changes what every multi-currency booking cost;
--   * create an exchange-rate adjustment;
--   * write journal entries and edit the chart of accounts;
--   * UPDATE their own `approval_requests` row to `approved` -- self-approving a refund, a discount,
--     a booking override or a manual price change;
--   * write `booking_items.cost_amount` and `commission_rate` (they cannot READ them after SPEC-139,
--     but the column grants are independent -- withholding SELECT does not withhold UPDATE);
--   * clear `cost_locked_at`, defeating cost locking entirely;
--   * set `finance_approval_status_code` to `approved` without ever calling
--     `app.review_finance_approval`.
--
-- Every one of those permissions was seeded and granted to exactly the right roles. Six of them
-- (`SET_EXCHANGE_RATE`, `CREATE_EXCHANGE_RATE_ADJUSTMENT`, `REVIEW_APPROVAL_REQUEST`, `ENTER_COST`,
-- `ENTER_SELLING_PRICE`, `EDIT_LOCKED_COST`) were enforced nowhere at all; `CREATE_JOURNAL_ENTRY`
-- and `APPROVE_FINANCE` were enforced only inside an RPC that nothing obliged anyone to call.
--
-- TWO MECHANISMS, CHOSEN PER TABLE. Where the WHOLE table is finance authority, an RLS write policy
-- is the right tool -- it is declarative and it cannot be reached around. Where only SOME columns are
-- (booking_items is mostly operational), a trigger is the only tool that can distinguish, because a
-- policy sees rows and not columns.
--
-- THE PERMISSION FOR EACH COLUMN IS TAKEN FROM CANON 28, NOT CHOSEN. `ENTER_COST`,
-- `ENTER_SELLING_PRICE` and `CREATE_BOOKING_ITEM` are held by the same five roles, so guarding the
-- costing columns cannot lock anyone out of creating an item they are entitled to create.

-- ---------------------------------------------------------------------------------------------
-- 1. Whole-table finance authority.
-- ---------------------------------------------------------------------------------------------
do $$
declare
    r record;
    v_read text;
    v_write text;
begin
    for r in
        select * from (values
            ('exchange_rates',            'SET_EXCHANGE_RATE'),
            ('exchange_rate_adjustments', 'CREATE_EXCHANGE_RATE_ADJUSTMENT'),
            ('journal_entries',           'CREATE_JOURNAL_ENTRY'),
            ('journal_entry_lines',       'CREATE_JOURNAL_ENTRY'),
            -- Canon 28 names no permission for the chart of accounts. It is the ledger's structure,
            -- and a journal entry cannot exist without the accounts it posts to, so the accounting
            -- authority that governs entries governs the accounts they use. `CREATE_JOURNAL_ENTRY`
            -- is held by exactly the three roles (owner / ceo / finance_manager) that canon puts in
            -- charge of the ledger, so this borrows an existing authority rather than inventing one.
            ('chart_of_accounts',         'CREATE_JOURNAL_ENTRY')
        ) as t(tbl, permission)
    loop
        v_read  := 'tenant_id = (select app.current_tenant_id())';
        v_write := format('%s and (select app.has_permission(%L))', v_read, r.permission);

        execute format('drop policy if exists tenant_isolation on public.%I', r.tbl);
        execute format('drop policy if exists scope_read on public.%I', r.tbl);
        execute format('create policy scope_read on public.%I for select to authenticated using (%s)', r.tbl, v_read);
        execute format('create policy scope_insert on public.%I for insert to authenticated with check (%s)', r.tbl, v_write);
        execute format('create policy scope_update on public.%I for update to authenticated using (%s) with check (%s)', r.tbl, v_write, v_write);
        execute format('create policy scope_delete on public.%I for delete to authenticated using (%s)', r.tbl, v_write);
    end loop;
end
$$;

-- ---------------------------------------------------------------------------------------------
-- 2. Approval requests: raising one is ordinary work, reviewing one is authority.
--
-- INSERT stays open to the tenant -- `app.request_finance_approval` authorizes CREATE_BOOKING_ITEM,
-- and asking for approval is not the privileged act. UPDATE is the review, and canon 28 splits which
-- permission governs it BY TYPE: "REVIEW_APPROVAL_REQUEST governs `approval_requests` rows whose
-- `approval_type_code` is not `finance_execution_approval` (covered by APPROVE_FINANCE) and not
-- `subscription_approval` (covered by REVIEW_SUBSCRIPTION_PAYMENT)". That sentence is the policy.
-- ---------------------------------------------------------------------------------------------
drop policy if exists tenant_isolation on public.approval_requests;
create policy scope_read on public.approval_requests for select to authenticated
    using (tenant_id = (select app.current_tenant_id()));
create policy scope_insert on public.approval_requests for insert to authenticated
    with check (tenant_id = (select app.current_tenant_id()));
create policy scope_update on public.approval_requests for update to authenticated
    using (
        tenant_id = (select app.current_tenant_id())
        and (case approval_type_code
                when 'finance_execution_approval' then (select app.has_permission('APPROVE_FINANCE'))
                when 'subscription_approval'      then (select app.has_permission('REVIEW_SUBSCRIPTION_PAYMENT'))
                else (select app.has_permission('REVIEW_APPROVAL_REQUEST'))
             end)
    )
    with check (
        tenant_id = (select app.current_tenant_id())
        and (case approval_type_code
                when 'finance_execution_approval' then (select app.has_permission('APPROVE_FINANCE'))
                when 'subscription_approval'      then (select app.has_permission('REVIEW_SUBSCRIPTION_PAYMENT'))
                else (select app.has_permission('REVIEW_APPROVAL_REQUEST'))
             end)
    );

-- A tenant user may upload a payment proof; reviewing it is the platform's act (canon 28 gives
-- REVIEW_SUBSCRIPTION_PAYMENT to the Platform Owner alone, so in practice this is service_role).
drop policy if exists tenant_isolation on public.subscription_payment_proofs;
create policy scope_read on public.subscription_payment_proofs for select to authenticated
    using (tenant_id = (select app.current_tenant_id()));
create policy scope_insert on public.subscription_payment_proofs for insert to authenticated
    with check (tenant_id = (select app.current_tenant_id()));
create policy scope_update on public.subscription_payment_proofs for update to authenticated
    using (tenant_id = (select app.current_tenant_id())
           and (select app.has_permission('REVIEW_SUBSCRIPTION_PAYMENT')))
    with check (tenant_id = (select app.current_tenant_id())
           and (select app.has_permission('REVIEW_SUBSCRIPTION_PAYMENT')));

-- ---------------------------------------------------------------------------------------------
-- 3. booking_items: column-level authority.
--
-- A policy cannot express this -- `booking_items` is mostly operational and must stay writable by
-- the people who run the booking. Only five columns carry financial authority, and a trigger is the
-- only mechanism that can tell them apart from the rest of the row.
--
-- `app.authorize` is called rather than `app.has_permission` so the failure is an explicit
-- `42501 permission denied: <KEY>`, identical to the message the RPC path produces. A silent
-- zero-row UPDATE would leave the caller believing the write succeeded.
-- ---------------------------------------------------------------------------------------------
create or replace function app.guard_booking_item_financials()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    -- No authenticated end user means this is not an employee acting -- it is `service_role` or a
    -- migration, both of which canon 35 principle 6 places outside per-table enforcement ("Platform
    -- -level support access is therefore a backend concern (service role), not a per-table RLS
    -- policy"). The exemption cannot be abused by a tenant user: without a resolved identity they
    -- fail `tenant_id = app.current_tenant_id()` on every policy and cannot reach a row at all.
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'INSERT' then
        -- `cost_amount` and `selling_amount` are NOT NULL DEFAULT 0, so "is not null" is never false
        -- and would demand a finance permission for an item carrying no financial value at all --
        -- which existing test 25 caught immediately. Entering a cost means entering a NON-ZERO one;
        -- zero is the absence of a figure, not a figure. Creating a bare item stays governed by
        -- CREATE_BOOKING_ITEM alone, which is what canon 28 says it is.
        if coalesce(new.cost_amount, 0) <> 0 then
            perform app.authorize('ENTER_COST');
        end if;
        if coalesce(new.selling_amount, 0) <> 0 or new.commission_rate is not null then
            perform app.authorize('ENTER_SELLING_PRICE');
        end if;
        if new.cost_locked_at is not null or new.finance_approval_status_code is not null then
            perform app.authorize('APPROVE_FINANCE');
        end if;
        return new;
    end if;

    -- Cost after locking is a different act from cost before it. Canon 28 gives the first to the
    -- five operational roles and the second to finance alone, which is the entire purpose of the
    -- lock: it moves the cost out of operations' reach.
    if new.cost_amount is distinct from old.cost_amount then
        if old.cost_locked_at is not null then
            perform app.authorize('EDIT_LOCKED_COST');
        else
            perform app.authorize('ENTER_COST');
        end if;
    end if;

    if new.selling_amount is distinct from old.selling_amount
       or new.commission_rate is distinct from old.commission_rate then
        perform app.authorize('ENTER_SELLING_PRICE');
    end if;

    -- Setting or clearing the lock, and moving the finance approval status, are both finance acts.
    -- Clearing the lock matters most: without this, any operational user could unlock a cost and
    -- then edit it under ENTER_COST, making EDIT_LOCKED_COST unreachable in practice.
    if new.cost_locked_at is distinct from old.cost_locked_at
       or new.finance_approval_status_code is distinct from old.finance_approval_status_code then
        perform app.authorize('APPROVE_FINANCE');
    end if;

    return new;
end
$$;
revoke execute on function app.guard_booking_item_financials() from public;

create trigger booking_items_guard_financials
    before insert or update on public.booking_items
    for each row execute function app.guard_booking_item_financials();

-- ---------------------------------------------------------------------------------------------
-- 4. Finance roles must be able to SEE the financial objects they govern.
--
-- Found while testing this migration, and it is a defect SPEC-137 introduced. A finance manager
-- holding both VIEW_FINANCIAL_DOCUMENTS and APPROVE_FINANCE could see **zero bookings and zero
-- booking items**: they own no records, belong to no sales department, and hold no VIEW_BRANCH_DATA.
-- `app.review_finance_approval` is SECURITY INVOKER, so it could not find the item it was approving
-- -- the entire finance-approval workflow was broken for the only role canon puts in charge of it.
--
-- Test 21 did not catch this because it asserted only that finance could read INVOICES, which is
-- exactly the clause SPEC-137 had written. It never asked whether finance could reach a booking.
--
-- Canon 28 scopes VIEW_FINANCIAL_DOCUMENTS as tenant/branch/assigned, with the finance roles holding
-- the tenant-scope variant, so tenant-wide visibility of the financial objects is the canonical
-- reading -- and it is already how `invoices`, `payments`, `refunds` and `receipts` behave. This
-- extends the same clause to the two tables those documents describe. It does NOT extend to leads,
-- tasks or conversations: canon says "Finance related", not "everything".
-- ---------------------------------------------------------------------------------------------
do $$
declare
    r record;
    v_predicate text;
begin
    for r in
        select * from (values
            ('bookings',      'branch_id',       'department_id',       'owner_user_id',                                                  'VIEW_DEPARTMENT_RECORDS'),
            ('booking_items', 'owner_branch_id', 'owner_department_id', 'owner_user_id, sales_owner_user_id, operational_owner_user_id',  'VIEW_DEPARTMENT_RECORDS')
        ) as t(tbl, branch_col, dept_col, owner_cols, dept_permission)
    loop
        v_predicate := format(
            'tenant_id = (select app.current_tenant_id()) and ('
            '  (select app.has_tenant_wide_read())'
            '  or (select app.has_permission(''VIEW_FINANCIAL_DOCUMENTS''))'
            '  or (select app.current_user_id()) in (%s)'
            '  or %s'
            '  or ( %I in (select app.visible_branch_ids())'
            '       and ( (select app.has_permission(''VIEW_BRANCH_DATA''))'
            '             or ( (select app.has_permission(%L))'
            '                  and %I in (select app.visible_department_ids()) ) ) )'
            ')',
            r.owner_cols,
            case when r.tbl = 'booking_items'
                 then 'exists (select 1 from public.bookings b where b.id = public.booking_items.booking_id)'
                 else 'false' end,
            r.branch_col, r.dept_permission, r.dept_col);

        execute format('drop policy if exists scope_isolation on public.%I', r.tbl);
        execute format(
            'create policy scope_isolation on public.%I for all to authenticated using (%s) with check (%s)',
            r.tbl, v_predicate, v_predicate);
    end loop;
end
$$;

-- ---------------------------------------------------------------------------------------------
-- 5. Keep the finance clause from leaking travel documents.
--
-- Giving finance visibility of bookings had a side effect that existing test 28 caught immediately:
-- `documents` grants a non-confidential document when any of its links points at a record the caller
-- can see, so finance's new booking visibility flowed straight through to passport scans. Canon 28
-- separates VIEW_TRAVEL_DOCUMENTS (Finance Manager: *Optional*, and not granted) from
-- VIEW_FINANCIAL_DOCUMENTS (Finance Manager: Yes) precisely so that seeing the money does not mean
-- seeing the passport.
--
-- The extra clause makes that separation real, and states it as a RULE rather than a role check:
-- a caller whose claim on the document is the finance permission gets financial document types only,
-- unless they also hold VIEW_TRAVEL_DOCUMENTS -- which is exactly the "Optional" canon 28 records.
-- Ordinary employees are unaffected: they do not hold VIEW_FINANCIAL_DOCUMENTS, so the first
-- disjunct is true for them. Owner and CEO short-circuit earlier on tenant-wide read.
--
-- `contract` and `other` are deliberately NOT classified as financial. They are ambiguous, and the
-- fail-closed reading is the one canon supports ("Financial documents require stricter visibility").
create or replace function app.is_financial_document_type(p_document_type_code text)
returns boolean
language sql
immutable
set search_path = ''
as $$
    select p_document_type_code in ('invoice', 'receipt', 'quotation')
$$;
revoke execute on function app.is_financial_document_type(text) from public;
grant execute on function app.is_financial_document_type(text) to authenticated;

drop policy if exists scope_isolation on public.documents;
create policy scope_isolation on public.documents for all to authenticated
using (
    tenant_id = (select app.current_tenant_id())
    and (
        (select app.has_tenant_wide_read())
        or created_by = (select app.current_user_id())
        or (is_confidential and (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS'))
            and app.is_financial_document_type(document_type_code))
        or (not is_confidential
            and exists (select 1 from public.document_links dl where dl.document_id = public.documents.id)
            and ( not (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS'))
                  or app.is_financial_document_type(document_type_code)
                  or (select app.has_permission('VIEW_TRAVEL_DOCUMENTS')) ))
    )
)
with check (
    tenant_id = (select app.current_tenant_id())
    and (
        (select app.has_tenant_wide_read())
        or created_by = (select app.current_user_id())
        or (is_confidential and (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS'))
            and app.is_financial_document_type(document_type_code))
        or (not is_confidential
            and exists (select 1 from public.document_links dl where dl.document_id = public.documents.id)
            and ( not (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS'))
                  or app.is_financial_document_type(document_type_code)
                  or (select app.has_permission('VIEW_TRAVEL_DOCUMENTS')) ))
    )
);
