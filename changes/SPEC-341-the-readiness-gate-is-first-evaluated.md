# Change Request — SPEC-341

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Evaluate the Pre-Production Readiness Closure gate for the first time and record the result in its existing homes. `B6-EXIT` was REACHED by SPEC-340, so `GATE-EVAL` is due: the plan's boundary table says the gate is first evaluated before the first production tenant. On the evaluation date `scripts/readiness_population.ps1` re-derived the population at 15bff27b445bdddb7572e4128f9388629d959b03, every member is classified once and nothing is overdue. The verdict for `FIRST-TENANT` is NOT READY, by conditions 2, 3 and 4: APP-1 and GADS-1 are required capabilities not yet built, nine BUSINESS POLICY members are undecided, and no Day-1 journey can be proven end to end. This contract records the evaluation and the verdict, moves `GATE-EVAL` to REACHED, moves the two accepted residuals that waited for this evaluation to the boundaries their containment protects (CTRL-11 to `FIRST-TENANT`, FIN-9 to `FIRST-JOURNAL-ENTRY`) after re-confirming both from Primary read-only, and re-triages the backlog's untriggered ideas row to `OWN-TRIGGER`. No scope is READY; FE-0 and Phase 8 transport are not started.

## Business Reason

The gate exists so the first tenant is provisioned only on a proven-ready platform. Until its first evaluation is recorded, the registry cannot move `GATE-EVAL` to REACHED, and the three rows parked at it either stay parked against a boundary that has passed or become OVERDUE under Check 29 the moment it is reached. Recording the verdict in the plan, the register, the certification ledger and the backlog makes the evaluation durable for every later agent (DEC-30: the repositories are the memory) with the smallest change: no script, test, migration or database object changes (DEC-33 rule 3).

## Risks

A REACHED boundary makes any open member classified at it OVERDUE (Check 29). Three rows were classified at `GATE-EVAL`; each moves in this contract to the boundary its own trigger names, so the registry reports complete with nothing overdue on the candidate tree. The verdict could be read as a readiness claim; it is the opposite: `FIRST-TENANT` is NOT READY and the certification ledger keeps launch readiness CONDITIONAL. The Primary reads behind CTRL-11, FIN-9 and EC-9 are read-only and dated; a later write to Primary invalidates them, which is why each residual now waits for the boundary that enables writes. No owner decision is taken: the nine undecided BUSINESS POLICY members stay undecided and keep the first tenant blocked.

## Supersedes / Depends On

Supersedes nothing. Depends on SPEC-340 (`B6-EXIT` REACHED, Complete and released at 15bff27b445bdddb7572e4128f9388629d959b03) and SPEC-269 (the action registry and Check 29). Those terminal contracts are immutable.

## Write Scope

- `changes/SPEC-341-the-readiness-gate-is-first-evaluated.md`
- `_ORVION_CANONICAL/manifest.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_CERTIFICATION_STATUS.md`
- `reports/future-backlog.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `GOVERNANCE.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `.github/workflows/repository-consistency.yml`
- `supabase/config.toml`

Migrations, product code, test SQL, any owner decision (the BUSINESS POLICY members, OD-1…OD-8, MAIL-1, RET-1, PH8-10), building APP-1 or GADS-1, reaching `FIRST-TENANT` or any other boundary, the repair of any finding, starting FE-0 or Phase 8 transport, any Primary write, Founder Secondary, frontend work, integration activation and email delivery are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9.
- `reports/master/MASTER_EXECUTION_PLAN.md`: the Pre-Production Readiness Closure gate, its five conditions, the boundary table and the action registry rules.
- `scripts/readiness_population.ps1`: the population derivation and the OVERDUE rule.
- `reports/master/MASTER_GAP_REGISTER.md`: CTRL-11.
- `reports/master/MASTER_CERTIFICATION_STATUS.md`: the launch readiness row.
- `reports/future-backlog.md`: the backlog rows and their boundaries.

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- github

## Additional Verification

- pwsh -NoProfile -File scripts/test_future_date_guard.ps1
- pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1
- pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1
- pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1
- pwsh -NoProfile -File scripts/readiness_selftest.ps1

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Four literal steps write the four records, each bound by its exact Git blob. The plan gains a dated header, a "First evaluation" subsection with the per-condition reading and the verdict, the `GATE-EVAL` row REACHED, CTRL-11 and FIN-9 moved with dated re-confirmations, and a recorded exception beside bundle M's. The register re-confirms CTRL-11 under a new dated header; the certification ledger names the evaluation in its header, its launch readiness row and its history; the backlog row moves to `OWN-TRIGGER`. Every older header becomes `Previously:`.

