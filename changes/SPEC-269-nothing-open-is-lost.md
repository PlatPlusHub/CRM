# Change Request — SPEC-269

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Make every open obligation in ORVION classified in one place, with its decider, its latest safe boundary and its treatment, and make that completeness a property every guard run enforces. The readiness gate's prose classes become an Action registry in `MASTER_EXECUTION_PLAN.md`: a boundaries table and one classification row per open id. `scripts/readiness_population.ps1` derives each id's trigger state from them. A new Check 29 of `scripts/check_repository_consistency.ps1` runs it, so Boot, Gate, `-Finish` and CI fail on any of these:
- an open finding, surface or owner decision that no row classifies;
- an id that two rows classify;
- an unknown id;
- an off-vocabulary class or boundary;
- an empty cell;
- an open item whose boundary is REACHED.

The same contract makes the four owner-ratified decision rules guard-protected, as `AGENTS.md` already claims, and records the 2026-10-11 assessment's open owner decisions, which existed only in a chat session.

## Business Reason

- **The owner's objective of 2026-10-12:** ORVION keeps its knowledge, open obligations, priorities and agreed decisions in the repository, not in any assistant's memory. A fresh agent must learn from the repository alone:
  - what is open, and why;
  - how important it is, and when it is due;
  - what it waits on, and who decides;
  - how it closes.

  The objective is owner-approved; the mechanism is engineering's choice.
- **CTRL-10, reproduced at `f6c30d0` while proving this contract.** The control suite failed INH-M15 on this Windows checkout, on unmodified `main` exactly as on the prototype. Its multi-line mutant anchor is written with a bare LF, and the CRLF working copy never matched it, so every CONTROL contract's `-Finish` failed here. The fix rides with this contract because its own `-Finish` is the trigger. A test-side newline translation was chosen over a repository-wide or path-specific `.gitattributes` rule. It is the smallest blast radius and the suite's own convention (the CRLF cases at `Ctrl4Crlf` and `$wfCrlf`), and it weakens no assertion.
- **CTRL-9, reproduced at `f6c30d0`.** `scripts/readiness_population.ps1` exits 1 with `UNCLASSIFIED (1): PAY-9`, while `scripts/check_repository_consistency.ps1` prints `REPOSITORY CONSISTENCY: CLEAN`.
  - SPEC-264 registered PAY-9 OPEN on 2026-10-11, and the gate section never classified it.
  - The derivation existed, but nothing that Boot, Gate, `-Finish` or CI runs ever called it.
  - The classes were prose bullets, so no trigger state could be derived from them.
- **GOV-25, reproduced at `f6c30d0`.** `AGENTS.md` §3 says Check 27 fails if the four decision rules leave `ENGINEERING_METHOD.md`.
  - With the paragraph deleted in a scratch copy, Check 27 printed `all 18 relocated owner-ratified rules are present`.
  - The owner's permanent principles rested on a sentence, not a guard.
- **Knowledge that existed only in chat.** The 2026-10-11 assessment proposed nine owner decisions, D1–D9. The owner decided D4, which SPEC-265 carries. The other eight, with the finance foundation design, the workstreams and the event-based roadmap, existed only in a session transcript. Six become register rows OD-1, OD-2, OD-3, OD-5, OD-8 and OD-9. D6 and D7 already have rows: DC-10/DC-28 and OPS-1. The analysis becomes an immutable history report.
- **What was reused, and what was rejected.** Each existing mechanism already does part of the job:
  - the register owns status;
  - the disposition record owns surfaces;
  - Check 25 forces every owner decision onto the manifest's boot line;
  - `GOVERNANCE.md` §2 already routes every kind of fact to one home;
  - the gate already defines the population, the five classes and boundary-based release consequences;
  - the guard already runs at Boot, Gate, `-Finish` and in CI.

  What was missing was execution of the rule, a parseable classification, boundary states, and the capture of chat-only decisions. Three alternatives were rejected:
  - **A committed, generated registry file.** It would duplicate the register's titles and statuses, and every Batch 6 contract would have to regenerate it. The classification table is the committed view, the guard keeps it complete, and `-Registry` prints the join.
  - **A scheduled job.** Nothing changes between commits.
  - **A Boot code change.** Boot already runs the guard, and its NEXT line already points at the registry.

## Risks

