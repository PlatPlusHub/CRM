# Change Request — SPEC-270

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make ORVION keep its derived state correct without an agent remembering which files to update, and make every obligation it holds reachable from one derivation. Each change below removes a measured way for state to go stale or for an obligation to be forgotten. All of them reuse existing mechanisms:
- **The manifest stops copying derived figures that nothing compares.** These are the Batch 6 target and its metrics, the coverage total, and the table, catalog, reporting-view and HTTP-assertion counts. Each is replaced by the name of the record or command that derives it.
- **One deterministic generator writes both repository-only projections.** `scripts/generate-ai-map.ps1` writes `ai-map.json` and `repository-index.md` with LF line endings and no timestamp. Its `-Check` mode reproduces both in memory. Check 7 runs it, so a stale projection fails every guard run, CI included. The approval-time write closure binds both projections to any contract that writes a canonical document.
- **The backlog's live items enter the registry's boundary model.** `reports/future-backlog.md` gets one Live deferred items table, and each row names a registry boundary. `scripts/readiness_population.ps1` derives each row's state. Check 29 fails on a row with no known boundary, or with a `REACHED` one.
- **The rest of Batch 6 joins the registry.** Every surface still `NOT-RECORDED` becomes an implicit registry member at `B6-EXIT`, by EC-1. The remaining programme is listed, and its exit cannot be recorded while any surface is unaudited.

## Business Reason

- **The owner's objective of 2026-10-12, second message.** ORVION must keep its own knowledge, recognize when obligations come due, and keep its authoritative and derived files synchronized. The rule is: an agent changes an authoritative fact once; ORVION reconciles everything safely derivable, and names any authored change still required. The owner set four principles: LEARN BEFORE GUESSING, EARN IT, WORTH IT, and SIMPLIFY IT WITHOUT WEAKENING.
- **The control-plane chapter is reopened only on earned evidence.** The manifest requires a false green, a real incident, a measured cost or a proven gap. Each item below is one of those, measured on 2026-10-12 at `6c8b500`:
  - **CTRL-12, a false green.** The manifest's next target was changed to `bookings` (Exposure 9, coverage 99) and its coverage to `41 of 78`. After the prescribed `ai-map.json` regeneration, the guard printed `REPOSITORY CONSISTENCY: CLEAN`, so Boot's NEXT line would have sent the next agent to the wrong slice. Seven figures were mutated one at a time:
    - tables, catalog, reporting views and HTTP assertions passed (exit 0);
    - RPCs, suite and migrations failed (Checks 15 and 9).
  - **CTRL-13, a false green and a recurring cost.** `repository-index.md` has listed `31_schema_draft.md` at 0.5 since `88f751c` (2026-08-10), and the document reads 0.6.
    - Its generator was inline in `scripts/repository-all.ps1`, which also runs `git add .`, commits and pushes, so no governed workflow ran it.
    - `ai-map.json` regenerated twice, a second apart, gave different bytes, with 262 CR bytes. The cause is OPS-4: every contract that moves the manifest converted line endings by hand, and every lifecycle commit touches `ai-map.json`.
  - **CTRL-14, a real incident.** The backlog check reported `26 live rows, 0 without a trigger`, but it only required a non-empty cell.
    - Five live rows described finished work: REF-1 (resolved 08-21), event immutability (`202607043300`), `auth_user_id` `on delete set null`, RLS before client access, and `finance_approval_required`, which is now read.
    - One row that looked finished is not: the invitation and activation lifecycle has no record, no timestamps and no events. It stays live.
    - Other rows named triggers that had already passed.
    - **Docker's unauthenticated `tcp://localhost:2375` was still listening.** The 2026-07-13 review recorded it as failing Earn-It and deferred it until "after the comprehensive review".
    - Separately, the 36 `NOT-RECORDED` surfaces were in no obligation list, and nothing tied `B6-EXIT` to EC-1.
- **What already works, and stays as it is.**
  - The Action registry derives every open obligation's state, and Check 29 enforces it on every Boot, Gate, `-Finish` and CI run (SPEC-269, proven).
  - Checks 9, 15 and 19 guard the manifest's migration, suite, RPC and ledger figures.
  - Check 22 owns surface coverage totals.
  - The approval-time write closure (SPEC-210) already binds `ai-map.json` to manifest contracts.
  - Gate 1 is the control that stops an agent choosing unrelated work: no work starts without a contract the owner approves.
