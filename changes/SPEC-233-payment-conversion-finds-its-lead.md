# Change Request — SPEC-233

## Status

[x] Draft
[ ] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Make `app.map_outcomes_to_conversions` resolve a `payment_recorded` event's booking, and therefore its lead, through the invoice the event names, so the `payment_received` offline conversion is produced from ORVION's sanctioned payment path; prove all four live conversion actions end to end from their sanctioned RPCs; and record the direct-door source-event gap as CONV-8.

## Business Reason

The 2026-09-28 system-wide decision-debt census asked whether each of ORVION's five Google Ads conversion actions can actually be produced from a real business path. A CASE arm with no reachable producer is not a working conversion.

- **The intended rule.** ADR-0023 and canon 21: ORVION turns verified CRM outcomes into offline conversions. `app.map_outcomes_to_conversions` maps `lead_qualified → qualified_lead`, `booking_created → booking_created`, `payment_recorded → payment_received` and `booking_issued → ticket_issued`, keyed on `source_event_seq`. `payment_received` is the only action that carries revenue (ADR-0023: value = revenue, never profit).
- **CONV-7 (High, reproduced, latent).** Measured on the local stack at `3759ef7`, in rolled-back transactions, with a consented Google Ads click on the lead:
  - An owner created a booking with `app.create_booking`, invoiced it with `app.create_invoice`, issued the invoice, paid it in full with `app.record_payment` and advanced the booking to `issued` with `app.advance_booking`.
  - All three source events were emitted. The real mapper produced `booking_created` and `ticket_issued` and **no `payment_received`**. Nothing was deferred and no finding was written.
  - Cause: `app.record_payment` pays an INVOICE and inserts the payment without `booking_id`; the mapper found a payment's lead only through `payments.booking_id → bookings.lead_id`. `app.record_payment` is the only producer of `payment_recorded`, so the revenue conversion could never fire on the sanctioned path. No test anywhere produced `payment_received` or `ticket_issued`.
- **CONV-8 (Medium, reproduced, latent, recorded OPEN).** In the same fixture, a handler qualified a lead by direct UPDATE and an `employee` created a booking by direct INSERT. Both states landed, neither emitted `lead_qualified` / `booking_created`, and the mapper produced no conversion, while the RPCs did. Together with **BOOK-10** (`booking_issued`) and **PAY-3** (payments), every live conversion source event is emitted by its RPC only. Not repaired here: the repair is one event authority per source (an AFTER producer replacing the RPC's own emission, RBAC-1's shape) across four tables and needs its own design; its trigger is BOOK-10's, "before offline-conversion delivery goes live", which has not fired.
- **Exposure.** Primary holds 0 tenants and 0 offline conversions, and no delivery workflow exists (n8n holds 0 workflows). Both findings are latent until the first tenant's pipeline runs.
- **Why these are not existing findings.** DEAD-2 is `payments.booking_item_id`, a different column with no producer. CONV-1 is deferral of gated tenants; CONV-6 is provenance of `source_event_seq`. PAY-3 is the payment event's table door, not the mapper's lead resolution. PH8-4 is `qualified_phone_call`.
- **The repair** changes only the mapper's `resolved` CTE: a payment's booking is `coalesce(payments.booking_id, invoices.booking_id)`, where the invoice is `payload.invoice_id` of the payment's own `payment_recorded` event, joined within the event's tenant. The event is system-written and immutable (`events_append_only`), exactly as `booking_created` already resolves its lead from `payload.lead_id`. `payments.booking_id` is deliberately not written: `app.customer_balance`, `app.booking_item_profit` and `app.supplier_balance` read it, so populating it would change per-booking balances and the negative-balance issuance check.

## Risks

- **The mapper is the scheduled path for every conversion.** Mitigated: only the payment branch's booking resolution changes; the cursor, the deferral bookkeeping, the gate, the identity snapshot and the idempotency key are byte-identical. The prototype passed the full suite, including `09_…`, `13_…`, `36_…`, `66_…`, `78_…` and `119_…`, and all six HTTP suites.
- **A payment could now attach to the wrong lead.** Mitigated: the invoice is the one the payment paid, as recorded by the RPC that paid it, and the join is tenant-scoped; a payment whose invoice has no booking still maps to nothing.
- **Primary deployment replaces one function body in production.** It requires separate exact-byte owner authorization (Gate 2); this contract's approval does not authorize it.

## Supersedes / Depends On

None.

## Write Scope