- **Every future contract that registers an open finding must classify it in the same change.** That contract therefore needs `MASTER_EXECUTION_PLAN.md` in its Write Scope. A contract that settles findings needs nothing new: a settled id still classified reads COMPLETED and is pruned at the next edit. Omitting the plan is caught at the latest by Check 29 in `-Finish`, before any irreversible step that follows `-Finish`. A database contract that adds an open finding after its Primary deployment would meet it after the deployment, so such a contract carries the plan in its Write Scope.
- **Fail-closed on a crossed boundary.** Setting a boundary to `REACHED` while its items are open fails every guard run. That is the intended release safeguard. Only a contract moves a state, and today only `B6-EXIT` is NEXT and nothing is REACHED.
- **Boot cost.** Check 29 adds about 2 seconds to each guard run (measured 1.9 s).
- **The classification is judgement, and the guard cannot check it.** The guard proves completeness and consistency, not that a class is right. Classes stay a dated reading of the register, and the register wins where they differ.
- **Order with the other two contracts.** SPEC-265 and SPEC-268 also edited the register and the manifest, and SPEC-265 the gate section. Both are Complete, and this contract is re-pinned on their final bytes. SPEC-265's GADS-1 classification becomes one row in the new table.
- **A boundary is recorded, not observed (CTRL-11).** The guard holds no Primary credential by design, so a production boundary crossed outside a contract would leave its state `NOT REACHED`, and Check 29 would not fail. Containment: provisioning needs `service_role`, and READY requires the gate's evaluation. Read-only on 2026-10-12, Primary holds 0 tenants and 0 business rows, so every recorded state is true today. CTRL-11 is classified with boundary `GATE-EVAL`, so it turns OVERDUE if that evaluation is reached without the confirmation it demands.
- **A finding cannot vanish silently in one direction only.** Deleting a register row while its registry row remains fails (F4). Deleting both the register row and its registry row in one change is visible only in the diff, and the register's own "never delete" rule governs that.
- **No product, database, Primary, Secondary, n8n or Google surface is touched.**

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-269-nothing-open-is-lost.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/history/delivery-assessment-2026-10-11.md`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `scripts/test_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `.github/workflows/repository-consistency.yml`
- `.github/workflows/orvion-acceptance.yml`
- `ENGINEERING_METHOD.md`
- `AGENTS.md`
- `GOVERNANCE.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `changes/TEMPLATE.md`
- `CR_LIFECYCLE.md`
- `scripts/check_agent_continuity.ps1`
- `scripts/publish_candidate.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/test_status_contradiction_guard.ps1`
- `scripts/test_primary_ledger_guard.ps1`
- `scripts/test_future_date_guard.ps1`
- `.github/workflows/migration-ci.yml`
- `.github/workflows/agent-control.yml`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/future-backlog.md`
- `reports/evidence/primary-ledger-evidence.json`
- `supabase/migrations/`
- `supabase/tests/`
- `_ORVION_CANONICAL/32_execution_roadmap.md`

## Required Reading

