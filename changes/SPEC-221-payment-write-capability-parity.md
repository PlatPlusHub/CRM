# Change Request — SPEC-221

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
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

Resume Step: DONE
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

- [x] An authenticated employee without `RECORD_PAYMENT` cannot change payment direction, customer, supplier, booking attribution, denomination, account, payment method, paid time or rate through direct UPDATE; a visible row and exact SQLSTATE prove each refusal.
- [x] Authorized ordinary payment changes, both payment RPC INSERTs, metadata edits and session-less system paths retain their existing behavior; other tables' `app.guard_financial_capability` mappings are unchanged.
- [x] PAY-2 is fixed by the measured guard; PAY-3 and PAY-4 remain separate OPEN findings; `payments` is `AUDITED-OPEN` / `ADVERSARIAL` and coverage is 21/77.
- [x] Migration, test, generated artifacts, local and fresh Primary evidence agree, with no out-of-scope file changes.

## Execution Log

### 2026-09-25 — Owner approval

Owner approved the exact Draft SHA `be47b2f395e9cb2ed2bd4cc82c81ab39e7488cc0` and the frozen nine-path Write Scope. An isolated Draft-to-Approved Gate returned `APPROVAL_EVIDENCE: PASS`. Approval authorizes PAY-2 local implementation and proof, not Primary deployment; PAY-3 and PAY-4 stay OPEN and separate.

### 2026-09-25 — Execution started

The approved nine-path contract entered In Progress. Resume Step 1; only PAY-2 local implementation and proof are authorized. Primary deployment remains separately gated.

### 2026-09-25 — Pre-deploy readiness gate

Step 1: the migration was independently diffed against the current definition in `202607057100`; the only change is the `payments` UPDATE list, now exactly the eleven approved fields; signature, SECURITY INVOKER, `search_path`, other table lists, INSERT branch, session-less exemption, trigger and grants are unchanged. Step 2: the test file inherited from the prior session had never run and failed at its first fixture (`suppliers.supplier_type_code` NOT NULL). It was corrected before any proof was taken: supplier fixture; closed-vocabulary `ATTACK-CLASSES` (Check 24 had rejected the old line); every refusal pinned to the guard's own `permission denied: RECORD_PAYMENT`, since RLS WITH CHECK also raises 42501; same-value assignment of guarded fields proven not to acquire a requirement; the session-less path now changes a newly guarded field; and the in-file mutant now re-runs the direction, customer and currency attacks, each landing, with balance consequences read through `coalesce` because `app.customer_balance` omits a currency with no contribution. Final plan 33. Step 3: `payments` was NOT-RECORDED and PAY-2/3/4 absent; PAY-2 is registered fixed (local proof, deployment gated), PAY-3 and PAY-4 OPEN, `payments` AUDITED-OPEN / ADVERSARIAL, coverage 21/77.

Clean local reset applied 227 migrations (latest `20260925120000`). The focused permanent test passed 33/33; full pgTAP Pass A and Pass B (no reset) each passed 126 files / 2170 assertions, equal to the plan sum; the six declared HTTP suites passed 33 + 120 + 40 + 74 + 122 + 60 = 449/449, all exit 0; `verify_database.sql` reported ALL CHECKS PASSED (77 tables). Installed mutation: in-file, the amount-only mutant was positively inspected, the employee's direction, customer and currency rewrites persisted and removed 101 and 100 EGP from two customers' paid balances, and `pg_get_functiondef` md5 was restored exactly. Externally, the pre-SPEC-221 definition was installed verbatim from `202607057100` in a rolled-back transaction: assertions 4–13 all failed (nine attacks landed with no exception; the currency attack was refused by FA-2 only because the landed account attack preceded it), assertion 14 (amount) still passed, and the function md5 `cff9f92e56f66edf33580d2d2282cedb` was unchanged after rollback. The API-contract generator reported 79 RPC endpoints (all with HTTP evidence), 8 reporting views and 73 tables with no file change; `git diff --check` passed including both new files. Frozen predeploy SHA-256: migration `1f01a2b79eb483d682104b9e38598f8f4135a42eefeefa05fc0b143102b489eb`; test 126 `eb99c86e94066e60baafc5730604334958404996860d2f9e8c8ac166d2f9a6fd`.

Fresh read-only Primary baseline (`vrvtsxexkiiiivlkdxzp`): 226 migrations through `20260924170000`, ledger `7c416f13f007cc244fc35ab98a8c105a`, target absent, 306 functions/hash `09995ce64a9d2f75896530b3074f0eef`, 3046 structural objects/hash `b7cc89445aadb90e957bfdceb2216a7f`, zero payment rows, the same nine enabled payment triggers, installed guard lacking the new fields (md5 `657a36fcf093f30bac42ca912889e3eb`). The clean local target is 227 migrations/ledger `b224fabad850e86d7f48a3fb52761b0b`, 306 functions/hash `ebf18ada4617978752b56360676821e8`, 3046 structural objects/hash `4874556d8512c0ee21bb913fecdf9b01`; the other nine structural categories are identical to Primary, so the predicted delta is one migration and one replaced function body, with no object added. Repository consistency found exactly six expected undeployed-state issues (three manifest migration fields, two manifest suite figures that Step 7 rewrites in the same live-state line, and Primary ledger evidence); Primary ledger and parity evidence failed only on the absent migration. Primary received no write; Secondary was not contacted. Step 5 is the next boundary; CR approval does not authorize Step 6.

### 2026-09-25 — Authorized Primary deployment and reconciliation

