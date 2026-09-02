# Schema Draft

Version: 0.5
Status: Frozen Baseline
Canonical: Yes

---

# Purpose

This document defines the first logical ORVION database schema draft.

It is not a SQL migration.

It is the reviewable schema specification before writing SQL.

---

# Schema Scope

This draft covers:

- Organization and SaaS isolation
- Users, roles, permissions
- CRM leads and customers
- Tasks, quotations, notes, and conversations
- Booking and booking items
- Passengers
- Suppliers
- Finance core
- Documents
- Events and notifications
- Subscriptions and plan limits
- Authentication support
- Offline conversion engine

This draft intentionally excludes:

- Full tax engine
- Advanced financial statements
- GDS integrations
- Data warehouse
- Marketplace/plugin architecture
- Full workflow engine runtime
- HR/payroll

---

# Global Conventions

All tenant-owned tables include:

- id
- tenant_id
- created_at
- updated_at

Important business tables include archive fields:

- is_archived
- archived_at
- archived_by
- archive_reason

Events are immutable and never archived as normal business action.

Operational ownership fields should be applied consistently to work records:

- owner_user_id
- owner_department_id
- owner_branch_id

These fields represent current operational responsibility, not historical assignment. Historical movement is recorded through assignment tables and events.

---

# 1. System Catalog Tables

## catalog_types

Purpose:

Defines catalog groups.

Core fields:

- id
- code
- name
- ownership_type
- description
- is_active

## catalog_values

Purpose:

Stores system and tenant-controlled catalog values.

Core fields:

- id
- tenant_id nullable for system values
- catalog_type_code
- code
- label
- description
- sort_order
- is_active
- is_system
- created_by
- created_at
- updated_at

Notes:

- System catalog values have `tenant_id = null`.
- Tenant catalog values have tenant_id.

---

# 2. Organization Tables

## tenants

Purpose:

Represents subscribed travel companies.

Core fields:

- id
- name
- slug
- legal_name
- primary_phone
- primary_email
- default_currency_code
- status
- created_at
- updated_at

Unique:

- slug

## branches

Purpose:

Operational branches inside tenant.

Core fields:

- id
- tenant_id
- name
- slug
- branch_type optional
- primary_phone
- address
- is_active
- created_at
- updated_at

Unique:

- tenant_id + slug

## departments

Purpose:

Departments inside branches.

Core fields:

- id
- tenant_id
- branch_id
- department_type_code
- name
- is_active
- created_at
- updated_at

## branch_business_hours

Purpose:

Defines weekly branch operating hours.

Core fields:

- id
- tenant_id
- branch_id
- day_of_week
- opens_at nullable
- closes_at nullable
- is_closed boolean
- notes nullable
- created_at
- updated_at

## holidays

Purpose:

Lightweight holiday calendar for SLA and operational planning.

Core fields:

- id
- tenant_id
- branch_id nullable
- name
- holiday_date
- is_recurring boolean
- description nullable
- created_at
- updated_at

## users

Purpose:

Application users/employees.

Core fields:

- id
- tenant_id
- full_name
- phone
- email
- is_active
- is_platform_user
- created_at
- updated_at

Notes:

- A `users` row is the human's membership in this tenant; `auth.users` is the shared human identity (one login per person). `auth_user_id` links the membership to that identity, is unique per tenant (a human holds at most one membership per tenant, and may hold memberships in several tenants), and is null until activation. Supabase Auth is the authentication identity; this table is ORVION's business profile layer. Authorization remains entirely inside ORVION RBAC — the JWT is authentication-only, never the authoritative source of business permissions. The physical key strategy is defined in `30_database_conventions.md`'s Identity Key Standard. See `# 13. Review Required` item 3.

## user_branch_assignments

Purpose:

Tracks current and historical branch assignments.

Core fields:

- id
- tenant_id
- user_id
- branch_id
- department_id nullable
- transfer_type_code
- starts_at
- ends_at
- is_primary
- reason
- created_by
- created_at

## roles

Purpose:

Defines roles.

Core fields:

- id
- code
- name
- description
- is_system
- is_active

## permissions

Purpose:

Defines permission keys.

Core fields:

- id
- key
- name
- description
- is_system
- is_active

## role_permissions

Purpose:

Maps roles to permissions.

Core fields:

- id
- role_id
- permission_id
- created_at

## user_role_assignments

Purpose:

Assigns scoped roles to users.

