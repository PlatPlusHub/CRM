# Change Request — SPEC-264

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Foundation Completion Programme Batch 6 Slice 40: give `public.payment_allocations` a truthful disposition and close **PAY-6**, **PAY-7**, **PAY-8**, **FIN-12**, **PAY-10** and **PAY-11**.

The surface is canon 24's Payment Allocation: the row that says which invoice a payment settled and how much of it. `authenticated` holds table-level INSERT, SELECT and UPDATE; RLS admits a reader of the invoice; `app.record_payment` (SECURITY INVOKER) writes a payment and its one allocation through that grant; and the table door is the only path canon gives for spreading one payment over several invoices.

After this change one invariant holds on every door: **an allocation spends its own customer payment, in that payment's currency, on an invoice of the payment's own customer; it never makes the payment settle more than it is, nor the invoice receive more than it is worth in the invoice's own currency, nor less than the invoice's recorded status says it received; a currency difference carries its exchange rate and its invoice-currency value is derived, never accepted; both ceilings are serialised; once written, an allocation stays where it was put — only its amount is corrected, by RECORD_PAYMENT as before; and every amount it is born with or corrected to is an event, with its actor and time.**

Record the surface `AUDITED-OPEN` on PAY-5 and FIN-11, and record **PAY-9**, found during this slice, as OPEN.

This contract adds one event type (`payment_allocation_amount_changed`) with its canon 27 entry and the smoke catalog pin that counts it. It does not touch any grant, policy, permission, state transition, invoice status, other canon file, any other surface, n8n or any Phase-8 work.

## Business Reason

### Revision
This is the second Draft of SPEC-264. The first, Draft commit `4e8589bf082be8f7cb7464df44fb8c6d00e65a6e` (contract SHA-256 `820c2c8872a02a02bf9bfcfb087699330310d0d61fe31874dc1d3edfeac264c8`, migration SHA-256 `7da89123b957025807ee2a206ae0ee3d633010ef56ad1ded2a71447c2d4c6719`), was never approved. On 2026-10-11 the owner made Gate 1 conditional on one question: does the correction it prescribed — set an allocation's amount to 0 and allocate again — keep a sufficient, durable, attributable history? Measured, it did not (PAY-10). The owner chose to resolve that inside this contract (Option A) and asked a second question: is a recorded event enough to make zeroing a sound accounting correction? Measured, it is not on its own (PAY-11). This Draft answers both. The first Draft's identities are superseded for approval and deployment; its investigation of PAY-6, PAY-7, PAY-8, FIN-12 and PAY-9 is kept below unchanged in substance.

What changed from the first Draft: the migration gains the floor in the invoice ceiling (PAY-11), the history producer and its event code (PAY-10), and a no-op guard on the derived converted amount; the link guard's message no longer prescribes zeroing; test 155 grows from 48 to 68 assertions; test 72 gains one harness flush; canon 27 and the smoke catalog pin move by one event type. PAY-6, PAY-7, PAY-8 and FIN-12's mechanism is unchanged.

### Selection
`scripts/batch6_select_target.ps1`, run at `1d25f40` on 2026-10-11 and recorded as the measured next target in SPEC-262's Complete entry, ranks `payment_allocations` first among the 38 surfaces still `NOT-RECORDED`: Exposure 8 (money column, two direct-write doors, one RPC), coverage 60. The runner-up is `receipts` at 7/20. Twelve pgTAP files mention the table. They prove the invoice ceiling (72), the invoice state an INSERT may target (89, 96), the capability on INSERT and on an amount change (68, 126), the creation events (38, 140) and the actor (87); none attacks an UPDATE of the allocation's link, its coherence with its own payment, its currency, two writers at once, or what an amount change leaves behind.

### Authority
- **Canon 24 (Payment Allocation)** and **canon 29**: an allocation belongs to exactly one invoice and exactly one payment; one payment may settle several invoices and one invoice may be paid by several payments; it records the exchange rate when the payment's currency differs from the invoice's.
- **Canon 31 (`payment_allocations`)**: `currency_code` is the currency the payment was actually made in; `exchange_rate_id` and `allocated_amount_invoice_currency` are populated only when the payment's currency differs from the invoice's; the sum per invoice, in the invoice's currency, must not exceed `total_amount`; and `partially_paid` and `paid` **are derived from the sum of this table's allocated amounts**.
- **Canon 26 (Invoice State Machine)**: `paid` has no outgoing transition and `partially_paid` none back to `issued`; "the precondition is the ALLOCATION, not the status word: `status_code` is derived from the amount".
- **Canon 27**: `payment_allocation_created` requires the invoice, the payment and the allocated amount.
- **Canon 30 (Financial Record Standard)** and **canon 07**: financial records must be auditable; corrections use an adjustment, a reversal, a new journal entry or an event; "do not overwrite approved financial actions silently". There is no DELETE grant on this table.
- **FA-2** (owner decision, ratified 2026-09-09, `20260909131000`, test 113): a payment in another currency is allowed only with explicit conversion evidence — an `exchange_rates` row for exactly that pair, in the tenant, positive and finite — with the converted value derived, never accepted.
- **FIN-10** (`202607057500`): an invoice cannot be paid more than it is worth, enforced at commit by `app.enforce_invoice_allocation_ceiling` on both tables, with no session-less exemption.
- **PAY-1** (`202607059500`): an allocation may target only an issued, partially paid or overdue invoice that is neither voided nor archived — enforced on INSERT only.
- **PAY-2** (SPEC-221): a payment's economic identity needs RECORD_PAYMENT on UPDATE; SPEC-221 left `payment_allocations`' amount-only mapping in place.
- **The event spine**: `public.events` is append-only (`events_append_only`); `app.record_event` refuses an unregistered code, takes the actor from the session (NULL on the platform path) and stamps the time server-side; `audit_read` already admits a `payment_allocation` event exactly to a reader of the allocation (WP-02).
- **The sole sanctioned writer, `app.record_payment`**: it charges RECORD_PAYMENT, serialises on `pg_advisory_xact_lock(hashtextextended(invoice_id::text, 0))`, writes a `customer_payment` of the invoice's customer and currency and one allocation of the same amount and currency, and derives `paid` / `partially_paid` from the allocated total.
- **`app.customer_balance`** derives a customer's paid amount from `payments`, by `payments.customer_id`, not from allocations.
- **Owner decision, 2026-10-11:** a payment allocation may settle only an invoice belonging to the payment's own customer. Third-party settlement needs its own explicit, auditable model and approved rules, and is not built.

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

Nothing compared an allocation with its payment. This is FIN-10's class from the payment's side, with FIN-10's grade.

### PAY-8 (Medium) — a currency difference was silent, and both ceilings counted it at face value
Measured at `1d25f40`:
- A 100 USD payment allocated to an EGP invoice with no exchange rate committed. The ceiling and `app.record_payment` both counted it as 100 EGP.
- A test on the unrepaired schema shows both directions: a 5000 EGP allocation that settles exactly a 100 USD invoice at 0.02 is refused (5000 > 100); and once 600 EGP plus 8 USD at 50 have filled a 1000 EGP invoice, `app.record_payment` still accepts more (it computes 392 outstanding).
- This is FA-2's owner-ratified rule ("never silently"), not yet applied to the table that canon makes carry the rate.

### FIN-12 (Medium) — the invoice ceiling had a race at the door
Measured at `1d25f40` with two live sessions: each allocated 600 to the same 1000 invoice at the table door and forced its deferred check before the other committed. Both checks passed and both transactions committed: 1200 against 1000. `app.record_payment` serialises on the invoice key; the ceiling trigger took no lock. SPP-6's grade.

### PAY-10 (Medium) — a corrected allocation left no trace of what it had been
Measured at `1d25f40`, rolled back. An owner holding RECORD_PAYMENT set an allocation from 600 to 0 at the table door. Comparing `pg_stat_xact_user_tables` before and after, the only write in the database was that row's own UPDATE: no event, no other table. Afterwards the 600, who removed it and when were unrecoverable:
- `payment_allocation_created` (WP-02) records the allocation's id, actor and time with a **null payload** — none of the invoice, payment and amount canon 27 requires of it;
- `payment_recorded` carries the payment's amount and names an invoice only when the payment settles exactly one; it is not the allocation's amount;
- no trigger on the table records an UPDATE, and no audit or history table exists.

Canon 30 forbids exactly this ("do not overwrite approved financial actions silently"), and the first Draft's refusal message prescribed zeroing as the correction. The gap predates this contract; the first Draft would have routed every correction through it.

### PAY-11 (Medium) — zeroing an allocation that settled an invoice stranded the invoice
Measured at `1d25f40`, rolled back. `app.record_payment` paid a 1000 invoice in full (`paid`). An owner then set that allocation to 0 at the table door. The invoice stayed `paid` with 0 allocated, and from that state:
- `app.record_payment` refused it ("only an issued/partially_paid/overdue invoice can be paid (is paid)");
- a new door allocation to it was refused with the same message (PAY-1);
- `paid -> issued` and `paid -> voided` were both refused by canon 26's machine.

The only exit was restoring the same allocation. Had the 1000 been reallocated elsewhere, the invoice would have read `paid` for ever while its customer owed it: excluded from collection, unpayable through the RPC, unvoidable. `app.customer_balance` stayed correct, because it reads payments. Canon 26 and 31 derive `paid` and `partially_paid` from the allocations and give neither a way back, so an allocation write that lowers the sum beneath what the status asserts is canon 26's forbidden backward transition made through the other door. A partially paid invoice zeroed to nothing is the same defect one state earlier.

### Is zero-and-reallocate a sound correction? The answer this contract gives
Two different properties were asked of it:
1. **The facts are preserved.** With PAY-10 repaired, yes. Every allocation is born with an event carrying its payment, invoice, currency, rate and both amounts, and every real change of its money is an event carrying the amounts before and after — attributed by `app.record_event` (a NULL actor marks the platform), timed by the server, append-only, readable exactly by readers of the allocation, and rolled back with any write that is refused. Allocations cannot be deleted by any API role. The whole correction — "600 created on IA; 600 → 0; 600 created on IC" — reads back from the events alone (test 155 assertion 52).
2. **The accounting stays true.** ORVION posts no journal from allocations and `app.customer_balance` reads payments, so moving money between a customer's invoices changes no ledger and no customer balance; the invoice outstanding derives from the allocations and is right after the move. The one stored fact an allocation can falsify is the invoice's derived status. Where no recorded status rests on the allocation — a door allocation, whose invoice status was never moved (PAY-5), or a reduction that leaves a `partially_paid` invoice with something allocated — zero-and-reallocate is sound and now fully recorded. Where a status does rest on it, the reduction is refused (PAY-11), because canon 26 defines no way to unsettle an invoice.

So a misapplied payment that has **settled** an invoice cannot be moved under this contract. Canon defines no unsettling transition; inventing one would be a business-policy decision, and deriving status on the door is FIN-7's (PAY-5). This is stated as a residual, not resolved here.

