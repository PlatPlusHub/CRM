# Change Request — SPEC-339

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Record the Foundation Completion Programme exit `B6-EXIT` as REACHED at 7b3e35e60351b27b57fda6abdae42bae2c271b3c. The gate evaluation found every exit criterion EC-1…EC-11 met. EC-2, EC-3, EC-4 and EC-11 were labelled for confirmation at the gate evaluation, and the SPEC-338 Original Finish confirmed them on the full local suite. The boundary row in `MASTER_EXECUTION_PLAN.md` moves to REACHED with its evidence, and those four labels become met. The canonical manifest names the readiness gate as next. Its Current Module, Batch 6 surface coverage and Next capability lines are pinned in `GOVERNANCE.md` §6, so this contract is also an authority change under rule 10: it writes their new pins, and Current Module and Next capability now name `reports/master/MASTER_EXECUTION_PLAN.md`, which owns the readiness gate, as their owner instead of `scripts/batch6_select_target.ps1`. No live member is due at `B6-EXIT`, so the cold-start guard's F3 mutation now plants PAY-9 at the REACHED boundary and must name it as OVERDUE. That keeps Check 29 proven, and the proof is stronger than before because the refusal must name the planted member. `GATE-EVAL` stays NOT REACHED. FE-0 and Phase 8 transport are not started.

## Business Reason

The owner directed that Batch 6 finish first (2026-11-22) and that the work continue until the Batch 6 Finish (2026-11-23). After SPEC-338 met EC-5, each exit criterion holds. Until the boundary is recorded, every agent's cold start reads Batch 6 as open and `scripts/batch6_select_target.ps1` keeps selecting slices that the exit no longer needs. A boundary that is reached but not recorded misstates the project's state (DEC-33 rules 10 and 11).

## Risks

A REACHED boundary makes any open member classified at it OVERDUE (Check 29). At 7b3e35e60351b27b57fda6abdae42bae2c271b3c, no open member is classified at `B6-EXIT`, and the registry reports complete with nothing overdue. The cold-start guard used to rewrite the boundary inside its own mutation. It now moves only PAY-9's row, so its F3 control needs the live REACHED row; its F-precondition checks for that row, and F3 must name PAY-9 rather than any id. This contract changes no migration, function, policy, grant, test SQL or database object, and it moves no other boundary.

## Supersedes / Depends On

Depends on SPEC-338 (EC-5 met; Original Finish READY on `3792b61`) and the SPEC-330 planted F3 witness. Those terminal contracts are immutable.

## Write Scope

- `changes/SPEC-339-batch-6-exit-is-reached.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `GOVERNANCE.md`
- `scripts/test_cold_start_state_guard.ps1`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_API_CONTRACT.md`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `.github/workflows/repository-consistency.yml`
- `supabase/config.toml`

Migrations, product code, test SQL, reaching `GATE-EVAL` or any other boundary, the repair of any finding, starting FE-0 or Phase 8 transport, any Primary write, Founder Secondary, frontend work, integration activation, email delivery and every owner decision are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9.
- `reports/master/MASTER_EXECUTION_PLAN.md`: the exit criteria EC-1…EC-11, the boundary table and the registry rules.
- `scripts/readiness_population.ps1`: the OVERDUE rule.
- `scripts/test_cold_start_state_guard.ps1`: section F.
- `GOVERNANCE.md` §6 rule 10 and its pin table; `scripts/check_agent_continuity.ps1`: `Validate-PinnedAuthority` and the ACI consumer search.

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- github

## Additional Verification

- pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1
- pwsh -NoProfile -File scripts/test_future_date_guard.ps1
- pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1
- pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1
- pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1
- pwsh -NoProfile -File scripts/readiness_selftest.ps1

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: three record edits and one guard adjustment. The plan gets a dated SPEC-339 header, and its four exit criteria labels become met at `B6-EXIT`. A `B6-EXIT` evidence bullet is added after EC-11, the row `| Batch 6, this plan |` moves from NEXT to REACHED 2026-11-24 SPEC-339, and the bundle M exception follows the bundle L exception. The manifest's Current Module, Batch 6 status line and Next capability name Batch 6 complete and the readiness gate next. The ai-map is regenerated from the manifest. In `GOVERNANCE.md` §6, the three pin rows of those manifest lines get the SHA-256 of their new text; Current Module and Next capability name `reports/master/MASTER_EXECUTION_PLAN.md` as owner, because they now point at its readiness gate, and Batch 6 surface coverage keeps `reports/master/MASTER_SURFACE_DISPOSITION.md`. In the cold-start guard, the F-precondition requires the REACHED row, the F3 mutation moves only PAY-9's row to `B6-EXIT`, and F3 expects `OVERDUE: PAY-9 -- boundary B6-EXIT is REACHED 2026-11-24 SPEC-339`.

Pass 2 Adversarial Review: The F3 expectation is stricter than at 7b3e35e60351b27b57fda6abdae42bae2c271b3c: it names PAY-9 and the recorded boundary text, not any id at a probe boundary, so a registry that reported a different member would fail F3. F4 and the F-restore control still run against the live plan. The registry at the new tree reports every open member classified once and nothing overdue, with no member at `B6-EXIT`. Nothing in the population depends on the readiness gate row, which stays NEXT. Check 846 holds because the ai-map's next capability is regenerated from the manifest. A first rehearsal of this contract without the pins was refused at Approval (APPROVAL_EVIDENCE: WRITE on the pinned line Current Module), so the pins and every consumer the native `git grep` finds at 7b3e35e60351b27b57fda6abdae42bae2c271b3c are now closed below; the native `Validate-PinnedAuthority` passes on the candidate tree. `MASTER_EXECUTION_PLAN.md` still says that inside Batch 6 the next task is the first row the selector ranks, which stays true as a conditional and needs no edit.

Pass 3 Evidence Refresh: 2026-11-24. In an isolated clone at 7b3e35e60351b27b57fda6abdae42bae2c271b3c carrying the payload, native repository consistency was CLEAN. All five hosted guard suites passed with 0 failed: future-date 19, status contradiction 38, primary ledger 13, cold-start 42 and readiness self-test 33. EC-9 was re-read from Primary through the read-only role: 277 migrations, latest `20261122100000`, and the combined parity digest equal to the recorded evidence.

Selected Version: SPEC-339; selected: the boundary row moved to REACHED with its evidence, EC-2, EC-3, EC-4 and EC-11 confirmed, the canonical manifest updated with its GOVERNANCE.md section 6 pins (an authority change under rule 10) and the cold-start guard F3 witness kept proving Check 29 by naming PAY-9, the smallest change that records B6-EXIT without any database change or weakened check

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Boundary row `B6-EXIT` REACHED | Check 29 (`readiness_population.ps1`) | WRITE | No open member is classified at `B6-EXIT`; REGISTRY complete, nothing overdue. |
| Exit criteria labels and evidence | Gate table and cold-start readers | WRITE | EC-1…EC-11 recorded met with their evidence; `GATE-EVAL` stays NOT REACHED. |
| Manifest Current Module, status and Next capability | Check 846, `ai-map.json`, agent cold start | WRITE | The regenerated ai-map next capability equals the manifest; `generate-ai-map.ps1 -Check` exit 0. |
| Manifest Current Module, Batch 6 surface coverage and Next capability pins | `GOVERNANCE.md` §6 pin table and `Validate-PinnedAuthority` | WRITE | The three pin rows carry the new line SHA-256 values; Current Module and Next capability are owned by `reports/master/MASTER_EXECUTION_PLAN.md`; the native validator passes on the candidate tree. |
| Pinned-line readers | `scripts/check_agent_continuity.ps1`, `scripts/check_repository_consistency.ps1`, `scripts/generate-ai-map.ps1` | VERIFY | Unchanged; they read the lines by key, and the candidate tree is CLEAN with the ai-map regenerated. |
| Pinned-line references | `CR_LIFECYCLE.md`, `reports/master/MASTER_GAP_REGISTER.md`, `reports/master/MASTER_REPOSITORY_HEALTH.md`, `reports/master/MASTER_EXECUTION_PLAN.md` | VERIFY | Unchanged except the plan's own WRITE rows; `CR_LIFECYCLE.md` already says a pinned line names its owner and Complete never rewrites it; the register and health rows are history. |
| Test fixtures naming the keys | `scripts/test_agent_continuity.ps1`, `scripts/test_certification_receipts.ps1` | UNAFFECTED | Their fixtures build their own manifests; the live lines are not read. |
| Cold-start guard section F | Hosted guard suites and `repository-consistency.yml` | WRITE | 42 passed, 0 failed; F3 names PAY-9. |
| Schema, grants, policies and API | Every product consumer | UNAFFECTED | No migration; the API contract has the same blob as the baseline. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchors and exact payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Checks 29 and 846, the §6 pins and the five hosted guard suites pass | BEFORE_COMPLETION | 1 | 4 | 5 |
| Full DATABASE readiness at 198 files and 3960 assertions | BEFORE_COMPLETION | NONE | NONE | 5 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: Check 29 in `scripts/readiness_population.ps1` and its mutation witness F3 in `scripts/test_cold_start_state_guard.ps1`.

