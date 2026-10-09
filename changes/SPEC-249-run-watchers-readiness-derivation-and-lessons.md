# Change Request — SPEC-249

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Integrate the session-validated run and CI watchers, the readiness-population derivation and the lessons they rest on into their existing repository authorities, as on-demand tooling that owns no truth.

## Business Reason

- **The owner's order (2026-10-09):** SPEC-248, then this integration, then the SUB-4 correction. The owner approved the monitoring approach on conditions: it stays on demand and non-authoritative, it never dismisses or reruns a failure on a familiar message, it records timings only with their conditions, and it enters the repository only if evidence justifies it. The owner also ordered that corrections live in the system rather than in agent memory.
- **Why the closed control-plane chapter reopens.** The manifest requires newly earned evidence. Each item below was observed in the 2026-10-08/09 sessions:
  - **Incident.** A scratch helper named `Rd` resolved to PowerShell's built-in `rd` alias, which deletes files, and removed `AGENTS.md` from the working tree. Git restored it.
  - **False green in reporting.** A progress report carried a "289 passed" line that no run had printed; it was retracted.
  - **Measured cost.** SPEC-248's step 4 ran the five CONTROL suites, and `-Finish` then ran all five again on the same bytes. That `-Finish` took 50.3 minutes with no visibility of which stage was running, and the owner asked twice whether it was stuck.
  - **Measured workstation failure.** `context7` and `postgres-local` failed to connect at session start: a cold `npx -y` start measured 51.6 s against Claude Code's 30 s default. A fresh `claude mcp list` with `MCP_TIMEOUT=5000` failed both, and with `90000` connected both.
  - **Governance gap.** Each trap above was recorded only in agent memory, which no other session or agent reads.
  - **A defect in the gate's own population, found by this contract's derivation script.** SPEC-248's first derivation read only the first id of a shared register row. It never classified BF-7, on row `CDD-5/BF-6/BF-7` (DESIGN-READY), and it reported 439 / 119 where the register's own resolver gives 446 / 124.
- **What the tools must do, and now do on real runs.** They were prototyped, attacked in scratch and run against six real, finished SHAs; every gap found was fixed and re-proved before freezing (Notes).
  - Every result line a repository script prints is reported, and prose is not.
  - Exit codes are preserved.
  - A stalled stage, a killed runner and a runner that never started are each reported.
  - The candidate and `main` share one SHA, so each branch is judged against its own contract: ORVION Acceptance runs on the candidate only. That contract is derived by the deriver `-Certify` already uses (`Workflow-Expectations`), never listed by hand.
  - A check that never ran is reported MISSING, never as passed. A path-filtered workflow that legitimately did not trigger is never waited for.

## Risks

- **Tooling could start to own truth.** It is excluded by construction, and the self-tests pin the observable consequences.
  - The watchers write only a local timings file outside the repository, and no profile, hook or workflow runs them.
  - Their exit code summarises the evidence they printed. `-Finish` and `-Certify` remain the only verdicts.
  - `AGENTS.md §7` states the boundary.
- **Two tools read another script's internals.** `watch_ci.ps1` reads `Workflow-Expectations` from `check_agent_continuity.ps1`, and `readiness_population.ps1` reads the register vocabularies and resolver from `check_repository_consistency.ps1`. Both read them through the PowerShell AST, so there is no copy to drift. A rename fails loudly with `AUTHORITY_MOVED`, never silently; R5 proves this for the readiness script. Both authorities are Out of Scope here.
- **The self-tests are timing-based.** Their waits are bounded and their tolerances wide, and both were measured on this workstation; the figures are in Notes.
- **CONTROL text.** `AGENTS.md`, `CR_LIFECYCLE.md` and `changes/TEMPLATE.md` gain appended text only. Assertions 44 and 45, Check 27 and both lifecycle marker lines keep their exact anchors.
- **WORKSTATION.** On a converged machine `prepare.ps1` prints `[ OK ] MCP_TIMEOUT=90000` and changes nothing. On an unconverged one it prints `[CONFIG]` once, by design. It never overwrites a different user value.
- **No migration, no test of the database, and no Primary access.** SUB-4 is referred to by subject only, and no later SPEC identity is named.