### PAY-9 (Medium, recorded OPEN, not repaired here) — a booking paid through `app.record_payment` still owes its full invoice in the booking-scoped balance
Measured at `1d25f40`, rolled back: an invoice on booking B1 was paid in full with `app.record_payment` and became `paid`. `app.customer_balance(C1, B1)` reported 1000 outstanding, while `app.customer_balance(C1)` reported 0. In booking mode it counts payments by `payments.booking_id`; `app.record_payment` leaves that column null (CONV-7's root cause); the link to the booking is the allocation. `app.enforce_booking_lifecycle` reads exactly this booking-scoped balance to decide whether issuing a booking charges ALLOW_ISSUE_WITH_NEGATIVE_BALANCE; read from its code, not exercised, issuing that fully paid booking would charge the override. `reporting.customer_outstanding` uses the customer-level call and is unaffected. It is a balance-model change with its own consumers (BOOK-12's open rule among them); with this contract an allocation becomes the trustworthy link that repair needs. **Latent:** Primary holds 0 bookings and 0 invoices. Reopening trigger: before the first production booking is issued.

### The repair
One migration, `20261011120000`:
- **`app.guard_payment_allocation_link()`**, the row-level BEFORE INSERT OR UPDATE trigger `payment_allocations_guard_link`, SECURITY DEFINER with an empty `search_path`, PUBLIC revoked, no session-less exemption.
  - On UPDATE it refuses (23514) any change to `id`, `tenant_id`, `payment_id`, `invoice_id`, `currency_code`, `exchange_rate_id`, `created_by` or `created_at` ("…fixed when it is written; only its amount can be corrected"). An UPDATE that leaves `allocated_amount` unchanged keeps the converted amount it was written with, even if its `exchange_rates` row has since been edited, and is otherwise judged no further.
  - On INSERT and on an amount change it applies FA-2's exact shape against the invoice's currency. **Same currency:** a rate is refused, and `allocated_amount_invoice_currency` is set null. **Different currency:** a rate is mandatory, in this tenant, converting exactly (allocation currency → invoice currency), positive and finite; `allocated_amount_invoice_currency := allocated_amount * rate` is derived and whatever the caller sent is discarded.
- **`app.enforce_payment_allocation_coherence()`**, same security, at commit through two DEFERRABLE INITIALLY DEFERRED constraint triggers: `payment_allocations_within_payment_amount` (AFTER INSERT OR UPDATE on the allocations) and `payments_amount_covers_allocations` (AFTER UPDATE on payments). It takes `pg_advisory_xact_lock(hashtextextended(payment_id::text, 0))` and, if the payment has any allocation, refuses (23514): a direction other than `customer_payment`; an allocation in another currency than the payment's; an allocation to an invoice of a customer other than the payment's (a null customer included); or a sum above the payment's amount.
- **`app.enforce_invoice_allocation_ceiling()`** keeps its two triggers. For an allocation write it first takes the invoice key `app.record_payment` takes; it sums `coalesce(allocated_amount_invoice_currency, allocated_amount)`; and, for an allocation write only, it refuses (23514) a sum below what the invoice's recorded status asserts — less than the total for `paid`, nothing for `partially_paid`. It moves no status.
- **`app.record_payment`** is replaced by its complete current definition with exactly one line changed: its already-allocated sum reads the same invoice-currency amount. Signature, SECURITY INVOKER, `search_path` and ACL are unchanged.
- **`app.emit_payment_allocation_event()`**, SECURITY DEFINER, empty `search_path`, PUBLIC revoked, the single producer of both allocation events through `app.record_event`. `payment_allocations_emit_created` (AFTER INSERT, the existing trigger name, re-pointed from the generic `app.emit_creation_event`) records `payment_allocation_created` (`info`) with `payment_id`, `invoice_id`, `currency_code`, `exchange_rate_id`, `allocated_amount` and `allocated_amount_invoice_currency`. The new `payment_allocations_emit_amount_changed` (AFTER UPDATE, WHEN either amount is distinct) records `payment_allocation_amount_changed` (`warning`) with the same keys plus `previous_allocated_amount` and `previous_allocated_amount_invoice_currency`. The code is registered in `catalog_values` at `sort_order` 935 (measured: 187 `event_type` rows, maximum 934).

No table, column, grant, policy, permission or state transition is added; `app.emit_creation_event` is unchanged for its other users.

