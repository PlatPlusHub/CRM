-- Migration: complete_catalog_enforcement
-- Plan reference: SPEC-136. Closes the CAT-4 residual and VOCAB-1's remainder by extending
-- `app.enforce_catalog_codes` to every catalog-backed column that was previously validated only on
-- its RPC path.
--
-- WHERE THIS STOOD. SPEC-127 applied the trigger to the 12 tables that had NO RPC write path, because
-- that was where the vocabulary was enforced by nothing at all. Columns written by an RPC were left
-- alone: their RPC validates them, which is sufficient for the RPC path and only for the RPC path.
-- Two consequences remained:
--   * CAT-4 residual — deactivating a catalog value still did not prevent its use on those columns,
--     because the ~27 in-RPC lookups do not filter `is_active`.
--   * SEC-1 — a direct PostgREST write bypasses the RPC entirely, and with it the only vocabulary
--     check those columns had.
-- Extending the trigger closes both at once, and does so without touching a single RPC.
--
-- THIS IS NOT A NEW MECHANISM. It is the same trigger, the same declarative column->family mapping,
-- applied to the rest of the schema. ADR-0006 names exactly this ("validation trigger … optional per
-- column"), and migration `202607049100` set the precedent for `events.event_type_code`.
--
-- DELIBERATE EXCLUSIONS, each with a reason rather than an oversight:
--   * `events` / `security_events` — already carry their own registry enforcement (049100) and are
--     append-only audit tables. A second trigger would duplicate an existing guarantee.
--   * `booking_items.sub_status_code` — its governing family DEPENDS ON `service_type_code`
--     (`ticket_sub_status` / `hotel_sub_status` / `visa_sub_status`), so a single static mapping
--     cannot express it. Canon 26's Sub-Status Rule owns that relationship; recorded as CAT-5 rather
--     than forced into a mechanism that cannot represent it correctly.
--   * `chart_of_accounts.account_type` — plain text by ratified decision ADR-0006, already recorded
--     as NOT-A-GAP in the backlog on 2026-07-17.
--   * `branches.branch_type`, `company_assets.asset_type`, `catalog_types.ownership_type`,
--     `user_role_assignments.scope_type`, `feature_entitlements.feature_code` — no catalog family
--     exists for these. Inventing one would be fabricating canon; recorded as CAT-6.
--   * Free-text reason/notes columns (`archive_reason`, `void_reason`, `rejection_reason`,
--     `assignment_reason`) — genuinely free-form employee input, not controlled vocabulary.

-- ---------------------------------------------------------------------------------------------
-- CRM
-- ---------------------------------------------------------------------------------------------
create trigger leads_enforce_catalog_codes
    before insert or update on public.leads
    for each row execute function app.enforce_catalog_codes(
        'lead_source_code', 'lead_source',
        'lead_status_code', 'lead_status',
        'closure_reason_code', 'lead_closure_reason',
        'priority_code', 'priority_code',
        'requested_service_type_code', 'service_type');

create trigger lead_interactions_enforce_catalog_codes
    before insert or update on public.lead_interactions
    for each row execute function app.enforce_catalog_codes(
        'interaction_type_code', 'lead_interaction_type');

create trigger customers_enforce_catalog_codes
    before insert or update on public.customers
    for each row execute function app.enforce_catalog_codes(
        'customer_type_code', 'customer_type',
        'preferred_contact_method_code', 'preferred_contact_method_code');

create trigger customer_identity_signals_enforce_catalog_codes
    before insert or update on public.customer_identity_signals
    for each row execute function app.enforce_catalog_codes(
        'signal_type_code', 'customer_identity_signal_type');

create trigger passengers_enforce_catalog_codes
    before insert or update on public.passengers
    for each row execute function app.enforce_catalog_codes(
        'passenger_type_code', 'passenger_type',
        'relationship_to_customer_code', 'passenger_relationship_code');

-- ---------------------------------------------------------------------------------------------
-- Booking
-- ---------------------------------------------------------------------------------------------
create trigger bookings_enforce_catalog_codes
    before insert or update on public.bookings
    for each row execute function app.enforce_catalog_codes(
        'booking_status_code', 'booking_status');

create trigger booking_items_enforce_catalog_codes
    before insert or update on public.booking_items
    for each row execute function app.enforce_catalog_codes(
        'service_type_code', 'service_type',
        'base_status_code', 'booking_item_base_status',
        'cancellation_reason_code', 'booking_cancellation_reason_code',
        'finance_approval_status_code', 'approval_status_code');

create trigger quotations_enforce_catalog_codes
    before insert or update on public.quotations
    for each row execute function app.enforce_catalog_codes(
        'quotation_status_code', 'quotation_status_code');

create trigger quotation_items_enforce_catalog_codes
    before insert or update on public.quotation_items
    for each row execute function app.enforce_catalog_codes(
        'service_type_code', 'service_type');

create trigger approval_requests_enforce_catalog_codes
    before insert or update on public.approval_requests
    for each row execute function app.enforce_catalog_codes(
        'approval_type_code', 'approval_type_code',
        'approval_status_code', 'approval_status_code');

-- ---------------------------------------------------------------------------------------------
-- Finance
-- ---------------------------------------------------------------------------------------------
create trigger invoices_enforce_catalog_codes
    before insert or update on public.invoices
    for each row execute function app.enforce_catalog_codes(
        'status_code', 'invoice_status_code',
        'external_submission_status_code', 'tax_submission_status_code');

create trigger receipts_enforce_catalog_codes
    before insert or update on public.receipts
    for each row execute function app.enforce_catalog_codes(
        'external_submission_status_code', 'tax_submission_status_code');

create trigger payments_enforce_catalog_codes
    before insert or update on public.payments
    for each row execute function app.enforce_catalog_codes(
        'payment_method_code', 'payment_method',
        'payment_direction_code', 'payment_direction');

create trigger refunds_enforce_catalog_codes
    before insert or update on public.refunds
    for each row execute function app.enforce_catalog_codes(
        'refund_reason_code', 'refund_reason_code',
        'refund_status_code', 'refund_status_code',
        'payment_direction_code', 'payment_direction');

create trigger journal_entries_enforce_catalog_codes
    before insert or update on public.journal_entries
    for each row execute function app.enforce_catalog_codes(
        'source_type_code', 'journal_entry_source_type');

-- ---------------------------------------------------------------------------------------------
-- Documents
-- ---------------------------------------------------------------------------------------------
create trigger documents_enforce_catalog_codes
    before insert or update on public.documents
    for each row execute function app.enforce_catalog_codes(
        'document_type_code', 'document_type',
        'lifecycle_status_code', 'document_lifecycle_status');

create trigger document_versions_enforce_catalog_codes
    before insert or update on public.document_versions
    for each row execute function app.enforce_catalog_codes(
        'file_type_code', 'allowed_file_type');

-- ---------------------------------------------------------------------------------------------
-- Attribution and organization
-- ---------------------------------------------------------------------------------------------
create trigger attribution_clicks_enforce_catalog_codes
    before insert or update on public.attribution_clicks
    for each row execute function app.enforce_catalog_codes(
        'attribution_source_code', 'attribution_source');

create trigger offline_conversions_enforce_catalog_codes
    before insert or update on public.offline_conversions
    for each row execute function app.enforce_catalog_codes(
        'conversion_event_type_code', 'offline_conversion_event_type');

create trigger offline_conversion_deliveries_enforce_catalog_codes
    before insert or update on public.offline_conversion_deliveries
    for each row execute function app.enforce_catalog_codes(
        'platform_code', 'platform_code',
        'delivery_status_code', 'offline_conversion_delivery_status');

create trigger departments_enforce_catalog_codes
    before insert or update on public.departments
    for each row execute function app.enforce_catalog_codes(
        'department_type_code', 'department_type');

create trigger notifications_enforce_catalog_codes
    before insert or update on public.notifications
    for each row execute function app.enforce_catalog_codes(
        'notification_type_code', 'notification_type');

create trigger user_branch_assignments_enforce_catalog_codes
    before insert or update on public.user_branch_assignments
    for each row execute function app.enforce_catalog_codes(
        'transfer_type_code', 'branch_transfer_type');
