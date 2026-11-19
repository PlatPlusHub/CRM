# Change Request — SPEC-318

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Prevent a new CRM task from entering either of Canon 26's terminal states directly. Keep completion and cancellation on the established transition path. This Draft covers the tasks member of ENTRY-1.

## Business Reason

SPEC-230 and Test 134 already proved the task creation gap. The owner authorized one Draft and the recorded selection exception after SPEC-317, with bounded discovery before freezing. The 78 surfaces are recorded and the normal selector has no eligible unrecorded surface. The plan records the exception for this repair only.

Campaign entry shares the broad entry pattern, but CAMP-2 has no proved material consequence. Booking items have a distinct state machine with an explicitly authorized manual completion path. ARCH-2 concerns archive authority and attribution even on open tasks. BRANCH-1 concerns step-up. These use different enforcement and verification and stay separate. PAX-4 and STEPUP-1 remain unproven at class level. The action registry retains all other triggers and deadlines.

## Risks

A state gate on UPDATE would interfere with the allowed task transitions. Limit the guard to INSERT and the two existing terminal values. The predicate makes no queries and requires no new privilege. Existing rows, grants, RLS, RPC signatures and event catalog keep their current behavior. Installing the guard takes a DDL lock. Verify the Primary window and lock risk before deployment. This Draft authorizes no hosted or Original writes.

## Supersedes / Depends On

Depends on SPEC-317 for exit scope and SPEC-230 for the task and Test 134 evidence. It supersedes only SPEC-230's two open task-entry assertions.

## Write Scope

- `changes/SPEC-318-guard-task-terminal-status-at-entry.md`
- `supabase/migrations/20261119112137_guard_task_terminal_status_at_entry.sql`
- `supabase/tests/134_task_queue_authority_test.sql`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/config.toml`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/readiness_population.ps1`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`

Every other product path and migration is out of scope. No historical data rewrite, task RPC rewrite, archive repair, campaign or booking-item change, permission or RLS change, Founder repository or Secondary access, or integration change. Gate 1 and any deployment or release authority remain separate.

## Required Reading

- `CR_LIFECYCLE.md` §§4–9 and `ENGINEERING_METHOD.md` §2.
- `_ORVION_CANONICAL/26_state_machines.md` Task State Machine.
- `changes/SPEC-230-task-queue-authority.md` and `supabase/tests/134_task_queue_authority_test.sql`.
- `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 action registry and recorded selector exceptions.
- `reports/master/MASTER_GAP_REGISTER.md` ENTRY-1, ARCH-2, CAMP-2, STEPUP-1 and PAX-4.
- `reports/master/MASTER_SURFACE_DISPOSITION.md` tasks and related dispositions.

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Use one task-local INSERT trigger for the two Canon 26 terminal states. Keep all status updates under the established transition guard. Extend Test 134 to cover both terminal refusals, allowed open creation and absence of rejected rows.

Pass 2 Adversarial Review: Check the two write paths, task and campaign state machines, booking-item manual completion, archived task fixture, and existing transition/tenant/step-up controls. A generic guard would assign incompatible policy to the three remaining ENTRY-1 members. Preserve the archive checks and don't use the class label as evidence of an individual defect.

Pass 3 Evidence Refresh: 2026-11-19. The push-disabled prototype passed the full isolated pgTAP run (181 files and 3349 assertions, including Test 134), and native database smoke passed. A rollback-only catalog check observed the trigger enabled, disabled, then restored. The native registry still reports 17 exit obligations and 78 recorded surfaces. The API contract re-generated against the isolated schema with zero differing lines. The intended shape delta is one enabled INSERT trigger and one non-definer function inaccessible to API roles, with no changed grant count, policy, column, index, constraint, RLS membership, view or status-transition rows. The ledger reached 272 locally, latest 20261119112137, fingerprint b2e617f87c56ee17dfab43629ce88609. This evidence is local. The first rehearsal applied all three blobs and attempted the implementation commit before completing the verification and deployment steps. Its guard correctly reported four manifest discrepancies and RECOVER-1. A new read-only Primary result shows 271 migrations and zero rows for the target. The same implementation blobs are retained.

