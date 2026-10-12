# Integration Priority

Version: 0.1
Status: Draft
Canonical: Yes

---

# Proposed Integration Order

> **Synchronization annotation (2026-07-15 Repository Recovery, C7 — no business change):** this document proposes integration *priority/rationale*; the **authoritative execution sequencing is `32_execution_roadmap.md`** (and `reports/master/MASTER_EXECUTION_PLAN.md` for finding-batch order). Where the order below differs from the roadmap, the roadmap governs.

Recommended order after core foundations:

1. GTM
2. GA4
3. Google Ads
4. Meta Conversions API
5. WhatsApp Cloud API
6. n8n
7. Supabase Edge Functions
8. AI Dashboard
9. Payment Gateway
10. GDS APIs

This order is subject to implementation review.

---

# WhatsApp Cloud API

WhatsApp integration must support sending and receiving messages.

MVP implementation may still be phased internally, but the target capability is two-way communication.

---

# Google Ads And Call Tracking

Google Ads integration must support:

- Source attribution
- Call tracking
- Offline conversion feedback
- Lead quality feedback
- Sales outcome feedback
- Read-only reporting and configuration visibility (owner decision D4, 2026-10-11; ADR-0030)

The purpose is to feed offline sales and lead quality data back into Google Ads optimization, and to let ORVION compare what advertising cost with the outcomes ORVION verifies.

ORVION never modifies the Google Ads account: every change is made in the official Google Ads interface. Reporting reads Google's data with GAQL — a read-only Google Ads script held in this repository, with the Google Ads API as the upgrade path (ADR-0030); offline conversions travel through the separate Data Manager API (ADR-0023). The two share no state.

Call tracking must not depend on Google Forwarding Numbers as the primary model.

ORVION should use CRM outcomes and captured click identifiers to send offline conversions through Offline Conversion Engine.

---

# n8n

n8n is intended for system-wide workflows, not only alerts.

Automation design must still distinguish between:

- Core workflows that must live inside ORVION
- External automations that may run through n8n

Critical business state changes should not depend only on external n8n workflows.

---

# Integration Risk Notes

Google Ads call tracking and offline conversion import require strict identity, consent, attribution, and event-quality rules.

WhatsApp automation requires template/message policy compliance.

Payment gateway is intentionally later than bank-transfer renewal because the first SaaS billing model depends on manual transfer proof.

GDS APIs are intentionally late because they add commercial, certification, and operational complexity.
