# Change Request — SPEC-317

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Reconcile CRM's Batch 6 exit records against evidence at 28e9052beaefa367b31d4ea7346654678374c54c so existing obligations have a stated boundary, evidence and next action.

## Business Reason

The owner approved this one CRM-only record Draft on 2026-11-19 as the execution plan's explicit exception. CRM SPEC-316 is remote certified and all 78 surfaces are recorded. The exhausted selector has no next surface and the original native registry still derives 22 exit obligations. The owner approval is saved in the Workbench packet. Gate 1 is a separate owner decision on this exact Draft.

Existing evidence is sufficient to return five surface obligations to their already recorded individual triggers. The remaining 17 due items comprise 12 surfaces and five finding IDs. The reconciliation does not close any surface disposition or a product defect. The existing Action registry remains the single queue.

## Risks

A record change can prematurely imply a business control is ready. All three partial dispositions, all genuine engineering findings, and all existing individual finding triggers retain their authority. The five proposed due-boundary corrections retain the open surface rows. The gate remains pending. No database operation is needed for this records change.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-317-reconcile-batch-6-exit-evidence.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `scripts/batch6_select_target.ps1`
- `scripts/readiness_population.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `reports/master/MASTER_CERTIFICATION_STATUS.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`
- `supabase/config.toml`

Other product code, schema, tests, roles, CI and all external writes are outside the exact Write Scope.

## Required Reading

- `CR_LIFECYCLE.md` §§4–9 and `ENGINEERING_METHOD.md` §2.
- `reports/master/MASTER_EXECUTION_PLAN.md` EC-1…EC-11 and Action registry.
- `reports/master/MASTER_GAP_REGISTER.md` ARCH-2, CAMP-2, ENTRY-1, PAX-4, STEPUP-1, OTP-2, AUTH-1, JE-6, SPP-3, USR-3, USR-4, OD-9 and CTRL-19.
- `reports/master/MASTER_SURFACE_DISPOSITION.md` the original 17 B6-EXIT surface rows and the three partial dispositions.

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

None

## Additional Verification

None

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Reconcile the existing Plan Action registry in place and record the owner exception. Update five stale surface deadlines to their existing triggers, reconcile contradictory findings evidence without settling class IDs, and correct the stale OTP surface record.

Pass 2 Adversarial Review: Preserve the 12 remaining surface deadlines where repair ownership, stale classification or exit conflicts still need evidence. Keep the five finding IDs due, including the three held as unproven. A passing suite cannot close a defect whose test records the still-open behavior. Preserve every deferred surface trigger and report any conflict with earlier exit proof.

Pass 3 Evidence Refresh: 2026-11-19. Re-ran the native registry at 28e9052beaefa367b31d4ea7346654678374c54c and on the three record amendments in a push-disabled CRM prototype. The native count moved from 22 due to 17, the 78 dispositions and 3 partial rows matched the baseline, and repository consistency was clean including Checks 21, 22, 24 and 29. Reused the exact SPEC-316 parity, local verification and remote Certify evidence.

Selected Version: SPEC-317; selected: the CRM record reconciliation using the existing Action registry and exact evidence from SPEC-316, with zero product changes

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Owner exception and individual exit obligations | Action registry and native Check 29 | WRITE | Existing boundaries and classifications are parsed by the unchanged native program. The five trigger-bound surfaces remain open. |
| Historical evidence and member status | Gap register and surface disposition records | WRITE | Stop at the proved record changes. All five class findings remain due and the OTP retirement trigger remains authoritative. |
| The surface set, existing selector order and database proof | Check 22, selector and EC-9 | UNAFFECTED | 78 recorded with 54 AUDITED, 21 AUDITED-OPEN and 3 PARTIAL. The exact SPEC-316 database evidence carries forward. |
| Native lifecycle metadata | Active Change Request, Last Completed and discovery projections | WRITE | Native lifecycle synchronization only. |
| Existing work ordering | Next capability and Current Module | UNAFFECTED | The recorded exception is for these records. Existing authority still governs work selection. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Approved source anchors and exact record payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Repository consistency including Check 29 and discovery | BEFORE_COMPLETION | NONE | NONE | 4 |
| Matching native verification evidence | BEFORE_COMPLETION | NONE | NONE | NONE |

## Implementation Steps

1. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Recorded exception, 2026-11-19, CRM.`; if so record Already Applied when its Git blob is 5ca456b301a3d32f40888b4d01375005b78d2841, and otherwise stop and report. Otherwise make exactly these 6 edits (the owner exception and the reconciled Batch 6 boundary and evidence), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-10-14 (**CTRL-19 joins the Action registry (SPEC-281).** SPEC-281 fixed CTRL-17 and CTRL-18, and proved that a candidate can certify itself through the required check it defines. The repair is GitHub configuration only the owner can make, so CTRL-19 waits on the owner at `GATE-EVAL`.)
   ```
   with
   ```text
   Last updated: 2026-11-19 (CRM Batch 6 Exit Reconciliation after SPEC-316. The Action registry records the owner exception and the exit work still owed.)

   Previously: 2026-10-14 (**CTRL-19 joins the Action registry (SPEC-281).** SPEC-281 fixed CTRL-17 and CTRL-18, and proved that a candidate can certify itself through the required check it defines. The repair is GitHub configuration only the owner can make, so CTRL-19 waits on the owner at `GATE-EVAL`.)
   ```

   b) immediately after the lines
   ```text
   | **EC-11** | **Cleanliness.** No abandoned, duplicate, superseded or orphaned mechanism without a stated reason | Partly earned by deletion-over-refreshment (GOV-5, REG-2). Exit = the sweep in EC-1 also records, per table, whether anything it touches is superseded |

   ```
   insert
   ```text
   **CRM exit evidence at `28e9052`, reconciled 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.

   - **EC-2 (partial):** Tests 57/58 carry 54/17/3. Finish the per-writable-surface rationale, PAX-4 and STEPUP-1 residual assessments, and RPC-1 permission remeasurement.
   - **EC-3 (partial):** SPEC-316 HTTP evidence covers cross-tenant denial for the paths it exercises. Provide a stated isolation basis for every surface, including the partial and platform-managed paths.
   - **EC-4 (open):** Tests 54/88 establish bounded transition and parent-state evidence. ENTRY-1 and CHAT-2 remain open. Reconcile their entry and transition contracts and the explicit surface boundaries.
   - **EC-5 (partial):** SPEC-316 smoke and both pgTAP passes cover exercised invariants. Map the remaining journal, payment, allocation and refund invariants to enforcement and evidence at their boundaries.
   - **EC-6 (partial):** Check 24 admits the recorded adversarial labels. Verify that every sensitive path has a targeted negative test. Retain the existing evaluation and delivery triggers for the three partial surfaces. Any required proof whose trigger falls after its own prerequisite needs an explicit gate decision.
   - **EC-7 (partial):** Existing member repairs carry permanent tests. Cross-check each material closure to its actual assertion and each ceiling to a named membership or monotonic bound. A test that records an open behavior still needs a matching repair or justified invariant.
   - **EC-8 (partial):** Native freshness checks and the reconciled records establish bounded coherence. Complete the existing gate-evaluation disposition work and resolve any remaining plan/finding/disposition conflicts.
   - **EC-10 (partial):** Check 20 and SPEC-316 hosted CI establish the guarded inputs and release result. Owner-controlled CTRL-19 independent enforcement evidence and coverage of any important change class outside that list are still owed.
   - **EC-11 (open):** AUTH-1 gives the inert authentication-table retirement trigger. Finish the per-surface review of orphaned, duplicate and superseded mechanisms with current reasons and triggers.

   ```

   c) replace the lines
   ```text
   |---|---|---|---|---|---|
   | USR-3 | VERIFIED DEFECT | engineering | `FIRST-TENANT` | — | High. An `aal1` `ceo` self-granted a permission and self-assigned a branch at the table door. Fixed by the Batch 6 slice of `user_permission_grants` or `user_branch_assignments`, whichever the selector reaches first; it is the strongest candidate for the next justified exception |
   ```
   with
   ```text
   |---|---|---|---|---|---|
   ```

   d) replace the line
   ```text
   | ARCH-2, ENTRY-1, CAMP-2, STEPUP-1, PAX-4 | VERIFIED DEFECT | engineering | `B6-EXIT` | each listed table's slice | Medium for ARCH-2 and ENTRY-1; CAMP-2 is ENTRY-1's question and is answered with it. STEPUP-1 and PAX-4 are UNPROVEN class candidates held here until each table's slice proves or dismisses its member; they never count as proven (EC-1) |
   ```
   with
   ```text
   | ENTRY-1 | VERIFIED DEFECT | engineering | `B6-EXIT` | Canon 26 and each creation path | Nine members have recorded closure. Tests 127 and 134 still document campaign and task entry. Check `booking_items` against its current creation contract and tests 74/105. Smallest known repair: task-local entry authority and a matching negative test. A campaign or booking-item rule requires its own canon and consequence evidence. |
   | ARCH-2 | VERIFIED DEFECT | engineering | `B6-EXIT` | Each surface's existing archive contract | SPEC-216/257/262 close documents, service requests and complaints. SPEC-310 records the customer-note exception. SPEC-215 and test 134 leave suppliers and tasks open. Bound those two repairs under their existing archive authority and confirm other historical members before expanding repair scope. |
   | CAMP-2 | VERIFIED DEFECT | engineering | `B6-EXIT` | ENTRY-1 campaign assessment | UNPROVEN as a material campaign defect. Test 127 confirms entry behavior and the gap register reports no reproduced harm. Resolve within ENTRY-1 using the campaign canon. |
   | STEPUP-1 | VERIFIED DEFECT | engineering | `B6-EXIT` | Individual write authority and EC-2 | UNPROVEN as a class. SPEC-245/246/278/301/305/307 close named member repairs. BRANCH-1 is the remaining demonstrated member. Check the two unswept candidate surfaces, campaign daily metrics and exchange-rate adjustments, before assigning additional repairs. |
   | PAX-4 | VERIFIED DEFECT | engineering | `B6-EXIT` | EC-2 and its five named members | UNPROVEN as a defect class. Test 106 assertions 15–16 pin enforcement locations. OTP-1, OTP-2, Canon 34 and surface evidence explain individual cases. Verify the remaining writer rationale for lead interactions and campaign metrics before assigning any repair. |
   ```

   e) replace the line
   ```text
   | `bookings`, `branches`, `conversations`, `journal_entries`, `journal_entry_lines`, `lead_interactions`, `marketing_campaigns`, `otp_challenges`, `passengers`, `payment_allocations`, `payments`, `refunds`, `subscription_payment_proofs`, `suppliers`, `tasks`, `totp_enrollments`, `users` | SURFACE | engineering | `B6-EXIT` | their open findings above | `AUDITED-OPEN`; each closes when its open findings do, and carries no separate class |
   ```
   with
   ```text
   | `bookings` | SURFACE | engineering | `B6-EXIT` | ARCH-2 assessment and BOOK-11/BOOK-12 | SPEC-239 fixes booking entry and issuance, and SPEC-224 fixes PAX-9. Check ARCH-2 at entry. Keep cancellation evidence and the customer-freeze rule at the BOOK-11/BOOK-12 boundary. |
   | `branches` | SURFACE | engineering | `B6-EXIT` | STEPUP-1 branch member | SPEC-226 and test 130 document the branch evidence. Scope any required write-authority repair to BRANCH-1. BRANCH-2 retains its enablement gate. |
   | `conversations` | SURFACE | engineering | `B6-EXIT` | CHAT-2 and the explicit surface boundary | SPEC-220 and test 125 close creator attribution and initial state. Reconcile CHAT-2's transition time and event gap with the exit obligation and its existing workflow gate. |
   | `journal_entry_lines` | SURFACE | engineering | `B6-EXIT` | JE-2 and DC-11 | SPEC-245 and test 145 close JE-3/JE-4 and the STEPUP-1 member. JE-2 needs the existing accounting decision or the recorded fail-closed single-currency containment. Resolve the exit evidence for that invariant. |
   | `lead_interactions` | SURFACE | engineering | `B6-EXIT` | PAX-4 and LI-3 | Test 108 pins the LI-1/LI-2 repairs and the LI-3 behavior. Verify the actor-bound write rationale. Any lifecycle repair depends on the existing FIN-9/FIN-11 side-effect authority before CRM enablement. |
   | `marketing_campaigns` | SURFACE | engineering | `B6-EXIT` | ENTRY-1 campaign member | SPEC-222 and test 127 close CAMP-3 and record current entry behavior. Resolve CAMP-2 through ENTRY-1. Recheck CAMP-4 under its existing workflow gate. |
   | `passengers` | SURFACE | engineering | `B6-EXIT` | ARCH-2 assessment and PAX-8 | SPEC-223 and test 128 close PAX-7 and record PAX-8 open. Verify archive-at-entry scope and preserve PAX-8's workflow gate. |
   | `payment_allocations` | SURFACE | engineering | `B6-EXIT` | FIN-11/PAY-5 and PAY-9 | SPEC-264 and test 155 cover allocation authority, audit and concurrency. PAY-5/FIN-11 is the invoice status/event unit at invoicing enablement. PAY-9 is the balance unit after BOOK-12, at first booking. Reconcile both with exit integrity evidence. |
   | `payments` | SURFACE | engineering | `B6-EXIT` | PAY-4 and exit integrity evidence | SPEC-221/238 and tests 126/140 close PAY-2/PAY-3. PAY-4 still needs a sanctioned payment-entry shape at first payment. Preserve its trigger and resolve the explicit exit obligation. |
   | `refunds` | SURFACE | engineering | `B6-EXIT` | RFD-3 and exit lifecycle evidence | SPEC-217 and test 123 close RFD-1/RFD-2 and refund entry. RFD-3 needs one refund event authority with the RPC reason preserved and one emission. Preserve the refund enablement gate. |
   | `suppliers` | SURFACE | engineering | `B6-EXIT` | ARCH-2 supplier member | SPEC-215 and test 121 close creation attribution. The recorded supplier archive-at-entry consequence supports the bounded ARCH-2 repair. |
   | `tasks` | SURFACE | engineering | `B6-EXIT` | ENTRY-1 and ARCH-2 task members | SPEC-230 and test 134 close TASK-4 and document the two open entry invariants. Keep the two repairs bounded to existing task authorities. |
   | `journal_entries` | SURFACE | engineering | `OWN-TRIGGER` | JE-6 | SPEC-246 and test 146 close JE-5 and the STEPUP-1 member. JE-2 stays with the line invariant. JE-6 reopens on the first reader of `source_entity_id`. |
   | `otp_challenges`, `totp_enrollments` | SURFACE | engineering | `OWN-TRIGGER` | AUTH-1 | OTP-1's repair and OTP-2's derivation are recorded. Test 106 and SPEC-259/test 151 cover the present boundary. Retire before the first client-facing authentication build or first reference. PAX-4 class assessment stays due at exit. |
   | `subscription_payment_proofs` | SURFACE | engineering | `OWN-TRIGGER` | SPP-3 | SPEC-260/261 and tests 152/153 settle the current integrity and concurrency work. A trusted reviewer identity is still owed before the second platform operator or an authenticated platform console. |
   | `users` | SURFACE | engineering | `OWN-TRIGGER` | USR-4 | SPEC-206 and test 118 cover membership authority and tenant isolation. USR-4 reopens when a policy, function or application first reads the flag. |
   ```

   f) immediately after the lines
   ```text
   **The order stays the owner's.** Batch 6 → bounded Phase-8 revalidation → n8n and Data Manager → the Direct Call Quality Feedback Loop → PH8-10 → the Smart Bidding decision → Phase-8 closure (`_ORVION_CANONICAL/32_execution_roadmap.md`). Inside Batch 6, `scripts/batch6_select_target.ps1` keeps choosing the slice. This registry reorders nothing silently: a `DUE NOW` state never overrides the selector, and an item taken ahead of it is an explicit, recorded exception with its reason. SUB-4 (SPEC-250) and SPP-6 (SPEC-261) are the exceptions taken so far.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-19, CRM.** After CRM SPEC-316 remote Certify at `28e9052beaefa367b31d4ea7346654678374c54c`, the owner authorized one CRM-only, record-only Batch 6 Exit Reconciliation Draft. The selector exhausted unrecorded surfaces and the registry still derived 22 obligations due at exit. This exception reconciles their records and identifies remaining work. Gate 1 remains separate. The existing ordering, individual finding triggers and Pre-Production Readiness Closure conditions govern. The private Workbench packet retains the source approval.

   ```

   The resulting file's Git blob is 5ca456b301a3d32f40888b4d01375005b78d2841.

2. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `CRM Batch 6 Exit Reconciliation. ARCH-2`; if so record Already Applied when its Git blob is 5aeb65725dcfb94099158ea0124bd4887cfb3a84, and otherwise stop and report. Otherwise make exactly these 5 edits (current evidence appended to the four existing findings), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-19 (**CRM SPEC-316, customer communication preferences.** CUST-17 is fixed. Registration checks Canon 25's preference catalog. The existing table guard continues to govern edits. Verified on Platinum Primary under the exact-SHA Gate 2.)
   ```
   with
   ```text
   Last updated: 2026-11-19 (CRM Batch 6 Exit Reconciliation. ARCH-2, ENTRY-1, PAX-4 and STEPUP-1 distinguish proven members from remaining questions.)

   Previously: 2026-11-19 (**CRM SPEC-316, customer communication preferences.** CUST-17 is fixed. Registration checks Canon 25's preference catalog. The existing table guard continues to govern edits. Verified on Platinum Primary under the exact-SHA Gate 2.)
   ```

   b) replace the line
   ```text
   | PAX-4 | **The "twenty ungoverned tables" count measured trigger sites, not governance — the real number is five** | security / authorization · measurement | Medium | O | 6 | — | 📋 | **OPEN — engineering, but SMALLER AND DIFFERENT THAN RECORDED. The count was never wrong; the inference drawn from it was.** As recorded in slice 4: of the tables `authenticated` may INSERT, **20 have no trigger calling `app.authorize` or `app.has_permission` on INSERT**. Slice 6 re-measured what that implies and found **15 of the 20 carry the capability check inside the RLS POLICY instead of a trigger** — `user_permission_grants` is the clearest case, with three triggers (`derive_created_by`, `moddatetime`, `emit_permission_change`) of which **not one authorizes**, while `scope_insert` and `scope_update` both require `app.has_permission('MANAGE_PERMISSIONS')`. PAX-4 counted **enforcement sites of one kind and reported it as governance**: the same MEAS-1 shape as GUARD-CRLF-1 and Check 12, this time in a register row rather than a guard. **The genuinely uncovered set is FIVE, and every one already has a disposition or a registered reason:** `otp_challenges` (**CLOSED by OTP-1**, slice 6), `totp_enrollments` (**OTP-2**, open decision), `trusted_devices` (canon 34 — ownership IS the model, and `58_...` tests that boundary rather than asserting it), `lead_interactions` (already registered BLOCKED/business in `202607056100`) and `campaign_daily_metrics` (already `AUDITED`, slice 1). **The old row also carried a claim slice 6 DISPROVED and which had reached the manifest:** that `otp_challenges` "is a pre-authentication surface and a capability check there would be a category error". The category-error half is right; the pre-authentication half is false — `anon` holds no grant and matches no policy on that table, so an unauthenticated caller could never reach it, and the surface is INTRA-authentication (canon 34 § 7 makes OTP a second factor, presented at `aal1`). **Stays OPEN** because the five-table question is real, and PAX-4 keeps its ID rather than being closed and reopened so the correction stays attached to what it corrects. **Trigger:** each remaining table's own Batch 6 slice. Ceiling pinned at `<= 20` by `10_grant_model_test` assertion 7 and the membership now NAMED by `67_...` assertion 7 and `106_...` assertions 15-16 — a bare count cannot see one table leaving as another joins | — | session-2026-09-07-batch6-slice4-booking-item-passengers | 09-07 | 09-07 |
   ```
   with
   ```text
   | PAX-4 | **The "twenty ungoverned tables" count measured trigger sites, not governance — the real number is five** | security / authorization · measurement | Medium | O | 6 | — | 📋 | **OPEN — engineering, but SMALLER AND DIFFERENT THAN RECORDED. The count was never wrong; the inference drawn from it was.** As recorded in slice 4: of the tables `authenticated` may INSERT, **20 have no trigger calling `app.authorize` or `app.has_permission` on INSERT**. Slice 6 re-measured what that implies and found **15 of the 20 carry the capability check inside the RLS POLICY instead of a trigger** — `user_permission_grants` is the clearest case, with three triggers (`derive_created_by`, `moddatetime`, `emit_permission_change`) of which **not one authorizes**, while `scope_insert` and `scope_update` both require `app.has_permission('MANAGE_PERMISSIONS')`. PAX-4 counted **enforcement sites of one kind and reported it as governance**: the same MEAS-1 shape as GUARD-CRLF-1 and Check 12, this time in a register row rather than a guard. **The genuinely uncovered set is FIVE, and every one already has a disposition or a registered reason:** `otp_challenges` (**CLOSED by OTP-1**, slice 6), `totp_enrollments` (**OTP-2**, open decision), `trusted_devices` (canon 34 — ownership IS the model, and `58_...` tests that boundary rather than asserting it), `lead_interactions` (already registered BLOCKED/business in `202607056100`) and `campaign_daily_metrics` (already `AUDITED`, slice 1). **The old row also carried a claim slice 6 DISPROVED and which had reached the manifest:** that `otp_challenges` "is a pre-authentication surface and a capability check there would be a category error". The category-error half is right; the pre-authentication half is false — `anon` holds no grant and matches no policy on that table, so an unauthenticated caller could never reach it, and the surface is INTRA-authentication (canon 34 § 7 makes OTP a second factor, presented at `aal1`). **Stays OPEN** because the five-table question is real, and PAX-4 keeps its ID rather than being closed and reopened so the correction stays attached to what it corrects. **Trigger:** each remaining table's own Batch 6 slice. Ceiling pinned at `<= 20` by `10_grant_model_test` assertion 7 and the membership now NAMED by `67_...` assertion 7 and `106_...` assertions 15-16 — a bare count cannot see one table leaving as another joins **2026-11-19 (CRM exit reconciliation):** OTP-2 is resolved by derivation and SPEC-259 shows that TOTP enrollments do not govern MFA. AUTH-1 retirement is trigger-bound. Test 106 assertions 15–16 prove enforcement location. Class closure still requires each remaining authority rationale. | — | session-2026-09-07-batch6-slice4-booking-item-passengers | 09-07 | 11-19 |
   ```

   c) replace the line
   ```text
   | ARCH-2 | **INVOICE-6 closed the UPDATE door on all thirteen archivable tables; the INSERT door is still open on twelve of them** | authorization / audit integrity | Medium | R | 6 | — | 📋 | **OPEN — engineering, PROVEN 2026-09-09, deliberately NOT fixed in a Slice-11 closure.** `202607052800` created every archive trigger as `before update`, so `app.enforce_archive_authority` — which INVOICE-6 correctly repaired in the ONE function all thirteen tables route through — **never fires on INSERT** for twelve of them. Only `customers` carries `before insert or update`, added by `20260909060754`. REPRODUCED against a clean local reset: an `authenticated` employee proven to hold **no** `ARCHIVE_RECORD` ran a plain `insert into public.customer_notes(... is_archived=true, archive_reason='forged narrative', archived_by=<self>)` and it **succeeded**, producing a row born archived, carrying a narrative nobody was authorized to write and an archiver value the server never stamped. This is **BOOK-1's "test both doors" against an archive guard**: INVOICE-6 measured, repaired and guarded the UPDATE path on thirteen tables, and the INSERT path was never the subject of the measurement, so a `coalesce` that no longer wins on UPDATE is simply not consulted on INSERT. **Not repaired here on purpose** — the one-line fix (widen the twelve triggers to `before insert or update`) changes archive-creation semantics on `bookings`, `invoices`, `documents`, `suppliers`, `passengers`, `leads`, `quotations`, `tasks`, `complaints`, `service_requests`, `booking_items` and `customer_notes`, every one of them a surface outside slice 11, and `AGENTS.md §5b` requires each affected execution path be classified and proven separately rather than by one generic answer. Each table's own Batch 6 slice is where that proof belongs; the finding is recorded so no slice can reach it without an existing row **2026-09-24 (SPEC-216): `documents` closed — refused at entry rather than authorized, because no RPC creates a document archived; eleven tables remain.** **2026-10-10 (SPEC-257): `service_requests` closed the same way — refused at entry for every caller, because no RPC creates a service request archived; the count falls to ten.** **2026-10-11 (SPEC-262): `complaints` closed the same way — refused at entry for every caller, because no RPC creates a complaint archived; the count falls to nine.** | — | session-2026-09-09-slice11-closure | 09-09 | 10-11 |
   ```
   with
   ```text
   | ARCH-2 | **INVOICE-6 closed the UPDATE door on all thirteen archivable tables; the INSERT door is still open on twelve of them** | authorization / audit integrity | Medium | R | 6 | — | 📋 | **OPEN — engineering, PROVEN 2026-09-09, deliberately NOT fixed in a Slice-11 closure.** `202607052800` created every archive trigger as `before update`, so `app.enforce_archive_authority` — which INVOICE-6 correctly repaired in the ONE function all thirteen tables route through — **never fires on INSERT** for twelve of them. Only `customers` carries `before insert or update`, added by `20260909060754`. REPRODUCED against a clean local reset: an `authenticated` employee proven to hold **no** `ARCHIVE_RECORD` ran a plain `insert into public.customer_notes(... is_archived=true, archive_reason='forged narrative', archived_by=<self>)` and it **succeeded**, producing a row born archived, carrying a narrative nobody was authorized to write and an archiver value the server never stamped. This is **BOOK-1's "test both doors" against an archive guard**: INVOICE-6 measured, repaired and guarded the UPDATE path on thirteen tables, and the INSERT path was never the subject of the measurement, so a `coalesce` that no longer wins on UPDATE is simply not consulted on INSERT. **Not repaired here on purpose** — the one-line fix (widen the twelve triggers to `before insert or update`) changes archive-creation semantics on `bookings`, `invoices`, `documents`, `suppliers`, `passengers`, `leads`, `quotations`, `tasks`, `complaints`, `service_requests`, `booking_items` and `customer_notes`, every one of them a surface outside slice 11, and `AGENTS.md §5b` requires each affected execution path be classified and proven separately rather than by one generic answer. Each table's own Batch 6 slice is where that proof belongs; the finding is recorded so no slice can reach it without an existing row **2026-09-24 (SPEC-216): `documents` closed — refused at entry rather than authorized, because no RPC creates a document archived; eleven tables remain.** **2026-10-10 (SPEC-257): `service_requests` closed the same way — refused at entry for every caller, because no RPC creates a service request archived; the count falls to ten.** **2026-10-11 (SPEC-262): `complaints` closed the same way — refused at entry for every caller, because no RPC creates a complaint archived; the count falls to nine.** **2026-11-19 (CRM exit reconciliation):** SPEC-310 records archived-at-entry customer notes as an explicit position. SPEC-215 keeps the supplier evidence open and SPEC-230 test 134 documents the open task member. The older counts are historical snapshots pending current member-level confirmation. | — | session-2026-09-09-slice11-closure | 09-09 | 11-19 |
   ```

   d) replace the line
   ```text
   | ENTRY-1 | **The state machine governs every move except the first, on ten more tables** | business invariant / state | Medium | R | 6 | — | 📋 | **OPEN — ENGINEERING, not an owner decision, and recorded because the SECOND instance made it a class rather than a coincidence.** `app.enforce_status_transition` is `before update` and has no entry arm, so on every table it guards a row can be INSERTed directly into any status the catalog accepts, including a terminal one. LEAD-2 was the first instance (`202607061900`: a lead born `won`), INVOICE-4 the second (`202607062000`: an invoice born `paid`, or `voided` with no reason and no timestamp). MEASURED 2026-09-08, not estimated: the trigger is attached to **twelve** tables — `booking_items`, `bookings`, `complaints`, `conversations`, `documents`, `invoices`, `leads`, `marketing_campaigns`, `quotations`, `refunds`, `service_requests`, `tasks` — and exactly **two** of them carry an entry-state guard, both added by the Batch-6 slice that reached them. **Ten tables have a governed transition machine and an ungoverned entry.** **Deliberately not fixed generically here.** The legal entry state is not expressible in `app.status_transitions` as it stands — the table records `from_status -> to_status` and has no notion of a first state — and each table's entry state has to be read off its own creating RPC, which is what a slice does. Inventing a shared entry rule from two samples would be inventing policy for ten tables nobody has read yet. **Trigger:** closed per surface as Batch 6 reaches each table (the LEAD-2 / INVOICE-4 shape, one guard each); OR, if a third or fourth slice finds itself writing the same guard, promote it by giving `app.status_transitions` an entry-state representation and letting the shared trigger enforce it on INSERT — at which point the per-table guards collapse into it. Whichever way it goes, **the class is now recorded and cannot be rediscovered as if new** **2026-09-24 (SPEC-214): `quotations` closed by QUO-5, the third instance; nine tables remain. Promotion into `app.status_transitions` was weighed and declined — it would change INSERT behaviour on nine surfaces no slice has read, and here the entry rule is one arm of a guard three other findings needed.** **2026-09-24 (SPEC-216): `documents` closed, the fourth instance, by one arm of a door-parity guard; eight tables remain. Promotion still declined for SPEC-214's reason.** **2026-09-24 (SPEC-217): `refunds` closed, the fifth instance, by the refund-local entry guard; seven tables remain. No generic entry rule was introduced.** **2026-09-24 (SPEC-220): `conversations` closed, the sixth instance, by a conversation-local guard requiring `open` and null `closed_at` for both signed-in and session-less creation; six tables remain. CHAT-1 owns the accompanying creator and event discrepancy. No generic entry rule was introduced.** **2026-09-29 (SPEC-239): `bookings` closed, the seventh instance, by the entry arm of `app.enforce_booking_lifecycle`, which requires `draft` for signed-in creation, LEAD-2's session-less exemption; five tables remain. No generic entry rule was introduced.** **2026-10-10 (SPEC-257): `service_requests` closed, the eighth instance, by a service-request-local guard requiring `requested` and no resolution time for every caller; four tables remain. No generic entry rule was introduced.** **2026-10-11 (SPEC-262): `complaints` closed, the ninth instance, by a complaint-local guard requiring `new` and no resolution time, closure time or resolution note for every caller; three tables remain. No generic entry rule was introduced.** | — | session-2026-09-08-batch6-slice10-invoices | 09-08 | 10-11 |
   ```
   with
   ```text
   | ENTRY-1 | **The state machine governs every move except the first, on ten more tables** | business invariant / state | Medium | R | 6 | — | 📋 | **OPEN — ENGINEERING, not an owner decision, and recorded because the SECOND instance made it a class rather than a coincidence.** `app.enforce_status_transition` is `before update` and has no entry arm, so on every table it guards a row can be INSERTed directly into any status the catalog accepts, including a terminal one. LEAD-2 was the first instance (`202607061900`: a lead born `won`), INVOICE-4 the second (`202607062000`: an invoice born `paid`, or `voided` with no reason and no timestamp). MEASURED 2026-09-08, not estimated: the trigger is attached to **twelve** tables — `booking_items`, `bookings`, `complaints`, `conversations`, `documents`, `invoices`, `leads`, `marketing_campaigns`, `quotations`, `refunds`, `service_requests`, `tasks` — and exactly **two** of them carry an entry-state guard, both added by the Batch-6 slice that reached them. **Ten tables have a governed transition machine and an ungoverned entry.** **Deliberately not fixed generically here.** The legal entry state is not expressible in `app.status_transitions` as it stands — the table records `from_status -> to_status` and has no notion of a first state — and each table's entry state has to be read off its own creating RPC, which is what a slice does. Inventing a shared entry rule from two samples would be inventing policy for ten tables nobody has read yet. **Trigger:** closed per surface as Batch 6 reaches each table (the LEAD-2 / INVOICE-4 shape, one guard each); OR, if a third or fourth slice finds itself writing the same guard, promote it by giving `app.status_transitions` an entry-state representation and letting the shared trigger enforce it on INSERT — at which point the per-table guards collapse into it. Whichever way it goes, **the class is now recorded and cannot be rediscovered as if new** **2026-09-24 (SPEC-214): `quotations` closed by QUO-5, the third instance; nine tables remain. Promotion into `app.status_transitions` was weighed and declined — it would change INSERT behaviour on nine surfaces no slice has read, and here the entry rule is one arm of a guard three other findings needed.** **2026-09-24 (SPEC-216): `documents` closed, the fourth instance, by one arm of a door-parity guard; eight tables remain. Promotion still declined for SPEC-214's reason.** **2026-09-24 (SPEC-217): `refunds` closed, the fifth instance, by the refund-local entry guard; seven tables remain. No generic entry rule was introduced.** **2026-09-24 (SPEC-220): `conversations` closed, the sixth instance, by a conversation-local guard requiring `open` and null `closed_at` for both signed-in and session-less creation; six tables remain. CHAT-1 owns the accompanying creator and event discrepancy. No generic entry rule was introduced.** **2026-09-29 (SPEC-239): `bookings` closed, the seventh instance, by the entry arm of `app.enforce_booking_lifecycle`, which requires `draft` for signed-in creation, LEAD-2's session-less exemption; five tables remain. No generic entry rule was introduced.** **2026-10-10 (SPEC-257): `service_requests` closed, the eighth instance, by a service-request-local guard requiring `requested` and no resolution time for every caller; four tables remain. No generic entry rule was introduced.** **2026-10-11 (SPEC-262): `complaints` closed, the ninth instance, by a complaint-local guard requiring `new` and no resolution time, closure time or resolution note for every caller; three tables remain. No generic entry rule was introduced.** **2026-11-19 (CRM exit reconciliation):** The three unmatched names in the recorded series are booking items, marketing campaigns and tasks. SPEC-222 test 127 and SPEC-230 test 134 preserve the latter two observations. Review booking-item creation and tests 74/105 for its expected initial state and consequence. The approved per-surface method still governs. | — | session-2026-09-08-batch6-slice10-invoices | 09-08 | 11-19 |
   ```

   e) replace the line
   ```text
   | STEPUP-1 | **A class CANDIDATE, found by structural evidence: eleven tables carry a direct permission-only write path with no step-up anywhere in their trigger chain** | security · authorization · class | Unclassified | R | 6 | — | 📋 | **UNPROVEN — structural candidate class, recorded, deliberately not acted on (Batch 6 Slice 24).** Not a reproduced class defect. Criterion, read from the local catalog at `b6a0714`: `authenticated` holds INSERT or UPDATE; the INSERT or UPDATE policy charges `app.has_permission(K)` for a K held only by roles that `app.requires_mfa` binds to step-up; and no trigger on the table, at any timing, calls `app.authorize` or `app.mfa_satisfied` directly or through one level of `app` helper. Eleven tables meet it: `branches`, `campaign_daily_metrics`, `catalog_values`, `chart_of_accounts`, `departments`, `document_retention_policies`, `exchange_rate_adjustments`, `exchange_rates`, `journal_entries`, `journal_entry_lines`, `tenants`. `user_branch_assignments` and `user_permission_grants` meet it too and belong to USR-3. `user_role_assignments` does NOT: its AFTER trigger `app.emit_role_change` charges `app.authorize('MANAGE_USERS')`, which a first, BEFORE-only reading missed and a rolled-back probe corrected. **Only `branches` is a reproduced and consequence-classified defect (BRANCH-1, Low).** **`journal_entry_lines` was audited in Batch 6 Slice 32 (SPEC-245): an `aal1` finance manager rewrote posted lines the RPC refuses it to post, and that member is closed by JE-3's repair; it no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it. `chart_of_accounts` was audited in Batch 6 Slice 42 (SPEC-278): its member was reproduced as COA-2 and is closed, and it no longer meets the criterion, because `app.guard_chart_account` charges `app.authorize`. `journal_entries` still meets it (JE-5).** The same probe saw an `aal1` owner's rename land on `departments` and on `tenants`. `departments`' consequence is not classified, so it remains a candidate and is not an audit. **`tenants` was audited in Batch 6 Slice 26 (SPEC-228) and its consequence is classified: none material.** An `aal1` `owner` or `ceo` does write every tenant-profile column, but nothing reads any of them except `name`, shown only to the tenant's own members; no canon marks a tenant-profile edit as step-up, platform-only or sensitive; and the other MANAGE_TENANT_SETTINGS doors that charge `app.authorize` guard distinct actions (licence redemption, payment-proof upload, legal hold, document versions and links, holidays), not a second door to the same action. So `tenants` still meets the criterion, is not a defect, and does not raise this class above UNPROVEN. The other eight are structural candidates only; the finance tables among them are where a consequence, if reproduced, would most likely be material. A member becomes a defect only when it is individually reproduced adversarially and its consequence is classified, and no member gains a disposition or counts toward Batch 6 coverage by being listed here. `campaign_daily_metrics` and `exchange_rate_adjustments` are recorded `AUDITED`, and step-up was not asked on either. **Ceiling:** the criterion reads function text, so it can miss step-up charged through deeper indirection and it cannot see consequence (MEAS-1). **Trigger to revisit:** the Batch 6 slice of any listed table, or the first reproduced consequence on a candidate. **2026-10-08 (SPEC-246): `journal_entries` no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it; its member consequence, JE-5, is closed by that revoke.** **2026-11-11 (SPEC-301): `departments` was audited in Batch 6 Slice 46; its member was reproduced as DEP-1 with a classified consequence (DEP-3) and is closed, and it no longer meets the criterion, because `app.guard_department_write` charges `app.authorize`.** **2026-11-11 (SPEC-305): `document_retention_policies` was audited in Batch 6 Slice 49; its member was reproduced as RET-3 with a classified consequence (a superseded file made deletable at `aal1`) and is closed, and it no longer meets the criterion, because `app.guard_document_retention_policy_write` charges `app.authorize`.** **2026-11-14 (SPEC-307): `exchange_rates` and `catalog_values` were audited in Batch 6 Slice 51; each member was reproduced with a classified consequence (FX-6 with FX-5: an `aal1` finance manager set the rate money is converted at; CAT-9 with CAT-7 and CAT-8: an `aal1` owner extended platform-owned families and renamed a value in use) and is closed, and neither meets the criterion any more, because `app.guard_exchange_rate_write` and `app.guard_catalog_value_write` charge `app.authorize`. `user_permission_grants` no longer meets it either: USR-3 is closed by `app.guard_permission_grant_authority`.** | — | SPEC-226-branch-door-audit-record | 09-27 | 09-27 |
   ```
   with
   ```text
   | STEPUP-1 | **A class CANDIDATE, found by structural evidence: eleven tables carry a direct permission-only write path with no step-up anywhere in their trigger chain** | security · authorization · class | Unclassified | R | 6 | — | 📋 | **UNPROVEN — structural candidate class, recorded, deliberately not acted on (Batch 6 Slice 24).** Not a reproduced class defect. Criterion, read from the local catalog at `b6a0714`: `authenticated` holds INSERT or UPDATE; the INSERT or UPDATE policy charges `app.has_permission(K)` for a K held only by roles that `app.requires_mfa` binds to step-up; and no trigger on the table, at any timing, calls `app.authorize` or `app.mfa_satisfied` directly or through one level of `app` helper. Eleven tables meet it: `branches`, `campaign_daily_metrics`, `catalog_values`, `chart_of_accounts`, `departments`, `document_retention_policies`, `exchange_rate_adjustments`, `exchange_rates`, `journal_entries`, `journal_entry_lines`, `tenants`. `user_branch_assignments` and `user_permission_grants` meet it too and belong to USR-3. `user_role_assignments` does NOT: its AFTER trigger `app.emit_role_change` charges `app.authorize('MANAGE_USERS')`, which a first, BEFORE-only reading missed and a rolled-back probe corrected. **Only `branches` is a reproduced and consequence-classified defect (BRANCH-1, Low).** **`journal_entry_lines` was audited in Batch 6 Slice 32 (SPEC-245): an `aal1` finance manager rewrote posted lines the RPC refuses it to post, and that member is closed by JE-3's repair; it no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it. `chart_of_accounts` was audited in Batch 6 Slice 42 (SPEC-278): its member was reproduced as COA-2 and is closed, and it no longer meets the criterion, because `app.guard_chart_account` charges `app.authorize`. `journal_entries` still meets it (JE-5).** The same probe saw an `aal1` owner's rename land on `departments` and on `tenants`. `departments`' consequence is not classified, so it remains a candidate and is not an audit. **`tenants` was audited in Batch 6 Slice 26 (SPEC-228) and its consequence is classified: none material.** An `aal1` `owner` or `ceo` does write every tenant-profile column, but nothing reads any of them except `name`, shown only to the tenant's own members; no canon marks a tenant-profile edit as step-up, platform-only or sensitive; and the other MANAGE_TENANT_SETTINGS doors that charge `app.authorize` guard distinct actions (licence redemption, payment-proof upload, legal hold, document versions and links, holidays), not a second door to the same action. So `tenants` still meets the criterion, is not a defect, and does not raise this class above UNPROVEN. The other eight are structural candidates only; the finance tables among them are where a consequence, if reproduced, would most likely be material. A member becomes a defect only when it is individually reproduced adversarially and its consequence is classified, and no member gains a disposition or counts toward Batch 6 coverage by being listed here. `campaign_daily_metrics` and `exchange_rate_adjustments` are recorded `AUDITED`, and step-up was not asked on either. **Ceiling:** the criterion reads function text, so it can miss step-up charged through deeper indirection and it cannot see consequence (MEAS-1). **Trigger to revisit:** the Batch 6 slice of any listed table, or the first reproduced consequence on a candidate. **2026-10-08 (SPEC-246): `journal_entries` no longer meets the criterion, because `authenticated` holds no INSERT or UPDATE on it; its member consequence, JE-5, is closed by that revoke.** **2026-11-11 (SPEC-301): `departments` was audited in Batch 6 Slice 46; its member was reproduced as DEP-1 with a classified consequence (DEP-3) and is closed, and it no longer meets the criterion, because `app.guard_department_write` charges `app.authorize`.** **2026-11-11 (SPEC-305): `document_retention_policies` was audited in Batch 6 Slice 49; its member was reproduced as RET-3 with a classified consequence (a superseded file made deletable at `aal1`) and is closed, and it no longer meets the criterion, because `app.guard_document_retention_policy_write` charges `app.authorize`.** **2026-11-14 (SPEC-307): `exchange_rates` and `catalog_values` were audited in Batch 6 Slice 51; each member was reproduced with a classified consequence (FX-6 with FX-5: an `aal1` finance manager set the rate money is converted at; CAT-9 with CAT-7 and CAT-8: an `aal1` owner extended platform-owned families and renamed a value in use) and is closed, and neither meets the criterion any more, because `app.guard_exchange_rate_write` and `app.guard_catalog_value_write` charge `app.authorize`. `user_permission_grants` no longer meets it either: USR-3 is closed by `app.guard_permission_grant_authority`.** **2026-11-19 (CRM exit reconciliation):** The remaining named questions are reproduced BRANCH-1 and two previously unswept candidate axes, campaign daily metrics and exchange-rate adjustments. SPEC-245/246 close the journal members, and the later entries carry the local repairs. The class remains UNPROVEN. | — | SPEC-226-branch-door-audit-record | 09-27 | 11-19 |
   ```

   The resulting file's Git blob is 5aeb65725dcfb94099158ea0124bd4887cfb3a84.

3. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `CRM Batch 6 Exit Reconciliation. OTP-2 is settled`; if so record Already Applied when its Git blob is 3f2094ab564533afe8b196c16c1021e41b6b86b5, and otherwise stop and report. Otherwise make exactly these 2 edits (the existing OTP record and its retirement trigger), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-18 (**slice 59 — `nationalities`, `countries` and `currencies` selected by Exposure 0, coverage 4, 10 and 22, in one contract, with `languages` by the owner's policy of 2026-11-18.** Coverage **75 → 78 of 78**. REF-2: a deactivated nationality, country, currency or language was accepted on new business. SPEC-315 closes it here, so the three new rows are `AUDITED` and the `languages` row records the new rule. No other row changed.)
   ```
   with
   ```text
   Last updated: 2026-11-19 (CRM Batch 6 Exit Reconciliation. OTP-2 is settled by derivation. The OTP challenge record carries the existing AUTH-1 retirement trigger.)

   Previously: 2026-11-18 (**slice 59 — `nationalities`, `countries` and `currencies` selected by Exposure 0, coverage 4, 10 and 22, in one contract, with `languages` by the owner's policy of 2026-11-18.** Coverage **75 → 78 of 78**. REF-2: a deactivated nationality, country, currency or language was accepted on new business. SPEC-315 closes it here, so the three new rows are `AUDITED` and the `languages` row records the new rule. No other row changed.)
   ```

   b) replace the line
   ```text
   | `otp_challenges` | **AUDITED-OPEN** | ADVERSARIAL | `session-2026-09-07-batch6-slice6-otp-challenges` | OTP-1, OTP-2, PAX-4 | `106_otp_challenge_subject_authority_test.sql` — 16 assertions, 3 classes declared `N/A` with reasons. `202607061600` closed **OTP-1** (the subject of a challenge could self-verify it, reset its own attempt counter, extend its expiry, redirect its delivery address and forge a pre-verified one — all reproduced at `aal1`). **The slice refuted its own premise:** the manifest predicted "correctly unguarded — pre-authentication", and `anon` holds no grant and matches no policy here, so the surface is INTRA-authentication (canon 34 § 7 makes OTP a second factor). `AUDITED-OPEN` because **OTP-2** is a security-policy decision (MFA self-disable at `aal1` on `totp_enrollments`), not engineering. **PAX-4 is listed because this slice corrected it**, not because it belongs to this table: 15 of its 20 "ungoverned" tables carry the capability check in RLS, so the uncovered set is five |
   ```
   with
   ```text
   | `otp_challenges` | **AUDITED-OPEN** | ADVERSARIAL | `session-2026-09-07-batch6-slice6-otp-challenges` | OTP-1, OTP-2, PAX-4, AUTH-1 | `106_otp_challenge_subject_authority_test.sql` — 16 assertions, 3 classes declared `N/A` with reasons. `202607061600` closed **OTP-1** (the subject of a challenge could self-verify it, reset its own attempt counter, extend its expiry, redirect its delivery address and forge a pre-verified one — all reproduced at `aal1`). **The slice refuted its own premise:** the manifest predicted "correctly unguarded — pre-authentication", and `anon` holds no grant and matches no policy here, so the surface is INTRA-authentication (canon 34 § 7 makes OTP a second factor). **OTP-2** resolved by derivation on 2026-09-08. SPEC-259 adds the TOTP non-authority proof. `AUDITED-OPEN` carries **AUTH-1** retirement before the first client-facing authentication build or first reference, whichever comes first. **PAX-4 is listed because this slice corrected it**, not because it belongs to this table: 15 of its 20 "ungoverned" tables carry the capability check in RLS, so the uncovered set is five |
   ```

   The resulting file's Git blob is 3f2094ab564533afe8b196c16c1021e41b6b86b5.

4. **Verify and synchronize the records.** Use the native repository guard, including Check 29, to confirm 17 action-registry obligations still due at Batch 6 exit and all source records classified once. Confirm the exact scope and `git diff --check`. Synchronize the contract and native discovery artifacts. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-317: CRM Batch 6 exit evidence reconciled.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] The Plan contains the exact exception, reconciled obligations and measured exit evidence. `check: blob reports/master/MASTER_EXECUTION_PLAN.md 5ca456b301a3d32f40888b4d01375005b78d2841`
- [ ] The findings record preserves open IDs and incorporates the exact updated provenance. `check: blob reports/master/MASTER_GAP_REGISTER.md 5aeb65725dcfb94099158ea0124bd4887cfb3a84`
- [ ] The surface record carries the exact OTP correction while preserving all disposition counts. `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md 3f2094ab564533afe8b196c16c1021e41b6b86b5`
- [ ] The native work selector is preserved. `check: same scripts/batch6_select_target.ps1 @28e9052beaefa367b31d4ea7346654678374c54c`
- [ ] The native registry evaluation is preserved. `check: same scripts/readiness_population.ps1 @28e9052beaefa367b31d4ea7346654678374c54c`
- [ ] The Plan leaves the existing release and prerequisites in force. The five trigger-bound surfaces, OD-9, CTRL-19 and all genuine findings retain their remaining obligations.

## Execution Log

None.

### 2026-11-19 — Original record implementation

Outcome: Complete (implementation only, native Finish and Review pending)

- Steps 1–3 Applied: the approved Workbench applier replayed the three exact record blobs. Gate 1 allocation 69ee92966840d53b9aaab1d42a69297c6e12fce9 and approval 150dd622d6ccb7a3e40a8c08423d093f70bb8d93 checked the owner-authorized digest. The native Approval evaluator reported NOT APPLICABLE for this repository-only profile.
- reports/master/MASTER_EXECUTION_PLAN.md blob 5ca456b301a3d32f40888b4d01375005b78d2841.
- reports/master/MASTER_GAP_REGISTER.md blob 5aeb65725dcfb94099158ea0124bd4887cfb3a84.
- reports/master/MASTER_SURFACE_DISPOSITION.md blob 3f2094ab564533afe8b196c16c1021e41b6b86b5.
- Step 4 Applied: the native registry has 17 B6-EXIT obligations due, 21 open and 3 partial dispositions, and all five named surfaces at OWN-TRIGGER. Discovery is current. Fresh timed Finish and Review remain pending.

## Verification Notes

None.


### 2026-11-19 — Gate 1 approval recorded

The owner approved CRM SPEC-317 Original Gate 1 for SHA-256 36888D97C8A48543B8B704CABF10F3AFAFB1302ED6A2FB2AB814AD2DA3BBFED5, CRM records only. The private Workbench approval record GATE1-SPEC-317-OWNER.md has SHA-256 A2AE3AF2592810D6DDFB8A356E9DE3483763B3C4656CEAEF74BEE5C9A4F8DBFA. Immediately before allocation the hash, the Draft blob e9df822cf59a359be39a1cdb10a3bf964f360258, all 3 source anchors, the baseline HEAD 28e9052beaefa367b31d4ea7346654678374c54c against refreshed origin/main 28e9052beaefa367b31d4ea7346654678374c54c and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 69ee929. No implementation performed before this transition. Publication and promotion follow separate owner authority.


### 2026-11-19 — Independent Original Review

Verdict: Confirmed Complete

Findings: Reviewed committed implementation 565ed5856fd9498e1687f2aedbbad17b03b72bb3 from the approved 28e9052beaefa367b31d4ea7346654678374c54c baseline. The three record blobs equal the frozen literal payload and both selector and registry tooling match the baseline. The native range Gate, watched Finish and fresh REPOSITORY receipt passed. All 17 expected due IDs remain present, the five individually triggered dispositions stay AUDITED-OPEN, and the owner, legal and external dependency rows were preserved. The exact range contains the contract, three records and native lifecycle metadata. Verified checks and receipts are in the private Workbench packet.

Recommendation to human: Set Status to Complete under the existing native Original lifecycle.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 28e9052beaefa367b31d4ea7346654678374c54c.

Owner authority: Workbench `data/records/batch6/exit-reconciliation/OWNER-DRAFT-APPROVAL.txt`, SHA-256 `9E78648D5165C898E8B62CF6740A2F2DA7CBC6C0C29CC8BE3FEFFEAB0206F167`.

Prototype evidence: `readiness-proto.log` and `repository-proto.log` in the same Workbench packet. The accepted baseline evidence is under `data/records/batch6/contact-preference` including `release/RELEASE-RESULT.json`, `runtime/gate2-local-primary-parity.log`, `runtime/original-api-e2e.log`, `runtime/original-pgtap-A.log`, `runtime/original-pgtap-B.log` and `runtime/original-db-smoke.log`.

Owner and external dependencies stay on their existing path. OD-9's unresolved app-check profile and CTRL-19's independent GitHub enforcement do not block this records Draft. Finance policy DC-11 or the approved fail-closed containment is still needed for JE-2. The AUTH-1 and SPP-3 release conditions remain attached to their own triggers.

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `e957b949bc330cb637a634644664bf93bd2eb5ce` |
| `reports/master/MASTER_GAP_REGISTER.md` | `dce96cc749202fb45b544fe80dfe7645591b95c0` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `f85cf12e36b38a7560f0fb7f86de959983bca836` |