Selected Version: SPEC-318; selected: one task-local trigger, Test 134 and the recorded selector exception. Campaign, booking-item, archive and step-up changes stay in their own authority.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Task terminal-state creation | public.tasks writes and app.create_task | WRITE | The guard refuses terminal creation for every writer. The RPC creates open tasks. Existing transition and archive paths are independent. |
| Task behavior and causal regression | Test 134 and existing task tests | WRITE | Both terminal values fail with SQLSTATE 23514. Open creation succeeds. None of the rejected rows persist. Queue, tenant, step-up and archive assertions are carried forward. |
| Selector exception and recorded finding | Action registry, ENTRY-1 row, tasks disposition | WRITE | Record the owner exception. After verified deployment, append only the task-member closure evidence to ENTRY-1 and update the tasks evidence. Keep ENTRY-1 open for its other members and tasks AUDITED-OPEN for ARCH-2. |
| API surface | MASTER_API_CONTRACT.md and generator | VERIFY | Regenerate from the local schema and compare to the baseline. The emitted API contract is identical. |
| Ledger, suite figure and discovery | Primary ledger evidence, manifest Live state, ai-map.json, repository-index.md | WRITE | Step 4 synchronizes measured local migration and suite figures in the uncommitted manifest and records Primary separately. Step 6 records actual Primary parity and regenerates discovery from its native source. |
| Current Module, Next capability and Batch 6 surface coverage | Boot, selector and governance pins | UNAFFECTED | All lines retain their ratified text and pin. No criteria or exit counts change. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 5 (Platinum Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Exact verified payload, isolated functional proof and fresh target | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Recorded ledger matches actual Primary ledger | BEFORE_COMPLETION | Step 1 | Step 6 | Step 7 |
| Repository/local migration figures and measured suite count match the prepared payload | BEFORE_IRREVERSIBLE_ACTION | Step 1 | Step 4 | Step 5 |
| Generated evidence and unified Live state match the deployed implementation | BEFORE_COMPLETION | Step 5 | Step 6 | Step 7 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: The shared transition guard is UPDATE-only. The task create RPC already chooses open. The existing write-capability guard establishes authority, while catalog checks establish valid values. Neither enforces the terminal-state creation invariant.

Added Property: A new task cannot be inserted as completed or cancelled. Existing tasks can still advance under the established authority.

Causal Negative: SPEC-230 reproduces the direct task creation gap, and the unchanged baseline Test 134 asserts its effect with the denied employee fixture. That retained causal evidence is reused.

Positive Test Design: The same fixture creates an open task. Existing task RPC, transition, tenant and authority coverage runs as part of the native suite.

Negative Test Design: Test 134 expects the same 23514 invariant for completed and cancelled at insertion and proves neither row persisted.

Non-Empty Population Obligation: Test 134 creates the employee with explicit completion denial, a populated tenant and placement, existing tasks, and a positive open-task control under the same authenticated session.

Mutation Obligation: A sandbox-only structural negative that disables the new trigger must make the enabled INSERT-trigger catalog predicate false. Restore the trigger in the same rolled-back transaction. Retain SPEC-230 and baseline Test 134 as the causal proof rather than rebuilding the historical fixture.

Post-Implementation Proof Obligation: Native tests and smoke, regenerated API comparison, measured target ledger and structural parity, exact task enforcement evidence and fresh independent native Review. Preserve unresolved cases at their existing triggers.

## Implementation Steps

1. Check whether `supabase/migrations/20261119112137_guard_task_terminal_status_at_entry.sql` contains `-- ENTRY-1: task completion`; if so record Already Applied when its Git blob is e4864c7bf2c4dc9c9ce07f79e9c0e4a389d98a5d, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the task terminal-state INSERT guard), and change nothing else:

   ```text
   -- ENTRY-1: task completion and cancellation must use the existing transition path.
   create function app.guard_task_terminal_status_at_entry()
   returns trigger
   language plpgsql
   set search_path = ''
   as $fn$
   begin
       raise exception using
           errcode = '23514',
           message = 'a task cannot be created in a terminal state';
   end;
   $fn$;

   revoke all on function app.guard_task_terminal_status_at_entry() from public;

   create trigger tasks_guard_terminal_status_at_entry
   before insert on public.tasks
   for each row
   when (new.task_status_code in ('completed', 'cancelled'))
   execute function app.guard_task_terminal_status_at_entry();
   ```

   The resulting file's Git blob is e4864c7bf2c4dc9c9ce07f79e9c0e4a389d98a5d.