Pass 2 Adversarial Review: Leaving the three rows at `GATE-EVAL` while reaching it fails Check 29 as OVERDUE, so each is moved, not deleted, to the boundary its own text names: CTRL-11's containment is the business-row count, which first changes at `FIRST-TENANT`; FIN-9's is the ledger's empty state, which first changes at `FIRST-JOURNAL-ENTRY`; the ideas row had no evidence of need and its trigger is evidence of need itself. Declaring any scope READY, or deciding a BUSINESS POLICY member on the owner's behalf, was rejected: conditions 2, 3 and 4 fail on recorded evidence and only the owner decides policy (DEC-02, DEC-05). No pin in `GOVERNANCE.md` §6 or the manifest names `GATE-EVAL`, so no pinned line changes; the manifest is in Write Scope only for the two lines the native lifecycle writes (`Active Change Request` at Approve, `Last Completed` at Complete). The first isolated rehearsal listed it Out of Scope and the sandbox Approve refused `OUT_OF_SCOPE_WRITE` before staging. A dated register line without a new header failed Check 21 in the isolated clone; the header was added and the rerun was CLEAN.

Pass 3 Evidence Refresh: 2026-11-25. `scripts/readiness_population.ps1` at 15bff27b445bdddb7572e4128f9388629d959b03: 547 finding ids, 426 settled, 121 not (109 open vocabulary, 6 other, 6 block only), 16 surfaces. Local stack at 15bff27b445bdddb7572e4128f9388629d959b03: `check_database_parity` CLEAN. Primary read-only: 277 migrations, the last `20261122100000`; every business table, `auth.users` and `storage.objects` hold 0 rows; `authenticated` holds no INSERT or UPDATE on either ledger table. In an isolated clone at 15bff27b445bdddb7572e4128f9388629d959b03 carrying the payload, the registry reported complete with nothing overdue (BLOCKED 20, NOT DUE 33, ACCEPTED RESIDUAL 28, FUTURE-ONLY 57; 10 backlog items NOT DUE), native repository consistency was CLEAN, and all five hosted guard suites passed with 0 failed: future-date 19, status contradiction 38, primary ledger 13, cold-start 42 and readiness self-test 33.

Selected Version: SPEC-341; selected: record the first evaluation of the readiness gate as measured on 2026-11-25 (population re-derived, every member classified, FIRST-TENANT NOT READY by conditions 2, 3 and 4), move GATE-EVAL to REACHED and its three waiting rows to the boundaries their own triggers name, with no owner decision taken and no script, test or database change, the smallest change that makes the evaluation durable and keeps Check 29 complete with nothing overdue

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Dated headers of the plan, register and certification ledger | Check 21 and agent cold start | WRITE | One new dated line each; every older header becomes `Previously:`; the candidate tree is CLEAN. |
| Boundary row `GATE-EVAL` REACHED | Check 29 (`readiness_population.ps1`) | WRITE | No open member is classified at `GATE-EVAL`; REGISTRY complete, nothing overdue. |
| CTRL-11 at `FIRST-TENANT`, FIN-9 at `FIRST-JOURNAL-ENTRY` | Check 29 and the register | WRITE | Both stay ACCEPTED RESIDUAL at NOT REACHED boundaries; re-confirmed from Primary read-only. |
| Backlog ideas row at `OWN-TRIGGER` | Check 29 backlog pass | WRITE | The row reads NOT DUE; nothing is lost. |
| Launch readiness row and certification history | Certification ledger readers | WRITE | Launch readiness stays CONDITIONAL; no certification state changes. |
| Manifest `Active Change Request` and `Last Completed` lines | Agent cold start and the native lifecycle | WRITE | Written only by the native Approve and Complete; no pinned manifest line changes and Batch 6 stays recorded complete. |
| `GOVERNANCE.md` §6 pins, scripts, tests | Check 846 and `Validate-PinnedAuthority` | UNAFFECTED | Same blobs as the baseline; no pin names `GATE-EVAL`. |
| Schema, grants, policies and API | Every product consumer | UNAFFECTED | No migration; the API contract has the same blob as the baseline. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchors and exact payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Checks 21 and 29 and the five hosted guard suites pass | BEFORE_COMPLETION | NONE | NONE | 5 |
| Matching native verification evidence | BEFORE_COMPLETION | NONE | NONE | NONE |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: Check 29 in `scripts/readiness_population.ps1` and its mutation witness F3 in `scripts/test_cold_start_state_guard.ps1`.

Added Property: None: the existing control already fails a REACHED boundary that still carries an open member.

Causal Negative: Moving `GATE-EVAL` to REACHED while CTRL-11 stays classified at it makes the registry report CTRL-11 OVERDUE, which is why the residuals move in the same step.

Positive Test Design: On the new tree, the registry reports complete with nothing overdue, and native repository consistency is CLEAN.

