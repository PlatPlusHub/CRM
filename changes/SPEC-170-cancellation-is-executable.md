# Change Request — SPEC-170

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
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

Resume Step: 1
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

- [ ] `scripts/test_agent_continuity.ps1` contains an adversarial group covering all five cases named
      in Step 1, and the whole suite passes.
- [ ] `Resolve-Contract` admits a contract whose Status is `Cancelled` as the governing contract.
- [ ] A local Gate run over an `Approved -> Cancelled` transition with the manifest pointer cleared
      succeeds instead of reporting `NO_GOVERNING_CR`.
- [ ] A `Complete -> Cancelled` transition is rejected.
- [ ] A range reaching `Complete` without `In Progress` immediately before it is still rejected as
      `INVALID_COMPLETION_TRANSITION`.
- [ ] `Resolve-Contract` raises no error code that did not already exist before this Change Request.
- [ ] `changes/SPEC-169-agent-control-skips-the-preflight-ref.md` has Status `Cancelled`, and its
      Objective, Business Reason, Write Scope, Implementation Steps and Execution Log are byte-identical
      to their state before this Change Request.
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