2. Check whether `supabase/tests/134_task_queue_authority_test.sql` contains `select plan(32);`; if so record Already Applied when its Git blob is 74612c13c8b24286eb7687ed55c285b6544b0532, and otherwise stop and report. Otherwise make exactly these 7 edits (the updated task queue and entry regression test), each matched once, and change nothing else:

   a) replace the lines
   ```text
   -- It also pins two OPEN defects as they stand, not as desired behaviour; each assertion fails when its
   -- finding is repaired: ENTRY-1 (a user DENIED COMPLETE_TASK creates a task born `completed`) and
   -- ARCH-2 (a user without ARCHIVE_RECORD creates a task born archived under another user's name).
   ```
   with
   ```text
   -- The ENTRY-1 assertions cover rejected terminal-state creation and allowed open creation.
   -- The ARCH-2 assertions retain the pending archive-at-entry evidence.
   ```

   b) replace the line
   ```text
   select plan(30);
   ```
   with
   ```text
   select plan(32);
   ```

   c) replace the line
   ```text
   -- 22-25. OPEN defects, pinned as they stand. Each assertion fails when its finding is repaired.
   ```
   with
   ```text
   -- 22-27. ENTRY-1 terminal-state guard and the existing ARCH-2 evidence.
   ```

   d) replace the line
   ```text
   select lives_ok($$insert into public.tasks (id,tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title)
   ```
   with
   ```text
   select throws_ok($$insert into public.tasks (id,tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title)
   ```

   e) replace the line
   ```text
     'OPEN ENTRY-1: the employee denied COMPLETE_TASK still creates a task born completed');
   ```
   with
   ```text
     '23514','a task cannot be created in a terminal state',
     'ENTRY-1: an employee cannot create a completed task');
   select throws_ok($$insert into public.tasks (id,tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title)
                     values ('13400000-0000-0000-0000-0000000000f3','13400000-0000-0000-0000-000000000001','13400000-0000-0000-0000-000000000014',
                             '13400000-0000-0000-0000-0000000000d1','13400000-0000-0000-0000-0000000000b1','follow_up','cancelled','born cancelled')$$,
     '23514','a task cannot be created in a terminal state',
     'ENTRY-1: an employee cannot create a cancelled task');
   select lives_ok($$insert into public.tasks (id,tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title)
                     values ('13400000-0000-0000-0000-0000000000f4','13400000-0000-0000-0000-000000000001','13400000-0000-0000-0000-000000000014',
                             '13400000-0000-0000-0000-0000000000d1','13400000-0000-0000-0000-0000000000b1','follow_up','open','open task')$$,
     'ENTRY-1: an employee with CREATE_TASK can create an open task');
   ```

   f) replace the lines
   ```text
   select is((select task_status_code || ':' || coalesce(completed_at::text,'-') from public.tasks where id = '13400000-0000-0000-0000-0000000000f1'),
     'completed:-',
     'OPEN ENTRY-1: it is terminal, with no completion time and no RPC having completed it');
   ```
   with
   ```text
   select is((select count(*)::int from public.tasks where id in ('13400000-0000-0000-0000-0000000000f1','13400000-0000-0000-0000-0000000000f3')), 0,
     'ENTRY-1: neither rejected terminal-state task was stored');
   ```

   g) replace the line
   ```text
   -- 26-30. Mutation: the pre-repair guard (owner only) is installed in a savepoint, the move lands,
   ```
   with
   ```text
   -- 28-32. Mutation: the pre-repair guard (owner only) is installed in a savepoint, the move lands,
   ```

   The resulting file's Git blob is 74612c13c8b24286eb7687ed55c285b6544b0532.

3. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Recorded exception, 2026-11-19, CRM task entry`; if so record Already Applied when its Git blob is c8ac9f40985fb8136dfb12ced623a2c8e9f2865f, and otherwise stop and report. Otherwise make exactly this one edit (the owner-authorized selector exception), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   **Recorded exception, 2026-11-19, CRM.** After CRM SPEC-316 remote Certify at `28e9052beaefa367b31d4ea7346654678374c54c`, the owner authorized one CRM-only, record-only Batch 6 Exit Reconciliation Draft. The selector exhausted unrecorded surfaces and the registry still derived 22 obligations due at exit. This exception reconciles their records and identifies remaining work. Gate 1 remains separate. The existing ordering, individual finding triggers and Pre-Production Readiness Closure conditions govern. The private Workbench packet retains the source approval.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-19, CRM task entry.** After CRM SPEC-317 Remote Certify at `a17473dbe478a2c2268ce9c503bf6e4832b7affb`, the owner authorized bounded discovery and one next Draft because the native selector has zero unrecorded surfaces. SPEC-318 selects the proven task member of ENTRY-1, supported by SPEC-230 and Test 134. The task guard and regression tests share one insertion boundary. Campaign entry requires a material consequence and booking-item entry has a separate authorized lifecycle. ARCH-2 and STEPUP-1 retain their independent authority. This selection does not close an obligation. Original Gate 1 and Primary deployment authorization remain separate.

   ```

   The resulting file's Git blob is c8ac9f40985fb8136dfb12ced623a2c8e9f2865f.

4. **Verify the prepared payload and predeployment target.** Run the existing database protocol, including focused Test 134, native required tests, HTTP verification and smoke, API generation and comparison, exact file hashes and scope, and compare the local schema to the certified Primary baseline. Confirm the new trigger exists, is enabled, fires only on INSERT and calls the non-definer function. Run the rollback-only structural negative. Read the Platinum Primary ledger, task row count and schema under its authorized read path. Stop on any unexpected divergence. The local intended outcome is 272 migrations, 181 test files with 3349 assertions, and the exact function and trigger delta in the isolated catalog evidence.

   After those measurements agree, update only the existing `Live state:` line of `_ORVION_CANONICAL/manifest.md` in the uncommitted working tree. Use this line only while the measured local payload and verified Primary baseline agree with the figures shown:

   ```text
   Live state: SPEC-318 pre-deploy verification. **Repository and local stack at 272 migrations** (latest `20261119112137`), ledger `b2e617f87c56ee17dfab43629ce88609`. **Platinum Primary `vrvtsxexkiiiivlkdxzp` verified separately at 271 migrations**, with the target absent. Structural parity awaits Gate 2. **80 client RPCs**. Suite **181 files / 3349 assertions**.
   ```

   Run the unchanged repository consistency guard against these uncommitted edits. Require zero migration-manifest and suite discrepancies. The only expected failure is RECOVER-1 for the exact missing target row; stop on any other diagnosis. Preserve the existing Primary evidence and keep Step 4 as the pre-deploy checkpoint while awaiting explicit Gate 2. Neither an implementation commit nor Runtime Checkpoint DONE is permitted at this checkpoint.

   In the push-disabled Sandbox, rehearse native Approve, the native literal file replay, and the unchanged consistency guard through this checkpoint. Preserve the separate local and Primary evidence. This rehearsal stops before deployment. The native implementation commit and full consistency PASS belong after Steps 5 and 6.
