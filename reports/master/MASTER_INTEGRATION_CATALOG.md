# MASTER_INTEGRATION_CATALOG — External Integration Contracts

Class: **LIVING-AUTHORITATIVE** (evolve in place; one SSOT row per integration — `GOVERNANCE.md §2/§4`).
Purpose: the single registry of every external-platform integration — direction, transport, ORVION surface, status, and owning decision record. Seeded 2026-07-17 at its recorded trigger (Phase 8 landed; `future-backlog.md` Adopt-Later). Platforms are **consumers** of ORVION's verified outcomes, never dependencies (`PROJECT_CONTEXT.md §11`).

## 0. Supabase project topology (deployment targets — verify before every schema/data change)

Recorded here, not a new document: this is ORVION's own deployment-target registry, the closest existing fit to "external targets ORVION connects to" (`GOVERNANCE.md §6.8` — evolve an existing authoritative home rather than create a new one). Owner-provided ground truth, 2026-08-10.

| Project | Ref | Account | Organization | Role | Status |
|---|---|---|---|---|---|
| **ORVION** (primary) | `vrvtsxexkiiiivlkdxzp` | platplustours@gmail.com | Platinum Plus Tours (`zvlxdabpjuunyfigkhci`) | **Primary** | ACTIVE_HEALTHY. **Not reachable from this repository's current Supabase MCP connection** — confirmed 2026-08-10: absent from `list_projects`; a direct `get_project` call returns a permission error. That connection is scoped to the `shehab.nim@gmail.com` account only. **SPEC-120 deployment status on this project is unverified.** |
| **orvion-core** (secondary / mirror) | `brplkqmbzffpxqgkkdzo` | shehab.nim@gmail.com | Orvion (`emjkklugmzgyuzuabell`) | **Secondary — mirrors primary** | ACTIVE_HEALTHY. SPEC-120 deployed and migration-version-reconciled 2026-08-10 (git history, `changes/SPEC-120-*.md`). Reachable from this repository's current Supabase MCP connection. |
| orvion-core *(deleted)* | `hzyuczdlwalectfduehw` | platplustours@gmail.com | Platinum Plus Tours | — | **DELETED — intentionally. Never use, restore, link, or reference.** |
| ORVION *(created by mistake)* | `wgsmrjcuhjdksfpdbhre` | shehab.nim@gmail.com | Orvion (`emjkklugmzgyuzuabell`) | — | Created 2026-08-09; zero migrations; not an ORVION target. Owner intends manual deletion — never delete automatically. |

**Synchronization rule (owner-ratified 2026-08-10):** the primary and secondary/mirror must remain synchronized — every schema/migration/RPC/policy/function/trigger/catalog change applies to both wherever technically applicable, GitHub/local migrations as the source of truth, applied there first. Neither project receives an undocumented direct change. **Verify the exact project ref before every schema-changing or destructive operation against either** — never assume which project is the target.

## 1. Registry

| Integration | Direction | Transport | ORVION surface | Status | Decision |
|---|---|---|---|---|---|
| **Google Ads offline conversions** | Outbound | Google **Data Manager API** + Enhanced Conversions for Leads, orchestrated by **n8n** over the database outbox | `app.capture_attribution_click` → `app.map_outcomes_to_conversions` → `app.claim_conversion_deliveries` → `app.record_conversion_delivery_result` (migrations 049200/049300/049400); role `orvion_integration` | **ORVION-side COMPLETE**; n8n workflow pending owner-exclusive credentials (§3) | ADR-0023; analysis: `google-offline-conversion-transport-decision-2026-07-17.md` |
| Landing-page / GTM click webhook | Inbound | GTM/site webhook → n8n → `app.capture_attribution_click` | same capture RPC (explicit-tenant, integration-role-only) | ORVION-side complete; site/GTM wiring at first live campaign | ADR-0023 (capture side); SPEC-119 |
| Meta Conversions API | Outbound | Meta CAPI via n8n, **reusing the same outbox** (`platform_code = 'meta_ads'`) | identical claim/ack pair — no new ORVION surface expected | Planned (Phase 10) | ADR-0023 §channel-generic |
| WhatsApp Cloud API (company-owned conversations) | Bidirectional | Meta WhatsApp Cloud API via n8n | `conversations`/`conversation_messages` (built; `external_conversation_id` ready); ingestion/send RPCs to be designed | Planned (Phase 10; shape needs Meta-ecosystem Learn-Before-Designing) | future-backlog §Group-3 determinations |
| GA4 / GTM tagging | Client-side | Google tag; coexists with server-side truth via Google's unified enhanced-conversions setting | none (browser-side); ORVION remains authoritative | At first UI / live campaign | ADR-0023 §ecosystem |

Rules: one row per integration; a new integration enters only with its decision record; retire rows via strikethrough + pointer (ADR-supersede convention). n8n is the orchestration layer for all outbound/inbound flows (owner decision 2026-07-17); any orchestrator swap changes *credentials and workflows*, never the ORVION RPC surface.

## 2. Google delivery — n8n workflow contract (build-ready spec)

One workflow, schedule-triggered (e.g. every 15 min). All DB calls use the `orvion_integration` Postgres credential; the whole pipeline is idempotent, so a crashed run is safely re-run.

1. **Map** — `select app.map_outcomes_to_conversions(500);` (advances the event cursor; returns rows mapped).
2. **Claim** — `select * from app.claim_conversion_deliveries('google_ads', 50);` → if 0 rows, stop. Only consent-granted conversions are ever returned (in-DB gate); each row carries `delivery_id`, conversion facts, click IDs (`gclid`/`gbraid`/`wbraid`), consent signals, and raw `customer_phone`/`customer_email`.
3. **Hash at the edge** (Function node) — normalize then SHA-256 (lowercase hex): email → trim + lowercase; phone → E.164 (`+…`) before hashing. **Raw PII never leaves n8n**; ORVION stores truth, Google receives hashes + click IDs only.
4. **Send** (HTTP node, OAuth2 credential with the `datamanager` scope) — Data Manager API conversion-event ingestion: click ID(s) + hashed `userIdentifiers` + `conversion_event_type_code`-mapped action + value/currency (revenue — never profit, ADR-0023) + `conversion_at` + consent (`adUserData`/`adPersonalization` from the claimed row). *Fast-moving surface:* verify the exact endpoint/payload field names against current Google Data Manager docs at build time (Learn-Before-Designing; the API is <1 yr old).
5. **Ack per row** — `select app.record_conversion_delivery_result(:delivery_id, :success, :response_json, :error_text);` → `sent`/`failed` + canonical events. Failed rows become re-claimable automatically on later runs (retry ceiling 5, then parked for review via `reporting`/events).

Monitoring: `offline_conversion_deliveries` rows + `offline_conversion_sent/failed` events are the health signal; a staleness/failure report is a Tier-A view away if operations wants one (Earn-It: build on demand).

## 3. Owner-exclusive setup (the only remaining Phase-8 inputs)

1. Google Cloud OAuth client authorized for the **Data Manager API** (`datamanager` scope) + the Ads account linked in Data Manager — owner authorizes; credential stored **only** in n8n.
2. Enable login on the integration role (operator, never in the repo): `alter role orvion_integration login password '…';` — then create the n8n Postgres credential with it.
3. n8n reachable with both credentials → build the §2 workflow → run once against a test conversion → confirm `sent` + the `offline_conversion_sent` event.
