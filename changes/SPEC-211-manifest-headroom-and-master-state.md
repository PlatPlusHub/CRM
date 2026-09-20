# Change Request — SPEC-211

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Restore the manifest's approval headroom by trimming `Last Completed` back to the single current
capability its own rule allows, and reconcile two stale current-state facts in the Master records —
the control-suite count in `MASTER_GAP_REGISTER.md` and the EC-1 coverage assertion in
`MASTER_EXECUTION_PLAN.md`, which duplicates a count that `MASTER_SURFACE_DISPOSITION.md` owns.

## Business Reason

**The repository cannot start its next Change Request.** Measured against the live guard, not
calculated: `_ORVION_CANONICAL/manifest.md` is **6995 of its 7000-character Check-5 budget**, leaving
5 characters. Setting `Active Change Request` to this contract's own path takes it to **7045**, and
`scripts/check_repository_consistency.ps1` reports `MANIFEST BLOAT: manifest.md is 7045 characters
(budget 7000)`. Even a minimal 21-character path reaches 7012. Every ordinary Approval transition is
therefore structurally unable to commit.

The cause is pre-existing and self-inflicted: `Last Completed` carries a **647-character** narrative
about `CTRL-2` — the 375→397 analysis, both reproduced examples, the SPEC-203 shape and the test
count. The manifest's own line 18 says it "holds ONLY current state", and line 24 says `Last
Completed` "names the single most recent capability — REPLACE it each time... If any field becomes a
changelog, trim it." That narrative is a changelog, and all of it is already held by
`changes/SPEC-210-applicability.md`, `MASTER_GAP_REGISTER.md` and the git log.

This is the exact shape `SPEC-191` recorded: Check 5 refused an Approve commit at 7060/7000 because
`Last Completed` had accumulated a 658-character changelog. The repair then was to trim to the current
capability and leave detailed evidence in its owning artifacts. The budget was not raised, and is not
raised here.

Two current-state facts drifted alongside it. `MASTER_GAP_REGISTER.md`'s `CTRL-2` entry says
`293 passed, 0 failed`; the certified `SPEC-210` evidence is `294 passed, 0 failed` — the 293 came
from a prototype run in a disposable worktree, before the `WC` population assertion existed. And
`MASTER_EXECUTION_PLAN.md`'s EC-1 exit-criteria row asserts coverage is "Standing at **6 of 77
recorded** (2026-09-07)" while naming `MASTER_SURFACE_DISPOSITION.md` as the mechanism that owns it;
that file records **13 of 77** as of 2026-09-20. One authority should state the count.

## Risks

**Trimming could delete a fact nothing else holds.** Mitigated by checking each removed clause against
its owning artifact before removal; the compact line keeps the capability, the certifying contract and
the date, and everything removed is verifiable in `changes/SPEC-210-applicability.md` and the register.

**Reconciling counts could rewrite history.** Dated `Previously:` entries in both Master files state
what was true on their dates and are not touched. Only current-state assertions move, and the EC-1 row
moves to a pointer rather than to a new hardcoded number that would drift again.

**Solving today's headroom could recreate it tomorrow.** The Complete-state `Last Completed` for this
contract is itself held compact, and the next Approval's pointer is simulated against a non-reserving
placeholder before this contract freezes.

**A permanent headroom guard is deliberately NOT added.** Its bound cannot be derived from any
authoritative repository fact, so it would be a proxy — and a proxy guard is worse than none. The
already-formalized `ENGINEERING_METHOD.md §3` measure-before-freezing obligation covers it.

## Supersedes / Depends On

Depends on `SPEC-191`, whose trim precedent this follows, and on `SPEC-210`, whose certified evidence
supplies the corrected count. Supersedes nothing.

## Write Scope

- `changes/SPEC-211-manifest-headroom-and-master-state.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_SURFACE_DISPOSITION.md` — it is the SSOT this contract points TO. Editing it
  to match a plan that duplicated it would invert the authority.
- `scripts/check_repository_consistency.ps1` — Check 5 is the authority being obeyed. The budget is
  never raised to fit; the subject is trimmed.
- `scripts/check_agent_continuity.ps1`, `scripts/test_agent_continuity.ps1`, `changes/TEMPLATE.md`,
  `ENGINEERING_METHOD.md`, `AGENTS.md`, `CR_LIFECYCLE.md`, `GOVERNANCE.md` — no control behaviour
  changes; this is a state reconciliation, not a mechanism change.
- `supabase/**` — no database change. No Supabase project is contacted.
- `changes/SPEC-210-applicability.md` and every other terminal contract — the evidence the manifest
  stops restating lives there and must stay byte-identical.

## Required Reading

- `_ORVION_CANONICAL/manifest.md`
- `changes/SPEC-191-check-12-measures-repository-evidence-not-generated-cache.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `scripts/check_repository_consistency.ps1`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- `pwsh -NoProfile -File scripts/generate-ai-map.ps1`

## Implementation Steps

1. Verification check: `_ORVION_CANONICAL/manifest.md`'s `Last Completed` line is at most 200
   characters. If it is longer, replace it with the single current capability — `CTRL-2` closed,
   certified by `SPEC-210`, with its date — removing the 375→397 analysis, the reproduced examples,
   the `SPEC-203` shape and the test count, each of which is verified present in
   `changes/SPEC-210-applicability.md` or `reports/master/MASTER_GAP_REGISTER.md` before removal.
   Change no other manifest field: not `Current Phase`, not `Next capability`, not the migration
   counts, not the Primary evidence.
2. Verification check: `reports/master/MASTER_GAP_REGISTER.md` contains `294 passed, 0 failed`. If it
   still says `293`, correct that one current-state figure in the `CTRL-2` narrative to the certified
   `SPEC-210` result. Rewrite no dated `Previously:` entry.
3. Verification check: `reports/master/MASTER_EXECUTION_PLAN.md`'s EC-1 exit-criteria row contains no
   hardcoded `of 77` current count. If it does, replace that current-state assertion with a pointer to
   `MASTER_SURFACE_DISPOSITION.md`, which owns it, and refresh the plan's `Last updated` header to
   state that Batch 6 has advanced through Slice 12 with the live count held by its SSOT. Leave every
   dated `Previously:` entry exactly as written, including the counts true on their dates.
4. Verification check: `scripts/check_repository_consistency.ps1` exits 0 and Check 5 reports no
   `MANIFEST BLOAT`. Regenerate `ai-map.json` with its generator — never by hand — then run the check
   and record the manifest's measured character count and the headroom remaining at both the Approve
   and the Complete state.

## Acceptance Criteria

- [x] `_ORVION_CANONICAL/manifest.md` measures under 7000 characters with `Active Change Request` set
      to this contract, proven by `scripts/check_repository_consistency.ps1` reporting no
      `MANIFEST BLOAT`.
- [x] The Complete-state manifest leaves enough headroom for the next Approval, proven by simulating a
      further pointer of at least 35 characters without exceeding the budget.
- [x] `Last Completed` names one capability and its certifying contract, and no fact removed from it is
      absent from `changes/SPEC-210-applicability.md`, `MASTER_GAP_REGISTER.md` or the git log.
- [x] `reports/master/MASTER_GAP_REGISTER.md` states `294 passed, 0 failed` for `CTRL-2`.
- [x] `reports/master/MASTER_EXECUTION_PLAN.md`'s EC-1 row states no hardcoded current coverage count
      and points at `MASTER_SURFACE_DISPOSITION.md` instead.
- [x] Every dated `Previously:` entry in both Master files is byte-identical to baseline.
- [x] `ai-map.json` agrees with the manifest by value on every field Check 7 compares.
- [x] No file outside Write Scope is modified; `supabase/` is untouched and no Supabase project is
      contacted; Batch 6 Slice 13 remains unopened.

## Execution Log

### 2026-09-21 — Pre-freeze proof, run against the real guard rather than calculated

A1 REPRODUCED. At `c801bd5` the manifest measured **6995 / 7000** under Check 5's own normalization
(`(Get-Content -Raw) -replace "\r\n","\n"`, then `.Length`). With `Active Change Request` set to this
contract's real path, `scripts/check_repository_consistency.ps1` reported
`MANIFEST BLOAT: manifest.md is 7045 characters (budget 7000)`. A minimal 21-character path still
reaches 7012. The next ordinary Approval was structurally uncommittable.

A2. `Last Completed` was **647 characters** of `CTRL-2` narrative; the compact replacement is **189**.
Every clause removed was verified still present in its owning artifact BEFORE removal — `375`, `397`,
the `SPEC-203` shape and the `AGENTS.md` example in `changes/SPEC-210-applicability.md` and
`MASTER_GAP_REGISTER.md`; the test count in `SPEC-210`. Nothing removed here is held nowhere.

A3. Approve state — trim plus the real pointer plus a regenerated `ai-map.json` — measured
**6587 / 7000**, and the real check returned `REPOSITORY CONSISTENCY: CLEAN`, exit 0.

A4. Complete state measured **6476 / 7000**, headroom **524**, and the NEXT Approval was simulated with
a deliberately NON-RESERVING placeholder (`changes/SPEC-NNN-historical-guard.md`, 35 characters)
reaching 6508 with 492 left; a 49-character name still fits. A real future SPEC number was never
written into tracked content, because a published mention reserves that identity permanently.

A5. No permanent headroom guard was added. Its bound cannot be derived from any authoritative
repository fact, so it would be a proxy, and a proxy guard is worse than none.

WRITE CLOSURE, self-applied. `SPEC-210`'s own rule binds this contract: with `ai-map.json` removed from
Write Scope the evaluator returns
`APPROVAL_EVIDENCE:FAIL:write closure - ai-map.json is regenerated by a mandatory verification`.
It is in scope, so the closure is satisfied.

TWO MISTAKES MADE IN THE DISPOSABLE PROBE, both caught there and recorded rather than hidden:
1. A header edit DELETED the dated `2026-09-08` entry instead of demoting it, leaving a dangling
   `Previously:`. That is the history rewriting Acceptance Criterion 6 forbids. Reverted and redone so
   the entry is demoted verbatim.
2. Relative paths passed to `[IO.File]` resolved against the .NET working directory, which PowerShell's
   `cd` does not change, so one edit landed in the REAL repository instead of the probe. It was
   uncommitted, no contract was active, the pre-commit Gate would have refused it, and
   `git checkout --` restored the tree to clean before anything else ran. All later edits use absolute
   paths only.

### 2026-09-21 — Steps 1-4

Step 1 — ALREADY APPLIED. The trim was performed in the Approve commit `0c49ec7`, because the manifest
had to be legal for that transition to be representable at all; `Last Completed` measured 189
characters at implementation time, satisfying the step's own check. No other manifest field moved —
`Current Phase`, `Next capability`, the migration counts and the Primary evidence are byte-identical.

Step 2 — `reports/master/MASTER_GAP_REGISTER.md` corrected in exactly one place, `293 passed, 0 failed`
to `294 passed, 0 failed`. The 293 was a prototype run taken in a disposable worktree before the `WC`
population assertion existed; the certified `SPEC-210` result on the real tree is 294. Diff is +1/-1.

Step 3 — `reports/master/MASTER_EXECUTION_PLAN.md`. The EC-1 exit-criteria row asserted "Standing at
**6 of 77 recorded** (2026-09-07)" while naming `MASTER_SURFACE_DISPOSITION.md` as the mechanism that
owns the count, which then recorded 13 of 77. The hardcoded current figure is replaced by a pointer to
that SSOT rather than by another number that would drift again. The stale `Last updated: 2026-09-08`
header is DEMOTED verbatim to `Previously: 2026-09-08` — not deleted, not rewritten — and every dated
entry keeps the count true on its date, including `9 of 77` and the 2026-09-07 `6 of 77`. Diff is
+4/-2 over a 1600-line file.

Step 4 — `ai-map.json` regenerated by its generator, never by hand.
`scripts/check_repository_consistency.ps1` returns `REPOSITORY CONSISTENCY: CLEAN`, exit 0, with no
`MANIFEST BLOAT`. Approve-state manifest **6587 / 7000**, headroom **413**.

SCOPE. `supabase/` shows zero changed files and no Supabase project was contacted.
`MASTER_SURFACE_DISPOSITION.md` — the SSOT this contract points at — is byte-identical to baseline.

## Verification Notes

### 2026-09-21 — Review

Reviewed against the frozen Objective, Risks and Acceptance Criteria through the convergence lens.

MISSING — none. Headroom restored, both stale current-state facts reconciled.

PARTIAL — none. The EC-1 row is not given a fresh number; it is given a pointer, which is the durable
form of the same fact and cannot drift again.

CONTRADICTORY — none. `MASTER_SURFACE_DISPOSITION.md` stays the sole authority for the `of 77` count
and is byte-identical to baseline.

UNREQUESTED — none. No guard, no budget change, no new report, no mechanism change. Check 5 was obeyed,
never widened.

DUPLICATED — the opposite: this contract REMOVES duplication. The manifest stops restating SPEC-210's
evidence and the plan stops restating the disposition count.

MORE COMPLEX THAN NECESSARY — no. Five files, a +4/-2 and a +1/-1 diff, and one manifest line replaced.

NO HISTORY REWRITTEN, checked explicitly. The `2026-09-08` plan entry is demoted verbatim to
`Previously:`; `EC-1 stands at 9 of 77` and the 2026-09-07 `6 of 77` both survive unchanged inside their
dated entries. Only current-state assertions moved.

MEASUREMENTS. Pre-fix 6995/7000 (headroom 5, next Approval impossible at 7045). Approve state
6587/7000 (headroom 413). Complete state proven at 6476/7000 (headroom 524) with the next Approval
simulated at 6508 against a non-reserving placeholder.

CERTIFICATION. `-Finish` on the derived REPOSITORY profile: `check_repository_consistency.ps1`,
`git diff --check` and `generate-ai-map.ps1` all PASS, `LOCAL_CERTIFY: READY`, exit 0.

PRE-APPROVAL. The evaluator returned `APPROVAL_EVIDENCE: NOT APPLICABLE`, which is the correct derived
verdict for a REPOSITORY-only contract — no control, authority or permanent-control surface is in Write
Scope. It is recorded as what it is rather than converted into a `PASS` by adding an unread evidence
section, which is the vacuous-PASS defect `SPEC-198` closed. Derived write closure still bound and was
satisfied.

PRIMARY was not contacted. SECONDARY was not contacted. `supabase/` has zero changed files.

Verdict: Confirmed Complete

## Review Gate

- [x] Confirmed Complete — the frozen Objective is met with nothing missing, contradictory,
      unrequested or duplicated, no existing invariant is weakened, and no budget was raised.