5. **Deploy only after explicit exact-SHA Gate 2.** Use Platinum Primary project `vrvtsxexkiiiivlkdxzp` only. Reverify identity, ledger, task schema and exact migration MD5 before the single approved write. Verify the exact new ledger row, enabled trigger, non-definer function, structural parity and unchanged task row count afterward. If the native connector uses a temporary version, reconcile only the exact new row after checking the stored statement digest and the target version's absence. On partial failure stop and preserve the exact target state. Never delete migration history or blindly retry. Require documented owner-authorized recovery under the native RECOVER-1 process. The additive change requires no data rollback. If reversal is necessary, use a separately authorized corrective migration for the two added objects.
6. **Record independently proved state.** Write fresh Primary ledger evidence from the confirmed live reading. Replace the interim manifest line with unified Live state only after independently proving Primary and local ledger and structural parity. Retain the measured suite figure, then regenerate and verify discovery and the API contract. Require a full native repository consistency PASS before marking the runtime checkpoint DONE and committing. Append to the existing ENTRY-1 finding only the tasks-member result, migration identity and Test 134 evidence. Revise only the corresponding task-entry evidence clause in the tasks disposition. Keep ARCH-2, other ENTRY-1 members, the tasks AUDITED-OPEN status, all 17 exit obligations and all other dispositions and triggers. Record exact verification and set Runtime Checkpoint to DONE before the implementation commit.
7. **Verify and close through the native lifecycle.** Run timed and watched Finish, independent Review, and Complete only with matching receipts and clean native gates. Set `Last Completed: **SPEC-318: Terminal-state task creation guarded.**`, clear the active pointer, regenerate discovery and bind the exact candidate. Release requires its own authority.

## Acceptance Criteria

- [x] The exact migration adds the task-local terminal-state INSERT guard. `check: blob supabase/migrations/20261119112137_guard_task_terminal_status_at_entry.sql e4864c7bf2c4dc9c9ce07f79e9c0e4a389d98a5d`
- [x] Test 134 covers both exact refusals, allowed open creation and absence of rejected rows. `check: blob supabase/tests/134_task_queue_authority_test.sql 74612c13c8b24286eb7687ed55c285b6544b0532`
- [x] The approved selector exception appears exactly once and B6-EXIT obligations retain their recorded status. `check: blob reports/master/MASTER_EXECUTION_PLAN.md c8ac9f40985fb8136dfb12ced623a2c8e9f2865f`
- [x] The generated API contract matches the certified baseline. `check: same reports/master/MASTER_API_CONTRACT.md @a17473dbe478a2c2268ce9c503bf6e4832b7affb`
- [x] The native selector and registry retain their authority. `check: same scripts/batch6_select_target.ps1 @a17473dbe478a2c2268ce9c503bf6e4832b7affb`
- [x] The manifest records the measured test figure. `check: has _ORVION_CANONICAL/manifest.md "Suite **181 files / 3349 assertions**"`
- [x] The verified Primary ledger and structural evidence match the local result. ENTRY-1 and tasks evidence reflect only the verified task-member repair.

## Execution Log

### 2026-11-19 — Original pre-deploy readiness

Steps 1–3 reconstituted the three exact payload blobs at the approved Original head. Step 4 verified the native database tests, API contract, scope and read-only live Primary baseline. Repository consistency returned only the expected RECOVER-1 target-row absence. A delegated exact Gate 2 record was saved in the Workbench packet. The deployment connection is unavailable in the executing Codex session. No hosted write has run.

Gate 2 record SHA-256: 9E3378F3756E4157E48840CFDCE6F481292D35F6F21C8078D37D3F3C223A2A80. Original readiness SHA-256: 03D31D73D2299EA0368A0DD63ABEC8932325C70E441C10682EFC182ED3064D57.

### 2026-11-19 — Original Step 5 verified on Platinum Primary

One call applied the exact approved migration using the owner-authorized Platinum Plus Tours Supabase connector in Codex. The server returned success. Readback proved the stored 633 bytes against MD5 5134389A8B82410EC858573982FCC247, then the guarded reconciliation changed only the temporary ledger version to 20261119112137. Fresh readback proved one canonical entry, enabled BEFORE INSERT guard, invoker function with no API-role execute, unchanged task count (0), matching 272-entry ledger and all ten structural surfaces. Workbench readback SHA-256 474F3FD775B54877365205E3F8A9CAA8D68696BF1C7CAD5E9F01BCD6F5B9DC8D. Original Step 6 records those verified facts.