Core fields:

- id
- tenant_id
- user_id
- role_id
- scope_type
- branch_id nullable
- department_id nullable
- starts_at
- ends_at
- is_active
- assigned_by
- created_at

---

# 2a. Reference Tables

## currencies

Purpose:

Canonical, validated currency list used by every `currency_code` column in this schema.

Core fields:

- code
- name
- symbol nullable
- decimal_places
- is_active
- created_at
- updated_at

Unique:

- code

Notes:

- Every `currency_code` column elsewhere in this document is a reference to `currencies.code`.
- `decimal_places` governs per-currency display/rounding; the Money Standard's `numeric(19, 4)` storage convention (see `30_database_conventions.md`, widened from `numeric(14, 2)` by SPEC-118 / DC-1) already stores the minor unit of 3-decimal currencies without truncation.

---

## countries

Purpose:

Canonical country reference used by every country code column (for example `destination_country_code`, `passport_issuing_country_code`).

Core fields:

- code
- name
- is_active
- created_at
- updated_at

Unique:

- code

## languages

Purpose:

Canonical language reference used by every language code column (for example `preferred_language_code`).

Core fields:

- code
- name
- is_active
- created_at
- updated_at

Unique:

- code

## nationalities

Purpose:

Canonical nationality reference used by every nationality code column (for example `nationality_code`).

Core fields:

- code
- name
- is_active
- created_at
- updated_at

Unique:

- code

---

# 3. CRM Tables

## leads

Purpose:

Represents sales/service opportunities.

Core fields:

- id
- tenant_id
- branch_id
- department_id
- owner_user_id nullable
- owner_department_id nullable
- owner_branch_id nullable
- lead_source_code
- lead_status_code
- priority_code nullable
- closure_reason_code nullable
- customer_id nullable
- assigned_user_id nullable
- title
- requested_service_type_code nullable
- expected_value numeric nullable
- next_follow_up_at nullable
- last_contact_at nullable
- customer_phone_snapshot
- customer_name_snapshot
- source_payload jsonb nullable
- attribution_click_id nullable (first-touch attribution anchor -> `attribution_clicks`)
- created_by
- created_at
- updated_at
- closed_at nullable
- is_archived
- archived_at
- archived_by
- archive_reason

Rules:

- Leads are not physically deleted.
- Closed leads keep status and closure reason.

## lead_assignments

Purpose:

Preserves assignment and reassignment history.

Core fields:

- id
- tenant_id
- lead_id
- assigned_user_id
- assigned_by
- assigned_at
- unassigned_at nullable
- assignment_reason
- is_current

## lead_interactions

Purpose:

Records meaningful lead interactions.

Core fields:

- id
- tenant_id
- lead_id
- user_id
- interaction_type_code
- interaction_at
- summary
- metadata jsonb nullable
- created_at

## customers

Purpose:

Approved customer identity.

Core fields:

- id
- tenant_id
- customer_type_code
- first_name nullable
- family_name nullable
- full_name
- company_name nullable
- primary_phone
- primary_email nullable
- preferred_language_code nullable
- preferred_contact_method_code nullable
- marketing_opt_in boolean
- first_registered_branch_id nullable
- last_interaction_branch_id nullable
- last_interaction_user_id nullable
- last_interaction_at nullable
- created_by
- created_at
- updated_at
- is_archived
- archived_at
- archived_by
- archive_reason

Indexes:

- tenant_id + primary_phone

## customer_contact_methods

Purpose:

Stores customer contact channels.

Core fields:

- id
- tenant_id
- customer_id
- contact_method_type_code
- value
- is_primary
- is_verified
- created_at
- updated_at

## customer_identity_signals

Purpose:

Supports duplicate detection.

Core fields:

- id
- tenant_id
- customer_id
- signal_type_code
- signal_value
- source_entity_type
- source_entity_id
- created_at

## customer_identity_merges

Purpose:

Records customer identity merge actions as first-class, queryable data.

Core fields:

- id
- tenant_id
- source_customer_id
- target_customer_id
- merged_by
- reason nullable
- created_at

Notes:

- This table supplements, and does not replace, the customer_identity_merged event already defined in event_catalog.md. The event remains the audit-trail record of the action; this table is the queryable relational record.

## customer_notes

Purpose:

Stores searchable and editable customer business notes.

Core fields:

