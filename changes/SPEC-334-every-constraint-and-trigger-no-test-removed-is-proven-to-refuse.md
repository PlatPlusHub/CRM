# Change Request — SPEC-334

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Pin every CRM database control that the EC-5 removal-mutation probe removed without failing a test, under the CRM `B6-EXIT` criteria EC-5 and EC-6. At 8a43a537cbd06cd9df6b636ac80fc1d658c1e88b the probe dropped each public check and unique control and disabled each RAISE-bearing row trigger in turn; 87 of the 365 valid mutants passed every test that names their table. Test 190 refuses the 72 check and unique constraints among them by name, Test 191 refuses the 13 triggers by their own message, and the other 2 are equivalent. The EC-5 reading cites the probe, and the EC-6 reading cites the negative sweep of the 101 member-writable doors and the 78 surfaces.

## Business Reason

EC-5's exit requires that no invariant be asserted in only one of the three places: a control that no test fails without can be dropped by a later migration while the whole suite still passes (DEC-33 rule 9). At 8a43a537cbd06cd9df6b636ac80fc1d658c1e88b (277 migrations, 189 test files) the probe found 72 check and unique constraints (NaN and sign guards on money columns, format and vocabulary checks, one-of and pairing rules, and tenant-scoped business keys) and 13 triggers (the subscription write gate on five tables, the write-capability guard on identity merges, the catalog-code check on six tables and the entity-reference check on notifications) whose removal no test noticed. EC-6's exit requires each sensitive surface to have at least one negative test; the sweep grades that and finds no gap.

## Risks

A refusal could come from a different control than the one named, so every assertion names the exact SQLSTATE and the exact constraint or trigger message, and Test 190 runs under `session_replication_role = replica` so no trigger or foreign key can refuse first. A test could pin a control that is never reached, so each of the 72 constraint drops and each of the 13 trigger disables must fail its own assertion. This contract changes no migration, function, policy, grant or database object. The probe does not mutate foreign keys, triggers without RAISE, function bodies or policies, so EC-5 stays partial; the sweep grades existence, not strength, so EC-6 stays partial; no exit criterion is marked met.

## Supersedes / Depends On

Extends the SPEC-333 door proof (Test 189), the SPEC-332 business-key proof (Test 188) and the SPEC-331 trigger catalog (Test 187). Uses the existing constraints and triggers at 8a43a537cbd06cd9df6b636ac80fc1d658c1e88b. Those terminal contracts are immutable.

## Write Scope

- `changes/SPEC-334-every-constraint-and-trigger-no-test-removed-is-proven-to-refuse.md`
- `supabase/tests/190_constraint_refusals_test.sql`
- `supabase/tests/191_trigger_enforcer_refusals_test.sql`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_API_CONTRACT.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `.github/workflows/repository-consistency.yml`
- `supabase/config.toml`

Migrations, product code, any Primary write, Founder Secondary, frontend work, integration activation, email delivery and every owner decision are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9.
- `reports/master/MASTER_EXECUTION_PLAN.md` the exit criteria EC-5 and EC-6.
- `supabase/tests/187_every_row_trigger_is_attached_where_its_contract_says_test.sql`.
- `supabase/tests/188_every_business_key_is_unique_and_every_event_type_is_registered_test.sql`.
- `supabase/tests/189_a_contact_method_change_is_refused_at_the_update_door_test.sql`.

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- github

## Additional Verification

- pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1
- pwsh -NoProfile -File scripts/test_future_date_guard.ps1
- pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1
- pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1
- pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1
- pwsh -NoProfile -File scripts/readiness_selftest.ps1

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Two new pgTAP tests, each rolled back at the end and declaring its attack classes for Check 24. Test 190 runs under `session_replication_role = replica`, so CHECK, UNIQUE and NOT NULL are enforced and no trigger or foreign key refuses first; its fixture rows hold the first key of each unique constraint, and each of its 72 assertions inserts one row that breaks one constraint and names its SQLSTATE and constraint. Test 191 builds an active and an expired tenant and a trainee; its 13 assertions name the exact SQLSTATE and message of the subscription write gate (5), the write-capability guard (1), the catalog-code check (6) and the entity-reference check (1). The plan and manifest record the result.

Pass 2 Adversarial Review: Each of the 72 constraints was dropped in turn inside Test 190's own transaction: 72 of 72 failed, each at its own one of 72 distinct assertions. Each of the 13 triggers was disabled in turn inside Test 191's transaction: 13 of 13 failed. The unmutated database passes 72 of 72 and 13 of 13. The 2 remaining survivors are equivalent: `user_role_assignments_scope_type_check` is implied by `user_role_assignments_scope_qualifier_check`, and the unique key `(tenant_id, id)` of `document_retention_policies` by its primary key. Fixture dates are past dates, so Check 12 stays clean.

Pass 3 Evidence Refresh: 2026-11-23. In an isolated clone at 8a43a537cbd06cd9df6b636ac80fc1d658c1e88b carrying the payload:
- Test 190 passed 72 of 72 and Test 191 13 of 13 on the local stack (277 migrations); the mutation sets failed 72 of 72 and 13 of 13.
- `readiness_population.ps1` reported REGISTRY complete with no COMPLETED member.
- Native repository consistency was CLEAN, Check 15 reading 191 files and 3591 assertions.
- All five hosted guard suites passed with 0 failed.

Selected Version: SPEC-334; selected: two adversarial pgTAP tests that refuse, by name, the 72 check and unique constraints and the 13 triggers the EC-5 removal-mutation probe removed at 8a43a53 without a failing test, with the plan and manifest records, the smallest change that pins every surviving non-equivalent control without any database change

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Constraint and trigger refusal proofs | Full pgTAP suite, Check 24 and the `B6-EXIT` gate evaluation | WRITE | Tests 190 and 191 add 85 assertions and name their attack classes; the suite grows to 191 files and 3591 assertions. |
| EC-5 and EC-6 readings | Exit criteria | WRITE | They cite the mutation probe, Tests 190 and 191 and the negative sweep; no criterion is marked met. |
| Surface disposition and register | Check 22 and Check 29 | UNAFFECTED | Every surface row is unchanged; no finding is added. |
| Schema, grants, policies and API | Every product consumer | UNAFFECTED | No migration; the API contract has the same blob as the baseline. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchors and exact payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Check 24 and the five hosted guard suites pass | BEFORE_COMPLETION | 1 | 4 | 5 |
| Full DATABASE readiness with Tests 190 and 191 | BEFORE_COMPLETION | NONE | NONE | 5 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: The pgTAP suite and its mutation-proven precedents, `supabase/tests/188_every_business_key_is_unique_and_every_event_type_is_registered_test.sql` and `supabase/tests/189_a_contact_method_change_is_refused_at_the_update_door_test.sql`.

Added Property: Each of the 72 named check and unique constraints refuses a row that breaks it, and each of the 13 named triggers refuses the write it exists to refuse, each with its exact SQLSTATE and message.

