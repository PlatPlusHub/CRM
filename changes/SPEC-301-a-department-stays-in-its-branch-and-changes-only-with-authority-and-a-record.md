# Change Request — SPEC-301

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 46 makes a department change only with the authority its RPC charges, records every department change on every door, and fixes a department's branch for life (DEP-1, DEP-2, DEP-3; the `departments` member of STEPUP-1).

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `2e05d41`, on the live local catalog, ranks `departments` first: Exposure 7, coverage 666, NOT-RECORDED (runner-up `user_role_assignments` 7/678). The manifest's Next capability names that selector, never a copy of its result.
- **Why it matters.** Every row filed under a department (leads, bookings, tasks, complaints, service requests, conversations, suppliers, placements) and department read scope (`app.visible_department_ids`) depend on it. `app.create_department` charges `app.authorize('MANAGE_DEPARTMENTS')`, permission AND step-up, and records `department_created`. The table door charges RLS `app.has_permission('MANAGE_DEPARTMENTS')` only, no trigger records anything, and no RPC renames, re-types, deactivates or moves a department, so every such change is a table write.
- **Measured at `2e05d41`** on the local stack, committed probe fixtures (owner, ceo and two employee actors):
  - **DEP-1 (Medium), the `departments` member of STEPUP-1.** A `ceo` at `aal1` was refused by the RPC ("multi-factor authentication required"), then created a department by direct INSERT, renamed and re-typed another by direct UPDATE, deactivated it, and moved a third to another branch.
  - **DEP-2 (Low).** The door's INSERT and all three UPDATEs recorded 0 events; the RPC is the only producer of `department_created`, and no department change has ever been recorded.
  - **DEP-3 (Medium).** `app.create_lead`, `app.create_booking`, `app.assign_user_branch` and `app.link_internal_supplier` each require the department to belong to the row's branch, but 17 of the 18 foreign keys into `departments` reference (`tenant_id`, `id`) only; only SPEC-300's placement FK pins the branch. An unplaced department moved from one branch to another: its lead stayed at the old branch and the moved department, a pair `app.create_lead` then refused; an employee the RPC placed at the department's new branch did not see that lead; and no department reader can be placed at the old pair again.
- **The repair**, in the SPEC-203 / SPEC-300 shape: authority is a precondition and runs BEFORE; the record is a fact and runs AFTER.
  - `app.guard_department_write`, BEFORE INSERT OR UPDATE (SECURITY DEFINER, empty `search_path`, executable by no client role): an UPDATE that changes `branch_id` is refused 23514 on every path, with or without a session; then `app.authorize('MANAGE_DEPARTMENTS')` on every session write and every column. A write with no session (migrations, seeds, the platform) is exempt from the charge, as in every sibling guard.
  - `app.emit_department_change`, AFTER INSERT OR UPDATE, session writes only: an INSERT records `department_created` with the RPC's payload; an UPDATE records the new code `department_changed` (severity info, `sort_order` 937, canon 27 entry) with the previous and current name, type and active flag, when one of them moves. `app.create_department` keeps every check and its insert and drops its own `app.record_event` call, so the act is recorded once on either door.
  - No grant, policy, FK, `enforce_catalog_codes` or other RPC changes.
- **Existing files that move, each for a stated reason.** `10_grant_model_test.sql`: the MEAS-2 inventory of bespoke-guard tables goes from twelve to thirteen; the assertion exists to force this justification. `scripts/verify_database.sql`: CHECK 6b 624 to 625 catalog values. `_ORVION_CANONICAL/27_event_catalog.md`: the new code's entry. No other test moves.
- **Swept and found sound, pinned rather than changed:** an employee's direct write is refused by RLS (INSERT) or touches no row (UPDATE); a branch of another tenant is refused by the tenant-composite FK; DELETE has no grant, so `scope_delete` is inert; a tenant move is refused by RLS; an unknown `department_type_code` is refused by the catalog trigger; two active departments of one name in a branch are refused by `departments_unique_name_per_branch_idx`.
- **Recorded position, not repaired:** `is_active` binds nothing: `app.create_lead` and `app.assign_user_branch` accepted an inactive department, and no function reads `departments.is_active`, `name` or `department_type_code`. Refusing inactive departments is a behaviour addition to five RPCs with no consumer (the UBA-4 precedent); reopening trigger: a department lifecycle flow that must stop new work in a closed department.
- **Latent on Primary:** `vrvtsxexkiiiivlkdxzp` holds 0 tenants and 0 departments (read-only, 2026-11-11, ledger 256), so no stored row meets the new guard and no data repair is needed.

## Risks

