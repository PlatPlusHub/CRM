# Change Request — SPEC-212

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close `CTRL-1`. Terminal-contract immutability must activate on a **declared lifecycle boundary**
resolved by Git ancestry, not on the presence of a diagnostic literal in an older copy of the
evaluator's own source — while preserving the original activation boundary exactly, so no history
that is protected today becomes unprotected and none that was never judged becomes retroactively
judged.

## Business Reason

**Reproduced fresh against the published baseline `3fc9ca2`, with no incidental guard able to supply
the refusal.** `Historical-Guard-IsActive` decided whether terminal immutability applied to a
committed range by reading the base ref's copy of `scripts/check_agent_continuity.ps1` and testing
`.Contains('HISTORICAL_CR_MUTATION')`. A behaviour-preserving rename landing inside the range
therefore made the new evaluator search the base for a literal the base could not contain, and the
protection switched itself off in silence.

The reproduction puts **both** the renamed script and the tampered contract inside the governing
contract's Write Scope, so `OUT_OF_SCOPE_WRITE` cannot be mistaken for the guard working:

- control, unmodified evaluator: **exit 1**, `HISTORICAL_CR_MUTATION:changes/SPEC-800-closed.md`;
- same range, diagnostic renamed inside it: **exit 0**, and the range **admits modification of a
  contract that was already `Complete` at the base ref**.

An earlier attempt at this reproduction was discarded rather than reported: renaming the literal
*before* the base commit moves the probe and the emitter together, so the guard stays active and
proves nothing. A second attempt was refused by `OUT_OF_SCOPE_WRITE`, which is incidental defence,
not the control under test. Only the third shape isolates the mechanism.

**Why the existing suite never caught it.** Cases 23, 24, 25 and 65 run a **local** Gate, where the
function returns `$true` unconditionally before reaching any activation decision. Cases 118 and 119
exercise a **different, ungated** path — the in-range terminal set at `Validate-CommittedRange`. No
assertion in the repository reached the activation decision at all, which is precisely why a defect
recorded as OPEN since `SPEC-196` survived every green run since.

## Risks

**Moving the activation boundary is the real hazard, not the mechanism.** `Historical-Guard-IsActive`
first appears at `5d78aacd5335278c5b03edb0b3f969bd86e6b9c4` (2026-09-11); its first parent
`dfcb44a8c233f3e0d88bb2900b21693f2b5091b5` carries no guard. The existing `SPEC Allocation
Enforcement` marker — the same declared-marker pattern, and the obvious thing to reuse — first
appears at `fcf065a` on 2026-09-19, **eight days later**. Reusing it as the cutover would leave every
range based between those two commits unprotected. Measured, not assumed, and refused on that
measurement.

**Reading the boundary at `$Ref` would reintroduce the defect.** Old refs cannot be expected to
declare a boundary that did not exist yet, so the marker is read from the current authority and only
the *ancestry question* is asked of `$Ref`.

**Failing open is the defect's own signature**, so missing and malformed declarations throw, and a
boundary this repository cannot resolve is treated as ACTIVE — being unable to prove a ref is
pre-activation is not a reason to stop protecting it.

**Over-correction would retroactively judge history.** A prototype bug did exactly that and was
caught by measurement: assigning `$LASTEXITCODE=0` inside a PowerShell function creates a
function-scoped shadow, so the next read returned a stale `0` and the guard read ACTIVE for every
ref including pre-activation ones. The truth table is therefore asserted commit by commit rather
than reasoned about.

## Supersedes / Depends On

Closes `CTRL-1`, recorded OPEN in `reports/master/MASTER_GAP_REGISTER.md` and named as a deferred
successor in `scripts/check_agent_continuity.ps1`'s own identity-allocation header. Depends on
`SPEC-196`, which introduced the declared-marker pattern this reuses. Supersedes nothing.

## Write Scope

