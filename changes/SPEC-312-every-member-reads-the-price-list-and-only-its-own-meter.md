# Change Request — SPEC-312

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 56 audits `catalog_types`, `feature_entitlements` and `usage_counters` and records them, not repaired: nothing material was found, so one test pins what the slice measured and no test held, and the disposition record sets the three surfaces `AUDITED`.

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `eb44e95`, on the live local catalog, ranks `catalog_types` (Exposure 2, coverage 8), `feature_entitlements` (2/10) and `usage_counters` (2/16) next, all NOT-RECORDED. Under the owner's instructions of 2026-11-16, this slice's entry of 2026-11-17 grouped the selector's next three surfaces in one contract per product: the three are SELECT-only for `authenticated` with no writer function, so their probes are reads and refusals, and each keeps its own probes, assertions and mutants. The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.** `catalog_types` (71 seeded rows) names the vocabulary every catalog value hangs on; `feature_entitlements` (66 seeded rows) is the price list, read by `app.plan_allows`, `app.plan_limit` and `app.tenant_capabilities` (each SECURITY DEFINER) to decide what a tenant's plan allows; `usage_counters` is the tenant's usage meter. A member who could raise a limit, add a type or reset a meter would change what every tenant pays for; a member who could read another tenant's meter would read that tenant's activity.
- **Measured at `eb44e95`** on the local stack with committed probe fixtures (an owner at `aal1` and `aal2`, an employee, a trainee, another tenant's owner at `aal2`, `service_role`, anonymous REST, and `postgres` for integrity only), every axis held or is a recorded design position:
  - **Held:** every member write to the three is refused 42501 by the missing grant at every role and second factor (insert, rename, deactivate and delete a type; raise a limit, enable a feature, insert and delete an entitlement; insert, reset and delete a meter, including another tenant's owner inserting one); anonymous REST GET and POST on all three 401 and `rpc/plan_limit` 404; a member reads only its own tenant's meter, not even another's by id; the plan readers return the caller's own plan.
  - **Positions:** every member of every tenant reads the whole catalog and every plan's entitlements (product reference data, not tenant data); `app.plan_allows` allows a feature code no plan names (fails open by design, `202607052500_plan_gating.sql`); six `max_*` rows carry no limit (unlimited); `service_role` holds no SELECT on any of the three (PAR-5, DC-15).
  - **Integrity reachable only as `postgres`:** a NULL ownership type, a negative or fractional limit, and a reversed, negative, unknown-metric or overlapping meter are accepted. Only migrations run as `postgres`, no producer of meters exists (nothing in `public` or `app` writes or reads `usage_counters`), and the seeded and hosted rows hold none of them (Primary: 71 types, NULL ownership 0; 66 entitlements, negative 0, fractional 0; 0 meters).
- **What is pinned where.** Tests 10 and 58 pin the grant lists, test 117 pins the plan ceilings and their non-enforcement and the INSERT refusal on meters, tests 25, 30 and 35 pin the plan vocabulary, plan gating and the subscription write gate. Test 178 adds only what the slice measured and no test held: the full reference read at `aal1` and `aal2` in two tenants, the meter read only in its tenant, the fail-open unknown feature, the seeded rows' ownership and whole limits, and the owner at `aal2` refused by the missing grant on each of the three.
- **Earn it and worth it.** No repair is owed, so no migration: a record-only contract, the SPEC-303 shape. A check against the `postgres`-only gaps would guard a writer that does not exist. The register is unchanged (no finding).

## Risks

- **None to the database.** No migration, function, policy, grant or trigger changes; Primary `vrvtsxexkiiiivlkdxzp` is not written and Secondary `brplkqmbzffpxqgkkdzo` is never contacted. The DATABASE protocol of `-Finish` resets the local ORVION database, as every DATABASE Finish does.
- **A future change to the reference read, the meter policy, plan gating or the table grants** now turns test 178 red where it changes what the slice measured; that is the purpose. A future meter producer must add the integrity checks this slice recorded.
- **Gate 1 of this contract is DELEGATED** under the owner's instructions, recorded outside this repository and never as a human-typed digest:
  - class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo
  - slice 14 in run mode 2, with the slice's own grouping decision, 2026-11-17 ~23:28 Cairo

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-312-every-member-reads-the-price-list-and-only-its-own-meter.md`
- `supabase/tests/178_the_price_list_is_read_by_every_member_and_a_meter_only_by_its_tenant_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607041300_create_system_catalog_tables.sql`
- `supabase/migrations/202607042700_create_subscription_tables.sql`
- `supabase/migrations/202607052500_plan_gating.sql`
- `supabase/migrations/202607053100_subscription_state_enforcement.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/25_conditional_vocabulary_and_plans_test.sql`
- `supabase/tests/30_plan_gating_test.sql`
- `supabase/tests/35_subscription_write_gate_test.sql`
- `supabase/tests/58_write_grants_and_config_capability_test.sql`
- `supabase/tests/117_plan_ceiling_semantics_and_non_enforcement_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/verify_database.sql`
- `.github/workflows/migration-ci.yml`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `supabase/migrations/202607041300_create_system_catalog_tables.sql` (`catalog_types`), `202607042700_create_subscription_tables.sql` (`feature_entitlements`, `usage_counters`), `202607052500_plan_gating.sql` (`app.plan_allows`) and `202607053100_subscription_state_enforcement.sql`
- `supabase/tests/10_grant_model_test.sql`, `58_write_grants_and_config_capability_test.sql` and `117_plan_ceiling_semantics_and_non_enforcement_test.sql`
- `changes/SPEC-303-the-consent-record-audit.md` (the record-only shape)
- `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_GAP_REGISTER.md` (PAR-5, DC-15); `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: record-only. Test 178 pins that a `trainee` at `aal1` and another tenant's `owner` at `aal2` each read every catalog type and every plan's entitlements; that each reads only its own tenant's meter; that `app.plan_allows` allows an unknown feature code; that every seeded type names its ownership and every seeded limit is whole; and that the owner at `aal2` is refused by the missing grant when it raises a plan limit, adds a catalog type or resets its own meter. The disposition record sets the three surfaces `AUDITED` / `ADVERSARIAL` with coverage 69 of 78; the manifest suite figure moves to 178 files / 3268 assertions.

Pass 2 Adversarial Review: each part was challenged on the prototype. Repeating the grant lists and the meter INSERT refusal in test 178 was rejected: they were re-measured, held, and are pinned by tests 10, 58 and 117. CHECK constraints for the `postgres`-only gaps (NULL ownership, negative limits, reversed, negative, unknown-metric or overlapping meters) were rejected for this slice: only migrations run as `postgres`, no meter producer exists, and the seeded and hosted rows hold none of them, so a check now would guard a writer that does not exist; a future producer owns them. Hiding the price list or the catalog from members was rejected: they are product reference data the readers and the client use. Failing `app.plan_allows` closed was rejected: fail-open is the recorded design of `202607052500_plan_gating.sql`, and test 178 pins it so a change is deliberate. Granting `service_role` SELECT was rejected: PAR-5 and DC-15 own that role's grants, which differ by environment. A test with `is()` assertions alone was rejected: Check 24 needs a negative assertion, and a grant-only mutant is killed only by the exact `permission denied for table` message, so three `throws_ok` carry it. A gap-register row was rejected: there is no finding. Copying the selector's next target into the manifest was rejected (SPEC-270; SPEC-278's cancellation).

Pass 3 Evidence Refresh: 2026-11-17. Re-measured on byte-identical files in a disposable clone of `eb44e95` with the project-local CLI 3.0.0: the clean reset, test 178 alone (10/10), the probes as the causal negative, the eleven mutants each installed and restored to the unmutated shape, the generators, declared scope, `git diff --check` and repository consistency; pgTAP Pass A and B, the three declared HTTP suites and smoke ran on the same bytes before the freeze. Primary was read read-only for the hosted rows and their integrity.

Selected Version: SPEC-312; selected: record-only (SPEC-303 shape): one test pinning what the slice measured and no test held, the three disposition rows AUDITED with coverage 69 of 78, and the suite figure; no migration, no register row, no hosted write; proven on byte-identical files by the full local protocol, eleven killed mutants and the probes

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Test 178 | `supabase/tests` | WRITE | SHA-256 `1dde413356237636f8ae185d51cc8315ce343480ac1cf6d8c4eda401a37b3a50`, md5 `08f06bb56de40fb1dcc22220fc0bdc12`, 6216 bytes, LF, ASCII, `plan(10)`: 10/10 on the prototype. |
| The plan readers, policies and grants | `app.plan_allows`; `app.plan_limit`; `app.tenant_capabilities`; `read_all_authenticated`; `tenant_isolation`; the table grants | UNAFFECTED | No body, grant, policy or trigger changes; `md5(pg_get_functiondef('app.plan_allows(text)'))` reads `05bf005b` (`78c6140f` with carriage returns stripped), the three tables' policies `7fc69e39`, RLS on `usage_counters` true and `authenticated`'s grants `525fc573`, before and after the mutants. |
| Other tests and the suite | the full pgTAP suite; the HTTP suites; smoke | VERIFY | Pass A `Files=178, Tests=3268`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 178/3268, PASS; smoke `ALL CHECKS PASSED` (78 tables, 71/626 catalog). 178 files whose literal `plan(N)` values sum to 3268. |
| The surfaces recorded | `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22 and 24 | WRITE | Test 178's `-- ATTACK-CLASSES:` line declares the ten classes with AUTH, STATE, CONCURRENCY, REPLAY, BUSINESS and OBSERVABILITY `=N/A` and carries negative assertions, so Check 24 admits `ADVERSARIAL`. Coverage 69: 45 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 9 `NOT-RECORDED`; all 69 `ADVERSARIAL`. |
| Measured state that moves | manifest suite figure; `ai-map.json` and `repository-index.md` | WRITE | 177 → 178 files and 3258 → 3268 assertions (Check 15). Migrations 269 and tables 78 do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 4 names `Current Module` and `Next capability` only to leave them unchanged; each line keeps its ratified text and pin. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3) | VERIFY | No RPC changes; the generator's output is identical to the stored file and to the baseline's (270 lines, 0 differ). It is in Write Scope because Check L3 regenerates it. |
| The gap register | `MASTER_GAP_REGISTER.md` | UNAFFECTED | No finding; positions and the `postgres`-only gaps are recorded in the disposition rows. |
| Primary and Secondary | hosted databases | UNAFFECTED | Nothing links, pushes or deploys; Primary was only read, read-only. |
| Repository consistency | `scripts/check_repository_consistency.ps1` | VERIFY | With the records applied on the prototype and no contract present, consistency reports exactly three items, Check 22's pointer from each of the three rows to this contract's file, which allocation creates; Checks 15, 21 and 24 pass. |
| The four CI-only guard self-tests | `scripts/test_*_guard.ps1`; `orvion-acceptance` | VERIFY | Unchanged scripts, run by `orvion-acceptance` on the exact candidate SHA before `main` may move to it; not run locally. |
| Active task and generated discovery | Native Boot and manifest projections | WRITE | Existing pointer and completion synchronization and the native generator only. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Selected bytes and baseline anchors | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 1 | Step 3 | Step 4 |
| Own native profiles and fresh verification | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: none of the controls that govern these records is added or changed: the missing INSERT, UPDATE and DELETE grants for every member role on the three tables, the `read_all_authenticated` policies on the catalog and the entitlements, the `tenant_isolation` policy on the meters, and `app.plan_allows`, `app.plan_limit` and `app.tenant_capabilities`.

Added Property: the measured behaviour is executable, so the suite turns red when it changes: the reference data stays readable in full by every member of every tenant; a meter stays inside its tenant; an unknown feature stays allowed until a deliberate change; the seeded types keep their ownership and the limits stay whole; the grant, not a policy, stays the door on each table.

Causal Negative: the probes (the slice's records, before any test existed, and again on the frozen bytes) measured the same behaviour; each mutant below, installed, turns its assertions red.

Positive Test Design: two active tenants on the `enterprise` plan, a `trainee` in the first and an `owner` in the second, and one October 2026 meter per tenant. Positive controls: both members read the full reference totals taken before the role switch, and each reads its own meter.

Negative Test Design:
- **Tenant:** each member's meter read returns exactly its own tenant's meter id, never the other's.
- **Privilege:** the owner at `aal2` is refused 42501 with `permission denied for table feature_entitlements`, `catalog_types` and `usage_counters` on a limit raise, a type insert and a meter reset.
- **Input:** an unknown feature code is allowed; no seeded type has NULL ownership; no seeded limit is fractional.

Non-Empty Population Obligation: the fixture holds two tenants, two users, two role grants, two subscriptions and two meters, and the seeded 71 types and 66 entitlements of 3 plans, before the first assertion; each refusal is asserted by exact SQLSTATE and message and each read by its exact totals or id.

Mutation Obligation: each mutant was installed inside test 178's own rolled-back transaction on the prototype stack, proven installed by the moved shape (`fn`, `pol`, `rls`, `nullown`, `frac`, `gr`), run, then rolled back; the shape was proven restored to the unmutated `05bf005b`, `7fc69e39`, true, 0, 0, `525fc573` with 0 failures unmutated.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| M1 | catalog types hidden from members | 178 assertions 3 and 6 |
| M2 | entitlements hidden from members | 178 assertions 3 and 6 |
| M3 | entitlements read only for enabled features | 178 assertions 3 and 6 |
| M4 | meters open across tenants | 178 assertions 4 and 7 |
| M5 | row level security off on meters | 178 assertions 4 and 7 |
| M6 | plan gating fails closed on an unknown code | 178 assertion 5 |
| M7 | a catalog type loses its ownership | 178 assertion 1 |
| M8 | a plan limit becomes fractional | 178 assertion 2 |
| M9 | members granted UPDATE on entitlements | 178 assertion 8 |
| M10 | members granted INSERT on catalog types | 178 assertion 9 |
| M11 | members granted UPDATE on meters | 178 assertion 10 |

Post-Implementation Proof Obligation: all of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI: the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke; the generated artifacts and repository consistency.

## Implementation Steps

1. Check whether `supabase/tests/178_the_price_list_is_read_by_every_member_and_a_meter_only_by_its_tenant_test.sql` contains `plan(10)`; if so record Already Applied when its Git blob is f2351dbaf7bcaaca26fd5b3cdf0f55ea7beeae8c, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 178, 10 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 56 (catalog_types, feature_entitlements, usage_counters) --
   -- the catalog types and every plan's entitlements are product reference data that every member of
   -- every tenant reads in full; a usage meter is read only inside its own tenant; an unknown feature
   -- code is allowed; the most privileged member, an owner at aal2, is refused by the missing grant when
   -- it tries to raise a plan limit, add a catalog type or reset its own meter (no migration: each door
   -- held when probed, so this file pins what was measured and was not yet pinned; tests 10, 58 and 117
   -- keep the grant lists and the INSERT refusal on meters).
   -- ATTACK-CLASSES: AUTH=N/A TENANT DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
   --   AUTH=N/A -- every read here is a SELECT that no second factor guards; no member writes any of
   --     the three tables (tests 10 and 58).
   --   STATE=N/A -- no row of the three has a lifecycle a member drives; no function writes them.
   --   CONCURRENCY, REPLAY=N/A -- nothing writes a meter (test 117); reads change no state.
   --   BUSINESS=N/A -- the plans' prices and limits are read, never charged here; ceilings are not
   --     enforced (test 117).
   --   OBSERVABILITY=N/A -- reading reference data and meters records no event on any door.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(10);

   select set_config('t178.totals',
     (select count(*) from public.catalog_types)::text || '/' || (select count(*) from public.feature_entitlements)
       || '/' || (select count(*) from public.subscription_plans), true);

   insert into auth.users (id, email) values
     ('17800000-0000-0000-0000-0000000000a1','trainee@c178.test'),
     ('17800000-0000-0000-0000-0000000000a2','other@c178.test');
   insert into public.tenants (id, name, slug, status) values
     ('17800000-0000-0000-0000-000000000001','Meter Travel','meter-travel-178','active'),
     ('17800000-0000-0000-0000-000000000002','Other Travel','other-travel-178','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select v.t, sp.id, 'active' from public.subscription_plans sp,
     (values ('17800000-0000-0000-0000-000000000001'::uuid), ('17800000-0000-0000-0000-000000000002')) v(t)
   where sp.plan_code = 'enterprise';
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('17800000-0000-0000-0000-000000000011','17800000-0000-0000-0000-000000000001','Trainee','trainee@c178.test',true,'17800000-0000-0000-0000-0000000000a1'),
     ('17800000-0000-0000-0000-000000000012','17800000-0000-0000-0000-000000000002','Other','other@c178.test',true,'17800000-0000-0000-0000-0000000000a2');
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select v.t, v.u, r.id, 'tenant'
   from (values
     ('17800000-0000-0000-0000-000000000001'::uuid, '17800000-0000-0000-0000-000000000011'::uuid, 'trainee'),
     ('17800000-0000-0000-0000-000000000002', '17800000-0000-0000-0000-000000000012', 'owner')) v(t, u, c)
   join public.roles r on r.code = v.c;
   insert into public.usage_counters (id, tenant_id, usage_metric_code, period_start, period_end, used_value) values
     ('17800000-0000-0000-0000-0000000000e1','17800000-0000-0000-0000-000000000001','monthly_leads','2026-10-01','2026-10-31',3),
     ('17800000-0000-0000-0000-0000000000e2','17800000-0000-0000-0000-000000000002','monthly_leads','2026-10-01','2026-10-31',5);

   select is(
     (select count(*)::int from public.catalog_types where ownership_type is null),
     0, 'every catalog type names its ownership (the column is nullable; no seeded row leaves it empty)');
   select is(
     (select count(*)::int from public.feature_entitlements where limit_value is not null and limit_value <> trunc(limit_value)),
     0, 'every plan limit is a whole number (test 117 pins the range; nothing writes the rows but migrations)');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"17800000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
   select is(
     (select count(*) from public.catalog_types)::text || '/' || (select count(*) from public.feature_entitlements)
       || '/' || (select count(distinct subscription_plan_id) from public.feature_entitlements),
     current_setting('t178.totals'),
     'a trainee at aal1 reads every catalog type and every plan''s entitlements: product reference data, not tenant data');
   select is(
     (select string_agg(id::text, ',') from public.usage_counters),
     '17800000-0000-0000-0000-0000000000e1', 'the trainee reads its own tenant''s meter and no other');
   select is(app.plan_allows('no_such_feature'), true,
     'a feature code no plan names is allowed: plan gating fails open by design (202607052500)');

   select set_config('request.jwt.claims', '{"sub":"17800000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   select is(
     (select count(*) from public.catalog_types)::text || '/' || (select count(*) from public.feature_entitlements)
       || '/' || (select count(distinct subscription_plan_id) from public.feature_entitlements),
     current_setting('t178.totals'),
     'another tenant''s owner reads the same full reference data');
   select is(
     (select string_agg(id::text, ',') from public.usage_counters),
     '17800000-0000-0000-0000-0000000000e2', 'another tenant''s owner reads only its own meter, never the first tenant''s');
   select throws_ok(
     $$update public.feature_entitlements set limit_value = limit_value + 1000 where limit_value is not null$$,
     '42501', 'permission denied for table feature_entitlements',
     'the owner at aal2 cannot raise a plan limit: no member holds UPDATE on the entitlements');
   select throws_ok(
     $$insert into public.catalog_types (code, name, ownership_type) values ('c178_own', 'Own', 'system')$$,
     '42501', 'permission denied for table catalog_types',
     'the owner at aal2 cannot add a catalog type: the refusal is the missing grant, not a policy');
   select throws_ok(
     $$update public.usage_counters set used_value = 0$$,
     '42501', 'permission denied for table usage_counters',
     'the owner at aal2 cannot reset its own tenant''s meter: the tenant policy is FOR ALL, so the grant is the door');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is f2351dbaf7bcaaca26fd5b3cdf0f55ea7beeae8c.

2. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**69 of 78 recorded · 45 `; if so record Already Applied when its Git blob is f386ccb9c4168c88789523771b773eef327928d3, and otherwise stop and report. Otherwise make exactly these 6 edits (the freshness entry, coverage 69 of 78 and the catalog_types, feature_entitlements and usage_counters rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-17 (**slice 55 — `branch_business_hours`, `document_storage_findings` and `attribution_clicks` selected by Exposure 4, 4 and 3, coverage 14, 34 and 42, in one contract.** Coverage **63 → 66 of 78**. RET-5: the storage resolver deleted a held document's version; ATTR-5: every member read every click of the tenant; ATTR-6: a member anchored a lead's first touch to another lead's click. SPEC-311 closes all three here; `branch_business_hours` holds with no finding, so the three rows are `AUDITED`.)
   ```
   with
   ```text
   Last updated: 2026-11-17 (**slice 56 — `catalog_types`, `feature_entitlements` and `usage_counters` selected by Exposure 2, 2 and 2, coverage 8, 10 and 16, in one contract.** Coverage **66 → 69 of 78**. No finding: every member reads the whole price list and catalog, a meter is read only inside its tenant, and no member writes any of the three. SPEC-312 records it with a pinning test and no migration, so the three rows are `AUDITED`. No other row changed.)

   Previously: 2026-11-17 (**slice 55 — `branch_business_hours`, `document_storage_findings` and `attribution_clicks` selected by Exposure 4, 4 and 3, coverage 14, 34 and 42, in one contract.** Coverage **63 → 66 of 78**. RET-5: the storage resolver deleted a held document's version; ATTR-5: every member read every click of the tenant; ATTR-6: a member anchored a lead's first touch to another lead's click. SPEC-311 closes all three here; `branch_business_hours` holds with no finding, so the three rows are `AUDITED`.)
   ```

   b) replace the line
   ```text
   **66 of 78 recorded · 42 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 12 `NOT-RECORDED`.**
   ```
   with
   ```text
   **69 of 78 recorded · 45 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 9 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 66 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 69 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `catalog_types` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `catalog_types` | **AUDITED** | ADVERSARIAL | `SPEC-312-every-member-reads-the-price-list-and-only-its-own-meter` | — | `178_the_price_list_is_read_by_every_member_and_a_meter_only_by_its_tenant_test.sql` (10 assertions; TENANT, DOOR, INPUT and PRIVILEGE declared, the rest N/A) proves that a `trainee` at `aal1` and another tenant's `owner` at `aal2` each read every catalog type; that every type names its ownership; and that the `owner` at `aal2` is refused adding a type by the missing grant, not by a policy. Mutants (types hidden from members, an ownership emptied, INSERT granted to members), each installed and restored md5-identical, are each killed. Tests 10, 25 and 58 pass unchanged. **Swept and classified as non-defects:** no member role inserts, renames, deactivates or deletes a type at any role or second factor (no grant); a code outside `^[a-z0-9_]+$` and a type still referenced by `catalog_values` are refused; the only reader is `app.guard_catalog_value_write`; anonymous REST is refused (401). **Recorded positions:** the catalog is product vocabulary, not tenant data, so every member reads all of it; `ownership_type` is nullable (only migrations write the rows, and none leaves it empty); `service_role` holds no SELECT, as its grants differ by environment (PAR-5, DC-15). 71 hosted types, none without ownership. |
   ```

   e) replace the line
   ```text
   | `feature_entitlements` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `feature_entitlements` | **AUDITED** | ADVERSARIAL | `SPEC-312-every-member-reads-the-price-list-and-only-its-own-meter` | — | `178_the_price_list_is_read_by_every_member_and_a_meter_only_by_its_tenant_test.sql` (10 assertions; TENANT, DOOR, INPUT and PRIVILEGE declared, the rest N/A) proves that every member reads every plan's entitlements, the same rows at `aal1` and `aal2` in two tenants; that every plan limit is a whole number; that `app.plan_allows` allows a feature code no plan names; and that the `owner` at `aal2` cannot raise a plan limit. Mutants (entitlements hidden, read only where enabled, a limit made fractional, plan gating failing closed, UPDATE granted to members), each installed and restored md5-identical, are each killed. Tests 10, 30, 35, 58 and 117 pass unchanged. **Swept and classified as non-defects:** no member role inserts, enables, raises or deletes an entitlement (no grant); the readers `app.plan_allows`, `app.plan_limit` and `app.tenant_capabilities` read only the caller's own subscription; `app.plan_limit` is not reachable anonymously (404); anonymous REST on the table is refused (401). **Recorded positions:** reading every plan's prices and limits is a product position (the price list is public to members); `app.plan_allows` fails open on an unknown code or an absent subscription by design (202607052500); no check refuses a negative or fractional limit, and six `max_*` rows carry no limit (unlimited); only migrations write the rows. 66 hosted rows, none negative or fractional. |
   ```

   f) replace the line
   ```text
   | `usage_counters` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `usage_counters` | **AUDITED** | ADVERSARIAL | `SPEC-312-every-member-reads-the-price-list-and-only-its-own-meter` | — | `178_the_price_list_is_read_by_every_member_and_a_meter_only_by_its_tenant_test.sql` (10 assertions; TENANT, DOOR, INPUT and PRIVILEGE declared, the rest N/A) proves that a `trainee` reads its own tenant's meter and no other; that another tenant's `owner` reads only its own; and that the `owner` at `aal2` cannot reset its own tenant's meter, because the tenant policy is FOR ALL and the grant is the door. Mutants (meters open across tenants, row level security off, UPDATE granted to members), each installed and restored md5-identical, are each killed. Tests 10, 35, 58 and 117 pass unchanged. **Swept and classified as non-defects:** no member role inserts, resets or deletes a meter at any role (no grant); another tenant cannot read a meter even by its id; anonymous REST is refused (401). **Recorded positions:** nothing writes or reads the meters (no function, view or job), and counting is a future mechanism (canon 28); until a producer exists, no check refuses a reversed period, a negative used value, an unknown metric or an overlapping period, and the plan limits are enforced by `app.plan_limit` alone; `service_role` holds no SELECT (PAR-5, DC-15). 0 hosted meters. |
   ```

   The resulting file's Git blob is f386ccb9c4168c88789523771b773eef327928d3.

3. Check whether `_ORVION_CANONICAL/manifest.md` contains `Suite **178 files / 3268 assertions**`; if so record Already Applied when its Git blob is c54a23ed61cbe3ddddda76e99bfa6471eeb00ece, and otherwise stop and report. Otherwise make exactly this one edit (the suite figure), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: Last fully verified 2026-11-11. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 269 migrations** (latest `20261117120000`), ledger `ff29e9c5acf7d70b25862941f548cf97`, full-function-surface hash `f7427d65b5f8ee6d9f0a360ec5717b59` (350 functions) identical on both; structural-surface hash `20caafd5b6cde6e9002e209b0a3a3102` (3,177 objects) identical on both — **all ten surfaces identical** (`PAR-5` resolved by `SPEC-207`). Re-read live from Primary 2026-11-14; ledger **read FROM Primary** (GUARD-1). **80 client RPCs**. Suite **177 files / 3258 assertions** (Pass A = Pass B, 2026-11-11).
   ```
   with
   ```text
   Live state: Last fully verified 2026-11-11. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 269 migrations** (latest `20261117120000`), ledger `ff29e9c5acf7d70b25862941f548cf97`, full-function-surface hash `f7427d65b5f8ee6d9f0a360ec5717b59` (350 functions) identical on both; structural-surface hash `20caafd5b6cde6e9002e209b0a3a3102` (3,177 objects) identical on both — **all ten surfaces identical** (`PAR-5` resolved by `SPEC-207`). Re-read live from Primary 2026-11-14; ledger **read FROM Primary** (GUARD-1). **80 client RPCs**. Suite **178 files / 3268 assertions** (Pass A = Pass B, 2026-11-11).
   ```

   The resulting file's Git blob is c54a23ed61cbe3ddddda76e99bfa6471eeb00ece.

4. **Check** for a `Local certification` Execution Log entry. If absent:
   - Confirm that `supabase/tests` holds 178 files whose literal `plan(N)` values sum to 3268; if either differs, stop.
   - Regenerate `ai-map.json` and `repository-index.md` (stored LF) with the canonical generator, and confirm the API-contract generator's output is identical to `MASTER_API_CONTRACT.md`.
   - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once; the pre-commit Gate must admit it.
   - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, in the Complete commit: transition to Complete, tick the Acceptance Criteria and the Review Gate, clear `Active Change Request`, set `Last Completed` from Notes, leave `Next capability` and `Current Module` unchanged, and regenerate `ai-map.json` and `repository-index.md` LF.
   - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] Test 178 is the frozen bytes; `check: blob supabase/tests/178_the_price_list_is_read_by_every_member_and_a_meter_only_by_its_tenant_test.sql f2351dbaf7bcaaca26fd5b3cdf0f55ea7beeae8c`
- [ ] The disposition record carries `catalog_types`, `feature_entitlements` and `usage_counters` AUDITED / ADVERSARIAL and coverage 69 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md f386ccb9c4168c88789523771b773eef327928d3`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **178 files / 3268 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @eb44e95720abd9a80d24b95854f8c11382bc9494`
- [ ] Migration CI remains exact; `check: same .github/workflows/migration-ci.yml @eb44e95720abd9a80d24b95854f8c11382bc9494`
- [ ] The catalog migration remains exact; `check: same supabase/migrations/202607041300_create_system_catalog_tables.sql @eb44e95720abd9a80d24b95854f8c11382bc9494`
- [ ] The subscription tables' migration remains exact; `check: same supabase/migrations/202607042700_create_subscription_tables.sql @eb44e95720abd9a80d24b95854f8c11382bc9494`
- [ ] The plan-gating migration remains exact; `check: same supabase/migrations/202607052500_plan_gating.sql @eb44e95720abd9a80d24b95854f8c11382bc9494`
- [ ] No file under `supabase/migrations/` changed and no database object was created, altered or dropped; Primary `vrvtsxexkiiiivlkdxzp` was not written and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] Mutants M1–M11 are each killed with installation and restoration proven.

## Execution Log

None.


### 2026-11-18 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was eb44e95720abd9a80d24b95854f8c11382bc9494 and every source anchor matched there; Draft allocated as 84ab447 and approved as 65c404a with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `supabase/tests/178_the_price_list_is_read_by_every_member_and_a_meter_only_by_its_tenant_test.sql` edited exactly as the step states; blob f2351dbaf7bcaaca26fd5b3cdf0f55ea7beeae8c (91 insertions, 0 deletions (created)).
- Step 3 Applied: `reports/master/MASTER_SURFACE_DISPOSITION.md` edited exactly as the step states; blob f386ccb9c4168c88789523771b773eef327928d3 (8 insertions, 6 deletions).
- Step 4 Applied: `_ORVION_CANONICAL/manifest.md` edited exactly as the step states; blob c54a23ed61cbe3ddddda76e99bfa6471eeb00ece (1 insertions, 1 deletions).
- Step 5 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain.

## Verification Notes

None.


### 2026-11-18 — Gate 1 approval recorded

DELEGATED exact Gate1 under the owner's instructions of 2026-11-08 (class authorization for Batch 6 releases and standing approval of proposals ~10:20 Cairo; publish, promote and hosted deploy ~12:05 Cairo), 2026-11-11 (Batch 6 decisions 1-9 ~19:50 Cairo), 2026-11-12 (priority order waiving no gate ~12:20 Cairo), 2026-11-14 (one contract per product ~11:30 Cairo; no credential rotation ~12:30 Cairo; BP-32 approved in principle ~16:20 Cairo) and 2026-11-17 (slice 14 runs through in run mode 2, ~23:28 Cairo); Draft SHA-256 D37156FADF27FF2E887A56CAF02F02931977ABA472ECEA8660A656DA17B8877D, decision SHA-256 977A48DC8104255BBB8324CAC79A27967D03809E40BB4AC9BD4587F70DADBC55. No fabricated human future-digest approval. Record-only: no migration, no hosted write. Immediately before allocation the hash, the Draft blob 338ec572a96d7c9a8eda8a53afe9368a2771e66c, all 2 source anchors, the baseline HEAD eb44e95720abd9a80d24b95854f8c11382bc9494 against refreshed origin/main eb44e95720abd9a80d24b95854f8c11382bc9494 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 84ab447. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-312: Batch 6 Slice 56 — the catalog, the price list and the usage meters audited and recorded, no finding (catalog_types, feature_entitlements and usage_counters AUDITED, 69 of 78); native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline eb44e95720abd9a80d24b95854f8c11382bc9494 and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `74068baae6f3cd17764f6384ec56fdaef3a4f473` |
| `_ORVION_CANONICAL/manifest.md` | `526100f41acd51b78ca116571fc745cd4233b1fe` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md and SPEC-303 at eb44e95720abd9a80d24b95854f8c11382bc9494; the owner's instructions of 2026-11-08, 2026-11-16 and 2026-11-17 (recorded outside this repository). This is the one Draft for these surfaces, finalized after the adversarial review and the evidence refresh its Draft Assurance records; correctness remains native and independent.
