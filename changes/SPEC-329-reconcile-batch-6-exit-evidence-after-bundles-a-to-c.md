# Change Request — SPEC-329

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Reconcile the CRM Batch 6 exit evidence at 30501ca5f3d94862165898c3b7de86d84090b87b after exit bundles A to C: prune the eighteen Action Registry members the native evaluator derives COMPLETED, record OD-9 as decided by the owner, and restate the EC-2, EC-4 and EC-5 readings so they name only what remains.

## Business Reason

`scripts/readiness_population.ps1` at 30501ca5f3d94862165898c3b7de86d84090b87b reports `COMPLETED 18` and "completed ids still classified (18) - prune at the next edit": BRANCH-1, booking_items, RFD-3, PAY-5, tasks, journal_entry_lines, payments, CHAT-2, conversations, payment_allocations, refunds, FIN-11, suppliers, ARCH-2, PAX-4, ENTRY-1, PAY-4 and STEPUP-1. Their closure evidence is already certified and released: SPEC-318, SPEC-319, SPEC-320, SPEC-324, SPEC-326 and SPEC-328 (the carried SPEC-327 payload), with Tests 58, 130, 134, 145, 182, 183, 184 and 185.

On 2026-11-22 the owner decided OD-9: AFTER. Frontend work, including FE-0, begins only after `B6-EXIT`. The register still shows OD-9 as OPEN — PROPOSED, the manifest still lists it among the open owner decisions, and the registry still holds it as a BLOCKED owner row due at `B6-EXIT`.

After this reconciliation the registry has one engineering obligation due at `B6-EXIT` (RPC-1), down from thirteen. The remaining exit work is visible: the EC-2 per-writable-surface rationale and the RPC-1 permission remeasurement, EC-3, EC-6, EC-7, EC-8, EC-10 and EC-11, and the owner-controlled CTRL-19.

## Risks

A record prune could hide an open obligation or imply that a criterion is met. Only the members the native evaluator itself derives COMPLETED are removed. PAY-9 keeps FIRST-BOOKING, DC-11 keeps the finance model, and JE-2 stays contained fail-closed rather than fixed. RPC-1, CAMP-4, BRANCH-2 and PAX-8 keep their rows and boundaries. No exit criterion is marked met: EC-4 reads "members closed; confirmed at the gate evaluation". The OD-9 superseded text is retained in the register row. This contract adds no migration and no test, and it performs no database action.

## Supersedes / Depends On

Extends the SPEC-317, SPEC-321 and SPEC-322 record reconciliations, and uses the certified SPEC-318, SPEC-319, SPEC-320, SPEC-324, SPEC-326 and SPEC-328 evidence. Those terminal contracts are immutable.

## Write Scope

- `changes/SPEC-329-reconcile-batch-6-exit-evidence-after-bundles-a-to-c.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `scripts/readiness_population.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `supabase/config.toml`

Product code, migrations, tests, hosted changes, Founder ORVION, frontend work, integration activation and any other owner decision are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9.
- `reports/master/MASTER_EXECUTION_PLAN.md` Action Registry and the exit criteria EC-1 to EC-11.
- `reports/master/MASTER_GAP_REGISTER.md` OD-9, APP-1 and the eighteen pruned members.
- `scripts/readiness_population.ps1` classification and the COMPLETED derivation.
- CRM SPEC-324, SPEC-326 and SPEC-328 Original Review and verification.

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

- pwsh -NoProfile -File scripts/test_future_date_guard.ps1
- pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1
- pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1
- pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1
- pwsh -NoProfile -File scripts/readiness_selftest.ps1

## Pre-Approval Evidence

Change Class: Routine

### Draft Assurance

Pass 1 Design: One record-only payload over the plan, the register and the manifest. It removes the registry rows the native evaluator derives COMPLETED, records the owner's OD-9 decision in its register row, removes OD-9 from the manifest list of open decisions and from the registry, and restates EC-2, EC-4 and EC-5 with the certified member evidence.

Pass 2 Adversarial Review: Every pruned id appears in the native "prune at the next edit" list at 30501ca5f3d94862165898c3b7de86d84090b87b; nothing outside it is removed. CHAT-2 and `booking_items` sit in shared rows, so only those ids are removed and the remaining members keep their rows. The OD-9 row keeps its superseded text and its decider, which still satisfies Check 25. Adding a decided status to the register does not close any engineering obligation, and APP-1 keeps OD-5 as its login dependency. The five hosted guard suites are named in Additional Verification so the native Finish runs them before release.