- **Rejected under EARN IT or WORTH IT:**
  - **A scheduled watcher or notifier.** No obligation is calendar-dated (searched 2026-10-12), and every repository-derived trigger is already re-evaluated on every push and every Boot. Nothing changes between commits that a schedule could observe. Primary-derived triggers are invisible to CI by design. Reopens on the first calendar-dated obligation, or on an owner decision to run an authorized reader of Primary.
  - **A Boot code change to print the registry.** SPEC-269 rejected it, and no incident since shows the routing failed.
  - **Observing Primary business counts in Check 29 (CTRL-11).** It stays an accepted residual with its trigger at `GATE-EVAL`.
  - **Auto-regeneration inside the pre-commit hook.** A hook that rewrites and stages files can capture a partial stage. One generator command with a precise failure is cheaper and safer.
  - **Moving the backlog into the register.** It would duplicate the register's role for ideas and move an authority. The backlog keeps its items and borrows the registry's boundaries.

## Risks

- **A contract that edits a canonical document must now carry both projections in its Write Scope.** The approval-time write closure enforces this, so the obligation is refused at approval rather than discovered after an irreversible step. That is the SPEC-203 class, and test 234 proves it.
- **Check 7 is stricter.** Any canonical header edit without regeneration fails. That is the intended behavior, and the remedy is one command. The guard self-tests run Check 7 on sandbox copies, and they pass on the prototype (Notes).
- **The registry's DUE NOW count rises from 22 to 58.** The added 36 are the unaudited surfaces, which EC-1 already required before `B6-EXIT`. Order is unchanged: the selector still chooses each slice.
- **The triage is judgement.** Each closed backlog row cites its evidence in the backlog itself, and an item's text survives in the dated record and in Git.
- **The Docker setting is not changed here.** It is a workstation setting the owner controls, and it stays DUE NOW in the backlog until the owner acts.
- **No product, database, Primary, Secondary, n8n or Google surface is touched.**

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-270-the-repository-reconciles-what-it-can-derive.md`
- `scripts/generate-ai-map.ps1`
- `scripts/repository-all.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `.github/workflows/repository-consistency.yml`
- `GOVERNANCE.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`
- `reports/future-backlog.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`

## Out of Scope — Files Forbidden to Modify

- `changes/TEMPLATE.md`
- `CR_LIFECYCLE.md`
- `AGENTS.md`
- `ENGINEERING_METHOD.md`
- `scripts/publish_candidate.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/test_future_date_guard.ps1`
- `.github/workflows/orvion-acceptance.yml`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/agent-control.yml`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/evidence/primary-ledger-evidence.json`
- `supabase/migrations/`
- `supabase/tests/`
- `_ORVION_CANONICAL/32_execution_roadmap.md`

## Required Reading