- id
- tenant_id
- customer_id
- note_text
- is_pinned
- is_confidential
- created_by
- created_at
- updated_at
- is_archived
- archived_at
- archived_by
- archive_reason

Notes:

- Customer notes are different from events.
- Events are immutable history.
- Notes are editable business memory.

## tasks

Purpose:

Represents operational work assigned to employees.

Examples:

- Call customer
- Send quotation
- Issue ticket
- Verify passport
- Collect payment
- Approve refund

Core fields:

- id
- tenant_id
- owner_user_id
- owner_department_id
- owner_branch_id
- related_entity_type nullable
- related_entity_id nullable
- task_type_code
- task_status_code
- priority_code nullable
- title
- description nullable
- due_at nullable
- completed_at nullable
- created_by
- created_at
- updated_at
- is_archived
- archived_at
- archived_by
- archive_reason

Rules:

- Tasks represent work.
- Notifications communicate information.
- Every pending task must belong to exactly one responsible employee.

## complaints

Purpose:

Captures first-class customer complaints and their resolution workflow.

Core fields:

- id
- tenant_id
- customer_id
- booking_id nullable
- booking_item_id nullable
- owner_user_id nullable
- owner_department_id nullable
- owner_branch_id nullable
- complaint_category_code
- complaint_severity_code
- complaint_status_code
- title
- description nullable
- resolution_notes nullable
- resolved_at nullable
- closed_at nullable
- created_by
- created_at
- updated_at
- is_archived
- archived_at
- archived_by
- archive_reason

Notes:

- Complaints integrate with tasks, conversations, and events.
- Timeline history is captured through immutable events.

## service_requests

Purpose:

Represents operational work requested after the initial booking.

Core fields:

- id
- tenant_id
- customer_id
- booking_id nullable
- booking_item_id nullable
- owner_user_id nullable
- owner_department_id nullable
- owner_branch_id nullable
- service_request_type_code
- service_request_severity_code nullable
- service_request_status_code
- title
- description nullable
- requested_at
- resolved_at nullable
- created_by
- created_at
- updated_at
- is_archived
- archived_at
- archived_by
- archive_reason

Notes:

- Service requests link naturally to tasks, events, and conversations.
- This avoids separate tables for every request type.

## quotations

Purpose:

Represents price/service offers sent to customers before booking.

Core fields:

- id
- tenant_id
- lead_id nullable
- customer_id
- owner_user_id nullable
- owner_department_id nullable
- owner_branch_id nullable
- quotation_status_code
- quotation_number (unique per tenant — migration 048800)
- currency_code
- total_amount numeric
- valid_until nullable
- sent_at nullable
- accepted_at nullable
- rejected_at nullable
- created_by
- created_at
- updated_at
- is_archived
- archived_at
- archived_by
- archive_reason

## quotation_items

Purpose:

Represents service lines inside a quotation.

Core fields:

- id
- tenant_id
- quotation_id
- service_type_code
- description
- quantity numeric
- unit_price numeric
- total_amount numeric
- currency_code
- created_at

Notes:

- Accepted quotations may create bookings.

## conversations

Purpose:

Represents an ongoing or historical customer conversation.

Core fields:

- id
- tenant_id
- customer_id nullable
- lead_id nullable
- booking_id nullable
- booking_item_id nullable
- owner_user_id nullable
- owner_department_id nullable
- owner_branch_id nullable
- current_branch_id nullable
- current_department_id nullable
- channel_code
- conversation_status_code
- external_conversation_id nullable
- started_at
- closed_at nullable
- created_at
- updated_at

Notes:

- Conversations support WhatsApp, phone, and future channels.
- Conversations are separate from events.
- Events record milestones; conversations store communication context.
- `current_branch_id` and `current_department_id` support active department handoffs without losing original ownership history.

## conversation_messages

Purpose:

Stores individual conversation messages or call log entries.

Core fields:

- id
- tenant_id
- conversation_id
- sender_type_code
- sender_user_id nullable
- message_direction_code
- message_text nullable
- external_message_id nullable
- sent_at nullable
- received_at nullable
- metadata jsonb nullable
- created_at

Rules:

- Integration-specific payload may stay in metadata.
- Business-critical outcomes should be recorded in lead_interactions and events.

---

# 4. Booking And Travel Tables

## passengers

Purpose:

Represents travelers.

Core fields:

