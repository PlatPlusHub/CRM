-- WP-04-C / PP-2 -- `document_links` gains the branch for the target it already had a column for.
--
-- THE DEFECT, recorded in WP-04-B rather than hidden: `document_links.scope_isolation` has a branch
-- for every link target EXCEPT `subscription_payment_proof_id`. The payment-proof link inserted by
-- `app.upload_subscription_payment_proof` therefore satisfies the policy only through the unrelated
-- `has_tenant_wide_read()` branch -- which happens to be true because `VIEW_ALL_BRANCHES` (Owner +
-- CEO) is exactly the role set holding `MANAGE_TENANT_SETTINGS`, the permission that RPC requires.
--
-- That is a real coupling between two permissions that have no business relationship. Granting
-- `MANAGE_TENANT_SETTINGS` to a role without `VIEW_ALL_BRANCHES` -- an ordinary, reasonable future
-- change -- would break subscription renewal with a confusing RLS error and no obvious cause. The
-- link is authorized for the wrong reason today; it works by coincidence.
--
-- WHY IT IS A POLICY REWRITE AND WHY THAT IS DONE CAREFULLY. PostgreSQL has no `alter policy … add
-- branch`; the expression must be dropped and recreated in full. That is exactly the high-risk edit
-- where a branch silently disappears and every remaining test still passes, so:
--   * all NINE existing branches are transcribed below verbatim from the live expression, and
--   * `48_document_storage_test.sql` asserts every link-target column still appears in the policy,
--     so a dropped branch fails a test rather than quietly widening or narrowing access.
--
-- The new branch is not a widening. `subscription_payment_proofs` carries its own RLS requiring
-- `VIEW_SUBSCRIPTION_STATUS`, so the sub-select admits only a proof the caller could already see;
-- the link becomes visible for the right reason instead of an accidental one.

drop policy scope_isolation on public.document_links;

create policy scope_isolation on public.document_links
    for all
    using (
        tenant_id = (select app.current_tenant_id())
        and (
            (select app.has_tenant_wide_read())
            or (booking_id is not null and exists (
                    select 1 from public.bookings b where b.id = document_links.booking_id))
            or (booking_item_id is not null and exists (
                    select 1 from public.booking_items bi where bi.id = document_links.booking_item_id))
            or (invoice_id is not null and exists (
                    select 1 from public.invoices i where i.id = document_links.invoice_id))
            or (quotation_id is not null and exists (
                    select 1 from public.quotations q where q.id = document_links.quotation_id))
            or (receipt_id is not null and exists (
                    select 1 from public.receipts r where r.id = document_links.receipt_id))
            or (passenger_id is not null and exists (
                    select 1 from public.passengers p where p.id = document_links.passenger_id))
            or (supplier_id is not null and exists (
                    select 1 from public.suppliers s where s.id = document_links.supplier_id))
            -- PP-2, the branch this table always needed:
            or (subscription_payment_proof_id is not null and exists (
                    select 1 from public.subscription_payment_proofs spp
                    where spp.id = document_links.subscription_payment_proof_id))
        )
    )
    with check (
        tenant_id = (select app.current_tenant_id())
        and (
            (select app.has_tenant_wide_read())
            or (booking_id is not null and exists (
                    select 1 from public.bookings b where b.id = document_links.booking_id))
            or (booking_item_id is not null and exists (
                    select 1 from public.booking_items bi where bi.id = document_links.booking_item_id))
            or (invoice_id is not null and exists (
                    select 1 from public.invoices i where i.id = document_links.invoice_id))
            or (quotation_id is not null and exists (
                    select 1 from public.quotations q where q.id = document_links.quotation_id))
            or (receipt_id is not null and exists (
                    select 1 from public.receipts r where r.id = document_links.receipt_id))
            or (passenger_id is not null and exists (
                    select 1 from public.passengers p where p.id = document_links.passenger_id))
            or (supplier_id is not null and exists (
                    select 1 from public.suppliers s where s.id = document_links.supplier_id))
            or (subscription_payment_proof_id is not null and exists (
                    select 1 from public.subscription_payment_proofs spp
                    where spp.id = document_links.subscription_payment_proof_id))
        )
    );
