# ORVION MASTER GAP REGISTER

Status: **Permanent single source of truth for architectural findings.** Never recreate; only evolve. Every future review updates this file (add rows, update status/dates, never delete — resolved items are marked Resolved and kept for history).

Owner policy in force: **Earn-It suspended for design/assurance only.** Findings are classified **Architecturally Required** (evidence proves it belongs in a complete modern Travel ERP/CRM/Revenue platform → its *design* must exist now) or **Architecturally Optional** (genuine independent/optimization choice). **Implementation timing belongs only to the owner.** The phrase "can be added later" is not used.

Last updated: 2026-07-15 (Repository Recovery synchronization — status column reconciled to `MASTER_EXECUTION_PLAN.md`, the verified current-truth for implementation state; no finding added or removed, statuses only).

## Validation reclassifications (2026-07-11 session 4 — authoritative)
The 9-stage evidence pipeline (`ARCHITECTURE_PROOF_LOG.md`) moved these rows OUT of accepted-required status. Their register rows below remain for traceability but are **superseded by these statuses**:
- **DC-13** UUIDv7 → **DEFERRED / PENDING** (out of Batch 0; benefit only at millions of rows, Supabase=PG17). See `PENDING_ARCHITECTURE_FINDINGS.md` RJ-1.
- **DC-6** sensitive-read log, **DC-8** self-healing, **DC-10** opening-balance domain, **DC-20** custom-fields, **DC-22** data-residency(KSA driver), **DC-24** tenant-custom-roles, **DC-25** retention → **PENDING (OPTIONAL / NEEDS MORE EVIDENCE)**.
- **DC-12** kept REQUIRED but **simplified** to `passengers.mahram_passenger_id` self-FK.
- **DC-21** kept REQUIRED but **presentation-layer** (store Gregorian, render Hijri) — near-zero schema impact.
- **Accepted-required (unchanged):** DC-1,2,3,4,5,7,9,11,14,15,16,23,27,28 + all inherited R/A/B/BF/CDD/N/INV/RC/OPS.
- **Net:** Batch-0 required-now structural touches = **R1–R8 + DC-1 only.**

Field model: the table below carries the queryable columns. The **per-ID detail blocks** below carry the full field set (Evidence · Business/Technical/Architectural justification · Affected tables/relationships/RPCs/events/catalogs/dropdowns/permissions/dashboards/reports/integrations/AI/MCP/automation/docs/ADR/canon/roadmap · Migration · Additive? · Root cause · Dependencies · Safest order). Inherited findings reference their source report for verbose fields to avoid loss or duplication.

Legend — **Req/Opt:** R = Architecturally Required · O = Architecturally Optional. **Mig:** M = modifies built object · A = additive. **Status:** OPEN · DESIGN-READY · RESOLVED · VERIFIED. **Cert:** 🔒 foundation-lock (cheapest before data) · 🛡 pre-production hardening · ➕ additive capability · 📋 backlog/ops · ✅ resolved.

## Register

