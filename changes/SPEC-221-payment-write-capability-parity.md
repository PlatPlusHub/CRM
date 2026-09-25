# Change Request — SPEC-221

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Require `RECORD_PAYMENT` for authenticated changes to the financially material fields of an existing payment through the direct table door.

## Business Reason

Batch 6 Slice 20 selected `payments` live at Exposure 11, coverage 84; `marketing_campaigns` was runner-up at 10/26. A real employee without `RECORD_PAYMENT` could see a payment through its booking and change its direction, customer or currency through authenticated UPDATE. In a rolled-back probe, changing `customer_payment` to `customer_refund` changed the customer's paid amount from 100 to 0 and outstanding balance from 35,900 to 36,000 EGP while the payment amount remained 100. The existing `app.guard_financial_capability` charged permission only when `amount` changed. This is a financial authorization gap, not a new payment policy.

## Risks

- Expanding a shared financial trigger function could accidentally change other tables' permission behavior; the migration must change only its `payments` column list.
- An UPDATE might be refused by RLS or a different trigger instead of this capability check; the test must prove row visibility and actor capability, then mutation-prove the named mapping.
- Primary deployment changes production function behavior and requires separate authorization for exact migration and test bytes after local proof.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-221-payment-write-capability-parity.md`
- `supabase/migrations/20260925120000_payment_write_capability_parity.sql`
- `supabase/tests/126_payment_write_capability_parity_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607057100_an_invoice_may_not_be_declared_paid_by_anyone_who_can_see_it.sql`
- `supabase/migrations/202607047100_record_payment.sql`
- `supabase/migrations/202607047400_record_supplier_payment.sql`
- `supabase/tests/56_financial_write_capability_test.sql`
- `supabase/tests/68_financial_status_capability_test.sql`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `reports/architecture-decision-records.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/07_finance_model.md` (payments); `_ORVION_CANONICAL/14_finance_rules.md` (money and currency); `_ORVION_CANONICAL/28_permissions_matrix.md` (`RECORD_PAYMENT`); `_ORVION_CANONICAL/31_schema_draft.md` (`payments`)
- Current local `app.guard_financial_capability`, `app.customer_balance`, `app.customer_exposure_in_limit_currency`, `app.supplier_balance`, `app.supplier_exposure_in_limit_currency`, `app.record_payment`, `app.record_supplier_payment`; `supabase/tests/56_financial_write_capability_test.sql` and `supabase/tests/68_financial_status_capability_test.sql`
- `reports/master/MASTER_SURFACE_DISPOSITION.md` (`payments`); `reports/master/MASTER_GAP_REGISTER.md` (PAY-1, FIN-3, ATTR-2 and separately owned payment gaps); `reports/master/MASTER_INTEGRATION_CATALOG.md` §0

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`
- `pwsh -NoProfile -File scripts/verify_role_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_care_journeys.ps1`
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_storage_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Authenticated UPDATE of payment direction and counterparty requires `RECORD_PAYMENT` | `app.customer_balance`; `reporting.customer_outstanding`; `app.customer_exposure_in_limit_currency`; customer credit probe | VERIFY | Employee without capability changed a visible payment from `customer_payment` to `customer_refund`; paid amount fell 100 to 0 and outstanding rose 100. The same actor set `customer_id` null and removed 100 from the customer's paid amount. Existing amount permission remains. |
| Authenticated UPDATE of supplier, booking, denomination, account and payment timing requires the same capability | `app.supplier_balance`; `app.supplier_exposure_in_limit_currency`; supplier credit probe; booking-specific balances; bank/account conversion; receipt and allocation references | VERIFY | These fields are read as payment economic identity. The employee changed a visible payment from EGP to USD without capability, shifting 100 from the EGP balance to USD. The contract charges the existing capability on a changed value; FK, catalog, account conversion and allocation rules stay in their existing authorities. |
| RPC and session-less payment writes | `app.record_payment`; `app.record_supplier_payment`; local system/fixture writes | VERIFY | Both RPCs INSERT and never UPDATE `payments`; their `RECORD_PAYMENT` check already precedes INSERT. The existing guard exempts null `auth.uid()` and keeps that behavior. Rolled-back prototype changed only the payments UPDATE column list, denied the employee with SQLSTATE 42501 and allowed an authorized owner; original function definition was restored exactly. |
| Payment creation events and row-shape integrity remain separate | `public.events`; `app.customer_timeline`; `app.map_outcomes_to_conversions`; payment direction catalog | UNAFFECTED | Separately reproduced: direct authorized INSERT yielded zero payment events while the RPC yielded one, and a direct zero-valued row coded `customer_refund` persisted in `payments`. Neither is caused or closed by UPDATE capability charging; record as separate open Slice-20 findings without broadening this repair. |
| Function definition and measured deployment state | focused pgTAP, existing financial tests, API contract, Primary evidence, manifest, disposition, gap register, map | WRITE | New test must prove non-empty allowed and denied paths and mutation; generated outputs remain in exact scope. Primary values will be measured after deployment. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused test, pgTAP A/B, six HTTP suites, smoke and installed mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Slice-20 findings and 21/77 disposition accurately describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Manifest and Primary ledger/function/structure agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| API contract and map match generators | BEFORE_COMPLETION | Step 7 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: `app.guard_financial_capability` already runs BEFORE INSERT OR UPDATE on `payments`, charges `RECORD_PAYMENT` for INSERT and amount changes, and compares named fields using `to_jsonb`; its payments UPDATE list omits direction and all non-amount economic fields. Reuse it without adding a trigger or permission.