- `reports/master/MASTER_EXECUTION_PLAN.md`: the Pre-Production Readiness Closure gate and its Action registry
- `scripts/readiness_population.ps1` and `scripts/readiness_selftest.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/check_repository_consistency.ps1`: Checks 7, 20 and 29
- `scripts/check_agent_continuity.ps1`: `$script:EvidenceWriteClosure`
- `reports/future-backlog.md`

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- `pwsh -NoProfile -File scripts/readiness_selftest.ps1`
- `pwsh -NoProfile -File scripts/readiness_population.ps1 -Registry`
- `pwsh -NoProfile -File scripts/generate-ai-map.ps1 -Check`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| `scripts/generate-ai-map.ps1`: writes `repository-index.md` too; LF; no `generated_at`; sorted with the invariant culture; new `-Check` | Check 7 (new reproduction); `scripts/repository-all.ps1`; `AiMap-CertifiedProjection` in `scripts/check_agent_continuity.ps1`; assertion 158; every reader of `ai-map.json` | WRITE | Measured on the prototype: the output equals the committed `ai-map.json` with line endings normalized and the timestamp removed. Two runs give identical bytes with 0 CR. The projection still removes `generated_at` when present, so a receipt over an older map is unchanged. Assertion 158 now requires the three live_state names and no timestamp. No reader of `generated_at` exists in the repository. |
| `repository-index.md`: regenerated (`31_schema_draft.md` 0.6; generator line) | `AGENTS.md` §4 file discovery; `ai-map.json` `file_index`; `GOVERNANCE.md` §2 | WRITE | Content is the same table, shape and columns, now reproduced by Check 7. |
| `scripts/repository-all.ps1` no longer generates the index inline | Its human caller | WRITE | It already called the generator, which now writes the index. The rest of the script is unchanged. |
| Check 7 runs `generate-ai-map.ps1 -Check`; Check 20 requires the generator as a trigger | `-Boot`, `-Gate`, `-Finish` (Repo-Guard); `repository-consistency.yml`; the four guard self-tests, which run the guard on sandbox copies | WRITE | The three by-value field comparisons are kept for their specific messages. The guard self-tests pass on the prototype (Notes). Adds under 1 s per guard run. |
| `$script:EvidenceWriteClosure`: any canonical document needs `ai-map.json` and `repository-index.md` | The Draft-to-Approved evaluator; tests 229–234 | WRITE | Closure binds only when the artifact exists, so 229–233 are unchanged. New test 234 refuses a canonical-document contract without the index. |
| `scripts/readiness_population.ps1`: implicit `NOT-RECORDED` members at `-SurfaceBoundary` (`B6-EXIT`); evaluated Live deferred items table; backlog rows in `-Registry` | Check 29; `scripts/readiness_selftest.ps1`; the `-Tsv` and `.registry.tsv` readers | WRITE | The population TSV is unchanged (R1, R2, R6). `.registry.tsv` gains the implicit rows. `registry:` reads DUE NOW 58, BLOCKED 21, NOT DUE 36, ACCEPTED RESIDUAL 27, FUTURE-ONLY 58. The backlog line reads `10 live items; DUE NOW 1, NOT DUE 9`. `REGISTRY: complete`. |
| `scripts/readiness_selftest.ps1`: fixtures gain `t_four` (`NOT-RECORDED`) and a Live table; R16–R19; mutants M13–M15 | The CONTROL profile; CI's guard-of-the-guard loop | WRITE | 33 passed, 0 failed, every mutant killed. |
| `reports/future-backlog.md`: the Live deferred items table and the triage record; the enter-and-leave rule | Check 29; agents routed by `GOVERNANCE.md` §2 ("deferred and triggers") | WRITE | The dated sections below stay as written. Each closed row's carrier or evidence is named in the triage paragraph. |
| `MASTER_EXECUTION_PLAN.md`: "DUE NOW is a deadline, not a work order" (EC-1…EC-11 all stay required); "Two kinds of member need no row"; OPS-4 pruned from its registry row | Check 29; Check 2 | WRITE | OPS-4 is settled in the register by this contract, so it would read COMPLETED with a prune note. |
| Register: CTRL-12, CTRL-13 and CTRL-14 FIXED by this contract; OPS-4 FIXED at its recorded trigger; a new `Last updated:` | Checks 2, 11, 14, 21 and 25; the registry | WRITE | Universe 491 ids, 352 settled. No decision id changes. |
| Manifest: four copied figures, the coverage total and the target metrics are removed; Current Module and Next capability name the selector | Boot NEXT; Checks 5, 6, 7, 9, 15, 16 and 17; `ai-map.json` | WRITE | 6632 characters, longest line 1144. Every guarded figure stays: migrations, ledger, fingerprints, RPCs, suite. |
| `GOVERNANCE.md` §2 rows and the authority graph name the generator; version 1.19 | Check 3; readers of §2 | WRITE | No authority moves. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Repository consistency is CLEAN, Checks 7 and 29 included | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| `scripts/readiness_selftest.ps1` passes, every mutant killed | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| The CONTROL suites pass | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| `ai-map.json` and `repository-index.md` reproduce from their generator | BEFORE_COMPLETION | NONE | NONE | Step 4 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism:
- `scripts/generate-ai-map.ps1`, already the owner of `ai-map.json`.
- Check 7's slot in `scripts/check_repository_consistency.ps1`, and Check 20's trigger list.
- `scripts/readiness_population.ps1` and Check 29, with the Action registry's boundaries table.
- `$script:EvidenceWriteClosure` (SPEC-210).

No new file, registry, schedule, workflow or authority is added.

Added Property: A generated projection that does not reproduce from its sources fails every guard run. A canonical-document contract must carry both projections at approval. A backlog item without a known boundary, or with a crossed one, fails every guard run. Every unaudited surface is a registry member at `B6-EXIT`, so the programme's exit cannot be recorded while one remains.

