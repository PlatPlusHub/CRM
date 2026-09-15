# Change Request — SPEC-185

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Stop re-executing on a `main` push the deterministic evidence that Ruleset 22950574 already required on that exact SHA before the push was allowed.

## Business Reason

A commit can only reach `main` by carrying a successful `orvion-acceptance` check run on that exact SHA. This is read from the live ruleset, not assumed: ruleset `22950574` ("main integrity") is `active` on `~DEFAULT_BRANCH` with an empty exclude list, `bypass_actors` is empty, and its `required_status_checks` rule names the single context `orvion-acceptance` bound to integration `15368` with `do_not_enforce_on_create: false`. A check run binds to a commit, not to a branch, so the evidence required at the `main` push is evidence about that commit's content. `ORVION Acceptance` is the workflow that produces that context, and it runs the Agent Control mutation suite and all four guard-calibration suites before it can conclude successfully.

Two workflows then execute that same evidence again, on the same SHA, after admission has already been decided. Both costs are measured from the step timings of the real `main` runs on `a2957f1`, not estimated:

| step | measured |
| --- | --- |
| `Agent Control` — Run Agent Control mutation suite | 194s |
| `Agent Control` — Enforce governing Change Request | 5s |
| `Repository Consistency` — Attack the guards themselves | 84s |
| `Repository Consistency` — Run repository consistency guard | 3s |

The two duplicated steps are 278 of the roughly 289 seconds of real work those two workflows perform on a `main` push. What remains after this change is the evidence that is NOT duplicated: the Agent Control Gate, which resolves `github.event.before -> github.sha` and asks a push-range question Acceptance never asks, and the repository consistency guard itself, which `SPEC-172` holds as a probation comparator.

The suppression is deliberately narrow. The mutation suite is a whole-suite execution taking no range, SHA or event input, which is what made its preflight duplicate removable under `SPEC-183`; the same property makes its `main` duplicate removable, and the ruleset is what supplies the "already proven on this SHA" premise that preflight got from the concurrent Acceptance run. Calibration on `main` is the weaker case of the two and is removed only there: on a pull request Acceptance never runs, so calibration is the only calibration; on `orvion-preflight` both run on one SHA, which is the only place the comparator `SPEC-172` preserves can actually compare anything. On `main`, `ORVION Acceptance` does not run at all, so nothing is being compared and the calibration is purely a repeat.

## Risks

Low, and the residual risk is named rather than assumed away.

- The entire premise is the ruleset. If `orvion-acceptance` ever stops being required on `main`, or a bypass actor is added, a `main` push could carry no acceptance evidence and this change would remove real assurance. That is a Ruleset change, which is out of scope here and is governed separately; it is recorded as the explicit dependency of this contract rather than hidden in it.
- A pull request must not be caught by either condition. `github.ref` is `refs/pull/N/merge` on a `pull_request` event, so a comparison against `refs/heads/...` cannot match it. This is why both assertions pin the exact literal rather than merely checking that some condition exists: a condition that looks deliberate and matches the wrong refs is the failure mode.
- Suppressing a step is invisible in a green run. Both suppressions are therefore fixed by structural assertions, and `agent-control.yml` already has 162 and 163 watching exactly this position.
- This narrows what runs on `main` but changes nothing about what must be true before `main` moves. No Ruleset, required check, trigger, permission, range check, frozen-authority check, terminal-history check or scope enforcement is touched, and every fail-closed path is unchanged.

## Supersedes / Depends On

None. This extends the mechanism `SPEC-183` introduced in `.github/workflows/agent-control.yml` and relies on the admission boundary `SPEC-172`, `SPEC-173` and `SPEC-174` established; none of those contracts is modified.

## Write Scope

