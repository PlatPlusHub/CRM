# Change Request — SPEC-275

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make ORVION's engineering method, and two of the tools that report on it, do in practice what they say.

- **GOV-26.** A fresh agent meets the sandbox isolation rule and the measure-before-freezing rule where it decides: in `AGENTS.md` §1's PLAN boundary, and in the template's existing Pre-Approval Evidence pointer, not only where `ENGINEERING_METHOD.md` documents them.
- **CTRL-16.** The publication range Gate refuses a write committed while its contract was still a Draft, for every contract, not only a cancelled one.
- **OPS-3.** The run watcher exits non-zero when the run it watched failed, and shows when it attached.
- **Recorded, not repaired.** The workstation update's false results (OPS-5) and the idempotence verifier's provisioning side effect (OPS-6) are registered with their measurements, repairs, blocker and trigger.

## Business Reason

The owner's 2026-10-13 directive asks that the engineering philosophy determine how every future agent works, not merely exist in text, and that defects in the tools agents read as evidence be closed.

- **GOV-26 (Medium, observed 2026-10-13).** Seven isolated, read-only, fresh agents were each given one neutrally worded ORVION task.
  - All seven applied the four decision rules.
  - Two documented rules did not reach them:
    - Three of the four that planned an experiment chose a `git worktree`, and one of those would have run `db reset` on the shared local stack. `ENGINEERING_METHOD.md` §2 excludes both.
    - One froze a trivial contract without measuring its mandatory commands (§3), and those commands fail on this workstation today.
  - The agents read `AGENTS.md` §1's PLAN sentence, which says only "a disposable sandbox … outside the authoritative repository", or the template, which points to the evidence rule but not to its sandbox paragraph.
- **CTRL-16 (Medium, verified, open since 2026-10-13).** `CR_LIFECYCLE.md` (SPEC-163) gives a Draft no write authority. SPEC-273 enforced that in range mode only for cancelled contracts, so a contract whose Draft commit also writes an in-scope file is admitted once it is approved and completed. Its trigger is "the next control-plane contract", before `GATE-EVAL`.
- **OPS-3 (Low, proven 2026-10-09).** `scripts/watch_run.ps1` exits 0 when the run it watched failed, so a background notification of exit 0 reads as success, and it never shows when it attached. Its trigger is "the next CR that changes `scripts/watch_run.ps1` for any reason".
- **OPS-5 and OPS-6 (Low, measured 2026-10-13).**
  - **OPS-5.** `.workstation/update.ps1`:
    - reads FAILED on every run on the owner workstation;
    - reads ok for steps that change nothing;
    - applies upgrades with no preview.
  - **OPS-6.** `scripts/verify_workstation_idempotence.ps1` provisions the machine it says it only measures.
  - **Why not repaired here.** Any change under `.workstation/` derives the WORKSTATION profile, and its verifier fails on the owner workstation today: Codex's `context7` is the owner's working OAuth server, not `.mcp.json`'s `npx` server. A contract that `-Finish` cannot certify must not be frozen (§3), so both are recorded with their trigger.

These items share one property: what the method and the tools say must match what agents and tools actually do. They touch disjoint lines of disjoint files, and each is proven on its own.

## Risks

- **Guidance (GOV-26).**
  - One sentence of `AGENTS.md` §1 gains two clauses, and one sentence of the template's evidence comment names §2's closing paragraph. A wrong clause would mislead every agent.
  - The clauses restate the existing §2 and §3 rules in fewer words, add no new rule, and keep the pointer. Checks 26 and 27 still resolve.
  - The failing scenarios are re-run on the repaired text before approval (Notes).
- **Gate tightening (CTRL-16).**
  - A legitimate history that commits a non-contract file while its governor is a Draft will now be refused.
  - Real history has none: every Draft commit from SPEC-250 to SPEC-274 changes only its own contract.
  - The one fixture that did so, case 191h's `KrToggle`, restores its marker after approval, keeping its assertion and purpose.
  - The full control suite was run against the generalised rule before drafting, and only the two predicted cases failed.
- **Watcher exit code (OPS-3).**
  - A caller that relied on exit 0 after a failed run would now see 1.
  - No repository script calls `watch_run.ps1`; it is an on-demand adapter that decides nothing (`AGENTS.md §7`).
- **Untouched.** No database, Primary, CI workflow, ruleset, workstation script or product behaviour changes.

## Supersedes / Depends On

None

## Write Scope

