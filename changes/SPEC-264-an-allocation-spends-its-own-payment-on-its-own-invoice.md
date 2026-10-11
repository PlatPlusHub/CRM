# Change Request — SPEC-264

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Foundation Completion Programme Batch 6 Slice 40: give `public.payment_allocations` a truthful disposition and close **PAY-6**, **PAY-7**, **PAY-8** and **FIN-12**.

The surface is canon 24's Payment Allocation: the row that says which invoice a payment settled and how much of it. `authenticated` holds table-level INSERT, SELECT and UPDATE; RLS admits a reader of the invoice; `app.record_payment` (SECURITY INVOKER) writes a payment and its one allocation through that grant; and the table door is the only path canon gives for spreading one payment over several invoices.

After this change one invariant holds on every door: **an allocation spends its own customer payment, in that payment's currency, on an invoice of the payment's own customer; it never makes the payment settle more than it is, nor the invoice receive more than it is worth in the invoice's own currency; a currency difference carries its exchange rate and its invoice-currency value is derived, never accepted; the two ceilings are serialised; and once written, an allocation stays where it was put — only its amount is corrected, by RECORD_PAYMENT as before.**

Record the surface `AUDITED-OPEN` on PAY-5 and FIN-11, and record **PAY-9**, found during this slice, as OPEN.

This contract does not touch any grant, policy, permission, catalog value, event, state transition, canon file, any other surface, n8n or any Phase-8 work.

## Business Reason

### Selection
`scripts/batch6_select_target.ps1`, run at `1d25f40` on 2026-10-11 and recorded as the measured next target in SPEC-262's Complete entry, ranks `payment_allocations` first among the 38 surfaces still `NOT-RECORDED`: Exposure 8 (money column, two direct-write doors, one RPC), coverage 60. The runner-up is `receipts` at 7/20. Twelve pgTAP files mention the table. They prove the invoice ceiling (72), the invoice state an INSERT may target (89, 96), the capability on INSERT and on an amount change (68, 126), the creation events (38, 140) and the actor (87); none attacks an UPDATE of the allocation's link, its coherence with its own payment, its currency, or two writers at once.

### Authority
- **Canon 24 (Payment Allocation)** and **canon 29**: an allocation belongs to exactly one invoice and exactly one payment; one payment may settle several invoices and one invoice may be paid by several payments; it records the exchange rate when the payment's currency differs from the invoice's.
- **Canon 31 (`payment_allocations`)**: `currency_code` is the currency the payment was actually made in, matching `payments.currency_code`; `exchange_rate_id` and `allocated_amount_invoice_currency` are populated only when the payment's currency differs from the invoice's, and are null otherwise; the sum per invoice, in the invoice's currency where a conversion applies, must not exceed `total_amount`.
- **Canon 07**: corrections after approval go through a new event, adjustment or reversal. There is no DELETE grant on this table.
- **FA-2** (owner decision, ratified 2026-09-09, `20260909131000`, test 113): a payment in another currency is allowed only with explicit conversion evidence — an `exchange_rates` row for exactly that pair, in the tenant, positive and finite — with the converted value derived, never accepted. Silent cross-currency treatment is rejected.
- **FIN-10** (`202607057500`): an invoice cannot be paid more than it is worth, enforced at commit by `app.enforce_invoice_allocation_ceiling` on both tables, with no session-less exemption.
- **PAY-1** (`202607059500`): an allocation may target only an issued, partially paid or overdue invoice that is neither voided nor archived — enforced on INSERT only.
- **PAY-2** (SPEC-221): a payment's economic identity needs RECORD_PAYMENT on UPDATE; SPEC-221 left `payment_allocations`' amount-only mapping in place and named no rule for its other columns.
- **The sole sanctioned writer, `app.record_payment`**: it charges RECORD_PAYMENT, serialises on `pg_advisory_xact_lock(hashtextextended(invoice_id::text, 0))`, writes a `customer_payment` of the invoice's customer and currency and one allocation of the same amount and currency, and derives `paid` / `partially_paid` from the allocated total.
- **`app.customer_balance`** derives a customer's paid amount from `payments`, by `payments.customer_id`, not from allocations.

### PAY-6 (High) — a reader of an allocation could move it to another invoice, payment or currency without RECORD_PAYMENT, and a RECORD_PAYMENT holder could move paid money onto a draft invoice
Measured at `1d25f40` on the local stack, in rolled-back transactions. The actor was an `employee` holding neither RECORD_PAYMENT nor VIEW_FINANCIAL_DOCUMENTS, who saw no payment at all and saw the allocation only because its invoice was on a booking they owned:
- `app.record_payment` allocated customer C1's 600 EGP to C1's invoice IA.
- The employee re-pointed that allocation by direct UPDATE: first to customer C2's invoice IB, then to a **draft** invoice, then onto a **supplier payment**, then to currency USD, then set its converted amount. Every UPDATE landed.
- `app.guard_financial_capability` compares only `allocated_amount` on UPDATE, and PAY-1 fires on INSERT only. As an owner holding RECORD_PAYMENT, the same UPDATE moved paid money onto a draft invoice.

