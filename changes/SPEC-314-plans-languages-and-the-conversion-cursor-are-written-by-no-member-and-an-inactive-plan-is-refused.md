# Change Request — SPEC-314

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 58 audits `subscription_plans`, `integration_cursors` and `languages` and records them, not repaired: nothing material was found, so one test pins what the slice measured and no test held, and the disposition record sets the three surfaces `AUDITED`.

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `8ff5563`, on the live local catalog, ranks `subscription_plans` (Exposure 2, coverage 866), `integration_cursors` (1/24) and `languages` (0/4) next, all NOT-RECORDED. Under the owner's instructions of 2026-11-16, this slice's entry of 2026-11-18 grouped the selector's next three surfaces in one contract per product: the three are platform-owned tables with no member write grant, so their probes share one fixture, and each keeps its own probes, assertions and mutants. `nationalities`, `countries` and `currencies` are the selector's next. The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.** `subscription_plans` (3 seeded rows) is what every subscription, activation, licence token and trial is sold on; `integration_cursors` (1 row) is the position of `app.map_outcomes_to_conversions`, which turns qualified outcomes into offline conversions; `languages` (20) is the reference list behind `customers.preferred_language_code`. A member who could change a plan, rewind or read the cursor, or add a language would change what the platform sells, what it reports to advertising platforms, or the reference data every tenant shares; a plan reader that ignored a deactivated plan would keep selling what the platform withdrew.
- **Measured at `8ff5563`** on the local stack with committed probe fixtures (an owner at `aal1` and `aal2`, an employee, a trainee, a manager, a finance user, another tenant's owner at `aal2`, `service_role`, anonymous REST, and `postgres` for integrity only), every axis held or is a recorded design position:
  - **Held:** every member write to the three is refused 42501 by the missing grant at every role, tenant and second factor (insert, deactivate and delete a plan; read, reset, insert and delete the cursor; insert, deactivate and delete a language); anonymous REST on all three 401 and `rpc/map_outcomes_to_conversions` 404; `anon` and `orvion_integration` hold no privilege on them; only `orvion_integration` (and `postgres`) holds EXECUTE on the mapper; `app.platform_activate_subscription`, `app.platform_issue_license_token`, the redemption of a token issued while the plan was active, and `app.provision_tenant` each refuse an inactive plan after a positive control; the cursor moves only forward through its one function, and a rewound or negative cursor reruns without a second conversion (the unique `source_event_seq`); an unknown language is refused by the foreign key.
  - **Positions:** the plan list and the language list are platform reference data every member of every tenant reads, written only by migrations; a deactivated plan grandfathers the tenants already on it (`app.subscription_allows_write` reads the subscription, not the plan); `app.provision_tenant` names `enterprise` in its text; a deactivated language stays valid on a customer, as for `nationalities`, `countries` and `currencies` (the foreign key checks existence, not `is_active`), and whether these four reference lists should refuse an inactive value is carried to slice 59, where the other three are the selector's next.
  - **Reachable only as `postgres` or `service_role`:** a cursor set ahead of the horizon, deleted or truncated stalls or skips the mapper; a plan with subscribers cannot be deleted (ON DELETE RESTRICT) and a renamed `enterprise` code would stop `app.provision_tenant`. Only migrations run as `postgres`, and a migration that changes these tables carries its own test; the `service_role` blast radius is DC-15 (OPEN; PAR-5 FIXED by SPEC-207). Hosted Primary and Secondary each hold 3 active plans, 20 active languages and the cursor at 0 with no source event and no open mapper finding.
- **What is pinned where.** Test 18 pins the seeded reference counts, tests 35, 36, 42, 43, 80, 131, 147 and 148 the plan readers' positive paths, the write gate and the platform authority, and tests 51, 66, 119, 142 and 169 the mapper, its dedupe and its findings. Test 180 adds only what the slice measured and no test held: both lists read in full at `aal1` and `aal2` in two tenants, the owner at `aal2` refused by the missing grant on each of the three, `anon` and `orvion_integration` without privilege, the mapper's EXECUTE held by `orvion_integration` alone, each plan reader refusing a deactivated plan, the grandfathered write gate, the cursor moved forward and a rewound rerun without a duplicate, and a deactivated language accepted while an unknown one is refused.
- **Earn it and worth it.** No repair is owed, so no migration: a record-only contract, the SPEC-303 shape. The register is unchanged (no finding).

## Risks

- **None to the database.** No migration, function, policy, grant or trigger changes; Primary `vrvtsxexkiiiivlkdxzp` is not written and Secondary `brplkqmbzffpxqgkkdzo` is never contacted. The DATABASE protocol of `-Finish` resets the local ORVION database, as every DATABASE Finish does.
- **A future change to the three tables' grants or read policies, the mapper's EXECUTE or cursor handling, or a plan reader's `is_active` handling** now turns test 180 red where it changes what the slice measured; that is the purpose.
- **Gate 1 of this contract is DELEGATED** under the owner's instructions, recorded outside this repository and never as a human-typed digest:
  - class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo
  - slice 16 in run mode 2, with the slice's own grouping decision, 2026-11-18 ~14:55 Cairo

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-314-plans-languages-and-the-conversion-cursor-are-written-by-no-member-and-an-inactive-plan-is-refused.md`
- `supabase/tests/180_plans_languages_and_conversion_cursor_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607042000_create_geo_reference_tables.sql`
- `supabase/migrations/202607042100_create_crm_core_tables.sql`
- `supabase/migrations/202607042700_create_subscription_tables.sql`
- `supabase/migrations/202607043300_create_rls_policies.sql`
- `supabase/migrations/202607043700_provision_tenant_and_has_permission.sql`
- `supabase/migrations/202607049300_outcome_conversion_mapper.sql`
- `supabase/migrations/202607049900_seed_subscription_plans.sql`
- `supabase/migrations/202607050200_restore_least_privilege_grant_model.sql`
- `supabase/migrations/202607053100_subscription_state_enforcement.sql`
- `supabase/migrations/202607054000_subscription_lifecycle_and_platform_authority.sql`
- `supabase/migrations/202607054100_tenant_license_activation.sql`
- `supabase/migrations/202607058400_a_single_use_code_is_single_use_under_concurrency_too.sql`
- `supabase/migrations/202607061200_an_account_keeps_the_currency_its_money_arrived_in.sql`
- `supabase/migrations/20261009120000_a_subscription_transition_is_judged_on_the_row_it_replaces.sql`
- `supabase/migrations/20261114160000_a_conversion_source_event_is_mapped_even_when_it_commits_late.sql`
- `supabase/tests/18_reference_data_test.sql`
- `supabase/tests/35_subscription_write_gate_test.sql`
- `supabase/tests/36_subscription_gate_system_paths_test.sql`
- `supabase/tests/42_subscription_lifecycle_test.sql`
- `supabase/tests/43_license_activation_test.sql`
- `supabase/tests/80_subscription_licensing_test.sql`
- `supabase/tests/119_conversion_provenance_is_platform_written_test.sql`
- `supabase/tests/142_a_google_ads_call_qualifies_as_a_phone_call_test.sql`
- `supabase/tests/169_a_conversion_source_event_is_mapped_even_when_it_commits_late_test.sql`
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
- `supabase/migrations/202607042000_create_geo_reference_tables.sql` (`languages`), `202607042700_create_subscription_tables.sql` (`subscription_plans`), `202607049300_outcome_conversion_mapper.sql` (`integration_cursors`, the mapper and its dedupe index) and `202607042100_create_crm_core_tables.sql` (the language foreign key); the plan readers' migrations `202607043700_provision_tenant_and_has_permission.sql`, `202607054000_subscription_lifecycle_and_platform_authority.sql`, `202607054100_tenant_license_activation.sql`, `202607058400_a_single_use_code_is_single_use_under_concurrency_too.sql` and `20261009120000_a_subscription_transition_is_judged_on_the_row_it_replaces.sql`; the write gate's `202607061200_an_account_keeps_the_currency_its_money_arrived_in.sql`; the mapper's latest `20261114160000_a_conversion_source_event_is_mapped_even_when_it_commits_late.sql`
- `supabase/tests/18_reference_data_test.sql`, `35_subscription_write_gate_test.sql`, `42_subscription_lifecycle_test.sql`, `43_license_activation_test.sql`, `80_subscription_licensing_test.sql`, `119_conversion_provenance_is_platform_written_test.sql` and `169_a_conversion_source_event_is_mapped_even_when_it_commits_late_test.sql`
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

Pass 1 Design: record-only. Test 180 pins that `anon` and `orvion_integration` hold no privilege on the three tables and `authenticated` holds only SELECT on the plan and language lists; that only `orvion_integration` holds EXECUTE on `app.map_outcomes_to_conversions` and no member may run `app.platform_activate_subscription` or `app.platform_issue_license_token`; that an `employee` at `aal1` and another tenant's `owner` at `aal2` each read every plan and language; that the owner at `aal2` is refused by the missing grant when it deactivates a plan, adds a language, reads the cursor or rewinds it; and, each after a positive control, that a deactivated plan is refused by activation, by licence-token issue and at the redemption of a token issued while it was active, that `app.provision_tenant` refuses a deactivated `enterprise` plan, that a tenant already on a deactivated plan still writes, that the mapper maps a qualified lead once and moves its cursor forward, that a rewound cursor reruns without a second conversion, and that a deactivated language is accepted on a customer while an unknown one is refused by the foreign key. The disposition record sets the three surfaces `AUDITED` / `ADVERSARIAL` with coverage 75 of 78; the manifest suite figure moves to 180 files / 3302 assertions.

Pass 2 Adversarial Review: each part was challenged on the prototype. Repeating the seeded counts, the write gate, the mapper's dedupe or its findings in test 180 was rejected: they were re-measured, held, and are pinned by tests 18, 35, 119 and 169. Hiding the plan or language list from members was rejected: both are platform reference data the client and every member's own forms read. Refusing a tenant on a deactivated plan was rejected: deactivation stops new sales, not running tenants, and the write gate reads the subscription. Refusing an inactive language on a customer was rejected for this slice: the sibling reference lists behave the same, so the four are decided together in slice 59. A guard against moving the cursor backwards was rejected: only `postgres` and `service_role` can write it, a rewind reruns without a duplicate, and `service_role` grants differ by environment (PAR-5 FIXED, DC-15 OPEN). Granting or revoking `service_role` privileges was rejected for the same reason. A test with `is()` assertions alone was rejected: Check 24 needs a negative assertion, and a grant-only mutant is killed only by the exact `permission denied for table` message, so `throws_ok` carries each refusal. Reading the cursor in the statement that runs the mapper was rejected: the subquery reads the statement's snapshot, so the mapper runs in its own statement and the cursor is read in the next. A gap-register row was rejected: there is no finding. Copying the selector's next target into the manifest was rejected (SPEC-270; SPEC-278's cancellation).

Pass 3 Evidence Refresh: 2026-11-18. Re-measured on byte-identical files in a disposable clone of `8ff5563` with the project-local CLI 3.0.0: the clean reset, test 180 alone (20/20), the probes as the causal negative, the fifteen mutants each installed and restored to the unmutated shape, the generators, declared scope, `git diff --check` and repository consistency; pgTAP Pass A and B, the three declared HTTP suites and smoke ran on the same bytes before the freeze. Primary and Secondary were read read-only for the hosted rows.

Selected Version: SPEC-314; selected: record-only (SPEC-303 shape): one test pinning what the slice measured and no test held, the three disposition rows AUDITED with coverage 75 of 78, and the suite figure; no migration, no register row, no hosted write; proven on byte-identical files by the full local protocol, fifteen killed mutants and the probes

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Test 180 | `supabase/tests` | WRITE | SHA-256 `11155ab066a1165feefd069b9f14fab2f6dfd96d6dfcb92cd90d77389b287a6c`, md5 `566e2c3731c0118cbc191379e0e5fc78`, 14078 bytes, LF, ASCII, `plan(20)`: 20/20 on the prototype. |
| The plan readers, the mapper, policies and grants | `app.platform_activate_subscription`; `app.platform_issue_license_token`; `app.provision_tenant`; `app.map_outcomes_to_conversions`; `app.subscription_allows_write`; the three tables' policies and grants; the dedupe index; the language foreign key | UNAFFECTED | No body, grant, policy, index or trigger changes; the five functions' definitions read `ee74c770` on the prototype's CRLF migrations (`7e95d485` on the source checkout, `b6799af6` with carriage returns stripped), the three tables' policies `fe7fb91c`, their ACLs `35606398`, the mapper's EXECUTE `{postgres=X/postgres,orvion_integration=X/postgres}`, the dedupe index and the language foreign key present, before and after the mutants. |
| Other tests and the suite | the full pgTAP suite; the HTTP suites; smoke | VERIFY | Pass A `Files=180, Tests=3302`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 180/3302, PASS; smoke `ALL CHECKS PASSED` (78 tables, 71/626 catalog). 180 files whose literal `plan(N)` values sum to 3302. |
| The surfaces recorded | `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22 and 24 | WRITE | Test 180's `-- ATTACK-CLASSES:` line declares the ten classes with CONCURRENCY and OBSERVABILITY `=N/A` and carries negative assertions, so Check 24 admits `ADVERSARIAL`. Coverage 75: 51 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 3 `NOT-RECORDED`; all 75 `ADVERSARIAL`. |
| Measured state that moves | manifest suite figure; `ai-map.json` and `repository-index.md` | WRITE | 179 → 180 files and 3282 → 3302 assertions (Check 15). Migrations 269 and tables 78 do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 4 names `Current Module` and `Next capability` only to leave them unchanged; each line keeps its ratified text and pin. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3) | VERIFY | No RPC changes; the generator's output is identical to the stored file and to the baseline's (270 lines, 0 differ). It is in Write Scope because Check L3 regenerates it. |
| The gap register | `MASTER_GAP_REGISTER.md` | UNAFFECTED | No finding; positions are recorded in the disposition rows, citing PAR-5 (FIXED by SPEC-207) and DC-15 (OPEN). |
| Primary and Secondary | hosted databases | UNAFFECTED | Nothing links, pushes or deploys; both were only read, read-only. |
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