- `reports/master/MASTER_EXECUTION_PLAN.md`: the Pre-Production Readiness Closure gate
- `scripts/readiness_population.ps1` and `scripts/readiness_selftest.ps1`
- `scripts/check_repository_consistency.ps1`: Checks 20, 25 and 27, and the closing summary
- `ENGINEERING_METHOD.md` §2 "Decision and architecture discipline" and §3 "Measurement integrity"
- `GOVERNANCE.md` §2 "Single Source of Truth (SSOT) matrix — the core rule"

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- `pwsh -NoProfile -File scripts/readiness_selftest.ps1`
- `pwsh -NoProfile -File scripts/readiness_population.ps1 -Registry`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| The gate section's classification moves from prose to the Action registry tables; SUB-4's row is pruned; PAY-9, OD-1…OD-9, APP-1 and CTRL-11 join; the label `REQUIRED CAPABILITY` names a Day-1 build canon requires and nothing implements, distinct from a reproduced defect | `scripts/readiness_population.ps1`; Check 2 (finding status across masters); any reader of the gate | WRITE | Each open id kept the class its prose placement gave it: the mapping was derived mechanically from the prose subsections and checked one by one. Rebased prototype: Check 2 CLEAN, and `-Registry` prints DUE NOW 22, BLOCKED 21, NOT DUE 36, ACCEPTED RESIDUAL 28 and FUTURE-ONLY 58 with no problem. |
| `scripts/readiness_population.ps1` gains the registry: it parses both tables, derives trigger states, adds `-Registry` and `-BacklogPath`, and writes `<tsv>.registry.tsv` beside `-Tsv`. Exit 1 now also covers duplicate, unknown, off-vocabulary, empty and OVERDUE | Check 29 (new); `scripts/readiness_selftest.ps1`; any manual `-Tsv` reader | WRITE | The population TSV keeps its columns and rows (R2 and R6). The register, surface and decision summary lines are unchanged. Exit 3 for a ref without the section is unchanged (R1). |
| `scripts/check_repository_consistency.ps1`: new Check 29; Check 20 adds `scripts/readiness_population.ps1`; Check 27 adds seven anchors | `-Boot`, `-Gate`, `-Finish` (Repo-Guard); `repository-consistency.yml`; `orvion-acceptance.yml` (via `-Gate`); `test_future_date_guard.ps1`, which runs the guard in a sandbox copy | WRITE | Prototype: guard CLEAN, and the four guard self-tests and `test_agent_continuity.ps1` pass (Notes). Check 29 adds about 2 s per run. |
| Both workflows run `readiness_selftest` in their suite loop; `repository-consistency.yml` triggers on the two readiness scripts | GitHub Actions; Check 20; `test_agent_continuity.ps1` assertion 142 (acceptance runs the four calibration suites with exit checks) | WRITE | Check 20 derives the selftest's trigger requirement from the loop, and both lists carry it. Assertion 142 still finds its four suites. |
| `ENGINEERING_METHOD.md` §3 gains "Nothing open is lost (owner-ratified 2026-10-12)" | Check 27 (new anchor); readers routed by `AGENTS.md` | WRITE | Added beside "A lesson is promoted". No existing rule changes. |
| `AGENTS.md` §4 routing table gains one row; `GOVERNANCE.md` §2's execution-plan row names the registry, version 1.18 | Check 3 (router integrity); Check 26 (section pointers); every Boot reader | WRITE | Prototype: Checks 3 and 26 CLEAN. No routing row is removed. |
| Register: new rows CTRL-9, CTRL-10 and GOV-25 (FIXED by this contract); OD-1, OD-2, OD-3, OD-5, OD-8 and OD-9 (OPEN, PROPOSED, decider `owner:`); APP-1 (OPEN, a required capability: no client application exists) and CTRL-11 (OPEN, an accepted residual: boundaries are recorded, not observed); a new `Last updated:` line | Checks 2, 11, 14, 21 and 25; the registry | WRITE | Check 25 demands the six OD ids on the manifest line, and they are there. Universe 488 ids: 348 settled, 140 open. No other row changes. |
| Manifest: open-decision line adds the six OD ids; one line points at the registry; three historical sentences are removed to stay within Check 5's 7000-character budget | Boot NEXT and START_CONTEXT; Checks 5, 7, 11, 14 and 25; `ai-map.json` | WRITE | 6778 characters, longest line 1152. The removed sentences are history the register and Git keep: the 2026-09-09 closure note, SPEC-160's no-report note, and SPEC-224's zero-row precheck. `Next capability` and `Active Change Request` are unchanged. |
| `reports/history/delivery-assessment-2026-10-11.md` (new, Historical-Immutable, with a seven-field HANDOFF) | Checks 4 and 23; the OD rows' Source | WRITE | Prototype: Checks 4 and 23 CLEAN. |
| `scripts/test_cold_start_state_guard.ps1`: its CONTROL case read the open-decision count as a pinned 3, and now counts the manifest's enumeration itself; a new section F attacks Checks 27 and 29 through the real guard on a sandbox copy (F1 four rules deleted, F2 a registry row removed, F3 a boundary REACHED, F4 a register row deleted) | The CONTROL profile; `repository-consistency.yml` and `orvion-acceptance.yml` | WRITE | The pinned 3 failed as soon as OD-1…OD-9 were recorded, which made recording a decision cost a test edit. The count is now derived independently of the guard, from the bold ids before the line's first full stop. Prototype: 42 passed, 0 failed, 5.5 min. Section F makes the live proofs permanent, and CI runs it. |
| `scripts/test_agent_continuity.ps1`: `CertMutant` writes a bare LF in an anchor as the evaluator's own line ending (CTRL-10) | The CONTROL profile, ORVION Acceptance and Agent Control; every mutant of family CERT-INHERIT | WRITE | At `f6c30d0` on this workstation, both an unmodified `main` worktree and the prototype reported 423 passed, 1 failed (INH-M15, `installed=False count=0`) in 29.9 min each. After the change, the anchor matches once on the CRLF checkout, and the full suite result is in Notes. The exact-once count, the installed check, and the pristine and mutated verdict assertions are unchanged. On an LF checkout (CI) the anchor and the result are unchanged, because the translation applies only to a bare LF. |
| SPEC-265 and SPEC-268 (Complete) | Their committed register, plan and manifest edits | VERIFY | This contract's "from" hashes are their Complete bytes at `04f541e`. Their freshness entries stay as `Previously:`, GADS-1's queue row becomes a registry row classified `REQUIRED CAPABILITY`, and RCPT-1 to RCPT-4 stay settled, so the registry does not list them. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Repository consistency is CLEAN, Check 29 included | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| `scripts/readiness_selftest.ps1` passes, every mutant killed | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| The CONTROL suites pass | BEFORE_COMPLETION | NONE | NONE | Step 3 |
| `ai-map.json` matches its generator | BEFORE_COMPLETION | NONE | NONE | Step 4 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism:
- `scripts/readiness_population.ps1`: the population rule, which reads its vocabularies from the guard's own AST.
- `scripts/check_repository_consistency.ps1`: its check framework, and Repo-Guard, which already runs it at Boot, Gate and `-Finish`.
- Check 20's derivation of trigger requirements from the workflow's suite loop.
- Check 25's decision surfacing, and Check 27's anchor list.

Nothing else is added: no generated file, schedule, workflow, database object or Boot code. The register keeps every status; the plan keeps every class and boundary.

Added Property: Every guard run fails when any of these holds:
- an open register finding, open surface or open owner decision is not classified exactly once in the Action registry;
- a row names an unknown id, an off-vocabulary class or boundary, or an empty Decides or Treatment;
- an open id's boundary is REACHED.

Each id's trigger state is derived, never typed: COMPLETED, OVERDUE, BLOCKED, ACCEPTED RESIDUAL, FUTURE-ONLY, DUE NOW or NOT DUE. Check 27 also fails when the four decision rules, their ratification line or the capture rule leave `ENGINEERING_METHOD.md`.