- id
- tenant_id
- customer_id nullable
- first_name
- family_name
- full_name
- passenger_type_code
- relationship_to_customer_code nullable
- date_of_birth nullable
- nationality_code nullable
- passport_number nullable
- passport_issue_date nullable
- passport_expiry_date nullable
- visa_number nullable
- visa_issue_date nullable
- visa_expiry_date nullable
- passport_issuing_country_code nullable
- created_at
- updated_at
- is_archived
- archived_at
- archived_by
- archive_reason

Notes:

- Passenger relationship improves customer history and future booking context.
- Add indexes on `passport_expiry_date` and `visa_expiry_date` for operational expiry searches.

Rules:

- passport_issue_date, when both fields are populated, must be earlier than passport_expiry_date.

## bookings

Purpose:

Booking container.

Core fields:

- id
- tenant_id
- branch_id
- department_id
- owner_user_id nullable
- owner_department_id nullable
- owner_branch_id nullable
- lead_id nullable
- quotation_id nullable
- customer_id
- booking_status_code
- title
- booking_reference (unique per tenant — migration 048800)
- travel_start_date nullable
- travel_end_date nullable
- destination_country_code nullable
- destination_city nullable
- created_by
- created_at
- updated_at
- completed_at nullable
- cancelled_at nullable
- is_archived
- archived_at
- archived_by
- archive_reason

## booking_items

Purpose:

One service inside booking.

Core fields:

- id
- tenant_id
- booking_id
- service_type_code
- base_status_code
- sub_status_code nullable
- supplier_id nullable
- operational_owner_user_id nullable
- owner_user_id nullable
- owner_department_id nullable
- owner_branch_id nullable
- sales_owner_user_id nullable
- sales_owner_department_id nullable
- sales_owner_branch_id nullable
- currency_code
- cost_amount numeric
- selling_amount numeric
- commission_rate numeric nullable
- exchange_rate_id nullable
- finance_approval_required boolean
- finance_approval_status_code nullable
- cancellation_reason_code nullable
- cancelled_at nullable
- cancelled_by nullable
- no_show_at nullable
- no_show_recorded_by nullable
- cost_locked_at nullable
- issued_at nullable
- completed_at nullable
- created_by
- created_at
- updated_at
- is_archived
- archived_at
- archived_by
- archive_reason

Notes:

- Booking items may be cancelled or marked no-show independently of parent booking state.
- Operational ownership changes should be recorded as events; a separate ownership history table is not required in this draft.
- `commission_rate` reserves a lightweight path for future sales commission calculation without creating a payroll model.

Rules:

- cost_amount and selling_amount must not be negative.

## booking_item_passengers

Purpose:

Links passengers to booking items.

Core fields:

- id
- tenant_id
- booking_item_id
- passenger_id
- selling_amount_override numeric nullable
- cost_amount_override numeric nullable
- created_at

Unique:

- booking_item_id + passenger_id

Rules:

- selling_amount_override and cost_amount_override, when populated, represent this passenger's individual price/cost within the shared booking_item. When null, the passenger's share is treated as an even split of the parent booking_item's selling_amount/cost_amount.
- Where populated, these fields must not be negative, consistent with the equivalent rule on booking_items.

## suppliers

Purpose:

Service providers.

Core fields:

- id
- tenant_id
- supplier_type_code
- name
- phone nullable
- email nullable
- payment_term_code nullable
- credit_limit_amount numeric nullable
- credit_limit_currency_code nullable — required exactly when `credit_limit_amount` is present (SUP-4a, `202607059900`). Canon 30's money standard: an amount is stored beside its currency, referencing `currencies.code`. This was the only money column in the schema without one, which is what made the ceiling incomparable to `app.supplier_balance`'s per-currency payable.
- is_internal
- internal_branch_id nullable
- internal_department_id nullable
- created_at
- updated_at
- is_archived
- archived_at
- archived_by
- archive_reason

## internal_supplier_links

Purpose:

Tracks internal department-to-department service.

Core fields:

- id
- tenant_id
- booking_item_id
- provider_branch_id
- provider_department_id
- requester_branch_id
- requester_department_id
- created_at

---

# 5. Finance Tables

## chart_of_accounts

Purpose:

Tenant chart of accounts.

Core fields:

- id
- tenant_id
- code
- name
- parent_account_id nullable
- account_type
- is_system_default
- is_active
- created_at
- updated_at

## financial_accounts

Purpose:

Bank and cash accounts.

Core fields:

