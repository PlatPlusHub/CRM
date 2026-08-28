# ORVION -- Master API Capability Contract

Class: Reference (GENERATED -- do not hand-edit; see SS0)
Generated: by `scripts/generate-api-contract.ps1` from the live local database

---

## 0. How this file is produced, and why it is generated

Every row below is DERIVED from `pg_catalog` and `app.status_transitions`. Nothing here is
hand-maintained, because a hand-maintained interface document is a claim about the system, and
this programme has repeatedly found that an unverified claim is worse than none -- SEC-1b was a
ceiling whose predicate did not measure what its description said.

`scripts/check_database_parity.ps1` regenerates this file and FAILS if the committed copy
differs, the same way Check 7 keeps `ai-map.json` honest. Regenerate with:

```
pwsh -File scripts/generate-api-contract.ps1
```

Where a property cannot be derived from the database -- what a request field MEANS to the
business, what a caller should DO about an error -- this contract says so rather than inventing.

## 1. Platform rules (true for every endpoint; not repeated per row)

| Property | Rule |
|---|---|
| Transport | PostgREST at `/rest/v1`. Only the `public` and `graphql_public` schemas are exposed; `app` is not (API-1). |
| Authentication | Supabase JWT in `Authorization: Bearer`, plus the `apikey` header. `anon` holds no privilege on any table or endpoint. |
| Tenant | Never a parameter. Derived from the JWT by `app.current_tenant_id()`. A caller cannot name another tenant. |
| Step-up | `app.authorize` composes MFA. `owner`, `ceo`, `finance_manager` and `system_administrator` require `aal2`; a missing claim raises 42501. |
| RPC method | `POST /rest/v1/rpc/<name>`, JSON body of named arguments. |
| Void return | HTTP **204 No Content** is success, not failure. |
| Error shape | PostgreSQL error surfaced as JSON `{code, message, details, hint}`. `42501` = permission/authorization; `23514` = check/catalog violation; `23503` = foreign key; `P0001` = business rule raised by an RPC. |
| Pagination | Table and view reads: `?limit=&offset=` or the `Range` header. RPCs return whole sets. |
| Filtering / sorting | Table and view reads: PostgREST operators (`?col=eq.x`, `?order=col.desc`). |
| Row scope | RLS, always. A read returns an empty set rather than 403 when scope excludes the row -- so an empty result is NOT evidence of a missing endpoint. |

## 2. RPC endpoints

`permission` is read from the `app` implementation of the same name: a literal
`app.authorize('X')` where one exists; for the `advance_*` family the permissions come from
`app.status_transitions`, which is the source `app.enforce_status_transition` reads at runtime
(a literal regex misses these because they authorize a VARIABLE -- the same detector-shape mistake
SEC-1b was); `-` means no capability check, which for a read is correct and governed by RLS.

`http` is whether a `verify_*.ps1` suite actually calls the endpoint over the wire.

