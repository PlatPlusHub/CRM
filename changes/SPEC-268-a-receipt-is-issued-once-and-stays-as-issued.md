# Change Request — SPEC-268

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Batch 6 Slice 41 makes a receipt issuable only for a customer payment, numbered and timed by the server on every door, born unsubmitted with exactly one `receipt_issued` event, and fixed once issued except for its tax-submission record, which needs CREATE_RECEIPT (RCPT-1, RCPT-2, RCPT-3, RCPT-4).

## Business Reason

- **Selection.** `scripts/batch6_select_target.ps1` at `f6c30d0` ranks `receipts` first: Exposure 7, coverage 20, NOT-RECORDED (runner-up `chart_of_accounts` 7/38). It is the target the manifest names.
- **The rule.** A receipt is proof that money was received (canon 24: it links a customer payment). It carries the number the tenant's receipt sequence gave it and the moment it was issued; canon 25 tracks its external tax submission; canon 27 records `receipt_issued`; canon 30 forbids overwriting a financial action silently. `app.issue_receipt` wrote all of that correctly by construction. `authenticated` holds INSERT and UPDATE on the table, and the table door guaranteed none of it.
- **Measured at `f6c30d0`** on a clean local reset (251 migrations), in rolled-back transactions:
  - **RCPT-1 (High).** An `employee` holding neither CREATE_RECEIPT nor VIEW_FINANCIAL_DOCUMENTS sees a receipt because its payment is on a booking they own (`scope_isolation`). That employee renumbered an issued receipt to `FAKE-0001`, backdated it two years, wrote `external_submission_id = 'forged'`, and moved it from its 600 payment onto a 900 payment of the same booking. Every UPDATE landed, and none left an event. The `receipt_issued` event still named the 600 payment. `app.guard_financial_capability` compares only `external_submission_status_code` on a receipt UPDATE (FIN-6b), and nothing else guards the row.
  - **RCPT-2 (Medium).** `app.issue_receipt` issued a receipt for an outbound `supplier_payment`. Nothing reads the payment's direction.
  - **RCPT-3 (Medium).** An owner holding CREATE_RECEIPT inserted a receipt at the table door numbered `RCP-2026-X1`, issued 400 days ago, with an external submission id. No `receipt_issued` event was written: the number, the date and the evidence were all the caller's.
  - **RCPT-4 (Medium).** After that one row, `app.issue_receipt` failed for the whole tenant for the rest of the year with `invalid input syntax for type integer: "X1"`. It parses every `RCP-<year>-%` number it finds with `split_part(...)::integer`, so one malformed door number stops every receipt.
- **Swept and found sound, pinned rather than changed:**
  - one receipt per payment (`receipts_tenant_payment_key`) and one number per tenant (`receipts_tenant_number_key`);
  - tenant-qualified foreign keys to the payment, the tenant and the creator;
  - no DELETE grant to `authenticated`;
  - CREATE_RECEIPT on INSERT (FIN-3) and on `external_submission_status_code` (FIN-6b);
  - `created_by` derived on every signed-in door.
- **Not changed, recorded:** canon 29 says a payment "may have one or more Receipts depending on split documentation". The schema's one-receipt-per-payment key is narrower. Widening it is a product decision with its own numbering consequences, and no consumer needs it before a client application exists. It is recorded in the disposition row, not built.
- **Latent:** Primary holds 0 tenants and 0 receipts, so no existing row is affected and no data repair is needed.

## Risks

- **A door insert's supplied number and time are discarded, not refused.** This follows PAY-6's precedent for a derived converted amount. A caller who names a number gets the sequence's number, not an error. Test 156 assertion 3 pins it.
- **A receipt is born with null tax-submission fields.** No function, script or test writes them at INSERT (searched). Submission is an UPDATE by CREATE_RECEIPT, or by the platform path.
- **`app.issue_receipt` is replaced.** Its signature, SECURITY INVOKER mode, empty `search_path`, ACL, checks and refusal messages stay. It no longer allocates the number or writes the event, because the row's own triggers do both for every door; that is what makes the RPC and the door unable to disagree. The three HTTP suites, including `verify_api_end_to_end.ps1`'s `issue_receipt` call, pass on the prototype.
- **A CLI-version trap, measured in this Draft's prototype.** A run from a directory without `node_modules` let `npx` fetch Supabase CLI 2.120. That reset grants `service_role` DELETE on public tables, and test 155 assertion 68 then fails. The same suite with the repository's pinned CLI 2.109 passes. Every command here runs from the main checkout, as `-Finish` does.
- **Primary deployment is a separate exact-byte authorization.** Approval of this contract does not authorize it.

## Supersedes / Depends On

None. It is independent of the Draft SPEC-265, which edits documents only. Whichever contract executes second applies its register, disposition and manifest edits to the text the first one left; the migration and the test do not depend on the order.

## Write Scope

