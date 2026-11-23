# Change Request — SPEC-335

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close the evidence gaps the CRM `B6-EXIT` evaluation found at 676df3e46fffae83366fa4c177a74d327edd6381 under the exit criteria EC-5, EC-7 and EC-8, and register what the gate-evaluation re-sweep measured. Test 192 pins the row locks of the CUST-10 and CUST-12 repairs, which only an unscheduled Python verifier proved (EC-7). Test 193 pins the presence and definition of the 302 foreign keys, policies, row-level security switches and triggers that the EC-5 extension probe removed without a failing test (EC-5). Test 194 pins as OPEN the four findings the `documents`/`quotations` re-sweep and the creation-stamp measurement registered: DOC-11, QUO-11, QUO-12 and BOOK-13. The register, the surface disposition and the plan record these findings, the accepted residual STAMP-1, the FIN-9 and CTRL-11 readings and the correction of BRANCH-2's stale sentence (EC-8). They also record the owner's decision of 2026-11-23 to decline CTRL-19's GitHub configuration repair: CTRL-19 becomes an accepted residual with its containment and reopening trigger, the manifest drops it from the open owner decisions, EC-10 no longer waits on the owner, and ADR-0031, whose revisit trigger is a change to CTRL-19, is revisited and stands.

## Business Reason

EC-5 requires that an invariant held in a database control be proven by a test that fails when the control is removed. EC-7 requires that no finding be closed without a permanent guard. EC-8 requires the records to be coherent with the measured state. At 676df3e46fffae83366fa4c177a74d327edd6381 (277 migrations, 191 test files): removing either CUST lock passes every test, because only `scripts/verify_customer_concurrency.py` proves them and nothing runs it; removing any of 302 structural controls (244 foreign keys, 22 permissive RLS policies and 36 `updated_at` triggers) passes every pgTAP file, as measured by the EC-5 extension probe over 625 removals of every foreign key, RLS policy, RLS switch and trigger without RAISE; and the gate rows FIN-9, CTRL-11 and the `documents`/`quotations` re-sweep were unmeasured. Leaving them would hand the gate evaluation a known gap (DEC-33 rules 9 and 12).

## Risks

A presence pin proves that a control exists with its recorded definition, not that it behaves; Test 193's header says so, and the behaviour stays the evidence of the files that name each table. A shape pin on a function body could pass while the lock is ineffective; Test 192 pins the exact lock statement and its order before the reads, and the race itself stays the Python verifier's proof. An OPEN pin records a defect, not desired behaviour; each Test 194 assertion fails when its finding is repaired, so the repair updates the test and the register together, as Test 130 does for BRANCH-2. This contract changes no migration, function, policy, grant or database object, and marks no exit criterion met. Accepting CTRL-19 leaves the agent's credential administering the repository; the containment is the promotion path through `scripts/promote_main.ps1` under `-Gate -Trusted`, recorded with its reopening trigger, and the decision is the owner's own.

## Supersedes / Depends On

Extends the SPEC-334 refusal proofs (Tests 190 and 191) and the house shape-pin pattern of Tests 148 and 153. Those terminal contracts are immutable.

## Write Scope

- `changes/SPEC-335-the-exit-evidence-gaps-are-pinned-and-the-re-sweep-registered.md`
- `supabase/tests/192_a_customer_lock_is_taken_before_its_judgement_test.sql`
- `supabase/tests/193_structural_control_presence_test.sql`
- `supabase/tests/194_door_evidence_and_sale_dates_open_pins_test.sql`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `_ORVION_CANONICAL/manifest.md`
- `reports/architecture-decision-records.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_API_CONTRACT.md`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `.github/workflows/repository-consistency.yml`
- `supabase/config.toml`

Migrations, product code, the repair of any finding registered here, any Primary write, Founder Secondary, frontend work, integration activation, email delivery and every owner decision are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9.
- `reports/master/MASTER_EXECUTION_PLAN.md` the exit criteria EC-5 to EC-8 and the gate table.
- `supabase/tests/130_branch_door_audit_test.sql`.
- `supabase/tests/148_a_subscription_transition_is_judged_on_the_row_it_replaces_test.sql`.
- `supabase/tests/153_a_payment_proof_is_decided_once_test.sql`.
- `supabase/tests/190_constraint_refusals_test.sql`.

## Runtime Checkpoint

Resume Step: DONE
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

Pass 1 Design: Three new pgTAP tests, each rolled back at the end. Test 192 reads the two function bodies from `pg_proc` and asserts the exact lock statement and that it precedes the first read it protects (4 assertions). Test 193 sets `search_path = public, extensions` and asserts with `set_has` that each pinned control is present with its deparsed definition, one assertion per control class (3 assertions). Test 194 builds one tenant with an employee and a branch manager and pins DOC-11, QUO-11, QUO-12 and BOOK-13 as OPEN beside RPC positive controls (11 assertions). The register gains DOC-11, QUO-11, QUO-12, BOOK-13 and STAMP-1; the disposition moves `documents`, `quotations` and `booking_items` to `AUDITED-OPEN`; the plan records the EC readings and the gate rows.

Pass 2 Adversarial Review: Test 192: four mutants that remove or reorder each lock fail it, and with both locks removed none of the ten existing files that name the two functions gains a failure (the causal negative). Test 193: removing each of the 302 pinned controls inside its transaction fails it. Test 194: seven mutants that simulate each repair (door events, transition stamps, owned and frozen creation stamps, a refused renumbering) each fail it. The unmutated database passes 4 of 4, 3 of 3 and 11 of 11.

Pass 3 Evidence Refresh: 2026-11-23. In an isolated clone at 676df3e46fffae83366fa4c177a74d327edd6381 carrying the payload:
- Tests 192, 193 and 194 passed on the local stack (277 migrations), and the mutation sets failed as above.
- `readiness_population.ps1` reported REGISTRY complete with no COMPLETED member.
- Native repository consistency was CLEAN, Check 15 reading 194 files and 3609 assertions.
- All five hosted guard suites passed with 0 failed.

Selected Version: SPEC-335; selected: three pgTAP tests (a lock-shape pin for CUST-10 and CUST-12, a presence-and-definition pin for the 302 structural controls the EC-5 extension removed without a failing test, and OPEN pins for DOC-11, QUO-11, QUO-12 and BOOK-13) with the plan, register, disposition and manifest records, the smallest change that closes the EC-5, EC-7 and EC-8 evidence gaps without any database change

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Lock-shape, presence and OPEN pins | Full pgTAP suite and the `B6-EXIT` gate evaluation | WRITE | Tests 192, 193 and 194 add 18 assertions; the suite grows to 194 files and 3609 assertions. |
| Register rows DOC-11, QUO-11, QUO-12, BOOK-13 and STAMP-1 | Check 29 (`readiness_population.ps1`) and the gate table | WRITE | Each row carries its class, boundary and SPEC-335 evidence; the population stays complete with no COMPLETED member. |
| Surface disposition of `documents`, `quotations` and `booking_items` | Check 22 and Check 24 | WRITE | 63 AUDITED, 14 AUDITED-OPEN, 1 PARTIAL; finding ids resolve and the coverage line matches. |
| EC-5, EC-7 and EC-8 readings and the gate rows | Exit criteria | WRITE | They cite the probes and tests; no criterion is marked met. |
| CTRL-19 as an owner-accepted residual at `OWN-TRIGGER` | Check 29, EC-10, the manifest's open owner decisions and ADR-0031's revisit trigger | WRITE | The registry row keeps a known boundary and non-empty treatment and the register status stays OPEN, so the population stays complete with no COMPLETED member; ADR-0031 records its revisit and stands unchanged. |
| Schema, grants, policies and API | Every product consumer | UNAFFECTED | No migration; the API contract has the same blob as the baseline. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchors and exact payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Checks 22, 24 and 29 and the five hosted guard suites pass | BEFORE_COMPLETION | 1 | 7 | 8 |
| Full DATABASE readiness with Tests 192, 193 and 194 | BEFORE_COMPLETION | NONE | NONE | 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: The pgTAP suite and its mutation-proven precedents, `supabase/tests/148_a_subscription_transition_is_judged_on_the_row_it_replaces_test.sql` (shape pins), `supabase/tests/130_branch_door_audit_test.sql` (OPEN pins) and `supabase/tests/190_constraint_refusals_test.sql`.

Added Property: The CUST-10 and CUST-12 locks keep their statement and order; each of the 302 pinned structural controls stays present with its definition; and each of DOC-11, QUO-11, QUO-12 and BOOK-13 stays recorded as open until a repair updates its pin.

Causal Negative: At 676df3e46fffae83366fa4c177a74d327edd6381, removing either CUST lock, or any of the 302 pinned controls, passes every pgTAP file that names its function or table.

Positive Test Design: On the unmutated database Tests 192, 193 and 194 pass 4 of 4, 3 of 3 and 11 of 11.

Negative Test Design: In a rolled-back transaction, each lock mutant fails Test 192, each control removal fails Test 193, and each simulated repair fails Test 194.

Non-Empty Population Obligation: Test 192 asserts each function exists exactly once; Test 193's expected sets list every pinned control, so an empty catalog fails; Test 194's fixture holds one active `enterprise` tenant with a branch, a department, an employee, a branch manager, a customer, a supplier, two leads, a booking and a booking item.

Mutation Obligation: The three mutation sets above must fail as stated.