| endpoint | args | returns | sec | permission | inserts | updates | raises | http |
|---|---|---|---|---|---|---|---|---|
| `activate_membership` |  | `TABLE(membership_id uuid, tenant_id uuid, tenant_name text, is_active boolean)` | invoker | - | - | users | 2 | -- |
| `add_customer_contact_method` | p_customer_id uuid, p_contact_method_type_code text, p_value text, p_is_primary boolean | `uuid` | invoker | CREATE_CUSTOMER | customer_contact_methods | customer_contact_methods | 4 | -- |
| `add_customer_note` | p_customer_id uuid, p_note_text text, p_is_pinned boolean, p_is_confidential boolean | `uuid` | invoker | CREATE_CUSTOMER | customer_notes | - | 3 | -- |
| `add_document_version` | p_document_id uuid, p_file_name text, p_file_type_code text, p_file_size bigint | `uuid` | invoker | CREATE_DOCUMENT_VERSION | document_versions | document_versions, documents | 4 | yes |
| `add_quotation_item` | p_quotation_id uuid, p_service_type_code text, p_unit_price numeric, p_quantity numeric... | `uuid` | invoker | CREATE_QUOTATION | quotation_items | quotations | 5 | yes |
| `advance_booking` | p_booking_id uuid, p_to_status text, p_reason text | `text` | invoker | ALLOW_ISSUE_WITH_NEGATIVE_BALANCE + per transition: APPROVE_BOOKING, CANCEL_BOOKING, CREATE_BOOKING, ISSUE_BOOKING, REFUND_BOOKING, REISSUE_BOOKING | - | bookings | 5 | yes |
| `advance_booking_item` | p_booking_item_id uuid, p_to_status text, p_reason text, p_sub_status_code text, p_canc... | `text` | invoker | UPDATE_BOOKING_ITEM_STATUS + per transition: UPDATE_BOOKING_ITEM_STATUS | - | booking_items | 9 | yes |
| `advance_complaint` | p_complaint_id uuid, p_to_status text, p_reason text | `void` | invoker | per transition: RESOLVE_COMPLAINT | - | complaints | 3 | yes |
| `advance_conversation` | p_conversation_id uuid, p_to_status text, p_reason text | `void` | invoker | per transition: CLOSE_CONVERSATION, ESCALATE_CONVERSATION, SEND_MESSAGE | - | conversations | 3 | yes |
| `advance_lead` | p_lead_id uuid, p_to_status text, p_reason text, p_closure_reason_code text | `text` | invoker | CLOSE_LEAD + per transition: ASSIGN_LEAD, CLOSE_LEAD | - | leads | 7 | -- |
| `advance_marketing_campaign` | p_campaign_id uuid, p_to_status text, p_reason text | `void` | invoker | per transition: MANAGE_MARKETING_CAMPAIGN | - | marketing_campaigns | 3 | -- |
| `advance_quotation` | p_quotation_id uuid, p_to_status text, p_reason text | `text` | invoker | per transition: ACCEPT_QUOTATION, CREATE_QUOTATION, SEND_QUOTATION | - | quotations | 4 | yes |
| `advance_refund` | p_refund_id uuid, p_to_status text, p_reason text | `text` | invoker | RECORD_REFUND + per transition: RECORD_REFUND | - | refunds | 3 | yes |
| `advance_service_request` | p_service_request_id uuid, p_to_status text, p_reason text | `void` | invoker | per transition: RESOLVE_SERVICE_REQUEST | - | service_requests | 3 | yes |
| `advance_task` | p_task_id uuid, p_to_status text, p_reason text | `void` | invoker | per transition: COMPLETE_TASK | - | tasks | 3 | yes |
| `archive_document` | p_document_id uuid, p_reason text | `text` | invoker | ARCHIVE_DOCUMENT | - | documents | 4 | -- |
| `assign_lead` | p_lead_id uuid, p_assignee_user_id uuid, p_reason text | `uuid` | invoker | ASSIGN_LEAD | lead_assignments | leads | 4 | yes |
| `assign_lead_round_robin` | p_lead_id uuid, p_reason text | `uuid` | invoker | ASSIGN_LEAD | - | - | 4 | -- |
| `assign_task` | p_task_id uuid, p_owner_user_id uuid, p_owner_department_id uuid, p_owner_branch_id uui... | `void` | invoker | ASSIGN_TASK | - | tasks | 4 | -- |
| `assign_user_branch` | p_user_id uuid, p_branch_id uuid, p_department_id uuid, p_is_primary boolean, p_transfe... | `uuid` | invoker | MANAGE_USERS | user_branch_assignments | - | 4 | -- |
| `assign_user_role` | p_user_id uuid, p_role_code text, p_scope_type text, p_branch_id uuid, p_department_id ... | `uuid` | invoker | MANAGE_USERS | user_role_assignments | - | 3 | yes |
| `convert_lead` | p_lead_id uuid, p_customer_id uuid, p_reason text | `uuid` | invoker | inline has_permission check | - | leads | 7 | -- |
| `create_booking` | p_customer_id uuid, p_lead_id uuid, p_title text, p_branch_id uuid, p_department_id uui... | `uuid` | invoker | CREATE_BOOKING | bookings | - | 10 | yes |
| `create_booking_item` | p_booking_id uuid, p_service_type_code text, p_currency_code text, p_cost_amount numeri... | `uuid` | invoker | CREATE_BOOKING_ITEM | booking_items | - | 9 | yes |
| `create_branch` | p_name text, p_slug text, p_branch_type text, p_primary_phone text, p_address text | `uuid` | invoker | MANAGE_BRANCHES | branches | - | 1 | yes |
| `create_complaint` | p_customer_id uuid, p_title text, p_complaint_category_code text, p_complaint_severity_... | `uuid` | invoker | CREATE_COMPLAINT | complaints | - | 6 | yes |
| `create_customer` | p_customer_type_code text, p_full_name text, p_first_name text, p_family_name text, p_c... | `uuid` | invoker | CREATE_CUSTOMER | customer_identity_signals, customers | - | 5 | yes |
| `create_department` | p_branch_id uuid, p_department_type_code text, p_name text | `uuid` | invoker | MANAGE_DEPARTMENTS | departments | - | 3 | -- |
| `create_invoice` | p_customer_id uuid, p_currency_code text, p_total_amount numeric, p_booking_id uuid, p_... | `uuid` | invoker | CREATE_INVOICE | invoices | - | 5 | yes |
| `create_journal_entry` | p_source_type_code text, p_entry_date date, p_description text, p_lines jsonb, p_source... | `uuid` | invoker | CREATE_JOURNAL_ENTRY | journal_entries, journal_entry_lines | - | 7 | -- |
| `create_lead` | p_branch_id uuid, p_department_id uuid, p_lead_source_code text, p_title text, p_priori... | `uuid` | invoker | CREATE_LEAD | leads | - | 6 | yes |
| `create_marketing_campaign` | p_campaign_name text, p_platform_code text, p_external_campaign_id text, p_started_at t... | `uuid` | invoker | MANAGE_MARKETING_CAMPAIGN | marketing_campaigns | - | 3 | -- |
| `create_passenger` | p_first_name text, p_family_name text, p_full_name text, p_passenger_type_code text, p_... | `uuid` | invoker | CREATE_BOOKING_ITEM | passengers | - | 7 | yes |
| `create_quotation` | p_customer_id uuid, p_currency_code text, p_lead_id uuid, p_valid_until timestamp with ... | `uuid` | invoker | CREATE_QUOTATION | quotations | - | 5 | yes |
| `create_service_request` | p_customer_id uuid, p_title text, p_service_request_type_code text, p_service_request_s... | `uuid` | invoker | CREATE_SERVICE_REQUEST | service_requests | - | 6 | yes |
| `create_supplier` | p_name text, p_supplier_type_code text, p_phone text, p_email text, p_payment_term_code... | `uuid` | invoker | ASSIGN_SUPPLIER | suppliers | - | 4 | yes |
| `create_task` | p_title text, p_task_type_code text, p_owner_user_id uuid, p_owner_department_id uuid, ... | `uuid` | invoker | CREATE_TASK | tasks | - | 7 | yes |
| `create_tenant_user` | p_full_name text, p_email text, p_phone text, p_auth_user_id uuid | `uuid` | invoker | MANAGE_USERS | users | - | 1 | -- |
| `current_placement` |  | `TABLE(branch_id uuid, department_id uuid)` | invoker | - | - | - | 0 | -- |
| `customer_timeline` | p_customer_id uuid | `TABLE(seq bigint, occurred_at timestamp with time zone, event_type_code text, entity_type text, entity_id uuid, actor_user_id uuid, previous_state text, new_state text, reason text, payload jsonb)` | invoker | - | - | - | 0 | yes |
| `expiring_documents` | p_within_days integer | `TABLE(document_id uuid, document_type_code text, title text, expires_at timestamp with time zone, days_until_expiry integer, is_confidential boolean)` | invoker | - | - | - | 2 | yes |
| `financial_documents` |  | `TABLE(document_id uuid, document_type_code text, title text, lifecycle_status_code text, is_confidential boolean, invoice_id uuid, receipt_id uuid)` | invoker | VIEW_FINANCIAL_DOCUMENTS | - | - | 1 | -- |
| `find_customer_duplicates` | p_phone text, p_email text, p_whatsapp text, p_passport_number text, p_document_number ... | `TABLE(customer_id uuid, full_name text, matched_signal_type text, matched_value text)` | invoker | - | - | - | 0 | -- |
| `issue_invoice` | p_invoice_id uuid, p_reason text | `text` | invoker | CREATE_INVOICE | - | invoices | 4 | yes |
| `issue_receipt` | p_payment_id uuid | `uuid` | invoker | CREATE_RECEIPT | receipts | - | 3 | yes |
| `lead_booking_readiness` | p_lead_id uuid | `TABLE(lead_id uuid, is_ready boolean, reason_code text, reason text, customer_id uuid, lead_status_code text, requested_service_type_code text, branch_id uuid, department_id uuid, assigned_user_id uuid, expected_value numeric, title text)` | invoker | - | - | - | 2 | -- |
| `lead_origin` | p_lead_id uuid | `TABLE(first_user_id uuid, first_assigned_at timestamp with time zone, current_user_id uuid, assignment_count integer)` | invoker | - | - | - | 0 | -- |
| `lead_timeline` | p_lead_id uuid | `TABLE(seq bigint, occurred_at timestamp with time zone, event_type_code text, entity_type text, entity_id uuid, actor_user_id uuid, previous_state text, new_state text, reason text, payload jsonb)` | invoker | - | - | - | 0 | -- |
| `link_internal_supplier` | p_booking_item_id uuid, p_provider_branch_id uuid, p_provider_department_id uuid, p_rea... | `uuid` | invoker | ASSIGN_SUPPLIER | internal_supplier_links | - | 5 | -- |
| `link_passenger_to_booking_item` | p_booking_item_id uuid, p_passenger_id uuid, p_selling_amount_override numeric, p_cost_... | `uuid` | invoker | CREATE_BOOKING_ITEM | booking_item_passengers | - | 7 | yes |
| `merge_customer_identity` | p_source_customer_id uuid, p_target_customer_id uuid, p_reason text | `uuid` | invoker | MERGE_CUSTOMER_IDENTITY | customer_identity_merges | customers | 5 | -- |
| `my_memberships` |  | `TABLE(membership_id uuid, tenant_id uuid, tenant_name text, is_active boolean)` | invoker | - | - | - | 0 | -- |
| `my_trusted_devices` |  | `TABLE(id uuid, device_identifier text, status_code text, first_seen_at timestamp with time zone, last_seen_at timestamp with time zone, verified_at timestamp with time zone, revoked_at timestamp with time zone)` | invoker | - | - | - | 0 | -- |
| `reassign_lead` | p_lead_id uuid, p_assignee_user_id uuid, p_reason text | `uuid` | invoker | REASSIGN_LEAD | lead_assignments | lead_assignments, leads | 6 | -- |
| `record_lead_interaction` | p_lead_id uuid, p_interaction_type_code text, p_summary text, p_metadata jsonb | `uuid` | invoker | inline has_permission check | lead_interactions | leads | 5 | yes |
| `record_offline_conversion` | p_conversion_event_type_code text, p_lead_id uuid, p_booking_id uuid, p_booking_item_id... | `uuid` | invoker | MANAGE_MARKETING_CAMPAIGN | offline_conversions | - | 6 | -- |
| `record_payment` | p_invoice_id uuid, p_amount numeric, p_payment_method_code text, p_paid_at timestamp wi... | `uuid` | invoker | RECORD_PAYMENT | payment_allocations, payments | invoices | 7 | yes |
| `record_refund` | p_customer_id uuid, p_amount numeric, p_currency_code text, p_refund_reason_code text, ... | `uuid` | invoker | RECORD_REFUND | refunds | - | 6 | yes |
| `record_supplier_payment` | p_supplier_id uuid, p_amount numeric, p_currency_code text, p_payment_method_code text,... | `uuid` | invoker | RECORD_PAYMENT | payments | - | 5 | yes |
| `record_trusted_device` | p_device_identifier text | `uuid` | invoker | - | trusted_devices | trusted_devices | 1 | -- |
| `redeem_license_token` | p_token text | `void` | invoker | MANAGE_TENANT_SETTINGS | security_events | tenant_license_activations | 2 | -- |
| `request_finance_approval` | p_booking_item_id uuid, p_reason text | `uuid` | invoker | CREATE_BOOKING_ITEM | approval_requests | booking_items | 5 | yes |
| `review_finance_approval` | p_approval_request_id uuid, p_decision text, p_reason text | `text` | invoker | APPROVE_FINANCE or CREATE_BOOKING_ITEM | - | approval_requests, booking_items | 6 | yes |
| `revoke_trusted_device` | p_device_id uuid | `void` | invoker | - | - | trusted_devices | 2 | -- |
| `revoke_user_role` | p_assignment_id uuid | `void` | invoker | MANAGE_USERS | - | user_role_assignments | 2 | -- |
| `seed_default_chart_of_accounts` |  | `integer` | invoker | CREATE_JOURNAL_ENTRY | chart_of_accounts | - | 1 | -- |
| `send_conversation_message` | p_conversation_id uuid, p_message_direction_code text, p_sender_type_code text, p_body ... | `uuid` | invoker | SEND_MESSAGE | conversation_messages | conversations | 3 | yes |
| `start_conversation` | p_channel_code text, p_customer_id uuid, p_lead_id uuid, p_booking_id uuid, p_booking_i... | `uuid` | invoker | SEND_MESSAGE | conversations | - | 5 | yes |
| `tenant_capabilities` |  | `TABLE(feature_code text, is_enabled boolean, limit_value numeric)` | invoker | - | - | - | 0 | -- |
| `upload_document` | p_document_type_code text, p_title text, p_file_name text, p_file_type_code text, p_lin... | `uuid` | invoker | UPLOAD_DOCUMENT | document_links, document_versions, documents | documents | 8 | yes |
| `upload_subscription_payment_proof` | p_file_name text, p_file_type_code text, p_file_size bigint, p_note text | `uuid` | invoker | MANAGE_TENANT_SETTINGS | document_links, document_versions, documents, subscription_payment_proofs | documents | 4 | -- |

