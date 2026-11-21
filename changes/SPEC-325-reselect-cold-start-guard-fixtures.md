# Change Request — SPEC-325

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Re-select the two cold-start guard fixtures that SPEC-324 made stale, by shape from the live records at 35560623dcd4405204f72034170d78ab618379ea, so the guard-of-the-guard suite passes again with its full strength and no longer depends on one named row staying open.

## Business Reason

SPEC-324 is Complete and bound at 35560623dcd4405204f72034170d78ab618379ea but cannot be released. Its hosted preflight failed in the step "Attack the guards themselves" for Repository Consistency and ORVION Acceptance. A local reproduction at 35560623dcd4405204f72034170d78ab618379ea proved the cause: in `scripts/test_cold_start_state_guard.ps1`, fixture C1 was pinned to the ARCH-2 register row and fixture F3 to the ENTRY-1 obligation, and SPEC-324 itself closed both. The suite reported 40 passed and 2 failed; the other four hosted guard suites pass. Releasing this repair carries SPEC-324 to main and aligns CRM main with Primary, which already holds migration 20261121100000.

## Risks

A fixture repair could weaken the guard it attacks. Both mutations keep their exact assertions: C1 still requires the UNSURFACED DECISION refusal and C2 still requires its absence after the row gains a decider; F3 still requires a non-zero exit with an OVERDUE line at the probed REACHED boundary. A new precondition fails the suite if no register row has the required shape, so the mutation can never pass vacuously. No product code, guard, workflow, record or database changes.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-325-reselect-cold-start-guard-fixtures.md`
- `scripts/test_cold_start_state_guard.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/test_future_date_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `.github/workflows/repository-consistency.yml`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`

Other product code, schema, tests, records, roles, CI and all external writes are outside the exact Write Scope.

## Required Reading

- `CR_LIFECYCLE.md` §§4–9 and `ENGINEERING_METHOD.md` §2.
- `scripts/test_cold_start_state_guard.ps1` sections C and F.
- `scripts/check_repository_consistency.ps1` Checks 25 and 29.
- `.github/workflows/repository-consistency.yml` step "Attack the guards themselves".

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- pwsh -NoProfile -File scripts/test_future_date_guard.ps1
- pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1
- pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1
- pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1
- pwsh -NoProfile -File scripts/readiness_selftest.ps1

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Replace the two pinned fixtures with shape selection. C1 and C2 take the first register row whose status cell opens with OPEN, still says NOT fixed and has no decider; F3 matches any OVERDUE item at the probed REACHED boundary. A precondition check proves the selected row exists.

Pass 2 Adversarial Review: The precondition reads the status cell, not the whole row, so a row whose history merely mentions OPEN cannot satisfy it. The assertions of C1, C2 and F3 are unchanged in strength. The five hosted guard suites are named in Additional Verification so the native Finish runs them locally, closing the gap that let SPEC-324 reach hosted preflight with a failing suite. Revision 2 adds the Permanent-Control Admission subsection that the native evaluator derives for a `scripts/test_*` path; revision 1 was refused for its absence in the isolated sandbox before any original authority was used.

Pass 3 Evidence Refresh: 2026-11-21. At 35560623dcd4405204f72034170d78ab618379ea in an isolated full-history clone carrying the repair, all five hosted guard suites passed, including the cold-start suite with C-precondition, C1, C2 and F3. The unrepaired suite at the same baseline reported 40 passed and 2 failed.

Selected Version: SPEC-325; selected: the two stale fixtures re-selected by shape from the live register and plan, with a precondition that proves the selected row exists, so the guard keeps its strength and stops depending on one row staying open

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| C1, C2 and F3 fixture selection | Hosted step "Attack the guards themselves" in Repository Consistency and ORVION Acceptance | WRITE | The same suite command passes with the same assertions. |
| Check 25 and Check 29 behavior | `scripts/check_repository_consistency.ps1` | UNAFFECTED | The guard is unchanged; only the probe input row changes. |
| Register and plan records | `MASTER_GAP_REGISTER.md` and `MASTER_EXECUTION_PLAN.md` | UNAFFECTED | The suite mutates copies only; the records are unchanged. |
| Native lifecycle metadata | Active Change Request, Last Completed and discovery projections | WRITE | Native lifecycle synchronization only. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Approved source anchor and exact suite payload | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| All five hosted guard suites pass | BEFORE_COMPLETION | NONE | NONE | 2 |
| Matching native verification evidence | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `scripts/test_cold_start_state_guard.ps1` already attacks Check 25 (unsurfaced decision) and Check 29 (overdue boundary) of `scripts/check_repository_consistency.ps1` by mutating copies of the register and plan; this change adds no new control and reuses the suite, the guard and the hosted step unchanged.

Added Property: The C1, C2 and F3 fixtures are selected by shape from the live register and plan, and a precondition fails the suite when no register row has the required shape, so the attack can never pass vacuously and no longer depends on one named row staying open.

Causal Negative: At `35560623dcd4405204f72034170d78ab618379ea` the unrepaired suite reported 40 passed and 2 failed (C1 pinned to ARCH-2, F3 pinned to ENTRY-1), reproduced locally and in hosted preflight runs 44856585926 (Repository Consistency) and 44856585921 (ORVION Acceptance).

Positive Test Design: C2 still requires the UNSURFACED DECISION refusal for the selected row to disappear once its status leads with VERIFIED, and the unmutated records still pass the guard after each restore.

Negative Test Design: C1 still requires a non-zero guard exit with the UNSURFACED DECISION refusal for the selected no-decider OPEN row once it gains a decider; F3 still requires a non-zero exit with an OVERDUE line at the probed REACHED B6-EXIT boundary.

Non-Empty Population Obligation: C-precondition proves at least one register row whose status cell opens with OPEN, contains NOT fixed and has no decider; F3 requires at least one OVERDUE item at the probed boundary.

Mutation Obligation: Removing the required shape from every register row must turn C-precondition red; restoring the old pinned ARCH-2 and ENTRY-1 literals must reproduce the 40 passed and 2 failed result at `35560623dcd4405204f72034170d78ab618379ea`.

Post-Implementation Proof Obligation: The native Finish runs all five hosted guard suites through Additional Verification with zero failures, and the hosted Repository Consistency and ORVION Acceptance preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `scripts/test_cold_start_state_guard.ps1` contains `ARCH-2 itself closed at CRM SPEC-324`; if so record Already Applied when its Git blob is 2ddd674cc7b372c0a74e5997bfee206570f2f49d, and otherwise stop and report. Otherwise make exactly these 5 edits (the shape-selected cold-start guard fixtures), each matched once, and change nothing else:

   a) replace the line
   ```text
       # ARCH-2's row is the exact live false-negative: its status OPENS with `**OPEN - engineering,
   ```
   with
   ```text
       # The exact live false-negative was ARCH-2's row: its status OPENED with `**OPEN - engineering,
   ```

   b) replace the lines
   ```text
       # FIXED as a settled verdict. Its Owner-Decision cell is currently `-` (no decider), so it sits
       # outside Check 25's population; giving it one puts it in.
       $archRow = (($registerOriginal -split "`r?`n") | Where-Object { $_ -match '^\|\s*ARCH-2\s*\|' } | Select-Object -First 1)
       Check 'C-precondition: ARCH-2 opens OPEN and contains the word FIXED inside its status' `
           ($archRow -and $archRow -match 'OPEN' -and $archRow -match 'NOT fixed')
   ```
   with
   ```text
       # FIXED as a settled verdict. ARCH-2 itself closed at CRM SPEC-324, so the site is now SELECTED:
       # the first register row whose status cell itself OPENS with **OPEN, still says NOT fixed, and has
       # no decider (Owner-Decision `-`), so it sits outside Check 25's population until given one. The
       # precondition reads the status CELL, not the whole row, so a row whose history merely mentions
       # OPEN can never satisfy it vacuously again.
       $archRow = (($registerOriginal -split "`r?`n") | Where-Object {
           $c = $_ -split '\|'
           $_ -match '^\|\s*[A-Z][A-Z0-9]*-\d+[a-z]?\s*\|' -and $c.Count -gt 10 -and
           $c[9] -match '^\s*\*\*OPEN' -and $c[9] -match 'NOT fixed' -and $c[10].Trim() -in @('-', [string][char]0x2014)
       } | Select-Object -First 1)
       $archId = if ($archRow) { ($archRow -split '\|')[1].Trim() } else { '' }
       Check "C-precondition: a no-decider register row ($archId) whose status cell opens OPEN and contains the word FIXED" `
           ($archRow -and ($archRow -split '\|')[9] -match '^\s*\*\*OPEN' -and ($archRow -split '\|')[9] -match 'NOT fixed')
   ```

   c) replace the line
   ```text
           ($r.Exit -ne 0 -and $r.Text -match "UNSURFACED DECISION: register entry 'ARCH-2'") $r.Exit
   ```
   with
   ```text
           ($r.Exit -ne 0 -and $r.Text -match "UNSURFACED DECISION: register entry '$([regex]::Escape($archId))'") $r.Exit
   ```

   d) replace the line
   ```text
           ($r.Exit -eq 0 -and $r.Text -notmatch "UNSURFACED DECISION: register entry 'ARCH-2'") $r.Exit
   ```
   with
   ```text
           ($r.Exit -eq 0 -and $r.Text -notmatch "UNSURFACED DECISION: register entry '$([regex]::Escape($archId))'") $r.Exit
   ```

   e) replace the line
   ```text
           ($r.Exit -ne 0 -and $r.Text -match 'OVERDUE: ENTRY-1 -- boundary B6-EXIT') $r.Exit
   ```
   with
   ```text
           ($r.Exit -ne 0 -and $r.Text -match 'OVERDUE: \S+ -- boundary B6-EXIT is REACHED 2026-10-12 probe') $r.Exit
   ```

   The resulting file's Git blob is 2ddd674cc7b372c0a74e5997bfee206570f2f49d.

2. **Verify and synchronize.** Run the five hosted guard suites named in Additional Verification and the native repository guard. Confirm the exact scope and `git diff --check`. Synchronize the contract and native discovery artifacts. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-325: CRM cold-start guard fixtures re-selected after SPEC-324.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] The cold-start guard suite selects its fixtures by shape and proves the selected row exists. `check: blob scripts/test_cold_start_state_guard.ps1 2ddd674cc7b372c0a74e5997bfee206570f2f49d`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @35560623dcd4405204f72034170d78ab618379ea`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @35560623dcd4405204f72034170d78ab618379ea`
- [ ] The other hosted guard suites are preserved. `check: same scripts/readiness_selftest.ps1 @35560623dcd4405204f72034170d78ab618379ea`
- [ ] The hosted guard workflow is preserved. `check: same .github/workflows/repository-consistency.yml @35560623dcd4405204f72034170d78ab618379ea`
- [ ] All five hosted guard suites pass in the native Finish.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 35560623dcd4405204f72034170d78ab618379ea (SPEC-324 Complete and bound, not yet released; main is 73b02a1).

Authority: DELEGATED under the Workbench Batch 6 run mode 2 record, answered by the constitution; never typed by the owner. The SPEC-324 hosted preflight evidence is Workbench `data/records/batch6/exit-bundle-a/r3/release/RELEASE-RESULT.json`.

| Path | Baseline Git blob |
| --- | --- |
| `scripts/test_cold_start_state_guard.ps1` | `fe24d2775e9482c063dcf59e859f2c1fc4cd3a71` |
