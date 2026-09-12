# Change Request — SPEC-175

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Bound the required admission boundary at an exact approved job timeout of 30 minutes, guarded so that
neither removing the bound nor moving it out of the approved value can pass without a Change Request.

## Business Reason

Phase C made `orvion-acceptance` the single required status check on `main`. The workflow declares no
`timeout-minutes`, so GitHub's default job timeout of 360 minutes is the effective upper bound on how
long the repository's only admission boundary may remain pending. A required check that never concludes
is indistinguishable from one that has not concluded yet, so one hung step — a docker pull, a Supabase
container that never reports ready, a pgTAP session that blocks — holds every promotion for hours.

The bound is derived from the only evidence that exists. All three `ORVION Acceptance` runs, read live:

```text
34715562635  c3d3c63  success  506 s  ubuntu-24.04 (frozen)
34705700442  18abbea  success  513 s  ubuntu-latest
34697041323  d0bba10  failure  148 s  ubuntu-latest (failed fast at the Gate, six steps skipped)
```

Per-step maxima across the two successful runs compose to 522 s. Bounding each step class by its own
failure mechanism — deterministic pwsh 312 s ×2 for runner CPU contention, network/registry 124 s ×5
because registry `toomanyrequests` throttling has already been observed here, database 86 s ×2 —
envelopes at 1,416 s = 23.6 min. The approved bound is 30, leaving 6.4 minutes of headroom above that
envelope rather than 1.4, because the sample is two successful runs and the network tail is not
statistically measured. It still reduces the 360-minute worst case by twelve times.

The guard pins the exact approved value rather than accepting a range. A range would let a weaker agent
set the required boundary to 5 minutes while the suite stayed green, making healthy candidates
impossible to admit — the failure direction a human notices but a test does not. Both directions must be
refused: too low makes admission impossible, too high leaves a hung admission blocked for hours.

## Risks

Low, and every failure direction fails closed.

A bound that is too low would reject healthy work. 30 minutes is 3.5× the slowest run ever observed and
6.4 minutes above the degraded envelope, and the guard refuses any value but the approved one, so the
bound cannot drift downward without a Change Request that says so.

The sample is two successful runs, and only one on the frozen `ubuntu-24.04` plus pinned-checkout
configuration. Measurement gives a floor, not a tail; the ×5 network factor is a stated risk posture
rather than a measured percentile. This is acceptable because the failure mode is a rejected candidate,
never a wrongly admitted one, and because retuning is a controlled future change.

Pinning the exact value means a future evidence-backed retune must change the workflow value and the
guard's expected value together. That is deliberate: it makes evolution explicit and auditable rather
than silent. It is not fossilization, because the number is the current repository contract rather than
an architectural constant.

A timeout cancels the job, and `cancelled` is not `success`, so the Ruleset refuses the push and
`-Certify` reports FAILED through the existing `conclusion -ne 'success'` path. No control-plane change
is required, and none is made.

## Supersedes / Depends On

Corrects and supersedes `changes/SPEC-174-bounded-required-acceptance.md`, whose Status is `Cancelled`
and which is therefore terminal and not modified. `SPEC-174` was approved with a 25-minute bound and
range-based assertion semantics; the owner replaced both before publication, frozen-authority
enforcement correctly refused amendment of an approved contract, and nothing from that lineage was ever
published. Its implementation commit `ce07859` remains in history and this Change Request changes that
implementation under its own Write Scope.

Depends on `changes/SPEC-172-acceptance-carries-the-evidence-it-replaces.md` and
`changes/SPEC-173-certified-evidence-names-its-context.md`, both `Complete` and terminal, which
established the acceptance boundary and froze its environment. Neither is modified.

## Write Scope