Negative Test Design: F3 moves an open row to a REACHED boundary, and the consistency check must exit non-zero with OVERDUE; the cold-start guard runs it on the new tree.

Non-Empty Population Obligation: The registry classifies all 121 not-settled findings and the 10 backlog items on the new tree.

Mutation Obligation: F3 must fail as stated, and F-restore must return CLEAN.

Post-Implementation Proof Obligation: The native Finish runs the repository guard and all five hosted guard suites through Additional Verification with zero failures, and the hosted Repository Consistency and ORVION Acceptance preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Last updated: 2026-11-25 (CRM SPEC-341, the readiness gate's first evaluation`; if so record Already Applied when its Git blob is baf1e609dc3c75c8cb4df99e7541435921796695, and otherwise stop and report. Otherwise make exactly these 6 edits (the dated SPEC-341 header, the First evaluation subsection with its per-condition reading and verdict, the GATE-EVAL row REACHED, CTRL-11 moved to FIRST-TENANT and FIN-9 to FIRST-JOURNAL-ENTRY with their dated re-confirmations, and the recorded exception), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-25 (CRM exit bundle M, SPEC-340 carries the cancelled SPEC-339 unchanged: its implementation `af450d4` records `B6-EXIT` REACHED, and SPEC-340 adds only this line. DATABASE readiness rests on the SPEC-338 Original Finish on `3792b61`, whose `supabase` tree equals `7b3e35e` and is unchanged since, so SPEC-340 changes no database path and its Finish derives no DATABASE profile.)
   ```
   with
   ```text
   Last updated: 2026-11-25 (CRM SPEC-341, the readiness gate's first evaluation: `GATE-EVAL` is REACHED at `15bff27` and its verdict for `FIRST-TENANT` is NOT READY, by conditions 2, 3 and 4. CTRL-11 moves to `FIRST-TENANT` and FIN-9 to `FIRST-JOURNAL-ENTRY`, both re-confirmed from Primary; the backlog's untriggered ideas row is re-triaged to `OWN-TRIGGER`. No migration, database object, script or test changes.)

   Previously: 2026-11-25 (CRM exit bundle M, SPEC-340 carries the cancelled SPEC-339 unchanged: its implementation `af450d4` records `B6-EXIT` REACHED, and SPEC-340 adds only this line. DATABASE readiness rests on the SPEC-338 Original Finish on `3792b61`, whose `supabase` tree equals `7b3e35e` and is unchanged since, so SPEC-340 changes no database path and its Finish derives no DATABASE profile.)
   ```

   b) immediately after the lines
   ```text
   **Corrected 2026-10-09 (`SPEC-249`).** `scripts/readiness_population.ps1` replayed this derivation at `523888d`. It reads a shared row such as `CDD-5/BF-6/BF-7` as one finding per id, as the register's resolver does, and finds **446** ids: **322** settled and **124** not (106 open vocabulary, 8 other, 10 block only). The surfaces and the decision line are unchanged. Of the five additional members, B3, BF-3, CDD-4 and BF-6 were already placed below beside their row siblings. **BF-7** had been left unplaced and is now placed with CDD-5/BF-6.

   ```
   insert
   ```text
   ### First evaluation — 2026-11-25, at `15bff27`

   `SPEC-341` evaluates the gate for the first time, for the scope `FIRST-TENANT`, after `B6-EXIT` was REACHED. `scripts/readiness_population.ps1` re-derived the population on the evaluation date at `15bff27`: **547** finding ids, **426** settled and **121** not (109 open vocabulary, 6 other, 6 block only); 16 surfaces (`AUDITED-OPEN` 15, `PARTIAL` 1); the open-decision line names MAIL-1, OD-1, OD-2, OD-3, OD-5, OD-8, PH8-10 and RET-1. The registry is complete and nothing is overdue: BLOCKED 20, NOT DUE 33, ACCEPTED RESIDUAL 28, FUTURE-ONLY 57, and the 10 backlog items are NOT DUE.

   | Condition | Reading for `FIRST-TENANT` | Holds |
   |---|---|---|
   | 1 | the population was re-derived on 2026-11-25 and every member is classified once | yes |
   | 2 | APP-1 and GADS-1 are `REQUIRED CAPABILITY` members at `FIRST-TENANT` and are not built; their boundary works like a defect's | no |
   | 3 | nine `BUSINESS POLICY` members at `FIRST-TENANT` are undecided: DC-10, DC-12, DC-28, OD-1, OD-2, OD-3, OD-5, OD-8 and OPS-1 | no |
   | 4 | no Day-1 journey is enabled or can be proven end to end, because no client application exists (APP-1) | no |
   | 5 | EC-1…EC-11 held at `B6-EXIT` (SPEC-339); EC-9 re-proven on the evaluation date: the local stack's parity check is CLEAN, and Primary read-only holds 277 migrations, the last `20261122100000`, with every business table, `auth.users` and `storage.objects` at 0 rows | yes |

   **Verdict: `FIRST-TENANT` is NOT READY.** No scope is READY. The next evaluation is the one before the first production tenant is provisioned, and each later boundary is evaluated at its own enablement. CTRL-11 and FIN-9, the accepted residuals that waited for this evaluation, were re-confirmed against Primary on the same date and now wait for the boundaries their containment protects.
   ```

   c) replace the line
   ```text
   | `GATE-EVAL` | this gate is first evaluated, before the first production tenant | this section | NOT REACHED |
   ```
   with
   ```text
   | `GATE-EVAL` | this gate is first evaluated, before the first production tenant | this section | REACHED 2026-11-25 SPEC-341: first evaluated at `15bff27`; `FIRST-TENANT` NOT READY (conditions 2, 3 and 4); EC-9 re-read from Primary |
   ```

   d) replace the line
   ```text
   | CTRL-11 | ACCEPTED RESIDUAL | engineering | `GATE-EVAL` | — | A boundary's state is recorded by a contract, never observed: the guard cannot read Primary. Containment: provisioning a tenant needs `service_role`, and READY requires this gate's evaluation. At `GATE-EVAL`, and in every contract that enables a boundary, each boundary state is confirmed against Primary's business counts. A non-zero count under a `NOT REACHED` boundary is repaired before anything else. **2026-11-23 (SPEC-335):** confirmed against Primary at `676df3e`: every business table holds 0 rows |
   ```
   with
   ```text
   | CTRL-11 | ACCEPTED RESIDUAL | engineering | `FIRST-TENANT` | — | A boundary's state is recorded by a contract, never observed: the guard cannot read Primary. Containment: provisioning a tenant needs `service_role`, and READY requires this gate's evaluation. At `GATE-EVAL`, and in every contract that enables a boundary, each boundary state is confirmed against Primary's business counts. A non-zero count under a `NOT REACHED` boundary is repaired before anything else. **2026-11-23 (SPEC-335):** confirmed against Primary at `676df3e`: every business table holds 0 rows. **2026-11-25 (SPEC-341):** re-confirmed at the first gate evaluation against Primary at `15bff27`: every business table, `auth.users` and `storage.objects` hold 0 rows; the residual now waits for `FIRST-TENANT` |
   ```

   e) replace the line
   ```text
   | FIN-9 | ACCEPTED RESIDUAL | engineering | `GATE-EVAL` | — | The residual writer is only the platform writer; the gate re-checks that the platform's operational write path uses the RPC. **2026-11-23 (SPEC-335):** re-checked at `676df3e`: the only function that writes the ledger is `app.create_journal_entry`, locally and on Primary, and `authenticated` holds no INSERT or UPDATE on either ledger table |
   ```
   with
   ```text
   | FIN-9 | ACCEPTED RESIDUAL | engineering | `FIRST-JOURNAL-ENTRY` | — | The residual writer is only the platform writer; the gate re-checks that the platform's operational write path uses the RPC. **2026-11-23 (SPEC-335):** re-checked at `676df3e`: the only function that writes the ledger is `app.create_journal_entry`, locally and on Primary, and `authenticated` holds no INSERT or UPDATE on either ledger table. **2026-11-25 (SPEC-341):** re-checked at the first gate evaluation at `15bff27`, locally and on Primary, with the same result; the residual now waits for `FIRST-JOURNAL-ENTRY` |
   ```

   f) immediately after the lines
   ```text
   **Recorded exception, 2026-11-24, CRM exit bundle M.** After CRM SPEC-338 at `7b3e35e`, the Batch 6 delegation records `B6-EXIT` as REACHED in the owner's AFK mode, as its own contract. SPEC-339 changes no migration, database object or test SQL: it moves the boundary row to REACHED with its evidence, confirms EC-2, EC-3, EC-4 and EC-11, and updates the canonical manifest. Because no live member is due at `B6-EXIT`, the cold-start guard's F3 mutation now plants PAY-9 at the REACHED boundary and must name it as OVERDUE, which keeps Check 29 proven. `GATE-EVAL` stays NOT REACHED: it holds CTRL-11 and FIN-9 as accepted residuals and a backlog item. FE-0 and Phase 8 transport are not started and keep their own gates. The Original and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-25, CRM GATE-EVAL.** After CRM SPEC-340 at `15bff27`, the Batch 6 delegation evaluates the readiness gate for the first time in the owner's AFK mode, as its own contract. SPEC-341 changes no migration, database object, script or test: it records the first evaluation and its verdict, `FIRST-TENANT` NOT READY, moves `GATE-EVAL` to REACHED, moves CTRL-11 to `FIRST-TENANT` and FIN-9 to `FIRST-JOURNAL-ENTRY` after re-confirming both from Primary read-only, and re-triages the backlog's untriggered ideas row to `OWN-TRIGGER`. No owner decision is taken for the undecided BUSINESS POLICY members; they keep the first tenant blocked. FE-0 and Phase 8 transport are not started and keep their own gates. The Original and release gates remain enforced.

   ```

   The resulting file's Git blob is baf1e609dc3c75c8cb4df99e7541435921796695.

2. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `the first gate evaluation re-confirmed it against Primary`; if so record Already Applied when its Git blob is 08b8da4c065a8a211ed2e13b6970108f952bc5c4, and otherwise stop and report. Otherwise make exactly these 2 edits (the dated SPEC-341 header and the CTRL-11 re-confirmation note with its next trigger FIRST-TENANT), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-24 (CRM SPEC-338 registers CHAT-5, OPEN: an invalid conversation transition is refused as `permission denied: <NULL>` instead of its own message; Test 196 pins it.)
   ```
   with
   ```text
   Last updated: 2026-11-25 (CRM SPEC-341, the readiness gate's first evaluation, re-confirms CTRL-11 against Primary at `15bff27`: every business table, `auth.users` and `storage.objects` hold 0 rows. It stays an accepted residual; its next trigger is `FIRST-TENANT`.)

   Previously: 2026-11-24 (CRM SPEC-338 registers CHAT-5, OPEN: an invalid conversation transition is refused as `permission denied: <NULL>` instead of its own message; Test 196 pins it.)
   ```

   b) replace the line
   ```text
   | CTRL-11 | **A registry boundary's state is recorded, never observed, so a production boundary crossed outside a contract would not fail Check 29** | control plane / release safety | Medium | R | — | — | 🛡 | **OPEN — accepted residual, contained; reopened at the first gate evaluation.** Recorded by SPEC-269 from the owner's review of 2026-10-12. The guard holds no Primary credential by design, so `REACHED` is set by the contract that crosses a boundary. Read-only on Primary on 2026-10-12: 0 tenants, subscriptions, customers, bookings, payments, invoices, journal entries and receipts, and 251 migrations, so every first-production boundary is truly not reached today. **Containment:** provisioning needs `service_role`, and READY requires the gate's evaluation. **Trigger:** `GATE-EVAL`, and every contract that enables a boundary, confirms each boundary state against Primary's business counts. | — | SPEC-269-nothing-open-is-lost | 10-12 | 10-12 |
   ```
   with
   ```text
   | CTRL-11 | **A registry boundary's state is recorded, never observed, so a production boundary crossed outside a contract would not fail Check 29** | control plane / release safety | Medium | R | — | — | 🛡 | **OPEN — accepted residual, contained; reopened at the first gate evaluation.** Recorded by SPEC-269 from the owner's review of 2026-10-12. The guard holds no Primary credential by design, so `REACHED` is set by the contract that crosses a boundary. Read-only on Primary on 2026-10-12: 0 tenants, subscriptions, customers, bookings, payments, invoices, journal entries and receipts, and 251 migrations, so every first-production boundary is truly not reached today. **Containment:** provisioning needs `service_role`, and READY requires the gate's evaluation. **Trigger:** `GATE-EVAL`, and every contract that enables a boundary, confirms each boundary state against Primary's business counts. **2026-11-25 (SPEC-341):** the first gate evaluation re-confirmed it against Primary at `15bff27`: every business table, `auth.users` and `storage.objects` hold 0 rows. It stays an accepted residual; its trigger is now every contract that enables a boundary, next `FIRST-TENANT`. | — | SPEC-269-nothing-open-is-lost; SPEC-341-the-readiness-gate-is-first-evaluated | 10-12 | 11-25 |
   ```

   The resulting file's Git blob is 08b8da4c065a8a211ed2e13b6970108f952bc5c4.

