# Change Request — SPEC-238

## Status

[ ] Draft
[ ] Approved
[x] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close PAY-3: make `payment_recorded` (customer payments) and `supplier_payment_recorded` (supplier payments) produced by one deferred constraint trigger on `payments` on every legal door, remove the RPCs' own emission so no payment is recorded twice, and prove that a customer payment made at the table door reaches the `payment_received` Google Ads conversion exactly once, while a supplier payment never does. This is the second contract of the Phase-8 Activation Closure (`MASTER_INTEGRATION_CATALOG.md` §2b item 1). Record PAY-5, found on the way and not repaired.

## Business Reason

The manifest's next capability is the Phase-8 Activation Closure, and PAY-3's trigger has fired. `payment_received` is the one conversion that carries revenue, and the conversion system may not be called live while a legal payment produces none.

- **The intended rule.** ADR-0023 and canon 21: ORVION turns verified CRM outcomes into offline conversions. `app.map_outcomes_to_conversions` maps `payment_recorded → payment_received` and finds the payment's lead through `payments.booking_id` or the invoice the event's payload names (CONV-7, SPEC-233).
- **PAY-3 (Medium, reproduced, latent).** Measured on the local stack at `73e571c`, in a rolled-back transaction, with a consented Google Ads click on every lead. `authenticated` holds INSERT on `payments` and `payment_allocations`, and PAY-1, PAY-2 and FIN-10 made that door a governed one (RECORD_PAYMENT, invoice state, ceiling). The owner then made four payments:

  | Payment | `*payment_recorded` events | Conversion |
  | --- | --- | --- |
  | `app.record_payment` on an issued invoice (control) | 1 | `payment_received` 5000 |
  | A door customer payment allocated to an issued invoice | 0 | none |
  | A door customer payment naming its booking | 0 | none |
  | A door supplier payment | 0 | not a conversion source |

- **Exposure.** Primary holds 0 tenants, 0 payments and 0 offline conversions, and no delivery workflow exists. The defect is latent until the first tenant's pipeline runs.
- **The repair is SPEC-215's and SPEC-237's shape, with one difference forced by the data.** A payment names the invoice it pays through `payment_allocations`, a row that can only be written after the payment, because it carries the payment's id. `app.record_payment` writes it second.
  - An immediate trigger on `payments` would therefore record every invoice payment with no invoice, and the mapper could not attribute it; the out-of-file mutant M-B proves this.
  - The trigger is therefore a DEFERRABLE INITIALLY DEFERRED constraint trigger, the idiom FIN-8, FIN-10 and ASGN-5 already use. It records the payment at commit, inside the same transaction and session, when its allocations exist.
  - **Customer payments** get `payment_recorded` with the RPC's payload keys. `invoice_id` is the one invoice the payment is allocated to; it is null when the payment is allocated to none or to several, and the emitter refuses to guess. `invoice_new_status` is that invoice's status, and `amount` and `currency_code` are the payment's own.
  - **Supplier payments** get `supplier_payment_recorded` with the RPC's payload keys.
  - **The refund directions** have no RPC and no event on this table, and get none.
  - `app.record_event` takes the actor from the session and stamps the time.
- **Not in this contract.** `booking_issued` and the issuance rules are BOOK-10, the next Activation Closure contract. PH8-4, PH8-9 and the delivery workflow follow it.

## Risks

- **A payment recorded twice would be revenue uploaded twice.** Mitigated by three things:
  - Neither RPC emits these events any more, and the trigger is their only producer. A census of every function body found no other writer of either code, and `app.record_payment` and `app.record_supplier_payment` are the only functions that insert payments.
  - `source_event_seq` is unique on `offline_conversions`.
  - Test 140 asserts one event per in-scope customer or supplier payment on every door, and mutants M-A and M-C, which restore each RPC's own emission, are killed.
