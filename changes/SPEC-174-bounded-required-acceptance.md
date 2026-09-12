# Change Request — SPEC-174

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[x] Cancelled

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

Resume Step: DONE
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

- [x] `.github/workflows/orvion-acceptance.yml` declares `timeout-minutes: 25` as a job-level key of
      the `acceptance` job, at the same indentation as `runs-on:`, not inside any step.
- [x] The workflow's step list is unchanged in count, order and content, and the runner family and
      the 40-character `actions/checkout` commit pin are byte-identical to their previous values.
- [x] `scripts/test_agent_continuity.ps1` contains an assertion 155 that fails when the admission job
      declares no job-level `timeout-minutes`.
- [x] Assertion 155 passes for any job-level timeout inside the accepted range and is not satisfied by
      a step-level key, proving it asserts the bound rather than the literal number 25.
- [x] Deleting the `timeout-minutes` line kills assertion 155 and changes the verdict of no other
      assertion.
- [x] `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` passes with zero failures.
- [x] Assertions 141 to 143 and 150 to 154 still exist and still pass.
- [x] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while it
      is in progress, and `ai-map.json` is regenerated from the current tree.

## Execution Log

### 2026-09-13 — Claude Opus 5 (agent execution run)

Outcome: Complete

PRECHECK — every step's verification check, before any edit:

```text
timeout-minutes in orvion-acceptance.yml   ABSENT   -> Step 1 applies
Assert '155 in test_agent_continuity.ps1   ABSENT   -> Step 2 applies
manifest names SPEC-174 as Active CR       PRESENT  -> Step 3 Already Applied
```

Step results:
- Step 1: Applied — job-level `timeout-minutes: 25` added beside `runs-on:` in the `acceptance` job,
  with the derivation recorded in comment. Step count, order and content unchanged; `ubuntu-24.04` and
  the `actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803` pin untouched.
- Step 2: Applied — assertion 155 parses the admission job body already extracted for 152 and 153 and
  requires a job-level `timeout-minutes:` whose integer value is 10 to 60 inclusive.
- Step 3: Already Applied — the manifest pointer and `ai-map.json` were set in the Approve commit,
  because the pre-commit hook refuses an `ORPHANED_APPROVED_CR`.

MEASUREMENT — every `ORVION Acceptance` run that exists, read live from GitHub:

```text
34715562635  c3d3c63  attempt 1  success  506 s  ubuntu-24.04 (frozen)
34705700442  18abbea  attempt 1  success  513 s  ubuntu-latest
34697041323  d0bba10  attempt 1  failure  148 s  ubuntu-latest (Gate failed fast, six steps skipped)
```

Per-step maxima across the two successful runs: mutation suite 175 s, guard attack 124 s, Supabase
start 120 s, db reset 37 s, pgTAP 27 s, stop 22 s, all others <= 5 s; composite 522 s. Largest relative
variance was Supabase start at +10.1 %, the registry-dependent step. Degraded envelope 1,416 s =
23.6 min; bound chosen 25.

MUTATION ANALYSIS — sequential, foreground, each bounded, workflow restored from a source copy before
each result was read:

```text
M1  delete the job-level timeout          154 passed / 1 failed   killed 155 only   328 s
M2  move the bound to STEP level          154 passed / 1 failed   killed 155 only   323 s
M3  MUST-ACCEPT retune 25 -> 20           155 passed / 0 failed   killed nothing    339 s
M4  out-of-range 600                      154 passed / 1 failed   killed 155 only   335 s
```

M3 is the assertion-design proof the owner required: the invariant is an explicit positive bounded
timeout inside an accepted range, not equality to 25, so retuning from later evidence is legal while
deletion, step-level relocation and an unbounding value are each refused. M2 matters because a
step-level key looks like a bound and leaves the JOB governed by GitHub's 360-minute default.

ENGINEERING OBSERVATIONS:

1. The fail-closed chain needed no new mechanism. A timeout cancels the job; `cancelled` is not
   `success`, so the Phase C Ruleset refuses the push and `-Certify` already reports FAILED through its
   existing `conclusion -ne 'success'` judgement, with pending handled separately as PENDING. This was
   verified by reading both paths rather than by inducing a timeout.
2. The accepted range's floor is load-bearing in the opposite direction from the ceiling. Below the
   slowest observed successful run a bound would reject healthy work, turning a safety device into an
   admission blocker; the guard refuses such a value rather than trusting a future editor's judgement.
3. `_ORVION_CANONICAL/manifest.md` had 6 characters of headroom against the 7,000-character Check 5
   budget. The stale `Next capability` line still described Phase C as a pending owner review, so
   correcting it to current state freed the room the Active CR pointer needed. The budget was not
   raised.

Commits: `20b70a4` (draft), `d1a4a56` (Approve), this commit (implementation).

### 2026-09-13 — Claude Opus 5 (owner-authorized cancellation)

Outcome: Failed

The entry above records what actually happened and remains true: the implementation was applied and
locally verified, and the implementation commit is `ce07859`. It is preserved rather than rewritten
because `Execution Log` is append-only, and because the work did occur legally under this contract's
authority. Nothing here was published — `origin/main` stayed at `c3d3c63` and nothing reached
`orvion-preflight`.

Cancellation reason: the owner changed the required timeout contract before publication. The approved
`SPEC-174` frozen authority encoded 25 minutes plus range-based assertion semantics that contradict the
new owner-approved exact-current-contract design. Frozen-authority enforcement correctly prevented
amendment. The implementation was never published to `origin/main` or `orvion-preflight`. A successor
Change Request will carry the corrected contract.

The amendment was refused by experiment, not by inspection: changing step 1's `25` to `30` in the
working tree and running the Gate produced `FROZEN_AUTHORITY_MUTATED:Implementation Steps`, and the
contract was then restored byte-for-byte. `CR_LIFECYCLE.md §4` admits no `Approved -> Draft` or
`In Progress -> Approved` transition, so no legal amendment path exists and a correction is made
through a new Change Request. Rewriting the three unpushed commits was considered and rejected by the
owner: retaining the identifier does not earn an exception to the no-history-rewrite discipline.

Adversarial note on why the owner's replacement is stronger, recorded because this contract's own
reasoning was wrong: a range guard treats a too-low bound as self-correcting on the theory that a false
timeout is visible. It is visible to a human, but a weaker agent setting `timeout-minutes: 5` keeps the
suite GREEN while making healthy candidates unadmittable. An exact expected value refuses both failure
directions and makes a retune an explicit, evidence-backed CR rather than a silent edit.

Blocker: contract superseded by an owner decision before publication. No verification check produced an
unanticipated result; the Gate behaved correctly throughout, and this Change Request is closed as
Cancelled rather than repaired.

## Verification Notes

### 2026-09-13 — Claude Opus 5 (review)

Verdict: Confirmed Complete

Findings: re-read the two changed files against the Implementation Steps. `.github/workflows/orvion-acceptance.yml`
gains exactly one functional line, `timeout-minutes: 25`, at four-space job-level indentation beside
`runs-on: ubuntu-24.04`; `git diff` reports insertions only, no deletions, in both files, so no step was
altered, reordered or removed and neither the runner family nor the checkout pin moved. Assertion 155
reuses the `$ab` job body already parsed for 152 and 153, so it cannot be satisfied by a step-level key.
The suite reports 155 passed, 0 failed; assertions 141 to 143 and 150 to 154 are all present and
passing. The four mutants each produced the intended verdict with zero collateral, including the
MUST-ACCEPT retune. No file outside Write Scope was touched, and the Phase C Ruleset was not modified.

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