- id
- tenant_id
- financial_account_type_code
- name
- currency_code
- opening_balance numeric
- is_active
- created_at
- updated_at

## journal_entries

Purpose:

Financial entries.

Core fields:

- id
- tenant_id
- source_type_code
- source_entity_id nullable
- entry_date
- description
- created_by
- created_at
- is_voided
- voided_at nullable
- voided_by nullable
- void_reason nullable

## journal_entry_lines

Purpose:

Debit/credit lines.

Core fields:

- id
- tenant_id
- journal_entry_id
- chart_account_id
- debit_amount numeric
- credit_amount numeric
- currency_code
- description
- created_at

Rules:

- Exactly one of debit_amount or credit_amount must be populated per row (the other must be null or zero). A row with both populated, or neither, is invalid.

## invoices

Purpose:

Customer invoices.

Core fields:

- id
- tenant_id
- customer_id
- booking_id nullable
- booking_item_id nullable
- invoice_number
- invoice_date
- due_date nullable
- currency_code
- total_amount numeric (>= 0, non-negative CHECK — migration 048800)
- status_code
- voided_at nullable
- voided_by nullable
- void_reason nullable
- external_submission_id nullable
- external_submission_status_code nullable
- external_submitted_at nullable
- external_response_at nullable
- created_by
- created_at
- updated_at
- is_archived
- archived_at
- archived_by
- archive_reason

## payments

Purpose:

Customer and supplier payments.

Core fields:

- id
- tenant_id
- payment_direction_code
- customer_id nullable
- supplier_id nullable
- booking_id nullable
- booking_item_id nullable
- financial_account_id nullable
- payment_method_code
- reference_number nullable
- currency_code
- amount numeric (>= 0, non-negative CHECK — migration 048800)
- paid_at
- received_by nullable
- verified_by nullable
- verified_at nullable
- created_by
- created_at
- updated_at

## payment_allocations

Purpose:

Links a payment to the specific invoice(s) it settles, supporting partial and installment payments against a single invoice, including cross-currency settlement.

Core fields:

- id
- tenant_id
- payment_id
- invoice_id
- allocated_amount numeric (>= 0, non-negative CHECK — migration 048800)
- currency_code
- exchange_rate_id nullable
- allocated_amount_invoice_currency numeric nullable
- created_by
- created_at

Notes:

- One payment may be allocated across multiple invoices; one invoice may receive allocations from multiple payments.
- sum(allocated_amount_invoice_currency) (or allocated_amount when no currency conversion applies) across all allocations for one invoice must not exceed that invoice's total_amount. This is an application/SQL-level rule, not a new table constraint description.
- invoice_status_code values partially_paid and paid are derived from the sum of this table's allocated amounts for the invoice, compared against invoices.total_amount.
- currency_code records the currency the payment was actually made in (matching payments.currency_code).
- exchange_rate_id (referencing exchange_rates) and allocated_amount_invoice_currency are populated only when the payment's currency differs from the invoice's currency, following the same pattern already established by booking_items.exchange_rate_id. When the payment and invoice share the same currency, both fields remain null and allocated_amount alone is authoritative.

## receipts

Purpose:

Proof of payment received.

Core fields:

- id
- tenant_id
- payment_id
- receipt_number
- issued_at
- external_submission_id nullable
- external_submission_status_code nullable
- external_submitted_at nullable
- external_response_at nullable
- created_by
- created_at

## refunds

Purpose:

Refunds to customers or from suppliers.

Core fields:

- id
- tenant_id
- payment_direction_code
- original_payment_id nullable
- customer_id nullable
- supplier_id nullable
- booking_id nullable
- booking_item_id nullable
- refund_reason_code nullable
- currency_code
- amount numeric (>= 0, non-negative CHECK — migration 048800)
- refund_status_code
- requested_at
- completed_at nullable
- created_by
- created_at
- updated_at

## approval_requests

Purpose:

Generic approval workflow for operational, finance, and sensitive actions.

Core fields:

- id
- tenant_id
- approval_type_code
- approval_status_code
- requested_by
- reviewed_by nullable
- related_entity_type
- related_entity_id
- booking_item_id nullable
- document_id nullable
- requested_at
- reviewed_at nullable
- reason nullable
- rejection_reason nullable
- payload jsonb nullable

Supported first-version approval types:

- finance_execution_approval
- refund_approval
- discount_approval
- booking_override
- manual_price_change
- sensitive_data_change
- subscription_approval