- `changes/SPEC-233-payment-conversion-finds-its-lead.md`
- `supabase/migrations/20260928140000_a_payment_conversion_finds_its_lead_through_its_invoice.sql`
- `supabase/tests/137_conversion_sources_reach_the_pipeline_test.sql`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`

## Out of Scope — Files Forbidden to Modify

- `supabase/migrations/202607049300_outcome_conversion_mapper.sql`
- `supabase/migrations/202607056900_a_scheduled_job_may_not_lose_work_silently.sql`
- `supabase/migrations/20260923120000_conversion_provenance_is_platform_written.sql`
- `supabase/tests/09_conversion_delivery_lease_test.sql`
- `supabase/tests/13_conversion_identity_snapshot_test.sql`
- `supabase/tests/78_marketing_conversion_integrity_test.sql`
- `supabase/tests/119_conversion_provenance_is_platform_written_test.sql`
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`
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
- `_ORVION_CANONICAL/21_offline_conversion_engine.md`; `reports/architecture-decision-records.md` ADR-0023, ADR-0024
- `supabase/migrations/202607056900_a_scheduled_job_may_not_lose_work_silently.sql` (the mapper's current body)
- Current local `app.map_outcomes_to_conversions`, `app.record_payment`, `app.create_invoice`, `app.issue_invoice`, `app.create_booking`, `app.advance_booking`, `app.advance_lead`, `app.claim_conversion_deliveries`, `app.capture_attribution_click`
- `reports/master/MASTER_GAP_REGISTER.md` (CONV-1, CONV-6, BOOK-10, PAY-3, DEAD-2, PH8-4); `reports/master/MASTER_SURFACE_DISPOSITION.md` (`offline_conversions`)

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
| A `payment_recorded` event now resolves its booking through `payload.invoice_id` when `payments.booking_id` is NULL | `app.map_outcomes_to_conversions` (its only reader); `offline_conversions`; `app.claim_conversion_deliveries` | VERIFY | The prototype was applied as a real migration on a clean reset in a scratch worktree at `3759ef7`: migration SHA-256 `2e51432515a8f507dc68db738680c7d82abbd5abd91ea4f4856762729c2a50f5`, test SHA-256 `6f615852ec2210f0fcce7c6f6ee430b1ceb6fbaca25bf52c60d7cbbb8327c8e8`. A booked, paid and issued lead now yields `booking_created`, `payment_received` (5000 EGP, naming the payment and the booking) and `ticket_issued`. A second run adds nothing. |
| The other three branches, the cursor, deferral, gate, identity snapshot and `on conflict (source_event_seq)` | `36_…`, `66_…`, `119_…`, `09_…`, `13_…`, `78_…` | VERIFY | Byte-identical outside the `resolved` CTE's payment branch; every listed test passes unchanged in the prototype's full suite. |
| `payments.booking_id` | `app.customer_balance`, `app.booking_item_profit`, `app.supplier_balance` | VERIFY | Not written by this change; balances, profit and the negative-balance issuance check are untouched. |
| Consent and delivery | `app.claim_conversion_deliveries` | VERIFY | Unchanged. Test 137 proves a denied-consent conversion is created and never claimed, and each claimed row carries its conversion id on attempt 1. |
| Rows that already exist | Primary and local `offline_conversions` | VERIFY | The function judges only events after the cursor and recovered deferrals; no row is rewritten. Primary held 0 tenants and 0 offline conversions on 2026-09-28. |
| Suite, smoke and every HTTP door | full pgTAP; `scripts/verify_database.sql`; all six HTTP suites | VERIFY | On the prototype stack, in `-Finish`'s order: pgTAP Pass A 137 files / 2463 assertions PASS (2447 existing assertions unchanged, plus 16 new). HTTP suites: 33 + 40 + 74 + 122 + 120 + 60 = 449 passed, 0 failed. Pass B without reset: 137 / 2463 PASS. Smoke: `ALL CHECKS PASSED`, exit 0. |
| The generated API surface | `MASTER_API_CONTRACT.md`; `check_database_parity_evidence.ps1` Check L3 | VERIFY | No RPC, view or table changes; the prototype stack reports the contract matching the live surface (79 RPC endpoints, 8 views, 73 tables). It is regenerated in Step 7. |
| Measured state that moves | manifest (`Live state`, suite figure, Last Completed, Active pointer); `primary-ledger-evidence.json`; `ai-map.json`; Checks 5, 7, 15, 19 | WRITE | 234 → 235 migrations, latest `20260928140000`; 136 → 137 files / 2447 → 2463 assertions. Batch 6 coverage is unchanged at 31 of 77: `offline_conversions` is already recorded. Primary values are written only from fresh post-deploy readings. |
| Findings and disposition | `MASTER_GAP_REGISTER.md`; `MASTER_SURFACE_DISPOSITION.md`; Checks 2, 11, 16, 21, 22, 24, 25 | WRITE | Two new rows: CONV-7 (fixed) and CONV-8 (open with BOOK-10's trigger), each with Owner Decision `—`. Every other row is unchanged. The `offline_conversions` disposition row stays `PARTIAL` / `ADVERSARIAL` and gains CONV-7, CONV-8 and Test 137; Coverage totals do not move. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Clean reset, focused test, pgTAP A/B, the declared HTTP suite, smoke and in-file mutation proof | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| CONV-7, CONV-8 and the `offline_conversions` disposition accurately describe local evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 4 |
| Manifest, recorded Primary evidence and Primary ledger agree | AFTER_IRREVERSIBLE_ACTION | Step 1 | Step 7 | Step 8 |
| Manifest suite figure equals the files and plan sum | BEFORE_COMPLETION | Step 2 | Step 7 | Step 8 |
| API contract and map match their generators | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: the mapper already resolves `booking_created`'s lead from the event's own payload (`payload.lead_id`), and `app.record_payment` already writes `payload.invoice_id` into every `payment_recorded` event. The repair is one tenant-scoped join to the invoice the event names, inside the existing `resolved` CTE. The alternatives were rejected:
- setting `payments.booking_id` in `app.record_payment`: it is read by `app.customer_balance`, `app.booking_item_profit` and `app.supplier_balance`, so it would change per-booking balances and the negative-balance issuance check — new financial semantics;
- resolving through `payment_allocations`: a second path to the same fact the event already records, and ambiguous for an allocation spanning invoices;
- fixing CONV-8 in the same change: a different mechanism (event authority on four tables) whose trigger has not fired.

Added Property: For every `payment_recorded` event on the sanctioned path whose invoice belongs to a booking on an attributed lead, the mapper produces exactly one `payment_received` conversion carrying the payment's amount and currency, the payment and the booking.

Causal Negative: On the local stack at `3759ef7`, in rolled-back transactions, a booking on a lead with a consented Google Ads click was invoiced, issued and paid in full through `app.record_payment`; `payment_recorded` was emitted and the mapper produced no `payment_received`.

Positive Test Design: As the owner at `aal2`: qualify a lead through `app.advance_lead`, and create, invoice, issue, pay and issue-advance a booking through the RPCs. Then the real mapper, a second run, and the real claim.

Negative Test Design: A qualified lead with no attribution click yields no conversion. A second mapper run adds nothing (five conversions, one per source event). A later customer edit does not rewrite a conversion's identity. A denied-consent conversion exists and is never claimed. A handler's direct qualification and an employee's direct booking produce no conversion (CONV-8, pinned OPEN and written to fail when repaired).

Non-Empty Population Obligation: Six leads carry the tenant's customer; five carry a first-touch Google Ads click (L4's consent denied); L3 carries none. The sanctioned paths emit one `booking_created`, one `booking_issued`, three `lead_qualified` and one `payment_recorded`, and `app.record_payment` leaves `payments.booking_id` NULL.

Mutation Obligation: Record the mapper's `pg_get_functiondef` md5, open a savepoint and install the pre-repair resolution (a payment's lead through `payments.booking_id` only). Prove the md5 differs and that the paid booking then yields `booking_created` and `ticket_issued` and no `payment_received`. Roll back to the savepoint and prove the md5 is identical. A mutant whose installation is not proven is a harness error, never a killed mutant.