Causal Negative: At `f6c30d0`, the guard prints `REPOSITORY CONSISTENCY: CLEAN` while `scripts/readiness_population.ps1` prints `UNCLASSIFIED (1): PAY-9` and exits 1. With the four-rules paragraph deleted from `ENGINEERING_METHOD.md`, Check 27 prints `all 18 relocated owner-ratified rules are present`. Re-measured at `04f541e`, where SPEC-265 had named PAY-9: with GADS-1's queue row removed, `scripts/readiness_population.ps1` prints `UNCLASSIFIED (1): GADS-1` and exits 1 while the guard prints `REPOSITORY CONSISTENCY: CLEAN`. `ENGINEERING_METHOD.md` and the guard are byte-unchanged since `f6c30d0`, so the Check 27 negative stands.

Positive Test Design: R2 is the fixture with every state by its rule, exit 0. R10: closing the items in the register clears OVERDUE and reads COMPLETED. R11: a boundary moved to NEXT makes its items DUE NOW. R13: admitting a newly registered finding with a row clears the failure. R1 replays 523888d's recorded population, and R6 matches the live universe to Check 11's subjects. On the live repository, the prototype guard is CLEAN.

Negative Test Design: each of these exits 1 with its named problem:
- R3: a member no row classifies (UNCLASSIFIED);
- R7: an unknown id;
- R8: an id classified twice;
- R9: a REACHED boundary with open items (OVERDUE);
- R12: a newly registered open finding;
- R14: an off-vocabulary class and boundary;
- R15: an empty Treatment;
- R5: a vocabulary the authority no longer defines.

Live: removing PAY-9's row makes the guard report `UNCLASSIFIED: PAY-9`, and setting `B6-EXIT` REACHED reports each open B6-EXIT item OVERDUE. Deleting the four-rules paragraph fails Check 27.

Non-Empty Population Obligation: the live registry derives 165 members, with no problem; the fixture derives 12 ids across 7 states, `REQUIRED CAPABILITY` among them. R2 asserts the fixture's exact states, and R6 asserts a live universe above 400.

Mutation Obligation: Each mutant is written to a disposable copy of the derivation and run against the same fixture the pristine copy passed. A kill requires the replacement to have applied and the case to fail without a parse error.

| Mutant | Change | Killed by |
| --- | --- | --- |
| M1 | settled state ignored | R2 |
| M2 | shared rows not split | R2 |
| M3 | range cell dropped | R2 |
| M4 | decision prose read as state | R2 |
| M5 | OVERDUE rule removed | R9 |
| M6 | COMPLETED rule removed | R10 |
| M7 | the decision line keeps nothing open | R2 |
| M8 | duplicates accepted | R8 |
| M9 | unknown ids accepted | R7 |
| M10 | unclassified not failed | R3 |
| M11 | NEXT ignored | R11 |
| M12 | empty cells accepted | R15 |

Post-Implementation Proof Obligation: on the final committed bytes, run these in order:
1. canonical `-Finish`: REPOSITORY, CONTROL and CI, plus this contract's Additional Verification;
2. `-Gate -BaseRef origin/main` over this contract's range;
3. `publish_candidate.ps1`, then candidate CI, then exact-SHA promotion to `main`, then `main` CI, then `-Certify` on this contract's own final SHA.

## Implementation Steps

Every file is written LF. The "from" hashes are the committed bytes at `04f541e`, SPEC-268's Complete commit, and the "to" hashes were measured on the prototype rebased onto it, held as `spec269-on-268.patch` in the owner's `ORVION-drafts-backup\2026-10-12\inflight` folder.