- `AGENTS.md`
- `changes/TEMPLATE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `CR_LIFECYCLE.md`
- `scripts/watch_run.ps1`
- `scripts/watch_selftest.ps1`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `changes/SPEC-271-upgrade-project-local-supabase-cli-to-2-120-0.md`
- `changes/SPEC-272-the-pinned-cli-keeps-the-certified-local-stack.md`
- `changes/SPEC-273-a-publication-admits-exactly-what-its-contracts-authorised.md`
- `changes/SPEC-274-uncertainty-is-reduced-before-a-contract-is-frozen.md`
- `ENGINEERING_METHOD.md`
- `GOVERNANCE.md`
- `PROJECT_CONTEXT.md`
- `README.md`
- `CLAUDE.md`
- `scripts/publish_candidate.ps1`
- `scripts/watch_ci.ps1`
- `scripts/run_timed.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/verify_workstation_idempotence.ps1`
- `.workstation/update.ps1`
- `.workstation/prepare.ps1`
- `.workstation/doctor.ps1`
- `.mcp.json`
- `.github/workflows/agent-control.yml`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/repository-consistency.yml`
- `package.json`
- `package-lock.json`
- `supabase/config.toml`

## Required Reading

- `AGENTS.md`
- `CR_LIFECYCLE.md`
- `ENGINEERING_METHOD.md` §§2–3
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `changes/SPEC-273-a-publication-admits-exactly-what-its-contracts-authorised.md`
- `changes/SPEC-274-uncertainty-is-reduced-before-a-contract-is-frozen.md`
- `scripts/watch_run.ps1`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- `pwsh -NoProfile -File scripts/watch_selftest.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| `AGENTS.md` §1's PLAN sentence carries §2's isolation principle (isolate whatever the experiment can change: commits in a fresh clone with push disabled, because a `git worktree` shares refs and config; database work on its own Supabase project id and ports, never the shared local stack) and §3's measurement rule for every Draft, running a command that can change shared state only in such a sandbox and asking before running one that cannot be isolated | Every cold-start agent: README, then Boot, then `AGENTS.md` | WRITE | Only clauses are inserted. "do not mutate implementation", the write-authority sentence and the status sentence are unchanged. Behaviour was observed on fresh agents before and after the change (Notes). |
| `changes/TEMPLATE.md`'s Pre-Approval Evidence comment names §2's closing paragraph, "Reduce uncertainty before freezing", where it already points Draft authors to the evidence rule | Every Draft author; the Gate's canonical section set; consistency Check 26 and the ACTIVE CR checks, which read the template | WRITE | One existing sentence is extended inside a bracketed comment. No section, status word or heading changes, so no section-set or Status consumer changes. Prototype: `REPOSITORY CONSISTENCY: CLEAN`, "all 81 cross-document section pointers resolve". |
| Both sentences | `ENGINEERING_METHOD.md` §2 "Reduce uncertainty before freezing" and §3 "Measure a verification before you freeze it as mandatory" | VERIFY | Both remain the owners of the rules, and neither file changes. §2 already says that "where running one would disturb shared state, a sandbox lets an author run it in isolation", which the new measurement clause carries. Asking before running a command that cannot be isolated keeps §3's obligation without licensing provisioning the owner's machine (OPS-6). §2's "a typo … needs neither" concerns sandboxes and prototypes, not measurement, so the two agree. |
| The same sentence | Repository consistency Check 26 (section pointers), Check 27 (relocated owner-ratified anchors), and the boot-authority and pointer checks | VERIFY | Prototype: `REPOSITORY CONSISTENCY: CLEAN`, and the pointer `"Reduce uncertainty before freezing"` is kept verbatim. |
| The same sentence | Boot's `WRITE_AUTHORITY: none (Draft CR authoring only)` line | UNAFFECTED | It describes authority over the repository. A disposable clone is outside it, as SPEC-274 established. |
| In `Validate-CommittedRange`, a commit at which the governing contract was still a Draft may change only that contract (`PRE_APPROVAL_WRITE`), for every governor; the cancelled-only condition and its two computing lines are removed | `Validate-PublicationSegments`, `Resolve-Contract`, `publish_candidate.ps1` and the ORVION Acceptance range step (all through `-Gate -BaseRef`) | WRITE | The range they pass is unchanged; only which commits are admitted changes. Every Draft commit from SPEC-250 to SPEC-274 (`23a5f3a`, `e461606`, `e62085f`, `1975890`, `022646f` and earlier) changes only its own contract. The working-tree Gate already refuses this shape in PLAN. |
| The same rule | Every control-suite fixture that commits during Draft | WRITE | Measured: the suite with only the predicate generalised gave 440 passed and 2 failed, both predicted. Case 191h's `KrToggle` rewrote `CR_LIFECYCLE.md` while its contract was a Draft; it now restores the marker after approval, keeping its assertion and purpose. The SPEC-273 mutant named the removed condition in its anchor, and is re-anchored on the new predicate. 191g, built from the same fixture and refused earlier by allocation, keeps its verdict. |
| The same rule | `CR_LIFECYCLE.md`'s SPEC-273 paragraph, which says range mode does not yet apply it to completed contracts (`CTRL-16`, open) | WRITE | That sentence becomes false and is replaced by the rule for every governor. The three enforcement markers are untouched. |
| `watch_run.ps1` exits 1 when the run ended non-zero, and its first line carries its attach time | Agents and humans reading a Monitor's or background task's exit code; `scripts/watch_selftest.ps1` (W3, W8); `AGENTS.md` §7, `CR_LIFECYCLE.md` and `ENGINEERING_METHOD.md` §3, which describe the watcher | WRITE | No repository script calls it, and none of the three documents states its exit code, so none changes. `watch_ci.ps1` already exits 1 on a failure, so both watchers now agree. The CSV, the result vocabulary, the heartbeat and `RUNNER GONE` are unchanged. |
| Register and Action registry | `reports/master/MASTER_GAP_REGISTER.md`; `reports/master/MASTER_EXECUTION_PLAN.md`; consistency Check 29 ("nothing open is lost") | WRITE | GOV-26, CTRL-16 and OPS-3 are recorded fixed. OPS-5 and OPS-6 are recorded OPEN, and join the registry's `OWN-TRIGGER` row in place of OPS-3. CTRL-16's row leaves the registry, which holds open items only. Prototype: `REPOSITORY CONSISTENCY: CLEAN`, Check 29 `ACCEPTED RESIDUAL 28`. |
| `.workstation/` and the WORKSTATION profile | `scripts/verify_workstation_idempotence.ps1` on the owner workstation | UNAFFECTED | Nothing under `.workstation/` changes, so this contract derives no WORKSTATION profile. Measured: the verifier exits 1 here (OPS-5), which is why OPS-5 and OPS-6 are recorded rather than repaired. |
| Manifest active pointer | Boot, Check 7, `scripts/generate-ai-map.ps1` | WRITE | `ai-map.json` and `repository-index.md` are in Write Scope. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Working tree is clean and the branch is not behind its upstream | BEFORE_IMPLEMENTATION | NONE | NONE | 1 |
| The nine implementation files equal their pinned target hashes and no other tracked path changed | BEFORE_COMPLETION | 1 | 2 | 3 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism:
- **The Gate.** SPEC-273's `PRE_APPROVAL_WRITE` refusal in `Validate-CommittedRange` is reused, with its cancelled-only condition removed; nothing new is added to the Gate.
- **The control suite.** `ScLife`, `MutationKillRangeAt` and the `SEG-CARRY` population are the existing fixture, mutation and population machinery.
- **The watcher.** It reuses `watch_selftest.ps1`'s W3, W8 and mutant table.
- **The guidance.** It reuses `AGENTS.md` §1's existing pointer sentence and the template's existing evidence pointer; no check, gate, checklist or file is added for it.

Added Property:
- Every governor's writes are admitted only if the contract carried write authority at the commit that made them.
- A watcher's exit code is the outcome of the run it watched.
- A fresh agent reads the isolation and measurement rules where it reads its PLAN boundary.

Causal Negative: Reproduced 2026-10-13 in disposable clones and fresh agents:
- **CTRL-16.** Under SPEC-273's cancelled-only condition, a completed contract's Draft-phase write is admitted. The new SC mutant restores exactly that behaviour, and the SC-13 range is then admitted.
- **OPS-3.** The unchanged watcher's only exit at END is `exit 0`, whatever `N` the run reported. Mutant M16 restores that line, and on W3's failing run (`END exit=1`) the watcher then exits 0.
- **GOV-26.** On the unchanged text, 3 of 4 agents that planned an experiment chose a worktree, and 1 of 7 froze a trivial contract unmeasured.

Positive Test Design:
- SC-9 (two clean born-and-completed segments), 191h (reordered, accepted), 204 (a Draft revised before approval) and every other existing range case keep their verdicts.
- W8: the watcher of a successful run exits 0.
- The cold-start agents of scenarios B, F and G behaved correctly before the change. The re-run scenarios must keep their decisions.

Negative Test Design:
- SC-13 (a born-and-completed contract), SC-14 (a later completed segment) and SC-15 (a Draft at the range base) refuse `PRE_APPROVAL_WRITE`.
- SC-10 still refuses a carried cancelled contract's Draft-phase write.
- W3: the watcher of a failing run exits 1 and shows its attach time.
- W8: a watcher re-armed on a finished failed run exits 1.
- W6: a runner that dies is reported `RUNNER GONE` with exit 1.
- Re-run scenarios A, C, D and E on the final wording, from a fresh clone at the rehearsed Complete commit. Measured before approval: none chooses a worktree or the shared stack for a history- or database-changing experiment, and the trivial contract's mandatory commands are inspected and measured, isolated or asked about, before freezing (Notes, with the residual).

Non-Empty Population Obligation: `SEG-CARRY` gains reject cases SC-13 to SC-15 and one mutation kill. Its accept, reject and mutation populations stay non-zero, as the existing `NON-EMPTY POPULATION SEG-CARRY` asserts.

Mutation Obligation:
- `SC-MUTATION: a completed contract's Draft-phase write is refused at the commit that made it` replaces the generalised predicate with `if($false)`, and SC-13's shape must kill it.
- The re-anchored SPEC-273 mutant must still be killed by SC-10's shape.
- Watcher mutant M16 (`exit 0` at END) must be killed by W3.
- No mutation applies to guidance text. Its proof is the observed behaviour of fresh agents, run before and after.

