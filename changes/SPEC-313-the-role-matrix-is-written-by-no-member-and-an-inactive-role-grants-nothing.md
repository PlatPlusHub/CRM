# Change Request — SPEC-313

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 57 audits `role_permissions`, `permissions` and `roles` and records them, not repaired: nothing material was found, so one test pins what the slice measured and no test held, and the disposition record sets the three surfaces `AUDITED`.

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `897da8a`, on the live local catalog, ranks `role_permissions` (Exposure 2, coverage 72), `permissions` (2/224) and `roles` (2/784) next, all NOT-RECORDED. Under the owner's instructions of 2026-11-16, this slice's entry of 2026-11-18 grouped the selector's next three surfaces in one contract per product: the three are SELECT-only for `authenticated`, written only by migrations, and read together by every authority reader, so their probes are reads, refusals and deactivations, and each keeps its own probes, assertions and mutants. The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.** `roles` (9 seeded rows), `permissions` (77) and `role_permissions` (315 grants) are the role model: `app.has_permission`, `app.effective_permissions`, `app.eligible_lead_handlers`, `app.requires_mfa` and `app.assign_user_role` decide from them who may do what in every tenant. A member who could add a grant, lift a permission's plan gate or reactivate a role would raise its own authority; a reader that ignored a deactivated role or permission would keep granting what the product withdrew.
- **Measured at `897da8a`** on the local stack with committed probe fixtures (an owner at `aal1` and `aal2`, an employee, a trainee, a branch manager, another tenant's owner at `aal2`, `service_role`, anonymous REST, and `postgres` for integrity only), every axis held or is a recorded design position:
  - **Held:** every member write to the three is refused 42501 by the missing grant at every role, tenant and second factor (insert, re-point and delete a grant; insert, rename, deactivate, delete and lift the plan gate of a permission; insert, rename, deactivate, reactivate and delete a role); anonymous REST on all three 401 and `rpc/has_permission` 404; `anon` and `orvion_integration` hold no privilege on them; no role holds the platform authority `REVIEW_SUBSCRIPTION_PAYMENT`; a deactivated permission or role grants nothing through `app.has_permission`, `app.effective_permissions` or `app.eligible_lead_handlers`, a user grant does not win a deactivated permission back, a deactivated `owner` role turns off `app.requires_mfa`, and `app.assign_user_role` refuses an inactive role, each after a positive control.
  - **Positions:** every member of every tenant reads the whole matrix: a fixed, platform-owned role model, not tenant data (RBAC-2). RBAC-5 (`202607059800_capability_grants_are_per_user_not_only_per_role.sql`) superseded RBAC-2 for `MANAGE_PERMISSIONS` by adding per-user grants and denies in `user_permission_grants`; the three tables themselves stay SELECT-only and platform-owned. `app.plan_allows` fails open on an unknown code by design (`202607052500_plan_gating.sql`); `service_role` grants differ by environment (PAR-5 FIXED, DC-15 OPEN); `app.requires_mfa`, `app.provision_tenant` and `app.credit_alert_recipients` name role codes in their text.
  - **Reachable only as `postgres`:** a platform permission granted to a tenant role, or a role code renamed under the readers that name it. Only migrations run as `postgres`; tests 42 and 179 pin the platform permissions, and a renaming migration would carry its own test. Hosted Primary and Secondary each hold 9 roles, 77 permissions and 315 grants, none to `system_administrator` and none of a platform permission.
- **What is pinned where.** Test 10 pins the grant model and its SEC-1 ceiling, test 30 the plan gate, test 31 the employee-role deactivation of `CREATE_CUSTOMER`, test 42 `MANAGE_SUBSCRIPTION`, test 65 the eligible lead handlers and test 162 the role-grant writers. Test 179 adds only what the slice measured and no test held: the full matrix read at `aal1` and `aal2` in two tenants, the owner at `aal2` refused by the missing grant on each of the three, `anon` and `orvion_integration` without privilege, `REVIEW_SUBSCRIPTION_PAYMENT` held by no role, and each authority reader honouring a deactivated permission or role.
- **Earn it and worth it.** No repair is owed, so no migration: a record-only contract, the SPEC-303 shape. The register is unchanged (no finding).

## Risks

- **None to the database.** No migration, function, policy, grant or trigger changes; Primary `vrvtsxexkiiiivlkdxzp` is not written and Secondary `brplkqmbzffpxqgkkdzo` is never contacted. The DATABASE protocol of `-Finish` resets the local ORVION database, as every DATABASE Finish does.
- **A future change to the matrix grants, the read policy or an authority reader's `is_active` handling** now turns test 179 red where it changes what the slice measured; that is the purpose.
- **Gate 1 of this contract is DELEGATED** under the owner's instructions, recorded outside this repository and never as a human-typed digest:
  - class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo
  - slice 15 in run mode 2, with the slice's own grouping decision, 2026-11-18 ~11:24 Cairo

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-313-the-role-matrix-is-written-by-no-member-and-an-inactive-role-grants-nothing.md`
- `supabase/tests/179_the_role_matrix_is_written_by_no_member_and_an_inactive_role_or_permission_grants_nothing_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607041700_create_identity_and_access_tables.sql`
- `supabase/migrations/202607043700_provision_tenant_and_has_permission.sql`
- `supabase/migrations/202607043800_user_management_rpcs.sql`
- `supabase/migrations/202607044100_mfa_requirement_enforcement.sql`
- `supabase/migrations/202607052500_plan_gating.sql`
- `supabase/migrations/202607056800_an_overdue_lead_reaches_someone_who_can_work_it.sql`
- `supabase/migrations/202607058100_one_lead_has_one_current_handler.sql`
- `supabase/migrations/202607059800_capability_grants_are_per_user_not_only_per_role.sql`
- `supabase/migrations/202607060700_a_role_assignment_that_has_not_started_grants_nothing.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/30_plan_gating_test.sql`
- `supabase/tests/31_access_revocation_test.sql`
- `supabase/tests/42_subscription_lifecycle_test.sql`
- `supabase/tests/65_eligible_lead_handler_test.sql`
- `supabase/tests/162_a_role_grant_changes_only_by_revoke_and_assign_test.sql`
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
- `supabase/migrations/202607041700_create_identity_and_access_tables.sql` (`roles`, `permissions`, `role_permissions`); the authority readers' migrations `202607043700_provision_tenant_and_has_permission.sql`, `202607043800_user_management_rpcs.sql`, `202607044100_mfa_requirement_enforcement.sql`, `202607052500_plan_gating.sql`, `202607056800_an_overdue_lead_reaches_someone_who_can_work_it.sql`, `202607058100_one_lead_has_one_current_handler.sql`, `202607059800_capability_grants_are_per_user_not_only_per_role.sql` and `202607060700_a_role_assignment_that_has_not_started_grants_nothing.sql`
- `supabase/tests/10_grant_model_test.sql`, `30_plan_gating_test.sql`, `31_access_revocation_test.sql`, `42_subscription_lifecycle_test.sql`, `65_eligible_lead_handler_test.sql` and `162_a_role_grant_changes_only_by_revoke_and_assign_test.sql`
- `changes/SPEC-303-the-consent-record-audit.md` (the record-only shape)
- `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_GAP_REGISTER.md` (RBAC-2, RBAC-5, PAR-5, DC-15); `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11

## Runtime Checkpoint

Resume Step: 1
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

Pass 1 Design: record-only. Test 179 pins that `REVIEW_SUBSCRIPTION_PAYMENT` exists and no role holds it; that `anon` and `orvion_integration` hold no privilege on the three tables; that a `trainee` at `aal1` and another tenant's `owner` at `aal2` each read the whole matrix; that the owner at `aal2` is refused by the missing grant when it adds a grant, lifts a permission's plan gate or deactivates a role; and, each after a positive control, that a deactivated `CLOSE_LEAD` is gone from `app.has_permission`, `app.effective_permissions` and `app.eligible_lead_handlers` and is not won back by a user grant, that a deactivated `employee` role drops the same three, that a deactivated `owner` role turns off `app.requires_mfa` and `MANAGE_PERMISSIONS`, and that `app.assign_user_role` refuses an inactive role. The disposition record sets the three surfaces `AUDITED` / `ADVERSARIAL` with coverage 72 of 78; the manifest suite figure moves to 179 files / 3282 assertions.

Pass 2 Adversarial Review: each part was challenged on the prototype. Repeating the grant ceiling, the plan gate or the employee-role deactivation in test 179 was rejected: they were re-measured, held, and are pinned by tests 10, 30 and 31. Hiding the matrix from members was rejected: it is the product's role model, read by the client and by every member's own authority check (RBAC-2). Citing RBAC-2 alone was rejected: the register marks it superseded by RBAC-5 for `MANAGE_PERMISSIONS`, so the records and the test header name RBAC-5's per-user grants and denies in `user_permission_grants`, which leave these three tables SELECT-only. A CHECK or trigger against a platform permission in the matrix was rejected: only migrations write it, and tests 42 and 179 pin `MANAGE_SUBSCRIPTION` and `REVIEW_SUBSCRIPTION_PAYMENT`. Failing `app.plan_allows` closed was rejected: fail-open is the recorded design of `202607052500_plan_gating.sql`. Granting or revoking `service_role` privileges was rejected: PAR-5 and DC-15 own that role's grants, which differ by environment. A test with `is()` assertions alone was rejected: Check 24 needs a negative assertion, and a grant-only mutant is killed only by the exact `permission denied for table` message, so `throws_ok` carries each refusal. A gap-register row was rejected: there is no finding. Copying the selector's next target into the manifest was rejected (SPEC-270; SPEC-278's cancellation).