- `changes/SPEC-268-a-receipt-is-issued-once-and-stays-as-issued.md`
- `supabase/migrations/20261012120000_a_receipt_is_issued_once_and_stays_as_issued.sql`
- `supabase/tests/156_a_receipt_is_issued_once_and_stays_as_issued_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607042500_create_finance_transaction_tables.sql`
- `supabase/migrations/202607047200_issue_receipt.sql`
- `supabase/migrations/20260925120000_payment_write_capability_parity.sql`
- `supabase/migrations/20261011120000_an_allocation_spends_its_own_payment_on_its_own_invoice.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/53_api_surface_test.sql`
- `supabase/tests/68_financial_status_capability_test.sql`
- `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql`
- `scripts/verify_database.sql`
- `scripts/verify_api_end_to_end.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`
- `_ORVION_CANONICAL/24_entity_registry.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/29_relationship_map.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/24_entity_registry.md` (Receipt); `_ORVION_CANONICAL/27_event_catalog.md` (`receipt_issued`); `_ORVION_CANONICAL/29_relationship_map.md` (Receipt To Payment); `_ORVION_CANONICAL/30_database_conventions.md` (Financial Record Standard)
- `reports/master/MASTER_GAP_REGISTER.md` (FIN-3, FIN-6b, PAY-6, PAY-10); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md`, Batch 6 method and EC-1…EC-11
- `supabase/migrations/202607047200_issue_receipt.sql`; `supabase/migrations/20261011120000_an_allocation_spends_its_own_payment_on_its_own_invoice.sql` (the precedent for a fixed-once-written guard and a single event producer)
- Current local `app.issue_receipt`, `app.guard_financial_capability`, `app.derive_created_by`, `app.record_event`

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
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| A receipt is issued only for a customer payment, its number and issue time are derived on every door, and it is born unsubmitted | `app.issue_receipt`; `receipts_guard_financial_capability`; `receipts_derive_created_by`; the two unique keys | WRITE | The prototype migration was applied to a clean reset of the `f6c30d0` local stack (251 migrations), from files held outside the repository. SHA-256 `090936946f72bbe1a22b60c362685ee61bb8304ac9680c309da259cc52b27bfc`, md5 `9a352fdd0d3caec23e1e1c36a43200ff`, 9882 bytes, LF, ASCII. A door insert naming `RCP-<year>-X1`, a date 400 days back and a submission id stored the sequence's number, the server's time and null submission fields. A supplier payment was refused 23514 on the RPC, the door and the platform path. No function, script or test reads a door-supplied number or time (searched). |
| An issued receipt's payment, number, issue time and origin are fixed; its tax-submission id and times need CREATE_RECEIPT | `scope_isolation` RLS; `app.guard_financial_capability` (FIN-6b, unchanged); the platform path | WRITE | Before: the employee's renumber, backdate, forged submission id and move to another payment all landed. Prototype: renumber, move, backdate and creation-time rewrite are refused 23514 for the employee, the owner and a session-less caller; the employee's submission id and response time are refused 42501 `permission denied: CREATE_RECEIPT`; the owner records a submission; the platform records a response time without a session (canon 35 principle 6). |
| One producer of `receipt_issued`, on every door | `public.events` (`events_append_only`); `app.record_event`; `audit_read` | WRITE | Before: a door receipt wrote no event; the RPC's event kept naming a payment the receipt had been moved off. Prototype: each receipt, from the RPC or the door, is born with exactly one event carrying its number, payment, customer, currency and amount; a refused write leaves none. `receipt_issued` is already registered (catalog unchanged, 71/623). |
| The sequence reads only numbers of its own shape, under the key `app.issue_receipt` has always taken | `app.issue_receipt`; the unique key on (tenant, number) | WRITE | Before (RCPT-4): one `RCP-<year>-X1` row stopped the RPC for the year. Prototype: with a malformed row written past the guard, as legacy data could be, the RPC issues `RCP-<year>-0003` after `-0002`. A door insert holds the advisory lock, read from `pg_locks` before any RPC runs. |
| `app.issue_receipt` replaced | `verify_api_end_to_end.ps1`; test 53; the API contract | WRITE | Signature, security mode, `search_path` and ACL unchanged; its tenant, payment, duplicate and CREATE_RECEIPT refusals unchanged. On the prototype the three HTTP suites pass: 35/0, 85/0, 122/0. `MASTER_API_CONTRACT.md` is regenerated in Step 7 and, with an unchanged signature, is predicted unchanged. |
| Test 156 | `supabase/tests` | WRITE | SHA-256 `26aeb66438f6c52c9e572cc190c3096da883c27ab1d08db8648faae06885e9c2`, md5 `50e7678414f7467cab2d678b2f3a88df`, `plan(33)`, 18773 bytes, LF, ASCII: 33/33 on the prototype. |
| Other tests reading this table or its functions | tests 10, 53, 68 and the full suite | VERIFY | Unchanged. Full pgTAP on the prototype with the pinned CLI 2.109: 156 files, 2969 assertions (2936 + 33), 0 failed. |
| Smoke | `scripts/verify_database.sql` | VERIFY | On the prototype: `ALL CHECKS PASSED (78 tables, … 71/623 catalog, …)`. No table, catalog value, policy, append-only or transition trigger is added, so no pin moves. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | Predicted: functions +2 (`app.guard_receipt_issue`, `app.emit_receipt_issued`; `app.issue_receipt` replaced in place), triggers +2 (`receipts_guard_issue`, `receipts_emit_issued`), constraints, policies, grants, columns, views, indexes, status transitions and RLS unchanged. Step 4 measures the exact fingerprints locally, and Step 7 writes Primary values only from fresh post-deploy readings. |
| Measured state that moves | manifest (`Live state`, suite figure, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 251 → 252 migrations, latest `20261012120000`; 155 → 156 files and 2936 → 2969 assertions; coverage 41 → 42 of 78. Catalog (71/623), HTTP (464), tables (78), views (8) and client RPCs (80) do not move. |
| RCPT-1, RCPT-2, RCPT-3 and RCPT-4 fixed; the surface recorded | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25 | WRITE | The `RCPT-` prefix is unused at `f6c30d0`. Test 156's `-- ATTACK-CLASSES:` line declares all ten classes, each earned by named assertions, and carries negative assertions, so Check 24 admits `ADVERSARIAL`. Every new row's Owner field is `—`, so Check 25 reads no owner decision. With every finding fixed and nothing left open, the row is `AUDITED`: coverage 42 recorded, 18 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 36 `NOT-RECORDED`. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | Predicted from SPEC-264's identical shape: before deployment, consistency reports exactly the measured-state drift (251 vs 252 migrations, latest, ledger fingerprint, 155 vs 156 files, 2936 vs 2969 assertions), and the primary-ledger and cold-start self-tests fail only their CONTROL and restore cases because of it. These are not waived: Step 7 makes them true and Step 8 requires them green. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused test, pgTAP A/B, the declared HTTP suites, smoke and the mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| RCPT-1 to RCPT-4 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.guard_financial_capability` charges CREATE_RECEIPT on INSERT and on a change of `external_submission_status_code`, and nothing else. `app.derive_created_by` fixes `created_by` for signed-in callers only. The unique keys bound one receipt per payment and one number per tenant. Nothing reads the payment's direction, derives the number or time on the door, fixes an issued receipt, or records a door receipt. Only `app.issue_receipt` wrote a coherent receipt, by construction. This contract reuses the RPC's own sequence key and number shape, PAY-6's fixed-once-written idiom and 23514, PAY-10's single-producer event idiom through `app.record_event`, the existing capability, foreign keys, RLS and unique keys. No shared document-numbering framework is earned.