### Rejected
- **Charging RECORD_PAYMENT for the link columns (PAY-2's shape).** It closes the employee door but not the owner's: a RECORD_PAYMENT holder could still move paid money onto a draft or voided invoice (PAY-1 is INSERT-only), or onto another customer's invoice.
- **Re-running PAY-1's state rule on UPDATE.** It closes the draft escape, but not cross-customer, cross-payment or currency re-points.
- **Revoking INSERT or UPDATE from `authenticated`.** Canon makes spreading one payment over several invoices a legitimate act and no RPC performs it; PAY-3 and PAY-5 recorded the door as legal. Revoking UPDATE alone would also remove the recorded amount correction SPEC-221 kept.
- **Refusing cross-currency allocation**, or **deriving the allocation's currency from the payment.** FA-2 permits it with evidence; refusing a mismatch is explicit where reinterpreting the number is silent.
- **A history table for allocations.** It would duplicate the append-only event spine every other financial fact already uses, with its own visibility rule to keep in step.
- **Immutable amounts with reversal rows.** It needs negative or linked reversal allocations, changes the sum read by the ceiling, the void guard, the coherence check, `app.record_payment` and `payments_emit_recorded`, and is a reversal framework this slice does not earn.
- **Recording amount changes in `previous_state` / `new_state`.** Those columns carry states; the amounts are money with a currency each, carried in the payload, where canon 30 permits non-predicate audit data.
- **Repairing PAY-11 by deriving the invoice status on the door.** It is PAY-5 / FIN-11's repair, which the FIN-7 invoice-state package owns, and unsettling a paid invoice needs transitions canon 26 does not define. The floor refuses; it moves nothing.
- **Refusing every amount reduction.** It would forbid the sound corrections — on a door allocation, or a partial reduction that stays partially paid — that the events now record.
- **Judging the floor on the invoice side too.** Which status the invoice door may declare is FIN-7's question; an issued invoice's total is frozen (INV-5).
- **Locking the invoice on invoice-side events.** There is no race there (INV-5, PAY-1), and the lock would open a deadlock against `app.record_payment`'s own invoice UPDATE.
- **SERIALIZABLE isolation.** A platform-wide change; PostgREST and every RPC run READ COMMITTED, where a lock taken in an earlier statement makes the later sum read the competitor's commit.
- **Repairing PAY-9 here**, and **a CHECK constraint** (it may reference only its own row).

### Held, recorded so a later slice does not rediscover it
- **Capability:** an employee is refused `permission denied: RECORD_PAYMENT` on INSERT and on an amount change (FIN-3), measured.
- **Deletion:** `anon`, `authenticated` and `service_role` hold no DELETE on the table. `service_role` holds TRUNCATE on every public table, which bypasses row triggers; it is the platform's backend key, outside the application's trust boundary by `202607050200`, recorded under PAR-5, and not this contract's.
- **Tenant:** another tenant's payment, invoice or rate is refused by the tenant-qualified foreign keys; the guard reads the rate within the tenant; `app.record_event` refuses an event outside the caller's tenant.
- **PAY-1 on INSERT**, unchanged. **Void:** `app.guard_invoice_void` refuses a void while money is allocated.
- **Balances:** `app.customer_balance` and `reporting.customer_outstanding` derive paid amounts from payments, so PAY-6 harmed invoice settlement, outstanding and collection, not the customer ledger.
- **Read scope:** an employee sees the allocations, and their events, of invoices on bookings they own — the invoice's read scope.
- **Event consumers:** the seven functions that read `public.events` (`app.customer_timeline`, `app.lead_timeline`, `app.map_outcomes_to_conversions`, `app.claim_conversion_deliveries`, `app.process_lead_sla` and the two credit-threshold evaluators) neither name `payment_allocation` nor read its payload; no edge function, script or client names either event.
- **Merge:** `app.merge_customer_identity` re-points a customer's invoices and payments in one transaction, so the commit-time customer rule sees them agree (test 155).

## Risks

- **Changed UPDATE semantics.** An allocation's payment, invoice, currency, rate and origin can no longer change, for any caller, the platform included. No function, script or test updates them today.
- **Changed INSERT and commit semantics at the door,** refused at commit for every caller: an allocation of a non-customer payment; in another currency than its payment's; to another customer's invoice or from a customer-less payment; one that makes a payment settle more than it is; a cross-currency allocation without its exact rate. `app.record_payment`'s allocation is coherent by construction and passes.
- **Payments that already settle invoices.** Shrinking one below what it settled, or changing its direction, currency or customer, is refused at commit. PAY-2 already required RECORD_PAYMENT for each.
- **Settled allocations cannot be reduced (PAY-11).** An allocation whose invoice is `paid` cannot be reduced, and the last money on a `partially_paid` invoice cannot be removed, for any caller. With PAY-7 this also means a payment recorded through `app.record_payment` that settled an invoice cannot be shrunk. No function, script or existing test does either. Correcting a misapplied payment on a settled invoice therefore has no path until canon defines one — see Notes.
- **History.** Every allocation INSERT and every real amount change writes one row to `public.events`; an UPDATE that changes no money, and any refused write, writes none. `payment_allocation_created`'s payload, previously null, now carries six keys; its event type, entity, actor and time are unchanged, and tests 38 and 140 pass unchanged.
- **Catalog.** `catalog_values` moves 622 → 623; `scripts/verify_database.sql` CHECK 6b and its banner move with it (one comment line explains the move), and the manifest's `71/622 catalog` becomes `71/623` from fresh readings.
- **Test 72's harness.** Assertion 12 raises a paid invoice's total on the platform path and forces every deferred check pending since `begin`, including the allocation checks of assertions 4–5's RPC payments. Judged against the raised total, those now meet the floor. One top-level flush after assertion 7 commits those payments where production would; the assertion's claim is unchanged, and the file passes 18/18 on both the unrepaired and the repaired schema.
- **Serialisation.** Allocation writers to one invoice, and to one payment, queue until the earlier commits. Two door transactions allocating to the same two invoices in opposite order can deadlock; PostgreSQL aborts one with 40P01, retryable, nothing written. A transaction at REPEATABLE READ is not protected by the lock; no ORVION client uses it.
- **The payments trigger inventory.** Test 126 assertion 23 pins the count of triggers on `payments`: 10 → 11, one line.
- **Owner decisions in force:** the same-customer clause is the owner's 2026-10-11 decision; assertions 18 and 19 and mutant M13 prove it.
- **Primary deployment** adds three functions and four triggers, re-points one trigger, replaces two function bodies, inserts one catalog row, and nothing else. It requires separate exact-byte owner authorization (Gate 2); approving this contract does not authorize it.
- **Workstation, not in scope:** resets for this contract run from the main checkout.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-264-an-allocation-spends-its-own-payment-on-its-own-invoice.md`
- `supabase/migrations/20261011120000_an_allocation_spends_its_own_payment_on_its_own_invoice.sql`
- `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql`
- `supabase/tests/126_payment_write_capability_parity_test.sql`
- `supabase/tests/72_invoice_allocation_ceiling_test.sql`
- `scripts/verify_database.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607042500_create_finance_transaction_tables.sql`
- `supabase/migrations/202607047100_record_payment.sql`
- `supabase/migrations/202607053400_wp02_class_a_events.sql`
- `supabase/migrations/202607057500_an_invoice_cannot_be_paid_more_than_it_is_worth.sql`
- `supabase/migrations/202607059500_money_allocated_to_an_invoice_that_was_never_issued.sql`
- `supabase/migrations/20260909131000_a_payment_in_another_currency_is_never_silent.sql`
- `supabase/migrations/20260925120000_payment_write_capability_parity.sql`
- `supabase/migrations/20260928180000_a_payment_is_recorded_on_every_door.sql`
- `supabase/tests/07_event_vocabulary_registry_test.sql`
- `supabase/tests/10_grant_model_test.sql`
- `supabase/tests/38_class_a_events_test.sql`
- `supabase/tests/68_financial_status_capability_test.sql`
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
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/29_relationship_map.md`
- `_ORVION_CANONICAL/30_database_conventions.md`
- `_ORVION_CANONICAL/31_schema_draft.md`
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
- `_ORVION_CANONICAL/24_entity_registry.md` (Payment Allocation); `_ORVION_CANONICAL/26_state_machines.md` (Invoice State Machine); `_ORVION_CANONICAL/27_event_catalog.md` (`payment_allocation_created`); `_ORVION_CANONICAL/29_relationship_map.md` (Invoice To Payment); `_ORVION_CANONICAL/30_database_conventions.md` (Financial Record Standard); `_ORVION_CANONICAL/31_schema_draft.md` (`payment_allocations`)
- `reports/master/MASTER_GAP_REGISTER.md` (FIN-10, FIN-11, PAY-1 to PAY-5, FA-2, CONV-7, BOOK-12, PAR-5); `reports/master/MASTER_SURFACE_DISPOSITION.md`; `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 method and EC-1…EC-11
- `supabase/migrations/202607053400_wp02_class_a_events.sql`; `supabase/migrations/202607057500_an_invoice_cannot_be_paid_more_than_it_is_worth.sql`; `supabase/migrations/20260909131000_a_payment_in_another_currency_is_never_silent.sql`; `supabase/migrations/20260928180000_a_payment_is_recorded_on_every_door.sql`
- Current local `app.record_payment`, `app.enforce_invoice_allocation_ceiling`, `app.guard_financial_capability`, `app.guard_parent_state_allows_write`, `app.guard_invoice_void`, `app.record_event`, `app.emit_creation_event`, `app.customer_balance`, `app.merge_customer_identity`
- Tests 07, 38, 72, 113, 126 and 140

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
| An allocation's payment, invoice, currency, rate and origin are fixed once written; an UPDATE leaving the amount alone keeps its converted amount | `scope_isolation` RLS; `app.guard_financial_capability`; `app.derive_created_by`; PAY-1's INSERT guard | WRITE | The prototype was the migration applied, with its ledger row, to a clean reset of the `1d25f40` local stack (250 migrations) from the main checkout; the files were held outside the repository. Migration SHA-256 `ee389adb2aff9253ad1f283805419a488696e579336da2b0e81b968749cc559f`, md5 `42e94bec60ab7a10b7de7f5bb76db807`, 26690 bytes, 493 LF lines, ASCII. The employee's re-points (invoice, payment, currency, creation time) and the owner's re-point onto a draft were refused 23514 with the guard's message; the employee's amount change was still refused 42501 by FIN-3's guard; assigning the fixed fields their own values succeeded, and a converted amount supplied on a same-currency INSERT or a no-op UPDATE was discarded. After a rate row was edited from 0.02 to 0.03, a no-op UPDATE of a 5000 EGP → 100 USD allocation left 100.0000 and recorded nothing; on the first Draft's bytes the same touch re-derived 150.0000 and was refused by the ceiling. No function, script or test updates the fixed columns (searched). |
| A payment's allocations must be of a customer payment, in its currency, for its own customer, and sum to no more than it, at commit, from both tables | `app.record_payment`; `app.merge_customer_identity`; `payments_guard_financial_capability` (PAY-2); `payments_guard_currency_conversion` (FA-2); `payments_emit_recorded` (PAY-3); tests 113, 126, 140 | WRITE | Before, as an owner with RECORD_PAYMENT: a 600 payment allocated 1600, a supplier payment settling a customer invoice, and an EGP payment's allocation in USD each committed. Prototype: each is refused 23514, as are a C2 payment settling C1's invoice and a customer-less payment's allocation; shrinking, redirecting, re-denominating or re-customering an allocated payment is refused; growing it succeeds. `app.record_payment`'s partial and full payments, a door split and a zero-and-reallocate correction on an issued invoice pass. Merging C2 into C1 after both were paid commits. Tests 113, 126 (as edited) and 140 pass. |
| A cross-currency allocation needs its exact rate and its invoice-currency value is derived (FA-2) | `public.exchange_rates`; the invoice ceiling; `app.record_payment` | WRITE | Before: 100 USD to an EGP invoice with no rate committed and counted as 100 EGP. Prototype: refused without a rate, with the inverse pair, with another tenant's rate; a rate on a same-currency allocation is refused; 8 USD at 50 stores 400.0000; 5000 EGP at 0.02 settles a 100 USD invoice exactly; an amount corrected to 0 re-derives 0. |
| The invoice ceiling is serialised with `app.record_payment`, counted in the invoice's currency, and floored by the invoice's recorded status after an allocation write | `invoices_total_covers_allocations`; `app.guard_invoice_void`; `app.record_payment`; test 72 | WRITE | Before (PAY-11), zeroing the allocation of a paid 1000 invoice left it `paid` on 0 and every door refused it afterwards. Prototype: zeroing it, or reducing it by 0.0001, is refused for a signed-in owner and on the platform path, and the invoice stays `paid` on 1000; a `partially_paid` invoice's 400 reduces to 100 and cannot reach 0; a door allocation on an issued invoice is zeroed and reallocated. Races on the final bytes, each on a dedicated tenant deleted afterwards, the second session observed waiting on the advisory lock: two 600 door allocations to one 1000 invoice — the second refused, 1200 > 1000, 600 committed; one 600 payment allocated 400 twice — the second refused, 800 > 600, 400 committed; two sessions each removing one of a `partially_paid` invoice's two 300 allocations — the second refused, 300 left. With only the invoice lock removed (and its exact text restored afterwards, md5 `bf4357fa510e71f7649813027dce21b8` before and after), both removals committed and the invoice read `partially_paid` on 0: the lock is what holds the floor. Test 72, with its one harness flush, passes 18/18 on the unrepaired and the repaired schema; unedited, it fails only assertion 12 on the prototype, as described in Risks. |
| Allocation history: one producer for `payment_allocation_created` (now with its canon 27 facts) and `payment_allocation_amount_changed` (new) | `public.events` (`events_append_only`); `app.record_event`; `audit_read`; the seven event readers; `app.map_outcomes_to_conversions`; tests 07, 38, 140 | WRITE | Before (PAY-10): an owner's 600 → 0 wrote only the row (`pg_stat_xact_user_tables`), and the creation event's payload was null. Prototype: a door allocation and each of `app.record_payment`'s two allocations are born with exactly one event carrying payment, invoice, currency, rate and both amounts, by their actor; a correction records `warning` with both amounts before and after in both currencies; the IA → IC move reads back from the events alone; a no-op UPDATE and every refused write record nothing (eight events for six allocations and two corrections); a platform correction records a NULL actor; the employee reads exactly the events of allocations they can read. None of the seven functions reading `public.events` names `payment_allocation` or reads its payload; `map_outcomes_to_conversions` maps `payment_recorded` only. Test 07 counts the new code as produced; tests 38 and 140 pass unchanged. |
| The event code is registered, documented and counted | `catalog_values`; `_ORVION_CANONICAL/27_event_catalog.md`; `scripts/verify_database.sql` CHECK 6b; the manifest's catalog figure | WRITE | `catalog_values` 622 → 623 (`event_type` 187 → 188, `sort_order` 935); `catalog_types` stays 71. Canon 27 (stored LF; committed blob `7036c9c8…`, SHA-256 `ee1c3794de418088f9ebd9bc8c55b6089b171b3e84fb1b78b3f1a41173cd2444`, 16163 bytes) gains one nine-line entry after `payment_allocation_created`, giving SHA-256 `ced9d93bbce5335b25b89d35709d79b51f0c3a0fcec08f680cd0c01fb2c0b79b`, 16289 bytes. `verify_database.sql` (SHA-256 `33c0cfdb3e5ac09c88109bb98a4c081483feb32220993b28438b41bd0187be7f`, 14142 bytes) moves its banner, CHECK 6b and notice from 622 to 623 with a three-line comment, giving SHA-256 `8cd405c61317bc9a425797ed0f4178d8b420076d2134c7820d4babaeed9c6092`, 14432 bytes; on the prototype it reports `ALL CHECKS PASSED (… 71/623 catalog, …)`. |
| `app.record_payment`'s already-allocated sum reads the invoice-currency amount (one line) | the three declared HTTP suites; the API contract | WRITE | The function is otherwise byte-identical to its `20260928180000` definition. After 600 EGP plus 8 USD at 50 filled a 1000 EGP invoice, the RPC refused 0.0001 ("exceeds invoice outstanding 0.0000"); at face value it computed 392 and accepted. On the prototype the three HTTP suites pass: 35/0, 85/0, 122/0. |
| The payments trigger inventory grows by one | `126_payment_write_capability_parity_test.sql` assertion 23 | WRITE | SHA-256 `618d3eab8ae51f9204670c80db776a83a5c953e83baa7f8c007381b078964203`, 15296 bytes → `f90fcd2a7f0746412b315e04ff85551d037f5efbbb92471a67c67f700cf03de4`, 15326 bytes: `10,` → `11,` and PAY-7's check named in the description. Unedited, it fails only assertion 23 on the prototype; edited, 33/33. Its amount-only `payment_allocations` mapping (assertion 24) is unchanged and still true. |
| Test 72's pending-check harness | `72_invoice_allocation_ceiling_test.sql` | WRITE | Committed blob `82a4cf56…`, SHA-256 `b430e2421bc64fe31967a1cb339862ce85a3acd1b7081b2597ec1d9d513941b7`, 15278 bytes (LF) → SHA-256 `3ad92d5e0b3c3cf8077876a7ef3e56a0b06ed2ced039eaa1ac37ab6247835c57`, 15739 bytes: seven lines after assertion 7 — one blank, four comment lines, `set constraints all immediate;` and `set constraints all deferred;`. No assertion, plan or expected value changes. 18/18 on the `1d25f40` schema and on the prototype. |
| Test 155 | `supabase/tests` | WRITE | SHA-256 `86cadadd2a486fe402eca680f1f3276e606328fca2c2b9d02f9598965316cdc7`, md5 `92b8c64cb94bd353ab505f965e1ed390`, `plan(68)`, 44771 bytes, 506 LF lines, ASCII: 68/68 on the prototype. On the unrepaired `1d25f40` schema all 68 run and 50 fail, each for its intended reason: 4, 7, 8, 9, 10, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 25, 26, 27, 28, 29, 31, 32, 33, 34, 36, 38, 43–57, 59, 60, 61, 63, 64, 65, 66, 67. On the first Draft's migration (`7da89123…`) 44 pass, 20 fail (7, 8, 9, 10, 14, 45, 49–57, 59, 60, 61, 63, 64) and 65–68 never run: the rate-drift touch is refused by the ceiling and aborts the transaction. |
| Other tests reading this table, its functions or the events | tests 07, 10, 38, 68, 73, 87, 88, 89, 96, 110, 113, 140 | VERIFY | Each passes unchanged on the prototype, inside the full runs below. |
| The generated API contract | `MASTER_API_CONTRACT.md` | WRITE | The canonical generator against the prototype is byte-identical to the committed contract (SHA-256 `d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`). Step 7 regenerates it, and it stays unchanged. |
| Suite and smoke | full pgTAP; `scripts/verify_database.sql` | VERIFY | On the prototype, after a clean reset from the main checkout: Pass A ran all 155 files and failed only test 72 assertion 12 (the harness case above, before its flush); the three declared HTTP suites passed; Pass B, without reset, 155 files / 2936 assertions (2868 + 68), 0 failed; a final run on the exact final test bytes, 155 files / 2936, 0 failed. Smoke with the edited script: `ALL CHECKS PASSED (78 tables, … 71/623 catalog, …)`. The other three HTTP suites call no payment RPC and write no payment or allocation, and are not declared. |
| Structural surface on Primary | `scripts/parity_surface.sql`; `primary-ledger-evidence.json` | WRITE | The `1d25f40` local stack equals the recorded Primary values (250 migrations, `24b8778b6d9e955a8472affb07712858`; functions `3d7eb4e3550f7cec15815defb600272d`/326; triggers `61f9789b320a4eb988542b83beee36ca`/312; constraints `cea733efe840d1579bc55f541de54c2d`/525; combined `a23669c9c5c31f56bed4f7e8d265c534`/3121). With the migration: functions `708dbe893149ea2b97e6893fea449925`/329, triggers `c6f7bb53f0f58500d026259b6e53b96d`/316, constraints `e669286c961025cb49688862286338ed`/527, combined `76c930988563bd06f86c65e429fdb8fc`/3130. Policies `b67d466a…`/125, grants `6727f6d8…`/189, columns `448db887…`/1134, views `10bb212a…`/16, indexes `22a4d58c…`/300, status transitions `db2165c7…`/115 and RLS `c117cbf7…`/79 are unchanged. The 251-row ledger fingerprint is `f678a3ef5790582c39635136c8aa202d`. |
| Measured state that moves | manifest (`Live state`, catalog figure, suite figure, coverage, Last Completed, Current Module, Next capability); `primary-ledger-evidence.json`; `ai-map.json` | WRITE | 250 → 251 migrations, latest `20261011120000`; catalog 71/622 → 71/623; 154 → 155 files and 2868 → 2936 assertions; coverage 40 → 41 of 78. HTTP (464), tables (78), views (8) and client RPCs (80) do not move. Primary values are written only from fresh post-deploy readings. |
| PAY-6, PAY-7, PAY-8, FIN-12, PAY-10, PAY-11 fixed; PAY-9 recorded; the surface `AUDITED-OPEN` | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 21, 22, 24, 25 | WRITE | PAY-9, PAY-10, PAY-11 and FIN-12 are unused on `origin/main` `1d25f40`. Test 155's `-- ATTACK-CLASSES:` line and negative assertions satisfy Check 24. Every new row's Owner field is `—` (the same-customer clause is cited as the owner's decision in the evidence, not as a pending decider), so Check 25 reads no owner decision. The row stays `AUDITED-OPEN` on PAY-5 and FIN-11, which are unchanged. Coverage becomes 41 recorded: 17 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 37 `NOT-RECORDED`. Step 4 runs Checks 21 to 25 on the applied edits. |
| CI-only guard self-tests and repository consistency | `scripts/test_*_guard.ps1` (four); `scripts/check_repository_consistency.ps1` | VERIFY | At `1d25f40` all four pass: cold-start 34/0, future-date 18/0, primary-ledger 13/0, status-contradiction 33/0. Predicted from SPEC-262's identical shape, and measured at Step 4: before deployment, repository consistency reports exactly the measured-state drift — 250 vs 251 migrations; latest `20261011090000` vs `20261011120000`; ledger `24b8778b…` vs `f678a3ef…`; 154 vs 155 test files; 2868 vs 2936 assertions; RECOVER-1 ledger evidence — and the primary-ledger and cold-start self-tests fail only their CONTROL and restore cases because of it. These are not waived: Step 7 makes them true, and Step 8 requires them green. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the declared HTTP suites, smoke, mutation proof and the three two-session races | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| PAY-6, PAY-7, PAY-8, FIN-12, PAY-10, PAY-11, PAY-9 and the disposition describe the local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite, catalog and coverage figures equal the files, the stack and the disposition record | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| The four CI-only guard self-tests pass | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: NO

Existing Mechanism: `app.guard_financial_capability` charges RECORD_PAYMENT on INSERT and on a change of `allocated_amount`, and nothing else. `app.guard_parent_state_allows_write` judges the invoice's state on INSERT only. `app.enforce_invoice_allocation_ceiling` caps the invoice total at commit, but takes no lock, counts face value and has no floor. `payments_guard_currency_conversion` applies FA-2 to a payment's account, not to an allocation's invoice. Nothing compares an allocation with its payment. `app.emit_creation_event` records an allocation's birth with no payload, and nothing records a change. Only `app.record_payment` writes a coherent allocation, by construction. This contract reuses the ceiling function, FA-2's exact rule and messages, the advisory key `app.record_payment` takes, the existing foreign keys, RLS, capability guard and event visibility branch, `app.record_event` and the append-only event spine, and FIN-8 and FIN-10's deferred constraint-trigger idiom. No shared allocation framework, history table or reversal mechanism is earned.

Added Property: Once written, an allocation keeps its payment, invoice, currency, rate and origin for every caller, and an UPDATE that leaves its amount alone changes no money. A different currency from the invoice's requires the exact rate, and the invoice-currency value is derived. At commit, a payment's allocations are of a customer payment, in its currency, for its own customer, and never more than it, judged when either side changes. After an allocation write, an invoice's allocations, in its own currency, lie between what its recorded status asserts and its total. Both ceilings serialise their writers per invoice and per payment. `app.record_payment` reads the same invoice-currency total. Every allocation and every real change of its money is one event with its facts, actor and time.

Causal Negative: These are the pre-repair measurements in Business Reason, at `1d25f40`:
- the employee's re-points (C1's allocation to C2's invoice, to a draft, onto a supplier payment, to USD, converted amount set) and the owner's re-point onto a draft, with the downstream double collection and refused genuine payment;
- the owner's 600 payment allocated 1600, a supplier payment settling a customer invoice, and a USD allocation of an EGP payment;
- 100 USD counted as 100 EGP;
- 1200 committed against a 1000 invoice by two sessions;
- 600 → 0 written with no other write and no event; a creation event with a null payload;
- a paid invoice left `paid` on 0 and refused by every door.

On the unrepaired schema test 155 runs all 68 assertions and fails 50, each for its intended reason: 4, 7, 8, 9, 10, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 25, 26, 27, 28, 29, 31, 32, 33, 34, 36, 38, 43–57, 59, 60, 61, 63, 64, 65, 66 and 67. The causes are:
- no exception where 23514 was required;
- 23503 from the foreign key where the guard's tenant message was required;
- a supplied converted amount kept, or not derived;
- a legitimate 5000 EGP → 100 USD allocation refused at face value, and `app.record_payment` accepting 0.0001 at face value;
- the state the unrepaired re-points and zeroings left behind;
- no event, or an event without its facts;
- the triggers, locks and event code absent.

Positive Test Design: One tenant has an owner and an employee who owns two bookings, of customers C1 and C2. There are five invoices — C1's IA, IC, ID (draft until assertion 58) and IU (USD), and C2's IB — and six payments: C1 EGP 600, a supplier payment, C1 USD 100, C2 EGP 1000, a customer-less EGP 100 and C1 EGP 5000; two in-tenant rates; and a rival tenant with its own payment and rate. Positive controls:
- a door allocation of C1's payment to C1's invoice passes both commit checks, and a converted amount it names is discarded;
- a no-op UPDATE succeeds and records nothing;
- 8 USD at 50 is stored with 400 EGP derived, and 5000 EGP at 0.02 settles the 100 USD invoice exactly;
- RECORD_PAYMENT corrects an amount on an issued invoice, the converted amount follows, and the change is recorded with both amounts;
- the zero-and-reallocate correction moves C1's 600 from IA to IC, both rows kept and both read back from the events;
- a payment can grow; `app.record_payment` takes a partial payment and the balance, derives `paid`, and its allocations are each born with one event;
- a `partially_paid` invoice's allocation is reduced from 400 to 100;
- a platform correction on an issued invoice commits and is recorded with a NULL actor;
- merging C2 into C1 commits and leaves no cross-customer allocation;
- the employee reads the history of exactly the allocations they can read.

Negative Test Design:
- **Link:** the employee's re-point of invoice, payment, currency and creation time, and the owner's re-point onto a draft, are refused 23514. A session-less re-point is refused too.
- **Capability (held):** the employee's amount change is refused 42501 `permission denied: RECORD_PAYMENT`.
- **Payment coherence:** each refused 23514 with its own message — over-spending a payment (also session-less), a supplier payment even at zero, an allocation in another currency than its payment's even with a valid rate, another customer's payment, a customer-less payment.
- **Payment side:** shrinking, redirecting, re-denominating or re-customering an allocated payment is refused 23514, and the payment is unchanged afterwards.
- **Currency evidence:** no rate, the inverse pair, a rate on a same-currency allocation and another tenant's rate are each refused 23514 with FA-2's messages. Another tenant's payment is refused 23503.
- **Floor:** zeroing IB's settling allocation, and reducing it by 0.0001, are refused 23514 for the owner and on the platform path, leaving IB `paid` on 1000; removing ID's last 100 is refused; no status moves.
- **History:** refused writes leave no event; a no-op leaves none; after a rate row is edited, a no-op touch changes no money and records nothing.
- **Concurrency:** the invoice's and the payment's advisory locks are held by the writing backend after an allocation write, read from `pg_locks`. The three two-session races are recorded above.

Non-Empty Population Obligation: The tenant has two users with their roles, two customers, two bookings, five invoices, six payments and two rates; the rival tenant has its own payment and rate. Every allocation, refusal, lock and event is counted by row id, invoice or exact message; no zero-row operation satisfies an assertion. Assertion 6 proves the employee sees exactly one allocation and no payment before any UPDATE; assertion 54 proves exactly eight allocation events exist before the floor section; assertion 66 proves the employee reads eleven.

Mutation Obligation: Out of file, record a surface: the md5 of the five functions' definitions with every trigger definition on both tables. For each mutant:
1. Install it inside test 155's own transaction, against the migration, and prove the surface differs.
2. Run test 155 and record the failing assertions.
3. Prove after the rollback that the live surface equals the pre-run surface.

A mutant whose installation is not proven is a harness error, never a kill.

| Mutant | Change | Failed on the prototype |
| --- | --- | --- |
| M1 | the UPDATE immutability arm removed | 7–10, 12–15, 18, 19, 25–46, 49–66 |
| M2 | `invoice_id` left out of the immutable set | 7, 12, 13, 14, 32, 38, 45, 52, 54, 58–61, 66 |
| M3 | `payment_id` left out | 8, 12, 13, 15, 17–19, 25–46, 49–66 |
| M4 | `currency_code` left out | 9, 12, 13, 15, 16, 18, 19, 25, 27, 29, 37, 38, 44, 45, 46, 52, 53, 54, 60, 63, 66 |
| M5 | `created_at` left out | 10 |
| M6 | a same-currency converted amount kept | 4, 13, 32, 38, 54, 60, 66 |
| M7 | a cross-currency allocation allowed without a rate | 20 |
| M8 | the rate-pair check removed | 21, 30, 31, 32, 36, 38, 51, 60 |
| M9 | a rate on a same-currency allocation allowed | 22, 54, 66 |
| M10 | the converted amount not derived | 31–34, 36, 38, 49, 51, 60, 65 |
| M11 | the direction check removed | 16, 26 |
| M12 | the payment-currency check removed | 17, 27, 29, 54, 66 |
| M13 | the customer check removed | 18, 19, 28, 30, 31, 32, 36, 38, 43, 51, 54, 60, 66 |
| M14 | the payment-amount check removed | 15, 25, 29, 38, 44, 54, 60, 66 |
| M15 | the payments-side trigger dropped | 25–29, 37, 38, 44, 45, 46, 48, 52, 53, 54, 60, 63, 66 |
| M16 | the allocations-side coherence trigger dropped | 15–19, 25, 28–32, 36, 38, 39, 43, 44, 47, 48, 50, 51, 54, 60, 66 |
| M17 | the invoice lock removed | 46 |
| M18 | the payment lock removed | 47 |
| M19 | the ceiling sums face value | 33, 34, 49, 54, 65, 66 |
| M20 | `app.record_payment` sums face value | 32, 33, 34, 38, 49, 60, 65 |
| M21 | a session-less exemption in the coherence check | 44, 54, 60, 66 |
| M22 | a session-less exemption in the immutability arm | 45, 60, 65, 66 |
| M23 | the rate read without the tenant | 23 |
| M24 | the link guard dropped | 4, 7–10, 12–15, 18–23, 25, 29–46, 48–66 |
| M25 | the amount-change event trigger dropped | 51–54, 61, 63, 66, 67 |
| M26 | the amount-change trigger fires on every UPDATE | 52, 53, 54, 65, 66, 67 |
| M27 | the allocated amount left out of the event payload | 49, 50, 51, 52, 61, 63 |
| M28 | the previous amount recorded as the new one | 51, 52, 61, 63 |
| M29 | the creation event returned to the generic, payload-less producer | 49, 50, 51, 52, 61, 67 |
| M30 | the `paid` floor removed | 55, 56, 57, 60, 64, 66 |
| M31 | the `partially_paid` floor removed | 59, 60, 61, 66 |
| M32 | a session-less exemption in the floor | 64, 66 |
| M33 | a no-op UPDATE re-derives the converted amount | 65, 66 |
| M34 | the change event recorded as `info` | 51, 61 |
| M35 | the `partially_paid` floor admits 0 (`< 0`) | 59, 60, 61, 66 |
| M36 | the `paid` floor tolerates 0.0001 | 56, 57, 60, 64, 66 |
| M37 | a session-less exemption in the event producer | 63, 66 |

Prototype result: the live surface was `919a84f1159bc0c9c0f112ee6e7d69ef` before and after the run, every installation changed the surface, and all thirty-seven were killed, as listed. Three harness defects were found and fixed before this result: the fixture's deferred PAY-3 events fired under a signed-in caller; an earlier statement's unflushed deferred check made assertions 25–28 pass under M15 for the wrong reason (every positive step now forces its own deferred checks); and M6 survived the first run of the revised file, because a no-op UPDATE no longer reaches the same-currency branch — assertion 3 now names a converted amount on INSERT, and assertion 4 proves it discarded.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused test, a clean reset from the main checkout, pgTAP Pass A, the declared HTTP suites, pgTAP Pass B and smoke;
- the out-of-file mutations M1–M37, the pre-repair causal negative and the three two-session races, with the floor race's lock-removed negative control;
- the generated artifacts, the four CI-only guard self-tests, repository consistency and `git diff --check`;
- fresh Primary evidence, parity evidence and the Primary ledger check.

## Implementation Steps

1. **Check** that `supabase/migrations/20261011120000_an_allocation_spends_its_own_payment_on_its_own_invoice.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `ee389adb2aff9253ad1f283805419a488696e579336da2b0e81b968749cc559f`, md5 `42e94bec60ab7a10b7de7f5bb76db807`, 26690 bytes.
   - Its statements, after a comment block stating the authority and the measurements: create `app.guard_payment_allocation_link()` with its BEFORE INSERT OR UPDATE trigger `payment_allocations_guard_link`; create `app.enforce_payment_allocation_coherence()` with its deferred constraint triggers `payment_allocations_within_payment_amount` and `payments_amount_covers_allocations`; replace `app.enforce_invoice_allocation_ceiling()` with the allocation-write lock, the invoice-currency sum and the floor; replace `app.record_payment(...)` with its one changed line; register `payment_allocation_amount_changed`; create `app.emit_payment_allocation_event()`; re-create `payment_allocations_emit_created` on it and create `payment_allocations_emit_amount_changed`. Every new function has PUBLIC revoked.
   - If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/155_an_allocation_spends_its_own_payment_on_its_own_invoice_test.sql` is absent.
   - If absent, create it LF and ASCII, byte-identical to the prototype: SHA-256 `86cadadd2a486fe402eca680f1f3276e606328fca2c2b9d02f9598965316cdc7`, `select plan(68);`. Its `-- ATTACK-CLASSES:` line reads `AUTH TENANT DOOR STATE INPUT BUSINESS PRIVILEGE CONCURRENCY OBSERVABILITY REPLAY=N/A`, with the `N/A` reason in its header.
   - In `supabase/tests/126_payment_write_capability_parity_test.sql`, change only assertion 23's expected count from `10` to `11` and its description to name PAY-7's allocation check, giving SHA-256 `f90fcd2a7f0746412b315e04ff85551d037f5efbbb92471a67c67f700cf03de4`.
   - In `supabase/tests/72_invoice_allocation_ceiling_test.sql`, stored LF, insert after assertion 7's closing line only the seven lines described in Consumer Closure, giving SHA-256 `3ad92d5e0b3c3cf8077876a7ef3e56a0b06ed2ced039eaa1ac37ab6247835c57`.
   - In `scripts/verify_database.sql`, change only the banner's `622 catalog`, CHECK 6b's expected `622` (with its three-line comment) and the notice's `71/622`, giving SHA-256 `8cd405c61317bc9a425797ed0f4178d8b420076d2134c7820d4babaeed9c6092`.
   - In `_ORVION_CANONICAL/27_event_catalog.md`, stored LF, insert after `payment_allocation_created`'s `- Allocated amount` line only: a blank line, `## payment_allocation_amount_changed`, a blank line, `Severity: warning`, a blank line, `Requires:`, a blank line, `- Payment allocation`, `- Allocated amount before and after`; giving SHA-256 `ced9d93bbce5335b25b89d35709d79b51f0c3a0fcec08f680cd0c01fb2c0b79b`.
   - If a target carries content other than its `1d25f40` bytes or its frozen value, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` already contains a `PAY-6` row. If not, make these edits and nothing else:
   - **Register:**
     - a 2026-10-11 Slice-40 freshness entry, with the previous one demoted to `Previously:`;
     - after PAY-5, new rows PAY-6 (High), PAY-7 (High), PAY-8 (Medium), PAY-10 (Medium) and PAY-11 (Medium), each FIXED by SPEC-264 locally with Primary pending and Cert `🛡`, with the measurements above;
     - after them, a new row PAY-9 (Medium), OPEN, with the measurement, its cause, its latency and its reopening trigger as stated above;
     - after FIN-11, a new row FIN-12 (Medium), FIXED by SPEC-264 locally with Primary pending and Cert `🛡`, with the two-session measurement;
     - PAY-11's row names the residual — a misapplied payment that settled an invoice has no correction path until canon defines one — and points to PAY-5 / FIN-7;
     - every new row with Owner `—` and this contract as session.
   - **Disposition:**
     - a freshness entry, with the previous one demoted;
     - coverage 41 of 78 (17 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL`, 0 `EXEMPT`, 37 `NOT-RECORDED`) and the "All 41" line;
     - the `payment_allocations` row `AUDITED-OPEN` / `ADVERSARIAL` / SPEC-264 / PAY-6, PAY-7, PAY-8, FIN-12, PAY-10, PAY-11, PAY-5, FIN-11, with its evidence, its swept non-defects and PAY-9's pointer.

   If a target carries content other than its `1d25f40` bytes, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 values:
   - a clean local reset from the main checkout; test 155 and the focused tests 07, 10, 38, 68, 72, 87, 88, 89, 96, 110, 113, 126 and 140;
   - pgTAP Pass A, the three declared HTTP suites, then pgTAP Pass B without reset; smoke and the plan sum;
   - the mutation evidence M1–M37, the causal negative, and the three two-session races on a dedicated tenant deleted afterwards, with the floor race's lock-removed negative control and the exact restoration of the function;
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
   - the `event_type` catalog count and the absence of `payment_allocation_amount_changed`;
   - the tenant, invoice, payment, allocation and event counts.

   Record the predicted delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present the Gate-2 package. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20261011120000_an_allocation_spends_its_own_payment_on_its_own_invoice`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts, both tables' triggers and both replaced functions' md5.
   - On an exact match, prove the transmitted text's md5 server-side, then apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces; both tables' triggers; the five functions' definitions, security modes and ACLs; the catalog count; the business counts.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`, set `Live state` from the same readings, with the catalog figure `71/623` and 464 HTTP assertions unchanged.
   - Confirm that `supabase/tests` holds 155 files whose literal `plan(N)` values sum to 2936, then set `Suite **155 files / 2936 assertions**`. If either differs, stop.
   - Set Batch 6 coverage to 41 of 78, all forty-one at `ADVERSARIAL`.
   - Mark PAY-6, PAY-7, PAY-8, FIN-12, PAY-10 and PAY-11 `DEPLOYED` with Cert `✅`, worded without a date beneath the register's freshness line.
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