Post-Implementation Proof Obligation: The certified `-Finish` runs CONTROL (the full control suite and the four guard suites), REPOSITORY, and the Additional Verification `watch_selftest.ps1`. After `Complete`:
- `publish_candidate.ps1` must admit `origin/main..HEAD`;
- ORVION Acceptance must pass on the candidate;
- `-Certify` must report READY on `main`.

## Implementation Steps

1. For each file below, read its blob with `git hash-object --path=<path> <path>`. If it equals the `to` hash, record Already Applied. If it equals the `from` hash, replace the file with the reviewed content summarised in Notes, so that its blob becomes exactly the `to` hash. Any other value means stop and report; do not guess.
   - `AGENTS.md`: from `b1d693e1b4e28ad7a7e5b29ba92460537747cc89` to `328aac3fdfc407cfbd924b72c50cdf4e6e40fd16`
   - `changes/TEMPLATE.md`: from `cdfded3fccfbda42b34ddc841097eeb2fbe66856` to `b386a61a27d4a74780e3706daec925f76d21c62a`
   - `scripts/check_agent_continuity.ps1`: from `65fa3765344c30b6aeec52f24b1d05c9e096810f` to `64d5d53887d61da97b87d451e3ffe5ed93abb81c`
   - `scripts/test_agent_continuity.ps1`: from `65b6ff93d6712cf82a1bf2ec06dbd3a9a846e966` to `013c3f9a3a89ebba92140c86b8ab825724804940`
   - `CR_LIFECYCLE.md`: from `b119aafea5007e16757822eeff091756a95469cb` to `d65a85ffab56635f1aa2251301c8c036a30467f4`
   - `scripts/watch_run.ps1`: from `8a3e57e9db5cecf4552f65c6e05e0b01bdbacd79` to `06e1001973c731e25687c816c6662bde17ef0a2f`
   - `scripts/watch_selftest.ps1`: from `122d672b5bdda6c82ed1edf2a2bad9b114233eec` to `6b2b7f719acefa1611b834d0300ff3a04dd19cb0`
   - `reports/master/MASTER_GAP_REGISTER.md`: from `503721130a10ce3bffe4d563943126ded8838787` to `3b2bf7bc4492d0ee9ce165843ea46e6d946b262b`
   - `reports/master/MASTER_EXECUTION_PLAN.md`: from `52424c50321b620c29a3960d6d33b0499b671f0e` to `55eb1c6c3432789fdbcda739755e13a89237059c`