1. **Check** whether `scripts/check_repository_consistency.ps1` contains `== Check 29: the action registry`. If absent, apply the prototype exactly, file by file:

   | File | From (LF SHA-256 at `04f541e`) | To (LF SHA-256, rebased prototype) |
   | --- | --- | --- |
   | `.github/workflows/orvion-acceptance.yml` | `ad9d51ad5f67285d90c4e0acf647429fbe42b6765ce30f9eb0324b8770c0cacf` | `c1438b38767d98dd86b517762f10e320c40aa02b7a3e054bc5a233da4ce4de0d` |
   | `.github/workflows/repository-consistency.yml` | `ee2719689c532f48348b65be84911321a69c2c93e2e44db0b8e446e6f21a13cf` | `91f484cb2abdea987f55a8c5affdbb6673221d3ca0e65e29164774cce5b266b9` |
   | `AGENTS.md` | `2d558ed3d1b3f4806f360356969a081daabc8a76be58e787322570d83389f82b` | `2e88469125737a11bb661e1972368a705733f59be4ba30fa61b78e35f7e68989` |
   | `ENGINEERING_METHOD.md` | `4e3527b0ad41c02bf85cc44301291ef0949c77b16400ac91b3b51d8b2ab0f238` | `8bf09f81986a4b2fb94055a59ca9fa7a1297acc089205db1df3d57e9d108df91` |
   | `GOVERNANCE.md` | `306ee2c206ab2e5f36c8bc0f81b031f0024499d1d785ac1d3fa31abd6f8f2e86` | `c5701816c3c586d82fa6986635e97c5b46967d5e00edb2ff12ef5ba1f297dfab` |
   | `_ORVION_CANONICAL/manifest.md` | `b611dc972b209d80fb561571f4dd2185105cf524dcb78cceb3543dcfe172e60d` | `d70e89b8aa8eab05c60987554f02944f6d22b19c0905462f7070782c31911ef6` |
   | `ai-map.json` | `468885f2f0eb175ac1a245d7ab85af99612aba9afd4f68416f03332f437938a0` | `5e6b0be4db3da7308097d9ae17462a7fa4a2b36923f97e7c3e61a4e500a4e541` |
   | `reports/history/delivery-assessment-2026-10-11.md` | new | `58676f70e7ef342752d40b9908d3e30f0d85825f5dda989f784c1fe446c565a9` |
   | `reports/master/MASTER_EXECUTION_PLAN.md` | `029646d70ef5ac1f0df0e03d76e463f4b95beb9555ed0cbf8da00eca1f44a8b4` | `d565ab2f0e42e69609c2fb86847d3af61b8d93b7bfcc02bcbe624385ee64a73f` |
   | `reports/master/MASTER_GAP_REGISTER.md` | `64880a3e15761b5f5cc6238cb19b95002b6ee87f093257ef85d359090bb222af` | `fc012f8cff2ed185cd02f373579c4a10331aac18d2b808034d23877010dbdad2` |
   | `scripts/check_repository_consistency.ps1` | `c74c3828861862f1890432d189569f240157ade92df5be4249b3db723960cd2f` | `cca8a1d22dd8a7878231547c9f41ba77d19c8897c3ed47a7414ea825bd85ae7e` |
   | `scripts/readiness_population.ps1` | `6392f0c4a0336db01133021f721b65746e50fd8cb335ecc0618ef47a8240d611` | `3cff9254975878c857d6a18d782b5269bb62167201637c56b4949a32b1e7aaf3` |
   | `scripts/readiness_selftest.ps1` | `62f27dcd0e48d464d3c9ab1d78cc5f0b053dea639c23194daddfe45789e3c978` | `338f297db3bf562c70b3e6981f947893a08334f0217679b7786c52b64737e365` |
   | `scripts/test_agent_continuity.ps1` | `2ed7975ef33dd9441704765a0a21f3db0214a410c46df71608cd14d9c2acbed3` | `ab05878a3e009011801d0024059858d4c6c7c6ce373ffc8cc2bdb9bbc6c4f584` |
   | `scripts/test_cold_start_state_guard.ps1` | `14d3fcdc9019e6db3663316cef70764ac4614795bc64ef331f618e75b8bf8f9e` | `22fb28d46f905276b284f54e5b0a99bb6343749551475842b9365a5d9c380cb5` |

   `ai-map.json` is then regenerated, never copied: its "to" hash is the prototype's regeneration, and a generator run on the applied bytes must reproduce it.

   If any existing file holds bytes other than its "from" hash, or a resulting hash differs, stop.
2. **Check** for an Execution Log entry recording step 1. If absent, run `scripts/readiness_population.ps1 -Registry` and require `REGISTRY: complete`. Run `scripts/readiness_selftest.ps1` and require `0 failed`. Commit step 1 with an Execution Log entry that quotes both lines.
3. **Check** for a `Local certification` Execution Log entry. If absent:
   - commit the Runtime Checkpoint as `Resume Step: DONE`;
   - run `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` once, alone, on the clean committed tree;
   - require `LOCAL_CERTIFY: READY`.
4. **Check** whether the manifest's `Last Completed` begins `**SPEC-269`. If not:
   - set it to this contract, with the Active pointer `None.`;
   - leave `Next capability` and the open-decision line as step 1 wrote them;
   - keep the manifest within 7000 characters and 1200 per line;
   - regenerate `ai-map.json` and convert it to LF.

   Then Review, Complete, and publish by the standing procedure.

## Acceptance Criteria