- `changes/SPEC-212-historical-activation-boundary.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `ENGINEERING_METHOD.md` — no method rule changes. `CTRL-1` is an implementation defect in an
  already-ratified lifecycle invariant, not a new doctrine.
- `AGENTS.md`, `GOVERNANCE.md`, `changes/TEMPLATE.md` — no governance or contract-shape change.
- `.github/workflows/**` — CI is unchanged; the same suite proves the same file.
- `supabase/**`, `scripts/check_database_parity*.ps1`, `scripts/parity_surface.sql`,
  `scripts/check_primary_ledger.ps1` — no database interaction of any kind. A `DATABASE` profile
  derivation from this scope would be a scope defect, and none is derived.
- Every terminal contract in `changes/` — this contract exists to keep them immutable.

## Required Reading

- `CR_LIFECYCLE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- `pwsh -NoProfile -File scripts/generate-ai-map.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Activation stops depending on a diagnostic literal | `Validate-HistoryAndIds` | VERIFY | It is the only caller of `Historical-Guard-IsActive`; its signature and semantics are unchanged, and cases 23/24/25/65/118/119 continue to pass. |
| Activation is declared in the lifecycle authority | `CR_LIFECYCLE.md` §4 | WRITE | The declared boundary and its fail-closed semantics are stated beside the existing `SPEC Allocation Enforcement` marker, which is the same pattern and is deliberately not reused as the value. |
| A new marker line must exist in fixtures | `scripts/test_agent_continuity.ps1` `Reset-Fixture` | WRITE | Synthetic repositories do not contain the boundary commit; the unresolvable case resolves ACTIVE, so every existing range case keeps the behaviour it had under the literal probe. |
| `HISTORICAL_CR_MUTATION` remains the emitted diagnostic | assertions 65, 118, 119, 128 | UNAFFECTED | Only activation stops reading the literal. The string is still emitted and still asserted, so those cases keep proving what they always proved. |
| `CTRL-1` moves from OPEN to RESOLVED | `reports/master/MASTER_GAP_REGISTER.md` | WRITE | Recorded with the original reproduction preserved, per the register's never-delete policy. |
| The evaluator's own deferred-successor note | `scripts/check_agent_continuity.ps1` header | WRITE | The comment says `HISTORICAL_CR_MUTATION` "still carries that defect and is recorded as a successor rather than repaired here"; that sentence stops being true and is corrected with the repair. |
| Terminal immutability itself | every contract already `Complete` or `Cancelled` | VERIFY | The activation truth table is asserted commit by commit against real history so protection neither widens nor narrows. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| The control suite passes | BEFORE_COMPLETION | Step 1 | Step 3 | Step 4 |
| Terminal immutability is active for this contract's own range | BEFORE_IMPLEMENTATION | NONE | NONE | Step 1 |
| `ai-map.json` agrees with the manifest | BEFORE_COMPLETION | Step 4 | Step 4 | Step 4 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `SPEC-196`'s declared-marker pattern in `CR_LIFECYCLE.md`, read by
`Get-AllocationMarker` / `Allocation-ActiveAt`. It is reused as a PATTERN and deliberately not as a
VALUE: `Allocation-ActiveAt` tests presence of the marker at a ref, which for historical immutability
would date activation to whenever the marker was added and silently unprotect eight days of already
protected history. The declared value is therefore the original activation commit and the question
asked of a ref is Git ancestry.

Added Property: whether terminal-contract immutability applies to a committed range becomes a
declared lifecycle fact resolved against Git history, independent of every diagnostic string the
evaluator emits.

Causal Negative: reproduced on the published baseline before this contract was written. Same range,
same fixture, same Write Scope: unmodified evaluator exits 1 on `HISTORICAL_CR_MUTATION`; with the
literal renamed inside the range the evaluator exits 0 and admits modification of a contract that was
already terminal at the base.

Positive Test Design: a contract terminal at the base is still refused under the original diagnostic;
a ref at the declared boundary is judged; legal lifecycles, born-in-range contracts and the existing
terminality cases all still pass.

Negative Test Design: the same tamper with the diagnostic renamed inside the range must still be
refused; a missing boundary must throw `HISTORICAL_ACTIVATION_MARKER_MISSING`; a malformed one must
throw `HISTORICAL_ACTIVATION_MARKER_MALFORMED`; an unresolvable boundary must protect rather than
disable; a ref before the declared boundary must not be retroactively judged.

Non-Empty Population Obligation: a new `CTRL1` family must record at least one accepting case, one
rejecting case and one mutation kill, and the suite's `NON-EMPTY POPULATIONS` guard must enumerate it
— a family absent from that hardcoded list records counts nothing asserts.

Mutation Obligation: the ancestry predicate and the unresolvable-boundary fallback are each
independently killed on a scenario only that predicate can refuse.

Post-Implementation Proof Obligation: the full control suite passes with every new case and both new
mutation kills, and the declared boundary is proven — from this repository's own history, not by
assertion — to be the commit that introduced the guard and whose first parent lacks it.

## Implementation Steps

1. Verification check: `scripts/check_agent_continuity.ps1` contains
   `function Get-HistoricalActivationBoundary`. If absent, add `$script:HistoricalAuthority`,
   `Get-HistoricalActivationBoundary` and a rewritten `Historical-Guard-IsActive` that reads the
   declared boundary from the current lifecycle authority, throws
   `HISTORICAL_ACTIVATION_MARKER_MISSING` when absent and
   `HISTORICAL_ACTIVATION_MARKER_MALFORMED` when it is not a 40-character hex commit, treats a
   boundary this repository cannot resolve as ACTIVE, and otherwise answers by Git ancestry of
   `$Ref` against that boundary. Capture every `$LASTEXITCODE` into a distinct local immediately and
   reset only through `$global:`. Preserve the existing local-mode short circuit. Correct the
   identity-allocation header comment, which states this defect is unrepaired.
2. Verification check: `CR_LIFECYCLE.md` contains `Historical CR Immutability Enforcement:`. If
   absent, declare the boundary `5d78aacd5335278c5b03edb0b3f969bd86e6b9c4` beside the existing
   allocation marker, and state why that marker's own value is not reused, what the fail-closed
   behaviour is, and that a ref before the boundary is not retroactively judged.
3. Verification check: `scripts/test_agent_continuity.ps1` contains `Assert '119b CTRL-1`. If absent,
   add the declared boundary to the fixture lifecycle file, add script-level `Ctrl1Base`,
   `Ctrl1Tamper`, `Ctrl1Build` and `Ctrl1Range` fixtures, add cases `119b`–`119i`, add the two
   mutation kills, and add `CTRL1` to the `NON-EMPTY POPULATIONS` family list. The rename case must
   execute the FIXTURE's copy of the evaluator, because the ordinary runner executes the source copy
   and would prove nothing about a rename.
4. Verification check: the control suite reports `0 failed`. Run
   `pwsh -NoProfile -File scripts/test_agent_continuity.ps1`, record the counts and exit code, record
   `CTRL-1` RESOLVED in `reports/master/MASTER_GAP_REGISTER.md` preserving the original reproduction,
   update `_ORVION_CANONICAL/manifest.md` at the `Complete` transition only, and regenerate
   `ai-map.json` with its generator.

## Acceptance Criteria

- [ ] `Historical-Guard-IsActive` contains no reference to any diagnostic literal, and renaming
      `HISTORICAL_CR_MUTATION` throughout the evaluator does not change whether terminal immutability
      applies.
- [ ] `CR_LIFECYCLE.md` declares the activation boundary
      `5d78aacd5335278c5b03edb0b3f969bd86e6b9c4`, and that commit is proven from git to be the one
      that introduced the guard while its first parent lacks it.
- [ ] A ref before the declared boundary is not retroactively judged; a ref at the boundary and every
      descendant is judged.
- [ ] A missing declaration throws `HISTORICAL_ACTIVATION_MARKER_MISSING`, a malformed one throws
      `HISTORICAL_ACTIVATION_MARKER_MALFORMED`, and an unresolvable boundary protects rather than
      disables.
- [ ] Both the ancestry predicate and the unresolvable-boundary fallback are independently
      mutation-killed, and the `CTRL1` family reports non-zero accept, reject and mutation counts.
- [ ] Terminal `Complete` and `Cancelled` mutation, closed-contract rename and deletion, the
      terminal-inside-range path and the reopen/reclose path all remain refused.
- [ ] `scripts/test_agent_continuity.ps1` reports `0 failed`, and legal lifecycles including
      born-in-range contracts still pass.
- [ ] No file outside Write Scope is modified; no `DATABASE` profile is derived; `supabase/` is
      untouched and no Supabase project is contacted; Batch 6 Slice 13 remains unopened.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Confirmed Complete — the frozen Objective is met, the original activation boundary is
      preserved exactly, no existing protection is weakened, and no new authority was created.