Consequences, measured after the employee moved C1's 600 onto C2's invoice:
- `app.record_payment` took another 1000 from C1 for C1's 1000 invoice, leaving C1 600 in credit.
- It then refused C2's genuine 1000 ("exceeds invoice outstanding 400").
- After that, it marked C2's invoice `paid` on 400 of C2's money, while `app.customer_balance` still showed C2 owing 1000.
- (A void of the stripped invoice was refused by canon 26's state machine, `partially_paid -> voided`; that door held.)

### PAY-7 (High) — an allocation was not bound to its own payment
Measured at `1d25f40` by an owner holding RECORD_PAYMENT, at the table door, each allocation committed:
- a 600 payment allocated 1600 across two invoices;
- a supplier payment settling a customer invoice;
- an allocation claiming USD from an EGP payment.

Nothing compared an allocation with its payment. This is FIN-10's class from the payment's side: the RPC is correct by construction, and the door that canon needs for split payments enforced none of it. It has FIN-10's grade.

### PAY-8 (Medium) — a currency difference was silent, and both ceilings counted it at face value
Measured at `1d25f40`:
- A 100 USD payment allocated to an EGP invoice with no exchange rate committed. The ceiling and `app.record_payment` both counted it as 100 EGP.
- At any realistic rate, that misstates how much of the invoice is paid. A test on the unrepaired schema shows both directions: a 5000 EGP allocation that settles exactly a 100 USD invoice at 0.02 is refused (5000 > 100); and once 600 EGP plus 8 USD at 50 have filled a 1000 EGP invoice, `app.record_payment` still accepts more (it computes 392 outstanding).
- This is FA-2's owner-ratified rule ("never silently"), not yet applied to the table that canon makes carry the rate.

### FIN-12 (Medium) — the invoice ceiling had a race at the door
Measured at `1d25f40` with two live sessions:
- Each session allocated 600 to the same 1000 invoice at the table door and forced its deferred check before the other committed.
- Both checks passed and both transactions committed: 1200 against 1000.
- `app.record_payment` serialises on the invoice key; the ceiling trigger took no lock, so a door allocation raced both the RPC and other door allocations. SPP-6's grade.

### PAY-9 (Medium, recorded OPEN, not repaired here) — a booking paid through `app.record_payment` still owes its full invoice in the booking-scoped balance
Measured at `1d25f40`, rolled back: an invoice on booking B1 was paid in full with `app.record_payment` and became `paid`. `app.customer_balance(C1, B1)` reported 1000 outstanding, while `app.customer_balance(C1)` reported 0. The causes:
- in booking mode it counts payments by `payments.booking_id`;
- `app.record_payment` leaves that column null (CONV-7's root cause);
- the link to the booking is the allocation.

`app.enforce_booking_lifecycle` reads exactly this booking-scoped balance to decide whether issuing a booking charges ALLOW_ISSUE_WITH_NEGATIVE_BALANCE. Read from its code, not exercised: issuing that fully paid booking would therefore charge the override, which is a false risk path on the sanctioned flow. `reporting.customer_outstanding` uses the customer-level call and is unaffected. It is not repaired here because the attribution of a payment to a booking is a balance-model change with its own consumers (BOOK-12's open business rule among them). With this contract an allocation becomes the trustworthy link that repair needs. **Latent:** Primary holds 0 bookings and 0 invoices. Reopening trigger: before the first production booking is issued.

### The repair
One migration, `20261011120000`:
- **`app.guard_payment_allocation_link()`**, the row-level BEFORE INSERT OR UPDATE trigger `payment_allocations_guard_link`. It is SECURITY DEFINER with an empty `search_path`, PUBLIC revoked, and has no session-less exemption.
  - On UPDATE it refuses (23514) any change to `id`, `tenant_id`, `payment_id`, `invoice_id`, `currency_code`, `exchange_rate_id`, `created_by` or `created_at`.
  - On INSERT and UPDATE it reads the invoice's currency and applies FA-2's exact shape:
    - **Same currency:** a rate is refused, and `allocated_amount_invoice_currency` is set null (canon 31).
    - **Different currency:** a rate is mandatory, must be in this tenant, must convert exactly (allocation currency → invoice currency), and must be positive and finite. `allocated_amount_invoice_currency := allocated_amount * rate` is derived; whatever the caller sent is discarded.
- **`app.enforce_payment_allocation_coherence()`**, with the same security, runs at commit through two DEFERRABLE INITIALLY DEFERRED constraint triggers: `payment_allocations_within_payment_amount` (AFTER INSERT OR UPDATE on the allocations) and `payments_amount_covers_allocations` (AFTER UPDATE on payments).
  - It takes `pg_advisory_xact_lock(hashtextextended(payment_id::text, 0))`.
  - If the payment has any allocation, it refuses (23514): a direction other than `customer_payment`; an allocation in another currency than the payment's; an allocation to an invoice of a customer other than the payment's (a null customer included); or a sum above the payment's amount.
- **`app.enforce_invoice_allocation_ceiling()`** keeps its body and its two triggers, with two additions:
  - for an allocation write, it first takes the invoice key `app.record_payment` already takes;
  - it sums `coalesce(allocated_amount_invoice_currency, allocated_amount)`, which by the guard is the amount in the invoice's currency.
- **`app.record_payment`** is replaced by its complete current definition, with exactly one line changed: its already-allocated sum reads the same invoice-currency amount. Its outstanding check and its `paid` / `partially_paid` derivation therefore agree with the ceiling. Signature, SECURITY INVOKER, `search_path` and ACL are unchanged.

A wrongly placed allocation is corrected by setting its amount to 0 and allocating again; the new allocation passes every rule an allocation must pass. No table, column, grant, policy, permission, event type, catalog value or state transition is added.

### Rejected
- **Charging RECORD_PAYMENT for the link columns (PAY-2's shape).** It closes the employee door but not the owner's: a RECORD_PAYMENT holder could still move paid money onto a draft or voided invoice (PAY-1 is INSERT-only), or onto another customer's invoice. Rewriting the link also silently rewrites what `payment_allocation_created` recorded. A zero-and-reallocate correction keeps the history, and passes PAY-1 and both ceilings on its INSERT.
- **Re-running PAY-1's state rule on UPDATE.** It closes the draft escape, but not cross-customer, cross-payment or currency re-points.
- **Revoking INSERT or UPDATE from `authenticated`.** Canon makes spreading one payment over several invoices a legitimate act, and no RPC performs it, so the table door is that act's only path. PAY-3 and PAY-5 recorded it as a legal door.
- **Refusing cross-currency allocation.** FA-2 permits it with evidence, and canon 31 describes it.
- **Deriving the allocation's currency from the payment.** That would silently reinterpret the caller's number; refusing a mismatch is explicit.
- **Locking the invoice on invoice-side events too.** An issued invoice's total is frozen (INV-5), and only an issued invoice can be allocated to (PAY-1), so there is no race there. The lock would also open a deadlock against `app.record_payment`'s own invoice UPDATE.
- **SERIALIZABLE isolation.** That is a platform-wide change. PostgREST and every RPC run READ COMMITTED, where a lock taken in an earlier statement makes the later sum read the competitor's commit.
- **Deriving invoice status at the door (PAY-5 / FIN-11).** That is the FIN-7 invoice-state package's reopening trigger, not this contract's.
- **Repairing PAY-9 here.** That is a balance-model change with its own consumers; it is recorded instead.
- **A CHECK constraint.** It may reference only its own row.

### Held, recorded so a later slice does not rediscover it
- **Capability on INSERT and on an amount change:** an employee is refused `permission denied: RECORD_PAYMENT` (FIN-3), measured. There is no DELETE grant.
- **Tenant:** another tenant's payment, invoice or rate is refused by the tenant-qualified foreign keys, and the guard reads the rate within the tenant.
- **PAY-1 on INSERT:** draft, voided and archived invoices are refused, unchanged.
- **Void:** `app.guard_invoice_void` refuses a void while money is allocated. A stripped `partially_paid` invoice was refused `voided` by canon 26's machine, measured.
- **Balances:** `app.customer_balance` and `reporting.customer_outstanding` derive paid amounts from payments, so PAY-6 harmed invoice settlement, outstanding and collection, not the customer ledger.
- **Read scope:** an employee sees the allocations of invoices on bookings they own. That is the invoice's read scope, intended.
- **Conversions:** `payment_recorded` is emitted at the payment's commit (PAY-3); a later allocation never re-records it.
- **Merge:** `app.merge_customer_identity` re-points a customer's invoices and payments in one transaction, so the commit-time customer rule sees them agree. This is proven in test 155.

## Risks

- **Changed UPDATE semantics.** An allocation's payment, invoice, currency, rate and origin can no longer change, for any caller, the platform included. No function, script or test updates them today; the only correction left is zeroing the amount and allocating again.
- **Changed INSERT and commit semantics at the door.** These are now refused at commit, for every caller:
  - an allocation of a non-customer payment;
  - an allocation in another currency than its payment's;
  - an allocation to another customer's invoice, or from a payment with no customer;
  - an allocation that makes a payment settle more than it is;
  - a cross-currency allocation without its exact rate.

  The converted amount is derived. `app.record_payment`'s allocation is coherent by construction and passes. Every fixture in the existing suite and all three declared HTTP suites pass unchanged.
- **Payments that already settle invoices.** Shrinking one below what it settled, or changing its direction, currency or customer, is now refused at commit. PAY-2 already required RECORD_PAYMENT for each.
- **Policy-bearing element, for the owner's attention at Gate 1:** "an allocation settles only an invoice of the payment's own customer". It follows `app.customer_balance`, which credits a payment to `payments.customer_id`: an allocation to another customer's invoice makes the invoice and the two balances disagree (measured in PAY-6). A third-party payer is not modelled anywhere in ORVION today; supporting one would need its own balance design. Rejecting this one clause at Gate 1 would remove it, its two assertions (18, 19) and mutant M13.
- **Serialisation.** Allocation writers to one invoice, and to one payment, now queue until the earlier one commits. Two door transactions allocating to the same two invoices in opposite order can deadlock; PostgreSQL detects it and aborts one with 40P01, which is retryable and leaves nothing written. A transaction run at REPEATABLE READ is not protected by the lock (its snapshot predates the competitor's commit). No ORVION client uses REPEATABLE READ.
- **The payments trigger inventory.** Test 126 assertion 23 pins the count of triggers on `payments`. It moves from 10 to 11 with a one-line edit; its query and every other assertion are unchanged.
- **Primary deployment** adds two functions and three triggers, and replaces two function bodies, and nothing else. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it.
- **Workstation, not in scope:** resets for this contract run from the main checkout.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-264-an-allocation-spends-its-own-payment-on-its-own-invoice.md`
- `supabase/migrations/20261011120000_an_allocation_spends_its_own_payment_on_its_own_invoice.sql`
- `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql`
- `supabase/tests/126_payment_write_capability_parity_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607042500_create_finance_transaction_tables.sql`
- `supabase/migrations/202607047100_record_payment.sql`
- `supabase/migrations/202607057500_an_invoice_cannot_be_paid_more_than_it_is_worth.sql`
- `supabase/migrations/202607059500_money_allocated_to_an_invoice_that_was_never_issued.sql`
- `supabase/migrations/20260909131000_a_payment_in_another_currency_is_never_silent.sql`
- `supabase/migrations/20260925120000_payment_write_capability_parity.sql`
- `supabase/migrations/20260928180000_a_payment_is_recorded_on_every_door.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/38_class_a_events_test.sql`
- `supabase/tests/68_financial_status_capability_test.sql`
- `supabase/tests/72_invoice_allocation_ceiling_test.sql`
- `supabase/tests/87_actor_attribution_second_door_test.sql`
- `supabase/tests/88_parent_state_on_every_door_test.sql`
- `supabase/tests/89_finance_periphery_parent_state_test.sql`
- `supabase/tests/96_invoice_void_and_eta_boundary_test.sql`
- `supabase/tests/110_invoice_document_integrity_test.sql`
- `supabase/tests/113_cross_currency_payment_evidence_test.sql`
- `supabase/tests/140_payment_is_recorded_on_every_door_test.sql`
- `reports/architecture-decision-records.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `_ORVION_CANONICAL/24_entity_registry.md`
- `_ORVION_CANONICAL/26_state_machines.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/29_relationship_map.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
- `scripts/verify_database.sql`
- `scripts/verify_api_end_to_end.ps1`
- `scripts/verify_journey_branches.ps1`
- `scripts/verify_lifecycle_branches.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/24_entity_registry.md` (Payment Allocation); `_ORVION_CANONICAL/29_relationship_map.md` (Invoice To Payment); `_ORVION_CANONICAL/31_schema_draft.md` (`payment_allocations`)
- `reports/master/MASTER_GAP_REGISTER.md` (FIN-10, FIN-11, PAY-1 to PAY-5, FA-2, CONV-7, BOOK-12); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 method and EC-1…EC-11
- `supabase/migrations/202607057500_an_invoice_cannot_be_paid_more_than_it_is_worth.sql`; `supabase/migrations/20260909131000_a_payment_in_another_currency_is_never_silent.sql`; `supabase/migrations/20260928180000_a_payment_is_recorded_on_every_door.sql`
- Current local `app.record_payment`, `app.enforce_invoice_allocation_ceiling`, `app.guard_financial_capability`, `app.guard_parent_state_allows_write`, `app.customer_balance`, `app.merge_customer_identity`
- Tests 72, 113, 126 and 140

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
- `pwsh -NoProfile -File scripts/verify_journey_branches.ps1`
- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| An allocation's payment, invoice, currency, rate and origin are fixed once written | `scope_isolation` RLS; `app.guard_financial_capability`; `app.derive_created_by`; PAY-1's INSERT guard | WRITE | The prototype was the migration applied, with its ledger row, to a clean reset of the `1d25f40` local stack (250 migrations); the files were held outside the repository. Migration SHA-256 `7da89123b957025807ee2a206ae0ee3d633010ef56ad1ded2a71447c2d4c6719`, md5 `26f9bd325e4f69ff4e7f2ad95ffec8cd`, 19748 bytes, 385 LF lines, ASCII. The employee's re-points (invoice, payment, currency, creation time) and the owner's re-point onto a draft were refused 23514 with the guard's message; the employee's amount change was still refused 42501 by FIN-3's guard; assigning the fixed fields their own values succeeded and a supplied converted amount was discarded. No function, script or test updates these columns (searched). |
| A payment's allocations must be of a customer payment, in its currency, for its own customer, and sum to no more than it, at commit, from both tables | `app.record_payment`; `app.merge_customer_identity`; `payments_guard_financial_capability` (PAY-2); `payments_guard_currency_conversion` (FA-2); `payments_emit_recorded` (PAY-3); tests 113, 126, 140 | WRITE | Before, as an owner with RECORD_PAYMENT: a 600 payment allocated 1600, a supplier payment settling a customer invoice, and an EGP payment's allocation in USD each committed. Prototype: each is refused 23514, as are a C2 payment settling C1's invoice and a customer-less payment's allocation; shrinking, redirecting, re-denominating or re-customering an allocated payment is refused; growing it succeeds. `app.record_payment`'s partial and full payments, a door split and a zero-and-reallocate correction pass. Merging C2 into C1 after both were paid commits. Tests 113 (all), 126 (as edited), 140 (all) pass. |
| A cross-currency allocation needs its exact rate and its invoice-currency value is derived (FA-2) | `public.exchange_rates`; the invoice ceiling; `app.record_payment` | WRITE | Before: 100 USD to an EGP invoice with no rate committed and counted as 100 EGP. Prototype: refused without a rate, with the inverse pair, with another tenant's rate, and a rate on a same-currency allocation is refused; 8 USD at 50 is stored with 400.0000 derived; 5000 EGP at 0.02 settles a 100 USD invoice exactly; an amount corrected to 0 re-derives 0. |
| The invoice ceiling is serialised with `app.record_payment` and counted in the invoice's currency | `invoices_total_covers_allocations`; `app.guard_invoice_void`; test 72 | WRITE | Before, two live sessions each forced the ceiling and committed 600 against a 1000 invoice: 1200 committed. With the final bytes installed, the second session waited for the first's commit and was refused, 1200 > 1000; 600 committed. A second race spent one 600 payment twice (400 + 400) and was refused, 800 > 600; 400 committed. The race fixture was a dedicated tenant, deleted afterwards. Test 72 passes unchanged (18/18). |
| `app.record_payment`'s already-allocated sum reads the invoice-currency amount (one line) | `verify_api_end_to_end.ps1`; `verify_journey_branches.ps1`; `verify_lifecycle_branches.ps1`; the API contract | WRITE | The function is otherwise byte-identical to its `20260928180000` definition (a 100-line comparison differs in exactly that line). On the prototype, after 600 EGP plus 8 USD at 50 filled a 1000 EGP invoice, the RPC refused 0.0001 ("exceeds invoice outstanding 0.0000"); at face value it computed 392 and accepted. The three HTTP suites pass: 35/0, 85/0, 122/0. |
| The payments trigger inventory grows by one | `126_payment_write_capability_parity_test.sql` assertion 23 | WRITE | SHA-256 `618d3eab8ae51f9204670c80db776a83a5c953e83baa7f8c007381b078964203`, 15296 bytes → `f90fcd2a7f0746412b315e04ff85551d037f5efbbb92471a67c67f700cf03de4`, 15326 bytes: a one-line diff changing `10,` to `11,` and naming PAY-7's check in the description. Unedited, it fails only assertion 23 on the prototype; edited, 33/33. Its amount-only `payment_allocations` mapping assertion (24) is unchanged and still true. |
| Test 155 | `supabase/tests` | WRITE | SHA-256 `2f64bb8f8129d7584f165dbbb61d20ad4053d128237cf40e4f2a841f6cb0784c`, md5 `111a48219d9582d21946de428001c0b0`, `plan(48)`, 31885 bytes, 369 LF lines, ASCII: 48/48 on the prototype. On the unrepaired `1d25f40` schema 32 fail, each for its intended reason: 7, 8, 9, 10, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 25, 26, 27, 28, 29, 31, 32, 33, 34, 36, 38, 43, 44, 45, 46, 47, 48. |
| Other tests reading this table or its functions | tests 10, 38, 68, 72, 73, 87, 88, 89, 96, 110, 113, 140 | VERIFY | Each passes unchanged on the prototype, inside the full runs below. |
| The generated API contract | `MASTER_API_CONTRACT.md` | WRITE | The canonical generator against the prototype reports 80 RPC endpoints (80 with HTTP evidence), 8 views and 74 tables, byte-identical to the committed contract (SHA-256 `d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`). Step 7 regenerates it, and it stays unchanged. |
| Suite and smoke | full pgTAP; `scripts/verify_database.sql` | VERIFY | On the prototype, after a clean reset from the main checkout: Pass A ran all 155 files (153 unchanged committed files, test 126 as edited and test 155), 2916 assertions (2868 + 48), 0 failed; the three declared HTTP suites passed; Pass B again 155 files / 2916, 0 failed. Smoke: `ALL CHECKS PASSED (78 tables, … 71/622 catalog, …)`. The other three HTTP suites (`verify_care_journeys`, `verify_role_journeys`, `verify_storage_end_to_end`) call no payment RPC and write no payment or allocation, and are not declared. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | The `1d25f40` local stack equals the recorded Primary values (250 migrations, `24b8778b6d9e955a8472affb07712858`; functions `3d7eb4e3550f7cec15815defb600272d`/326; combined `a23669c9c5c31f56bed4f7e8d265c534`/3121). With the migration: functions `a8e4e193a239ffc03ae4940633c9ec2d`/328, triggers `fb5354b40fee5521d790d39673ef9694`/315, constraints `e669286c961025cb49688862286338ed`/527, combined `825c6f70382a8ea2f33921efbbcae973`/3128. Policies `b67d466a…`/125, grants `6727f6d8…`/189, columns `448db887…`/1134, views `10bb212a…`/16, indexes `22a4d58c…`/300, status transitions `db2165c7…`/115 and RLS `c117cbf7…`/79 are unchanged. The 251-row ledger fingerprint is `f678a3ef5790582c39635136c8aa202d`. |
| Measured state that moves | manifest (`Live state`, suite figure, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 250 → 251 migrations, latest `20261011120000`; 154 → 155 files and 2868 → 2916 assertions; coverage 40 → 41 of 78. HTTP (464), tables (78), catalog (71/622), views (8) and client RPCs (80) do not move. Primary values are written only from fresh post-deploy readings. |
| PAY-6, PAY-7, PAY-8, FIN-12 fixed; PAY-9 recorded; the surface `AUDITED-OPEN` | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25 | WRITE | Test 155's `-- ATTACK-CLASSES:` line and negative assertions satisfy Check 24 for `payment_allocations`. Every new row's Owner field is `—`, so Check 25 reads no owner decision. The row stays `AUDITED-OPEN` on PAY-5 and FIN-11, which are unchanged. Coverage becomes 41 recorded: 17 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 37 `NOT-RECORDED`. Step 4 runs Checks 21 to 25 on the applied edits. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | At `1d25f40` all four pass: cold-start 34/0, future-date 18/0, primary-ledger 13/0, status-contradiction 33/0. Predicted from SPEC-262's identical shape, and measured at Step 4: before deployment, repository consistency reports exactly the measured-state drift — 250 vs 251 migrations; latest `20261011090000` vs `20261011120000`; ledger `24b8778b…` vs `f678a3ef…`; 154 vs 155 test files; 2868 vs 2916 assertions; RECOVER-1 ledger evidence — and the primary-ledger and cold-start self-tests fail only their CONTROL and restore cases because of it. These are not waived: Step 7 makes them true, and Step 8 requires them green. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the declared HTTP suites, smoke, mutation proof and the two-session races | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| PAY-6, PAY-7, PAY-8, FIN-12, PAY-9 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite and coverage figures equal the files and the disposition record | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.guard_financial_capability` charges RECORD_PAYMENT on INSERT and on a change of `allocated_amount`, and nothing else. `app.guard_parent_state_allows_write` judges the invoice's state on INSERT only. `app.enforce_invoice_allocation_ceiling` caps the invoice total at commit, but takes no lock and counts face value. `payments_guard_currency_conversion` applies FA-2 to a payment's account, not to an allocation's invoice. Nothing compares an allocation with its payment. Only `app.record_payment` writes a coherent allocation, by construction. This contract reuses the ceiling function, FA-2's exact rule and messages, the advisory key `app.record_payment` takes, the existing foreign keys, RLS and capability guard, and FIN-8 and FIN-10's deferred constraint-trigger idiom. No shared allocation framework is earned.

Added Property: Once written, an allocation keeps its payment, invoice, currency, rate and origin for every caller. A different currency from the invoice's requires the exact rate, and the invoice-currency value is derived. At commit, a payment's allocations are of a customer payment, in its currency, for its own customer, and never more than it, judged when either side changes. The invoice ceiling counts the invoice's currency. Both ceilings serialise their writers per invoice and per payment. `app.record_payment` reads the same invoice-currency total.

Causal Negative: These are the pre-repair measurements in Business Reason, at `1d25f40`:
- the employee's re-points (C1's allocation to C2's invoice, to a draft, onto a supplier payment, to USD, converted amount set);
- the owner's re-point onto a draft;
- the downstream double collection and refused genuine payment;
- the owner's 600 payment allocated 1600, supplier payment settling a customer invoice, and USD allocation of an EGP payment;
- 100 USD counted as 100 EGP;
- 1200 committed against a 1000 invoice by two sessions.

On the unrepaired schema, test 155 fails assertions 7, 8, 9, 10, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 25, 26, 27, 28, 29, 31, 32, 33, 34, 36, 38, 43, 44, 45, 46, 47 and 48, each for its intended reason. The causes are:
- no exception where 23514 was required;
- 23503 from the foreign key where the guard's tenant message was required;
- a supplied converted amount kept;
- the converted amount not derived;
- a legitimate 5000 EGP → 100 USD allocation refused at face value;
- `app.record_payment` accepting 0.0001 at face value;
- the state the unrepaired re-points left behind;
- the triggers and locks absent.

Positive Test Design: One tenant has an owner and an employee who owns two bookings, of customers C1 and C2. There are five invoices: C1's IA, IC, ID (left draft) and IU (USD), and C2's IB. There are six payments, among them C1 EGP 600, a supplier payment, C1 USD 100, C2 EGP 1000, a customer-less EGP 100 and C1 EGP 5000. There are two in-tenant rates, and a rival tenant with its own payment and rate. Positive controls:
- a door allocation of C1's payment to C1's invoice passes both commit checks, with no converted amount;
- a no-op UPDATE succeeds;
- 8 USD at 50 is stored with 400 EGP derived, and 5000 EGP at 0.02 settles the 100 USD invoice exactly;
- RECORD_PAYMENT corrects an amount and the converted amount follows;
- the zero-and-reallocate correction moves C1's 600 from IA to IC, with both rows kept;
- a payment can grow;
- `app.record_payment` takes a partial payment and the balance, and derives `paid`;
- merging C2 into C1 commits and leaves no cross-customer allocation.

Negative Test Design:
- **Link:** the employee's re-point of invoice, payment, currency and creation time, and the owner's re-point onto a draft, are refused 23514. A session-less re-point is refused too.
- **Capability (held):** the employee's amount change is refused 42501 `permission denied: RECORD_PAYMENT`.
- **Payment coherence:** each of these is refused 23514 with its own message:
  - over-spending a payment, including by a session-less write;
  - a supplier payment, even at zero;
  - an allocation in another currency than its payment's, even with a valid rate;
  - another customer's payment;
  - a customer-less payment.
- **Payment side:** shrinking, redirecting, re-denominating or re-customering an allocated payment is refused 23514, and the payment is unchanged afterwards.
- **Currency evidence:** no rate, the inverse pair, a rate on a same-currency allocation and another tenant's rate are each refused 23514 with FA-2's messages. Another tenant's payment is refused 23503.
- **Concurrency:** the invoice's and the payment's advisory locks are held by the writing backend after an allocation write, read from `pg_locks`. The two-session races are recorded above.

Non-Empty Population Obligation: The tenant has two users with their roles, two customers, two bookings, five invoices, six payments and two rates; the rival tenant has its own payment and rate. Every allocation, refusal and lock is counted by row id or exact message; no zero-row operation satisfies an assertion. Assertion 6 proves that the employee sees exactly one allocation and no payment before any UPDATE.

Mutation Obligation: Out of file, record a surface: the md5 of the four functions' definitions with every trigger definition on both tables. For each mutant:
1. Install it inside test 155's own transaction, after the migration, and prove the surface differs.
2. Run test 155 and record the failing assertions.
3. Prove after the rollback that the live surface equals the pre-run surface.

A mutant whose installation is not proven is a harness error, never a kill.

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M1 | the UPDATE immutability arm removed | 7, 8, 9, 10, 12, 13, 14, 45 and their cascade |
| M2 | `invoice_id` left out of the immutable set | 7, 12, 13, 14, 32, 38, 45 |
| M3 | `payment_id` left out | 8, 12, 13 and their cascade |
| M4 | `currency_code` left out | 9 |
| M5 | `created_at` left out | 10 |
| M6 | a same-currency converted amount kept | 13, 32, 38 |
| M7 | a cross-currency allocation allowed without a rate | 20 |
| M8 | the rate-pair check removed | 21, 30, 31, 32, 36, 38 |
| M9 | a rate on a same-currency allocation allowed | 22 |
| M10 | the converted amount not derived | 31, 32, 33, 34, 36, 38 |
| M11 | the direction check removed | 16, 26 |
| M12 | the payment-currency check removed | 17, 27, 29 |
| M13 | the customer check removed | 18, 19, 28, 30, 31, 32, 36, 38, 43 |
| M14 | the payment-amount check removed | 15, 25, 29, 38, 44 |
| M15 | the payments-side trigger dropped | 25, 26, 27, 28, 29, 37, 38, 44, 45, 46, 48 |
| M16 | the allocations-side coherence trigger dropped | 15, 16, 17, 18, 19, 25, 28, 29, 30, 31, 32, 36, 38, 39, 43, 44, 47, 48 |
| M17 | the invoice lock removed | 46 |
| M18 | the payment lock removed | 47 |
| M19 | the ceiling sums face value | 33, 34 |
| M20 | `app.record_payment` sums face value | 32, 33, 34, 38 |
| M21 | a session-less exemption in the coherence check | 44 |
| M22 | a session-less exemption in the immutability arm | 45 |
| M23 | the rate read without the tenant | 23 |
| M24 | the link guard dropped | 7, 8, 9, 10, 12, 13, 14, 15, 18–23, 25, 29–46, 48 |

Prototype result: base surface `c749bf6fe071577ec77bcd0853b63851`; the live surface was `a1b916eae176a7684140a8347b310fa7` before and after the run. Every installation changed the surface, and all twenty-four were killed, exactly as listed. Two harness defects were found and fixed before this result:
- the fixture's deferred PAY-3 events fired under a signed-in caller;
- an earlier statement's unflushed deferred check made assertions 25–28 pass under M15 for the wrong reason.

Every positive step now forces its own deferred checks.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused test, a clean reset from the main checkout, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke;
- the out-of-file mutations M1–M24, the pre-repair causal negative and the two-session races;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261011120000_an_allocation_spends_its_own_payment_on_its_own_invoice.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `7da89123b957025807ee2a206ae0ee3d633010ef56ad1ded2a71447c2d4c6719`, md5 `26f9bd325e4f69ff4e7f2ad95ffec8cd`, 19748 bytes.
   - Its statements create, each with PUBLIC revoked:
     - `app.guard_payment_allocation_link()` with its BEFORE INSERT OR UPDATE trigger `payment_allocations_guard_link`;
     - `app.enforce_payment_allocation_coherence()` with its deferred constraint triggers `payment_allocations_within_payment_amount` and `payments_amount_covers_allocations`.
   - They then replace `app.enforce_invoice_allocation_ceiling()` with the allocation-write lock and the invoice-currency sum, and `app.record_payment(...)` with its one changed line. A comment block precedes them, stating the authority and the measurements.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `2f64bb8f8129d7584f165dbbb61d20ad4053d128237cf40e4f2a841f6cb0784c`, `select plan(48);`.
   - Its `-- ATTACK-CLASSES:` line reads `AUTH TENANT DOOR STATE INPUT BUSINESS PRIVILEGE CONCURRENCY REPLAY=N/A OBSERVABILITY=N/A`, with each `N/A` reason in its header.
   - Then, in `supabase/tests/126_payment_write_capability_parity_test.sql`, change only assertion 23's expected count from `10` to `11` and its description to name PAY-7's allocation check, giving SHA-256 `f90fcd2a7f0746412b315e04ff85551d037f5efbbb92471a67c67f700cf03de4`.
   - If a target carries content other than its `1d25f40` bytes or its frozen value, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains a `PAY-6` row. If not, make these edits and nothing else:
   - **Register:**
     - a 2026-10-11 Slice-40 freshness entry, with the previous one demoted to `Previously:`;
     - after PAY-5, new rows PAY-6 (High), PAY-7 (High) and PAY-8 (Medium), each FIXED by SPEC-264 locally with Primary pending and Cert `🛡`, with the measurements above;
     - after them, a new row PAY-9 (Medium), OPEN, with the measurement, its cause, its latency and its reopening trigger as stated above;
     - after FIN-11, a new row FIN-12 (Medium), FIXED by SPEC-264 locally with Primary pending and Cert `🛡`, with the two-session measurement;
     - every new row with Owner `—` and this contract as session.
   - **Disposition:**
     - a freshness entry, with the previous one demoted;
     - coverage 41 of 78 (17 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 37 `NOT-RECORDED`) and the "All 41" line;
     - the `payment_allocations` row `AUDITED-OPEN` / `ADVERSARIAL` / SPEC-264 / PAY-6, PAY-7, PAY-8, FIN-12, PAY-5, FIN-11, with its evidence, its swept non-defects and PAY-9's pointer.

   If a target carries content other than its `1d25f40` bytes, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset from the main checkout; test 155 and the focused tests 10, 38, 68, 72, 87, 88, 89, 96, 110, 113, 126 and 140;
   - pgTAP Pass A, the three declared HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - the mutation evidence M1–M24, the causal negative, and both two-session races on a dedicated tenant deleted afterwards;
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
   - the triggers of `payment_allocations` and `payments`;
   - `app.record_payment`'s and `app.enforce_invoice_allocation_ceiling`'s text md5, security mode and ACL;
   - the tenant, invoice, payment and allocation counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261011120000_an_allocation_spends_its_own_payment_on_its_own_invoice`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, both tables' triggers and both replaced functions' md5.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires:
     - exactly one new row;
     - its stored statement md5 equal to the file's;
     - no existing target version.
   - Read fresh:
     - the ledger, the function surface and all ten structural surfaces;
     - both tables' triggers;
     - the four functions' definitions, security modes and ACLs;
     - the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with 464 HTTP assertions unchanged.
   - Confirm that `supabase/tests` holds 155 files whose literal `plan(N)` values sum to 2916, then set `Suite **155 files / 2916 assertions**`. If either differs, stop.
   - Set Batch 6 coverage to 41 of 78, all forty-one at `ADVERSARIAL`.
   - Mark PAY-6, PAY-7, PAY-8 and FIN-12 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
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
     - set `Last Completed` to SPEC-264 / Slice 40;
     - set `Current Module` to Foundation Completion Programme Batch 6 resuming at Slice 41;
     - set `Next capability` to **Foundation Completion Programme — Batch 6 Slice 41**, naming the measured first target, followed by the existing Phase-8 order, closed-chapter and standing-fact sentences unchanged;
     - keep the manifest within 7000 characters;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate with `scripts/publish_candidate.ps1` and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [ ] An allocation's payment, invoice, currency, rate, creator and creation time cannot be changed by any caller (23514), the platform included. The employee's amount change is still refused 42501. Assigning the fixed fields their own values succeeds, and a supplied converted amount is discarded.
- [ ] At commit, an allocation of a non-customer payment, in a currency other than its payment's, to another customer's invoice, from a customer-less payment, or beyond its payment's amount is refused (23514), for every caller. An allocated payment cannot shrink below, redirect, re-denominate or re-customer beneath its allocations. Growing a payment succeeds.
- [ ] A cross-currency allocation requires an exchange rate in the tenant for exactly its pair, positive and finite, and stores the derived invoice-currency value. A same-currency allocation carries neither (23514 for a rate).
- [ ] The invoice ceiling counts each allocation in the invoice's currency, and an allocation write takes the invoice's advisory lock (the key `app.record_payment` takes) and the payment's. Two concurrent door allocations cannot together exceed an invoice or a payment.
- [ ] `app.record_payment` differs from its `20260928180000` definition only in its already-allocated sum reading the invoice-currency amount. It keeps its signature, security mode, `search_path` and ACL; its partial and full payments and its `paid` derivation are unchanged.
- [ ] The held controls stay held: PAY-1 on INSERT, FIN-3's capability, the tenant-qualified foreign keys, the void guard, and a customer merge with allocated payments.
- [ ] Mutants M1–M24 are each killed against test 155, with installation and restoration proven. The causal negative and the two-session races are recorded.
- [ ] Test 126 assertion 23's expected count moves from 10 to 11 and nothing else in that file changes.
- [ ] PAY-6, PAY-7, PAY-8 and FIN-12 are fixed and deployed in the register, and PAY-9 is recorded OPEN with its trigger. PAY-1 to PAY-5, FIN-10 and FIN-11 are unchanged.
- [ ] `payment_allocations` is `AUDITED-OPEN` / `ADVERSARIAL` in the disposition record, and coverage is 41 of 78. No other surface's row changed.
- [ ] The migration, test 155 and test 126 matched their frozen SHA-256 values when applied.
- [ ] Primary, the recorded evidence, the manifest (251 migrations; 155 files / 2916 assertions; 464 HTTP assertions), the API contract and `ai-map.json` agree. The four CI-only guard self-tests and repository consistency pass.
- [ ] The manifest names Batch 6 Slice 41 and its measured target as the next capability, with no Active Change Request.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

## Verification Notes

## Review Gate

- [ ] Every change matches the Implementation Steps exactly, or was correctly recorded as Already Applied per its verification check.
- [ ] No file outside Write Scope was modified, created, or deleted.
- [ ] No section was added, removed, or restructured outside the approved steps.
- [ ] Every Acceptance Criteria item is confirmed true.
- [ ] Any step that could not be resolved deterministically was reported, not guessed.
- [ ] If this Change Request's Supersedes / Depends On section names another file, that file's Status has been updated accordingly.
- [ ] The repository is in a clean, releasable state.

## Notes

Batch 6 Slice 40, prepared under the owner's 2026-10-11 Slice 40 directive. Gate 1 approval of this exact Draft and Gate 2 authorization of the migration's exact SHA-256 are each the owner's decision.
