# ORVION MASTER DOMAIN CATALOG

Status: **Permanent engineering reference.** Never recreate; evolve. One entry per domain: purpose, responsibilities, and the physical objects (built + designed). Full column-level physical specs live in `complete-platform-physical-design-2026-07.md` (referenced by § number as **PD§n**) — this catalog is the navigable index over it plus completion state. Cross-reference: `MASTER_GAP_REGISTER.md`, `MASTER_ENTITY_RELATIONSHIP_MAP.md`.

Last updated: 2026-07-11. **Design Completion %** = how completely the domain is *designed* (owner's standard: a new team needs no rediscovery), not how much is implemented. `[B]` built (Phases 2–7), `[D]` designed-in-register, `[H]` hooks-pending.

**Grounding — a DATED DESIGN SNAPSHOT, not live state (GOV-5, 2026-08-30).** As measured **2026-07-15**: 71 tables · 55 app RPCs · 65 catalog types · 64 permissions · 9 roles · 137 indexes · 12 CHECKs · 0 views. Every one of those has since moved (views alone went 0 → 8), and this file was still presenting them as current. They are kept, dated, because the domain map below was *drawn against them* — deleting them would strand the analysis from its basis. **For live counts read `_ORVION_CANONICAL/manifest.md`; for the client-facing surface read `MASTER_API_CONTRACT.md`, which is generated from the database.** This document owns the *domain index and completion assessment*, never the counts.

---

## 1. Party / Customer-Identity / Suppliers — PD§1 — Completion 90%
- **Purpose:** the single counterparty model (customer ⇄ supplier ⇄ sub-agent ⇄ corporate ⇄ partner ⇄ employee).
- **Tables:** `[B]` customers, suppliers, customer_contact_methods, customer_notes, customer_identity_signals, customer_identity_merges · `[D]` parties, party_roles, party_relationships, party_contact_identities.
- **Events:** customer_created/merged (built), party_created/updated/merged, role_granted/revoked, consent_changed (designed).
- **RPCs:** `[B]` create_customer, find_customer_duplicates, merge_customer_identity · `[D]` upsert_party, grant_party_role, merge_party, set_credit_terms.
- **Permissions:** MANAGE_CUSTOMER (built), MERGE_CUSTOMER_IDENTITY (built), MANAGE_PARTY/VIEW_PARTY/MERGE_PARTY/MANAGE_CREDIT_TERMS (designed).
- **Catalogs:** customer_type (built), party_kind/party_role/party_relationship_type/contact_channel (designed).
- **Integrations/AI:** inbound comms resolve to party via contact_identities; AI dedup via pg_trgm (B7).
- **Open items:** R6 (party_id), BF-3 (credit terms), N5 (consent), DC-4 (erasure), DC-14 (offboarding), DC-6 (read-audit).
- **Gap to 100%:** party generalization + consent/erasure/credit-terms not yet in canon.

## 2. Leads / Sales / CRM — PD§2 — Completion 95% `[B]`
- **Tables:** leads, lead_assignments, lead_interactions, tasks, complaints, service_requests, quotations, quotation_items, conversations, conversation_messages.
- **RPCs:** create_lead, assign_lead, assign_lead_round_robin, record_lead_interaction, process_lead_sla, advance_lead, convert_lead, lead_booking_readiness.
- **Events:** lead_created/assigned/reassigned/sla_warning/converted.
- **Permissions:** CREATE_LEAD, UPDATE_LEAD_STATUS, ASSIGN_LEAD, VIEW_LEAD, etc.
- **Open items:** R5 (attribution_click_id link), DC-9 (SLA timezone).

## 3. Reservations / Booking + Service Verticals — PD§3 — Completion 85% `[B core]`
- **Tables:** `[B]` bookings, booking_items, passengers, booking_item_passengers, internal_supplier_links · `[D]` booking_item_references, per-vertical extension tables (flight_segments/hotel_stays/visa_applications/insurance_policies/transport_segments), passenger_relationships.
- **RPCs:** create_booking, create_booking_item, create_passenger, link_passenger_to_booking_item, link_internal_supplier, advance_booking, advance_booking_item + finance-gate slices.
- **Events:** booking/item lifecycle (confirmed/issued/cancelled/refunded/reissued).
- **Open items:** R4 (product/ref links + DC-7 ticketing_deadline), BF-1 (PNR/ticket refs), BF-2 (groups), DC-12 (mahram), DC-3 (allotment concurrency).
- **Gap:** per-vertical detail tables + product linkage + references.

## 4. Product Catalog / Inventory / Allotments / Supplier Contracts — PD§4 — Completion 80% `[D]`
- **Tables:** products, product_categories, product_components, product_variants, product_constraints, package_departures, supplier_contracts, supplier_rates, inventory_allotments, allotment_movements.
- **CK:** departure.sold ≤ capacity; allotment held+released ≤ quantity (+ DC-3 concurrency).
- **RPCs:** create_product, compose_package, open_departure, hold_allotment, release_allotment, get_availability.
- **Integrations:** GDS/NDC/hotel availability sync.
- **Open items:** whole domain unbuilt; DC-3 locking; design complete.

## 5. Pricing / Discounts / Promotions — PD§5 — Completion 85% `[D]`
- **Tables:** price_components, pricing_rules, promotions, promotion_redemptions.
- **Rule (Synth §2.5):** header total = enforced roll-up of lines; price_components decompose a line, never the header.

## 6. Tax / VAT — PD§6 — Completion 85% `[D]`
- **Tables:** tax_authorities, tax_codes, tax_rates. **Scheme:** standard/margin(TOMS)/zero/exempt. **RPC:** compute_tax(line/margin).
- **Open:** BF-4 promote to near-term iff launch tenant VAT-registered.

## 7. Finance / Accounting / Treasury — PD§7 — Completion 80% `[B core]`
- **Tables:** `[B]` chart_of_accounts, journal_entries, journal_entry_lines, invoices, payments, payment_allocations, receipts, refunds, exchange_rates, exchange_rate_adjustments, financial_accounts, company_assets · `[D]` invoice_lines, accounting_dimensions, fiscal_calendars, accounting_periods, posting_rules, supplier_bills(+lines), bill_allocations, credit_notes, debit_notes, bank_statements(+lines), bank_reconciliations, account_transfers, cash_sessions, currency_revaluations, document_sequences, opening_balance_batches.
- **RPCs:** `[B]` create_journal_entry, seed_default_chart_of_accounts, create_invoice, issue_invoice, record_payment, issue_receipt, record_supplier_payment, record_refund, advance_refund, customer_balance, supplier_balance, booking_item_profit · `[D]` post_transaction, close_period, approve_bill, reconcile, revalue_currency, next_document_number, import_opening_balances.
- **Invariants:** INV-1..4 (ADR-0021 amend). **Open:** R2/R3/R7(money), DC-1, DC-10, DC-11, BF-6, BF-7, BF-8, BF-10, CDD-6.
- **Gap:** subledger auto-posting, dimensions, periods, AP, treasury, tax, opening balances, money-scale.

## 8. Documents — PD§8 — Completion 90% `[B]`
- **Tables:** documents, document_versions, document_links. **RPCs:** upload_document, add_document_version, archive_document, expiring_documents, financial_documents.
- **Open:** DC-5 (binary storage + Storage RLS), document_templates, document_sequences, signature_status slot.

## 9. Assets — PD§9 — Completion 70% `[B minimal]`
- **Tables:** `[B]` company_assets · `[D]` asset_categories, asset_assignments, asset_depreciations. **Open:** FOE-4 (depreciation posts via §7).

## 10. HR — PD§10 — Completion 80% `[D]`
- **Tables:** employees, employment_contracts, leave_types, leave_requests, attendance. Links party+users. **Open:** BF-5.

## 11. Payroll — PD§11 — Completion 80% `[D]`
- **Tables:** payroll_runs, payroll_items, commission_settlements (reads booking_items.commission_rate + sales_owner). Posts via §7. **Open:** BF-5.

## 12. Procurement — PD§12 — Completion 80% `[D]`
- **Tables:** purchase_requisitions, purchase_orders, purchase_order_lines → supplier_bills. **Open:** future phase.

## 13. Fleet / Vehicles & Guides / Resources — PD§13 — Completion 80% `[D]`
- **Tables:** resources, resource_availability, resource_assignments. **Open:** BF-12.

## 14. Branches / Org / Franchise / Multi-company — PD§14 — Completion 88% `[B core]`
- **Tables:** `[B]` tenants, branches, departments, branch_business_hours, holidays, user_branch_assignments · `[D]` tenant_groups, tenant_relationships. **Open:** CDD-9 (consolidation read path C1), DC-9 (timezone).

## 15. Subscription / Billing / Entitlements / Feature Flags — PD§15 — Completion 82% `[B tables]`
- **Tables:** `[B]` subscription_plans, subscriptions, feature_entitlements, usage_counters, subscription_payment_proofs · `[D]` feature_flags, platform_invoices. **RPCs:** `[D]` has_feature, meter_usage. **Open:** RC-1 lifecycle, N2 composition.

## 16. Workflow / Approvals — PD§16 — Completion 85% `[B generic]`
- **Tables:** `[B]` approval_requests (generic) · `[D]` workflow_definitions, workflow_instances (overlay FOE-6). **RPCs:** request_finance_approval, review_finance_approval (built).

## 17. Customer Communications / Notifications / Templates / Consent — PD§17 — Completion 80% `[B core]`
- **Tables:** `[B]` conversations, conversation_messages, notifications, notification_deliveries · `[D]` message_templates, notification_rules, notification_preferences, consent_records + channel/status fields. **Open:** CDD-10, RC-2, N5, DC-17 (realtime).

## 18. Integration Layer + Event/Outbox — PD§18 — Completion 82% `[D]`
- **Tables:** `[B]` offline_conversion_deliveries (bespoke) · `[D]` integration_providers, integration_connections, event_outbox (selective, C2), webhook_inbox, integration_sync_state. **Connectors:** Google Ads Data Manager, Meta CAPI, WhatsApp Cloud API, GA4/GTM, GDS/NDC, BSP, n8n, Framer(inbound). **Open:** CDD-7, DC-2 (idempotency edge), Phase 8/10.

## 19. Event Contract / Audit / Security — PD§19 — Completion 88% `[B]`
- **Tables:** events, security_events (append-only + forbid_mutation trigger — V4 verified). **Open:** R1 (versioned/correlated cols), N1 (event_type registry), DC-6 (sensitive-read log).

## 20. Revenue Intelligence / Reporting / Dashboards / Analytics — PD§20 — Completion 70% `[D consumer]`
- **Design:** read models/matviews over events + dimensions; report_definitions/dashboard_definitions optional; RI delivery via outbox. **Note:** **0 views/matviews exist today (V6)** — RC-4 introduces the first read-model layer. **Open:** RC-4, BF-11 (statements), depends on N1+dimensions.

## 21. AI / MCP — PD§21 — Completion 75% `[D consumer]`
- **Design:** MCP server exposes read + guarded action RPCs; observes via events/outbox; ai_agent_runs, ai_recommendations audit tables; DC-18 pgvector for semantic. **Open:** N1 (reliable event contract), DC-18.

## 22. Localization / i18n — PD§22 — Completion 80% `[D]`
- **Tables:** locales, translations. Drives catalog labels, product content, templates, document layouts. **Open:** CDD-11.

## Cross-cutting (designed once) — Completion 78%
document_sequences (CDD-6) · accounting dimensions (CDD-5) · transactional outbox + webhook inbox (CDD-7) · event contract + registry (N1) · party+contact+consent (CDD-1/N5) · i18n (CDD-11) · feature entitlements+flags · RLS single primitive + group scope (C1) · **idempotency (DC-2)** · **concurrency discipline (DC-3)** · **money-storage standard (DC-1)** · **UUIDv7 (DC-13)** · **test-assurance (DC-16)**.

## Excluded (proven, PD E1/E2) — not part of a Travel ERP
Physical Warehouse / MRP · Retail POS. Operational-not-schema: Monitoring/Logging/Backup-DR (ops runbook).

---
**Weighted platform design completion: see `MASTER_COVERAGE_SCORE.md`** — the single source of truth for this metric (≈82% as last scored 2026-07-11; that figure predates the 2026-07-15 implementations and understates current completeness). The remaining balance is concentrated in Finance-depth, Product/Inventory, Reporting read-models, and the cross-cutting substrate — all designed in the register, awaiting canon integration + phased build.
