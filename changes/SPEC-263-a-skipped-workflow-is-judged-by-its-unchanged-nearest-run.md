# Change Request — SPEC-263

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make `-Certify` judge an expected path-filtered workflow that GitHub did not start on the certified SHA by that workflow's nearest push run on the target branch at an ancestor of the SHA, and only when git proves that no path the workflow watches, and not its own definition, changed between the two SHAs; every other missing workflow stays `REQUIRED_WORKFLOW_MISSING`.

## Business Reason

- **The owner's decision of 2026-10-11:** Option 3. Investigate and correct the remote-certification mismatch, preserving exact-SHA evidence and mandatory database CI, through a bounded corrective contract. SPEC-262 is terminal and is not modified.
- **The defect (CTRL-8), reproduced.**
  - SPEC-262's Implement SHA `a87fa92` changed `supabase/migrations/` and `supabase/tests/`. Migration CI ran on `main` (run 38103963744, success), and `-Certify` returned `REMOTE_CERTIFY: READY`.
  - Its Complete SHA `f61ed84` was pushed alone, with base `a87fa92`. It changed only its contract, the manifest and `ai-map.json`.
  - GitHub's push path filter compares the pushed head with the push's base and starts a workflow only when a watched path changed. It therefore correctly started no Migration CI run.
  - `-Certify` at `f61ed84` returned `REMOTE_CERTIFY: FAILED` with `REQUIRED_WORKFLOW_MISSING: Migration CI`.
- **Root cause.** `Write-Certification` derives the receipt's expected set once, from the contract's whole Write Scope (`Certification-Paths`, single-contract branch), while `-Certify` judges the runs of one push. The two agree only when every change to a watched path reaches the target in the final push.
- **When it recurs.** It recurs for every later contract whose watched-path change and final SHA reach the target in different pushes. It also recurs when a Write Scope names a watched path the range never changes.
- **A latent defect on the same path.** `Trigger-List` stopped at the first comment line inside a `paths:` list. It read 2 of `repository-consistency.yml`'s 14 push paths. A watched set read short is the one error that could certify falsely, so it is repaired here.

## Risks

- **No false success is admitted.** Measured on twenty fixture histories, against the current evaluator:
  - Exactly two verdicts change from FAILED to READY. Both are the false failure: INH-1, the `f61ed84` shape, and INH-13, a comment-interleaved filter with an unwatched head.
  - INH-3, an inherited run still in progress, changes from FAILED to PENDING.
  - Every other refusal keeps its verdict.
- **Fifteen mutants.** Each bypasses one load-bearing predicate, and each turns a refusal into a false READY (or a READY into a refusal) on the case named for it.
- **Exact-SHA, branch, event, status and freshness guards are unchanged.** Runs on HEAD are judged exactly as today. An inherited run must itself be a push run on the target at an ancestor of HEAD, completed and successful. The target ref must still stand at HEAD.
- **The expected set may grow, never shrink.** It grows only where `Trigger-List` now reads a filter fully. Every contract's Write Scope names `changes/*.md`, which Repository Consistency already watches, so no contract's expected set is measured to change.
- **Residual: the watched paths are the authority on a workflow's inputs.** A file a workflow reads but does not watch could change without the workflow re-running. GitHub's own trigger has that same property, and this contract does not widen it.
- **No workflow trigger, Primary, Secondary, migration or database test is touched.** CI-2's owner decision of 2026-10-09 (no automatic change to main-branch Migration CI) is respected.

## Supersedes / Depends On

None. SPEC-262 is Complete and is neither modified nor re-certified by this contract.

## Write Scope