3. Check whether `reports/master/MASTER_CERTIFICATION_STATUS.md` contains `The readiness gate is first evaluated.`; if so record Already Applied when its Git blob is 1148df87640114da911888afabf45ae1c914224f, and otherwise stop and report. Otherwise make exactly these 3 edits (the dated header, the launch readiness row naming the first evaluation and its verdict, and the certification history entry), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-10-08 (**Launch readiness now has exactly one gate.** The owner's 2026-10-08 directive (SPEC-248) puts the Pre-Production Readiness Closure gate in `MASTER_EXECUTION_PLAN.md`. This ledger keeps the launch-readiness verdict, points to the gate, and records no finding. No certification state changes.)
   ```
   with
   ```text
   Last updated: 2026-11-25 (**The readiness gate is first evaluated.** SPEC-341 evaluates the Pre-Production Readiness Closure gate at `15bff27`: `FIRST-TENANT` is NOT READY, so launch readiness stays CONDITIONAL. No certification state changes.)

   Previously: 2026-10-08 (**Launch readiness now has exactly one gate.** The owner's 2026-10-08 directive (SPEC-248) puts the Pre-Production Readiness Closure gate in `MASTER_EXECUTION_PLAN.md`. This ledger keeps the launch-readiness verdict, points to the gate, and records no finding. No certification state changes.)
   ```

   b) replace the line
   ```text
   | **Product/application launch readiness** | 🟡 **CONDITIONAL** | Database deployment is complete; the application UI/runtime surface is not implemented; Phase-8 n8n go-live now needs the n8n workflow itself to be built and verified (owner-exclusive credential setup is reported done but not agent-verified — `MASTER_INTEGRATION_CATALOG.md §3/§4`). **Launch readiness is decided only by the Pre-Production Readiness Closure gate in `MASTER_EXECUTION_PLAN.md` (owner directive 2026-10-08).** The gate is evaluated once Batch 6's EC-1…EC-11 hold, and again before each workflow or integration is enabled. It has not yet been evaluated, so no scope is READY. |
   ```
   with
   ```text
   | **Product/application launch readiness** | 🟡 **CONDITIONAL** | Database deployment is complete; the application UI/runtime surface is not implemented; Phase-8 n8n go-live now needs the n8n workflow itself to be built and verified (owner-exclusive credential setup is reported done but not agent-verified — `MASTER_INTEGRATION_CATALOG.md §3/§4`). **Launch readiness is decided only by the Pre-Production Readiness Closure gate in `MASTER_EXECUTION_PLAN.md` (owner directive 2026-10-08).** The gate is evaluated once Batch 6's EC-1…EC-11 hold, and again before each workflow or integration is enabled. It was first evaluated on 2026-11-25 (SPEC-341): `FIRST-TENANT` is NOT READY, so no scope is READY (see the plan's "First evaluation"). |
   ```

   c) immediately after the lines
   ```text
   ## Certification history

   ```
   insert
   ```text
   - **2026-11-25 (the readiness gate is first evaluated; no certification state changes)** — SPEC-341 evaluates the Pre-Production Readiness Closure gate at `15bff27` after `B6-EXIT` was reached. The population was re-derived (547 finding ids, 121 not settled) and every member is classified. `FIRST-TENANT` is NOT READY: APP-1 and GADS-1 are unbuilt, nine BUSINESS POLICY members are undecided, and no Day-1 journey can yet be proven. EC-9 was re-read from Primary: 277 migrations and 0 business rows. Product/application launch readiness stays 🟡 CONDITIONAL.

   ```

   The resulting file's Git blob is 1148df87640114da911888afabf45ae1c914224f.

4. Check whether `reports/future-backlog.md` contains `re-triaged at the gate's first evaluation, 2026-11-25, SPEC-341`; if so record Already Applied when its Git blob is e456a972649d0646e33dfe596a8a972c642d3344, and otherwise stop and report. Otherwise make exactly this one edit (the untriggered ideas row re-triaged to OWN-TRIGGER with no evidence of need), each matched once, and change nothing else:

   a) replace the line
   ```text
   | Ideas with no earned trigger: a structured address model, a capability dependency graph, a runtime AI-agent access model | engineering | Evidence of need; otherwise re-triaged at the gate's first evaluation | `GATE-EVAL` | Structural-Completeness Assessment and 10-year review, below |
   ```
   with
   ```text
   | Ideas with no earned trigger: a structured address model, a capability dependency graph, a runtime AI-agent access model | engineering | Evidence of need (re-triaged at the gate's first evaluation, 2026-11-25, SPEC-341: no evidence of need) | `OWN-TRIGGER` | Structural-Completeness Assessment and 10-year review, below |
   ```

   The resulting file's Git blob is e456a972649d0646e33dfe596a8a972c642d3344.