- [x] The gate section of `MASTER_EXECUTION_PLAN.md` holds the Action registry, with its state rules and both tables.
- [x] The boundaries table has exactly one `NEXT` (`B6-EXIT`) and nothing `REACHED`.
- [x] The classification table classifies every derived open member exactly once, including PAY-9, OD-1…OD-9, APP-1 and CTRL-11.
- [x] The class vocabulary holds the five release classes plus `REQUIRED CAPABILITY`, `TERMINAL IN SUBSTANCE` and `SURFACE`, in the section and in `scripts/readiness_population.ps1`.
- [x] `scripts/readiness_population.ps1 -Registry` exits 0 with `REGISTRY: complete`.
- [x] `scripts/readiness_selftest.ps1` reports 26 passed, 0 failed, with M1–M12 killed.
- [x] Check 29 runs in every guard run of `scripts/check_repository_consistency.ps1`.
- [x] Check 27 anchors the four decision rules by their definition bullets, their ratification line, "A lesson is promoted" and "Nothing open is lost".
- [x] `scripts/test_cold_start_state_guard.ps1` passes in full, including section F: F1 (four rules deleted, Check 27 fails), F2 (PAY-9's registry row removed, `UNCLASSIFIED: PAY-9`), F3 (`B6-EXIT` REACHED, `OVERDUE: ENTRY-1`), F4 (PAY-9's register row deleted, `UNKNOWN ID: PAY-9`), and F-restore.
- [x] `scripts/test_cold_start_state_guard.ps1` derives its open-decision count from the manifest's enumeration instead of a pinned number.
- [x] `scripts/test_agent_continuity.ps1` passes in full on a CRLF Windows checkout, INH-M15 included.
- [x] `CertMutant` still requires an exact-once anchor, an installed mutant, the pristine verdict and the mutated verdict.
- [x] Both workflows run `readiness_selftest` with its own exit check.
- [x] `repository-consistency.yml` triggers on both readiness scripts in its push and pull_request lists, and Check 20 is CLEAN.
- [x] The register carries CTRL-9, CTRL-10 and GOV-25 as FIXED by this contract.
- [x] The register carries OD-1, OD-2, OD-3, OD-5, OD-8 and OD-9 as OPEN and PROPOSED, each with decider `owner` and its proposed default.
- [x] The register carries APP-1 (OPEN, a required capability) and CTRL-11 (OPEN, an accepted residual with its trigger at `GATE-EVAL`).
- [x] The manifest's open-decision line names the six OD ids, and the manifest stays within 7000 characters and 1200 per line.
- [x] `reports/history/delivery-assessment-2026-10-11.md` exists with a complete seven-field HANDOFF.
- [x] `AGENTS.md` §4 routes "what is open, due now, blocked or waiting" to the registry.
- [x] `GOVERNANCE.md` §2 names the registry as part of the execution plan's ownership.
- [x] `ENGINEERING_METHOD.md` §3 carries "Nothing open is lost (owner-ratified 2026-10-12)".
- [x] Repository consistency is CLEAN.
- [x] `git diff --check` is clean.

## Execution Log

### 2026-10-12 — Gate 1 approval and execution started

- **Authority:** the owner's execution authorization of 2026-10-12 approves Gate 1 for this living-registry contract, which it names by the number it was drafted under. The renumbering is recorded in Notes and is mechanical; the owner's authorization covers numbering reconciliation and re-pinning that preserve the approved substance. Draft `c5f3562`, contract SHA-256 `b28c9dc907f7521015605222736a08658a68c2e42be6e14d3f41eae57a81949e` (32678 bytes, LF). Approval was committed at `85e28d6`; its pre-commit Gate returned `APPROVAL_EVIDENCE: PASS`.
- **Verified before acting:**
  - HEAD was the Approve commit, on top of SPEC-268's Complete commit `04f541e`, which is `origin/main`;
  - the committed Draft blob hashes to the approved value;
  - every one of the fifteen files holds its pinned "from" bytes at `04f541e`, the delivery assessment is absent, and the guard does not yet contain `== Check 29: the action registry`.
- **Not authorized here:** any database, Primary, Secondary, n8n or Google surface, and any answer to an OD row.

### 2026-10-12 — Step 1 applied; Step 2 verified

- **Step 1.** `scripts/check_repository_consistency.ps1` did not contain `== Check 29: the action registry`. Each file was checked against its "from" hash, then written from the rebased prototype and checked against its "to" hash, all LF:
  - The fourteen copied files match both their "from" and "to" hashes.
  - The manifest is compared with `Active Change Request: None.` restored, the value it holds at `04f541e` and at Complete. The Approve commit's pointer stays until Step 4.
  - The delivery assessment was absent and is created.
  - `ai-map.json` was regenerated, not copied. Its output equals the prototype's regeneration (`5e6b0be4…`) except for two fields: `generated_at`, a time the generator stamps on every run, and `active_change_request`, the Approve commit's pointer. No hash that carries a generation time can reproduce, so this is the reproducible form of the check.
- **Step 2:**
  - `scripts/readiness_population.ps1 -Registry`: `registry: DUE NOW 22, BLOCKED 21, NOT DUE 36, ACCEPTED RESIDUAL 28, FUTURE-ONLY 58` and `REGISTRY: complete -- every open member is classified once, and nothing is overdue`, exit 0.
  - `scripts/readiness_selftest.ps1`: `== 26 passed, 0 failed ==`, exit 0.
  - `REPOSITORY CONSISTENCY: CLEAN`, Check 29 included. `git diff --check` is clean.

### 2026-10-12 — Local certification (Step 3)

- The Runtime Checkpoint was committed as `Resume Step: DONE` at `5327a31`.
- Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran once, alone, on that clean committed tree, under `scripts/run_timed.ps1` (`concurrent=0`) and followed by `scripts/watch_run.ps1`.
- It ran profiles CI, CONTROL and REPOSITORY plus this contract's Additional Verification, and reported `LOCAL_CERTIFY: READY` in 33.8 min, exit 0.
- Every step passed:
  - `test_agent_continuity.ps1` in 21.1 min, on this CRLF Windows checkout, INH-M15 included;
  - `test_cold_start_state_guard.ps1` in 5.4 min, section F included;
  - `test_status_contradiction_guard.ps1`, `test_primary_ledger_guard.ps1` and `test_future_date_guard.ps1`;
  - repository consistency, Check 29 included;
  - `git diff --check`;
  - `readiness_selftest.ps1`;
  - `readiness_population.ps1 -Registry`.

