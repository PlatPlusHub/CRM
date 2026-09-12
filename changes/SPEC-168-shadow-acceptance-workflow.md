# Change Request — SPEC-168

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Add one deterministic acceptance workflow that proves an exact candidate SHA on the
`orvion-preflight` ref, and teach the expected-workflow deriver about branch filters so adding it
cannot break post-push certification.

## Business Reason

`main` currently accepts any push and CI runs afterwards. That is not a theoretical gap: the three
`SPEC-167` commits all landed on `main` before any check ran, and `SPEC-164` records a push that left
`main` red. The target model is that `main` never moves to a candidate revision until that exact
revision has already passed the required acceptance evidence, and the accepted SHA is the tested SHA.

This Change Request builds the evidence producer only. It creates no Ruleset change and no branch
protection, so `main`'s policy is untouched and the workflow can be proven in shadow first.

A prerequisite defect must be repaired in the same change, because it is a defect the moment the new
workflow exists and not before. `Workflow-Expectations` derives the EXPECTED workflow set from the
`push:` triggers the workflow files declare, and it treats every list item under `push:` as a path
glob — it has no concept of `branches:`. Measured against fixtures: a workflow declaring
`branches: [orvion-preflight]` in flow style is reported as expected on an ordinary `main` push, so
`-Certify` would wait forever for a run that can never happen and then fail closed on every future
push. In block style it is reported as not expected, but only because the branch name happens not to
match any written file path — correct by coincidence, which `ENGINEERING_METHOD.md §3` does not
accept as correct. Shipping the workflow without this repair either breaks the certification chain
or leaves it right by accident.

## Risks

Moderate, and contained to CI. No Ruleset, branch protection or `main` policy changes here, so the
worst outcome is a failing workflow on a non-default branch while `main` behaves exactly as today.

The real risks are two. First, over-strictness in the expectation deriver: narrowing it incorrectly
would stop a genuinely required workflow being expected, which is the exact blindness `SPEC-164`
closed — so the adversarial group asserts both directions, including that an unfiltered workflow
stays expected. Second, the lockfile-driven Supabase CLI is unproven on a hosted runner in this
repository; `migration-ci.yml` proves the stack starts there but does so through
`supabase/setup-cli`. If the lockfile approach cannot start the stack, the shadow run fails while
`main` remains protected by exactly the controls it has today, and the repair happens before any
Ruleset change.

Running database verification on every candidate is a deliberate cost, not an oversight
(plan §15): a changed-file classifier would add permanent classification rules, tests and
skipped-state semantics, and hosted compute is cheap for a public repository.

## Supersedes / Depends On

Depends on `changes/SPEC-167-range-integrity-over-committed-intermediate-states.md`, which closed the
range-integrity property this workflow's Gate invocation relies on.

## Write Scope

- `changes/SPEC-168-shadow-acceptance-workflow.md`
- `.github/workflows/orvion-acceptance.yml`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/claude.yml`
- `.github/workflows/claude-code-review.yml`
- `changes/SPEC-167-range-integrity-over-committed-intermediate-states.md`
- `changes/TEMPLATE.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `scripts/check_repository_consistency.ps1`
- `package.json`
- `package-lock.json`
- `supabase/migrations`

## Required Reading

- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `.github/workflows/agent-control.yml`
- `.github/workflows/migration-ci.yml`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

None

## Implementation Steps

1. Check for `Assert '121` in `scripts/test_agent_continuity.ps1`. If absent, add an adversarial
   group for branch-filtered trigger derivation, run it against the unmodified control script, and
   record in the Execution Log which cases already hold and which fail. Using workflow fixtures
   written into the sandbox and `Run Finish` to read the derived expected set from the certification
   receipt, assert that: a workflow whose `push:` declares `branches:` in FLOW style
   (`branches: [some-branch]`) naming a branch other than the checked-out one is NOT expected; the
   same in BLOCK style (`branches:` then `- some-branch`) is NOT expected; a workflow whose
   `branches:` names the checked-out branch IS expected; a workflow with `branches:` naming the
   checked-out branch AND a `paths:` filter that no written path matches is NOT expected; and the
   existing unfiltered and path-filtered behaviours are unchanged.
2. Check for `branchList` in `scripts/check_agent_continuity.ps1`. If absent, extend
   `Workflow-Expectations` so it reads `branches:` and `branches-ignore:` from inside the `push:`
   block, in both flow and block style, and treats a workflow as expected only when the checked-out
   branch satisfies that filter. Path filtering keeps its current meaning and is applied after the
   branch test. The function signature and return contract do not change, so no call site and no
   receipt field changes shape.