## Supersedes / Depends On

None. SPEC-248 is Complete and is not modified. The gate section it added to `MASTER_EXECUTION_PLAN.md` is corrected here by an added, dated paragraph, and its first-derivation record is left as written.

## Write Scope

- `changes/SPEC-249-run-watchers-readiness-derivation-and-lessons.md`
- `scripts/run_timed.ps1`
- `scripts/watch_run.ps1`
- `scripts/watch_ci.ps1`
- `scripts/watch_selftest.ps1`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `changes/TEMPLATE.md`
- `CODING_STANDARDS.md`
- `ENGINEERING_METHOD.md`
- `.workstation/manifest.md`
- `.workstation/prepare.ps1`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-248-four-rules-and-readiness-gate.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/verify_workstation_idempotence.ps1`
- `.workstation/doctor.ps1`
- `.mcp.json`
- `.github/workflows/agent-control.yml`
- `GOVERNANCE.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_CERTIFICATION_STATUS.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`

## Required Reading

- `AGENTS.md` §2, §7 and §8; `ENGINEERING_METHOD.md` §2–§3; `CR_LIFECYCLE.md` §4, §8 and §9; `changes/TEMPLATE.md`
- `scripts/check_agent_continuity.ps1`: `Invoke-Verification`, the mode derivation and `FINISH_NOT_READY`
- `scripts/check_repository_consistency.ps1`: `$idPat`, `$statusOpenLead`, `$statusResolvedLead`, `$registerDeciderRx`, `$decisionIdRx`, `Get-RegisterFindingState`, and Checks 11, 22 and 27
- `reports/master/MASTER_EXECUTION_PLAN.md`, the Pre-Production Readiness Closure gate
- `.workstation/manifest.md` §3, `.workstation/prepare.ps1` and `scripts/verify_workstation_idempotence.ps1`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- `pwsh -NoProfile -File scripts/watch_selftest.ps1`
- `pwsh -NoProfile -File scripts/readiness_selftest.ps1`
- `pwsh -NoProfile -File scripts/readiness_population.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| `AGENTS.md §7` gains one sentence bounding the on-demand watchers | Boot; `test_agent_continuity.ps1` assertions 44–45; Check 27 | VERIFY | The sentence is appended to the §7 paragraph, and every routing anchor (`ENGINEERING_METHOD.md §2`, `§3`) is unchanged. |
| `CR_LIFECYCLE.md §9`: one paragraph after the `-Finish` paragraph | The Gate reads the `SPEC Allocation Enforcement` and `Historical CR Immutability Enforcement` marker lines; `test_agent_continuity.ps1` (line 1399) reads the latter | VERIFY | Both marker lines are byte-unchanged, and §4's transition matrix is untouched. |
| `changes/TEMPLATE.md`: two lines in the Implementation Steps guidance | Authors of new contracts; the Gate parses only the governing contract, never the template | VERIFY | No heading or section changes. |
| `CODING_STANDARDS.md §12` PowerShell traps (new) | Evidence-authority path; read by authors; no parser | WRITE | Appended after §11; nothing existing changes. |
| `ENGINEERING_METHOD.md §3`: four bullets after the credentials bullet | Check 27 anchors; assertion 45 (`No vacuous security tests`, `A green guard proves only`, `Attack every new detector with a counterexample`, `External credentials never pass through the agent`) | VERIFY | Every anchor is preserved. |
| `.workstation/manifest.md`: `Last curated` and a §3 startup-timeout paragraph | Check 28 (the MCP and extension tables against `.mcp.json` and `.vscode/extensions.json`) | VERIFY | Neither table changes. |
| `.workstation/prepare.ps1`: the MCP startup-timeout block | `scripts/verify_workstation_idempotence.ps1` (no `[INSTALL]`, `[CONFIG]` or `FAILED` on a converged machine); `.workstation/doctor.ps1` | VERIFY | On this workstation the block prints `[ OK ] MCP_TIMEOUT=90000`. The prototype's idempotence and doctor runs are recorded in Notes. |
| `MASTER_EXECUTION_PLAN.md`: header, one gate sentence, a dated correction paragraph, and BF-7 placed with CDD-5/BF-6 | Check 2 (cross-Master status); Check 21; `test_status_contradiction_guard.ps1` | WRITE | No `Status` column is added, and no row leads with a finding id. The register is not touched, so no status changes anywhere. |
| Six new on-demand scripts in `scripts/` | No profile, hook or workflow runs them, and none sits on a Permanent-Control path (`check_`, `verify_`, `test_`) | WRITE | Proved by `watch_selftest.ps1` and `readiness_selftest.ps1`, named in Additional Verification; `-Live` is run once on the prototype, because it needs the network. |
| `Workflow-Expectations`, `Trigger-List` and `Glob-Regex` (`check_agent_continuity.ps1`); `$idPat`, both status vocabularies, `$registerDeciderRx`, `$decisionIdRx` and `Get-RegisterFindingState` (`check_repository_consistency.ps1`) | `watch_ci.ps1` and `readiness_population.ps1` read them through the AST | VERIFY | Unchanged and Out of Scope. A rename throws `AUTHORITY_MOVED`. The CI contract at real SHAs (C3) and the live universe (R6) prove that both readings agree with the authorities. |
| The manifest's `Last Completed` and the Active pointer; `ai-map.json` | Checks 5 and 7; Boot; `test_cold_start_state_guard.ps1` | WRITE | The open-decision line and `Next capability` (the SUB-4 correction first) are unchanged. The manifest stays within 7000 characters and 1200 per line. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Repository consistency is CLEAN | BEFORE_COMPLETION | NONE | NONE | Step 5 |
| The CONTROL suites pass | BEFORE_COMPLETION | NONE | NONE | Step 5 |
| The workstation doctor and idempotence pass | BEFORE_COMPLETION | NONE | NONE | Step 5 |
| Both self-tests pass, and the readiness population is fully classified | BEFORE_COMPLETION | NONE | NONE | Step 5 |
| `ai-map.json` matches its generator | BEFORE_COMPLETION | NONE | NONE | Step 6 |