## Verification Notes

### 2026-10-12 — Independent Review of the execution commit `5327a31`

The review checked the committed tree against the approved Draft `c5f3562` and its pinned hashes, the original prototype and the Write Scope. It did not rely on the Execution Log alone.

1. **Registry (criteria 1–5).**
   - The gate section holds the Action registry, its state rules and both tables.
   - The boundaries table has exactly one `NEXT`, `B6-EXIT`, and nothing `REACHED`.
   - `-Registry` exits 0 with `REGISTRY: complete`: DUE NOW 22, BLOCKED 21, NOT DUE 36, ACCEPTED RESIDUAL 28 and FUTURE-ONLY 58, 165 members. PAY-9, OD-1…OD-9, APP-1 and CTRL-11 are among them.
   - GADS-1 and APP-1 are classified `REQUIRED CAPABILITY`, boundary `FIRST-TENANT`.
2. **Self-test (criterion 6).** `readiness_selftest.ps1` reports `26 passed, 0 failed`, with M1–M12 killed, at Step 2 and again inside `-Finish`.
3. **Guard (criteria 7, 8, 14).**
   - Check 29 runs in every guard run (`check_repository_consistency.ps1` line 2497), and the guard is CLEAN.
   - Check 27's seven new anchors are in the committed guard. The four decision rules — LEARN BEFORE GUESSING, EARN IT, WORTH IT, SIMPLIFY IT WITHOUT WEAKENING — and their ratification line are unchanged in `ENGINEERING_METHOD.md` and `AGENTS.md`.
   - `repository-consistency.yml` names both readiness scripts in its trigger lists, and Check 20 is CLEAN.
4. **Tests (criteria 9–12).**
   - `test_cold_start_state_guard.ps1` passed in full inside `-Finish`, section F and its derived open-decision count included.
   - `test_agent_continuity.ps1` passed in full on this CRLF checkout. `CertMutant`'s exact-once, installed, pristine-verdict and mutated-verdict requirements are the prototype's.
5. **Workflows (criterion 13).** Both workflows run `readiness_selftest` with its own exit check.
6. **Register (criteria 15–17).**
   - CTRL-9, CTRL-10 and GOV-25 are FIXED by this contract.
   - OD-1, OD-2, OD-3, OD-5, OD-8 and OD-9 are OPEN and PROPOSED, each with decider `owner` and a proposed default.
   - APP-1 is OPEN as a required capability, and CTRL-11 is OPEN as an accepted residual triggered at `GATE-EVAL`.
   - The freshness chain keeps SPEC-268's and SPEC-265's entries as `Previously:`.
   - RCPT-1 to RCPT-4 and GADS-1 are byte-unchanged.
7. **Manifest and documents (criteria 18–22).**
   - The open-decision line names the six OD ids.
   - The manifest is 6812 characters, with its longest line 1152.
   - The delivery assessment carries its HANDOFF.
   - `AGENTS.md` §4 routes "What is open, due now, blocked or waiting" to the registry.
   - `GOVERNANCE.md` §2 names the registry, at version 1.18.
   - `ENGINEERING_METHOD.md` §3 carries "Nothing open is lost (owner-ratified 2026-10-12)".
   - `CR_LIFECYCLE.md`, which defines LEARN → VERIFY → DECIDE → IMPLEMENT → TEST → REVIEW → COMPLETE, is untouched.
8. **Checks (criteria 23–24).** Repository consistency is CLEAN and `git diff --check` is clean.
9. **Frozen values.**
   - Each file matched its "from" hash at `04f541e` and its "to" hash at Step 1.
   - Eleven files equal the original prototype once SPEC-269 is written back as SPEC-267. The plan, the register and the manifest also carry SPEC-265's and SPEC-268's committed edits.
   - The two lines removed outside the plan, register and manifest are `GOVERNANCE.md`'s version line and its execution-plan row, both rewritten.
10. **Scope.** `04f541e..5327a31` changes sixteen paths: the fifteen in the table and this contract. No database, Primary, Secondary, n8n or Google surface was touched, and no OD row was answered.

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

- **Rebased prototype evidence, 2026-10-12, on a scratch worktree at `04f541e`:**
  - The rebased patch, `spec269-on-268.patch`, touches the same 15 files. Repository consistency is CLEAN, Check 29 included.
  - `scripts/readiness_population.ps1 -Registry`: DUE NOW 22, BLOCKED 21, NOT DUE 36, ACCEPTED RESIDUAL 28, FUTURE-ONLY 58; `REGISTRY: complete`. The register has 488 ids, 348 settled and 140 not settled; 36 of 78 surfaces have no disposition.
  - `scripts/readiness_selftest.ps1`: 26 passed, 0 failed, M1–M12 killed.
  - GADS-1 and APP-1 are classified `REQUIRED CAPABILITY`, boundary `FIRST-TENANT`.
  - Causal negative at `04f541e`: with GADS-1's queue row removed, the population exits 1 `UNCLASSIFIED (1): GADS-1` while the guard is CLEAN.
