# Change Request — SPEC-183

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Stop the `Agent Control` workflow re-running the deterministic `scripts/test_agent_continuity.ps1` mutation suite on `orvion-preflight`, where `ORVION Acceptance` already runs that exact suite on the same candidate SHA, and mechanically fix that only that one step is suppressed.

## Business Reason

On a push to `orvion-preflight` two workflows execute the same script. `.github/workflows/agent-control.yml` runs `./scripts/test_agent_continuity.ps1` as its second step, and `.github/workflows/orvion-acceptance.yml` runs the identical `./scripts/test_agent_continuity.ps1` as its third. `ORVION Acceptance` triggers on `push: branches: [orvion-preflight]` and carries no `paths:` filter, so it always runs there; both therefore execute on every candidate.

The reason this particular duplication buys nothing is a property of the suite, not an argument about ranges. `scripts/test_agent_continuity.ps1` is invoked with no arguments and consumes no `BASE_SHA`, no `HEAD_SHA`, no `github.event` data and no range: it builds its own sandbox fixtures and asserts against the working tree it was checked out into. Two executions of it on one SHA read identical inputs and can only reach identical conclusions. That is what makes the second run redundant — a deterministic suite re-executed over unchanged state, which is precisely what EARN IT forbids paying for twice.

The Gate is a different object and is deliberately untouched. `Enforce governing Change Request` resolves `github.event.before -> github.sha`, which is a real push-range question that `ORVION Acceptance` does not ask — Acceptance resolves `origin/main -> candidate SHA`. Those two contexts can legitimately reach different conclusions, so no claim is made here that either range subsumes the other, and no trigger filter is added to this workflow. `Agent Control` keeps running on `orvion-preflight`; only its duplicate deterministic step stops.

The mechanical protection exists because nothing in this repository currently parses `.github/workflows/agent-control.yml` structurally. Assertion 152 bans a job-level condition on the admission job only — its condition is evaluated against the `orvion-acceptance` job body alone. A step-level condition introduced here is therefore unguarded on arrival: a later edit could widen it to the Gate step, or lift it to the job, and no assertion in the repository would notice. A conditional step added without a detector is the fail-open class this control plane keeps finding.

## Risks

Low, and the residual risk is named rather than assumed away.

- The condition is placed on one step, not the job and not the Gate. A job-level condition would skip the Gate with it, and GitHub reports a skipped job in a way that does not read as a failure. Assertion 163 refuses exactly that shape, in both newline representations.
- `github.ref` is `refs/pull/N/merge` on a `pull_request` event and `refs/tags/...` on a tag push, so neither matches the literal and pull-request, tag, `main` and every other branch keep their current behaviour unchanged. This is the one place a typo would silently remove coverage from the branch that matters most, which is why assertion 162 pins the literal exactly rather than merely checking that some condition is present.
- The suppressed step is a whole-suite execution, so if `ORVION Acceptance` were ever to stop running on `orvion-preflight`, the mutation suite would run nowhere on that ref. That workflow's trigger is unfiltered by design and assertion 151 already refuses a `paths:` filter on it; this contract adds no dependency on that fact beyond the one already asserted.
- Runner diversity narrows on this ref alone. `Agent Control` is `ubuntu-latest` and `ORVION Acceptance` is pinned `ubuntu-24.04`, so on `orvion-preflight` the suite stops executing on the unpinned image. It continues to execute on `ubuntu-latest` for every `main` push, every other branch and every pull request, which is where that diversity is actually consumed.
- No Ruleset, required check, trigger, permission or evidence class changes. The `CI` profile this Write Scope derives remains POST_PUSH evidence owned by `-Certify`, and is not asserted locally.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-183-preflight-skips-the-duplicate-mutation-suite.md`
- `.github/workflows/agent-control.yml`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/claude.yml`
- `.github/workflows/claude-code-review.yml`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/test_future_date_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/verify_database.sql`
- `changes/SPEC-169-agent-control-skips-the-preflight-ref.md`
- `changes/SPEC-172-acceptance-carries-the-evidence-it-replaces.md`
- `changes/TEMPLATE.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `supabase/migrations`
- `supabase/tests`