| ID | Title | Category | Sev | Req/Opt | Batch | Mig | Cert | Status | Owner Decision | Source | Added | Updated |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| DC-1/R7 | Money columns numeric(14,2) truncate 3-dp currencies | correctness | Critical | R | 0 | M | 🔒 | ✅IMPLEMENTED (SPEC-118) | done | cert-2026-07 | 07-10 | 07-13 |
| R1 | events + schema_version/correlation_id/causation_id | event-contract | High | R | 0 | M | 🔒 | DESIGN-READY | synthesis | 07-09 | 07-11 |
| R2 | journal_entry_lines + accounting dimensions | finance | High | R | 0→4 | M | 🔒 | DESIGN-READY | synthesis | 07-09 | 07-11 |
| R3 | invoices + invoice_lines (INV-1 roll-up) | finance | High | R | 0→4 | M | 🔒 | DESIGN-READY | synthesis | 07-09 | 07-11 |
| R4 | booking_items + product/reference links + ticketing_deadline | reservations | High | R | 0 | M | 🔒 | DESIGN-READY | synthesis/BF-1/DC-7 | 07-09 | 07-11 |
| R5 | attribution_clicks + gbraid/wbraid/consent; leads.attribution_click_id | attribution | High | R | 0→3 | M | 🔒 | ✅IMPLEMENTED (SPEC-119) | done | 07-09 | 07-13 |
| R6 | customers/suppliers + party_id; customer credit terms | party | High | R | 0 | M | 🔒 | DESIGN-READY | synthesis/BF-3 | 07-09 | 07-11 |
| R8/B3 | business-key UNIQUE constraints (5 keys) | integrity | High | R | 0 | M | 🔒 | DESIGN-READY | audit B3 | 07-09 | 07-11 |
| DC-13 | UUIDv7 PK on high-insert tables (amend ADR-0002) | scalability | Med | NME | trigger | M | 📋 | MOVED→PENDING | deferred (RJ-1) | ARB-07-11 | 07-11 | 07-11 |
| DC-16 | pgTAP regression harness + RLS/invariant tests | quality | High | R | 0 | A | 🔒 | ✅IMPLEMENTED (SPEC-113) | done | ARB-07-11 | 07-11 | 07-15 |
| DC-2 | write-idempotency keys on mutating RPCs | correctness | High | R | 1 | A | 🔒 | DESIGN-READY | cert-2026-07 | 07-10 | 07-11 |
| DC-3 | concurrency control (oversell lock + lost-update guard) | concurrency | High | R | 1 | A | 🔒 | DESIGN-READY | cert-2026-07 | 07-10 | 07-11 |
| DC-4 | PII erasure boundary (pseudonymization/crypto-shred) | privacy | High | R | 0→1 | A/M | 🔒 | DESIGN-READY | cert-2026-07 | 07-10 | 07-11 |
| N5 | single consent model (party-owned) | privacy | High | R | 1 | A | 🔒 | DESIGN-READY | synthesis | 07-09 | 07-11 |
| N1 | event_type registry validated by record_event (amend ADR-0006) | event-contract | High | R | 1 | A | 🔒 | DESIGN-READY | synthesis | 07-09 | 07-11 |
| INV-1..4 | derived-primitive invariants (amend ADR-0021) | finance | High | R | 0 | A | 🔒 | DESIGN-READY | synthesis | 07-09 | 07-11 |
| DC-5 | document binary storage + Storage RLS | security | High | R | 2 | A | 🛡 | DESIGN-READY | cert-2026-07 | 07-10 | 07-11 |
| DC-10 | opening-balance / legacy AR-AP onboarding | accounting | High | R | 4 | A | ➕ | OPEN | pending | ARB-07-11 | 07-11 | 07-11 |
| A1 | RLS (select …) init-plan wrapping | performance | High | R | 2 | M | 🛡 | ✅RESOLVED (SPEC-117) | done | audit A1 | 07-09 | 07-15 |
| A2 | 18 missing tenant_id indexes | performance | High | R | 2 | A | 🛡 | ✅RESOLVED bare-index (SPEC-114); composite deferred | partial | audit A2 | 07-09 | 07-15 |
| B5 | DML grants to authenticated (+anon read scope) | access | High | R | 2 | A | 🛡 | ✅authenticated-DML DONE (202607043400); anon scope→DC-23 | partial | audit B5 | 07-09 | 07-15 |
| B2 | remaining DB CHECK constraints (only 12 exist) | integrity | Medium | R | 2 | A | 🛡 | OPEN | pending | audit B2 | 07-09 | 07-11 |
| B1 | reference-data integrity (+airports) | reference | Medium | R | 2 | A | 🛡 | OPEN | pending | backlog | 07-04 | 07-11 |
| B6 | status-column naming normalization | consistency | Low | R | 2 | M | 🛡 | OPEN | pending | audit B6 | 07-09 | 07-11 |
| DC-15 | service_role/Edge least-privilege + tenant assertions | security | Medium | R | 2 | A | 🛡 | OPEN | pending | ARB-07-11 | 07-11 | 07-11 |
| DC-6 | sensitive-read access log | privacy | Medium | R | 1 | A | ➕ | DESIGN-READY | cert-2026-07 | 07-10 | 07-11 |
| DC-8 | self-healing / reconciliation sweepers | operations | Medium | R | 1 | A | ➕ | DESIGN-READY | cert-2026-07 | 07-10 | 07-11 |
| DC-9 | branch timezone anchor for SLA | operations | Low-Med | R | 1 | A | ➕ | DESIGN-READY | cert-2026-07 | 07-10 | 07-11 |
| DC-11 | realized FX gain/loss posting | accounting | Medium | R | 4 | A | ➕ | OPEN | pending | ARB-07-11 | 07-11 | 07-11 |
| DC-12 | passenger_relationships (mahram/family) | reservations | Med-High | R | 5 | A | ➕ | OPEN | pending | ARB-07-11 | 07-11 | 07-11 |
| DC-14 | whole-tenant offboarding/export/purge | saas | Medium | R | 5 | A | ➕ | OPEN | pending | ARB-07-11 | 07-11 | 07-11 |
| DC-17 | Supabase Realtime publication scope | engagement | Low-Med | R | 5 | A | ➕ | OPEN | pending | ARB-07-11 | 07-11 | 07-11 |
| DC-18 | pgvector semantic layer for AI | ai | Low | O | 5 | A | 📋 | OPEN | pending | ARB-07-11 | 07-11 | 07-11 |
| CDD-1/BF-3 | Party/Account model (roles: customer/supplier/sub-agent/corporate) | party | High | R | 1 | A/M | ➕ | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| CDD-2 | Product/Package/Component + Inventory-Allotment | reservations | High | R | 5 | A | ➕ | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| CDD-3 | Price-component model | pricing | High | R | 4 | A | ➕ | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| BF-4/CDD-4 | Tax / VAT (TOMS / GCC margin scheme) | tax | High* | R | 4 | A | ➕ | DESIGN-READY | stress-test | 07-09 | 07-11 |
| CDD-5/BF-6/BF-7 | Accounting depth: subledgers/dimensions/periods/AP bills/treasury | accounting | High | R | 4 | A/M | ➕ | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| CDD-6 | document_sequences + next_document_number | finance | Medium | R | 1 | A | ➕ | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| CDD-7 | Integration layer + selective transactional outbox + webhook inbox | integration | High | R | 1 | A | ➕ | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| CDD-9 | Tenant hierarchy / franchise (consolidation read path, C1) | saas | High | R | 5 | A | ➕ | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| CDD-10 | Omnichannel contact-identity + conversation channel model | engagement | High | R | 5 | A/M | ➕ | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| CDD-11 | Localization / i18n (translations) | localization | Medium | R | 5 | A | ➕ | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| BF-1 | PNR/ticket/confirmation refs | reservations | High | R | 0→3 | A | 🔒 | DESIGN-READY | stress-test | 07-09 | 07-11 |
| BF-2 | groups / rooming list | reservations | High | R | 5 | A | ➕ | DESIGN-READY | stress-test | 07-09 | 07-11 |
| BF-5 | HR / employees / payroll / commission settlement | hr | Medium | R | 5 | A | ➕ | DESIGN-READY | stress-test | 07-09 | 07-11 |
| BF-8 | chargeback / payment dispute | finance | Medium | R | 5 | A | ➕ | DESIGN-READY | stress-test | 07-09 | 07-11 |
| BF-9 | blacklist / fraud / risk flags | risk | Medium | R | 5 | A | ➕ | DESIGN-READY | stress-test | 07-09 | 07-11 |
| BF-10 | amendment / change-fee / fare-difference workflow | finance | Medium | R | 4 | A | ➕ | DESIGN-READY | stress-test | 07-09 | 07-11 |
| BF-11 | customer account statements | reporting | Medium | R | 5 | A | ➕ | DESIGN-READY | stress-test | 07-09 | 07-11 |
| BF-12 | guide/vehicle resource scheduling | operations | Low-Med | R | 5 | A | ➕ | DESIGN-READY | stress-test | 07-09 | 07-11 |
| RC-1 | Subscription/billing lifecycle + entitlement enforcement | saas | Medium | R | 5 | A | ➕ | DESIGN-READY | design-evolution/audit D | 07-09 | 07-11 |
| RC-2 | Notification engine (templates/preferences/routing) | engagement | Medium | R | 5 | A | ➕ | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| RC-4 | Reporting/Dashboards read-model layer (0 views today) | reporting | Medium | R | 5 | A | ➕ | DESIGN-READY | design-evolution/ARB | 07-09 | 07-11 |
| B7 | pg_trgm fuzzy dedup | crm | Low | O | 5 | A | 📋 | OPEN | pending | backlog | 07-04 | 07-11 |
| B8 | partitioning high-volume tables | scalability | Low | O | 5 | A | 📋 | OPEN | pending | backlog | 07-04 | 07-11 |
| OPS-1 | structured logging/metrics/tracing + documented RPO/RTO | observability | Medium | R | 2 | ops | 📋 | OPEN | pending | audit C | 07-09 | 07-11 |
| FOE-4 | Asset lifecycle / depreciation | assets | Low | O | 5 | A | 📋 | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| FOE-5 | Insurance claims | insurance | Low | O | 5 | A | 📋 | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| FOE-6 | Configurable workflow engine (overlay) | workflow | Low | O | 5 | A | 📋 | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| FOE-8 | Loyalty / rewards | crm | Low | O | 5 | A | 📋 | DESIGN-READY | design-evolution | 07-09 | 07-11 |
| DC-19 | Multi-book accounting (statutory vs management ledger) | accounting | Low | O | 4 | A | 📋 | OPEN | pending | design-authority-07-11 | 07-11 | 07-11 |
| DC-20 | Metadata / custom-field / custom-object extensibility (+ white-label theming) | extensibility | High | R | 1 | A | ➕ | OPEN | pending | final-proof-07-11 | 07-11 | 07-11 |
| DC-21 | Hijri (Islamic) calendar support (Umrah/Hajj core market) | localization | Med-High | R | 5 | A | ➕ | OPEN | pending | final-proof-07-11 | 07-11 | 07-11 |
| AUDIT-1 | Event-vocabulary/catalog drift: `app.merge_customer_identity`/`app.advance_refund` emitted `event_type` codes never registered, silently broken by N1's later hardening (found by full-repository audit treating migrations as ground truth, not the manifest) | correctness | Critical | R | n/a | M | 🔒 | ✅RESOLVED (SPEC-120) | done | audit-2026-08-10 | 08-10 | 08-10 |
| AUDIT-2 | `feature_entitlements` per-plan seed data (`subscription_plans` itself resolved by SPEC-120) — canon's numeric limits have no schema home, no unlimited/custom encoding convention, Enterprise's feature list is not fully enumerable from canon | saas | Medium | R | 5 | A | ➕ | OPEN | owner: limit-metric storage + unlimited encoding + Enterprise scope (see `future-backlog.md`) | audit-2026-08-10 | 08-10 | 08-10 |
| DC-22 | Data residency / multi-region (Saudi PDPL + EU GDPR localization) | compliance | Med-High | R | 2 | A | ➕ | OPEN | pending | final-proof-07-11 | 07-11 | 07-11 |
| DC-23 | Public API contract + versioning + rate-limiting/quota | api | Medium | R | 2 | A | ➕ | OPEN | pending | final-proof-07-11 | 07-11 | 07-11 |
| DC-24 | Tenant-custom roles/permissions (RBAC extensibility) | access | Medium | R | 1 | A/M | ➕ | OPEN | pending | final-proof-07-11 | 07-11 | 07-11 |
| DC-25 | Data retention / archival / cold-storage strategy | operations | Medium | R | 2 | A | ➕ | OPEN | pending | final-proof-07-11 | 07-11 | 07-11 |
| DC-26 | Plugin / extension / marketplace SDK architecture | extensibility | Low | O | 5 | A | 📋 | OPEN | pending | final-proof-07-11 | 07-11 | 07-11 |
| DC-27 | Explicit state-based (not event-sourced) + CQRS-lite stance (ADR) | architecture | Medium | R | 0 | A | ➕ | OPEN | pending | final-proof-07-11 | 07-11 | 07-11 |
| DC-28 | Migration rollback/forward-fix + legacy bulk-import framework | operations | Medium | R | 2 | A | ➕ | OPEN | pending | final-proof-07-11 | 07-11 | 07-11 |
| DC-29 | Offline / connectivity-resilience (client sync/conflict) | operations | Low | O | 5 | A | 📋 | OPEN | pending | final-proof-07-11 | 07-11 | 07-11 |

