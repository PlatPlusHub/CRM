# Change Request — SPEC-340

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Deliver what SPEC-339 approved. SPEC-339's implementation (af450d4) records the Foundation Completion Programme exit `B6-EXIT` as REACHED: the boundary row with its evidence, EC-2, EC-3, EC-4 and EC-11 met, the canonical manifest naming the readiness gate next with its `GOVERNANCE.md` §6 pins, and the cold-start guard's F3 witness naming PAY-9. Its native Finish passed every CONTROL and REPOSITORY check. But its Additional Verification named `scripts/verify_api_end_to_end.ps1`, a suite that needs a freshly reset database, while its Write Scope derived no DATABASE profile, so no reset ran and the suite refused (ADDITIONAL_VERIFICATION_FAILED). SPEC-339 was Cancelled at 78c71bdc86b246090e327e6b9e31e85880564ad0. This successor carries that implementation unchanged, names only the guard suites its derived profiles run, and adds one step: the plan's dated header names the carry and where DATABASE readiness rests. `GATE-EVAL` stays NOT REACHED. FE-0 and Phase 8 transport are not started.

## Business Reason

The exit is met and its record is correct and already proven, but a contract that cannot Finish delivers nothing (DEC-33 rule 12): until a terminal contract records the boundary, every agent's cold start reads Batch 6 as open. The native route for an approved contract that cannot finish is Cancel plus one successor named in Supersedes (CR_LIFECYCLE section 4; SPEC-335 → SPEC-336 carried a committed implementation forward unchanged). The smallest successor changes only the verification its derived profiles cannot run and the one line that records why (DEC-33 rule 3).

## Risks

The carried outputs are not rewritten, so a carried defect would pass through; each is bound by its exact Git blob or measured text below, and this contract's own Finish reruns every CONTROL and REPOSITORY check and the five hosted guard suites on them. DATABASE readiness is not rerun: this contract changes no database path, no DATABASE path changed between `3792b61`, where the SPEC-338 Original Finish proved the full DATABASE protocol, and 78c71bdc86b246090e327e6b9e31e85880564ad0, and the Finish derives no DATABASE profile. A REACHED boundary makes any open member classified at it OVERDUE (Check 29); at 78c71bdc86b246090e327e6b9e31e85880564ad0 none is, and the registry reports complete with nothing overdue. This contract changes no migration, function, policy, grant, test SQL or database object, and it moves no other boundary.

## Supersedes / Depends On

Supersedes `changes/SPEC-339-batch-6-exit-is-reached.md` (Cancelled at 78c71bdc86b246090e327e6b9e31e85880564ad0) and carries its committed implementation af450d4 unchanged. Depends on SPEC-338 (EC-5 met; Original Finish READY on `3792b61`) and the SPEC-330 planted F3 witness. Those terminal contracts are immutable.

## Write Scope

- `changes/SPEC-340-batch-6-exit-is-carried-and-reached.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `GOVERNANCE.md`
- `scripts/test_cold_start_state_guard.ps1`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_API_CONTRACT.md`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `.github/workflows/repository-consistency.yml`
- `supabase/config.toml`

Migrations, product code, test SQL, reaching `GATE-EVAL` or any other boundary, the repair of any finding, starting FE-0 or Phase 8 transport, any Primary write, Founder Secondary, frontend work, integration activation, email delivery and every owner decision are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9.
- `changes/SPEC-339-batch-6-exit-is-reached.md`: the cancelled contract this one carries.
- `reports/master/MASTER_EXECUTION_PLAN.md`: the exit criteria EC-1…EC-11, the boundary table and the registry rules.
- `scripts/readiness_population.ps1`: the OVERDUE rule.
- `scripts/test_cold_start_state_guard.ps1`: section F.
- `GOVERNANCE.md` §6 rule 10 and its pin table; `scripts/check_agent_continuity.ps1`: `Profiles`, `Validate-DatabaseContract` and `Validate-PinnedAuthority`.

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- pwsh -NoProfile -File scripts/test_future_date_guard.ps1
- pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1
- pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1
- pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1
- pwsh -NoProfile -File scripts/readiness_selftest.ps1

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: One literal step writes the plan's dated SPEC-340 header and demotes the SPEC-339 header to `Previously:`. The four SPEC-339 outputs are already at 78c71bdc86b246090e327e6b9e31e85880564ad0 through its committed implementation af450d4: the plan's REACHED row and evidence, the manifest lines, the `GOVERNANCE.md` §6 pins and the cold-start guard. Acceptance Criteria bind each by its exact Git blob or measured text, so no step rewrites them and any drift fails Complete.