Also out of scope as SUBJECTS, not merely as files: GitHub Rulesets; the retirement of standalone `Repository Consistency`, which `SPEC-172` holds as a probation comparator until equivalence is proven; workflow concurrency, `cancel-in-progress`, caching, reusable workflows, selective or affected-test selection; any second source of truth for CI expectations; and any change to the `Enforce governing Change Request` Gate command or its range resolution.

## Required Reading

- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- `github`

## Additional Verification

None

## Implementation Steps

1. Verification check: `.github/workflows/agent-control.yml` contains the string `orvion-preflight`. If it matches, record Already Applied and skip. Otherwise insert exactly one line into that file, between the existing step header naming `Run Agent Control mutation suite` and its immediately following `shell: pwsh` line. The inserted line is indented by eight spaces and its content is exactly `if: ${{ github.ref != 'refs/heads/orvion-preflight' }}` with no trailing characters. Change nothing else in the file: `on:`, `push:`, `pull_request:`, `permissions:`, the `gate` job key, `runs-on:`, the `actions/checkout` step and its `fetch-depth:`, the `Resolve changed range` step and every line inside it, `BASE_SHA`, `HEAD_SHA`, the `Enforce governing Change Request` step and its `run:` command must all remain byte-identical. Do not add a `branches:`, `branches-ignore:`, `paths:` or `paths-ignore:` filter, do not add a job-level condition, and do not place a condition on any other step.

2. Verification check: `scripts/test_agent_continuity.ps1` contains the string `162 STRUCTURAL`. If it matches, record Already Applied and skip. Otherwise add exactly two assertions, numbered 162 and 163, inside the existing structural block that already builds `$reps`, immediately after assertion 155. They must consume the emitter collection that block already derived through `Get-WorkflowEmitters` for the LF and the CRLF representation, and must require their conditions of BOTH representations in the manner assertion 152 already establishes. Introduce no new file, module, class, dependency, YAML parser, package, framework, workflow or permanent utility script; do not read `.github/workflows` a second time; do not write fixture files to disk; and do not add, remove, renumber or alter the meaning of any assertion numbered 1 through 161.

   Assertion 162 must require, of each representation: exactly one emitter whose `File` is `agent-control.yml` and whose `Job` is `gate`; that this job body contains a step named `Run Agent Control mutation suite`; and that this step carries a step-level condition whose value is exactly `${{ github.ref != 'refs/heads/orvion-preflight' }}`.

   Assertion 163 must require, of each representation, of that same job: no job-level condition and no job-level `continue-on-error:`, matched at the job's own indentation in the manner of assertion 152; that the job contains a step named `Enforce governing Change Request`; and that the mutation-suite step is the ONLY step in the job carrying a step-level condition.

3. Verification check: none — this step is a proof obligation and is recorded in the Execution Log rather than detected in the tree. Before the candidate is accepted, kill both new assertions with causal mutants applied to a disposable copy only, never to authoritative history. For 162, require it to fail when the condition literal is altered (for example to another ref name, or to an equality test) and when the condition is removed entirely. For 163, require it to fail when the condition is moved to the job level, and when a step-level condition is added to the `Enforce governing Change Request` step. Each mutant must be accompanied by the unmutated control in the same run, so that a kill is attributable to the mutation rather than to the harness. Restore the candidate exactly afterwards and prove the restoration before concluding.

## Acceptance Criteria