3. Check for `name: ORVION Acceptance` in `.github/workflows/orvion-acceptance.yml`. If the file does
   not exist, create it with exactly one job whose `name:` is `orvion-acceptance`, triggered only by
   `push:` with `branches:` naming `orvion-preflight`, with no `paths:`, no `paths-ignore:`, no
   `pull_request:` trigger, no `workflow_run:` chain and `permissions: contents: read`. Its steps, in
   order: check out with `fetch-depth: 0`; resolve `BASE_SHA` from `origin/main` and `HEAD_SHA` from
   the pushed SHA, failing closed unless `BASE_SHA` is an ancestor of `HEAD_SHA`; run
   `scripts/test_agent_continuity.ps1`; run `scripts/check_agent_continuity.ps1 -Gate` over
   `BASE_SHA..HEAD_SHA`; then `npm ci`, `npx supabase start`, `npx supabase db reset`,
   `npx supabase test db`, the `scripts/verify_database.sql` smoke test, and a stop step guarded by
   `if: always()`. The Supabase CLI version comes from `package-lock.json` via `npm ci`, never from
   `supabase/setup-cli`.
4. Check whether the remote ref `orvion-preflight` exists with
   `git ls-remote --heads origin orvion-preflight`. If it does not, create it pointing at exactly the
   current `origin/main` commit, and record that SHA in the Execution Log. Do not force, do not push
   any other ref, and do not modify `main`.
