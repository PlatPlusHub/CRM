# Change Request — SPEC-230

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make moving a task's department or branch cost ASSIGN_TASK at the `public.tasks` table door, as moving its owner already does and as `app.assign_task` charges for the same move, and record `tasks` as audited.

## Business Reason

Batch 6 Slice 28 selected `tasks` live at Exposure 9, coverage 56; `document_versions` was runner-up at 9/60.

- **The intended rule.** A task's accountable owner is the triple `owner_user_id`, `owner_department_id`, `owner_branch_id` (all NOT NULL). `tasks.scope_isolation` supervises a task by the last two: a department queue sees it through VIEW_DEPARTMENT_TASK_QUEUE over `owner_department_id`, a branch through VIEW_BRANCH_DATA over `owner_branch_id`. After creation, the only RPC that moves any of the three is `app.assign_task`, and it charges ASSIGN_TASK (owner, ceo, branch_manager, department_manager). TASK-1 (`202607058600`) closed the table door for the owner column: "a task changes hands only with authority". Its legal-writer enumeration and its condition covered `owner_user_id` alone.
- **TASK-4 (Medium, reproduced, latent).** Measured on a clean reset at `3b4b5e4`, in rolled-back transactions:
  - An `employee` held CREATE_TASK and COMPLETE_TASK, and neither ASSIGN_TASK nor ARCHIVE_RECORD. It was placed in Cairo / Cairo Sales under a department manager.
  - `app.assign_task` naming itself in Giza / Giza Sales refused it: `permission denied: ASSIGN_TASK`.
  - A direct UPDATE of its own task's `owner_branch_id` and `owner_department_id` to Giza then landed.
  - The department manager's view of that task went from 1 row to 0. The Giza branch manager gained it. No event recorded the move.
  - RLS WITH CHECK passed because the employee stays the owner (VIEW_ASSIGNED_TASKS). The same policy refuses moving a colleague's task, so the defect is "hide one's own task from one's supervisors".
  - **Exposure.** Primary `vrvtsxexkiiiivlkdxzp` holds 231 migrations (latest `20260927120000`), 0 tenants and 0 tasks (read-only, 2026-09-27). The guard's `pg_get_functiondef` md5 there is `27c811689f6b3f5d6ea95da523741884`, equal to the local definition with carriage returns removed.
- **Why TASK-4 is not an existing finding.** TASK-1 is FIXED and its guard fires only on `owner_user_id`. TASK-2 is `assign_task`'s placement lookup. No register row names task placement authority.
- **Reached and deliberately not repaired here.** The `tasks` instances of two open classes reproduced:
  - **ENTRY-1:** an employee explicitly DENIED COMPLETE_TASK, refused completion by both doors, created a task born `completed` with no `completed_at`.
  - **ARCH-2:** the employee without ARCHIVE_RECORD created a task born archived, with `archived_by` naming the owner and `archived_at` 2020-01-01.

  Both rows already own their class and name `tasks`. No function, view, trigger or table reads a task's status, completion or archive state outside its own three RPCs, so neither instance has a consequence beyond the task record. Test 134 pins both as OPEN defects, and those assertions fail when either is repaired.
- **The repair** widens TASK-1's own condition in `app.guard_task_reassignment()` from the owner to the owner triple, and changes nothing else: same function, same BEFORE UPDATE trigger, same session-less exemption.

## Risks

- **A wider guard could stop ordinary task work.** Mitigated: the guard still fires only when one of the three columns actually changes. In the prototype, the owner edited, re-prioritised, rescheduled and started its own task. Tests 16, 17, 39, 54 and 81, and every HTTP suite, passed unchanged.
- **`app.assign_task` could be double-charged.** It already authorizes ASSIGN_TASK, so the trigger is idempotent for it, and `app.create_task` is INSERT-only. An ASSIGN_TASK holder moved a task through the RPC and back through the table in the prototype.
- **Primary deployment replaces one function body in production.** It requires separate exact-byte owner authorization (Gate 2) after the local proof; this contract's approval does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-230-task-queue-authority.md`
- `supabase/migrations/20260927130000_a_task_changes_queue_only_with_authority.sql`
- `supabase/tests/134_task_queue_authority_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607058600_a_task_changes_hands_only_with_authority.sql`
- `supabase/migrations/202607050800_task_write_path.sql`
- `supabase/tests/12_catalog_code_enforcement_test.sql`
- `supabase/tests/15_entity_reference_test.sql`
- `supabase/tests/16_task_write_path_test.sql`
- `supabase/tests/54_transition_permission_parity_test.sql`
- `supabase/tests/81_task_supplier_financial_test.sql`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `scripts/verify_database.sql`
- `scripts/verify_journey_branches.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/26_state_machines.md` (Task State Machine); `_ORVION_CANONICAL/28_permissions_matrix.md` (task permissions)
- `supabase/migrations/202607058600_a_task_changes_hands_only_with_authority.sql` (TASK-1, TASK-2)
- Current local `public.tasks` grants, `scope_isolation`, its nine triggers, `app.create_task`, `app.assign_task`, `app.advance_task`, `app.guard_task_reassignment`, `app.guard_write_capability`
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`tasks`, Coverage); `reports/master/MASTER_GAP_REGISTER.md` (TASK-1, TASK-2, ENTRY-1, ARCH-2, CAMP-4)

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

- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Changing a task's `owner_department_id` or `owner_branch_id` charges ASSIGN_TASK on an authenticated UPDATE | the PostgREST table door; `tasks.scope_isolation`; `app.guard_write_capability`; `app.enforce_status_transition`; the other seven `tasks` triggers | VERIFY | The prototype was applied as a real migration on a clean reset in a scratch worktree at `3b4b5e4`: migration SHA-256 `65f91dd79848f8ef25ff7a97616ed368b129052663d70eddbfe89dc97ac42ec5`, test SHA-256 `a1cdd28db4911fa07b4f2107e3388848f09e273c728ddd52365f3a017685dd80`. Refused with `42501` `permission denied: ASSIGN_TASK`: moving both columns, the department alone, and the branch alone. The same test file on the unrepaired stack failed exactly those three and the placement check (6-9) and passed the other 26. Still landed: the owner's edit, re-prioritisation, rescheduling and start; an ASSIGN_TASK holder's move on both doors; the session-less path. |
| The task RPCs | `app.create_task` (INSERT only; the trigger is BEFORE UPDATE); `app.assign_task` (already authorizes ASSIGN_TASK); `app.advance_task` (never touches placement) | VERIFY | No RPC changes. `verify_journey_branches.ps1` creates, assigns and patches tasks over HTTP, and its TASK-1 checks pass. |
| Existing task tests | `12_...`, `15_...`, `16_...`, `17_...`, `39_...`, `53_...`, `54_...`, `81_...` | VERIFY | None moves a placement without ASSIGN_TASK; all pass unchanged in the prototype's full suite. |
| Who sees a task | `tasks.scope_isolation` | UNAFFECTED | No policy changes. The department and branch the policy reads can no longer be moved out from under it without ASSIGN_TASK. |
| Rows that already exist | Primary and local `public.tasks` | VERIFY | The trigger judges only new UPDATEs and no row is rewritten. Primary held 0 tasks and 0 tenants on 2026-09-27 (read-only). |
| Suite, smoke and every HTTP door | full pgTAP; `scripts/verify_database.sql`; all six HTTP suites | VERIFY | On the prototype stack, in `-Finish`'s order: pgTAP Pass A 134 files / 2408 assertions PASS (2378 existing assertions unchanged, plus 30 new). HTTP suites: 33 + 40 + 74 + 122 + 120 + 60 = 449 passed, 0 failed. Pass B without reset: 134 / 2408 PASS. Smoke: `ALL CHECKS PASSED`, exit 0. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | `app.guard_task_reassignment` is not executable by `authenticated`. The generator, run against the prototype stack into a scratch file, is byte-identical to the committed contract (79 RPC endpoints, 8 views, 73 tables). It is regenerated in Step 7, and any difference is recorded. |
| Measured state that moves | manifest (`Live state`, suite figure, Batch 6 coverage, Last Completed, Active pointer); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 15, 19, 22, 24 | WRITE | 231 → 232 migrations, latest `20260927130000`; 133 → 134 files / 2378 → 2408 assertions; coverage 28 → 29 of 77. Primary values are written only from fresh post-deploy readings. The manifest is 6601 of its 7000-character budget, and Step 7 keeps each moved line within its current length or trims `Last Completed`. |
| Findings and disposition | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 2, 11, 16, 21, 22, 25 | WRITE | One new row: TASK-4, with Owner Decision `—`, so Check 25 adds nothing to the open-decision line. ENTRY-1, ARCH-2, TASK-1, TASK-2, CAMP-4 and every other row are unchanged. Only the `tasks` disposition row changes, to `AUDITED-OPEN` / `ADVERSARIAL` with findings TASK-4, ENTRY-1 and ARCH-2, because the two class instances stay open on this surface. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused test, pgTAP A/B, the declared HTTP suite, smoke and in-file mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| TASK-4 and the `tasks` disposition accurately describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| Manifest Batch 6 coverage equals the disposition record | BEFORE_COMPLETION | Step 3 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: TASK-1's `app.guard_task_reassignment()` on trigger `tasks_guard_reassignment` (BEFORE UPDATE, SECURITY INVOKER, empty `search_path`, EXECUTE revoked from PUBLIC) already owns "a task changes hands only with ASSIGN_TASK" at this door. Its condition is widened from the owner to the owner triple, and nothing else is added. The alternatives were rejected:
- widening `app.guard_write_capability` cannot see which column moved, which is TASK-1's own reason;
- a new trigger would be a second owner of the same invariant;
- an RLS change would alter visibility, not authority.