Added Property: A receipt is issued only for a customer payment. Its number (the tenant's per-year sequence, under its lock, reading only numbers of its own shape) and its issue time are derived on every door, and it is born unsubmitted. Once issued, its payment, number, issue time and origin never change for any caller. Its tax-submission id and times change only with CREATE_RECEIPT, or on the platform path. Every receipt is born with exactly one `receipt_issued` event with its facts.

Causal Negative: These are the pre-repair measurements in Business Reason, at `f6c30d0`:
- the employee's renumber, two-year backdate, forged submission id and move to a 900 payment, with the event left naming the 600 payment;
- a receipt issued for a supplier payment;
- a door receipt with a caller's number and date and no event;
- the RPC stopped for the year by one malformed number.

On the unrepaired schema, test 156 fails assertions 3, 4, 5, 6 and 7, then aborts at its reference to `receipts_guard_issue`, which is absent. Assertion 6 fails because the door row of assertion 2 has already stopped the RPC: RCPT-4 itself.

Positive Test Design: One tenant has an owner and an employee who owns booking B1 of customer C1, with customer payments f1 (600), f2 (900) and f5 (300) on B1, f4 (100) and f6 (50) on no booking, a supplier payment f3 (500), and a rival tenant with its own customer payment. Positive controls:
- the owner's door receipt is stored with the sequence's number, the server's time and no submission;
- the RPC issues for f1 after the door receipt, and for f2 after a malformed legacy row;
- the owner records a tax submission, and the platform records a response time;
- the employee sees exactly the two receipts on their booking, and f1's receipt is exactly as issued after every refused attempt.

Negative Test Design:
- **Fixed once issued:** renumber (owner, employee, platform), move to another payment, backdate and creation-time rewrite are refused 23514.
- **Submission record:** the employee's submission id and response time are refused 42501.
- **Capability (held):** the employee's door insert is refused 42501.
- **Customer payment only:** a supplier payment is refused 23514 on the RPC, the door and the platform path.
- **Replay:** a second receipt for f1 is refused by the RPC (P0001) and by the unique key at the door (23505).
- **Tenant:** a receipt in the rival tenant is refused 42501.
- **Privilege:** neither SECURITY DEFINER function is executable by `authenticated` or `anon`.
- **Evidence:** a refused write records nothing; four receipts written, four events.

Non-Empty Population Obligation: The tenant has two users with their roles, one customer, one booking and six payments; the rival tenant has its own payment. Every receipt, refusal, lock and event is counted by id, payment or exact message; no zero-row operation satisfies an assertion. Assertion 19 proves the employee sees exactly two receipts before any UPDATE, and assertion 33 proves exactly four events.

Mutation Obligation: Each mutant replaces one function (or drops or grants one trigger or function) on the prototype stack. The run then executes test 156, records the failing assertions, and restores the original definition, proving 33/33 again before the next mutant. A mutant that is not proven installed is a harness error, never a kill.

| Mutant | Change | Failed on the prototype |
| --- | --- | --- |
| M1 | `receipt_number` left out of the fixed set | 15, 20, 27, 28 |
| M2 | `payment_id` left out | 21–25, 27 |
| M3 | `issued_at` left out | 22 |
| M4 | `created_at` left out | 23 |
| M5 | the direction check removed | 11, 12, 29, 33 |
| M6 | a supplied number kept | 3, 5–10, 13, 14, 19, 27, 33 |
| M7 | a supplied issue time kept | 3, 4, 5, 7, 9, 27 |
| M8 | a supplied submission id kept | 3 |
| M9 | the sequence lock removed | 4 |
| M10 | the sequence parses every number (`split_part(...)::integer`) | 8, 9, 14, 19, 33 |
| M11 | the submission record uncharged | 24, 25, 27 |
| M12 | the platform charged for the submission record | 30 |
| M13 | the RPC also writes `receipt_issued` | 10, 33 |
| M14 | the event trigger dropped | 5, 10, 33 |
| M15 | the guard granted to `authenticated` | 32 |

Prototype result: all fifteen were killed, as listed, and the restored stack passed 33/33 after the last one. One test defect was found and fixed before this result: assertion 33 first expected three events, but the legacy row of assertion 8 is written with only the guard disabled, so it is born with its event too. Four is correct.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`, from the main checkout with the pinned CLI:
- the focused test, a clean reset, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke;
- mutants M1–M15 and the pre-repair causal negative;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261012120000_a_receipt_is_issued_once_and_stays_as_issued.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `090936946f72bbe1a22b60c362685ee61bb8304ac9680c309da259cc52b27bfc`, md5 `9a352fdd0d3caec23e1e1c36a43200ff`, 9882 bytes.
   - Its statements, after a comment block stating the rule and the measurements:
     - create `app.guard_receipt_issue()` (SECURITY DEFINER, empty `search_path`, PUBLIC revoked) with its BEFORE INSERT OR UPDATE trigger `receipts_guard_issue`;
     - create `app.emit_receipt_issued()` (SECURITY DEFINER, empty `search_path`, PUBLIC revoked) with its AFTER INSERT trigger `receipts_emit_issued`;
     - replace `app.issue_receipt(uuid)` with the same signature, security mode and checks, inserting only the tenant and the payment.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/156_a_receipt_is_issued_once_and_stays_as_issued_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `26aeb66438f6c52c9e572cc190c3096da883c27ab1d08db8648faae06885e9c2`, `select plan(33);`.
   - Its `-- ATTACK-CLASSES:` line reads `AUTH TENANT DOOR STATE INPUT BUSINESS PRIVILEGE CONCURRENCY REPLAY OBSERVABILITY`.
   - If the target exists with different bytes, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains an `RCPT-1` row. If not, make these edits and nothing else:
   - **Register:**
     - a 2026-10-12 Slice-41 freshness entry, with the previous one demoted to `Previously:`;
     - new rows RCPT-1 (High), RCPT-2 (Medium), RCPT-3 (Medium) and RCPT-4 (Medium), each FIXED by SPEC-268 locally, with Primary pending and Cert `🛡`, and with the measurements above;
     - every new row with Owner `—` and this contract as session.
   - **Disposition:**
     - a freshness entry, with the previous one demoted;
     - coverage 42 of 78 (18 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 36 `NOT-RECORDED`) and the "All 42" line;
     - the `receipts` row `AUDITED` / `ADVERSARIAL` / SPEC-268 / RCPT-1, RCPT-2, RCPT-3, RCPT-4, with its evidence, its swept non-defects and canon 29's split-receipt note.

   If a target carries content other than its `f6c30d0` bytes, or `f6c30d0` plus SPEC-265's completed edits, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values, all from the main checkout with the repository's pinned CLI:
   - a clean local reset; test 156 and the focused tests 10, 53, 68 and 155;
   - pgTAP Pass A, the three declared HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - mutants M1–M15 and the causal negative, with each restoration proven;
   - the local structural fingerprints of `scripts/parity_surface.sql`, before and after the migration;
   - the API-contract and map generators;
   - the four CI-only guard self-tests;
   - the scope check, `git diff --check` and repository consistency.

   Treat as expected at this boundary only:
   - an undeployed Primary;
   - the pre-deploy repository-consistency drift listed in Consumer Closure;
   - the guard self-test CONTROL failures that drift causes.

   Read a fresh Primary baseline, read-only:
   - the project URL, the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - the triggers of `receipts`;
   - `app.issue_receipt`'s text md5, security mode and ACL;
   - the tenant, payment, receipt and event counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261012120000_a_receipt_is_issued_once_and_stays_as_issued`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, the triggers of `receipts` and `app.issue_receipt`'s md5.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; the triggers of `receipts`; the three functions' definitions, security modes and ACLs; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the catalog figure `71/623` and 464 HTTP assertions unchanged.
   - Confirm that `supabase/tests` holds 156 files whose literal `plan(N)` values sum to 2969, then set `Suite **156 files / 2969 assertions**`. If either differs, stop.
   - Set Batch 6 coverage to 42 of 78, all forty-two at `ADVERSARIAL`.
   - Mark RCPT-1 to RCPT-4 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators.
   - Run the four `scripts/test_*_guard.ps1` and require each to pass.
   - Set the Runtime Checkpoint to DONE.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, do all of the following in the Complete commit:
     - transition to Complete, tick the Acceptance Criteria and the Review Gate, and clear `Active Change Request`;
     - run `scripts/batch6_select_target.ps1` and record its Top-12;
     - set `Last Completed` to SPEC-268 / Slice 41;
     - set `Current Module` to Foundation Completion Programme Batch 6 resuming at Slice 42;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 42**, naming the measured first target, followed by the existing Phase-8 order, closed-chapter and standing-fact sentences unchanged;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [x] A receipt for a payment that is not a customer payment is refused (23514) on the RPC, the table door and the platform path.
- [x] A receipt's number is the tenant's per-year sequence and its issue time is the server's, on every door; a supplied number, time or tax-submission field is discarded at INSERT; one malformed stored number neither stops nor bends the sequence; a door insert holds the sequence's advisory lock.
- [x] Once issued, a receipt's payment, number, issue time, creator and creation time cannot be changed by any caller (23514); its tax-submission id and times change only with CREATE_RECEIPT (42501 otherwise) or on the platform path; CREATE_RECEIPT on INSERT and on the submission status is unchanged.
- [x] Every receipt is born with exactly one `receipt_issued` event carrying its number, payment, customer, currency and amount, on the RPC and the door alike; a refused write records nothing.
- [x] `app.issue_receipt` keeps its signature, SECURITY INVOKER mode, empty `search_path`, ACL and refusals, and inserts only the tenant and the payment.
- [x] Mutants M1–M15 are each killed against test 156, with installation and restoration proven, and the causal negative is recorded.
- [x] RCPT-1, RCPT-2, RCPT-3 and RCPT-4 are fixed and deployed in the register; no other row changed.
- [x] `receipts` is `AUDITED` / `ADVERSARIAL` in the disposition record, and coverage is 42 of 78. No other surface's row changed.
- [x] The migration and test 156 matched their frozen SHA-256 values when applied.
- [x] Primary, the recorded evidence, the manifest (252 migrations; 71/623 catalog; 156 files / 2969 assertions; 464 HTTP assertions), the API contract and `ai-map.json` agree. The four CI-only guard self-tests and repository consistency pass.
- [x] The manifest names Batch 6 Slice 42 and its measured target as the next capability, with no Active Change Request.
- [x] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-12 — Gate 1 approval and execution started

- **Authority:** the owner's execution authorization of 2026-10-12 approves Gate 1 for this receipts contract, which it names SPEC-266, the number it was drafted under. The renumbering is recorded in Notes and is mechanical: the allocator refused SPEC-266 as `SPEC_ID_ALREADY_USED`, and the owner's authorization covers numbering reconciliation that preserves the approved substance. Draft `fb81eb0`, contract SHA-256 `22ae36c585b51a6a848a89cc430a12d175ba2e0bba9e393fb81926a40ea2afe9` (32384 bytes, LF). Approval was committed at `c4a822c`; its pre-commit Gate returned `APPROVAL_EVIDENCE: PASS`.
- **Verified before acting:**
  - HEAD was the Approve commit, on top of SPEC-265's Complete commit `2049f2e`. It is 8 ahead of and 0 behind `origin/main` `f6c30d0`, with 0 merges, and `2049f2e` is the published candidate awaiting its CI;
  - the committed Draft blob hashes to the approved value;
  - the frozen prototype migration in the owner's `ORVION-drafts-backup\2026-10-12` is `090936946f72bbe1a22b60c362685ee61bb8304ac9680c309da259cc52b27bfc`, md5 `9a352fdd0d3caec23e1e1c36a43200ff`, 9882 bytes, 0 CR, ASCII;
  - test 156, re-derived by changing only its first-line contract number, is `26aeb66438f6c52c9e572cc190c3096da883c27ab1d08db8648faae06885e9c2`, md5 `50e7678414f7467cab2d678b2f3a88df`, 18773 bytes, LF, ASCII.
- **Preconditions:** the migration and test 156 are absent from the tree.
- **Gate 2 stands before Step 6.** The same authorization grants a separate, exact-byte Gate 2 for migration `20261012120000_a_receipt_is_issued_once_and_stays_as_issued.sql`, SHA-256 `090936946f72bbe1a22b60c362685ee61bb8304ac9680c309da259cc52b27bfc`, md5 `9a352fdd0d3caec23e1e1c36a43200ff`, to Primary `vrvtsxexkiiiivlkdxzp` only. It is valid only if every pre-deployment condition passes: exact content, HEAD and scope, project identity, the expected ledger with the migration absent, the function and structural fingerprints, the business counts and receipt objects, the mandatory local and adversarial tests, no unexpected drift, and the readiness gate. It is recorded at Step 5 only if Step 4 passes. It covers no other migration. Secondary is never contacted.

### 2026-10-12 — Steps 1-3 applied; Pre-deploy readiness gate (Step 4)

- **Steps 1–2.** The migration and test 156 were absent and were created LF, ASCII, byte-identical to their pinned values: migration `090936946f72bbe1a22b60c362685ee61bb8304ac9680c309da259cc52b27bfc` (md5 `9a352fdd0d3caec23e1e1c36a43200ff`, 9882 bytes), test 156 `26aeb66438f6c52c9e572cc190c3096da883c27ab1d08db8648faae06885e9c2`.
- **Step 3.** The register held SPEC-265's completed edits, the case Step 3 admits.
  - Register: a Slice-41 freshness entry, with the D4 entry demoted to `Previously:`, and rows RCPT-1 (High) and RCPT-2, RCPT-3 and RCPT-4 (Medium), each leading `FIXED … locally; Primary deployment pending` with Cert `🛡` and Owner `—`.
  - Disposition: the freshness entry; coverage 42 of 78 (18 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 36 `NOT-RECORDED`); the "All 42" line; the `receipts` row `AUDITED` / `ADVERSARIAL`.
- **Step 4**, from the main checkout with the pinned CLI 2.109, HEAD `dff42ea`, under `scripts/run_timed.ps1` with `concurrent=0`:
  - **Causal negative.** A clean reset with the migration held aside gave 251 migrations, latest `20261011120000`. Test 156 failed assertions 3, 4, 5, 6 and 7, then aborted on `trigger "receipts_guard_issue" … does not exist`, as predicted.
  - **Fingerprints, unrepaired local:** `app.issue_receipt` md5 `fdb063de930b6fb43662df89d070ae8c`, SECURITY INVOKER, ACL `{postgres=X/postgres,authenticated=X/postgres}`; four `receipts` triggers; functions `708dbe893149ea2b97e6893fea449925`/329; structural `_combined` `76c930988563bd06f86c65e429fdb8fc`/3130.
  - **Fingerprints, after a clean reset with the migration:** 252 migrations, latest `20261012120000`; `app.issue_receipt` md5 `b2e09f264b27a0f5643353c2fe78c5fb`, with the same mode and ACL; triggers `receipts_emit_issued` and `receipts_guard_issue` added. The structural surface moves exactly as predicted: functions `e6a65849bc390360dcb53b2be4f1a0b8`/331 (+2), triggers `d0b98a16e51bb805a93e14737cd5e1b3`/318 (+2), and `_combined` `02dcc5a1076506289a6f7ff81894fb4d`/3134. Policies, constraints, grants, columns, views, indexes, status transitions and RLS are unchanged.
  - **Focused tests:** test 156 33/33, test 10 9/9, test 53 12/12, test 68 11/11, test 155 68/68.
  - **Full suite:** pgTAP Pass A `Files=156, Tests=2969`, PASS. HTTP: `verify_api_end_to_end` 35/0, `verify_journey_branches` 85/0, `verify_lifecycle_branches` 122/0. pgTAP Pass B without reset: 2969, PASS. Smoke: `ALL CHECKS PASSED (78 tables, … 71/623 catalog, …)`. 156 files whose literal `plan(N)` values sum to 2969.
  - **Mutants M1–M15, all killed.** Each failing set equals the Mutation Obligation table: M1 15,20,27,28; M2 21–25,27; M3 22; M4 23; M5 11,12,29,33; M6 3,5–10,13,14,19,27,33; M7 3,4,5,7,9,27; M8 3; M9 4; M10 8,9,14,19,33; M11 24,25,27; M12 30; M13 10,33; M14 5,10,33; M15 32.
    - **Harness strengthened.** For every mutant, the harness now proves installation from a changed function-source, trigger or privilege fingerprint. It proves restoration as byte-equal to the migration's definitions and 33/33 before the next mutant.
    - **First run stopped as a harness error, not a verdict.** M1's restore was not byte-equal: on Windows, a text-mode pipe turned the migration's LF into CRLF inside the restored function body. The prototype harness had the same flaw and did not check for it. The SQL is now sent as bytes, and the rerun on a fresh reset gave the result above and `ALL RESTORED`.
  - **Generators.** `MASTER_API_CONTRACT.md` regenerates byte-identical to the committed file (80 RPC endpoints, 8 reporting views, 74 tables), so it is unchanged, as predicted. `ai-map.json` changes only its timestamp.
  - **Guard self-tests:**
    - `test_future_date_guard` 18/0 and `test_status_contradiction_guard` 33/0;
    - `test_cold_start_state_guard` 25/9 and `test_primary_ledger_guard` 11/2. Every failure is a CONTROL or restore case that requires a CLEAN guard: cold-start CONTROL, A2, A-restore, B-restore, C2, C-restore, D-restore, E-CONTROL and the second-direction CONTROL; primary-ledger's two CONTROL cases. Every MUTATION case passes. This is the drift Consumer Closure predicts, and Step 8 requires them green.
  - **Scope and consistency.** `git status` shows only Write Scope paths, and `git diff --check` is clean. Repository consistency reports exactly the six predicted items:
    - manifest 251 vs 252 migrations;
    - the latest migration;
    - the ledger fingerprint (files `5f13c62d2f609e7794a0193a2f203c50`);
    - 155 vs 156 test files;
    - 2936 vs 2969 assertions;
    - RECOVER-1 counting two of them.
  - **Fresh Primary baseline**, read-only through `supabase-primary`:
    - project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`;
    - ledger 251 rows, `f678a3ef5790582c39635136c8aa202d`, latest `20261011120000`, with the target absent;
    - functions `708dbe893149ea2b97e6893fea449925`/329 and structural `_combined` `76c930988563bd06f86c65e429fdb8fc`/3130, both equal to the recorded evidence and to the unrepaired local stack;
    - `app.issue_receipt` md5 `fdb063de930b6fb43662df89d070ae8c`, SECURITY INVOKER, with the same ACL; the same four `receipts` triggers; neither new function present;
    - 0 tenants, customers, bookings, invoices, payments, receipts and events.

    No drift from the approved baseline. **Predicted delta on Primary:** ledger 252 with `20261012120000` once; functions 331 with `e6a65849…`; triggers 318; `_combined` `02dcc5a1…`/3134; no business row written.
- **Readiness verdict: PASS.** Every pre-deployment condition of the owner's Gate 2 holds.

### 2026-10-12 — Gate 2 recorded (Step 5)

- The owner's execution authorization of 2026-10-12 grants, separately from Gate 1, an exact-byte deployment of `20261012120000_a_receipt_is_issued_once_and_stays_as_issued.sql`, SHA-256 `090936946f72bbe1a22b60c362685ee61bb8304ac9680c309da259cc52b27bfc`, md5 `9a352fdd0d3caec23e1e1c36a43200ff`, to Primary `vrvtsxexkiiiivlkdxzp` only, valid only if every pre-deployment condition passes. Step 4 shows they do. It authorizes no other migration and no business-data write. Secondary `brplkqmbzffpxqgkkdzo` is never contacted.

### 2026-10-12 — Primary deployment (Step 6) and post-deploy state (Step 7)

- **Prewrite recheck**, in a later session from the preserved checkpoint, matched every Gate-2 condition exactly:
  - HEAD `04d117e`, 4 ahead of and 0 behind `origin/main` `2049f2e`; the working tree held only Write Scope paths;
  - the migration file `090936946f72bbe1a22b60c362685ee61bb8304ac9680c309da259cc52b27bfc`, md5 `9a352fdd0d3caec23e1e1c36a43200ff`; test 156 `26aeb66438f6c52c9e572cc190c3096da883c27ab1d08db8648faae06885e9c2`;
  - project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`; ledger 251 `f678a3ef5790582c39635136c8aa202d`, latest `20261011120000`, target absent by version and by name;
  - functions `708dbe893149ea2b97e6893fea449925`/329; all ten structural surfaces and `_combined` `76c930988563bd06f86c65e429fdb8fc`/3130;
  - `app.issue_receipt` md5 `fdb063de930b6fb43662df89d070ae8c`, SECURITY INVOKER, ACL `{postgres=X/postgres,authenticated=X/postgres}`; the four prior `receipts` triggers; neither new function present;
  - 0 tenants, customers, bookings, invoices, payments, receipts and events.
- **Step 6.** The transmitted text was proven server-side before the write: md5 `9a352fdd0d3caec23e1e1c36a43200ff`, 9882 bytes, 198 LF, 0 CR. It was applied once through `supabase-primary` as `a_receipt_is_issued_once_and_stays_as_issued`. The connector assigned the temporary version `20261012110339`. One guarded UPDATE renamed that row to `20261012120000`; the guard required exactly one row after `20261011120000`, a single stored statement whose md5 is the file's, and no existing target.
- **Fresh post-deploy reads:**
  - ledger 252 `5f13c62d2f609e7794a0193a2f203c50`, equal to the migration files, with `20261012120000` exactly once;
  - functions `e6a65849bc390360dcb53b2be4f1a0b8`/331, triggers `d0b98a16e51bb805a93e14737cd5e1b3`/318, `_combined` `02dcc5a1076506289a6f7ff81894fb4d`/3134. Policies, constraints, grants, columns, views, indexes, status transitions and RLS are unchanged. Every value equals the local stack after a clean reset (Step 4);
  - `receipts` triggers now add `receipts_emit_issued` and `receipts_guard_issue`;
  - `app.guard_receipt_issue` md5 `de1134b24a2d4662776d163ac2ff5853` and `app.emit_receipt_issued` md5 `d4458754410b7e530bc39b2b2fb5cb9a`, both SECURITY DEFINER, `search_path=""`, ACL `{postgres=X/postgres}`;
  - `app.issue_receipt` md5 `b2e09f264b27a0f5643353c2fe78c5fb`, SECURITY INVOKER, ACL unchanged;
  - catalog values 623; 0 tenants, customers, bookings, invoices, payments, receipts and events.

  No business row was written. Secondary was not contacted.
- **Step 7:**
  - `primary-ledger-evidence.json` was rewritten from those readings only, read at `2026-10-12T11:04:38Z`;
  - the manifest's Live state is 252 migrations with the same fingerprints, 71/623 catalog and 464 HTTP assertions unchanged;
  - `supabase/tests` holds 156 files whose `plan(N)` values sum to 2969, so the suite is `156 files / 2969 assertions`;
  - coverage is 42 of 78, all at `ADVERSARIAL`;
  - RCPT-1 to RCPT-4 are `DEPLOYED` with Cert `✅`.
- **Generators.** `MASTER_API_CONTRACT.md` regenerates byte-identical (80 RPC endpoints, 8 reporting views, 74 tables). `ai-map.json` changes only its timestamp.
- **Guard self-tests, all green:** `test_cold_start_state_guard` 34/0, `test_future_date_guard` 18/0, `test_primary_ledger_guard` 13/0, `test_status_contradiction_guard` 33/0.
- **Checks:** `check_primary_ledger` `RECOVER-1 LEDGER EVIDENCE: CLEAN` (252, `5f13c62d…`); `check_database_parity_evidence` `PRIMARY PARITY EVIDENCE: CLEAN`; `REPOSITORY CONSISTENCY: CLEAN`; `git diff --check` clean.
- **Runtime Checkpoint:** DONE.

### 2026-10-12 — Post-deploy local certification

Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran on the clean, committed HEAD `22821f3` under `scripts/run_timed.ps1`, with nothing else running (`concurrent=0`), followed by `scripts/watch_run.ps1`.
- It ran in VERIFY mode (`ORVION: READY`, `STEP: DONE`).
- It reported `LOCAL_CERTIFY: READY` in 3.1 min, exit 0.
- Every mandatory verification passed in that run: reset; pgTAP Pass A; `verify_api_end_to_end.ps1`; `verify_journey_branches.ps1`; `verify_lifecycle_branches.ps1`; pgTAP Pass B; smoke; `check_database_parity_evidence.ps1`; repository consistency; `git diff --check`; `check_primary_ledger.ps1`.

Two earlier results were not repeated, because what they ran on is unchanged:
- The four CI-only guard self-tests passed on the same committed content at Step 7.
- M1–M15 and the causal negative ran at Step 4, against the committed migration and test bytes.

This contract's Review Gate holds no remote item. The implementation and the Complete commit are therefore published together as one range, as Step 8 states.

**Selector after SPEC-268** (`scripts/batch6_select_target.ps1`, 36 surfaces still `NOT-RECORDED`), as Exposure/coverage:
1. `chart_of_accounts` 7/38
2. `notification_deliveries` 7/42
3. `approval_requests` 7/52
4. `user_branch_assignments` 7/590
5. `departments` 7/654
6. `user_role_assignments` 7/654
7. `customer_consents` 6/18
8. `document_retention_policies` 6/36
9. `document_links` 6/54
10. `exchange_rates` 6/66
11. `user_permission_grants` 6/88
12. `catalog_values` 6/102

Slice 42's measured target is `chart_of_accounts`.

## Verification Notes

### 2026-10-12 — Independent Review of the execution commit `22821f3`

The review checked the committed tree against the approved Draft `fb81eb0`, the owner's Gate 2 and the Write Scope, using the committed migration in full, the range diffs, the certified local stack and fresh Primary readings. It did not rely on the Execution Log alone.

1. **Wrong-direction receipts (criterion 1).** `app.guard_receipt_issue` reads the payment's `payment_direction_code` on INSERT and raises 23514 unless it is `customer_payment`. It has no session-less exit, so the RPC, the table door and the platform path are all bound. Test 156 passed in both `-Finish` pgTAP passes, and M5 is killed.
2. **Number and time (criterion 2).**
   - On INSERT the guard sets `issued_at := now()` and nulls the four submission fields.
   - It takes `pg_advisory_xact_lock(hashtextextended(tenant || ':RCP:' || year, 0))`, the key `app.issue_receipt` always took.
   - It derives the number from `max(substring(receipt_number from '^RCP-[0-9]{4}-([0-9]+)$')::bigint)`, so a malformed stored number is skipped, not parsed.
   - M6–M10 are killed.
3. **Fixed once issued (criterion 3).**
   - On UPDATE, a distinct `id`, `tenant_id`, `payment_id`, `receipt_number`, `issued_at`, `created_by` or `created_at` raises 23514 for every caller.
   - A distinct submission id or submitted or response time calls `app.authorize('CREATE_RECEIPT')` only when `auth.uid()` is not null.
   - `app.guard_financial_capability` is not modified.
   - M1–M4, M11 and M12 are killed.
4. **One event (criterion 4).** `receipts_emit_issued`, AFTER INSERT, is the only producer. `app.issue_receipt` no longer calls `app.record_event`. The payload carries the number, payment, customer, currency and amount. M13 and M14 are killed, and test 156's assertion 33 counts exactly four events.
5. **The RPC (criterion 5).**
   - `app.issue_receipt` keeps `(p_payment_id uuid) returns uuid`, SECURITY INVOKER and `search_path=''`. Its three refusals and its `CREATE_RECEIPT` check are unchanged, and it inserts only `(tenant_id, payment_id)`.
   - On Primary it reads md5 `b2e09f264b27a0f5643353c2fe78c5fb`, with ACL `{postgres=X/postgres,authenticated=X/postgres}` as before.
   - `MASTER_API_CONTRACT.md` regenerates unchanged.
6. **Mutation (criterion 6).** M1–M15 were each killed at Step 4, every installation proven by a fingerprint and every restoration byte-equal and 33/33. The causal negative is recorded: 3–7 failed, then the run aborted on the missing trigger.
7. **Register (criterion 7).** The range adds RCPT-1 to RCPT-4, each FIXED and DEPLOYED with Cert `✅`, and changes the freshness line, demoting the D4 entry to `Previously:`. No other row changed.
8. **Disposition (criterion 8).** Against `2049f2e`, only four things changed: the freshness entry, the coverage line, "All 42" and the `receipts` row (`AUDITED` / `ADVERSARIAL`). Its 78 rows count 18 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL` and 36 `NOT-RECORDED`: 42 of 78.
9. **Frozen values (criterion 9).** The committed blobs hash to the approved values: the migration `090936946f72bbe1a22b60c362685ee61bb8304ac9680c309da259cc52b27bfc` (9882 bytes, 0 CR) and test 156 `26aeb66438f6c52c9e572cc190c3096da883c27ab1d08db8648faae06885e9c2` (18773 bytes, `plan(33)`). Primary's stored statement md5 is `9a352fdd0d3caec23e1e1c36a43200ff`.
10. **Agreement (criterion 10).**
    - Primary, the evidence and the manifest agree: 252 migrations, `5f13c62d…`; functions `e6a65849…`/331; structural `02dcc5a1…`/3134; 71/623 catalog; 156 files / 2969 assertions; 464 HTTP assertions.
    - `check_primary_ledger` and `check_database_parity_evidence` are CLEAN inside `-Finish`.
    - The four guard self-tests passed at Step 7, and repository consistency is CLEAN.
11. **Next capability (criterion 11).** The Complete commit names Batch 6 Slice 42 and `chart_of_accounts` (7/38), measured on the certified stack, and clears the Active Change Request.
12. **Primary and Secondary (criterion 12).**
    - Primary received two writes: the one authorized migration, applied once after its transmitted text was proven, and one guarded rename of temporary version `20261012110339`.
    - It holds 0 tenants, customers, bookings, invoices, payments, receipts and events, before and after. Only the function and trigger surfaces moved.
    - Secondary was never contacted.
13. **Scope (criterion 13).** `2049f2e..22821f3` changes eight paths, all in Write Scope. The contract's changes since the Draft are the status, the checkpoint and Execution Log entries replacing the template placeholder.

**The renumbering, as exercised.** The owner's Gate 1 and Gate 2 name this contract SPEC-266. Its approved substance and the migration's bytes are unchanged; only the identity and test 156's first-line comment moved, as Notes records. The exact-byte Gate 2 applied to the bytes deployed.

**Outside this contract, and not a defect in it:** canon 29's split receipts stay a product decision (Notes).

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

- **Prototype files.** The migration, test 156, the mutation harness and the probe are held outside the repository, in the authoring session's `prototypes` folder. A fresh agent that lacks them re-derives the files from this contract's description, and the frozen SHA-256 decides whether they match.
- **Not decided here:** canon 29's split receipts (several receipts for one payment). It needs a product decision before the one-receipt-per-payment key changes.
- **Renumbered before approval.** This contract was drafted as SPEC-266. SPEC-265's Execution Log quoted the owner's 2026-10-12 authorization, which names SPEC-266 and SPEC-267, and any tracked mention reserves an identity (`CR_LIFECYCLE.md` §4), so the allocator's first unreserved identity after SPEC-265 is SPEC-268. The substance the owner approved is unchanged. The migration's bytes carry no contract number and keep the SHA-256 the owner's Gate 2 names. Test 156's first line names the contract, so its pinned SHA-256 and md5 were re-derived after that one comment changed; its 33 assertions are unchanged.