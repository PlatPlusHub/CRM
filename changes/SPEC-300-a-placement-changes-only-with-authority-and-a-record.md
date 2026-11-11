# Change Request — SPEC-300

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 45 makes a branch placement change only with the authority its RPC charges, records every placement change on every door, and makes a placement's department belong to its branch and its end follow its start (USR-3 for `user_branch_assignments`, UBA-1, UBA-3, UBA-5).

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `90a3a72`, on the live local catalog, ranks `user_branch_assignments` first: Exposure 7, coverage 596, NOT-RECORDED (runner-up `departments` 7/660). The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.** A placement decides read scope (`app.visible_branch_ids`, `app.visible_department_ids`) and filing (`app.current_placement`, the lead-handler and task RPCs). `app.assign_user_branch` charges `app.authorize('MANAGE_USERS')`, permission AND step-up, and checks that the department belongs to the branch. The table door charges RLS `app.has_permission('MANAGE_USERS')` only, and the only emitter fires AFTER INSERT.
- **Measured at `90a3a72`** on the local stack, committed probe fixtures (owner, ceo and employee actors):
  - **USR-3 (High), this table's half.** A `ceo` at `aal1` was refused by the RPC ("multi-factor authentication required"), then added a branch by direct INSERT and moved a colleague's primary placement to another branch and department by direct UPDATE. The same actor was refused 42501 on `user_role_assignments`.
  - **UBA-1 (High).** A stepped-up administrator's direct UPDATE re-pointed a primary placement to another branch (visible branches moved), ended it (visible branches empty) and handed it to another user: 0 events across the three.
  - **UBA-3 (Medium).** The RPC refused a department of another branch; the table door accepted it, and `app.visible_department_ids()` then returned that department.
  - **UBA-5 (Low).** The table door accepted `ends_at` a day before `starts_at`.
- **The repair**, in the SPEC-203 shape (`20260920120000`): authority is a precondition and runs BEFORE; the record is a fact and runs AFTER.
  - `app.guard_placement_authority`, BEFORE INSERT OR UPDATE (SECURITY DEFINER, empty `search_path`, executable by no client role): `app.authorize('MANAGE_USERS')` on every session write and every column. A write with no session (migrations, seeds, the platform) is exempt, as in every sibling guard.
  - `app.emit_user_branch_transfer` also fires AFTER UPDATE when `user_id`, `branch_id`, `department_id`, `is_primary`, `starts_at` or `ends_at` moves, and records the new code `user_branch_assignment_changed` (severity security, `sort_order` 936, canon 27 entry) with the previous and current placement; a row handed to another user records it for both users. The INSERT branch is unchanged.
  - The composite FK `user_branch_assignments_department_in_branch_fkey` (`tenant_id`, `branch_id`, `department_id`) to `departments` (`tenant_id`, `branch_id`, `id`), on the new unique key `departments_tenant_id_branch_id_id_key`; MATCH SIMPLE, so a placement without a department is unaffected.
  - The CHECK `user_branch_assignments_ends_after_start_check` (`ends_at is null or ends_at >= starts_at`).
  - No grant, policy, RPC body, `derive_created_by` or `enforce_catalog_codes` changes.
- **Existing files that move, each for a stated reason.** `10_grant_model_test.sql`: the MEAS-2 inventory of bespoke-guard tables goes from eleven to twelve; the assertion exists to force this justification. `38_class_a_events_test.sql`: a `reset role` left an employee claim set, which the guard now refuses; the claim is cleared as the same file already does at assertions 8-9. `79_customer_data_integrity_test.sql`: an "ended yesterday" placement that started today now starts two days ago. `scripts/verify_database.sql`: CHECK 6b 623 to 624 catalog values. `_ORVION_CANONICAL/27_event_catalog.md`: the new code's entry.
- **Swept and found sound, pinned rather than changed:** an employee's direct write is refused by RLS; a branch of another tenant is refused by the tenant-composite FK; DELETE has no grant; a forged `created_by` is replaced by the derived actor; the one race, two current primaries, is refused by `user_branch_assignments_one_primary_idx`.
- **Recorded positions, not repaired:** no RPC transfers or ends a placement, so a transfer is a table write by a stepped-up MANAGE_USERS holder, now guarded and recorded (reopening trigger: a transfer or offboarding flow in the product). The RPC places a user onto an inactive branch, which then joins their visible branches, and places an inactive user (reopening trigger: a branch or user lifecycle flow that must withdraw read scope). USR-3's `user_permission_grants` half is its own surface with its own defining migration (`202607059800`) and stays OPEN.
- **Latent on Primary:** `vrvtsxexkiiiivlkdxzp` holds 0 tenants and 0 placements (read-only, 2026-11-11, ledger 255), so the FK and the CHECK meet no existing row and no data repair is needed.

## Risks

- **A stored placement that breaks the new FK or CHECK would stop the migration.** `alter table` refuses it and the whole migration rolls back before anything changes. Step 10 reads Primary for department mismatches and end-before-start rows, and Step 12 re-reads them immediately before deployment.
- **A session write without the step-up now fails on the table door** (42501), as it already did through the RPC. No migration other than the RPC writes this table with a session; the seeds of the declared and undeclared journey suites write without one and pass.
- **Primary deployment is irreversible** and runs only under the exact-SHA Gate-2 record of Step 11. Approval of this contract does not authorize it. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
- **Gate 1 and Gate 2 of this contract are DELEGATED** under the owner's instructions (class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo; publish, promote and hosted deploy ~12:05; slice 3 hypotheses and probes, 2026-11-11 ~05:50; "go with your recommendation" for slice 3 ~06:28; V1 as a CRM SPEC ~07:00), recorded outside this repository; never a human-typed digest.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-300-a-placement-changes-only-with-authority-and-a-record.md`
- `supabase/migrations/20261111120000_a_placement_changes_only_with_authority_and_a_record.sql`
- `supabase/tests/160_a_placement_changes_only_with_authority_and_a_record_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/38_class_a_events_test.sql`
- `supabase/tests/79_customer_data_integrity_test.sql`
- `scripts/verify_database.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607041700_create_identity_and_access_tables.sql`
- `supabase/migrations/202607043900_organization_management_rpcs.sql`
- `supabase/migrations/202607044100_mfa_requirement_enforcement.sql`
- `supabase/migrations/202607051400_read_scope_model.sql`
- `supabase/migrations/202607053400_wp02_class_a_events.sql`
- `supabase/migrations/202607058300_a_primary_is_per_channel_and_a_placement_is_not_over_yet.sql`
- `supabase/migrations/202607059800_capability_grants_are_per_user_not_only_per_role.sql`
- `supabase/migrations/20260920120000_membership_authority_and_audit.sql`
- `supabase/tests/21_read_scope_model_test.sql`
- `supabase/tests/118_membership_authority_and_audit_test.sql`
- `supabase/tests/130_branch_door_audit_test.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/readiness_population.ps1`
- `scripts/parity_surface.sql`
- `scripts/check_database_parity.ps1`
- `scripts/check_primary_ledger.ps1`
- `ENGINEERING_METHOD.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `reports/architecture-decision-records.md`
- `reports/future-backlog.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `supabase/migrations/202607044100_mfa_requirement_enforcement.sql` (`app.assign_user_branch`, the one writer) and `202607053400_wp02_class_a_events.sql` (the INSERT emitter)
- `supabase/migrations/202607051400_read_scope_model.sql` (the readers) and `20260920120000_membership_authority_and_audit.sql` (the SPEC-203 shape)
- `reports/master/MASTER_GAP_REGISTER.md` (USR-3); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11
- `changes/SPEC-299-a-decided-approval-is-final.md` (the last Primary-deploying slice)

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: SPEC-300-V1 adds an authority guard on every session write of a placement, an UPDATE emitter with a new event code, a department-belongs-to-branch FK and an end-after-start CHECK; test 160 pins each on the table door, the stepped-up and session-less controls and an edit that records nothing; tests 10, 38 and 79 and the smoke count move with stated reasons; the register and disposition record USR-3's half, UBA-1, UBA-3, UBA-5 and the surface.