**71 RPC endpoints executable by `authenticated`; 38 exercised over HTTP by a suite.**

## 3. Reporting views

| view | columns | security | select |
|---|---|---|---|
| `reporting.booking_item_profit` | 7 | invoker | authenticated |
| `reporting.booking_pipeline` | 5 | invoker | authenticated |
| `reporting.customer_outstanding` | 8 | invoker | authenticated |
| `reporting.lead_performance` | 7 | invoker | authenticated |
| `reporting.my_sales_performance` | 22 | invoker | authenticated |
| `reporting.sales_activity` | 5 | invoker | authenticated |
| `reporting.subscription_state` | 10 | invoker | authenticated |
| `reporting.supplier_outstanding` | 7 | invoker | authenticated |

## 4. The table surface -- the other half of the door

PostgREST serves TABLES as well as RPCs, so `POST /rest/v1/complaints` is as reachable from a
browser as `POST /rest/v1/rpc/create_complaint`. A contract covering only the RPCs would describe
a minority of what a client can touch; SEC-1b was found precisely here.

`insert guard` requires a trigger that FIRES ON INSERT and charges capability.
`update guard` says **conditional** where such a trigger exists but returns early unless a status
or archive flag changes -- so a DESCRIPTIVE edit passes it. That is SEC-2, and it is stated as
`conditional` rather than `yes` deliberately.

