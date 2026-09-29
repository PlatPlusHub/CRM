# Change Request — SPEC-241

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Repair one stale self-test expectation so that the completed SPEC-240 can be published. `scripts/test_cold_start_state_guard.ps1` pins the size of the manifest's open-owner-decision enumeration at `2`. The enumeration is now `MAIL-1`, `RET-1`, `PH8-10`: three ids, correctly derived and validated by Check 25. Change the pin's two expectation sites from `2` to `3`, keeping the count an explicit, hardcoded pin. Nothing else changes.

## Business Reason

SPEC-240 (PH8-4) is Complete and deployed to Primary, and its candidate `66bf1b2b647f86771413c10dc7cb46de5a742da6` was published to `orvion-preflight`. Candidate CI failed two of its four workflows:
- **Repository Consistency** (run `36600463823`);
- **ORVION Acceptance** (run `36600463643`).

Migration CI and Agent Control passed. Both failures are the same line in the "Attack the guards themselves" step, which runs four guard self-test suites, stopping at the first failure:

`FAIL CONTROL: the open-decision set is the current ENUMERATION (2)`

- **The defect.** `scripts/test_cold_start_state_guard.ps1` lines 103–104 assert the description `the current ENUMERATION (2)` and the guard output `checked against 2 open id(s)`. SPEC-240 correctly added `PH8-10` to the manifest's `Open owner decisions` enumeration: Check 25 demands every decider-bearing register entry appear there. The real guard now reports `checked against 3 open id(s)`. The self-test runs only in CI, never in local `-Finish`, which is why SPEC-240's gates did not see it.
- **Precedent.** The same pin was updated deliberately when the decision set last changed, from 10 to 2, in `f1145b3` (2026-09-09, "fix stale cold-start guard expectations").
- **Why a separate contract.** SPEC-240 is terminal and this file was never in its Write Scope. SPEC-240 is neither reopened nor rewritten, and the rejected candidate `66bf1b2` is not promoted. The next candidate is SPEC-240 Complete plus this contract.
- **Prototype, measured at the exact candidate `66bf1b2` in a clean scratch worktree, invoked as CI invokes it (`pwsh -File scripts/<suite>.ps1` from the repository root):**

  | Suite | Unmodified | With the two-line repair |
  | --- | --- | --- |
  | `test_future_date_guard` | exit 0 | exit 0, `FUTURE-DATE GUARD TEST: 18 passed, 0 failed` |
  | `test_status_contradiction_guard` | exit 0, 33 passed / 0 failed | exit 0, 33 / 0 |
  | `test_primary_ledger_guard` | exit 0, 13 passed / 0 failed | exit 0, 13 / 0 |
  | `test_cold_start_state_guard` | **exit 1, 33 passed / 1 failed**, the ENUMERATION (2) control | **exit 0, 34 passed / 0 failed** |

  - Repository consistency on the repaired tree: `REPOSITORY CONSISTENCY: CLEAN`, exit 0. It reports "checked against 3 open id(s)".
  - `git diff --check`: exit 0.
  - The manifest's enumeration is exactly `**MAIL-1**, **RET-1**, **PH8-10**`.
  - No other site in the file depends on the enumeration's size. The other decision checks key on `**MAIL-1**, ` inside the enumeration and stay valid with three ids.
- **Load-bearing proof.** Restoring `2` in both sites (bytes identical to the baseline) gives exit 1, 33 / 1, failing the same control. Restoring the repair gives exit 0, 34 / 0, and the repaired hash again.

## Risks

- **A pin that must be updated by hand can go stale again.** Intended: the pin exists so that a change to the owner-decision enumeration must be deliberate and visible in a guard. Deriving the expected count from the manifest would compare the guard with the state it tests, and it would pass any enumeration. The recurrence cost is carried by the owner's standing rule that any future change to the enumeration updates this self-test.
- **The lifecycle writes the manifest and `ai-map.json`.** The Gate requires the pointer to follow the contract's Status (`ORPHANED_APPROVED_CR`, `MANIFEST_CR_CONTRADICTION`), and the write-closure rule requires `ai-map.json` with any manifest write (Check 7).
  - **Approve** sets `Active Change Request` to this contract and changes nothing else.
  - **Complete**, per `CR_LIFECYCLE.md`, clears the pointer, sets `Last Completed` to this contract and reaffirms `Next capability` as the Phase-8 Activation Closure. PH8-9 remains its next dependency-ready work.

  The open-decision enumeration and every measured figure are untouched. Measured at `66bf1b2`: the manifest is 6935 characters, the Approve peak with the pointer is 6984, and the projected Complete state is 6825, all within the unchanged 7000 budget. Execution re-measures each.
