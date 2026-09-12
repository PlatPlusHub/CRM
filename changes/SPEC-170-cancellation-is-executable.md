# Change Request — SPEC-170

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make the `Cancelled` terminal state executable by the control plane, and cancel `SPEC-169` with it.

## Business Reason

`CR_LIFECYCLE.md` §4 lists `Draft -> Cancelled`, `Approved -> Cancelled` and `In Progress -> Cancelled`
as legal transitions, and `$script:LegalTransitions` agrees. The Gate cannot commit any of them.

Reproduced against `SPEC-169` on 2026-09-12. Cancelling requires clearing the manifest pointer,
because a manifest naming a `Cancelled` contract is rejected as `MANIFEST_CR_CONTRADICTION`. With the
pointer cleared and the Status `Cancelled`, `Resolve-Contract` finds no governing Change Request —
it accepts only `Complete` as a terminal governing status — so control falls to the PLAN arm, which
rejects every record that is not a `Draft` Change Request file. A cancellation necessarily writes
`_ORVION_CANONICAL/manifest.md` and `ai-map.json`. Observed exactly:

```text
CODE: NO_GOVERNING_CR
SUBJECT: _ORVION_CANONICAL/manifest.md,ai-map.json,changes/SPEC-169-agent-control-skips-the-preflight-ref.md
```

The trap closes on every side: while the contract stays `Approved` no other Change Request may be
approved either, because an unpointed executable contract is `ORPHANED_APPROVED_CR`. A repository
holding a Change Request that was approved on a false premise therefore has no legal way forward.

That is the defect worth repairing, and the reason is not convenience. A weaker agent meeting this
deadlock sees exactly two escapes — `--no-verify` or rewriting history — and `AGENTS.md` §1 forbids
both. A control plane that can only be obeyed by breaking it teaches the wrong lesson.

## Risks

Low and narrowly scoped. The change widens which terminal status may govern a run; it does not widen
what any status is allowed to do. `Complete` keeps its strictly stronger rule — the committed path
must place `In Progress` immediately before it — and `Cancelled` is judged by the same
`$script:LegalTransitions` matrix every other transition already uses, so `Complete -> Cancelled`
stays rejected.

The realistic failure is over-acceptance: letting a contract reach `Cancelled` from a state the matrix
forbids, or letting `Complete` inherit the looser rule. The adversarial group asserts both directions
and the completion regression explicitly.

`Validate-CompletionPrerequisites` is invoked only on a transition to `Complete`, so a cancelled
contract is not asked for ticked Acceptance Criteria it was abandoned before satisfying.

## Supersedes / Depends On

Cancels `changes/SPEC-169-agent-control-skips-the-preflight-ref.md`, whose load-bearing premise was
refuted by live evidence. Depends on `changes/SPEC-167-range-integrity-over-committed-intermediate-states.md`
for the per-commit range semantics that judge a non-governing contract's transitions.

## Write Scope

- `changes/SPEC-170-cancellation-is-executable.md`
- `changes/SPEC-169-agent-control-skips-the-preflight-ref.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `changes/SPEC-167-range-integrity-over-committed-intermediate-states.md`
- `changes/SPEC-168-shadow-acceptance-workflow.md`
- `changes/TEMPLATE.md`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `GOVERNANCE.md`
- `ENGINEERING_METHOD.md`
- `scripts/check_repository_consistency.ps1`
- `supabase/migrations`

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

1. Check for `Assert '126` in `scripts/test_agent_continuity.ps1`. If absent, add an adversarial
   group for cancellation and run it against the unmodified control script, recording in the
   Execution Log which cases already hold and which fail. Assert that: an `Approved` contract moved
   to `Cancelled` with the manifest pointer cleared is ACCEPTED locally; the same shape is ACCEPTED
   as a committed range; a contract moved from `Complete` to `Cancelled` is REJECTED; a diff in which
   two contracts reach a terminal status is REJECTED as `AMBIGUOUS_GOVERNING_CR`; and, as the
   completion regression, a range whose committed path reaches `Complete` without `In Progress`
   immediately before it is still REJECTED as `INVALID_COMPLETION_TRANSITION`.