- **A session write without the step-up now fails on the table door** (42501), as it already did through the RPC. No migration other than the RPC writes this table with a session; the seeds of the declared and undeclared journey suites write without one and pass.
- **A department can no longer change branch.** No writer moves `departments.branch_id`; a move is a new department in the other branch.
- **Primary deployment is irreversible** and runs only under the exact-SHA Gate-2 record of Step 9. Approval of this contract does not authorize it. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.
- **Gate 1 and Gate 2 of this contract are DELEGATED** under the owner's instructions (class authorization for Batch 6 releases and standing approval of proposals, 2026-11-08 ~10:20 Cairo; publish, promote and hosted deploy ~12:05; run mode 2, "run through" to both products' publish, promote and remote Certify, for slice 4, 2026-11-11 ~10:50 Cairo), recorded outside this repository; never a human-typed digest.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-301-a-department-stays-in-its-branch-and-changes-only-with-authority-and-a-record.md`
- `supabase/migrations/20261111130000_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record.sql`
- `supabase/tests/161_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record_test.sql`
- `supabase/tests/10_grant_model_test.sql`
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
- `supabase/migrations/202607049600_identity_event_emission.sql`
- `supabase/migrations/202607051400_read_scope_model.sql`
- `supabase/migrations/20260920120000_membership_authority_and_audit.sql`
- `supabase/migrations/20261111120000_a_placement_changes_only_with_authority_and_a_record.sql`
- `supabase/tests/21_read_scope_model_test.sql`
- `supabase/tests/38_class_a_events_test.sql`
- `supabase/tests/53_api_surface_test.sql`
- `supabase/tests/76_tenant_administration_test.sql`
- `supabase/tests/130_branch_door_audit_test.sql`
- `supabase/tests/160_a_placement_changes_only_with_authority_and_a_record_test.sql`
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
- `supabase/migrations/202607044100_mfa_requirement_enforcement.sql` and `202607049600_identity_event_emission.sql` (`app.create_department`, the one writer, and its record)
- `supabase/migrations/202607051400_read_scope_model.sql` (the readers) and `20261111120000_a_placement_changes_only_with_authority_and_a_record.sql` (the SPEC-300 shape and the one branch-pinning FK)
- `reports/master/MASTER_GAP_REGISTER.md` (STEPUP-1, BRANCH-1, BRANCH-2); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method, EC-1…EC-11
- `changes/SPEC-300-a-placement-changes-only-with-authority-and-a-record.md` (the last Primary-deploying slice)

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

Pass 1 Design: SPEC-301-V1 adds a guard that fixes a department's branch and charges the RPC's authority on every session write, an emitter that records a creation on either door and a change with a new event code, and moves the RPC's own record into it; test 161 pins each on the table door, the stepped-up and session-less controls, an edit that records nothing and the RPC's single record; test 10 and the smoke count move with stated reasons; the register and disposition record DEP-1, DEP-2, DEP-3, the STEPUP-1 member and the surface.

Pass 2 Adversarial Review: SPEC-301-V2 challenged each part on the prototype. Charging the step-up in the RLS policy was rejected: a policy filters rows instead of raising, so an UPDATE at `aal1` would touch 0 rows and look like success, and SPEC-203 set the BEFORE-trigger shape. Revoking INSERT and UPDATE from `authenticated` (the SPEC-246 shape) was rejected: no RPC renames, re-types or deactivates a department, so the revoke would remove a working administrator flow, and adding those RPCs is a behaviour addition. Repairing DEP-3 with composite FKs on the 17 referencing tables, or by moving the filed rows with the department, was rejected: seventeen new keys and indexes, or a rewrite of business rows across seventeen tables, against one refusal on the one table; no writer moves a department's branch. Keeping the RPC's own `record_event` beside the trigger was rejected: the RPC's creation would be recorded twice; test 161 assertion 12 pins exactly one. Emitting on every UPDATE was rejected: only name, type and active flag carry meaning, and churn would bury the record. Refusing inactive departments in five RPCs was rejected for this slice: a behaviour addition with no consumer, recorded with its reopening trigger. Attacks run on the final bytes: no migration other than the RPC writes the table with a session, and the three undeclared journey suites, whose seeds write departments without one and one of which calls `create_department` over HTTP, pass (`verify_care_journeys` 40/0, `verify_role_journeys` 122/0, `verify_storage_end_to_end` 60/0); test 161 carries assertion 13 (a branch of another tenant is refused, so TENANT is earned) and assertion 17 (the branch is fixed on the session-less path too); the generated API contract moves `departments` from `no | no` to `yes | conditional`, so `MASTER_API_CONTRACT.md` is regenerated in Step 11. Copying the selector's next target into the manifest was rejected (SPEC-270; SPEC-278's cancellation).

Pass 3 Evidence Refresh: 2026-11-11. SPEC-301-V3 re-measured on byte-identical files in a disposable clone of `2e05d41` with the project-local CLI 3.0.0: the clean reset, test 161 and tests 10, 38 and 130 alone, pgTAP Pass A and B, the three declared HTTP suites, smoke, the probes, all three mutants, the causal negative, the structural fingerprints before and after, the generators and repository consistency; and read Primary and Founder Secondary read-only for their ledgers and departments.

Selected Version: SPEC-301-V3; selected: the smallest repair that closes DEP-1, DEP-2 and DEP-3 on every door (one guard that charges the RPC's authority and fixes the branch, one emitter with one new code, the RPC's own record moved into it; no grant, policy or FK changed), proven on byte-identical files by the full local protocol, three killed mutants, the probes and the causal negative

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A department write charges `app.authorize('MANAGE_DEPARTMENTS')` on every door, and its branch is fixed | `app.create_department`; the administrator's table door (RLS insert and update); any platform writer | WRITE | Migration SHA-256 `bc7aa0022f8f7b53273f671da5c06a8a5af450c65f7058a28e8290119842eb56`, md5 `8586c0612a656e142b2f2aa8838c5bce`, 7985 bytes, LF, ASCII. A clean reset gives 257 migrations, latest `20261111130000`, guard `md5(prosrc)` `040f97565abd992a60f03231d1c7fe85`, SECURITY DEFINER, ACL `{postgres=X/postgres}`; both triggers fire on INSERT and UPDATE. |
| Every department change is recorded once | readers of `public.events`; canon 27; `catalog_values` (`event_type`); `app.create_department` | WRITE | Emitter `md5(prosrc)` `35d9ec237237cd98d4d6b6439a060f54`, SECURITY DEFINER, ACL `{postgres=X/postgres}`; the RPC's `md5(prosrc)` `42218ed9c7b2737a0154c4b1e2cee53c` → `8365ffa3a5dbdce5da337e4e55896eb4` (its record call removed, every check kept); one new code at `sort_order` 937, catalog 71/624 → 71/625. |
| The readers of departments | `app.create_lead`; `app.create_booking`; `app.assign_user_branch`; `app.link_internal_supplier`; `app.guard_internal_supplier_link`; `app.create_task`; `app.visible_department_ids`; SPEC-300's placement FK; tests 21, 38, 53, 76, 130, 160 | VERIFY | No body changes; every pgTAP file passes; the undeclared journeys `verify_care_journeys` 40/0, `verify_role_journeys` 122/0, `verify_storage_end_to_end` 60/0. |
| Test 161 | `supabase/tests` | WRITE | SHA-256 `d23e546ae647a29e40dbbf2bb4e65b6685d419a70d3a282da52fb32d94c3aeaf`, md5 `3a0bf66f5e358999eb8e879eb10aa29e`, 8559 bytes, LF, ASCII, `plan(17)`: 17/17. |
| Test 10 | the MEAS-2 inventory | WRITE | The edit and its reason in Business Reason; it passes alone (9 assertions). |
| Other tests and the suite | the full pgTAP suite; the HTTP suites | VERIFY | Pass A `Files=161, Tests=3058`, PASS; HTTP 35/0, 85/0, 122/0; Pass B 161/3058, PASS. 161 files whose literal `plan(N)` values sum to 3058. |
| Smoke | `scripts/verify_database.sql` | WRITE | CHECK 6b expects 625 catalog values; `ALL CHECKS PASSED` (78 tables, 71/625 catalog). |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Before (256): functions `965f9695147a4dcba08ca71cd9f4a4d3`/334, `_combined` `6ce7270e06e890832c53c505d4976a49`/3146, equal to the recorded Primary evidence. After (257): functions `5d50b5ba57ec83e66c6ad492a22ff050`/336 (+2), triggers `59b4283fc37e2bd9f997b84744139f27`/323 (+2), `_combined` `acaa0b419371eb704cc531ad84769485`/3150; policies, constraints, grants, columns, views, indexes, status transitions and RLS unchanged. Step 11 writes Primary values only from fresh post-deploy readings. |
| Client API | `MASTER_API_CONTRACT.md` (Check L3) | WRITE | No RPC is added, removed or changed in signature; the guard and the emitter are trigger functions executable by no client role. The generator's table-surface row for `departments` moves from insert guard `no`, update guard `no` to `yes`, `conditional`, as for `user_branch_assignments`; Step 11 regenerates it. |
| Measured state that moves | manifest `Live state` and suite figure; `primary-ledger-evidence.json`; `ai-map.json` and `repository-index.md` | WRITE | 256 → 257 migrations, latest `20261111130000`, ledger fingerprint `ed3211eac78a43cdcf04f44235d5516d`; 160 → 161 files and 3041 → 3058 assertions; coverage 46 → 47 of 78. Tables 78 and client RPCs 80 do not move. `Next capability` and `Current Module` stay unchanged (selector form). |
| The pinned manifest lines `Current Module`, `Next capability` and `Batch 6 surface coverage` | native Boot; `scripts/batch6_select_target.ps1` and `MASTER_SURFACE_DISPOSITION.md`, which own their values (GOVERNANCE.md §6 rule 10) | UNAFFECTED | Step 12 names `Current Module` and `Next capability` only to leave them unchanged; each line keeps its ratified text and pin, so the selector and the disposition record name the next slice and the coverage. |
| DEP-1, DEP-2 and DEP-3 fixed; STEPUP-1's member closed; the surface recorded | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25, 29 | WRITE | No `DEP-` row exists at `2e05d41`. STEPUP-1 stays open for its other members; the note records that `departments` no longer meets its criterion. Test 161's `-- ATTACK-CLASSES:` line declares ten classes with CONCURRENCY and REPLAY `=N/A` and carries negative assertions, so Check 24 admits `ADVERSARIAL`. Each DEP row has Owner `—` and is settled. Coverage 47: 23 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 31 `NOT-RECORDED`; all 47 `ADVERSARIAL`. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | With Steps 1–7 applied and the contract present, consistency reports exactly six measured-state items (256 vs 257 migrations, latest, ledger fingerprint, 160 vs 161 files, 3041 vs 3058 assertions, the Primary-evidence record) and Checks 21–29 pass. Step 11 makes them true; the one implementation commit is made only after it. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 10 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The applied files equal the verified bytes, and the focused tests, probes, mutants and causal negative hold | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 8 |
| Primary lacks the target migration and its ledger and structure equal the recorded evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 10 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 11 | Step 12 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 11 | Step 12 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 11 | Step 12 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 11 | Step 12 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.create_department` charges `app.authorize('MANAGE_DEPARTMENTS')` and records `department_created`, but it only inserts; the table's RLS insert and update policies charge `app.has_permission('MANAGE_DEPARTMENTS')` with no step-up; no trigger records a department write; the (`tenant_id`, `branch_id`) FK binds the branch to the tenant but nothing fixes it. `guard_write_capability` has no mapping for this table.

Added Property: For every end-user writer, a department is written only with permission AND step-up, every creation and every change of name, type or active flag is recorded once with the actor, and a department never leaves its branch on any path.

Causal Negative: On the stack with the guard, the emitter, their functions and triggers removed and the RPC's own record back (the `2e05d41` schema), test 161 fails assertions 1, 3–6, 8–10 and 17, and the probes return: the `aal1` direct INSERT, rename, re-type and deactivation succeed with 0 events, and an unplaced department moves to another branch, stranding its lead at a pair `app.create_lead` refuses.

