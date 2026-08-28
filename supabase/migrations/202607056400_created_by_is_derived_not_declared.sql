-- ATTR-1 -- `created_by` was a caller-supplied column on twenty tables.
--
-- ================================================================================================
-- THE SAME RULE FIN-4 RATIFIED, APPLIED TO THE CLASS INSTEAD OF THE INSTANCE
--
-- FIN-4 found that `approval_requests.requested_by` was an ordinary caller-supplied column, so any
-- tenant user could open an approval request attributed to a colleague. The fix was WP-00's shape --
-- DERIVE, DO NOT VALIDATE -- which makes the forgery unrepresentable rather than merely refused, on
-- the RPC path and the direct path alike.
--
-- A sweep for the class finds the same shape on `created_by` across TWENTY tables that
-- `authenticated` may INSERT: bookings, booking_items, customers, customer_notes, leads,
-- quotations, invoices, payments, payment_allocations, receipts, refunds, journal_entries,
-- documents, document_links, complaints, service_requests, tasks, catalog_values,
-- exchange_rate_adjustments and user_branch_assignments.
--
-- Every `app.*` RPC already sets it from the session. Direct DML did not have to, so an employee
-- could create a customer, a booking, an invoice or a payment attributed to a colleague. Not
-- cross-tenant -- RLS holds that boundary -- but it corrupts precisely the attribution an audit
-- trail exists to carry, and `documents.scope_isolation` even reads `created_by` as one of its
-- visibility grants, so on that table it is load-bearing for authorization rather than only for
-- history.
--
-- WHY IMMUTABLE ON UPDATE, AND HOW THAT WAS CHECKED. No function anywhere in `app` or `public`
-- updates `created_by` -- verified against every function body before this was written, not assumed
-- from the name. So restoring OLD on UPDATE cannot break a working path, and it closes the second
-- half of the hole: deriving only on INSERT would leave the value editable a moment later.
--
-- `archived_by`, `document_versions.uploaded_by` and `approval_requests.requested_by` are already
-- derived by their own triggers and are deliberately untouched here.
--
-- NOT INCLUDED, and recorded rather than guessed: `invoices.voided_by`, `journal_entries.voided_by`,
-- `approval_requests.reviewed_by` and `subscription_payment_proofs.reviewed_by` / `uploaded_by`.
-- Those are ACTION attributions, stamped when the action happens rather than when the row is
-- created, so an insert-time derivation would be wrong for them. They need the same treatment at
-- the moment of the action, which is a different trigger shape -- ATTR-2.
-- ================================================================================================

create or replace function app.derive_created_by()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    -- Platform/system paths (canon 35 principle 6): provisioning, cron and the integration role
    -- write rows before any session exists, and must keep whatever attribution they set.
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'INSERT' then
        new.created_by := app.current_user_id();
    else
        -- Immutable. Verified first: no app.* or public.* function updates this column.
        new.created_by := old.created_by;
    end if;

    return new;
end
$fn$;

revoke execute on function app.derive_created_by() from public;

create trigger bookings_derive_created_by                 before insert or update on public.bookings                 for each row execute function app.derive_created_by();
create trigger booking_items_derive_created_by            before insert or update on public.booking_items            for each row execute function app.derive_created_by();
create trigger customers_derive_created_by                before insert or update on public.customers                for each row execute function app.derive_created_by();
create trigger customer_notes_derive_created_by           before insert or update on public.customer_notes           for each row execute function app.derive_created_by();
create trigger leads_derive_created_by                    before insert or update on public.leads                    for each row execute function app.derive_created_by();
create trigger quotations_derive_created_by               before insert or update on public.quotations               for each row execute function app.derive_created_by();
create trigger invoices_derive_created_by                 before insert or update on public.invoices                 for each row execute function app.derive_created_by();
create trigger payments_derive_created_by                 before insert or update on public.payments                 for each row execute function app.derive_created_by();
create trigger payment_allocations_derive_created_by      before insert or update on public.payment_allocations      for each row execute function app.derive_created_by();
create trigger receipts_derive_created_by                 before insert or update on public.receipts                 for each row execute function app.derive_created_by();
create trigger refunds_derive_created_by                  before insert or update on public.refunds                  for each row execute function app.derive_created_by();
create trigger journal_entries_derive_created_by          before insert or update on public.journal_entries          for each row execute function app.derive_created_by();
create trigger documents_derive_created_by                before insert or update on public.documents                for each row execute function app.derive_created_by();
create trigger document_links_derive_created_by           before insert or update on public.document_links           for each row execute function app.derive_created_by();
create trigger complaints_derive_created_by               before insert or update on public.complaints               for each row execute function app.derive_created_by();
create trigger service_requests_derive_created_by         before insert or update on public.service_requests         for each row execute function app.derive_created_by();
create trigger tasks_derive_created_by                    before insert or update on public.tasks                    for each row execute function app.derive_created_by();
create trigger catalog_values_derive_created_by           before insert or update on public.catalog_values           for each row execute function app.derive_created_by();
create trigger exchange_rate_adjustments_derive_created_by before insert or update on public.exchange_rate_adjustments for each row execute function app.derive_created_by();
create trigger user_branch_assignments_derive_created_by  before insert or update on public.user_branch_assignments  for each row execute function app.derive_created_by();
