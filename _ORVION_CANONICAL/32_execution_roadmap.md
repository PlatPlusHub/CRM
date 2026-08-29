# ORVION Execution Roadmap

Version: 0.2
Status: Draft
Canonical: Yes

---

# Purpose

This roadmap defines how ORVION should move from canonical documentation to implementation.

The project owner reviews decisions.

Codex drives structure, sequencing, and implementation work.

---

# Working Principle

The project should move in small controlled packages.

Each package must produce a concrete output.

No package should attempt to solve the entire product.

---

# Phase 0: Canonical Foundation

Status: Complete

Outputs:

- Product charter
- MVP scope
- Company structure
- Lead lifecycle
- Customer identity
- Booking model
- Finance model
- Document model
- SaaS plan model
- Notification model
- Authentication model
- Offline conversion engine
- Codex constitution
- Manifest
- Daily working prompt

---

# Phase 1: Database-Ready Specification

Status: Complete

Objective:

Prepare the database specification without writing SQL.

Outputs:

- Entity registry
- Catalog registry
- State machines
- Event catalog
- Permissions matrix
- Relationship map
- Database conventions
- Schema draft

Owner review required:

- Entity registry
- Catalog registry
- State machines
- Schema draft

---

# Phase 2: Database Foundation

Status: Complete

Objective:

Create the first Supabase/PostgreSQL database foundation.

Outputs:

- SQL migrations
- Core tables
- Catalog seed data
- RLS baseline
- Audit/event tables
- Basic indexes
- Database verification checklist

Delivered: migrations 1-20 (SPEC-022 through SPEC-053); 71 tables, 65 catalog types / 395 catalog values, 76 RLS policies, append-only audit, and an executable verification smoke-test (`scripts/verify_database.sql`).

---

# Backend Architecture (applies to Phases 3-10)

Supabase-native-first, per ADR-0014: PostgREST + RLS + PostgreSQL functions (RPC) as the backbone; Edge Functions + pg_cron/pg_net + n8n for out-of-database compute; a server-rendered web app (`@supabase/ssr`) and future mobile/API clients on the same Supabase surface; no standalone backend service unless a concrete capability provably requires one. Phases 3-10 are executed capability-by-capability under the CR lifecycle ("small controlled packages"); no separate per-phase implementation-plan document is authored unless a phase's complexity earns it.

---

# Phase 3: Identity And Access

Status: Complete

Objective:

Implement tenant, user, role, permission, branch, department, and authentication foundation.

Outputs:

- Tenant management
- User accounts
- Branch/department assignment
- Role/permission assignment
- TOTP requirements for high-risk roles
- Device trust baseline

---

# Phase 4: CRM Core

Status: Complete

Regression note (2026-08-10): `app.merge_customer_identity` emitted an unregistered `event_type` code from migration `202607049100` onward, so every call silently aborted. Found by a full-repository audit treating `supabase/migrations/**` as ground truth, not the manifest; fixed by SPEC-120 with a permanent pgTAP guard added by SPEC-121 (`changes/SPEC-120-*.md`, `changes/SPEC-121-*.md`). Phase deliverables and scope unchanged — this is a closed regression record, not an open item.

Objective:

Implement lead and customer flow.

Outputs:

- Lead intake
- Round-robin assignment
- Lead SLA escalation
- Customer identity matching
- Lead closure
- Lead-to-customer link
- Lead-to-booking preparation

---

# Phase 5: Booking Core

Status: Complete

Objective:

Implement booking and booking item workflows.

Outputs:

- Booking creation
- Booking item creation
- Passenger linkage
- Supplier linkage
- Item lifecycle
- Finance approval gate
- Risk flag for negative balance issuance

---

# Phase 6: Finance Core

Status: Complete

Delivered: `app.customer_balance` + `app.supplier_balance` + `app.booking_item_profit` (derived read primitives); invoice create/issue, `record_payment` (allocation + status), `issue_receipt`, `record_supplier_payment`, customer refund workflow (`record_refund`/`advance_refund`), and basic journal entries + default chart of accounts (SPEC-089, SPEC-100–108). The finance-approval execution gate landed in Phase 5 (ADR-0020).