Notes:

- Booking items may still store `finance_approval_status_code` as a workflow summary.
- The approval record remains the source of review history.
- Finance execution approval uses `approval_type_code = finance_execution_approval`.
- Do not create a separate `finance_approvals` physical table unless implementation review proves it necessary.

## exchange_rates

Purpose:

Manual exchange rates.

Core fields:

- id
- tenant_id
- from_currency_code
- to_currency_code
- rate numeric
- effective_at
- set_by
- created_at

## exchange_rate_adjustments

Purpose:

Post-lock exchange rate corrections.

Core fields:

- id
- tenant_id
- booking_item_id
- original_exchange_rate_id
- new_exchange_rate_id
- reason_code
- reason_text
- created_by
- created_at

## company_assets

Purpose:

Practical asset management.

Core fields:

- id
- tenant_id
- name
- asset_type
- purchase_date nullable
- purchase_amount numeric nullable
- currency_code nullable
- status
- created_at
- updated_at

---

# 6. Document Tables

## documents

Purpose:

Document metadata.

Core fields:

- id
- tenant_id
- document_type_code
- title
- current_version_id nullable
- lifecycle_status_code
- is_confidential boolean
- expires_at nullable
- created_by
- created_at
- updated_at
- is_archived
- archived_at
- archived_by
- archive_reason

## document_versions

Purpose:

Stored file versions.

Core fields:

- id
- tenant_id
- document_id
- version_number
- file_name
- file_type_code
- file_size
- storage_path
- uploaded_by
- uploaded_at
- is_current

Rules:

- At most one document_versions row per document_id may have is_current = true.

## document_links

Purpose:

Links documents to business entities.

Core fields:

- id
- tenant_id
- document_id
- passenger_id nullable
- booking_id nullable
- booking_item_id nullable
- invoice_id nullable
- quotation_id nullable
- receipt_id nullable
- supplier_id nullable
- subscription_payment_proof_id nullable
- created_by
- created_at

Rules:

- Exactly one target FK should be set per row.
- This avoids weak polymorphic document links for MVP.
- This rule must be enforced as a database-level constraint at SQL migration time, not only as an application-layer check.

---

# 7. Event And Notification Tables

## events

Purpose:

Immutable business event log.

Core fields:

- id
- tenant_id nullable for platform events
- event_type_code
- severity_code
- actor_user_id nullable
- entity_type
- entity_id
- previous_state nullable
- new_state nullable
- reason nullable
- payload jsonb nullable
- created_at
- seq bigint identity (monotonic consumer cursor for automation/outbox readers — migration 049000)

Indexes:

- tenant_id + entity_type + entity_id + created_at
- tenant_id + event_type_code + created_at
- seq unique; tenant_id + seq (consumer read path — migration 049000)

Notes:

- The current event architecture remains unchanged.
- `event_links` is a future extension for events involving multiple business entities, not part of this schema.

## security_events

Purpose:

Authentication and permission audit.

Core fields:

- id
- tenant_id nullable
- user_id nullable
- security_event_type_code
- ip_address nullable
- user_agent nullable
- payload jsonb nullable
- created_at
- seq bigint identity (monotonic consumer cursor — migration 049000)

## notifications

Purpose:

In-system notifications.

Core fields:

- id
- tenant_id
- target_user_id
- notification_type_code
- title
- body
- related_entity_type nullable
- related_entity_id nullable
- is_read
- created_at
- read_at nullable

## notification_deliveries

Purpose:

Notification channel delivery tracking.

Core fields:

- id
- tenant_id
- notification_id
- channel_code
- delivery_status_code
- sent_at nullable
- failed_at nullable
- error_message nullable
- created_at

---

# 8. Subscription Tables

## subscription_plans

Purpose:

Defines Starter, Professional, Enterprise.

Core fields:

- id
- plan_code
- name
- description
- is_active
- created_at

Unique:

- plan_code (platform-global — no tenant scope; migration 048800)

## feature_entitlements

Purpose:

Defines plan features.

Core fields:

- id
- subscription_plan_id
- feature_code
- is_enabled
- limit_value nullable
- created_at

Unique:

- subscription_plan_id + feature_code (migration 048800)

## subscriptions

Purpose:

Tenant subscription history.

Core fields:

- id
- tenant_id
- subscription_plan_id
- subscription_status_code
- starts_at
- ends_at
- grace_ends_at nullable
- read_only_started_at nullable
- created_at
- updated_at

