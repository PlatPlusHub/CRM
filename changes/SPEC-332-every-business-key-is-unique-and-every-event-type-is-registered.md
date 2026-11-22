# Change Request — SPEC-332

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Settle the six findings the CRM `B6-EXIT` gate evaluation still owes under EC-8. The Action Registry row "N1, DC-5, RC-4, R8, B3, RC-1 | TERMINAL IN SUBSTANCE" leaves them to be re-verified against their migrations. One pgTAP test (Test 188) proves the two that have no test, R8/B3 and N1. The other four are settled on their existing tests. The five register rows carry settled statuses with their superseded text, and the registry row leaves.

## Business Reason

At 5bed4ed52cf3612b58c73b09f054b296c968bcf5 (277 migrations), the six findings are implemented but the register still reads DESIGN-READY, so the registry keeps them open for the gate evaluation. Re-verified against their migrations: DC-5 (`202607054600`) has Tests 48, 49, 97, 116 and 175; RC-4 Tier A (`202607048900`, the `reporting` security-invoker views) has Tests 23, 45 and 53; RC-1 has Tests 42, 66 and 148. R8/B3 (`202607048800`) adds five business-key UNIQUE constraints that no test names, and N1 (`202607049100`, current body `20261114160000`) makes `app.record_event` refuse an unregistered event type and severity, and no test pins the refusal. A finding without a proving test cannot be settled by reading alone (DEC-33 rule 9).

## Risks

A key could exist but be wider than its owner, or exist unvalidated. Assertion 1 pins the exact five keys over their exact columns and requires each to be validated. Assertions 2–9 prove each key refuses a duplicate inside its owner and, where the owner is a tenant, admits the same value in another tenant. A registry check could pass because `record_event` refuses everything. Assertion 12 is a positive control with a registered type. Re-wording a status could erase history, so each settled status keeps its superseded text. This contract changes no migration, function, policy, grant or database object, and no exit criterion is marked met: FIN-9 and the `documents`/`quotations` re-sweep keep their gate-evaluation rows, so EC-8 stays partial.

## Supersedes / Depends On

Extends the SPEC-331 reconciliation (Test 187) and the SPEC-330 catalog-driven proof (Test 186). Uses the migrations `202607048800`, `202607048900`, `202607049100`, `202607054600` and `20261114160000` and the existing Tests 23, 42, 45, 48, 49, 53, 66, 97, 116, 148 and 175. Those terminal contracts are immutable.

## Write Scope

- `changes/SPEC-332-every-business-key-is-unique-and-every-event-type-is-registered.md`
- `supabase/tests/188_every_business_key_is_unique_and_every_event_type_is_registered_test.sql`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_API_CONTRACT.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
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
- `reports/master/MASTER_EXECUTION_PLAN.md` Action Registry and the exit criterion EC-8.
- `reports/master/MASTER_GAP_REGISTER.md` R8/B3, N1, DC-5, RC-4 and RC-1.
- `supabase/migrations/202607048800_group2_integrity_constraints.sql` and `supabase/migrations/202607049100_event_type_registry_enforcement.sql`.
- `supabase/tests/187_every_ceiling_is_a_named_membership_and_no_mechanism_is_orphaned_test.sql`.

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

Pass 1 Design: One new pgTAP test, Test 188, with a two-tenant fixture rolled back at the end. Assertion 1 pins the five R8/B3 business keys as a set equality over their exact definitions, all validated. Assertions 2–9 insert a duplicate inside the owner of each key and the same value in another tenant. Assertions 10–12 call `app.record_event` with an unregistered event type, an unregistered severity and a registered type. The plan, register and manifest record the result.

Pass 2 Adversarial Review: Applied in a rolled-back transaction, a mutation set failed every one of the 12 assertions. It dropped the five keys, replaced the booking, quotation and usage keys with keys wider than their tenant, replaced `app.record_event` with a body that writes without consulting the catalog, and then with one that refuses everything. The unmutated database passes all 12. Each settled status keeps its superseded text and cites its migration and tests.