\* BF-4 severity High iff the launch tenant is VAT-registered (likely KSA/GCC).

---

## Detail blocks (full field set — new & consolidated findings)

> Inherited findings (A*, B*, BF*, CDD*, RC*, FOE*, N*, INV*, R1–R6, R8) carry their verbose fields in their source reports (`engineering-audit`, `business-stress-test`, `design-evolution-plan`, `architecture-synthesis`). Reproduced here only where this ARB added or changed a field. The DC-series and DC-1/R7 detail below is authoritative.

### DC-1 / R7 — Money precision
- **Root cause:** money type chosen (`numeric(14,2)`) before the multi-currency reference model (`currencies.decimal_places`) was reconciled with storage scale; no test asserts scale ≥ currency precision. **Why missed:** all prior reviews checked table/column existence, never scale.
- **Business:** financial inaccuracy/un-reconcilable balances in GCC/Umrah/Hajj (KWD/BHD/OMR/JOD = 3-dp). **Technical:** truncation on write; the 3 derived RPCs inherit it. **Architectural:** money is cross-cutting to finance/booking/marketing.
- **Affected — tables:** all 22+ money columns (invoices, payments, refunds, payment_allocations, journal_entry_lines, booking_items, quotation_items, campaign_daily_metrics, offline_conversions, chart_of_accounts opening, exchange_rate_adjustments, subscription/plan amounts). **RPCs:** customer_balance, supplier_balance, booking_item_profit, all finance write RPCs. **Events:** none. **Catalogs:** none. **Permissions:** none. **Reports/dashboards:** all finance. **ADR:** amend/append (money-storage standard). **Canon:** `30` conventions, `31` schema. **Roadmap:** Batch 0.
- **Migration:** yes (ALTER TYPE scale). **Additive?** No — modifies built columns; must precede finance data. **Order:** Batch 0, after pgTAP (DC-16). **Design:** `numeric(19,4)` + rounding via `currencies.decimal_places`. **Req/Opt:** R.