Regression note (2026-08-10): `app.advance_refund` emitted an unregistered `event_type` code from migration `202607049100` onward, so every refund-advance call silently aborted. Found by the same full-repository audit as the Phase-4 note above; fixed by SPEC-120 with a permanent pgTAP guard added by SPEC-121 (`changes/SPEC-120-*.md`, `changes/SPEC-121-*.md`). Phase deliverables and scope unchanged — this is a closed regression record, not an open item.

Objective:

Implement practical finance workflows.

Outputs:

- Customer receivables
- Supplier payables
- Payments
- Receipts
- Invoices
- Refunds
- Basic journal entries
- Profit per booking item
- Outstanding balance

---

# Phase 7: Documents

Status: Complete

Delivered: `app.upload_document` (document + first version + polymorphic link, with document-type/file-type/target catalogs + placement rules), `app.add_document_version` + `app.archive_document` (versioning + lifecycle), `app.expiring_documents` (expiry surfacing), and `app.financial_documents` (`VIEW_FINANCIAL_DOCUMENTS`-guarded stricter visibility) — SPEC-109…112. Engineering Observation recorded (SPEC-110): canon-26 "new version → superseded" diverges from the frozen `current_version_id` intra-document versioning design; document-level supersede reserved for a future explicit op.

Objective:

Implement document upload, linkage, lifecycle, permissions, archive, and versioning.

Outputs:

- Document types
- Passenger documents
- Booking item documents
- Financial documents
- Expiry dates
- Archive
- Versioning

---

> **Execution-order decision (owner, 2026-07-16):** phases run **7 → 9 → 8 → 10**, not in numeric order. **Phase 9 (Reports & Dashboards / RC-4) is executed BEFORE Phase 8 (Offline Conversion)** — reporting unblocks the most operational roles and is the read-model substrate for later AI/RI + offline-conversion consumers (evidence: `reports/history/repository-recovery-completion-2026-07-15.md` §5; checkpoint proposal P3). Phase numbers are stable identifiers, not execution order.

# Phase 8: Offline Conversion

Status: **In Progress — CURRENT phase** (started 2026-07-17 after Phase 9 Tier A completed). Re-verified against live systems 2026-08-30 during the pre-Phase-10 reconciliation; **it is NOT complete, and the single reason is precise.**

**Done:** the ORVION-side pipeline (capture→map→claim→ack, migrations 049200/049300/049400), the SPEC-123 delivery lease, the in-DB consent gate, and the Integration Catalog workflow contract. All deployed to **Primary `vrvtsxexkiiiivlkdxzp`**, this repository's sole Supabase deployment target (`MASTER_INTEGRATION_CATALOG.md §0`); Secondary `brplkqmbzffpxqgkkdzo` is the separate `Shehabhub/ORVION` environment and is **never a CRM deployment target**. Migration parity between the two was **permanently revoked** (owner-ratified 2026-08-20) — differences are valid, never a defect to reconcile. *(Live migration/fingerprint state is not restated here — `manifest.md` owns it, proven by `scripts/check_database_parity.ps1`. This paragraph carried "Primary carries 90 migrations" until 2026-08-30, seventy migrations stale: **GOV-5**.)*

**Not done — the whole of what remains:** the **n8n workflow itself**. Verified live 2026-08-30: the n8n instance holds **zero workflows**. Nothing delivers a conversion to Google Ads, so the founding feedback loop this phase exists to close is open.

**Why it has not been built — a gate, not a blocker:** the workflow build is **GATED behind the Foundation Completion Programme** (owner-directed 2026-08-21; the programme is `MASTER_EXECUTION_PLAN.md` Batch 6). That gate is still shut — Batch 6 has open engineering items (the table-by-table audit, `notification_deliveries` having no producer, the Employee/Supplier/Branch 360 primitives, DOC-LC-1, API-3's remaining endpoints, SPEC-154-B) and open owner decisions (**SEC-1**'s write-path model above all). *(The gate list previously named here — "AUDIT-3 read-scope model, ~13 write permissions, CAT-5/CAT-6" — was itself stale: AUDIT-3 was resolved 2026-08-24 by SPEC-137. Read Batch 6 for the live list rather than any summary of it.)*

**The workflow's own prerequisites are ready** and unchanged when the gate is earned: both n8n credentials are agent-verified **present** (`ORVION Google Data Manager`, `Postgres account`, 2026-08-20) and `orvion_integration` login is independently verified (`pg_roles.rolcanlogin = true`). *(Presence only — neither credential's target or scope is independently verified, and neither has been observed to authenticate. That is an UNPROVEN, not a PROVEN.)*