Pass 3 Evidence Refresh: 2026-11-22. In an isolated clone at 5bed4ed52cf3612b58c73b09f054b296c968bcf5 carrying the payload:
- Test 188 passed 12 of 12 on the local stack (277 migrations), and the mutation set failed 12 of 12.
- `readiness_population.ps1` reported REGISTRY complete with no COMPLETED member.
- Native repository consistency was CLEAN.
- All five hosted guard suites passed with 0 failed.

Selected Version: SPEC-332; selected: one behavioural pgTAP test that proves the five R8/B3 business keys and the N1 event registry, the two of the six terminal-in-substance findings without a test, with the plan, register and manifest records that settle all six on their migrations and tests, the smallest change that closes the six-finding EC-8 registry row without any database change

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Business keys and event registry proof | Full pgTAP suite and the `B6-EXIT` gate evaluation | WRITE | Test 188 adds 12 assertions; the suite grows to 188 files and 3491 assertions. |
| One registry row and five register statuses | Action Registry, Check 29 and `readiness_population.ps1` | WRITE | The statuses are settled with their superseded text; the evaluator reports REGISTRY complete with no COMPLETED member. |
| EC-8 reading | Exit criteria | WRITE | It cites Test 188 and the existing tests; no criterion is marked met. |
| Schema, grants, policies and API | Every product consumer | UNAFFECTED | No migration; the API contract has the same blob as the baseline. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchors and exact payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Check 29 and the five hosted guard suites pass | BEFORE_COMPLETION | 2 | 4 | 5 |
| Full DATABASE readiness with Test 188 | BEFORE_COMPLETION | NONE | NONE | 5 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: The pgTAP suite and its behavioural precedents, `supabase/tests/187_every_ceiling_is_a_named_membership_and_no_mechanism_is_orphaned_test.sql` for catalog pins.

Added Property: The five R8/B3 business keys exist exactly, are validated and are scoped to their owner, and `app.record_event` refuses an event type and a severity the catalog does not register while admitting a registered type.

Causal Negative: At 5bed4ed52cf3612b58c73b09f054b296c968bcf5, dropping any of the five keys, widening a tenant key to the whole platform, or replacing `app.record_event` with a body that skips the catalog passes the whole suite.

Positive Test Design: On the unmutated database Test 188 passes 12 of 12.

Negative Test Design: In a rolled-back transaction, each mutation fails its assertion: the five keys are dropped, three tenant keys are widened, `app.record_event` stops consulting the catalog and then refuses everything.

Non-Empty Population Obligation: The fixture holds two tenants, a booking, a quotation and a usage counter, and the catalog holds the `enterprise` plan, at least one feature entitlement and the registered type `branch_created`; assertion 1 fails on an empty population.

Mutation Obligation: The mutation set above must fail all 12 assertions.

