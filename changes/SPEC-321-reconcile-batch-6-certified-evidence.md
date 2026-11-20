# Change Request — SPEC-321

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Reconcile the CRM Batch 6 Action Registry against the individually certified archive, task-entry and branch-authority member repairs.

## Business Reason

The native selector found zero unrecorded surfaces and the registry has 14 engineering obligations at B6-EXIT. Three registry treatments still present certified repairs as pending. One record-only reconciliation proves each member separately while using the same native guards and release.

- ARCH-2: SPEC-319, Test 182 and Primary readback establish the covered archive members. Bookings return to FIRST-BOOKING for BOOK-11 and BOOK-12. Passengers return to ENABLE-SURFACE-WORKFLOW for PAX-8. Both dispositions remain AUDITED-OPEN.
- ENTRY-1: SPEC-318, the unchanged task trigger migration and the carried Test 134 entry assertions establish task closure. Booking items and marketing campaigns still require their respective assessments. CAMP-2 retains its status.
- STEPUP-1 and BRANCH-1: SPEC-320, Tests 58/130 and Primary readback establish the branch member closure. BRANCH-1 stays COMPLETED at its original workflow boundary. BRANCH-2 stays open at that boundary. Campaign daily metrics and exchange-rate adjustments still need their targeted evidence.

The other due obligations require separate lifecycle, financial-integrity or authority evidence. This contract has a single product-record payload and no deployment.

## Risks

Changing registry language could imply class closure or move an independent obligation. Keep ARCH-2, ENTRY-1 and STEPUP-1 due at B6-EXIT. Keep CAMP-2, PAX-4 and every other outstanding obligation at its established status and boundary. Change only the two independently justified surface deadlines. Preserve B6-EXIT itself and every exit criterion.

## Supersedes / Depends On

Revises the unapproved CRM SPEC-321 r1 Draft. Extends SPEC-317 record reconciliation and uses certified SPEC-318, SPEC-319 and SPEC-320 evidence. Their terminal contracts are immutable.

## Write Scope