Post-Implementation Proof Obligation: Focused test, clean reset, pgTAP Pass A, the declared HTTP suite, pgTAP Pass B, smoke, the in-file mutation, generated artifacts, fresh Primary evidence, parity evidence, the Primary ledger check, repository consistency and `git diff --check`, all on the final bytes and through canonical `-Finish`.

## Implementation Steps

1. **Check** that `supabase/migrations/20260928140000_a_payment_conversion_finds_its_lead_through_its_invoice.sql` is absent. If absent, create it LF with SHA-256 `2e51432515a8f507dc68db738680c7d82abbd5abd91ea4f4856762729c2a50f5`. It holds one `create or replace function app.map_outcomes_to_conversions(p_batch integer default 500)` whose body is `202607056900`'s with exactly this change inside the `resolved` CTE: the payment branch's `booking_id` becomes `coalesce(p.booking_id, pinv.booking_id)`, a `left join public.invoices pinv` on `b.event_type_code = 'payment_recorded' and pinv.id = (b.payload ->> 'invoice_id')::uuid and pinv.tenant_id = b.tenant_id` is added (with a one-line CONV-7 comment), and `pbk` joins on `pbk.id = coalesce(p.booking_id, pinv.booking_id) and pbk.tenant_id = b.tenant_id`. The security mode stays DEFINER, the `search_path` stays empty and the ACL is unchanged. It changes no trigger, policy, grant, RPC or other function. If the target exists with different bytes, stop.
2. **Check** that `supabase/tests/137_conversion_sources_reach_the_pipeline_test.sql` is absent. If absent, create it LF with SHA-256 `6f615852ec2210f0fcce7c6f6ee430b1ceb6fbaca25bf52c60d7cbbb8327c8e8`. It is one transaction-rolled-back pgTAP file with `select plan(16);`. Its first line is `-- ATTACK-CLASSES: BUSINESS DOOR STATE INPUT REPLAY PRIVILEGE=N/A TENANT=N/A AUTH=N/A CONCURRENCY=N/A OBSERVABILITY=N/A`, and its header cites SPEC-233 and states each `N/A` reason. It implements:
   - the Non-Empty Population Obligation (1-3);
   - the Mutation Obligation (4-6);
   - the Positive and Negative Test Design for the four live conversion actions (7-14);
   - CONV-8, pinned OPEN (15-16).

   If the target exists with different bytes, stop.