Added Property: every changed financially material payment field is charged to `RECORD_PAYMENT` for an authenticated UPDATE, while reference-only metadata, other financial tables, RPC INSERTs and session-less paths retain their existing behavior.

Causal Negative: A real employee with no `RECORD_PAYMENT` saw one booking-linked payment, changed its direction with UPDATE 1, and reduced `app.customer_balance.paid_amount` from 100 to 0; setting `customer_id` null and changing EGP to USD also landed and changed the reported balance. Every probe rolled back.

Positive Test Design: Establish one visible payment, an employee without the permission and an owner with it. The owner may still update an unallocated, unverified payment amount and metadata; both payment RPC INSERT paths and a valid session-less UPDATE must keep working. Show unchanged-field UPDATE does not acquire a new capability requirement.

Negative Test Design: The employee's direction, customer, currency and other named economic-field changes must fail with SQLSTATE 42501 while a visible-row count remains one; an amount change must continue to fail by the existing branch. Assert the payment and balance remain unchanged after each refusal.

Non-Empty Population Obligation: Prove the payment ID exists and is visible to the employee, the employee's `RECORD_PAYMENT` is false, the owner's is true, a permitted UPDATE changes exactly one row, and each denied attempt targets that same row.

Mutation Obligation: Save the installed function definition; remove the newly mapped payment fields while retaining `amount`, positively inspect the installed mutant, rerun the same direction/customer/currency attacks and observe at least one unauthorized change land and alter balance; restore and prove exact definition equality. A failed installation is HARNESS ERROR, never a killed mutant. The existing amount mapping must remain live throughout.

Post-Implementation Proof Obligation: Focused test, clean reset, pgTAP A/B, six HTTP suites, smoke, installed/restored mutation, generated artifacts, fresh Primary evidence, parity and repository Gate on final bytes.

## Implementation Steps

