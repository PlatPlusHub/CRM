# ORVION MASTER EXECUTION PLAN

Status: **Permanent cumulative execution plan.** Never recreate; evolve. Batches are ordered by *foundation-reopen risk first*, not by roadmap phase. Implementation timing is the owner's; this plan states the safest order and dependencies so any batch can be executed directly from the Master documents. Cross-reference: `MASTER_GAP_REGISTER.md`, `MASTER_DEPENDENCY_GRAPH.md`.

Last updated: 2026-07-15 (date corrected — the batch statuses below already reflect SPEC-113/114/117/118/119, all post-2026-07-11; content unchanged this sync, only the stale header date).

**Guarantee:** once Batch 0 + Batch 1 are designed into canon and implemented, no later batch reopens the foundation. Every later batch is additive new tables/logic.

---

## Batch 0 — Foundation-lock + safety net (before more finance/CRM/PII data)
*These are the only items that get more expensive as data accrues. Do the test net first.*
1. **DC-16 pgTAP harness** — ✅ **DONE (SPEC-113)**. `supabase/tests/**` wired into CI; catalog-driven invariants live: RLS coverage (V5, negative-checked), append-only forbid_mutation backbone, and the money-currency scale invariant carried as a `todo` that surfaces DC-1 (have:22 want:0) without failing CI. *Was the precondition for the rest of Batch 0 — now satisfied.*
2. **Record consolidated ADRs** (design only): Party (CDD-1), Product/Inventory (CDD-2), Pricing+Tax (CDD-3/4), Accounting-depth (CDD-5), Integration+selective-outbox (CDD-7), Event-contract+registry (CDD-8/N1), Engagement+consent (CDD-10/N5), Subscription two-plane + feature flags, Franchise-read-path (CDD-9/C1), Localization (CDD-11). **Amend** ADR-0002 (UUIDv7 DC-13), ADR-0006 (event registry N1), ADR-0021 (INV-1..4).
3. **Built-table structural retrofits:** R1 (events dims), R2 (JE dims — hooks), R3 (invoice_lines — hooks), R4 (booking_items product/ref + DC-7 ticketing_deadline + BF-1), **R5 (attribution consent) ✅ DONE (SPEC-119)**, R6 (party_id + credit terms), **R7/DC-1 money precision ✅ DONE (SPEC-118)**, R8/B3 (unique keys). *(DC-13 UUIDv7 REMOVED from Batch 0 by Evidence Validation session 4 → DEFERRED with trigger; see `PENDING_ARCHITECTURE_FINDINGS.md`.)*
4. **Substrate hooks:** DC-2 idempotency-keys table, DC-4 PII-erasure boundary decision (which columns, satellite vs crypto-shred).

## Batch 1 — Cross-cutting substrate (design once; consumed everywhere)
Party + contact-identities + **single consent** (CDD-1/N5) · accounting dimensions model (CDD-5 base) · `document_sequences` + numbering (CDD-6) · **event_type registry** (N1) · integration providers/outbox/webhook-inbox (CDD-7) · **DC-3 concurrency discipline** · **DC-6 sensitive-read log** · **DC-8 reconciliation sweepers** · **DC-9 timezone anchor** · i18n translations (CDD-11 base) · feature-flags + permission×feature rule (N2) · DC-4 erasure implementation.

## Batch 2 — Pre-production hardening (all additive; no completed-phase file changed)
~~A1 (RLS init-plan wrapping)~~ ✅ **DONE (SPEC-117)** — all 63 policies wrap `current_tenant_id()` in a scalar subquery + pgTAP-guarded · ~~A2 (18 tenant_id indexes)~~ ✅ **DONE bare-index portion (SPEC-114)** — 18 tenant_id indexes added + pgTAP-guarded; composite refinements (tenant_id+status/customer_id/booking_id) still deferred to their access-path capabilities · B5 (DML grants + anon scope) + **DC-5 storage RLS** · **DC-15 service_role bounding** · B2 (CHECK constraints) · B6 (naming normalization) · B1 (reference-data integrity) · **OPS-1** (structured logging/metrics/tracing + documented RPO/RTO).

## Batch 3 — Phase 8 Offline Conversion (on the substrate)
Attribution/outbox/event-registry ready → click capture at intake, attribution engine, conversion events, delivery+retry. **Owner-Decision open:** Google Ads Data Manager transport + consent (legacy import blocked 2026-06-15).

## Batch 4 — Finance depth
invoice_lines + tax (BF-4/CDD-4) · dimension posting (R2/CDD-5) · AP `supplier_bills` (BF-7) · **DC-10 opening balances** · **DC-11 realized FX** · accounting periods · treasury/reconciliation (BF-6) · currency revaluation · amendment/change-fee/ADM (BF-10) · price-components (CDD-3).

