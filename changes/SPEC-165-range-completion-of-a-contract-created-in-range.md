# Change Request — SPEC-165

## Status

[ ] Draft
[ ] Approved
[x] In Progress
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

Resume Step: DONE
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

- [x] A CI range carrying a contract's creation as `Approved`, its move to `In Progress` and its `Complete` transition is accepted and reports `MODE: VERIFY`.
- [x] A range whose single commit creates a contract already marked `Complete` is still rejected as `INVALID_COMPLETION_TRANSITION`.
- [x] A range whose commits take a newly created contract from `Draft` straight to `Complete` is still rejected.
- [x] `scripts/check_agent_continuity.ps1 -Gate -BaseRef 5e32ad66a810d07882f02b831fef9d1ce06ceb9d -HeadRef` the `SPEC-164` completion commit reports `MODE: VERIFY`, reproducing the exact range CI rejected.
- [x] `scripts/test_agent_continuity.ps1` reports 0 failed and retains every pre-existing assertion.
- [x] `pwsh -NoProfile -File scripts/check_repository_consistency.ps1` reports `REPOSITORY CONSISTENCY: CLEAN`.
- [x] No file outside this Change Request's Write Scope is created, modified or deleted, and `git diff --check` is clean.

## Execution Log

### 2026-09-12 — implementation agent

Outcome: Complete

Step results:
- Step 1: Applied — cases 111, 112 and 113 added. Against the unmodified control script the accepting case failed and both rejecting cases already held: 119 passed, 1 failed. That split is the evidence that matters, because it shows the removed guard was redundant rather than protective.
- Step 2: Applied — the `Read-GitFile $base $c[0]` base-existence test removed from `Resolve-Contract`, leaving `Status-Path` as the sole arbiter, with the reasoning recorded in place.
- Step 3: Applied — `CR_LIFECYCLE.md §8` now covers a contract created inside the range it completes in, as part of the paragraph that already owns "a CI range is a sequence of transitions, never one transition".
- Step 4: Already Applied — the manifest named this Change Request and `ai-map.json` was regenerated at approval.

Two fixture defects of my own, found and fixed before the implementation was trusted. The first three attempts retired the outgoing fixture contract INSIDE the range, which makes it an out-of-scope write against the new contract's Write Scope and would have rejected all three cases for an unrelated reason; the retirement now happens in a commit before the range begins. The second was a contaminated reproduction: running the repaired Gate against the real range from the working tree resolved the governing contract through the CURRENT manifest pointer, which by then named `SPEC-165`, so the range's files were judged against the wrong Write Scope. The faithful reproduction uses a clone checked out at the rejected SHA.

Evidence: the exact range CI rejected, `5e32ad6..3f5a1be`, run against a clone at that commit — the script as CI ran it reports `INVALID_COMPLETION_TRANSITION`, the repaired script reports `MODE: VERIFY / CR: SPEC-164 / STATUS: Complete`. `scripts/test_agent_continuity.ps1` 120 passed, 0 failed.

Also corrected here without a step of its own, because `Complete` rewrites the field wholesale as `CR_LIFECYCLE.md §9` requires: the manifest's `Last Completed` entry written at `SPEC-164` completion had `SPEC-163`'s description still attached to it, so it credited `SPEC-164` with work `SPEC-163` did. That is the changelog-chaining the manifest's own instruction forbids.

## Verification Notes

### 2026-09-12 — reviewing agent

Verdict: Confirmed Complete

Findings: every Acceptance Criterion was re-checked against the live repository. The decisive evidence is a differential, not a green: the same range, `5e32ad6..3f5a1be`, run against a clone checked out at that exact commit, is rejected as `INVALID_COMPLETION_TRANSITION` by the script as CI actually ran it and accepted as `MODE: VERIFY / CR: SPEC-164 / STATUS: Complete` by the repaired one. That is the production failure reproduced and closed, not a proxy for it.

The removed guard is proven redundant rather than merely absent. Cases 112 and 113 passed against the UNMODIFIED script and still pass after the removal: a single commit creating a contract already marked `Complete`, and a newly created contract taken from `Draft` straight to `Complete`, are both still rejected by name. Only the accepting case changed behaviour. A guard whose removal changes exactly one outcome, in the direction a legal history requires, was not carrying the protection it appeared to carry.

Worth recording why the `SPEC-164` suite missed this, since that suite was written to attack this exact area: every completion fixture in it reached `Complete` from a contract the sandbox baseline already held. The suite tested the transition thoroughly and never tested the contract's age, so the defect sat in a dimension none of the 117 assertions varied. CI found it because CI is the only place a contract is routinely born and completed inside one range.

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

Found by CI, not by the suite that was supposed to attack this exact area. Worth recording why: every `SPEC-164` completion fixture reached `Complete` from a contract that already existed in the sandbox baseline, so no case ever modelled a contract born inside the range it dies in. The suite tested the transition and never the contract's age. Case 111 closes that.