- `changes/SPEC-263-a-skipped-workflow-is-judged-by-its-unchanged-nearest-run.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-262-a-complaint-begins-new-under-its-creator.md`
- `changes/TEMPLATE.md`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `scripts/publish_candidate.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/readiness_population.ps1`
- `scripts/run_timed.ps1`
- `scripts/watch_run.ps1`
- `scripts/watch_ci.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/test_future_date_guard.ps1`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/evidence/primary-ledger-evidence.json`
- `AGENTS.md`
- `GOVERNANCE.md`
- `ENGINEERING_METHOD.md`

## Required Reading

- `CR_LIFECYCLE.md`: the `SPEC-164` paragraph on the certification receipt, and the following `-Certify` paragraph
- `scripts/check_agent_continuity.ps1`: `Glob-Regex`, `Trigger-List`, `Target-Branch`, `Workflow-Expectations`, `Certification-Paths`, `Write-Certification` and `Certify-Remote`
- `scripts/test_agent_continuity.ps1`: the `gh` stub, `Run1`, `GhRuns`, `RunCertify`, cases 104 to 108b and 144 to 149, and SEG-5 to SEG-8
- `reports/master/MASTER_GAP_REGISTER.md`: the CTRL-7 and CI-2 rows

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- `pwsh -NoProfile -File scripts/readiness_population.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| `Certify-Remote` in `scripts/check_agent_continuity.ps1`: after every run on HEAD has settled, each missing expected workflow is passed to the new `Inherited-Run`; a returned run joins `$runs`, and settlement is re-read | Every `-Certify` after a push, the Step 8 publication of each contract | WRITE | Cases 104 to 108b, 144 to 149 and SEG-5 to SEG-8 keep their verdicts on the prototype. The real `f61ed84` with SPEC-262's receipt reads `INHERITED: Migration CI from a87fa92… run 38103963744 attempt 1 completed/success` and `REMOTE_CERTIFY: READY`, against `REQUIRED_WORKFLOW_MISSING: Migration CI` on the current evaluator. |
| `Trigger-List` reads through full-line comments inside a block list | `Workflow-Expectations` (the receipt's expected set) and `Inherited-Run` | WRITE | The real workflows read 0, 5, 0 and 14 push paths (agent-control, migration-ci, orvion-acceptance, repository-consistency), against 0, 5, 0 and 2 before. The expected set can only grow, and only where Repository Consistency is concerned, which every contract's `changes/*.md` already triggers. |
| `Write-Certification`, `Certification-Paths`, `Validate-Certification` and the receipt format | `-Finish`, the `Complete` transition | VERIFY | Byte-unchanged. |
| `scripts/test_agent_continuity.ps1`: the `gh` stub answers a `--workflow` query across commits; cases INH-0 to INH-17 and mutants INH-M1 to INH-M15 in a new family `CERT-INHERIT`, added to NON-EMPTY POPULATIONS | ORVION Acceptance and Agent Control run the suite; `-Finish` (CONTROL) | WRITE | A focused harness built from the suite's own fixture: 52 passed, 0 failed, populations accept 3, reject 17, mutation 15. The full suite on the prototype is recorded in Notes. |
| `CR_LIFECYCLE.md` `-Certify` paragraph: one appended sentence | Authors; no parser reads this sentence | WRITE | The allocation, historical-immutability and evidence-character marker lines are byte-unchanged. |
| `MASTER_GAP_REGISTER.md`: a new CTRL-8 row, FIXED by this contract; a new dated `Last updated:` line, the previous one demoted to `Previously:` | Checks 2, 11, 14, 21 and 25; `scripts/readiness_population.ps1` | WRITE | Prototype in the disposable clone: repository consistency CLEAN; readiness population exit 0. No other row changes. |
| Manifest `Last Completed` and Active pointer; `ai-map.json` | Checks 5 and 7; Boot; `test_cold_start_state_guard.ps1` | WRITE | `Next capability` (Batch 6 Slice 40, `payment_allocations`) and the open-decision line (MAIL-1, PH8-10, RET-1) are unchanged. |
| SPEC-262's committed contract and its local receipt | None | UNAFFECTED | Not modified. `main` moves past `f61ed84` when this contract publishes, so `f61ed84` is never re-certified. This contract certifies its own final SHA. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Repository consistency is CLEAN | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| The CONTROL suites pass: agent continuity and the four guard self-tests | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| Every derived readiness id is classified | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| `ai-map.json` matches its generator | BEFORE_COMPLETION | NONE | NONE | Step 4 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism:
- `Certify-Remote`: the receipt's expected set, the per-row revalidation of SHA, branch and event, the settlement and conclusion judgement, and the remote-ref freshness check.
- `Trigger-List` and `Glob-Regex`, which already read the workflow filters for the expected set.
- The suite's `gh` stub keyed by commit and its permissive mode.

Nothing else is added: no receipt field, ledger, allowlist, mode, switch, file, workflow or capability. The expected set keeps one authority, the receipt. A missing workflow gains one way to be satisfied, by an exact run whose inputs git proves identical.

Added Property: An expected workflow with no run on the certified SHA is satisfied only when all of these hold, and is then judged by that run's status and conclusion:
- the workflow has exactly one definition, with a push `paths:` filter read exactly;
- its nearest push run on the target branch, by position in the SHA's ancestry, is at an ancestor of the SHA;
- git shows no watched path, renames split, and not the definition, changed between that run's SHA and the certified SHA.

Otherwise the workflow stays `REQUIRED_WORKFLOW_MISSING`.

Causal Negative: The current evaluator at `dbfbf8a9…`, on the real `f61ed84` with SPEC-262's receipt, returns `REMOTE_CERTIFY: FAILED` and `REQUIRED_WORKFLOW_MISSING: Migration CI produced no run on this SHA`. Migration CI succeeded on `a87fa92`, and no path it watches differs between `a87fa92` and `f61ed84`. The fixture shape INH-1 reproduces the same verdict.

Positive Test Design: INH-0, a database head with its own green run, is READY and inherits nothing. INH-1 is the `f61ed84` shape, READY with Db inherited. INH-13 is a comment between filter bullets with an unwatched head, READY. Cases 108, 144 and SEG-8 are unchanged.

Negative Test Design: Every case below refuses, and an INH case's refusal names the reason (`NOT INHERITED: <workflow> — <reason>`, or the inherited run's own conclusion):
- INH-0b: a database head whose own run failed, beside an older green run.
- INH-2 and INH-3: an implementation run that failed, or is still in progress (PENDING).
- INH-4: a database head with no run.
- INH-5: a nearer failure beside an older green run on byte-identical inputs.
- INH-6: the workflow's definition changed.
- INH-7: an unfiltered workflow.
- INH-8 to INH-10: a run on another branch, event or workflow, under the permissive stub.
- INH-11: a run outside the ancestry.
- INH-12: a watched file renamed out of its directory.
- INH-13b: a path listed after a comment.
- INH-14 and INH-15: trailing-comment bullets.
- INH-16: two definitions with one name.
- INH-17: a target ref that moved on.

