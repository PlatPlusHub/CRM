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
   change that deserves its own package. **DONE 2026-08-27 — SPEC-156 (`202607053900`).** Dropped
   rather than replaced, so no stale overload survived; guarded in `41_commission_derivation_test.sql`.
1b. **Subscription lifecycle, trial and platform authority — DONE 2026-08-27, SPEC-157
   (`202607054000`).** Closes **BLOCKED-1**, **BLOCKED-2** and canon **C5**. Three defects were
   proven live first: (i) `app.provision_tenant` created **no subscription row**, and
   `app.subscription_allows_write` fails closed on absence, so **every newly provisioned tenant was
   unable to write on all 42 gated tables** — day one of a real agency failed; (ii) `ends_at` /
   `grace_ends_at` / `read_only_started_at` were **decorative** — read by one reporting view,
   consumed by no logic, advanced by no job, so an expired trial kept write access forever;
   (iii) `tenants.status` was unconstrained free text nothing read, a second lifecycle competing
   with the authority canon 35 §8 names. Fixed: 30-day full-feature (Enterprise) trial created at
   provisioning; write-once trial stamp on `tenants`; dates load-bearing in the gate **and** advanced
   by a daily `pg_cron` job per canon 26; 5-value `subscription_period` catalog with **lifetime
   modelled as `ends_at is null`** under CHECK constraints; the 11 subscription event types given
   their first producers. Platform authority is `service_role`-only functions, **not** a tenant
   permission — `app.has_permission` is tenant-bound by construction, so `MANAGE_SUBSCRIPTION`
   remains held by no role and a test now pins that. Guard: `42_subscription_lifecycle_test.sql`.
1c. **SPEC-158 — tenant license activation credential — DONE 2026-08-27 (`202607054100`).** Closes
   canon **C4**, open since 2026-07-15, where canon 09 recorded the activation-code idea and said it
   "requires security review before implementation". That review's outcome: **deliberately not
   TOTP** — `totp_enrollments` stores no secret by design and canon 34 / ADR-0017 place every
   authentication factor in Supabase Auth, so a per-tenant TOTP seed would be the first auth secret
   ORVION ever stored; and TOTP is a *repeating* credential where a *single-use* one is required.
   Built instead: a single-use, hashed (SHA-256), expiring token whose plaintext is returned once and
   never persisted, carrying the plan/period/auto-renew terms the Platform Owner fixes at issuance so
   redemption can apply them but never choose them. Replay closed by consumption, rotation is
   re-issuance (which revokes the outstanding token), revocation is a platform function.
   `public.security_events` gained its **first producers** — a gap open since the WP-00 sweep.
   Guard: `43_license_activation_test.sql`. **Known limitation LIC-1:** a *refused* redemption is not
   audited — `raise` rolls back its own audit row and PostgreSQL has no autonomous transaction. The
   first version shipped that INSERT anyway and its own test caught that the row was never written;
   rather than keep code that looks like auditing and never runs, the limitation is stated in the
   function body, pinned by an assertion, and classified **BLOCKED BY EXTERNAL DEPENDENCY**
   (an out-of-transaction audit hop). Successful redemptions *are* audited; replay is closed
   regardless; a 128-bit token makes guessing infeasible.
1d. **SPEC-159 — employee performance & earnings report — DONE 2026-08-27 (`202607054300`).**
   `reporting.my_sales_performance`, a `security_invoker` view scoped by
   `sales_owner_user_id = app.current_user_id()`. Money comes from
   `cross join lateral app.item_financials(bi.id)` — `authenticated` cannot SELECT `cost_amount` or
   `commission_rate` (proven), so a view naming them would fail for every employee; this is what
   keeps SPEC-139 intact rather than weakened. A colleague's rows are **absent, not masked**: a
   masked row still discloses that a colleague sold something, to whom, and when. Archived and
   `cancelled`/`no_show` items are excluded, reusing `app.booking_item_profit`'s existing rule.
   LEFT joins deliberately, because an item can be the caller's while its parent booking is not
   visible to them — an inner join would under-report the employee's own commission.
   **Exactly one view** was added: the employee already reads their own leads, quotations, customers
   and bookings under RLS, and `reporting.sales_activity` / `lead_performance` already aggregate per
   owner, so only the money needed a new object. **No EXPORT permission invented** — canon 25 defines
   none, every listed filter is a WHERE clause over exposed columns, and PostgREST serves the same
   view as CSV. Airline reporting is `supplier_type_code = 'airline'`; canon 32 defers airline
   reference tables, so no dimension was invented. Guard: `45_employee_performance_test.sql`.