### DC-2 — Write idempotency
- **Root cause:** RPCs designed for authorization/state-correctness, not client-retry semantics; idempotency solved only at integration edges. **Business:** duplicate payments/bookings/invoices on retry. **Technical:** no dedup on inbound writes. **Affected:** new `idempotency_keys` table; optional param on mutating RPCs; no catalog/event/permission. **Migration:** additive. **Order:** Batch 1 (with first client). **Req:** R.

### DC-3 — Concurrency control
- **Root cause:** CHECK constraints mistaken for concurrency guarantees; no locking discipline documented. **Business:** oversold departures/allotments; lost updates. **Affected:** hold/issue RPCs (FOR UPDATE / advisory locks); optional `row_version` pattern; inventory tables (CDD-2). **Migration:** additive (logic + optional column). **Order:** Batch 1, before inventory ships. **Req:** R.

### DC-4 — PII erasure boundary
- **Root cause:** consent (inbound) modeled; erasure (outbound GDPR Art.17) owned by no domain; events already ID-based (erasure-safe) but CRM PII is raw. **Affected:** PII columns in customers/passengers → satellites or crypto-shred; `app.erase_party`; `party_erased` event; erasure_reason catalog; ERASE_PARTY permission. **Migration:** additive + possible PII relocation. **Order:** boundary decided Batch 0, implemented Batch 1. **Req:** R. **Evidence:** validated pattern (pseudonymization/crypto-shredding) — see cert report sources.