Pass 3 Evidence Refresh: 2026-11-22. In an isolated clone at 30501ca5f3d94862165898c3b7de86d84090b87b carrying the payload, `readiness_population.ps1` reported open decisions CTRL-19, MAIL-1, OD-1, OD-2, OD-3, OD-5, OD-8, PH8-10 and RET-1, the registry at BLOCKED 20, NOT DUE 40, ACCEPTED RESIDUAL 26 and FUTURE-ONLY 58 with no COMPLETED member, and "REGISTRY: complete". Native repository consistency was CLEAN, and all five hosted guard suites passed (19, 33, 13, 42 and 33 assertions, 0 failed).

Selected Version: SPEC-329; selected: one record-only payload over the plan, the register and the manifest that prunes the eighteen registry members the native evaluator derives COMPLETED, records OD-9 as decided AFTER by the owner and restates the EC-2, EC-4 and EC-5 readings, the smallest change the native "prune at the next edit" obligation and the owner decision of 2026-11-22 require

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Eighteen COMPLETED registry members | Action Registry, Check 29 and `readiness_population.ps1` | WRITE | Prune only the ids the evaluator derives COMPLETED; the evaluator then reports no COMPLETED member and REGISTRY complete. |
| OD-9 owner decision | Gap Register, manifest open-decision list and Check 25 | WRITE | Record DECIDED BY THE OWNER 2026-11-22: AFTER with the superseded text and decider kept; the open-decision list drops OD-9. |
| EC-2, EC-4 and EC-5 readings | Exit criteria and the `B6-EXIT` gate evaluation | WRITE | Name the certified member evidence and what remains; no criterion is marked met. |
| Surface dispositions and the registry evaluator | Surface Disposition and `readiness_population.ps1` | UNAFFECTED | Same blobs as the baseline. |
| Native lifecycle metadata | Manifest and discovery | WRITE | Synchronize the active pointer and terminal entry under the native lifecycle. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchors and exact record payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Check 25, Check 29 and the five hosted guard suites pass | BEFORE_COMPLETION | NONE | NONE | 4 |
| Native local certification and Review | BEFORE_COMPLETION | NONE | NONE | NONE |

## Implementation Steps

1. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Last updated: 2026-11-22 (CRM exit bundle D, SPEC-329.`; if so record Already Applied when its Git blob is 9a2c647c9ba24676c5dbf55c82e53b0c710ac8cc, and otherwise stop and report. Otherwise make exactly these 14 edits (the registry prune, OD-9 decided, the EC readings and the dated SPEC-329 header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-22 (CRM exit bundle C, SPEC-328. The Action registry records the grouped selection of JE-2, through the fail-closed single-currency containment, and PAY-4, which share the finance-ledger write boundary; SPEC-327 delivered and deployed it and was cancelled, and this contract carries it forward.)
   ```
   with
   ```text
   Last updated: 2026-11-22 (CRM exit bundle D, SPEC-329. The exit evidence is reconciled at `30501ca` after bundles A to C: the Action registry prunes the eighteen members the register and the surface record have settled, OD-9 is recorded as decided by the owner (AFTER: FE-0 begins only after `B6-EXIT`), and the EC-2, EC-4 and EC-5 readings name what remains.)

   Previously: 2026-11-22 (CRM exit bundle C, SPEC-328. The Action registry records the grouped selection of JE-2, through the fail-closed single-currency containment, and PAY-4, which share the finance-ledger write boundary; SPEC-327 delivered and deployed it and was cancelled, and this contract carries it forward.)
   ```

   b) replace the line
   ```text
   **CRM exit evidence at `28e9052`, reconciled 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```
   with
   ```text
   **CRM exit evidence at `30501ca`, reconciled 2026-11-22 (SPEC-329), after the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```

   c) replace the line
   ```text
   - **EC-2 (partial):** Tests 57/58 carry 54/17/3. Finish the per-writable-surface rationale, PAX-4 and STEPUP-1 residual assessments, and RPC-1 permission remeasurement.
   ```
   with
   ```text
   - **EC-2 (partial):** Tests 57/58 carry 54/17/3. PAX-4 is fixed and STEPUP-1 is resolved for its `B6-EXIT` members (SPEC-320/324, Tests 58/130/183). Finish the per-writable-surface rationale and the RPC-1 permission remeasurement.
   ```

   d) replace the lines
   ```text
   - **EC-4 (open):** Tests 54/88 establish bounded transition and parent-state evidence. ENTRY-1 and CHAT-2 remain open. Reconcile their entry and transition contracts and the explicit surface boundaries.
   - **EC-5 (partial):** SPEC-316 smoke and both pgTAP passes cover exercised invariants. Map the remaining journal, payment, allocation and refund invariants to enforcement and evidence at their boundaries.
   ```
   with
   ```text
   - **EC-4 (members closed; confirmed at the gate evaluation):** Tests 54/88 establish bounded transition and parent-state evidence. ENTRY-1 is fixed by SPEC-318/324 (Tests 134/183) and CHAT-2 by SPEC-326 (Test 184), on Platinum Primary; no registry member of EC-4 remains open.
   - **EC-5 (partial):** SPEC-316 smoke and both pgTAP passes cover exercised invariants. RFD-3 and the PAY-5/FIN-11 unit are fixed by SPEC-326 (Test 184), PAY-4 by SPEC-327 (Test 185), and JE-2 is contained fail-closed by SPEC-327 (Tests 145/185). PAY-9 keeps `FIRST-BOOKING` and DC-11 keeps the finance model; each is classified at its own boundary.
   ```

   e) replace the line
   ```text
   | `ENABLE-CLIENT-WRITES` | a client application first writes | frontend, OD-9 | NOT REACHED |
   ```
   with
   ```text
   | `ENABLE-CLIENT-WRITES` | a client application first writes | frontend (FE-0, after `B6-EXIT`) | NOT REACHED |
   ```

   f) replace the lines
   ```text
   | PAY-9 | VERIFIED DEFECT | engineering | `FIRST-BOOKING` | BOOK-12's rule, a consumer of the same balance | Medium. A booking paid through `app.record_payment` still owes its invoice in the booking-scoped balance, so issuing it would charge the negative-balance override. One balance-model unit that counts a payment through its allocation |
   | PAY-5, FIN-11 | VERIFIED DEFECT | engineering | `ENABLE-INVOICING` | — | SPEC-326 and Test 184 close the unit on Platinum Primary: `app.derive_invoice_payment_status` on payment_allocations derives the invoice's status and emits its event on both doors, and `app.record_payment` no longer derives it. A zero allocation settles nothing and no settlement walks back. |
   | RFD-3 | VERIFIED DEFECT | engineering | `ENABLE-REFUNDS` | — | SPEC-326 and Test 184 close it on Platinum Primary: the refunds table records each refund transition once on both doors, with the RPC reason carried through `app.transition_reason`. The RPC severities are kept. |
   | PAY-4 | VERIFIED DEFECT | engineering | `FIRST-PAYMENT` | — | SPEC-327 and Test 185 close it on Platinum Primary: `payments_amount_positive_check` requires `amount > 0` on every door, the rule `app.record_payment` and `app.record_supplier_payment` already enforce. |
   ```
   with
   ```text
   | PAY-9 | VERIFIED DEFECT | engineering | `FIRST-BOOKING` | BOOK-12's rule, a consumer of the same balance | Medium. A booking paid through `app.record_payment` still owes its invoice in the booking-scoped balance, so issuing it would charge the negative-balance override. One balance-model unit that counts a payment through its allocation |
   ```

   g) replace the lines
   ```text
   | JE-2, DC-11 | VERIFIED DEFECT | engineering | `FIRST-JOURNAL-ENTRY` | the finance model (OD-1) | Medium. SPEC-327 and Test 185 contain JE-2 fail-closed on Platinum Primary: the deferred balance trigger refuses an entry whose lines carry more than one currency, on every door. DC-11 still decides the translation model; launch never presents a false balance. |
   | ENTRY-1 | VERIFIED DEFECT | engineering | `B6-EXIT` | Canon 26 and each creation path | SPEC-318 and Test 134 close task terminal-state entry on Platinum Primary. Previously closed members retain their evidence. SPEC-324 and Test 183 close booking-item entry on Platinum Primary. The campaign member is assessed without material consequence and moves with CAMP-2 to its own trigger. No residual entry assessment remains due at B6-EXIT. |
   | ARCH-2 | VERIFIED DEFECT | engineering | `B6-EXIT` | Each surface's existing archive contract | SPEC-319 and Test 182 close archive-at-entry for bookings, passengers, suppliers and tasks on Platinum Primary and verify the existing customers metadata check. SPEC-216/257/262 hold for documents, service requests and complaints. SPEC-310 retains the customer-note position. SPEC-324 and Test 183 close leads, invoices, quotations and booking items on Platinum Primary. No member remains due. |
   ```
   with
   ```text
   | JE-2, DC-11 | VERIFIED DEFECT | engineering | `FIRST-JOURNAL-ENTRY` | the finance model (OD-1) | Medium. SPEC-327 and Test 185 contain JE-2 fail-closed on Platinum Primary: the deferred balance trigger refuses an entry whose lines carry more than one currency, on every door. DC-11 still decides the translation model; launch never presents a false balance. |
   ```

   h) replace the lines
   ```text
   | CAMP-2 | VERIFIED DEFECT | engineering | `OWN-TRIGGER` | a programme-wide initial-state pass, or the first reproduced harm | UNPROVEN as a material campaign defect. Test 127 confirms entry behavior and the gap register reports no reproduced harm. SPEC-324 assessed campaign entry under ENTRY-1 without material consequence. |
   | STEPUP-1 | VERIFIED DEFECT | engineering | `B6-EXIT` | Individual write authority and EC-2 | UNPROVEN as a class. SPEC-320 and Tests 58/130 close the demonstrated BRANCH-1 member on Platinum Primary. Prior member repairs remain recorded. SPEC-324 and Test 183 close the campaign daily metrics and exchange-rate adjustments members on Platinum Primary. Remaining candidates keep their recorded status. |
   | PAX-4 | VERIFIED DEFECT | engineering | `B6-EXIT` | EC-2 and the INSERT-path authority | Fixed by the insert-authority reconciliation. Test 67 SEC-1b owns the live measurement, Test 101 pins campaign metrics policy, and Test 108 pins lead interaction authority. Test 106 retains its OTP assertions. Canon 34 and SPEC-259 explain the ownership-only cases. STEPUP-1 and AUTH-1 remain independent. |
   ```
   with
   ```text
   | CAMP-2 | VERIFIED DEFECT | engineering | `OWN-TRIGGER` | a programme-wide initial-state pass, or the first reproduced harm | UNPROVEN as a material campaign defect. Test 127 confirms entry behavior and the gap register reports no reproduced harm. SPEC-324 assessed campaign entry under ENTRY-1 without material consequence. |
   ```

   i) replace the lines
   ```text
   | CHAT-2, CAMP-4, BRANCH-2, PAX-8 | VERIFIED DEFECT | engineering | `ENABLE-SURFACE-WORKFLOW` | — | Low. Audit and timeline evidence is missing at a table door, and each finding's measured bound is that nothing reads it. At the gate the bound is re-measured: if it holds, the item becomes an explicit accepted residual; otherwise it is repaired. Never deferred silently. SPEC-326 and Test 184 close CHAT-2 on Platinum Primary: the conversation guard stamps `closed_at` and requires a reopen reason, and the table records each transition once on both doors. |
   | BRANCH-1 | VERIFIED DEFECT | engineering | `ENABLE-SURFACE-WORKFLOW` | — | Fixed by SPEC-320. Tests 58 and 130 and the independent Platinum Primary readback verify branch write permission and MFA. BRANCH-2 remains a separate workflow obligation. |
   | APP-1 | REQUIRED CAPABILITY | engineering | `FIRST-TENANT` | OD-9 (whether it runs beside Batch 6), OD-5 (staff login) | No client application exists, while ADR-0014 chose a server-rendered web app as ORVION's client. Treatment: FE-0, the web foundation and the first read-only journey (`delivery-assessment-2026-10-11.md` §7) |
   ```
   with
   ```text
   | CAMP-4, BRANCH-2, PAX-8 | VERIFIED DEFECT | engineering | `ENABLE-SURFACE-WORKFLOW` | — | Low. Audit and timeline evidence is missing at a table door, and each finding's measured bound is that nothing reads it. At the gate the bound is re-measured: if it holds, the item becomes an explicit accepted residual; otherwise it is repaired. Never deferred silently. SPEC-326 and Test 184 close CHAT-2 on Platinum Primary: the conversation guard stamps `closed_at` and requires a reopen reason, and the table records each transition once on both doors. |
   | APP-1 | REQUIRED CAPABILITY | engineering | `FIRST-TENANT` | `B6-EXIT` (OD-9, decided AFTER by the owner 2026-11-22), OD-5 (staff login) | No client application exists, while ADR-0014 chose a server-rendered web app as ORVION's client. Treatment: FE-0, the web foundation and the first read-only journey (`delivery-assessment-2026-10-11.md` §7) |
   ```

   j) replace the lines
   ```text
   | OD-1, OD-2, OD-3, OD-5, OD-8 | BUSINESS POLICY | owner | `FIRST-TENANT` | the owner | Launch scope, revenue policy, reporting currency, staff login without email, and salary visibility. Each register row carries the proposed default; `delivery-assessment-2026-10-11.md` carries the analysis. On answers: FIN-0 (the profitability model) and the canon 01/20 amendments |
   | OD-9 | BUSINESS POLICY | owner | `B6-EXIT` | the owner | Whether frontend, finance design, Google access and counsel work run in parallel with Batch 6, and the app's check profile. On approval: FE-0 (the web foundation) as a Draft |
   ```
   with
   ```text
   | OD-1, OD-2, OD-3, OD-5, OD-8 | BUSINESS POLICY | owner | `FIRST-TENANT` | the owner | Launch scope, revenue policy, reporting currency, staff login without email, and salary visibility. Each register row carries the proposed default; `delivery-assessment-2026-10-11.md` carries the analysis. On answers: FIN-0 (the profitability model) and the canon 01/20 amendments |
   ```

   k) replace the line
   ```text
   | `booking_item_passengers`, `booking_items`, `financial_accounts` | SURFACE | engineering | `GATE-EVAL` | — | Still `AUDITED-OPEN` for decisions the register has since settled (PAX-5, PAX-6, BOOK-8, BOOK-9, FA-2); re-dispositioned at the first evaluation (EC-8) |
   ```
   with
   ```text
   | `booking_item_passengers`, `financial_accounts` | SURFACE | engineering | `GATE-EVAL` | — | Still `AUDITED-OPEN` for decisions the register has since settled (PAX-5, PAX-6, BOOK-8, BOOK-9, FA-2); re-dispositioned at the first evaluation (EC-8) |
   ```

   l) replace the lines
   ```text
   | `branches` | SURFACE | engineering | `ENABLE-SURFACE-WORKFLOW` | STEPUP-1 branch member | SPEC-320 and Tests 58/130 verify the BRANCH-1 repair on Platinum Primary. BRANCH-2 retains its workflow-enablement gate. |
   | `conversations` | SURFACE | engineering | `B6-EXIT` | CHAT-2 and the explicit surface boundary | SPEC-220 and test 125 close creator attribution and initial state. SPEC-326 and Test 184 close CHAT-2's transition time, reopen reason and event gap on Platinum Primary. |
   | `journal_entry_lines` | SURFACE | engineering | `B6-EXIT` | JE-2 and DC-11 | SPEC-245 and test 145 close JE-3/JE-4 and the STEPUP-1 member. SPEC-327 and Test 185 close JE-2's exit evidence on Platinum Primary with the recorded fail-closed single-currency containment. DC-11 keeps the translation model. |
   ```
   with
   ```text
   | `branches` | SURFACE | engineering | `ENABLE-SURFACE-WORKFLOW` | STEPUP-1 branch member | SPEC-320 and Tests 58/130 verify the BRANCH-1 repair on Platinum Primary. BRANCH-2 retains its workflow-enablement gate. |
   ```

   m) replace the lines
   ```text
   | `passengers` | SURFACE | engineering | `ENABLE-SURFACE-WORKFLOW` | PAX-8 | SPEC-319 and Test 182 verify ARCH-2 at entry on Platinum Primary. SPEC-223 and Test 128 close PAX-7. PAX-8 remains open at ENABLE-SURFACE-WORKFLOW. |
   | `payment_allocations` | SURFACE | engineering | `B6-EXIT` | FIN-11/PAY-5 and PAY-9 | SPEC-264 and test 155 cover allocation authority, audit and concurrency. SPEC-326 and Test 184 close the PAY-5/FIN-11 invoice status and event unit on Platinum Primary. PAY-9 remains the booking-balance unit at first booking, and the PAY-11 residual remains an owner policy question. |
   | `payments` | SURFACE | engineering | `B6-EXIT` | PAY-4 and exit integrity evidence | SPEC-221/238 and tests 126/140 close PAY-2/PAY-3. SPEC-327 and Test 185 close PAY-4 on Platinum Primary: a payment row carries `amount > 0` on every door. The payment trigger is preserved. |
   | `refunds` | SURFACE | engineering | `B6-EXIT` | RFD-3 and exit lifecycle evidence | SPEC-217 and test 123 close RFD-1/RFD-2 and refund entry. SPEC-326 and Test 184 close RFD-3 on Platinum Primary with the RPC reason preserved and one emission. The refund enablement gate is preserved. |
   | `suppliers` | SURFACE | engineering | `B6-EXIT` | ARCH-2 supplier member | SPEC-215 and Test 121 close creation attribution. SPEC-319 and Test 182 verify the ARCH-2 supplier member on Platinum Primary. |
   | `tasks` | SURFACE | engineering | `B6-EXIT` | ENTRY-1 and ARCH-2 task members | SPEC-230 and Test 134 close TASK-4. SPEC-318 and Test 134 verify task entry under ENTRY-1, and SPEC-319 and Test 182 verify the ARCH-2 task member on Platinum Primary. |
   ```
   with
   ```text
   | `passengers` | SURFACE | engineering | `ENABLE-SURFACE-WORKFLOW` | PAX-8 | SPEC-319 and Test 182 verify ARCH-2 at entry on Platinum Primary. SPEC-223 and Test 128 close PAX-7. PAX-8 remains open at ENABLE-SURFACE-WORKFLOW. |
   ```

   n) immediately after the lines
   ```text
   **Recorded exception, 2026-11-22, CRM exit bundle C.** After CRM SPEC-326 at `17ec05a0904f9b5eac676b2d0024d71850886441`, the owner's 2026-11-20 directive authorized grouping items that share evidence, tests and a release boundary while keeping per-item acceptance. SPEC-327 selects JE-2, through the recorded fail-closed single-currency containment while DC-11 stays open, and PAY-4, through the entry-shape rule derived from the sanctioned payment RPCs. Both are the exit evidence of the `journal_entry_lines` and `payments` surfaces and share the finance-ledger write boundary: the deferred balance trigger refuses a mixed-currency entry and a payment row carries `amount > 0`, on every door. Test 185 proves each selected effect on one isolated schema. PAY-9 keeps FIRST-BOOKING and DC-11 keeps the finance model. Closure is evaluated after deployment. The Original, deployment and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-22, CRM exit bundle D.** After CRM SPEC-328 at `30501ca5f3d94862165898c3b7de86d84090b87b`, the owner decided OD-9 on 2026-11-22: AFTER, so FE-0 begins only after `B6-EXIT` and the app check profile is an engineering recommendation in FE-0's own Draft. SPEC-329 is record-only: it prunes the eighteen Action registry members that `scripts/readiness_population.ps1` derives as COMPLETED, records OD-9 as decided and removes its row, and restates the EC-2, EC-4 and EC-5 readings against the evidence of bundles A to C. It changes no migration, test or database object and closes no obligation by itself. EC-2's rationale and RPC-1, and EC-3, EC-6, EC-7, EC-8, EC-10 and EC-11, keep their recorded work. The Original and release gates remain enforced.

   ```

   The resulting file's Git blob is 9a2c647c9ba24676c5dbf55c82e53b0c710ac8cc.

2. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `CRM SPEC-329 records OD-9`; if so record Already Applied when its Git blob is 3c670c12a0e9adcabdd364cae99bb5dbf72cc83b, and otherwise stop and report. Otherwise make exactly these 3 edits (OD-9 decided AFTER by the owner and APP-1 sequencing, with the dated header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-22 (CRM SPEC-327 fixes PAY-4 and contains JE-2 fail-closed on Platinum Primary: a ledger entry balances in one currency and a payment row carries value on every door. DC-11 still decides the translation model.)
   ```
   with
   ```text
   Last updated: 2026-11-22 (CRM SPEC-329 records OD-9 as decided by the owner: AFTER. FE-0 begins only after `B6-EXIT`; APP-1's sequencing follows it. No finding changes status otherwise.)

   Previously: 2026-11-22 (CRM SPEC-327 fixes PAY-4 and contains JE-2 fail-closed on Platinum Primary: a ledger entry balances in one currency and a payment row carries value on every door. DC-11 still decides the translation model.)
   ```

   b) replace the line
   ```text
   | APP-1 | **No client application exists, so no employee can use ORVION** | product delivery / frontend | High | R | — | — | 📋 | **OPEN — a required capability, not a defect.** ADR-0014 chose a server-rendered web app as ORVION's client, and every Day-1 journey in canon 01 needs one; the repository holds no application code. Measured 2026-10-11 (`delivery-assessment-2026-10-11.md` §1). Recorded by SPEC-269 so the missing build has a home, a boundary (`FIRST-TENANT`) and a treatment (FE-0). Its sequencing waits on OD-9, and its login on OD-5. | — | delivery-assessment-2026-10-11 | 10-12 | 10-12 |
   ```
   with
   ```text
   | APP-1 | **No client application exists, so no employee can use ORVION** | product delivery / frontend | High | R | — | — | 📋 | **OPEN — a required capability, not a defect.** ADR-0014 chose a server-rendered web app as ORVION's client, and every Day-1 journey in canon 01 needs one; the repository holds no application code. Measured 2026-10-11 (`delivery-assessment-2026-10-11.md` §1). Recorded by SPEC-269 so the missing build has a home, a boundary (`FIRST-TENANT`) and a treatment (FE-0). Its sequencing follows OD-9, decided AFTER by the owner on 2026-11-22: FE-0 begins only after `B6-EXIT`. Its login waits on OD-5. | — | delivery-assessment-2026-10-11 | 10-12 | 10-12 |
   ```

   c) replace the line
   ```text
   | OD-9 | **Work in parallel with Batch 6, and the app's check profile** | sequencing / governance | High | R | — | — | 📋 | **OPEN — PROPOSED 2026-10-11, not decided.** The owner's order runs Batch 6 first; Batch 6 still has 37 of 78 surfaces without a recorded disposition. The proposal is that the frontend foundation and read-only journeys against the local stack, the finance design, and counsel and policy work run beside it, since none needs a migration. The UI holds no authority, so it would get end-to-end, accessibility and not-permitted tests instead of the per-table adversarial process. The n8n workflow stays after Batch 6, as the owner ordered. Google access is now SPEC-265's script route (D4, owner-decided). Analysis: `delivery-assessment-2026-10-11.md` §5–§7, D9. Recorded by SPEC-269. | owner: proposed default — approve the parallel streams and the proportionate app profile; on approval FE-0 is drafted | delivery-assessment-2026-10-11 | 10-12 | 10-12 |
   ```
   with
   ```text
   | OD-9 | **Work in parallel with Batch 6, and the app's check profile** | sequencing / governance | High | R | — | — | 📋 | **✅ DECIDED BY THE OWNER 2026-11-22: AFTER.** Frontend work, FE-0 included, begins only after Batch 6 meets its exit criteria (`B6-EXIT`, EC-1..EC-11). The app's check profile is carried to FE-0's own Draft as an engineering recommendation for that Draft's Gate 1. Recorded by SPEC-329 from the owner's words of 2026-11-22. **Superseded text:** OPEN — PROPOSED 2026-10-11, not decided. The owner's order runs Batch 6 first; Batch 6 still has 37 of 78 surfaces without a recorded disposition. The proposal is that the frontend foundation and read-only journeys against the local stack, the finance design, and counsel and policy work run beside it, since none needs a migration. The UI holds no authority, so it would get end-to-end, accessibility and not-permitted tests instead of the per-table adversarial process. The n8n workflow stays after Batch 6, as the owner ordered. Google access is now SPEC-265's script route (D4, owner-decided). Analysis: `delivery-assessment-2026-10-11.md` §5–§7, D9. Recorded by SPEC-269. | owner: sequencing of frontend work against Batch 6 | delivery-assessment-2026-10-11 | 10-12 | 11-22 |
   ```

   The resulting file's Git blob is 3c670c12a0e9adcabdd364cae99bb5dbf72cc83b.

3. Check whether `_ORVION_CANONICAL/manifest.md` contains `**OD-8**, **CTRL-19**`; if so record Already Applied when its Git blob is 9902974ff219ac6967dcdda97104a19235509e5a, and otherwise stop and report. Otherwise make exactly this one edit (OD-9 removed from the open owner decisions), each matched once, and change nothing else:

   a) replace the line
   ```text
   Open owner decisions — **MAIL-1**, **RET-1**, **PH8-10**, **OD-1**, **OD-2**, **OD-3**, **OD-5**, **OD-8**, **OD-9**, **CTRL-19**. The OD rows are proposed product decisions awaiting the owner, each with its default in the register. MAIL-1, RET-1 and PH8-10 are exact external prerequisites, not unresolved architecture: MAIL-1 has technically selected Resend but production activation still requires owner authorization and counsel/PDPC confirmation for the actual cross-border destination; RET-1's retention/closure architecture and legal-hold override are implemented, while counsel must supply the actual per-type periods as tenant configuration; PH8-10 awaits Google evidence that click-less phone conversions are credited. No email is sent and no retention policy is seeded while those prerequisites remain. CTRL-19 is GitHub configuration only the owner can make.
   ```
   with
   ```text
   Open owner decisions — **MAIL-1**, **RET-1**, **PH8-10**, **OD-1**, **OD-2**, **OD-3**, **OD-5**, **OD-8**, **CTRL-19**. The OD rows are proposed product decisions awaiting the owner, each with its default in the register. MAIL-1, RET-1 and PH8-10 are exact external prerequisites, not unresolved architecture: MAIL-1 has technically selected Resend but production activation still requires owner authorization and counsel/PDPC confirmation for the actual cross-border destination; RET-1's retention/closure architecture and legal-hold override are implemented, while counsel must supply the actual per-type periods as tenant configuration; PH8-10 awaits Google evidence that click-less phone conversions are credited. No email is sent and no retention policy is seeded while those prerequisites remain. CTRL-19 is GitHub configuration only the owner can make.
   ```

   The resulting file's Git blob is 9902974ff219ac6967dcdda97104a19235509e5a.

4. **Verify and synchronize.** Run the native repository guard and the five hosted guard suites named in Additional Verification. Confirm that `readiness_population.ps1` reports no COMPLETED member and REGISTRY complete, that OD-9 is no longer an open decision, and that RPC-1 is the only obligation due at `B6-EXIT`. Confirm the exact scope and `git diff --check`. Synchronize the contract and native discovery artifacts. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-329: CRM Batch 6 exit evidence reconciled after bundles A to C.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] The Action Registry plan equals the exact isolated record payload. `check: blob reports/master/MASTER_EXECUTION_PLAN.md 9a2c647c9ba24676c5dbf55c82e53b0c710ac8cc`
- [ ] The register records OD-9 as decided by the owner and equals the exact isolated payload. `check: blob reports/master/MASTER_GAP_REGISTER.md 3c670c12a0e9adcabdd364cae99bb5dbf72cc83b`
- [ ] `readiness_population.ps1` reports no COMPLETED member, OD-9 absent from the open decisions and REGISTRY complete; RPC-1 is the only obligation due at `B6-EXIT`.
- [ ] PAY-9, DC-11, JE-2, RPC-1, CAMP-4, BRANCH-2 and PAX-8 keep their recorded status and boundary, and no exit criterion is marked met.
- [ ] The surface dispositions are preserved. `check: same reports/master/MASTER_SURFACE_DISPOSITION.md @30501ca5f3d94862165898c3b7de86d84090b87b`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @30501ca5f3d94862165898c3b7de86d84090b87b`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @30501ca5f3d94862165898c3b7de86d84090b87b`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @30501ca5f3d94862165898c3b7de86d84090b87b`
- [ ] All five hosted guard suites pass in the native Finish.

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

Baseline: 30501ca5f3d94862165898c3b7de86d84090b87b (SPEC-328 Complete and released; main is 30501ca5f3d94862165898c3b7de86d84090b87b).

Authority: DELEGATED under the Workbench Batch 6 run mode 2 record, answered by the constitution; never typed by the owner. The OD-9 decision is the owner's own words of 2026-11-22, Workbench `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D; this contract records that decision and grants nothing beyond it.

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `a28c51c3b52f50e6c7b0de8ab8a9131d63f43287` |
| `reports/master/MASTER_GAP_REGISTER.md` | `b442d9f1ad801e1041e07d4eb76951afc06c249b` |
| `_ORVION_CANONICAL/manifest.md` | `3d060713df4bb9f5c40708bc789c79840cd60c45` |