- [x] An allocation's payment, invoice, currency, rate, creator and creation time cannot be changed by any caller (23514), the platform included. The employee's amount change is still refused 42501. Assigning the fixed fields their own values succeeds; a supplied converted amount is discarded; an UPDATE that leaves the amount alone keeps the converted amount it was written with.
- [x] At commit, an allocation of a non-customer payment, in a currency other than its payment's, to another customer's invoice, from a customer-less payment, or beyond its payment's amount is refused (23514), for every caller. An allocated payment cannot shrink below, redirect, re-denominate or re-customer beneath its allocations. Growing a payment succeeds.
- [x] A cross-currency allocation requires an exchange rate in the tenant for exactly its pair, positive and finite, and stores the derived invoice-currency value. A same-currency allocation carries neither (23514 for a rate).
- [x] The invoice ceiling counts each allocation in the invoice's currency, and an allocation write takes the invoice's advisory lock (the key `app.record_payment` takes) and the payment's. Two concurrent door allocations cannot together exceed an invoice or a payment.
- [x] After an allocation write, a `paid` invoice's allocations cannot total less than its total and a `partially_paid` invoice's cannot total nothing (23514), for every caller and under concurrency; no invoice status is moved by this contract.
- [x] Every allocation is born with exactly one `payment_allocation_created` event carrying its payment, invoice, currency, rate and both amounts, and every real change of its amounts records exactly one `payment_allocation_amount_changed` (`warning`) with both amounts before and after, its actor (NULL on the platform path) and its time, on the RPC and the door alike. A no-op UPDATE and a refused write record nothing. The code is registered, in canon 27, and counted by smoke.
- [x] `app.record_payment` differs from its `20260928180000` definition only in its already-allocated sum reading the invoice-currency amount. It keeps its signature, security mode, `search_path` and ACL; its partial and full payments and its `paid` derivation are unchanged.
- [x] The held controls stay held: PAY-1 on INSERT, FIN-3's capability, the tenant-qualified foreign keys, the void guard, no DELETE grant, and a customer merge with allocated payments.
- [x] Mutants M1–M37 are each killed against test 155, with installation and restoration proven. The causal negative, the three two-session races and the floor race's lock-removed negative control are recorded.
- [x] Test 126 changes only assertion 23's expected count (10 → 11) and description; test 72 gains only its seven-line harness flush; `verify_database.sql` moves only its catalog pin to 623; canon 27 gains only the one entry.
- [x] PAY-6, PAY-7, PAY-8, FIN-12, PAY-10 and PAY-11 are fixed and deployed in the register, and PAY-9 is recorded OPEN with its trigger. PAY-1 to PAY-5, FIN-10 and FIN-11 are unchanged.
- [x] `payment_allocations` is `AUDITED-OPEN` / `ADVERSARIAL` in the disposition record, and coverage is 41 of 78. No other surface's row changed.
- [x] The migration, test 155, test 126, test 72, `verify_database.sql` and canon 27 matched their frozen SHA-256 values when applied.
- [x] Primary, the recorded evidence, the manifest (251 migrations; 71/623 catalog; 155 files / 2936 assertions; 464 HTTP assertions), the API contract and `ai-map.json` agree. The four CI-only guard self-tests and repository consistency pass.
- [x] The manifest names Batch 6 Slice 41 and its measured target as the next capability, with no Active Change Request.
- [x] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [x] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-10-11 — Gate 1 approval and execution started