| table | SIUD | insert guard | update guard | RLS policies |
|---|---|---|---|---|
| `approval_requests` | `SIU-` | yes | no | scope_insert, scope_read, scope_update |
| `attribution_clicks` | `S---` | no | no | tenant_isolation |
| `booking_item_passengers` | `-IU-` | yes | conditional | scope_isolation |
| `booking_items` | `-IU-` | yes | conditional | scope_isolation |
| `bookings` | `SIU-` | yes | conditional | scope_isolation |
| `branch_business_hours` | `SIU-` | yes | conditional | tenant_isolation |
| `branches` | `SIU-` | no | no | scope_delete, scope_insert, scope_read, scope_update |
| `campaign_daily_metrics` | `SIU-` | no | no | scope_isolation |
| `catalog_types` | `S---` | no | no | read_all_authenticated |
| `catalog_values` | `SIU-` | no | no | catalog_read, catalog_tenant_delete, catalog_tenant_insert, catalog_tenant_update |
| `chart_of_accounts` | `SIU-` | no | no | scope_delete, scope_insert, scope_read, scope_update |
| `company_assets` | `SIU-` | yes | conditional | tenant_isolation |
| `complaints` | `SIU-` | yes | conditional | scope_isolation |
| `conversation_messages` | `SIU-` | yes | conditional | scope_isolation |
| `conversations` | `SIU-` | yes | conditional | scope_isolation |
| `countries` | `S---` | no | no | read_all_authenticated |
| `currencies` | `S---` | no | no | read_all_authenticated |
| `customer_contact_methods` | `SIU-` | yes | conditional | tenant_isolation |
| `customer_identity_merges` | `SIU-` | yes | conditional | tenant_isolation |
| `customer_identity_signals` | `SIU-` | yes | conditional | tenant_isolation |
| `customer_notes` | `SIU-` | yes | conditional | scope_isolation |
| `customers` | `SIU-` | yes | conditional | tenant_isolation |
| `departments` | `SIU-` | no | no | scope_delete, scope_insert, scope_read, scope_update |
| `document_links` | `SIU-` | yes | conditional | scope_isolation |
| `document_versions` | `SIU-` | yes | conditional | scope_isolation |
| `documents` | `SIU-` | yes | conditional | scope_isolation |
| `events` | `S---` | no | no | audit_insert, audit_read |
| `exchange_rate_adjustments` | `SIU-` | no | no | scope_delete, scope_insert, scope_read, scope_update |
| `exchange_rates` | `SIU-` | no | no | scope_delete, scope_insert, scope_read, scope_update |
| `feature_entitlements` | `S---` | no | no | read_all_authenticated |
| `financial_accounts` | `SIU-` | yes | conditional | tenant_isolation |
| `holidays` | `SIU-` | yes | conditional | tenant_isolation |
| `internal_supplier_links` | `SIU-` | yes | conditional | tenant_isolation |
| `invoices` | `SIU-` | yes | conditional | scope_isolation |
| `journal_entries` | `SIU-` | no | no | scope_delete, scope_insert, scope_read, scope_update |
| `journal_entry_lines` | `SIU-` | no | no | scope_delete, scope_insert, scope_read, scope_update |
| `languages` | `S---` | no | no | read_all_authenticated |
| `lead_assignments` | `SIU-` | yes | conditional | scope_isolation |
| `lead_interactions` | `SIU-` | yes | conditional | scope_isolation |
| `leads` | `SIU-` | yes | conditional | scope_isolation |
| `marketing_campaigns` | `SIU-` | no | conditional | scope_isolation |
| `nationalities` | `S---` | no | no | read_all_authenticated |
| `notification_deliveries` | `S---` | no | no | scope_isolation |
| `notifications` | `S---` | no | no | scope_isolation |
| `offline_conversion_deliveries` | `S---` | no | no | tenant_isolation |
| `offline_conversions` | `SIU-` | yes | conditional | tenant_isolation |
| `otp_challenges` | `SIU-` | no | no | owner_only |
| `passengers` | `SIU-` | yes | conditional | tenant_isolation |
| `payment_allocations` | `SIU-` | yes | conditional | scope_isolation |
| `payments` | `SIU-` | yes | conditional | scope_isolation |
| `permissions` | `S---` | no | no | read_all_authenticated |
| `quotation_items` | `SIU-` | yes | conditional | scope_isolation |
| `quotations` | `SIU-` | yes | conditional | scope_isolation |
| `receipts` | `SIU-` | yes | conditional | scope_isolation |
| `refunds` | `SIU-` | yes | conditional | scope_isolation |
| `role_permissions` | `S---` | no | no | read_all_authenticated |
| `roles` | `S---` | no | no | read_all_authenticated |
| `security_events` | `S---` | no | no | audit_insert, audit_read |
| `service_requests` | `SIU-` | yes | conditional | scope_isolation |
| `subscription_payment_proofs` | `SIU-` | no | no | scope_insert, scope_read, scope_update |
| `subscription_plans` | `S---` | no | no | read_all_authenticated |
| `subscriptions` | `SIU-` | no | no | scope_delete, scope_insert, scope_read, scope_update |
| `suppliers` | `SIU-` | yes | conditional | tenant_isolation |
| `tasks` | `SIU-` | yes | conditional | scope_isolation |
| `tenants` | `SIU-` | no | no | scope_delete, scope_insert, scope_read, scope_update |
| `totp_enrollments` | `SIU-` | no | no | owner_only |
| `trusted_devices` | `SIU-` | no | no | owner_only |
| `usage_counters` | `S---` | no | no | tenant_isolation |
| `user_branch_assignments` | `SIU-` | no | no | scope_delete, scope_insert, scope_read, scope_update |
| `user_role_assignments` | `SIU-` | yes | conditional | scope_delete, scope_insert, scope_read, scope_update |
| `users` | `SIU-` | no | no | scope_delete, scope_insert, scope_read, scope_update |