Added Property: Once `B6-EXIT` is REACHED, a member classified at it while still open fails as OVERDUE, and the guard proves this on the live REACHED row.

Causal Negative: At 7b3e35e60351b27b57fda6abdae42bae2c271b3c the F-precondition requires `| Batch 6, this plan | NEXT |`, so recording the boundary without this change fails the cold-start guard.

Positive Test Design: On the new tree, the registry reports complete with nothing overdue, and the untouched copy is CLEAN.

Negative Test Design: F3 moves PAY-9's open row to `B6-EXIT`, and the consistency check must exit non-zero with `OVERDUE: PAY-9 -- boundary B6-EXIT is REACHED 2026-11-24 SPEC-339`.

Non-Empty Population Obligation: The F-precondition first asserts that the registry classifies PAY-9 and that the live plan carries the REACHED `B6-EXIT` row.

Mutation Obligation: F3 must fail as stated, and F-restore must return CLEAN.

Post-Implementation Proof Obligation: The native Finish runs the full DATABASE protocol, and all five hosted guard suites run through Additional Verification, with zero failures. Hosted preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Last updated: 2026-11-24 (CRM exit bundle M, SPEC-339.`; if so record Already Applied when its Git blob is cb7ef900646a7f31fd27b74c6d4866ea7131caa9, and otherwise stop and report. Otherwise make exactly these 5 edits (the REACHED boundary row, the EC-2, EC-3, EC-4 and EC-11 labels, the B6-EXIT evidence, the bundle M exception and the dated SPEC-339 header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-24 (CRM exit bundle L, SPEC-338. Behavioural refusal tests cover the 360 refusals the SPEC-337 function-body probe found unseen: Test 195 reaches the 71 refusals of a caller with no active tenant, Test 196 145 refusals by a direct call, Test 197 91 that need a prepared state, another actor or the system caller, and Test 198 40 trigger refusals, and lowering each of those 347 RAISE statements to NOTICE fails its own assertion; the other 13 cannot be reached, each for a recorded reason. EC-5 is met as measured at `b4562e7`; `B6-EXIT` is recorded by its own contract. CHAT-5, found by the probe, is registered OPEN.)
   ```
   with
   ```text
   Last updated: 2026-11-24 (CRM exit bundle M, SPEC-339. `B6-EXIT` is REACHED: EC-1…EC-11 hold at `7b3e35e`. EC-2, EC-3, EC-4 and EC-11 are confirmed by the SPEC-338 Original Finish on `3792b61` (its `supabase` tree equals `7b3e35e`) ran 198 test files and 3960 assertions READY, receipt `366e63c5…f274`, Tests 54, 57, 58, 88, 186 and 187 among them; the readiness registry has no open member at `B6-EXIT` and 0 of 78 surfaces lack a recorded disposition; EC-9 was re-read from Primary on 2026-11-24 and is unchanged. `GATE-EVAL` stays NOT REACHED; FE-0 and Phase 8 transport keep their own gates.)

   Previously: 2026-11-24 (CRM exit bundle L, SPEC-338. Behavioural refusal tests cover the 360 refusals the SPEC-337 function-body probe found unseen: Test 195 reaches the 71 refusals of a caller with no active tenant, Test 196 145 refusals by a direct call, Test 197 91 that need a prepared state, another actor or the system caller, and Test 198 40 trigger refusals, and lowering each of those 347 RAISE statements to NOTICE fails its own assertion; the other 13 cannot be reached, each for a recorded reason. EC-5 is met as measured at `b4562e7`; `B6-EXIT` is recorded by its own contract. CHAT-5, found by the probe, is registered OPEN.)
   ```

   b) replace the lines
   ```text
   - **EC-2 (members closed; confirmed at the gate evaluation):** Tests 57/58 carry 54/17/3, and `MASTER_SURFACE_DISPOSITION.md` states each writable surface's rationale. PAX-4 is fixed and STEPUP-1 is resolved for its `B6-EXIT` members (SPEC-320/324, Tests 58/130/183). RPC-1 is resolved by SPEC-330: Test 186 pins the four permissions enforced nowhere (MANAGE_ROLES, whose role matrix no member may write, and ACCESS_API_FULL, ACCESS_API_READ_ONLY and VIEW_ADVANCED_DASHBOARDS, whose surfaces do not exist and which no role holds) as a set that can only shrink.
   - **EC-3 (members closed; confirmed at the gate evaluation):** SPEC-316 HTTP evidence covers cross-tenant denial for the paths it exercises. Test 186 states the isolation basis of every public table from the catalog: all 78 have row-level security; 61 rest on the tenant predicate in every policy, 10 are reference data members read and never write, 4 are platform-only (no member privilege, `false` policies) and 3 are identity-owned (`auth.uid()` on read and write); `anon` holds no privilege on any of them. A new table without a basis fails it.
   - **EC-4 (members closed; confirmed at the gate evaluation):** Tests 54/88 establish bounded transition and parent-state evidence. ENTRY-1 is fixed by SPEC-318/324 (Tests 134/183) and CHAT-2 by SPEC-326 (Test 184), on Platinum Primary; no registry member of EC-4 remains open.
   ```
   with
   ```text
   - **EC-2 (met at `B6-EXIT`, SPEC-339):** Tests 57/58 carry 54/17/3, and `MASTER_SURFACE_DISPOSITION.md` states each writable surface's rationale. PAX-4 is fixed and STEPUP-1 is resolved for its `B6-EXIT` members (SPEC-320/324, Tests 58/130/183). RPC-1 is resolved by SPEC-330: Test 186 pins the four permissions enforced nowhere (MANAGE_ROLES, whose role matrix no member may write, and ACCESS_API_FULL, ACCESS_API_READ_ONLY and VIEW_ADVANCED_DASHBOARDS, whose surfaces do not exist and which no role holds) as a set that can only shrink.
   - **EC-3 (met at `B6-EXIT`, SPEC-339):** SPEC-316 HTTP evidence covers cross-tenant denial for the paths it exercises. Test 186 states the isolation basis of every public table from the catalog: all 78 have row-level security; 61 rest on the tenant predicate in every policy, 10 are reference data members read and never write, 4 are platform-only (no member privilege, `false` policies) and 3 are identity-owned (`auth.uid()` on read and write); `anon` holds no privilege on any of them. A new table without a basis fails it.
   - **EC-4 (met at `B6-EXIT`, SPEC-339):** Tests 54/88 establish bounded transition and parent-state evidence. ENTRY-1 is fixed by SPEC-318/324 (Tests 134/183) and CHAT-2 by SPEC-326 (Test 184), on Platinum Primary; no registry member of EC-4 remains open.
   ```

   c) replace the line
   ```text
   - **EC-11 (swept; confirmed at the gate evaluation):** Test 187 sweeps every table, trigger, index, policy, constraint, sequence and function in `public`, `app` and `reporting`. It finds no disabled or duplicate trigger, no duplicate or invalid index, no duplicate policy, no unvalidated constraint and no unowned sequence. Exactly one function is reachable from nothing at runtime: `app.document_retention_days(uuid,text)`. It is superseded by RET-1's policy table and kept as the tested lookup, and it leaves the set when RET-1's owner decision retires it or a caller appears. AUTH-1 keeps the retirement trigger for the inert authentication tables. The `documents`/`quotations` re-sweep is done (SPEC-335), and its findings carry their own boundaries.
   ```
   with
   ```text
   - **EC-11 (met at `B6-EXIT`, SPEC-339):** Test 187 sweeps every table, trigger, index, policy, constraint, sequence and function in `public`, `app` and `reporting`. It finds no disabled or duplicate trigger, no duplicate or invalid index, no duplicate policy, no unvalidated constraint and no unowned sequence. Exactly one function is reachable from nothing at runtime: `app.document_retention_days(uuid,text)`. It is superseded by RET-1's policy table and kept as the tested lookup, and it leaves the set when RET-1's owner decision retires it or a caller appears. AUTH-1 keeps the retirement trigger for the inert authentication tables. The `documents`/`quotations` re-sweep is done (SPEC-335), and its findings carry their own boundaries.
   - **`B6-EXIT` evidence (SPEC-339, 2026-11-24, at `7b3e35e`):** EC-2, EC-3, EC-4 and EC-11 were labelled for confirmation at the gate evaluation; the SPEC-338 Original Finish on `3792b61` (its `supabase` tree equals `7b3e35e`) ran 198 test files and 3960 assertions READY, receipt `366e63c5…f274`, Tests 54, 57, 58, 88, 186 and 187 among them, so each is confirmed on the full local suite. `scripts/readiness_population.ps1 -Registry` reports every open member classified once and nothing overdue, no member due at `B6-EXIT`, and 0 of 78 surfaces without a recorded disposition (EC-1, with Check 22). EC-5 to EC-8 and EC-10 stand as measured above. EC-9 was re-read from Primary on 2026-11-24 through the read-only role: 277 migrations, latest `20261122100000`, every parity section and the combined digest equal to `reports/evidence/primary-ledger-evidence.json`; the grants section is read from `pg_class.relacl`, because that role cannot see other roles' grants in `information_schema`, and the variant gives the local value exactly.
   ```

   d) replace the line
   ```text
   | `B6-EXIT` | Batch 6's EC-1…EC-11 hold; inside it `scripts/batch6_select_target.ps1` chooses each slice | Batch 6, this plan | NEXT |
   ```
   with
   ```text
   | `B6-EXIT` | Batch 6's EC-1…EC-11 hold; inside it `scripts/batch6_select_target.ps1` chooses each slice | Batch 6, this plan | REACHED 2026-11-24 SPEC-339: EC-1…EC-11 hold at `7b3e35e` (EC-9 re-read from Primary) |
   ```

   e) immediately after the lines
   ```text
   **Recorded exception, 2026-11-24, CRM exit bundle L.** After CRM SPEC-337 at `b4562e7`, the Batch 6 delegation continues to `B6-EXIT` in the owner's AFK mode. SPEC-338 adds Tests 195, 196, 197 and 198, which reach 347 of the 360 refusals the function-body probe found unseen; each was mutation-probed before it counted, and the other 13 are unreachable for recorded reasons. It records EC-5 met as measured and registers CHAT-5 OPEN with its boundary `ENABLE-CRM`. It changes no migration or database object. `B6-EXIT` stays `NEXT` in this change because recording a boundary as reached is its own contract. The Original and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-24, CRM exit bundle M.** After CRM SPEC-338 at `7b3e35e`, the Batch 6 delegation records `B6-EXIT` as REACHED in the owner's AFK mode, as its own contract. SPEC-339 changes no migration, database object or test SQL: it moves the boundary row to REACHED with its evidence, confirms EC-2, EC-3, EC-4 and EC-11, and updates the canonical manifest. Because no live member is due at `B6-EXIT`, the cold-start guard's F3 mutation now plants PAY-9 at the REACHED boundary and must name it as OVERDUE, which keeps Check 29 proven. `GATE-EVAL` stays NOT REACHED: it holds CTRL-11 and FIN-9 as accepted residuals and a backlog item. FE-0 and Phase 8 transport are not started and keep their own gates. The Original and release gates remain enforced.

   ```

   The resulting file's Git blob is cb7ef900646a7f31fd27b74c6d4866ea7131caa9.