- **Primary is ahead of `main` until promotion.** Primary holds 239 migrations while `main`'s recorded evidence says 238. CI never reads Primary live, so `main` stays self-consistent. Promoting the new candidate closes the gap. This contract makes no database write.

## Supersedes / Depends On

Depends on: `changes/SPEC-240-a-google-ads-call-qualifies-as-a-phone-call.md` (Complete; its candidate is this contract's parent). It is not modified.

## Write Scope

- `changes/SPEC-241-the-open-decision-pin-counts-three.md`
- `scripts/test_cold_start_state_guard.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-240-a-google-ads-call-qualifies-as-a-phone-call.md`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_future_date_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `reports/evidence/primary-ledger-evidence.json`
- `supabase/migrations/20260929160000_a_google_ads_call_qualifies_as_a_phone_call.sql`
- `supabase/tests/142_a_google_ads_call_qualifies_as_a_phone_call_test.sql`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `scripts/test_cold_start_state_guard.ps1`; `scripts/check_repository_consistency.ps1` Check 25
- `.github/workflows/orvion-acceptance.yml` and `.github/workflows/repository-consistency.yml` ("Attack the guards themselves")
- `changes/SPEC-240-a-google-ads-call-qualifies-as-a-phone-call.md` (Execution Log and Verification Notes)

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- `pwsh -File scripts/test_future_date_guard.ps1`
- `pwsh -File scripts/test_status_contradiction_guard.ps1`
- `pwsh -File scripts/test_primary_ledger_guard.ps1`
- `pwsh -File scripts/test_cold_start_state_guard.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| The cold-start guard's pinned open-decision count becomes 3 | CI "Attack the guards themselves" in `orvion-acceptance.yml` and `repository-consistency.yml`; the file's other checks | VERIFY | At `66bf1b2` the suite fails 33 / 1 on this pin alone; with the repair it passes 34 / 0. The other three suites pass unchanged, and the file's other decision checks pass with three ids. Script LF SHA-256 before `3c6415ceff47de87ca1e2b3f13d5ae267b2c066870dea6a1970599f172a61310`, after `14d3fcdc9019e6db3663316cef70764ac4614795bc64ef331f618e75b8bf8f9e`. |
| Manifest lifecycle fields: the `Active Change Request` pointer (None → this contract → None), and at Complete `Last Completed` → this contract with `Next capability` reaffirmed | Boot; Checks 5, 7 and 25; `ORPHANED_APPROVED_CR`; `MANIFEST_CR_CONTRADICTION` | WRITE | Lifecycle bookkeeping only, per `CR_LIFECYCLE.md` Complete. `Next capability` stays the Phase-8 Activation Closure. The open-decision enumeration `MAIL-1`, `RET-1`, `PH8-10` and every live database and repository figure are unchanged. Measured 6935 → 6984 at Approve → 6825 at Complete, within 7000. |
| `ai-map.json` regenerated | Check 7 | WRITE | Canonical generator only, stored LF. During execution `live_state.active_change_request` names this contract. At Complete it agrees with the manifest by value: relative to `66bf1b2` it may differ only in `generated_at` and `live_state.last_completed`, and `active_change_request` returns to None. Any other semantic difference stops execution. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The four CI guard self-test suites pass | BEFORE_COMPLETION | NONE | NONE | Step 2 |
| `ai-map.json` matches its generator | BEFORE_COMPLETION | NONE | NONE | Step 2 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: the existing pinned CONTROL in `scripts/test_cold_start_state_guard.ps1`, updated deliberately as `f1145b3` did when the enumeration last changed. No new check, suite, script or mechanism is added. The alternatives were rejected:
- **Deriving the expected count from the manifest:** the guard would be measured against the state it tests and pass any enumeration. It weakens the guard (owner direction).
- **Deleting or loosening the control:** it would remove the only self-test that pins the enumeration's size.
- **Editing Check 25, the manifest's enumeration or the register:** each is correct. The stale party is the self-test alone.
- **Reopening or amending SPEC-240:** it is terminal, and its bytes stay unchanged.

Added Property: CI's cold-start guard suite passes only while the manifest's open-owner-decision enumeration holds exactly three ids. Any future change to that enumeration must deliberately update this pin, or CI goes red.

Causal Negative: On the published candidate `66bf1b2`, Repository Consistency and ORVION Acceptance failed on `CONTROL: the open-decision set is the current ENUMERATION (2)`. Locally, at the same SHA, the suite reports 33 passed, 1 failed.

Positive Test Design: At the repaired tree, run all four CI guard suites from the repository root and require exit 0 each, with 34 / 0 for the cold-start guard. Require repository consistency CLEAN, reporting 3 open ids.

Negative Test Design: With the expectation restored to `2` in both sites, the cold-start suite exits 1 with 33 / 1, failing exactly that control.

Non-Empty Population Obligation: The real repository at `66bf1b2`, whose manifest enumeration is `MAIL-1`, `RET-1`, `PH8-10`, whose register holds the three corresponding decider-bearing entries, and whose Check 25 reports 3 open ids.

Mutation Obligation: Restore `2` in both expectation sites (the result must be byte-identical to the baseline file) and prove the cold-start suite exits 1 with that control failing. Restore the repaired bytes and prove exit 0, 34 / 0, and the repaired SHA-256. Record this in the Execution Log at Step 2.

Post-Implementation Proof Obligation: All of the following on the final bytes:
- the four guard suites, repository consistency and `git diff --check`;
- canonical `-Finish` with `LOCAL_CERTIFY: READY`;
- exact-SHA candidate CI green in all four workflows (Agent Control, Repository Consistency, Migration CI, ORVION Acceptance);
- main CI after promotion, and `-Certify` with `REMOTE_CERTIFY: READY`.

## Implementation Steps

1. **Check** lines 103–104 of `scripts/test_cold_start_state_guard.ps1`.
   - If line 103 carries the description `the open-decision set is the current ENUMERATION (2)` and line 104 the match `checked against 2 open id\(s\)`, change `2` to `3` in exactly those two sites and nothing else. The file must then be LF with SHA-256 `14d3fcdc9019e6db3663316cef70764ac4614795bc64ef331f618e75b8bf8f9e`.
   - If the file already has that hash, record Already Applied.
   - If it differs in any other way, stop.
2. **Check** for a `Local certification` Execution Log entry. If absent:
   - Run the four guard suites from the repository root, repository consistency and `git diff --check`, and record each command and result.
   - Run the Mutation Obligation and record it.
   - Verify that the manifest's enumeration is exactly `MAIL-1`, `RET-1`, `PH8-10`, and that no SPEC-240 implementation file and no `supabase/**` path differs from `66bf1b2`.
   - Set Runtime Checkpoint DONE.
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review against every Acceptance Criterion. After `Verdict: Confirmed Complete`:
     - transition to Complete;
     - in the same commit, clear `Active Change Request`, set `Last Completed: **SPEC-241 corrected the cold-start open-decision self-test pin from 2 to 3; repository-only, no product or database change (2026-09-29).**`, and reaffirm `Next capability` as the Phase-8 Activation Closure;
     - regenerate `ai-map.json` LF with the canonical generator.

     Re-measure the manifest at Approve and at Complete, and stop if either exceeds 7000 characters. Relative to `66bf1b2`, stop if the manifest differs anywhere but the `Last Completed` line, or if `ai-map.json` differs anywhere but `generated_at` and `live_state.last_completed`.
   - Prove the range with `-Gate -BaseRef origin/main`, then publish the exact candidate carrying SPEC-240 Complete and this contract.
   - Require all four exact-SHA candidate workflows green, promote the same SHA to `main`, require main CI, run `-Certify` for `REMOTE_CERTIFY: READY`, and verify synchronized clean refs.

## Acceptance Criteria

- [ ] `scripts/test_cold_start_state_guard.ps1` differs from `66bf1b2` in exactly the two expectation sites, `2` → `3`, the count still an explicit hardcoded pin, with LF SHA-256 `14d3fcdc9019e6db3663316cef70764ac4614795bc64ef331f618e75b8bf8f9e`.
- [ ] All four CI guard self-test suites exit 0 from the repository root, the cold-start suite at 34 passed / 0 failed, and restoring `2` fails exactly its enumeration control.
- [ ] Repository consistency is CLEAN and reports 3 open ids, `git diff --check` passes, and canonical `-Finish` returns `LOCAL_CERTIFY: READY`.
- [ ] At completion the manifest's `Active Change Request` is None, `Last Completed` names SPEC-241, `Next capability` remains the Phase-8 Activation Closure, and the open owner decisions are exactly `MAIL-1`, `RET-1`, `PH8-10`. Every live database and repository figure is unchanged, and no other manifest line differs from `66bf1b2`.
- [ ] At completion `ai-map.json` agrees with the manifest by value. Relative to `66bf1b2` it differs only in `generated_at` and `live_state.last_completed`, and no other semantic field changed.
- [ ] No SPEC-240 file, no `supabase/**` path and no other script or workflow changed. There is no database write, and neither Primary nor Secondary was contacted.
- [ ] The exact candidate carrying SPEC-240 Complete and this contract is green in all four candidate workflows, is promoted as that SHA, and reaches `REMOTE_CERTIFY: READY`. The rejected `66bf1b2` is not promoted itself.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-29 — Owner approval (Human Gate 1)

The owner approved the exact Draft SHA `5a81bbde67de5fb2fbf435e78892934d0a1dd1b8` (CR SHA-256 `e102fc0863c49c43fb35c454e6ffc76a05a4eeb110ebb265ec92ce2a431f111f`) and its frozen four-path Write Scope. The corrective implementation is frozen: in `scripts/test_cold_start_state_guard.ps1`, exactly the two stale enumeration expectations change from `2` to `3`, giving LF SHA-256 `14d3fcdc9019e6db3663316cef70764ac4614795bc64ef331f618e75b8bf8f9e`. The count stays an explicit pin, and Check 25 and `check_repository_consistency.ps1` are not changed.

The approved lifecycle:
- **Approve / In Progress:** only the manifest's `Active Change Request` pointer changes, with `ai-map.json` regenerated canonically. `Last Completed` stays SPEC-240, `Next capability` stays the Phase-8 Activation Closure, the open decisions stay `MAIL-1`, `RET-1`, `PH8-10`, and every figure is unchanged. The manifest must stay within 7000 characters.
- **Complete:** clear the pointer, set `Last Completed` to SPEC-241 and reaffirm `Next capability`. Relative to `66bf1b2`, the manifest may differ only in `Last Completed`, and `ai-map.json` only in `generated_at` and `live_state.last_completed`.

After Complete, a new candidate carrying SPEC-240 Complete and SPEC-241 Complete is published. It needs all four workflows green before it is promoted, then main CI and `REMOTE_CERTIFY: READY`. No Human Gate 2 is needed, since there is no database write. Primary and Secondary are not contacted.

Revalidation before approval:
- HEAD was the Draft, a child of `6c8f43c`, which is a child of `66bf1b2`. The tree was clean, `orvion-preflight` was at `66bf1b2` and `main` at `6c48fbb`.
- The committed Draft hashes to the approved value.
- A read-only evaluation returned `APPROVAL_EVIDENCE: PASS` (profile REPOSITORY, one permanent-control path).
- Its probes returned INDETERMINATE with the Mutation Obligation removed, and FAIL on write closure with `ai-map.json` removed from Write Scope.

### 2026-09-29 — Execution started

The approved four-path contract entered In Progress at `5c1e55893357433713f840150e9578c7943e21fa`. Resume Step 1.

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

- **EARN IT.** A real CI failure on the published candidate, reproduced locally at the same SHA and traced to one stale pin.
- **WORTH IT.** Two characters in one file unblock the publication of a deployed, certified contract.
- **SIMPLIFY IT WITHOUT WEAKENING.** The pin stays explicit, and no guard, check, workflow or state changes.
- **Lesson carried forward.** The four guard self-test suites run only in CI. A contract that changes the manifest's open-decision enumeration, or another guard-pinned manifest fact, should run them at its Gate-1 prototype.
- **Deliberately not changed:**
  - SPEC-240, which stays Complete and untouched.
  - PH8-9, the n8n workflow and Slice 31.
  - The registered worktree `owt/p2`.