- **Authority:** the owner's SPEC-264 revised-Draft approval (2026-10-11). It approves Gate 1 for Draft `cd5f7f420b50d68840ef74832a1ce221d2b35b98`, contract SHA-256 `8cdfb5e1c65ce2c2dc19bd0c6ea81cc5c98f933b61a082a440ef294451c695ba`, to close PAY-6, PAY-7, PAY-8, FIN-12, PAY-10 and PAY-11, keeps the owner's same-customer decision, and accepts the settled-state floor without establishing any policy for unsettling an invoice. The first Draft's identities are superseded and its authorizations unused. Verified before acting:
  - HEAD was the Draft commit, 2 ahead of and 0 behind `origin/main` `1d25f40`, with 0 merges, and the working tree was clean;
  - the contract file and its committed blob both hash to the approved value (71340 bytes);
  - the frozen prototype files in the scratchpad `s40` hash to their Step 1–2 values, LF with 0 CR: migration `ee389adb…` (MD5 `42e94bec…`, 26690 bytes), test 155 `86cadadd…` (44771 bytes), test 126 `f90fcd2a…` (15326 bytes), test 72 `3ad92d5e…` (15739 bytes), `verify_database.sql` `8cd405c6…` (14432 bytes), canon 27 `ced9d93b…` (16289 bytes);
  - the four edited files' committed bases are their `1d25f40` bytes: test 126 `618d3eab…`, test 72 `b430e242…`, `verify_database.sql` `33c0cfdb…`, canon 27 `ee1c3794…`;
  - Write Scope is the thirteen paths above.

  Approval was committed at `59bf144`; its pre-commit Gate returned `APPROVAL_EVIDENCE: PASS`.