1e. **SPEC-159-A — per-passenger financial authority — DONE 2026-08-27 (`202607054200`).**
   **A prerequisite discovered inside SPEC-159's lineage pass and inserted rather than skipped.**
   `booking_item_passengers.cost_amount_override` / `selling_amount_override` — the per-passenger
   fare and cost — had none of the protection their `booking_items` siblings have carried since
   SPEC-139/145/154-A: the column was **readable by `authenticated`** (proven live, while
   `booking_items.cost_amount` is not), writable through `link_passenger_to_booking_item` on **any
   item the caller could see** with only `CREATE_BOOKING_ITEM` and no scope check, and writable by
   direct DML besides. RLS made it reachable rather than theoretical — department continuity means a
   colleague's item is visible. It survived four financial packages because
   `link_passenger_to_booking_item` had **zero test coverage**. Fixed with the same permissions, the
   same `app.is_my_booking_item` scope test and the same tenant-wide exemption the parent table uses;
   enforced by a trigger because direct DML was the unguarded path. Guard:
   `44_passenger_financial_authority_test.sql`. Related open items, both recorded not hidden:
   **DEAD-1** the override columns still have no reader (kept, not dropped — per-passenger pricing is
   inevitable in a travel agency and AGENTS.md §3 keeps inevitable structure); **DEAD-2**
   `refunds.booking_item_id` and `payments.booking_item_id` have no producer, so item-level refund
   and payment attribution is a genuine gap for the finance package.
2. **SPEC-154-B — `VIEW_FINANCIAL_DOCUMENTS` cannot express canon's "assigned related only."**
   Binary tenant-wide gate; granting it would regress SPEC-139 financial privacy.