### DC-5 — Document binary storage
- **Root cause:** all reviews at relational layer; Supabase Storage is a separate surface; `financial_documents` enforces stricter-than-row visibility the byte layer must mirror. **Affected:** Storage buckets + Storage RLS keyed to tenant/visibility; Edge upload relay (size/MIME/AV); signed URLs. **Integrations:** Supabase Storage, AV scanner. **Migration:** additive (config). **Order:** Batch 2 with DML grants. **Req:** R.

### DC-6 — Sensitive-read audit
- **Root cause:** event philosophy records business milestones (writes), not reads; read-audit is a security control that fell between events and security_events. **Affected:** `sensitive_access_log`; guarded read RPCs for passports/financial-docs/PII; VIEW_ACCESS_LOG permission. **Migration:** additive. **Order:** Batch 1. **Req:** R.

### DC-7 — Ticketing deadline
- **Root cause:** BF-1 captured post-issuance references; the pre-issuance fare-hold expiry was never enumerated. **Business:** agents track ticketing time limits in WhatsApp; PNRs lost. **Affected:** `booking_items.ticketing_deadline` (folds into R4); pg_cron sweep → `ticketing_deadline_approaching`/`expired` events + notifications. **Migration:** additive column (in R4). **Order:** Batch 0 with BF-1. **Req:** R.

