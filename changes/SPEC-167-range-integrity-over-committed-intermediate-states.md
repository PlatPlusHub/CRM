# Change Request — SPEC-167

## Status

[ ] Draft
[ ] Approved
[x] In Progress
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

Resume Step: DONE
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

- [x] `scripts/test_agent_continuity.ps1` contains an adversarial group covering all seven cases
      named in Step 1, and the whole suite passes.
- [x] `scripts/check_agent_continuity.ps1` defines `Validate-CommittedRange`, and it is invoked only
      when `$BaseRef` is set.
- [x] A range whose commits write a file outside Write Scope and then restore it is rejected as
      `OUT_OF_SCOPE_WRITE` naming that file.
- [x] A range whose commits widen the governing contract's `Write Scope` and then restore it is
      rejected as `FROZEN_AUTHORITY_MUTATED:Write Scope`.
- [x] A range carrying an illegal Status transition in a contract that is not the governing contract
      is rejected as `ILLEGAL_STATUS_TRANSITION`.
- [x] A range in which a contract becomes terminal and is then modified by a later commit in the
      same range is rejected as `HISTORICAL_CR_MUTATION`.
- [x] The legal three-commit `Approved -> In Progress -> Complete` lifecycle and the `SPEC-165`
      born-and-completed-in-range shape are both still accepted.
- [x] `Validate-CommittedRange` introduces no error code that did not already exist in
      `scripts/check_agent_continuity.ps1` before this Change Request.
- [x] `CR_LIFECYCLE.md` §8 records that range checks judge committed states rather than range
      endpoints, and names the four violation classes closed.
- [x] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while
      it is in progress, and `ai-map.json` is regenerated from the current tree.

## Execution Log

### 2026-09-12 — Claude Opus 5 (agent execution run)

Outcome: Complete

Step results:
- Step 1: Applied — adversarial group added as assertions 115–120. See the PRECHECK table below.
- Step 2: Applied — `Validate-CommittedRange` added after `Validate-StatusPath`, invoked from the
  `try` block under `if($BaseRef)` after `Resolve-Contract`, before `Validate-ManifestCrState`.
- Step 3: Applied — `$FrozenBaseline` resolves to the contract at `$BaseRef`, falling back to its
  first appearance in the range.
- Step 4: Applied — `$scopeAt` is read from the frozen baseline, never from the commit's own text.
- Step 5: Applied — `$touched` collects every contract touched per commit; each gets
  `Validate-StatusPath`.
- Step 6: Applied — `$terminal` records terminality after each commit's own checks.
- Step 7: Applied — `CR_LIFECYCLE.md` §8 paragraph added ahead of the `SPEC-163` LOCAL-evidence rule.
- Step 8: Already Applied — the manifest pointer was set by the Approve commit; `ai-map.json`
  regenerated.

PRECHECK, against the unmodified control script. Every case was ACCEPTED (`ORVION: READY`), which is
the defect:

| Case | Assertion | Before | After |
| --- | --- | --- | --- |
| F transient out-of-scope write | 115 | READY | `OUT_OF_SCOPE_WRITE:outside.txt` |
| G transient Write Scope widening | 116 | READY | `FROZEN_AUTHORITY_MUTATED:Write Scope` |
| D illegal transition, non-governing CR | 117 | READY | `ILLEGAL_STATUS_TRANSITION:Approved->Complete` |
| E mutation after terminal in range | 118 | READY | `HISTORICAL_CR_MUTATION:changes/SPEC-902-other.md` |
| H reopened and re-closed in range | 119 | READY | `HISTORICAL_CR_MUTATION` |
| legal born-in-range, multi-file | 120 | READY | READY (unchanged) |

Cases A, B and C were confirmed `ALREADY PROTECTED` by assertions 83 and 111 and were not touched.

Suite: 122 passed / 5 failed before the repair, 127 passed / 0 failed after.

Engineering Observations (none repaired here; none widens this contract's scope):

1. **Step 1's verification check was stale when it was written.** `Assert '113` was already present
   from the `SPEC-165` group, so a literal reading marks Step 1 Already Applied while the adversarial
   group demonstrably did not exist. The check was authored from a miscounted assertion total; the
   suite ends at 114. Recorded rather than silently reinterpreted. The step's intent, its own body
   and every Acceptance Criterion agree on what the work must produce, and the live owner instruction
   of 2026-09-12 ("Execute Phase A test-first exactly as scoped. Reproduce the identified F/G/D/E-H
   historical-range failures before modifying the implementation") resolved it; the group was added
   at 115–120. A future contract must derive such a check from the file, not from a remembered count.
2. **Two draft fixtures measured the wrong thing and were corrected before the repair.** Cases 117
   and 118 first failed with `SPEC_ID_ALREADY_USED`, because naming a *new* contract in the governing
   Write Scope puts its identifier into the baseline text and collision validation then reserves it
   (`CR_LIFECYCLE.md` §4, deliberate). The `Second` helper now commits the second contract into the
   range BASE so the range carries only the transitions under test. Case 119 first asserted a bare
   non-zero exit and passed on `ORPHANED_APPROVED_CR` — a FINAL-STATE mechanism, since a non-governing
   contract left executable at `HEAD` is always an orphan. It was reframed to reopen *and re-close*
   inside the range, which removes the orphan and leaves only the forbidden intermediate state, and
   it now asserts a named code. Both were vacuous tests in the `ENGINEERING_METHOD.md §3` sense.
3. **`.github/workflows/migration-ci.yml` pins the Supabase CLI at `2.109.1` via
   `supabase/setup-cli@v3` while `package-lock.json` resolves `2.109.0`.** A genuine second version
   authority, not a range-integrity defect. Deferred to its own Change Request.

Commits: recorded by the Complete commit that carries this entry.

## Verification Notes

### 2026-09-12 — Claude Opus 5 (review)

Verdict: Confirmed Complete

Findings: every Acceptance Criterion was re-checked against the live tree rather than against the
Execution Log's self-report.

- `Validate-CommittedRange` is defined at `scripts/check_agent_continuity.ps1:329` and invoked at
  line 957 as `if($BaseRef){Validate-CommittedRange $rel}` — the only call site, and guarded, so
  local working-tree mode is provably unaffected.
- Assertions 115–120 are present and each names a specific failure code. This was checked because
  case 119 originally passed on a bare non-zero exit produced by `ORPHANED_APPROVED_CR`, a
  final-state mechanism; a bare-exit assertion would have satisfied the criterion while proving
  nothing about terminality.
- The no-new-error-code criterion was verified mechanically rather than by inspection: every code
  thrown inside the new function was extracted and counted against
  `git show 8be2abd:scripts/check_agent_continuity.ps1`. `HISTORICAL_CR_MUTATION` (2 occurrences)
  and `OUT_OF_SCOPE_WRITE` (1) both pre-existed; `FROZEN_AUTHORITY_MUTATED` and
  `ILLEGAL_STATUS_TRANSITION` are raised by the reused validators, not by new code.
- The four rejection criteria and the two must-accept criteria are proven by the suite, which
  `-Finish` executed rather than this review asserting: 127 passed, 0 failed. Assertions 83 and 111
  (the pre-existing legal lifecycles) remain green, which is the over-strictness guard.
- `-Finish` emitted `LOCAL_CERTIFY: READY` with all five guard suites, the consistency guard and
  `git diff --check` passing.
- `CR_LIFECYCLE.md` §8 carries the new paragraph; the manifest and `ai-map.json` both name this
  Change Request.

No discrepancy found between the Execution Log and the live repository state. Scope was not widened:
the Supabase CLI dual-authority finding was recorded and deferred rather than repaired here.

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
