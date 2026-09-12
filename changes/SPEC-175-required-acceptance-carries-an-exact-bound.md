# Change Request — SPEC-175

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
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

Resume Step: DONE
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

- [x] `.github/workflows/orvion-acceptance.yml` declares exactly one job-level `timeout-minutes: 30` on
      the `acceptance` job, at the same indentation as `runs-on:`, and no `timeout-minutes: 25` remains.
- [x] No `timeout-minutes` key appears at step level in the acceptance workflow.
- [x] The workflow's step list is unchanged in count, order and content, and the runner family and the
      40-character `actions/checkout` commit pin are byte-identical to their previous values.
- [x] The workflow comment states the current measured bound and that retuning requires fresh evidence,
      and does not reproduce the per-step timing analysis.
- [x] `scripts/test_agent_continuity.ps1` contains an assertion 155 that fails when the admission job
      declares no job-level `timeout-minutes`, when the key is present only at step level, when the
      value is below the approved value, and when it is above the approved value.
- [x] Each of those four conditions is proven by an independent mutant that kills assertion 155 and
      changes the verdict of no other assertion.
- [x] `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` passes with zero failures.
- [x] Assertions 141 to 143 and 150 to 154 still exist and still pass.
- [x] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while it is
      in progress, and `ai-map.json` is regenerated from the current tree.

## Execution Log

### 2026-09-13 — Claude Opus 5 (agent execution run)

Outcome: Complete

PRECHECK — every step's verification check, before any edit:

```text
timeout-minutes: 30 in orvion-acceptance.yml   ABSENT (25 present from the cancelled lineage)
Assert '155 in test_agent_continuity.ps1       PRESENT with range semantics, rewritten by Step 2
manifest names SPEC-175 as Active CR           PRESENT  -> Step 3 Already Applied
```

Step results:
- Step 1: Applied — the job-level key became `timeout-minutes: 30`, exactly one, at four-space
  indentation beside `runs-on: ubuntu-24.04`. Its comment was cut from fifteen lines to seven, keeping
  the current bound, the fail-closed chain and the retuning rule while the per-step timing analysis stays
  in this contract. Step count, order and content unchanged; `ubuntu-24.04` and
  `actions/checkout@d23441a48e516b6c34aea4fa41551a30e30af803` untouched.
- Step 2: Applied — assertion 155 now COUNTS job-level `timeout-minutes` keys in the admission job body
  and requires exactly one whose value is exactly 30. Counting rather than matching the first occurrence
  also refuses a second contradicting job-level key.
- Step 3: Already Applied — the manifest pointer and `ai-map.json` were set in the Approve commit,
  because the pre-commit hook refuses an `ORPHANED_APPROVED_CR`.

MEASUREMENT — every `ORVION Acceptance` run that exists, read live from GitHub:

```text
34715562635  c3d3c63  attempt 1  success  506 s  ubuntu-24.04 (frozen)
34705700442  18abbea  attempt 1  success  513 s  ubuntu-latest
34697041323  d0bba10  attempt 1  failure  148 s  ubuntu-latest (Gate failed fast, six steps skipped)
```

Per-step maxima across the two successful runs: mutation suite 175 s, guard attack 124 s, Supabase start
120 s, db reset 37 s, pgTAP 27 s, stop 22 s, all others <= 5 s; composite 522 s. Largest relative
variance was Supabase start at +10.1 %, the registry-dependent step. Degraded envelope 1,416 s =
23.6 min. The approved bound of 30 leaves 6.4 minutes above that envelope and is 3.5x the slowest run
observed.

MUTATION ANALYSIS — sequential, foreground, each bounded, the workflow restored from a source copy
before each result was read:

```text
M1  delete the job-level timeout     154 passed / 1 failed   killed 155 only   314 s
M2  move the bound to STEP level     154 passed / 1 failed   killed 155 only   350 s
M3  30 -> 5                          154 passed / 1 failed   killed 155 only   350 s
M4  30 -> 600                        154 passed / 1 failed   killed 155 only   314 s
```

Both failure directions are now refused, which is the whole reason this contract replaced the cancelled
one. M3 is the decisive case: under the range semantics `SPEC-174` had approved, lowering the bound to 5
would have kept the suite GREEN while making every healthy candidate unadmittable. M2 matters because a
step-level key looks like a bound and leaves the JOB governed by GitHub's 360-minute default.

ENGINEERING OBSERVATIONS:

1. The fail-closed chain needed no new mechanism. A timeout cancels the job; `cancelled` is not
   `success`, so the Phase C Ruleset refuses the push and `-Certify` already reports FAILED through its
   existing `conclusion -ne 'success'` judgement, with a pending run handled separately as PENDING. Both
   paths were verified by reading them rather than by inducing a timeout on the live boundary.
2. A range guard is not a weaker version of an exact guard; it is a guard that answers a different
   question. It asks "is a bound present and not absurd", while the property actually needed is "is the
   bound the one that was approved". Only the second refuses the direction that keeps the suite green.
3. `_ORVION_CANONICAL/manifest.md` cleared to 11 characters of headroom against the 7,000-character
   Check 5 budget once this contract's long filename entered the Active pointer. The budget was not
   raised; the cancellation commit had already trimmed the stale narrative that made room.

Commits: `92b66fe` (draft), `c859fd6` (Approve), this commit (implementation). The corrected
implementation replaces the one made under the cancelled `SPEC-174` at `ce07859`, which is preserved in
history rather than rewritten.

## Verification Notes

### 2026-09-13 — Claude Opus 5 (review)

Verdict: Confirmed Complete

Findings: independently re-read both changed files against the Implementation Steps.
`.github/workflows/orvion-acceptance.yml` contains exactly one `timeout-minutes` occurrence, at line 37,
four-space job-level indentation, value 30; no step-level occurrence exists and no `25` remains. `git diff`
against the implementation of the cancelled lineage shows the workflow's step list untouched and the
runner family and checkout pin byte-identical. Assertion 155 reuses the `$ab` job body already parsed for
152 and 153, so a step-level key cannot satisfy it, and it counts matches so a duplicate job-level key
cannot either. The unmutated suite reports 155 passed, 0 failed; assertions 141 to 143 and 150 to 154 are
present and passing. Four independent mutants each produced 154 passed / 1 failed killing only 155, with
the workflow restored exactly after each. No file outside Write Scope was modified, and the Phase C
Ruleset was not touched.

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