3. **WP-04 — documents/storage. NEXT.** Discovery pass run 2026-08-27; findings proven live and
   recorded here so the package starts from evidence rather than from a re-scan:
   * **`storage.buckets` = 0, `storage.objects` = 0, `pg_policies` in schema `storage` = 0 on
     Primary**, while `document_versions.storage_path` is **NOT NULL**. Every upload is therefore
     required to record a path into storage that does not exist.
   * **DOC-1 / DOC-3 — DONE 2026-08-27 as WP-04-A (`202607054400`).** Re-introspection found DOC-1
     was wider than first recorded: `app.add_document_version` takes `p_storage_path` too, and
     `authenticated` holds INSERT/UPDATE on `document_versions` directly — three caller-controlled
     paths, not one. **DOC-3** (new): nothing forced anyone through the RPC, so a version's
     `storage_path` could be rewritten by direct DML with no permission check and no event — the
     WP-00 forgery class in the document domain. Fixed by derivation, not validation:
     `app.document_storage_path` is the single source of the object key (tenant-first, so storage
     policy can isolate on segment 1, and provider-independent by design), and a trigger derives
     `version_number` / `storage_path` / `uploaded_by` on INSERT while freezing a version's identity
     on UPDATE. Direct DML now costs `CREATE_DOCUMENT_VERSION` — verified safe first: every role
     holding `UPLOAD_DOCUMENT` already holds it. Guard: `46_document_write_integrity_test.sql`.
     *Correction recorded:* a partial unique index for "one current version" was attempted and
     rejected by the database — `202607041900` already created it, so that invariant was never open.
   * **WP-04-B — NEXT. DOC-2 is three layers deep, not one.** (i) the `document_type` catalog has no
     `payment_proof` value; (ii) **`subscription_payment` IS already a `document_link_target_type`
     but `app.upload_document` has no branch for it**, so it falls through to `else false` and
     raises; (iii) `document_links.subscription_payment_proof_id` is populated by no code path. A
     circular dependency (`subscription_payment_proofs.document_id` is NOT NULL while the link needs
     the proof id) means the fix is a dedicated transactional RPC —
     `app.upload_subscription_payment_proof` — not another parameter on `upload_document`. Then the
     platform-side review that transitions the subscription and emits
     `subscription_payment_approved` / `_rejected`.
   * **The subscription-gate exemption (owner directive §7) belongs with WP-04-B.** Confirmed live:
     **zero** gate triggers on `documents` / `document_versions` / `document_links`, so a suspended
     tenant can create ANY document, not merely a renewal proof. Narrowing it requires
     `payment_proof` to exist first — that type is the discriminator by which the gate tells a
     renewal proof from an ordinary document — so sequencing it before DOC-2 would have meant
     inventing a placeholder.
   * Also owns SPEC-154-B's
     document-classification boundary (`VIEW_FINANCIAL_DOCUMENTS` is a binary tenant-wide gate that
     cannot express canon's "assigned related only").
   * **Provider evaluation is the gate** (owner directive §14): decided on tenant isolation, private
     objects, signed URLs, versioning, retention, deletion, recovery, backups, size limits,
     operational simplicity, scalability, auditability and n8n integration — explicitly **not** on
     cost or on Supabase already being present. Options to compare: Supabase Storage, Google Cloud
     Storage, Google Drive, OneDrive/SharePoint. One constraint is already evidence, not preference:
     every non-Supabase option needs an external credential, which AGENTS.md §6 requires the owner to
     enter directly into its destination — so those options carry a BLOCKED — EXTERNAL DEPENDENCY
     step that Supabase Storage does not, and the evaluation must weigh that honestly rather than let
     it silently decide the outcome.
4. **Notifications.** `notifications` / `notification_deliveries` have **no producer at all**.
5. **Employee / Supplier / Branch 360 primitives.** Customer 360 and Lead 360 exist; these three do not.
6. **`public.security_events` has zero producers** — the 13 authentication event types are Supabase
   Auth events with no ORVION hook.
7. **Table/column completeness sweep** across all 72 tables — never finished.
8. **SEC-1 write-path model** — remains the open owner decision; three further forgeries of
   authoritative history are recorded as its evidence.

**Blocked on commercial decisions (none blocks the above):**
~~BLOCKED-1 trial plan tier + duration at provisioning~~ — **RESOLVED 2026-08-27**: owner set a
30-day full-feature trial; "full feature" resolved to the Enterprise plan on evidence (it is the only
plan with all 22 entitlements enabled), implemented in SPEC-157.
~~BLOCKED-2 what `MANAGE_SUBSCRIPTION` "Limited" means for Owner/CEO~~ — **RESOLVED 2026-08-27**, and
resolved in the opposite direction to the obvious reading: it is granted to **neither**. Platform
authority cannot be a tenant permission at all, because `app.has_permission` resolves the caller
through `public.users` joined on `current_tenant_id()` — every role holder is inside exactly one
tenant by construction. SPEC-157 places it on `service_role` instead.
~~BLOCKED-3 who may set `commission_rate`~~ — **RESOLVED 2026-08-27** by owner rule (10% of gross
profit, system-derived), implemented in SPEC-155.
**New, and none blocks current work:** **BLOCKED-4** — once booking-item ownership becomes
transferable (it is not today: `create_booking_item` sets all three ownership fields to the creator
and no reassignment path exists), does commission follow the new sales owner or stay with the
original seller? Pure compensation policy. **BLOCKED-5** — may the Platform Owner ever deliberately
re-grant a trial? Implemented conservatively as never (write-once stamp). **CANON-26-1** — canon 26
admits `suspended` only from `read_only`, so an active tenant cannot be suspended in one step;
`active -> cancelled` is available. Encoded as canon states rather than widened by assumption.

**Standing method for this batch** (`AGENTS.md §3 5b`, §6): every package ends with a cross-path
impact sweep classifying each affected execution path, and no security test may pass vacuously.

---

## Tooling / environment enablement (supports execution quality — see ARB report §Tooling)
- **Now:** pgTAP (DC-16); CR-invariant guard hook; secret scanning.
- **Recommended:** Supabase/Postgres MCP server (replaces `docker exec psql` verification with direct queries); `sqlfluff`/`squawk` migration linters in CI.
- App-facing tools (Playwright/Sentry/Stripe) remain future-gated (no app surface yet).
