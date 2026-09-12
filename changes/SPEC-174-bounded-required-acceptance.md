# Change Request — SPEC-174

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Give the required admission boundary an explicit measured job timeout, so a hung step can no longer
leave `main` indefinitely inadmissible.

## Business Reason

Phase C made `orvion-acceptance` the single required status check on `main`. The workflow declares no
`timeout-minutes`, so GitHub's default job timeout of 360 minutes is now the effective upper bound on
how long the repository's only admission boundary may remain pending.

Before Phase C this was a cost observation. Now it is load-bearing: a required check that never
concludes is indistinguishable from one that has not concluded *yet*, so a single hung step — a docker
pull, a Supabase container that never reports ready, a pgTAP session that blocks — holds every
promotion to `main` for up to six hours while reporting nothing actionable.

The bound is derived from the only evidence that exists. All three `ORVION Acceptance` runs, read live:

```text
34715562635  c3d3c63  success  506 s  ubuntu-24.04 (frozen)
34705700442  18abbea  success  513 s  ubuntu-latest
34697041323  d0bba10  failure  148 s  ubuntu-latest (failed fast at the Gate, six steps skipped)
```

Per-step maxima across the two successful runs compose to 522 s. Bounding each step class by its own
failure mechanism — deterministic pwsh 312 s ×2 for runner CPU contention, network/registry 124 s ×5
because registry `toomanyrequests` throttling has already been observed here, database 86 s ×2 —
envelopes at 1,416 s = 23.6 min. Rounded up to the next whole minute with margin: **25**.

That is 2.9× the slowest observed success, leaves every healthy run at ~34 % of the bound, and cuts
worst-case pending admission 14× against GitHub's default.

## Risks

Low, and every failure direction fails closed.

A bound set too low would reject healthy work. 25 minutes is 2.9× the slowest run ever observed, and
the accepted range asserted by the suite refuses any value below 10 minutes — above the slowest
observed successful run — so the guard itself cannot be satisfied by a bound that would kill a healthy
job.

The sample is two successful runs, and only one on the frozen `ubuntu-24.04` + pinned-checkout
configuration. Measurement gives a solid floor, not a tail; the ×5 network factor is a stated risk
posture rather than a measured percentile. This is acceptable because the setting is retunable and its
failure mode is a rejected candidate, never a wrongly admitted one.

A timeout cancels the job, and `cancelled` is not `success`, so the Ruleset refuses the push and
`-Certify` reports FAILED through the existing `conclusion -ne 'success'` path. No control-plane change
is required, and none is made.

The value is a measured operational setting, not a permanent invariant, so the suite asserts the
bound's existence within an accepted range rather than the number. Pinning 25 exactly would fossilize a
provisional threshold and make a legitimate retune indistinguishable from a guard failure.

## Supersedes / Depends On

Depends on `changes/SPEC-172-acceptance-carries-the-evidence-it-replaces.md` and
`changes/SPEC-173-certified-evidence-names-its-context.md`, both `Complete` and terminal, which
established the acceptance boundary and froze its environment. Neither is modified. Supersedes nothing.

## Write Scope

- `changes/SPEC-174-bounded-required-acceptance.md`
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

1. Check for `timeout-minutes` in `.github/workflows/orvion-acceptance.yml`. If absent, add a
   job-level `timeout-minutes: 25` to the `acceptance` job beside its existing `runs-on:`, with a
   comment recording the measured basis and why the boundary needs a bound at all. Add, remove,
   reorder, weaken and skip no step; leave the runner family, the checkout pin, every Supabase
   invocation and the always-run cleanup exactly as they are.
2. Check for `Assert '155` in `scripts/test_agent_continuity.ps1`. If absent, add one structural
   assertion over the admission job body already parsed for assertions 152 and 153 that fails unless
   the job declares a job-level `timeout-minutes:` whose integer value lies inside the accepted range.
   Assert the bound's existence and range, never equality to the current number, so a retune from
   further evidence is legal and a deletion is not.
3. Check that `_ORVION_CANONICAL/manifest.md` names `changes/SPEC-174-bounded-required-acceptance.md`
   as the Active Change Request. If it does not, set it, and regenerate `ai-map.json` with
   `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [ ] `.github/workflows/orvion-acceptance.yml` declares `timeout-minutes: 25` as a job-level key of
      the `acceptance` job, at the same indentation as `runs-on:`, not inside any step.
- [ ] The workflow's step list is unchanged in count, order and content, and the runner family and
      the 40-character `actions/checkout` commit pin are byte-identical to their previous values.
- [ ] `scripts/test_agent_continuity.ps1` contains an assertion 155 that fails when the admission job
      declares no job-level `timeout-minutes`.
- [ ] Assertion 155 passes for any job-level timeout inside the accepted range and is not satisfied by
      a step-level key, proving it asserts the bound rather than the literal number 25.
- [ ] Deleting the `timeout-minutes` line kills assertion 155 and changes the verdict of no other
      assertion.
- [ ] `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` passes with zero failures.
- [ ] Assertions 141 to 143 and 150 to 154 still exist and still pass.
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

The accepted range asserted by the suite is 10 to 60 minutes, and both endpoints are derived rather
than chosen. The floor is the next whole minute above the slowest observed successful run (8.55 min):
below it, the bound would be capable of killing a job already proven healthy, which would make the
timeout an admission blocker instead of a safety device. The ceiling is an hour — still 6× below
GitHub's 360-minute default and 7× the slowest observed success — because a bound an order of magnitude
above measured behaviour has stopped bounding anything.

This Change Request's own promotion is the first push to `main` under the live Phase C Ruleset. The
required check is evaluated on the revision the branch will point to, and that revision earns its
`orvion-acceptance` run on `orvion-preflight` before promotion, which is the model working as designed.
Should the live Ruleset instead contradict that expectation, the instruction is to stop before
promotion and report rather than to widen this Change Request.

No real GitHub timeout is induced. Proving `cancelled → blocked` live would require deliberately
hanging the required admission boundary on a real ref; the chain is established by the Ruleset readback
taken during Phase C and by the existing `conclusion -ne 'success'` judgement in `-Certify`.