Post-Implementation Proof Obligation: The native Finish runs the full DATABASE protocol with Tests 192, 193 and 194 and all five hosted guard suites through Additional Verification with zero failures. Hosted preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `supabase/tests/192_a_customer_lock_is_taken_before_its_judgement_test.sql` contains `select plan(4);`; if so record Already Applied when its Git blob is 00d4d776f17ad411f4499ad454d446e0ac772623, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the customer lock-shape test), and change nothing else:

   ```text
   -- pgTAP: a customer row is locked before the decision that reads it (CUST-10, CUST-12).
   --
   -- EC-7: every repaired finding keeps a permanent guard. CUST-10 (migration 20260909060754) and CUST-12
   --   (20260909114354) fixed two races by a row lock, and only scripts/verify_customer_concurrency.py proves
   --   them; no workflow, Finish profile or script runs it, and pgTAP has one session, so no test noticed a
   --   lost lock. As Tests 148 (SUB-4, SUB-5) and 153 (SPP-6) do, this file pins in every CI run the shape
   --   the race proof depends on:
   --   * app.merge_customer_identity locks both identities in id order before it reads either lifecycle
   --     state, so opposite merges cannot each validate a stale row version and archive both survivors;
   --   * app.evaluate_customer_credit_threshold locks the customer before it aggregates the exposure and
   --     reads the last threshold event, so two concurrent evaluations cannot both record a crossing.
   --   Each function exists exactly once; a missing or overloaded function fails its assertions.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(4);

   create temporary table customer_lock_src on commit drop as
   select p.proname::text as fn, p.prosrc as src
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'app'
     and p.proname in ('merge_customer_identity', 'evaluate_customer_credit_threshold');

   select ok((select count(*) = 1 and bool_and(src
                 ~ 'perform 1 from public\.customers\s+where tenant_id = v_tenant and id in \(p_source_customer_id, p_target_customer_id\)\s+order by id for update;')
              from customer_lock_src where fn = 'merge_customer_identity'),
     'CUST-12: app.merge_customer_identity locks both identities in id order');

   select ok((select count(*) = 1 and bool_and(strpos(src, 'order by id for update;') > 0
                 and strpos(src, 'order by id for update;') < strpos(src, 'select is_archived into v_src_archived')
                 and strpos(src, 'order by id for update;') < strpos(src, 'select is_archived into v_target_archived'))
              from customer_lock_src where fn = 'merge_customer_identity'),
     'CUST-12: the merge takes its lock before it reads either lifecycle state');

   select ok((select count(*) = 1 and bool_and(src
                 ~ 'from public\.customers c\s+where c\.id=p_customer_id and c\.tenant_id=p_tenant_id for update;')
              from customer_lock_src where fn = 'evaluate_customer_credit_threshold'),
     'CUST-10: app.evaluate_customer_credit_threshold locks the customer it judges');

   select ok((select count(*) = 1 and bool_and(strpos(src, 'c.tenant_id=p_tenant_id for update;') > 0
                 and strpos(src, 'c.tenant_id=p_tenant_id for update;') < strpos(src, 'app.customer_exposure_in_limit_currency(')
                 and strpos(src, 'c.tenant_id=p_tenant_id for update;') < strpos(src, 'from public.events e'))
              from customer_lock_src where fn = 'evaluate_customer_credit_threshold'),
     'CUST-10: the evaluation takes its lock before the exposure and the last threshold event');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 00d4d776f17ad411f4499ad454d446e0ac772623.

2. Check whether `supabase/tests/193_structural_control_presence_test.sql` contains `select plan(3);`; if so record Already Applied when its Git blob is 472b404c67b1656b5c0013bbbb86f1b7a2e33b4a, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the structural control presence test), and change nothing else:

   ```text
   -- pgTAP: Batch 6 exit -- the structural controls that no test removed are pinned present, each with its definition.
   --
   -- EC-5: an invariant held in a database control must be proven by a test that fails when the control is removed. The
   --   EC-5 extension probe at CRM 676df3e dropped each foreign key, row-level security policy, row-level security switch
   --   and RAISE-free trigger in turn and ran the pgTAP files that name its table, then reran each survivor against the
   --   catalog-wide files. These 302 survived both (244 foreign keys, 22 policies, 0 switches, 36 triggers).
   --   This file pins their PRESENCE and DEFINITION, not their behaviour: a change that drops or rewrites one fails here
   --   and must update this file in the same change, which makes the removal a reviewed decision instead of a silent one.
   --   Behaviour stays the evidence of the files that name each table. Definitions are compared as deparsed text (foreign
   --   keys) or as an md5 of the deparsed text (policy expressions, triggers) under the search_path set below.
   --   No migration.
   create extension if not exists pgtap with schema extensions;

   begin;
   set local search_path = public, extensions;
   select plan(3);

   select set_has(
     $a$select conrelid::regclass::text || '.' || conname || ' ' || pg_get_constraintdef(oid) from pg_constraint where contype = 'f' and connamespace = 'public'::regnamespace$a$,
     $e$values
       ('approval_requests.approval_requests_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('approval_requests.approval_requests_document_id_fkey FOREIGN KEY (tenant_id, document_id) REFERENCES documents(tenant_id, id) ON DELETE RESTRICT'),
       ('approval_requests.approval_requests_requested_by_fkey FOREIGN KEY (tenant_id, requested_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('approval_requests.approval_requests_reviewed_by_fkey FOREIGN KEY (tenant_id, reviewed_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('approval_requests.approval_requests_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('attribution_clicks.attribution_clicks_lead_id_fkey FOREIGN KEY (tenant_id, lead_id) REFERENCES leads(tenant_id, id) ON DELETE RESTRICT'),
       ('attribution_clicks.attribution_clicks_marketing_campaign_id_fkey FOREIGN KEY (tenant_id, marketing_campaign_id) REFERENCES marketing_campaigns(tenant_id, id) ON DELETE RESTRICT'),
       ('attribution_clicks.attribution_clicks_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('booking_item_passengers.booking_item_passengers_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_item_passengers.booking_item_passengers_corrected_by_fkey FOREIGN KEY (tenant_id, passenger_corrected_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_item_passengers.booking_item_passengers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_cancelled_by_fkey FOREIGN KEY (tenant_id, cancelled_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('booking_items.booking_items_exchange_rate_id_fkey FOREIGN KEY (tenant_id, exchange_rate_id) REFERENCES exchange_rates(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_finance_withdrawn_by_fkey FOREIGN KEY (tenant_id, finance_approval_withdrawn_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_no_show_recorded_by_fkey FOREIGN KEY (tenant_id, no_show_recorded_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_owner_branch_id_fkey FOREIGN KEY (tenant_id, owner_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_owner_department_id_fkey FOREIGN KEY (tenant_id, owner_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_reassigned_by_fkey FOREIGN KEY (tenant_id, reassigned_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_sales_owner_branch_id_fkey FOREIGN KEY (tenant_id, sales_owner_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_sales_owner_department_id_fkey FOREIGN KEY (tenant_id, sales_owner_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_supplier_id_fkey FOREIGN KEY (tenant_id, supplier_id) REFERENCES suppliers(tenant_id, id) ON DELETE RESTRICT'),
       ('booking_items.booking_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('bookings.bookings_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('bookings.bookings_branch_id_fkey FOREIGN KEY (tenant_id, branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('bookings.bookings_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('bookings.bookings_department_id_fkey FOREIGN KEY (tenant_id, department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('bookings.bookings_owner_department_id_fkey FOREIGN KEY (tenant_id, owner_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('bookings.bookings_quotation_id_fkey FOREIGN KEY (tenant_id, quotation_id) REFERENCES quotations(tenant_id, id) ON DELETE RESTRICT'),
       ('bookings.bookings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('branch_business_hours.branch_business_hours_branch_id_fkey FOREIGN KEY (tenant_id, branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('branch_business_hours.branch_business_hours_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('branches.branches_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('campaign_daily_metrics.campaign_daily_metrics_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('campaign_daily_metrics.campaign_daily_metrics_marketing_campaign_id_fkey FOREIGN KEY (tenant_id, marketing_campaign_id) REFERENCES marketing_campaigns(tenant_id, id) ON DELETE RESTRICT'),
       ('campaign_daily_metrics.campaign_daily_metrics_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('catalog_values.catalog_values_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('catalog_values.catalog_values_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('chart_of_accounts.chart_of_accounts_parent_account_id_fkey FOREIGN KEY (tenant_id, parent_account_id) REFERENCES chart_of_accounts(tenant_id, id) ON DELETE RESTRICT'),
       ('chart_of_accounts.chart_of_accounts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('company_assets.company_assets_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('complaints.complaints_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('complaints.complaints_booking_id_fkey FOREIGN KEY (tenant_id, booking_id) REFERENCES bookings(tenant_id, id) ON DELETE RESTRICT'),
       ('complaints.complaints_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('complaints.complaints_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('complaints.complaints_owner_branch_id_fkey FOREIGN KEY (tenant_id, owner_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('complaints.complaints_owner_department_id_fkey FOREIGN KEY (tenant_id, owner_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('complaints.complaints_owner_user_id_fkey FOREIGN KEY (tenant_id, owner_user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('complaints.complaints_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('conversation_messages.conversation_messages_conversation_id_fkey FOREIGN KEY (tenant_id, conversation_id) REFERENCES conversations(tenant_id, id) ON DELETE RESTRICT'),
       ('conversation_messages.conversation_messages_sender_user_id_fkey FOREIGN KEY (tenant_id, sender_user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('conversation_messages.conversation_messages_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('conversations.conversations_booking_id_fkey FOREIGN KEY (tenant_id, booking_id) REFERENCES bookings(tenant_id, id) ON DELETE RESTRICT'),
       ('conversations.conversations_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('conversations.conversations_current_branch_id_fkey FOREIGN KEY (tenant_id, current_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('conversations.conversations_current_department_id_fkey FOREIGN KEY (tenant_id, current_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('conversations.conversations_lead_id_fkey FOREIGN KEY (tenant_id, lead_id) REFERENCES leads(tenant_id, id) ON DELETE RESTRICT'),
       ('conversations.conversations_owner_branch_id_fkey FOREIGN KEY (tenant_id, owner_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('conversations.conversations_owner_department_id_fkey FOREIGN KEY (tenant_id, owner_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('conversations.conversations_owner_user_id_fkey FOREIGN KEY (tenant_id, owner_user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('conversations.conversations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('customer_consents.customer_consents_tenant_id_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('customer_consents.customer_consents_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('customer_contact_methods.customer_contact_methods_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('customer_identity_merges.customer_identity_merges_merged_by_fkey FOREIGN KEY (tenant_id, merged_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('customer_identity_merges.customer_identity_merges_source_customer_id_fkey FOREIGN KEY (tenant_id, source_customer_id) REFERENCES customers(tenant_id, id) ON DELETE RESTRICT'),
       ('customer_identity_merges.customer_identity_merges_target_customer_id_fkey FOREIGN KEY (tenant_id, target_customer_id) REFERENCES customers(tenant_id, id) ON DELETE RESTRICT'),
       ('customer_identity_merges.customer_identity_merges_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('customer_identity_signals.customer_identity_signals_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('customer_notes.customer_notes_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('customer_notes.customer_notes_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('customer_notes.customer_notes_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('customers.customers_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('customers.customers_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('customers.customers_first_registered_branch_id_fkey FOREIGN KEY (tenant_id, first_registered_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('customers.customers_first_registered_user_id_fkey FOREIGN KEY (tenant_id, first_registered_user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('customers.customers_last_interaction_branch_id_fkey FOREIGN KEY (tenant_id, last_interaction_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('customers.customers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('departments.departments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('document_links.document_links_booking_id_fkey FOREIGN KEY (tenant_id, booking_id) REFERENCES bookings(tenant_id, id) ON DELETE RESTRICT'),
       ('document_links.document_links_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('document_links.document_links_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('document_links.document_links_document_id_fkey FOREIGN KEY (tenant_id, document_id) REFERENCES documents(tenant_id, id) ON DELETE RESTRICT'),
       ('document_links.document_links_invoice_id_fkey FOREIGN KEY (tenant_id, invoice_id) REFERENCES invoices(tenant_id, id) ON DELETE RESTRICT'),
       ('document_links.document_links_passenger_id_fkey FOREIGN KEY (tenant_id, passenger_id) REFERENCES passengers(tenant_id, id) ON DELETE RESTRICT'),
       ('document_links.document_links_quotation_id_fkey FOREIGN KEY (tenant_id, quotation_id) REFERENCES quotations(tenant_id, id) ON DELETE RESTRICT'),
       ('document_links.document_links_receipt_id_fkey FOREIGN KEY (tenant_id, receipt_id) REFERENCES receipts(tenant_id, id) ON DELETE RESTRICT'),
       ('document_links.document_links_supplier_id_fkey FOREIGN KEY (tenant_id, supplier_id) REFERENCES suppliers(tenant_id, id) ON DELETE RESTRICT'),
       ('document_links.document_links_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('document_retention_policies.document_retention_policies_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('document_retention_policies.document_retention_policies_tenant_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('document_storage_findings.document_storage_findings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('document_storage_findings.document_storage_findings_version_fkey FOREIGN KEY (tenant_id, document_version_id) REFERENCES document_versions(tenant_id, id) ON DELETE RESTRICT'),
       ('document_versions.document_versions_document_id_fkey FOREIGN KEY (tenant_id, document_id) REFERENCES documents(tenant_id, id) ON DELETE RESTRICT'),
       ('document_versions.document_versions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('document_versions.document_versions_uploaded_by_fkey FOREIGN KEY (tenant_id, uploaded_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('documents.documents_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('documents.documents_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('documents.documents_legal_hold_changed_by_fkey FOREIGN KEY (tenant_id, legal_hold_changed_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('documents.documents_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('events.events_actor_user_id_fkey FOREIGN KEY (tenant_id, actor_user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('events.events_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('exchange_rate_adjustments.exchange_rate_adjustments_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('exchange_rate_adjustments.exchange_rate_adjustments_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('exchange_rate_adjustments.exchange_rate_adjustments_new_exchange_rate_id_fkey FOREIGN KEY (tenant_id, new_exchange_rate_id) REFERENCES exchange_rates(tenant_id, id) ON DELETE RESTRICT'),
       ('exchange_rate_adjustments.exchange_rate_adjustments_original_exchange_rate_id_fkey FOREIGN KEY (tenant_id, original_exchange_rate_id) REFERENCES exchange_rates(tenant_id, id) ON DELETE RESTRICT'),
       ('exchange_rate_adjustments.exchange_rate_adjustments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('exchange_rates.exchange_rates_from_currency_code_fkey FOREIGN KEY (from_currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('exchange_rates.exchange_rates_set_by_fkey FOREIGN KEY (tenant_id, set_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('exchange_rates.exchange_rates_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('exchange_rates.exchange_rates_to_currency_code_fkey FOREIGN KEY (to_currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('feature_entitlements.feature_entitlements_subscription_plan_id_fkey FOREIGN KEY (subscription_plan_id) REFERENCES subscription_plans(id) ON DELETE RESTRICT'),
       ('financial_accounts.financial_accounts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('holidays.holidays_branch_id_fkey FOREIGN KEY (tenant_id, branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('holidays.holidays_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('internal_supplier_links.internal_supplier_links_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('internal_supplier_links.internal_supplier_links_provider_branch_id_fkey FOREIGN KEY (tenant_id, provider_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('internal_supplier_links.internal_supplier_links_provider_department_id_fkey FOREIGN KEY (tenant_id, provider_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('internal_supplier_links.internal_supplier_links_requester_branch_id_fkey FOREIGN KEY (tenant_id, requester_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('internal_supplier_links.internal_supplier_links_requester_department_id_fkey FOREIGN KEY (tenant_id, requester_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('internal_supplier_links.internal_supplier_links_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('invoices.invoices_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('invoices.invoices_booking_id_fkey FOREIGN KEY (tenant_id, booking_id) REFERENCES bookings(tenant_id, id) ON DELETE RESTRICT'),
       ('invoices.invoices_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('invoices.invoices_corrects_invoice_fkey FOREIGN KEY (tenant_id, corrects_invoice_id) REFERENCES invoices(tenant_id, id) ON DELETE RESTRICT'),
       ('invoices.invoices_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('invoices.invoices_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('invoices.invoices_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('invoices.invoices_voided_by_fkey FOREIGN KEY (tenant_id, voided_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('journal_entries.journal_entries_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('journal_entries.journal_entries_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('journal_entries.journal_entries_voided_by_fkey FOREIGN KEY (tenant_id, voided_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('journal_entry_lines.journal_entry_lines_chart_account_id_fkey FOREIGN KEY (tenant_id, chart_account_id) REFERENCES chart_of_accounts(tenant_id, id) ON DELETE RESTRICT'),
       ('journal_entry_lines.journal_entry_lines_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('journal_entry_lines.journal_entry_lines_journal_entry_id_fkey FOREIGN KEY (tenant_id, journal_entry_id) REFERENCES journal_entries(tenant_id, id) ON DELETE RESTRICT'),
       ('journal_entry_lines.journal_entry_lines_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('lead_assignments.lead_assignments_assigned_by_fkey FOREIGN KEY (tenant_id, assigned_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('lead_assignments.lead_assignments_lead_id_fkey FOREIGN KEY (tenant_id, lead_id) REFERENCES leads(tenant_id, id) ON DELETE RESTRICT'),
       ('lead_assignments.lead_assignments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('lead_interactions.lead_interactions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('lead_interactions.lead_interactions_user_id_fkey FOREIGN KEY (tenant_id, user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('leads.leads_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('leads.leads_attribution_click_id_fkey FOREIGN KEY (tenant_id, attribution_click_id) REFERENCES attribution_clicks(tenant_id, id) ON DELETE RESTRICT'),
       ('leads.leads_branch_id_fkey FOREIGN KEY (tenant_id, branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('leads.leads_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('leads.leads_department_id_fkey FOREIGN KEY (tenant_id, department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('leads.leads_owner_branch_id_fkey FOREIGN KEY (tenant_id, owner_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('leads.leads_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('marketing_campaigns.marketing_campaigns_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('notification_deliveries.notification_deliveries_notification_id_fkey FOREIGN KEY (tenant_id, notification_id) REFERENCES notifications(tenant_id, id) ON DELETE RESTRICT'),
       ('notification_deliveries.notification_deliveries_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('notifications.notifications_target_user_id_fkey FOREIGN KEY (tenant_id, target_user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('notifications.notifications_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('offline_conversion_deliveries.offline_conversion_deliveries_offline_conversion_id_fkey FOREIGN KEY (tenant_id, offline_conversion_id) REFERENCES offline_conversions(tenant_id, id) ON DELETE RESTRICT'),
       ('offline_conversion_deliveries.offline_conversion_deliveries_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('offline_conversions.offline_conversions_attribution_click_id_fkey FOREIGN KEY (tenant_id, attribution_click_id) REFERENCES attribution_clicks(tenant_id, id) ON DELETE RESTRICT'),
       ('offline_conversions.offline_conversions_booking_id_fkey FOREIGN KEY (tenant_id, booking_id) REFERENCES bookings(tenant_id, id) ON DELETE RESTRICT'),
       ('offline_conversions.offline_conversions_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('offline_conversions.offline_conversions_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('offline_conversions.offline_conversions_marketing_campaign_id_fkey FOREIGN KEY (tenant_id, marketing_campaign_id) REFERENCES marketing_campaigns(tenant_id, id) ON DELETE RESTRICT'),
       ('offline_conversions.offline_conversions_payment_id_fkey FOREIGN KEY (tenant_id, payment_id) REFERENCES payments(tenant_id, id) ON DELETE RESTRICT'),
       ('offline_conversions.offline_conversions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('otp_challenges.otp_challenges_auth_user_id_fkey FOREIGN KEY (auth_user_id) REFERENCES auth.users(id) ON DELETE CASCADE'),
       ('passengers.passengers_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('passengers.passengers_passport_issuing_country_code_fkey FOREIGN KEY (passport_issuing_country_code) REFERENCES countries(code) ON DELETE RESTRICT'),
       ('passengers.passengers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('payment_allocations.payment_allocations_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('payment_allocations.payment_allocations_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('payment_allocations.payment_allocations_exchange_rate_id_fkey FOREIGN KEY (tenant_id, exchange_rate_id) REFERENCES exchange_rates(tenant_id, id) ON DELETE RESTRICT'),
       ('payment_allocations.payment_allocations_invoice_id_fkey FOREIGN KEY (tenant_id, invoice_id) REFERENCES invoices(tenant_id, id) ON DELETE RESTRICT'),
       ('payment_allocations.payment_allocations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('payments.payments_account_currency_code_fkey FOREIGN KEY (account_currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('payments.payments_booking_id_fkey FOREIGN KEY (tenant_id, booking_id) REFERENCES bookings(tenant_id, id) ON DELETE RESTRICT'),
       ('payments.payments_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('payments.payments_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('payments.payments_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('payments.payments_exchange_rate_id_fkey FOREIGN KEY (tenant_id, exchange_rate_id) REFERENCES exchange_rates(tenant_id, id) ON DELETE RESTRICT'),
       ('payments.payments_financial_account_id_fkey FOREIGN KEY (tenant_id, financial_account_id) REFERENCES financial_accounts(tenant_id, id) ON DELETE RESTRICT'),
       ('payments.payments_received_by_fkey FOREIGN KEY (tenant_id, received_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('payments.payments_supplier_id_fkey FOREIGN KEY (tenant_id, supplier_id) REFERENCES suppliers(tenant_id, id) ON DELETE RESTRICT'),
       ('payments.payments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('quotation_items.quotation_items_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('quotation_items.quotation_items_quotation_id_fkey FOREIGN KEY (tenant_id, quotation_id) REFERENCES quotations(tenant_id, id) ON DELETE RESTRICT'),
       ('quotation_items.quotation_items_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('quotations.quotations_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('quotations.quotations_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('quotations.quotations_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('quotations.quotations_lead_id_fkey FOREIGN KEY (tenant_id, lead_id) REFERENCES leads(tenant_id, id) ON DELETE RESTRICT'),
       ('quotations.quotations_owner_branch_id_fkey FOREIGN KEY (tenant_id, owner_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('quotations.quotations_owner_department_id_fkey FOREIGN KEY (tenant_id, owner_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('quotations.quotations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('receipts.receipts_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('receipts.receipts_payment_id_fkey FOREIGN KEY (tenant_id, payment_id) REFERENCES payments(tenant_id, id) ON DELETE RESTRICT'),
       ('receipts.receipts_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('refunds.refunds_booking_id_fkey FOREIGN KEY (tenant_id, booking_id) REFERENCES bookings(tenant_id, id) ON DELETE RESTRICT'),
       ('refunds.refunds_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('refunds.refunds_currency_code_fkey FOREIGN KEY (currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('refunds.refunds_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('role_permissions.role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE RESTRICT'),
       ('role_permissions.role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT'),
       ('scheduled_job_findings.scheduled_job_findings_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('security_events.security_events_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('security_events.security_events_user_id_fkey FOREIGN KEY (tenant_id, user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('service_requests.service_requests_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('service_requests.service_requests_booking_id_fkey FOREIGN KEY (tenant_id, booking_id) REFERENCES bookings(tenant_id, id) ON DELETE RESTRICT'),
       ('service_requests.service_requests_booking_item_id_fkey FOREIGN KEY (tenant_id, booking_item_id) REFERENCES booking_items(tenant_id, id) ON DELETE RESTRICT'),
       ('service_requests.service_requests_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('service_requests.service_requests_owner_branch_id_fkey FOREIGN KEY (tenant_id, owner_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('service_requests.service_requests_owner_department_id_fkey FOREIGN KEY (tenant_id, owner_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('service_requests.service_requests_owner_user_id_fkey FOREIGN KEY (tenant_id, owner_user_id) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('service_requests.service_requests_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('subscription_payment_proofs.subscription_payment_proofs_reviewed_by_fkey FOREIGN KEY (tenant_id, reviewed_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('subscription_payment_proofs.subscription_payment_proofs_subscription_id_fkey FOREIGN KEY (tenant_id, subscription_id) REFERENCES subscriptions(tenant_id, id) ON DELETE RESTRICT'),
       ('subscription_payment_proofs.subscription_payment_proofs_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('subscription_payment_proofs.subscription_payment_proofs_uploaded_by_fkey FOREIGN KEY (tenant_id, uploaded_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('subscriptions.subscriptions_subscription_plan_id_fkey FOREIGN KEY (subscription_plan_id) REFERENCES subscription_plans(id) ON DELETE RESTRICT'),
       ('subscriptions.subscriptions_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('suppliers.suppliers_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('suppliers.suppliers_credit_limit_currency_code_fkey FOREIGN KEY (credit_limit_currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('suppliers.suppliers_internal_branch_id_fkey FOREIGN KEY (tenant_id, internal_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('suppliers.suppliers_internal_department_id_fkey FOREIGN KEY (tenant_id, internal_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('suppliers.suppliers_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('tasks.tasks_archived_by_fkey FOREIGN KEY (tenant_id, archived_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('tasks.tasks_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('tasks.tasks_owner_branch_id_fkey FOREIGN KEY (tenant_id, owner_branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('tasks.tasks_owner_department_id_fkey FOREIGN KEY (tenant_id, owner_department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('tasks.tasks_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('tenant_license_activations.tenant_license_activations_consumed_by_fkey FOREIGN KEY (tenant_id, consumed_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('tenant_license_activations.tenant_license_activations_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('tenants.tenants_default_currency_code_fkey FOREIGN KEY (default_currency_code) REFERENCES currencies(code) ON DELETE RESTRICT'),
       ('usage_counters.usage_counters_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('user_branch_assignments.user_branch_assignments_created_by_fkey FOREIGN KEY (tenant_id, created_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('user_branch_assignments.user_branch_assignments_department_id_fkey FOREIGN KEY (tenant_id, department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('user_branch_assignments.user_branch_assignments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('user_permission_grants.user_permission_grants_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES permissions(id) ON DELETE RESTRICT'),
       ('user_permission_grants.user_permission_grants_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('user_role_assignments.user_role_assignments_assigned_by_fkey FOREIGN KEY (tenant_id, assigned_by) REFERENCES users(tenant_id, id) ON DELETE RESTRICT'),
       ('user_role_assignments.user_role_assignments_branch_id_fkey FOREIGN KEY (tenant_id, branch_id) REFERENCES branches(tenant_id, id) ON DELETE RESTRICT'),
       ('user_role_assignments.user_role_assignments_department_id_fkey FOREIGN KEY (tenant_id, department_id) REFERENCES departments(tenant_id, id) ON DELETE RESTRICT'),
       ('user_role_assignments.user_role_assignments_role_id_fkey FOREIGN KEY (role_id) REFERENCES roles(id) ON DELETE RESTRICT'),
       ('user_role_assignments.user_role_assignments_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT'),
       ('users.users_tenant_id_fkey FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE RESTRICT')$e$,
     'each of the 244 pinned foreign keys is present with its recorded definition');

   select set_has(
     $a$select tablename || '.' || policyname || ' ' || permissive || ' ' || array_to_string(roles, ',') || ' ' || cmd || ' ' || md5(coalesce(qual, '') || '|' || coalesce(with_check, '')) from pg_policies where schemaname = 'public'$a$,
     $e$values
       ('branches.scope_delete PERMISSIVE authenticated DELETE faf0d4906aca9ad5f8b59f2afa297fb4'),
       ('catalog_values.catalog_tenant_delete PERMISSIVE authenticated DELETE b1461c0372818a6d78f25d9c9f6d197c'),
       ('chart_of_accounts.scope_delete PERMISSIVE authenticated DELETE 76ad84862b563ac7cf1ffd4d7d06a3e7'),
       ('departments.scope_delete PERMISSIVE authenticated DELETE d2d961a3fef22abda8590e3c3fbb0f9a'),
       ('events.audit_insert PERMISSIVE authenticated INSERT 6ff708dfd78c4394ef6440a1cf1aa6a3'),
       ('exchange_rates.scope_delete PERMISSIVE authenticated DELETE e4db04bc4708e7af563e6103ee501a8a'),
       ('journal_entries.scope_delete PERMISSIVE authenticated DELETE 76ad84862b563ac7cf1ffd4d7d06a3e7'),
       ('journal_entries.scope_insert PERMISSIVE authenticated INSERT 1d014b22847bb2764dd4538ec7d36c81'),
       ('journal_entries.scope_read PERMISSIVE authenticated SELECT e4fcf4f527f2d05d88d0bb2e75492f4f'),
       ('journal_entries.scope_update PERMISSIVE authenticated UPDATE 2a156b0d8ef8c8e2689ecc3926c0c2d9'),
       ('journal_entry_lines.scope_delete PERMISSIVE authenticated DELETE 76ad84862b563ac7cf1ffd4d7d06a3e7'),
       ('journal_entry_lines.scope_insert PERMISSIVE authenticated INSERT 1d014b22847bb2764dd4538ec7d36c81'),
       ('journal_entry_lines.scope_update PERMISSIVE authenticated UPDATE 2a156b0d8ef8c8e2689ecc3926c0c2d9'),
       ('scheduled_job_findings.platform_only PERMISSIVE authenticated ALL 18b6c82111707e214f8aaa30c5b6e717'),
       ('security_events.audit_insert PERMISSIVE authenticated INSERT 6ff708dfd78c4394ef6440a1cf1aa6a3'),
       ('subscription_payment_proofs.scope_update PERMISSIVE authenticated UPDATE cf13f1261e4cee095021a2ec7d18bc89'),
       ('subscriptions.scope_delete PERMISSIVE authenticated DELETE 3c10d7f5f74ebcb211dc0e3456897954'),
       ('subscriptions.scope_update PERMISSIVE authenticated UPDATE 4d7d4188d4084ff6515cedb156d9dfc8'),
       ('tenants.scope_delete PERMISSIVE authenticated DELETE 3097a43453b68a82af36118adf211481'),
       ('user_branch_assignments.scope_delete PERMISSIVE authenticated DELETE da74996cfccb795bf15a8f028988fc91'),
       ('user_role_assignments.scope_delete PERMISSIVE authenticated DELETE da74996cfccb795bf15a8f028988fc91'),
       ('users.scope_delete PERMISSIVE authenticated DELETE da74996cfccb795bf15a8f028988fc91')$e$,
     'each of the 22 pinned row-level security policies is present with its recorded definition');

   select set_has(
     $a$select tgrelid::regclass::text || '.' || tgname || ' ' || tgenabled::text || ' ' || md5(pg_get_triggerdef(oid)) from pg_trigger where not tgisinternal and tgrelid::regclass::text not like '%.%'$a$,
     $e$values
       ('booking_items.booking_items_set_updated_at O b1ea83c60dc267e8fcb8bf59ced75c5e'),
       ('bookings.bookings_set_updated_at O 3319cc14a14fadc148591d85d45fbcbe'),
       ('branch_business_hours.branch_business_hours_set_updated_at O dbcb83038e2aa651860f2186b613c03e'),
       ('branches.branches_set_updated_at O 03fa1e058ceaf5239ae94e7b4620c688'),
       ('campaign_daily_metrics.campaign_daily_metrics_set_updated_at O 5cb8c841d649c469a990e48fb908b3e8'),
       ('catalog_values.catalog_values_set_updated_at O 6b904a0c412eab884237069832eac397'),
       ('chart_of_accounts.chart_of_accounts_set_updated_at O 5975e65bc1cd6e0c70e19afc3c51502d'),
       ('company_assets.company_assets_set_updated_at O 42577ae754286556994c743776469ae2'),
       ('complaints.complaints_set_updated_at O a42cbcfc1036379c73cc3823b158eb5a'),
       ('conversations.conversations_set_updated_at O 92f3b312696e8b1ee3ec6d99bf75d05a'),
       ('countries.countries_set_updated_at O 1421fb695e1f97c8648e72a8a012330e'),
       ('currencies.currencies_set_updated_at O 2c174b602b9a4860e97d88421c935457'),
       ('customer_contact_methods.customer_contact_methods_set_updated_at O be0dcf1a24be48859622651a57d66bef'),
       ('customer_notes.customer_notes_set_updated_at O 53f32ebbdfb7de83ff39ea4e9546541e'),
       ('customers.customers_set_updated_at O ccfad2eb150d623c66c1a895877fe5b3'),
       ('departments.departments_set_updated_at O d082b4ea570541fb0a69229ee8403910'),
       ('document_retention_policies.document_retention_policies_set_updated_at O 7d021f1d74e5e5551fc4ca5725b199b6'),
       ('documents.documents_set_updated_at O 688a142b5f7156a844cbd57ffbe42aac'),
       ('financial_accounts.financial_accounts_set_updated_at O 70607e19acaa7500c212178a3fb245fb'),
       ('holidays.holidays_set_updated_at O 712427ed711cb379408f5568c3f58657'),
       ('integration_cursors.integration_cursors_set_updated_at O cb1d99e7a647c036b98ae23c11636b56'),
       ('invoices.invoices_set_updated_at O 0e9059cccfed37bfa0faa4446964af87'),
       ('languages.languages_set_updated_at O 1566d1f8d2f9ce84a2af7ca049d9d830'),
       ('leads.leads_set_updated_at O 55bc1b09f49454cbbc0716cffd1b92c3'),
       ('marketing_campaigns.marketing_campaigns_set_updated_at O 5654e18ca1aaddbea97fbb9ef1ed773f'),
       ('nationalities.nationalities_set_updated_at O 34cbde1b6cc754b4c317774285e41073'),
       ('passengers.passengers_set_updated_at O f4a44b04c9270bc0b0b2a0697b6920c5'),
       ('quotations.quotations_set_updated_at O 577989c945901b4064d56b1e70b29d20'),
       ('refunds.refunds_set_updated_at O 55fc4b1a32bef8150851aa43a853a0d9'),
       ('service_requests.service_requests_set_updated_at O 7dc87d862316be9ac313f2f96fcb5a34'),
       ('subscriptions.subscriptions_set_updated_at O f2bbf2c0599a47eb8c1639fa6697368b'),
       ('suppliers.suppliers_set_updated_at O 65079ebaf30b34d2f72c244ba7f008e0'),
       ('tasks.tasks_set_updated_at O 205616144138d0a973633a15257605e4'),
       ('tenants.tenants_set_updated_at O 63e80e160a8f3f38771ce10b294f1a54'),
       ('user_permission_grants.user_permission_grants_set_updated_at O b80172eb7effbed26f4c46751d253af4'),
       ('users.users_set_updated_at O 24f756d48b64a13b65962916c6dcee9b')$e$,
     'each of the 36 pinned triggers is present with its recorded definition');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 472b404c67b1656b5c0013bbbb86f1b7a2e33b4a.

3. Check whether `supabase/tests/194_door_evidence_and_sale_dates_open_pins_test.sql` contains `select plan(11);`; if so record Already Applied when its Git blob is 0390d2a92ead6a69ff20e2276332adfc9a036c4c, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the OPEN pins test), and change nothing else:

   ```text
   -- pgTAP: the open table-door findings of the documents/quotations re-sweep and the backdated sale (DOC-11, QUO-11,
   -- QUO-12, BOOK-13), pinned as OPEN.
   --
   -- EC-8 / gate re-sweep: SPEC-335 measured each finding at 676df3e and registered it with its class and boundary.
   --   Each OPEN assertion below records the defect as it stands; it is NOT desired behaviour. As Test 130 pins
   --   BRANCH-2, each one FAILS when its finding is repaired, so the repair must update this file and the register
   --   in the same change. A repair that refuses the door write fails the lives_ok step instead.
   --   * DOC-11: a document created at the table door records no document_uploaded, while app.upload_document does.
   --   * QUO-11: a quotation created at the table door records no quotation_created, and door transitions to sent and
   --     accepted record nothing and leave sent_at and accepted_at null.
   --   * QUO-12: the assigned member renumbers and re-leads a quotation, and a manager reassigns its owner, at the
   --     table door with no event; no RPC offers these changes.
   --   * BOOK-13: a member chooses or rewrites the creation date of their own booking and booking item, and
   --     reporting.sales_activity and reporting.my_sales_performance report the chosen date.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(11);

   insert into auth.users (id, email) values
     ('19400000-0000-0000-0000-0000000000a1','emp@t194.test'),
     ('19400000-0000-0000-0000-0000000000a2','mgr@t194.test');
   insert into public.tenants (id, name, slug, status) values
     ('19400000-0000-0000-0000-000000000001','T194 Travel','t194-travel','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '19400000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp
   where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-000000000001','Cairo','t194-cairo');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-00000000000a','sales','Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('19400000-0000-0000-0000-000000000011','19400000-0000-0000-0000-000000000001','Emp','emp@t194.test',true,'19400000-0000-0000-0000-0000000000a1'),
     ('19400000-0000-0000-0000-000000000021','19400000-0000-0000-0000-000000000001','Mgr','mgr@t194.test',true,'19400000-0000-0000-0000-0000000000a2');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
   select '19400000-0000-0000-0000-000000000001', u, '19400000-0000-0000-0000-00000000000a', '19400000-0000-0000-0000-0000000000c1', true
   from unnest(array['19400000-0000-0000-0000-000000000011'::uuid,'19400000-0000-0000-0000-000000000021']) u;
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '19400000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
   from (values ('19400000-0000-0000-0000-000000000011'::uuid,'employee'),
                ('19400000-0000-0000-0000-000000000021'::uuid,'branch_manager')) v(u, rc)
   join public.roles r on r.code = v.rc;
   insert into public.customers (id, tenant_id, customer_type_code, full_name, first_registered_branch_id) values
     ('19400000-0000-0000-0000-0000000000d1','19400000-0000-0000-0000-000000000001','person','Buyer','19400000-0000-0000-0000-00000000000a');
   insert into public.suppliers (id, tenant_id, name, supplier_type_code) values
     ('19400000-0000-0000-0000-0000000000e1','19400000-0000-0000-0000-000000000001','Nile Air','airline');
   insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code, title, lead_status_code) values
     ('19400000-0000-0000-0000-0000000000f1','19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-0000000000d1','direct_call','Lead A','new'),
     ('19400000-0000-0000-0000-0000000000f2','19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-0000000000d1','direct_call','Lead B','new');
   -- Written as `postgres`: emp's booking and the item emp sold.
   insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
       owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
     ('19400000-0000-0000-0000-0000000000b1','19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-0000000000d1','19400000-0000-0000-0000-000000000011','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1','draft','Trip','T194-B1');
   insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
       currency_code, cost_amount, selling_amount, owner_user_id, owner_branch_id, owner_department_id,
       sales_owner_user_id, sales_owner_branch_id, sales_owner_department_id) values
     ('19400000-0000-0000-0000-0000000000b2','19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-0000000000b1','hotel','draft','EGP',100,150,'19400000-0000-0000-0000-000000000011','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-000000000011','19400000-0000-0000-0000-00000000000a','19400000-0000-0000-0000-0000000000c1');

   -- Events recorded on the quotation or document with this number or title, other than the excluded type.
   create function pg_temp.t194_q(p_number text, p_not text default '') returns int language sql as $$
     select count(e.id)::int from public.quotations q join public.events e on e.entity_id = q.id
     where q.tenant_id = '19400000-0000-0000-0000-000000000001' and q.quotation_number = p_number
       and e.event_type_code <> p_not
   $$;
   create function pg_temp.t194_d(p_title text) returns int language sql as $$
     select count(e.id)::int from public.documents d join public.events e on e.entity_id = d.id
     where d.tenant_id = '19400000-0000-0000-0000-000000000001' and d.title = p_title
   $$;
   grant execute on function pg_temp.t194_q(text, text) to authenticated;
   grant execute on function pg_temp.t194_d(text) to authenticated;

   -- ================================================================================================
   -- emp: the RPC doors (positive controls) and the table doors (OPEN pins)
   -- ================================================================================================
   select set_config('request.jwt.claims','{"sub":"19400000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
   set local role authenticated;

   select app.create_quotation('19400000-0000-0000-0000-0000000000d1','EGP','19400000-0000-0000-0000-0000000000f1',null,'T194-RPC');
   select is(pg_temp.t194_q('T194-RPC'), 1,
     'POSITIVE CONTROL: app.create_quotation records exactly one quotation_created');

   select lives_ok(
     $$insert into public.quotations (tenant_id, customer_id, owner_user_id, owner_branch_id, owner_department_id,
         quotation_status_code, quotation_number, currency_code, total_amount)
       values ('19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-0000000000d1',
         '19400000-0000-0000-0000-000000000011','19400000-0000-0000-0000-00000000000a',
         '19400000-0000-0000-0000-0000000000c1','draft','T194-DOOR','EGP',0)$$,
     'the assigned member creates a quotation at the table door');
   select is(pg_temp.t194_q('T194-DOOR'), 0,
     'QUO-11 is OPEN: a quotation created at the table door records no event (FAILS when QUO-11 is repaired)');

   select lives_ok(
     $$update public.quotations set quotation_number = 'T194-RENUMBERED', lead_id = '19400000-0000-0000-0000-0000000000f2'
        where tenant_id = '19400000-0000-0000-0000-000000000001' and quotation_number = 'T194-RPC'$$,
     'QUO-12 is OPEN: the assigned member renumbers and re-leads a quotation at the table door (FAILS when the door refuses it)');
   select is(pg_temp.t194_q('T194-RENUMBERED', 'quotation_created'), 0,
     'QUO-12 is OPEN: the renumbering and re-leading record no event (FAILS when QUO-12 is repaired)');

   select app.upload_document('contract','T194 rpc doc','a.pdf','pdf','supplier','19400000-0000-0000-0000-0000000000e1',100,null,false);
   select ok(pg_temp.t194_d('T194 rpc doc') > 0,
     'POSITIVE CONTROL: app.upload_document records its events');

   insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code, is_confidential)
     values ('19400000-0000-0000-0000-000000000001','contract','T194 door doc','active',false);
   select is(pg_temp.t194_d('T194 door doc'), 0,
     'DOC-11 is OPEN: a document created at the table door records no event (FAILS when DOC-11 is repaired)');

   insert into public.bookings (tenant_id, branch_id, department_id, customer_id, owner_user_id, booking_status_code,
       title, booking_reference, created_at)
     values ('19400000-0000-0000-0000-000000000001','19400000-0000-0000-0000-00000000000a',
       '19400000-0000-0000-0000-0000000000c1','19400000-0000-0000-0000-0000000000d1',
       '19400000-0000-0000-0000-000000000011','draft','Backdated','T194-B2','2001-01-01');
   select is((select string_agg(activity_date::text || ':' || bookings_created, ',' order by activity_date)
                from public.sales_activity where owner_user_id = '19400000-0000-0000-0000-000000000011'),
     '2001-01-01:1,' || current_date::text || ':1',
     'BOOK-13 is OPEN: a booking created at the table door keeps the creation date its member chose, and the sales activity report counts it on that date (FAILS when BOOK-13 is repaired)');

   update public.booking_items set created_at = '2001-01-01' where id = '19400000-0000-0000-0000-0000000000b2';
   select is((select sold_at::date from public.my_sales_performance
               where booking_item_id = '19400000-0000-0000-0000-0000000000b2'), '2001-01-01'::date,
     'BOOK-13 is OPEN: the sales owner rewrites a sold item''s creation date and the performance report shows it as sold then (FAILS when BOOK-13 is repaired)');

   -- ================================================================================================
   -- mgr: door transitions and reassignment (OPEN pins)
   -- ================================================================================================
   reset role;
   select set_config('request.jwt.claims','{"sub":"19400000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
   set local role authenticated;

   select app.add_quotation_item((select id from public.quotations where quotation_number = 'T194-RENUMBERED'),'hotel',100,1,'x');
   update public.quotations set quotation_status_code = 'sent' where quotation_number = 'T194-RENUMBERED';
   update public.quotations set quotation_status_code = 'accepted' where quotation_number = 'T194-RENUMBERED';
   select is((select quotation_status_code || '/' || coalesce(sent_at::text, 'null') || '/' || coalesce(accepted_at::text, 'null')
                     || '/' || pg_temp.t194_q('T194-RENUMBERED', 'quotation_created')
                from public.quotations where quotation_number = 'T194-RENUMBERED'),
     'accepted/null/null/0',
     'QUO-11 is OPEN: door transitions to sent and accepted record no event and leave sent_at and accepted_at null (FAILS when QUO-11 is repaired)');

   update public.quotations set owner_user_id = '19400000-0000-0000-0000-000000000021' where quotation_number = 'T194-RENUMBERED';
   select is((select owner_user_id::text || '/' || pg_temp.t194_q('T194-RENUMBERED', 'quotation_created')
                from public.quotations where quotation_number = 'T194-RENUMBERED'),
     '19400000-0000-0000-0000-000000000021/0',
     'QUO-12 is OPEN: a manager reassigns the quotation''s owner at the table door with no event (FAILS when QUO-12 is repaired)');

   reset role;
   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 0390d2a92ead6a69ff20e2276332adfc9a036c4c.

4. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Last updated: 2026-11-23 (CRM exit bundle J, SPEC-335.`; if so record Already Applied when its Git blob is 984a32d852fa86036f357c2761fa7aca6b9474fe, and otherwise stop and report. Otherwise make exactly these 11 edits (the EC-5, EC-7, EC-8 and EC-10 readings, the gate rows, the CTRL-19 registry row and the dated SPEC-335 header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-23 (CRM exit bundle I, SPEC-334. The EC-5 removal-mutation probe at `8a43a53` removes each check and unique control and each RAISE-bearing row trigger in turn: 87 of 365 valid mutants pass every test that names their table. Test 190 refuses 72 check and unique constraints by name and Test 191 refuses 13 triggers by their own message; the other 2 are equivalent. The EC-6 negative sweep finds a refusal test for each of the 101 member-writable doors and each of the 78 surfaces.)
   ```
   with
   ```text
   Last updated: 2026-11-23 (CRM exit bundle J, SPEC-335. An EC-5 extension probe at `676df3e` removes each of the 301 foreign keys, 125 RLS policies, 78 RLS switches and 121 triggers without RAISE; Test 193 pins the 302 removals no test caught. The `documents`/`quotations` re-sweep and the caller-writable creation stamps register DOC-11, QUO-11, QUO-12 and BOOK-13, each pinned OPEN by Test 194, and STAMP-1 as an accepted residual. Test 192 pins the customer locks of CUST-10 and CUST-12, the two repairs the EC-7 cross-check found with no CI guard. FIN-9 and CTRL-11 are re-checked against Primary. The owner declined CTRL-19's repair on 2026-11-23, so CTRL-19 is an owner-accepted residual.)

   Previously: 2026-11-23 (CRM exit bundle I, SPEC-334. The EC-5 removal-mutation probe at `8a43a53` removes each check and unique control and each RAISE-bearing row trigger in turn: 87 of 365 valid mutants pass every test that names their table. Test 190 refuses 72 check and unique constraints by name and Test 191 refuses 13 triggers by their own message; the other 2 are equivalent. The EC-6 negative sweep finds a refusal test for each of the 101 member-writable doors and each of the 78 surfaces.)
   ```

   b) replace the line
   ```text
   **CRM exit evidence at `8a43a53`, measured 2026-11-23 (SPEC-334, Tests 190 and 191; SPEC-333, Test 189; SPEC-332, Test 188; SPEC-331, Test 187; SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```
   with
   ```text
   **CRM exit evidence at `676df3e`, measured 2026-11-23 (SPEC-335, Tests 192, 193 and 194; SPEC-334, Tests 190 and 191; SPEC-333, Test 189; SPEC-332, Test 188; SPEC-331, Test 187; SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```

   c) replace the lines
   ```text
   - **EC-5 (partial):** SPEC-316 smoke and both pgTAP passes cover exercised invariants. RFD-3 and the PAY-5/FIN-11 unit are fixed by SPEC-326 (Test 184), PAY-4 by SPEC-327 (Test 185), and JE-2 is contained fail-closed by SPEC-327 (Tests 145/185). PAY-9 keeps `FIRST-BOOKING` and DC-11 keeps the finance model; each is classified at its own boundary. SPEC-334 runs a removal-mutation probe at `8a43a53`: it drops each of the 144 check and unique constraints and 33 unique indexes and disables each of the 216 RAISE-bearing row triggers, one at a time, and runs the pgTAP files that name the table. 28 drops are refused because a foreign key depends on the key. Of the 365 valid mutants, 278 fail a test; the 83 caught only by the trigger catalog of Test 187 run one of eight shared functions that a behavioural test runs on another table. Of the 87 survivors, Test 190 refuses 72 by constraint name and Test 191 refuses 13 by trigger message, and removing each fails its own assertion; 2 are equivalent (implied by another check and by the primary key). Foreign keys, triggers without RAISE, function bodies and policies are not mutated, so EC-5 stays partial.
   - **EC-6 (partial):** Check 24 admits the recorded adversarial labels. SPEC-333 sweeps the 101 member-writable doors at `2f8c19a` (52 INSERT, 49 UPDATE, no DELETE): exactly one, UPDATE on `customer_contact_methods`, had no test writing through it, and Test 189 is its targeted negative test across seven controls. SPEC-334 grades the negative side: each of the 101 doors has a refusal assertion writing through it (99 by `throws_*` statement text, 2 by inspection: Tests 47, 131 and 152 read back an RLS-silent UPDATE on `subscription_payment_proofs`, and Test 182 refuses a passengers INSERT built with `format`), and so does each of the 78 surfaces (74 by text, 4 by inspection: Tests 181, 175 and 66). The sweep grades existence; whether each negative test is the strongest case for its door stays with the gate evaluation. Retain the existing evaluation and delivery triggers for the three partial surfaces. Any required proof whose trigger falls after its own prerequisite needs an explicit gate decision.
   - **EC-7 (ceilings closed; closures cross-checked at the gate evaluation):** Existing member repairs carry permanent tests. Test 187 turns the four numeric ceilings with slack into named memberships: Test 07 `<= 42` is the 39 event codes no function or trigger emits, and Test 10 `<= 56`, `<= 20` and `<= 3` are the 52 member-insertable tables, the 5 of them without a capability trigger and the 2 identity tables without any INSERT capability. Each is a set equality, so a new member fails and a removed one must leave the set. Cross-checking each material closure to its actual assertion stays with the gate evaluation.
   - **EC-8 (partial):** Native freshness checks and the reconciled records establish bounded coherence. SPEC-331 resolves two record conflicts: `booking_item_passengers` and `financial_accounts` are AUDITED, because PAX-5, PAX-6 and FA-2 were resolved on 2026-09-09 (Tests 104, 113 and 114). OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 now carry settled statuses, and each keeps its superseded text. SPEC-332 re-verifies N1, DC-5, RC-4, R8, B3 and RC-1 against their migrations at `5bed4ed`: Test 188 proves R8/B3 (`202607048800`) and N1 (`202607049100`), which had no test, and DC-5 (`202607054600`; Tests 48, 49, 97, 116, 175), RC-4 Tier A (`202607048900`; Tests 23, 45, 53) and RC-1 (Tests 42, 66, 148) are settled on their existing tests. The register rows carry the settled statuses with their superseded text. FIN-9 and the `documents`/`quotations` re-sweep keep their gate-evaluation rows.
   - **EC-10 (partial):** Check 20 and SPEC-316 hosted CI establish the guarded inputs and release result. Owner-controlled CTRL-19 independent enforcement evidence and coverage of any important change class outside that list are still owed.
   - **EC-11 (swept; confirmed at the gate evaluation):** Test 187 sweeps every table, trigger, index, policy, constraint, sequence and function in `public`, `app` and `reporting`. It finds no disabled or duplicate trigger, no duplicate or invalid index, no duplicate policy, no unvalidated constraint and no unowned sequence. Exactly one function is reachable from nothing at runtime: `app.document_retention_days(uuid,text)`. It is superseded by RET-1's policy table and kept as the tested lookup, and it leaves the set when RET-1's owner decision retires it or a caller appears. AUTH-1 keeps the retirement trigger for the inert authentication tables, and the `documents`/`quotations` re-sweep keeps its gate-evaluation row.
   ```
   with
   ```text
   - **EC-5 (partial):** SPEC-316 smoke and both pgTAP passes cover exercised invariants. RFD-3 and the PAY-5/FIN-11 unit are fixed by SPEC-326 (Test 184), PAY-4 by SPEC-327 (Test 185), and JE-2 is contained fail-closed by SPEC-327 (Tests 145/185). PAY-9 keeps `FIRST-BOOKING` and DC-11 keeps the finance model; each is classified at its own boundary. SPEC-334 runs a removal-mutation probe at `8a43a53`: it drops each of the 144 check and unique constraints and 33 unique indexes and disables each of the 216 RAISE-bearing row triggers, one at a time, and runs the pgTAP files that name the table. 28 drops are refused because a foreign key depends on the key. Of the 365 valid mutants, 278 fail a test; the 83 caught only by the trigger catalog of Test 187 run one of eight shared functions that a behavioural test runs on another table. Of the 87 survivors, Test 190 refuses 72 by constraint name and Test 191 refuses 13 by trigger message, and removing each fails its own assertion; 2 are equivalent (implied by another check and by the primary key). SPEC-335 extends the probe at `676df3e`: it drops each of the 301 foreign keys, 125 RLS policies and 121 triggers without RAISE, and disables RLS on each of the 78 tables that enable it, one at a time. 300 of the 625 removals fail a file that names the table, and 23 more fail a catalog-wide file (Tests 01, 83, 102 and 187). Test 193 pins the 302 survivors (244 foreign keys, 22 permissive policies and 36 `updated_at` triggers) by presence and definition, and removing each of them fails it. It pins presence, not behaviour, and function bodies are not mutated, so EC-5 stays partial.
   - **EC-6 (partial):** Check 24 admits the recorded adversarial labels. SPEC-333 sweeps the 101 member-writable doors at `2f8c19a` (52 INSERT, 49 UPDATE, no DELETE): exactly one, UPDATE on `customer_contact_methods`, had no test writing through it, and Test 189 is its targeted negative test across seven controls. SPEC-334 grades the negative side: each of the 101 doors has a refusal assertion writing through it (99 by `throws_*` statement text, 2 by inspection: Tests 47, 131 and 152 read back an RLS-silent UPDATE on `subscription_payment_proofs`, and Test 182 refuses a passengers INSERT built with `format`), and so does each of the 78 surfaces (74 by text, 4 by inspection: Tests 181, 175 and 66). The sweep grades existence; whether each negative test is the strongest case for its door stays with the gate evaluation. SPEC-335 moves `documents` and `quotations` to `AUDITED-OPEN`; retain the existing evaluation and delivery trigger for the one partial surface, `offline_conversions`. Any required proof whose trigger falls after its own prerequisite needs an explicit gate decision.
   - **EC-7 (ceilings closed; closures cross-checked at the gate evaluation):** Existing member repairs carry permanent tests. Test 187 turns the four numeric ceilings with slack into named memberships: Test 07 `<= 42` is the 39 event codes no function or trigger emits, and Test 10 `<= 56`, `<= 20` and `<= 3` are the 52 member-insertable tables, the 5 of them without a capability trigger and the 2 identity tables without any INSERT capability. Each is a set equality, so a new member fails and a removed one must leave the set. SPEC-335 cross-checks the 338 repair rows of the register at `676df3e`: 140 name their test, 152 are named by a test, 16 name another guard (a CI-run script, check or catalog assertion), and the 30 with none found were read by hand: contract-tooling repairs guarded by the Finish and CI suites, document corrections whose coherence is EC-8's, verified non-defects, and two recorded closures without a guard (SYNC-2, GOV-12). Two concurrency repairs, CUST-10 and CUST-12, were proven only by `scripts/verify_customer_concurrency.py`, which nothing runs. Test 192 pins both locks in the function bodies: removing them fails its 4 assertions while every other test that names either function still passes. The gate evaluation re-measures this.
   - **EC-8 (partial):** Native freshness checks and the reconciled records establish bounded coherence. SPEC-331 resolves two record conflicts: `booking_item_passengers` and `financial_accounts` are AUDITED, because PAX-5, PAX-6 and FA-2 were resolved on 2026-09-09 (Tests 104, 113 and 114). OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 now carry settled statuses, and each keeps its superseded text. SPEC-332 re-verifies N1, DC-5, RC-4, R8, B3 and RC-1 against their migrations at `5bed4ed`: Test 188 proves R8/B3 (`202607048800`) and N1 (`202607049100`), which had no test, and DC-5 (`202607054600`; Tests 48, 49, 97, 116, 175), RC-4 Tier A (`202607048900`; Tests 23, 45, 53) and RC-1 (Tests 42, 66, 148) are settled on their existing tests. The register rows carry the settled statuses with their superseded text. SPEC-335 settles the gate-evaluation rows at `676df3e`, re-measured at the evaluation: FIN-9's only ledger writer is `app.create_journal_entry`, locally and on Primary, and CTRL-11 finds every business table of Primary empty, so no non-zero count sits under a `NOT REACHED` boundary; both stay accepted residuals. The `documents`/`quotations` re-sweep registers DOC-11 and QUO-11 (`ENABLE-SURFACE-WORKFLOW`) and QUO-12 (`ENABLE-CRM`); the caller-writable creation stamps register BOOK-13 (`FIRST-BOOKING`: `reporting.sales_activity` and `reporting.my_sales_performance` report them) and STAMP-1, an accepted residual (the other 46 have no deciding reader). Test 194 pins each finding OPEN. BRANCH-2's sentence on `created_at` is corrected.
   - **EC-10 (partial):** Check 20 and SPEC-316 hosted CI establish the guarded inputs and release result. CTRL-19's independent enforcement is an owner-accepted residual (SPEC-335): the owner declined its GitHub configuration repair on 2026-11-23, and every release is promoted by `scripts/promote_main.ps1` from a trusted `main` checkout judged by `-Gate -Trusted`, while the agent's credential still administers the repository. Coverage of any important change class outside that list is still owed and is judged at the gate evaluation.
   - **EC-11 (swept; confirmed at the gate evaluation):** Test 187 sweeps every table, trigger, index, policy, constraint, sequence and function in `public`, `app` and `reporting`. It finds no disabled or duplicate trigger, no duplicate or invalid index, no duplicate policy, no unvalidated constraint and no unowned sequence. Exactly one function is reachable from nothing at runtime: `app.document_retention_days(uuid,text)`. It is superseded by RET-1's policy table and kept as the tested lookup, and it leaves the set when RET-1's owner decision retires it or a caller appears. AUTH-1 keeps the retirement trigger for the inert authentication tables. The `documents`/`quotations` re-sweep is done (SPEC-335), and its findings carry their own boundaries.
   ```

   d) immediately after the line
   ```text
   | BOOK-11, BOOK-12 | VERIFIED DEFECT | engineering | `FIRST-BOOKING` | BOOK-12: the rule for when a booking's customer freezes, derived from canon and escalated to the owner only if not derivable | Medium. Door cancellation leaves no reason, stamp or event; the customer can be rebound before issuance |
   ```
   insert
   ```text
   | BOOK-13 | VERIFIED DEFECT | engineering | `FIRST-BOOKING` | — | Low. A member chooses or rewrites the creation date of their own booking and booking item, and `reporting.sales_activity` and `reporting.my_sales_performance` report that date. The platform owns both stamps before the first production booking (SPEC-335, Test 194) |
   ```

   e) replace the line
   ```text
   | CAMP-4, BRANCH-2, PAX-8 | VERIFIED DEFECT | engineering | `ENABLE-SURFACE-WORKFLOW` | — | Low. Audit and timeline evidence is missing at a table door, and each finding's measured bound is that nothing reads it. At the gate the bound is re-measured: if it holds, the item becomes an explicit accepted residual; otherwise it is repaired. Never deferred silently. SPEC-326 and Test 184 close CHAT-2 on Platinum Primary: the conversation guard stamps `closed_at` and requires a reopen reason, and the table records each transition once on both doors. |
   ```
   with
   ```text
   | QUO-12 | VERIFIED DEFECT | engineering | `ENABLE-CRM` | BOOK-9's rule: a reassignment needs a permission, a reason and an event | Low. The assigned member renumbers and re-leads a quotation, and a manager reassigns its owner, at the table door with no event; no RPC offers these changes (SPEC-335, Test 194) |
   | CAMP-4, BRANCH-2, PAX-8, DOC-11, QUO-11 | VERIFIED DEFECT | engineering | `ENABLE-SURFACE-WORKFLOW` | — | Low. Audit and timeline evidence is missing at a table door, and each finding's measured bound is that nothing reads it. At the gate the bound is re-measured: if it holds, the item becomes an explicit accepted residual; otherwise it is repaired. Never deferred silently. SPEC-326 and Test 184 close CHAT-2 on Platinum Primary: the conversation guard stamps `closed_at` and requires a reopen reason, and the table records each transition once on both doors. SPEC-335 adds DOC-11 and QUO-11 (Test 194), whose missing events only the customer and lead timelines would read; their bound is re-measured the same way. |
   ```

   f) replace the lines
   ```text
   | CTRL-11 | ACCEPTED RESIDUAL | engineering | `GATE-EVAL` | — | A boundary's state is recorded by a contract, never observed: the guard cannot read Primary. Containment: provisioning a tenant needs `service_role`, and READY requires this gate's evaluation. At `GATE-EVAL`, and in every contract that enables a boundary, each boundary state is confirmed against Primary's business counts. A non-zero count under a `NOT REACHED` boundary is repaired before anything else |
   | CTRL-19 | VERIFIED DEFECT | owner | `GATE-EVAL` | the owner's GitHub configuration: the agent as a separate Write collaborator in its own OS account, and `main` updatable only by the owner's account | High. Until the owner acts, a candidate can certify itself through the check it defines. `scripts/promote_main.ps1`, run by the owner from a `main` checkout, is the promotion that does not trust the candidate |
   ```
   with
   ```text
   | CTRL-11 | ACCEPTED RESIDUAL | engineering | `GATE-EVAL` | — | A boundary's state is recorded by a contract, never observed: the guard cannot read Primary. Containment: provisioning a tenant needs `service_role`, and READY requires this gate's evaluation. At `GATE-EVAL`, and in every contract that enables a boundary, each boundary state is confirmed against Primary's business counts. A non-zero count under a `NOT REACHED` boundary is repaired before anything else. **2026-11-23 (SPEC-335):** confirmed against Primary at `676df3e`: every business table holds 0 rows |
   | CTRL-19 | ACCEPTED RESIDUAL | owner | `OWN-TRIGGER` | — | High, accepted by the owner on 2026-11-23 (SPEC-335), who declined the GitHub configuration repair with the code and migration work nearly finished. Containment: every release is promoted by `scripts/promote_main.ps1` from a trusted `main` checkout and judged by `check_agent_continuity.ps1 -Gate -Trusted`, never by the candidate's own evaluator. Residual: the agent's credential still administers the repository. Reopened by the first real tenant on Primary, or by any other person or agent account gaining write access |
   ```

   g) replace the line
   ```text
   | FIN-9 | ACCEPTED RESIDUAL | engineering | `GATE-EVAL` | — | The residual writer is only the platform writer; the gate re-checks that the platform's operational write path uses the RPC |
   ```
   with
   ```text
   | FIN-9 | ACCEPTED RESIDUAL | engineering | `GATE-EVAL` | — | The residual writer is only the platform writer; the gate re-checks that the platform's operational write path uses the RPC. **2026-11-23 (SPEC-335):** re-checked at `676df3e`: the only function that writes the ledger is `app.create_journal_entry`, locally and on Primary, and `authenticated` holds no INSERT or UPDATE on either ledger table |
   ```

   h) immediately after the line
   ```text
   | JE-6 | ACCEPTED RESIDUAL | engineering | `OWN-TRIGGER` | — | Reopened by the first reader of `source_entity_id` |
   ```
   insert
   ```text
   | STAMP-1 | ACCEPTED RESIDUAL | engineering | `OWN-TRIGGER` | — | Reopened by the first function, view, policy or report that decides or reports by a caller-writable creation stamp |
   ```

   i) replace the line
   ```text
   | `documents`, `quotations` | SURFACE | engineering | `GATE-EVAL` | — | `PARTIAL`: door-created event parity (the family of CHAT-2's row) and a caller-writable `created_at` read only by `app.financial_documents`' listing are re-swept at the first evaluation |
   ```
   with
   ```text
   | `documents` | SURFACE | engineering | `ENABLE-SURFACE-WORKFLOW` | DOC-11 | `AUDITED-OPEN` (SPEC-335): the re-sweep registers door event parity as DOC-11; the caller-writable `created_at` is STAMP-1 |
   | `quotations` | SURFACE | engineering | `ENABLE-CRM` | QUO-11 and QUO-12 | `AUDITED-OPEN` (SPEC-335): door event parity and the transition stamps are QUO-11 (`ENABLE-SURFACE-WORKFLOW`), the unrecorded reassignment is QUO-12, and the caller-writable stamps are STAMP-1 |
   ```

   j) replace the line
   ```text
   | `bookings` | SURFACE | engineering | `FIRST-BOOKING` | BOOK-11 and BOOK-12 | SPEC-319 and Test 182 verify ARCH-2 at entry on Platinum Primary. SPEC-239 fixes booking entry and issuance, and SPEC-224 fixes PAX-9. BOOK-11 and BOOK-12 remain open at FIRST-BOOKING. |
   ```
   with
   ```text
   | `bookings`, `booking_items` | SURFACE | engineering | `FIRST-BOOKING` | BOOK-11, BOOK-12 and BOOK-13 | SPEC-319 and Test 182 verify ARCH-2 at entry on Platinum Primary. SPEC-239 fixes booking entry and issuance, and SPEC-224 fixes PAX-9. BOOK-11 and BOOK-12 remain open at FIRST-BOOKING. SPEC-335 registers BOOK-13 on both tables, so `booking_items` is `AUDITED-OPEN` again. |
   ```

   k) immediately after the lines
   ```text
   **Recorded exception, 2026-11-23, CRM exit bundle I.** After CRM SPEC-333 at `8a43a537cbd06cd9df6b636ac80fc1d658c1e88b`, the Batch 6 delegation continues to `B6-EXIT` in the owner's AFK mode. SPEC-334 adds Test 190, which refuses the 72 check and unique constraints the EC-5 mutation probe found unpinned, and Test 191, which refuses the 13 unpinned triggers; the EC-5 and EC-6 readings cite the probe and the negative sweep. It changes no migration or database object, and EC-5 and EC-6 stay partial. The Original and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-23, CRM exit bundle J.** After CRM SPEC-334 at `676df3e46fffae83366fa4c177a74d327edd6381`, the Batch 6 delegation continues to `B6-EXIT` in the owner's AFK mode. SPEC-335 adds Test 192, which pins the two customer locks the EC-7 cross-check found guarded by nothing that runs, Test 193, which pins the presence of the structural controls the extended EC-5 probe found unpinned, and Test 194, which pins DOC-11, QUO-11, QUO-12 and BOOK-13 OPEN. It registers those four findings and STAMP-1 from the `documents`/`quotations` re-sweep, settles the FIN-9 and CTRL-11 gate rows against Primary, and moves `documents`, `quotations` and `booking_items` to `AUDITED-OPEN`. It changes no migration or database object. `B6-EXIT` stays `NOT REACHED` until the gate evaluation re-measures; The owner declined CTRL-19's GitHub configuration repair on 2026-11-23, so SPEC-335 records CTRL-19 as an accepted residual with its containment and reopening trigger, and EC-10 no longer waits on the owner. The Original and release gates remain enforced.

   ```

   The resulting file's Git blob is 984a32d852fa86036f357c2761fa7aca6b9474fe.

5. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `Last updated: 2026-11-23 (CRM SPEC-335 registers DOC-11`; if so record Already Applied when its Git blob is 424d084a30c76058ee2a081004d317f6e2b909c5, and otherwise stop and report. Otherwise make exactly these 7 edits (the DOC-11, QUO-11, QUO-12, BOOK-13 and STAMP-1 rows, the BRANCH-2 correction and CTRL-19 as an accepted residual), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-23 (CRM SPEC-332 settles R8/B3 and N1 on Test 188 and DC-5, RC-4 and RC-1 on their existing tests, each keeping its superseded status, and adds no finding.)
   ```
   with
   ```text
   Last updated: 2026-11-23 (CRM SPEC-335 registers DOC-11, QUO-11, QUO-12 and BOOK-13 from the `documents`/`quotations` re-sweep and the caller-writable creation stamps, each pinned OPEN by Test 194, records STAMP-1 as an accepted residual, corrects BRANCH-2's sentence on `created_at`, and records CTRL-19 as an accepted residual by the owner's decision of 2026-11-23.)

   Previously: 2026-11-23 (CRM SPEC-332 settles R8/B3 and N1 on Test 188 and DC-5, RC-4 and RC-1 on their existing tests, each keeping its superseded status, and adds no finding.)
   ```

   b) immediately after the line
   ```text
   | DOC-10 | **A link moved by UPDATE took a document off the record it belonged to and was recorded nowhere** | audit completeness · observability | Low | R | 6 | M | ✅ | **✅ FIXED 2026-11-12 (SPEC-306, `20261112150000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-306; the fresh Primary ledger, functions and structure equal local.** **MEASURED** at `789e056`: an `employee` moved the ticket link of their booking to another of their bookings; the tenant's events did not move and `app.derive_created_by` keeps the creator, so nothing showed who took the ticket off the booking. A new link is attributed by its own row (`created_by` derived and immutable); `app.upload_document` records `document_linked` for its link. **Repaired:** `app.guard_document_link_readable` (BEFORE INSERT OR UPDATE, SECURITY INVOKER, session writes only) refuses a link whose document the writer cannot already read under the `documents` policy; `app.emit_document_link_move` (AFTER UPDATE, SECURITY DEFINER) records a moved link as `document_linked` with the link id and the previous and current document and target. `165_a_document_is_linked_only_by_someone_who_can_read_it_test.sql` pins both. An update that moves nothing and a session-less write record nothing. | — | SPEC-306-a-document-is-linked-only-by-someone-who-can-read-it | 11-12 | 11-12 |
   ```
   insert
   ```text
   | DOC-11 | **A document created at the table door records no `document_uploaded`, while `app.upload_document` records the same act** | audit completeness · observability | Low | R | 6 | — | 📋 | **OPEN — found by the SPEC-335 re-sweep of `documents` and `quotations` (the gate's `GATE-EVAL` row), deliberately not repaired.** MEASURED at `676df3e`, rolled back: an `employee` at aal2 uploaded a document through `app.upload_document`, which recorded `document_uploaded` and `document_linked`, and inserted another at the table door, which recorded no event. Its creator is server-derived and it carries no file until a recorded version is added. **Low, and the bound is measured:** the only readers of these events are `app.customer_timeline` and `app.lead_timeline`, so the loss is timeline completeness. CAMP-4's and BRANCH-2's shape; it joins their registry row at `ENABLE-SURFACE-WORKFLOW`. The door's caller-writable `created_at` is STAMP-1. `194_door_evidence_and_sale_dates_open_pins_test.sql` pins it OPEN and fails when it is repaired. | — | SPEC-335-the-exit-evidence-gaps-are-pinned-and-the-re-sweep-registered | 11-23 | 11-23 |
   ```

   c) replace the line
   ```text
   | CTRL-19 | **The required check is computed by code the candidate controls, and the agent's credential administers the ruleset** | governance / control plane · trust boundary | High | R | — | — | 📋 | **OPEN — PROVEN 2026-10-14; the repair is GitHub configuration outside the repository.** Ruleset 22950574 requires `orvion-acceptance` on `main` with zero bypass, but that check runs the candidate's own workflow and evaluator, and GitHub counts a `skipped` or `neutral` required check as passing. Test 281-T1: a candidate that neuters its own evaluator is READY under it. The agent pushes as the owner's own account, which administers the repository, so it could also change the ruleset. GitHub grants a ruleset bypass to roles, teams and apps rather than to tokens, so a restricted token of that account is not a reliable way to keep the agent off `main`; a separate collaborator without administration is. SPEC-281 adds `-Gate -Trusted`, which judges a candidate with an evaluator from a `main` checkout, on data that is exactly the candidate SHA, executing no candidate file (tests 281-T1…T4), and `scripts/promote_main.ps1`, which the owner runs from a clean checkout of `main` to push one candidate SHA only after that judgment, under a lease on the `main` it judged (tests 281-R1…R5). **Not enforced until the owner acts.** | owner: run the agent as a separate collaborator without administration, in an OS account that holds none of the owner's credentials; let only the owner's account update `main`; promote with `scripts/promote_main.ps1` | SPEC-281 | 10-14 | 10-14 |
   ```
   with
   ```text
   | CTRL-19 | **The required check is computed by code the candidate controls, and the agent's credential administers the ruleset** | governance / control plane · trust boundary | High | R | — | — | 📋 | **OPEN — accepted residual by the owner's decision of 2026-11-23 (SPEC-335); not enforced, contained by the promotion path.** PROVEN 2026-10-14; the repair is GitHub configuration outside the repository. Ruleset 22950574 requires `orvion-acceptance` on `main` with zero bypass, but that check runs the candidate's own workflow and evaluator, and GitHub counts a `skipped` or `neutral` required check as passing. Test 281-T1: a candidate that neuters its own evaluator is READY under it. The agent pushes as the owner's own account, which administers the repository, so it could also change the ruleset. GitHub grants a ruleset bypass to roles, teams and apps rather than to tokens, so a restricted token of that account is not a reliable way to keep the agent off `main`; a separate collaborator without administration is. SPEC-281 adds `-Gate -Trusted`, which judges a candidate with an evaluator from a `main` checkout, on data that is exactly the candidate SHA, executing no candidate file (tests 281-T1…T4), and `scripts/promote_main.ps1`, which the owner runs from a clean checkout of `main` to push one candidate SHA only after that judgment, under a lease on the `main` it judged (tests 281-R1…R5). **Not enforced: on 2026-11-23 the owner declined the repair, judging it not worth its cost with the code and migration work nearly finished.** Containment: every release is promoted by `scripts/promote_main.ps1` from a trusted `main` checkout and judged by `check_agent_continuity.ps1 -Gate -Trusted`, never by the candidate's own evaluator. Residual: the agent's credential still administers the repository, so the release path holds by that route, not by a native control against the credential. Reopened by the first real tenant on Primary, or by any other person or agent account gaining write access. | owner, 2026-11-23: accepted residual, repair declined. At the trigger: run the agent as a separate collaborator without administration, in an OS account that holds none of the owner's credentials; let only the owner's account update `main`; promote with `scripts/promote_main.ps1` | SPEC-281 | 10-14 | 11-23 |
   ```

   d) immediately after the line
   ```text
   | BOOK-12 | **A booking's customer can be rebound before issuance, so the negative-balance override judges a customer who owes nothing** | authorization · financial risk | Medium | R | 6 | — | 📋 | **OPEN — found by SPEC-239's adversarial pass, on the sanctioned path as well; deliberately not repaired.** MEASURED at `2496591`, rolled back: a `branch_manager` holding ISSUE_BOOKING with a per-user deny on ALLOW_ISSUE_WITH_NEGATIVE_BALANCE, refused issuing a booking whose customer owed 5000 EGP, rebound the booking to another customer of the tenant by direct UPDATE of `customer_id` (1 row) and then issued it through `app.advance_booking` with no refusal and no risk flag. Cause: `app.customer_balance(customer, booking)` counts the invoices of that customer on that booking, the invoice stays with the first customer, and nothing freezes a booking's customer once it is invoiced. SPEC-239 closes the one-statement form (the trigger judges the booking as it stood), not this two-statement one. Not BOOK-10: this is not door parity -- the RPC is equally exposed. Repair needs a business rule on when a booking's customer may change. **Latent:** Primary holds 0 bookings and 0 per-user denies. Reopening trigger: before the first production booking. | — | SPEC-239-issuance-holds-on-every-door | 09-29 | 09-29 |
   ```
   insert
   ```text
   | BOOK-13 | **A member chooses or rewrites the creation date of their own booking and booking item, and the sales reports date the sale by it** | reporting integrity · audit | Low | R | 6 | — | 📋 | **OPEN — found by SPEC-335's measurement of the caller-writable creation stamps, deliberately not repaired.** MEASURED at `676df3e`, rolled back: an `employee` inserted a booking at the table door with `created_at = 2001-01-01`, rewrote it to 2002-02-02, and `public.sales_activity` (`reporting.sales_activity`, `activity_date` = `bookings.created_at::date`) reported the booking on 2002-02-02; the sales owner rewrote a booking item's `created_at` and `public.my_sales_performance` (`sold_at` = `booking_items.created_at`) reported it sold on 2001-01-01. Both views are security-invoker and granted to `authenticated`. **Low:** no money moves and no commission payout exists, but once production bookings exist the reports misstate when a sale happened. **Latent:** Primary holds 0 bookings. Fix unit: the platform owns both stamps (no caller value at INSERT, frozen at UPDATE). `194_door_evidence_and_sale_dates_open_pins_test.sql` pins it OPEN. Reopening trigger: before the first production booking. | — | SPEC-335-the-exit-evidence-gaps-are-pinned-and-the-re-sweep-registered | 11-23 | 11-23 |
   ```

   e) immediately after the line
   ```text
   | QUO-10 | **A line could leave a SENT quotation, or reach one while it was being sent, and the emptied quotation was accepted at 0** | financial integrity · state · concurrency | Medium | R | 6 | M | ✅ | **✅ FIXED 2026-10-10 (SPEC-258, `20261010140000`), DEPLOYED to Primary under separate exact-byte owner authorization; the fresh Primary ledger, function surface and all ten structural surfaces match local.** **The rule** is QUO-2's: a sent quotation's lines are the customer's offer; `app.add_quotation_item` locks the quotation `for update` before refusing any status but `draft`, and no sanctioned writer moves a line. **MEASURED** at `44c09d8`: after a quotation was sent through `app.advance_quotation` with its one 1,000 line, a direct UPDATE of the line's `quotation_id` moved it to a draft; the sent quotation held 0 lines and 0 against its `quotation_sent` of 1,000, and was then accepted at 0. The editable-parent guard judged only the line's NEW quotation, and the denied employee of QUO-9 moved a line the same way. In two concurrent sessions a direct INSERT read the quotation as `draft` while a send held its lock, waited, and committed onto the sent quotation (1,300 against 1,000); the RPC under the same timing re-read `sent` and refused. **Found while attacking the repair:** the guard runs as its definer before RLS's WITH CHECK, and answered an employee naming another tenant's SENT quotation with that quotation's state (23514) where RLS would have refused. **REPAIRED** in the same guard, for every caller: `quotation_id` cannot change (23514), and the quotation is read `for update`, for a signed-in caller only within its own tenant, so the race waits and is refused and a foreign quotation is refused by RLS (42501). Test 150 pins it (assertions 19–29 and 31); mutants M1, M5 and M6 are killed, M5 also in two sessions. | — | SPEC-258-a-quotation-line-stays-on-its-quotation-at-its-own-price | 10-10 | 10-10 |
   ```
   insert
   ```text
   | QUO-11 | **A quotation created or moved to `sent` or `accepted` at the table door records no event and leaves the transition stamps empty** | audit completeness · observability | Low | R | 6 | — | 📋 | **OPEN — found by the SPEC-335 re-sweep of `documents` and `quotations` (the gate's `GATE-EVAL` row), deliberately not repaired.** MEASURED at `676df3e`, rolled back: `app.create_quotation` recorded one `quotation_created` and a table-door create by the same member recorded none; a `branch_manager`'s door transitions to `sent` and then `accepted` recorded no event and left `sent_at` and `accepted_at` null. SPEC-214's axes (1) and (4). **Low, and the bound is measured:** the only readers of these events are `app.customer_timeline` and `app.lead_timeline`, and nothing reads `sent_at`, `accepted_at` or `rejected_at`; the caller-writable stamps are STAMP-1. It joins CAMP-4's registry row at `ENABLE-SURFACE-WORKFLOW`. `194_door_evidence_and_sale_dates_open_pins_test.sql` pins it OPEN. | — | SPEC-335-the-exit-evidence-gaps-are-pinned-and-the-re-sweep-registered | 11-23 | 11-23 |
   | QUO-12 | **A quotation's number, lead and owner can be reassigned at the table door with no event, and no RPC offers the change** | authorization · audit completeness | Low | R | 6 | — | 📋 | **OPEN — found by the SPEC-335 re-sweep of `documents` and `quotations` (the gate's `GATE-EVAL` row), deliberately not repaired.** MEASURED at `676df3e`, rolled back: the assigned `employee` renumbered a quotation created through the RPC and moved it to another lead, and a `branch_manager` reassigned its `owner_user_id`, each at the table door with no event. SPEC-214's axis (2). The reassignment moves timeline attribution, visibility, `app.is_document_responsible`, the displayed key and the event payload's `lead_id`; no money moves and the conversions do not read it. **Low.** BOOK-9's rule applies: a reassignment needs a permission, a reason and an event. `194_door_evidence_and_sale_dates_open_pins_test.sql` pins it OPEN; a repair that refuses the door write fails its `lives_ok` step instead. | engineering: which fields may change after creation and under which permission, by BOOK-9's rule, escalating to the owner only if canon cannot answer | SPEC-335-the-exit-evidence-gaps-are-pinned-and-the-re-sweep-registered | 11-23 | 11-23 |
   ```

   f) replace the line
   ```text
   | BRANCH-2 | **A branch created at the table door records no `branch_created`, while `app.create_branch` records the same act** | audit completeness · observability | Low | R | 6 | — | 📋 | **OPEN — reproduced in Batch 6 Slice 24 and recorded, deliberately not repaired.** MEASURED in rolled-back local transactions: three branches were created in one tenant, one by the owner's `app.create_branch` at `aal2`, one by direct INSERT at `aal2` and one by direct INSERT at `aal1` (BRANCH-1), and the tenant gained exactly one `branch_created` event. `branches` has no creator column, so for a branch created at the table door nothing records who created it. **Low, and the bound is measured:** the only function that names `branch_created` is its producer and nothing consumes the event, so the loss is audit and timeline completeness. CAMP-4's shape on another surface; SUP-5's single AFTER INSERT producer is the existing mechanism if this is repaired. **Not part of this finding:** the same direct INSERT also stored a caller-supplied `created_at = 2001-01-01`. That is the caller-writable `created_at` that SPEC-216 recorded as "a question that stands on every table with such a column" and SPEC-218 left unregistered on `customer_contact_methods`: no function in `app` or `public` assigns `new.created_at` on any table, SUP-5's repair left `suppliers.created_at` caller-writable, and nothing reads `branches.created_at`, so repairing this finding would not change it. `130_branch_door_audit_test.sql` assertion 19 pins it OPEN and fails when it is repaired. | — | SPEC-226-branch-door-audit-record | 09-27 | 09-27 |
   ```
   with
   ```text
   | BRANCH-2 | **A branch created at the table door records no `branch_created`, while `app.create_branch` records the same act** | audit completeness · observability | Low | R | 6 | — | 📋 | **OPEN — reproduced in Batch 6 Slice 24 and recorded, deliberately not repaired.** MEASURED in rolled-back local transactions: three branches were created in one tenant, one by the owner's `app.create_branch` at `aal2`, one by direct INSERT at `aal2` and one by direct INSERT at `aal1` (BRANCH-1), and the tenant gained exactly one `branch_created` event. `branches` has no creator column, so for a branch created at the table door nothing records who created it. **Low, and the bound is measured:** the only function that names `branch_created` is its producer and nothing consumes the event, so the loss is audit and timeline completeness. CAMP-4's shape on another surface; SUP-5's single AFTER INSERT producer is the existing mechanism if this is repaired. **Not part of this finding:** the same direct INSERT also stored a caller-supplied `created_at = 2001-01-01`. That is the caller-writable `created_at` that SPEC-216 recorded as "a question that stands on every table with such a column" and SPEC-218 left unregistered on `customer_contact_methods`: no function in `app` or `public` assigned `new.created_at` on any table at the time (corrected by SPEC-335: at `676df3e` `app.guard_customer_note_integrity` does, and the caller-writable stamps are STAMP-1), SUP-5's repair left `suppliers.created_at` caller-writable, and nothing reads `branches.created_at`, so repairing this finding would not change it. `130_branch_door_audit_test.sql` assertion 19 pins it OPEN and fails when it is repaired. | — | SPEC-226-branch-door-audit-record | 09-27 | 09-27 |
   ```

   g) immediately after the line
   ```text
   | JE-6 | **`app.create_journal_entry` stores any `source_entity_id`, including a nonexistent one or another tenant's entity** | financial integrity · provenance | Low | R | 6 | — | 📋 | **OPEN -- recorded, deliberately not repaired (Batch 6 Slice 33, SPEC-246).** MEASURED at `7e6f51e`, rolled back: a `finance_manager` at aal2 posted through the RPC with `source_entity_id` set to another tenant's invoice, to a nonexistent id, and to an id on a `manual_entry`, and all three committed. The column has no foreign key: it is polymorphic over `journal_entry_source_type`. **Low:** no disclosure was demonstrated (the RPC stores the id and reads nothing behind it), and no function, view or report reads the column. **Not repaired because the authority is unresolved:** canon names the source types but not which table each points to, nor whether a manual entry may carry a source; inventing that model would be business policy (`AGENTS.md §6`). Separate from JE-5, whose repair closes the header's table door and leaves this RPC and its input handling unchanged. | engineering: decide the source-type-to-entity mapping and manual-entry semantics when the first reader of `source_entity_id` is built, escalating to the owner only if canon cannot answer them | SPEC-246-a-posted-journal-entry-is-never-rewritten | 10-08 | 10-08 |
   ```
   insert
   ```text
   | STAMP-1 | **A member can write the creation stamp of most tables they can write, and no deciding reader reads it** | audit · provenance | Low | R | 6 | — | 📋 | **OPEN — accepted residual, deliberately not repaired.** MEASURED at `676df3e` (catalog): `authenticated` may write `created_at` on 48 tables; only `app.guard_customer_note_integrity` assigns `new.created_at`, and five guards (trusted devices, payment allocations, receipts, user role assignments, customer notes) freeze it on update. No policy reads `created_at`; the function readers read tables members cannot write or use it for display order only (`app.financial_documents`). The two readers that decide something, the sales reports over `bookings` and `booking_items`, are BOOK-13. The other 46 stamps have no deciding reader. Reopening trigger: the first function, view, policy or report that decides or reports by such a column (JE-6's precedent). | engineering: re-measure at the reopening trigger and repair that table's stamp in the same change | SPEC-335-the-exit-evidence-gaps-are-pinned-and-the-re-sweep-registered | 11-23 | 11-23 |
   ```

   The resulting file's Git blob is 424d084a30c76058ee2a081004d317f6e2b909c5.

6. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `Last updated: 2026-11-23 (CRM SPEC-335 re-dispositions`; if so record Already Applied when its Git blob is 222ee26cf30b5dff7b0bef93c76416b2c2fa7d6f, and otherwise stop and report. Otherwise make exactly these 5 edits (the documents, quotations and booking_items dispositions), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-22 (CRM SPEC-331 re-dispositions booking_item_passengers and financial_accounts as AUDITED, because PAX-5, PAX-6 and FA-2 were resolved on 2026-09-09.)
   ```
   with
   ```text
   Last updated: 2026-11-23 (CRM SPEC-335 re-dispositions `documents` and `quotations` from PARTIAL and `booking_items` from AUDITED to AUDITED-OPEN, because the re-sweep registers DOC-11, QUO-11, QUO-12 and BOOK-13.)

   Previously: 2026-11-22 (CRM SPEC-331 re-dispositions booking_item_passengers and financial_accounts as AUDITED, because PAX-5, PAX-6 and FA-2 were resolved on 2026-09-09.)
   ```

   b) replace the line
   ```text
   **78 of 78 recorded · 64 `AUDITED` · 11 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 0 `NOT-RECORDED`.**
   ```
   with
   ```text
   **78 of 78 recorded · 63 `AUDITED` · 14 `AUDITED-OPEN` · 1 `PARTIAL` · 0 `EXEMPT` · 0 `NOT-RECORDED`.**
   ```

   c) replace the lines
   ```text
   | `booking_items` | **AUDITED** | ADVERSARIAL | session-2026-09-07-batch6-slice5-booking-items | BOOK-8, BOOK-9 | `105_booking_item_service_door_test.sql` — **44 assertions, all ten attack classes, none N/A.** `202607061500` closed **BOOK-3** (the bare booked service, and its whole UPDATE half: service type, currency, ownership and re-parenting were all free), **BOOK-4** (a cross-tenant existence-and-state oracle, PAX-3 one table up), **BOOK-5** (the canon-28 scope check read the attacker's own post-image), **BOOK-6** (the finance execution gate was clearable) and **BOOK-7** (a priced item could be redenominated). `AUDITED-OPEN` rather than `AUDITED` because two remain and **neither is engineering**: **BOOK-8** is a business decision (may a finance-approval requirement be withdrawn) and **BOOK-9** a canon one (booking items have no reassignment permission where leads have REASSIGN_LEAD). **2026-11-21 (CRM SPEC-324):** `AUDITED`, because BOOK-8 and BOOK-9 are resolved in the gap register; `20261121100000` and `183_entry_and_step_up_hold_at_the_table_door_test.sql` close this door's ARCH-2 member (archive authority at INSERT) and ENTRY-1 member (a signed-in creation opens at `draft` with no lifecycle stamp, the RPC door and session-less paths unchanged), verified on Platinum Primary |
   | `bookings` | **AUDITED-OPEN** | ADVERSARIAL | `SPEC-239-issuance-holds-on-every-door` | PAX-9, BOOK-10, BOOK-11, BOOK-12, ARCH-2 | `129_manifest_freeze_cannot_be_left_test.sql` proves that once a booking's status freezes its passenger manifest, an employee is refused carrying its item out, moving entries off or on, inserting a traveller and bringing a traveller-carrying item in, each by its own message; correction holders (including a finance manager) need a fresh reason and are server-stamped, with the linked/replaced event carrying it; correction evidence cannot be forged at birth; the platform path gets no exemption; an installed/restored mutation of `app.manifest_is_frozen` reopens every operation. Capability with step-up, the per-transition status permission, archive authority and scope-aware RLS were already held by existing controls. **2026-09-29 (SPEC-239):** `141_issuance_holds_on_every_door_test.sql` closes **BOOK-10** for issuance — the override, the risk flag and one `booking_issued` on the RPC, table and platform doors, the archived rule on every transition, and `draft` at birth — with an in-file mutation. **BOOK-11 and BOOK-12 remain OPEN.** CRM SPEC-319 and `182_archive_authority_applies_at_entry_test.sql` verify the ARCH-2 booking member on Platinum Primary. BOOK-11 and BOOK-12 remain open. |
   ```
   with
   ```text
   | `booking_items` | **AUDITED-OPEN** | ADVERSARIAL | session-2026-09-07-batch6-slice5-booking-items | BOOK-8, BOOK-9, BOOK-13 | `105_booking_item_service_door_test.sql` — **44 assertions, all ten attack classes, none N/A.** `202607061500` closed **BOOK-3** (the bare booked service, and its whole UPDATE half: service type, currency, ownership and re-parenting were all free), **BOOK-4** (a cross-tenant existence-and-state oracle, PAX-3 one table up), **BOOK-5** (the canon-28 scope check read the attacker's own post-image), **BOOK-6** (the finance execution gate was clearable) and **BOOK-7** (a priced item could be redenominated). `AUDITED-OPEN` rather than `AUDITED` because two remain and **neither is engineering**: **BOOK-8** is a business decision (may a finance-approval requirement be withdrawn) and **BOOK-9** a canon one (booking items have no reassignment permission where leads have REASSIGN_LEAD). **2026-11-21 (CRM SPEC-324):** `AUDITED`, because BOOK-8 and BOOK-9 are resolved in the gap register; `20261121100000` and `183_entry_and_step_up_hold_at_the_table_door_test.sql` close this door's ARCH-2 member (archive authority at INSERT) and ENTRY-1 member (a signed-in creation opens at `draft` with no lifecycle stamp, the RPC door and session-less paths unchanged), verified on Platinum Primary. **2026-11-23 (CRM SPEC-335):** `AUDITED-OPEN`: **BOOK-13**, the sales owner rewrites a sold item's `created_at` and `reporting.my_sales_performance` reports it sold then; `194_door_evidence_and_sale_dates_open_pins_test.sql` pins it OPEN |
   | `bookings` | **AUDITED-OPEN** | ADVERSARIAL | `SPEC-239-issuance-holds-on-every-door` | PAX-9, BOOK-10, BOOK-11, BOOK-12, BOOK-13, ARCH-2 | `129_manifest_freeze_cannot_be_left_test.sql` proves that once a booking's status freezes its passenger manifest, an employee is refused carrying its item out, moving entries off or on, inserting a traveller and bringing a traveller-carrying item in, each by its own message; correction holders (including a finance manager) need a fresh reason and are server-stamped, with the linked/replaced event carrying it; correction evidence cannot be forged at birth; the platform path gets no exemption; an installed/restored mutation of `app.manifest_is_frozen` reopens every operation. Capability with step-up, the per-transition status permission, archive authority and scope-aware RLS were already held by existing controls. **2026-09-29 (SPEC-239):** `141_issuance_holds_on_every_door_test.sql` closes **BOOK-10** for issuance — the override, the risk flag and one `booking_issued` on the RPC, table and platform doors, the archived rule on every transition, and `draft` at birth — with an in-file mutation. **BOOK-11 and BOOK-12 remain OPEN.** CRM SPEC-319 and `182_archive_authority_applies_at_entry_test.sql` verify the ARCH-2 booking member on Platinum Primary. BOOK-11 and BOOK-12 remain open. **2026-11-23 (CRM SPEC-335):** **BOOK-13**, a member backdates their own booking and `reporting.sales_activity` reports it on that date; Test 194 pins it OPEN. |
   ```

   d) replace the line
   ```text
   | `documents` | **PARTIAL** | ADVERSARIAL | `SPEC-216-document-door-parity` | DOC-4, DOC-5, DOC-6, DOC-LC-3 | The table door's entry state, type, version pointer and archive representations were swept and **DOC-4**, **DOC-5**, **DOC-6** and **DOC-LC-3** closed: `122_document_door_parity_test.sql` pins them with 25 assertions — an `employee` holding neither ARCHIVE_DOCUMENT nor MANAGE_TENANT_SETTINGS, a `finance_manager` holding no MANAGE_TENANT_SETTINGS, and a pointer attack aimed at a version the caller CAN see, so no permission or visibility is the refuser — and `69_…` 18-19 now assert DOC-LC-3's refusal. The same guard closed the `documents` instances of **ARCH-2** (a document born archived) and **ENTRY-1** (born `archived` or `superseded`). **Swept and classified as non-defects, not registered:** tenant relocation (refused by `scope_isolation`); `created_by` (derived and immutable, `61_…`); confidentiality and title (editable by an actor who already holds the file, so no escalation; a `payment_proof` stays under MANAGE_TENANT_SETTINGS for every edit); both doors agreeing at `aal1`; no DELETE grant; the subscription gate on every door. **`PARTIAL` because two axes were probed and deliberately not classified:** (1) event parity for a document created at the door — it records no `document_uploaded`, while its creator is server-derived and it carries no file until a recorded version is added (`quotations` names the same axis); (2) `created_at`, writable at the door and read only by `app.financial_documents`' listing, a question that stands on every table with such a column |
   ```
   with
   ```text
   | `documents` | **AUDITED-OPEN** | ADVERSARIAL | `SPEC-216-document-door-parity` | DOC-4, DOC-5, DOC-6, DOC-LC-3, DOC-11 | The table door's entry state, type, version pointer and archive representations were swept and **DOC-4**, **DOC-5**, **DOC-6** and **DOC-LC-3** closed: `122_document_door_parity_test.sql` pins them with 25 assertions — an `employee` holding neither ARCHIVE_DOCUMENT nor MANAGE_TENANT_SETTINGS, a `finance_manager` holding no MANAGE_TENANT_SETTINGS, and a pointer attack aimed at a version the caller CAN see, so no permission or visibility is the refuser — and `69_…` 18-19 now assert DOC-LC-3's refusal. The same guard closed the `documents` instances of **ARCH-2** (a document born archived) and **ENTRY-1** (born `archived` or `superseded`). **Swept and classified as non-defects, not registered:** tenant relocation (refused by `scope_isolation`); `created_by` (derived and immutable, `61_…`); confidentiality and title (editable by an actor who already holds the file, so no escalation; a `payment_proof` stays under MANAGE_TENANT_SETTINGS for every edit); both doors agreeing at `aal1`; no DELETE grant; the subscription gate on every door. **`PARTIAL` because two axes were probed and deliberately not classified:** (1) event parity for a document created at the door — it records no `document_uploaded`, while its creator is server-derived and it carries no file until a recorded version is added (`quotations` names the same axis); (2) `created_at`, writable at the door and read only by `app.financial_documents`' listing, a question that stands on every table with such a column. **2026-11-23 (CRM SPEC-335):** `AUDITED-OPEN`: both axes are classified. Axis (1) is **DOC-11** (`ENABLE-SURFACE-WORKFLOW`) and axis (2) is **STAMP-1**, an accepted residual; `194_door_evidence_and_sale_dates_open_pins_test.sql` pins DOC-11 OPEN |
   ```

   e) replace the line
   ```text
   | `quotations` | **PARTIAL** | ADVERSARIAL | `SPEC-214-quotation-door-parity` | QUO-5, QUO-6, QUO-7, QUO-8 | The table door's lifecycle state, commercial terms, authority contrast and tenant boundary were swept and **QUO-5** to **QUO-8** closed: `120_quotation_door_parity_test.sql` pins them with 30 assertions, an `employee` carrying DENY on SEND_QUOTATION and ACCEPT_QUOTATION so no permission can be the refuser, and an in-file mutation control. Four axes were left unclassified by choice and are named here rather than registered: (1) event parity for direct-DML creation and transitions (canon 26's Required Events); (2) reassignment of `owner_user_id`, `lead_id` and `quotation_number` by any CREATE_QUOTATION holder who can see the row, which no RPC offers and canon does not decide (BOOK-9's question on another surface); (3) the `quotations` instance of **ARCH-2** (a row born archived), reproduced in this slice and owned by ARCH-2's row; (4) direct writes to `sent_at`, `accepted_at` and `rejected_at`, probed and found to have no reader. **2026-11-21 (CRM SPEC-324):** axis (3) is closed: `20261121100000` attaches archive authority at INSERT and `183_entry_and_step_up_hold_at_the_table_door_test.sql` proves the refusal without ARCHIVE_RECORD. Axes (1), (2) and (4) remain, so the surface stays `PARTIAL` |
   ```
   with
   ```text
   | `quotations` | **AUDITED-OPEN** | ADVERSARIAL | `SPEC-214-quotation-door-parity` | QUO-5, QUO-6, QUO-7, QUO-8, QUO-11, QUO-12 | The table door's lifecycle state, commercial terms, authority contrast and tenant boundary were swept and **QUO-5** to **QUO-8** closed: `120_quotation_door_parity_test.sql` pins them with 30 assertions, an `employee` carrying DENY on SEND_QUOTATION and ACCEPT_QUOTATION so no permission can be the refuser, and an in-file mutation control. Four axes were left unclassified by choice and are named here rather than registered: (1) event parity for direct-DML creation and transitions (canon 26's Required Events); (2) reassignment of `owner_user_id`, `lead_id` and `quotation_number` by any CREATE_QUOTATION holder who can see the row, which no RPC offers and canon does not decide (BOOK-9's question on another surface); (3) the `quotations` instance of **ARCH-2** (a row born archived), reproduced in this slice and owned by ARCH-2's row; (4) direct writes to `sent_at`, `accepted_at` and `rejected_at`, probed and found to have no reader. **2026-11-21 (CRM SPEC-324):** axis (3) is closed: `20261121100000` attaches archive authority at INSERT and `183_entry_and_step_up_hold_at_the_table_door_test.sql` proves the refusal without ARCHIVE_RECORD. Axes (1), (2) and (4) remain, so the surface stays `PARTIAL`. **2026-11-23 (CRM SPEC-335):** `AUDITED-OPEN`: axes (1) and (4) are **QUO-11** (`ENABLE-SURFACE-WORKFLOW`), axis (2) is **QUO-12** (`ENABLE-CRM`), and the caller-writable `created_at` is **STAMP-1**; `194_door_evidence_and_sale_dates_open_pins_test.sql` pins QUO-11 and QUO-12 OPEN |
   ```

   The resulting file's Git blob is 222ee26cf30b5dff7b0bef93c76416b2c2fa7d6f.

7. Check whether `_ORVION_CANONICAL/manifest.md` contains `Suite **194 files / 3609 assertions**.`; if so record Already Applied when its Git blob is b0e8f24e9ef3c1607ab24642c0d553ef3262c6a0, and otherwise stop and report. Otherwise make exactly these 2 edits (the measured suite figure), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **191 files / 3591 assertions**.
   ```
   with
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **194 files / 3609 assertions**.
   ```

   b) replace the line
   ```text
   Open owner decisions — **MAIL-1**, **RET-1**, **PH8-10**, **OD-1**, **OD-2**, **OD-3**, **OD-5**, **OD-8**, **CTRL-19**. The OD rows are proposed product decisions awaiting the owner, each with its default in the register. MAIL-1, RET-1 and PH8-10 are exact external prerequisites, not unresolved architecture: MAIL-1 has technically selected Resend but production activation still requires owner authorization and counsel/PDPC confirmation for the actual cross-border destination; RET-1's retention/closure architecture and legal-hold override are implemented, while counsel must supply the actual per-type periods as tenant configuration; PH8-10 awaits Google evidence that click-less phone conversions are credited. No email is sent and no retention policy is seeded while those prerequisites remain. CTRL-19 is GitHub configuration only the owner can make.
   ```
   with
   ```text
   Open owner decisions — **MAIL-1**, **RET-1**, **PH8-10**, **OD-1**, **OD-2**, **OD-3**, **OD-5**, **OD-8**. The OD rows are proposed product decisions awaiting the owner, each with its default in the register. MAIL-1, RET-1 and PH8-10 are exact external prerequisites, not unresolved architecture: MAIL-1 has technically selected Resend but production activation still requires owner authorization and counsel/PDPC confirmation for the actual cross-border destination; RET-1's retention/closure architecture and legal-hold override are implemented, while counsel must supply the actual per-type periods as tenant configuration; PH8-10 awaits Google evidence that click-less phone conversions are credited. No email is sent and no retention policy is seeded while those prerequisites remain. CTRL-19 is no longer an open owner decision: on 2026-11-23 the owner declined its GitHub configuration repair, and it is an accepted residual contained by the promotion path.
   ```

   The resulting file's Git blob is b0e8f24e9ef3c1607ab24642c0d553ef3262c6a0.

8. **Establish readiness and verify.** Run the native DATABASE readiness: full SQL tests at 277 migrations with 194 files and 3609 assertions including Test 192 at 4 of 4, Test 193 at 3 of 3 and Test 194 at 11 of 11, smoke and HTTP, and API generation with the API contract unchanged. Run the native repository guard and the five hosted guard suites named in Additional Verification. Confirm that `readiness_population.ps1` reports REGISTRY complete with no COMPLETED member. Confirm the exact scope and `git diff --check`. Make no Primary write. Synchronize the contract and native discovery artifacts, set Runtime Checkpoint DONE and commit the implementation. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-335: The exit evidence gaps are pinned and the re-sweep registered.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] Test 192 pins the CUST-10 and CUST-12 locks. `check: blob supabase/tests/192_a_customer_lock_is_taken_before_its_judgement_test.sql 00d4d776f17ad411f4499ad454d446e0ac772623`
- [ ] Test 193 pins the surviving structural controls. `check: blob supabase/tests/193_structural_control_presence_test.sql 472b404c67b1656b5c0013bbbb86f1b7a2e33b4a`
- [ ] Test 194 pins DOC-11, QUO-11, QUO-12 and BOOK-13 as OPEN. `check: blob supabase/tests/194_door_evidence_and_sale_dates_open_pins_test.sql 0390d2a92ead6a69ff20e2276332adfc9a036c4c`
- [ ] The EC readings and gate rows are recorded. `check: blob reports/master/MASTER_EXECUTION_PLAN.md 984a32d852fa86036f357c2761fa7aca6b9474fe`
- [ ] The register carries the new findings, the BRANCH-2 correction and CTRL-19's acceptance. `check: blob reports/master/MASTER_GAP_REGISTER.md 424d084a30c76058ee2a081004d317f6e2b909c5`
- [ ] The disposition follows the findings. `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md 222ee26cf30b5dff7b0bef93c76416b2c2fa7d6f`
- [ ] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **194 files / 3609 assertions**"`
- [ ] The manifest records the owner's CTRL-19 decision. `check: has _ORVION_CANONICAL/manifest.md "CTRL-19 is no longer an open owner decision"`
- [ ] ADR-0031 records its revisit. `check: has reports/architecture-decision-records.md "Revisited 2026-11-23 (SPEC-335)"`
- [ ] The API contract is unchanged. `check: same reports/master/MASTER_API_CONTRACT.md @676df3e46fffae83366fa4c177a74d327edd6381`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @676df3e46fffae83366fa4c177a74d327edd6381`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @676df3e46fffae83366fa4c177a74d327edd6381`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @676df3e46fffae83366fa4c177a74d327edd6381`
- [ ] The cold-start guard suite is preserved. `check: same scripts/test_cold_start_state_guard.ps1 @676df3e46fffae83366fa4c177a74d327edd6381`
- [ ] Full DATABASE readiness and all five hosted guard suites pass in the native Finish; no exit criterion is marked met.

## Execution Log

None.


### 2026-11-23 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was 676df3e46fffae83366fa4c177a74d327edd6381 and every source anchor matched there; Draft allocated as 3d013bd and approved as 88e3047 with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `supabase/tests/192_a_customer_lock_is_taken_before_its_judgement_test.sql` edited exactly as the step states; blob 00d4d776f17ad411f4499ad454d446e0ac772623 (47 insertions, 0 deletions (created)).
- Step 3 Applied: `supabase/tests/193_structural_control_presence_test.sql` edited exactly as the step states; blob 472b404c67b1656b5c0013bbbb86f1b7a2e33b4a (336 insertions, 0 deletions (created)).
- Step 4 Applied: `supabase/tests/194_door_evidence_and_sale_dates_open_pins_test.sql` edited exactly as the step states; blob 0390d2a92ead6a69ff20e2276332adfc9a036c4c (147 insertions, 0 deletions (created)).
- Step 5 Applied: `reports/master/MASTER_EXECUTION_PLAN.md` edited exactly as the step states; blob 984a32d852fa86036f357c2761fa7aca6b9474fe (22 insertions, 14 deletions).
- Step 6 Applied: `reports/master/MASTER_GAP_REGISTER.md` edited exactly as the step states; blob 424d084a30c76058ee2a081004d317f6e2b909c5 (10 insertions, 3 deletions).
- Step 7 Applied: `reports/master/MASTER_SURFACE_DISPOSITION.md` edited exactly as the step states; blob 222ee26cf30b5dff7b0bef93c76416b2c2fa7d6f (8 insertions, 6 deletions).
- Step 8 Applied: `_ORVION_CANONICAL/manifest.md` edited exactly as the step states; blob b0e8f24e9ef3c1607ab24642c0d553ef3262c6a0 (2 insertions, 2 deletions).
- Step 9 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain.

## Verification Notes

None.


### 2026-11-23 — Gate 1 approval recorded

DELEGATED Original Gate 1 for CRM SPEC-335 only under DEC-02 in the owner AFK Mode (owner-2026-11-23-modes-any-session.txt, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73), continuing Batch 6 under the owner OD-9 decision of 2026-11-22 (SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D); CTRL-19 accepted residual by the owner (owner-2026-11-23-ctrl19-declined.txt, SHA-256 6882D7C5A1E1C71B05EE8AD878DD72100821972811F1E1358CA022623D333124). Exact Draft SHA-256 F9F41EBD3F4AF0A13A803F4E557ECDD921DA0ACD6B1C6EDA76280BF905081A53, Git blob c1084bbfb731621c40debbb9acb26c338c717a02, CRM baseline 676df3e. Native isolated Approve 04e66ca and implement d122f91 passed, and the native repository consistency on the sandbox final tree is CLEAN (sandbox-final-consistency.log SHA-256 8803C67032B8897C13A142ADA3EC51CBB0F1ED1431128DB02443D1A0D2305142). Three pgTAP tests and records; no migration, no Primary write. Gate 1 only. Immediately before allocation the hash, the Draft blob c1084bbfb731621c40debbb9acb26c338c717a02, all 4 source anchors, the baseline HEAD 676df3e46fffae83366fa4c177a74d327edd6381 against refreshed origin/main 676df3e46fffae83366fa4c177a74d327edd6381 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 3d013bd. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 676df3e46fffae83366fa4c177a74d327edd6381 (SPEC-334 Complete and released; main is 676df3e46fffae83366fa4c177a74d327edd6381).

Authority: DELEGATED under the owner's AFK Mode, answered by the constitution; never typed by the owner. The owner's words of 2026-11-23, Workbench `data/records/batch6/owner-words/owner-2026-11-23-modes-any-session.txt`, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73, make AFK Mode a tool that decides by the project's rules and widens nothing; the owner's words of 2026-11-22, `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D, direct Batch 6 to finish first; and the owner's words of 2026-11-23, `data/records/batch6/owner-words/owner-2026-11-23-ctrl19-declined.txt`, SHA-256 6882D7C5A1E1C71B05EE8AD878DD72100821972811F1E1358CA022623D333124, decline CTRL-19's repair, which this contract records as the owner's accepted residual. This contract grants nothing beyond them. The evidence is Workbench `data/records/batch6/exit-bundle-j/`: `ec7/` (the closure cross-check), `ec5-extended/` (the probe and its recheck), `gate-eval/` (FIN-9, CTRL-11, the re-sweep and the stamps) and `spec335/` (the mutation runs).

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `707cdab6f86060d57e9709b758f79fe7820aced8` |
| `reports/master/MASTER_GAP_REGISTER.md` | `6b49b7742a97b48f601c660f3e20078a215e3881` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `62db5668af68eaa6f34a108d6cacb13b261ed0d8` |
| `_ORVION_CANONICAL/manifest.md` | `049fcb8f4090b1fa76a56f7d9d81ce2a58d2c596` |