Causal Negative: At `6c8b500`:
- `generate-ai-map.ps1 -Check` (prototype script, committed bytes) prints `GENERATED STALE` for both files, while the guard is CLEAN.
- With the manifest's target set to `bookings` and coverage to `41 of 78`, the guard is CLEAN after regeneration (CTRL-12).
- The backlog check reports `0 without a trigger` over rows whose triggers had passed (CTRL-14).

Positive Test Design:
- After regeneration, `-Check` exits 0, and a second generation is byte-identical.
- R2: the fixture derives `t_four` NOT DUE and the backlog line `2 live items; DUE NOW 1, NOT DUE 1`.
- R10: once every finding is closed and `t_four` is recorded, a `REACHED` boundary passes.
- Test 230 still admits a manifest contract that carries `ai-map.json`.

Negative Test Design: each of these exits 1, or refuses, with its named problem:
- R16: an unrecorded surface at a `REACHED` exit, `OVERDUE: t_four`;
- R17: a backlog row without a registry boundary, `BACKLOG BOUNDARY`;
- R18: a backlog row whose boundary is `REACHED`, `OVERDUE: backlog item`;
- R19: a backlog without the Live table;
- test 234: a canonical-document contract without the index, `write closure`;
- live: a manifest header change without regeneration fails Check 7 with `GENERATED STALE`.

Non-Empty Population Obligation: the live registry derives 36 implicit surfaces and 10 backlog items. The fixture derives `t_four` and two backlog rows, and R2 asserts their states.

Mutation Obligation: each mutant is written to a disposable copy of the derivation and run against the fixture the pristine copy passed. A kill requires the replacement to have applied and the case to fail without a parse error.

| Mutant | Change | Killed by |
| --- | --- | --- |
| M13 | `NOT-RECORDED` surfaces are not members | R16 |
| M14 | a backlog boundary is not required | R17 |
| M15 | a backlog `OVERDUE` does not fail | R18 |

M1–M12 stay killed by their SPEC-269 cases.

Post-Implementation Proof Obligation: on the final committed bytes, run these in order:
1. canonical `-Finish`: REPOSITORY, CONTROL and CI, plus this contract's Additional Verification;
2. `-Gate -BaseRef origin/main` over this contract's range;
3. `publish_candidate.ps1`, then candidate CI, then exact-SHA promotion to `main`, then `main` CI, then `-Certify` on this contract's own final SHA. CI on Linux is the cross-machine reproduction of `generate-ai-map.ps1 -Check`.

## Implementation Steps

Every file is written LF. The "from" hashes are the committed bytes at `6c8b500`. The "to" hashes were measured on the prototype, held as `spec270-prototype.patch` in the owner's `ORVION-drafts-backup\2026-10-12\inflight` folder.