- **Money paid out recorded as revenue.** Mitigated: the emitter maps direction to event explicitly, and the mapper sees only `payment_recorded`. Test 140 asserts that no supplier payment ever carries `payment_recorded`, and mutant M-D is killed.
- **Revenue attributed to the wrong booking.** Mitigated: a payment split across invoices names none, and mutant M-E, which takes the first invoice instead, is killed. The invoice lookup is tenant-scoped.
- **The event is recorded at commit, not at the INSERT.** Two consequences follow:
  - Within the writing transaction, the event does not exist until commit. No function reads it in-transaction: the census found the mapper as its only reader, and the mapper runs in its own transaction. pgTAP files, which roll back, fire it explicitly; only `137_...` needed that.
  - An allocation made in a later transaction does not re-record the payment, so a door payment linked to its invoice only afterwards is recorded without it and attributes through `payments.booking_id` if set. The event states what the payment was when recorded, as every creation event here does.
- **Tests pinned to the old shape.** `126_...` pins the `payments` trigger inventory at 9, and it becomes 10. `137_...` reads `payment_recorded` inside its transaction and now fires the deferred event where the RPC ran. The prototype's full suite and all six HTTP suites found no other consumer.
- **Primary deployment adds one function and one trigger and replaces two function bodies in production.** It requires separate exact-byte owner authorization (Gate 2). Approving this contract does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-238-payment-is-recorded-on-every-door.md`
- `supabase/migrations/20260928180000_a_payment_is_recorded_on_every_door.sql`
- `supabase/tests/140_payment_is_recorded_on_every_door_test.sql`
- `supabase/tests/137_conversion_sources_reach_the_pipeline_test.sql`
- `supabase/tests/126_payment_write_capability_parity_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607047100_record_payment.sql`
- `supabase/migrations/202607047400_record_supplier_payment.sql`
- `supabase/migrations/20260928140000_a_payment_conversion_finds_its_lead_through_its_invoice.sql`
- `supabase/migrations/20260928160000_a_qualified_lead_and_a_booking_are_recorded_on_every_door.sql`
- `supabase/tests/72_invoice_allocation_ceiling_test.sql`
- `supabase/tests/119_conversion_provenance_is_platform_written_test.sql`
- `supabase/tests/139_qualified_lead_and_booking_are_recorded_on_every_door_test.sql`
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/architecture-decision-records.md`
- `scripts/verify_database.sql`
- `scripts/verify_lifecycle_branches.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/generate-ai-map.ps1`
- `scripts/generate-api-contract.ps1`

## Required Reading