Causal Negative: At 8a43a537cbd06cd9df6b636ac80fc1d658c1e88b, removing any of these 85 controls passes every pgTAP file that names its table.

Positive Test Design: On the unmutated database Test 190 passes 72 of 72 and Test 191 13 of 13.

Negative Test Design: In a rolled-back transaction, dropping each constraint fails its own Test 190 assertion, and disabling each trigger fails its Test 191 assertion.

Non-Empty Population Obligation: Test 190's fixture rows hold the first key of each unique constraint, and Test 191's fixture holds an active and an expired `enterprise` tenant, a branch, a department and a trainee; a unique assertion fails on an empty population.

Mutation Obligation: The two mutation sets above must fail 72 of 72 and 13 of 13.

Post-Implementation Proof Obligation: The native Finish runs the full DATABASE protocol with Tests 190 and 191 and all five hosted guard suites through Additional Verification with zero failures. Hosted preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `supabase/tests/190_constraint_refusals_test.sql` contains `select plan(72);`; if so record Already Applied when its Git blob is 8ae13da46d8ced91c652dfcaec13dba2f7546f3f, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the constraint refusal test), and change nothing else:

   ```text
   -- pgTAP: Batch 6 exit -- seventy-two check and unique constraints that no test broke are proven to refuse, each by name.
   --
   -- EC-5: an invariant held in a database control must be proven by a test that fails when the control is removed. The
   --   EC-5 mutation probe at CRM 8a43a53 dropped each CHECK constraint and each UNIQUE constraint or index in turn and ran
   --   the pgTAP files that name its table; these seventy-two survived. A partial full-suite rerun killed seven of them
   --   only through Test 103, a sweep that reads constraint text, or Tests 91 and 107, which name none of their tables (an
   --   unattributed failure, not a proof). Each control already refuses (PROVEN on the local stack before this test was
   --   written); no test attempted a row that breaks it.
   --   Every assertion names the exact SQLSTATE (23514 for a check, 23505 for a unique key) and the exact constraint, so
   --   a refusal by any other control fails the assertion. The transaction runs with session_replication_role = replica,
   --   which disables triggers and foreign keys and leaves CHECK, UNIQUE and NOT NULL enforced, so each row isolates the
   --   one constraint it breaks: its other required columns carry placeholder values that no trigger or foreign key reads.
   --   The sixteen fixture rows below hold the first key of each unique constraint the assertions then repeat.
   --   No migration: this test pins the controls so a later change cannot drop one unseen.
   -- ATTACK-CLASSES: INPUT BUSINESS STATE AUTH=N/A PRIVILEGE=N/A TENANT=N/A DOOR=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(72);
   set local session_replication_role = replica;

   insert into public.tenants (name, slug, status) values ('x190_9', 'dup-slug-190', 'active');
   insert into public.roles (code, name) values ('dup_role_190', 'x190_19');
   insert into public.permissions (key, name) values ('DUP_KEY_190', 'x190_25');
   insert into public.role_permissions (role_id, permission_id) values ('c1900000-0000-0000-0000-000000000001', 'c1900000-0000-0000-0000-000000000002');
   insert into public.users (tenant_id, full_name, email, auth_user_id) values ('c1900000-0000-0000-0000-000000000003', 'x190_35', 'x190_36', 'c1900000-0000-0000-0000-000000000004');
   insert into public.users (tenant_id, full_name, email) values ('c1900000-0000-0000-0000-000000000003', 'x190_41', 'dup@a190.test');
   insert into public.document_versions (tenant_id, document_id, version_number, file_name, file_type_code, storage_path, is_current) values (gen_random_uuid(), 'c1900000-0000-0000-0000-000000000005', 1, 'x190_81', 'x190_82', 'x190_83', true);
   insert into public.invoices (tenant_id, customer_id, invoice_number, invoice_date, currency_code, status_code) values ('c1900000-0000-0000-0000-000000000003', gen_random_uuid(), 'INV-DUP-190', current_date, 'x190_151', 'x190_152');
   insert into public.receipts (tenant_id, payment_id, receipt_number) values ('c1900000-0000-0000-0000-000000000003', gen_random_uuid(), 'RCT-DUP-190');
   insert into public.events (event_type_code, severity_code, entity_type, entity_id, seq) overriding system value values ('x190_202', 'x190_203', 'x190_204', gen_random_uuid(), 990001901);
   insert into public.security_events (security_event_type_code, seq) overriding system value values ('x190_210', 990001902);
   insert into public.attribution_clicks (tenant_id, attribution_source_code, gbraid) values ('c1900000-0000-0000-0000-000000000003', 'x190_245', 'GB-DUP-190');
   insert into public.attribution_clicks (tenant_id, attribution_source_code, wbraid) values ('c1900000-0000-0000-0000-000000000003', 'x190_249', 'WB-DUP-190');
   insert into public.tenant_license_activations (tenant_id, token_hash, plan_code, billing_period_code, expires_at) values (gen_random_uuid(), 'dup-hash-190', 'x190_265', 'x190_266', now());
   insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect) values ('c1900000-0000-0000-0000-000000000003', 'c1900000-0000-0000-0000-000000000007', 'c1900000-0000-0000-0000-000000000002', 'deny');
   insert into public.customer_consents (tenant_id, customer_id, purpose_code, consent_status_code, channel_code, seq) overriding system value values (gen_random_uuid(), gen_random_uuid(), 'ad_user_data', 'granted', 'x190_305', 990001903);

   select throws_ok($s$insert into public.catalog_types (code, name) values ('Bad-Code', 'x190_2')$s$, '23514', 'new row for relation "catalog_types" violates check constraint "catalog_types_code_format_chk"', 'catalog_types_code_format_chk refuses a row that breaks it');
   select throws_ok($s$insert into public.currencies (code, name) values ('egx', 'x190_4')$s$, '23514', 'new row for relation "currencies" violates check constraint "currencies_code_format_chk"', 'currencies_code_format_chk refuses a row that breaks it');
   select throws_ok($s$insert into public.languages (code, name) values ('EN', 'x190_6')$s$, '23514', 'new row for relation "languages" violates check constraint "languages_code_format_chk"', 'languages_code_format_chk refuses a row that breaks it');
   select throws_ok($s$insert into public.nationalities (code, name) values ('eg', 'x190_8')$s$, '23514', 'new row for relation "nationalities" violates check constraint "nationalities_code_format_chk"', 'nationalities_code_format_chk refuses a row that breaks it');
   select throws_ok($s$insert into public.tenants (name, slug, status) values ('x190_12', 'dup-slug-190', 'active')$s$, '23505', 'duplicate key value violates unique constraint "tenants_slug_key"', 'tenants_slug_key refuses a second equal key');
   select throws_ok($s$insert into public.tenants (name, slug, status, trial_started_at) values ('x190_15', 'x190_16', 'active', now())$s$, '23514', 'new row for relation "tenants" violates check constraint "tenants_trial_dates_paired"', 'tenants_trial_dates_paired refuses a row that breaks it');
   select throws_ok($s$insert into public.roles (code, name) values ('dup_role_190', 'x190_21')$s$, '23505', 'duplicate key value violates unique constraint "roles_code_key"', 'roles_code_key refuses a second equal key');
   select throws_ok($s$insert into public.permissions (key, name, action_kind) values ('x190_22', 'x190_23', 'edit')$s$, '23514', 'new row for relation "permissions" violates check constraint "permissions_action_kind_check"', 'permissions_action_kind_check refuses a row that breaks it');
   select throws_ok($s$insert into public.permissions (key, name) values ('DUP_KEY_190', 'x190_27')$s$, '23505', 'duplicate key value violates unique constraint "permissions_key_key"', 'permissions_key_key refuses a second equal key');
   select throws_ok($s$insert into public.permissions (key, name, required_feature_code) values ('x190_28', 'x190_29', 'unknown_feature')$s$, '23514', 'new row for relation "permissions" violates check constraint "permissions_required_feature_code_check"', 'permissions_required_feature_code_check refuses a row that breaks it');
   select throws_ok($s$insert into public.role_permissions (role_id, permission_id) values ('c1900000-0000-0000-0000-000000000001', 'c1900000-0000-0000-0000-000000000002')$s$, '23505', 'duplicate key value violates unique constraint "role_permissions_role_permission_key"', 'role_permissions_role_permission_key refuses a second equal key');
   select throws_ok($s$insert into public.users (tenant_id, full_name, email, auth_user_id) values ('c1900000-0000-0000-0000-000000000003', 'x190_38', 'x190_39', 'c1900000-0000-0000-0000-000000000004')$s$, '23505', 'duplicate key value violates unique constraint "users_tenant_auth_key"', 'users_tenant_auth_key refuses a second equal key');
   select throws_ok($s$insert into public.users (tenant_id, full_name, email) values ('c1900000-0000-0000-0000-000000000003', 'x190_44', 'dup@a190.test')$s$, '23505', 'duplicate key value violates unique constraint "users_tenant_email_key"', 'users_tenant_email_key refuses a second equal key');
   select throws_ok($s$insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'branch')$s$, '23514', 'new row for relation "user_role_assignments" violates check constraint "user_role_assignments_scope_qualifier_check"', 'user_role_assignments_scope_qualifier_check refuses a row that breaks it');
   select throws_ok($s$insert into public.customer_identity_signals (tenant_id, customer_id, signal_type_code, signal_value) values (gen_random_uuid(), gen_random_uuid(), 'x190_52', ' padded ')$s$, '23514', 'new row for relation "customer_identity_signals" violates check constraint "customer_identity_signals_value_normalized_chk"', 'customer_identity_signals_value_normalized_chk refuses a row that breaks it');
   select throws_ok($s$insert into public.leads (tenant_id, branch_id, department_id, lead_source_code, lead_status_code, title, expected_value) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'x190_57', 'x190_58', 'x190_59', 'NaN')$s$, '23514', 'new row for relation "leads" violates check constraint "leads_no_nan_check"', 'leads_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.suppliers (tenant_id, supplier_type_code, name, credit_limit_amount, credit_limit_currency_code) values (gen_random_uuid(), 'x190_61', 'x190_62', 'NaN', 'EGP')$s$, '23514', 'new row for relation "suppliers" violates check constraint "suppliers_no_nan_check"', 'suppliers_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.passengers (tenant_id, first_name, family_name, full_name, passenger_type_code, passport_issue_date, passport_expiry_date) values (gen_random_uuid(), 'x190_64', 'x190_65', 'x190_66', 'x190_67', '2020-01-02', '2020-01-01')$s$, '23514', 'new row for relation "passengers" violates check constraint "passengers_passport_dates_check"', 'passengers_passport_dates_check refuses a row that breaks it');
   select throws_ok($s$insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code, legal_hold_active) values (gen_random_uuid(), 'x190_69', 'x190_70', 'x190_71', true)$s$, '23514', 'new row for relation "documents" violates check constraint "documents_legal_hold_evidence_check"', 'documents_legal_hold_evidence_check refuses a row that breaks it');
   select throws_ok($s$insert into public.document_links (tenant_id, document_id, passenger_id, booking_id) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$s$, '23514', 'new row for relation "document_links" violates check constraint "document_links_single_target_check"', 'document_links_single_target_check refuses a row that breaks it');
   select throws_ok($s$insert into public.document_storage_findings (tenant_id, finding_type_code) values (gen_random_uuid(), 'orphan_object')$s$, '23514', 'new row for relation "document_storage_findings" violates check constraint "document_storage_findings_path_present"', 'document_storage_findings_path_present refuses a row that breaks it');
   select throws_ok($s$insert into public.document_storage_findings (tenant_id, finding_type_code, resolved_at) values (gen_random_uuid(), 'tenant_scan_failed', now())$s$, '23514', 'new row for relation "document_storage_findings" violates check constraint "document_storage_findings_resolution_complete"', 'document_storage_findings_resolution_complete refuses a row that breaks it');
   select throws_ok($s$insert into public.document_versions (tenant_id, document_id, version_number, file_name, file_type_code, storage_path, is_current) values (gen_random_uuid(), 'c1900000-0000-0000-0000-000000000005', 1, 'x190_87', 'x190_88', 'x190_89', true)$s$, '23505', 'duplicate key value violates unique constraint "document_versions_one_current_idx"', 'document_versions_one_current_idx refuses a second equal key');
   select throws_ok($s$insert into public.quotations (tenant_id, customer_id, quotation_status_code, quotation_number, currency_code, total_amount) values (gen_random_uuid(), gen_random_uuid(), 'x190_92', 'x190_93', 'x190_94', 'NaN')$s$, '23514', 'new row for relation "quotations" violates check constraint "quotations_no_nan_check"', 'quotations_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, quantity) values (gen_random_uuid(), gen_random_uuid(), 'x190_97', 'x190_98', 'NaN')$s$, '23514', 'new row for relation "quotation_items" violates check constraint "quotation_items_no_nan_check"', 'quotation_items_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price) values (gen_random_uuid(), gen_random_uuid(), 'x190_101', 'x190_102', -1)$s$, '23514', 'new row for relation "quotation_items" violates check constraint "quotation_items_unit_price_nonneg_check"', 'quotation_items_unit_price_nonneg_check refuses a row that breaks it');
   select throws_ok($s$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code, currency_code, cost_amount) values (gen_random_uuid(), gen_random_uuid(), 'x190_105', 'x190_106', 'x190_107', -1)$s$, '23514', 'new row for relation "booking_items" violates check constraint "booking_items_amounts_nonneg_check"', 'booking_items_amounts_nonneg_check refuses a row that breaks it');
   select throws_ok($s$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code, currency_code, selling_amount) values (gen_random_uuid(), gen_random_uuid(), 'x190_110', 'x190_111', 'x190_112', 'NaN')$s$, '23514', 'new row for relation "booking_items" violates check constraint "booking_items_no_nan_check"', 'booking_items_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id, cost_amount_override) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'NaN')$s$, '23514', 'new row for relation "booking_item_passengers" violates check constraint "booking_item_passengers_no_nan_check"', 'booking_item_passengers_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at) values (gen_random_uuid(), 'x190_117', 'x190_118', 'NaN', now())$s$, '23514', 'new row for relation "exchange_rates" violates check constraint "exchange_rates_no_nan_check"', 'exchange_rates_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, currency_code, debit_amount, credit_amount) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'x190_124', 5, 5)$s$, '23514', 'new row for relation "journal_entry_lines" violates check constraint "journal_entry_lines_debit_xor_credit_check"', 'journal_entry_lines_debit_xor_credit_check refuses a row that breaks it');
   select throws_ok($s$insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, currency_code, debit_amount, credit_amount) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'x190_128', 'NaN', 0)$s$, '23514', 'new row for relation "journal_entry_lines" violates check constraint "journal_entry_lines_no_nan_check"', 'journal_entry_lines_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.invoices (tenant_id, customer_id, invoice_number, invoice_date, currency_code, status_code, id, corrects_invoice_id) values (gen_random_uuid(), gen_random_uuid(), 'x190_131', current_date, 'x190_133', 'x190_134', 'c1900000-0000-0000-0000-000000000006', 'c1900000-0000-0000-0000-000000000006')$s$, '23514', 'new row for relation "invoices" violates check constraint "invoices_corrects_not_self_check"', 'invoices_corrects_not_self_check refuses a row that breaks it');
   select throws_ok($s$insert into public.invoices (tenant_id, customer_id, invoice_number, invoice_date, currency_code, status_code, total_amount) values (gen_random_uuid(), gen_random_uuid(), 'x190_137', current_date, 'x190_139', 'x190_140', 'NaN')$s$, '23514', 'new row for relation "invoices" violates check constraint "invoices_no_nan_check"', 'invoices_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.invoices (tenant_id, customer_id, invoice_number, invoice_date, currency_code, status_code, total_amount) values (gen_random_uuid(), gen_random_uuid(), 'x190_143', current_date, 'x190_145', 'x190_146', -1)$s$, '23514', 'new row for relation "invoices" violates check constraint "invoices_total_amount_nonneg_check"', 'invoices_total_amount_nonneg_check refuses a row that breaks it');
   select throws_ok($s$insert into public.invoices (tenant_id, customer_id, invoice_number, invoice_date, currency_code, status_code) values ('c1900000-0000-0000-0000-000000000003', gen_random_uuid(), 'INV-DUP-190', current_date, 'x190_157', 'x190_158')$s$, '23505', 'duplicate key value violates unique constraint "invoices_tenant_number_key"', 'invoices_tenant_number_key refuses a second equal key');
   select throws_ok($s$insert into public.payments (tenant_id, payment_direction_code, payment_method_code, currency_code, amount) values (gen_random_uuid(), 'x190_160', 'x190_161', 'x190_162', -1)$s$, '23514', 'new row for relation "payments" violates check constraint "payments_amount_nonneg_check"', 'payments_amount_nonneg_check refuses a row that breaks it');
   select throws_ok($s$insert into public.payments (tenant_id, payment_direction_code, payment_method_code, currency_code, amount) values (gen_random_uuid(), 'x190_164', 'x190_165', 'x190_166', 'NaN')$s$, '23514', 'new row for relation "payments" violates check constraint "payments_no_nan_check"', 'payments_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.payments (tenant_id, payment_direction_code, payment_method_code, currency_code, account_amount) values (gen_random_uuid(), 'x190_168', 'x190_169', 'x190_170', -1)$s$, '23514', 'new row for relation "payments" violates check constraint "payments_account_amount_nonneg_check"', 'payments_account_amount_nonneg_check refuses a row that breaks it');
   select throws_ok($s$insert into public.payments (tenant_id, payment_direction_code, payment_method_code, currency_code, account_amount) values (gen_random_uuid(), 'x190_172', 'x190_173', 'x190_174', 'NaN')$s$, '23514', 'new row for relation "payments" violates check constraint "payments_account_amount_no_nan_check"', 'payments_account_amount_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.payment_allocations (tenant_id, payment_id, invoice_id, currency_code, allocated_amount) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'x190_178', -1)$s$, '23514', 'new row for relation "payment_allocations" violates check constraint "payment_allocations_amount_nonneg_check"', 'payment_allocations_amount_nonneg_check refuses a row that breaks it');
   select throws_ok($s$insert into public.payment_allocations (tenant_id, payment_id, invoice_id, currency_code, allocated_amount) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'x190_182', 'NaN')$s$, '23514', 'new row for relation "payment_allocations" violates check constraint "payment_allocations_no_nan_check"', 'payment_allocations_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.receipts (tenant_id, payment_id, receipt_number) values ('c1900000-0000-0000-0000-000000000003', gen_random_uuid(), 'RCT-DUP-190')$s$, '23505', 'duplicate key value violates unique constraint "receipts_tenant_number_key"', 'receipts_tenant_number_key refuses a second equal key');
   select throws_ok($s$insert into public.refunds (tenant_id, payment_direction_code, currency_code, refund_status_code, amount) values (gen_random_uuid(), 'x190_190', 'x190_191', 'x190_192', -1)$s$, '23514', 'new row for relation "refunds" violates check constraint "refunds_amount_nonneg_check"', 'refunds_amount_nonneg_check refuses a row that breaks it');
   select throws_ok($s$insert into public.refunds (tenant_id, payment_direction_code, currency_code, refund_status_code, amount) values (gen_random_uuid(), 'x190_194', 'x190_195', 'x190_196', 'NaN')$s$, '23514', 'new row for relation "refunds" violates check constraint "refunds_no_nan_check"', 'refunds_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.approval_requests (tenant_id, approval_type_code, approval_status_code, related_entity_type, related_entity_id, booking_item_id, document_id) values (gen_random_uuid(), 'x190_198', 'x190_199', 'x190_200', gen_random_uuid(), gen_random_uuid(), gen_random_uuid())$s$, '23514', 'new row for relation "approval_requests" violates check constraint "approval_requests_single_typed_subject_chk"', 'approval_requests_single_typed_subject_chk refuses a row that breaks it');
   select throws_ok($s$insert into public.events (event_type_code, severity_code, entity_type, entity_id, seq) overriding system value values ('x190_206', 'x190_207', 'x190_208', gen_random_uuid(), 990001901)$s$, '23505', 'duplicate key value violates unique constraint "events_seq_idx"', 'events_seq_idx refuses a second equal key');
   select throws_ok($s$insert into public.security_events (security_event_type_code, seq) overriding system value values ('x190_211', 990001902)$s$, '23505', 'duplicate key value violates unique constraint "security_events_seq_idx"', 'security_events_seq_idx refuses a second equal key');
   select throws_ok($s$insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code, attempt_number) values (gen_random_uuid(), gen_random_uuid(), 'x190_214', 'x190_215', 0)$s$, '23514', 'new row for relation "notification_deliveries" violates check constraint "notification_deliveries_attempt_number_positive"', 'notification_deliveries_attempt_number_positive refuses a row that breaks it');
   select throws_ok($s$insert into public.feature_entitlements (subscription_plan_id, feature_code, limit_value) values (gen_random_uuid(), 'crm', 'NaN')$s$, '23514', 'new row for relation "feature_entitlements" violates check constraint "feature_entitlements_no_nan_check"', 'feature_entitlements_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.usage_counters (tenant_id, usage_metric_code, period_start, period_end, used_value) values (gen_random_uuid(), 'x190_219', current_date, current_date, 'NaN')$s$, '23514', 'new row for relation "usage_counters" violates check constraint "usage_counters_no_nan_check"', 'usage_counters_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, spend_amount) values (gen_random_uuid(), gen_random_uuid(), current_date, 1)$s$, '23514', 'new row for relation "campaign_daily_metrics" violates check constraint "campaign_daily_metrics_amount_currency_pairing"', 'campaign_daily_metrics_amount_currency_pairing refuses a row that breaks it');
   select throws_ok($s$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, bookings_count) values (gen_random_uuid(), gen_random_uuid(), current_date, -1)$s$, '23514', 'new row for relation "campaign_daily_metrics" violates check constraint "campaign_daily_metrics_bookings_non_negative"', 'campaign_daily_metrics_bookings_non_negative refuses a row that breaks it');
   select throws_ok($s$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, clicks) values (gen_random_uuid(), gen_random_uuid(), current_date, -1)$s$, '23514', 'new row for relation "campaign_daily_metrics" violates check constraint "campaign_daily_metrics_clicks_non_negative"', 'campaign_daily_metrics_clicks_non_negative refuses a row that breaks it');
   select throws_ok($s$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, leads_count) values (gen_random_uuid(), gen_random_uuid(), current_date, -1)$s$, '23514', 'new row for relation "campaign_daily_metrics" violates check constraint "campaign_daily_metrics_leads_non_negative"', 'campaign_daily_metrics_leads_non_negative refuses a row that breaks it');
   select throws_ok($s$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, impressions) values (gen_random_uuid(), gen_random_uuid(), current_date, 'NaN')$s$, '23514', 'new row for relation "campaign_daily_metrics" violates check constraint "campaign_daily_metrics_no_nan_check"', 'campaign_daily_metrics_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.campaign_daily_metrics (tenant_id, marketing_campaign_id, metric_date, revenue_amount, currency_code) values (gen_random_uuid(), gen_random_uuid(), current_date, -1, 'EGP')$s$, '23514', 'new row for relation "campaign_daily_metrics" violates check constraint "campaign_daily_metrics_revenue_non_negative"', 'campaign_daily_metrics_revenue_non_negative refuses a row that breaks it');
   select throws_ok($s$insert into public.attribution_clicks (tenant_id, attribution_source_code, consent_ad_personalization) values (gen_random_uuid(), 'x190_241', 'yes')$s$, '23514', 'new row for relation "attribution_clicks" violates check constraint "attribution_clicks_consent_ad_personalization_check"', 'attribution_clicks_consent_ad_personalization_check refuses a row that breaks it');
   select throws_ok($s$insert into public.attribution_clicks (tenant_id, attribution_source_code, consent_ad_user_data) values (gen_random_uuid(), 'x190_243', 'yes')$s$, '23514', 'new row for relation "attribution_clicks" violates check constraint "attribution_clicks_consent_ad_user_data_check"', 'attribution_clicks_consent_ad_user_data_check refuses a row that breaks it');
   select throws_ok($s$insert into public.attribution_clicks (tenant_id, attribution_source_code, gbraid) values ('c1900000-0000-0000-0000-000000000003', 'x190_247', 'GB-DUP-190')$s$, '23505', 'duplicate key value violates unique constraint "attribution_clicks_unique_gbraid_idx"', 'attribution_clicks_unique_gbraid_idx refuses a second equal key');
   select throws_ok($s$insert into public.attribution_clicks (tenant_id, attribution_source_code, wbraid) values ('c1900000-0000-0000-0000-000000000003', 'x190_251', 'WB-DUP-190')$s$, '23505', 'duplicate key value violates unique constraint "attribution_clicks_unique_wbraid_idx"', 'attribution_clicks_unique_wbraid_idx refuses a second equal key');
   select throws_ok($s$insert into public.offline_conversions (tenant_id, conversion_event_type_code, conversion_value) values (gen_random_uuid(), 'x190_253', 'NaN')$s$, '23514', 'new row for relation "offline_conversions" violates check constraint "offline_conversions_no_nan_check"', 'offline_conversions_no_nan_check refuses a row that breaks it');
   select throws_ok($s$insert into public.offline_conversion_deliveries (tenant_id, offline_conversion_id, platform_code, delivery_status_code, provider_status_code) values (gen_random_uuid(), gen_random_uuid(), 'x190_256', 'x190_257', 'SUCCESS')$s$, '23514', 'new row for relation "offline_conversion_deliveries" violates check constraint "offline_conversion_deliveries_provider_status_vocabulary"', 'offline_conversion_deliveries_provider_status_vocabulary refuses a row that breaks it');
   select throws_ok($s$insert into public.tenant_license_activations (tenant_id, token_hash, plan_code, billing_period_code, expires_at, consumed_at, revoked_at) values (gen_random_uuid(), 'x190_259', 'x190_260', 'x190_261', now(), now(), now())$s$, '23514', 'new row for relation "tenant_license_activations" violates check constraint "tenant_license_activations_not_both_consumed_and_revoked"', 'tenant_license_activations_not_both_consumed_and_revoked refuses a row that breaks it');
   select throws_ok($s$insert into public.tenant_license_activations (tenant_id, token_hash, plan_code, billing_period_code, expires_at) values (gen_random_uuid(), 'dup-hash-190', 'x190_270', 'x190_271', now())$s$, '23505', 'duplicate key value violates unique constraint "tenant_license_activations_token_hash_key"', 'tenant_license_activations_token_hash_key refuses a second equal key');
   select throws_ok($s$insert into public.scheduled_job_findings (job_name, finding_type_code) values ('x190_273', 'item_lost')$s$, '23514', 'new row for relation "scheduled_job_findings" violates check constraint "scheduled_job_findings_finding_type_code_check"', 'scheduled_job_findings_finding_type_code_check refuses a row that breaks it');
   select throws_ok($s$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'allow')$s$, '23514', 'new row for relation "user_permission_grants" violates check constraint "user_permission_grants_effect_check"', 'user_permission_grants_effect_check refuses a row that breaks it');
   select throws_ok($s$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, starts_at, ends_at) values (gen_random_uuid(), gen_random_uuid(), gen_random_uuid(), 'grant', '2020-01-02', '2020-01-01')$s$, '23514', 'new row for relation "user_permission_grants" violates check constraint "user_permission_grants_period"', 'user_permission_grants_period refuses a row that breaks it');
   select throws_ok($s$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect) values ('c1900000-0000-0000-0000-000000000003', 'c1900000-0000-0000-0000-000000000007', 'c1900000-0000-0000-0000-000000000002', 'deny')$s$, '23505', 'duplicate key value violates unique constraint "user_permission_grants_unique"', 'user_permission_grants_unique refuses a second equal key');
   select throws_ok($s$insert into public.customer_consents (tenant_id, customer_id, purpose_code, consent_status_code, channel_code, evidence) values (gen_random_uuid(), gen_random_uuid(), 'ad_user_data', 'granted', 'x190_295', '   ')$s$, '23514', 'new row for relation "customer_consents" violates check constraint "customer_consents_evidence_check"', 'customer_consents_evidence_check refuses a row that breaks it');
   select throws_ok($s$insert into public.customer_consents (tenant_id, customer_id, purpose_code, consent_status_code, channel_code) values (gen_random_uuid(), gen_random_uuid(), 'marketing', 'granted', 'x190_300')$s$, '23514', 'new row for relation "customer_consents" violates check constraint "customer_consents_purpose_code_check"', 'customer_consents_purpose_code_check refuses a row that breaks it');
   select throws_ok($s$insert into public.customer_consents (tenant_id, customer_id, purpose_code, consent_status_code, channel_code, seq) overriding system value values (gen_random_uuid(), gen_random_uuid(), 'ad_user_data', 'granted', 'x190_310', 990001903)$s$, '23505', 'duplicate key value violates unique constraint "customer_consents_seq_key"', 'customer_consents_seq_key refuses a second equal key');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 8ae13da46d8ced91c652dfcaec13dba2f7546f3f.

2. Check whether `supabase/tests/191_trigger_enforcer_refusals_test.sql` contains `select plan(13);`; if so record Already Applied when its Git blob is e75f8c0425431f68ddb85e1e17f03611b07c3008, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the trigger refusal test), and change nothing else:

   ```text
   -- pgTAP: Batch 6 exit -- thirteen row triggers that no test removed are proven to refuse, each by its own message.
   --
   -- EC-5: an invariant held in a database control must be proven by a test that fails when the control is removed. The
   --   EC-5 mutation probe at CRM 8a43a53 disabled each of the RAISE-bearing row triggers in turn and ran the pgTAP suite;
   --   thirteen survived: the subscription write gate on customer_identity_merges, journal_entries, journal_entry_lines,
   --   notifications and attribution_clicks; the write-capability guard on customer_identity_merges; the catalog-code
   --   check on journal_entries, notifications, notification_deliveries, attribution_clicks,
   --   offline_conversion_deliveries and customer_consents; and the entity-reference check on notifications. Each
   --   control already refuses (PROVEN on the local stack before this test was written); no test named its refusal.
   --   Every assertion names the exact SQLSTATE and message its trigger raises, so a refusal by any other control (a
   --   later trigger, a NOT NULL, a foreign key) fails the assertion. A BEFORE row trigger raises before NOT NULL,
   --   CHECK and foreign key checks run, so the refused rows carry only the columns their trigger reads.
   --   Assertions 1-5: a tenant whose latest subscription is expired is refused on each gated table, reads unaffected.
   --   Assertion 6: a trainee of an active tenant, without MERGE_CUSTOMER_IDENTITY, is refused a merge record.
   --   Assertions 7-12: a code that is not an active value of its catalog family is refused on each table.
   --   Assertion 13: a notification naming a customer that does not exist in its tenant is refused.
   --   No migration: this test pins the controls so a later change cannot drop one unseen.
   -- ATTACK-CLASSES: AUTH PRIVILEGE STATE INPUT TENANT BUSINESS DOOR=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(13);

   insert into auth.users (id, email, email_confirmed_at) values
     ('c1910000-0000-0000-0000-0000000000a2','trainee@a191.test', now());
   insert into public.tenants (id, name, slug, status) values
     ('c1910000-0000-0000-0000-000000000001','A191 Travel','a191-travel','active'),
     ('c1910000-0000-0000-0000-000000000002','L191 Travel','l191-travel','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select t.id, sp.id, t.status
     from (values ('c1910000-0000-0000-0000-000000000001'::uuid,'active'),
                  ('c1910000-0000-0000-0000-000000000002'::uuid,'expired')) t(id, status)
    cross join public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('c1910000-0000-0000-0000-00000000000a','c1910000-0000-0000-0000-000000000001','Main A','a191-main');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('c1910000-0000-0000-0000-0000000000da','c1910000-0000-0000-0000-000000000001','c1910000-0000-0000-0000-00000000000a','sales','Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('c1910000-0000-0000-0000-000000000012','c1910000-0000-0000-0000-000000000001','Trainee A','trainee@a191.test',true,'c1910000-0000-0000-0000-0000000000a2');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
     ('c1910000-0000-0000-0000-000000000001','c1910000-0000-0000-0000-000000000012','c1910000-0000-0000-0000-00000000000a','c1910000-0000-0000-0000-0000000000da',true);
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select 'c1910000-0000-0000-0000-000000000001', 'c1910000-0000-0000-0000-000000000012', r.id, 'tenant'
     from public.roles r where r.code = 'trainee';

   -- 1-5. STATE: the subscription write gate refuses a tenant whose latest subscription is expired.
   select throws_ok(
     $$insert into public.customer_identity_merges (tenant_id) values ('c1910000-0000-0000-0000-000000000002')$$,
     '42501',
     'subscription state "expired" does not permit writes on public.customer_identity_merges (reads remain available so the tenant can inspect and export its own data)',
     'an expired tenant is refused a customer identity merge by the subscription write gate'
   );
   select throws_ok(
     $$insert into public.journal_entries (tenant_id, source_type_code) values ('c1910000-0000-0000-0000-000000000002', 'manual_entry')$$,
     '42501',
     'subscription state "expired" does not permit writes on public.journal_entries (reads remain available so the tenant can inspect and export its own data)',
     'an expired tenant is refused a journal entry by the subscription write gate'
   );
   select throws_ok(
     $$insert into public.journal_entry_lines (tenant_id) values ('c1910000-0000-0000-0000-000000000002')$$,
     '42501',
     'subscription state "expired" does not permit writes on public.journal_entry_lines (reads remain available so the tenant can inspect and export its own data)',
     'an expired tenant is refused a journal entry line by the subscription write gate'
   );
   select throws_ok(
     $$insert into public.notifications (tenant_id, notification_type_code) values ('c1910000-0000-0000-0000-000000000002', 'security_alert')$$,
     '42501',
     'subscription state "expired" does not permit writes on public.notifications (reads remain available so the tenant can inspect and export its own data)',
     'an expired tenant is refused a notification by the subscription write gate'
   );
   select throws_ok(
     $$insert into public.attribution_clicks (tenant_id, attribution_source_code) values ('c1910000-0000-0000-0000-000000000002', 'manual')$$,
     '42501',
     'subscription state "expired" does not permit writes on public.attribution_clicks (reads remain available so the tenant can inspect and export its own data)',
     'an expired tenant is refused an attribution click by the subscription write gate'
   );

   -- 6. PRIVILEGE: a trainee of an active tenant does not hold MERGE_CUSTOMER_IDENTITY and is refused a merge record.
   select set_config('request.jwt.claims', '{"sub":"c1910000-0000-0000-0000-0000000000a2"}', true);
   select throws_ok(
     $$insert into public.customer_identity_merges (tenant_id) values ('c1910000-0000-0000-0000-000000000001')$$,
     '42501',
     'permission denied: one of MERGE_CUSTOMER_IDENTITY is required to write customer_identity_merges',
     'a trainee without MERGE_CUSTOMER_IDENTITY is refused a customer identity merge by the write-capability guard'
   );
   select set_config('request.jwt.claims', '', true);

   -- 7-12. INPUT: a code that is not an active value of its catalog family is refused.
   select throws_ok(
     $$insert into public.journal_entries (tenant_id, source_type_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_source')$$,
     '23514',
     'journal_entries .source_type_code : "x191_source" is not an active value of catalog family "journal_entry_source_type"',
     'an unknown journal entry source type is refused by the catalog-code check'
   );
   select throws_ok(
     $$insert into public.notifications (tenant_id, notification_type_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_type')$$,
     '23514',
     'notifications .notification_type_code : "x191_type" is not an active value of catalog family "notification_type"',
     'an unknown notification type is refused by the catalog-code check'
   );
   select throws_ok(
     $$insert into public.notification_deliveries (tenant_id, channel_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_channel')$$,
     '23514',
     'notification_deliveries .channel_code : "x191_channel" is not an active value of catalog family "notification_channel"',
     'an unknown notification delivery channel is refused by the catalog-code check'
   );
   select throws_ok(
     $$insert into public.attribution_clicks (tenant_id, attribution_source_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_source')$$,
     '23514',
     'attribution_clicks .attribution_source_code : "x191_source" is not an active value of catalog family "attribution_source"',
     'an unknown attribution source is refused by the catalog-code check'
   );
   select throws_ok(
     $$insert into public.offline_conversion_deliveries (tenant_id, platform_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_platform')$$,
     '23514',
     'offline_conversion_deliveries .platform_code : "x191_platform" is not an active value of catalog family "platform_code"',
     'an unknown offline conversion delivery platform is refused by the catalog-code check'
   );
   select throws_ok(
     $$insert into public.customer_consents (tenant_id, channel_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_channel')$$,
     '23514',
     'customer_consents .channel_code : "x191_channel" is not an active value of catalog family "channel_code"',
     'an unknown consent channel is refused by the catalog-code check'
   );

   -- 13. TENANT: a notification cannot name a customer that does not exist in its own tenant.
   select throws_ok(
     $$insert into public.notifications (tenant_id, notification_type_code, related_entity_type, related_entity_id)
       values ('c1910000-0000-0000-0000-000000000001', 'security_alert', 'customer', 'c1910000-0000-0000-0000-0000000000c9')$$,
     '23503',
     'notifications: related_entity_id "c1910000-0000-0000-0000-0000000000c9" does not identify a customer in this tenant',
     'a notification naming a customer outside its tenant is refused by the entity-reference check'
   );

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is e75f8c0425431f68ddb85e1e17f03611b07c3008.

3. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Last updated: 2026-11-23 (CRM exit bundle I, SPEC-334.`; if so record Already Applied when its Git blob is 707cdab6f86060d57e9709b758f79fe7820aced8, and otherwise stop and report. Otherwise make exactly these 4 edits (the EC-5 and EC-6 readings cite the probe, Tests 190 and 191 and the negative sweep, and the dated SPEC-334 header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-23 (CRM exit bundle H, SPEC-333. The EC-6 door sweep at `2f8c19a` finds one member-writable door that no test writes through, UPDATE on `customer_contact_methods`. Test 189 proves that door refuses a tenant move, a foreign customer, an unnormalized value, a second primary, an unregistered, retired or foreign channel, a member without CREATE_CUSTOMER, a cross-tenant write and a lapsed subscription.)
   ```
   with
   ```text
   Last updated: 2026-11-23 (CRM exit bundle I, SPEC-334. The EC-5 removal-mutation probe at `8a43a53` removes each check and unique control and each RAISE-bearing row trigger in turn: 87 of 365 valid mutants pass every test that names their table. Test 190 refuses 72 check and unique constraints by name and Test 191 refuses 13 triggers by their own message; the other 2 are equivalent. The EC-6 negative sweep finds a refusal test for each of the 101 member-writable doors and each of the 78 surfaces.)

   Previously: 2026-11-23 (CRM exit bundle H, SPEC-333. The EC-6 door sweep at `2f8c19a` finds one member-writable door that no test writes through, UPDATE on `customer_contact_methods`. Test 189 proves that door refuses a tenant move, a foreign customer, an unnormalized value, a second primary, an unregistered, retired or foreign channel, a member without CREATE_CUSTOMER, a cross-tenant write and a lapsed subscription.)
   ```

   b) replace the line
   ```text
   **CRM exit evidence at `2f8c19a`, measured 2026-11-23 (SPEC-333, Test 189; SPEC-332, Test 188; SPEC-331, Test 187; SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```
   with
   ```text
   **CRM exit evidence at `8a43a53`, measured 2026-11-23 (SPEC-334, Tests 190 and 191; SPEC-333, Test 189; SPEC-332, Test 188; SPEC-331, Test 187; SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```

   c) replace the lines
   ```text
   - **EC-5 (partial):** SPEC-316 smoke and both pgTAP passes cover exercised invariants. RFD-3 and the PAY-5/FIN-11 unit are fixed by SPEC-326 (Test 184), PAY-4 by SPEC-327 (Test 185), and JE-2 is contained fail-closed by SPEC-327 (Tests 145/185). PAY-9 keeps `FIRST-BOOKING` and DC-11 keeps the finance model; each is classified at its own boundary.
   - **EC-6 (partial):** Check 24 admits the recorded adversarial labels. SPEC-333 sweeps the 101 member-writable doors at `2f8c19a` (52 INSERT, 49 UPDATE, no DELETE): exactly one, UPDATE on `customer_contact_methods`, had no test writing through it, and Test 189 is its targeted negative test across seven controls. The sweep finds untested doors; whether each tested door pins every negative case stays with the gate evaluation. Retain the existing evaluation and delivery triggers for the three partial surfaces. Any required proof whose trigger falls after its own prerequisite needs an explicit gate decision.
   ```
   with
   ```text
   - **EC-5 (partial):** SPEC-316 smoke and both pgTAP passes cover exercised invariants. RFD-3 and the PAY-5/FIN-11 unit are fixed by SPEC-326 (Test 184), PAY-4 by SPEC-327 (Test 185), and JE-2 is contained fail-closed by SPEC-327 (Tests 145/185). PAY-9 keeps `FIRST-BOOKING` and DC-11 keeps the finance model; each is classified at its own boundary. SPEC-334 runs a removal-mutation probe at `8a43a53`: it drops each of the 144 check and unique constraints and 33 unique indexes and disables each of the 216 RAISE-bearing row triggers, one at a time, and runs the pgTAP files that name the table. 28 drops are refused because a foreign key depends on the key. Of the 365 valid mutants, 278 fail a test; the 83 caught only by the trigger catalog of Test 187 run one of eight shared functions that a behavioural test runs on another table. Of the 87 survivors, Test 190 refuses 72 by constraint name and Test 191 refuses 13 by trigger message, and removing each fails its own assertion; 2 are equivalent (implied by another check and by the primary key). Foreign keys, triggers without RAISE, function bodies and policies are not mutated, so EC-5 stays partial.
   - **EC-6 (partial):** Check 24 admits the recorded adversarial labels. SPEC-333 sweeps the 101 member-writable doors at `2f8c19a` (52 INSERT, 49 UPDATE, no DELETE): exactly one, UPDATE on `customer_contact_methods`, had no test writing through it, and Test 189 is its targeted negative test across seven controls. SPEC-334 grades the negative side: each of the 101 doors has a refusal assertion writing through it (99 by `throws_*` statement text, 2 by inspection: Tests 47, 131 and 152 read back an RLS-silent UPDATE on `subscription_payment_proofs`, and Test 182 refuses a passengers INSERT built with `format`), and so does each of the 78 surfaces (74 by text, 4 by inspection: Tests 181, 175 and 66). The sweep grades existence; whether each negative test is the strongest case for its door stays with the gate evaluation. Retain the existing evaluation and delivery triggers for the three partial surfaces. Any required proof whose trigger falls after its own prerequisite needs an explicit gate decision.
   ```

   d) immediately after the lines
   ```text
   **Recorded exception, 2026-11-23, CRM exit bundle H.** After CRM SPEC-332 at `2f8c19ae489ecbb988ebffd4b8aad7911dd4edd1`, the Batch 6 delegation continues to `B6-EXIT` in the owner's AFK mode. SPEC-333 adds Test 189, the targeted negative test of the one member-writable door the EC-6 sweep found untested, UPDATE on `customer_contact_methods`, and the EC-6 reading cites the sweep. It changes no migration or database object, and EC-6 stays partial. The Original and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-23, CRM exit bundle I.** After CRM SPEC-333 at `8a43a537cbd06cd9df6b636ac80fc1d658c1e88b`, the Batch 6 delegation continues to `B6-EXIT` in the owner's AFK mode. SPEC-334 adds Test 190, which refuses the 72 check and unique constraints the EC-5 mutation probe found unpinned, and Test 191, which refuses the 13 unpinned triggers; the EC-5 and EC-6 readings cite the probe and the negative sweep. It changes no migration or database object, and EC-5 and EC-6 stay partial. The Original and release gates remain enforced.

   ```

   The resulting file's Git blob is 707cdab6f86060d57e9709b758f79fe7820aced8.

4. Check whether `_ORVION_CANONICAL/manifest.md` contains `Suite **191 files / 3591 assertions**.`; if so record Already Applied when its Git blob is d920e797d02ec8997643a83e7ec31901819c2313, and otherwise stop and report. Otherwise make exactly this one edit (the measured suite figure), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **189 files / 3506 assertions**.
   ```
   with
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **191 files / 3591 assertions**.
   ```

   The resulting file's Git blob is d920e797d02ec8997643a83e7ec31901819c2313.

5. **Establish readiness and verify.** Run the native DATABASE readiness: full SQL tests at 277 migrations with 191 files and 3591 assertions including Test 190 at 72 of 72 and Test 191 at 13 of 13, smoke and HTTP, and API generation with the API contract unchanged. Run the native repository guard and the five hosted guard suites named in Additional Verification. Confirm that `readiness_population.ps1` reports REGISTRY complete with no COMPLETED member. Confirm the exact scope and `git diff --check`. Make no Primary write. Synchronize the contract and native discovery artifacts, set Runtime Checkpoint DONE and commit the implementation. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-334: Every constraint and trigger no test removed is proven to refuse.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] Test 190 refuses the 72 check and unique constraints by name. `check: blob supabase/tests/190_constraint_refusals_test.sql 8ae13da46d8ced91c652dfcaec13dba2f7546f3f`
- [ ] Test 191 refuses the 13 triggers by their own message. `check: blob supabase/tests/191_trigger_enforcer_refusals_test.sql e75f8c0425431f68ddb85e1e17f03611b07c3008`
- [ ] The EC-5 and EC-6 readings cite the probe, the tests and the negative sweep. `check: blob reports/master/MASTER_EXECUTION_PLAN.md 707cdab6f86060d57e9709b758f79fe7820aced8`
- [ ] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **191 files / 3591 assertions**"`
- [ ] The API contract is unchanged. `check: same reports/master/MASTER_API_CONTRACT.md @8a43a537cbd06cd9df6b636ac80fc1d658c1e88b`
- [ ] The surface disposition is unchanged. `check: same reports/master/MASTER_SURFACE_DISPOSITION.md @8a43a537cbd06cd9df6b636ac80fc1d658c1e88b`
- [ ] The gap register is unchanged. `check: same reports/master/MASTER_GAP_REGISTER.md @8a43a537cbd06cd9df6b636ac80fc1d658c1e88b`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @8a43a537cbd06cd9df6b636ac80fc1d658c1e88b`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @8a43a537cbd06cd9df6b636ac80fc1d658c1e88b`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @8a43a537cbd06cd9df6b636ac80fc1d658c1e88b`
- [ ] The cold-start guard suite is preserved. `check: same scripts/test_cold_start_state_guard.ps1 @8a43a537cbd06cd9df6b636ac80fc1d658c1e88b`
- [ ] Full DATABASE readiness and all five hosted guard suites pass in the native Finish; no exit criterion is marked met.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 8a43a537cbd06cd9df6b636ac80fc1d658c1e88b (SPEC-333 Complete and released; main is 8a43a537cbd06cd9df6b636ac80fc1d658c1e88b).

Authority: DELEGATED under the owner's AFK Mode, answered by the constitution; never typed by the owner. The owner's words of 2026-11-23, Workbench `data/records/batch6/owner-words/owner-2026-11-23-modes-any-session.txt`, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73, make AFK Mode a tool that decides by the project's rules and widens nothing; the owner's words of 2026-11-22, `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D, direct Batch 6 to finish first. This contract grants nothing beyond them. The mutation probe is Workbench `data/records/batch6/exit-bundle-i/ec5-mutation/`, the negative sweep `data/records/batch6/exit-bundle-i/ec6-negative-sweep/`, and the final mutation runs `data/records/batch6/exit-bundle-i/spec334/mutation/`.

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `3e5a77c722aaa1bd496b6c6e0cc282d8528429bc` |
| `_ORVION_CANONICAL/manifest.md` | `3e805de7f0da739e7cc111631f35066652740810` |
