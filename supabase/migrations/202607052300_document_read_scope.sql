-- Migration: document_read_scope
-- Plan reference: SPEC-144. Brings `documents`, `document_links` and `document_versions` into the
-- read-scope model.
--
-- HOW THIS WAS MISSED, AND WHY IT MATTERS. SPEC-137 scoped the eight ownership-triple tables, their
-- derived children, and the financial tables. Documents were named in its plan and never reached its
-- migration, so all three document tables stayed on the original `tenant_isolation` policy. The gap
-- surfaced when auditing permission coverage: `VIEW_TRAVEL_DOCUMENTS` and `VIEW_FINANCIAL_DOCUMENTS`
-- both appeared as enforced nowhere, which for a table holding passport scans and financial records
-- is not a paperwork discrepancy. Canon 28 scopes travel documents as assigned/department and
-- financial documents more tightly still, and neither was true of the database.
--
-- THE SHAPE OF THE PROBLEM. `documents` carries no branch, department or owner: a document belongs to
-- whatever it is attached to, through the polymorphic `document_links`. So visibility has to be
-- derived, and the derivation has one hazard worth stating -- if `documents` scoped itself through
-- `document_links` while `document_links` scoped itself through `documents`, each policy would invoke
-- the other and recurse without end. The dependency is therefore deliberately one-directional:
--
--     document_links  -> scoped by its PARENT record (booking, invoice, quotation, ...)
--     documents       -> scoped by whether any of its links is visible
--     document_versions -> scoped by its document
--
-- Each `exists` inherits the referenced table's own RLS, so the whole chain tracks SPEC-137 without
-- restating any of it.

-- ---------------------------------------------------------------------------------------------
-- 1. document_links: visible when the thing the document is attached to is visible.
--
-- `passengers` and `suppliers` are tenant-visible master data, so a link to either is visible to
-- anyone in the tenant -- the same reasoning canon 05 applies to the customer master. The restriction
-- that matters is on the operational and financial records, which carry their own scope.
-- ---------------------------------------------------------------------------------------------
drop policy if exists tenant_isolation on public.document_links;
create policy scope_isolation on public.document_links for all to authenticated
using (
    tenant_id = (select app.current_tenant_id())
    and (
        (select app.has_tenant_wide_read())
        or (booking_id is not null       and exists (select 1 from public.bookings b       where b.id = public.document_links.booking_id))
        or (booking_item_id is not null  and exists (select 1 from public.booking_items bi where bi.id = public.document_links.booking_item_id))
        or (invoice_id is not null       and exists (select 1 from public.invoices i       where i.id = public.document_links.invoice_id))
        or (quotation_id is not null     and exists (select 1 from public.quotations q     where q.id = public.document_links.quotation_id))
        or (receipt_id is not null       and exists (select 1 from public.receipts r       where r.id = public.document_links.receipt_id))
        or (passenger_id is not null     and exists (select 1 from public.passengers p     where p.id = public.document_links.passenger_id))
        or (supplier_id is not null      and exists (select 1 from public.suppliers s      where s.id = public.document_links.supplier_id))
    )
)
with check (
    tenant_id = (select app.current_tenant_id())
    and (
        (select app.has_tenant_wide_read())
        or (booking_id is not null       and exists (select 1 from public.bookings b       where b.id = public.document_links.booking_id))
        or (booking_item_id is not null  and exists (select 1 from public.booking_items bi where bi.id = public.document_links.booking_item_id))
        or (invoice_id is not null       and exists (select 1 from public.invoices i       where i.id = public.document_links.invoice_id))
        or (quotation_id is not null     and exists (select 1 from public.quotations q     where q.id = public.document_links.quotation_id))
        or (receipt_id is not null       and exists (select 1 from public.receipts r       where r.id = public.document_links.receipt_id))
        or (passenger_id is not null     and exists (select 1 from public.passengers p     where p.id = public.document_links.passenger_id))
        or (supplier_id is not null      and exists (select 1 from public.suppliers s      where s.id = public.document_links.supplier_id))
    )
);

-- ---------------------------------------------------------------------------------------------
-- 2. documents.
--
-- `is_confidential` is treated as meaning what it says. A confidential document does not become
-- readable because a colleague can see the booking it hangs off; it stays with its author, the
-- finance roles, and tenant-wide readers. Without that clause the flag would be decorative -- and a
-- flag that does nothing is worse than no flag, because it implies a protection that is not there.
--
-- An uploader always keeps their own uploads. Otherwise attaching a document to a record that later
-- moves branches would silently take it away from the person who added it.
-- ---------------------------------------------------------------------------------------------
drop policy if exists tenant_isolation on public.documents;
create policy scope_isolation on public.documents for all to authenticated
using (
    tenant_id = (select app.current_tenant_id())
    and (
        (select app.has_tenant_wide_read())
        or created_by = (select app.current_user_id())
        or (is_confidential and (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS')))
        or (not is_confidential
            and exists (select 1 from public.document_links dl where dl.document_id = public.documents.id))
    )
)
with check (
    tenant_id = (select app.current_tenant_id())
    and (
        (select app.has_tenant_wide_read())
        or created_by = (select app.current_user_id())
        or (is_confidential and (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS')))
        or (not is_confidential
            and exists (select 1 from public.document_links dl where dl.document_id = public.documents.id))
    )
);

-- ---------------------------------------------------------------------------------------------
-- 3. document_versions: a version is part of its document and has no separate audience.
-- ---------------------------------------------------------------------------------------------
drop policy if exists tenant_isolation on public.document_versions;
create policy scope_isolation on public.document_versions for all to authenticated
using (
    tenant_id = (select app.current_tenant_id())
    and exists (select 1 from public.documents d where d.id = public.document_versions.document_id)
)
with check (
    tenant_id = (select app.current_tenant_id())
    and exists (select 1 from public.documents d where d.id = public.document_versions.document_id)
);