- `changes/SPEC-321-reconcile-batch-6-certified-evidence.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `scripts/batch6_select_target.ps1`
- `scripts/readiness_population.ps1`
- `scripts/check_repository_consistency.ps1`
- `supabase/config.toml`

Product code, migrations, tests, hosted changes, Founder ORVION, integration activation and owner decisions are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9.
- `reports/master/MASTER_EXECUTION_PLAN.md` Action Registry and exit criteria.
- `reports/master/MASTER_GAP_REGISTER.md` ARCH-2, ENTRY-1, STEPUP-1, BRANCH-1, BRANCH-2, BOOK-11, BOOK-12, PAX-8 and CAMP-2.
- `reports/master/MASTER_SURFACE_DISPOSITION.md` bookings, passengers, suppliers, tasks and branches.
- CRM SPEC-318, SPEC-319 and SPEC-320 Original Review and verification.

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Routine

### Draft Assurance

Pass 1 Design: Use one Action Registry payload for the three independently proved member reconciliations and return only the two ARCH-2 surface rows to their existing triggers. Retain the original live scope boundary of a local product-record change.

Pass 2 Adversarial Review: Reviewed all 14 due obligations. The resolved task and branch members have real closure evidence. CHAT-2 and the accounting, payment and refund obligations lack comparable closure or containment evidence. CAMP-2 and PAX-4 still need their targeted work. Three class IDs remain due and moving their residual scopes is out of scope.

Pass 3 Evidence Refresh: 2026-11-20. Verified all three certified release receipts and ancestry at d7960b8ddd9675c339ce464440b480141fc4d9c3. Confirmed the carried Test 134 entry assertions and original task migration, the SPEC-319 Test 182 member proof and SPEC-320 Tests 58/130. Isolated replay derived 12 B6-EXIT obligations and 78 recorded dispositions. Native consistency including Check 29 passed. Only the nine named native rows change, two of them in state and boundary.

Selected Version: SPEC-321 r2, exact single-file record payload covering ARCH-2, ENTRY-1 and STEPUP-1/BRANCH-1 member evidence.

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| ARCH-2 and two surface deadlines | Action Registry and Check 29 | WRITE | Use SPEC-319/Test 182 and preserve both AUDITED-OPEN dispositions. |
| ENTRY-1 task and STEPUP-1 branch evidence | Action Registry and Check 29 | WRITE | Use SPEC-318/Test 134 and SPEC-320/Tests 58 and 130. Keep both classes due. |
| BRANCH-1 and other workflow obligations | Action Registry and Check 29 | WRITE | Give the already completed BRANCH-1 its verified treatment at its original boundary. Keep the other workflow rows' evaluated values identical. |
| Independent findings and dispositions | Gap Register and Surface Disposition | UNAFFECTED | Same blobs as the certified baseline. |
| Native lifecycle metadata | Manifest and discovery | WRITE | Synchronize the active pointer and terminal entry under the native lifecycle. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchor and exact row payload | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Check 29 and unchanged unrelated native values | BEFORE_COMPLETION | NONE | NONE | 2 |
| Native local certification and Review | BEFORE_COMPLETION | NONE | NONE | NONE |

## Implementation Steps

1. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Fixed by SPEC-320. Tests 58 and 130`; if so record Already Applied when its Git blob is 3347d75afa11a93738478c161eb6382d0ba2c269, and otherwise stop and report. Otherwise make exactly these 6 edits (the exact certified member reconciliations and two surface deadlines), each matched once, and change nothing else:

   a) replace the lines
   ```text
   | ENTRY-1 | VERIFIED DEFECT | engineering | `B6-EXIT` | Canon 26 and each creation path | Nine members have recorded closure. Tests 127 and 134 still document campaign and task entry. Check `booking_items` against its current creation contract and tests 74/105. Smallest known repair: task-local entry authority and a matching negative test. A campaign or booking-item rule requires its own canon and consequence evidence. |
   | ARCH-2 | VERIFIED DEFECT | engineering | `B6-EXIT` | Each surface's existing archive contract | SPEC-216/257/262 close documents, service requests and complaints. SPEC-310 records the customer-note exception. SPEC-215 and test 134 leave suppliers and tasks open. Bound those two repairs under their existing archive authority and confirm other historical members before expanding repair scope. |
   ```
   with
   ```text
   | ENTRY-1 | VERIFIED DEFECT | engineering | `B6-EXIT` | Canon 26 and each creation path | SPEC-318 and Test 134 close task terminal-state entry on Platinum Primary. Previously closed members retain their evidence. Review booking_items against its creation contract and tests 74/105. Assess marketing campaign entry with CAMP-2 and Test 127. Keep both residual entry assessments due at B6-EXIT. |
   | ARCH-2 | VERIFIED DEFECT | engineering | `B6-EXIT` | Each surface's existing archive contract | SPEC-319 and Test 182 close archive-at-entry for bookings, passengers, suppliers and tasks on Platinum Primary and verify the existing customers metadata check. SPEC-216/257/262 hold for documents, service requests and complaints. SPEC-310 retains the customer-note position. Leads, invoices, quotations and booking items remain due. |
   ```

   b) replace the line
   ```text
   | STEPUP-1 | VERIFIED DEFECT | engineering | `B6-EXIT` | Individual write authority and EC-2 | UNPROVEN as a class. SPEC-245/246/278/301/305/307 close named member repairs. BRANCH-1 is the remaining demonstrated member. Check the two unswept candidate surfaces, campaign daily metrics and exchange-rate adjustments, before assigning additional repairs. |
   ```
   with
   ```text
   | STEPUP-1 | VERIFIED DEFECT | engineering | `B6-EXIT` | Individual write authority and EC-2 | UNPROVEN as a class. SPEC-320 and Tests 58/130 close the demonstrated BRANCH-1 member on Platinum Primary. Prior member repairs remain recorded. Campaign daily metrics and exchange-rate adjustments still require targeted authority evidence before additional repairs are assigned. |
   ```

   c) replace the line
   ```text
   | CHAT-2, CAMP-4, BRANCH-1, BRANCH-2, PAX-8 | VERIFIED DEFECT | engineering | `ENABLE-SURFACE-WORKFLOW` | — | Low. Audit and timeline evidence is missing at a table door, and each finding's measured bound is that nothing reads it. At the gate the bound is re-measured: if it holds, the item becomes an explicit accepted residual; otherwise it is repaired. Never deferred silently |
   ```
   with
   ```text
   | CHAT-2, CAMP-4, BRANCH-2, PAX-8 | VERIFIED DEFECT | engineering | `ENABLE-SURFACE-WORKFLOW` | — | Low. Audit and timeline evidence is missing at a table door, and each finding's measured bound is that nothing reads it. At the gate the bound is re-measured: if it holds, the item becomes an explicit accepted residual; otherwise it is repaired. Never deferred silently |
   | BRANCH-1 | VERIFIED DEFECT | engineering | `ENABLE-SURFACE-WORKFLOW` | — | Fixed by SPEC-320. Tests 58 and 130 and the independent Platinum Primary readback verify branch write permission and MFA. BRANCH-2 remains a separate workflow obligation. |
   ```

   d) replace the lines
   ```text
   | `bookings` | SURFACE | engineering | `B6-EXIT` | ARCH-2 assessment and BOOK-11/BOOK-12 | SPEC-239 fixes booking entry and issuance, and SPEC-224 fixes PAX-9. Check ARCH-2 at entry. Keep cancellation evidence and the customer-freeze rule at the BOOK-11/BOOK-12 boundary. |
   | `branches` | SURFACE | engineering | `ENABLE-SURFACE-WORKFLOW` | STEPUP-1 branch member | SPEC-226 and test 130 document the branch evidence. Scope any required write-authority repair to BRANCH-1. BRANCH-2 retains its enablement gate. |
   ```
   with
   ```text
   | `bookings` | SURFACE | engineering | `FIRST-BOOKING` | BOOK-11 and BOOK-12 | SPEC-319 and Test 182 verify ARCH-2 at entry on Platinum Primary. SPEC-239 fixes booking entry and issuance, and SPEC-224 fixes PAX-9. BOOK-11 and BOOK-12 remain open at FIRST-BOOKING. |
   | `branches` | SURFACE | engineering | `ENABLE-SURFACE-WORKFLOW` | STEPUP-1 branch member | SPEC-320 and Tests 58/130 verify the BRANCH-1 repair on Platinum Primary. BRANCH-2 retains its workflow-enablement gate. |
   ```

   e) replace the line
   ```text
   | `passengers` | SURFACE | engineering | `B6-EXIT` | ARCH-2 assessment and PAX-8 | SPEC-223 and test 128 close PAX-7 and record PAX-8 open. Verify archive-at-entry scope and preserve PAX-8's workflow gate. |
   ```
   with
   ```text
   | `passengers` | SURFACE | engineering | `ENABLE-SURFACE-WORKFLOW` | PAX-8 | SPEC-319 and Test 182 verify ARCH-2 at entry on Platinum Primary. SPEC-223 and Test 128 close PAX-7. PAX-8 remains open at ENABLE-SURFACE-WORKFLOW. |
   ```

   f) replace the lines
   ```text
   | `suppliers` | SURFACE | engineering | `B6-EXIT` | ARCH-2 supplier member | SPEC-215 and test 121 close creation attribution. The recorded supplier archive-at-entry consequence supports the bounded ARCH-2 repair. |
   | `tasks` | SURFACE | engineering | `B6-EXIT` | ENTRY-1 and ARCH-2 task members | SPEC-230 and test 134 close TASK-4 and document the two open entry invariants. Keep the two repairs bounded to existing task authorities. |
   ```
   with
   ```text
   | `suppliers` | SURFACE | engineering | `B6-EXIT` | ARCH-2 supplier member | SPEC-215 and Test 121 close creation attribution. SPEC-319 and Test 182 verify the ARCH-2 supplier member on Platinum Primary. |
   | `tasks` | SURFACE | engineering | `B6-EXIT` | ENTRY-1 and ARCH-2 task members | SPEC-230 and Test 134 close TASK-4. SPEC-318 and Test 134 verify task entry under ENTRY-1, and SPEC-319 and Test 182 verify the ARCH-2 task member on Platinum Primary. |
   ```

   The resulting file's Git blob is 3347d75afa11a93738478c161eb6382d0ba2c269.

