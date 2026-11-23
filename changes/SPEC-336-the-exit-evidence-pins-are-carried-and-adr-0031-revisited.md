# Change Request — SPEC-336

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Deliver what SPEC-335 approved. SPEC-335's implementation (b274da4) passed its native Finish, but its Complete refused criterion 9 because no Implementation Step wrote the ADR-0031 revisit line, and SPEC-335 was Cancelled at b78739119185d7b7c4bb20c422e47a8cda088469. This successor carries that implementation unchanged: Tests 192, 193 and 194, the plan, register and surface disposition records and the manifest figure, which close the EC-5, EC-7 and EC-8 evidence gaps and record the owner's decision of 2026-11-23 to decline CTRL-19's GitHub configuration repair. It adds the one missing step: ADR-0031, whose revisit trigger is a change to CTRL-19, records its revisit and stands.

## Business Reason

The exit evidence SPEC-335 produced is correct and already proven, but a contract that cannot Complete delivers nothing: the gate evaluation needs it terminal and released (DEC-33 rule 12). The native route for an approved contract that cannot Complete is Cancel plus one successor named in Supersedes (CR_LIFECYCLE section 4; SPEC-271 → SPEC-272 carried a committed implementation forward unchanged). The smallest successor adds only the line SPEC-335 left out (DEC-33 rule 3).

## Risks

The carried outputs are not rewritten, so a carried defect would pass through; each is bound by its exact Git blob below, and the full DATABASE readiness reruns them in this contract's own Finish. A presence pin proves that a control exists with its recorded definition, not that it behaves; an OPEN pin records a defect, not desired behaviour; both are SPEC-335's accepted design. This contract changes no migration, function, policy, grant or database object, and marks no exit criterion met. Accepting CTRL-19 leaves the agent's credential administering the repository; the containment is the promotion path through `scripts/promote_main.ps1` under `-Gate -Trusted`, and the decision is the owner's own.

## Supersedes / Depends On

Supersedes `changes/SPEC-335-the-exit-evidence-gaps-are-pinned-and-the-re-sweep-registered.md` (Cancelled at b78739119185d7b7c4bb20c422e47a8cda088469) and carries its committed implementation b274da4 unchanged. Extends the SPEC-334 refusal proofs (Tests 190 and 191) and the house shape-pin pattern of Tests 148 and 153. Those terminal contracts are immutable.

## Write Scope

- `changes/SPEC-336-the-exit-evidence-pins-are-carried-and-adr-0031-revisited.md`
- `supabase/tests/192_a_customer_lock_is_taken_before_its_judgement_test.sql`
- `supabase/tests/193_structural_control_presence_test.sql`
- `supabase/tests/194_door_evidence_and_sale_dates_open_pins_test.sql`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `_ORVION_CANONICAL/manifest.md`
- `reports/architecture-decision-records.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_API_CONTRACT.md`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `.github/workflows/repository-consistency.yml`
- `supabase/config.toml`

Migrations, product code, any change to the carried SPEC-335 outputs, the repair of any finding they register, any Primary write, Founder Secondary, frontend work, integration activation, email delivery and every owner decision are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9.
- `changes/SPEC-335-the-exit-evidence-gaps-are-pinned-and-the-re-sweep-registered.md`.
- `reports/architecture-decision-records.md` ADR-0031.
- `reports/master/MASTER_EXECUTION_PLAN.md` the exit criteria EC-5 to EC-8 and the gate table.

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

Pass 1 Design: One literal step appends the ADR-0031 revisit line after its revisit-trigger list. The seven SPEC-335 outputs are already at b78739119185d7b7c4bb20c422e47a8cda088469 through its committed implementation b274da4; Acceptance Criteria bind each by its exact Git blob or measured text, so no step rewrites them and any drift fails Complete.

Pass 2 Adversarial Review: The SPEC-335 refusal is reproduced as a requirement: criterion `has reports/architecture-decision-records.md "Revisited 2026-11-23 (SPEC-336)"` fails at b78739119185d7b7c4bb20c422e47a8cda088469 and passes only after step 1. The carried blobs equal SPEC-335's approved payload (00d4d776, 472b404c, 0390d2a9, 984a32d8, 424d084a, 222ee26c and the manifest figure). The SPEC-335 mutation sets stay its evidence: Test 192 fails 4 of 4 on reversed locks, Test 193 fails for each of its 302 removals, Test 194 fails on each of 7 repairing mutants. A sandbox Complete runs before the original Approve, the check SPEC-335 lacked.