2. Check whether `_ORVION_CANONICAL/manifest.md` contains `is REACHED (SPEC-339); exit criteria EC-1…EC-11`; if so record Already Applied when its Git blob is f0c709651e85562774337d24e92157b570f87264, and otherwise stop and report. Otherwise make exactly these 3 edits (the Current Module, the Batch 6 status line and the Next capability), each matched once, and change nothing else:

   a) replace the line
   ```text
   Current Module: Foundation Completion Programme Batch 6 (owner's 2026-10-07 order, `32` Phase 8); its next slice is the first row `scripts/batch6_select_target.ps1` ranks; the n8n workflow follows Batch 6 and stays governed by `MASTER_INTEGRATION_CATALOG.md §2/§2a/§2b`; the real-GCLID test stays on hold until genuine ad-click traffic exists.
   ```
   with
   ```text
   Current Module: Foundation Completion Programme Batch 6 is complete (`B6-EXIT` REACHED 2026-11-24 by SPEC-339; owner's 2026-10-07 order, `32` Phase 8); the readiness gate in `MASTER_EXECUTION_PLAN.md` is next; the n8n workflow follows Batch 6 and stays governed by `MASTER_INTEGRATION_CATALOG.md §2/§2a/§2b`; the real-GCLID test stays on hold until genuine ad-click traffic exists.
   ```

   b) replace the line
   ```text
   Batch 6 surface coverage: counted only in `MASTER_SURFACE_DISPOSITION.md` (Checks 22 and 24), and every surface still `NOT-RECORDED` is a DUE NOW registry member until `B6-EXIT` (EC-1). Batch 6 is **NOT complete**; exit criteria EC-1…EC-11 and the adversarial method live in `MASTER_EXECUTION_PLAN.md`. The next slice is ranked by `scripts/batch6_select_target.ps1`, which stores nothing. **Its ranking was INVERTED until 2026-09-08 and is now EXPOSURE-ordered**; `Score` is a diagnostic, not the sort key.
   ```
   with
   ```text
   Batch 6 surface coverage: counted only in `MASTER_SURFACE_DISPOSITION.md` (Checks 22 and 24), and every surface still `NOT-RECORDED` is a DUE NOW registry member until `B6-EXIT` (EC-1). Batch 6 is **complete**: `B6-EXIT` is REACHED (SPEC-339); exit criteria EC-1…EC-11 and the adversarial method live in `MASTER_EXECUTION_PLAN.md`. The next slice is ranked by `scripts/batch6_select_target.ps1`, which stores nothing. **Its ranking was INVERTED until 2026-09-08 and is now EXPOSURE-ordered**; `Score` is a diagnostic, not the sort key.
   ```

   c) replace the line
   ```text
   Next capability: **Foundation Completion Programme — Batch 6**: the next slice is the first row of `scripts/batch6_select_target.ps1` (local stack), never a copy of it here. Batch 6 runs until EC-1…EC-11 hold, then the readiness gate (`MASTER_EXECUTION_PLAN.md`); then the Phase-8 order in `32` resumes: bounded boundary revalidation → n8n workflow → Direct Call Quality Feedback Loop → PH8-10 evidence → Smart Bidding handoff when earned. **The control-plane optimization chapter is CLOSED** — reopening it requires newly earned evidence (a real incident, a false green or false red, a measured material cost, or a proven safety/governance gap), never a further search for theoretical optimizations.
   ```
   with
   ```text
   Next capability: **the readiness gate** (`MASTER_EXECUTION_PLAN.md`): Batch 6 is complete (`B6-EXIT` REACHED by SPEC-339); FE-0 starts only after its own gates and the owner's frontend assessment; then the Phase-8 order in `32` resumes: bounded boundary revalidation → n8n workflow → Direct Call Quality Feedback Loop → PH8-10 evidence → Smart Bidding handoff when earned. **The control-plane optimization chapter is CLOSED** — reopening it requires newly earned evidence (a real incident, a false green or false red, a measured material cost, or a proven safety/governance gap), never a further search for theoretical optimizations.
   ```

   The resulting file's Git blob is f0c709651e85562774337d24e92157b570f87264.