2. Compare the result with the isolated native replay. Verify the two NOT DUE surface rows against their own triggers, the twelve engineering obligations remaining at B6-EXIT, the three still-due class IDs, the completed BRANCH-1 row and the unchanged BRANCH-2 workflow obligation. Confirm identical unrelated registry rows and unchanged Gap Register, Surface Disposition and exit criteria. Run native consistency and discovery, synchronize the contract, and follow the timed and watched native Finish, Review and Complete. At Complete use `SPEC-321: Certified Batch 6 member evidence reconciled.` as the manifest completion text. Publication and promotion retain their separate exact-candidate gates.

## Acceptance Criteria

- [x] The Action Registry plan equals the exact isolated record payload. `check: blob reports/master/MASTER_EXECUTION_PLAN.md 3347d75afa11a93738478c161eb6382d0ba2c269`
- [x] ARCH-2 remains due for leads, invoices, quotations and booking items. The two covered surfaces keep AUDITED-OPEN and retain BOOK-11/BOOK-12 and PAX-8 at their already recorded triggers. SPEC-319 and Test 182 support each affected member.
- [x] ENTRY-1 records the independently verified SPEC-318 task closure with the Test 134 evidence. Booking items and marketing campaigns remain in scope for their respective assessments. CAMP-2 stays due.
- [x] STEPUP-1 remains due for the two outstanding candidate assessments. BRANCH-1 records the verified SPEC-320 closure with Tests 58/130 at its original boundary. BRANCH-2 retains its open workflow obligation.
- [x] The independent finding evidence, status and trigger records are preserved. `check: same reports/master/MASTER_GAP_REGISTER.md @d7960b8ddd9675c339ce464440b480141fc4d9c3`
- [x] The surface dispositions and coverage remain as recorded. `check: same reports/master/MASTER_SURFACE_DISPOSITION.md @d7960b8ddd9675c339ce464440b480141fc4d9c3`
- [x] The native registry evaluator is unchanged. `check: same scripts/readiness_population.ps1 @d7960b8ddd9675c339ce464440b480141fc4d9c3`
- [x] Native Check 29 derives twelve due at B6-EXIT, 78 recorded surfaces and identical results for unrelated rows. EC-1 through EC-11 retain their recorded statuses.