- [ ] `.github/workflows/agent-control.yml` carries exactly one step-level condition, on the `Run Agent Control mutation suite` step, whose value is exactly `${{ github.ref != 'refs/heads/orvion-preflight' }}`.
- [ ] That file declares no `branches:`, `branches-ignore:`, `paths:` or `paths-ignore:` filter, no job-level condition and no `continue-on-error:`.
- [ ] That file's `on:`, `permissions:`, checkout step, `fetch-depth:`, `Resolve changed range` step, `BASE_SHA`, `HEAD_SHA`, and the `Enforce governing Change Request` step including its `run:` command are byte-identical to their state before this Change Request, the single added line excepted.
- [ ] `scripts/test_agent_continuity.ps1` declares assertions 162 and 163, and every assertion numbered 1 through 161 is unchanged in number, name and meaning.
- [ ] Assertions 162 and 163 evaluate against the emitter collection already derived by `Get-WorkflowEmitters` for both the LF and the CRLF representation, and no second workflow read, parser, fixture file, module or dependency was added.
- [ ] Assertion 162 fails when the condition literal is altered or removed, and assertion 163 fails when the condition is lifted to the job level or a second step gains one, each proven against an unmutated control in the same run and recorded in the Execution Log.
- [ ] No file under `.github/workflows/` other than `agent-control.yml` was created, modified or deleted, and no Ruleset, trigger, permission, concurrency, cache or reusable-workflow construct was introduced anywhere.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-15 — Claude Opus 5 (agent)

Outcome: Complete

Step results:

- Step 1: Applied — `.github/workflows/agent-control.yml` did not contain `orvion-preflight`. Exactly one line was inserted, indented eight spaces, between the `Run Agent Control mutation suite` step header and its `shell: pwsh` line. The diff against the base is one addition and zero deletions; triggers, `permissions:`, the `gate` job key, `runs-on:`, checkout, `fetch-depth:`, `Resolve changed range`, `BASE_SHA`, `HEAD_SHA` and the `Enforce governing Change Request` step with its `run:` command are untouched. No trigger filter and no job-level condition were added.
- Step 2: Applied — the suite did not contain `162 STRUCTURAL`. The existing `$reps` loop now also selects the `agent-control.yml` `gate` emitter from the SAME `Get-WorkflowEmitters` pass and splits its step list, and assertions 162 and 163 evaluate over both the LF and the CRLF representation. No new file, module, dependency, parser, fixture or second workflow read was introduced, and no assertion numbered 1 through 161 was added, removed, renumbered or altered. The suite's maximum assertion identifier moves 161 -> 163 with no duplicates.
- Step 3: Applied — proof obligation discharged below.

Mutation proof, run in a disposable sandbox against copies of the workflow directory; the repository was only read. The harness executes the CANDIDATE SOURCE VERBATIM — the region from `Get-WorkflowEmitters` through assertion 163 is sliced out of `scripts/test_agent_continuity.ps1` and executed, never reimplemented — so a kill is attributable to the shipped parser rather than to a restatement of it.

```text
case                              162   163   (150,151,152,153,155)
control (unmutated)               PASS  PASS  all PASS
M1 literal -> refs/heads/main     FAIL  PASS  all PASS
M2 condition removed              FAIL  FAIL  all PASS
M3 condition lifted to job level  FAIL  FAIL  all PASS
M4 Gate step gains a condition    PASS  FAIL  all PASS
restore (unmutated)               PASS  PASS  all PASS
```

M1 and M4 are the rows that matter, and they are mirrors: M1 kills 162 while 163 survives, so the ref literal is genuinely carried by 162; M4 kills 163 while 162 survives, so containment is genuinely carried by 163. Neither assertion is doing the other's work, and the two controls bracket the battery so a kill cannot be an artefact of the harness. M2 and M3 are the removal and job-lift cases Step 3 requires; both die on both assertions, which is correct — removing the condition defeats 162's literal and 163's exactly-one-conditioned-step count together.

The harness's own first run is recorded because it is the reason the result is trustworthy. M2 and M3 initially reported PASS/PASS: the mutator matched a condition line terminated by `LF` against a `CRLF` working copy, so those two mutants silently ran the UNMUTATED file. Nothing in the mutation itself said so — the expectation table did, by refusing a PASS where a kill was specified. The mutator was made newline-agnostic and the battery re-run; a harness that had merely reported "all mutants ran" would have certified two mutants that never existed. This is the same CRLF class `SPEC-177` closed inside the parser, reappearing in the tooling that attacks it.