Post-Implementation Proof Obligation: The native Finish runs the full DATABASE protocol with Test 188 and all five hosted guard suites through Additional Verification with zero failures. Hosted preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `supabase/tests/188_every_business_key_is_unique_and_every_event_type_is_registered_test.sql` contains `select plan(12);`; if so record Already Applied when its Git blob is fb389022d81120ed9578fcd721447ed146f6023d, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the business-key and event-registry test), and change nothing else:

   ```text
   -- pgTAP: Batch 6 exit -- every business key is unique per its owner, and every event type is registered before it is written.
   --
   -- EC-8: the registry row "N1, DC-5, RC-4, R8, B3, RC-1 | TERMINAL IN SUBSTANCE" left six findings to the gate evaluation,
   --   to be re-verified against their migrations. Measured at `5bed4ed` (277 migrations), DC-5 (`202607054600`), RC-4
   --   (`202607048900`) and RC-1 already have behavioural tests (DC-5: 48, 49, 97, 116, 175; RC-4: 23, 45, 53; RC-1: 42,
   --   66, 148). Two had none, and this test is theirs:
   --     R8/B3 (`202607048800_group2_integrity_constraints.sql`) -- five business-key UNIQUE constraints, all validated:
   --       bookings (tenant_id, booking_reference), quotations (tenant_id, quotation_number), subscription_plans
   --       (plan_code), feature_entitlements (subscription_plan_id, feature_code) and usage_counters (tenant_id,
   --       usage_metric_code, period_start, period_end). No test named any of them.
   --     N1 (`202607049100_event_type_registry_enforcement.sql`, current body `20261114160000`) -- app.record_event refuses
   --       an event_type_code, and a severity_code, that the catalog does not register. No test pinned the refusal.
   --   Assertion 1 pins the exact five keys; assertions 2-9 prove each key refuses a duplicate inside its owner and, where
   --   the owner is a tenant, admits the same value in another tenant (the key is not wider than its owner); assertions
   --   10-12 prove the event registry refuses an unknown type and an unknown severity and admits a registered type.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(12);

   insert into auth.users (id, email, email_confirmed_at) values
     ('c1880000-0000-0000-0000-0000000000a1','owner@a188.test', now()),
     ('c1880000-0000-0000-0000-0000000000a2','owner@b188.test', now());
   insert into public.tenants (id, name, slug, status) values
     ('c1880000-0000-0000-0000-000000000001','A188 Travel','a188','active'),
     ('c1880000-0000-0000-0000-000000000002','B188 Travel','b188','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
   where sp.plan_code = 'enterprise'
     and t.id in ('c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-000000000002');
   insert into public.branches (id, tenant_id, name, slug) values
     ('c1880000-0000-0000-0000-00000000000a','c1880000-0000-0000-0000-000000000001','HQ','a188-hq'),
     ('c1880000-0000-0000-0000-00000000000b','c1880000-0000-0000-0000-000000000002','HQ','b188-hq');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('c1880000-0000-0000-0000-0000000000c1','c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-00000000000a','management','Exec'),
     ('c1880000-0000-0000-0000-0000000000c2','c1880000-0000-0000-0000-000000000002','c1880000-0000-0000-0000-00000000000b','management','Exec');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('c1880000-0000-0000-0000-000000000011','c1880000-0000-0000-0000-000000000001','Owner A','owner@a188.test',true,'c1880000-0000-0000-0000-0000000000a1'),
     ('c1880000-0000-0000-0000-000000000012','c1880000-0000-0000-0000-000000000002','Owner B','owner@b188.test',true,'c1880000-0000-0000-0000-0000000000a2');
   insert into public.customers (id, tenant_id, customer_type_code, full_name) values
     ('c1880000-0000-0000-0000-0000000000d1','c1880000-0000-0000-0000-000000000001','person','Customer A'),
     ('c1880000-0000-0000-0000-0000000000d2','c1880000-0000-0000-0000-000000000002','person','Customer B');
   insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id) values
     ('c1880000-0000-0000-0000-0000000000b1','c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-00000000000a','c1880000-0000-0000-0000-0000000000c1','c1880000-0000-0000-0000-0000000000d1','confirmed','Trip','BK-188-1','c1880000-0000-0000-0000-000000000011');
   insert into public.quotations (id, tenant_id, customer_id, quotation_status_code, quotation_number, currency_code) values
     ('c1880000-0000-0000-0000-0000000000e1','c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-0000000000d1','sent','QT-188-1','EGP');
   insert into public.usage_counters (id, tenant_id, usage_metric_code, period_start, period_end) values
     ('c1880000-0000-0000-0000-0000000000f1','c1880000-0000-0000-0000-000000000001','t188_metric','2026-10-01','2026-10-31');

   -- 1. R8/B3: exactly the five business keys, each UNIQUE over its exact columns and validated.
   select set_eq(
     $$select c.conrelid::regclass::text || ' ' || c.conname::text || ' ' || pg_get_constraintdef(c.oid)
         from pg_constraint c
        where c.contype = 'u' and c.convalidated
          and c.conname in ('bookings_tenant_reference_key','quotations_tenant_number_key','subscription_plans_code_key',
                            'feature_entitlements_plan_feature_key','usage_counters_tenant_metric_period_key')$$,
     $$values ('bookings bookings_tenant_reference_key UNIQUE (tenant_id, booking_reference)'),
              ('quotations quotations_tenant_number_key UNIQUE (tenant_id, quotation_number)'),
              ('subscription_plans subscription_plans_code_key UNIQUE (plan_code)'),
              ('feature_entitlements feature_entitlements_plan_feature_key UNIQUE (subscription_plan_id, feature_code)'),
              ('usage_counters usage_counters_tenant_metric_period_key UNIQUE (tenant_id, usage_metric_code, period_start, period_end)')$$,
     'R8/B3: the five business keys exist, are UNIQUE over their exact columns and are validated'
   );

   -- 2-3. A booking reference is unique inside its tenant, and only there.
   select throws_ok(
     $$insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id)
       values ('c1880000-0000-0000-0000-0000000000b2','c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-00000000000a','c1880000-0000-0000-0000-0000000000c1','c1880000-0000-0000-0000-0000000000d1','confirmed','Trip 2','BK-188-1','c1880000-0000-0000-0000-000000000011')$$,
     '23505', null,
     'R8/B3: a second booking with the same reference in the same tenant is refused'
   );
   select lives_ok(
     $$insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id)
       values ('c1880000-0000-0000-0000-0000000000b3','c1880000-0000-0000-0000-000000000002','c1880000-0000-0000-0000-00000000000b','c1880000-0000-0000-0000-0000000000c2','c1880000-0000-0000-0000-0000000000d2','confirmed','Trip B','BK-188-1','c1880000-0000-0000-0000-000000000012')$$,
     'R8/B3: another tenant may use the same booking reference'
   );

   -- 4-5. A quotation number is unique inside its tenant, and only there.
   select throws_ok(
     $$insert into public.quotations (id, tenant_id, customer_id, quotation_status_code, quotation_number, currency_code)
       values ('c1880000-0000-0000-0000-0000000000e2','c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-0000000000d1','sent','QT-188-1','EGP')$$,
     '23505', null,
     'R8/B3: a second quotation with the same number in the same tenant is refused'
   );
   select lives_ok(
     $$insert into public.quotations (id, tenant_id, customer_id, quotation_status_code, quotation_number, currency_code)
       values ('c1880000-0000-0000-0000-0000000000e3','c1880000-0000-0000-0000-000000000002','c1880000-0000-0000-0000-0000000000d2','sent','QT-188-1','EGP')$$,
     'R8/B3: another tenant may use the same quotation number'
   );

   -- 6. A plan code is unique across the platform.
   select throws_ok(
     $$insert into public.subscription_plans (plan_code, name) values ('enterprise', 'Enterprise copy')$$,
     '23505', null,
     'R8/B3: a second subscription plan with an existing plan code is refused'
   );

   -- 7. A plan grants a feature at most once.
   select throws_ok(
     $$insert into public.feature_entitlements (subscription_plan_id, feature_code)
       select fe.subscription_plan_id, fe.feature_code from public.feature_entitlements fe
        order by fe.subscription_plan_id, fe.feature_code limit 1$$,
     '23505', null,
     'R8/B3: a second entitlement of the same feature on the same plan is refused'
   );

   -- 8-9. A usage counter is unique per tenant, metric and period, and only per tenant.
   select throws_ok(
     $$insert into public.usage_counters (id, tenant_id, usage_metric_code, period_start, period_end)
       values ('c1880000-0000-0000-0000-0000000000f2','c1880000-0000-0000-0000-000000000001','t188_metric','2026-10-01','2026-10-31')$$,
     '23505', null,
     'R8/B3: a second usage counter for the same tenant, metric and period is refused'
   );
   select lives_ok(
     $$insert into public.usage_counters (id, tenant_id, usage_metric_code, period_start, period_end)
       values ('c1880000-0000-0000-0000-0000000000f3','c1880000-0000-0000-0000-000000000002','t188_metric','2026-10-01','2026-10-31')$$,
     'R8/B3: another tenant may count the same metric over the same period'
   );

   -- 10-12. N1: the event registry is enforced at the write path.
   select throws_matching(
     $$select app.record_event('c1880000-0000-0000-0000-000000000001'::uuid, 't188_not_a_registered_code', 'branch',
                               'c1880000-0000-0000-0000-00000000000a'::uuid)$$,
     '^unknown event_type_code: t188_not_a_registered_code',
     'N1: record_event refuses an event type the catalog does not register'
   );
   select throws_matching(
     $$select app.record_event('c1880000-0000-0000-0000-000000000001'::uuid, 'branch_created', 'branch',
                               'c1880000-0000-0000-0000-00000000000a'::uuid, null, null, null, null, null, 't188_not_a_severity')$$,
     '^unknown severity_code: t188_not_a_severity',
     'N1: record_event refuses a severity the catalog does not register'
   );
   select lives_ok(
     $$select app.record_event('c1880000-0000-0000-0000-000000000001'::uuid, 'branch_created', 'branch',
                               'c1880000-0000-0000-0000-00000000000a'::uuid)$$,
     'N1: record_event admits a registered event type (positive control)'
   );

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is fb389022d81120ed9578fcd721447ed146f6023d.

2. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Last updated: 2026-11-23 (CRM exit bundle G, SPEC-332.`; if so record Already Applied when its Git blob is 7a90aeb9aea0310a0a9726e5ff27e6c265e533bf, and otherwise stop and report. Otherwise make exactly these 5 edits (the six-finding registry row leaves, the EC-8 reading cites Test 188 and the existing tests, and the dated SPEC-332 header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-22 (CRM exit bundle F, SPEC-331. Test 187 pins the four numeric suite ceilings of Tests 07 and 10 as named memberships and sweeps `public`, `app` and `reporting` for disabled, duplicate, invalid, unvalidated, unowned and unreachable mechanisms. Two surfaces are re-dispositioned AUDITED and five register statuses are re-worded to the settled vocabulary, so their two registry rows leave.)
   ```
   with
   ```text
   Last updated: 2026-11-23 (CRM exit bundle G, SPEC-332. Test 188 proves R8/B3 and N1: the five business keys are validated, each refuses a duplicate inside its owner and admits it in another tenant, and `app.record_event` refuses an unregistered event type and severity. DC-5, RC-4 and RC-1 are settled on their existing tests, so the six-finding registry row leaves.)

   Previously: 2026-11-22 (CRM exit bundle F, SPEC-331. Test 187 pins the four numeric suite ceilings of Tests 07 and 10 as named memberships and sweeps `public`, `app` and `reporting` for disabled, duplicate, invalid, unvalidated, unowned and unreachable mechanisms. Two surfaces are re-dispositioned AUDITED and five register statuses are re-worded to the settled vocabulary, so their two registry rows leave.)
   ```

   b) replace the line
   ```text
   **CRM exit evidence at `23be9e2`, measured 2026-11-22 (SPEC-331, Test 187; SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```
   with
   ```text
   **CRM exit evidence at `5bed4ed`, measured 2026-11-23 (SPEC-332, Test 188; SPEC-331, Test 187; SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```

   c) replace the line
   ```text
   - **EC-8 (partial):** Native freshness checks and the reconciled records establish bounded coherence. SPEC-331 resolves two record conflicts: `booking_item_passengers` and `financial_accounts` are AUDITED, because PAX-5, PAX-6 and FA-2 were resolved on 2026-09-09 (Tests 104, 113 and 114). OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 now carry settled statuses, and each keeps its superseded text. N1, DC-5, RC-4, R8, B3 and RC-1 stay with the gate evaluation, which re-verifies them against their migrations.
   ```
   with
   ```text
   - **EC-8 (partial):** Native freshness checks and the reconciled records establish bounded coherence. SPEC-331 resolves two record conflicts: `booking_item_passengers` and `financial_accounts` are AUDITED, because PAX-5, PAX-6 and FA-2 were resolved on 2026-09-09 (Tests 104, 113 and 114). OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 now carry settled statuses, and each keeps its superseded text. SPEC-332 re-verifies N1, DC-5, RC-4, R8, B3 and RC-1 against their migrations at `5bed4ed`: Test 188 proves R8/B3 (`202607048800`) and N1 (`202607049100`), which had no test, and DC-5 (`202607054600`; Tests 48, 49, 97, 116, 175), RC-4 Tier A (`202607048900`; Tests 23, 45, 53) and RC-1 (Tests 42, 66, 148) are settled on their existing tests. The register rows carry the settled statuses with their superseded text. FIN-9 and the `documents`/`quotations` re-sweep keep their gate-evaluation rows.
   ```

   d) replace the lines
   ```text
   | GOV-9, GOV-15, GOV-20, GUARD-1, SYNC-1, PAR-7, CTRL-3, DC-27, CTRL-5, CI-2, TEST-4, PERF-2, CTRL-6 | ACCEPTED RESIDUAL | engineering | `OWN-TRIGGER` | — | Control plane and governance, none a Day-1 business function. The control-plane chapter is closed, and each reopens only on its own trigger |
   | N1, DC-5, RC-4, R8, B3, RC-1 | TERMINAL IN SUBSTANCE | engineering | `GATE-EVAL` | — | Still `DESIGN-READY` although shipped migrations implement them in whole or part: `202607049100`, `202607054600`, `202607048900`, `202607048800`, and the subscription lifecycle. Re-verified and settled at the first evaluation |
   ```
   with
   ```text
   | GOV-9, GOV-15, GOV-20, GUARD-1, SYNC-1, PAR-7, CTRL-3, DC-27, CTRL-5, CI-2, TEST-4, PERF-2, CTRL-6 | ACCEPTED RESIDUAL | engineering | `OWN-TRIGGER` | — | Control plane and governance, none a Day-1 business function. The control-plane chapter is closed, and each reopens only on its own trigger |
   ```

   e) immediately after the lines
   ```text
   **Recorded exception, 2026-11-22, CRM exit bundle F.** After CRM SPEC-330 at `23be9e2cee6e29ef8ffb5c751554a65651a0f994`, the Batch 6 run mode 2 delegation continues to `B6-EXIT`. SPEC-331 adds Test 187, which reads entirely from the catalog and uses no fixture. It pins the four numeric suite ceilings as named memberships and records the EC-11 mechanism sweep. Two surfaces whose findings were already resolved are re-dispositioned, and five register statuses are re-worded with their superseded text kept. The two registry rows leave, and the EC-7, EC-8 and EC-11 readings cite the result. It changes no migration or database object. The gate-evaluation rows keep their work, and the Original and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-23, CRM exit bundle G.** After CRM SPEC-331 at `5bed4ed52cf3612b58c73b09f054b296c968bcf5`, the Batch 6 delegation continues to `B6-EXIT` in the owner's AFK mode. SPEC-332 adds Test 188, which proves the five R8/B3 business keys and the N1 event registry, the two of the six terminal-in-substance findings that had no test. The other four are settled on their existing tests, the five register rows carry settled statuses with their superseded text, and the registry row leaves. It changes no migration or database object. The Original and release gates remain enforced.

   ```

   The resulting file's Git blob is 7a90aeb9aea0310a0a9726e5ff27e6c265e533bf.

3. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `CRM SPEC-332 settles`; if so record Already Applied when its Git blob is 6b49b7742a97b48f601c660f3e20078a215e3881, and otherwise stop and report. Otherwise make exactly these 6 edits (R8/B3, N1, DC-5, RC-4 and RC-1 carry settled statuses with their superseded text, and the dated header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-22 (CRM SPEC-331 re-words OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 to the settled vocabulary, each keeping its superseded text, and adds no finding. Test 187 pins the suite ceilings and the mechanism sweep.)
   ```
   with
   ```text
   Last updated: 2026-11-23 (CRM SPEC-332 settles R8/B3 and N1 on Test 188 and DC-5, RC-4 and RC-1 on their existing tests, each keeping its superseded status, and adds no finding.)

   Previously: 2026-11-22 (CRM SPEC-331 re-words OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 to the settled vocabulary, each keeping its superseded text, and adds no finding. Test 187 pins the suite ceilings and the mechanism sweep.)
   ```

   b) replace the line
   ```text
   | R8/B3 | business-key UNIQUE constraints (5 keys) | integrity | High | R | 0 | M | 🔒 | DESIGN-READY | audit B3 | 07-09 | 07-11 |
   ```
   with
   ```text
   | R8/B3 | business-key UNIQUE constraints (5 keys) | integrity | High | R | 0 | M | 🔒 | ✅RESOLVED 2026-11-23 (SPEC-332, Test 188: migration `202607048800`; the five keys are validated, each refuses a duplicate inside its owner and admits it in another tenant; superseded: DESIGN-READY) | audit B3 | 07-09 | 07-11 |
   ```

   c) replace the line
   ```text
   | N1 | event_type registry validated by record_event (amend ADR-0006) | event-contract | High | R | 1 | A | 🔒 | DESIGN-READY | synthesis | 07-09 | 07-11 |
   ```
   with
   ```text
   | N1 | event_type registry validated by record_event (amend ADR-0006) | event-contract | High | R | 1 | A | 🔒 | ✅RESOLVED 2026-11-23 (SPEC-332, Test 188: migration `202607049100`, current body `20261114160000`; `app.record_event` refuses an unregistered event type and severity; superseded: DESIGN-READY) | synthesis | 07-09 | 07-11 |
   ```

   d) replace the line
   ```text
   | DC-5 | document binary storage + Storage RLS | security | High | R | 2 | A | 🛡 | DESIGN-READY | cert-2026-07 | 07-10 | 07-11 |
   ```
   with
   ```text
   | DC-5 | document binary storage + Storage RLS | security | High | R | 2 | A | 🛡 | ✅IMPLEMENTED (migration `202607054600`; Tests 48, 49, 97, 116, 175; settled 2026-11-23 by SPEC-332; superseded: DESIGN-READY) | cert-2026-07 | 07-10 | 07-11 |
   ```

   e) replace the line
   ```text
   | RC-1 | Subscription/billing lifecycle + entitlement enforcement | saas | Medium | R | 5 | A | ➕ | DESIGN-READY | design-evolution/audit D | 07-09 | 07-11 |
   ```
   with
   ```text
   | RC-1 | Subscription/billing lifecycle + entitlement enforcement | saas | Medium | R | 5 | A | ➕ | ✅IMPLEMENTED (Tests 42, 66, 148; settled 2026-11-23 by SPEC-332; superseded: DESIGN-READY) | design-evolution/audit D | 07-09 | 07-11 |
   ```

   f) replace the line
   ```text
   | RC-4 | Reporting/Dashboards read-model layer (0 views today) | reporting | Medium | R | 5 | A | ➕ | DESIGN-READY | design-evolution/ARB | 07-09 | 07-11 |
   ```
   with
   ```text
   | RC-4 | Reporting/Dashboards read-model layer (0 views today) | reporting | Medium | R | 5 | A | ➕ | ✅IMPLEMENTED Tier A (migration `202607048900`, the `reporting` security-invoker views; Tests 23, 45, 53; Tier B aggregates only where measured cost earns them, ADR-0022; settled 2026-11-23 by SPEC-332; superseded: DESIGN-READY) | design-evolution/ARB | 07-09 | 07-11 |
   ```

   The resulting file's Git blob is 6b49b7742a97b48f601c660f3e20078a215e3881.