3. Check whether `GOVERNANCE.md` contains `efde8086c712a111907be3abb2c60d054adc622e8775467b57a7d3cbf23f4d0d`; if so record Already Applied when its Git blob is 0f2f6361495f68d6254087bb0a465f0d4e88c61c, and otherwise stop and report. Otherwise make exactly this one edit (the section 6 pins of the three manifest lines this contract rewrites, with the readiness gate owner), each matched once, and change nothing else:

   a) replace the lines
   ```text
       | `_ORVION_CANONICAL/manifest.md` | `Current Module` | `scripts/batch6_select_target.ps1` | `63c303fb1bcfde20de5d8f6c9f16ab38436e451c6bf8795cb93d7da97114ca77` |
       | `_ORVION_CANONICAL/manifest.md` | `Batch 6 surface coverage` | `reports/master/MASTER_SURFACE_DISPOSITION.md` | `166b2f42e10851e6c13be8d578229e72ff22865d6761bfb2a2d8f78296ce8a16` |
       | `_ORVION_CANONICAL/manifest.md` | `Next capability` | `scripts/batch6_select_target.ps1` | `90b037bb396498533eb9209c81d73278a5da8ad481562a02941440a3219557ee` |
   ```
   with
   ```text
       | `_ORVION_CANONICAL/manifest.md` | `Current Module` | `reports/master/MASTER_EXECUTION_PLAN.md` | `efde8086c712a111907be3abb2c60d054adc622e8775467b57a7d3cbf23f4d0d` |
       | `_ORVION_CANONICAL/manifest.md` | `Batch 6 surface coverage` | `reports/master/MASTER_SURFACE_DISPOSITION.md` | `ab75ed855f391cbfd165340e57cc69b6831cdf60282abd15e26b2983d9ca26ca` |
       | `_ORVION_CANONICAL/manifest.md` | `Next capability` | `reports/master/MASTER_EXECUTION_PLAN.md` | `4ede42e1e2c2c9d6d5019dfb039c8c84d791277990df280440bbf782e63bc298` |
   ```

   The resulting file's Git blob is 0f2f6361495f68d6254087bb0a465f0d4e88c61c.