EARN IT, on the evidence NOT re-run. This contract's two implementation files are byte-identical to the revision the battery above was executed against — proven by `git diff` over both paths reporting no difference, and by SHA256 over the worktree bytes. Because the bytes did not change, the causal conclusions cannot have changed either, so the four-mutant battery was not repeated to produce a second copy of the same report. What IS re-earned is everything keyed to this contract's own identity: a fresh `-Finish` under `SPEC-183`, never a reused receipt.

Numbering, measured rather than assumed: a baseline run of the unmodified suite on this tree reported `AGENT CONTROL TESTS: 161 passed, 0 failed`, and the structural block being edited ends at 155 while `SPEC-179` owns 156-157 and `SPEC-180` owns 158-161. 162 and 163 are the next free identifiers.

Commits: recorded by the implementation commit carrying this entry.

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

Why a step-level condition is safe here, confirmed by reading the workflow rather than assumed. The `gate` job's four steps are siblings in one job: checkout, `Resolve changed range`, the mutation suite, and `Enforce governing Change Request`. GitHub evaluates each step's condition independently, and a skipped step does not fail the job or prevent later steps from running, so suppressing the third cannot suppress the fourth. `BASE_SHA` and `HEAD_SHA` are written to `$GITHUB_ENV` by the second step, which is unconditional, so the Gate's inputs are unaffected by the skip. What makes this worth asserting rather than trusting is that the safety is a property of WHERE the condition sits, and nothing in the repository was previously watching that position in this file.

Expected remote shape on `orvion-preflight`, recorded here as a POST_PUSH expectation rather than a completion criterion: `Agent Control` runs with checkout, range resolution and the Gate executing and the mutation suite reported as skipped; `ORVION Acceptance` runs unchanged and in full, including the mutation suite, the candidate-range Gate, Repository Consistency through `Repo-Guard`, the four guard-calibration suites and the database path; `Repository Consistency` behaves exactly as it did before this contract.

Scope deliberately NOT taken. The same deduplication argument can be made about standalone `Repository Consistency` on this ref, and it is not made here. `SPEC-172` states the position directly — the calibration duplication "is deliberate for the probation period: legacy `Repository Consistency` stays as a comparator until equivalence is proven, and the copy is removed when its retirement is earned, not before." That retirement has not earned implementation authority, and `orvion-preflight` is the only ref where the two can be compared on one SHA, so suppressing it there would remove the comparison that the retirement is waiting on. It is a separate future decision with its own evidence.

Assertion numbering, measured rather than inferred. The structural block being edited ends at 155, but the suite does not: `SPEC-179` added 156 and 157 and `SPEC-180` added 158 through 161, and a baseline run of the unmodified suite on this tree reports 161 passed, 0 failed. Identifiers are also sparse — 90 and 134 through 140 are unused. The next free identifier is therefore the file's MAXIMUM plus one, never the assertion count and never the last number in whichever block is being edited.

Lineage note. This contract's work was first carried by an earlier local lineage that never reached `main`. That lineage authored a contract, cancelled it for the numbering error above, and authored a replacement — and the replacement's Write Scope did not list the cancelled contract's file, so the published range contained a write no governing contract authorised and both Gates correctly refused it with `OUT_OF_SCOPE_WRITE`. `SPEC-171` already records the rule that was broken: a cancellation is carried INSIDE the governing contract's Write Scope, which is how `SPEC-170` legally carried `SPEC-169`'s. The lineage is therefore rebuilt from `main` as this single contract, so the published range contains only writes this Write Scope authorises. The implementation bytes are the ones already proven by the mutation battery below; none of that evidence was re-derived, because none of those bytes changed.