- **Preconditions:** the migration and test 155 are absent.
- **Worktrees.** A read-only inventory; nothing was modified.
  - `wt251` is clean at `578f3fb`, and `owt/p2` is clean at `7fe62ed`.
  - `wt255` at `33e4db6` has 6 entries, `wt260` at `e26733a` has 4, `wt261` at `39ab45a` has 6, and `C:\w234` at `6c48fbb` has 15.

  All stay untouched.
- **Gate 2 stands before Step 6.** The same approval grants a separate, advance, one-time, exact-byte Gate 2 for migration `20261011120000_an_allocation_spends_its_own_payment_on_its_own_invoice.sql`, SHA-256 `ee389adb2aff9253ad1f283805419a488696e579336da2b0e81b968749cc559f` (26690 bytes, LF), to Primary `vrvtsxexkiiiivlkdxzp` only, conditional on the frozen artifact identities, a fresh Primary baseline with the migration absent, and every existing deployment safeguard. It takes effect only after Step 4's readiness requirements pass, and it is recorded at Step 5 only if they do. Secondary is never contacted.

### 2026-10-11 — Steps 1–3 applied; pre-deploy readiness gate

- **Steps 1–2.** The six files were copied byte for byte from the scratchpad `s40` and hash to their frozen values, each LF with 0 CR:
  - migration `supabase/migrations/20261011120000_an_allocation_spends_its_own_payment_on_its_own_invoice.sql`: SHA-256 `ee389adb2aff9253ad1f283805419a488696e579336da2b0e81b968749cc559f`, MD5 `42e94bec60ab7a10b7de7f5bb76db807`, 26690 bytes;
  - test 155: `86cadadd2a486fe402eca680f1f3276e606328fca2c2b9d02f9598965316cdc7`, 44771 bytes, `plan(68)`;
  - test 126: `618d3eab…` → `f90fcd2a7f0746412b315e04ff85551d037f5efbbb92471a67c67f700cf03de4`, 15326 bytes, a one-line diff;
  - test 72: `b430e242…` → `3ad92d5e0b3c3cf8077876a7ef3e56a0b06ed2ced039eaa1ac37ab6247835c57`, 15739 bytes, seven added lines;
  - `scripts/verify_database.sql`: `33c0cfdb…` → `8cd405c61317bc9a425797ed0f4178d8b420076d2134c7820d4babaeed9c6092`, 14432 bytes;
  - canon 27: `ee1c3794…` → `ced9d93bbce5335b25b89d35709d79b51f0c3a0fcec08f680cd0c01fb2c0b79b`, 16289 bytes, nine added lines.
- **Step 3.** The register now holds PAY-6 (High), PAY-7 (High), PAY-8, PAY-10 and PAY-11 after PAY-5, each FIXED locally with Primary pending and Cert `🛡`, then PAY-9 OPEN with its reopening trigger, and FIN-12 after FIN-11; every new row has Owner `—` and this contract as its session, and PAY-11's row carries the unsettling residual and points to PAY-5 / FIN-7. A 2026-10-11 Slice-40 freshness entry demotes SPEC-263's to `Previously:`. The disposition record carries a freshness entry, coverage `41 of 78 recorded · 17 AUDITED · 21 AUDITED-OPEN · 3 PARTIAL · 0 EXEMPT · 37 NOT-RECORDED` (recounted from the rows), "All 41", and the `payment_allocations` row `AUDITED-OPEN` / `ADVERSARIAL`. Register SHA-256 `837b693685179d2a2cb662dc9886bf4ea0a7c2a0393e70e0b214f2965e7d098b`, disposition record `b1ea6026572719fbdba662de42bd43de3602badcab9b05ca9a7ab9d61459a58b`.
- **Causal negative, first, on the still-unrepaired 250 stack:** the committed test 155 ran all 68 assertions, passed 18 and failed 50, set-equal to the frozen list: 4, 7, 8, 9, 10, 13–23, 25–29, 31–34, 36, 38, 43–57, 59, 60, 61, 63–67.
- **Clean reset** (`npx supabase db reset`, main checkout): 251 migrations, latest `20261011120000`, ledger `f678a3ef5790582c39635136c8aa202d`. `scripts/parity_surface.sql` reads functions `708dbe893149ea2b97e6893fea449925`/329, triggers `c6f7bb53f0f58500d026259b6e53b96d`/316, constraints `e669286c961025cb49688862286338ed`/527, combined `76c930988563bd06f86c65e429fdb8fc`/3130, and the other seven surfaces at their recorded Primary values — each equal to the Pre-Approval prediction. `payment_allocations` carries 9 triggers and `payments` 11; `catalog_values` 623, `event_type` 188.
- **Focused tests:** 155 68/68, 07 2/2, 10 9/9, 38 21/21, 68 11/11, 72 18/18, 87 29/29, 88 25/25, 89 21/21, 96 32/32, 110 25/25, 113 20/20, 126 33/33, 140 20/20.
- **Mutation M1–M37,** against the committed test 155 (`86cadadd…` in the container): live surface `919a84f1159bc0c9c0f112ee6e7d69ef` before and after the run; every installation changed the surface, every rollback restored it, and all thirty-seven were killed with exactly the frozen failing assertions.
- **Races on the final bytes,** on a dedicated tenant deleted afterwards (0 tenants, allocations and events left), the second session observed waiting on an advisory lock each time: two 600 door allocations to one 1000 invoice — the second refused, 1200 > 1000, 600 committed; one 600 payment allocated 400 twice — the second refused, 800 > 600, 400 committed; two sessions each removing one of a `partially_paid` invoice's two 300 allocations — the second refused, `partially_paid` on 300. **Negative control:** with only the invoice lock removed from `app.enforce_invoice_allocation_ceiling` (definition md5 `bf4357fa510e71f7649813027dce21b8` → `473d312433984a7a2ad073f784cc8d2d`), no session waited and both removals committed, leaving `partially_paid` on 0; the saved definition was restored and hashes to `bf4357fa…` again, and the function surface reads `708dbe89…`/329.
- **A second clean reset, then in `-Finish`'s order:** pgTAP Pass A `Files=155, Tests=2936, Result: PASS`; `verify_api_end_to_end.ps1` 35 passed, 0 failed; `verify_journey_branches.ps1` 85/0; `verify_lifecycle_branches.ps1` 122/0; pgTAP Pass B without reset `Files=155, Tests=2936, Result: PASS`; smoke `ALL CHECKS PASSED (78 tables, … 71/623 catalog, …)`. Plan sum 155 files / 2936.
- **Generators:** the API contract regenerates byte-identical (`d28fb5672ca9c0795a99a74746069c973e1392edcc5e3d2a5a315348138175fd`; 80 RPC endpoints, 8 views, 74 tables). The map is regenerated at Step 7.
- **CI-only guard self-tests:** future-date 18/0 and status-contradiction 33/0 pass. Cold-start (25 passed, 9 failed) and primary-ledger (11 passed, 2 failed) fail only their CONTROL and restore cases, which require an untouched copy to be CLEAN; every mutation case passes.
- **Repository consistency:** exactly the predicted drift, 6 issues — 250 vs 251 migrations; latest `20261011090000` vs `20261011120000`; ledger `24b8778b…` vs `f678a3ef…`; 154 vs 155 test files; 2868 vs 2936 assertions; RECOVER-1. Checks 21 to 25 are clean (Check 24: all 41 `ADVERSARIAL` surfaces earned; Check 25: no new decider). `git diff --check` exit 0. The working tree touches only Write Scope paths.
- **Fresh Primary baseline, read-only:** project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`; ledger 250 `24b8778b6d9e955a8472affb07712858`, latest `20261011090000`, the target absent by version and name, no row after it; `parity_surface.sql` functions `3d7eb4e3550f7cec15815defb600272d`/326, triggers `61f9789b320a4eb988542b83beee36ca`/312, policies `b67d466a…`/125, constraints `cea733efe840d1579bc55f541de54c2d`/525, grants `6727f6d8…`/189, columns `448db887…`/1134, views `10bb212a…`/16, indexes `22a4d58c…`/300, status transitions `db2165c7…`/115, RLS `c117cbf7…`/79, combined `a23669c9c5c31f56bed4f7e8d265c534`/3121; `payment_allocations` has the 6 enabled triggers `derive_created_by`, `emit_created`, `enforce_subscription_write_gate`, `guard_financial_capability`, `guard_parent_state`, `within_invoice_total`, and `payments` 10; `app.record_payment` prosrc md5 `c6b1efb7f07d9bb667eadbeebb50a158` / definition `b51c763418c942bcbc4337c880ef7c61`, SECURITY INVOKER, `search_path=""`, ACL `{postgres=X/postgres,authenticated=X/postgres}`; `app.enforce_invoice_allocation_ceiling` `77636b76e5cf82916700e69759068c60` / `ec34d628c0122aad53ad917c569dcb5f`, SECURITY DEFINER, `search_path=""`, ACL `{postgres=X/postgres}`; the three new functions are absent; `catalog_values` 622, `event_type` 187, `payment_allocation_amount_changed` absent; 0 tenants, invoices, payments, allocations and events.
- **Predicted delta:** one ledger row (251, `f678a3ef…`, latest `20261011120000`); functions → `708dbe89…`/329, triggers → `c6f7bb53…`/316, constraints → `e669286c…`/527, combined → `76c93098…`/3130; the other seven surfaces unchanged; `catalog_values` 623 by the migration's one registration row; no business row.

### 2026-10-11 — Human Gate 2: owner authorization

The owner's SPEC-264 revised-Draft approval (2026-10-11) grants a separate, advance, one-time, exact-byte Gate 2: deploy only `supabase/migrations/20261011120000_an_allocation_spends_its_own_payment_on_its_own_invoice.sql`, SHA-256 `ee389adb2aff9253ad1f283805419a488696e579336da2b0e81b968749cc559f`, 26,690 bytes, LF, to Primary `vrvtsxexkiiiivlkdxzp` only, subject to every existing deployment safeguard; no other migration is authorized, the migration is never reapplied under uncertainty, and Secondary is never contacted. Its conditions hold as recorded in the entry above: the frozen bytes exist in the scratchpad and in the repository and match in full; the approved contract and the other frozen artifacts — test 155 `86cadadd…`, test 126 `f90fcd2a…`, test 72 `3ad92d5e…`, `verify_database.sql` `8cd405c6…`, canon 27 `ced9d93b…` — match; the readiness checks passed with only the drift the contract names; the Primary baseline was read independently, the target is absent, and the predicted effect is limited to the approved scope. Step 6 re-reads everything immediately before the write.

### 2026-10-11 — Resume at Step 6: blocked Boot diagnosed; owner's one-time continuation authorization

- **Boot was BLOCKED, not READY.** On the working tree, `-Boot` returned `ORVION: BLOCKED` / `REPOSITORY_CONSISTENCY_FAILED` with 6 issues. They are exactly the Consumer Closure list and nothing else: Check 9's 250 vs 251 migrations, latest `20261011090000` vs `20261011120000`, and ledger `24b8778b…` vs `f678a3ef…`; Check 15's 154 vs 155 test files and 2868 vs 2936 assertions; and Check 19's RECOVER-1, where only `20261011120000` is absent from Primary. Checks 1–8, 10–14, 16–18 and 20–28 are clean.
- **Why they were expected.** They are produced by Steps 1–3's uncommitted files before deployment. Only Step 7 can make them true, because Step 7 writes from fresh post-deploy readings. Writing the manifest earlier would assert a Primary state that does not exist.
- **What Boot did not reach, and its substitutes.** Boot threw at the repository guard, before its Git, frozen-authority and capability stages. Substitutes:
  - **Git, read by hand:** after a fetch, 5 ahead / 0 behind `origin/main` `1d25f40` with 0 merges; the range touches only this contract, the manifest and `ai-map.json`; the working tree touched only Write Scope paths; `git diff --check` exit 0.
  - **Contract identity:** the Draft blob hashes to `8cdfb5e1…`, and only the Status and the Execution Log changed after it.
  - **Frozen files:** all eight files hash to their recorded values, LF with 0 CR.
  - **Boot itself:** with the eight files parked (`git stash push --include-untracked`, after a byte-exact copy to scratch), `-Boot` on the committed state returned `ORVION: READY`, `MODE: EXECUTE`, `GIT: clean | ahead 5 / behind 0`, `REPOSITORY: clean` and `BLOCKER: none`.
- **Session entrypoint:** this session runs through the terminal CLI. The transcript records `entrypoint: cli` only, `CLAUDE_CODE_ENTRYPOINT=cli`, and the process is the npm `claude.exe` under an interactive pwsh. It is not `claude-vscode`.
- **Checkpoint.** `Resume Step` read 1, although the entries above record Steps 1–5. Each of Steps 1–5 is a re-check, and each is satisfied:
  - Steps 1–2: the six files exist with their frozen bytes.
  - Step 3: the register holds the `PAY-6` row.
  - Step 4: the `Pre-deploy readiness gate` entry exists.
  - Step 5: the Gate 2 authorization is recorded.

  The checkpoint is therefore set to 6. Nothing is skipped.
- **Fresh Primary baseline, read-only, before the write:** every value equals Step 4's baseline:
  - project URL `https://vrvtsxexkiiiivlkdxzp.supabase.co`;
  - ledger 250 `24b8778b6d9e955a8472affb07712858`, latest `20261011090000`; the target is absent by version and by name, and no row follows it;
  - 0 tenants, invoices, payments, allocations and events; `catalog_values` 622, `event_type` 187, `payment_allocation_amount_changed` absent;
  - the same 6 `payment_allocations` and 10 `payments` triggers, all enabled;
  - `app.record_payment` `c6b1efb7…` / `b51c7634…`, INVOKER; `app.enforce_invoice_allocation_ceiling` `77636b76…` / `ec34d628…`, DEFINER; both keep `search_path=""` and their recorded ACLs;
  - the three new functions are absent.