Pass 2 Adversarial Review: SPEC-300-V2 challenged each part on the prototype. Charging the step-up in the RLS policy was rejected: a policy filters rows instead of raising, so an UPDATE at `aal1` would touch 0 rows and look like success, and SPEC-203 set the BEFORE-trigger shape. Recording UPDATEs as `user_branch_transfer_completed` was rejected: test 38 pins one transfer as one `_completed`, and the end of the old primary would count as a second. Emitting on every UPDATE was rejected: only the six columns a reader consumes move read scope, and churn would bury the record. A trigger for department-in-branch was rejected for a declarative FK; the RPC's own check stays. A transfer or end RPC and refusing inactive targets were rejected for this slice: behaviour additions with no consumer, recorded with their reopening triggers. Absorbing USR-3's `user_permission_grants` half was rejected: its own surface and defining migration, as SPEC-203 ruled. Attacks run on the final bytes: no migration other than the RPC writes the table with a session, and the three undeclared journey suites, whose seeds write placements without one, pass (`verify_care_journeys` 40/0, `verify_role_journeys` 122/0, `verify_storage_end_to_end` 60/0); test 160 gained assertion 16 (a branch of another tenant is refused, so TENANT is earned) and assertion 17 (the RPC's own transfer is recorded once and the UPDATE emitter adds nothing); no writer moves `departments.branch_id`, so the FK blocks no flow; the generated API contract moves `user_branch_assignments` from `no | no` to `yes | conditional`, so `MASTER_API_CONTRACT.md` is regenerated in Step 13. Copying the selector's next target into the manifest was rejected (SPEC-270; SPEC-278's cancellation).

Pass 3 Evidence Refresh: 2026-11-11. SPEC-300-V3 re-measured on byte-identical files in a disposable clone of `90a3a72` with the project-local CLI 3.0.0: the clean reset, test 160 and tests 10, 38, 79 and 118 alone, pgTAP Pass A and B, the three declared HTTP suites, smoke, the probes, all four mutants, the causal negative, the structural fingerprints before and after, the generators and repository consistency; and read Primary and Founder Secondary read-only for their ledgers and placements.

Selected Version: SPEC-300-V3; selected: the smallest repair that closes the placement half of USR-3, UBA-1, UBA-3 and UBA-5 on every door (one authority guard, the emitter extended to UPDATE with one new code, one FK, one CHECK; no RPC body, grant or policy changed), proven on byte-identical files by the full local protocol, four killed mutants, the probes and the causal negative

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A placement write charges `app.authorize('MANAGE_USERS')` on every door | `app.assign_user_branch`; the administrator's table door (RLS insert and update); any platform writer | WRITE | Migration SHA-256 `0357e458260a62ae4273aea8759f9f319a06752043f3812c02665a4b525af61b`, md5 `89ac4aeb61f5eeade88a9f63360309c0`, 7635 bytes, LF, ASCII. A clean reset gives 256 migrations, latest `20261111120000`, guard `md5(prosrc)` `6e75bf9dca6e2112e3ef71c26efe88eb`, SECURITY DEFINER, ACL `{postgres=X/postgres}`; both triggers fire on INSERT and UPDATE. |
| Every placement change is recorded | readers of `public.events`; canon 27; `catalog_values` (`event_type`) | WRITE | Emitter `md5(prosrc)` `2696ca99264ea35a3b037f2a55b661be` → `a0e8398f69ff7bea38ed657ba2915a76`, SECURITY DEFINER, ACL `{postgres=X/postgres}`; one new code at `sort_order` 936, catalog 71/623 → 71/624. |
| A department belongs to its placement's branch; a placement ends after it starts | `app.visible_department_ids`; `app.current_placement`; every insert or update of a placement | WRITE | Constraints +3 (the unique key on `departments`, the FK, the CHECK), indexes +1. The RPC already refused both; 0 placements on Primary. |
| The readers of placements | `app.visible_branch_ids`; `app.visible_department_ids`; `app.current_placement`; `app.eligible_lead_handlers`; `app.lead_responsible_managers`; `app.create_task`; `app.assign_task`; tests 21, 118, 130 | VERIFY | No body changes; every pgTAP file passes; the undeclared journeys `verify_care_journeys` 40/0, `verify_role_journeys` 122/0, `verify_storage_end_to_end` 60/0. |
| Test 160 | `supabase/tests` | WRITE | SHA-256 `251c911617b0110c156e25d03b5b25eb9e75ed2a15561c0471774c36c4931832`, md5 `5d00c7b8438c2a6e00b5eb7d9faa43e5`, 10396 bytes, LF, ASCII, `plan(17)`: 17/17. |
| Tests 10, 38 and 79 | the MEAS-2 inventory; the Class A event pins; the customer-data placement fixture | WRITE | Each edit and its reason in Business Reason; each passes alone (9, 21 and 19 assertions). |
| Other tests and the suite | the full pgTAP suite; the HTTP suites | VERIFY | Pass A `Files=160, Tests=3041`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 160/3041, PASS. 160 files whose literal `plan(N)` values sum to 3041. |
| Smoke | `scripts/verify_database.sql` | WRITE | CHECK 6b expects 624 catalog values; `ALL CHECKS PASSED` (78 tables, 71/624 catalog). |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Before (255): functions `b85385fc150c11088ec13f5dcfc0b889`/333, `_combined` `04223971cbe8be586da4135ddcfbfe06`/3140, equal to the recorded Primary evidence. After (256): functions `965f9695147a4dcba08ca71cd9f4a4d3`/334 (+1), triggers `c4da265b570c72f41c8e2c830053fbfa`/321 (+1), constraints `de558c4ca5e359684c0c64d29e3b05c1`/531 (+3), indexes `68bebc859d882adfd2dc1d1a51148c06`/302 (+1), `_combined` `6ce7270e06e890832c53c505d4976a49`/3146; the rest unchanged. Step 13 writes Primary values only from fresh post-deploy readings. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3) | WRITE | No RPC is added, removed or changed in signature; the guard is a trigger function executable by no client role. The generator's table-surface row for `user_branch_assignments` moves from insert guard `no`, update guard `no` to `yes`, `conditional`, as for `user_role_assignments` and `users`; Step 13 regenerates it. |
| Measured state that moves | manifest `Live state` and suite figure; `primary-ledger-evidence.json`; `ai-map.json` and `repository-index.md` | WRITE | 255 → 256 migrations, latest `20261111120000`, ledger fingerprint `7175a9d8726ea68a08c612a4a624b972`; 159 → 160 files and 3024 → 3041 assertions; coverage 45 → 46 of 78. Tables 78 and client RPCs 80 do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 14 names `Current Module` and `Next capability` only to leave them unchanged; each line keeps its ratified text and pin, so the selector and the disposition record name the next slice and the coverage. |
| USR-3's half, UBA-1, UBA-3 and UBA-5 fixed; the surface recorded | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25, 29 | WRITE | No `UBA-` row exists at `90a3a72`. USR-3 stays OPEN for `user_permission_grants`, already classified in the action registry, so Check 29 passes unchanged. Test 160's `-- ATTACK-CLASSES:` line declares ten classes with CONCURRENCY and REPLAY `=N/A` and carries negative assertions, so Check 24 admits `ADVERSARIAL`. Each UBA row has Owner `—` and is settled. Coverage 46: 22 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 32 `NOT-RECORDED`; all 46 `ADVERSARIAL`. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | With Steps 1–9 applied and the contract present, consistency reports exactly six measured-state items (255 vs 256 migrations, latest, ledger fingerprint, 159 vs 160 files, 3024 vs 3041 assertions, the Primary-evidence record) and Checks 21–29 pass. Step 13 makes them true; the one implementation commit is made only after it. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 12 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The applied files equal the verified bytes, and the focused tests, probes, mutants and causal negative hold | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 10 |
| Primary holds no placement the FK or CHECK would refuse and lacks the target migration | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 12 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 13 | Step 14 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 13 | Step 14 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 13 | Step 14 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 13 | Step 14 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.assign_user_branch` charges `app.authorize('MANAGE_USERS')` and checks the department's branch, but it only inserts; the table's RLS insert and update policies charge `app.has_permission('MANAGE_USERS')` with no step-up; `user_branch_assignments_emit_transfer` fires AFTER INSERT only; the tenant-composite FKs bind user, branch and department to the tenant but not the department to the branch; no CHECK orders `starts_at` and `ends_at`. `guard_write_capability` has no mapping for this table.

Added Property: For every end-user writer, a placement is written only with permission AND step-up, every change to a column a reader consumes is recorded with both placements and the actor, a placement's department belongs to its branch, and a placement never ends before it starts.

Causal Negative: On the stack with the guard, its function, the UPDATE branch of the emitter trigger, the FK, its unique key and the CHECK removed (the `90a3a72` schema), test 160 fails assertions 1, 3–6, 9, 11–13 and 17, and the probes return: the `aal1` direct INSERT and UPDATE succeed, an UPDATE moves, ends and hands over a placement with 0 events, a department of another branch becomes visible, and an end before the start is stored.

Positive Test Design: One tenant with a `ceo` and two employees, two branches each with one department, one placement; a second tenant with one branch. Positive controls: the stepped-up `ceo` writes through the table door, re-points, ends and hands over the placement; an edit no reader consumes lands; a session-less platform write lands; the RPC places a user.

Negative Test Design:
- **Auth:** at `aal1` the RPC, the direct INSERT and the direct UPDATE are each refused 42501.
- **Business:** a department of another branch is refused 23503.
- **Input:** an end before the start is refused 23514.
- **Tenant:** a branch of another tenant is refused 23503.
- **Privilege:** an employee is refused by RLS.
- **Observability:** a re-point, an end and a hand-over each record `user_branch_assignment_changed` with both placements and the actor (both users on a hand-over); an edit no reader consumes records nothing; the RPC's own transfer is recorded once.

Non-Empty Population Obligation: The fixture holds two tenants, three users, three branches, two departments and one placement before the first assertion. Each refusal is asserted by exact SQLSTATE and each record by an exact count.

Mutation Obligation: Each mutant is installed on the prototype stack, proven installed by a changed fingerprint (guard trigger count, emitter trigger events, FK and CHECK counts, guard `md5(prosrc)`), run against test 160 and the probes, then restored and proven equal (`guard=1 emit=ins+upd fk=1 chk=1 fn=6e75bf9d`) with 17/17 before the next. A mutant not proven installed is a harness error, never a kill. Rows a mutant's own probe leaves that the restored constraints refuse are retired (disposable data) before the restore.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| M1 | the guard trigger dropped | 160 assertions 1, 3–4 and 17; the `aal1` direct INSERT and UPDATE succeed again |
| M2 | the emitter trigger back to AFTER INSERT only | 160 assertions 1, 9, 11–13 and 17; the probes' UPDATEs record 0 events |
| M3 | the department FK dropped | 160 assertions 5 and 17; the probe's department of another branch becomes visible |
| M4 | the end CHECK dropped | 160 assertions 6 and 17; the probe's end before the start is stored |

Post-Implementation Proof Obligation: All of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI: the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke; the generated artifacts, repository consistency and the recorded Primary evidence. Before Step 12: the focused tests, the probes, the mutants, the causal negative and the fresh Primary baseline of Step 10.

## Implementation Steps

1. Check whether `supabase/migrations/20261111120000_a_placement_changes_only_with_authority_and_a_record.sql` contains `SPEC-300 (Batch 6 Slice 45, USR-3, UBA-1, UBA-3, UBA-5)`; if so record Already Applied when its Git blob is 3d6987cf6052c4a455a3352d29b11d502cfaa0cd, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the migration: the authority guard, the UPDATE emitter and its code, the department FK and the end CHECK), and change nothing else:

   ```text
   -- SPEC-300 (Batch 6 Slice 45, USR-3, UBA-1, UBA-3, UBA-5) -- a placement changes only with the
   -- RPC's authority, leaves a record on every door, and is internally consistent.
   --
   -- =================================================================================================
   -- THE MEASURED DEFECTS (2026-11-11 at 90a3a72 on the local stack, committed probe fixtures)
   --
   -- USR-3 `app.assign_user_branch` charges `app.authorize('MANAGE_USERS')` (permission AND step-up);
   --      the table's RLS charges `app.has_permission` only. A `ceo` at `aal1` was refused by the RPC,
   --      then added a branch by direct INSERT and moved a colleague's primary BR1/D1 -> BR2/D2 by
   --      direct UPDATE. The same actor was refused 42501 on `user_role_assignments`. (USR-3 also names
   --      `user_permission_grants`; that half is a different surface and stays OPEN.)
   -- UBA-1 `user_branch_assignments_emit_transfer` is AFTER INSERT only. A direct UPDATE re-pointed a
   --      primary to another branch, ended it, and handed the row to another user: read scope moved
   --      three times, 0 events.
   -- UBA-3 The RPC refuses a department of another branch; the table accepted BR1 with D2 of BR2, and
   --      `app.visible_department_ids()` then returned D2.
   -- UBA-5 The table accepted `ends_at` a day before `starts_at`.
   --
   -- =================================================================================================
   -- THE REPAIR, IN THE SPEC-203 SHAPE (`20260920120000`): authority is a precondition and runs
   -- BEFORE; the record is a fact and runs AFTER.
   --
   -- 1. `app.guard_placement_authority`, BEFORE INSERT OR UPDATE: `app.authorize('MANAGE_USERS')` on
   --    every session write, every column. No session (migrations, seeds, provisioning, service_role):
   --    no charge, as in every sibling guard. The RPC's own charge stays; a second check is free.
   -- 2. `app.emit_user_branch_transfer` also fires AFTER UPDATE when a column a reader consumes moves
   --    (user_id, branch_id, department_id, is_primary, starts_at, ends_at). It records the NEW code
   --    `user_branch_assignment_changed` (severity security: a read-scope input moved outside the RPC)
   --    with the previous and current placement; a row handed to another user records it for both
   --    users. Not `user_branch_transfer_completed`: a transfer is "end the old primary, insert the new
   --    one", and test 38 pins one transfer = one `_completed`; reusing it would count every end as a
   --    transfer. The INSERT branch is unchanged.
   -- 3. A department belongs to the placement's branch: a composite FK
   --    (tenant_id, branch_id, department_id) -> departments (tenant_id, branch_id, id). MATCH SIMPLE,
   --    so a placement without a department is unaffected.
   -- 4. `ends_at >= starts_at` as a CHECK.
   --
   -- DELETE is not included: `authenticated` holds no DELETE on this table (SPEC-203's reasoning).
   -- POSITIONS, not changed here (behaviour additions, recorded under UBA-1 with their reopening
   -- triggers): no RPC transfers or ends a placement (a new primary while one is open is refused 23505
   -- by `user_branch_assignments_one_primary_idx`, so a transfer is a guarded, recorded table write),
   -- and the RPC places onto an inactive branch or an inactive user.
   -- NOT CHANGED: every grant, policy, the RPC body, `derive_created_by`, `enforce_catalog_codes`.
   -- Hosted rows at the time of writing (read-only, ledger 255): 0 placements on Primary and on
   -- Founder Secondary, so the FK and the CHECK meet no existing row.
   -- =================================================================================================

   -- Vocabulary. `sort_order` 936 is MEASURED: `event_type` holds 188 rows, maximum 935. Seeded under the
   -- existing catalog type, as SPEC-203 did; canon 27 gains the matching entry.
   insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
   select null::uuid, 'event_type', 'user_branch_assignment_changed', 'User Branch Assignment Changed', 936, true, true
   where not exists (
       select 1 from public.catalog_values cv
       where cv.catalog_type_code = 'event_type' and cv.code = 'user_branch_assignment_changed' and cv.tenant_id is null
   );

   create or replace function app.guard_placement_authority()
   returns trigger
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   begin
       if (select auth.uid()) is null then
           return new;
       end if;
       perform app.authorize('MANAGE_USERS');
       return new;
   end;
   $fn$;

   revoke execute on function app.guard_placement_authority() from public;

   create trigger user_branch_assignments_guard_authority
       before insert or update on public.user_branch_assignments
       for each row execute function app.guard_placement_authority();

   -- `old` is read only inside the UPDATE branch (the SPEC-159-A 55000 failure mode).
   create or replace function app.emit_user_branch_transfer()
   returns trigger
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   declare
       v_prev jsonb;
       v_next jsonb;
   begin
       if tg_op = 'INSERT' then
           if exists (
               select 1 from public.user_branch_assignments prior
               where prior.tenant_id = new.tenant_id
                 and prior.user_id   = new.user_id
                 and prior.id       <> new.id
           ) then
               perform app.record_event(
                   new.tenant_id, 'user_branch_transfer_completed', 'user', new.user_id,
                   null, null, null, new.transfer_type_code,
                   jsonb_build_object('branch_id', new.branch_id, 'department_id', new.department_id),
                   'info');
           end if;
           return null;
       end if;

       v_prev := jsonb_build_object('user_id', old.user_id, 'branch_id', old.branch_id,
           'department_id', old.department_id, 'is_primary', old.is_primary,
           'starts_at', old.starts_at, 'ends_at', old.ends_at);
       v_next := jsonb_build_object('user_id', new.user_id, 'branch_id', new.branch_id,
           'department_id', new.department_id, 'is_primary', new.is_primary,
           'starts_at', new.starts_at, 'ends_at', new.ends_at);
       if v_prev = v_next then
           return null;
       end if;

       perform app.record_event(
           new.tenant_id, 'user_branch_assignment_changed', 'user', new.user_id,
           null, null, null, null,
           jsonb_build_object('assignment_id', new.id, 'previous', v_prev, 'current', v_next),
           'security');
       if new.user_id is distinct from old.user_id then
           perform app.record_event(
               new.tenant_id, 'user_branch_assignment_changed', 'user', old.user_id,
               null, null, null, null,
               jsonb_build_object('assignment_id', new.id, 'previous', v_prev, 'current', v_next),
               'security');
       end if;
       return null;
   end;
   $fn$;

   revoke execute on function app.emit_user_branch_transfer() from public;

   drop trigger if exists user_branch_assignments_emit_transfer on public.user_branch_assignments;
   create trigger user_branch_assignments_emit_transfer
       after insert or update on public.user_branch_assignments
       for each row execute function app.emit_user_branch_transfer();

   alter table public.departments
       add constraint departments_tenant_id_branch_id_id_key unique (tenant_id, branch_id, id);

   alter table public.user_branch_assignments
       add constraint user_branch_assignments_department_in_branch_fkey
           foreign key (tenant_id, branch_id, department_id)
           references public.departments (tenant_id, branch_id, id)
           on delete restrict on update no action,
       add constraint user_branch_assignments_ends_after_start_check
           check (ends_at is null or ends_at >= starts_at);
   ```

   The resulting file's Git blob is 3d6987cf6052c4a455a3352d29b11d502cfaa0cd.

2. Check whether `supabase/tests/160_a_placement_changes_only_with_authority_and_a_record_test.sql` contains `plan(17)`; if so record Already Applied when its Git blob is 52a514903559196adc104c41ced2b7ebd4eb2efa, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 160, 17 assertions), and change nothing else:

   ```text
   -- pgTAP: SPEC-300 (Batch 6 Slice 45, USR-3, UBA-1, UBA-3, UBA-5) --
   -- a placement changes only with the RPC's authority, leaves a record on every door, and is
   -- internally consistent (`20261111120000`).
   -- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY
   --   CONCURRENCY=N/A -- the one race on this table, two current primaries, is refused by the existing
   --     unique index; nothing here adds or relies on ordering.
   --   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(17);

   insert into auth.users (id, email) values
     ('16000000-0000-0000-0000-0000000000a1','ceo@c160.test'),
     ('16000000-0000-0000-0000-0000000000a2','u1@c160.test'),
     ('16000000-0000-0000-0000-0000000000a3','u2@c160.test');
   insert into public.tenants (id, name, slug, status) values
     ('16000000-0000-0000-0000-000000000001','Placement Travel','placement-travel-160','active'),
     ('16000000-0000-0000-0000-000000000002','Other Travel','other-travel-160','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '16000000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('16000000-0000-0000-0000-0000000000b1','16000000-0000-0000-0000-000000000001','B1','b1-160'),
     ('16000000-0000-0000-0000-0000000000b2','16000000-0000-0000-0000-000000000001','B2','b2-160'),
     ('16000000-0000-0000-0000-0000000000b9','16000000-0000-0000-0000-000000000002','B9','b9-160');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('16000000-0000-0000-0000-0000000000d1','16000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-0000000000b1','sales','S1'),
     ('16000000-0000-0000-0000-0000000000d2','16000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-0000000000b2','sales','S2');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('16000000-0000-0000-0000-000000000011','16000000-0000-0000-0000-000000000001','CEO','ceo@c160.test',true,'16000000-0000-0000-0000-0000000000a1'),
     ('16000000-0000-0000-0000-000000000012','16000000-0000-0000-0000-000000000001','U1','u1@c160.test',true,'16000000-0000-0000-0000-0000000000a2'),
     ('16000000-0000-0000-0000-000000000013','16000000-0000-0000-0000-000000000001','U2','u2@c160.test',true,'16000000-0000-0000-0000-0000000000a3');
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '16000000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
   from (values ('16000000-0000-0000-0000-000000000011'::uuid,'ceo'),
                ('16000000-0000-0000-0000-000000000012'::uuid,'employee'),
                ('16000000-0000-0000-0000-000000000013'::uuid,'employee')) v(uid, role_code)
   join public.roles r on r.code = v.role_code;
   insert into public.user_branch_assignments (id, tenant_id, user_id, branch_id, department_id, is_primary) values
     ('16000000-0000-0000-0000-0000000000e1','16000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000012','16000000-0000-0000-0000-0000000000b1','16000000-0000-0000-0000-0000000000d1',true);

   select is(
     (select count(*)::int from pg_trigger
      where tgrelid = 'public.user_branch_assignments'::regclass and not tgisinternal
        and tgname in ('user_branch_assignments_guard_authority', 'user_branch_assignments_emit_transfer')
        and pg_get_triggerdef(oid) like '%INSERT OR UPDATE%'),
     2,
     'the authority guard and the emitter both fire on INSERT and UPDATE');

   -- The ceo at aal1: the RPC refuses (control), and now so does the table door.
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
   select throws_ok(
     $$select app.assign_user_branch('16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b2')$$,
     '42501', null,
     'control: the RPC refuses a password-only session');
   select throws_ok(
     $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id)
       values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b2')$$,
     '42501', null,
     'USR-3: the direct INSERT at aal1 is refused too (measured before the repair: accepted)');
   select throws_ok(
     $$update public.user_branch_assignments set branch_id = '16000000-0000-0000-0000-0000000000b2', department_id = '16000000-0000-0000-0000-0000000000d2'
       where id = '16000000-0000-0000-0000-0000000000e1'$$,
     '42501', null,
     'USR-3: the direct UPDATE at aal1 is refused too (measured before the repair: moved a primary)');

   -- The ceo at aal2.
   select set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   select throws_ok(
     $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id)
       values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b1', '16000000-0000-0000-0000-0000000000d2')$$,
     '23503', null,
     'UBA-3: a department of another branch is refused on the table door, as the RPC refuses it');
   select throws_ok(
     $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id, starts_at, ends_at)
       values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b2', now(), now() - interval '1 day')$$,
     '23514', null,
     'UBA-5: a placement cannot end before it starts');
   select lives_ok(
     $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id)
       values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b2', '16000000-0000-0000-0000-0000000000d2')$$,
     'the stepped-up administrator still writes through the table door');

   select lives_ok(
     $$update public.user_branch_assignments set branch_id = '16000000-0000-0000-0000-0000000000b2', department_id = '16000000-0000-0000-0000-0000000000d2'
       where id = '16000000-0000-0000-0000-0000000000e1'$$,
     'the administrator re-points u1''s primary to B2');
   select is(
     (select count(*)::int from public.events
      where entity_id = '16000000-0000-0000-0000-000000000012' and event_type_code = 'user_branch_assignment_changed'
        and payload->'previous'->>'branch_id' = '16000000-0000-0000-0000-0000000000b1'
        and payload->'current'->>'branch_id' = '16000000-0000-0000-0000-0000000000b2'
        and actor_user_id = '16000000-0000-0000-0000-000000000011'),
     1,
     'UBA-1: the re-point is recorded, with both placements and the actor (measured before the repair: 0 events)');

   select lives_ok(
     $$update public.user_branch_assignments set reason = 'filed' where id = '16000000-0000-0000-0000-0000000000e1'$$,
     'an edit no reader consumes is accepted');
   select is(
     (select count(*)::int from public.events
      where entity_id = '16000000-0000-0000-0000-000000000012' and event_type_code = 'user_branch_assignment_changed'),
     1,
     '...and records nothing: the emitter fires on placement changes, not column churn');

   update public.user_branch_assignments set ends_at = now() where id = '16000000-0000-0000-0000-0000000000e1';
   select is(
     (select count(*)::int from public.events
      where entity_id = '16000000-0000-0000-0000-000000000012' and event_type_code = 'user_branch_assignment_changed'
        and payload->'previous'->>'ends_at' is null and payload->'current'->>'ends_at' is not null),
     1,
     'UBA-1: ending a placement is recorded');

   update public.user_branch_assignments set user_id = '16000000-0000-0000-0000-000000000013' where id = '16000000-0000-0000-0000-0000000000e1';
   select is(
     (select count(*)::int from public.events
      where entity_id in ('16000000-0000-0000-0000-000000000012', '16000000-0000-0000-0000-000000000013')
        and event_type_code = 'user_branch_assignment_changed'
        and payload->'current'->>'user_id' = '16000000-0000-0000-0000-000000000013'
        and payload->'previous'->>'user_id' = '16000000-0000-0000-0000-000000000012'),
     2,
     'UBA-1: a row handed to another user is recorded for both of them');

   -- An employee is still refused by RLS before the guard is reached.
   select set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   select throws_ok(
     $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id)
       values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000012', '16000000-0000-0000-0000-0000000000b2')$$,
     '42501', null,
     'an employee is refused by RLS, unchanged');

   -- No session (migrations, seeds, provisioning): exempt from the charge, as every sibling guard is.
   reset role;
   select set_config('request.jwt.claims', '', true);
   select lives_ok(
     $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id)
       values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000012', '16000000-0000-0000-0000-0000000000b1')$$,
     'a platform path without a session still places a user');

   -- Back to the stepped-up administrator: the tenant boundary, and the RPC's own record.
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   select throws_ok(
     $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id)
       values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b9')$$,
     '23503', null,
     'a branch of another tenant is refused on the table door (the tenant-composite FK), unchanged');
   do $$ begin perform app.assign_user_branch('16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b1'); end $$;
   select is(
     (select count(*) filter (where event_type_code = 'user_branch_transfer_completed') || '/' ||
             count(*) filter (where event_type_code = 'user_branch_assignment_changed')
      from public.events where entity_id = '16000000-0000-0000-0000-000000000013'),
     '1/1',
     'the RPC records its own transfer once, and the UPDATE emitter adds nothing to it (the 1 change is the hand-over)');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 52a514903559196adc104c41ced2b7ebd4eb2efa.

