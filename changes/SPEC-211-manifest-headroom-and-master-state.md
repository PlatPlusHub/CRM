# Change Request — SPEC-211

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
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

Resume Step: 1
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

- [ ] `_ORVION_CANONICAL/manifest.md` measures under 7000 characters with `Active Change Request` set
      to this contract, proven by `scripts/check_repository_consistency.ps1` reporting no
      `MANIFEST BLOAT`.
- [ ] The Complete-state manifest leaves enough headroom for the next Approval, proven by simulating a
      further pointer of at least 35 characters without exceeding the budget.
- [ ] `Last Completed` names one capability and its certifying contract, and no fact removed from it is
      absent from `changes/SPEC-210-applicability.md`, `MASTER_GAP_REGISTER.md` or the git log.
- [ ] `reports/master/MASTER_GAP_REGISTER.md` states `294 passed, 0 failed` for `CTRL-2`.
- [ ] `reports/master/MASTER_EXECUTION_PLAN.md`'s EC-1 row states no hardcoded current coverage count
      and points at `MASTER_SURFACE_DISPOSITION.md` instead.
- [ ] Every dated `Previously:` entry in both Master files is byte-identical to baseline.
- [ ] `ai-map.json` agrees with the manifest by value on every field Check 7 compares.
- [ ] No file outside Write Scope is modified; `supabase/` is untouched and no Supabase project is
      contacted; Batch 6 Slice 13 remains unopened.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Confirmed Complete — the frozen Objective is met with nothing missing, contradictory,
      unrequested or duplicated, no existing invariant is weakened, and no budget was raised.