Pass 2 Adversarial Review: SPEC-339's refusal is answered at its cause. Additional Verification now names only the five guard suites, each of which runs without a database, and the Write Scope derives CONTROL and REPOSITORY, so the product's own `Validate-DatabaseContract` has nothing to require. The Workbench rehearsal rig now refuses a Draft whose Additional Verification names a `scripts/verify_` suite while its Write Scope derives no DATABASE profile; the guard refuses SPEC-339 and passes SPEC-336 and this Draft. Adding a database path to Write Scope only to derive DATABASE, or resetting the database by hand, would bend the gate to fit the test, so both were rejected. The carried blobs equal SPEC-339's approved payload (manifest text, GOVERNANCE `0f2f6361`, guard `ff8f70c7`). A sandbox Complete runs before the original Approve.

Pass 3 Evidence Refresh: 2026-11-25. In an isolated clone at 78c71bdc86b246090e327e6b9e31e85880564ad0 carrying the payload, native repository consistency was CLEAN, and all five hosted guard suites passed with 0 failed: future-date 19, status contradiction 38, primary ledger 13, cold-start 42 and readiness self-test 33. SPEC-339's own Finish at af450d4, the same four outputs, passed all five CONTROL suites, the repository guard and `git diff --check` before the refused Additional suite. `git diff` from `3792b61` to 78c71bdc86b246090e327e6b9e31e85880564ad0 names no `supabase/`, `scripts/verify_database.sql` or `MASTER_DATABASE_` path.

Selected Version: SPEC-340; selected: carry the cancelled SPEC-339 implementation af450d4 unchanged (SPEC-335 to SPEC-336 precedent), name only the guard suites its derived CONTROL and REPOSITORY profiles run, and add the one dated plan header that says where DATABASE readiness rests, the smallest change that records B6-EXIT with every one of its checks

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Plan header dated SPEC-340 | Check 21 and agent cold start | WRITE | One new dated line; the SPEC-339 header becomes `Previously:` unchanged; the candidate tree is CLEAN. |
| Carried boundary row `B6-EXIT` REACHED | Check 29 (`readiness_population.ps1`) | WRITE | No open member is classified at `B6-EXIT`; REGISTRY complete, nothing overdue. |
| Carried manifest lines and their §6 pins | Check 846, `ai-map.json`, `GOVERNANCE.md` §6 and `Validate-PinnedAuthority` | WRITE | Same text and blobs as af450d4; the ai-map next capability equals the manifest; the candidate tree is CLEAN. |
| Carried cold-start guard section F | Hosted guard suites and `repository-consistency.yml` | WRITE | 42 passed, 0 failed; F3 names PAY-9. |
| Additional Verification without `scripts/verify_api_end_to_end.ps1` | Native Finish profiles CONTROL and REPOSITORY | VERIFY | Every named suite runs without a database; DATABASE readiness rests on the SPEC-338 Original Finish on `3792b61`. |
| Schema, grants, policies and API | Every product consumer | UNAFFECTED | No migration; no DATABASE path changed since `3792b61`; the API contract has the same blob as the baseline. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchors and exact payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Checks 21, 29 and 846, the §6 pins and the five hosted guard suites pass | BEFORE_COMPLETION | NONE | NONE | 2 |
| Matching native verification evidence | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: Check 29 in `scripts/readiness_population.ps1` and its mutation witness F3 in `scripts/test_cold_start_state_guard.ps1`, as carried from SPEC-339.

Added Property: None beyond SPEC-339's: once `B6-EXIT` is REACHED, a member classified at it while still open fails as OVERDUE, and the guard proves this on the live REACHED row.

Causal Negative: At `7b3e35e` the F-precondition requires `| Batch 6, this plan | NEXT |`, so recording the boundary without SPEC-339's guard change fails the cold-start guard (SPEC-339 evidence).

Positive Test Design: On the new tree, the registry reports complete with nothing overdue, and the untouched copy is CLEAN.

Negative Test Design: F3 moves PAY-9's open row to `B6-EXIT`, and the consistency check must exit non-zero with `OVERDUE: PAY-9 -- boundary B6-EXIT is REACHED 2026-11-24 SPEC-339`.

Non-Empty Population Obligation: The F-precondition first asserts that the registry classifies PAY-9 and that the live plan carries the REACHED `B6-EXIT` row.

Mutation Obligation: The carried guard blob equals the bytes SPEC-339's F3 ran against; F3 must fail as stated, and F-restore must return CLEAN.