3. Check whether `supabase/tests/10_grant_model_test.sql` contains `exactly these TWELVE tables`; if so record Already Applied when its Git blob is ea4d929d8da576369129bb0ddad8a5bae495bc3f, and otherwise stop and report. Otherwise make exactly these 2 edits (the MEAS-2 bespoke-guard inventory, eleven to twelve), each matched once, and change nothing else:

   a) immediately after the line
   ```text
   -- guard's absence and re-assert it after the rollback.
   ```
   insert
   ```text
   --
   -- IT WENT FROM ELEVEN TO TWELVE ON 2026-11-11 (SPEC-300, Batch 6 Slice 45, `20261111120000`).
   -- `user_branch_assignments` joined because `app.guard_placement_authority` charges
   -- `app.authorize('MANAGE_USERS')` (USR-3: the door now asks for the step-up `app.assign_user_branch`
   -- asks for). `guard_write_capability` has no mapping for this table. The charge is UNCONDITIONAL for
   -- every signed-in caller, on INSERT and UPDATE and every column; its one exemption, the SESSION-LESS
   -- platform write, is pinned by `160_...` assertion 15, and the slice's mutants remove the guard.
   ```

   b) replace the lines
   ```text
           'payments','quotation_items','receipts','refunds','user_role_assignments','users'],
     'MEAS-2: exactly these ELEVEN tables are credited by a BESPOKE capability trigger rather than by guard_write_capability, so for each of them "credited" means "a human read its short-circuits". Nine until 2026-09-20, when SPEC-203 gave users app.guard_membership_authority -- admissible only because that guard charges app.authorize unconditionally on every path and every column, and its only two exemptions, the session-less platform write and the activate_membership self-claim, are each pinned by a named assertion in 118_membership_authority_and_audit_test.sql. Eleven since 2026-10-13, when SPEC-278 gave chart_of_accounts app.guard_chart_account -- the same unconditional charge, its one session-less exemption pinned by 157_a_used_ledger_account_keeps_its_meaning_test.sql');
   ```
   with
   ```text
           'payments','quotation_items','receipts','refunds','user_branch_assignments','user_role_assignments','users'],
     'MEAS-2: exactly these TWELVE tables are credited by a BESPOKE capability trigger rather than by guard_write_capability, so for each of them "credited" means "a human read its short-circuits". Nine until 2026-09-20, when SPEC-203 gave users app.guard_membership_authority -- admissible only because that guard charges app.authorize unconditionally on every path and every column, and its only two exemptions, the session-less platform write and the activate_membership self-claim, are each pinned by a named assertion in 118_membership_authority_and_audit_test.sql. Eleven since 2026-10-13, when SPEC-278 gave chart_of_accounts app.guard_chart_account -- the same unconditional charge, its one session-less exemption pinned by 157_a_used_ledger_account_keeps_its_meaning_test.sql. Twelve since 2026-11-11, when SPEC-300 gave user_branch_assignments app.guard_placement_authority -- the same unconditional charge, its one session-less exemption pinned by 160_a_placement_changes_only_with_authority_and_a_record_test.sql');
   ```

   The resulting file's Git blob is ea4d929d8da576369129bb0ddad8a5bae495bc3f.