## Implementation Steps

Every file is written LF. Each SHA-256 below was measured on the prototype at `697b050`.

1. **Check** whether `scripts/watch_run.ps1` exists. If absent, create the six on-demand scripts exactly as prototyped:
   - `scripts/run_timed.ps1` `31be25631b9b4e247135d7ae2a52173678c5a471f44b90048a574e180933730a`
   - `scripts/watch_run.ps1` `84050ab2826996eb52b947d27f0a714d8464177fdcdbc84d38bb6f88abf034d2`
   - `scripts/watch_ci.ps1` `049c45cb64aadcb72e22a0ed43baab16f5be0de364753c5425971646d59af7e2`
   - `scripts/watch_selftest.ps1` `136a758fec4fcd20aba6f4b6bfb97f7895b60ebe7734955a0090b47472a7a995`
   - `scripts/readiness_population.ps1` `6392f0c4a0336db01133021f721b65746e50fd8cb335ecc0618ef47a8240d611`
   - `scripts/readiness_selftest.ps1` `62f27dcd0e48d464d3c9ab1d78cc5f0b053dea639c23194daddfe45789e3c978`

   If any of them exists with other content, or a resulting hash differs, stop.
2. **Check** whether `AGENTS.md` contains `The on-demand run and CI watchers`. If absent, apply exactly as prototyped:
   - **`AGENTS.md`:** the watcher-boundary sentence, appended to the §7 paragraph that ends "without separate owner-approved architecture." Expected SHA-256 `2d558ed3d1b3f4806f360356969a081daabc8a76be58e787322570d83389f82b`.
   - **`CR_LIFECYCLE.md`:** the paragraph "**`-Finish` is the one run of the local verification, and it runs last**", directly after §9's `-Finish` paragraph. Expected SHA-256 `36eace8bdb3edca4f956177ea3cca55b5eea023908f829ffdff173c1f7a77228`.
   - **`changes/TEMPLATE.md`:** two lines after "stop and escalate." in the Implementation Steps guidance. Expected SHA-256 `f1f71e291130c6f41542d91e4d0fee39552f29288268ef6319daca7161678ce1`.
   - **`CODING_STANDARDS.md`:** `## 12. PowerShell traps`, with eight traps and their evidence, appended after §11. Expected SHA-256 `5b335192bf0f1a4f7d08d23966c7fe1a1fc436808671c78fcb59b73f237ff678`.
   - **`ENGINEERING_METHOD.md`:** four §3 bullets after the credentials bullet: quoting only what a log printed, timings with their conditions, watching a long run, and promoting a lesson. Expected SHA-256 `4e3527b0ad41c02bf85cc44301291ef0949c77b16400ac91b3b51d8b2ab0f238`.

   If a target carries different content, or a resulting hash differs, stop.