- **Original prototype evidence, 2026-10-12, on a scratch worktree at `f6c30d0`:**
  - The prototype patch, `spec267-prototype.patch` (131,807 bytes), applies cleanly to a fresh `origin/main` worktree and touches the 15 files above.
  - Repository consistency is CLEAN, and `git diff --check` is clean.
  - `scripts/readiness_population.ps1 -Registry`: DUE NOW 22, BLOCKED 21, NOT DUE 35, ACCEPTED RESIDUAL 28, FUTURE-ONLY 58; `REGISTRY: complete`. The backlog has 26 live trigger rows and 0 without a trigger. Batch 6 has 37 of 78 surfaces with no disposition.
  - `scripts/readiness_selftest.ps1`: 26 passed, 0 failed, M1–M12 killed, 27 s.
  - The guard self-tests:
    - `test_future_date_guard`: 18 of 18;
    - `test_status_contradiction_guard`: 33 of 33;
    - `test_primary_ledger_guard`: 13 of 13;
    - `test_cold_start_state_guard`: 42 of 42 in 5.5 min, with section F (F1–F4 and restore). Before its pinned count was derived, it failed 1 of 34 on the pinned 3.
  - Live proofs on the applied patch, each reverted:
    - L1: removing PAY-9's row fails `UNCLASSIFIED: PAY-9`.
    - L2: setting `B6-EXIT` REACHED reports 24 OVERDUE, OD-9 among them.
    - L3: resolving PAY-9 in the register reads COMPLETED, with a prune note, and no failure.
    - L4: moving PAY-9's boundary to `B6-EXIT` reads DUE NOW.
    - L5: deleting the four-rules paragraph fails Check 27 on the rule names.
    - L6: restored, CLEAN.
  - Causal negatives at `f6c30d0`: the guard is CLEAN while `readiness_population.ps1` exits 1 on PAY-9, and Check 27 stays CLEAN with the four-rules paragraph deleted.
  - `scripts/test_agent_continuity.ps1`: before the CTRL-10 repair, 423 passed and 1 failed (INH-M15) on both the prototype and an unmodified `main` worktree, 29.9 min each, run side by side under `run_timed.ps1` and followed by `watch_run.ps1`. After it, 424 passed, 0 failed in 21.3 min (`concurrent=0`).
- **How a new agreement enters the record.** `ENGINEERING_METHOD.md` §3 "Nothing open is lost" routes each item to the home `GOVERNANCE.md` §2 already assigns it. Every open id then needs its registry row in the same change, and Check 29 refuses the change without it. A proposal by an agent is recorded as `PROPOSED` with its decider and is never written as the owner's decision.
- **Not decided here.** Every OD row's answer is the owner's. So are any changes to boundary states: only a contract moves one, and `REACHED` needs its evidence.
- **Execution order, measured 2026-10-12.** A Draft committed alone onto `f6c30d0` and judged by the Gate's allocation walk gives these results:
  - SPEC-265: legal;
  - the receipts Draft, then numbered 266: `SPEC_ID_NOT_NEXT:265:266`;
  - this contract, then numbered 267: `SPEC_ID_NOT_NEXT:265:267`.

  SPEC-265 executed first, then the receipts contract (SPEC-268), whose Gate 2 deployment came before this contract. This contract's "from" hashes are re-pinned on SPEC-268's Complete bytes. SPEC-265's GADS-1 and PAY-9 queue rows are registry rows, and GADS-1 takes `REQUIRED CAPABILITY`.
- **Product roadmap.** Canon 32 is not changed here. The missing product capabilities each carry a home, a boundary and a treatment in the registry: the frontend (APP-1), management finance (OD-1, OD-2, OD-3, OD-8), staff login (OD-5), sequencing (OD-9), Google Ads reporting (GADS-1, SPEC-265), Data Manager (PH8 rows and `offline_conversions`), and recovery (OPS-1). Canon 32 is amended by the contracts that answer OD-1 and OD-9, which is their trigger.
- **Drafts.** A range Gate refuses a range of Drafts alone (`NO_GOVERNING_CR`), and a contract's range that carries another contract's Draft (`OUT_OF_SCOPE_WRITE`). So a Draft is committed only when it is approved, and Drafts are never stacked on `main`.
- **Renumbered before approval.** This contract was drafted as SPEC-267, and the receipts contract as SPEC-266. SPEC-265's Execution Log quoted the owner's 2026-10-12 authorization, which names both numbers, and any tracked mention reserves an identity (`CR_LIFECYCLE.md` §4). So the receipts contract became SPEC-268 and this one SPEC-269. The substance the owner approved is unchanged. Eleven of the fifteen files differ from the original prototype only by this identity: with SPEC-269 written back as SPEC-267, each hashes to its original "to" value. The plan, the register and the manifest also carry SPEC-265's and SPEC-268's committed edits.
