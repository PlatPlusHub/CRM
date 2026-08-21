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

Status: In Progress — CURRENT phase (started 2026-07-17 after Phase 9 Tier A completed). ORVION-side pipeline COMPLETE (capture→map→claim→ack, migrations 049200/049300/049400) and Integration Catalog seeded. CRM database deployment is complete and verified live on **Primary `vrvtsxexkiiiivlkdxzp`**, this repository's sole Supabase deployment target (`MASTER_INTEGRATION_CATALOG.md §0`): Primary carries 90 migrations, latest `202607050100_conversion_delivery_lease` (includes SPEC-120/121/122/123). Secondary `brplkqmbzffpxqgkkdzo` is the separate `Shehabhub/ORVION` environment (89 migrations) and is **never a CRM deployment target**; SPEC-123 is intentionally present on Primary and intentionally absent from Secondary. **Migration parity/synchronization between the two was permanently revoked (owner-ratified 2026-08-20)** — differences are valid and expected, never a defect to reconcile. Remaining: **the Foundation Completion Programme first — the workflow build is GATED behind it (owner-directed 2026-08-21)**; see `manifest.md` for the ordered remaining work (AUDIT-3 read-scope model, ~13 write permissions, CAT-5/CAT-6, table-by-table and configuration audits). The workflow's own prerequisites are ready and unchanged when that gate is earned: the previously recorded Google OAuth / `orvion_integration` credential prerequisite is **no longer an outstanding blocker**. Both n8n credentials are agent-verified **present** (`ORVION Google Data Manager` and `Postgres account`, 2026-08-20), and `orvion_integration` login is independently verified (`pg_roles.rolcanlogin = true`). Zero workflows currently exist on the instance; **workflow build is the remaining work**. *(Presence only — neither credential's target or scope is independently verified, and neither has been observed to authenticate.)*

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

Status: Complete (Tier A, 2026-07-17 — migration 048900: `reporting` schema + 7 security_invoker views serving all six outputs per ADR-0022). Tier B aggregates remain evidence-gated (a report must prove measured cost) and do not hold the phase open.

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

Status: Pending

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
