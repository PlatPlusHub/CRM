# Change Request — SPEC-172

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make `orvion-acceptance` carry the guard-calibration evidence it is intended to replace, and make
every Supabase CLI invocation inside it — including the cleanup step that runs on failure — resolve
only from the repository lockfile.

## Business Reason

`orvion-acceptance` is the single external check a future Ruleset will require. Two measured defects
mean that requiring it today would make the repository weaker, not stronger.

**One: the failure path acquires tooling from outside the lockfile.** The cleanup step is
`npx supabase stop || true` under `if: always()`. A failed run reached cleanup before `npm ci` had
run; `npx` resolved `supabase` from the network, installed `2.117.0` against a lockfile that pins
`2.109.0`, and the step reported success. The version mismatch is the symptom. The defect is that a
path of the admission boundary installed software the repository did not choose, and said it was
fine. A boundary whose happy path obeys the lockfile and whose failure path does not is not a
boundary.

**Two: the acceptance job carries less evidence than the union it replaces.** `Repository
Consistency` has two layers: it runs `scripts/check_repository_consistency.ps1`, and then it attacks
the detectors themselves with `test_future_date_guard`, `test_status_contradiction_guard`,
`test_primary_ledger_guard` and `test_cold_start_state_guard`. Those four are not a second run of the
guard; they are the guard's calibration, added because a detector regression is invisible until it
produces a false verdict in front of someone — which is exactly what Check 12's local-timezone
ceiling did. `orvion-acceptance` runs the Gate, which invokes the consistency guard through
`Repo-Guard`, and runs none of the four. Measured on this tree: the string `test_future_date_guard`
does not occur in `.github/workflows/orvion-acceptance.yml`.

A third item is proof, not repair. Assertions 122, 123 and 124 pass today, but three of them passed
before the parser they claim to prove was repaired — they agreed with the broken code. `SPEC-171`
showed where that ends: assertion 129 asserted the defect and passed. Passing is not evidence that a
mechanism exists; being killed by a mutant of that mechanism is.

## Risks

Low, and the residual risk is on the side of failing closed.

Guarding the cleanup step makes teardown conditional: a stack started by a CLI that is later removed
would not be stopped. On a hosted runner the machine is destroyed after the job, so the cost is
bounded by that job. Leaving the guard out costs an unpinned install on every failed run.

Adding four suites to the acceptance job gives it four more ways to go red. That is the intent — the
legacy union already produces those failures, and the replacement must not be quieter than what it
replaces. They run after the Gate and before `npm ci` so the cheap evidence fails first.

The calibration list now exists in two workflows. That duplication is deliberate for the probation
period: legacy `Repository Consistency` stays as a comparator until equivalence is proven, and the
copy is removed when its retirement is earned, not before.

This Change Request does not modify `scripts/check_agent_continuity.ps1`, `package.json` or
`package-lock.json`. The pinned version is not the problem and is not changed; the workflow is made
to obey it.

## Supersedes / Depends On

Corrects the workflow introduced by `changes/SPEC-168-shadow-acceptance-workflow.md`, which is
`Complete` and terminal and is therefore not modified.

## Write Scope

- `changes/SPEC-172-acceptance-carries-the-evidence-it-replaces.md`
- `.github/workflows/orvion-acceptance.yml`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `package.json`
- `package-lock.json`
- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `changes/SPEC-168-shadow-acceptance-workflow.md`
- `changes/SPEC-171-a-cancellation-is-not-a-governing-act.md`
- `changes/TEMPLATE.md`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `GOVERNANCE.md`
- `supabase/migrations`

## Required Reading

- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
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

1. Check for `node_modules/.bin/supabase` in `.github/workflows/orvion-acceptance.yml`. If absent,
   replace every `npx supabase` invocation with that repository-local executable, and make the
   `if: always()` cleanup step invoke nothing at all when the executable does not exist — reporting
   that there is nothing safe to invoke, never resolving a package from the network. `npm ci` remains
   the only installation authority; no second version pin is introduced anywhere.
2. Check for `Attack the guards themselves` in `.github/workflows/orvion-acceptance.yml`. If absent,
   add one step running `test_future_date_guard`, `test_status_contradiction_guard`,
   `test_primary_ledger_guard` and `test_cold_start_state_guard`, each followed by its own exit-code
   check so an earlier failure cannot be hidden by a later success. Place it after the Gate step and
   before `npm ci`. Do not run `check_repository_consistency.ps1` again; the Gate already invokes it.
3. Check for `Assert '141` in `scripts/test_agent_continuity.ps1`. If absent, add structural
   assertions read from `.github/workflows/orvion-acceptance.yml` that fail if the workflow invokes
   `npx`, if its always-run cleanup is not guarded by an existence test on the repository-local
   executable, or if any of the four calibration suites is absent from it.
4. Mutate `Trigger-List` and `Workflow-Expectations` in a scratch copy of
   `scripts/check_agent_continuity.ps1` — never the committed script — once per claimed mechanism:
   block-style `branches:` parsing removed, the positive branch match forced to fail, and the `paths:`
   result ignored after a branch has matched. Record in the Execution Log which of assertions 122, 123
   and 124 each mutant kills. If an assertion survives the mutant of the mechanism it claims to prove,
   repair that assertion or its fixture in `scripts/test_agent_continuity.ps1` until it does not, and
   record the repair.
5. Check that `_ORVION_CANONICAL/manifest.md` names
   `changes/SPEC-172-acceptance-carries-the-evidence-it-replaces.md` as the Active Change Request. If
   it does not, set it, and regenerate `ai-map.json` with
   `pwsh -NoProfile -File scripts/generate-ai-map.ps1`.

## Acceptance Criteria

- [ ] `.github/workflows/orvion-acceptance.yml` contains no `npx` invocation.
- [ ] The always-run cleanup step performs no package resolution when `node_modules/.bin/supabase`
      does not exist.
- [ ] `orvion-acceptance` runs all four guard-calibration suites, each with its own exit-code check,
      after the Gate and before the toolchain install.
- [ ] `check_repository_consistency.ps1` is not invoked a second time by the acceptance workflow.
- [ ] Assertions 141 and later exist, and each fails when the property it names is removed from the
      workflow.
- [ ] Each of assertions 122, 123 and 124 is killed by a mutant of the specific mechanism it claims to
      prove, and that mapping is recorded in the Execution Log.
- [ ] `pwsh -NoProfile -File scripts/test_agent_continuity.ps1` passes with zero failures.
- [ ] `_ORVION_CANONICAL/manifest.md` names this Change Request as the Active Change Request while it
      is in progress, and `ai-map.json` is regenerated from the current tree.

## Execution Log

None.

## Verification Notes

None.

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

**Phase C stays forbidden.** This Change Request closes two of the three blockers and supplies the
proof for the third. It does not touch the `main integrity` Ruleset, which still carries only
`non_fast_forward` and `deletion` with zero bypass actors. The Ruleset changes only after a real
candidate SHA has passed the whole acceptance path.

**This candidate is the shadow proof.** The completed commit of this Change Request is intended to be
the first SHA pushed to `orvion-preflight` ahead of `main`, so that the acceptance workflow runs
against a non-empty candidate range. No artificial no-op candidate is created for that purpose.

**Deliberately not added.** No `supabase/setup-cli` action, no second version pin such as
`npx supabase@2.109.0`, no `npx` flag whose behaviour would have to be remembered rather than read,
no generic workflow-execution test framework, and no permanent mutation-testing framework. The
mutation proof required by Step 4 is a scratch copy and the existing suite.