Post-Implementation Proof Obligation: The native Finish runs the repository guard and all five hosted guard suites through Additional Verification with zero failures, and the hosted Repository Consistency and ORVION Acceptance preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Last updated: 2026-11-25 (CRM exit bundle M, SPEC-340`; if so record Already Applied when its Git blob is dd50b17c2a1d954c24769bac8fb3280048751acd, and otherwise stop and report. Otherwise make exactly this one edit (the dated SPEC-340 header that names the carry and where DATABASE readiness rests, with the SPEC-339 header demoted to Previously), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-24 (CRM exit bundle M, SPEC-339. `B6-EXIT` is REACHED: EC-1…EC-11 hold at `7b3e35e`. EC-2, EC-3, EC-4 and EC-11 are confirmed by the SPEC-338 Original Finish on `3792b61` (its `supabase` tree equals `7b3e35e`) ran 198 test files and 3960 assertions READY, receipt `366e63c5…f274`, Tests 54, 57, 58, 88, 186 and 187 among them; the readiness registry has no open member at `B6-EXIT` and 0 of 78 surfaces lack a recorded disposition; EC-9 was re-read from Primary on 2026-11-24 and is unchanged. `GATE-EVAL` stays NOT REACHED; FE-0 and Phase 8 transport keep their own gates.)
   ```
   with
   ```text
   Last updated: 2026-11-25 (CRM exit bundle M, SPEC-340 carries the cancelled SPEC-339 unchanged: its implementation `af450d4` records `B6-EXIT` REACHED, and SPEC-340 adds only this line. DATABASE readiness rests on the SPEC-338 Original Finish on `3792b61`, whose `supabase` tree equals `7b3e35e` and is unchanged since, so SPEC-340 changes no database path and its Finish derives no DATABASE profile.)

   Previously: 2026-11-24 (CRM exit bundle M, SPEC-339. `B6-EXIT` is REACHED: EC-1…EC-11 hold at `7b3e35e`. EC-2, EC-3, EC-4 and EC-11 are confirmed by the SPEC-338 Original Finish on `3792b61` (its `supabase` tree equals `7b3e35e`) ran 198 test files and 3960 assertions READY, receipt `366e63c5…f274`, Tests 54, 57, 58, 88, 186 and 187 among them; the readiness registry has no open member at `B6-EXIT` and 0 of 78 surfaces lack a recorded disposition; EC-9 was re-read from Primary on 2026-11-24 and is unchanged. `GATE-EVAL` stays NOT REACHED; FE-0 and Phase 8 transport keep their own gates.)
   ```

   The resulting file's Git blob is dd50b17c2a1d954c24769bac8fb3280048751acd.

2. **Verify and synchronize.** Run the native repository guard and the five hosted guard suites named in Additional Verification. Confirm that `readiness_population.ps1` reports REGISTRY complete with no member at `B6-EXIT`, and that the `supabase` tree equals the baseline's. Confirm the exact scope and `git diff --check`. Make no Primary write. Synchronize the contract and native discovery artifacts, set Runtime Checkpoint DONE and commit the implementation. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-340: Batch 6 exit is carried and reached.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] The plan records the carry and the REACHED boundary with its evidence. `check: blob reports/master/MASTER_EXECUTION_PLAN.md dd50b17c2a1d954c24769bac8fb3280048751acd`
- [ ] The manifest records Batch 6 complete (carried). `check: has _ORVION_CANONICAL/manifest.md "is REACHED (SPEC-339); exit criteria EC-1…EC-11"`
- [ ] The §6 pins name the new manifest lines and their owners (carried). `check: blob GOVERNANCE.md 0f2f6361495f68d6254087bb0a465f0d4e88c61c`
- [ ] The cold-start guard proves Check 29 on the REACHED boundary (carried). `check: blob scripts/test_cold_start_state_guard.ps1 ff8f70c79c6f86c4b8b8742802e62b8f655028b7`
- [ ] The API contract is unchanged. `check: same reports/master/MASTER_API_CONTRACT.md @78c71bdc86b246090e327e6b9e31e85880564ad0`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @78c71bdc86b246090e327e6b9e31e85880564ad0`
- [ ] The registry self-test is preserved. `check: same scripts/readiness_selftest.ps1 @78c71bdc86b246090e327e6b9e31e85880564ad0`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @78c71bdc86b246090e327e6b9e31e85880564ad0`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @78c71bdc86b246090e327e6b9e31e85880564ad0`
- [ ] Repository consistency is CLEAN and all five hosted guard suites pass in the native Finish; `GATE-EVAL` stays NOT REACHED.

## Execution Log

None.


### 2026-11-25 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was 78c71bdc86b246090e327e6b9e31e85880564ad0 and every source anchor matched there; Draft allocated as b6de3d0 and approved as baeec7c with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `reports/master/MASTER_EXECUTION_PLAN.md` edited exactly as the step states; blob dd50b17c2a1d954c24769bac8fb3280048751acd (3 insertions, 1 deletions).
- Step 3 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain.

## Verification Notes

None.


### 2026-11-25 — Gate 1 approval recorded

DELEGATED Original Gate 1 for CRM SPEC-340 only under DEC-02 in the owner AFK Mode (owner-2026-11-23-modes-any-session.txt, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73) and the owner words to finish all plan (owner-2026-11-24-afk-finish-all-plan.txt, SHA-256 C155D6191185693D3DBBA01471540EA16A2C6BB0C6B835FFC08B82E792B968DE), continuing Batch 6 under the owner OD-9 decision of 2026-11-22 (SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D) and the owner prompt to continue until the Batch 6 Finish (SHA-256 7D2A8B8F0F209C8538B0D87F133C440DBB620C2577DEAECF8F3D312584C94759); CTRL-19 accepted residual by the owner (owner-2026-11-23-ctrl19-declined.txt, SHA-256 6882D7C5A1E1C71B05EE8AD878DD72100821972811F1E1358CA022623D333124). Exact Draft SHA-256 F79CB9ADE8EE99C5C9ECC091414F2E3A20B24B718D013FD1FD4257ED334881BF, Git blob d58cced6200f54fc15531407597f3df0e239e722, CRM baseline 78c71bd (the SPEC-339 Cancel). The one successor of the Cancelled SPEC-339: carries its implementation af450d4 unchanged and adds one dated plan header. Native isolated Approve 48ddaf1 and implement 11e168e passed (1 committed blob verified), the product criterion checks on the sandbox tree passed 9 of 9, and the native repository consistency on the sandbox final tree is CLEAN (sandbox-final-consistency.log SHA-256 2BCDFA78906C55A4F38BA029BF083F5BB4D77AEC0D308A7B798D64D9838B0047). Derived profiles CONTROL and REPOSITORY; no migration, no Primary write. Gate 1 only. Immediately before allocation the hash, the Draft blob d58cced6200f54fc15531407597f3df0e239e722, all 1 source anchors, the baseline HEAD 78c71bdc86b246090e327e6b9e31e85880564ad0 against refreshed origin/main 7b3e35e60351b27b57fda6abdae42bae2c271b3c and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as b6de3d0. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 78c71bdc86b246090e327e6b9e31e85880564ad0 (the SPEC-339 Cancel; its implementation af450d4 is carried; origin/main is `7b3e35e`, SPEC-338 Complete and released).

Authority: DELEGATED under the owner's AFK Mode and answered by the constitution; never typed by the owner. This contract grants nothing beyond the following owner's words:

- 2026-11-24 23:27:22 Cairo, Workbench `data/records/WS-049/owner-words/owner-2026-11-24-afk-finish-all-plan.txt`, SHA-256 C155D6191185693D3DBBA01471540EA16A2C6BB0C6B835FFC08B82E792B968DE: continue to finish all plan.
- 2026-11-21, `data/records/WS-046/owner-words/owner-2026-11-21-constitution-decides-in-my-absence.txt`, SHA-256 DB34F67C2AF82D9A9751597247ABEEBD74B4BBB1CC6F47291D2572FE080EEAB0: the constitution decides in the owner's absence.
- 2026-11-23, `data/records/batch6/owner-words/owner-2026-11-23-modes-any-session.txt`, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73: AFK Mode is a tool that decides by the project's rules and widens nothing.
- 2026-11-22, `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D: Batch 6 finishes first.
- 2026-11-23, `data/records/WS-048/owner-words/owner-2026-11-23-continue-until-b6-finish.txt`, SHA-256 7D2A8B8F0F209C8538B0D87F133C440DBB620C2577DEAECF8F3D312584C94759: the delegation continues until the Batch 6 Finish.

The evidence is Workbench `data/records/batch6/exit-bundle-m/`: `spec339/DELEGATED-CANCEL.md` records the Cancel and this successor, `spec339/r2/` holds SPEC-339's payload and refused Finish, and `spec340/` holds this Draft's consistency log, guard suites and rig guard proof.

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `cb7ef900646a7f31fd27b74c6d4866ea7131caa9` |