Pass 3 Evidence Refresh: 2026-11-18. Re-measured on byte-identical files in a disposable clone of `897da8a` with the project-local CLI 3.0.0: the clean reset, test 179 alone (14/14), the probes as the causal negative, the sixteen mutants each installed and restored to the unmutated shape, the generators, declared scope, `git diff --check` and repository consistency; pgTAP Pass A and B, the three declared HTTP suites and smoke ran on the same bytes before the freeze. Primary and Secondary were read read-only for the hosted rows.

Selected Version: SPEC-313; selected: record-only (SPEC-303 shape): one test pinning what the slice measured and no test held, the three disposition rows AUDITED with coverage 72 of 78, and the suite figure; no migration, no register row, no hosted write; proven on byte-identical files by the full local protocol, sixteen killed mutants and the probes

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Test 179 | `supabase/tests` | WRITE | SHA-256 `c47fd0aab8e0259e4e8637fc9d14b0989482d09eaa96c57a7b04fa9202f80323`, md5 `6e613b0c39dd2dc5649856952545a96c`, 11802 bytes, LF, ASCII, `plan(14)`: 14/14 on the prototype. |
| The authority readers, policies and grants | `app.has_permission`; `app.effective_permissions`; `app.eligible_lead_handlers`; `app.requires_mfa`; `app.assign_user_role`; `read_all_authenticated` on the three tables; the table grants | UNAFFECTED | No body, grant, policy or trigger changes; the five readers' definitions read `f870c544` on the prototype's CRLF migrations (`89d97bdc` from LF, `634d0fa9` with carriage returns stripped), the three tables' policies `c5f60bd6`, RLS on all three true, `authenticated` and `orvion_integration` grants `addcce29`, `REVIEW_SUBSCRIPTION_PAYMENT` grants 0, before and after the mutants. |
| Other tests and the suite | the full pgTAP suite; the HTTP suites; smoke | VERIFY | Pass A `Files=179, Tests=3282`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 179/3282, PASS; smoke `ALL CHECKS PASSED` (78 tables, 71/626 catalog). 179 files whose literal `plan(N)` values sum to 3282. |
| The surfaces recorded | `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22 and 24 | WRITE | Test 179's `-- ATTACK-CLASSES:` line declares the ten classes with CONCURRENCY, REPLAY, BUSINESS and OBSERVABILITY `=N/A` and carries negative assertions, so Check 24 admits `ADVERSARIAL`. Coverage 72: 48 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 6 `NOT-RECORDED`; all 72 `ADVERSARIAL`. |
| Measured state that moves | manifest suite figure; `ai-map.json` and `repository-index.md` | WRITE | 178 → 179 files and 3268 → 3282 assertions (Check 15). Migrations 269 and tables 78 do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 4 names `Current Module` and `Next capability` only to leave them unchanged; each line keeps its ratified text and pin. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3) | VERIFY | No RPC changes; the generator's output is identical to the stored file and to the baseline's (270 lines, 0 differ). It is in Write Scope because Check L3 regenerates it. |
| The gap register | `MASTER_GAP_REGISTER.md` | UNAFFECTED | No finding; positions are recorded in the disposition rows, citing RBAC-2 as amended by RBAC-5. |
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

Existing Mechanism: none of the controls that govern these records is added or changed: the missing INSERT, UPDATE and DELETE grants for every member role on the three tables, no privilege for `anon` and `orvion_integration`, the `read_all_authenticated` policies, and the `is_active` handling inside `app.has_permission`, `app.effective_permissions`, `app.eligible_lead_handlers`, `app.requires_mfa` and `app.assign_user_role`.

Added Property: the measured behaviour is executable, so the suite turns red when it changes: the matrix stays readable in full by every member of every tenant and writable by none; `anon` and `orvion_integration` stay without privilege; the platform authority stays out of the tenant role matrix; a deactivated permission or role stays without effect in every authority reader.

Causal Negative: the probes (the slice's records, before any test existed, and again on the frozen bytes) measured the same behaviour; each mutant below, installed, turns its assertions red.

Positive Test Design: two active tenants on the `enterprise` plan, an `owner`, an `employee`, a `trainee` and a `branch_manager` in the first and an `owner` in the second. Positive controls: both members read the full matrix totals taken before the role switch; the employee holds `CLOSE_LEAD` and is, with the branch manager, an eligible lead handler; the owner requires a second factor and holds `MANAGE_PERMISSIONS`.

Negative Test Design:
- **Auth and privilege:** `anon` and `orvion_integration` hold none of the seven table privileges on the three tables; the owner at `aal2` is refused 42501 with `permission denied for table role_permissions`, `permissions` and `roles` on a grant insert, a plan-gate lift and a role deactivation.
- **State:** a deactivated `CLOSE_LEAD` gives `false/0/` across the three readers and a user grant does not win it back; a deactivated `employee` role gives `false/1/…14/0`; a deactivated `owner` role gives `false/false`; `app.assign_user_role` of the inactive `senior_employee` is refused P0001 `unknown or inactive role: senior_employee`.
- **Tenant and door:** another tenant's owner reads the same matrix totals and nothing more; no role holds `REVIEW_SUBSCRIPTION_PAYMENT`.

Non-Empty Population Obligation: the fixture holds two tenants, five users, five role grants, two subscriptions, one branch and one department, and the seeded 9 roles, 77 permissions and 315 grants, before the first assertion; each refusal is asserted by exact SQLSTATE and message and each read by its exact totals or ids.

Mutation Obligation: each mutant was installed on the prototype stack, proven installed by the moved shape (`fn`, `pol`, `gr`, `rsp`), run against test 179, then restored; the shape was proven restored to the unmutated `f870c544`, `c5f60bd6`, `addcce29`, 0 with 0 failures unmutated.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| M1 | the matrix hidden from members | 179 assertions 3 and 4 |
| M2 | permissions hidden from members | 179 assertions 3 and 4 |
| M3 | roles hidden from members | 179 assertions 3 and 4 |
| M4 | `app.has_permission` ignores an inactive permission | 179 assertions 9 and 10 |
| M5 | `app.has_permission` ignores an inactive role | 179 assertions 11 and 14 |
| M6 | `app.effective_permissions` lists an inactive permission | 179 assertion 9 |
| M7 | `app.effective_permissions` ignores an inactive role | 179 assertion 11 |
| M8 | lead handlers ignore an inactive permission | 179 assertion 9 |
| M9 | lead handlers ignore an inactive role | 179 assertion 11 |
| M10 | `app.requires_mfa` ignores an inactive role | 179 assertion 14 |
| M11 | `app.assign_user_role` accepts an inactive role | 179 assertion 13 |
| M12 | members granted INSERT on the matrix | 179 assertion 5 |
| M13 | members granted UPDATE on permissions | 179 assertion 6 |
| M14 | members granted UPDATE on roles | 179 assertion 7 |
| M15 | `orvion_integration` granted SELECT on roles | 179 assertion 2 |
| M16 | the `owner` role holds `REVIEW_SUBSCRIPTION_PAYMENT` | 179 assertion 1 |

Post-Implementation Proof Obligation: all of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI: the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke; the generated artifacts and repository consistency.

## Implementation Steps

1. Check whether `supabase/tests/179_the_role_matrix_is_written_by_no_member_and_an_inactive_role_or_permission_grants_nothing_test.sql` contains `plan(14)`; if so record Already Applied when its Git blob is 37c661d051d0184c8a25cacddd843a7b0e7db219, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 179, 14 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 57 (role_permissions, permissions, roles) --
   -- the role and permission matrix is fixed, platform-owned product reference data (RBAC-2; per-user
   -- grants and denies are RBAC-5's user_permission_grants, not these tables): every member of every
   -- tenant reads all of it, no member writes any of it (an owner at aal2 is refused by the missing grant),
   -- anon and orvion_integration hold no privilege on it, and no role holds the platform authority
   -- REVIEW_SUBSCRIPTION_PAYMENT (test 42 pins MANAGE_SUBSCRIPTION). The authority readers
   -- honour is_active: a deactivated permission is gone from app.has_permission, app.effective_permissions
   -- and app.eligible_lead_handlers and a user grant does not win it back; a deactivated role drops the
   -- same three and app.requires_mfa; app.assign_user_role refuses an inactive role. Each is proven after
   -- a positive control. No migration: each door held when probed, so this file pins what was measured and
   -- was not yet pinned (tests 10, 30, 31 and 42 keep the grant ceiling, the plan gate, the employee-role
   -- deactivation of CREATE_CUSTOMER and MANAGE_SUBSCRIPTION).
   -- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
   --   CONCURRENCY, REPLAY=N/A -- only migrations write the three tables; no member or function path
   --     writes them, so there is no race or replay to attack.
   --   BUSINESS=N/A -- the matrix carries no amount or limit; the plan gate is test 30's.
   --   OBSERVABILITY=N/A -- a migration's change to the matrix records no event by design; the
   --     member-facing writes are refused before any row or event exists.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(14);

   select set_config('t179.totals',
     (select count(*) from public.role_permissions)::text || '/' || (select count(*) from public.permissions)
       || '/' || (select count(*) from public.roles), true);

   insert into auth.users (id, email) values
     ('17900000-0000-0000-0000-0000000000a1','owner@c179.test'),
     ('17900000-0000-0000-0000-0000000000a2','employee@c179.test'),
     ('17900000-0000-0000-0000-0000000000a3','trainee@c179.test'),
     ('17900000-0000-0000-0000-0000000000a4','manager@c179.test'),
     ('17900000-0000-0000-0000-0000000000a5','other@c179.test');
   insert into public.tenants (id, name, slug, status) values
     ('17900000-0000-0000-0000-000000000001','Matrix Travel','matrix-travel-179','active'),
     ('17900000-0000-0000-0000-000000000002','Other Travel','other-travel-179','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code, starts_at)
   select v.t, sp.id, 'active', now() - interval '2 days' from public.subscription_plans sp,
     (values ('17900000-0000-0000-0000-000000000001'::uuid), ('17900000-0000-0000-0000-000000000002')) v(t)
   where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('17900000-0000-0000-0000-0000000000b1','17900000-0000-0000-0000-000000000001','Giza','giza-179');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('17900000-0000-0000-0000-0000000000c1','17900000-0000-0000-0000-000000000001','17900000-0000-0000-0000-0000000000b1','sales','Giza Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('17900000-0000-0000-0000-000000000011','17900000-0000-0000-0000-000000000001','Owner','owner@c179.test',true,'17900000-0000-0000-0000-0000000000a1'),
     ('17900000-0000-0000-0000-000000000012','17900000-0000-0000-0000-000000000001','Employee','employee@c179.test',true,'17900000-0000-0000-0000-0000000000a2'),
     ('17900000-0000-0000-0000-000000000013','17900000-0000-0000-0000-000000000001','Trainee','trainee@c179.test',true,'17900000-0000-0000-0000-0000000000a3'),
     ('17900000-0000-0000-0000-000000000014','17900000-0000-0000-0000-000000000001','Manager','manager@c179.test',true,'17900000-0000-0000-0000-0000000000a4'),
     ('17900000-0000-0000-0000-000000000015','17900000-0000-0000-0000-000000000002','Other','other@c179.test',true,'17900000-0000-0000-0000-0000000000a5');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
   select '17900000-0000-0000-0000-000000000001', u, '17900000-0000-0000-0000-0000000000b1', '17900000-0000-0000-0000-0000000000c1', true
   from unnest(array['17900000-0000-0000-0000-000000000012','17900000-0000-0000-0000-000000000013','17900000-0000-0000-0000-000000000014']::uuid[]) u;
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select v.t, v.u, r.id, 'tenant'
   from (values
     ('17900000-0000-0000-0000-000000000001'::uuid, '17900000-0000-0000-0000-000000000011'::uuid, 'owner'),
     ('17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-000000000012', 'employee'),
     ('17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-000000000013', 'trainee'),
     ('17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-000000000014', 'branch_manager'),
     ('17900000-0000-0000-0000-000000000002', '17900000-0000-0000-0000-000000000015', 'owner')) v(t, u, c)
   join public.roles r on r.code = v.c;

   select is(
     (select count(*) from public.permissions where key = 'REVIEW_SUBSCRIPTION_PAYMENT')::text || '/'
       || (select count(*) from public.role_permissions rp join public.permissions p on p.id = rp.permission_id
           where p.key = 'REVIEW_SUBSCRIPTION_PAYMENT'),
     '1/0', 'REVIEW_SUBSCRIPTION_PAYMENT exists and no role holds it: platform authority stays out of the tenant role matrix');
   select is(
     (select count(*)::int from unnest(array['anon','orvion_integration']) r,
        unnest(array['public.role_permissions','public.permissions','public.roles']) t,
        unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
      where has_table_privilege(r, t, p)),
     0, 'anon and orvion_integration hold no privilege of any kind on the three tables');

   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a3","aal":"aal1"}', true);
   select is(
     (select count(*) from public.role_permissions)::text || '/' || (select count(*) from public.permissions)
       || '/' || (select count(*) from public.roles),
     current_setting('t179.totals'),
     'a trainee at aal1 reads the whole role and permission matrix: product reference data, not tenant data');

   select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a5","aal":"aal2"}', true);
   select is(
     (select count(*) from public.role_permissions)::text || '/' || (select count(*) from public.permissions)
       || '/' || (select count(*) from public.roles),
     current_setting('t179.totals'),
     'another tenant''s owner reads the same whole matrix');

   select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   select throws_ok(
     $$insert into public.role_permissions (role_id, permission_id)
       select (select id from public.roles where code = 'trainee'), id from public.permissions where key = 'MANAGE_PERMISSIONS'$$,
     '42501', 'permission denied for table role_permissions',
     'the owner at aal2 cannot grant a role a permission: no member holds INSERT on the matrix');
   select throws_ok(
     $$update public.permissions set required_feature_code = null where key = 'CREATE_BOOKING'$$,
     '42501', 'permission denied for table permissions',
     'the owner at aal2 cannot lift a permission''s plan gate: no member holds UPDATE on permissions');
   select throws_ok(
     $$update public.roles set is_active = false where code = 'trainee'$$,
     '42501', 'permission denied for table roles',
     'the owner at aal2 cannot deactivate a role: no member holds UPDATE on roles');

   select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
   select is(
     app.has_permission('CLOSE_LEAD')::text || '/' || (select count(*) from app.effective_permissions() where permission_key = 'CLOSE_LEAD')
       || '/' || coalesce((select string_agg(h::text, ',' order by h) from app.eligible_lead_handlers(
         '17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-0000000000b1', '17900000-0000-0000-0000-0000000000c1') h), ''),
     'true/1/17900000-0000-0000-0000-000000000012,17900000-0000-0000-0000-000000000014',
     'control: the employee holds CLOSE_LEAD by its role and is, with the branch manager, an eligible lead handler');

   reset role;
   update public.permissions set is_active = false where key = 'CLOSE_LEAD';
   set local role authenticated;
   select is(
     app.has_permission('CLOSE_LEAD')::text || '/' || (select count(*) from app.effective_permissions() where permission_key = 'CLOSE_LEAD')
       || '/' || coalesce((select string_agg(h::text, ',' order by h) from app.eligible_lead_handlers(
         '17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-0000000000b1', '17900000-0000-0000-0000-0000000000c1') h), ''),
     'false/0/',
     'a deactivated permission is gone from has_permission, effective_permissions and the lead handler pool');

   reset role;
   -- the grant guard asks who grants: the tenant's owner at aal2, who holds MANAGE_PERMISSIONS
   select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
   select '17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-000000000012', id, 'grant'
   from public.permissions where key = 'CLOSE_LEAD';
   select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
   set local role authenticated;
   select is(app.has_permission('CLOSE_LEAD'), false,
     'a user grant does not win back a deactivated permission');

   reset role;
   delete from public.user_permission_grants where user_id = '17900000-0000-0000-0000-000000000012';
   update public.permissions set is_active = true where key = 'CLOSE_LEAD';
   update public.roles set is_active = false where code = 'employee';
   set local role authenticated;
   select is(
     app.has_permission('CLOSE_LEAD')::text || '/' || (select count(*) from app.effective_permissions() where permission_key = 'CLOSE_LEAD')
       || '/' || coalesce((select string_agg(h::text, ',' order by h) from app.eligible_lead_handlers(
         '17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-0000000000b1', '17900000-0000-0000-0000-0000000000c1') h), '') || '/' || (select count(*) from app.effective_permissions() where from_role),
     'false/1/17900000-0000-0000-0000-000000000014/0',
     'a deactivated role grants nothing: no CLOSE_LEAD, no permission from the role, and only the branch manager stays a handler');

   reset role;
   update public.roles set is_active = true where code = 'employee';
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   select is(app.requires_mfa()::text || '/' || app.has_permission('MANAGE_PERMISSIONS'), 'true/true',
     'control: the owner requires MFA and holds MANAGE_PERMISSIONS');

   reset role;
   update public.roles set is_active = false where code = 'senior_employee';
   set local role authenticated;
   select throws_ok(
     $$select app.assign_user_role('17900000-0000-0000-0000-000000000013', 'senior_employee')$$,
     'P0001', 'unknown or inactive role: senior_employee',
     'the owner at aal2 cannot assign a deactivated role');

   reset role;
   update public.roles set is_active = false where code = 'owner';
   set local role authenticated;
   select is(app.requires_mfa()::text || '/' || app.has_permission('MANAGE_PERMISSIONS'), 'false/false',
     'a deactivated owner role neither requires MFA nor grants MANAGE_PERMISSIONS: the readers agree');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 37c661d051d0184c8a25cacddd843a7b0e7db219.

2. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**72 of 78 recorded · 48 `; if so record Already Applied when its Git blob is f6ad392883bdd4482b15ccaf9aecb238296ff29e, and otherwise stop and report. Otherwise make exactly these 5 edits (the freshness entry, coverage 72 of 78 and the role_permissions, permissions and roles rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-17 (**slice 56 — `catalog_types`, `feature_entitlements` and `usage_counters` selected by Exposure 2, 2 and 2, coverage 8, 10 and 16, in one contract.** Coverage **66 → 69 of 78**. No finding: every member reads the whole price list and catalog, a meter is read only inside its tenant, and no member writes any of the three. SPEC-312 records it with a pinning test and no migration, so the three rows are `AUDITED`. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-18 (**slice 57 — `role_permissions`, `permissions` and `roles` selected by Exposure 2, 2 and 2, coverage 72, 224 and 784, in one contract.** Coverage **69 → 72 of 78**. No finding: the role and permission matrix is fixed, platform-owned reference data that every member reads and no member writes, and every authority reader honours a deactivated role or permission. SPEC-313 records it with a pinning test and no migration, so the three rows are `AUDITED`. No other row changed.)

   Previously: 2026-11-17 (**slice 56 — `catalog_types`, `feature_entitlements` and `usage_counters` selected by Exposure 2, 2 and 2, coverage 8, 10 and 16, in one contract.** Coverage **66 → 69 of 78**. No finding: every member reads the whole price list and catalog, a meter is read only inside its tenant, and no member writes any of the three. SPEC-312 records it with a pinning test and no migration, so the three rows are `AUDITED`. No other row changed.)
   ```

   b) replace the line
   ```text
   **69 of 78 recorded · 45 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 9 `NOT-RECORDED`.**
   ```
   with
   ```text
   **72 of 78 recorded · 48 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 6 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 69 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 72 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `permissions` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `permissions` | **AUDITED** | ADVERSARIAL | `SPEC-313-the-role-matrix-is-written-by-no-member-and-an-inactive-role-grants-nothing` | — | `179_the_role_matrix_is_written_by_no_member_and_an_inactive_role_or_permission_grants_nothing_test.sql` (14 assertions; AUTH, TENANT, DOOR, STATE, INPUT and PRIVILEGE declared, the rest N/A) proves that every member in two tenants reads every permission; that the `owner` at `aal2` cannot change a permission (missing grant); and that a deactivated permission grants nothing through `app.has_permission`, `app.effective_permissions` or `app.eligible_lead_handlers`, and is not won back by a user grant, each after a positive control. Mutants (permissions hidden from members, each of the three readers ignoring an inactive permission, UPDATE granted to members), each installed and restored md5-identical, are each killed. Tests 10, 30, 31 and 65 pass unchanged. **Swept and classified as non-defects:** no member role inserts, renames, deactivates, deletes or lifts the plan gate of a permission (no grant); an unknown `required_feature_code` or `action_kind` is refused by its check; a permission a role holds cannot be deleted (FK); a plan-gated permission is off when its feature is off for the plan (test 30); `app.has_permission` is not reachable anonymously (404) and anonymous REST on the table is refused (401). **Recorded positions:** the permission list is product reference data every member reads (RBAC-2, RBAC-5); `app.plan_allows` fails open on an unknown code by design (202607052500); only migrations write the rows. 77 hosted permissions. |
   ```

   e) replace the lines
   ```text
   | `role_permissions` | NOT-RECORDED | — | — | — | — |
   | `roles` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `role_permissions` | **AUDITED** | ADVERSARIAL | `SPEC-313-the-role-matrix-is-written-by-no-member-and-an-inactive-role-grants-nothing` | — | `179_the_role_matrix_is_written_by_no_member_and_an_inactive_role_or_permission_grants_nothing_test.sql` (14 assertions; AUTH, TENANT, DOOR, STATE, INPUT and PRIVILEGE declared, the rest N/A) proves that a `trainee` at `aal1` and another tenant's `owner` at `aal2` each read the whole matrix; that the `owner` at `aal2` is refused adding a grant to the matrix by the missing grant, not by a policy; that `anon` and `orvion_integration` hold no privilege on it; and that no role holds the platform authority `REVIEW_SUBSCRIPTION_PAYMENT`. Mutants (the matrix hidden from members, INSERT granted to members, the platform authority given to `owner`), each installed and restored md5-identical, are each killed. Tests 10, 42 and 65 pass unchanged. **Swept and classified as non-defects:** no member role at any role, tenant or second factor inserts, deletes or re-points a grant (no grant); the matrix has no tenant column, so there is nothing to scope; a role or permission still held in the matrix cannot be deleted (FK, ON DELETE RESTRICT) and a pair cannot be granted twice (unique); anonymous REST is refused (401). **Recorded positions:** the matrix is a fixed, platform-owned role model, not tenant data (RBAC-2; RBAC-5 added per-user grants and denies in `user_permission_grants`, not here), so every member reads all of it; only migrations write it, and a migration could grant a platform permission to a tenant role, which tests 42 and 179 pin for `MANAGE_SUBSCRIPTION` and `REVIEW_SUBSCRIPTION_PAYMENT`; `service_role` grants differ by environment (PAR-5, DC-15). 315 hosted grants, none to `system_administrator` and none of a platform permission. |
   | `roles` | **AUDITED** | ADVERSARIAL | `SPEC-313-the-role-matrix-is-written-by-no-member-and-an-inactive-role-grants-nothing` | — | `179_the_role_matrix_is_written_by_no_member_and_an_inactive_role_or_permission_grants_nothing_test.sql` (14 assertions; AUTH, TENANT, DOOR, STATE, INPUT and PRIVILEGE declared, the rest N/A) proves that every member in two tenants reads every role; that the `owner` at `aal2` cannot change a role (missing grant); that a deactivated role grants nothing through `app.has_permission`, `app.effective_permissions` or `app.eligible_lead_handlers`; that a deactivated `owner` role turns off both `app.requires_mfa` and `MANAGE_PERMISSIONS`; and that `app.assign_user_role` refuses an inactive role, each after a positive control. Mutants (roles hidden from members, each of the four readers ignoring an inactive role, `app.assign_user_role` accepting one, UPDATE granted to members, SELECT granted to `orvion_integration`), each installed and restored md5-identical, are each killed. Tests 10, 31 and 162 pass unchanged. **Swept and classified as non-defects:** no member role inserts, renames, deactivates, reactivates or deletes a role, in its own tenant or another (no grant); a duplicate role code is refused (unique); a role that holds grants cannot be deleted (FK); anonymous REST is refused (401). **Recorded positions:** the nine roles are a fixed, platform-owned role model every member reads (RBAC-2, RBAC-5); `app.requires_mfa` (`owner`, `ceo`, `system_administrator`), `app.provision_tenant` and `app.credit_alert_recipients` (`owner`) name role codes in their text, so only a migration could rename one, and that migration would carry its own test; only migrations write the rows. 9 hosted roles. |
   ```

   The resulting file's Git blob is f6ad392883bdd4482b15ccaf9aecb238296ff29e.

3. Check whether `_ORVION_CANONICAL/manifest.md` contains `Suite **179 files / 3282 assertions**`; if so record Already Applied when its Git blob is 3c80c5614ea81d0d89741e3aeffa964b60431796, and otherwise stop and report. Otherwise make exactly this one edit (the suite figure), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: Last fully verified 2026-11-11. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 269 migrations** (latest `20261117120000`), ledger `ff29e9c5acf7d70b25862941f548cf97`, full-function-surface hash `f7427d65b5f8ee6d9f0a360ec5717b59` (350 functions) identical on both; structural-surface hash `20caafd5b6cde6e9002e209b0a3a3102` (3,177 objects) identical on both — **all ten surfaces identical** (`PAR-5` resolved by `SPEC-207`). Re-read live from Primary 2026-11-14; ledger **read FROM Primary** (GUARD-1). **80 client RPCs**. Suite **178 files / 3268 assertions** (Pass A = Pass B, 2026-11-11).
   ```
   with
   ```text
   Live state: Last fully verified 2026-11-11. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 269 migrations** (latest `20261117120000`), ledger `ff29e9c5acf7d70b25862941f548cf97`, full-function-surface hash `f7427d65b5f8ee6d9f0a360ec5717b59` (350 functions) identical on both; structural-surface hash `20caafd5b6cde6e9002e209b0a3a3102` (3,177 objects) identical on both — **all ten surfaces identical** (`PAR-5` resolved by `SPEC-207`). Re-read live from Primary 2026-11-14; ledger **read FROM Primary** (GUARD-1). **80 client RPCs**. Suite **179 files / 3282 assertions** (Pass A = Pass B, 2026-11-11).
   ```

   The resulting file's Git blob is 3c80c5614ea81d0d89741e3aeffa964b60431796.

4. **Check** for a `Local certification` Execution Log entry. If absent:
   - Confirm that `supabase/tests` holds 179 files whose literal `plan(N)` values sum to 3282; if either differs, stop.
   - Regenerate `ai-map.json` and `repository-index.md` (stored LF) with the canonical generator, and confirm the API-contract generator's output is identical to `MASTER_API_CONTRACT.md`.
   - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once; the pre-commit Gate must admit it.
   - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, in the Complete commit: transition to Complete, tick the Acceptance Criteria and the Review Gate, clear `Active Change Request`, set `Last Completed` from Notes, leave `Next capability` and `Current Module` unchanged, and regenerate `ai-map.json` and `repository-index.md` LF.
   - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] Test 179 is the frozen bytes; `check: blob supabase/tests/179_the_role_matrix_is_written_by_no_member_and_an_inactive_role_or_permission_grants_nothing_test.sql 37c661d051d0184c8a25cacddd843a7b0e7db219`
- [ ] The disposition record carries `role_permissions`, `permissions` and `roles` AUDITED / ADVERSARIAL and coverage 72 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md f6ad392883bdd4482b15ccaf9aecb238296ff29e`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **179 files / 3282 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @897da8a1042002ea04f719340bffa97363a202a0`
- [ ] Migration CI remains exact; `check: same .github/workflows/migration-ci.yml @897da8a1042002ea04f719340bffa97363a202a0`
- [ ] The identity and access tables' migration remains exact; `check: same supabase/migrations/202607041700_create_identity_and_access_tables.sql @897da8a1042002ea04f719340bffa97363a202a0`
- [ ] The MFA requirement migration remains exact; `check: same supabase/migrations/202607044100_mfa_requirement_enforcement.sql @897da8a1042002ea04f719340bffa97363a202a0`
- [ ] The per-user grants migration remains exact; `check: same supabase/migrations/202607059800_capability_grants_are_per_user_not_only_per_role.sql @897da8a1042002ea04f719340bffa97363a202a0`
- [ ] The role-assignment start migration remains exact; `check: same supabase/migrations/202607060700_a_role_assignment_that_has_not_started_grants_nothing.sql @897da8a1042002ea04f719340bffa97363a202a0`
- [ ] No file under `supabase/migrations/` changed and no database object was created, altered or dropped; Primary `vrvtsxexkiiiivlkdxzp` was not written and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] Mutants M1–M16 are each killed with installation and restoration proven.