Cases 104 to 107, 145 to 149 and SEG-5 to SEG-7 are unchanged.

Non-Empty Population Obligation: Family `CERT-INHERIT` holds 3 accepting cases, 17 refusing cases and 15 mutation kills, asserted by `NON-EMPTY POPULATION CERT-INHERIT`.

Mutation Obligation: Each mutant is written to a disposable evaluator outside the fixture and run against the same pushed history the pristine evaluator judged. A kill requires the find string to occur exactly once, the pristine run to show the expected verdict, and the mutated run to lose it and reach the named wrong verdict, so a crash is never a kill.

| Mutant | Change | Killed by | Wrong verdict |
| --- | --- | --- | --- |
| INH-M1 | the last row wins instead of the nearest ancestor | INH-5 | READY |
| INH-M2 | the ancestry filter removed | INH-11 | READY |
| INH-M3 | the watched-glob term removed | INH-4 | READY |
| INH-M4 | the own-definition term removed | INH-6 | READY |
| INH-M5 | `--no-renames` removed | INH-12 | READY |
| INH-M6 | the unfiltered-workflow refusal disabled | INH-7 | READY |
| INH-M7 | the bullet-count check disabled | INH-14 | READY |
| INH-M8 | the glob character check disabled | INH-15 | READY |
| INH-M9 | `Trigger-List` stops at comments again | INH-13 | FAILED |
| INH-M10 | more than one definition admitted | INH-16 | READY |
| INH-M11 | the workflow-name revalidation removed | INH-10 | READY |
| INH-M12 | the branch revalidation removed | INH-8 | READY |
| INH-M13 | the event revalidation removed | INH-9 | READY |
| INH-M14 | the inherited run not joined to the judgement | INH-2 | READY |
| INH-M15 | settlement not re-read after inheritance | INH-3 | FAILED |

Post-Implementation Proof Obligation: On the final committed bytes:
- canonical `-Finish` (CONTROL and REPOSITORY: agent continuity with every case and mutant, the four guard self-tests, repository consistency and `scripts/readiness_population.ps1`);
- then `-Gate -BaseRef origin/main` over this contract's range;
- then `publish_candidate.ps1`, candidate CI, exact-SHA promotion to `main`, `main` CI and `-Certify` on this contract's own final SHA.

## Implementation Steps