## Batch 5 — Operational domains (pulled on owner demand; each additive)
Product/Inventory/Allotments (CDD-2) · Groups + **DC-12 passenger_relationships** (BF-2) · Engagement build-out + **DC-17 realtime** (CDD-10/RC-2) · HR/Payroll/commission (BF-5) · Procurement · Fleet/Resources (BF-12) · Franchise-consolidation + **DC-14 offboarding** (CDD-9) · Subscription/billing lifecycle (RC-1) · **RC-4 reporting/dashboard read-model layer** (first views/matviews; BF-11 statements) · Localization build-out · fraud/chargeback (BF-8/9) · **DC-18 pgvector**/AI · FOE modules (assets-depreciation, insurance-claims, workflow-engine, loyalty) as owner scopes them.

---

## Batch 6 — Foundation Completion Programme (owner-directed 2026-08-24 → current)
*Added 2026-08-27. This batch did not exist when Batches 0–5 were written: it is the owner's
zero-known-debt programme, executed package-by-package with EARN-IT. It does not supersede Batches
0–5; it runs ahead of them because each item is a LIVE defect or a day-one blocker rather than
additive capability.*

**Closed (each EARNED with behavioural proof, see `reports/history/`):**

| Package | Migration | What it actually fixed |
|---|---|---|
| WP-00 | `202607053000` | Audit-spine forgery: any employee could INSERT a forged, backdated event blamed on a colleague into an append-only table |
| WP-03 / SPEC-152 | `202607053100` | Subscription state was INVERTED — `read_only` permitted writes, `suspended`/`expired`/`cancelled` denied reads |
| WP-03 discovery | `202607053200` | Two cross-tenant aborts the gate introduced: one lapsed tenant aborted the shared SLA run and stalled the n8n conversion cursor |
| WP-01 | `202607053300` | Four creation events with real producers that never fired; timelines began mid-relationship |
| WP-02 / SPEC-153 | `202607053400` | Five Class A events + a Finance-visibility defect (`payment_allocation` events were invisible to `finance_manager`) |
| SPEC-154 | `202607053500`, `202607053600` | The ordinary employee could not quote or book — 15 canon-mandated permissions were never seeded; and `create_booking` was broken on the direct path for every role |
| SPEC-154-A | `202607053700` | The financial guard authorized by ROLE only, so canon's `assigned` scope on ENTER_COST/ENTER_SELLING_PRICE could not be honoured; guard made scope-aware and both permissions granted |
| SPEC-155 | `202607053800` | An employee could set the basis of their own commission; commission is now system-derived (10% of gross profit), overwritten on every write path, with commission_amount/company_profit exposed through the existing financial accessor. **Closes BLOCKED-3.** |

**Open, ordered by evidence (highest day-one/business impact first):**

1. **`app.create_booking_item` accepts a `p_commission_rate` parameter that is now silently ignored.**
   A caller (future UI, n8n) can pass a value, get no error and no effect — a misleading contract.
   Classified **A / FIX NOW**; separated only because removing a parameter is an integration-contract
   change that deserves its own package.
2. **SPEC-154-B — `VIEW_FINANCIAL_DOCUMENTS` cannot express canon's "assigned related only."**
   Binary tenant-wide gate; granting it would regress SPEC-139 financial privacy.
3. **WP-04 — documents/storage.** Zero storage buckets and zero storage policies exist:
   `app.upload_document` records metadata pointing at storage that does not exist. Must also narrow
   WP-03's broad `documents` subscription-gate exemption and resolve the missing `payment_proof`
   document type (canon 28 requires proof upload; the catalog has no code).
4. **Notifications.** `notifications` / `notification_deliveries` have **no producer at all**.
5. **Employee / Supplier / Branch 360 primitives.** Customer 360 and Lead 360 exist; these three do not.
6. **`public.security_events` has zero producers** — the 13 authentication event types are Supabase
   Auth events with no ORVION hook.
7. **Table/column completeness sweep** across all 72 tables — never finished.
8. **SEC-1 write-path model** — remains the open owner decision; three further forgeries of
   authoritative history are recorded as its evidence.

**Blocked on commercial decisions (none blocks the above):** BLOCKED-1 trial plan tier + duration at
provisioning; BLOCKED-2 what `MANAGE_SUBSCRIPTION` "Limited" means for Owner/CEO; **~~BLOCKED-3 who may set `commission_rate`~~ — **RESOLVED 2026-08-27** by owner rule (10% of gross
profit, system-derived), implemented in SPEC-155.

**Standing method for this batch** (`AGENTS.md §3 5b`, §6): every package ends with a cross-path
impact sweep classifying each affected execution path, and no security test may pass vacuously.

---

## Tooling / environment enablement (supports execution quality — see ARB report §Tooling)
- **Now:** pgTAP (DC-16); CR-invariant guard hook; secret scanning.
- **Recommended:** Supabase/Postgres MCP server (replaces `docker exec psql` verification with direct queries); `sqlfluff`/`squawk` migration linters in CI.
- App-facing tools (Playwright/Sentry/Stripe) remain future-gated (no app surface yet).