Pass 3 Evidence Refresh: 2026-11-23. On the candidate tree (b78739119185d7b7c4bb20c422e47a8cda088469 plus step 1), native repository consistency was CLEAN. SPEC-335's own Finish at b274da4, the same seven outputs, reported LOCAL_CERTIFY READY with the full DATABASE protocol (194 files, 3609 assertions, 0 failing).

Selected Version: SPEC-336; selected: carry the cancelled SPEC-335 implementation unchanged (WS-048 carried-Cancel baseline) and add the one ADR-0031 revisit line its Complete found unwritten, the smallest change that delivers SPEC-335 with every one of its checks

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| ADR-0031 revisit line | ADR readers and the CTRL-19 revisit trigger | WRITE | One appended line; the decision stands unchanged. |
| Carried Tests 192, 193 and 194 | Full pgTAP suite and the `B6-EXIT` gate evaluation | WRITE | 194 files and 3609 assertions, rerun in this contract's Finish. |
| Carried register, disposition, plan and manifest records | Checks 22, 24 and 29, EC-10 and the gate table | WRITE | Same blobs as SPEC-335's approved payload; the population stays complete with no COMPLETED member. |
| Schema, grants, policies and API | Every product consumer | UNAFFECTED | No migration; the API contract has the same blob as the baseline. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchors and exact payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Checks 22, 24 and 29 and the five hosted guard suites pass | BEFORE_COMPLETION | NONE | NONE | 2 |
| Full DATABASE readiness with Tests 192, 193 and 194 | BEFORE_COMPLETION | NONE | NONE | 2 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: The pgTAP suite with SPEC-335's carried Tests 192, 193 and 194 and their mutation-proven precedents, `supabase/tests/148_a_subscription_transition_is_judged_on_the_row_it_replaces_test.sql`, `supabase/tests/130_branch_door_audit_test.sql` and `supabase/tests/190_constraint_refusals_test.sql`.

Added Property: None beyond SPEC-335's: the CUST-10 and CUST-12 locks keep their statement and order; each of the 302 pinned structural controls stays present with its definition; and each of DOC-11, QUO-11, QUO-12 and BOOK-13 stays recorded as open until a repair updates its pin.

Causal Negative: At 676df3e, removing either CUST lock, or any of the 302 pinned controls, passes every pgTAP file that names its function or table (SPEC-335 evidence).

Positive Test Design: On the unmutated database Tests 192, 193 and 194 pass 4 of 4, 3 of 3 and 11 of 11.

Negative Test Design: SPEC-335's mutation sets, bound by the carried blobs: each lock mutant fails Test 192, each control removal fails Test 193, and each simulated repair fails Test 194.

Non-Empty Population Obligation: Test 192 asserts each function exists exactly once; Test 193's expected sets list every pinned control, so an empty catalog fails; Test 194's fixture holds one active `enterprise` tenant with a branch, a department, an employee, a branch manager, a customer, a supplier, two leads, a booking and a booking item.

Mutation Obligation: The carried blobs equal the bytes SPEC-335's mutation sets ran against.

Post-Implementation Proof Obligation: The native Finish runs the full DATABASE protocol with Tests 192, 193 and 194 and all five hosted guard suites through Additional Verification with zero failures. Hosted preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `reports/architecture-decision-records.md` contains `Revisited 2026-11-23 (SPEC-336)`; if so record Already Applied when its Git blob is db6c7d7dc989577e4e619f4b4211bcd55225ea32, and otherwise stop and report. Otherwise make exactly this one edit (the ADR-0031 revisit line), each matched once, and change nothing else:

   a) immediately after the line
   ```text
     - a change in how GitHub applies a ruleset's required status checks to a push.
   ```
   insert
   ```text
   - **Revisited 2026-11-23 (SPEC-336):** CTRL-19 changed: the owner declined its GitHub configuration repair, so it is an accepted residual (recorded by SPEC-335). The decision stands unchanged, because its promotion route is that residual's containment.
   ```

   The resulting file's Git blob is db6c7d7dc989577e4e619f4b4211bcd55225ea32.