5. Check that `_ORVION_CANONICAL/manifest.md` names `changes/SPEC-168-shadow-acceptance-workflow.md`
   as the Active Change Request. If it does not, set it, and regenerate `ai-map.json` with
   `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [x] `scripts/test_agent_continuity.ps1` contains an adversarial group covering all five branch
      filter cases named in Step 1, and the whole suite passes.
- [x] A workflow whose `push:` declares `branches:` in flow style naming a branch other than the
      checked-out one is absent from the derived expected set.
- [x] The same declaration in block style is absent from the derived expected set.
- [x] A workflow whose `branches:` names the checked-out branch is present in the derived expected
      set, and adding a non-matching `paths:` filter removes it again.
- [x] An unfiltered `push:` workflow is still expected and a non-matching path-filtered one is still
      not, unchanged from before this Change Request.
- [x] `.github/workflows/orvion-acceptance.yml` exists, declares exactly one job named
      `orvion-acceptance`, triggers only on `push:` to `orvion-preflight`, and contains no `paths:`,
      no `paths-ignore:`, no `pull_request:` and no `workflow_run:` key.
- [x] That workflow derives its base from `origin/main` and fails closed when the base is not an
      ancestor of the pushed SHA.
- [x] That workflow obtains the Supabase CLI through `npm ci` and `npx`, and contains no reference to
      `supabase/setup-cli`.
- [x] The remote ref `orvion-preflight` exists and `main` is unchanged by this Change Request.
- [x] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while it
      is in progress, and `ai-map.json` is regenerated from the current tree.

## Execution Log
### 2026-09-12 — Claude Opus 5 (agent execution run)

Outcome: Complete

Step results:
- Step 1: Applied — adversarial group added as assertions 121–125, with four branch-filtered
  workflow fixtures added to the sandbox baseline beside the existing trigger fixtures.
- Step 2: Applied — `Trigger-List` added and `Workflow-Expectations` now settles branch filters
  before path filters.
- Step 3: Applied — `.github/workflows/orvion-acceptance.yml` created.
- Step 4: Applied — `git ls-remote --heads origin orvion-preflight` returned empty, so the ref was
  created at exactly `e99324ee2423f5dd6640d655eef34687b906a716`, the then-current `origin/main`.
  `main` was re-read afterwards and was unchanged at that same SHA.
- Step 5: Applied — manifest pointer set; `ai-map.json` regenerated.

PRECHECK, against the unmodified deriver. This is the honest result and it is more interesting than
a clean sweep of failures:

| Assertion | Before | Why |
| --- | --- | --- |
| 121 flow-style other branch | **FAIL** | inline `[release]` yields no `- item` lines, so the workflow read as UNFILTERED and was expected on every push |
| 122 block-style other branch | pass, vacuously | `- release` was read as a PATH glob; no written path looks like `release`, so it fell out by coincidence |
| 123 matching branch expected | pass, vacuously | expected because it read as unfiltered, not because the branch matched |
| 124 matching branch, non-matching paths | pass, vacuously | the `paths:` bullets were read; the branch filter played no part |
| 125 unfiltered / path-filtered unchanged | pass | genuine — this is the regression guard |

Only 121 was a live failure; 122–124 asserted the right outcomes for the wrong reasons, which
`ENGINEERING_METHOD.md §3` treats as unproven rather than passing. They are retained because after
the repair they hold for the right reason, and they are what would catch a future reader that
re-collapses branch and path handling.

Suite: 131 passed / 1 failed before the repair, 132 passed / 0 failed after. Assertions 109 and 110,
which pin the pre-existing path-based derivation, remain green — that is the over-strictness guard,
since narrowing the deriver incorrectly would re-open the `SPEC-164` blindness.

Engineering Observations:

1. **The dual Supabase CLI authority recorded by `SPEC-167` is retired for the acceptance path, not
   repaired in place.** `orvion-acceptance.yml` takes the CLI from `package-lock.json` through
   `npm ci`, so the lockfile is the single version authority for this workflow.
   `.github/workflows/migration-ci.yml` still pins `2.109.1` through `supabase/setup-cli@v3` against
   the lockfile's `2.109.0`; it is out of scope here and is a candidate for deletion in the
   simplification phase once this gate has proven itself, which is the cheaper resolution than
   editing a file that may not survive.
2. **The `orvion-acceptance` check has not yet been observed.** That is POST_PUSH evidence by
   `CR_LIFECYCLE.md` §8 and is deliberately absent from the Acceptance Criteria. It is proven after
   this Change Request publishes, and it gates the Phase C Ruleset cutover rather than this
   completion.

Commits: recorded by the Complete commit that carries this entry.

## Verification Notes

### 2026-09-12 — Claude Opus 5 (review)

Verdict: Confirmed Complete

Findings: every Acceptance Criterion was re-checked against the live tree and the live remote rather
than against the Execution Log's self-report.

- `.github/workflows/orvion-acceptance.yml` declares one job, `acceptance`, whose `name:` is
  `orvion-acceptance` — that name, not the job id, is the external check context a Ruleset will
  require. Its only trigger is `push:` with `branches:` naming `orvion-preflight`. A negative grep
  for `paths:`, `paths-ignore:`, `pull_request:` and `workflow_run:` returned nothing, which is the
  criterion stated as a forbidden-key search rather than an eyeball read.
- The base is `git rev-parse origin/main`, not `github.event.before`, and
  `git merge-base --is-ancestor` gates the run with an explicit `MAIN_NOT_ANCESTOR` throw. A
  divergent candidate therefore fails closed rather than being reinterpreted through a merge-base
  range that nobody would push.
- The workflow contains zero occurrences of `setup-cli`; the CLI arrives via `npm ci` and every
  Supabase invocation is `npx supabase`. The lockfile is the single version authority for this path.
- `git ls-remote` shows `refs/heads/orvion-preflight` and `refs/heads/main` at the identical SHA
  `e99324ee2423f5dd6640d655eef34687b906a716`, which is both the steady-state invariant the design
  requires and proof that creating the ref did not move `main`.
- The suite is 132 passed / 0 failed. Assertions 109 and 110 remain green, which is the check that
  matters most here: the deriver was narrowed, and narrowing it too far would re-open the `SPEC-164`
  blindness rather than close anything.
- The PRECHECK distinction is recorded honestly in the Execution Log: only assertion 121 failed
  before the repair, and 122 through 124 passed for reasons unrelated to the property they name.
  Three vacuous passes were reported as vacuous rather than counted as coverage.

No discrepancy found. Scope was not widened: `migration-ci.yml` still carries the competing
`setup-cli` pin and was left untouched.

Recommendation to human: Set Status to Complete

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

**Evidence classes.** Every Acceptance Criterion above asserts LOCAL evidence, per `CR_LIFECYCLE.md`
§8. The shadow proof this workflow exists for — that `orvion-acceptance` actually appears against an
exact SHA, succeeds, and is emitted by the GitHub Actions App — is POST_PUSH evidence and is
deliberately not a completion checkbox, because the commit that produces that SHA does not exist
while the boxes are being ticked. It is observed after the push and it gates the Phase C Ruleset
cutover, not this Change Request's completion.

**Why the expectation repair belongs here.** It has no independent purpose. No workflow in the
repository uses `branches:` today, so shipping the repair alone would be machinery for a need that
does not yet exist; shipping the workflow alone would break or accidentally satisfy the `SPEC-164`
certification chain. The smallest safe scope is both together.

**Deliberately excluded.** No Ruleset change, no required status check, no branch protection, no
deletion of the existing workflows, no Action SHA pinning, and no changed-file classifier for the
database steps. Each belongs to a later phase of the Simple Acceptance programme and earns itself
separately. `package-lock.json` is out of scope: the Supabase CLI version is read from it, never
changed by this work, which is the point of making the lockfile the single version authority.