3. **Check** whether `reports/master/MASTER_GAP_REGISTER.md` contains `| CONV-7 |`. If absent:
   - Add a dated freshness entry and demote the previous entry to `Previously:`.
   - Append two rows after `| ASGN-5 |`: **CONV-7** (Category `offline conversion · data integrity`, Sev `High`, Cert `📋`, Status `FIXED locally by SPEC-233 (`20260928140000`), pending Primary deployment`) and **CONV-8** (Category `offline conversion · two doors`, Sev `Medium`, Cert `📋`, Status `OPEN`, with the measurement above, its relation to BOOK-10 and PAY-3, the repair shape, and the reopening trigger "before offline-conversion delivery goes live, together with BOOK-10"). Each Req/Opt `R`, Batch `8`, Mig `A`, Owner Decision `—`, Source `SPEC-233-payment-conversion-finds-its-lead`, dates `09-28`. Each states the latent exposure, why it is not DEAD-2, CONV-1, CONV-6, PAY-3, BOOK-10 or PH8-4, and that it is pinned by `137_...`.
   - Change no other row.

   Then check whether `reports/master/MASTER_SURFACE_DISPOSITION.md`'s `offline_conversions` row names `SPEC-213-conversion-provenance-is-platform-written`. If so, keep it `PARTIAL` / `ADVERSARIAL`, set its CR to `SPEC-233-payment-conversion-finds-its-lead`, its findings to `CONV-6, CONV-7, CONV-8`, and extend its Next cell with what `137_…` proves and with CONV-8 as the open axis (creation-event parity for direct-DML rows, now measured). Add a dated freshness entry and demote the previous one. Coverage and every other row are unchanged.

   If either target already carries different content, stop.
4. **Check** for a `Pre-deploy readiness gate` Execution Log entry. If absent, run and record, with actual counts, exits and exact SHA-256 hashes:
   - a clean local reset and the focused test;
   - pgTAP Pass A, the declared HTTP suite, then pgTAP Pass B without reset;
   - `scripts/verify_database.sql` and the plan sum;
   - the in-file mutation evidence and the unrepaired counterfactual;
   - the API-contract and map generators;
   - the scope check, `git diff --check` and repository consistency.

   Treat only undeployed Primary, manifest and parity drift as expected at this boundary. Read a fresh Primary baseline, read-only: the full ordered ledger; the function and structural surfaces; the tenant and offline-conversion counts; the absence of the target migration; the mapper's current definition md5, security mode, `search_path` and ACL. Record the predicted structural delta.
5. **Check** that exact owner authorization for the migration and Test-137 SHA-256 values is recorded in the Execution Log. If absent, stop after Step 4 and present the current HEAD, the exact hashes, the fresh Primary baseline and predicted delta, and the exact Primary write requested. Approval of this contract does not authorize deployment.
6. **Check** that Primary `vrvtsxexkiiiivlkdxzp` lacks `20260928140000_a_payment_conversion_finds_its_lead_through_its_invoice`. If it is absent and deployment is separately authorized:
   - Immediately re-read HEAD, both hashes, the project URL, the full ordered ledger, target absence, the business counts and the mapper's pre-repair md5.
   - On an exact match, apply only the authorized migration through the Primary connector. If the connector assigns a temporary version, normalize only its newly inserted ledger row.
   - Read fresh: the ledger, the function surface and all ten structural surfaces, and the mapper's definition md5, security mode, `search_path` and EXECUTE ACL.

   Never contact Secondary `brplkqmbzffpxqgkkdzo`.