- `AGENTS.md`; `CR_LIFECYCLE.md`; `ENGINEERING_METHOD.md` §§1–5
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`; `_ORVION_CANONICAL/27_event_catalog.md`
- `supabase/migrations/20260928160000_a_qualified_lead_and_a_booking_are_recorded_on_every_door.sql` (the shape reused) and `supabase/tests/139_...`
- Current local `app.record_payment`, `app.record_supplier_payment`, `app.record_event`, `app.guard_financial_capability`, `app.enforce_invoice_allocation_ceiling`, `app.map_outcomes_to_conversions`
- `reports/master/MASTER_GAP_REGISTER.md` (PAY-1 to PAY-4, FIN-7, FIN-10, CONV-7, BOOK-10); `reports/master/MASTER_INTEGRATION_CATALOG.md` §2b

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

- `pwsh -NoProfile -File scripts/verify_lifecycle_branches.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| `payment_recorded` is produced at commit by `payments_emit_recorded` on every door, and no longer by `app.record_payment` | `app.map_outcomes_to_conversions` (reads `payload.invoice_id`); `app.customer_timeline`; `events` readers | VERIFY | The prototype was applied as a real migration on a clean reset in a scratch worktree at `73e571c`: migration SHA-256 `b696f6aa8ea5619a1a75c456f3a790e785d4f6eacce801ca654f67aa71c2218d`, Test-140 SHA-256 `b6c873085e0f49a6f98561f319a41912f5b827f7dd1c2b19bfd42f7ec99c7d89`. The RPC path records exactly one event with the same actor, reason, new state, severity and four payload keys as before, including the invoice it paid. One value changes form: `amount` is the stored `payments.amount` (`5000.0000`), where the RPC wrote its argument (`5000`). The two are numerically equal, and no function reads the field; the mapper reads `payments.amount`. |
| `supplier_payment_recorded` is produced by the same trigger, and no longer by `app.record_supplier_payment` | `events` readers (no function reads it) | VERIFY | The RPC path records exactly one event with the same payload keys, read from the row. |
| The event is recorded at commit rather than inside the RPC call | In-transaction readers of the event | WRITE | The only reader is the mapper, which runs in its own transaction. `137_...` fires the deferred event after `app.record_payment`, and its assertions are unchanged. |
| The `payments` trigger inventory grows by one | `126_...` assertion 23 | WRITE | Moves from 9 to 10, and its description names the emitter. |
| Every other `app.record_payment` behaviour | the invoice-status events, the ceiling, PAY-1 and PAY-2; `72_...`, `94_...`, `110_...`, `113_...`, `126_...` | VERIFY | Unchanged. The full suite passes. |
| Suite, smoke and every HTTP door, where the trigger fires at a real commit | full pgTAP; `scripts/verify_database.sql`; all six HTTP suites | VERIFY | On the prototype stack, in `-Finish`'s order: pgTAP Pass A 140 files / 2505 assertions PASS (the 2485 existing, with `126_...` 23 and `137_...`'s deferred-event firing changed as stated, plus 20 new); HTTP suites 33 + 40 + 74 + 122 + 120 + 60 = 449 passed, 0 failed, including every HTTP payment journey, where the trigger fires at a real commit; Pass B without reset 140 / 2505 PASS; smoke `ALL CHECKS PASSED`, exit 0. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | No RPC, view or table changes: the emitter returns `trigger` and is not an endpoint, and the regenerated contract is byte-identical (79 RPC endpoints, 8 views, 73 tables). It is regenerated in Step 7. |
| Measured state that moves | manifest (`Live state`, suite figure, Last Completed, Active pointer); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 15, 19 | WRITE | 236 → 237 migrations, latest `20260928180000`; 139 → 140 files / 2485 → 2505 assertions. Primary values are written only from fresh post-deploy readings. |
| Findings, disposition and the activation list | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; `MASTER_INTEGRATION_CATALOG.md` §2b; Checks 2, 11, 16, 21, 22, 24, 25 | WRITE | PAY-3 becomes fixed. PAY-5 is new and open, with Owner Decision `—`. The `payments` row stays `AUDITED-OPEN` on PAY-4 and the `offline_conversions` row stays `PARTIAL`, each gaining Test 140. §2b item 1 records PAY-3 closed. No other row changes. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused tests, pgTAP A/B, the declared HTTP suite, smoke and in-file mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| PAY-3, PAY-5, both disposition rows and §2b accurately describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: SPEC-215's and SPEC-237's single-producer event trigger, SECURITY DEFINER with EXECUTE revoked from PUBLIC and the RPC's own emission removed, with `app.record_event` owning the actor and the time. It is combined with the deferred constraint trigger FIN-8, FIN-10 and ASGN-5 already use, because the invoice a payment pays exists only at commit. The alternatives were rejected:
- **An immediate trigger on `payments`:** it records invoice payments with no invoice, and the RPC's own payment loses its `payment_received`. Mutant M-B proves it.
- **A trigger on `payment_allocations`:** a payment with no allocation (one naming its booking) would record nothing, and a split payment would record twice.
- **Resolving the invoice in the mapper from `payment_allocations`:** allocations are mutable, and the mapper would attribute differently depending on when it ran. SPEC-233 chose the immutable event payload for exactly this reason.
- **Setting `payments.booking_id` in the RPC:** it changes per-booking balances and the negative-balance issuance check, as SPEC-233 recorded.
- **Keeping the RPC emission and skipping the trigger when an RPC runs:** two producers joined by a flag is the double-emission risk this shape removes.
- **Closing the door:** PAY-1, PAY-2 and FIN-10 made it a governed, designed door; closing it would change authority, not observability.