## subscription_payment_proofs

Purpose:

Bank transfer proof for renewal.

Core fields:

- id
- tenant_id
- subscription_id
- document_id
- uploaded_by
- reviewed_by nullable
- uploaded_at
- reviewed_at nullable
- status_code
- review_notes nullable

## usage_counters

Purpose:

Plan usage tracking.

Core fields:

- id
- tenant_id
- usage_metric_code
- period_start
- period_end
- used_value numeric
- limit_value numeric nullable
- updated_at

Unique:

- tenant_id + usage_metric_code + period_start + period_end (migration 048800)

---

# 9. Authentication Support Tables

Identity ownership (amended per `34_authentication_and_identity_principles.md`, Principles 1/6/7): these tables prove *who the human is* and therefore belong to the Human Identity (`auth.users`), not to a tenant membership. Each is keyed by `auth_user_id` referencing `auth.users(id)` and carries **no** `tenant_id` and no membership `user_id`. Deletion of the human identity cascades to these rows (`on delete cascade`, an explicit opt-in to the Referential Action Standard, since a device/OTP/TOTP record has no meaning without its human). The requirement to present a factor remains role-driven through RBAC, independent of where the artifact is stored.

## trusted_devices

Purpose:

Stores verified devices.

Core fields:

- id
- auth_user_id
- device_identifier
- status_code
- first_seen_at
- last_seen_at
- verified_at nullable
- revoked_at nullable
- created_at

## otp_challenges

Purpose:

Email OTP challenges.

Core fields:

- id
- auth_user_id
- status_code
- sent_to_email
- expires_at
- verified_at nullable
- failed_attempts
- created_at

## totp_enrollments

Purpose:

Authenticator app enrollment.

Core fields:

- id
- auth_user_id
- is_active
- enrolled_at
- revoked_at nullable
- created_at

Security note:

Actual secrets must be stored securely according to implementation security standards, not exposed in logs or normal queries.

---

# 10. Marketing And Offline Conversion Tables

## marketing_campaigns

Purpose:

Represents advertising campaigns tracked by ORVION.

Core fields:

- id
- tenant_id
- platform_code
- external_campaign_id nullable
- campaign_name
- status_code nullable
- started_at nullable
- ended_at nullable
- created_at
- updated_at

Notes:

- This supports Marketing Dashboard without implementing full ad platform management.

## campaign_daily_metrics

Purpose:

Stores daily marketing performance values.

Core fields:

- id
- tenant_id
- marketing_campaign_id
- metric_date
- spend_amount numeric nullable
- currency_code nullable
- impressions numeric nullable
- clicks numeric nullable
- leads_count numeric nullable
- bookings_count numeric nullable
- revenue_amount numeric nullable
- created_at
- updated_at

Notes:

- Metrics may be imported from integrations or calculated internally.
- Detailed analytics can remain deferred.

## attribution_clicks

Purpose:

Captured advertising click/session data.

Core fields:

- id
- tenant_id
- lead_id nullable
- attribution_source_code
- marketing_campaign_id nullable
- gclid nullable
- gbraid nullable (iOS/app-campaign Google click id)
- wbraid nullable (web-to-app Google click id)
- session_id nullable
- click_id nullable
- consent_ad_user_data nullable (Google consent-mode signal: granted/denied/unspecified)
- consent_ad_personalization nullable (Google consent-mode signal: granted/denied/unspecified)
- landing_page_url nullable
- utm_source nullable
- utm_medium nullable
- utm_campaign nullable
- utm_content nullable
- utm_term nullable
- clicked_at
- created_at

## offline_conversions

Purpose:

Internal business conversion event prepared for external upload.

Core fields:

- id
- tenant_id
- lead_id nullable
- booking_id nullable
- booking_item_id nullable
- payment_id nullable
- attribution_click_id nullable
- marketing_campaign_id nullable
- conversion_event_type_code
- conversion_value numeric nullable
- currency_code nullable
- conversion_at
- created_at

## offline_conversion_deliveries

Purpose:

Tracks external delivery attempts.

Core fields:

- id
- tenant_id
- offline_conversion_id
- platform_code
- delivery_status_code
- attempt_number
- sent_at nullable
- failed_at nullable
- response_payload jsonb nullable
- error_message nullable
- created_at

---

# 11. Table Classification Summary

## Configuration

