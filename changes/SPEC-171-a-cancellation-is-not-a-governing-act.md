# Change Request — SPEC-171

## Status

[ ] Draft
[ ] Approved
[x] In Progress
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

Resume Step: DONE
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

- [x] `scripts/test_agent_continuity.ps1` contains an adversarial group covering all three cases named
      in Step 1, and the whole suite passes.
- [x] A range containing one `Complete` and one `Cancelled` contract resolves to the `Complete` one.
- [x] A range containing two `Complete` contracts is still rejected as `AMBIGUOUS_GOVERNING_CR`.
- [x] A range containing two `Cancelled` contracts is rejected as `AMBIGUOUS_GOVERNING_CR`.
- [x] `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Gate -BaseRef d0bba10 -HeadRef cde4f06`
      no longer reports `AMBIGUOUS_GOVERNING_CR`.
- [x] `Resolve-Contract` raises no error code that did not already exist before this Change Request.
- [x] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while it
      is in progress, and `ai-map.json` is regenerated from the current tree.

## Execution Log
### 2026-09-12 — Claude Opus 5 (agent execution run)

Outcome: Complete

Step results:
- Step 1: Applied — assertions 131 and 132 added; 129 rewritten (see Step 3).
- Step 2: Applied — `Resolve-Contract` resolves to the single `Complete` contract when more than one
  terminal contract is present, and raises the existing `AMBIGUOUS_GOVERNING_CR` otherwise.
- Step 3: Applied — assertion 129 corrected from asserting ambiguity to asserting that the `Complete`
  contract governs, with the two-`Complete` case retained as assertion 131.
- Step 4: Applied — manifest pointer set; `ai-map.json` regenerated.

Suite: 140 passed / 0 failed.

MUTATION ANALYSIS. The repair had to prove the RULE, not the `SPEC-169`/`SPEC-170` example, so each
assertion was checked against a distinct mutant of the implementation:

| Mutant of `Resolve-Contract` | Killed by |
| --- | --- |
| preference removed entirely (`$c.Count-gt1` always throws) | 129 — the accepting case fails |
| resolve to `$c[0]` unconditionally | 131 and 132 — both wrongly accept |
| prefer `Cancelled` instead of `Complete` | 129 — the `CR: SPEC-900` identity check fails |
| apply the losing contract's Write Scope | 133 — `secret.txt` is admitted |

Assertion 129 alone survives three of those four mutants, which is the same weakness that produced
this defect: 129 originally agreed with the code because both came from one unexamined conclusion.

Assertion 133 is an addition beyond the three cases Step 1 names, recorded here rather than folded
in silently. It stays inside this contract under `CR_LIFECYCLE.md` §11 — inside the declared Write
Scope, inside the stated objective, reusing existing mechanisms, requiring no new judgment — and it
is the only assertion that proves the load-bearing safety property: preferring `Complete` is safe
ONLY because Write Scope still comes from the resolved contract alone.

Engineering Observations:

1. **Two `Complete` contracts in one range stay rejected, and that is correct rather than a gap.**
   The Gate resolves exactly one governing contract and checks every record against its Write Scope,
   and `Validate-CommittedRange` uses one frozen baseline. A range carrying two completed authorities
   cannot be checked correctly by that design, so failing closed is right; the legitimate sequential
   case is two pushes and two ranges. The cancelled case differs in kind — an abandoned contract
   authorised nothing, so only one authority is ever present.
2. **A local range reproduction is contaminated by the working tree.** `Resolve-Contract` reads
   `$m.Active` from the working-tree manifest even in range mode, so
   `-Gate -BaseRef <base> -HeadRef <head>` answers with the CURRENT pointer rather than the pointer at
   `<head>`. The first attempt at Acceptance Criterion 5 therefore reported
   `OUT_OF_SCOPE_WRITE` purely because this tree names `SPEC-171` active while `cde4f06` names none.
   It never affects CI, which checks out the pushed SHA, and the correct reproduction is a detached
   worktree at the target SHA — which is how that criterion was finally proven. EARN IT does not
   justify changing a core resolution path mid-correction for a diagnostic-ergonomics gain, so this
   is recorded and deferred.
3. **Three fixture failures in this correction shared one cause.** `FROZEN_AUTHORITY_MUTATED:Write
   Scope` fired on 129, and the same latent fault existed in 131, 132 and 133: the governing contract
   was given its final Write Scope only on the tip commit while the range base still held the default.
   Frozen authority is compared against the base, so a range fixture that sets scope only at the tip
   is self-invalidating. The Gate was correct every time; the fixtures were not.

Commits: recorded by the Complete commit that carries this entry.

## Verification Notes

### 2026-09-12 — Claude Opus 5 (review)

Verdict: Confirmed Complete

Findings: re-checked against the live tree and against the exact failing range, not against the
Execution Log.

- Acceptance Criterion 5 was proven the only way it can honestly be proven: a detached worktree at
  `cde4f06` with the repaired script, run as `-Gate -Root <worktree> -BaseRef d0bba10 -HeadRef
  cde4f06`. That is the state CI sees. Result: `ORVION: READY`, `MODE: VERIFY`, `CR: SPEC-170`,
  exit 0. The earlier in-tree attempt reporting `OUT_OF_SCOPE_WRITE` was the working-tree
  contamination recorded as Observation 2, not a failure of the repair.
- `Resolve-Contract` raises only `NO_GOVERNING_CR`, `AMBIGUOUS_GOVERNING_CR` and
  `INVALID_COMPLETION_TRANSITION`; all three pre-existed. No new vocabulary.
- Write Scope is still read from the resolved contract alone. Assertion 133 proves this is not merely
  true but enforced: a cancelled contract naming `secret.txt` does not authorise writing it while the
  governing completed contract does not name it.
- Both rejecting directions survive: two `Complete` contracts (131) and two `Cancelled` contracts
  (132) remain `AMBIGUOUS_GOVERNING_CR`. The preference narrows the rejection without removing it.
- Suite: 140 passed, 0 failed.

The correction to assertion 129 is a test-expectation repair, not an accommodation. The counterexample
is a real committed history — `d0bba10..cde4f06` — that the original expectation forbids.

Recommendation to human: Set Status to Complete

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