1. **Check** whether `scripts/generate-ai-map.ps1` contains `param([switch]$Check)`. If absent, apply the prototype exactly, file by file:

   | File | From (LF SHA-256 at `6c8b500`) | To (LF SHA-256, prototype) |
   | --- | --- | --- |
   | `.github/workflows/repository-consistency.yml` | `91f484cb2abdea987f55a8c5affdbb6673221d3ca0e65e29164774cce5b266b9` | `4433299cf539192684feb4deaa6e047c86811961e20a6748afb82ae41a96778e` |
   | `GOVERNANCE.md` | `c5701816c3c586d82fa6986635e97c5b46967d5e00edb2ff12ef5ba1f297dfab` | `e33c3e566b32143ac48db734d57c7ff97c78f8fe701ec75f0ee429819749dbd2` |
   | `_ORVION_CANONICAL/manifest.md` | `c45459591f345b0ef959a389dc801131bd2b0fcdfa77f78f4fc9bb90dcec1e9b` | `a2e807a41001b577afa22afca10e63363281bf8e4b8a9434f121b2fef12db560` |
   | `ai-map.json` | `3b65aa7dcc3ce6b03ecb4d31b7c60e9c8c64d8f31fd64564bf7a01bc40c74a1b` | `6121762755b0382a71e4d40741a9bd8dbe8d6a1d0e4f8ab9ea612ce36665bedb` |
   | `reports/future-backlog.md` | `5e92dc8689491f546d817986fd1fe50600d3b9debbddef05c3a7647bc5266c11` | `4bf32f56ae77cec4171a57c31593e33a4fa087cdf573a513d045141545c3ece5` |
   | `reports/master/MASTER_EXECUTION_PLAN.md` | `d565ab2f0e42e69609c2fb86847d3af61b8d93b7bfcc02bcbe624385ee64a73f` | `6492d1be9337d35c29197116a0e1029bd2bb26ba09b932b7e143d25409ca1059` |
   | `reports/master/MASTER_GAP_REGISTER.md` | `fc012f8cff2ed185cd02f373579c4a10331aac18d2b808034d23877010dbdad2` | `ee990a5caf76ba1e40ad171ecac3768abf4ed9237a24f4dc4179134cd09a115b` |
   | `repository-index.md` | `f89291071ada19c8bc6a125ffc5b3f875beb6d1b8ccf9b828bfcc9116e94e774` | `a193443ec2aa40fe7ab1695e7fc60438fb5e5a865dca65ff0d3de12e8f325d01` |
   | `scripts/check_agent_continuity.ps1` | `925c2394729aa8a61a0f9d87f233a040e2665f34e90cd25f6e318c7049983ef1` | `7903fd13159984632d27f3831eb559f50c3b8bfdcd51ef5a49b81c762338f233` |
   | `scripts/check_repository_consistency.ps1` | `cca8a1d22dd8a7878231547c9f41ba77d19c8897c3ed47a7414ea825bd85ae7e` | `d429b91eeb9e2a8aa1e75aad2b510915085b3dc601af4d29f089a8ea11884a62` |
   | `scripts/generate-ai-map.ps1` | `4a0e762ee59e0ad4a5e93a6e49189f523a1be7c673fdeca0cd3545bd24788a39` | `9ab62179b61840b19225f280a7095d2005814a34d253f3151cc9c4e900e8086b` |
   | `scripts/readiness_population.ps1` | `3cff9254975878c857d6a18d782b5269bb62167201637c56b4949a32b1e7aaf3` | `5ec9e77a0409f804e9bd17ed6eab77e29650188140f34beef9f1888f5ab4e59c` |
   | `scripts/readiness_selftest.ps1` | `338f297db3bf562c70b3e6981f947893a08334f0217679b7786c52b64737e365` | `d90a760e9704a46af94ce16ec689a557d35de8549a6123b9b44cd32414169dad` |
   | `scripts/repository-all.ps1` | `a5fe3a82201cf5e38741fa42a5766a8c9b866d42bf322bbb0488038b217594fb` | `5eed5d63df431d872d15aa87476c08cfc73039ff88dd6108763687df58de57bf` |
   | `scripts/test_agent_continuity.ps1` | `ab05878a3e009011801d0024059858d4c6c7c6ce373ffc8cc2bdb9bbc6c4f584` | `f1e9d45beccd617afc1f227a21893c3000533ab8c43357b92882185d34537f68` |

   `ai-map.json` and `repository-index.md` are then regenerated, never copied, and a generator run on the applied bytes must reproduce their "to" hashes.

   If any existing file holds bytes other than its "from" hash, or a resulting hash differs, stop.
2. **Check** for an Execution Log entry recording step 1. If absent:
   - run `scripts/generate-ai-map.ps1 -Check` and require exit 0;
   - run `scripts/readiness_population.ps1 -Registry` and require `REGISTRY: complete`;
   - run `scripts/readiness_selftest.ps1` and require `0 failed`;
   - commit step 1 with an Execution Log entry that quotes the three lines.