- catalog_types
- catalog_values
- currencies
- roles
- permissions
- role_permissions
- subscription_plans
- feature_entitlements

## Core Business

- tenants
- branches
- departments
- users
- user_branch_assignments
- user_role_assignments
- leads
- lead_assignments
- lead_interactions
- customers
- customer_contact_methods
- customer_identity_signals
- customer_identity_merges
- customer_notes
- tasks
- complaints
- service_requests
- quotations
- quotation_items
- conversations
- conversation_messages
- passengers
- bookings
- booking_items
- booking_item_passengers
- suppliers
- internal_supplier_links
- branch_business_hours
- holidays

## Financial

- chart_of_accounts
- financial_accounts
- journal_entries
- journal_entry_lines
- invoices
- payments
- payment_allocations
- receipts
- refunds
- approval_requests
- exchange_rates
- exchange_rate_adjustments
- company_assets

## System

- documents
- document_versions
- document_links
- events
- notifications
- notification_deliveries
- subscriptions
- subscription_payment_proofs
- usage_counters

## Security

- security_events
- trusted_devices
- otp_challenges
- totp_enrollments

## Integration

- marketing_campaigns
- campaign_daily_metrics
- attribution_clicks
- offline_conversions
- offline_conversion_deliveries

---

# 12. Future Extension Notes

## event_links

Do not implement now.

Potential future purpose:

Support events that involve multiple business entities with stronger querying than a single `entity_type` and `entity_id`.

Example future use cases:

- Payment received for booking and customer.
- Document uploaded for passenger and booking item.
- Refund approved for payment, booking, and supplier.

Current decision:

Keep `events` as-is for MVP.

Add `event_links` only if implementation shows real timeline/reporting limitations.

---

# 13. Review Required

The following decisions are acceptable for MVP but should be reviewed before SQL migration:

1. `events` uses polymorphic entity fields. This is practical for timeline/audit.
2. `catalog_values` combines system and tenant values. This is simple, but requires careful constraints.
3. RESOLVED (consolidated into `35_tenant_isolation_and_data_access_principles.md`): a `users` row is a human's membership in one tenant; `auth.users` is the shared human identity (one login per person). `auth_user_id` is unique per tenant (a human may hold memberships in several tenants, each a separate `users` row), nullable, and set on activation. Supabase Auth is the authentication identity; `users` is ORVION's business profile layer. Authorization remains entirely inside ORVION RBAC (`roles`, `permissions`, `role_permissions`, `user_role_assignments`) — the JWT issued by Supabase Auth is authentication-only and is never the authoritative source of business permissions. RLS resolves authorization through `auth.uid()` and a `SECURITY DEFINER` lookup function against the current ORVION RBAC tables, not through JWT claims. The physical key strategy implementing this relationship is a project-wide convention, defined in `30_database_conventions.md`'s Identity Key Standard, and is not part of this architectural statement. This decision applies to future SQL migrations, RLS implementation, and authorization logic unless a future approved Change Request explicitly supersedes it.
4. Finance is journal-based, but advanced statements are deferred.
5. `approval_requests` is now generic. Finance execution approval should use this table instead of a separate physical finance approvals table.
6. `document_links` now uses explicit nullable target FKs instead of polymorphic target fields. SQL migration should enforce exactly one target per row.
7. Logical schema is frozen as the working baseline after this review. No additional schema redesign should happen unless implementation reveals a real problem.
8. Version 0.4 closed the Phase 1 Domain & Schema Audit findings via SPEC-002 and SPEC-003 (see changes/): added `currencies`, `payment_allocations`, and `customer_identity_merges`; added missing columns to `journal_entry_lines`, `invoices`, `booking_item_passengers`, `bookings`, `conversations`, `attribution_clicks`, `offline_conversions`, and `document_links`; documented five previously-unenforced constraints as table-level Rules (journal debit/credit exclusivity, booking_items and booking_item_passengers non-negative amounts, document_links single-target, document_versions single-current-version); and corrected the Table Classification Summary. State machines, events, and permissions for the CRM-extension entities (Task, Quotation, Conversation, Complaint, Service Request, Marketing Campaign) remain open and are explicitly deferred to the Phase 2 Catalog & Lifecycle Audit — no changes to `26_state_machines.md`, `27_event_catalog.md`, or `28_permissions_matrix.md` have been made as of this entry.

---

# Next Step

Create SQL migration plan.