2. **Establish readiness and verify.** Run the native DATABASE readiness: full SQL tests at 277 migrations with 194 files and 3609 assertions including Test 192 at 4 of 4, Test 193 at 3 of 3 and Test 194 at 11 of 11, smoke and HTTP, and API generation with the API contract unchanged. Run the native repository guard and the five hosted guard suites named in Additional Verification. Confirm that `readiness_population.ps1` reports REGISTRY complete with no COMPLETED member. Confirm the exact scope and `git diff --check`. Make no Primary write. Synchronize the contract and native discovery artifacts, set Runtime Checkpoint DONE and commit the implementation. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-336: The exit evidence pins are carried and ADR-0031 revisited.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] ADR-0031 records its revisit. `check: has reports/architecture-decision-records.md "Revisited 2026-11-23 (SPEC-336)"`
- [ ] Test 192 pins the CUST-10 and CUST-12 locks (carried). `check: blob supabase/tests/192_a_customer_lock_is_taken_before_its_judgement_test.sql 00d4d776f17ad411f4499ad454d446e0ac772623`
- [ ] Test 193 pins the surviving structural controls (carried). `check: blob supabase/tests/193_structural_control_presence_test.sql 472b404c67b1656b5c0013bbbb86f1b7a2e33b4a`
- [ ] Test 194 pins DOC-11, QUO-11, QUO-12 and BOOK-13 as OPEN (carried). `check: blob supabase/tests/194_door_evidence_and_sale_dates_open_pins_test.sql 0390d2a92ead6a69ff20e2276332adfc9a036c4c`
- [ ] The EC readings and gate rows are recorded (carried). `check: blob reports/master/MASTER_EXECUTION_PLAN.md 984a32d852fa86036f357c2761fa7aca6b9474fe`
- [ ] The register carries the new findings, the BRANCH-2 correction and CTRL-19's acceptance (carried). `check: blob reports/master/MASTER_GAP_REGISTER.md 424d084a30c76058ee2a081004d317f6e2b909c5`
- [ ] The disposition follows the findings (carried). `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md 222ee26cf30b5dff7b0bef93c76416b2c2fa7d6f`
- [ ] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **194 files / 3609 assertions**"`
- [ ] The manifest records the owner's CTRL-19 decision. `check: has _ORVION_CANONICAL/manifest.md "CTRL-19 is no longer an open owner decision"`
- [ ] The API contract is unchanged. `check: same reports/master/MASTER_API_CONTRACT.md @b78739119185d7b7c4bb20c422e47a8cda088469`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @b78739119185d7b7c4bb20c422e47a8cda088469`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @b78739119185d7b7c4bb20c422e47a8cda088469`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @b78739119185d7b7c4bb20c422e47a8cda088469`
- [ ] The cold-start guard suite is preserved. `check: same scripts/test_cold_start_state_guard.ps1 @b78739119185d7b7c4bb20c422e47a8cda088469`
- [ ] Full DATABASE readiness and all five hosted guard suites pass in the native Finish; no exit criterion is marked met.

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

Baseline: b78739119185d7b7c4bb20c422e47a8cda088469 (SPEC-335 Cancelled; its implementation b274da4 is carried; origin/main is 676df3e, SPEC-334 Complete and released).

Authority: DELEGATED under the owner's AFK Mode, answered by the constitution; never typed by the owner. The owner's words of 2026-11-23, Workbench `data/records/batch6/owner-words/owner-2026-11-23-modes-any-session.txt`, SHA-256 FE02A9FFFBDC408431E3FB59E944ADFED71B07F935BBB2291B7AA59B2A36CE73, make AFK Mode a tool that decides by the project's rules and widens nothing; the owner's words of 2026-11-22, `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D, direct Batch 6 to finish first; and the owner's words of 2026-11-23, `data/records/batch6/owner-words/owner-2026-11-23-ctrl19-declined.txt`, SHA-256 6882D7C5A1E1C71B05EE8AD878DD72100821972811F1E1358CA022623D333124, decline CTRL-19's repair. This contract grants nothing beyond them. The Cancel decision is Workbench `data/records/batch6/exit-bundle-j/spec335/DELEGATED-CANCEL.md`; the SPEC-335 evidence is `data/records/batch6/exit-bundle-j/` (`ec7/`, `ec5-extended/`, `gate-eval/`, `spec335/`).

| Path | Baseline Git blob |
| --- | --- |
| `reports/architecture-decision-records.md` | `0bc32a7ec591cfbeeb7b26333ce66825d04c3e26` |
