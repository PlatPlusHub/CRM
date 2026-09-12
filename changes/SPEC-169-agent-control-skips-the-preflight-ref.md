# Change Request — SPEC-169

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Stop `Agent Control` triggering on the `orvion-preflight` ref, where it fails on branch creation and
otherwise re-runs a Gate that `orvion-acceptance` already runs over a stricter range.

## Business Reason

`Agent Control` declares an unfiltered `push:` trigger, so creating `orvion-preflight` immediately
produced a failing run: on a branch-creation event `github.event.before` is all zeros, the workflow
resolves that as `BASE_SHA`, and the Gate rejects it as an invalid ref. Observed, not predicted —
run `34696395223` on `e99324e` concluded `failure` for exactly this reason.

On every later candidate push it runs a second time and proves less than the check beside it. Its
range is `github.event.before..HEAD`, which is only what that push added to the branch;
`orvion-acceptance` uses `origin/main..HEAD`, which is every commit not yet in `main`. Two runs, two
different ranges, one of them weaker, both green-or-red on the same commit — and the weaker one is
the one that fails spuriously.

A workflow that is permanently red for a structural reason is worse than no workflow, because it
teaches every future reader and agent that red is normal. That is the defect being closed.

## Risks

Low, and the smallest change available. `Agent Control` keeps its exact current behaviour on `main`
and on pull requests; only the `orvion-preflight` ref is excluded, and that ref is covered more
strictly by `orvion-acceptance`, which runs the same mutation suite and the same Gate over a
superset range.

The one real risk is a typo in the trigger silently excluding more than intended — a `branches-ignore`
that accidentally matched `main` would remove Gate coverage from the branch that matters most. The
acceptance criteria therefore assert `main` is still covered rather than only asserting that
`orvion-preflight` is not, and `SPEC-168` added the adversarial coverage that makes
`branches-ignore` parsing itself a tested property rather than an assumption.

This Change Request is also the first real candidate pushed through `orvion-preflight` before
reaching `main`, which is the shadow proof `main`'s Ruleset change depends on. It changes no Ruleset
and adds no required check.

## Supersedes / Depends On

Depends on `changes/SPEC-168-shadow-acceptance-workflow.md`, which created the `orvion-preflight`
ref, the `orvion-acceptance` workflow, and the `branches-ignore` parsing this contract relies on.

## Write Scope

- `changes/SPEC-169-agent-control-skips-the-preflight-ref.md`
- `.github/workflows/agent-control.yml`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/claude.yml`
- `.github/workflows/claude-code-review.yml`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `changes/SPEC-168-shadow-acceptance-workflow.md`
- `changes/TEMPLATE.md`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `GOVERNANCE.md`
- `supabase/migrations`

## Required Reading

- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

None

## Implementation Steps

1. Check for `branches-ignore` in `.github/workflows/agent-control.yml`. If absent, add a
   `branches-ignore:` list under the existing `push:` trigger naming exactly `orvion-preflight`, in
   block style, one entry. Do not add a `branches:` list, do not add or change any `paths:` filter,
   do not alter the `pull_request:` trigger, and do not change any job, step or permission in that
   file.
2. Check that `_ORVION_CANONICAL/manifest.md` names
   `changes/SPEC-169-agent-control-skips-the-preflight-ref.md` as the Active Change Request. If it
   does not, set it, and regenerate `ai-map.json` with
   `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [ ] `.github/workflows/agent-control.yml` declares `branches-ignore:` under `push:` with exactly
      one entry, `orvion-preflight`.
- [ ] That file declares no `branches:` list and no `paths:` or `paths-ignore:` filter, so `main`
      and every other ref remain covered.
- [ ] That file's `pull_request:` trigger, jobs, steps and `permissions:` are byte-identical to their
      state before this Change Request apart from the added trigger lines.
- [ ] `Agent Control` is still present in the derived expected workflow set for a push on `main`,
      proven by the certification receipt written by `-Finish`.
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

**This contract is deliberately also the shadow-proof candidate.** `SPEC-168` proved that
`orvion-acceptance` appears, resolves its range from `origin/main`, runs the mutation suite on a
hosted runner and fails closed on an inadmissible candidate — but the candidate it was given was
`main`'s own SHA, so the range was empty, the Gate correctly reported `NO_GOVERNING_CR`, and every
database step was skipped. The success path and the lockfile-driven Supabase CLI are therefore still
unproven on a runner.

This Change Request's commits are published to `orvion-preflight` FIRST and promoted to `main` only
after `orvion-acceptance` succeeds on that exact SHA. That is the target operating model executed by
hand, before any Ruleset requires it and while `main` still accepts an ordinary push — so a failure
costs a repair rather than a blocked branch.

**Not a substitute for deleting the duplication.** Excluding one ref is the smallest change that
stops the bleeding; whether `Agent Control` should continue to exist alongside `orvion-acceptance` at
all is a question for the simplification phase, once the acceptance gate has earned the trust to
replace it. Adding a trigger filter now does not prejudge that.