## Verification Notes

None.


### 2026-11-19 — Gate 1 approval recorded

Owner directly approved CRM SPEC-318 r2 Original Gate 1 for exact Draft SHA-256 AE2755380A2429721071776A41B94A54B570777BA0C9F3389D67A0A804581E23 in owner instruction OWNER-SPEC318-RUN-THROUGH.md (SHA-256 9DB89E5851377A8F5195E8EA188763FC227AD8F53B6DF48078E07B9228681E37). The current instruction sets Batch 6 PLAN section 2 Mode 2. Native sandbox approval 45fe50fa9e86cae09270fb8f304ffd1fe048671c passed; the unchanged checkpoint guard isolated only RECOVER-1. This record is Gate 1 only. Gate 2 is separate and depends on the exact artifact, current target, readiness and recovery. Immediately before allocation the hash, the Draft blob c466187285bb35fbd1899c27a201636d87312b14, all 2 source anchors, the baseline HEAD a17473dbe478a2c2268ce9c503bf6e4832b7affb against refreshed origin/main a17473dbe478a2c2268ce9c503bf6e4832b7affb and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 9d3837f. No implementation performed before this transition.


Verdict: Confirmed Complete

The Review checked the allocated Draft blob, all three frozen output blobs and the committed range independently of the implementation log. Native timed and watched Finish returned LOCAL_CERTIFY READY on a4b8c9ace84558e8be0747d82ce38ab2b53c4082 with receipt c993b81a9e7ed068ae382cf59e2246dc4dddc9b4d940c39a689ccc375bcfab7d. Both native database passes, Test 134, HTTP verification, smoke, parity, API equivalence and repository verification passed. The first Finish refusal was caused by missing native manifest hash labels. The corrected manifest passed the targeted parity check and the full new Finish. Primary readback proved the 272-entry ledger and all ten surfaces agree with local. RECOVER-1 is clean. The approved selector exception, tasks AUDITED-OPEN and the 17 due Batch 6 exit obligations are preserved. This Review covers this CRM correction and verified Primary deployment.


Native Review and Complete close the Original on its fresh, matching Finish and verified Primary evidence. Candidate binding follows Complete. The native release gates still apply to this exact candidate.

## Review Gate

- [x] Exact payload and scope matched.
- [x] Test 134, native database verification, smoke and API equivalence are backed by actual results.
- [x] Primary state, ledger, suite counts and regenerated discovery match the verified evidence.
- [x] ARCH-2 and all other unresolved findings remain correctly classified.

## Notes

Baseline: a17473dbe478a2c2268ce9c503bf6e4832b7affb.

Owner authority: Workbench `data/records/batch6/entry1-task-creation/OWNER-DRAFT-APPROVAL.txt`, SHA-256 `54BF876E399BB64B9FE8B02E391AFF11E1BB3C4B8609BE5AABA899085646D68C`.

Correction authority: Workbench `data/records/batch6/entry1-task-creation/r2/OWNER-DRAFT-REMEDIATION.txt`, SHA-256 `96B5CFBECC53A96E1E9467D57A2664836758F4E3EA875F308AE92D281C9E6293`. The first freeze and refusal are retained in the parent packet.

Isolated proof in the parent packet: `isolated-pgtap.log`, `isolated-smoke.log`, `isolated-catalog.log`, `isolated-parity.log` and `generated-api-contract.md`. The native selector evidence is the S17 P8 CRM selector result corroborated by the SPEC-317 certified registry at this baseline. Finance, integration and legal obligations remain with their existing registry rows.

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/134_task_queue_authority_test.sql` | `9ffa7c4159154176b8c862824d790fe78a451765` |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `5ca456b301a3d32f40888b4d01375005b78d2841` |