Every file is written LF. The "from" hashes are the committed bytes at `f61ed84`, and the "to" hashes were measured on the prototype.

1. **Check** whether `scripts/check_agent_continuity.ps1` contains `function Inherited-Run([string]$Workflow,[string]$Sha,[string]$Target){`. If absent, write the evaluator and its suite exactly as prototyped:
   - `scripts/check_agent_continuity.ps1` from `dbfbf8a9ede8872b7d4026fdb7014d2307b5f2ba477328e229a3d5c2fd99e1da` to `925c2394729aa8a61a0f9d87f233a040e2665f34e90cd25f6e318c7049983ef1`
   - `scripts/test_agent_continuity.ps1` from `057dc455a24140c71348dba9aa92893a3320c4c88eed769ca3e35e7f6fd2a808` to `2ed7975ef33dd9441704765a0a21f3db0214a410c46df71608cd14d9c2acbed3`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
2. **Check** whether `CR_LIFECYCLE.md` contains ``One expected workflow may stand on an earlier run, and only under proof (`SPEC-263`)``. If absent, apply exactly as prototyped:
   - `CR_LIFECYCLE.md` from `cdc316bb8c84a9ef57ffad793d8a5862fd13c2d58153e983f1121642778432b9` to `75c7c9672f618b8d3686a4d170582ff0e95e5a07c3a690f0b0f38b27c1a9c0e9`
   - `reports/master/MASTER_GAP_REGISTER.md` from `9f3541f7440c15a3d751bffb52cc0e993652a5071ee61a3b0766851f7b006f5b` to `0cca07b7ecd4f8df020d6c288ba28ef0341d9538ec75f269cd1515ffd7be6dd0`

   If either holds bytes other than its "from" hash, or a resulting hash differs, stop.