4. Check whether `supabase/tests/38_class_a_events_test.sql` contains `a leftover employee claim is refused MANAGE_USERS`; if so record Already Applied when its Git blob is 25e481393523dae92d61feb3b7b0949b4a45624a, and otherwise stop and report. Otherwise make exactly this one edit (the leftover employee claim cleared before the system-path writes), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   --        `_started` is never fabricated (SPEC-153 Class B).
   -- =============================================================================================
   reset role;
   ```
   insert
   ```text
   -- ...and CLEAR the claim, as at 8-9 above: the writes below are SYSTEM paths, and since
   -- `app.guard_placement_authority` (SPEC-300) a leftover employee claim is refused MANAGE_USERS.
   select set_config('request.jwt.claims', null, true);
   ```

   The resulting file's Git blob is 25e481393523dae92d61feb3b7b0949b4a45624a.

5. Check whether `supabase/tests/79_customer_data_integrity_test.sql` contains `holds since SPEC-300 (UBA-5)`; if so record Already Applied when its Git blob is fa01969b1adf6c0547274ecc6bcf69681966b09e, and otherwise stop and report. Otherwise make exactly this one edit (the ended placement starts before it ends), each matched once, and change nothing else:

   a) replace the line
   ```text
   update public.user_branch_assignments set ends_at = now() - interval '1 day'
   ```
   with
   ```text
   -- It started before it ended: `ends_at >= starts_at` holds since SPEC-300 (UBA-5).
   update public.user_branch_assignments set starts_at = now() - interval '2 days', ends_at = now() - interval '1 day'
   ```

   The resulting file's Git blob is fa01969b1adf6c0547274ecc6bcf69681966b09e.

6. Check whether `scripts/verify_database.sql` contains `expected 624 catalog_values`; if so record Already Applied when its Git blob is 993bc5509e6776555aee8a97a2e47e49ab751802, and otherwise stop and report. Otherwise make exactly these 3 edits (smoke CHECK 6b, 623 to 624 catalog values), each matched once, and change nothing else:

   a) replace the line
   ```text
   -- Expected values track the frozen baseline: 77 public base tables, 71 catalog types, 623 catalog
   ```
   with
   ```text
   -- Expected values track the frozen baseline: 77 public base tables, 71 catalog types, 624 catalog
   ```

   b) replace the line
   ```text
       if n <> 623 then raise exception 'CHECK 6b FAILED: expected 623 catalog_values, found %', n; end if;
   ```
   with
   ```text
       -- 623 -> 624: SPEC-300 (UBA-1) registered user_branch_assignment_changed at sort_order 936 --
       -- the record of a placement changed by UPDATE; `app.record_event` refuses an unregistered code.
       if n <> 624 then raise exception 'CHECK 6b FAILED: expected 624 catalog_values, found %', n; end if;
   ```

   c) replace the line
   ```text
       raise notice 'ALL CHECKS PASSED (78 tables, RLS + policies, resolver + read-scope model, 71/623 catalog, FK standard, updated_at triggers, append-only audit, grant/schema-usage completeness)';
   ```
   with
   ```text
       raise notice 'ALL CHECKS PASSED (78 tables, RLS + policies, resolver + read-scope model, 71/624 catalog, FK standard, updated_at triggers, append-only audit, grant/schema-usage completeness)';
   ```

   The resulting file's Git blob is 993bc5509e6776555aee8a97a2e47e49ab751802.

7. Check whether `_ORVION_CANONICAL/27_event_catalog.md` contains `## user_branch_assignment_changed`; if so record Already Applied when its Git blob is f2c20b57e9c0b6c8a306fe0eccc375e72a4e2701, and otherwise stop and report. Otherwise make exactly this one edit (the canon entry of the new code), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   ## user_branch_transfer_completed

   Severity: info

   ```
   insert
   ```text
   ## user_branch_assignment_changed

   Severity: security

   ```

   The resulting file's Git blob is f2c20b57e9c0b6c8a306fe0eccc375e72a4e2701.

8. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| UBA-1 |`; if so record Already Applied when its Git blob is 6744a126e5c588d02ce817d89fcf0326751115b8, and otherwise stop and report. Otherwise make exactly these 3 edits (the Slice 45 freshness entry, the USR-3 status and the UBA-1, UBA-3 and UBA-5 rows), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-09 (**Slice 44 — `approval_requests` selected live at Exposure 7, coverage 52; runner-up `user_branch_assignments` at 7/590.** **AR-1** (High), **AR-2** (Medium) and **AR-3** (Medium) are new and fixed. Two overlapping finance reviews of one request both succeeded, so a request ended `rejected` with its item's cost locked by the approval, and a concurrent approval overwrote a withdrawal; two overlapping requests opened two pending requests for one item; and the reviewer's direct table door turned a `rejected` request `approved` and approved one on a cancelled booking. SPEC-299 makes a decided request final on every door, makes an approval obey the parent-state rule on every door, and allows one pending finance request per item. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-11 (**Slice 45 — `user_branch_assignments` selected live at Exposure 7, coverage 596; runner-up `departments` at 7/660.** **UBA-1** (High), **UBA-3** (Medium) and **UBA-5** (Low) are new and fixed, and the `user_branch_assignments` half of **USR-3** (High) is fixed. A `ceo` at `aal1`, refused by `app.assign_user_branch`, added a branch and moved a colleague's primary placement by direct table writes; an UPDATE re-pointed, ended and handed over a placement with no event; and the table accepted a department of another branch and a placement that ends before it starts. SPEC-300 charges the RPC's authority on every door, records every placement change, and makes a placement's department belong to its branch and its end follow its start. USR-3 stays OPEN for `user_permission_grants`. No other row changed.)

   Previously: 2026-11-09 (**Slice 44 — `approval_requests` selected live at Exposure 7, coverage 52; runner-up `user_branch_assignments` at 7/590.** **AR-1** (High), **AR-2** (Medium) and **AR-3** (Medium) are new and fixed. Two overlapping finance reviews of one request both succeeded, so a request ended `rejected` with its item's cost locked by the approval, and a concurrent approval overwrote a withdrawal; two overlapping requests opened two pending requests for one item; and the reviewer's direct table door turned a `rejected` request `approved` and approved one on a cancelled booking. SPEC-299 makes a decided request final on every door, makes an approval obey the parent-state rule on every door, and allows one pending finance request per item. No other row changed.)
   ```

   b) immediately after the line
   ```text
   | AR-3 | **The reviewer's direct table door changed an approval request outside every rule the RPC keeps** | security / state | Medium | R | 6 | M | ✅ | **✅ FIXED 2026-11-09 (SPEC-299, `20261109120000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of this contract; the fresh Primary ledger, functions and structure equal local.** **MEASURED** at `a4fc1e1`: RLS `scope_update` opens the table to the reviewer the request type names, by design, but no rule bound what that door could write. After an RPC rejection, a finance manager's plain `update` turned the request `approved` (the item stayed `rejected`, no event), and approved a pending request on a CANCELLED booking that the RPC refuses. **Repaired:** the AR-1 guard holds on every door, and an approval of a booking-item request obeys the RPC's parent-state rule (item not archived, cancelled or no_show; booking not archived, completed or cancelled), 23514; a rejection stays possible. **Recorded positions, not repaired:** a direct approval of a still-pending request leaves the item pending with no cost lock and no event (an authorized reviewer, no money effect; reopening trigger: a consumer that reads the request instead of the item); a `ceo` or `owner` may approve their own request (separation of duties is an owner policy; reopening trigger: that policy); the RPC's requester-`cancelled` branch is unreachable because the item guard charges APPROVE_FINANCE (withdrawal covers the need). Pinned by `159_...` | — | SPEC-299-a-decided-approval-is-final | 11-09 | 11-09 |
   ```
   insert
   ```text
   | UBA-1 | **An UPDATE re-pointed, ended or handed over a placement with no record, so read scope moved silently** | security · audit | **High** | R | 6 | M | 🛡 | **FIXED 2026-11-11 locally (SPEC-300, `20261111120000`); Primary deployment pending.** **MEASURED** at `90a3a72` on the local stack: a stepped-up administrator's direct UPDATE re-pointed a primary placement from one branch to another (the user's visible branches moved), then ended it (visible branches empty), then handed the row to another user, with 0 events across the three; `user_branch_assignments_emit_transfer` fired AFTER INSERT only. **Repaired:** `app.emit_user_branch_transfer` also fires AFTER UPDATE when `user_id`, `branch_id`, `department_id`, `is_primary`, `starts_at` or `ends_at` moves, and records the new code `user_branch_assignment_changed` (severity security, `sort_order` 936, canon 27) with the previous and current placement, for both users when the row is handed over; an edit no reader consumes records nothing, and the RPC's own transfer is still recorded once. Not `user_branch_transfer_completed`: test 38 pins one transfer (end the old primary, insert the new) as one `_completed`, and reusing that code counted the end as a second transfer. The INSERT branch is unchanged. **Recorded positions, not repaired:** no RPC transfers or ends a placement (`app.assign_user_branch` with `p_is_primary` for a user whose primary is open is refused 23505 by `user_branch_assignments_one_primary_idx`), so a transfer is a table write by a stepped-up MANAGE_USERS holder, now guarded and recorded; reopening trigger: a transfer or offboarding flow in the product. The RPC places a user onto an inactive branch, which then joins their visible branches, and places an inactive user; reopening trigger: a branch or user lifecycle flow that must withdraw read scope. **Latent:** Primary and Founder Secondary held 0 placements. Pinned by `160_...` and mutant M2 (the UPDATE emitter removed), killed | — | SPEC-300-a-placement-changes-only-with-authority-and-a-record | 11-11 | 11-11 |
   | UBA-3 | **The table door accepted a department of another branch, which the RPC refuses, and the placed user's visible departments then included it** | integrity · authorization | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-11 locally (SPEC-300, `20261111120000`); Primary deployment pending.** **MEASURED** at `90a3a72`: `app.assign_user_branch` refused "department does not belong to branch"; a direct INSERT accepted a placement in one branch with a department of another, and `app.visible_department_ids()` then returned that department. Whether that department's business rows became readable was not measured. **Repaired:** the composite FK `user_branch_assignments_department_in_branch_fkey` (`tenant_id`, `branch_id`, `department_id`) to `departments` (`tenant_id`, `branch_id`, `id`), on the new unique key `departments_tenant_id_branch_id_id_key`; MATCH SIMPLE, so a placement without a department is unaffected; 23503 on every door. **Latent:** Primary and Founder Secondary held 0 placements and 0 mismatches. Pinned by `160_...` and mutant M3 (the FK dropped), killed | — | SPEC-300-a-placement-changes-only-with-authority-and-a-record | 11-11 | 11-11 |
   | UBA-5 | **A placement could end before it started** | data quality | Low | R | 6 | M | 🛡 | **FIXED 2026-11-11 locally (SPEC-300, `20261111120000`); Primary deployment pending.** **MEASURED** at `90a3a72`: a direct INSERT with `ends_at` a day before `starts_at` was accepted. **Repaired:** the CHECK `user_branch_assignments_ends_after_start_check` (`ends_at is null or ends_at >= starts_at`), 23514 on every door. Test 79's fixture, which ended a placement the day before it started, now starts it two days earlier. **Latent:** Primary and Founder Secondary held 0 placements. Pinned by `160_...` and mutant M4 (the CHECK dropped), killed | — | SPEC-300-a-placement-changes-only-with-authority-and-a-record | 11-11 | 11-11 |
   ```

   c) replace the line
   ```text
   | USR-3 | **`user_permission_grants` and `user_branch_assignments` charge no step-up at the table door — a `ceo` at `aal1` self-granted a permission and self-assigned a branch** | security · authorization | High | R | 6 | — | 📋 | **OPEN — a DIFFERENT SURFACE, deliberately not absorbed (Batch 6 slice 12).** MEASURED: a `ceo` at `aal1` self-granted `VIEW_ADVANCED_DASHBOARDS` on `public.user_permission_grants`, moving `app.has_permission` for it from false to **true**, and self-assigned an additional branch on `public.user_branch_assignments`. The same actor at the same `aal1` was refused `42501` on `public.user_role_assignments`, which is what makes these OUTLIERS rather than the norm — the precedent works, and these two tables are simply not behind it. **One precision that must not be lost:** the permission-grant door DID emit an event, so this gap is **step-up only, not audit** — the opposite balance from USR-1/USR-2, and a repairer who copies SPEC-203 wholesale would add an emitter that duplicates an existing one. **Not repaired here, and the boundary is mechanical, not rhetorical:** these are separate surfaces with their own defining migration (`202607059800`), which SPEC-203 names in its frozen Out of Scope. Widening a slice to absorb a neighbouring defect is what four cancelled predecessors did wrong. **Reopening trigger:** the next Batch-6 slice that selects either table, or any change to `202607059800` | — | SPEC-203-membership-authority-and-audit | 09-20 | 09-20 |
   ```
   with
   ```text
   | USR-3 | **`user_permission_grants` and `user_branch_assignments` charge no step-up at the table door — a `ceo` at `aal1` self-granted a permission and self-assigned a branch** | security · authorization | High | R | 6 | — | 📋 | **OPEN — the `user_permission_grants` half only.** The `user_branch_assignments` half FIXED 2026-11-11 locally (SPEC-300, `20261111120000`); Primary deployment pending. `app.guard_placement_authority` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, empty `search_path`, executable by no client role) charges `app.authorize('MANAGE_USERS')`, permission AND step-up, on every session write and every column, as `app.assign_user_branch` does; a session-less platform write is exempt, as in every sibling guard. Re-measured at `90a3a72` before the repair: the `aal1` `ceo` was refused by the RPC, then added a branch by direct INSERT and moved a colleague's primary from one branch and department to another by direct UPDATE; after it, both direct writes are refused 42501. Pinned by `160_...` assertions 3-4 and 15 and mutant M1 (the guard dropped), killed; `10_...` MEAS-2 now counts twelve bespoke-guard tables. The permission-grant half below is unchanged. Original text follows. **OPEN — a DIFFERENT SURFACE, deliberately not absorbed (Batch 6 slice 12).** MEASURED: a `ceo` at `aal1` self-granted `VIEW_ADVANCED_DASHBOARDS` on `public.user_permission_grants`, moving `app.has_permission` for it from false to **true**, and self-assigned an additional branch on `public.user_branch_assignments`. The same actor at the same `aal1` was refused `42501` on `public.user_role_assignments`, which is what makes these OUTLIERS rather than the norm — the precedent works, and these two tables are simply not behind it. **One precision that must not be lost:** the permission-grant door DID emit an event, so this gap is **step-up only, not audit** — the opposite balance from USR-1/USR-2, and a repairer who copies SPEC-203 wholesale would add an emitter that duplicates an existing one. **Not repaired here, and the boundary is mechanical, not rhetorical:** these are separate surfaces with their own defining migration (`202607059800`), which SPEC-203 names in its frozen Out of Scope. Widening a slice to absorb a neighbouring defect is what four cancelled predecessors did wrong. **Reopening trigger:** the next Batch-6 slice that selects either table, or any change to `202607059800` | — | SPEC-203-membership-authority-and-audit | 09-20 | 11-11 |
   ```

   The resulting file's Git blob is 6744a126e5c588d02ce817d89fcf0326751115b8.

9. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**46 of 78 recorded · 22 `; if so record Already Applied when its Git blob is b4c5c8d8be959ad262ef03b450204b33fdbd9e95, and otherwise stop and report. Otherwise make exactly these 4 edits (the freshness entry, coverage 46 of 78 and the user_branch_assignments row), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-09 (**slice 44 — `approval_requests` selected by Exposure 7, coverage 52; runner-up `user_branch_assignments` at 7/590.** Coverage **44 → 45 of 78**. AR-1: two overlapping finance reviews of one request both succeeded, and a concurrent approval overwrote a withdrawal, leaving a rejected or withdrawn request with its item's cost locked. AR-2: two overlapping requests opened two pending requests for one item. AR-3: the reviewer's direct table door rewrote a decided request and approved one on a cancelled booking. SPEC-299 closes all three, so the row is `AUDITED`, with its recorded positions and their reopening triggers. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-11 (**slice 45 — `user_branch_assignments` selected by Exposure 7, coverage 596; runner-up `departments` at 7/660.** Coverage **45 → 46 of 78**. USR-3 (this table's half): a `ceo` at `aal1` placed and moved users by direct table writes the RPC refuses at that level. UBA-1: an UPDATE re-pointed, ended and handed over a placement with no event. UBA-3: the table accepted a department of another branch. UBA-5: a placement could end before it started. SPEC-300 closes all four here, so the row is `AUDITED`, with its recorded positions and their reopening triggers; USR-3 stays open on `user_permission_grants`. No other row changed.)

   Previously: 2026-11-09 (**slice 44 — `approval_requests` selected by Exposure 7, coverage 52; runner-up `user_branch_assignments` at 7/590.** Coverage **44 → 45 of 78**. AR-1: two overlapping finance reviews of one request both succeeded, and a concurrent approval overwrote a withdrawal, leaving a rejected or withdrawn request with its item's cost locked. AR-2: two overlapping requests opened two pending requests for one item. AR-3: the reviewer's direct table door rewrote a decided request and approved one on a cancelled booking. SPEC-299 closes all three, so the row is `AUDITED`, with its recorded positions and their reopening triggers. No other row changed.)
   ```

   b) replace the line
   ```text
   **45 of 78 recorded · 21 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 33 `NOT-RECORDED`.**
   ```
   with
   ```text
   **46 of 78 recorded · 22 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 32 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 45 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 46 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `user_branch_assignments` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `user_branch_assignments` | **AUDITED** | ADVERSARIAL | `SPEC-300-a-placement-changes-only-with-authority-and-a-record` | USR-3, UBA-1, UBA-3, UBA-5 | `160_a_placement_changes_only_with_authority_and_a_record_test.sql` (17 assertions, ten attack classes declared, CONCURRENCY and REPLAY N/A) proves that a password-only (`aal1`) session is refused on the table door as by the RPC, on INSERT and UPDATE; that a department of another branch is refused 23503, a branch of another tenant 23503 and an end before the start 23514; that a stepped-up administrator still writes through the door; that a re-point, an end and a hand-over are each recorded as `user_branch_assignment_changed` with both placements and the actor, for both users on a hand-over, while an edit no reader consumes records nothing and the RPC's own transfer is recorded once; that an employee is still refused by RLS; and that a session-less platform write is exempt. Mutants M1 (guard dropped), M2 (UPDATE emitter removed), M3 (department FK dropped) and M4 (end CHECK dropped) were each killed on the prototype; the causal negative (all removed, the `90a3a72` schema) brought back every measured result. **Swept and sound:** an employee's direct update touches no row; DELETE has no grant; a forged `created_by` is replaced by the derived actor; the one race, two current primaries, is refused by `user_branch_assignments_one_primary_idx`. **Recorded positions, not repaired:** no RPC transfers or ends a placement, so a transfer is a guarded, recorded table write; reopening trigger: a transfer or offboarding flow. The RPC places onto an inactive branch or an inactive user; reopening trigger: a lifecycle flow that must withdraw read scope. USR-3's other half is `user_permission_grants`, its own surface. |
   ```

   The resulting file's Git blob is b4c5c8d8be959ad262ef03b450204b33fdbd9e95.

10. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, with Steps 1–9 applied and uncommitted in the main checkout, run with the project-local CLI and record, with actual counts, exits and exact SHA-256 values:
   - the SHA-256, md5 and byte counts of the migration and test 160, which must equal Consumer Closure;
   - on the local stack holding the migration: the guard's and the emitter's `md5(prosrc)`, security mode and ACL, both triggers, the three constraints and the new code; test 160 and tests 10, 38, 79 and 118 alone; the probes; mutants M1–M4, each restoration proven equal;
   - the causal negative on a local stack without the migration, then the stack restored with it;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migration;
   - the API-contract and map generators, the scope check and `git diff --check`.

   Treat as expected at this boundary only: an undeployed Primary, the API contract's moved `user_branch_assignments` row and the six measured-state items of Consumer Closure.

   Read a fresh Primary baseline, read-only: the project URL, the full ordered ledger and the absence of the target migration; the function and structural surfaces; the triggers of `user_branch_assignments`, the absence of the guard function, of the new code and of the three constraints; the tenant and placement counts, and the placements whose department belongs to another branch or that end before they start, which must be 0. Record the predicted delta. If any reading differs, stop.
11. **Check** that an exact-SHA Gate-2 record for the migration is in the Execution Log: the owner's own, or one marked DELEGATED naming this contract, the migration's SHA-256, Primary `vrvtsxexkiiiivlkdxzp` and the owner's instructions under which it is taken. If absent, write it only when Step 10 passed and those instructions cover a migration that drops no table or column and deletes or rewrites no business row; otherwise stop after Step 10 and present the Gate-2 package.
12. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261111120000_a_placement_changes_only_with_authority_and_a_record`. If it is absent and Step 11 is recorded:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, the mismatch and end-before-start counts and the triggers of `user_branch_assignments`.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the triggers of `user_branch_assignments` and the three constraints; the guard's and the emitter's `md5(prosrc)`, security mode and ACL; the new code; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
13. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the client RPC figure unchanged.
   - Confirm that `supabase/tests` holds 160 files whose literal `plan(N)` values sum to 3041, then set `Suite **160 files / 3041 assertions**`. If either differs, stop.
   - In each of the three rows UBA-1, UBA-3 and UBA-5 of the register, replace the text `` | 🛡 | **FIXED 2026-11-11 locally (SPEC-300, `20261111120000`); Primary deployment pending.** `` with `` | ✅ | **✅ FIXED 2026-11-11 (SPEC-300, `20261111120000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-300; the fresh Primary ledger, functions and structure equal local.** `` (each span's one leading and one trailing space are delimiters, not text). In the USR-3 row, replace the text `half FIXED 2026-11-11 locally (SPEC-300, `20261111120000`); Primary deployment pending.` with `half FIXED 2026-11-11 (SPEC-300, `20261111120000`) and DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-300.` Change nothing else in the register.
   - Regenerate `MASTER_API_CONTRACT.md`, `ai-map.json` and `repository-index.md` (stored LF) with the canonical generators.
   - Run the four `scripts/test_*_guard.ps1` and require each to pass.
   - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once; the pre-commit Gate must admit it.

   If Primary is unproven, stop.
14. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, in the Complete commit: transition to Complete, tick the Acceptance Criteria and the Review Gate, clear `Active Change Request`, set `Last Completed` from Notes, leave `Next capability` and `Current Module` unchanged, and regenerate `ai-map.json` and `repository-index.md` LF.
   - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] The migration is the frozen bytes; `check: blob supabase/migrations/20261111120000_a_placement_changes_only_with_authority_and_a_record.sql 3d6987cf6052c4a455a3352d29b11d502cfaa0cd`
- [ ] Test 160 is the frozen bytes; `check: blob supabase/tests/160_a_placement_changes_only_with_authority_and_a_record_test.sql 52a514903559196adc104c41ced2b7ebd4eb2efa`
- [ ] The disposition record carries `user_branch_assignments` AUDITED / ADVERSARIAL and coverage 46 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md b4c5c8d8be959ad262ef03b450204b33fdbd9e95`
- [ ] USR-3's half, UBA-1, UBA-3 and UBA-5 are fixed and deployed in the register; `check: has reports/master/MASTER_GAP_REGISTER.md "DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-300"`
- [ ] The smoke count includes the new code; `check: has scripts/verify_database.sql "expected 624 catalog_values"`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **160 files / 3041 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @90a3a7212b5cd3380f0dc3c746b03c085ae7613c`
- [ ] The originating placement RPC migration remains exact; `check: same supabase/migrations/202607044100_mfa_requirement_enforcement.sql @90a3a7212b5cd3380f0dc3c746b03c085ae7613c`
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write, after a recorded Step 10 readiness gate and Step 11 Gate-2 record; Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] Mutants M1–M4 are each killed with installation and restoration proven, and the causal negative is recorded.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-300: Batch 6 Slice 45 — a placement changes only with authority and a record (USR-3 placement half, UBA-1, UBA-3, UBA-5), deployed to Primary; native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline 90a3a7212b5cd3380f0dc3c746b03c085ae7613c and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/10_grant_model_test.sql` | `36dfceb92dbc0c707a0418e5ec2a269f9025f487` |
| `supabase/tests/38_class_a_events_test.sql` | `d9af38617a639ec5cc8f87fd72409208cf00a315` |
| `supabase/tests/79_customer_data_integrity_test.sql` | `5e827a86a7008d67aba8e8b7047bfd07f6230ddb` |
| `scripts/verify_database.sql` | `d035dd71475ef39a9f81f5e1ad61190c9e913f1b` |
| `_ORVION_CANONICAL/27_event_catalog.md` | `24d71f718bb96fbf89fda4a715dbcf99a3d8699f` |
| `reports/master/MASTER_GAP_REGISTER.md` | `bc6a191e65c8777fc99d78f1370954b3cfaf41d4` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `196c55813a8c1afcccf01ca4d3b293d1c00538f1` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md and SPEC-299 at 90a3a7212b5cd3380f0dc3c746b03c085ae7613c; the owner's instructions of 2026-11-08 and 2026-11-11 (recorded outside this repository). Three identified snapshots and selection reasons are retained externally; correctness remains native and independent.

Snapshot identities: V1 A17D657048C7E45680A22AF42A3B004A819CDA9FFB43232B4BC3E38AEC9A4C15; V2 B09BFC6340B8D814C67F30508B328DF8CF9B7E025E66AAD7068A329D036A1452. V3 adds this linkage and the final selection; its own SHA-256 is external.