Existing Mechanism: none of the controls that govern these records is added or changed: the missing write grants for every member role on the three tables and the missing SELECT on the cursor, no privilege for `anon` and `orvion_integration`, the `read_all_authenticated` and `platform_only` policies, the mapper's EXECUTE to `orvion_integration` only, its forward-only cursor update and the unique `source_event_seq` index, the `is_active` checks inside `app.platform_activate_subscription`, `app.platform_issue_license_token`, the token redemption and `app.provision_tenant`, and the `customers_preferred_language_code_fkey` foreign key.

Added Property: the measured behaviour is executable, so the suite turns red when it changes: the plan and language lists stay readable in full by every member of every tenant and writable by none; the cursor stays closed to every member and moves only forward through its one function; `anon` and `orvion_integration` stay without privilege; a deactivated plan stays unsellable while the tenants on it keep working; a deactivated language stays valid and an unknown one stays refused.

Causal Negative: the probes (the slice's records, before any test existed, and again on the frozen bytes) measured the same behaviour; each mutant below, installed, turns its assertions red.

Positive Test Design: two active tenants on the `enterprise` plan, an `owner` and an `employee` (Giza branch, sales department) in the first and an `owner` in the second. Positive controls: both members read the plan and language totals taken before the role switch; the platform activates an active plan; the employee creates a customer; the mapper maps a qualified call lead once and moves its cursor to that event.

Negative Test Design:
- **Auth and privilege:** `anon` and `orvion_integration` hold none of the table privileges on the three tables; `authenticated` holds only `languages:SELECT` and `subscription_plans:SELECT`; only `orvion_integration` runs the mapper; the owner at `aal2` is refused 42501 with `permission denied for table subscription_plans`, `languages` and `integration_cursors` on a plan deactivation, a language insert, a cursor read and a cursor rewind.
- **State:** a deactivated `professional` plan is refused P0001 `unknown or inactive plan_code: professional` by activation, by licence-token issue and at redemption of a token issued while it was active; a deactivated `enterprise` plan makes `app.provision_tenant` refuse P0001 `enterprise plan is not seeded; cannot start a full-feature trial`; the write gate stays open for the tenant already on it.
- **Replay and input:** with the cursor rewound to 0 a rerun maps nothing new (`0/1`); a deactivated language `fr` is accepted on a customer and an unknown `zz` is refused 23503 by `customers_preferred_language_code_fkey`.
- **Tenant and door:** another tenant's owner reads the same plan and language totals and nothing more; no member reaches the cursor.

Non-Empty Population Obligation: the fixture holds two tenants, three users, their role grants, two subscriptions, one branch and one department, a qualified call-lead source event, and the seeded 3 plans, 1 cursor and 20 languages, before the first assertion; each refusal is asserted by exact SQLSTATE and message and each read by its exact totals or values.

Mutation Obligation: each mutant was installed on the prototype stack, proven installed by the moved shape (`fn`, `pol`, `acl`, `mx`, `idx`, `fk`), run against test 180, then restored; the shape was proven restored to the unmutated `ee74c770`, `fe7fb91c`, `35606398`, `{postgres=X/postgres,orvion_integration=X/postgres}`, 1, 1 with 0 failures unmutated.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| M1 | plans hidden from members | 180 assertions 4 and 5 |
| M2 | languages hidden from members | 180 assertions 4 and 5 |
| M3 | members granted UPDATE on plans | 180 assertions 2 and 6 |
| M4 | members granted INSERT on languages | 180 assertions 2 and 7 |
| M5 | members granted SELECT on the cursor | 180 assertions 2 and 8 |
| M6 | members granted UPDATE on the cursor, with a permissive policy | 180 assertions 2 and 9 |
| M7 | `orvion_integration` granted SELECT on the cursor | 180 assertion 1 |
| M8 | members granted EXECUTE on the mapper | 180 assertion 3 |
| M9 | `app.platform_activate_subscription` accepts an inactive plan | 180 assertions 11 and 13 |
| M10 | `app.platform_issue_license_token` accepts an inactive plan | 180 assertions 12 and 13 |
| M11 | `app.provision_tenant` accepts an inactive `enterprise` plan | 180 assertion 14 |
| M12 | the write gate drops a tenant on a deactivated plan | 180 assertion 15 (and the plan aborts at 16) |
| M13 | the mapper holds its cursor | 180 assertion 17 |
| M14 | the dedupe index dropped | 180 assertions 17 and 18 |
| M15 | the language foreign key dropped | 180 assertion 20 |

Post-Implementation Proof Obligation: all of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI: the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke; the generated artifacts and repository consistency.

## Implementation Steps

1. Check whether `supabase/tests/180_plans_languages_and_conversion_cursor_test.sql` contains `plan(20)`; if so record Already Applied when its Git blob is a5de730097515f7cc2a2f95dcbba070b9f4e4385, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 180, 20 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 58 (subscription_plans, integration_cursors, languages) --
   -- the plan list and the language list are platform-owned reference data: every member of every tenant
   -- reads all of both, no member writes either (an owner at aal2 is refused by the missing grant), and anon
   -- and orvion_integration hold no privilege on them. integration_cursors is the conversion mapper's
   -- position: no member reads or writes it, and its one writer, app.map_outcomes_to_conversions (EXECUTE to
   -- orvion_integration only), moves it forward; a rewound cursor re-maps nothing (one source event is one
   -- conversion). The plan readers honour is_active: app.platform_activate_subscription,
   -- app.platform_issue_license_token, app.redeem_license_token (for a token issued while the plan was
   -- active) and app.provision_tenant refuse a deactivated plan; a tenant already on a deactivated plan keeps
   -- working (grandfathered). A deactivated language stays valid on a customer, as the sibling reference
   -- tables are (the foreign key refuses only an unknown code). Each is proven after a positive control. No
   -- migration: each door held when probed, so this file pins what was measured and was not yet pinned
   -- (tests 18, 51, 119, 142 and 169 keep the seeded counts, CUR-1 and the mapper's dedupe and findings).
   -- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY=N/A REPLAY PRIVILEGE BUSINESS OBSERVABILITY=N/A
   --   CONCURRENCY=N/A -- only migrations write the plan and language lists; two mapper runs over one source
   --     event meet the same unique index on source_event_seq that the REPLAY assertion pins.
   --   OBSERVABILITY=N/A -- the member-facing writes are refused before any row or event exists; the mapper's
   --     failure findings are tests 119 and 137.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(20);

   select set_config('t180.totals',
     (select count(*) from public.subscription_plans)::text || '/' || (select count(*) from public.languages), true);

   insert into auth.users (id, email) values
     ('18000000-0000-0000-0000-0000000000a1','owner@c180.test'),
     ('18000000-0000-0000-0000-0000000000a2','employee@c180.test'),
     ('18000000-0000-0000-0000-0000000000a5','other@c180.test');
   insert into public.tenants (id, name, slug, status) values
     ('18000000-0000-0000-0000-000000000001','Plan Travel','plan-travel-180','active'),
     ('18000000-0000-0000-0000-000000000002','Other Travel','other-travel-180','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code, starts_at)
   select v.t, sp.id, 'active', now() - interval '2 days' from public.subscription_plans sp,
     (values ('18000000-0000-0000-0000-000000000001'::uuid), ('18000000-0000-0000-0000-000000000002')) v(t)
   where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('18000000-0000-0000-0000-0000000000b1','18000000-0000-0000-0000-000000000001','Giza','giza-180');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('18000000-0000-0000-0000-0000000000c1','18000000-0000-0000-0000-000000000001','18000000-0000-0000-0000-0000000000b1','sales','Giza Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('18000000-0000-0000-0000-000000000011','18000000-0000-0000-0000-000000000001','Owner','owner@c180.test',true,'18000000-0000-0000-0000-0000000000a1'),
     ('18000000-0000-0000-0000-000000000012','18000000-0000-0000-0000-000000000001','Employee','employee@c180.test',true,'18000000-0000-0000-0000-0000000000a2'),
     ('18000000-0000-0000-0000-000000000015','18000000-0000-0000-0000-000000000002','Other','other@c180.test',true,'18000000-0000-0000-0000-0000000000a5');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
     ('18000000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000012','18000000-0000-0000-0000-0000000000b1','18000000-0000-0000-0000-0000000000c1',true);
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select v.t, v.u, r.id, 'tenant'
   from (values
     ('18000000-0000-0000-0000-000000000001'::uuid, '18000000-0000-0000-0000-000000000011'::uuid, 'owner'),
     ('18000000-0000-0000-0000-000000000001', '18000000-0000-0000-0000-000000000012', 'employee'),
     ('18000000-0000-0000-0000-000000000002', '18000000-0000-0000-0000-000000000015', 'owner')) v(t, u, c)
   join public.roles r on r.code = v.c;

   -- =============================================================================================
   -- 1-3. THE GRANTS: reference data read-only to members, the cursor closed, the mapper integration-only.
   -- =============================================================================================
   select is(
     (select count(*)::int from unnest(array['anon','orvion_integration']) r,
        unnest(array['public.subscription_plans','public.integration_cursors','public.languages']) t,
        unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
      where has_table_privilege(r, t, p)),
     0, 'anon and orvion_integration hold no privilege of any kind on the three tables');
   select is(
     (select string_agg(split_part(t, '.', 2) || ':' || p, ',' order by t, p)
        from unnest(array['public.subscription_plans','public.integration_cursors','public.languages']) t,
             unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
       where has_table_privilege('authenticated', t, p)),
     'languages:SELECT,subscription_plans:SELECT',
     'authenticated may read the plan and language lists and holds nothing else on the three tables, nothing at all on integration_cursors');
   select is(
     (select string_agg(r || '=' || has_function_privilege(r, 'app.map_outcomes_to_conversions(integer)', 'EXECUTE'), ',' order by r)
        from unnest(array['anon','authenticated','orvion_integration','service_role']) r)
       || '/' || has_function_privilege('authenticated', 'app.platform_activate_subscription(uuid,text,text,boolean)', 'EXECUTE')
       || '/' || has_function_privilege('authenticated', 'app.platform_issue_license_token(uuid,text,text,boolean,integer,text)', 'EXECUTE'),
     'anon=false,authenticated=false,orvion_integration=true,service_role=false/false/false',
     'only orvion_integration may run the cursor''s one writer; no member may activate a plan or issue a license token');

   -- =============================================================================================
   -- 4-9. THE MEMBER DOORS: every member reads all of the reference data, none writes it or touches the cursor.
   -- =============================================================================================
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
   select is((select count(*) from public.subscription_plans)::text || '/' || (select count(*) from public.languages),
     current_setting('t180.totals'), 'an employee at aal1 reads every plan and every language');
   select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a5","aal":"aal2"}', true);
   select is((select count(*) from public.subscription_plans)::text || '/' || (select count(*) from public.languages),
     current_setting('t180.totals'), 'another tenant''s owner reads the same lists: reference data, not tenant data');

   select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   select throws_ok($$update public.subscription_plans set is_active = false where plan_code = 'starter'$$,
     '42501', 'permission denied for table subscription_plans', 'the owner at aal2 cannot deactivate a plan');
   select throws_ok($$insert into public.languages (code, name) values ('zz', 'Forged')$$,
     '42501', 'permission denied for table languages', 'the owner at aal2 cannot add a language');
   select throws_ok($$select last_seq from public.integration_cursors$$,
     '42501', 'permission denied for table integration_cursors', 'the owner at aal2 cannot read the mapper cursor');
   select throws_ok($$update public.integration_cursors set last_seq = 0$$,
     '42501', 'permission denied for table integration_cursors', 'the owner at aal2 cannot rewind the mapper cursor');
   reset role;
   select set_config('request.jwt.claims', '', true);

   -- =============================================================================================
   -- 10-14. THE PLAN READERS honour is_active, after a positive control.
   -- =============================================================================================
   select lives_ok($$select app.platform_activate_subscription('18000000-0000-0000-0000-000000000002', 'professional', 'monthly')$$,
     'POSITIVE CONTROL: the platform activates an active plan');
   select set_config('t180.tok', app.platform_issue_license_token('18000000-0000-0000-0000-000000000002', 'professional', 'monthly'), true) is not null;
   update public.subscription_plans set is_active = false where plan_code = 'professional';
   select throws_ok($$select app.platform_activate_subscription('18000000-0000-0000-0000-000000000002', 'professional', 'monthly')$$,
     'P0001', 'unknown or inactive plan_code: professional', 'the platform cannot activate a deactivated plan');
   select throws_ok($$select app.platform_issue_license_token('18000000-0000-0000-0000-000000000002', 'professional', 'monthly')$$,
     'P0001', 'unknown or inactive plan_code: professional', 'the platform cannot issue a license token for a deactivated plan');
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a5","aal":"aal2"}', true);
   select throws_ok($$select app.redeem_license_token(current_setting('t180.tok'))$$,
     'P0001', 'unknown or inactive plan_code: professional',
     'a token issued while the plan was active cannot be redeemed after the plan is deactivated');
   reset role;
   select set_config('request.jwt.claims', '', true);
   update public.subscription_plans set is_active = false where plan_code = 'enterprise';
   select throws_ok($$select * from app.provision_tenant('New Travel', 'new-travel-180', 'new@c180.test', 'New')$$,
     'P0001', 'enterprise plan is not seeded; cannot start a full-feature trial',
     'no tenant is provisioned onto a deactivated enterprise trial plan');

   -- =============================================================================================
   -- 15-16. GRANDFATHERED: a tenant already on a deactivated plan keeps working.
   -- =============================================================================================
   select is(app.subscription_allows_write('18000000-0000-0000-0000-000000000001'), true,
     'the write gate still opens for a tenant whose enterprise plan was deactivated after it subscribed');
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
   select isnt(app.create_customer('person', 'T180 Grandfathered'), null,
     'BUSINESS: the employee of a grandfathered tenant still creates a customer');
   reset role;
   select set_config('request.jwt.claims', '', true);
   update public.subscription_plans set is_active = true;

   -- =============================================================================================
   -- 17-18. THE CURSOR moves forward through its one writer; a rewound cursor re-maps nothing.
   -- =============================================================================================
   select app.map_outcomes_to_conversions(100000);
   insert into public.leads (id, tenant_id, branch_id, department_id, lead_source_code, lead_status_code, title) values
     ('18000000-0000-0000-0000-0000000000d1','18000000-0000-0000-0000-000000000001','18000000-0000-0000-0000-0000000000b1',
      '18000000-0000-0000-0000-0000000000c1','google_ads_call','new','T180 call lead');
   select app.record_event('18000000-0000-0000-0000-000000000001', 'lead_qualified', 'lead',
     '18000000-0000-0000-0000-0000000000d1', null, null, null, 't180', null) is not null;
   -- The mapper runs in its own statement: a subquery in the same statement would read the cursor's old snapshot.
   select set_config('t180.mapped', app.map_outcomes_to_conversions(500)::text, true);
   select is(current_setting('t180.mapped') || '/'
               || ((select last_seq from public.integration_cursors where name = 'outcome_conversion_mapper')
                   = (select max(seq) from public.events where event_type_code = 'lead_qualified'))::text,
     '1/true', 'POSITIVE CONTROL: the mapper maps the qualified call lead once and moves its cursor forward to that event');
   update public.integration_cursors set last_seq = 0 where name = 'outcome_conversion_mapper';
   select is(app.map_outcomes_to_conversions(500)::text || '/'
               || (select count(*) from public.offline_conversions where lead_id = '18000000-0000-0000-0000-0000000000d1'),
     '0/1', 'REPLAY: with the cursor rewound to zero, a rerun maps nothing new -- one source event is one conversion');

   -- =============================================================================================
   -- 19-20. LANGUAGES on a customer: a deactivated language stays valid, an unknown one is refused.
   -- =============================================================================================
   update public.languages set is_active = false where code = 'fr';
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
   select isnt(app.create_customer('person', 'T180 French', p_preferred_language_code => 'fr'), null,
     'a deactivated language stays valid on a customer, as on the sibling reference tables');
   select throws_ok($$select app.create_customer('person', 'T180 Unknown', p_preferred_language_code => 'zz')$$,
     '23503', 'insert or update on table "customers" violates foreign key constraint "customers_preferred_language_code_fkey"',
     'INPUT: an unknown language code is refused by the foreign key');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is a5de730097515f7cc2a2f95dcbba070b9f4e4385.

2. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**75 of 78 recorded · 51 `; if so record Already Applied when its Git blob is aba8a1aa32fa7db61079cc70a2f3f0e454e2fabe, and otherwise stop and report. Otherwise make exactly these 6 edits (the freshness entry, coverage 75 of 78 and the subscription_plans, integration_cursors and languages rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-18 (**slice 57 — `role_permissions`, `permissions` and `roles` selected by Exposure 2, 2 and 2, coverage 72, 224 and 784, in one contract.** Coverage **69 → 72 of 78**. No finding: the role and permission matrix is fixed, platform-owned reference data that every member reads and no member writes, and every authority reader honours a deactivated role or permission. SPEC-313 records it with a pinning test and no migration, so the three rows are `AUDITED`. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-18 (**slice 58 — `subscription_plans`, `integration_cursors` and `languages` selected by Exposure 2, 1 and 0, coverage 866, 24 and 4, in one contract.** Coverage **72 → 75 of 78**. No finding: the plan list and the language list are platform-owned reference data that every member reads and no member writes, the conversion cursor is closed to every member and moved only forward by its one function, and every plan reader refuses an inactive plan. SPEC-314 records it with a pinning test and no migration, so the three rows are `AUDITED`. No other row changed.)

   Previously: 2026-11-18 (**slice 57 — `role_permissions`, `permissions` and `roles` selected by Exposure 2, 2 and 2, coverage 72, 224 and 784, in one contract.** Coverage **69 → 72 of 78**. No finding: the role and permission matrix is fixed, platform-owned reference data that every member reads and no member writes, and every authority reader honours a deactivated role or permission. SPEC-313 records it with a pinning test and no migration, so the three rows are `AUDITED`. No other row changed.)
   ```

   b) replace the line
   ```text
   **72 of 78 recorded · 48 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 6 `NOT-RECORDED`.**
   ```
   with
   ```text
   **75 of 78 recorded · 51 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 3 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 72 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 75 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `integration_cursors` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `integration_cursors` | **AUDITED** | ADVERSARIAL | `SPEC-314-plans-languages-and-the-conversion-cursor-are-written-by-no-member-and-an-inactive-plan-is-refused` | — | `180_plans_languages_and_conversion_cursor_test.sql` (20 assertions; AUTH, TENANT, DOOR, STATE, INPUT, REPLAY, PRIVILEGE and BUSINESS declared, CONCURRENCY and OBSERVABILITY N/A) proves that `anon`, `authenticated` and `orvion_integration` hold no privilege on the cursor and the `owner` at `aal2` is refused reading or moving it by the missing grant; that only `orvion_integration` holds EXECUTE on `app.map_outcomes_to_conversions` (not `anon`, `authenticated` or `service_role`); that a run maps a qualified lead and moves the cursor to the last qualified-lead event; and that a cursor rewound to 0 reruns without a second conversion. Mutants (SELECT or UPDATE granted to members, SELECT granted to `orvion_integration`, EXECUTE on the mapper granted to members, the mapper holding its cursor, the dedupe index dropped), each installed and restored md5-identical, are each killed. Tests 36, 51, 66 and 142 pass unchanged. **Swept and classified as non-defects:** no member role at any role or second factor reads, resets, inserts or deletes the cursor (no grant, and the `platform_only` policy is `false`); the mapper is not reachable over REST (404) and anonymous REST on the table is refused (401); a batch of 1, 0, -1 or null moves the cursor forward or holds it, never backwards, and a failing batch becomes a finding; a rewound or negative cursor reruns without a duplicate (unique `source_event_seq`); a null cursor is refused (not null). **Recorded positions:** the cursor is platform state, not tenant data; only `postgres` or `service_role` can set it ahead, delete it or truncate it, which stalls or skips the mapper, and the `service_role` blast radius is DC-15 (OPEN; PAR-5 FIXED by SPEC-207). 1 hosted cursor at 0, no source event and no open mapper finding on either hosted database. |
   ```

   e) replace the line
   ```text
   | `languages` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `languages` | **AUDITED** | ADVERSARIAL | `SPEC-314-plans-languages-and-the-conversion-cursor-are-written-by-no-member-and-an-inactive-plan-is-refused` | — | `180_plans_languages_and_conversion_cursor_test.sql` (20 assertions; AUTH, TENANT, DOOR, STATE, INPUT, REPLAY, PRIVILEGE and BUSINESS declared, CONCURRENCY and OBSERVABILITY N/A) proves that an `employee` at `aal1` and another tenant's `owner` at `aal2` each read every language; that the `owner` at `aal2` is refused adding a language by the missing grant; that `anon` and `orvion_integration` hold no privilege on it; that a deactivated language is still accepted on a new customer; and that an unknown language is refused by the foreign key. Mutants (languages hidden from members, INSERT granted to members, the customer foreign key dropped), each installed and restored md5-identical, are each killed. Test 18 passes unchanged. **Swept and classified as non-defects:** no member role at any role, tenant or second factor inserts, deactivates or deletes a language (no grant); the list has no tenant column; a language a customer uses cannot be deleted (FK) and a malformed code is refused (check); anonymous REST is refused (401). **Recorded positions:** the language list is platform-owned reference data every member reads, and only migrations write it; the customer foreign key checks that a language exists, not that it is active, as for `nationalities`, `countries` and `currencies`, so a deactivated language stays valid on new and existing customers (unlike catalog families, whose trigger checks `is_active`); whether these four reference lists should refuse an inactive value is carried to slice 17. 20 hosted languages, all active. |
   ```

   f) replace the line
   ```text
   | `subscription_plans` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `subscription_plans` | **AUDITED** | ADVERSARIAL | `SPEC-314-plans-languages-and-the-conversion-cursor-are-written-by-no-member-and-an-inactive-plan-is-refused` | — | `180_plans_languages_and_conversion_cursor_test.sql` (20 assertions; AUTH, TENANT, DOOR, STATE, INPUT, REPLAY, PRIVILEGE and BUSINESS declared, CONCURRENCY and OBSERVABILITY N/A) proves that an `employee` at `aal1` and another tenant's `owner` at `aal2` each read every plan; that the `owner` at `aal2` is refused changing a plan by the missing grant; that `anon` and `orvion_integration` hold no privilege on it and no member holds EXECUTE on `app.platform_activate_subscription` or `app.platform_issue_license_token`; that a deactivated plan is refused by `app.platform_activate_subscription`, by `app.platform_issue_license_token`, and at redemption of a token issued while it was active; that `app.provision_tenant` refuses a deactivated `enterprise` plan; and that a tenant already on a deactivated plan keeps writing (grandfathered), each after a positive control. Mutants (plans hidden from members, UPDATE granted to members, each of the three plan readers accepting an inactive plan, the write gate refusing a tenant on a deactivated plan), each installed and restored md5-identical, are each killed. Tests 35, 42, 43, 80, 131, 147 and 148 pass unchanged. **Swept and classified as non-defects:** no member role at any role, tenant or second factor inserts, deactivates or deletes a plan (no grant); the plan list has no tenant column, so there is nothing to scope; a plan with subscribers cannot be deleted (FK, ON DELETE RESTRICT); anonymous REST is refused (401). **Recorded positions:** the plan list is platform-owned reference data every member reads, and only migrations write it; deactivating a plan stops new activations, licence tokens and trials on it but leaves tenants already on it running (the write gate reads the subscription, not the plan); `app.provision_tenant` names `enterprise` in its text, so only a migration could rename that plan, and that migration would carry its own test; `service_role` grants differ by environment (PAR-5, DC-15). 3 hosted plans, all active. |
   ```

   The resulting file's Git blob is aba8a1aa32fa7db61079cc70a2f3f0e454e2fabe.

3. Check whether `_ORVION_CANONICAL/manifest.md` contains `Suite **180 files / 3302 assertions**`; if so record Already Applied when its Git blob is 666ace7871504c4374383d2bb221e81ea75e4acc, and otherwise stop and report. Otherwise make exactly this one edit (the suite figure), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: Last fully verified 2026-11-11. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 269 migrations** (latest `20261117120000`), ledger `ff29e9c5acf7d70b25862941f548cf97`, full-function-surface hash `f7427d65b5f8ee6d9f0a360ec5717b59` (350 functions) identical on both; structural-surface hash `20caafd5b6cde6e9002e209b0a3a3102` (3,177 objects) identical on both — **all ten surfaces identical** (`PAR-5` resolved by `SPEC-207`). Re-read live from Primary 2026-11-14; ledger **read FROM Primary** (GUARD-1). **80 client RPCs**. Suite **179 files / 3282 assertions** (Pass A = Pass B, 2026-11-11).
   ```
   with
   ```text
   Live state: Last fully verified 2026-11-11. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 269 migrations** (latest `20261117120000`), ledger `ff29e9c5acf7d70b25862941f548cf97`, full-function-surface hash `f7427d65b5f8ee6d9f0a360ec5717b59` (350 functions) identical on both; structural-surface hash `20caafd5b6cde6e9002e209b0a3a3102` (3,177 objects) identical on both — **all ten surfaces identical** (`PAR-5` resolved by `SPEC-207`). Re-read live from Primary 2026-11-14; ledger **read FROM Primary** (GUARD-1). **80 client RPCs**. Suite **180 files / 3302 assertions** (Pass A = Pass B, 2026-11-11).
   ```

   The resulting file's Git blob is 666ace7871504c4374383d2bb221e81ea75e4acc.

4. **Check** for a `Local certification` Execution Log entry. If absent:
   - Confirm that `supabase/tests` holds 180 files whose literal `plan(N)` values sum to 3302; if either differs, stop.
   - Regenerate `ai-map.json` and `repository-index.md` (stored LF) with the canonical generator, and confirm the API-contract generator's output is identical to `MASTER_API_CONTRACT.md`.
   - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once; the pre-commit Gate must admit it.
   - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, in the Complete commit: transition to Complete, tick the Acceptance Criteria and the Review Gate, clear `Active Change Request`, set `Last Completed` from Notes, leave `Next capability` and `Current Module` unchanged, and regenerate `ai-map.json` and `repository-index.md` LF.
   - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] Test 180 is the frozen bytes; `check: blob supabase/tests/180_plans_languages_and_conversion_cursor_test.sql a5de730097515f7cc2a2f95dcbba070b9f4e4385`
- [ ] The disposition record carries `subscription_plans`, `integration_cursors` and `languages` AUDITED / ADVERSARIAL and coverage 75 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md aba8a1aa32fa7db61079cc70a2f3f0e454e2fabe`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **180 files / 3302 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @8ff5563c118aa36a816f40a11375d85f62a16e88`
- [ ] Migration CI remains exact; `check: same .github/workflows/migration-ci.yml @8ff5563c118aa36a816f40a11375d85f62a16e88`
- [ ] The subscription tables' migration remains exact; `check: same supabase/migrations/202607042700_create_subscription_tables.sql @8ff5563c118aa36a816f40a11375d85f62a16e88`
- [ ] The geo reference tables' migration remains exact; `check: same supabase/migrations/202607042000_create_geo_reference_tables.sql @8ff5563c118aa36a816f40a11375d85f62a16e88`
- [ ] The conversion mapper's first migration remains exact; `check: same supabase/migrations/202607049300_outcome_conversion_mapper.sql @8ff5563c118aa36a816f40a11375d85f62a16e88`
- [ ] The conversion mapper's latest migration remains exact; `check: same supabase/migrations/20261114160000_a_conversion_source_event_is_mapped_even_when_it_commits_late.sql @8ff5563c118aa36a816f40a11375d85f62a16e88`
- [ ] The licence activation migration remains exact; `check: same supabase/migrations/202607054100_tenant_license_activation.sql @8ff5563c118aa36a816f40a11375d85f62a16e88`
- [ ] No file under `supabase/migrations/` changed and no database object was created, altered or dropped; Primary `vrvtsxexkiiiivlkdxzp` was not written and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] Mutants M1–M15 are each killed with installation and restoration proven.

## Execution Log

None.


### 2026-11-18 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was 8ff5563c118aa36a816f40a11375d85f62a16e88 and every source anchor matched there; Draft allocated as d48a3a3 and approved as 36490cf with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `supabase/tests/180_plans_languages_and_conversion_cursor_test.sql` edited exactly as the step states; blob a5de730097515f7cc2a2f95dcbba070b9f4e4385 (172 insertions, 0 deletions (created)).
- Step 3 Applied: `reports/master/MASTER_SURFACE_DISPOSITION.md` edited exactly as the step states; blob aba8a1aa32fa7db61079cc70a2f3f0e454e2fabe (8 insertions, 6 deletions).
- Step 4 Applied: `_ORVION_CANONICAL/manifest.md` edited exactly as the step states; blob 666ace7871504c4374383d2bb221e81ea75e4acc (1 insertions, 1 deletions).
- Step 5 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain.

## Verification Notes

None.


### 2026-11-18 — Gate 1 approval recorded

DELEGATED exact Gate1 under the owner's instructions of 2026-11-08 (class authorization for Batch 6 releases and standing approval of proposals ~10:20 Cairo; publish, promote and hosted deploy ~12:05 Cairo), 2026-11-11 (Batch 6 decisions 1-9 ~19:50 Cairo), 2026-11-12 (priority order waiving no gate ~12:20 Cairo), 2026-11-14 (one contract per product ~11:30 Cairo; no credential rotation ~12:30 Cairo; BP-32 approved in principle ~16:20 Cairo) and 2026-11-18 (slice 16 runs through in run mode 2, ~14:55 Cairo); Draft SHA-256 FD030E280BEFD311CD268021A4CE2152EC958E983096EB83B53A9E4BC50B5DDC, decision SHA-256 E06933A5C0F9036FC41566955A76B632F74DD7B7365EFBE1A8769B413A756964. No fabricated human future-digest approval. Record-only: no migration, no hosted write. Immediately before allocation the hash, the Draft blob f09060a6b6f0745b0218ecbef6c67bf2661505c0, all 2 source anchors, the baseline HEAD 8ff5563c118aa36a816f40a11375d85f62a16e88 against refreshed origin/main 8ff5563c118aa36a816f40a11375d85f62a16e88 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as d48a3a3. No implementation performed before this transition.


Verdict: Confirmed Complete

Independent current Git evidence: selected Draft FD030E280BEFD311CD268021A4CE2152EC958E983096EB83B53A9E4BC50B5DDC, allocated blob f09060a6b6f0745b0218ecbef6c67bf2661505c0, the three literal outputs (test 180, the disposition record, the manifest suite figure 180 files / 3302 assertions), regenerated discovery, the API contract identical to its generator, unchanged native evaluator, Migration CI and the plan, language, cursor and plan-reader migrations, and declared scope verified; no migration, no database object changed, Primary not written and Secondary never contacted. This original root owns fresh receipt 62dc9e5ed790952cbe825c883b58f66fd6dc073124b16e3aed1ff7fe10866af1, finishHead dddaf0077d804559f781683a5e345024cc77fca2, profiles DATABASE,REPOSITORY, in a native timed/watched Finish observed READY/END0. Native Complete/range/binder still own full receipt/criterion validation. No publication or hosted result asserted.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-314: Batch 6 Slice 58 — the plan list, the language list and the conversion cursor audited and recorded, no finding (subscription_plans, integration_cursors and languages AUDITED, 75 of 78); native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline 8ff5563c118aa36a816f40a11375d85f62a16e88 and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `f6ad392883bdd4482b15ccaf9aecb238296ff29e` |
| `_ORVION_CANONICAL/manifest.md` | `0e9d4558446e1d84d08b680a851281a843537ea7` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md and SPEC-303 at 8ff5563c118aa36a816f40a11375d85f62a16e88; the owner's instructions of 2026-11-08, 2026-11-16 and 2026-11-18 (recorded outside this repository). This is the one Draft for these surfaces, finalized after the adversarial review and the evidence refresh its Draft Assurance records; correctness remains native and independent.
