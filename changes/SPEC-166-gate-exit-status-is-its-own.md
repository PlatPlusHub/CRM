# Change Request — SPEC-166

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make `scripts/check_agent_continuity.ps1` state its own success exit status instead of inheriting whatever a preceding native command left in `$LASTEXITCODE`, and measure the range Gate the way CI actually invokes it so the suite can observe that status at all.

## Business Reason

`Read-GitFile` runs `git show` and treats failure as "absent", which is correct and deliberate — but it leaves `$LASTEXITCODE` at 128, and the Gate's range path then ends on cmdlets, so nothing resets it. GitHub's `pwsh` shell appends `exit $LASTEXITCODE` to every step, so the Gate printed `ORVION: READY`, `MODE: VERIFY` and `BLOCKER: none` and the step still failed with no error to read. It happens exactly when the governing Change Request does not exist at the range base — which is the FIRST push of every new Change Request, so this is not a rare corner. The suite could not see it because its range harness invokes `pwsh -File`, which discards `$LASTEXITCODE` when a script falls off its end. A guard whose success is reported by accident is not reporting success.

## Risks

Very low. Stating `exit 0` at the end of a path that has already printed a successful report cannot mask a failure: every failure route throws and is caught, and the catch block still exits 1. The measurable risk is the opposite one, already realised in production — a green run reported as red, which teaches an agent that a failing required workflow is normal.

## Supersedes / Depends On

None

## Write Scope

- `changes/SPEC-166-gate-exit-status-is-its-own.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-164-agent-control-evidence-lifecycle-closure.md`
- `changes/SPEC-165-range-completion-of-a-contract-created-in-range.md`
- `.github/workflows/agent-control.yml`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `changes/TEMPLATE.md`
- `scripts/check_repository_consistency.ps1`
- `supabase/migrations`

## Required Reading

- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `.github/workflows/agent-control.yml`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

None

## Implementation Steps

1. Check whether `RunRange` in `scripts/test_agent_continuity.ps1` invokes the control script with `-Command`. If it does not, change that helper to invoke exactly as `.github/workflows/agent-control.yml` does — dot-sourced under `pwsh -Command`, with GitHub's `exit $LASTEXITCODE` appendix — so every range assertion observes the exit status CI will observe, and record beside it that the local `Run` helper deliberately keeps `pwsh -File` because that is how the pre-commit hook invokes it.
2. Check for `Assert '114` in `scripts/test_agent_continuity.ps1`. If absent, add the mutation: a range whose governing Change Request does not exist at the range base, and whose report is otherwise a clean success, must exit 0. Run the suite and record that it fails against the unmodified control script.
3. Check for an `exit 0` at the end of the main `try` block in `scripts/check_agent_continuity.ps1`. If absent, add one so a successful Gate, Boot or Finish states its own status rather than inheriting the last native command's, and record beside it that `Read-GitFile` leaves 128 behind by design.
4. Check that `_ORVION_CANONICAL/manifest.md` names `changes/SPEC-166-gate-exit-status-is-its-own.md` as the Active Change Request. If it does not, set it, and regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [x] `RunRange` invokes the control script the way `.github/workflows/agent-control.yml` invokes it, including the `exit $LASTEXITCODE` appendix GitHub appends.
- [x] A range whose governing Change Request is absent at the range base, and which reports a clean success, exits 0.
- [x] Every range assertion that previously expected a non-zero exit still observes one, so the harness change strengthened the measurement rather than relaxing it.
- [x] `scripts/check_agent_continuity.ps1` ends its successful path with an explicit exit status.
- [x] Replaying the exact range that failed in production — base `3f5a1be3f4c218059f81f9584cb17802b8a7cf46`, head `8102cdd390057638e24ea61730fb1eece46951c5` — under GitHub's invocation form exits 0 with the repaired script and 128 with the script as it stands.
- [x] `scripts/test_agent_continuity.ps1` reports 0 failed and retains every pre-existing assertion.
- [x] `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` reports `REPOSITORY CONSISTENCY: CLEAN`.
- [x] No file outside this Change Request's Write Scope is created, modified or deleted, and `git diff --check` is clean.

## Execution Log

### 2026-09-12 — implementation agent

Outcome: Complete

Step results:
- Step 1: Applied — `RunRange` now dot-sources the control script under `pwsh -Command` with GitHub's `exit $LASTEXITCODE` appendix, matching `.github/workflows/agent-control.yml`. The local `Run` helper deliberately keeps `pwsh -File`, because that is how `.githooks/pre-commit` invokes it; each harness mirrors its real caller.
- Step 2: Applied — case 114 added. The harness change alone exposed the defect in TWO places against the unmodified control script: 119 passed, 2 failed, the second being case 111, which had been passing only because `pwsh -File` discarded the exit status. That is the measurement gap made visible.
- Step 3: Applied — an explicit `exit 0` ends the main `try` block, with the reason recorded beside it.
- Step 4: Already Applied — the manifest named this Change Request and `ai-map.json` was regenerated at approval.

Evidence: the exact range that failed in production, base `3f5a1be`, head `8102cdd`, replayed against a clone at that commit under GitHub's invocation form — 128 with the script as it stood, 0 with the repaired script. `scripts/test_agent_continuity.ps1` 121 passed, 0 failed.

## Verification Notes

### 2026-09-12 — reviewing agent

Verdict: Confirmed Complete

Findings: every Acceptance Criterion was re-checked against the live repository, and the decisive evidence is again a differential on the real failure rather than a green suite. The exact range CI rejected — base `3f5a1be`, head `8102cdd`, replayed against a clone checked out at that commit under GitHub's own invocation form — exits 128 with the script as it stood and 0 with the repaired script, while both print the same successful report. That is the production symptom reproduced and closed.

The harness change is what makes this assertable at all, and it strengthened the measurement rather than relaxing it. Applying it alone, before any production fix, turned 121 passing assertions into 119 passing and 2 failing: case 114, written for this defect, and case 111, which had been reporting success only because `pwsh -File` discards a script's trailing `$LASTEXITCODE`. Every range case that expects a non-zero exit still observes one, because those paths exit explicitly through the catch block. Case 114 asserts the report alongside the code, so a guard that exited 0 while reporting a failure would fail it too.

Worth recording plainly: the previous two Change Requests added twenty-six assertions to this exact area and none of them could see this, because the harness invoked the Gate differently from the thing that judges it. The defect was not in the Gate's logic but in an output the suite never read. `MEAS-1` in a new place — a test harness must invoke what it guards the way the real caller does.

Recommendation to human: Set Status to Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

The measurement lesson is the durable part, and it is the `MEAS-1` class in a new place: the suite was not wrong about the Gate's behaviour, it was blind to one of the Gate's outputs. `pwsh -File` discards a script's trailing `$LASTEXITCODE`; `pwsh -Command` with GitHub's appendix propagates it. The harness therefore could not observe the exit status that CI treats as the whole verdict, and 120 green assertions said nothing about it. A test harness must invoke the thing it guards the way the real caller invokes it — the local `Run` helper keeps `pwsh -File` for exactly that reason, because the pre-commit hook uses `-File`.