4. Check whether `scripts/test_cold_start_state_guard.ps1` contains `OVERDUE: PAY-9 -- boundary B6-EXIT is REACHED 2026-11-24 SPEC-339`; if so record Already Applied when its Git blob is ff8f70c79c6f86c4b8b8742802e62b8f655028b7, and otherwise stop and report. Otherwise make exactly these 3 edits (the F-precondition and the F3 witness for a REACHED B6-EXIT), each matched once, and change nothing else:

   a) replace the line
   ```text
       Check 'F-precondition: the registry classifies PAY-9 and B6-EXIT is NEXT' ($payRow -and $planOriginal.Contains('| Batch 6, this plan | NEXT |'))
   ```
   with
   ```text
       Check 'F-precondition: the registry classifies PAY-9 and B6-EXIT is REACHED' ($payRow -and $planOriginal.Contains('| Batch 6, this plan | REACHED 2026-11-24 '))
   ```

   b) replace the lines
   ```text
       # last), F3 must still prove the guard, so PAY-9's open row is moved to that boundary inside the mutation.
       Write-S $PLAN $planOriginal.Replace($payRow, $payRow.Replace('| `FIRST-BOOKING` |', '| `B6-EXIT` |')).Replace('| Batch 6, this plan | NEXT |', '| Batch 6, this plan | REACHED 2026-10-12 probe |')
   ```
   with
   ```text
       # last), F3 must still prove the guard, so PAY-9's open row is moved to that boundary inside the mutation. Since
       # SPEC-339 the boundary is REACHED in the live plan, so only the row moves, and the refusal must name PAY-9.
       Write-S $PLAN $planOriginal.Replace($payRow, $payRow.Replace('| `FIRST-BOOKING` |', '| `B6-EXIT` |'))
   ```

   c) replace the line
   ```text
           ($r.Exit -ne 0 -and $r.Text -match 'OVERDUE: \S+ -- boundary B6-EXIT is REACHED 2026-10-12 probe') $r.Exit
   ```
   with
   ```text
           ($r.Exit -ne 0 -and $r.Text -match 'OVERDUE: PAY-9 -- boundary B6-EXIT is REACHED 2026-11-24 SPEC-339') $r.Exit
   ```

   The resulting file's Git blob is ff8f70c79c6f86c4b8b8742802e62b8f655028b7.