- **Transmitted text, proved server-side.** One read-only `select md5(...)` returned `42e94bec60ab7a10b7de7f5bb76db807`, 26690 bytes, 493 LF, equal to the file. The text includes line 483 (`drop trigger …`), so Supabase's human confirmation was raised and accepted in the terminal.
- **Owner authorization (2026-10-11), one-time.** It is a narrowly bounded exception to continue past exactly those six findings, only during Steps 6 and 7:
  - Every other check and safeguard stays enforceable, and no guard is disabled, modified or bypassed.
  - The existing Gate 2 is reaffirmed for migration `ee389adb2aff9253ad1f283805419a488696e579336da2b0e81b968749cc559f`, to Primary `vrvtsxexkiiiivlkdxzp` only.
  - A ledger correction is allowed only as this contract's Step 6 states it.
  - Repository consistency must be genuinely CLEAN before `-Finish`.
  - The exception expires when the six findings resolve, or at any new mandatory blocker.

### 2026-10-11 — Step 6, deployment attempt 1: refused unapplied (confirmation expired)

- **Before the write.** Repository consistency again reported exactly the same six findings and nothing else. Every Step 6 pre-write reading matched the baseline exactly.
- **The call.** Checkpoint commit `719c24d` was in place and the eight files were restored byte-exact. `apply_migration` was then sent once, with the text the md5 proof had verified.
- **The result.** The call waited 23 min 25 s for Supabase's human confirmation dialog, then returned `Invalid or expired requestState`: the confirmation token expired before it was answered. For comparison, the md5 proof's confirmation was answered within 8 s.
- **Nothing was applied, proven read-only immediately afterwards:**
  - ledger 250 `24b8778b6d9e955a8472affb07712858`, latest `20261011090000`, no new row by version or name;
  - `catalog_values` 622, and the new code absent;
  - the three new functions absent; triggers 6 and 10;
  - `app.record_payment` definition `b51c7634…` and the ceiling's prosrc `77636b76…` unchanged.
- **Status.** The migration has not been applied, so a later attempt is its first application, not a reapplication. Step 6 stays the Resume Step, and the attempt waits for the owner to be present to answer the dialog promptly.

### 2026-10-11 — Step 6 deployed (attempt 2); Step 7 synchronized

- **Authority.** The owner, present at the terminal, authorized one further attempt, conditional on reverifying everything first.
- **Reverified before the write:**
  - the eight files hash to their frozen values (migration MD5 `42e94bec…`);
  - HEAD `719c24d` is 6 ahead / 0 behind `origin/main` `1d25f40`;
  - repository consistency still reports exactly the six predicted findings;
  - the Primary pre-write reading equals the baseline exactly.
- **Deployment.** `apply_migration` sent the proven text once. The owner answered Supabase's confirmation, and the call returned `success`.
- **Ledger rename.** The connector stored version `20261011141637`. Each guard held: exactly one row after `20261011090000`, 251 rows, one stored statement with MD5 `42e94bec…` (26690 bytes), and no `20261011120000` row. One guarded UPDATE, carrying every condition in its WHERE clause, renamed that row alone to `20261011120000`, and returned exactly that row.
- **Fresh Primary readings (read at `2026-10-11T14:17:36Z`), each equal to the prediction:**
  - ledger 251 `f678a3ef5790582c39635136c8aa202d`, latest `20261011120000`, nothing after it;
  - Check L2/P2 functions `708dbe893149ea2b97e6893fea449925`/329;
  - `parity_surface.sql`: functions `708dbe89…`/329, triggers `c6f7bb53…`/316, constraints `e669286c…`/527, combined `76c930988563bd06f86c65e429fdb8fc`/3130; policies `b67d466a…`/125, grants `6727f6d8…`/189, columns `448db887…`/1134, views `10bb212a…`/16, indexes `22a4d58c…`/300, status transitions `db2165c7…`/115 and RLS `c117cbf7…`/79 unchanged;
  - `payment_allocations` has 9 enabled triggers (adding `guard_link`, `within_payment_amount` deferred, and `emit_amount_changed`); `payments` has 11 (adding `amount_covers_allocations` deferred);
  - the five functions' prosrc and definition MD5s, SECURITY DEFINER/INVOKER modes, `search_path=""` and ACLs equal the local stack's (251 / `f678a3ef…`): `record_payment` `085950d8…`/`94dd903a…`, `enforce_invoice_allocation_ceiling` `2faaac12…`/`bf4357fa…`, `guard_payment_allocation_link` `e4ec8ade…`/`723419a5…`, `enforce_payment_allocation_coherence` `9353cd11…`/`45c3f95a…`, `emit_payment_allocation_event` `9987bb91…`/`a6762849…`;
  - `catalog_values` 623, `catalog_types` 71, `event_type` 188; `payment_allocation_amount_changed` is system, active, at `sort_order` 935;
  - 0 tenants, invoices, payments, allocations and events.
