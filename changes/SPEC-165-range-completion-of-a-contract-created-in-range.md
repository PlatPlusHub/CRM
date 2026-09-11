# Change Request — SPEC-165

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Accept a `Complete` transition in a CI range when the governing Change Request was also created inside that same range, judging the transition by the Status path actually committed rather than by whether the contract existed at the range base.

## Business Reason

The `SPEC-164` push carried the whole lifecycle — create, `Approve`, implement, `Review`, `Complete` — in one range, which is the ordinary shape of a small bounded Change Request. CI rejected it as `INVALID_COMPLETION_TRANSITION` and left `main` red, even though the committed path was `Approved -> In Progress -> Complete`, every step legal and every commit already gated locally. The rejection came from a guard that required the contract to exist at the range base, which is true only for work that spans more than one push. This is the same class of defect `SPEC-162` repaired one layer up: a legal history refused because the check looked at the range's endpoints instead of the transitions that actually occurred.

## Risks

Low. The base-existence test is redundant, not protective: the completion path is already judged by `Status-Path`, which walks the Status recorded at each commit that touched the contract and requires the state immediately before `Complete` to be `In Progress`. A single commit creating a contract directly as `Complete` yields a one-element path and is still rejected; a two-commit `Draft -> Complete` yields `Draft` immediately before `Complete` and is still rejected. The risk of NOT fixing it is larger and concrete: every small Change Request completed in one push fails CI, which trains an agent to treat a red required workflow as normal.

## Supersedes / Depends On

None

## Write Scope

- `changes/SPEC-165-range-completion-of-a-contract-created-in-range.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-164-agent-control-evidence-lifecycle-closure.md`
- `.github/workflows/agent-control.yml`
- `AGENTS.md`
- `ENGINEERING_METHOD.md`
- `changes/TEMPLATE.md`
- `scripts/check_repository_consistency.ps1`
- `supabase/migrations`
- `GOVERNANCE.md`

## Required Reading

- `CR_LIFECYCLE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

None

## Implementation Steps

1. Check for `Assert '111` in `scripts/test_agent_continuity.ps1`. If absent, add the mutation group: a range in which a Change Request is created as `Approved`, moved to `In Progress` and then to `Complete` must be ACCEPTED even though it did not exist at the range base; a range whose single commit creates a contract directly as `Complete` must still be REJECTED as `INVALID_COMPLETION_TRANSITION`; and a range whose commits create a contract as `Draft` and then flip it straight to `Complete` must still be REJECTED. Run the suite and record that the accepting case fails against the unmodified control script while both rejecting cases already hold.
2. Check for `Read-GitFile $base $c[0]` in `scripts/check_agent_continuity.ps1`. If present, remove that base-existence test from `Resolve-Contract`, leaving the `Status-Path` judgement as the sole arbiter of whether `Complete` was reached legally, and record in a comment why the removed test was redundant rather than protective.
3. Check for `created inside that same range` in `CR_LIFECYCLE.md`. If absent, extend the §8 paragraph that already records "a CI range is a sequence of transitions, never one transition" so it also covers a contract created inside the range it completes in.
4. Check that `_ORVION_CANONICAL/manifest.md` names `changes/SPEC-165-range-completion-of-a-contract-created-in-range.md` as the Active Change Request. If it does not, set it, and regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [ ] A CI range carrying a contract's creation as `Approved`, its move to `In Progress` and its `Complete` transition is accepted and reports `MODE: VERIFY`.
- [ ] A range whose single commit creates a contract already marked `Complete` is still rejected as `INVALID_COMPLETION_TRANSITION`.
- [ ] A range whose commits take a newly created contract from `Draft` straight to `Complete` is still rejected.
- [ ] `scripts/check_agent_continuity.ps1 -Gate -BaseRef 5e32ad66a810d07882f02b831fef9d1ce06ceb9d -HeadRef` the `SPEC-164` completion commit reports `MODE: VERIFY`, reproducing the exact range CI rejected.
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

Found by CI, not by the suite that was supposed to attack this exact area. Worth recording why: every `SPEC-164` completion fixture reached `Complete` from a contract that already existed in the sandbox baseline, so no case ever modelled a contract born inside the range it dies in. The suite tested the transition and never the contract's age. Case 111 closes that.