7. **Check** that fresh Primary evidence contains the new migration exactly once. If so:
   - Update `reports/evidence/primary-ledger-evidence.json` from those readings only.
   - In `_ORVION_CANONICAL/manifest.md`: set the `Live state` migration count, latest version, ledger and surface hashes and counts from the same readings; set the suite figure to `Suite **137 files / 2463 assertions**` after confirming `supabase/tests` holds 137 files whose literal `plan(N)` values sum to 2463 (if either differs, stop); set `Last Completed` to SPEC-233 / CONV-7, keeping the manifest within 7000 characters.
   - Mark CONV-7 `FIXED` and `DEPLOYED` in the register and change its Cert to `✅`.
   - Regenerate `MASTER_API_CONTRACT.md` and `ai-map.json` (stored LF) with the canonical generators.
   - Run `check_primary_ledger.ps1`, `check_database_parity_evidence.ps1`, repository consistency and `git diff --check`.

   If Primary is unproven, stop.
8. **Check** for a `Post-deploy local certification` Execution Log entry. If absent:
   - Run canonical `pwsh -NoProfile -File scripts/check_agent_continuity.ps1 -Finish` and require `LOCAL_CERTIFY: READY`.
   - Independently Review the committed implementation against every Acceptance Criterion. After `Verdict: Confirmed Complete`, set Runtime Checkpoint DONE, transition Complete, keep `Next capability` as Batch 6 Slice 31, clear `Active Change Request` and regenerate `ai-map.json` LF.
   - Prove the committed range with `-Gate -BaseRef origin/main`, publish the exact committed candidate and require exact-SHA candidate CI. Promote the same accepted SHA, run `-Certify` for `REMOTE_CERTIFY: READY`, verify synchronized clean refs and remove permitted scratch files.

## Acceptance Criteria

- [ ] A booking on an attributed lead that is invoiced, issued and paid through `app.record_payment` yields exactly one `payment_received` conversion carrying the payment's amount and currency, the payment and the booking, alongside `booking_created` and `ticket_issued`.
- [ ] A lead qualified through `app.advance_lead` yields exactly one `qualified_lead` keyed to its own event; a qualified lead with no click yields none; a second mapper run adds nothing.
- [ ] A later customer edit does not rewrite a conversion's identity; a denied-consent conversion is created and never claimed; each claimed row carries its conversion id on attempt 1.
- [ ] With the pre-repair resolution installed in a savepoint, the paid booking yields no `payment_received`; the restored mapper is byte-identical. On the unrepaired stack the decisive assertions fail.
- [ ] CONV-7 (High) is registered `FIXED` / `DEPLOYED` and CONV-8 (Medium) `OPEN` with its trigger and pinned by `137_...`; the `offline_conversions` row names CONV-6, CONV-7 and CONV-8 and stays `PARTIAL`; every other row and the Coverage totals are unchanged.
- [ ] The migration and Test 137 match their authorized SHA-256 values. Primary, the recorded evidence, the manifest (235 migrations; 137 files / 2463 assertions), the API contract and `ai-map.json` agree.
- [ ] Primary `vrvtsxexkiiiivlkdxzp` received only the authorized migration and no business-data write, and Secondary `brplkqmbzffpxqgkkdzo` was never contacted.
- [ ] No file outside Write Scope was created, modified or deleted.

## Execution Log

None.

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

- **EARN IT.** Reproduced end to end from the sanctioned RPCs: the only revenue-carrying conversion action could not be produced by the only producer of its source event. A CASE arm with no reachable producer is not a working conversion.
- **WORTH IT.** One join inside the existing resolution, no data reconciliation (Primary has 0 conversions), and it is the only change on the conversion path that does not wait for an owner decision or for the delivery workflow. A reopen trigger was rejected: the defect would surface only as a silently empty conversion action after delivery goes live.
- **Deliberately not changed:** CONV-8, BOOK-10 and PAY-3 (one door-parity package with BOOK-10's trigger); PH8-4 (`qualified_phone_call` needs an owner definition); PH8-2/DELIV-1, PH8-3, PH8-6, PH8-7, PH8-8 and the Data Manager build-spec corrections (a separate governance contract). The registered worktree `owt/p2` is untouched.
