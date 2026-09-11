# Change Request — SPEC-166

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
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

Resume Step: 1
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

- [ ] `RunRange` invokes the control script the way `.github/workflows/agent-control.yml` invokes it, including the `exit $LASTEXITCODE` appendix GitHub appends.
- [ ] A range whose governing Change Request is absent at the range base, and which reports a clean success, exits 0.
- [ ] Every range assertion that previously expected a non-zero exit still observes one, so the harness change strengthened the measurement rather than relaxing it.
- [ ] `scripts/check_agent_continuity.ps1` ends its successful path with an explicit exit status.
- [ ] Replaying the exact range that failed in production — base `3f5a1be3f4c218059f81f9584cb17802b8a7cf46`, head `8102cdd390057638e24ea61730fb1eece46951c5` — under GitHub's invocation form exits 0 with the repaired script and 128 with the script as it stands.
- [ ] `scripts/test_agent_continuity.ps1` reports 0 failed and retains every pre-existing assertion.
- [ ] `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` reports `REPOSITORY CONSISTENCY: CLEAN`.
- [ ] No file outside this Change Request's Write Scope is created, modified or deleted, and `git diff --check` is clean.

## Execution Log

[Appended by the executing agent after each run against this Change Request, before
IMPLEMENT is considered complete, per synchronization as defined in `CR_LIFECYCLE.md` §8
— this file is always implicitly in scope for this section.
Append-only — never edit or delete a prior entry, including a Blocked or Failed one.]

## Verification Notes

[Appended by the reviewing agent after independently re-checking the Execution Log
against the live repository state. Append-only — never edit or delete a prior entry.]

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as
      Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's
      Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

The measurement lesson is the durable part, and it is the `MEAS-1` class in a new place: the suite was not wrong about the Gate's behaviour, it was blind to one of the Gate's outputs. `pwsh -File` discards a script's trailing `$LASTEXITCODE`; `pwsh -Command` with GitHub's appendix propagates it. The harness therefore could not observe the exit status that CI treats as the whole verdict, and 120 green assertions said nothing about it. A test harness must invoke the thing it guards the way the real caller invokes it — the local `Run` helper keeps `pwsh -File` for exactly that reason, because the pre-commit hook uses `-File`.