4. Check whether `_ORVION_CANONICAL/manifest.md` contains `Suite **188 files / 3491 assertions**.`; if so record Already Applied when its Git blob is 363a2c11dacedd54f677925147505b69e3ef86d7, and otherwise stop and report. Otherwise make exactly this one edit (the measured suite figure), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **187 files / 3479 assertions**.
   ```
   with
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **188 files / 3491 assertions**.
   ```

   The resulting file's Git blob is 363a2c11dacedd54f677925147505b69e3ef86d7.

5. **Establish readiness and verify.** Run the native DATABASE readiness: full SQL tests at 277 migrations with 188 files and 3491 assertions including Test 188 at 12 of 12, smoke and HTTP, and API generation with the API contract unchanged. Run the native repository guard and the five hosted guard suites named in Additional Verification. Confirm that `readiness_population.ps1` reports REGISTRY complete with no COMPLETED member. Confirm the exact scope and `git diff --check`. Make no Primary write. Synchronize the contract and native discovery artifacts, set Runtime Checkpoint DONE and commit the implementation. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-332: Every business key is unique and every event type is registered.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] Test 188 proves the five business keys and the event registry. `check: blob supabase/tests/188_every_business_key_is_unique_and_every_event_type_is_registered_test.sql fb389022d81120ed9578fcd721447ed146f6023d`
- [ ] The plan removes the six-finding registry row and the EC-8 reading cites the result. `check: blob reports/master/MASTER_EXECUTION_PLAN.md 7a90aeb9aea0310a0a9726e5ff27e6c265e533bf`
- [ ] The register carries the five settled statuses with their superseded text. `check: blob reports/master/MASTER_GAP_REGISTER.md 6b49b7742a97b48f601c660f3e20078a215e3881`
- [ ] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **188 files / 3491 assertions**"`
- [ ] The API contract is unchanged. `check: same reports/master/MASTER_API_CONTRACT.md @5bed4ed52cf3612b58c73b09f054b296c968bcf5`
- [ ] The surface disposition is unchanged. `check: same reports/master/MASTER_SURFACE_DISPOSITION.md @5bed4ed52cf3612b58c73b09f054b296c968bcf5`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @5bed4ed52cf3612b58c73b09f054b296c968bcf5`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @5bed4ed52cf3612b58c73b09f054b296c968bcf5`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @5bed4ed52cf3612b58c73b09f054b296c968bcf5`
- [ ] The cold-start guard suite is preserved. `check: same scripts/test_cold_start_state_guard.ps1 @5bed4ed52cf3612b58c73b09f054b296c968bcf5`
- [ ] Full DATABASE readiness and all five hosted guard suites pass in the native Finish; no exit criterion is marked met.

## Execution Log

None.


### 2026-11-23 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was 5bed4ed52cf3612b58c73b09f054b296c968bcf5 and every source anchor matched there; Draft allocated as e001dfe and approved as 19393c5 with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `supabase/tests/188_every_business_key_is_unique_and_every_event_type_is_registered_test.sql` edited exactly as the step states; blob fb389022d81120ed9578fcd721447ed146f6023d (140 insertions, 0 deletions (created)).
- Step 3 Applied: `reports/master/MASTER_EXECUTION_PLAN.md` edited exactly as the step states; blob 7a90aeb9aea0310a0a9726e5ff27e6c265e533bf (7 insertions, 4 deletions).
- Step 4 Applied: `reports/master/MASTER_GAP_REGISTER.md` edited exactly as the step states; blob 6b49b7742a97b48f601c660f3e20078a215e3881 (8 insertions, 6 deletions).
- Step 5 Applied: `_ORVION_CANONICAL/manifest.md` edited exactly as the step states; blob 363a2c11dacedd54f677925147505b69e3ef86d7 (1 insertions, 1 deletions).
- Step 6 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain.

## Verification Notes

None.


### 2026-11-23 — Gate 1 approval recorded

DELEGATED Original Gate 1 for CRM SPEC-332 only under DEC-02 in the owner AFK Mode (owner-2026-11-23-modes-any-session.txt, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73), continuing Batch 6 under the owner OD-9 decision of 2026-11-22 (SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D). Exact Draft SHA-256 0959AC513FD9CC6FCF5217AD469F896B556323150D5BB2207279CAB44CAAE32A, Git blob 57a27b860cfa6e2cc53f20204da23a63e62a9cf8, CRM baseline 5bed4ed. Native isolated Approve 8b5f2b3 and implement 9b5270f passed with 4 committed blobs verified, and the native repository consistency on the sandbox final tree is CLEAN (sandbox-final-consistency.log SHA-256 6EA597226F11ACD505E1056F9EC6CF40CF1BBC6B0ED655FD7CA03746B1BDEFF0). One pgTAP test and records; no migration, no Primary write. Gate 1 only. Immediately before allocation the hash, the Draft blob 57a27b860cfa6e2cc53f20204da23a63e62a9cf8, all 3 source anchors, the baseline HEAD 5bed4ed52cf3612b58c73b09f054b296c968bcf5 against refreshed origin/main 5bed4ed52cf3612b58c73b09f054b296c968bcf5 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as e001dfe. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 5bed4ed52cf3612b58c73b09f054b296c968bcf5 (SPEC-331 Complete and released; main is 5bed4ed52cf3612b58c73b09f054b296c968bcf5).

Authority: DELEGATED under the owner's AFK Mode, answered by the constitution; never typed by the owner. The owner's words of 2026-11-23, Workbench `data/records/batch6/owner-words/owner-2026-11-23-modes-any-session.txt`, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73, make AFK Mode a tool that decides by the project's rules and widens nothing; the owner's words of 2026-11-22, `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D, direct Batch 6 to finish first. This contract grants nothing beyond them.

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `f5f0acb106e9c1e3520ede80b8cc48110788a787` |
| `reports/master/MASTER_GAP_REGISTER.md` | `434c9a8db2f30d450ea7dccb564032be32f5dc4e` |
| `_ORVION_CANONICAL/manifest.md` | `be2a63eac7f25bb3abd019316b9c82b5ef86d552` |