### DC-8 — Self-healing / reconciliation
- **Root cause:** all reviews design-time; runtime operational integrity owned by no domain; outbox retries delivery but nothing heals stuck internal state. **Affected:** scheduled reconciliation RPCs (ADR-0018), `reconciliation_runs` log, `reconciliation_finding` event. **Automation:** pg_cron. **Migration:** additive. **Order:** Batch 1. **Req:** R.

### DC-9 — Timezone anchor
- **Root cause:** SLA/business-hours tables checked for existence, not for the tz reference their math needs. **Affected:** `branches.timezone` (IANA); `process_lead_sla` window computation. **Migration:** additive column. **Order:** Batch 1. **Req:** R.

### DC-10 — Opening balances
- **Root cause:** provisioning (ADR-0016) assumes greenfield; onboarding an operating agency (existing AR/AP/cash/allotments) has no home. **Business:** historical balances stay in Excel; day-one balances understated. **Affected:** `opening_balance_batches` + opening AR/AP entries via posting_rules → Opening-Balance-Equity account; `app.import_opening_balances`; opening_balance_status catalog; opening_balance_posted event; MANAGE_OPENING_BALANCES permission. **Depends on:** dimensions/periods/posting (CDD-5). **Migration:** additive. **Order:** Batch 4. **Req:** R.

### DC-11 — Realized FX gain/loss
- **Root cause:** multi-currency validated at balance level; settlement-posting path untraced. **Affected:** posting_rules template + FX gain/loss GL accounts on cross-currency allocation; reads payment_allocations.exchange_rate. **Depends on:** CDD-5 auto-posting. **Migration:** additive. **Order:** Batch 4. **Req:** R.

### DC-12 — Passenger relationships (mahram)
- **Root cause:** passenger model reviewed for identity/documents, not inter-passenger graph; BF-2 covers group leader, not mahram compliance. **Business:** Saudi Umrah/Hajj mahram declaration; family grouping. **Affected:** `passenger_relationships` (passenger_id, related_passenger_id, relationship_type_code, is_mahram); passenger_relationship_type catalog (mahram/spouse/parent/child/sibling/guardian/group_leader). **Migration:** additive. **Order:** Batch 5 with BF-2. **Req:** R.

### DC-13 — UUIDv7 keys
- **Root cause:** ADR-0002 optimized for uniqueness/guessability, never insert-locality at volume; random v4 fragments B-tree on append-heavy tables. **Affected:** PK default on events, security_events, conversation_messages, attribution_clicks, campaign_daily_metrics, notification_deliveries. **ADR:** amend ADR-0002. **Depends on/pairs with:** B8 partitioning. **Migration:** modifies PK default — cheapest before data. **Order:** Batch 0. **Req:** R (retrofit-risk).

### DC-14 — Tenant offboarding
- **Root cause:** reviews focused on isolation in, not exit out; GDPR portability + SaaS churn unowned. **Affected:** `app.export_tenant` (service_role→Edge over outbox), retention policy, `app.purge_tenant`; MANAGE_TENANT_LIFECYCLE permission; tenant_exported/purged events. **Depends on:** CDD-7 outbox. **Migration:** additive. **Order:** Batch 5. **Req:** R.

### DC-15 — service_role blast radius
- **Root cause:** audit validated `authenticated` isolation; `service_role` treated as trusted-by-design, unbounded and unmonitored. **Affected:** principle — every service_role/SECURITY DEFINER RPC takes explicit tenant_id + asserts it; consider constrained platform DB role; log service_role access to DC-6. **ADR:** append (least-privilege principle). **Migration:** additive (principle + guards). **Order:** Batch 2. **Req:** R.

