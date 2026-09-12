# Change Request — SPEC-167

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make the Agent Control Gate judge a CI range by the states actually committed inside it, so a
candidate history cannot hide a forbidden intermediate commit behind a clean final tree.

## Business Reason

`main` is to be protected by a required acceptance check that proves an exact candidate SHA before
promotion. That protection is only worth what the Gate proves about the range it admits, and the
Gate currently proves less than it appears to.

`Diff-Records` (`scripts/check_agent_continuity.ps1`) computes a NET
`git diff BaseRef..HeadRef`, and every consumer of its records therefore judges the range by its two
endpoints. `Status-Path` is the single exception: `SPEC-162` and `SPEC-165` already established that
a range is a sequence of committed transitions and walk it per commit. That insight was applied to
Status and to nothing else, and it was applied to the governing contract alone.

Four consequences follow, each a way for a committed violation to reach `main` unseen:

- A commit that writes a file outside Write Scope and a later commit that restores it cancel out in
  the net diff, so `OUT_OF_SCOPE_WRITE` never sees the record. The repository's invariant is
  "forbidden to commit", not "forbidden at HEAD".
- A commit that widens `Write Scope` and a later commit that restores it are net-identical, so
  `Validate-FrozenAuthority` — which compares the BASE text against the HEAD text — sees no change,
  and the writes that widened authority authorized are themselves invisible for the same reason.
- An illegal Status transition in a contract that is not the resolved governing contract is never
  walked at all, so a valid corrective Change Request can carry an invalid earlier one.
- Terminality is read at the range BASE only, so a contract that reaches `Complete` inside the range
  and is then modified by a later commit in that same range is not recognised as historical.

This is the admission boundary's load-bearing property. It is repaired before `main`'s protection
depends on it, not after.

## Risks

Moderate and contained. The change makes the Gate strictly stricter in range mode only; local
working-tree mode is untouched. The realistic failure is over-strictness — rejecting a legal history
— which is why the adversarial group added in Step 1 asserts the legal multi-commit lifecycles in
both directions and the `SPEC-165` born-and-completed-in-range shape must keep passing. A contract
created inside the range has no text at BASE, so the frozen baseline must fall back to its first
appearance in the range; getting that wrong would re-break `SPEC-165`, and Step 1 pins it.

Runtime cost is a handful of `git show` reads per commit in the range. Pushes are small and the cost
is not material.

No risk to `main`: this Change Request changes no workflow, no Ruleset, and no branch.

## Supersedes / Depends On

None. Extends the range semantics established by `SPEC-162` and `SPEC-165`.

## Write Scope

- `changes/SPEC-167-range-integrity-over-committed-intermediate-states.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-166-a-successful-gate-states-its-own-exit-status.md`
- `changes/SPEC-165-range-completion-of-a-contract-created-in-range.md`
- `changes/TEMPLATE.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `ENGINEERING_METHOD.md`
- `scripts/check_repository_consistency.ps1`
- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
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

1. Check for `Assert '113` in `scripts/test_agent_continuity.ps1`. If absent, add the adversarial
   mutation group below, run the suite against the unmodified control script, and record in the
   Execution Log which cases already hold and which fail. Each case builds a multi-commit range and
   is asserted through `RunRange`:
   - a commit writing a file outside Write Scope followed by a commit restoring it must be REJECTED
     as `OUT_OF_SCOPE_WRITE` naming that file;
   - a commit widening the governing contract's `Write Scope` followed by a commit restoring the
     approved scope must be REJECTED as `FROZEN_AUTHORITY_MUTATED:Write Scope`;
   - a range in which a second contract records `Approved` and then `Complete` in one commit, while
     the governing contract's own path is legal, must be REJECTED as `ILLEGAL_STATUS_TRANSITION`;
   - a range in which a contract reaches `Complete` and a later commit in the same range modifies
     that contract must be REJECTED as `HISTORICAL_CR_MUTATION`;
   - a range in which a contract reaches `Complete` and a later commit in the same range returns it
     to `In Progress` must be REJECTED;
   - the legal lifecycle `Approved -> In Progress -> Complete` across three commits must be
     ACCEPTED, and the `SPEC-165` shape — a contract created, approved, implemented and completed
     inside one range — must remain ACCEPTED.
2. Check for `function Validate-CommittedRange` in `scripts/check_agent_continuity.ps1`. If absent,
   add it, invoked from the `try` block only when `$BaseRef` is set and only after `Resolve-Contract`
   has produced the governing contract path. For each commit returned by
   `git rev-list --reverse "$BaseRef..$HeadRef"` it reads that commit's own diff against its first
   parent and applies, per commit, the checks the net diff cannot see. It reuses `Read-GitFile`,
   `Section`, `Section-OutOfScope`, `Normalize`, `Status-FromText` and `Validate-StatusPath` rather
   than reimplementing any of them, and it raises the existing error codes with the offending commit
   appended after an `@` so no new failure vocabulary is introduced.
3. Check for `FrozenBaseline` in `scripts/check_agent_continuity.ps1`. If absent, give
   `Validate-CommittedRange` the effective frozen baseline rule: the governing contract's text at
   `$BaseRef` when it exists there, otherwise its text at the first commit in the range that
   contains it. Every later commit in the range that contains the contract must match that baseline
   on every section `$script:FrozenSections` names and on `Out of Scope`, raising
   `FROZEN_AUTHORITY_MUTATED`. This is the clause that keeps a contract created inside its own range
   legal, which `SPEC-165` established and this step must not regress.