2. Check for `TerminalStatuses` in `scripts/check_agent_continuity.ps1`. If absent, change
   `Resolve-Contract` so a changed contract whose Status is `Complete` OR `Cancelled` may be the
   governing contract. Judge the committed path against the contract's own final Status rather than a
   hardcoded `Complete`: keep the existing stricter rule for `Complete` — the path must place
   `In Progress` immediately before it, raising `INVALID_COMPLETION_TRANSITION` — and validate a
   `Cancelled` path with the existing `Validate-StatusPath`, introducing no new error code.
3. Check whether `changes/SPEC-169-agent-control-skips-the-preflight-ref.md` has Status `Cancelled`.
   If it does not, set its Status from `Approved` to `Cancelled`, changing nothing else in that file —
   its frozen authority, Execution Log and Verification Notes are historical evidence of an EARN-IT
   conclusion that was made and then corrected, and are not rewritten.
4. Check that `_ORVION_CANONICAL/manifest.md` names `changes/SPEC-170-cancellation-is-executable.md`
   as the Active Change Request. If it does not, set it, and regenerate `ai-map.json` with
   `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [x] `scripts/test_agent_continuity.ps1` contains an adversarial group covering all five cases named
      in Step 1, and the whole suite passes.
- [x] `Resolve-Contract` admits a contract whose Status is `Cancelled` as the governing contract.
- [x] A local Gate run over an `Approved -> Cancelled` transition with the manifest pointer cleared
      succeeds instead of reporting `NO_GOVERNING_CR`.
- [x] A `Complete -> Cancelled` transition is rejected.
- [x] A range reaching `Complete` without `In Progress` immediately before it is still rejected as
      `INVALID_COMPLETION_TRANSITION`.
- [x] `Resolve-Contract` raises no error code that did not already exist before this Change Request.
- [x] `changes/SPEC-169-agent-control-skips-the-preflight-ref.md` has Status `Cancelled`, and its
      Objective, Business Reason, Write Scope, Implementation Steps and Execution Log are byte-identical
      to their state before this Change Request.
- [x] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while it
      is in progress, and `ai-map.json` is regenerated from the current tree.

## Execution Log
### 2026-09-12 — Claude Opus 5 (agent execution run)

Outcome: Complete

Step results:
- Step 1: Applied — adversarial group added as assertions 126–130.
- Step 2: Applied — `$script:TerminalStatuses` added beside `$script:LegalTransitions`;
  `Resolve-Contract` admits either terminal status and judges the committed path against the
  contract's own final Status.
- Step 3: Applied — `SPEC-169` Status `Approved -> Cancelled`, nothing else in that file touched.
- Step 4: Applied — manifest pointer set to this contract; `ai-map.json` regenerated.

PRECHECK, against the unmodified control script:

| Assertion | Before | After |
| --- | --- | --- |
| 126 local `Approved -> Cancelled`, pointer cleared | FAIL `NO_GOVERNING_CR` | ACCEPTED |
| 127 same shape as a committed range | FAIL `NO_GOVERNING_CR` | ACCEPTED |
| 128 `Complete -> Cancelled` rejected | already held | still rejected |
| 129 one `Complete` + one `Cancelled` is ambiguous | FAIL (only `Complete` was collected) | `AMBIGUOUS_GOVERNING_CR` |
| 130 `Complete` still needs `In Progress` before it | already held | still rejected |

Suite: 134 passed / 3 failed before the repair, 137 passed / 0 failed after.

Engineering Observations:

1. **The runtime-mode switch needed a `Cancelled` arm, which Step 2 does not name.** Admitting
   `Cancelled` into `Resolve-Contract` alone resolved the contract and then fell to the `default`
   arm, reporting `RUNTIME_BLOCKED` — the refusal would have moved rather than been removed. The
   repair stays inside this contract under `CR_LIFECYCLE.md` §11: it is inside the declared Write
   Scope, squarely inside the stated Objective ("executable by the control plane"), reuses the
   existing `Complete` arm's shape, and required no new judgment. Recorded rather than silently
   folded into the step.
2. **Closure still requires the contract to declare `_ORVION_CANONICAL/manifest.md` in its own Write
   Scope, and this contract does not remove that.** Assertions 126 and 127 first failed with
   `OUT_OF_SCOPE_WRITE:_ORVION_CANONICAL/manifest.md` because the fixture contract's scope was
   `allowed.txt`. The implementation was right and the fixtures were wrong; they now declare the
   manifest exactly as the pre-existing completion fixtures do. Making the manifest implicitly
   writable at closure was considered and rejected — the manifest carries Current Phase, Live state
   and far more than the pointer, so an implicit permission would hand every contract silent write
   access to all of it. A contract that omits the manifest from its Write Scope therefore still
   cannot close itself, by either route. `SPEC-169` declared it, which is why its cancellation
   succeeded.
3. **A Draft cannot be authored while another contract is `Approved`.** Creating
   `changes/SPEC-170-*.md` while `SPEC-169` held the pointer was itself
   `OUT_OF_SCOPE_WRITE:changes/SPEC-170-cancellation-is-executable.md`, because the stuck contract
   was the governing one and its Write Scope did not name the new file. This contract was therefore
   born `Approved` in the same commit that cancelled `SPEC-169` — a shape assertion 114 already
   pins as legal. Step 2 removes the need for any future cancellation to be carried this way.

Commits: recorded by the Complete commit that carries this entry.

## Verification Notes

### 2026-09-12 — Claude Opus 5 (review)

Verdict: Confirmed Complete

Findings: re-checked against the live tree and the Git baseline, not against the Execution Log.

- `$script:TerminalStatuses` is defined once at `scripts/check_agent_continuity.ps1:53` and consumed
  at exactly two sites: `Resolve-Contract` (`:563`) and the runtime-mode switch (`:1050`). One
  definition, no second list to drift.
- The no-new-error-code criterion was verified mechanically rather than by inspection. Every `throw`
  inside `Resolve-Contract` was extracted — `NO_GOVERNING_CR`, `AMBIGUOUS_GOVERNING_CR`,
  `INVALID_COMPLETION_TRANSITION` — and each was counted in
  `git show ff7b9a5:scripts/check_agent_continuity.ps1`. All three pre-existed.
- `changes/SPEC-169-agent-control-skips-the-preflight-ref.md` diffed against `2e978a5` yields exactly
  four changed lines, all of them the Status checkboxes. Its Objective, Business Reason — including
  the refuted "permanently red" claim — Write Scope, Implementation Steps and evidence sections are
  byte-identical. The incorrect conclusion is preserved, as required.
- Both directions are covered. 126 and 127 prove cancellation is now accepted; 128 proves a closed
  contract still cannot be cancelled; 129 proves admitting a second terminal status did not create a
  second way to be ambiguous; 130 proves `Complete` did not inherit the looser rule. 126, 127 and 129
  each failed before the repair, so none of them is vacuous.
- Suite: 137 passed, 0 failed.

Two limitations are recorded in the Execution Log rather than repaired here: closure still requires a
contract to declare the manifest in its own Write Scope, and a Draft still cannot be authored while
another contract is `Approved`. Neither is widened by this change and neither blocks Phase C.

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

**Why `SPEC-169`'s cancellation rides inside this contract's Write Scope.** The cancellation is a
human-authorized act (owner command, 2026-09-12) but it is not self-executing: a standalone
cancellation is precisely the deadlock described above. Naming `SPEC-169`'s file in this contract's
Write Scope means the act happens under an approved authority that the Gate can resolve, which is the
ordinary mechanism rather than an exception to it. Step 2 then removes the need for any future
cancellation to be carried this way.

**What is deliberately NOT done.** `SPEC-169`'s text is not corrected. Its Business Reason still
claims Agent Control is permanently red on preflight, which live evidence refuted
(`success @ d0bba10`, `failure @ e99324e` only, the one-time all-zero `github.event.before` on branch
creation). Frozen authority is not rewritten to make history look tidy, and a cancelled contract that
records a wrong conclusion is more useful to a future reader than a silent gap.

**Not a Phase C blocker.** The acceptance boundary does not depend on cancellation. This contract
exists first only because nothing else can be approved while `SPEC-169` remains `Approved`.