## Execution Log

None.

## Verification Notes

None.


### 2026-11-18 — Gate 1 approval recorded

DELEGATED exact Gate1 under the owner's instructions of 2026-11-08 (class authorization for Batch 6 releases and standing approval of proposals ~10:20 Cairo; publish, promote and hosted deploy ~12:05 Cairo), 2026-11-11 (Batch 6 decisions 1-9 ~19:50 Cairo), 2026-11-12 (priority order waiving no gate ~12:20 Cairo), 2026-11-14 (one contract per product ~11:30 Cairo; no credential rotation ~12:30 Cairo; BP-32 approved in principle ~16:20 Cairo) and 2026-11-18 (slice 15 runs through in run mode 2, ~11:24 Cairo); Draft SHA-256 B74E7048A9CA8EAD99F158911D513CE01C63724BE7E786E341F099C25B9F9184, decision SHA-256 41FE324EEB1874D73ACCEB87E85ECD524849B88B5D1D89F0B252EFA048288BF9. No fabricated human future-digest approval. Record-only: no migration, no hosted write. Immediately before allocation the hash, the Draft blob f84cc97d2aee260d4a7184642b4b90a9b6d21041, all 2 source anchors, the baseline HEAD 897da8a1042002ea04f719340bffa97363a202a0 against refreshed origin/main 897da8a1042002ea04f719340bffa97363a202a0 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 61c49ae. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-313: Batch 6 Slice 57 — the role and permission matrix audited and recorded, no finding (role_permissions, permissions and roles AUDITED, 72 of 78); native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline 897da8a1042002ea04f719340bffa97363a202a0 and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `f386ccb9c4168c88789523771b773eef327928d3` |
| `_ORVION_CANONICAL/manifest.md` | `94d6487e382d78072a5e01ae1bf7e00fed1dbdb0` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md and SPEC-303 at 897da8a1042002ea04f719340bffa97363a202a0; the owner's instructions of 2026-11-08, 2026-11-16 and 2026-11-18 (recorded outside this repository). This is the one Draft for these surfaces, finalized after the adversarial review and the evidence refresh its Draft Assurance records; correctness remains native and independent.
