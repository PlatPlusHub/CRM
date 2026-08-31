-- Migration: a financial document follows the work, not the department
-- SPEC-154-B, owner-decided 2026-08-31 (Option C).
--
-- THE RULE, and where it comes from. Canon 08 §Document Permissions: "Financial documents are
-- visible to finance and management by default. The responsible employee for a lead or booking may
-- view financial documents directly related to that lead or booking when operationally required" --
-- with the worked example "An employee can upload and view a customer's bank transfer receipt for
-- their assigned booking, but CANNOT BROWSE UNRELATED FINANCE DOCUMENTS." Canon 07 §Transfer Proof
-- Approval says the same from the finance side ("the responsible employee uploads the transfer
-- receipt"), and canon 28 records VIEW_FINANCIAL_DOCUMENTS as "Assigned related only" for both
-- `employee` and `senior_employee`. Three canonical sources, no dissent.
--
-- WHAT WAS ACTUALLY HAPPENING, reproduced before this was written. In one transaction: a booking
-- owned by employee E1; an invoice document uploaded by the MANAGER (so `created_by` explains
-- nothing) and linked to that booking; E2, an ordinary employee in the same department, responsible
-- for nothing. E1 read the document. **E2 read the same document, identically.** The two results
-- were indistinguishable, which is the defect: responsibility played no part. The read came through
-- the department axis -- `VIEW_DEPARTMENT_RECORDS` makes the BOOKING visible, the booking makes the
-- LINK visible, and the link was the whole test the policy applied.
--
-- WHY THE DEPARTMENT AXIS IS NOT THE ANSWER HERE, although it is elsewhere. The owner directive of
-- 2026-08-24 has both halves: "assignment must never mean sole visibility" (amendment 1, which is
-- why department continuity exists at all) AND §2.1 "an ordinary employee must NOT be able to see
-- the profit, commission, financial performance ... of another employee". SPEC-139 already applied
-- exactly that split one table over: a department colleague keeps the booking ITEM and loses the
-- MARGIN. This migration applies the same split to the document: the colleague keeps the booking
-- and loses the invoice attached to it. Nothing about operational continuity changes -- leads,
-- bookings, booking items, tasks, quotations and their records stay department-visible.
--
-- ENFORCEMENT LAYER, chosen from the MEASURED surface and not copied from the last package.
-- `documents` is reachable through PostgREST (`authenticated` holds SELECT) and through
-- `app.financial_documents()`, which is SECURITY INVOKER -- so BOTH doors resolve through the same
-- RLS policy, and RLS is therefore the one place the rule can live. A trigger cannot express a READ
-- rule; a CHECK cannot see another table; widening the endpoint's `authorize` would have left the
-- table door open, which is BOOK-1's whole lesson. One policy, one authority.
--
-- WHAT WAS DELIBERATELY NOT DONE:
--   * `VIEW_FINANCIAL_DOCUMENTS` is NOT granted to `employee`/`senior_employee`. Canon marks it
--     "Assigned related only" and the permission is binary; worse, the CONFIDENTIAL branch below
--     carries no link-visibility conjunct, so granting it would hand every ordinary employee every
--     confidential financial document in the tenant. The scope is expressed as a predicate instead
--     -- the same choice SPEC-139 made with `app.item_financials`, which gates on
--     `has_permission(VIEW_FINANCIAL_DOCUMENTS) OR <caller is a responsible user>` and mints nothing.
--   * `is_confidential` is NOT collapsed into the financial classification. Canon 25 defines
--     `confidentiality_level_code` (normal | confidential) with usage "Document visibility" as a
--     PER-DOCUMENT control; canon 08/28 make financial strictness a PER-TYPE control. They are
--     orthogonal, and forcing the flag on financial types would satisfy canon 28's "stricter
--     visibility" by destroying canon 08's assigned-employee rule.
--   * `app.financial_documents()` keeps its `VIEW_FINANCIAL_DOCUMENTS` gate. It is a tenant-wide
--     finance REGISTER, not the per-document read canon grants the assigned employee; that read is
--     served by the table, correctly scoped, from now on. Its header comment is corrected below.

-- ---------------------------------------------------------------------------------------------
-- 1. `quotation` leaves the financial set, because canon never put it there.
--
--    Canon 07's finance inventory is journal entries, receivables, payables, payments, refunds,
--    INVOICES and RECEIPTS -- no quotation. Canon 28 puts CREATE_QUOTATION / SEND_QUOTATION /
--    ACCEPT_QUOTATION in the CRM table at `assigned/department` scope, not in Finance. Canon 28's
--    own read-scope model lists the financial records as invoices, payments, receipts, refunds and
--    payment_allocations, and lists `quotations` among the OPERATIONAL scope-bearing tables. And
--    `app.financial_documents()` has never returned a quotation-typed document. The classifier was
--    the only place in ORVION that called a quotation financial; it did so fail-closed
--    (`202607052400`), which cost nothing while the set only affected finance-role holders.
--
--    It costs something now. From this migration the financial set is what an ordinary employee is
--    held OUT of, so membership has to be canon-correct: leaving `quotation` in would strip the
--    quotation document from a colleague covering an absent seller -- defeating amendment 2 of the
--    same 2026-08-24 directive, which minted VIEW_DEPARTMENT_RECORDS *for quotations* precisely so
--    that record stays readable. Removing it is required, not tidying.
--
--    MEASURED CONSEQUENCE, not assumed: a finance_manager who does not also hold
--    VIEW_TRAVEL_DOCUMENTS stops seeing non-confidential quotation DOCUMENTS (they kept them only
--    through the `is_financial_document_type` escape). That is canon-consistent -- canon 28 has
--    exactly two document VIEW permissions, so a non-financial document is governed by the other
--    one, which canon marks *Optional* for that role. No consumer breaks: the classifier's only
--    non-test caller is the policy below, and `app.financial_documents()` never listed quotations.
create or replace function app.is_financial_document_type(p_document_type_code text)
returns boolean
language sql
immutable
set search_path = ''
as $fn$
    select p_document_type_code in ('invoice', 'receipt', 'payment_proof')
$fn$;

-- ---------------------------------------------------------------------------------------------
-- 2. "The responsible employee for a lead or booking", as a predicate.
--
--    `documents` carries no owner of its own -- a document belongs to whatever it is attached to --
--    so responsibility, like visibility, has to be derived through `document_links`. The
--    responsible-user columns are taken from the read-scope model rather than invented:
--    bookings(owner_user_id) · booking_items(owner_user_id, sales_owner_user_id,
--    operational_owner_user_id) · quotations(owner_user_id). Invoices and receipts have no owner of
--    their own, so each resolves to the booking or booking item it is FOR -- an invoice through
--    `booking_id`/`booking_item_id`, a receipt through its payment. That is what "directly related
--    to their lead/booking" means for a document hanging off a financial record.
--
--    `passenger_id`, `supplier_id` and `subscription_payment_proof_id` deliberately resolve to
--    FALSE. The first two are tenant master data with no responsible user; the third is the
--    company's own bank transfer, where "the responsible employee" has no meaning -- and it is
--    written confidential by `app.upload_subscription_payment_proof`, so it never reaches this
--    branch anyway.
--
--    SECURITY DEFINER, and the reason is SUP-1's: responsibility is a property of the row, not of
--    the caller's visibility, and under INVOKER a parent hidden by its own RLS would read as "not
--    responsible" -- a false negative that would deny exactly the access canon grants. It cannot
--    widen anything, because the policy below still requires a VISIBLE link before it is consulted.
--
--    Written as explicit `=` comparisons rather than `x in (a, b, c)`. In a WHERE clause the NULL
--    that SPEC-139 was bitten by behaves as false, which is the right answer here -- but the shape
--    that made a flag NULL once is not worth reusing where a plain OR says the same thing.
create or replace function app.is_document_responsible(p_document_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
    select exists (
        select 1
        from public.document_links dl
        left join public.bookings       b   on b.id   = dl.booking_id
        left join public.booking_items  bi  on bi.id  = dl.booking_item_id
        left join public.quotations     q   on q.id   = dl.quotation_id
        left join public.invoices       i   on i.id   = dl.invoice_id
        left join public.bookings       ib  on ib.id  = i.booking_id
        left join public.booking_items  ibi on ibi.id = i.booking_item_id
        left join public.receipts       r   on r.id   = dl.receipt_id
        left join public.payments       pm  on pm.id  = r.payment_id
        left join public.bookings       rb  on rb.id  = pm.booking_id
        left join public.booking_items  rbi on rbi.id = pm.booking_item_id
        where dl.document_id = p_document_id
          and (   b.owner_user_id                 = app.current_user_id()
               or bi.owner_user_id                = app.current_user_id()
               or bi.sales_owner_user_id          = app.current_user_id()
               or bi.operational_owner_user_id    = app.current_user_id()
               or q.owner_user_id                 = app.current_user_id()
               or ib.owner_user_id                = app.current_user_id()
               or ibi.owner_user_id               = app.current_user_id()
               or ibi.sales_owner_user_id         = app.current_user_id()
               or ibi.operational_owner_user_id   = app.current_user_id()
               or rb.owner_user_id                = app.current_user_id()
               or rbi.owner_user_id               = app.current_user_id()
               or rbi.sales_owner_user_id         = app.current_user_id()
               or rbi.operational_owner_user_id   = app.current_user_id() )
    )
$fn$;
revoke execute on function app.is_document_responsible(uuid) from public;
grant execute on function app.is_document_responsible(uuid) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- 3. The policy. ONE disjunct changes; the other three are byte-identical to `202607052400`.
--
--    Original inner test on the non-confidential branch:
--        not has(VIEW_FINANCIAL_DOCUMENTS) or is_financial_type or has(VIEW_TRAVEL_DOCUMENTS)
--    which reads: a finance-permission holder gets financial documents only, unless they also hold
--    the travel permission; EVERYONE ELSE gets every linked document. The second half is the hole.
--
--    New form, stated as a CASE so the two audiences are visible rather than inferred:
--      * finance-permission holder  -> unchanged (financial types, plus travel if they hold it)
--      * everyone else              -> non-financial documents as before; financial ones ONLY when
--                                      they are the responsible user for what it is attached to
--    Equivalence for every case except the hole was checked line by line, not assumed.
--
--    Applied to USING and WITH CHECK alike, as the original was. The `created_by` disjunct is what
--    keeps canon 08's example whole: an employee who uploads their booking's transfer receipt keeps
--    it whether or not anyone later considers them responsible.
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
            and case
                  when (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS'))
                      then app.is_financial_document_type(document_type_code)
                           or (select app.has_permission('VIEW_TRAVEL_DOCUMENTS'))
                  else not app.is_financial_document_type(document_type_code)
                       or app.is_document_responsible(public.documents.id)
                end)
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
            and case
                  when (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS'))
                      then app.is_financial_document_type(document_type_code)
                           or (select app.has_permission('VIEW_TRAVEL_DOCUMENTS'))
                  else not app.is_financial_document_type(document_type_code)
                       or app.is_document_responsible(public.documents.id)
                end)
    )
);

-- ---------------------------------------------------------------------------------------------
-- 4. A stale claim, corrected here because its own file is immutable (a comment is a claim).
--    `202607048200`'s header states "RLS on documents is tenant-wide (every member can read
--    documents)", and uses that premise to justify the endpoint's `authorize` as "the earned case
--    for an app.authorize on a read". The premise was true when SPEC-112 shipped and was made FALSE
--    by SPEC-144 and SPEC-145, which brought `documents` into the read-scope model. The endpoint has
--    therefore been stricter than its own stated reason for two packages, and after this migration
--    it is stricter still. The gate is KEPT -- not for the reason `202607048200` gives, but because
--    a tenant-wide finance register is a finance tool, while the per-document read canon grants the
--    assigned employee is served by the policy above, on both doors, correctly scoped.
--    The function itself is deliberately NOT re-created: the false sentence is in a migration
--    header, not in `prosrc`, so replacing the object would change the function surface and correct
--    nothing a reader can see. Evidence home: FIN-DOC-1 in `MASTER_GAP_REGISTER.md`.