3. **Check** whether `.workstation/manifest.md` contains `**Startup timeout (2026-10-09).**`. If absent, apply exactly as prototyped:
   - **`.workstation/manifest.md`:** `Last curated: 2026-10-09`, and the startup-timeout paragraph after the §3 MCP table. Expected SHA-256 `01d95a3735959b17a3e55ea5f3f79a9640260c2fe45db012c6724f47bf9aa98e`.
   - **`.workstation/prepare.ps1`:** the `== MCP startup timeout ==` block, after the project-MCP section. Expected SHA-256 `0c5ae9e73b4e21a191573ee873aecc803fdd2c3aca1ebcdc5923a5dced81f587`.

   If a target carries different content, or a resulting hash differs, stop.
4. **Check** whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `**Corrected 2026-10-09 (`SPEC-249`).**`. If absent, apply exactly as prototyped:
   - a new `Last updated: 2026-10-09` entry, with the prior one demoted to `Previously:`;
   - the sentence naming `scripts/readiness_population.ps1` after "A hand-picked or remembered list is not an evaluation.";
   - the dated correction paragraph after the first derivation (446 / 322 / 124 at `523888d`);
   - `CDD-5/BF-6` becomes `CDD-5/BF-6/BF-7` in the future-only list.

   Expected SHA-256 `27ceff439f3090258ba92df4651eae3d01eaaad27a54adf996f773f9f13a686a`. If the target carries different content, or the resulting hash differs, stop.