Objective:

Implement advertising outcome feedback.

Outputs:

- Click data capture
- Lead attribution
- CRM outcome mapping
- Internal conversion event
- Google Ads offline conversion delivery
- Delivery status and retry

---

# Phase 9: Reports And Dashboards

Status: **Complete (Tier A)** — 2026-07-17, migration 048900: `reporting` schema + `security_invoker` views per ADR-0022. Tier B aggregates remain evidence-gated (a report must prove measured cost) and do not hold the phase open.

**Acceptance re-proven live 2026-08-30** (the reconciliation did not take this status on trust): the `reporting` schema holds **8** views, each exposed over HTTP and pinned by name in `53_api_surface_test.sql`, and all six of the phase's required outputs map to one — lead performance → `lead_performance`; sales activity → `sales_activity`; booking pipeline → `booking_pipeline`; finance outstanding balances → `customer_outstanding` + `supplier_outstanding`; profit by booking item → `booking_item_profit`; subscription state → `subscription_state`. The eighth, `my_sales_performance`, was added later by SPEC-159 and is a Phase-9-shaped addition rather than an outstanding deliverable. **No output is missing, so nothing about Phase 9 gates Phase 10.**

Objective:

Implement useful operational visibility.

Outputs:

- Lead performance
- Sales activity
- Booking pipeline
- Finance outstanding balances
- Profit by booking item
- Subscription state

---

# Phase 10: Automation And Integrations

Status: **Pending — NOT READY TO BEGIN. Determination made 2026-08-30 against live systems, per the owner's pre-Phase-10 reconciliation directive.**

**Verdict: NOT READY.** Two prerequisites are unmet, and neither is a matter of opinion:

1. **Phase 8 is not complete.** Its sole remaining deliverable is the n8n workflow, and the n8n instance holds **zero workflows** (verified live 2026-08-30). Phase 8 precedes Phase 10 in the owner's own 7→9→8→10 sequencing.
2. **The Foundation Completion Programme gate is still shut.** The owner gated the Phase-8 workflow build behind it on 2026-08-21, and `MASTER_EXECUTION_PLAN.md` Batch 6 still carries open engineering items and open owner decisions — **SEC-1**'s write-path architecture chief among them.

**These are the same blocker seen twice, not two.** Phase 10's own first output is *"n8n workflows"*, and Phase 8's remaining deliverable **is** an n8n workflow — so the work that finishes Phase 8 is literally the opening move of Phase 10, under a gate the owner placed. Starting Phase 10 now would mean building Phase 8's deliverable while calling it Phase 10, which changes the label and not the dependency.

**What is NOT blocking, and was checked rather than assumed:**
- **Phase 9** — complete, all six outputs re-proven live (above).
- **The database foundation** — repository, local and Primary agree on 160 migrations, the ledger fingerprint **and** the full 230-function surface, both sides read live (`check_database_parity.ps1` L1/P1/L2/P2).
- **API reachability** — 71 RPC endpoints + 8 reporting views are live and generated into `MASTER_API_CONTRACT.md`; **API-3** tracks the 30 still lacking HTTP evidence, which is a coverage debt, not a reachability blocker.
- **The architecture does not make Phase 10 impossible** (directive §14). The WhatsApp/AI data model is present — nullable customer/owner/sender, external ids, whatsapp catalog values, `orvion_integration` attribution capture. **CONV-3** records the one genuine gap: there is no session-less inbound *door*, which is integration-phase work with an in-house precedent, not a redesign.

**Do not mark this phase started until:** the Foundation Completion Programme gate is released by the owner, and Phase 8's workflow is built and verified against `MASTER_INTEGRATION_CATALOG.md §2` with its `§2a` corrections.

Objective:

Implement controlled external automation.

Outputs:

- WhatsApp Cloud API
- n8n workflows
- GTM/GA4/Google Ads integrations
- Meta Conversions API
- Supabase Edge Functions

---

# Remaining Work — Living Forward Plan (2026-07-18; evolve in place)

The primary execution reference for future sessions. Phase numbers are stable identifiers; execution order is 7→9→8→10. Update whenever repository evidence justifies it — this section is Living, never frozen.