5. **Verify and synchronize.** Run the native repository guard and the five hosted guard suites named in Additional Verification. Confirm that `readiness_population.ps1` reports REGISTRY complete with no member at `GATE-EVAL` and nothing overdue, and that the `supabase` tree equals the baseline's. Confirm the exact scope and `git diff --check`. Make no Primary write. Synchronize the contract and native discovery artifacts, set Runtime Checkpoint DONE and commit the implementation. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-341: The readiness gate is first evaluated.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] The plan records the first evaluation, its verdict, `GATE-EVAL` REACHED and the moved residuals. `check: blob reports/master/MASTER_EXECUTION_PLAN.md baf1e609dc3c75c8cb4df99e7541435921796695`
- [ ] The register re-confirms CTRL-11. `check: blob reports/master/MASTER_GAP_REGISTER.md 08b8da4c065a8a211ed2e13b6970108f952bc5c4`
- [ ] The certification ledger names the evaluation and keeps launch readiness CONDITIONAL. `check: blob reports/master/MASTER_CERTIFICATION_STATUS.md 1148df87640114da911888afabf45ae1c914224f`
- [ ] The backlog ideas row is re-triaged to `OWN-TRIGGER`. `check: blob reports/future-backlog.md e456a972649d0646e33dfe596a8a972c642d3344`
- [ ] The manifest keeps Batch 6 recorded complete; only its lifecycle lines change. `check: has _ORVION_CANONICAL/manifest.md "is REACHED (SPEC-339); exit criteria EC-1…EC-11"`
- [ ] The governance pins are unchanged. `check: same GOVERNANCE.md @15bff27b445bdddb7572e4128f9388629d959b03`
- [ ] The API contract is unchanged. `check: same reports/master/MASTER_API_CONTRACT.md @15bff27b445bdddb7572e4128f9388629d959b03`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @15bff27b445bdddb7572e4128f9388629d959b03`
- [ ] The registry self-test is preserved. `check: same scripts/readiness_selftest.ps1 @15bff27b445bdddb7572e4128f9388629d959b03`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @15bff27b445bdddb7572e4128f9388629d959b03`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @15bff27b445bdddb7572e4128f9388629d959b03`
- [ ] The cold-start guard is preserved. `check: same scripts/test_cold_start_state_guard.ps1 @15bff27b445bdddb7572e4128f9388629d959b03`
- [ ] Repository consistency is CLEAN, the registry is complete with nothing overdue, and all five hosted guard suites pass in the native Finish; no scope is READY.

## Execution Log

None.


### 2026-11-25 — Implementation checkpoint (governed automation)

Outcome: Complete (implementation steps; final verification pending)

- Step 1 Applied: native recorded Gate 1 evidence names this exact Draft's SHA-256; the baseline HEAD was 15bff27b445bdddb7572e4128f9388629d959b03 and every source anchor matched there; Draft allocated as 16c69ce and approved as da2d1cf with APPROVAL_EVIDENCE: PASS.
- Step 2 Applied: `reports/master/MASTER_EXECUTION_PLAN.md` edited exactly as the step states; blob baf1e609dc3c75c8cb4df99e7541435921796695 (21 insertions, 4 deletions).
- Step 3 Applied: `reports/master/MASTER_GAP_REGISTER.md` edited exactly as the step states; blob 08b8da4c065a8a211ed2e13b6970108f952bc5c4 (4 insertions, 2 deletions).
- Step 4 Applied: `reports/master/MASTER_CERTIFICATION_STATUS.md` edited exactly as the step states; blob 1148df87640114da911888afabf45ae1c914224f (6 insertions, 2 deletions).
- Step 5 Applied: `reports/future-backlog.md` edited exactly as the step states; blob e456a972649d0646e33dfe596a8a972c642d3344 (1 insertions, 1 deletions).
- Step 6 Applied: generator rerun, `generate-ai-map.ps1 -Check` exit 0, the staged change names only Write Scope paths. Every edit was applied literally from this contract's steps and its Git blob checked before commit. Fresh timed and watched Finish, independent Review, Complete and candidate binding remain.

## Verification Notes

None.


### 2026-11-25 — Gate 1 approval recorded

DELEGATED Original Gate 1 for CRM SPEC-341 only under DEC-02 in the owner AFK Mode (owner-2026-11-23-modes-any-session.txt, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73) and the owner words to finish all plan (owner-2026-11-24-afk-finish-all-plan.txt, SHA-256 C155D6191185693D3DBBA01471540EA16A2C6BB0C6B835FFC08B82E792B968DE), the constitution deciding in the owner's absence (owner-2026-11-21-constitution-decides-in-my-absence.txt, SHA-256 DB34F67C2AF82D9A9751597247ABEEBD74B4BBB1CC6F47291D2572FE080EEAB0), continuing Batch 6 under the owner OD-9 decision of 2026-11-22 (SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D) and the owner prompt to continue until the Batch 6 Finish (SHA-256 7D2A8B8F0F209C8538B0D87F133C440DBB620C2577DEAECF8F3D312584C94759). Exact Draft SHA-256 E777B4B2DAFB74099308D88A48DA3202571ED8D7359FC5D5DFB934800DB394B5, Git blob 2cc68beb03acaf0c0329cfe8f9c82e7d2487d0ae, CRM baseline 15bff27 (SPEC-340 Complete, released). Records the first readiness gate evaluation: FIRST-TENANT NOT READY by conditions 2, 3 and 4, GATE-EVAL REACHED, CTRL-11 to FIRST-TENANT and FIN-9 to FIRST-JOURNAL-ENTRY after Primary read-only re-confirmation, backlog row to OWN-TRIGGER; no owner decision taken. Native isolated Approve 86df9de and implement cf8916e passed (4 committed blobs verified, equal to the proto), the product criterion checks on the sandbox tree passed 12 of 12, and the native repository consistency on the sandbox final tree is CLEAN (sandbox-final-consistency.log SHA-256 0431C41EC81458944FB06649266B72973CB4D21C59667BE92735C7F9225727BC). Derived profile REPOSITORY; no migration, no script or test change, no Primary write. Gate 1 only. Immediately before allocation the hash, the Draft blob 2cc68beb03acaf0c0329cfe8f9c82e7d2487d0ae, all 4 source anchors, the baseline HEAD 15bff27b445bdddb7572e4128f9388629d959b03 against refreshed origin/main 15bff27b445bdddb7572e4128f9388629d959b03 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 16c69ce. No implementation performed before this transition.


Verdict: Confirmed Complete

Independent current Git evidence (Claude main, DELEGATED Gate 1 in the owner's AFK Mode; checks the reviewer ran, not the author's): selected Draft E777B4B2DAFB74099308D88A48DA3202571ED8D7359FC5D5DFB934800DB394B5, allocated blob 2cc68beb03acaf0c0329cfe8f9c82e7d2487d0ae at 16c69ce; the range 15bff27..2f199f1 changes only Write Scope paths (the contract, the canonical manifest's lifecycle lines, the regenerated ai-map.json, reports/master/MASTER_EXECUTION_PLAN.md, reports/master/MASTER_GAP_REGISTER.md, reports/master/MASTER_CERTIFICATION_STATUS.md and reports/future-backlog.md); the four output blobs at HEAD equal the frozen payload (plan baf1e609, register 08b8da4c, certification 1148df87, backlog e456a972), their criteria; the native evaluator scripts/check_agent_continuity.ps1, Migration CI, scripts/readiness_population.ps1 and scripts/readiness_selftest.ps1 are byte-identical to the baseline; the supabase tree 8c210578 equals the baseline 15bff27, so no migration or database object changed. This original root owns fresh receipt digest 069d6b672f3118d645a514bd6d25c25707d8248940bfef1b8d47f59f525cbc13, finishHead 2f199f1d0dfdaf0a8ada717fd1e6d9eaac91e155, profile REPOSITORY, from a native timed and watched Finish observed LOCAL_CERTIFY READY and END exit 0 (15.0 min; runner, watcher and host exit 0): the future-date, status contradiction, primary ledger and cold-start guard suites and the readiness self-test all PASS. Native Complete, range and binder still own full receipt and criterion validation. No publication or hosted result asserted.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 15bff27b445bdddb7572e4128f9388629d959b03 (SPEC-340 Complete and released; origin/main and the product root both at it).

Authority: DELEGATED under the owner's AFK Mode and answered by the constitution; never typed by the owner. This contract grants nothing beyond the following owner's words:

- 2026-11-24 23:27:22 Cairo, Workbench `data/records/WS-049/owner-words/owner-2026-11-24-afk-finish-all-plan.txt`, SHA-256 C155D6191185693D3DBBA01471540EA16A2C6BB0C6B835FFC08B82E792B968DE: continue to finish all plan.
- 2026-11-21, `data/records/WS-046/owner-words/owner-2026-11-21-constitution-decides-in-my-absence.txt`, SHA-256 DB34F67C2AF82D9A9751597247ABEEBD74B4BBB1CC6F47291D2572FE080EEAB0: the constitution decides in the owner's absence.
- 2026-11-23, `data/records/batch6/owner-words/owner-2026-11-23-modes-any-session.txt`, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73: AFK Mode is a tool that decides by the project's rules and widens nothing.
- 2026-11-22, `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D: Batch 6 finishes first; the agent carries the engineering decision work.
- 2026-11-23, `data/records/WS-048/owner-words/owner-2026-11-23-continue-until-b6-finish.txt`, SHA-256 7D2A8B8F0F209C8538B0D87F133C440DBB620C2577DEAECF8F3D312584C94759: the delegation continues until the Batch 6 Finish.

The evidence is Workbench `data/records/batch6/gate-eval/`: `runtime/` holds the population log, the local parity check, the Primary read-only results, the registry and consistency logs (with the preserved Check 21 failure) and the five guard suite logs.

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `dd50b17c2a1d954c24769bac8fb3280048751acd` |
| `reports/master/MASTER_GAP_REGISTER.md` | `7c1bdefca422d936386f24e1b8a82c2c84434eaa` |
| `reports/master/MASTER_CERTIFICATION_STATUS.md` | `e9c25d3e5a29a680fad1b607abfd81494666ecde` |
| `reports/future-backlog.md` | `fd53b32c151a902f5ba52faa82d73bdbbcecf77d` |