2. Check whether `git diff --name-only` against the approval commit lists only the nine files above plus this contract. If so, record Already Applied. Otherwise stop and report any other path. Nothing else is edited in this step; the lifecycle commits own the manifest, `ai-map.json` and `repository-index.md`.
3. Check whether the Runtime Checkpoint already reads `Resume Step: DONE`. If so, record Already Applied. Otherwise synchronize the Execution Log and the Runtime Checkpoint to `DONE`, and commit the implementation and checkpoint together.
   - Run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` normally. No container, Docker or workstation state is changed for it.
   - If a test fails, preserve its exit code and evidence, and follow bounded recovery without weakening any assertion.

## Acceptance Criteria

- [x] Each of the nine Step 1 files has exactly its `to` blob.
- [x] `scripts/test_agent_continuity.ps1` contains SC-13, SC-14, SC-15 and the new `SC-MUTATION` kill, and `scripts/check_agent_continuity.ps1` no longer contains `cancelledGovernor`.
- [x] `scripts/watch_selftest.ps1` contains mutant M16, and W3 and W8 assert the watcher's exit code.
- [x] `AGENTS.md` §1 carries the isolation principle (a fresh clone with push disabled for commits, its own Supabase project id and ports for database work) and the measurement rule with its shared-state qualifier, and `changes/TEMPLATE.md` names §2's closing paragraph; the `"Reduce uncertainty before freezing"` pointer is unchanged.
- [x] The register reads GOV-26, CTRL-16 and OPS-3 fixed and OPS-5 and OPS-6 OPEN with their trigger, and the Action registry has no CTRL-16 or OPS-3 entry and lists OPS-5 and OPS-6.
- [x] `changes/SPEC-271-…` to `changes/SPEC-274-…` are byte-identical to `13fb8fc`.
- [x] The tracked implementation diff touches only this contract's Write Scope.

## Execution Log

### 2026-10-13 — Claude

Outcome: Implemented. The Runtime Checkpoint is DONE; `-Finish` follows.

Step results:
- **Step 1: Applied.** Each file read its `from` hash. It was replaced with the reviewed content from the pre-approval prototype, whose blob had been checked equal to the `to` hash before copying. `git hash-object --path` then read exactly the `to` hash:
  - `AGENTS.md`: `b1d693e1` to `328aac3f`
  - `changes/TEMPLATE.md`: `cdfded3f` to `b386a61a`
  - `scripts/check_agent_continuity.ps1`: `65fa3765` to `64d5d538`
  - `scripts/test_agent_continuity.ps1`: `65b6ff93` to `013c3f9a`
  - `CR_LIFECYCLE.md`: `b119aafe` to `d65a85ff`
  - `scripts/watch_run.ps1`: `8a3e57e9` to `06e10019`
  - `scripts/watch_selftest.ps1`: `122d672b` to `6b2b7f71`
  - `reports/master/MASTER_GAP_REGISTER.md`: `50372113` to `3b2bf7bc`
  - `reports/master/MASTER_EXECUTION_PLAN.md`: `52424c50` to `55eb1c6c`
- **Step 2: Applied.** `git diff --name-only` listed exactly those nine files plus this contract. No other path changed.
- **Step 3: Applied.** The Runtime Checkpoint is synchronized to `DONE` and committed with the implementation. `-Finish` runs next, normally, with no container, Docker or workstation state changed. Docker Desktop is down after Windows Update's WSL 3.0.3 install (Notes) and is not needed by CONTROL or REPOSITORY.

Correction to Notes, recorded here so the approved Draft stays byte-identical:
- The bullet "Recorded here, not registered separately" overstates a defect. In `.workstation/manifest.md`, the version column is headed "Live evidence 2026-09-10". The file itself says these values "are evidence, not pins; package identities and `package-lock.json` are the reproducible contracts". So `^2.109.0`, GitHub CLI 2.100 and Node 24.19 are a dated observation, not a current claim or a configuration defect.
- `package.json` and `package-lock.json` remain the version authority. Nothing is owed to it beyond refreshing the observation when the next justified workstation change runs the doctor.

Commits: the implementation and checkpoint commit that carries this entry.
## Verification Notes

### 2026-10-13 — Claude (Independent Review of `1497f24`)

Verdict: Confirmed Complete

Findings: each was re-checked against the committed repository after `-Finish`, not against the Execution Log.

1. **Criterion 1.** At HEAD, all nine files read exactly their pinned blobs (9 of 9).
2. **Criterion 2.** `scripts/test_agent_continuity.ps1` asserts SC-13, SC-14 and SC-15 (3 of 3) and contains the new `SC-MUTATION` kill. `scripts/check_agent_continuity.ps1` contains `cancelledGovernor` 0 times.
3. **Criterion 3.** `scripts/watch_selftest.ps1` contains mutant M16. W3 asserts exit 1 and the attach time. W8 asserts exit 1 for a re-armed watcher on a finished failed run, and exit 0 for a later successful one.
4. **Criterion 4.** `AGENTS.md` §1 carries the fresh clone with push disabled, the worktree's shared refs and config as the reason, the database's own Supabase project id and ports, and "asking before running one that cannot be isolated". The `"Reduce uncertainty before freezing"` pointer is unchanged. `changes/TEMPLATE.md` names §2's closing paragraph.
5. **Criterion 5.** The register reads GOV-26, CTRL-16 and OPS-3 fixed and OPS-5 and OPS-6 OPEN, each in one row. The Action registry has no CTRL-16 row and no OPS-3 entry, and lists OPS-5 and OPS-6 in the `OWN-TRIGGER` ACCEPTED RESIDUAL row.
6. **Criterion 6.** `git diff --name-only 13fb8fc HEAD` lists none of `changes/SPEC-271-…` to `changes/SPEC-274-…`.
7. **Criterion 7.** The net diff from `13fb8fc` is exactly the nine files, this contract, the manifest and `ai-map.json`, all in Write Scope, and the tree is clean. The manifest and `ai-map.json` return to baseline at Complete.
8. **Local certification.** `-Finish` at `1497f24` ran alone (`concurrent=0` at start and end), with no container, Docker or workstation state changed; Docker Desktop was down throughout, after Windows Update's WSL install. Every command passed:
   - `test_agent_continuity.ps1`, the full suite with SC-1 to SC-15, both Draft-write mutation kills, 191g, 191h and the SEG cases (21.3 min);
   - `test_cold_start_state_guard.ps1`, `test_status_contradiction_guard.ps1`, `test_primary_ledger_guard.ps1` and `test_future_date_guard.ps1`;
   - `check_repository_consistency.ps1` and `git diff --check`;
   - the Additional Verification `watch_selftest.ps1`.

   `LOCAL_CERTIFY: READY`, 36.9 min. The receipt names SPEC-275, READY, CONTROL and REPOSITORY, and expects Agent Control and Repository Consistency on `main`. The repaired watcher followed the run, attached 5 s after its start, and exited 0.
9. **Original defects against corrected behaviour.**
   - **CTRL-16.** Before approval, the unchanged Gate admitted SC-13, SC-14 and SC-15 (`ORVION: READY`). The repaired Gate refuses all three with `PRE_APPROVAL_WRITE`.
   - **OPS-3.** M16 restores the old `exit 0`, and W3 kills it.
   - **GOV-26.** Fresh agents on the final wording chose a fresh clone and an isolated stack, and inspected the verifier before running it (Notes).
10. **Authority.** The owner conditionally authorised Gate 1 and Gate 2 for this exact Draft (blob `ae754b95…`, SHA-256 `459637bc…`, base `13fb8fc`), and all eight conditions were verified before the Approve commit. No architectural decision beyond the contract is introduced. OPS-5 and OPS-6 stay deferred to their trigger. Docker, WSL, Context7 OAuth, `MCP_TIMEOUT` and the local stack were not touched.

Recommendation to human: Set Status to Complete (performed by the executing agent under the owner's 2026-10-13 Gate 2 authorization).
## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

- **The owner's 2026-10-13 directives, and what was decided.**
  - **Adopted now:** GOV-26, CTRL-16 and OPS-3.
  - **Adopted later: OPS-5 and OPS-6.**
    - Both are measured, and OPS-5's repair is prototyped and proven.
    - Both wait for WORKSTATION verification to pass on the owner workstation.
    - The owner decides the Context7 definition. The reconciliation must keep the working OAuth server and stay right for a fresh install.
    - `MCP_TIMEOUT=90000`, set as a side effect of measuring, is the documented desired value and was left in place.
  - **Not adopted: restating principles A–H.**
    - The cold-start trial showed the decision method is already applied (7 of 7 agents): learn first, earn it, worth it, simplify, reuse, proportion research to risk, challenge negative paths, verify freshness at the source, and refuse to overstate a PASS.
    - What failed was two specific rules not reaching agents at the point of use, and that is what GOV-26 repairs.
    - A second statement of the principles, a checklist, a score or a new kernel would add text without changing any observed behaviour.
  - **Not adopted: a new approval-evidence mechanism.**
    - The evaluator already refuses missing, `UNKNOWN`, unresolved and placeholder consumer rows, red-window and out-of-range boundaries, self-exempting labels, missing regenerated artifacts (write closure) and post-approval rewrites (cases 167–179, 195–203, 223–228).
    - Scenario G's agent stated PASS's limit correctly.
    - The remaining classes (whether a mandatory command can succeed, whether a causal negative is true) are judgment, which §2 and §3 own and GOV-26 makes visible.
    - This contract is itself an instance: measuring its first design before freezing found its WORKSTATION command failing, and the scope was narrowed before approval.
    - **Trigger:** the first measured false PASS on a structural class.
  - **Not adopted: a workstation framework.**
    - `doctor.ps1` (read-only, PASSED 2026-10-13), `prepare.ps1` (setup and repair, proven by the idempotence verifier), `update.ps1`, `menu.ps1` and `workstation.cmd` already provide DOCTOR, SETUP and REPAIR/UPDATE.
    - Only the update path and the verifier were found defective.
  - **Not adopted: further watcher changes.**
    - `watch_ci.ps1` already judges the exact SHA, branch and push event, reports a missing workflow as MISSING, and exits non-zero on failure (C1–C4, L1–L6).
    - Re-arming adds no duplicate rows (W8).
    - Inherited CI evidence is `-Certify`'s (SPEC-263), never a watcher's.
- **Scenario B's residual, observed and not repaired.**
  - That agent did not run Boot, and it read a 404 from GitHub's classic branch-protection endpoint as "main is not protected".
  - In fact Ruleset 22950574 protects `main`, which Boot states.
  - The rule it broke already exists (§3: a result proves only what it measures). Its cause is that the agent never entered the boot path, which no repository text can force on an agent that does not read it.
  - **Trigger:** a second observed instance.
- **`AGENTS.md` (+1/−1).** The §1 PLAN sentence keeps every existing clause. Inside the existing pointer it inserts §2's isolation principle, and after it §3's measurement rule with §2's shared-state qualifier and "asking before running one that cannot be isolated".
- **`changes/TEMPLATE.md` (+3/−1).** The Pre-Approval Evidence comment's first sentence names §2's closing paragraph and what it says.
- **Validator change (`scripts/check_agent_continuity.ps1`, +4/−7).**
  - `if($cancelledGovernor-and$statusAt-eq'Draft')` becomes `if($statusAt-eq'Draft')`, and its comment is restated.
  - The two lines that computed `$cancelledGovernor`, whose only use this was, are removed.
- **Suite change (`scripts/test_agent_continuity.ps1`, +22/−9).**
  - `ScLife` gains `-DraftWork`, run before the Draft commit.
  - SC-13, SC-14, SC-15 and one `MutationKillRangeAt` kill are added. SC-15's approval names the manifest it writes, so its Draft-phase write is the history's only defect. A first version did not: the unchanged Gate refused it as `OUT_OF_SCOPE_WRITE: _ORVION_CANONICAL/manifest.md`, so that refusal was incidental and proved nothing.
  - The SPEC-273 mutant is re-anchored.
  - `KrToggle` restores its marker after approval.
  - The block comment is restated.
- **`CR_LIFECYCLE.md` (+1/−1).** One sentence in the SPEC-273 paragraph.
- **`scripts/watch_run.ps1` (+5/−2).** At END it exits `[int]($body -notmatch '^END exit=0\b')`, and its first line names its attach time. The header says both.
- **`scripts/watch_selftest.ps1` (+6/−5).**
  - W3 asserts exit 1 and the attach time.
  - W8 asserts exit 1 for a watcher re-armed on a finished failed run, and exit 0 for a later successful one.
  - Mutant M16 is added.
- **Register (+8/−3) and plan (+4/−3).**
  - **Headers.** Each file gets a new "Last updated" header, and the previous one becomes "Previously:".
  - **Register.**
    - CTRL-16 and OPS-3 become fixed.
    - GOV-26 is added, fixed.
    - OPS-5 is added OPEN, with its measurement, prototype, safety constraints, blocker and trigger.
    - OPS-6 is added OPEN.
  - **Plan.** CTRL-16's row is removed. The grouped `OWN-TRIGGER` ACCEPTED RESIDUAL row loses OPS-3 and gains OPS-5 and OPS-6.
- **Pre-approval evidence**, gathered 2026-10-13 in fresh clones of `13fb8fc`, each with its push URL set to `none`, and in fresh read-only agents. No tracked file in the authoritative repository was changed.
  - **Generalised predicate alone:** `AGENT CONTROL TESTS: 440 passed, 2 failed`, 22.6 min. The two failures were the predicted ones: 191h (`PRE_APPROVAL_WRITE: CR_LIFECYCLE.md`) and the SPEC-273 mutant (`applied=False`).
  - **Full prototype suite:** `AGENT CONTROL TESTS: 446 passed, 0 failed`, 22.9 min, `concurrent=0`. It includes SC-13, SC-14, SC-15, both Draft-write mutation kills, 191g, 191h and `NON-EMPTY POPULATION SEG-CARRY`.
  - **Prototype watcher, live:** following that suite, it printed `END exit=0` and exited 0. Following a later `-Finish`, its first line read `started 2026-10-13 11:27:48, attached 2026-10-13 11:28:03`.
  - **Repository consistency on the final prototype:** `REPOSITORY CONSISTENCY: CLEAN`, Check 29 included, and `git diff --check` clean.
  - **WORKSTATION, measured for an earlier design that changed `.workstation/update.ps1`:**
    - `doctor.ps1` printed `WORKSTATION VERIFICATION: PASSED`.
    - `verify_workstation_idempotence.ps1` exited 1 (`[FAIL] Codex MCP context7 exists but does not match the repository definition`), and set `MCP_TIMEOUT=90000` (OPS-6).
    - The scope was narrowed so that this contract derives no WORKSTATION profile.
  - **Cold-start trial on the unchanged text:** 7 fresh agents, 1 per scenario, each read-only. Every one applied the four decision rules.
    - **A:** kept a trivial change minimal, but would have frozen it unmeasured.
    - **B:** reused Check 7. It skipped Boot and misread an API.
    - **C:** found the newest stable CLI already pinned, but chose a worktree and `db reset` on the shared stack.
    - **D:** checked `actions/checkout` at its source, but chose a worktree.
    - **E:** demanded the missing negative RLS paths, but chose a worktree.
    - **F:** rejected Pester on EARN IT, using a fresh clone.
    - **G:** said a PASS proves structure, not truth.
  - **First repair round.** The `AGENTS.md` clause said "never a `git worktree`", without the template pointer. It was rehearsed through Complete (`-Finish` `LOCAL_CERTIFY: READY`), then the four failing scenarios were re-run on fresh agents. A, C and E were corrected. D still chose a worktree; it reached its task through `CR_LIFECYCLE.md`, `changes/TEMPLATE.md` and earlier SPECs, never through `AGENTS.md` §1. The owner's review then asked for isolation to be resource-aware, not a blanket worktree ban, and for measurement never to license changing the owner's machine. That produced the final wording: §2's principle and qualifier carried verbatim in substance, plus the template's existing evidence pointer naming §2's closing paragraph.
  - **CTRL-16 causal negative on the unchanged Gate.** The new suite was run against the `main` validator (`65fa3765…`).
    - The first run gave 441 passed and 5 failed. SC-13 and SC-14 printed `ORVION: READY`, so the old Gate admits them. The two `SC-MUTATION` kills reported `applied=False`, because their anchor is the new predicate.
    - SC-15 printed `BLOCKED` with `OUT_OF_SCOPE_WRITE: _ORVION_CANONICAL/manifest.md`. That refusal was incidental: the fixture's approval wrote the manifest outside the base Draft's scope. The fixture was corrected, so the Draft-phase write is now its only defect.
    - The second run, with the corrected suite (`013c3f9a…`), again gave 441 passed and 5 failed. SC-13, SC-14 and **SC-15 all printed `ORVION: READY`**.
    - Every other case passed on the old Gate, including 191g, 191h (reordered), 204, SC-1 to SC-12 and the SEG cases. So nothing else depends on the change, and 191h still tests allocation under either Gate.
  - **Final lifecycle rehearsal of the exact final scope**, in a fresh clone with hooks active, base `13fb8fc`. It was never pushed and certifies nothing.
    - **Commits, every Gate READY:** Draft `1b9c632`, Approve `28c11c3`, Begin `8a063e4`, Implement `39429bb`, Complete `3e2ef32`.
    - **At Approve:** `APPROVAL_EVIDENCE: PASS`, `VERIFICATION: CONTROL, REPOSITORY, pwsh -NoProfile -File scripts/watch_selftest.ps1`.
    - **At Implement:** all nine files read their `to` hashes.
    - **`-Finish` at `39429bb`:** all seven profile commands and `watch_selftest.ps1` passed, `LOCAL_CERTIFY: READY`. Its suite refused SC-13, SC-14 and SC-15 with `PRE_APPROVAL_WRITE`, as asserted. The 41.7 min ran beside the old-Gate suite, so it is not a timing.
    - **Range Gate** (`-Gate -BaseRef origin/main`): READY. The net diff is exactly the nine files and this contract; the manifest and generated maps return to baseline.
    - **The fixed watcher on a real run,** in an earlier rehearsal: its first line read `started 2026-10-13 11:46:27, attached 2026-10-13 12:08:10`, a 22-minute late attach that the unchanged watcher would have hidden, and it exited 0 after `END exit=0`.
  - **Final behaviour test on the final wording.** Four new read-only agents ran in a fresh clone of the rehearsed Complete commit (Boot `READY / PLAN`, clean).
    - **A:** inspected the mandatory verifier before running it ("may change the machine"), and would run it isolated or ask first. Residual: it named a fresh clone as that isolation, although a clone does not contain `prepare.ps1`'s machine-level effects. Its ask-first fallback still protects the owner workstation.
    - **C:** would prototype "in a fresh clone with push disabled, using its own Supabase project id and ports", and found the newest stable CLI already pinned.
    - **D:** would rehearse "in a fresh clone with its push URL disabled", to prove every command the Draft is judged by can pass before freezing. That agent read `AGENTS.md` §1–3, so one trial cannot separate the `AGENTS.md` wording's effect from the template pointer's.
    - **E:** would test "in a fresh clone with push disabled, its own Supabase project id and ports", and again rejected the vacuous one-sided RLS test.
    - **B, F and G** were not re-run: their decisions involved neither changed clause. This is a small population; it shows an observed improvement, not reliability.
- **Recorded here, not registered separately.** Scenario C's final agent noticed that `.workstation/manifest.md`'s live-evidence column is stale: Supabase CLI `^2.109.0` against the pinned `2.120.0`, GitHub CLI 2.100, and Node 24.19. It is documentation drift inside `.workstation/`, and belongs to OPS-5's trigger, the next CR that changes `.workstation/`.
- **Environment events during preparation, not caused by it.** At 11:53–11:54 Windows Installer applied WSL 3.0.3.0 from Windows Update, Restart Manager stopped the running WSL processes, and Docker Desktop then reported "unable to start". This contract's verification uses no Docker, so its rehearsal was unaffected. Neither Docker nor WSL was touched by this work; the owner decides any restart.