1. **Check** that `supabase/migrations/20260925120000_payment_write_capability_parity.sql` is absent. If absent, create one LF migration replacing `app.guard_financial_capability()` with its current complete definition except that the `payments` `v_cols` list becomes `amount`, `payment_direction_code`, `customer_id`, `supplier_id`, `booking_id`, `booking_item_id`, `financial_account_id`, `currency_code`, `payment_method_code`, `paid_at`, `exchange_rate_id`. Preserve function signature, SECURITY INVOKER, search path, all other table lists, INSERT branch, null-session exemption, error behavior, existing trigger and grants. If the target exists with different bytes or the source function differs unexpectedly, stop.
2. **Check** that `supabase/tests/126_payment_write_capability_parity_test.sql` is absent. If absent, create one LF transaction-rolled-back pgTAP file with `-- ATTACK-CLASSES:` and an exact `plan(N)`. Prove the Positive and Negative Test Design with actor permission and visible-row controls, balance consequence, unchanged other-table mapping, session-less behavior, and installed-function structural inventory. Include an installed/restored mutation that deletes only the new payments fields and proves the same unauthorized operation succeeds before restoration; prove exact function restoration. If the target exists with different bytes, stop.
3. **Check** whether `payments` remains `NOT-RECORDED` and PAY-2/3/4 are absent from the master register. If so, register PAY-2 as the reproduced High authorization and balance gap fixed by this change; register PAY-3 as the separately reproduced Medium direct-creation event gap and PAY-4 as the separately reproduced Low zero/refund-coded payment entry gap, both OPEN. Set only `payments` to `AUDITED-OPEN` / `ADVERSARIAL` with findings PAY-2, PAY-3, PAY-4, and mechanically update Batch-6 coverage to 21/77. Preserve existing PAY-1 and other findings. If the current record conflicts, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run clean local reset, focused test, pgTAP Pass A, six declared HTTP suites, pgTAP Pass B without reset, `scripts/verify_database.sql`, plan sum, installed mutation proof, API-contract generator, scope, `git diff --check`, repository consistency and parity readiness. Record actual counts, exits and exact SHA-256 hashes. Treat only undeployed Primary/manifest/parity drift as expected at this boundary.
5. **Check** that exact owner authorization for the migration and permanent-test SHA-256 values is recorded in the Execution Log. If absent, stop after Step 4 and present current HEAD, both exact 64-character hashes, fresh full Primary baseline, predicted structural delta and exact Primary write. CR approval does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260925120000_payment_write_capability_parity`. If absent and separately authorized, immediately re-read HEAD, hashes, project identity, full ordered Primary ledger, absence and material data preconditions. On exact match apply only the authorized migration. Normalize only its newly inserted ledger row if the connector assigns a temporary version. Read fresh full ledger, function and all ten structural surfaces, changed function definition/security/EXECUTE and trigger timing/enabled state. Never contact Secondary.
7. **Check** that fresh Primary evidence contains the unique new migration. If so, update `reports/evidence/primary-ledger-evidence.json` and manifest only from measured Primary facts; update the Slice-20 disposition, gap register and coverage 21/77; regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` with canonical generators. Run ledger, parity-evidence, repository consistency and `git diff --check`. If Primary is unproven, stop.
8. **Check** for a `Post-deploy verification` Execution Log entry. If absent, run canonical `-Finish` and require `LOCAL_CERTIFY: READY`; independently Review the committed implementation and every acceptance item. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete and clear the manifest pointer. Publish the exact committed candidate, require exact-SHA candidate CI, promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs, and remove permitted scratch files. Do not start Slice 21.

## Acceptance Criteria

- [ ] An authenticated employee without `RECORD_PAYMENT` cannot change payment direction, customer, supplier, booking attribution, denomination, account, payment method, paid time or rate through direct UPDATE; a visible row and exact SQLSTATE prove each refusal.
- [ ] Authorized ordinary payment changes, both payment RPC INSERTs, metadata edits and session-less system paths retain their existing behavior; other tables' `app.guard_financial_capability` mappings are unchanged.
- [ ] PAY-2 is fixed by the measured guard; PAY-3 and PAY-4 remain separate OPEN findings; `payments` is `AUDITED-OPEN` / `ADVERSARIAL` and coverage is 21/77.
- [ ] Migration, test, generated artifacts, local and fresh Primary evidence agree, with no out-of-scope file changes.

## Execution Log

### 2026-09-25 — Owner approval

Owner approved the exact Draft SHA `be47b2f395e9cb2ed2bd4cc82c81ab39e7488cc0` and the frozen nine-path Write Scope. An isolated Draft-to-Approved Gate returned `APPROVAL_EVIDENCE: PASS`. Approval authorizes PAY-2 local implementation and proof, not Primary deployment; PAY-3 and PAY-4 stay OPEN and separate.

## Verification Notes

None yet.

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created or deleted.
- [ ] No section was added, removed or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

EARN IT: direction, counterparty and currency changes by an employee without `RECORD_PAYMENT` persisted and changed money reported by `app.customer_balance`; the existing guard checked only amount. WORTH IT: leaving this intact permits an unprivileged caller to reclassify money through the direct table door. Revoking authenticated UPDATE would also break the existing SECURITY INVOKER model; a new trigger duplicates the installed capability guard. A rolled-back replacement of that guard's payments list denied the employee with 42501, allowed the owner, and was restored to the original `pg_get_functiondef` hash. PAY-3 and PAY-4 have different causes and are intentionally separate. No shared authorization abstraction or new business rule is proposed.