5. **Establish readiness and verify.** Run the native DATABASE readiness: full SQL tests at 277 migrations with 198 files and 3960 assertions, smoke and HTTP, and API generation with the API contract unchanged. Run the native repository guard and the five hosted guard suites named in Additional Verification. Confirm that `readiness_population.ps1` reports REGISTRY complete with no member at `B6-EXIT`. Confirm the exact scope and `git diff --check`. Make no Primary write. Synchronize the contract and native discovery artifacts, set Runtime Checkpoint DONE and commit the implementation. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-339: Batch 6 exit is reached.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] The REACHED boundary, its evidence and the bundle M exception are recorded. `check: blob reports/master/MASTER_EXECUTION_PLAN.md cb7ef900646a7f31fd27b74c6d4866ea7131caa9`
- [ ] The manifest records Batch 6 complete. `check: has _ORVION_CANONICAL/manifest.md "is REACHED (SPEC-339); exit criteria EC-1…EC-11"`
- [ ] The §6 pins name the new manifest lines and their owners. `check: blob GOVERNANCE.md 0f2f6361495f68d6254087bb0a465f0d4e88c61c`
- [ ] The cold-start guard proves Check 29 on the REACHED boundary. `check: blob scripts/test_cold_start_state_guard.ps1 ff8f70c79c6f86c4b8b8742802e62b8f655028b7`
- [ ] The API contract is unchanged. `check: same reports/master/MASTER_API_CONTRACT.md @7b3e35e60351b27b57fda6abdae42bae2c271b3c`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @7b3e35e60351b27b57fda6abdae42bae2c271b3c`
- [ ] The registry self-test is preserved. `check: same scripts/readiness_selftest.ps1 @7b3e35e60351b27b57fda6abdae42bae2c271b3c`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @7b3e35e60351b27b57fda6abdae42bae2c271b3c`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @7b3e35e60351b27b57fda6abdae42bae2c271b3c`
- [ ] Full DATABASE readiness and all five hosted guard suites pass in the native Finish.

## Execution Log

None.

## Verification Notes

None.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 7b3e35e60351b27b57fda6abdae42bae2c271b3c (SPEC-338 Complete and released; origin/main is the same commit).

Authority: DELEGATED under the owner's AFK Mode and answered by the constitution; never typed by the owner. This contract grants nothing beyond the following owner's words:

- 2026-11-23, Workbench `data/records/batch6/owner-words/owner-2026-11-23-modes-any-session.txt`, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73: AFK Mode is a tool that decides by the project's rules and widens nothing.
- 2026-11-22, `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D: Batch 6 finishes first.
- 2026-11-23, `data/records/WS-048/owner-words/owner-2026-11-23-continue-until-b6-finish.txt`, SHA-256 7D2A8B8F0F209C8538B0D87F133C440DBB620C2577DEAECF8F3D312584C94759: the delegation continues until the Batch 6 Finish.

The evidence is Workbench `data/records/batch6/exit-bundle-m/spec339/`: the payload, the EC-9 Primary re-read, the consistency log and the guard suites; `r2/` holds this revision and the reason for it.

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `e2fb1c95d6e393a07d8df12d274babc46373720e` |
| `_ORVION_CANONICAL/manifest.md` | `1650a4eb9d8657be60b22ceb648475aeb54cfc9b` |
| `GOVERNANCE.md` | `5670c47888bbd6b4194f6c41c54476ee42cb7bdf` |
| `scripts/test_cold_start_state_guard.ps1` | `b36a1b40bccf9ec5a3b4a106f6356ea7e9108ffb` |