Added Property: On any signed-in path, a change to a task's `owner_user_id`, `owner_department_id` or `owner_branch_id` requires ASSIGN_TASK, exactly as `app.assign_task` does. Editing, re-prioritising, rescheduling, starting and completing a task keep their current authority, and the session-less platform path keeps its exemption.

Causal Negative: On a clean reset at `3b4b5e4`, in a rolled-back transaction, an `employee` without ASSIGN_TASK was refused the move by `app.assign_task` and then moved its own task from Cairo / Cairo Sales to Giza / Giza Sales by direct UPDATE. Its department manager's view of the task went from 1 row to 0.

Positive Test Design: As the employee at `aal2`: edit title, priority and due date of its own task, and start it. As the owner at `aal2`: move the task through `app.assign_task`, and back through the table. Session-less: a placement write lands.

Negative Test Design: As the employee, four moves are refused with `42501` `permission denied: ASSIGN_TASK`: the RPC move; the table move of both columns; the department alone; the branch alone. After them the task's placement is unchanged, read as the department manager. Handing the task to a colleague stays refused (TASK-1). The surface's other refusals are pinned by their own messages:
- planting a task in another tenant (RLS);
- DELETE (no grant);
- a trainee's INSERT (`one of CREATE_TASK is required`);
- an `aal1` owner's INSERT (`multi-factor authentication required for this role`);
- the denied user's direct completion (`permission denied: COMPLETE_TASK`).

An UPDATE of another tenant's task changes nothing. ENTRY-1's and ARCH-2's `tasks` instances are pinned as OPEN.

Non-Empty Population Obligation: The employee holds CREATE_TASK and COMPLETE_TASK, and neither ASSIGN_TASK nor ARCHIVE_RECORD. The department manager sees the employee's task through the department queue. The denied user holds CREATE_TASK, is denied COMPLETE_TASK, and is refused completion by the RPC. Every refused write targets a task its actor can see or its actor's own tenant.

Mutation Obligation: Record `app.guard_task_reassignment`'s `pg_get_functiondef` md5, then open a savepoint and install the pre-repair definition (owner column only). Prove the md5 differs. As the employee, prove the placement move lands and the department manager's view goes to 0. Roll back to the savepoint, then prove the md5 is identical and no mutant move survived. A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: Focused test, clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B, smoke, the in-file mutation, generated artifacts, fresh Primary evidence, parity evidence, the Primary ledger check, repository consistency and `git diff --check`, all on the final bytes and through canonical `-Finish`.

## Implementation Steps