### DC-16 — pgTAP harness
- **Root cause:** verification is smoke-test + manual psql; no regression net — a precondition for safely executing R1–R8/DC-1/DC-13 built-table retrofits; also nothing asserts RLS coverage (V5 latent trap: RLS depends on tenant_id NOT NULL). **Affected:** test tree + CI step; invariant tests (RLS on every tenant table, money currency-correctness, append-only triggers present). **Migration:** additive. **Order:** Batch 0, first. **Req:** R.
- **Status: ✅ IMPLEMENTED (SPEC-113, 2026-07-11).** `supabase/tests/**` + `supabase test db` in CI. RLS-coverage (negative-checked), append-only, and money-currency invariants live; money-currency runs as a `todo` that surfaces DC-1 (have:22 want:0) without breaking the build. Removing that `todo` wrapper is the acceptance test for the DC-1 fix. Extended by SPEC-114 (tenant_id index coverage) and SPEC-115 (function search_path).

### SEC-1 — Function search_path hardening (discovered 2026-07-11, continuous review)
- **Finding:** `app.forbid_mutation()` was the one of 55 app functions not pinning `search_path` (CODING_STANDARDS violation; mutable-search_path hardening gap in the append-only guard). **Status: ✅ IMPLEMENTED (SPEC-115).** Body unchanged, `set search_path=''` added; pgTAP `05_function_search_path_test` now guards all app functions permanently.

### OPS-2 — Smoke-test non-gating (discovered 2026-07-11, continuous review)
- **Finding:** `scripts/verify_database.sql` raises on the first broken invariant but did not set `ON_ERROR_STOP`, so psql exited 0 on failure — the smoke-test was silently non-gating for every caller (local + never run in CI). **Status: ✅ IMPLEMENTED (SPEC-116).** File now self-arms `\set ON_ERROR_STOP on` (verified: pass→0, fail→3) and CI runs it after every `db reset`.

### DC-17 — Realtime publication scope
- **Root cause:** reviews were data-at-rest; Realtime is a delivery surface for shared inbox/live dashboards. **Affected:** explicit per-table realtime publication list + RLS-authorized channels. **Migration:** additive config. **Order:** Batch 5 (Engagement). **Req:** R.

### DC-18 — pgvector semantic layer
- **Root cause:** AI ambition (RAG/semantic search) needs embeddings; not enabled. **Affected:** enable pgvector; `embeddings(owner_type, owner_id, vector, model)`. **Migration:** additive. **Order:** Batch 5 / backlog. **Opt:** O.

### V-series (verifications, not gaps — recorded for audit trail)
- **V1 RESOLVED:** RLS covers all 5 marketing/offline tables via the dynamic NOT-NULL-tenant_id loop (`202607043300` §1). Earlier "no RLS" worry overturned. ✅
- **V2:** `tenant_isolation` uses bare `app.current_tenant_id()` → A1 confirmed. 
- **V4:** `events`/`security_events` immutability trigger exists (`forbid_mutation`) → partially closes B4. ✅ for those two tables.
- **V5:** RLS coverage silently depends on `tenant_id NOT NULL` → guarded by DC-16 test.
- **V6 (ARB-07-11):** schema has **0 views / 0 materialized views** — the read-model layer (reporting/RI/dashboards) does not yet exist; RC-4 introduces it. Recorded, not a defect.

### S-EVENT — Event vocabulary unenforced (verified 2026-07-15 audit; fix = N1, deferred to implementation phase)
- **Evidence (source-verified twice):** `events.event_type_code` is `text not null` in `202607042600_create_event_and_notification_tables.sql:13` with **no FK and no CHECK**; a repository search for a `create table … event_type(s)` catalog returns **none** — no event-type catalog exists. `app.record_event`'s `p_event_type_code` is passed by call sites as a computed variable, so a mistyped code is silently accepted. Emitted codes already drift from canon-27 (e.g. `internal_supplier_linked` vs canon `internal_supplier_link_created`; `receipt_issued` vs `receipt_created`; `invoice_issued`/`invoice_paid`/`supplier_payment_recorded`/`refund_requested` absent from canon-27).
- **Assessment:** this is the substantive justification for **N1** (event_type registry validated by `record_event`) — it is arresting *live* drift, not speculative. **Classification: the fix is a new schema object + ADR-0006 amendment = architectural capability, OUT of scope for the Repository Recovery phase.** Recorded here so it is not re-discovered; implement under N1 when the implementation phase resumes, together with a one-authority canon-27 ↔ emitters reconcile.