Positive Test Design: One tenant with a `ceo` and an employee, two branches, two departments; a second tenant with one branch. Positive controls: the stepped-up `ceo` writes through the table door and renames and deactivates; the RPC creates a department; an edit that moves no name, type or active flag lands; a session-less platform write lands.

Negative Test Design:
- **Auth:** at `aal1` the RPC, the direct INSERT and the direct UPDATE are each refused 42501.
- **Business:** a branch move is refused 23514 and the branch is unchanged.
- **State:** the branch move is refused on the session-less path too.
- **Tenant:** a branch of another tenant is refused 23503.
- **Privilege:** an employee is refused by RLS.
- **Observability:** a door creation records `department_created` with the actor; a rename and deactivation records `department_changed` once with both states and the actor; an edit that moves none records nothing; the RPC's own creation is recorded once; a session-less write records nothing.

Non-Empty Population Obligation: The fixture holds two tenants, two users, three branches and two departments before the first assertion. Each refusal is asserted by exact SQLSTATE and each record by an exact count.

Mutation Obligation: Each mutant is installed on the prototype stack, proven installed by a changed fingerprint (guard and emitter trigger counts, `md5` of the guard, emitter and RPC bodies), run against test 161 and the probes, then restored and proven equal (`guard=1 emit=1 fn=7b1b4393`) with 17/17 before the next. A mutant not proven installed is a harness error, never a kill.

| Mutant | Change | Killed on the prototype by |
| --- | --- | --- |
| M1 | the guard's step-up charge removed (branch fix kept) | 161 assertions 3–4; the `aal1` direct INSERT and UPDATEs succeed again |
| M2 | the guard's branch fix removed (charge kept) | 161 assertions 5–6 and 17; the probe's unplaced department moves |
| M3 | the emitter trigger dropped | 161 assertions 1, 8–10 and 12; every door write and the RPC record 0 events |

Post-Implementation Proof Obligation: All of the following on the final bytes, through canonical `-Finish` from the main checkout with the project-local CLI: the clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke; the generated artifacts, repository consistency and the recorded Primary evidence. Before Step 10: the focused tests, the probes, the mutants, the causal negative and the fresh Primary baseline of Step 8.

## Implementation Steps

1. Check whether `supabase/migrations/20261111130000_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record.sql` contains `Batch 6 slice 4 (DEP-1, DEP-2, DEP-3)`; if so record Already Applied when its Git blob is e5c56ad2f2df4ee0a4b62e695fa34a16d5918ea2, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the migration: the department guard, the emitter and its code, and the RPC without its own record), and change nothing else:

   ```text
   -- Batch 6 slice 4 (DEP-1, DEP-2, DEP-3) -- a department stays in its branch, and changes only with
   -- the RPC's authority and a record on every door.
   --
   -- =================================================================================================
   -- THE MEASURED DEFECTS (2026-11-11 at 2e05d41 on the local stack, committed probe fixtures)
   --
   -- DEP-1 `app.create_department` charges `app.authorize('MANAGE_DEPARTMENTS')` (permission AND
   --      step-up); the table's RLS charges `app.has_permission` only. A `ceo` at `aal1` was refused by
   --      the RPC, then created a department, renamed and re-typed another, deactivated it and moved a
   --      third to another branch, all by direct INSERT and UPDATE. A member of STEPUP-1.
   -- DEP-2 The only `department_created` producer is the RPC: the door's INSERT recorded nothing, and no
   --      UPDATE (rename, re-type, deactivation, branch move) has ever been recorded on any door.
   -- DEP-3 A department's branch could be moved. Every writer that files work under a department
   --      (`app.create_lead`, `app.create_booking`, `app.assign_user_branch`, `app.link_internal_supplier`)
   --      requires the department to belong to the row's branch, but 17 of the 18 inbound foreign keys
   --      reference (tenant_id, id) only. Moving an unplaced department left its lead at (old branch,
   --      department), a pair `app.create_lead` now refuses; the department's new-branch employee could
   --      not see it, and no department-queue reader can ever be placed at the old pair again (the RPC
   --      and SPEC-300's composite FK both refuse it). Only a placed department was pinned (SPEC-300 FK).
   --
   -- =================================================================================================
   -- THE REPAIR, IN THE SPEC-203 / SPEC-300 SHAPE: authority is a precondition and runs BEFORE; the
   -- record is a fact and runs AFTER.
   --
   -- 1. `app.guard_department_write`, BEFORE INSERT OR UPDATE:
   --    - a department's branch is fixed for life (DEP-3): an UPDATE that changes `branch_id` is refused
   --      23514 on every path, with or without a session. A "move" is a new department in the other
   --      branch. With the branch fixed, the tenant is fixed too (the (tenant_id, branch_id) FK).
   --    - `app.authorize('MANAGE_DEPARTMENTS')` on every session write, every column (DEP-1). No session
   --      (migrations, seeds, provisioning, service_role): no charge, as in every sibling guard.
   -- 2. `app.emit_department_change`, AFTER INSERT OR UPDATE, session writes only (a platform write
   --    recorded nothing before and records nothing now):
   --    - INSERT records `department_created` with the RPC's exact arguments and payload. The RPC's own
   --      `app.record_event` call is removed in the same migration, so the act is recorded once on
   --      either door (one producer, the SUP-5 shape).
   --    - UPDATE records the NEW code `department_changed` (info) with the previous and current name,
   --      type and active flag, when one of them moves; an UPDATE that moves none records nothing.
   --
   -- DELETE is not included: `authenticated` holds no DELETE on this table, so `scope_delete` is inert.
   -- POSITION, not changed here (a behaviour addition to five RPCs, the UBA-4 precedent): `is_active`
   -- binds nothing; `app.create_lead` and `app.assign_user_branch` accepted an inactive department, and
   -- no function reads `departments.is_active`, `name` or `department_type_code`.
   -- NOT CHANGED: every grant and policy, `enforce_catalog_codes`, `departments_set_updated_at`, and the
   -- RPC's checks and insert.
   -- Hosted rows at the time of writing (read-only, ledger 256): 0 departments on Primary and on
   -- Founder Secondary.
   -- =================================================================================================

   -- Vocabulary. `sort_order` 937 is MEASURED: `event_type` holds 189 rows, maximum 936. Canon 27 gains
   -- the matching entry.
   insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
   select null::uuid, 'event_type', 'department_changed', 'Department Changed', 937, true, true
   where not exists (
       select 1 from public.catalog_values cv
       where cv.catalog_type_code = 'event_type' and cv.code = 'department_changed' and cv.tenant_id is null
   );

   -- `old` is read only inside the UPDATE branch (the SPEC-159-A 55000 failure mode).
   create or replace function app.guard_department_write()
   returns trigger
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   begin
       if tg_op = 'UPDATE' then
           if new.branch_id is distinct from old.branch_id then
               raise exception 'a department belongs to one branch for life; create a department in the other branch'
                   using errcode = '23514';
           end if;
       end if;
       if (select auth.uid()) is null then
           return new;
       end if;
       perform app.authorize('MANAGE_DEPARTMENTS');
       return new;
   end;
   $fn$;

   revoke execute on function app.guard_department_write() from public;

   create trigger departments_guard_write
       before insert or update on public.departments
       for each row execute function app.guard_department_write();

   create or replace function app.emit_department_change()
   returns trigger
   language plpgsql
   security definer
   set search_path = ''
   as $fn$
   declare
       v_prev jsonb;
       v_next jsonb;
   begin
       if (select auth.uid()) is null then
           return null;
       end if;

       if tg_op = 'INSERT' then
           perform app.record_event(
               new.tenant_id, 'department_created', 'department', new.id, null,
               null, case when new.is_active then 'active' else 'inactive' end, null,
               jsonb_build_object('branch_id', new.branch_id, 'department_type_code', new.department_type_code,
                                  'name', new.name),
               'info');
           return null;
       end if;

       v_prev := jsonb_build_object('name', old.name, 'department_type_code', old.department_type_code,
           'is_active', old.is_active);
       v_next := jsonb_build_object('name', new.name, 'department_type_code', new.department_type_code,
           'is_active', new.is_active);
       if v_prev = v_next then
           return null;
       end if;

       perform app.record_event(
           new.tenant_id, 'department_changed', 'department', new.id, null,
           case when old.is_active then 'active' else 'inactive' end,
           case when new.is_active then 'active' else 'inactive' end, null,
           jsonb_build_object('branch_id', new.branch_id, 'previous', v_prev, 'current', v_next),
           'info');
       return null;
   end;
   $fn$;

   revoke execute on function app.emit_department_change() from public;

   create trigger departments_emit_change
       after insert or update on public.departments
       for each row execute function app.emit_department_change();

   -- The RPC's checks and insert are unchanged; its `department_created` is now the trigger's.
   create or replace function app.create_department(p_branch_id uuid, p_department_type_code text, p_name text)
   returns uuid
   language plpgsql
   set search_path = ''
   as $function$
   declare
       v_tenant uuid := app.current_tenant_id();
       v_department uuid;
   begin
       if v_tenant is null then
           raise exception 'no active tenant for caller';
       end if;
       perform app.authorize('MANAGE_DEPARTMENTS');

       if not exists (
           select 1 from public.branches where id = p_branch_id and tenant_id = v_tenant
       ) then
           raise exception 'branch is not in your tenant';
       end if;

       if not exists (
           select 1 from public.catalog_values
           where catalog_type_code = 'department_type' and code = p_department_type_code
       ) then
           raise exception 'unknown department_type_code: %', p_department_type_code;
       end if;

       insert into public.departments (tenant_id, branch_id, department_type_code, name, is_active)
       values (v_tenant, p_branch_id, p_department_type_code, p_name, true)
       returning id into v_department;

       return v_department;
   end;
   $function$;
   ```

   The resulting file's Git blob is e5c56ad2f2df4ee0a4b62e695fa34a16d5918ea2.