- **Writes and contacts.** Primary received only the authorized migration and the one guarded rename. Secondary `brplkqmbzffpxqgkkdzo` was not contacted.
- **Step 7, written from those readings:**
  - `primary-ledger-evidence.json`: 251 entries equal to the migration files, recomputing to `f678a3ef…`.
  - Manifest `Live state`: 251 / `20261011120000` / `f678a3ef…`, functions `708dbe89…` (329), structural `76c93098…` (3,130), 71/623 catalog, Suite **155 files / 2936 assertions** (the plan sum, confirmed by Check 15's count), and 464 HTTP assertions unchanged.
  - Batch 6 coverage: 41 of 78, all forty-one `ADVERSARIAL`.
  - Register: PAY-6, PAY-7, PAY-8, FIN-12, PAY-10 and PAY-11 marked `DEPLOYED` with Cert `✅`, in the SPEC-262 wording.
  - `MASTER_API_CONTRACT.md` regenerated byte-identical (`d28fb567…`). `ai-map.json` regenerated, with only `generated_at` moved, and normalized to LF.
  - The four CI-only guard self-tests pass: cold-start 34/0, future-date 18/0, primary-ledger 13/0, status-contradiction 33/0.
  - The Runtime Checkpoint is set to DONE.

  Closing checks on the synchronized tree:
  - `check_primary_ledger.ps1`: `RECOVER-1 LEDGER EVIDENCE: CLEAN`, 251 / `f678a3ef…`.
  - `check_database_parity_evidence.ps1`: `PRIMARY PARITY EVIDENCE: CLEAN`.
  - Repository consistency: `REPOSITORY CONSISTENCY: CLEAN`. The six pre-deploy findings resolved exactly as predicted, and the owner's one-time exception expired.
  - `git diff --check`: exit 0.

  Committed at `3619fad`. The pre-commit Gate reported `STEP: DONE` and `REPOSITORY: clean`.

### 2026-10-11 — Post-deploy local certification

Canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` ran on the clean, committed HEAD `3619fad`, with nothing else running.
- It ran in VERIFY mode (`STATUS: In Progress`, `STEP: DONE`), with profiles DATABASE and REPOSITORY plus the three declared HTTP suites.
- It reported `LOCAL_CERTIFY: READY` in 5.8 min, exit 0.
- Every mandatory verification passed in that run: reset; pgTAP Pass A; `verify_api_end_to_end.ps1`; `verify_journey_branches.ps1`; `verify_lifecycle_branches.ps1`; pgTAP Pass B; smoke; `check_database_parity_evidence.ps1`; repository consistency; `git diff --check`; `check_primary_ledger.ps1`.

Three earlier results were not repeated, because what they ran on is unchanged:
- The four CI-only guard self-tests passed on the same committed content at Step 7.
- M1–M37, the causal negative, the three races and the lock-removed negative control ran at Step 4, against the committed migration and test bytes.

This contract's Review Gate holds no remote item. The implementation and the Complete commit are therefore published together as one range, as Step 8 states.

**Selector after SPEC-264** (`scripts/batch6_select_target.ps1`, 37 surfaces still `NOT-RECORDED`), as Exposure/coverage:
1. `receipts` 7/20
2. `chart_of_accounts` 7/38
3. `notification_deliveries` 7/42
4. `approval_requests` 7/52
5. `user_branch_assignments` 7/584
6. `departments` 7/648
7. `user_role_assignments` 7/648
8. `customer_consents` 6/18
9. `document_retention_policies` 6/36
10. `document_links` 6/54
11. `exchange_rates` 6/66
12. `user_permission_grants` 6/88

Slice 41's measured target is `receipts`.

## Verification Notes

### 2026-10-11 — Independent Review of the execution commit `3619fad`

Reviewed the committed tree against three references: the approved Draft `cd5f7f4`, the owner's Gate 2 authorization and the thirteen-path Write Scope. The review read the committed migration in full, the extracted function definitions, the range diffs, the certified local stack and fresh Primary readings. It did not rely on the Execution Log alone.

1. **Fixed fields (criterion 1).**
   - **The rule.** `app.guard_payment_allocation_link()` (SECURITY DEFINER, `search_path=""`, PUBLIC revoked; BEFORE INSERT OR UPDATE, row) refuses 23514 on any distinct `id`, `tenant_id`, `payment_id`, `invoice_id`, `currency_code`, `exchange_rate_id`, `created_by` or `created_at`. It has no session-less exit, so the platform is bound too.
   - **Amount-only UPDATE.** An UPDATE that leaves `allocated_amount` alone restores the stored converted amount and returns before any derivation. FIN-3's guard, still installed, refuses the employee's amount change 42501.
   - **Proof.** Test 155 passed in both `-Finish` pgTAP passes. M1–M5, M22 and M24 are killed by it.
2. **Payment coherence (criterion 2).**
   - **The rule.** `app.enforce_payment_allocation_coherence()` is fired by two deferred constraint triggers: `payment_allocations_within_payment_amount` (INSERT/UPDATE) and `payments_amount_covers_allocations` (UPDATE). Both are read on Primary with `tgdeferrable` true.
   - **What it refuses.** At commit, a non-`customer_payment`, a foreign currency, a foreign customer and an over-allocation each raise 23514. A customer-less payment fails the `is distinct from` customer test against any invoice's customer.
   - **Proof.** M11–M16, M18 and M21 are killed.
3. **Cross-currency (criterion 3).** The guard requires an `exchange_rate_id` in the tenant for exactly the allocation→invoice pair. The rate must be positive and finite, so NaN and Infinity are excluded. The guard derives `allocated_amount * rate`. A same-currency allocation with a rate is refused 23514, and its converted amount is nulled. M6–M10, M19, M20, M23 and M33 are killed.
4. **Invoice ceiling and locks (criterion 4).**
   - **The rule.** `app.enforce_invoice_allocation_ceiling()` sums `coalesce(allocated_amount_invoice_currency, allocated_amount)`. On an allocation write it takes `pg_advisory_xact_lock(hashtextextended(invoice_id::text, 0))`, the key `app.record_payment` takes. The coherence function takes the payment's key.
   - **Concurrency.** The Step 4 races on the final bytes refused the second session each time. The lock-removed negative control let both commit, and the definition was restored to `bf4357fa…`.
   - **Primary.** Primary's definition is the same `bf4357fa…`.
5. **The floor (criterion 5).** After an allocation write only, `paid` with less than the total, or `partially_paid` with 0, raises 23514. No statement in the migration writes `invoices.status_code`. The floor race held, and M30–M32, M35 and M36 are killed.
6. **History (criterion 6).**
   - **The producer.** One producer, `app.emit_payment_allocation_event()`, is fired by `payment_allocations_emit_created` (AFTER INSERT) and `payment_allocations_emit_amount_changed`. The second fires AFTER UPDATE only `when` either amount is distinct.
   - **The event.** It records `info` on creation and `warning` on change, with payment, invoice, currency, rate and both amounts, adding both previous amounts on a change. Its actor is left to `app.record_event`, so it is NULL on the platform path.
   - **The code.** `payment_allocation_amount_changed` is registered: system, active, `sort_order` 935, read on Primary. It is in canon 27, and smoke counts 623.
   - **Proof.** M25–M29, M34 and M37 are killed.
7. **`app.record_payment` (criterion 7).** Extracted from the committed files, the 100-line definition differs from its only earlier one (`20260928180000`) in a single line: the `v_already` sum now reads `coalesce(allocated_amount_invoice_currency, allocated_amount)`. Both Primary and local keep SECURITY INVOKER, `search_path=""` and ACL `{postgres=X/postgres,authenticated=X/postgres}`. The three HTTP suites passed inside `-Finish`.
8. **Held controls (criterion 8).** The migration touches no grant, policy, foreign key, `guard_financial_capability`, `guard_invoice_void` or the PAY-1 INSERT rule. On Primary the grants (`6727f6d8…`/189) and policies (`b67d466a…`/125) are unchanged. Tests 10, 38, 68, 87, 88, 89, 96, 110, 113, 126 and 140, and the merge cases in test 155, passed in both `-Finish` passes.
9. **Mutation (criterion 9).**
   - **The run.** M1–M37 ran at Step 4, against the reset stack carrying the committed migration, with test 155's committed bytes.
   - **The surface.** The base surface was `919a84f1…`. Every installation changed it, every rollback restored it, and all thirty-seven mutants were killed with their frozen assertions.
   - **Causal negative.** It was measured on the unrepaired 250 stack: 50 failures, the frozen list.
   - **Races.** The three races and the floor race's lock-removed negative control are recorded.
10. **Edited files (criterion 10).**
    - Test 126 changes only assertion 23 (`10` → `11` and its description).
    - Test 72 gains seven lines and loses none.
    - `verify_database.sql` moves only its banner, CHECK 6b with its three-line comment, and its notice, all from 622 to 623.
    - Canon 27 gains nine lines and loses none.
11. **Register (criterion 11).** The range adds PAY-6, PAY-7, PAY-8, PAY-10, PAY-11 and FIN-12, each FIXED and DEPLOYED with Cert `✅`. It adds PAY-9 OPEN with its reopening trigger, and changes the freshness line. PAY-1 to PAY-5, FIN-10 and FIN-11 are unchanged.
12. **Disposition (criterion 12).** Against `1d25f40`, only four things changed: the freshness entry, the coverage line, "All 41" and the `payment_allocations` row (`AUDITED-OPEN` / `ADVERSARIAL`). Its 78 rows count 17 `AUDITED`, 21 `AUDITED-OPEN`, 3 `PARTIAL` and 37 `NOT-RECORDED`: 41 of 78.
13. **Frozen values (criterion 13).** The committed blobs hash to the approved values: migration `ee389adb…`, test 155 `86cadadd…`, test 126 `f90fcd2a…`, test 72 `3ad92d5e…`, `verify_database.sql` `8cd405c6…`, canon 27 `ced9d93b…`. Primary's stored statement MD5 is `42e94bec60ab7a10b7de7f5bb76db807`, 26690 bytes.
14. **Agreement (criterion 14).**
    - **The same values everywhere.** Primary, the evidence and the manifest agree: 251 migrations, `f678a3ef…`; functions `708dbe89…`/329; structural `76c93098…`/3130; 71/623 catalog; 155 files / 2936 assertions; 464 HTTP assertions.
    - **Generated files.** The API contract matches its generator (`d28fb567…`), and `ai-map.json` is LF.
    - **Checks.** The four guard self-tests passed on the deployed content, and repository consistency is CLEAN inside `-Finish`.
15. **Next capability (criterion 15).** The Complete commit names Batch 6 Slice 41 and `receipts` (7/20), which the selector measured on the certified stack, and clears the Active Change Request.
16. **Primary and Secondary (criterion 16).**
    - **The writes.** Primary received two writes: the one authorized migration, applied once (an earlier attempt was proven unapplied), and one guarded rename of temporary version `20261011141637`.
    - **Its state.** It holds 0 tenants, invoices, payments, allocations and events, both before and after. Only the function, trigger and constraint surfaces moved.
    - **Secondary** was never contacted.
17. **Scope (criterion 17).** `1d25f40..3619fad` changes twelve paths, all in Write Scope. `MASTER_API_CONTRACT.md` regenerates unchanged.

**The governance exception, as exercised.** Boot was BLOCKED on the working tree at the start of this session, on exactly the six pre-deploy findings the contract predicted. It was not reported READY. The owner granted a one-time exception for Steps 6 and 7 only, and it is recorded above. It expired when repository consistency became CLEAN at Step 7, before `-Finish`.

**Outside this contract, and not a defect in it:**
- PAY-9 (the booking-scoped balance) stays OPEN with its trigger.
- The unsettle-an-invoice policy question stays an owner question (Notes).
- PAY-5 and FIN-11 keep the row `AUDITED-OPEN`.

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

Batch 6 Slice 40, prepared under the owner's 2026-10-11 Slice 40 directive and revised under the owner's 2026-10-11 decision to resolve the allocation-history gap inside this contract (Option A). Gate 1 approval of this exact Draft and Gate 2 authorization of the migration's exact SHA-256 are each the owner's decision; the first Draft's Gate 1 and Gate 2 authorizations do not apply to these bytes.

Owner question, not decided and not built here: canon 26 gives `paid` and `partially_paid` no way back, so a payment applied to the wrong invoice after it has settled that invoice cannot be moved, and a payment recorded through `app.record_payment` with a wrong amount cannot be shrunk once it settled an invoice. Whether ORVION should support unsettling an invoice — and through which governed action (a reversal, a credit note, an authorized finance correction with status derivation on every door, PAY-5 / FIN-7) — is a business-policy decision for a later contract.