5. **Check** for a `Local certification` Execution Log entry. If absent:
   - commit steps 1–4 with an Execution Log entry;
   - commit the Runtime Checkpoint as `Resume Step: DONE`;
   - run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` once, on the clean committed tree, and require `LOCAL_CERTIFY: READY`. It may be run through `scripts/run_timed.ps1` and followed with `scripts/watch_run.ps1`.

   No step runs any command that `-Finish` runs.
6. **Check** whether the manifest's `Last Completed` begins `**SPEC-249`. If not:
   - set it to this contract, with the Active pointer `None.`;
   - leave `Current Module`, `Next capability` (the SUB-4 correction, then Batch 6 Slice 35) and the open-decision line unchanged;
   - keep the manifest within 7000 characters and 1200 per line;
   - regenerate `ai-map.json` with `scripts/generate-ai-map.ps1`, LF.

   Then Review, and Complete.

## Acceptance Criteria

- [ ] The six on-demand scripts exist with the step-1 SHA-256s (`run_timed` `31be2563…`, `watch_run` `84050ab2…`, `watch_ci` `049c45cb…`, `watch_selftest` `136a758f…`, `readiness_population` `6392f0c4…`, `readiness_selftest` `62f27dcd…`), and no profile, hook or workflow invokes them.
- [ ] `AGENTS.md §7` bounds the watchers as on-demand reporting adapters that never retry, rerun, dismiss, classify or approve; SHA-256 `2d558ed3…`.
- [ ] `CR_LIFECYCLE.md §9` and `changes/TEMPLATE.md` state that `Resume Step: DONE` is committed before `-Finish` and that no step runs what `-Finish` runs; SHA-256 `36eace8b…` and `f1f71e29…`.
- [ ] `CODING_STANDARDS.md §12` lists the eight PowerShell traps with their evidence; SHA-256 `5b335192…`.
- [ ] `ENGINEERING_METHOD.md §3` carries the four bullets, and every assertion-45 and Check 27 anchor survives; SHA-256 `4e3527b0…`.
- [ ] `.workstation/manifest.md` records the measured startup timeout, and `prepare.ps1` sets `MCP_TIMEOUT=90000` only when it is absent; SHA-256 `01d95a37…` and `0c5ae9e7…`.
- [ ] `MASTER_EXECUTION_PLAN.md` names the derivation script, records the corrected first derivation (446 / 322 / 124) and places BF-7; no class, order, criterion or EC changed; SHA-256 `27ceff43…`.
- [ ] At Complete, the manifest's `Last Completed` names this contract, its `Next capability` still begins with the SUB-4 correction, its open-decision line is MAIL-1, RET-1 and PH8-10, and `ai-map.json` is regenerated LF.
- [ ] No migration, database test or Primary object changed, and no SPEC identity after this one is named in any changed file.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-09 — Owner approval and execution started

- **Approval** is delegated by the owner's instruction of 2026-10-09: correct the defects found in prototyping, then, once the prototype is stable and the acceptance criteria pass, freeze the minimal Write Scope and proceed through the governed lifecycle. `APPROVAL_EVIDENCE: PASS` was reported at Approve `bca3310`, with profiles CONTROL, REPOSITORY and WORKSTATION. The same verdict was refused (`FAIL`) when a mandatory gate was injected inside a red window, so the PASS is a real evaluation.
- `origin/main` and `origin/orvion-preflight` were at `697b050`; the Draft is `4cff68c`.
### 2026-10-09 — Steps 1-4 executed

Outcome: Complete

Step results:
- Step 1: Applied — the six on-demand scripts, each matching its frozen SHA-256.
- Step 2: Applied — `AGENTS.md`, `CR_LIFECYCLE.md`, `changes/TEMPLATE.md`, `CODING_STANDARDS.md` and `ENGINEERING_METHOD.md`, each matching its frozen SHA-256.
- Step 3: Applied — `.workstation/manifest.md` and `.workstation/prepare.ps1`, each matching its frozen SHA-256.
- Step 4: Applied — `reports/master/MASTER_EXECUTION_PLAN.md`, matching its frozen SHA-256.

All 14 resulting hashes were compared with the frozen values: 14 matched and none differed. `git diff --check` is clean. No step ran a command that `-Finish` runs.

Engineering Observation: the first application stopped at step 2's `CR_LIFECYCLE.md` anchor, as the step requires when content is not as expected. The cause was measured, not guessed. This checkout held CRLF working copies (`git ls-files --eol`: `i/lf w/crlf`) of `CR_LIFECYCLE.md` and `changes/TEMPLATE.md`, while their committed blobs are LF; the prototype worktree had fresh LF copies. The content was otherwise identical. The scratch apply script now normalizes line endings on read, and it writes LF, the committed form. The rerun produced the frozen bytes exactly. This is the LF trap `CODING_STANDARDS.md §12` now records.
## Verification Notes

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

**Prototype evidence.** Measured 2026-10-09 in a scratch worktree at `697b050` on this workstation (`DESKTOP-0U3LC2V`, pwsh 7.6.6, 8 logical CPUs), each suite run alone. Every figure below was copied from the run's own output.

- **`scripts/readiness_selftest.ps1`: 11 passed, 0 failed in 0.3 min.**
  - R1: the replay at `523888d`.
  - R2–R4: fixtures for every rule, in both directions.
  - R5: a vocabulary the authority no longer defines fails loudly.
  - R6: on the live register, the derived universe equals the subjects Check 11's own rule reads.
  - Five mutants are killed, each by its own rule.
- **`scripts/watch_selftest.ps1 -Live`: 34 passed, 0 failed in 6.7 min (28 cases without `-Live`).** It drives real processes, judges the CI contract at real SHAs, and kills all 15 mutants. Overhead at the production cadence was 1.41 s of CPU at start, then 0.34 s per minute watched.
- **Live CI cases, against real exact SHAs:**
  - L1 and L2: `697b050`, success on `orvion-preflight` and on `main`. On `main`, ORVION Acceptance is correctly not expected; Migration CI is legitimately path-filtered on both.
  - L3: `66bf1b2`, a candidate code failure. The evidence includes the indented `FAIL CONTROL` line.
  - L4: `795d6bc`, Migration CI attempt 4, failed at "Start local Supabase stack" on `ghcr.io` `toomanyrequests` pulls. It is shown, not classified.
  - L5: `cde4f06`, `main`, Agent Control failed. Its cause, `CODE: AMBIGUOUS_GOVERNING_CR`, is shown.
  - L6: `ab1e3a3`, an intermediate commit. No runs exist, so it is reported `MISSING` and exits 1.
- **`scripts/readiness_population.ps1` on the prototype:** 446 / 322 / 124, with 18 + 3 surfaces and MAIL-1, PH8-10 and RET-1, every id classified. Exit 0.
- **Other runs on the prototype:**
  - `scripts/check_repository_consistency.ps1`: `REPOSITORY CONSISTENCY: CLEAN` in 0.4 min, run through `run_timed.ps1` with `concurrent=0`.
  - `.workstation/doctor.ps1`: `WORKSTATION VERIFICATION: PASSED`, with 0 required failures. Its one warning, Codex `supabase-primary` OAuth, is identical on the unchanged main checkout.
  - `scripts/verify_workstation_idempotence.ps1`: `WORKSTATION IDEMPOTENCE: PASSED`: exit 0, no installation, no reconfiguration, no failure, and every tracked file byte-identical. The new block prints `[ OK ] MCP_TIMEOUT=90000` here.
  - `git diff --check`: clean.
- **Not run on the prototype: the five CONTROL suites.** This contract's CONTROL edits only append text. Assertions 44 and 45, Check 27 and both `CR_LIFECYCLE.md` marker lines read anchors this contract leaves byte-unchanged. `-Finish` runs all five once. Paying for a second full run to guard append-only text is not worth it (WORTH IT).

**Reconciliation of the readiness derivation, 2026-10-09.**
- The derivation never states a total of its own: settled state comes only from the register's resolver, and nothing is settled by default.
- Its universe, 446 ids, is exactly the set of finding subjects Check 11 reads, by Check 11's own rule (R6). All 124 not-settled ids are among them.
- SPEC-248's prototype read only the first id of a shared row. The faithful reading adds five ids, each on a row whose siblings the gate had already placed:
  - B3, on `R8/B3`;
  - BF-3, on `CDD-1/BF-3`;
  - CDD-4, on `BF-4/CDD-4`;
  - BF-6 and BF-7, on `CDD-5/BF-6/BF-7`, all DESIGN-READY.

  B3, BF-3, CDD-4 and BF-6 were already named beside those siblings. BF-7 was named nowhere, and is placed with its row.
- Every OTHER member (8) and BLOCK-ONLY member (10) has a placement in the section. The `523888d` record stays as written, and the correction is a dated paragraph beside it.

**Defects found by testing before freezing:**
- The step lines `PASS:` and `FAILED:` were missed.
- Prose such as "fail-closed" was read as a failure.
- Six verdict words that the scripts print were missed; the list is now derived from source.
- `pwsh -Command` collapsed every exit code to 1.
- A runner killed mid-run was indistinguishable from a long stage.
- An editor's terminal script was labelled as concurrent load, while a scratch `-File` script, the real contaminant of SPEC-248's `-Finish`, was not.
- A universal required-check list made the CI watcher wait forever on `main`.
- The CI evidence dropped `CODE:` refusals and indented `FAIL` lines, and kept `PASS` lines that contain the word FAILED.
- The readiness reading dropped shared-row siblings and the range row `INV-1..4`.

**Success measures, judged on the SUB-4 correction.**
- No silent stall: every quiet period produces a heartbeat that names a stage.
- Every failure is reported within one poll.
- No promoted trap recurs.
- No step repeats a `-Finish` command.
- The readiness population is re-derived by the script.

If any of these fails EARN IT there, that tool is simplified or removed by a later contract; it is not defended.

**Limits, stated rather than hidden:**
- The concurrency label is a lower bound: it sees PowerShell `-File` scripts only.
- `watch_ci.ps1` needs the true `-Base`, the `main` commit the SHA is published on.
- Its path matching is `Workflow-Expectations`' own, with three glob forms.
- `-Live` depends on GitHub keeping those runs' logs.
- The timings file is local to one workstation.
- SPEC-248's 50.3-minute `-Finish` is not a baseline. The first labelled `-Finish` timing is this contract's own.
- `MCP_TIMEOUT` reaches a client only after a restart, and this host has not restarted since the value was set.