3. **Check** for a `Local certification` Execution Log entry. If absent:
   - commit the Runtime Checkpoint as `Resume Step: DONE`;
   - run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` once, alone, on the clean committed tree;
   - require `LOCAL_CERTIFY: READY`.
4. **Check** whether the manifest's `Last Completed` begins `**SPEC-270`. If not:
   - set it to this contract, with the Active pointer `None.`;
   - leave `Next capability` and the open-decision line as step 1 wrote them;
   - keep the manifest within 7000 characters and 1200 per line;
   - regenerate with `scripts/generate-ai-map.ps1`.

   Then Review, Complete, and publish by the standing procedure.

## Acceptance Criteria

- [x] `scripts/generate-ai-map.ps1` writes `ai-map.json` and `repository-index.md` LF, with no timestamp, and two runs give identical bytes.
- [x] `scripts/generate-ai-map.ps1 -Check` exits 0 on the committed tree and 1 naming each stale file otherwise.
- [x] Check 7 runs the reproduction, and Check 20 and `repository-consistency.yml` cover the generator.
- [x] `scripts/repository-all.ps1` no longer generates the index itself.
- [x] The write closure binds `ai-map.json` and `repository-index.md` to any `_ORVION_CANONICAL/*.md` contract, and test 234 passes.
- [x] Assertion 158 requires the three live_state names and no timestamp.
- [x] `scripts/readiness_population.ps1 -Registry` lists every `NOT-RECORDED` surface at `B6-EXIT` and every Live deferred item with its state, and exits 0 with `REGISTRY: complete`.
- [x] `scripts/readiness_selftest.ps1` reports 33 passed, 0 failed, with M1–M15 killed.
- [x] `reports/future-backlog.md` holds the Live deferred items table, each row with a registry boundary, and the triage record.
- [x] The Action registry states the two kinds of member that need no row, and OPS-4 is pruned from its row.
- [x] The register carries CTRL-12, CTRL-13 and CTRL-14 as FIXED, and OPS-4 as FIXED at its trigger.
- [x] The manifest copies no unguarded figure, names the selector for the next slice, and stays within 7000 characters and 1200 per line.
- [x] `GOVERNANCE.md` §2 names the generator for both projections, version 1.19.
- [x] The CONTROL suites pass.
- [x] Repository consistency is CLEAN.
- [x] `git diff --check` is clean.

## Execution Log

### 2026-10-12 — Gate 1 approval and execution started

- **Authority:** the owner's written authorization of 2026-10-12 approves Gate 1 and Gate 2 for this contract, by number, Draft path and contract SHA-256 `1afd913f9dd03d49e3c3a243580af26e11cfb12e05ba3f3528b6b2ecfac8593a`. It authorizes the repository-only lifecycle through exact-SHA promotion and `-Certify`, and no database deployment. The Draft was committed at `022646f`, and its blob hashes to the approved value (26557 bytes, LF). Approval was committed at `21a5e52`; `-Gate -BaseRef 022646f` returned `APPROVAL_EVIDENCE: PASS`.
- **Verified before acting:**
  - HEAD was the Approve commit, on top of SPEC-269's Complete commit `6c8b500`, which is `origin/main`;
  - every one of the fifteen files holds its pinned "from" bytes at `6c8b500`. The manifest is compared with `Active Change Request: None.` restored. `ai-map.json` equals its `6c8b500` bytes except `generated_at` and the Approve pointer;
  - `scripts/generate-ai-map.ps1` does not contain `param([switch]$Check)`;
  - `core.autocrlf` is `true`, from the system configuration only.
- **Not authorized here:** any database, Primary, Secondary, n8n, Google or Docker surface; TEST-4 and PERF-2 work.

### 2026-10-12 — Step 1 applied; Step 2 verified

- **Step 1.** `scripts/generate-ai-map.ps1` did not contain `param([switch]$Check)`. Each file was checked against its "from" hash, then written LF and checked against its "to" hash:
  - The thirteen copied files match both their "from" and "to" hashes.
  - The manifest is compared with `Active Change Request: None.` restored. The Approve commit's pointer stays until Step 4.
  - `ai-map.json` and `repository-index.md` were regenerated by the applied `scripts/generate-ai-map.ps1`, not copied. `repository-index.md` hashes to `a193443e…`. `ai-map.json` hashes to `61217627…` with the Approve pointer read as `None.`; the generator no longer stamps a time, so no other field differs.
- **Step 2:**
  - `scripts/generate-ai-map.ps1 -Check`: `GENERATED: ai-map.json and repository-index.md reproduce from their sources`, exit 0.
  - `scripts/readiness_population.ps1 -Registry`: `registry: DUE NOW 58, BLOCKED 21, NOT DUE 36, ACCEPTED RESIDUAL 27, FUTURE-ONLY 58`, `backlog: 10 live items in reports/future-backlog.md; DUE NOW 1, NOT DUE 9` and `REGISTRY: complete -- every open member is classified once, and nothing is overdue`, exit 0.
  - `scripts/readiness_selftest.ps1`: `== 33 passed, 0 failed ==`, exit 0.
  - `REPOSITORY CONSISTENCY: CLEAN`, Checks 7 and 29 included. `git diff --check` is clean.

### 2026-10-12 — Local certification (Step 3)

- The Runtime Checkpoint was committed as `Resume Step: DONE` at `ca7b5a6`.
- **Memory.** The pre-approval re-run of `test_agent_continuity.ps1` had been stopped by the host at 1.7 GB free. Before this run, the eleven local ORVION containers were stopped with `docker stop` and the WSL page cache was dropped, raising free memory from 1.9 GB to 3.1 GB. No Docker setting was changed. `-Finish` for this contract runs no DATABASE profile, so it needs no container. Free memory read 4.4 GB and 4.8 GB during the run. The containers were started again afterwards, all healthy.
- Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran once, alone, on that clean committed tree, under `scripts/run_timed.ps1` (`concurrent=0`) and followed by `scripts/watch_run.ps1`. `core.autocrlf` was `true`, from the system configuration only.
- It ran profiles CI, CONTROL and REPOSITORY plus this contract's Additional Verification, and reported `LOCAL_CERTIFY: READY` in 33.6 min, exit 0.
- Every step passed:
  - `test_agent_continuity.ps1` in 21.0 min, in full, test 234 and assertion 158 included;
  - `test_cold_start_state_guard.ps1` in 5.4 min;
  - `test_status_contradiction_guard.ps1`, `test_primary_ledger_guard.ps1` and `test_future_date_guard.ps1`;
  - repository consistency, Checks 7 and 29 included;
  - `git diff --check`;
  - `readiness_selftest.ps1`, `readiness_population.ps1 -Registry` and `generate-ai-map.ps1 -Check`.

### 2026-10-12 — Step 4

- The manifest's `Last Completed` names this contract and its Active pointer is `None.`. `Next capability` and the open-decision line are as Step 1 wrote them. It holds 6718 characters, its longest line 1144.
- `scripts/generate-ai-map.ps1` regenerated `ai-map.json`; `repository-index.md` reproduced byte-identical. `-Check` prints `GENERATED: ai-map.json and repository-index.md reproduce from their sources`.

## Verification Notes

### 2026-10-12 — Independent Review of the execution commit `ca7b5a6`

The review was made by a separate agent, read-only on the repository. Every experiment that changed a file ran in a disposable clone at `ca7b5a6` under the job's scratch directory. It checked the committed tree against the approved Draft `022646f` and its pinned hashes, and did not rely on the Execution Log.

1. **Contract.** The `022646f` blob hashes to `1afd913f…8593a`, 26557 bytes. Split by heading, only Status, Runtime Checkpoint and Execution Log differ at `ca7b5a6`. Every frozen section is byte-identical.
2. **Scope.** `6c8b500..ca7b5a6` changes exactly the sixteen Write Scope paths. This contract is the only file added, and nothing is deleted.
3. **Hashes.** All fifteen files match their "from" hash at `6c8b500` and their "to" hash at `ca7b5a6`, with the manifest's pointer and `ai-map.json`'s `active_change_request` read as `None.`. Every file has 0 CR.
4. **Generator (criteria 1–4).**
   - Two runs in the clone gave byte-identical files with no CR, no BOM and no `generated_at`.
   - `-Check` exits 0 on the committed tree and does not write. It exits 1 naming the stale files when:
     - a `31_schema_draft.md` version changes, naming both files;
     - the manifest's phase changes, naming `ai-map.json` only;
     - `repository-index.md` is edited by hand, naming that file only.
   - Check 7 fails the guard on the `31_schema_draft.md` change, which none of its three by-value comparisons covers.
   - Check 20 and both path lists in `repository-consistency.yml` name the generator. `repository-all.ps1` only calls it.
5. **Approval rule (criteria 5–6).** Both closure entries use `^_ORVION_CANONICAL/[^/]+\.md$`. Test 234 exists and passes inside `test_agent_continuity.ps1`. Assertion 158 requires the three `live_state` names and no timestamp.
6. **Registry (criteria 7–11).**
   - `-Registry` exits 0, reading DUE NOW 58, BLOCKED 21, NOT DUE 36, ACCEPTED RESIDUAL 27, FUTURE-ONLY 58; backlog 10 live items, DUE NOW 1, NOT DUE 9; `REGISTRY: complete`.
   - The 36 implicit members equal the 36 `NOT-RECORDED` rows of `MASTER_SURFACE_DISPOSITION.md`.
   - `readiness_selftest.ps1`: 33 passed, 0 failed, R16–R19 passed, M1–M15 killed.
   - Docker 2375 is a live item at `B6-EXIT`, DUE NOW.
   - The plan's two paragraphs are present, and OPS-4 is pruned from its row.
   - CTRL-12, CTRL-13 and CTRL-14 are FIXED by this contract, and OPS-4 is FIXED at its trigger.
7. **Manifest and documents (criteria 12–13).** None of the removed figures remains. The selector is named. `GOVERNANCE.md` is at 1.19, with the generator named for both projections.
8. **Checks (criteria 14–16).** The `-Finish` log at `ca7b5a6` holds every suite PASS and `LOCAL_CERTIFY: READY`. Repository consistency is CLEAN, and `git diff --check 6c8b500 HEAD` is clean.
9. **Nothing weakened.**
   - No assertion, case or check was removed.
   - Assertion 158 and the write closure are stricter.
   - The backlog summary that could not fail is replaced by one that can.
   - Dated backlog sections and register rows are appended to, not rewritten. The previous `Last updated:` is kept as `Previously:`.
10. **Observations, not blocking, and outside this contract's approved bytes:**
    - If the Live deferred items table's `Boundary` header is renamed, its rows are skipped and the check reports `0 live items` and passes. R19 covers only a missing table. This is an unguarded path in the new control, and it needs its own contract.
    - Check 7 skips the reproduction when `scripts/generate-ai-map.ps1` is absent. Check 20 still names that file.
    - A comment in `generate-ai-map.ps1` says "Ordinal order", while the code sorts with the invariant culture, as the Draft states.

Verdict: Confirmed Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created, or deleted.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

- **Prototype evidence, 2026-10-12, on a scratch worktree at `6c8b500`:**
  - The prototype patch, `spec270-prototype.patch` (83,111 bytes), touches the 15 files of step 1. Repository consistency is CLEAN, and `git diff --check` is clean.
  - `scripts/readiness_population.ps1 -Registry`: DUE NOW 58, BLOCKED 21, NOT DUE 36, ACCEPTED RESIDUAL 27, FUTURE-ONLY 58; backlog 10 live items (DUE NOW 1, NOT DUE 9); `REGISTRY: complete`. The register has 491 ids, 352 settled.
  - Live proofs on the prototype, each reverted:
    - L1: a canonical header changed without regeneration fails Check 7 for both files.
    - L2: regeneration restores CLEAN.
    - L3: a hand edit to `repository-index.md` fails.
    - L4: a truncated `ai-map.json` fails, and one re-run restores it.
    - P1: a body-only canonical edit regenerates byte-identical outputs, so the write closure permits rather than forces an edit.
    - P2: `-Check` changed none of 951 files while the projections were stale.
    - P3: no BOM.
    - An LF-only checkout and the CRLF checkout regenerate identical bytes. `-Check` costs 0.66 s.
  - **First full run:** `test_cold_start_state_guard` 42/0 (6.2 min), `test_future_date_guard` 18/0, `test_status_contradiction_guard` 33/0, `test_primary_ledger_guard` 13/0, `readiness_selftest` 33/0, `test_agent_continuity` 425/0 (21.5 min, test 234 included).
    - Four of those suites ran while a stray `core.autocrlf=false` sat in the shared `.git/config`, written by a scratch-worktree command; it was found by `git diff --check` and removed.
  - **Re-run with the setting corrected, under `run_timed.ps1` and `watch_run.ps1`:**
    - the five guard and readiness suites pass with identical counts;
    - `test_agent_continuity` was stopped by the host for low memory at 19.7 of about 21.5 min, with no failure reported before the stop.
    - Step 3's `-Finish` runs it again on the committed bytes.
  - **Triage corrected during review:** the invitation and activation lifecycle was first closed as done. It has no record, timestamps or events, so it was restored as a live item.
- **What stays authored, by design.** These are never generated:
  - every finding's status, class, boundary and treatment;
  - every owner decision;
  - each slice's choice, recorded by its own contract;
  - each backlog item's boundary.

  A generator never invents policy, approvals or history.
- **Owner action, outside this contract:** disable "Expose daemon on tcp://localhost:2375 without TLS" in Docker Desktop (Settings → General), then run the environment health check. The backlog row closes when that is recorded.