Added Property: Every `customer_payment` and `supplier_payment` inserted on any door records exactly one creation event of its own direction, naming the session's actor, at the commit that makes it visible. Refund directions remain outside SPEC-238 and remain separately owned by PAY-4. A customer payment with an attributable booking, through the one invoice it paid in its transaction or the booking it names, yields exactly one `payment_received`. A supplier payment yields none.

Causal Negative: On the local stack at `73e571c`, in a rolled-back transaction, with a consented Google Ads click on each lead, an owner holding RECORD_PAYMENT made two door customer payments and one door supplier payment. One was allocated to an issued invoice and one named its booking. None produced an event, and the mapper produced no `payment_received` for either customer payment, while `app.record_payment` produced both.

Positive Test Design: As the owner at `aal2`:
- pay an issued invoice through `app.record_payment`;
- pay a supplier through `app.record_supplier_payment`;
- at the table door, make a customer payment allocated to an issued invoice, one naming its booking, one split across two invoices, and a supplier payment;
- as `postgres` with no session, make a platform payment.

Fire each pending event in the writer's session, then run the real mapper.

Negative Test Design:
- An employee without RECORD_PAYMENT is refused at the door by the guard's own message and leaves no payment.
- A later edit and a later allocation of a recorded payment record nothing more.
- A split payment names no invoice.
- No supplier payment ever carries `payment_recorded`.
- A further mapper run adds nothing.
- Every in-scope `customer_payment` and `supplier_payment` carries exactly one creation event of its own direction. Refund directions remain outside SPEC-238 and remain separately owned by PAY-4.

Non-Empty Population Obligation: One tenant, one branch and department, an owner holding RECORD_PAYMENT and an `employee` without it, one customer, one supplier, and five leads, each carrying a consented first-touch Google Ads click. Each lead has a booking with an issued 5000 EGP invoice.

Mutation Obligation: In the file, in a savepoint, drop `payments_emit_recorded`, repeat a door payment, and prove it is silent and the mapper produces nothing; roll back and prove the identical payment is recorded and converted. Out of file, record the md5 of the three function definitions and the trigger definition. Install each mutant, prove the md5 differs, run Test 140, restore, and prove the md5 matches:

| Mutant | Change | Expected to fail |
| --- | --- | --- |
| M-A | `app.record_payment` keeps its own emission | assertion 2 |
| M-B | the trigger is initially immediate | assertion 2 |
| M-C | `app.record_supplier_payment` keeps its own emission | assertion 3 |
| M-D | the emitter records supplier payments as `payment_recorded` | assertion 20 |
| M-E | the emitter takes the first invoice of a split payment | assertion 7 |

A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: All of the following, on the final bytes and through canonical `-Finish`:
- the focused tests, a clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B and smoke;
- the in-file and out-of-file mutations and the unrepaired counterfactual;
- the generated artifacts;
- fresh Primary evidence, parity evidence and the Primary ledger check;
- repository consistency and `git diff --check`.

## Implementation Steps