## Phase 8 — Offline Conversion (CURRENT; ORVION-side pipeline landed 2026-07-17)

- **Objective:** close the founding feedback loop — verified CRM outcomes delivered to Google Ads.
- **Deliverables:** conversion-mapping RPC (verified outcome → `offline_conversions`, value = revenue) ✓; n8n-facing outbox pair `claim_conversion_deliveries` / `record_conversion_delivery_result` + dedicated integration role ✓; in-DB consent gate ✓; Integration Catalog workflow contract ✓; the n8n workflow activation remains (Data Manager API + Enhanced Conversions for Leads, OAuth `datamanager` scope, SHA-256 hashing at the edge).
- **Dependencies (all met):** attribution capture (SPEC-119) ✓ · money precision (SPEC-118) ✓ · read-model outcome surface (ADR-0022) ✓ · event cursor (`seq`, mig 049000) ✓ · event-type registry (mig 049100) ✓.
- **Decided ADRs:** ADR-0023 (transport + n8n outbox). **Expected new:** none — remaining choices are implementation-level.
- **Integration points:** Google Data Manager API (first row of the Integration Catalog, which seeds when this phase lands); GTM/GA4 coexist via Google's unified enhanced-conversions setting.
- **Risks:** Data Manager API is <1 yr old (mitigated: transport behind the claim/ack boundary); consent-data handling (mitigated: in-DB gate + hashing at edge); owner must provision Google OAuth credentials.

## Phase 10 — Automation & Integrations

- **Objective:** n8n as the standing orchestration fabric; WhatsApp Cloud API conversations (company-owned, on the existing `conversations` structures); Meta CAPI reusing the Phase-8 outbox (`platform_code`); GTM/GA4 wiring; Edge Functions where n8n does not fit.
- **Expected ADRs:** communications-domain shape (after full Meta-ecosystem Learn-Before-Designing — deliberately undecided until then); generic automation event-feed RPC (trigger: second n8n event consumer; additive thanks to `events.seq`).
- **Expected canon:** communications-domain doc(s) when that Design Challenge runs; Integration Catalog growth.
- **Risks:** Meta platform review/verification lead times; channel-ownership migration of live customer conversations.

## Post-phase capability queue (each enters as its trigger fires; all structures already exist)

| Capability | Trigger | Expected decisions |
|---|---|---|
| Quotations workflow (schema inert today) | Sales quotation-issuance scheduled | quotation→booking integration design |
| Subscription/billing lifecycle (schema complete) | Business go-live decision (C4/C5 open: activation-code, grace) | subscription-strategy ADR (owner: pricing/grace = business policy) |
| Department dashboards / first UI | First frontend implementation | dashboard contracts over the `reporting` schema; UI stack ADR; DML GRANTs + `anon` scope |
| Customer/Supplier/Employee portals | After first internal UI | portal identity surface (RLS model already supports) |
| AI-agent capabilities | First AI capability scheduled | runtime agent role/permission ADR; RPC + events are the interface |
| Phase-9 Tier B aggregates | A Tier-A report measurably slow | per-report `pg_cron` refresh (ADR-0022 pre-designed) |
| Travel reference tables (airports/airlines/cities) | Flight-ticketing design | reference-shape decided by that feature |
| HR domain (owner boundary revision 2026-07-17 — `PROJECT_CONTEXT §12`) | Owner schedules the HR capability | HR Design Challenge + Learn-Before-Designing first; employee-vs-membership identity split is the expected core decision; org skeleton already built |
| Presentation-currency FX | Owner elects single-currency reporting | additive `convert_amount` over `exchange_rates` (ADR-0022 pre-designed) |
| Live-DB V-series re-verification; A3 money-storage ADR | Next comprehensive DB audit | — |

# Immediate Next Action

Phases 2–7 and 9 (Tier A) are complete. Per the 2026-07-16 owner sequencing (decision banner above §Phase 8), execution order is **7 → 9 → 8 → 10**, so **Phase 8 (Offline Conversion) is the current phase** until its n8n workflow is activated. The outbound transport decision is closed by ADR-0023. For the live next engineering action (current module, active Change Request, and immediate next step), the single source of truth is `manifest.md` — this roadmap owns phase *sequencing*, not live state, and does not restate it.