1. **Check** that `supabase/migrations/20260927130000_a_task_changes_queue_only_with_authority.sql` is absent. If absent, create it LF with SHA-256 `65f91dd79848f8ef25ff7a97616ed368b129052663d70eddbfe89dc97ac42ec5`. It holds one `create or replace function app.guard_task_reassignment()`, whose condition compares `(owner_user_id, owner_department_id, owner_branch_id)` of `new` and `old`, plus its comment and `revoke all ... from public`. The body is otherwise TASK-1's, the security mode stays INVOKER and the `search_path` stays empty. It changes no trigger, policy, grant or other function. If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/134_task_queue_authority_test.sql` is absent. If absent, create it LF with SHA-256 `a1cdd28db4911fa07b4f2107e3388848f09e273c728ddd52365f3a017685dd80`. It is one transaction-rolled-back pgTAP file with `select plan(30);`. Its first line is `-- ATTACK-CLASSES: PRIVILEGE DOOR TENANT AUTH STATE INPUT=N/A BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A`, and its header cites SPEC-230 and states each `N/A` reason. It implements:
   - the Non-Empty Population Obligation (1-4);
   - the Negative and Positive Test Design (5-21);
   - the ENTRY-1 and ARCH-2 OPEN pins (22-25);
   - the Mutation Obligation (26-30).

   If the target exists with different bytes, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `| TASK-4 |`. If absent:
   - Add a dated Slice 28 freshness entry and demote the previous entry to `Previously:`.
   - Append one row after `| SUB-3 |`: **TASK-4**, Category `authorization · supervision`, Sev `Medium`, Req/Opt `R`, Batch `6`, Mig `A`, Cert `📋`, Owner Decision `—`, Source `SPEC-230-task-queue-authority`, dates `09-27`. Its Status reads `FIXED locally by SPEC-230 (`20260927130000`), pending Primary deployment` and states:
     - the reproduction and consequence above;
     - latent exposure (0 tenants on Primary);
     - why it is not TASK-1 or TASK-2;
     - that the repair widens TASK-1's own guard;
     - that it is pinned by `134_...`.
   - Change no other row.

   Then check whether `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `tasks` row reads `NOT-RECORDED`. If so:
   - Set it to `AUDITED-OPEN` / `ADVERSARIAL` / `SPEC-230-task-queue-authority` / `TASK-4, ENTRY-1, ARCH-2`. Its Next cell names `134_task_queue_authority_test.sql` and what it proves, and names ENTRY-1 and ARCH-2 as pinned OPEN. It also states the swept non-defects:
     - nothing outside the three RPCs reads a task, and no table references one;
     - `completed_at` is caller-writable at the table and read by nothing;
     - a department-queue member working a colleague's queued task is what both doors allow;
     - direct creation and transitions emit no task event, which is CAMP-4's shape, and nothing reads task events;
     - `created_at` is SPEC-216's schema-wide question;
     - the related-entity reference is existence-checked in the row's own tenant.
   - Update Coverage to `29 of 77 recorded · 10 AUDITED · 16 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 48 NOT-RECORDED` and `All 29 recorded surfaces`.
   - Add a dated freshness entry and demote the previous one to `Previously:`.
   - Change no other row.

   If either target already carries different content, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 hashes:
   - a clean local reset and the focused test;
   - pgTAP Pass A, the declared HTTP suite, then pgTAP Pass B without reset;
   - `scripts/verify_database.sql` and the plan sum;
   - the in-file mutation evidence;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat only undeployed Primary, manifest and parity drift as expected at this boundary. Read a fresh Primary baseline, read-only:
   - the full ordered ledger;
   - the function and structural surfaces;
   - the tenant and task counts;
   - the absence of the target migration;
   - the guard's current definition md5.

   Record the predicted structural delta.
5. **Check** that exact owner authorization for the migration and Test-134 SHA-256 values is recorded in the Execution Log. If absent, stop after Step 4 and present:
   - the current HEAD;
   - the exact 64-character hashes;
   - the fresh Primary baseline and the predicted delta;
   - the exact Primary write requested.

   Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260927130000_a_task_changes_queue_only_with_authority`. If it is absent and deployment is separately authorized:
   - Immediately re-read: HEAD; both hashes; the project URL; the full ordered ledger; target absence; and the guard's pre-repair md5.
   - On an exact match, apply only the authorized migration through the Primary connector. If the connector assigns a temporary version, normalize only its newly inserted ledger row.
   - Read fresh: the ledger, the function surface and all ten structural surfaces, the guard's definition md5, security mode, `search_path` and EXECUTE ACL, and the trigger's timing and enabled state.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`:
     - Set the `Live state` migration count, latest version, ledger and surface hashes and counts from the same readings.
     - Set the suite figure to `Suite **134 files / 2408 assertions**`, after confirming `supabase/tests` holds 134 files whose literal `plan(N)` values sum to 2408. If either differs, stop.
     - Change the Batch 6 line's `**28 of 77 surfaces have a recorded audit disposition**, all twenty-eight at` to `**29 of 77 surfaces have a recorded audit disposition**, all twenty-nine at`, only after Step 3 set Coverage to `29 of 77 recorded`.
     - Set `Last Completed` to Slice 28 / TASK-4 / SPEC-230, trimming it so the manifest stays within 7000 characters.
   - Mark TASK-4 `FIXED` and `DEPLOYED` in the register and change its Cert to `✅`.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators, never by hand.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete, set `Next capability` to Batch 6 Slice 29 ranked by `scripts/batch6_select_target.ps1`, clear `Active Change Request` and regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate and require exact-SHA candidate CI. Promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs and remove permitted scratch files.

   Do not start Slice 29.

## Acceptance Criteria

- [ ] On every signed-in path, a change to a task's department, branch or owner requires ASSIGN_TASK. The employee's table moves (both columns, department alone, branch alone) and its RPC move are pinned to `42501` `permission denied: ASSIGN_TASK`, and the task stays in its department manager's queue.
- [ ] With the pre-repair guard installed in a savepoint, the same employee moves its task out of the queue and the manager loses sight of it; the restored guard is byte-identical and no mutant move survives.
- [ ] Editing, re-prioritising, rescheduling and starting one's own task, an ASSIGN_TASK holder's move on both doors, the session-less path, every RPC and every policy keep their behaviour; `verify_journey_branches.ps1` passes.
- [ ] TASK-4 is registered Medium and `FIXED` / `DEPLOYED`. `tasks` is `AUDITED-OPEN` / `ADVERSARIAL` with findings TASK-4, ENTRY-1 and ARCH-2, the two class instances pinned OPEN by Test 134. Coverage reads 29 of 77 in both the disposition record and the manifest. ENTRY-1, ARCH-2 and every other row are unchanged.
- [ ] The migration and Test 134 match their authorized SHA-256 values. Primary, the recorded evidence, the manifest (232 migrations; 134 files / 2408 assertions), the API contract and `ai-map.json` agree.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and no business-data write, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-27 — Owner approval

Owner approved the exact Draft SHA `d4ccb1907d6c010cf3863f54383079026dd62844` and the frozen nine-path Write Scope, with TASK-4 as FIX NOW under the approved design. A read-only evaluation of the committed Draft returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE, REPOSITORY). Two mutated copies returned FAIL (a gate inside a red window) and INDETERMINATE (Mutation Obligation removed). Pre-approval revalidation:
- HEAD was the Draft SHA and the tree was clean;
- `origin/main` and `origin/orvion-preflight` were at `3b4b5e4`;
- the prototype migration and Test 134 hash to the frozen values;
- the local stack is back at 231 migrations after the prototype.

The approval is bound to migration SHA-256 `65f91dd79848f8ef25ff7a97616ed368b129052663d70eddbfe89dc97ac42ec5` and Test-134 SHA-256 `a1cdd28db4911fa07b4f2107e3388848f09e273c728ddd52365f3a017685dd80`. ENTRY-1 and ARCH-2 stay existing OPEN findings, neither repaired nor reclassified, and no unrelated register row changes. During prototyping, a relative-path write briefly altered the main checkout's manifest outside any Write Scope. It was restored from HEAD before the Draft was committed, and it widens nothing.

Approval authorizes Approve, In Progress, Steps 1-4 and local proof. It does not authorize a Primary write, which needs separate exact-byte authorization at Gate 2.

### 2026-09-27 — Execution started

The approved nine-path contract entered In Progress at `98a5fdc`. Resume Step 1. Local implementation and proof through the Step 4 pre-deploy readiness gate are authorized; Primary deployment remains separately gated at Step 5.

## Verification Notes

None yet.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created or deleted.
- [ ] No section was added, removed or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

- **EARN IT.** TASK-4 was reproduced on a clean reset against a rule the repository already states twice: `app.assign_task`'s ASSIGN_TASK charge and TASK-1's "a task changes hands only with authority". Its consequence lands on the one reader of placement that exists, `scope_isolation`: the supervising department manager lost sight of a task assigned to its employee, and nothing recorded the move. No existing control owns it.
- **WORTH IT.** The repair is one condition in the function that already owns the invariant. It needs no data reconciliation, because Primary has 0 tasks, and it closes the door before the first tenant. Recording it OPEN would still need the same aimed test for `ADVERSARIAL`. The residual cost is Gate 2 and one deployment.
- **Rejected alternatives:**
  - recording TASK-4 OPEN with a reopen trigger: the only consumer, supervision by queue, is live from the first tenant, so no later trigger would fire before exposure;
  - a new trigger or a `guard_write_capability` mapping: a second owner, or one that cannot see which column moved;
  - closing the `tasks` instances of ENTRY-1 and ARCH-2 here: each is an existing class row with its own per-surface closure rule, and nothing reads task status, completion or archive state, so this slice pins them rather than absorbing them.
- **Classified, not recorded as findings:**
  - `app.enforce_entity_reference` is SECURITY DEFINER and runs before RLS WITH CHECK. A caller who already holds another tenant's ids can therefore tell an existing related id from a missing one before the RLS refusal. It needs the victim's ids, yields one bit, is shared with `notifications` and `approval_requests`, and reads nothing else, so it is not a `tasks` defect.
  - An employee who is a member of the department queue can edit and complete a colleague's queued task, and `app.advance_task` allows the same.
- **Untouched:** ENTRY-1, ARCH-2, CAMP-4, STEPUP-1, PAR-5 and every other open finding. The registered worktree `owt/p2` is untouched.