## 5. Known exposure a client author must design around

- **SEC-2 (open, owner decision).** A role holding only VIEW permissions can UPDATE *descriptive*
  columns of rows already in its read scope. Reproduced: a `trainee` holding
  `CREATE_LEAD=f, CLOSE_LEAD=f` renamed the lead assigned to them. BOUNDED -- the same trainee
  could not see or edit a colleague-owned complaint (0 rows, `UPDATE 0`). Status transitions,
  monetary columns, acquisition attribution and assignment history are all separately guarded, so
  what remains reachable is non-governed descriptive text within scope.
- **No DELETE anywhere.** `authenticated` holds DELETE on zero tables. A client cannot destroy
  a row through any door; archival is an explicit, permissioned act.
- **Excluded on purpose (API-1).** `record_event` (audit forgery), `authorize` /
  `has_permission` / `current_tenant_id` (a permission-probing oracle) and every `platform_*`
  function are NOT exposed. A client cannot mint audit rows, probe the permission matrix, or
  elevate its own subscription.

## 6. What this contract does NOT establish

- Request-field SEMANTICS. Types and defaults are derived; what a field means to the business is
  in canon, not in `pg_catalog`.
- Remedies for business errors. The `raises` column counts the raise sites in each
  implementation; it does not say what a client should do about each one.
- Endpoints with `http = --` are NOT proven reachable. pgTAP proves database behaviour; only an
  HTTP suite proves the browser-facing door. API-1 was 600 green pgTAP assertions over an entirely
  unreachable API, and that is the standing reason this column exists.