4. Check for `$scopeAt` in `scripts/check_agent_continuity.ps1`. If absent, have
   `Validate-CommittedRange` evaluate every path touched by each commit against the Write Scope
   taken from the effective frozen baseline of Step 3, skipping only the governing contract's own
   path, and raise `OUT_OF_SCOPE_WRITE` for any other path. Because the scope comes from the frozen
   baseline rather than from the contract as it stood at that commit, a commit that widened its own
   scope cannot authorise its own writes.
5. Check for `TouchedContracts` in `scripts/check_agent_continuity.ps1`. If absent, have
   `Validate-CommittedRange` collect every `changes/SPEC-*.md` path touched by any commit in the
   range and run `Validate-StatusPath (Status-Path <path> $BaseRef $null)` on each, so a
   non-governing contract's committed transitions are judged by the same matrix as the governing
   one. Leave the existing governing-contract call in the `try` block in place.
6. Check for `terminal at an earlier commit` in `scripts/check_agent_continuity.ps1`. If absent,
   have `Validate-CommittedRange` raise `HISTORICAL_CR_MUTATION` when a contract's Status is
   `Complete` or `Cancelled` at one commit in the range and a later commit in that same range
   modifies that contract. Leave `Validate-HistoryAndIds`' existing BASE-terminality check in place;
   it covers contracts already terminal before the range began.
7. Check for `committed intermediate states` in `CR_LIFECYCLE.md`. If absent, extend the §8
   paragraph that records "a CI range is a sequence of transitions, never one transition" so it
   also records that every other range check now judges the commits that occurred rather than the
   range's endpoints, and name the four violation classes this closes.
8. Check that `_ORVION_CANONICAL/manifest.md` names
   `changes/SPEC-167-range-integrity-over-committed-intermediate-states.md` as the Active Change
   Request. If it does not, set it, and regenerate `ai-map.json` with
   `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [ ] `scripts/test_agent_continuity.ps1` contains an adversarial group covering all seven cases
      named in Step 1, and the whole suite passes.
- [ ] `scripts/check_agent_continuity.ps1` defines `Validate-CommittedRange`, and it is invoked only
      when `$BaseRef` is set.
- [ ] A range whose commits write a file outside Write Scope and then restore it is rejected as
      `OUT_OF_SCOPE_WRITE` naming that file.
- [ ] A range whose commits widen the governing contract's `Write Scope` and then restore it is
      rejected as `FROZEN_AUTHORITY_MUTATED:Write Scope`.
- [ ] A range carrying an illegal Status transition in a contract that is not the governing contract
      is rejected as `ILLEGAL_STATUS_TRANSITION`.
- [ ] A range in which a contract becomes terminal and is then modified by a later commit in the
      same range is rejected as `HISTORICAL_CR_MUTATION`.
- [ ] The legal three-commit `Approved -> In Progress -> Complete` lifecycle and the `SPEC-165`
      born-and-completed-in-range shape are both still accepted.
- [ ] `Validate-CommittedRange` introduces no error code that did not already exist in
      `scripts/check_agent_continuity.ps1` before this Change Request.
- [ ] `CR_LIFECYCLE.md` §8 records that range checks judge committed states rather than range
      endpoints, and names the four violation classes closed.
- [ ] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while
      it is in progress, and `ai-map.json` is regenerated from the current tree.

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

**Scope boundary.** This Change Request is Phase A of the Simple Acceptance program and deliberately
stops at range integrity. It creates no branch, no workflow, and no Ruleset change. The
`orvion-preflight` ref, the `orvion-acceptance` workflow, the required-status-check cutover, the
paved-road publisher and the Supabase CLI authority unification are each separate Change Requests
that depend on this one, because `main`'s protection must not come to depend on a range check that
does not yet hold.

**Why not a second policy engine.** Every check added here is an existing check evaluated over a
different set of inputs. No new validation semantics, no new error vocabulary, no second authority
for Change Request state. `Validate-CommittedRange` is a loop over commits that calls the functions
the Gate already trusts, which is why it can be strict without becoming a thing to maintain
separately.

**Measured live state at authoring (2026-09-12).** `origin/main` and `HEAD` were both
`262462771d829a3875e8d44ce9fb0653b99db2aa` with a clean tree. Ruleset `main integrity` (id
`22950574`) was active on `~DEFAULT_BRANCH` with rules `non_fast_forward` and `deletion`, no bypass
actors, and no required status check. Classic branch protection was determined to be absent — the
REST endpoint returned `404 Branch not protected`. These are recorded because the later phases read
them again rather than trusting this note.

**Adjacent defect, deliberately not fixed here.** `.github/workflows/migration-ci.yml` pins the
Supabase CLI through `supabase/setup-cli@v3` at `2.109.1` while `package-lock.json` resolves
`2.109.0`. That is a genuine second version authority, but it is not a range-integrity defect and
repairing it here would widen this contract's scope to hide an unrelated finding. Recorded as an
Engineering Observation for its own Change Request per `CR_LIFECYCLE.md §11`.