2. Check whether `supabase/tests/161_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record_test.sql` contains `plan(17)`; if so record Already Applied when its Git blob is 4eb38bf030a2909c7b59cdd8c89620279d09ed87, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (test 161, 17 assertions), and change nothing else:

   ```text
   -- pgTAP: Batch 6 slice 4 (DEP-1, DEP-2, DEP-3) --
   -- a department stays in its branch, and changes only with the RPC's authority and a record on
   -- every door (`20261111130000`).
   -- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY
   --   CONCURRENCY=N/A -- the one race on this table, two active departments of one name in a branch, is
   --     refused by the existing partial unique index; nothing here adds or relies on ordering.
   --   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(17);

   insert into auth.users (id, email) values
     ('16100000-0000-0000-0000-0000000000a1','ceo@c161.test'),
     ('16100000-0000-0000-0000-0000000000a2','u1@c161.test');
   insert into public.tenants (id, name, slug, status) values
     ('16100000-0000-0000-0000-000000000001','Department Travel','department-travel-161','active'),
     ('16100000-0000-0000-0000-000000000002','Other Travel','other-travel-161','active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '16100000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug) values
     ('16100000-0000-0000-0000-0000000000b1','16100000-0000-0000-0000-000000000001','B1','b1-161'),
     ('16100000-0000-0000-0000-0000000000b2','16100000-0000-0000-0000-000000000001','B2','b2-161'),
     ('16100000-0000-0000-0000-0000000000b9','16100000-0000-0000-0000-000000000002','B9','b9-161');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
     ('16100000-0000-0000-0000-0000000000d1','16100000-0000-0000-0000-000000000001','16100000-0000-0000-0000-0000000000b1','sales','S1'),
     ('16100000-0000-0000-0000-0000000000d3','16100000-0000-0000-0000-000000000001','16100000-0000-0000-0000-0000000000b1','operations','O3');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
     ('16100000-0000-0000-0000-000000000011','16100000-0000-0000-0000-000000000001','CEO','ceo@c161.test',true,'16100000-0000-0000-0000-0000000000a1'),
     ('16100000-0000-0000-0000-000000000012','16100000-0000-0000-0000-000000000001','U1','u1@c161.test',true,'16100000-0000-0000-0000-0000000000a2');
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '16100000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
   from (values ('16100000-0000-0000-0000-000000000011'::uuid,'ceo'),
                ('16100000-0000-0000-0000-000000000012'::uuid,'employee')) v(uid, role_code)
   join public.roles r on r.code = v.role_code;

   select is(
     (select count(*)::int from pg_trigger
      where tgrelid = 'public.departments'::regclass and not tgisinternal
        and tgname in ('departments_guard_write', 'departments_emit_change')
        and pg_get_triggerdef(oid) like '%INSERT OR UPDATE%'),
     2,
     'the guard and the emitter both fire on INSERT and UPDATE');

   -- The ceo at aal1: the RPC refuses (control), and now so does the table door.
   set local role authenticated;
   select set_config('request.jwt.claims', '{"sub":"16100000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
   select throws_ok(
     $$select app.create_department('16100000-0000-0000-0000-0000000000b1', 'sales', 'RPC aal1')$$,
     '42501', null,
     'control: the RPC refuses a password-only session');
   select throws_ok(
     $$insert into public.departments (tenant_id, branch_id, department_type_code, name)
       values ('16100000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-0000000000b2', 'sales', 'Door aal1')$$,
     '42501', null,
     'DEP-1: the direct INSERT at aal1 is refused too (measured before the repair: created)');
   select throws_ok(
     $$update public.departments set name = 'Hijacked', is_active = false where id = '16100000-0000-0000-0000-0000000000d1'$$,
     '42501', null,
     'DEP-1: the direct UPDATE at aal1 is refused too (measured before the repair: renamed and deactivated)');

   -- The ceo at aal2.
   select set_config('request.jwt.claims', '{"sub":"16100000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
   select throws_ok(
     $$update public.departments set branch_id = '16100000-0000-0000-0000-0000000000b2' where id = '16100000-0000-0000-0000-0000000000d3'$$,
     '23514', null,
     'DEP-3: a department cannot move to another branch, even unplaced (measured before the repair: moved, stranding its lead)');
   select is(
     (select branch_id::text from public.departments where id = '16100000-0000-0000-0000-0000000000d3'),
     '16100000-0000-0000-0000-0000000000b1',
     '...and it is still in its branch');

   select lives_ok(
     $$insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
       values ('16100000-0000-0000-0000-0000000000d4', '16100000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-0000000000b2', 'sales', 'Door aal2')$$,
     'the stepped-up administrator still writes through the table door');
   select is(
     (select count(*)::int from public.events
      where entity_id = '16100000-0000-0000-0000-0000000000d4' and event_type_code = 'department_created'
        and payload->>'name' = 'Door aal2' and actor_user_id = '16100000-0000-0000-0000-000000000011'),
     1,
     'DEP-2: the door''s creation is recorded, with the actor (measured before the repair: 0 events)');

   update public.departments set name = 'Renamed', is_active = false where id = '16100000-0000-0000-0000-0000000000d4';
   select is(
     (select count(*)::int from public.events
      where entity_id = '16100000-0000-0000-0000-0000000000d4' and event_type_code = 'department_changed'
        and payload->'previous'->>'name' = 'Door aal2' and payload->'current'->>'name' = 'Renamed'
        and payload->'current'->>'is_active' = 'false' and new_state = 'inactive'
        and actor_user_id = '16100000-0000-0000-0000-000000000011'),
     1,
     'DEP-2: a rename and deactivation is recorded once, with both states and the actor (measured before the repair: 0 events)');

   update public.departments set updated_at = now() where id = '16100000-0000-0000-0000-0000000000d4';
   select is(
     (select count(*)::int from public.events
      where entity_id = '16100000-0000-0000-0000-0000000000d4' and event_type_code = 'department_changed'),
     1,
     '...and an update that moves no name, type or active flag records nothing');

   select lives_ok(
     $$select app.create_department('16100000-0000-0000-0000-0000000000b1', 'sales', 'RPC aal2')$$,
     'the RPC still creates a department');
   select is(
     (select count(*)::int from public.events e join public.departments d on d.id = e.entity_id
      where d.name = 'RPC aal2' and e.event_type_code = 'department_created'),
     1,
     'the RPC''s creation is recorded exactly once (its own call moved to the trigger, not duplicated)');

   select throws_ok(
     $$insert into public.departments (tenant_id, branch_id, department_type_code, name)
       values ('16100000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-0000000000b9', 'sales', 'Elsewhere')$$,
     '23503', null,
     'a branch of another tenant is refused on the table door (the tenant-composite FK), unchanged');

   -- An employee is refused before any write.
   select set_config('request.jwt.claims', '{"sub":"16100000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
   select throws_ok(
     $$insert into public.departments (tenant_id, branch_id, department_type_code, name)
       values ('16100000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-0000000000b1', 'sales', 'Emp')$$,
     '42501', null,
     'an employee is refused, unchanged');

   -- No session (migrations, seeds, provisioning): exempt from the charge and silent, as before; the
   -- branch is fixed on this path too.
   reset role;
   select set_config('request.jwt.claims', '', true);
   select lives_ok(
     $$insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
       values ('16100000-0000-0000-0000-0000000000d5', '16100000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-0000000000b1', 'sales', 'Platform')$$,
     'a platform path without a session still creates a department');
   select is(
     (select count(*)::int from public.events where entity_id = '16100000-0000-0000-0000-0000000000d5'),
     0,
     '...and records nothing, as before the repair');
   select throws_ok(
     $$update public.departments set branch_id = '16100000-0000-0000-0000-0000000000b2' where id = '16100000-0000-0000-0000-0000000000d5'$$,
     '23514', null,
     'DEP-3: the branch is fixed on the session-less path too');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 4eb38bf030a2909c7b59cdd8c89620279d09ed87.

3. Check whether `supabase/tests/10_grant_model_test.sql` contains `exactly these THIRTEEN tables`; if so record Already Applied when its Git blob is 518de71a30d557ae4737618fa3a3ecaf47476b08, and otherwise stop and report. Otherwise make exactly these 3 edits (the MEAS-2 bespoke-guard inventory, twelve to thirteen), each matched once, and change nothing else:

   a) immediately after the line
   ```text
   -- platform write, is pinned by `160_...` assertion 15, and the slice's mutants remove the guard.
   ```
   insert
   ```text
   --
   -- IT WENT FROM TWELVE TO THIRTEEN ON 2026-11-11 (Batch 6 slice 4, `20261111130000`).
   -- `departments` joined because `app.guard_department_write` charges
   -- `app.authorize('MANAGE_DEPARTMENTS')` (DEP-1: the door now asks for the step-up
   -- `app.create_department` asks for). `guard_write_capability` has no mapping for this table. The charge
   -- is UNCONDITIONAL for every signed-in caller, on INSERT and UPDATE and every column; its one
   -- exemption, the SESSION-LESS platform write, is pinned by `161_...`, and the slice's mutants remove
   -- the guard.
   ```

   b) replace the line
   ```text
     array['chart_of_accounts','document_versions','invoices','lead_interactions','payment_allocations',
   ```
   with
   ```text
     array['chart_of_accounts','departments','document_versions','invoices','lead_interactions','payment_allocations',
   ```

   c) replace the line
   ```text
     'MEAS-2: exactly these TWELVE tables are credited by a BESPOKE capability trigger rather than by guard_write_capability, so for each of them "credited" means "a human read its short-circuits". Nine until 2026-09-20, when SPEC-203 gave users app.guard_membership_authority -- admissible only because that guard charges app.authorize unconditionally on every path and every column, and its only two exemptions, the session-less platform write and the activate_membership self-claim, are each pinned by a named assertion in 118_membership_authority_and_audit_test.sql. Eleven since 2026-10-13, when SPEC-278 gave chart_of_accounts app.guard_chart_account -- the same unconditional charge, its one session-less exemption pinned by 157_a_used_ledger_account_keeps_its_meaning_test.sql. Twelve since 2026-11-11, when SPEC-300 gave user_branch_assignments app.guard_placement_authority -- the same unconditional charge, its one session-less exemption pinned by 160_a_placement_changes_only_with_authority_and_a_record_test.sql');
   ```
   with
   ```text
     'MEAS-2: exactly these THIRTEEN tables are credited by a BESPOKE capability trigger rather than by guard_write_capability, so for each of them "credited" means "a human read its short-circuits". Nine until 2026-09-20, when SPEC-203 gave users app.guard_membership_authority -- admissible only because that guard charges app.authorize unconditionally on every path and every column, and its only two exemptions, the session-less platform write and the activate_membership self-claim, are each pinned by a named assertion in 118_membership_authority_and_audit_test.sql. Eleven since 2026-10-13, when SPEC-278 gave chart_of_accounts app.guard_chart_account -- the same unconditional charge, its one session-less exemption pinned by 157_a_used_ledger_account_keeps_its_meaning_test.sql. Twelve since 2026-11-11, when SPEC-300 gave user_branch_assignments app.guard_placement_authority -- the same unconditional charge, its one session-less exemption pinned by 160_a_placement_changes_only_with_authority_and_a_record_test.sql. Thirteen since 2026-11-11, when Batch 6 slice 4 gave departments app.guard_department_write -- the same unconditional charge, its one session-less exemption pinned by 161_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record_test.sql');
   ```

   The resulting file's Git blob is 518de71a30d557ae4737618fa3a3ecaf47476b08.

4. Check whether `scripts/verify_database.sql` contains `expected 625 catalog_values`; if so record Already Applied when its Git blob is 58acd3d7755600acf8b1411d31b18a70e8a1f3f3, and otherwise stop and report. Otherwise make exactly these 3 edits (smoke CHECK 6b, 624 to 625 catalog values), each matched once, and change nothing else:

   a) replace the line
   ```text
   -- Expected values track the frozen baseline: 77 public base tables, 71 catalog types, 624 catalog
   ```
   with
   ```text
   -- Expected values track the frozen baseline: 77 public base tables, 71 catalog types, 625 catalog
   ```

   b) replace the line
   ```text
       if n <> 624 then raise exception 'CHECK 6b FAILED: expected 624 catalog_values, found %', n; end if;
   ```
   with
   ```text
       -- 624 -> 625: Batch 6 slice 4 (DEP-2) registered department_changed at sort_order 937 -- the record
       -- of a department renamed, re-typed or deactivated; `app.record_event` refuses an unregistered code.
       if n <> 625 then raise exception 'CHECK 6b FAILED: expected 625 catalog_values, found %', n; end if;
   ```

   c) replace the line
   ```text
       raise notice 'ALL CHECKS PASSED (78 tables, RLS + policies, resolver + read-scope model, 71/624 catalog, FK standard, updated_at triggers, append-only audit, grant/schema-usage completeness)';
   ```
   with
   ```text
       raise notice 'ALL CHECKS PASSED (78 tables, RLS + policies, resolver + read-scope model, 71/625 catalog, FK standard, updated_at triggers, append-only audit, grant/schema-usage completeness)';
   ```

   The resulting file's Git blob is 58acd3d7755600acf8b1411d31b18a70e8a1f3f3.

5. Check whether `_ORVION_CANONICAL/27_event_catalog.md` contains `## department_changed`; if so record Already Applied when its Git blob is c3fd59a12f850ac1058121f01126ac526a4982c2, and otherwise stop and report. Otherwise make exactly this one edit (the canon entry of the new code), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   ## department_created

   Severity: info

   ```
   insert
   ```text
   ## department_changed

   Severity: info

   ```

   The resulting file's Git blob is c3fd59a12f850ac1058121f01126ac526a4982c2.

6. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `| DEP-1 |`; if so record Already Applied when its Git blob is bef01c4d2a8d3bc613db431515a7b46f2a68985b, and otherwise stop and report. Otherwise make exactly these 3 edits (the Slice 46 freshness entry, the DEP-1, DEP-2 and DEP-3 rows and the STEPUP-1 note), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-11 (**Slice 45 — `user_branch_assignments` selected live at Exposure 7, coverage 596; runner-up `departments` at 7/660.** **UBA-1** (High), **UBA-3** (Medium) and **UBA-5** (Low) are new and fixed, and the `user_branch_assignments` half of **USR-3** (High) is fixed. A `ceo` at `aal1`, refused by `app.assign_user_branch`, added a branch and moved a colleague's primary placement by direct table writes; an UPDATE re-pointed, ended and handed over a placement with no event; and the table accepted a department of another branch and a placement that ends before it starts. SPEC-300 charges the RPC's authority on every door, records every placement change, and makes a placement's department belong to its branch and its end follow its start. USR-3 stays OPEN for `user_permission_grants`. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-11 (**Slice 46 — `departments` selected live at Exposure 7, coverage 666; runner-up `user_role_assignments` at 7/678.** **DEP-1** (Medium), **DEP-2** (Low) and **DEP-3** (Medium) are new and fixed. A `ceo` at `aal1`, refused by `app.create_department`, created, renamed, re-typed, deactivated and moved departments by direct table writes, none of them recorded; and a moved department left its existing lead at a branch and department pair every writer refuses, outside every department queue. SPEC-301 charges the RPC's authority on every door, records every department change, and fixes a department's branch for life. STEPUP-1 loses its `departments` member. No other row changed.)

   Previously: 2026-11-11 (**Slice 45 — `user_branch_assignments` selected live at Exposure 7, coverage 596; runner-up `departments` at 7/660.** **UBA-1** (High), **UBA-3** (Medium) and **UBA-5** (Low) are new and fixed, and the `user_branch_assignments` half of **USR-3** (High) is fixed. A `ceo` at `aal1`, refused by `app.assign_user_branch`, added a branch and moved a colleague's primary placement by direct table writes; an UPDATE re-pointed, ended and handed over a placement with no event; and the table accepted a department of another branch and a placement that ends before it starts. SPEC-300 charges the RPC's authority on every door, records every placement change, and makes a placement's department belong to its branch and its end follow its start. USR-3 stays OPEN for `user_permission_grants`. No other row changed.)
   ```

   b) immediately after the line
   ```text
   | UBA-5 | **A placement could end before it started** | data quality | Low | R | 6 | M | ✅ | **✅ FIXED 2026-11-11 (SPEC-300, `20261111120000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-300; the fresh Primary ledger, functions and structure equal local.** **MEASURED** at `90a3a72`: a direct INSERT with `ends_at` a day before `starts_at` was accepted. **Repaired:** the CHECK `user_branch_assignments_ends_after_start_check` (`ends_at is null or ends_at >= starts_at`), 23514 on every door. Test 79's fixture, which ended a placement the day before it started, now starts it two days earlier. **Latent:** Primary and Founder Secondary held 0 placements. Pinned by `160_...` and mutant M4 (the CHECK dropped), killed | — | SPEC-300-a-placement-changes-only-with-authority-and-a-record | 11-11 | 11-11 |
   ```
   insert
   ```text
   | DEP-1 | **An `aal1` owner or ceo created, renamed, re-typed, deactivated and moved departments through the table that `app.create_department` refuses them** | security · authorization | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-11 locally (SPEC-301, `20261111130000`); Primary deployment pending.** **MEASURED** at `2e05d41`: a `ceo` at `aal1`, refused "multi-factor authentication required" by the RPC, created a department by direct INSERT, renamed and re-typed another and deactivated it by direct UPDATE, and moved a third to another branch (DEP-3). Cause: the RPC charges `app.authorize('MANAGE_DEPARTMENTS')`, permission AND step-up; `scope_insert` and `scope_update` charge `app.has_permission` only, and no trigger charged step-up. MANAGE_DEPARTMENTS is held only by `owner` and `ceo`, both step-up-bound by `app.requires_mfa`. A member of STEPUP-1. **Repaired:** `app.guard_department_write` (BEFORE INSERT OR UPDATE, SECURITY DEFINER, empty `search_path`, executable by no client role) charges `app.authorize('MANAGE_DEPARTMENTS')` on every session write and every column; a session-less platform write is exempt, as in every sibling guard. **Latent:** Primary and Founder Secondary held 0 departments. Pinned by `161_...` and mutant M1 (the charge removed), killed | — | SPEC-301-a-department-stays-in-its-branch-and-changes-only-with-authority-and-a-record | 11-11 | 11-11 |
   | DEP-2 | **No door recorded a department change: a table-door creation recorded no `department_created`, and no rename, re-type, deactivation or branch move was ever recorded** | audit completeness · observability | Low | R | 6 | M | 🛡 | **FIXED 2026-11-11 locally (SPEC-301, `20261111130000`); Primary deployment pending.** **MEASURED** at `2e05d41`: a direct INSERT and three UPDATEs (rename and re-type, deactivation, branch move) recorded 0 events; the only producer of `department_created` was the RPC. BRANCH-2's shape on a sibling table. **Repaired:** `app.emit_department_change` (AFTER INSERT OR UPDATE, session writes only) records `department_created` on either door, with the RPC's own call removed so the act is recorded once, and the new code `department_changed` (info, `sort_order` 937, canon 27 entry) with the previous and current name, type and active flag when one of them moves; an update that moves none records nothing. A session-less platform write recorded nothing before and records nothing now. Pinned by `161_...` and mutant M3 (the emitter dropped), killed | — | SPEC-301-a-department-stays-in-its-branch-and-changes-only-with-authority-and-a-record | 11-11 | 11-11 |
   | DEP-3 | **A department could be moved to another branch, stranding the work filed under it outside every department queue** | integrity · authorization | Medium | R | 6 | M | 🛡 | **FIXED 2026-11-11 locally (SPEC-301, `20261111130000`); Primary deployment pending.** **MEASURED** at `2e05d41`: `app.create_lead`, `app.create_booking`, `app.assign_user_branch` and `app.link_internal_supplier` each require the department to belong to the row's branch, but 17 of the 18 foreign keys into `departments` reference `(tenant_id, id)` only; only SPEC-300's placement FK pinned the branch. A `ceo` at `aal1` moved an unplaced department from one branch to another: its lead stayed at the old branch and the moved department, a pair `app.create_lead` then refused; the department's new-branch employee, placed by the RPC, did not see it; and no department reader can be placed at the old pair again. **Repaired:** `app.guard_department_write` refuses an UPDATE of `branch_id` 23514 on every path, with or without a session; a move is a new department in the other branch, and with the branch fixed the tenant is fixed too. No writer moved a department's branch. **Latent:** 0 departments and 0 mismatched lead or booking pairs on Primary and Founder Secondary. **Recorded position:** `is_active` binds nothing: `app.create_lead` and `app.assign_user_branch` accepted an inactive department, and no function reads `departments.is_active`, `name` or `department_type_code`; reopening trigger: a department lifecycle flow that must stop new work in a closed department. Pinned by `161_...` and mutant M2 (the branch fix removed), killed | — | SPEC-301-a-department-stays-in-its-branch-and-changes-only-with-authority-and-a-record | 11-11 | 11-11 |
   ```

   c) replace the line
   ```text
   | STEPUP-1 | **A class CANDIDATE, found by structural evidence: eleven tables carry a direct permission-only write path with no step-up anywhere in their trigger chain** | security · authorization · class | Unclassified | R | 6 | — | 📋 | **UNPROVEN — structural candidate class, recorded, deliberately not acted on (Batch 6 Slice 24).** Not a reproduced class defect. Criterion, read from the local catalog at `b6a0714`: `authenticated` holds INSERT or UPDATE; the INSERT or UPDATE policy charges `app.has_permission(K)` for a K held only by roles that `app.requires_mfa` binds to step-up; and no trigger on the table, at any timing, calls `app.authorize` or `app.mfa_satisfied` directly or through one level of `app` helper. Eleven tables meet it: `branches`, `campaign_daily_metrics`, `catalog_values`, `chart_of_accounts`, `departments`, `document_retention_policies`, `exchange_rate_adjustments`, `exchange_rates`, `journal_entries`, `journal_entry_lines`, `tenants`. `user_branch_assignments` and `user_permission_grants` meet it too and belong to USR-3. `user_role_assignments` does NOT: its AFTER trigger `app.emit_role_change` charges `app.authorize('MANAGE_USERS')`, which a first, BEFORE-only reading missed and a rolled-back probe corrected. **Only `branches` is a reproduced and consequence-classified defect (BRANCH-1, Low).** **`journal_entry_lines` was audited in Batch 6 Slice 32 (SPEC-245): an `aal1` finance manager rewrote posted lines the RPC refuses it to post, and that member is closed by JE-3's repair; it no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it. `chart_of_accounts` was audited in Batch 6 Slice 42 (SPEC-278): its member was reproduced as COA-2 and is closed, and it no longer meets the criterion, because `app.guard_chart_account` charges `app.authorize`. `journal_entries` still meets it (JE-5).** The same probe saw an `aal1` owner's rename land on `departments` and on `tenants`. `departments`' consequence is not classified, so it remains a candidate and is not an audit. **`tenants` was audited in Batch 6 Slice 26 (SPEC-228) and its consequence is classified: none material.** An `aal1` `owner` or `ceo` does write every tenant-profile column, but nothing reads any of them except `name`, shown only to the tenant's own members; no canon marks a tenant-profile edit as step-up, platform-only or sensitive; and the other MANAGE_TENANT_SETTINGS doors that charge `app.authorize` guard distinct actions (licence redemption, payment-proof upload, legal hold, document versions and links, holidays), not a second door to the same action. So `tenants` still meets the criterion, is not a defect, and does not raise this class above UNPROVEN. The other eight are structural candidates only; the finance tables among them are where a consequence, if reproduced, would most likely be material. A member becomes a defect only when it is individually reproduced adversarially and its consequence is classified, and no member gains a disposition or counts toward Batch 6 coverage by being listed here. `campaign_daily_metrics` and `exchange_rate_adjustments` are recorded `AUDITED`, and step-up was not asked on either. **Ceiling:** the criterion reads function text, so it can miss step-up charged through deeper indirection and it cannot see consequence (MEAS-1). **Trigger to revisit:** the Batch 6 slice of any listed table, or the first reproduced consequence on a candidate. **2026-10-08 (SPEC-246): `journal_entries` no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it; its member consequence, JE-5, is closed by that revoke.** | — | SPEC-226-branch-door-audit-record | 09-27 | 09-27 |
   ```
   with
   ```text
   | STEPUP-1 | **A class CANDIDATE, found by structural evidence: eleven tables carry a direct permission-only write path with no step-up anywhere in their trigger chain** | security · authorization · class | Unclassified | R | 6 | — | 📋 | **UNPROVEN — structural candidate class, recorded, deliberately not acted on (Batch 6 Slice 24).** Not a reproduced class defect. Criterion, read from the local catalog at `b6a0714`: `authenticated` holds INSERT or UPDATE; the INSERT or UPDATE policy charges `app.has_permission(K)` for a K held only by roles that `app.requires_mfa` binds to step-up; and no trigger on the table, at any timing, calls `app.authorize` or `app.mfa_satisfied` directly or through one level of `app` helper. Eleven tables meet it: `branches`, `campaign_daily_metrics`, `catalog_values`, `chart_of_accounts`, `departments`, `document_retention_policies`, `exchange_rate_adjustments`, `exchange_rates`, `journal_entries`, `journal_entry_lines`, `tenants`. `user_branch_assignments` and `user_permission_grants` meet it too and belong to USR-3. `user_role_assignments` does NOT: its AFTER trigger `app.emit_role_change` charges `app.authorize('MANAGE_USERS')`, which a first, BEFORE-only reading missed and a rolled-back probe corrected. **Only `branches` is a reproduced and consequence-classified defect (BRANCH-1, Low).** **`journal_entry_lines` was audited in Batch 6 Slice 32 (SPEC-245): an `aal1` finance manager rewrote posted lines the RPC refuses it to post, and that member is closed by JE-3's repair; it no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it. `chart_of_accounts` was audited in Batch 6 Slice 42 (SPEC-278): its member was reproduced as COA-2 and is closed, and it no longer meets the criterion, because `app.guard_chart_account` charges `app.authorize`. `journal_entries` still meets it (JE-5).** The same probe saw an `aal1` owner's rename land on `departments` and on `tenants`. `departments`' consequence is not classified, so it remains a candidate and is not an audit. **`tenants` was audited in Batch 6 Slice 26 (SPEC-228) and its consequence is classified: none material.** An `aal1` `owner` or `ceo` does write every tenant-profile column, but nothing reads any of them except `name`, shown only to the tenant's own members; no canon marks a tenant-profile edit as step-up, platform-only or sensitive; and the other MANAGE_TENANT_SETTINGS doors that charge `app.authorize` guard distinct actions (licence redemption, payment-proof upload, legal hold, document versions and links, holidays), not a second door to the same action. So `tenants` still meets the criterion, is not a defect, and does not raise this class above UNPROVEN. The other eight are structural candidates only; the finance tables among them are where a consequence, if reproduced, would most likely be material. A member becomes a defect only when it is individually reproduced adversarially and its consequence is classified, and no member gains a disposition or counts toward Batch 6 coverage by being listed here. `campaign_daily_metrics` and `exchange_rate_adjustments` are recorded `AUDITED`, and step-up was not asked on either. **Ceiling:** the criterion reads function text, so it can miss step-up charged through deeper indirection and it cannot see consequence (MEAS-1). **Trigger to revisit:** the Batch 6 slice of any listed table, or the first reproduced consequence on a candidate. **2026-10-08 (SPEC-246): `journal_entries` no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it; its member consequence, JE-5, is closed by that revoke.** **2026-11-11 (SPEC-301): `departments` was audited in Batch 6 Slice 46; its member was reproduced as DEP-1 with a classified consequence (DEP-3) and is closed, and it no longer meets the criterion, because `app.guard_department_write` charges `app.authorize`.** | — | SPEC-226-branch-door-audit-record | 09-27 | 09-27 |
   ```

   The resulting file's Git blob is bef01c4d2a8d3bc613db431515a7b46f2a68985b.

7. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `**47 of 78 recorded · 23 `; if so record Already Applied when its Git blob is 834fca4f222e2d1d30e44dcf3c08672395c20770, and otherwise stop and report. Otherwise make exactly these 4 edits (the freshness entry, coverage 47 of 78 and the departments row), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-11 (**slice 45 — `user_branch_assignments` selected by Exposure 7, coverage 596; runner-up `departments` at 7/660.** Coverage **45 → 46 of 78**. USR-3 (this table's half): a `ceo` at `aal1` placed and moved users by direct table writes the RPC refuses at that level. UBA-1: an UPDATE re-pointed, ended and handed over a placement with no event. UBA-3: the table accepted a department of another branch. UBA-5: a placement could end before it started. SPEC-300 closes all four here, so the row is `AUDITED`, with its recorded positions and their reopening triggers; USR-3 stays open on `user_permission_grants`. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-11 (**slice 46 — `departments` selected by Exposure 7, coverage 666; runner-up `user_role_assignments` at 7/678.** Coverage **46 → 47 of 78**. DEP-1: a `ceo` at `aal1` created, renamed, re-typed, deactivated and moved departments by direct table writes the RPC refuses at that level. DEP-2: no door recorded any of it. DEP-3: a moved department stranded its existing lead at a branch and department pair every writer refuses, outside every department queue. SPEC-301 closes all three here, so the row is `AUDITED`, with its recorded position and its reopening trigger. No other row changed.)

   Previously: 2026-11-11 (**slice 45 — `user_branch_assignments` selected by Exposure 7, coverage 596; runner-up `departments` at 7/660.** Coverage **45 → 46 of 78**. USR-3 (this table's half): a `ceo` at `aal1` placed and moved users by direct table writes the RPC refuses at that level. UBA-1: an UPDATE re-pointed, ended and handed over a placement with no event. UBA-3: the table accepted a department of another branch. UBA-5: a placement could end before it started. SPEC-300 closes all four here, so the row is `AUDITED`, with its recorded positions and their reopening triggers; USR-3 stays open on `user_permission_grants`. No other row changed.)
   ```

   b) replace the line
   ```text
   **46 of 78 recorded · 22 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 32 `NOT-RECORDED`.**
   ```
   with
   ```text
   **47 of 78 recorded · 23 `AUDITED` · 21 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 31 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   **All 46 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```
   with
   ```text
   **All 47 recorded surfaces stand at `ADVERSARIAL`, and Check 24 (ADV-1) is what makes that word cost something**: a surface may not carry it unless a pgTAP file names it, declares which attack classes it aimed at (`-- ATTACK-CLASSES:`, closed vocabulary), and carries at least one negative assertion. A file of positive controls earns `TESTED` and no more.
   ```

   d) replace the line
   ```text
   | `departments` | NOT-RECORDED | — | — | — | — |
   ```
   with
   ```text
   | `departments` | **AUDITED** | ADVERSARIAL | `SPEC-301-a-department-stays-in-its-branch-and-changes-only-with-authority-and-a-record` | DEP-1, DEP-2, DEP-3 | `161_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record_test.sql` (17 assertions, ten attack classes declared, CONCURRENCY and REPLAY N/A) proves that a password-only (`aal1`) session is refused on the table door as by the RPC, on INSERT and UPDATE; that a department cannot move to another branch, with or without a session (23514); that a stepped-up administrator still writes through the door; that a door creation is recorded as `department_created` with the actor and a rename and deactivation once as `department_changed` with both states, while an update that moves no name, type or active flag records nothing and the RPC's own creation is recorded once; that a branch of another tenant is refused 23503; that an employee is refused; and that a session-less platform write is exempt and silent. Mutants M1 (step-up charge removed), M2 (branch fix removed) and M3 (emitter dropped) were each killed on the prototype; the causal negative (all removed and the RPC's own record back, the `2e05d41` schema) brought back every measured result. **Swept and sound:** an employee's direct update touches no row; DELETE has no grant, so `scope_delete` is inert; an unknown `department_type_code` is refused by the catalog trigger; a tenant move is refused; two active departments of one name in a branch are refused by `departments_unique_name_per_branch_idx`; `created_at` is caller-writable here as on every table with such a column (SPEC-216's recorded schema-wide question) and nothing reads it. **Recorded position, not repaired:** `is_active` binds nothing (DEP-3's row); reopening trigger: a department lifecycle flow that must stop new work in a closed department. |
   ```

   The resulting file's Git blob is 834fca4f222e2d1d30e44dcf3c08672395c20770.

8. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, with Steps 1–7 applied and uncommitted in the main checkout, run with the project-local CLI and record, with actual counts, exits and exact SHA-256 values:
   - the SHA-256, md5 and byte counts of the migration and test 161, which must equal Consumer Closure;
   - on the local stack holding the migration: the guard's, the emitter's and the RPC's `md5(prosrc)`, security mode and ACL, both triggers and the new code; test 161 and tests 10, 38 and 130 alone; the probes; mutants M1–M3, each restoration proven equal;
   - the causal negative on a local stack without the migration, then the stack restored with it;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migration;
   - the API-contract and map generators, the scope check and `git diff --check`.

   Treat as expected at this boundary only: an undeployed Primary, the API contract's moved `departments` row and the six measured-state items of Consumer Closure.

   Read a fresh Primary baseline, read-only: the project URL, the full ordered ledger and the absence of the target migration; the function and structural surfaces; the triggers of `departments`, the absence of the guard and emitter functions and of the new code; the tenant and department counts. Record the predicted delta. If any reading differs, stop.
9. **Check** that an exact-SHA Gate-2 record for the migration is in the Execution Log: the owner's own, or one marked DELEGATED naming this contract, the migration's SHA-256, Primary `vrvtsxexkiiiivlkdxzp` and the owner's instructions under which it is taken. If absent, write it only when Step 8 passed and those instructions cover a migration that drops no table or column and deletes or rewrites no business row; otherwise stop after Step 8 and present the Gate-2 package.
10. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261111130000_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record`. If it is absent and Step 9 is recorded:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and the triggers of `departments`.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the triggers of `departments`; the guard's, the emitter's and the RPC's `md5(prosrc)`, security mode and ACL; the new code; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
11. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the client RPC figure unchanged.
   - Confirm that `supabase/tests` holds 161 files whose literal `plan(N)` values sum to 3058, then set `Suite **161 files / 3058 assertions**`. If either differs, stop.
   - In each of the three rows DEP-1, DEP-2 and DEP-3 of the register, replace the text `` | 🛡 | **FIXED 2026-11-11 locally (SPEC-301, `20261111130000`); Primary deployment pending.** `` with `` | ✅ | **✅ FIXED 2026-11-11 (SPEC-301, `20261111130000`), DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-301; the fresh Primary ledger, functions and structure equal local.** `` (each span's one leading and one trailing space are delimiters, not text). Change nothing else in the register.
   - Regenerate `MASTER_API_CONTRACT.md`, `ai-map.json` and `repository-index.md` (stored LF) with the canonical generators.
   - Run the four `scripts/test_*_guard.ps1` and require each to pass.
   - Set the Runtime Checkpoint to DONE, append the Execution Log, and commit the implementation once; the pre-commit Gate must admit it.

   If Primary is unproven, stop.
12. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `-Finish` through `scripts/run_timed.ps1`, watched by `scripts/watch_run.ps1`, and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, in the Complete commit: transition to Complete, tick the Acceptance Criteria and the Review Gate, clear `Active Change Request`, set `Last Completed` from Notes, leave `Next capability` and `Current Module` unchanged, and regenerate `ai-map.json` and `repository-index.md` LF.
   - Bind the exact candidate with `-Gate -BindCandidate`. Publication and promotion follow the native release path separately.

## Acceptance Criteria

- [ ] The migration is the frozen bytes; `check: blob supabase/migrations/20261111130000_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record.sql e5c56ad2f2df4ee0a4b62e695fa34a16d5918ea2`
- [ ] Test 161 is the frozen bytes; `check: blob supabase/tests/161_a_department_stays_in_its_branch_and_changes_only_with_authority_and_a_record_test.sql 4eb38bf030a2909c7b59cdd8c89620279d09ed87`
- [ ] The disposition record carries `departments` AUDITED / ADVERSARIAL and coverage 47 of 78; `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md 834fca4f222e2d1d30e44dcf3c08672395c20770`
- [ ] DEP-1, DEP-2 and DEP-3 are fixed and deployed in the register; `check: has reports/master/MASTER_GAP_REGISTER.md "DEPLOYED to Primary under the exact-SHA Gate-2 record of SPEC-301"`
- [ ] The smoke count includes the new code; `check: has scripts/verify_database.sql "expected 625 catalog_values"`
- [ ] The manifest suite figure equals the files; `check: has _ORVION_CANONICAL/manifest.md "Suite **161 files / 3058 assertions**"`
- [ ] Native evaluator remains exact; `check: same scripts/check_agent_continuity.ps1 @2e05d4105b3b52625d624cb35645a328af000564`
- [ ] The originating department RPC migration remains exact; `check: same supabase/migrations/202607049600_identity_event_emission.sql @2e05d4105b3b52625d624cb35645a328af000564`
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write, after a recorded Step 8 readiness gate and Step 9 Gate-2 record; Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] Mutants M1–M3 are each killed with installation and restoration proven, and the causal negative is recorded.

## Execution Log

None.

## Verification Notes

None.


### 2026-11-11 — Gate 1 approval recorded

DELEGATED exact Gate1 under the owner's instructions of 2026-11-08 (class authorization for Batch 6 releases and standing approval of proposals ~10:20 Cairo; publish, promote and hosted deploy ~12:05 Cairo) and 2026-11-11 (slice 4 run mode 2, run through to both products' publish, promote and remote Certify ~10:50 Cairo); Draft SHA-256 25B1DD79D7E57CECC3DC044AAE5A5BC31CCBFD30576F63F58EEEF6148FC3653C, decision SHA-256 D0ACF542982AE1975A4FB3EDF48555510FADDA3BEC8AB03A0CE2A2EA2E50136E. No fabricated human future-digest approval. Gate 2 (Primary deploy) is a separate exact-SHA record in Step 9. Immediately before allocation the hash, the Draft blob 2b679650112ea502bf395a099818580b2ac88980, all 5 source anchors, the baseline HEAD 2e05d4105b3b52625d624cb35645a328af000564 against refreshed origin/main 2e05d4105b3b52625d624cb35645a328af000564 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 57a8b56. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

After actual native Finish and truthful Review, synchronize only this contract and the declared manifest/discovery paths to Complete. Set `Last Completed: **SPEC-301: Batch 6 Slice 46 — a department stays in its branch and changes only with authority and a record (DEP-1, DEP-2, DEP-3), deployed to Primary; native verification and Review complete. Publication/promotion remain separately governed.**` and regenerate discovery. `Next capability` and `Current Module` stay unchanged: the selector names the next slice. Candidate binding follows Complete and is never a pre-Complete criterion.

Exact baseline 2e05d4105b3b52625d624cb35645a328af000564 and source anchors:

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/10_grant_model_test.sql` | `ea4d929d8da576369129bb0ddad8a5bae495bc3f` |
| `scripts/verify_database.sql` | `993bc5509e6776555aee8a97a2e47e49ab751802` |
| `_ORVION_CANONICAL/27_event_catalog.md` | `f2c20b57e9c0b6c8a306fe0eccc375e72a4e2701` |
| `reports/master/MASTER_GAP_REGISTER.md` | `6785a44a7496c082c147150d5071803d1ee9f14d` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `b4c5c8d8be959ad262ef03b450204b33fdbd9e95` |

Selection sources: native AGENTS.md, CR_LIFECYCLE.md, ENGINEERING_METHOD.md and SPEC-300 at 2e05d4105b3b52625d624cb35645a328af000564; the owner's instructions of 2026-11-08 and 2026-11-11 (recorded outside this repository). Three identified snapshots and selection reasons are retained externally; correctness remains native and independent.

Snapshot identities: V1 9E395203D7ED3E95063B8408B075406CFD7654052255CF0997947AADE0EA8E29; V2 2E1A9F1DE01D101E1A6E2B18FF3479609BB01BB32D7ABC1C9204BC45F8BD638D. V3 adds this linkage and the final selection; its own SHA-256 is external.