The owner authorized Primary `vrvtsxexkiiiivlkdxzp` for HEAD `5b3a8945016fd78c101bf49976d1e9349271f97c`, migration SHA-256 `1f01a2b79eb483d682104b9e38598f8f4135a42eefeefa05fc0b143102b489eb` and test-126 SHA-256 `eb99c86e94066e60baafc5730604334958404996860d2f9e8c8ac166d2f9a6fd`, and accepted the Test-126 corrections as part of those frozen bytes. Immediately before writing, HEAD and both hashes matched exactly; the connector URL named `vrvtsxexkiiiivlkdxzp`; Primary held 226 migrations through `20260924170000`, ledger `7c416f13f007cc244fc35ab98a8c105a` (equal to the repository's first 226 migrations), no target migration, zero payment rows, nine enabled payment triggers, and a live guard whose payments mapping was amount-only. Applied only `20260925120000_payment_write_capability_parity.sql` through the Primary connector. The connector assigned temporary version `20260925204057`; a guarded uniqueness check (source 1, collision 0) normalized only that new row to `20260925120000`. No business-data write; Secondary was not contacted.

Fresh postwrite Primary full ordered ledger is 227 migrations through `20260925120000`, fingerprint `b224fabad850e86d7f48a3fb52761b0b`, with the target present exactly once and zero payment rows. Its full function hash is `ebf18ada4617978752b56360676821e8` (306), and all ten structural categories match local, combined hash `4874556d8512c0ee21bb913fecdf9b01` (3046); triggers, policies, constraints, grants, columns, views, indexes, status transitions and RLS flags are unchanged from the prewrite reading. The installed `app.guard_financial_capability()` `pg_get_functiondef` md5 `cff9f92e56f66edf33580d2d2282cedb` equals the locally proven definition, whose only difference from `202607057100` is the payments UPDATE list; it remains SECURITY INVOKER with empty `search_path`, EXECUTE held only by `postgres` (no `authenticated`), six enabled guard triggers, and the nine enabled payment triggers are unchanged. Primary evidence and manifest were reconciled from these readings; `payments` disposition, PAY-2 deployed status and coverage 21/77 recorded; map and API contract regenerated (79 endpoints, contract unchanged). `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, `check_repository_consistency.ps1` and `git diff --check` all exited 0 (CLEAN). PAY-3 and PAY-4 remain OPEN. Runtime Checkpoint names DONE so canonical `-Finish` can run in VERIFY mode; Status remains In Progress pending Review and the Complete transition.

### 2026-09-25 — Post-deploy local certification

The canonical `-Finish` ran on the final scoped bytes in VERIFY mode. Clean reset, full pgTAP Pass A, all six declared HTTP suites, full pgTAP Pass B, database smoke, Primary parity evidence, repository consistency, `git diff --check` and Primary ledger evidence all passed; it exited 0 and issued `LOCAL_CERTIFY: READY`. It validated the recorded Primary evidence and did not contact Primary. The focused 33/33 and the in-file and external installed/restored mutation proofs remain applicable because the migration and permanent-test bytes did not change.

### 2026-09-25 — Independent Review of execution commit

Reviewed committed execution HEAD `2661bf6` against the approved nine-path Write Scope; the working tree was clean and the pre-commit Gate reported `ORVION: READY`. The range from the approved Draft `be47b2f` changes eight paths, all in scope (`MASTER_API_CONTRACT.md` regenerated unchanged), and touches none of the Out-of-Scope files. Objective, Write Scope, Out of Scope, Implementation Steps and Acceptance Criteria are byte-identical to the approved Draft apart from checkbox state. Committed migration and test bytes hash to the authorized `1f01a2b79eb483d682104b9e38598f8f4135a42eefeefa05fc0b143102b489eb` and `eb99c86e94066e60baafc5730604334958404996860d2f9e8c8ac166d2f9a6fd`. The migration's sole difference from `202607057100` is the payments UPDATE list; no trigger, grant, policy or permission was added and tests 56/68 still pass. A live Primary re-read after the commit shows 227 migrations / `b224fabad850e86d7f48a3fb52761b0b`, guard md5 `cff9f92e56f66edf33580d2d2282cedb`, nine enabled payment triggers and 306 functions / `ebf18ada4617978752b56360676821e8`, matching the recorded evidence. Acceptance: test 126 assertions 2 and 4–13 prove ten visible-row refusals by the guard's own 42501 message; 16–22 prove metadata, same-value, authorized and session-less paths; both payment RPC INSERTs pass in tests 53/87 and `verify_journey_branches.ps1`; PAY-2 is recorded fixed and deployed, PAY-3 and PAY-4 OPEN, `payments` AUDITED-OPEN / ADVERSARIAL at 21/77. No unapproved business-data write occurred and Secondary was never contacted. Every Acceptance Criterion and Review Gate item is confirmed.

Verdict: Confirmed Complete

## Verification Notes

None yet.

Verdict: Confirmed Complete

## Review Gate

- [x] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [x] No file outside Write Scope was modified, created or deleted.
- [x] No section was added, removed or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] Any step that could not be resolved deterministically was reported, not guessed.
- [x] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [x] The repository is in a clean, releasable state.

## Notes

EARN IT: direction, counterparty and currency changes by an employee without `RECORD_PAYMENT` persisted and changed money reported by `app.customer_balance`; the existing guard checked only amount. WORTH IT: leaving this intact permits an unprivileged caller to reclassify money through the direct table door. Revoking authenticated UPDATE would also break the existing SECURITY INVOKER model; a new trigger duplicates the installed capability guard. A rolled-back replacement of that guard's payments list denied the employee with 42501, allowed the owner, and was restored to the original `pg_get_functiondef` hash. PAY-3 and PAY-4 have different causes and are intentionally separate. No shared authorization abstraction or new business rule is proposed.
