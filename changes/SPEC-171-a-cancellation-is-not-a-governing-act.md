# Change Request — SPEC-171

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Resolve a range that closes one contract and cancels another to the completed contract, instead of
rejecting it as ambiguous.

## Business Reason

`SPEC-170` admitted `Cancelled` as a terminal governing status so that cancellation could be
committed at all. It did not ask what happens when a range contains BOTH a cancelled and a completed
contract — which is exactly the shape `SPEC-170` itself produced, because cancelling `SPEC-169`
required carrying that cancellation inside `SPEC-170`'s Write Scope.

The result reached `main` and failed there. Reproduced against the exact pushed range:

```text
pwsh scripts/check_agent_continuity.ps1 -Gate -BaseRef d0bba10 -HeadRef cde4f06
ORVION: BLOCKED
CODE: AMBIGUOUS_GOVERNING_CR
```

`Resolve-Contract` now collects every terminal contract and rejects more than one. That rule is right
for two contracts that both claim to have done the work, and wrong here. A cancelled contract never
held write authority for anything in the range: `SPEC-169` was abandoned, and every file the range
touched was authorised by `SPEC-170`'s Write Scope, including `SPEC-169`'s own file. A cancellation
carried inside another contract's scope is a written artefact, not a governing act.

This also demonstrates the defect class the Simple Acceptance programme exists to remove. The bad
revision reached `main` and CI reported it afterwards; an admission boundary would have refused it
before `main` moved.

## Risks

Low. The change narrows when `AMBIGUOUS_GOVERNING_CR` is raised; it never widens who may write.
Write Scope is still taken from the governing contract alone, so a cancelled contract confers no
authority on anything — which is the property that makes preferring the completed contract safe
rather than merely convenient.

The realistic failure is the preference swallowing genuine ambiguity. Two contracts that both reach
`Complete` remain ambiguous, and so do two that both reach `Cancelled`; only the mixed case resolves.
Both rejecting directions are asserted alongside the accepting one.

A correction to `SPEC-170`'s own test is required: assertion 129 asserted that one `Complete` plus one
`Cancelled` is ambiguous. That expectation was wrong — it forbids a history the repository has
already legitimately produced — and it is corrected rather than worked around.

## Supersedes / Depends On

Corrects `changes/SPEC-170-cancellation-is-executable.md`, which is `Complete` and terminal and is
therefore not modified. Depends on it for `$script:TerminalStatuses`.

## Write Scope

- `changes/SPEC-171-a-cancellation-is-not-a-governing-act.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-170-cancellation-is-executable.md`
- `changes/SPEC-169-agent-control-skips-the-preflight-ref.md`
- `changes/SPEC-168-shadow-acceptance-workflow.md`
- `changes/SPEC-167-range-integrity-over-committed-intermediate-states.md`
- `changes/TEMPLATE.md`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `GOVERNANCE.md`
- `scripts/check_repository_consistency.ps1`
- `supabase/migrations`

## Required Reading

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

1. Check for `Assert '131` in `scripts/test_agent_continuity.ps1`. If absent, add an adversarial
   group and run it against the unmodified control script, recording in the Execution Log which cases
   already hold and which fail. Assert that: a range containing one `Complete` contract and one
   `Cancelled` contract is ACCEPTED and resolves to the `Complete` one; a range containing two
   `Complete` contracts is still REJECTED as `AMBIGUOUS_GOVERNING_CR`; and a range containing two
   `Cancelled` contracts is REJECTED as `AMBIGUOUS_GOVERNING_CR`.
2. Check for `$done` in `scripts/check_agent_continuity.ps1`. If absent, change `Resolve-Contract` so
   that when more than one terminal contract is present it resolves to the single `Complete` one, and
   raises `AMBIGUOUS_GOVERNING_CR` when the number of `Complete` contracts is not exactly one. Write
   Scope continues to come from the resolved governing contract only, so this introduces no new write
   authority and no new error code.
3. Check whether assertion `129` in `scripts/test_agent_continuity.ps1` still asserts
   `AMBIGUOUS_GOVERNING_CR` for a diff containing one `Complete` and one `Cancelled` contract. If it
   does, correct that assertion to the behaviour proven in Step 1, keeping a two-`Complete` case as
   the genuine ambiguity guard.
4. Check that `_ORVION_CANONICAL/manifest.md` names
   `changes/SPEC-171-a-cancellation-is-not-a-governing-act.md` as the Active Change Request. If it
   does not, set it, and regenerate `ai-map.json` with
   `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [ ] `scripts/test_agent_continuity.ps1` contains an adversarial group covering all three cases named
      in Step 1, and the whole suite passes.
- [ ] A range containing one `Complete` and one `Cancelled` contract resolves to the `Complete` one.
- [ ] A range containing two `Complete` contracts is still rejected as `AMBIGUOUS_GOVERNING_CR`.
- [ ] A range containing two `Cancelled` contracts is rejected as `AMBIGUOUS_GOVERNING_CR`.
- [ ] `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate -BaseRef d0bba10 -HeadRef cde4f06`
      no longer reports `AMBIGUOUS_GOVERNING_CR`.
- [ ] `Resolve-Contract` raises no error code that did not already exist before this Change Request.
- [ ] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while it
      is in progress, and `ai-map.json` is regenerated from the current tree.

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

**`main` is red while this contract is open, and that is left visible.** Commit `cde4f06` carries a
failing `Agent Control` run. It is not rewritten, amended or force-pushed. The next push's CI range
begins at `cde4f06`, so it contains only this contract's commits and one terminal contract, which is
why completing this work returns `main` to green without touching history.

**Why assertion 129 was wrong.** It was written in the same change that created the defect, and it
encoded the same unexamined assumption: that two terminal contracts are always ambiguous. The test
agreed with the code because both came from one conclusion, which is precisely how a green suite can
certify a broken rule. Correcting the assertion is the repair, not an accommodation — a real,
already-committed history is the counterexample.

**Deliberately still out of scope.** The two proven Phase C blockers — the acceptance cleanup path
acquiring an unpinned Supabase CLI, and `orvion-acceptance` carrying no guard-calibration evidence —
are untouched here and remain the next corrective unit. Phase C stays forbidden.