1. **Check** that `supabase/migrations/20260928180000_a_payment_is_recorded_on_every_door.sql` is absent. If absent, create it LF with SHA-256 `b696f6aa8ea5619a1a75c456f3a790e785d4f6eacce801ca654f67aa71c2218d`. It holds:
   - `app.emit_payment_recorded()`, `language plpgsql security definer set search_path to ''`, with EXECUTE revoked from PUBLIC;
   - constraint trigger `payments_emit_recorded`, AFTER INSERT ON `public.payments`, DEFERRABLE INITIALLY DEFERRED, FOR EACH ROW, WHEN the direction is `customer_payment` or `supplier_payment`;
   - `app.record_payment` and `app.record_supplier_payment`, each byte-identical to its live body except that its `app.record_event` call for the payment's creation event is replaced by a PAY-3 comment. `app.record_payment`'s invoice-status event is kept.

   It changes no grant, policy, guard, invoice rule or other function. If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/140_payment_is_recorded_on_every_door_test.sql` is absent. If absent, create it LF with SHA-256 `b6c873085e0f49a6f98561f319a41912f5b827f7dd1c2b19bfd42f7ec99c7d89`. It is one transaction-rolled-back pgTAP file with `select plan(20);`. Its `-- ATTACK-CLASSES:` line reads `DOOR BUSINESS INPUT STATE OBSERVABILITY PRIVILEGE REPLAY TENANT=N/A AUTH=N/A CONCURRENCY=N/A`, and its header states each `N/A` reason and how it fires deferred events. It implements:
   - the Positive and Negative Test Design;
   - the emitter's privilege and trigger shape;
   - the platform path;
   - the in-file Mutation Obligation;
   - completeness.

   Then edit two existing tests, each LF, stopping on any mismatch:
   - `supabase/tests/137_conversion_sources_reach_the_pipeline_test.sql`: after `app.record_payment`, add a two-line comment and `set constraints payments_emit_recorded immediate;` then `set constraints payments_emit_recorded deferred;`. SHA-256 `eceac068b979795ed953f428fbcda1eb360b2b690e55457e07850f20a0d7f3fc`, `plan(16)` unchanged.
   - `supabase/tests/126_payment_write_capability_parity_test.sql`: change assertion 23's expected count from 9 to 10 and its description to name the emitter. SHA-256 `618d3eab8ae51f9204670c80db776a83a5c953e83baa7f8c007381b078964203`, `plan(33)` unchanged.

   If a target carries different content, stop.
3. **Check** whether the PAY-3 row in `reports/master/MASTER_GAP_REGISTER.md` still reads `**OPEN — independently reproduced during Slice 20`. If it does, make four changes and nothing else:
   - Add a dated freshness entry and demote the previous one to `Previously:`.
   - Keep every PAY-3 cell except Status and Updated, and set Updated to `09-28`. Prefix its Status with a bold statement that SPEC-238 (`20260928180000`) fixed it locally, pending Primary deployment, followed by the mechanism, the measurement, what `140_...` proves, and that the unchanged invoice status is PAY-5.
   - Insert **PAY-5** after PAY-4: Category `financial state / two doors`, Sev `Low`, Req/Opt `R`, Batch `6`, Mig `—`, Cert `📋`, Status `OPEN`. It carries the measurement, the cause (the RPC derives the invoice status and nothing else does), the consequence, why it is not FIN-7, PAY-1 or PAY-3, its latency, and the reopening trigger FIN-7's scheduled package. Owner Decision `—`, Source this contract, dates `09-28`.

   In `reports/master/MASTER_SURFACE_DISPOSITION.md`, add a dated freshness entry and demote the previous one. Then:
   - The `payments` row stays `AUDITED-OPEN` / `ADVERSARIAL`. Its CR becomes this contract, and its Next cell records Test 140 closing PAY-3 with PAY-4 still open.
   - The `offline_conversions` row stays `PARTIAL` / `ADVERSARIAL`. Its CR becomes this contract, and its Next cell records PAY-3 closed with BOOK-10 the remaining creation-event axis.
   - Coverage and every other row are unchanged.

   In `reports/master/MASTER_INTEGRATION_CATALOG.md`, extend §2b item 1's 2026-09-28 note to record PAY-3 closed, with BOOK-10 remaining.

   If a target already carries different content, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 hashes:
   - a clean local reset and the focused tests;
   - pgTAP Pass A, the declared HTTP suite, then pgTAP Pass B without reset;
   - `scripts/verify_database.sql` and the plan sum;
   - the in-file and out-of-file mutation evidence and the unrepaired counterfactual;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat only undeployed Primary, manifest and parity drift as expected at this boundary. Read a fresh Primary baseline, read-only:
   - the full ordered ledger and the absence of the target migration;
   - the function and structural surfaces;
   - the tenant, payment, allocation, event and offline-conversion counts;
   - the current definition md5 of both RPCs, and the absence of the emitter and trigger;
   - the `payments` trigger count and Primary's default function ACL for schema `app`.

   Record the predicted structural delta.
5. **Check** that exact owner authorization for the migration SHA-256 is recorded in the Execution Log. If absent, stop after Step 4 and present:
   - the current HEAD and the exact hashes;
   - the fresh Primary baseline and the predicted delta;
   - the exact Primary write requested;
   - the guarded ledger-normalization conditions.

   Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260928180000_a_payment_is_recorded_on_every_door`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, the hashes, the project URL, the full ordered ledger, target absence, the business counts and both pre-repair md5 values.
   - On an exact match, apply only the authorized migration through the Primary connector.
   - If the connector assigns a temporary version, rename only that one newly inserted ledger row. The rename requires exactly one new row, its stored statement md5 equal to the file's, and no existing target version.
   - Read fresh: the ledger, the function surface and all ten structural surfaces, the emitter's security mode, `search_path` and EXECUTE ACL, and the trigger's timing and deferral.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`:
     - set the `Live state` migration count, latest version, ledger and surface hashes and counts from the same readings;
     - confirm that `supabase/tests` holds 140 files whose literal `plan(N)` values sum to 2505, then set the suite figure to `Suite **140 files / 2505 assertions**`; if either differs, stop;
     - set `Last Completed` to SPEC-238 / PAY-3, keeping the manifest within 7000 characters.
   - Mark PAY-3 `DEPLOYED` in the register and change its Cert to `✅`.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators.
   - Set the Runtime Checkpoint to DONE, so that Step 8's `-Finish` runs in VERIFY mode.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, do all of the following:
     - transition to Complete;
     - keep `Next capability` as the Phase-8 Activation Closure with Slice 31 paused;
     - clear `Active Change Request`;
     - regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate and require exact-SHA candidate CI.
   - Promote the same accepted SHA, require main CI, and run `-Certify` for `REMOTE_CERTIFY: READY`.
   - Verify synchronized clean refs.

## Acceptance Criteria

- [ ] A customer payment made through `app.record_payment`, and one made at the table door and allocated to an issued invoice in the same transaction, each record exactly one `payment_recorded` naming the session's actor and that invoice.
- [ ] A door customer payment naming its booking records one `payment_recorded` with no invoice, and a split payment records one naming no invoice.
- [ ] A supplier payment made through `app.record_supplier_payment` or at the door records exactly one `supplier_payment_recorded`, and never `payment_recorded`.
- [ ] The RPC payment, the door payment through its invoice, the door payment through its booking and the platform payment each yield exactly one `payment_received`, keyed to its own event. The split payment and the supplier payments yield none, and a further mapper run adds nothing. The SPEC-233 invoice → booking → lead path still attributes the RPC payment.
- [ ] A refused door payment leaves nothing to record, and a later edit or allocation records nothing more. Every in-scope `customer_payment` and `supplier_payment` carries exactly one creation event of its own direction. Refund directions remain outside SPEC-238 and remain separately owned by PAY-4.
- [ ] The emitter is SECURITY DEFINER with an empty `search_path`, executable by neither PUBLIC nor `authenticated`. Its trigger fires once, AFTER INSERT ROW, deferred to commit.
- [ ] With the trigger dropped in a savepoint, the door payment is silent and produces no conversion, and the rolled-back state records it again. Mutants M-A to M-E are each killed, with their installation and restoration md5-proven. On the unrepaired stack, the decisive assertions of Test 140 fail.
- [ ] PAY-3 is registered fixed and deployed, and PAY-5 is registered open with its trigger. The `payments` row stays `AUDITED-OPEN`, the `offline_conversions` row stays `PARTIAL`, and §2b item 1 records PAY-3 closed. Every other row and the Coverage totals are unchanged.
- [ ] The migration and tests match their SHA-256 values. Primary, the recorded evidence, the manifest (237 migrations; 140 files / 2505 assertions), the API contract and `ai-map.json` agree.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and at most the one guarded ledger rename, with no business-data write. Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

### 2026-09-28 — Owner approval

The owner approved the exact Draft SHA `7127742f1e671cdee8a2248e61731eba11e3b32d` (CR SHA-256 `1518d1957c8dea8399db77c68ca10f0fdaa858e620b12227a60d73f65f7c56ef`) and the frozen twelve-path Write Scope. The approval covers Approve, In Progress, Steps 1-4 and full local proof only. Primary remains read-only and requires Human Gate 2.

The approval is bound to four SHA-256 values:
- migration `20260928180000`: `b696f6aa8ea5619a1a75c456f3a790e785d4f6eacce801ca654f67aa71c2218d`;
- Test 140: `b6c873085e0f49a6f98561f319a41912f5b827f7dd1c2b19bfd42f7ec99c7d89`;
- Test 137: `eceac068b979795ed953f428fbcda1eb360b2b690e55457e07850f20a0d7f3fc`;
- Test 126: `618d3eab8ae51f9204670c80db776a83a5c953e83baa7f8c007381b078964203`.

`7127742` amends the first Draft `fbd64ca`, at the owner's bounded Gate-1 request, in three ways:
- It scopes every completeness claim, in the CR and in Test 140's completeness assertion, to `customer_payment` and `supplier_payment`; refund directions remain PAY-4's.
- It renumbers Test 140's section-banner comments.
- It sets the PAY-3 register row's Updated date to `09-28`.

The migration, the mechanism, the event ownership, PAY-5 and the Write Scope are unchanged.

The owner restated the guarantees to preserve:
- one producer, the trigger remaining DEFERRABLE INITIALLY DEFERRED;
- the SPEC-233 invoice → booking → lead attribution;
- no invoice guessed for a split payment, and no supplier payment as revenue;
- no grant, policy, financial guard, invoice-state rule or mapper change;
- Test 140 at `plan(20)`;
- BOOK-10, PH8-4, PH8-9 and the workflow untouched, and Slice 31 paused.

Revalidation before approval:
- HEAD was the Draft, a direct descendant of the certified `73e571c`, and the tree was clean.
- `origin/main` was at `73e571c`.
- The Draft file hashes to the approved value.
- A read-only evaluation of the committed Draft returned `APPROVAL_EVIDENCE: PASS` (profiles DATABASE and REPOSITORY, three permanent-control paths in scope).
- Two mutated copies returned FAIL (a gate at Step 4 inside the red window 1..7) and INDETERMINATE (the Mutation Obligation removed).
- The prototype's focused Tests 140, 137 and 126 passed 20, 16 and 33. Mutants M-A to M-E were each killed, with md5-proven install and restore.

### 2026-09-28 — Execution started

The approved twelve-path contract entered In Progress at `564ef71e4178eddd5c1b5cfff126c7d870591156`. Resume Step 1. Primary stays read-only until Human Gate 2.

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

- **EARN IT.** PAY-3 was reproduced twice, the second time through to the missing `payment_received`, and its trigger fired. The revenue conversion is the one that most distorts bidding when it is undercounted.
- **WORTH IT.** One function and one trigger in an existing shape and an existing idiom, and two one-call removals. No grant, policy, guard, invoice rule or mapper changes.
- **SIMPLIFY IT WITHOUT WEAKENING.** One producer for both payment events replaces two RPC emissions. The deferral is the smallest change that keeps the immutable invoice attribution SPEC-233 relies on. A split payment names no invoice rather than guessing.
- **Deliberately not changed:**
  - PAY-5, the invoice status after a door allocation: recorded, with FIN-7's package as its trigger.
  - PAY-4: the refund directions' entry shape.
  - BOOK-10: its own contract, next.
  - The registered worktree `owt/p2` is untouched.