- `changes/SPEC-185-the-control-plane-stops-reproving-accepted-shas.md`
- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `scripts/test_agent_continuity.ps1`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/claude.yml`
- `.github/workflows/claude-code-review.yml`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/test_future_date_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `changes/TEMPLATE.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md`
- `supabase/migrations`
- `supabase/tests`

Also out of scope as SUBJECTS, not merely as files: GitHub Rulesets, including any change to what `main` requires; removal of any guard-calibration suite from `ORVION Acceptance`; retirement of the `Repository Consistency` workflow or of `scripts/check_repository_consistency.ps1`; any change to `-Finish`, `-Gate`, `-Certify` or Publisher; branch-classification machinery, test-selection systems, caching, concurrency policy and reusable workflows; and any new mutation framework, helper system or test harness kept in the repository.

## Required Reading

- `.github/workflows/agent-control.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/orvion-acceptance.yml`
- `scripts/test_agent_continuity.ps1`

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Implementation Steps

1. Verification check: `.github/workflows/agent-control.yml` contains the string `refs/heads/main`. If it matches, record Already Applied and skip. Otherwise change ONLY the existing step-level condition on the `Run Agent Control mutation suite` step so that its value is exactly `${{ github.ref != 'refs/heads/orvion-preflight' && github.ref != 'refs/heads/main' }}`. Change nothing else in that file: triggers, `permissions:`, the `gate` job key, `runs-on:`, the checkout step and its `fetch-depth:`, the `Resolve changed range` step and every line inside it, `BASE_SHA`, `HEAD_SHA`, and the `Enforce governing Change Request` step with its `run:` command must remain byte-identical. Do not add any trigger filter, do not add a job-level condition, and do not place a condition on any other step.

2. Verification check: `.github/workflows/repository-consistency.yml` contains the string `refs/heads/main`. If it matches, record Already Applied and skip. Otherwise add exactly one step-level condition, on the `Attack the guards themselves` step only, whose value is exactly `${{ github.ref != 'refs/heads/main' }}`. Change nothing else in that file: both trigger blocks and every entry in both `paths:` lists, the `consistency` job key, `runs-on:`, the checkout step and its `fetch-depth: 0`, and the `Run repository consistency guard` step including its `run:` command must remain byte-identical. Do not add a job-level condition, do not add or remove any path entry, and do not alter the four suites named inside the calibration loop.

3. Verification check: `scripts/test_agent_continuity.ps1` contains the string `167 STRUCTURAL`. If it matches, record Already Applied and skip. Otherwise make exactly two changes to that file, adding no new file, fixture, stub, helper module or framework, and touching no assertion other than the one named:

   - Update assertion 162's pinned condition value to the new literal from Step 1, keeping its number, name and meaning — it continues to prove that the mutation-suite step carries exactly the approved condition and no other. Assertion 163 is NOT modified: it already proves that this remains the only conditioned step in that job and that the job carries no job-level condition or `continue-on-error:`.
   - Add exactly one assertion, numbered 167, proving of `.github/workflows/repository-consistency.yml`, in both the LF and the CRLF representation already derived by the existing `Get-WorkflowEmitters` pass: that exactly one emitter comes from that file; that its `Attack the guards themselves` step carries a step-level condition whose value is exactly the literal from Step 2; that its `Run repository consistency guard` step carries no condition; that the calibration step is the only conditioned step in that job; and that the job carries no job-level condition and no `continue-on-error:`.

   Do not add an assertion that `ORVION Acceptance` still runs the four calibration suites: assertion 142 already proves exactly that, with its own exit check, and duplicating it would add a second owner for one fact.

4. Verification check: none — this step is a proof obligation recorded in the Execution Log rather than detected in the tree. Kill assertion 162 and assertion 167 with the smallest faithful mutants of the SHIPPED source, run against ONE known-green baseline and paired with the unmutated control in the same run: for 162, a condition naming a different ref; for 167, moving the calibration condition onto the consistency-guard step. Restore exactly and prove the restoration by hash. Do NOT repeat the four-clone, full-suite battery pattern: a targeted execution of the shipped structural block against mutated workflow copies is a faithful surface and is sufficient here.

5. Verification check: `_ORVION_CANONICAL/manifest.md` contains the string `Batch 6 Slice 12` on its `Next capability:` line. If it matches, record Already Applied and skip. Otherwise replace the stale `Next capability:` line, which still names ad-hoc process safety and Publisher although both are complete, so that it returns the plan to the canonical Batch-6 selector and records that the control-plane optimization chapter is CLOSED, with reopening requiring newly earned evidence. Do not raise the manifest budget; trim elsewhere in that line if needed.

## Acceptance Criteria

- [ ] `.github/workflows/agent-control.yml` carries exactly one step-level condition, on the `Run Agent Control mutation suite` step, whose value is exactly `${{ github.ref != 'refs/heads/orvion-preflight' && github.ref != 'refs/heads/main' }}`.
- [ ] `.github/workflows/repository-consistency.yml` carries exactly one step-level condition, on the `Attack the guards themselves` step, whose value is exactly `${{ github.ref != 'refs/heads/main' }}`, and its `Run repository consistency guard` step carries none.
- [ ] Neither workflow declares a job-level condition or `continue-on-error:`, and neither gained or lost a trigger, a `paths:` entry, a permission or a step.
- [ ] Both conditions compare `github.ref` only against `refs/heads/...` values, so a `pull_request` event, whose ref is `refs/pull/N/merge`, matches neither and pull-request behaviour is unchanged.
- [ ] The four guard-calibration suites remain named inside the `Repository Consistency` calibration loop and inside `.github/workflows/orvion-acceptance.yml`, and `scripts/check_repository_consistency.ps1` is still executed unconditionally by the `Run repository consistency guard` step.
- [ ] `scripts/test_agent_continuity.ps1` declares assertion 167, assertion 162 pins the new literal, and every other assertion numbered 1 through 166 is unchanged in number, name and meaning.
- [ ] Assertion 162 fails when its condition names a different ref, and assertion 167 fails when the calibration condition is moved onto the consistency-guard step, each proven against an unmutated control in the same run and recorded in the Execution Log.
- [ ] `_ORVION_CANONICAL/manifest.md` no longer names ad-hoc process safety or Publisher as the next capability, names the canonical Batch-6 selector instead, and remains within its existing budget.
- [ ] No file outside Write Scope was created, modified or deleted, and no Ruleset was changed.

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

**Target C — NO CHANGE, NOT EARNED, and the reason is recorded so it is not re-investigated.** A duplicate execution inside one `-Finish` does exist and is visible in `SPEC-184`'s own Finish output: the run prints `REPOSITORY: clean`, which is `Repo-Guard` executing `scripts/check_repository_consistency.ps1`, and then `PASS: pwsh -NoProfile -File scripts/check_repository_consistency.ps1`, which is the always-derived `REPOSITORY` profile executing the same script again over the same tree in the same process. The literal trigger for a Target C change is therefore met.

It is not implemented because removal cannot preserve identical semantics, which is the other half of the condition. The two invocations have different owners: `Repo-Guard` is the Gate's own precondition, reached on every mode, and it throws `REPOSITORY_CONSISTENCY_FAILED` early — before the Agent Control suite's ~194 seconds — so removing it would convert a fast fail into a slow one. The profile command is what makes `LOCAL_CERTIFY` an honest statement about the `REPOSITORY` profile; removing it instead would leave the receipt asserting evidence produced by a mechanism it does not name, so a later change to `Repo-Guard` would silently change what certification means. Deduplicating them requires coupling the Gate's precondition to the receipt's meaning, which adds a special case and a shared authority to save one local execution. The existing dedup in `Finish-Checks` is deliberately scoped to commands across profiles and against Additional Verification, and this is outside that scope by construction rather than by oversight.

**What was deliberately not done.** No branch-classification machinery was invented to preserve redundancy: both suppressions are a single literal comparison in the place the repository already uses for this, and the `pull_request` case is handled by GitHub's own ref shape rather than by classification. Calibration is not removed from `ORVION Acceptance`, the `Repository Consistency` workflow is not retired, and `scripts/check_repository_consistency.ps1` still runs unconditionally on every event that triggers that workflow.

**Closing the chapter.** On completion this contract returns `Next capability` to the canonical Batch-6 selector and records the control-plane optimization chapter as CLOSED. Reopening it requires newly earned evidence — a real incident, a false green or false red, a measured material cost, or a proven safety or governance gap — and not a further search for theoretical optimizations.