- `changes/SPEC-175-required-acceptance-carries-an-exact-bound.md`
- `.github/workflows/orvion-acceptance.yml`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/claude.yml`
- `.github/workflows/claude-code-review.yml`
- `package.json`
- `package-lock.json`
- `ENGINEERING_METHOD.md`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `GOVERNANCE.md`
- `CODING_STANDARDS.md`
- `changes/TEMPLATE.md`
- `changes/SPEC-174-bounded-required-acceptance.md`
- `changes/SPEC-172-acceptance-carries-the-evidence-it-replaces.md`
- `changes/SPEC-173-certified-evidence-names-its-context.md`
- `supabase/migrations`

## Required Reading

- `.github/workflows/orvion-acceptance.yml`
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

1. Check for `timeout-minutes: 30` in `.github/workflows/orvion-acceptance.yml`. If it is absent, make
   the `acceptance` job declare exactly one job-level `timeout-minutes: 30` beside its existing
   `runs-on:`, replacing the cancelled lineage's `timeout-minutes: 25` if that key is present, and
   reduce its comment to the current measured bound plus the rule that retuning requires fresh evidence
   and a Change Request. Keep the detailed timing analysis in this contract, not in the workflow. Add,
   remove, reorder, weaken and skip no step; leave the runner family, the checkout pin, every Supabase
   invocation and the always-run cleanup exactly as they are.
2. Check for `Assert '155` in `scripts/test_agent_continuity.ps1`. If absent, add one structural
   assertion over the admission job body already parsed for assertions 152 and 153 that fails unless the
   job declares exactly one job-level `timeout-minutes:` key whose integer value is exactly 30. Count
   the job-level keys rather than matching the first, so a second contradicting key is also refused.
3. Check that `_ORVION_CANONICAL/manifest.md` names
   `changes/SPEC-175-required-acceptance-carries-an-exact-bound.md` as the Active Change Request. If it
   does not, set it, and regenerate `ai-map.json` with `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [ ] `.github/workflows/orvion-acceptance.yml` declares exactly one job-level `timeout-minutes: 30` on
      the `acceptance` job, at the same indentation as `runs-on:`, and no `timeout-minutes: 25` remains.
- [ ] No `timeout-minutes` key appears at step level in the acceptance workflow.
- [ ] The workflow's step list is unchanged in count, order and content, and the runner family and the
      40-character `actions/checkout` commit pin are byte-identical to their previous values.
- [ ] The workflow comment states the current measured bound and that retuning requires fresh evidence,
      and does not reproduce the per-step timing analysis.
- [ ] `scripts/test_agent_continuity.ps1` contains an assertion 155 that fails when the admission job
      declares no job-level `timeout-minutes`, when the key is present only at step level, when the
      value is below the approved value, and when it is above the approved value.
- [ ] Each of those four conditions is proven by an independent mutant that kills assertion 155 and
      changes the verdict of no other assertion.
- [ ] `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` passes with zero failures.
- [ ] Assertions 141 to 143 and 150 to 154 still exist and still pass.
- [ ] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while it is
      in progress, and `ai-map.json` is regenerated from the current tree.

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

The candidate range published by this Change Request will contain the cancelled `SPEC-174` lineage and
this contract together. That history is legal and is the point: `SPEC-174` was approved, implemented,
overtaken by an owner decision, refused amendment by the frozen-authority guard, and cancelled, and this
contract then corrected the implementation. The prospective range Gate is run before publication to
prove exactly one governing `Complete` contract, that the cancelled contract confers no authority, and
that no commit in the range wrote outside its approved Write Scope.

No real GitHub timeout is induced. Proving `cancelled → blocked` live would require deliberately hanging
the required admission boundary on a real ref; the chain is established by the Phase C Ruleset readback
and by the existing `conclusion -ne 'success'` judgement in `-Certify`.

The identity was allocated mechanically after the cancellation commit, not from a numbering plan:
`SPEC-175` is the next integer above the real engineering maximum of 174, and at that point it appeared
in no tracked filename and no tracked text, so collision validation admits it. An earlier mention of
`SPEC-175` written into the manifest by the `SPEC-174` Approve commit was removed when the cancellation
cleared the Active pointer, and no tracked occurrence remains.