## Execution Log

None.

### 2026-11-20 — Original implementation

Outcome: Implementation complete. Native Finish and independent Review pending.

- Step 1 Applied: The frozen CRM contract produced the exact Action Registry blob 3347d75afa11a93738478c161eb6382d0ba2c269.
- Step 2 Applied: The native registry matched the isolated replay on every row. B6-EXIT moves from 14 to 12, bookings and passengers keep their existing open findings and workflow triggers, and all 78 surface dispositions and EC rows are preserved. BRANCH-1 is verified complete and BRANCH-2 remains at its workflow trigger. Native consistency runs in the commit Gate. Timed Finish, independent Review and Complete follow in order.

## Verification Notes

None.


### 2026-11-20 — Gate 1 approval recorded

The owner answered the exact SPEC-321 r2 Gate 1 request in the current session. The approval is bound to the single presented Draft SHA-256 0498F86977F5F7ED0C7C2F31E7D11347617C680C1F6652A317EAA9EEF994DFBE. Verbatim reply retained in private Workbench evidence OWNER-ORIGINAL-APPROVAL.txt with SHA-256 3B262234FC8711BE0971B08707BD05C8C54F0C141DB945DA7320DFE923A34C62. The scope is the frozen CRM record-only candidate and the native Original lifecycle. Immediately before allocation the hash, the Draft blob 0355937cacbcb463bc178fba91fa5e918bd3b794, all 1 source anchors, the baseline HEAD d7960b8ddd9675c339ce464440b480141fc4d9c3 against refreshed origin/main d7960b8ddd9675c339ce464440b480141fc4d9c3 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as e244dfc. No implementation performed before this transition. No production write applies to this contract. Owner publication and promotion retain their native release authority.


### 2026-11-20 — Independent Original Review

Verdict: Confirmed Complete

Findings: Verified committed Original e131dfdfe6894528206e2539f00726839461af92 against baseline d7960b8ddd9675c339ce464440b480141fc4d9c3. Only the scoped contract, plan, active manifest pointer and its generated map changed. The plan blob equals 3347d75afa11a93738478c161eb6382d0ba2c269 and the native committed registry matches the complete isolated replay. Check 29 derives 12 due at B6-EXIT. ARCH-2, ENTRY-1, STEPUP-1, CAMP-2 and PAX-4 remain due. Bookings and passengers remain AUDITED-OPEN at their individual triggers. BRANCH-1 is complete at its original workflow boundary and BRANCH-2 remains open at that boundary. The finding and disposition records and native evaluator are byte-identical to baseline. All 78 recorded dispositions and all exit criteria are preserved. Native watched Finish returned LOCAL_CERTIFY READY with receipt SHA-256 457C5D35BD3A2ABBB0AB5E91D0ACB32D539FC6DD2A8CE92DA6C559608FD27873.

Recommendation: Complete and bind the exact record-only Original. No deployment applies.

### 2026-11-20 — Original completion

Verdict: Confirmed Complete

The independent Original Review 3aab20a3352c15e93ed7083e51cd70cf84350849 and the native Finish receipt certify the scoped record reconciliation. All exit criteria and surface dispositions are preserved. The candidate derives 12 engineering obligations at B6-EXIT. Publication and promotion are outside the local Complete verdict.

## Review Gate

- [x] Every change matches the accepted implementation steps.
- [x] All changed paths are within Write Scope.
- [x] Every acceptance criterion is confirmed by local evidence.
- [x] Native Finish evidence and independent Review are present.

## Notes

Revision: r2. Supersedes the unapproved r1 SHA-256 9887C0DA73B8AD8F437E082FFF2CBE824D9BF50E2ECC4733BF6EE9ABD90613D6. The r1 bytes are preserved.

Baseline: d7960b8ddd9675c339ce464440b480141fc4d9c3.

Evidence: isolated native registry replay and Check 29, certified SPEC-318 at 243fd86c53715a4eb69f02e97353cfa2ad90ea8e, SPEC-319 at 21d411b0e642c68b90cec795bbab0c86f27c8bee, and SPEC-320 at d7960b8ddd9675c339ce464440b480141fc4d9c3. Each release receipt and Primary readback remains the original evidence in Workbench.

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `4d6d6ea5fb0ca2ae50eeff90e151ff041d50fac6` |