3. **Check** for a `Local certification` Execution Log entry. If absent:
   - commit steps 1 and 2 with an Execution Log entry;
   - commit the Runtime Checkpoint as `Resume Step: DONE`;
   - run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` once, alone, on the clean committed tree, and require `LOCAL_CERTIFY: READY`.

   No step runs any command that `-Finish` runs.
4. **Check** whether the manifest's `Last Completed` begins `**SPEC-263`. If not:
   - set it to this contract, with the Active pointer `None.`;
   - leave `Current Module`, `Next capability` (Batch 6 Slice 40) and the open-decision line unchanged;
   - keep the manifest within 7000 characters and 1200 per line;
   - regenerate `ai-map.json` with `scripts/generate-ai-map.ps1` and convert it to LF.

   Then Review, and Complete.

## Acceptance Criteria

- [x] `scripts/check_agent_continuity.ps1` (`925c2394…`) carries `Inherited-Run`. `Certify-Remote` calls it for each missing expected workflow only after every run on HEAD has settled, joins a returned run to the judgement and re-reads settlement. `Trigger-List` reads through full-line comments. `Write-Certification`, `Certification-Paths` and `Validate-Certification` are byte-unchanged.
- [x] `scripts/test_agent_continuity.ps1` (`2ed7975e…`) carries cases INH-0 to INH-17 and mutants INH-M1 to INH-M15 in family `CERT-INHERIT`, which NON-EMPTY POPULATIONS asserts, and it passes in `-Finish`.
- [x] `CR_LIFECYCLE.md` (`75c7c967…`) states the one inheritance exception in its `-Certify` paragraph, and its marker lines are byte-unchanged.
- [x] The register (`0cca07b7…`) records CTRL-8 fixed by this contract in a new row and a new dated `Last updated:` line, demoting the previous one to `Previously:`, and no other row changes.
- [x] At Complete, the manifest names this contract, its `Next capability` is still Batch 6 Slice 40, its open-decision line is unchanged, and `ai-map.json` is regenerated LF.

## Execution Log

### 2026-10-11 — Gate 1 approval and execution started

- **Authority:** the owner's SPEC-263 exact-identity approval and completion authorization (2026-10-11). It approves Gate 1 for Draft `15338ec3ac27f4389fc4ccb2b62edd54c39a7c54`, contract SHA-256 `7fbff1c901f2d96ba097d41ba698f1bd4d4c5a9277933a9e2624104bce0d54af`, to close CTRL-8. Verified before acting:
  - HEAD was the Draft commit, 1 ahead of and 0 behind `origin/main` `f61ed84`, and the working tree was clean;
  - the contract file hashes to the approved value, and the Draft commit changed only this file;
  - the four prototype files in the scratchpad clone `c263` hash to their Step 1–2 "to" values (`925c2394…`, `2ed7975e…`, `75c7c967…`, `0cca07b7…`), and the committed files hash to their "from" values (`dbfbf8a9…`, `057dc455…`, `cdc316bb…`, `9f3541f7…`);
  - Write Scope is the seven paths above.

  Approval was committed at `be9622a`; its pre-commit Gate returned `APPROVAL_EVIDENCE: PASS`.
- **Publication range:** before this commit, `origin/main..HEAD` held 2 commits with 0 merges and was 0 behind.
- **Worktrees.** A read-only inventory; nothing was modified: `wt251` at `578f3fb`, `wt255` at `33e4db6`, `wt260` at `e26733a`, `wt261` at `39ab45a`, `owt/p2` at `7fe62ed` and `C:\w234` at `6c48fbb`. All stay untouched.
- **No database, Primary or Secondary action** belongs to this contract. Migration `20261011090000` is not reapplied.

### 2026-10-11 — Steps 1 and 2: the evaluator, its suite, the lifecycle sentence and the register

- **Checks.** `function Inherited-Run([string]$Workflow,[string]$Sha,[string]$Target){` was absent from the evaluator, and the `SPEC-263` sentence was absent from `CR_LIFECYCLE.md`. Each of the four files held exactly its "from" hash.
- **Applied** by a byte copy from the prototype clone `c263`; each result was re-hashed:

  | File | From | To (measured) |
  | --- | --- | --- |
  | `scripts/check_agent_continuity.ps1` | `dbfbf8a9…` | `925c2394729aa8a61a0f9d87f233a040e2665f34e90cd25f6e318c7049983ef1` |
  | `scripts/test_agent_continuity.ps1` | `057dc455…` | `2ed7975ef33dd9441704765a0a21f3db0214a410c46df71608cd14d9c2acbed3` |
  | `CR_LIFECYCLE.md` | `cdc316bb…` | `75c7c9672f618b8d3686a4d170582ff0e95e5a07c3a690f0b0f38b27c1a9c0e9` |
  | `reports/master/MASTER_GAP_REGISTER.md` | `9f3541f7…` | `0cca07b7ecd4f8df020d6c288ba28ef0341d9538ec75f269cd1515ffd7be6dd0` |

- **Shape.** The evaluator gains 78 lines and loses none. Across the four files: 235 insertions, 4 deletions; `git diff --check` is clean.
- **Step 3.** The Runtime Checkpoint is committed as `Resume Step: DONE` with this entry. `-Finish` runs next, once, alone, on the clean committed tree.

### 2026-10-11 — Step 3: Local certification

Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran once on the clean, committed HEAD `f724919` (VERIFY, `STEP: DONE`, profiles CONTROL and REPOSITORY plus the declared `readiness_population.ps1`). It ran through `scripts/run_timed.ps1` with nothing else running at its start (`concurrent=0`) and was watched by `scripts/watch_run.ps1`. It returned `LOCAL_CERTIFY: READY`, exit 0, in 39.8 min:

| Verification | Result | At |
| --- | --- | --- |
| `scripts/test_agent_continuity.ps1` | PASS | 29.4 min |
| `scripts/test_cold_start_state_guard.ps1` | PASS | 33.6 min |
| `scripts/test_status_contradiction_guard.ps1` | PASS | 36.6 min |
| `scripts/test_primary_ledger_guard.ps1` | PASS | 36.8 min |
| `scripts/test_future_date_guard.ps1` | PASS | 39.5 min |
| `scripts/check_repository_consistency.ps1` | PASS | 39.7 min |
| `git diff --check` | PASS | 39.8 min |
| `scripts/readiness_population.ps1` | PASS | 39.8 min |

The local receipt names `SPEC-263`, profiles CONTROL and REPOSITORY, target `main`, and expected workflows Agent Control and Repository Consistency; Migration CI is not expected, because this Write Scope names no path it watches. A read-only heartbeat (process list and log tail only) was attached after the start and is the `concurrent_end` the runner recorded.

### 2026-10-11 — Step 4: manifest and ai-map

The manifest's `Last Completed` names this contract and its Active pointer is `None.`; against `f61ed84` only the `Last Completed` line differs, so `Current Module`, `Next capability` (Batch 6 Slice 40, `payment_allocations`) and the open-decision line (MAIL-1, RET-1, PH8-10) are unchanged. It holds 6872 characters, its longest line 1154. `ai-map.json` was regenerated by `scripts/generate-ai-map.ps1` and converted to LF.

## Verification Notes

### 2026-10-11 — Independent Review of the execution commit `f724919`

Reviewed the committed tree against the approved Draft `15338ec` and the seven-path Write Scope. The review read the committed files, the range and the `-Finish` log, not the Execution Log.

1. **The evaluator (criterion 1).** `scripts/check_agent_continuity.ps1` hashes to `925c2394729aa8a61a0f9d87f233a040e2665f34e90cd25f6e318c7049983ef1`. Against `f61ed84` its diff has four hunks and no removed line: the `Trigger-List` header comment, the one `elseif($line-match'^\s*#'){continue}` line, the new `Inherited-Run`, and the block in `Certify-Remote` after the `missing && running → PENDING` check, which calls `Inherited-Run` for each still-missing workflow, prints `INHERITED:` or `NOT INHERITED:`, joins a returned run to `$runs` and re-reads `$running`. Extracted from both revisions, `Write-Certification`, `Certification-Paths`, `Validate-Certification`, `Workflow-Expectations` and `Target-Branch` are byte-identical, and `Glob-Regex`'s body is unchanged.
2. **The suite (criterion 2).** `scripts/test_agent_continuity.ps1` hashes to `2ed7975ef33dd9441704765a0a21f3db0214a410c46df71608cd14d9c2acbed3`. It carries INH-0, INH-0b, INH-1 to INH-13, INH-13b and INH-14 to INH-17 (twenty cases) and INH-M1 to INH-M15 (fifteen mutants), each recorded under `Pop 'CERT-INHERIT'`, and `CERT-INHERIT` is the last family in the NON-EMPTY POPULATIONS list. It passed inside `-Finish` at `f724919`.
3. **The lifecycle sentence (criterion 3).** `CR_LIFECYCLE.md` hashes to `75c7c9672f618b8d3686a4d170582ff0e95e5a07c3a690f0b0f38b27c1a9c0e9`; a word diff against `f61ed84` shows only the appended `SPEC-263` sentence in the `-Certify` paragraph, so every marker line is byte-unchanged.
4. **The register (criterion 4).** `reports/master/MASTER_GAP_REGISTER.md` hashes to `0cca07b7ecd4f8df020d6c288ba28ef0341d9538ec75f269cd1515ffd7be6dd0`. Against `f61ed84` it removes only the previous `Last updated:` line, which returns verbatim as `Previously:`, and adds the new `Last updated:` line and the CTRL-8 row; no other row changes.
5. **Manifest and ai-map (criterion 5).** In the Complete commit the manifest's `Last Completed` names SPEC-263 and the Active pointer is `None.`; `Next capability` is Batch 6 Slice 40 and the open-decision line is unchanged; `ai-map.json` is regenerated and LF.
6. **Certification.** `-Finish` at `f724919` returned `LOCAL_CERTIFY: READY` with every mandatory verification PASS, alone at its start. The receipt expects Agent Control and Repository Consistency.
7. **Scope.** `f61ed84..HEAD` changes exactly the seven Write Scope paths. No Out of Scope file, workflow definition, migration, database test, SPEC-262 or worktree changed; neither Primary nor Secondary was contacted.

The committed bytes equal the prototype bytes on which the full suite (424/0), the focused harness (52/0, fifteen mutants killed) and the live `f61ed84` comparison (current `REQUIRED_WORKFLOW_MISSING: Migration CI`; proposed `INHERITED: Migration CI from a87fa92… run 38103963744`, `REMOTE_CERTIFY: READY`) were measured, so that evidence holds for them without a repeat.

Verdict: Confirmed Complete

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

**Evidence before freezing.** Measured 2026-10-11 in a disposable clone of `f61ed84`, with pushes disabled. Nothing was pushed, and the repository was not modified. The live reads were `gh run list`, which is read-only, and `git fetch`.

- **The two pushes, from GitHub:**
  - `a87fa92` on `main`: Repository Consistency, Agent Control and Migration CI, all success.
  - `f61ed84` on `main`: Agent Control and Repository Consistency only.
  - The `origin/main` reflog shows `88bc20a` then `a87fa92` then `f61ed84`.
- **Current against prototype, on the real `f61ed84` and SPEC-262's receipt:**

  | Evaluator | Result |
  | --- | --- |
  | Current | `REMOTE_CERTIFY: FAILED`, `REQUIRED_WORKFLOW_MISSING: Migration CI` |
  | Prototype | `INHERITED: Migration CI from a87fa92… run 38103963744`, `REMOTE_CERTIFY: READY`, in 8 s |

- **Alternatives measured and rejected:**
  - **Removing the push `paths:` filter from Migration CI.** It would remove the false failure without script change. However, over 30 days Migration CI ran on 74 of 182 push runs. Always-on would add about 108 runs a month at about 4.6 min each (longest 46.7 min). Every non-database publication's `main` certification would wait on it instead of about 1 min, and each run is exposed to the infrastructure flakes CI-2 records. It also changes main-branch Migration CI, which CI-2's owner decision of 2026-10-09 rules out, and it leaves the defect for Repository Consistency and any future filtered workflow.
  - **Deriving the expected set from the final push's paths alone.** It would drop the database workflow from a bookkeeping push and certify without any database evidence, so an implementation whose Migration CI failed would certify READY behind a later bookkeeping commit. This is a false success.
  - **Forbidding split publication.** It is a process rule, not a repair: a Write Scope naming a watched path the range never changes still fails, and the history that forces a split (the SPEC-262 recovery) remains possible.
- **GitHub's documented push filter semantics** (workflow syntax, "Git diff comparisons"): a two-dot diff of head and base for an existing branch. A workflow does not run when no watched file changed. It always runs past 1,000 commits or on a diff timeout. Past 3,000 changed files it may not run. `Inherited-Run` never relies on GitHub having skipped: it recomputes the changed paths with git, so a skip GitHub should not have made still refuses.
- **Focused harness on the prototype, built from the suite's own fixture:** 52 passed, 0 failed, covering cases 104 to 108b, 144 to 149, SEG-5 to SEG-8, INH-0 to INH-17 and INH-M1 to INH-M15. On the current evaluator the same twenty INH histories read FAILED everywhere except INH-0, which reads READY.
- **The full suite on the prototype's exact bytes (`925c2394…`, `2ed7975e…`):** `AGENT CONTROL TESTS: 424 passed, 0 failed`, exit 0, in 25.9 min, with no other verification running. Nothing was skipped. It includes all 35 INH cases and mutants, `NON-EMPTY POPULATION CERT-INHERIT`, and every pre-existing `-Certify` case. An earlier run on the same bytes was killed by a session end at 340 passed and 0 failed, and is not counted.
- **The four guard self-tests on the prototype tree,** through `scripts/run_timed.ps1` and watched by `scripts/watch_run.ps1`, all passed. The run was alone (`concurrent=0`), exited 0 and took 8.3 min.

  | Guard self-test | Passed | Failed |
  | --- | --- | --- |
  | Cold-start state | 34 | 0 |
  | Status contradiction | 33 | 0 |
  | Primary ledger | 13 | 0 |
  | Future date | 18 | 0 |
- **The disposable clone,** with the prototype's four files: repository consistency CLEAN, readiness population exit 0.
- **No existing guarantee is removed.** Against `f61ed84`, the evaluator gains 78 lines and loses none:
  - Every exact-SHA, branch, event, settlement, conclusion and freshness statement in `Certify-Remote` runs unchanged, and runs on HEAD are judged first, exactly as before.
  - The new code is reached only for a workflow still missing once every run on HEAD has completed.
  - An inherited run joins the same conclusion check as a run on HEAD.
- **What "unchanged" means.** It is the net difference between the inherited run's SHA and HEAD, which is the same two-dot comparison GitHub uses for a push.
  - A watched file changed and fully restored between the two leaves the workflow's inputs at HEAD byte-identical to those it was judged on, and GitHub would not start it either.
  - When a run exists for the intermediate state, it is nearer, and it decides (INH-5).
  - A change to the certified push itself is never inherited past (INH-4).
- **Approval probe.** In a second disposable clone, the pre-commit hook accepted this Draft, and a replayed Approve commit printed `APPROVAL_EVIDENCE: PASS`. That revision of the Draft differed from this one only in this Notes section, which the evaluator does not read.
