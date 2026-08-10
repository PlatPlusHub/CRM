# MASTER_INTEGRATION_CATALOG — External Integration Contracts

Class: **LIVING-AUTHORITATIVE** (evolve in place; one SSOT row per integration — `GOVERNANCE.md §2/§4`).
Purpose: the single registry of every external-platform integration — direction, transport, ORVION surface, status, and owning decision record. Seeded 2026-07-17 at its recorded trigger (Phase 8 landed; `future-backlog.md` Adopt-Later). Platforms are **consumers** of ORVION's verified outcomes, never dependencies (`PROJECT_CONTEXT.md §11`).

## 0. Supabase project topology (deployment targets — verify before every schema/data change)

Recorded here, not a new document: this is ORVION's own deployment-target registry, the closest existing fit to "external targets ORVION connects to" (`GOVERNANCE.md §6.8` — evolve an existing authoritative home rather than create a new one). Owner-provided ground truth, 2026-08-10.

| Project | Ref | Account | Organization | Role | Status |
|---|---|---|---|---|---|
| **ORVION** (primary) | `vrvtsxexkiiiivlkdxzp` | platplustours@gmail.com | Platinum Plus Tours (`zvlxdabpjuunyfigkhci`) — org name/id as owner-provided, not independently verifiable via MCP (see note) | **Primary** | ACTIVE_HEALTHY. **Reachable via the dedicated `supabase-primary` MCP server**, confirmed live 2026-08-10 (superseding the 2026-08-10 topology-correction entry below, which found it unreachable through a *different* connector — see note). Still not reachable through the `claude_ai_Supabase` connector (`list_projects` omits it; `get_project` returns a permission error — that connector is scoped to the `shehab.nim@gmail.com` account only; this is a connector-scoping fact, not a project-reachability fact). **SPEC-120 deployment status: VERIFIED — full comparison 2026-08-10, see `MASTER_CERTIFICATION_STATUS.md`.** |
| **orvion-core** (secondary / mirror) | `brplkqmbzffpxqgkkdzo` | shehab.nim@gmail.com | Orvion (`emjkklugmzgyuzuabell`) | **Secondary — mirrors primary** | ACTIVE_HEALTHY. SPEC-120 deployed and migration-version-reconciled 2026-08-10 (git history, `changes/SPEC-120-*.md`). Reachable via the `claude_ai_Supabase` connector. Confirmed identical to primary — full comparison 2026-08-10. |
| orvion-core *(deleted)* | `hzyuczdlwalectfduehw` | platplustours@gmail.com | Platinum Plus Tours | — | **DELETED — intentionally. Never use, restore, link, or reference.** |
| ORVION *(created by mistake)* | `wgsmrjcuhjdksfpdbhre` | shehab.nim@gmail.com | Orvion (`emjkklugmzgyuzuabell`) | — | Created 2026-08-09; zero migrations, zero tables (re-confirmed 2026-08-10 via `list_migrations`/`list_tables`). Not an ORVION target. **Owner intends manual deletion.** No `delete_project`-class tool exists in any Supabase MCP server available to this repository as of 2026-08-10 — deletion is not currently possible via MCP regardless of authorization. **Scoped pre-authorization (owner-ratified 2026-08-10):** if a project-deletion tool ever becomes available to a future session, deletion of this exact ref (`wgsmrjcuhjdksfpdbhre`) only is pre-authorized without a further live owner confirmation, on condition the agent re-runs and re-confirms the same four checks recorded above (exact ref match; not one of the two authorized refs; zero migrations; zero tables) immediately beforehand. This pre-authorization does not extend to any other project, ref, or account, and does not relax the Primary/Secondary protection below. |

**Note on primary org/account attribution:** the `vrvtsxexkiiiivlkdxzp` → `platplustours@gmail.com` / "Platinum Plus Tours" mapping above is owner-provided ground truth, not independently confirmed by this repository — the `supabase-primary` MCP server exposes no `get_project`/`get_organization`/`list_organizations` tool, only project-scoped data/schema tools, so there is no MCP call available to cross-check which account or organization it authenticates as.

**Synchronization & agent-discipline rules (owner-ratified 2026-08-10; expanded 2026-08-10 into an explicit checklist — content unchanged, only made enumerable and testable). Each item is tagged with what actually enforces it — do not read a tag as stronger than it is:**

1. GitHub repository (`supabase/migrations/**`) is the schema/migration source of truth. *[AGENT DISCIPLINE — a repo instruction; nothing scans for direct out-of-band schema edits on either live project.]*
2. No undocumented direct schema change against either project. *[AGENT DISCIPLINE]*
3. Every ORVION migration is tracked in GitHub before being applied anywhere. *[AGENT DISCIPLINE]*
4. Every applicable migration is applied to **both** Primary and Secondary. *[AGENT DISCIPLINE — no automated deployment fan-out exists; each apply is a manual/agent-directed MCP call today.]*
5. A database change is not "complete" until both projects are verified, not assumed. *[AGENT DISCIPLINE]*
6. A new session must verify the current project refs (this table) before any database write. *[AGENT DISCIPLINE]*
7. A new session must verify migration synchronization before declaring a database task complete. *[AGENT DISCIPLINE]*
8. Never assume one Supabase project represents the whole ORVION system. *[AGENT DISCIPLINE]*
9. Never use `wgsmrjcuhjdksfpdbhre` or `hzyuczdlwalectfduehw` (or any ref other than the two Primary/Secondary rows above) as an ORVION deployment target. *[PARTIALLY ENFORCED — `scripts/check_repository_consistency.ps1` Check 8 fails if this file's Primary/Secondary ref values are altered or the retired/mistake rows are removed, but it cannot inspect live MCP calls an agent actually makes.]*
10. Never delete either authorized project (Primary or Secondary) without explicit, contemporaneous owner authorization. *[AGENT DISCIPLINE — no technical control prevents it; this is a hard behavioral rule.]*
11. If one project is unreachable, report the access gap; never claim synchronization anyway. *[AGENT DISCIPLINE]*
12. If Primary and Secondary differ, report the difference; never silently declare them synchronized. *[AGENT DISCIPLINE]*
13. GitHub must be updated whenever repository migrations or this governance is changed. *[AGENT DISCIPLINE, backstopped by normal PR/commit review]*
14. This consistency check must be re-runnable by any future session. *[ENFORCED — `pwsh -File scripts/check_repository_consistency.ps1` is deterministic, dependency-free, exit-code gated.]*
15. The guard must fail loudly / report INCOMPLETE, never silently pass, when only one project has been updated. *[PARTIALLY ENFORCED — Check 8 catches the *documented* contradiction (this file marking a project's deployment status as not confirmed while `MASTER_CERTIFICATION_STATUS.md` simultaneously claims CERTIFIED synchronized); it cannot detect an actual live drift an agent never wrote down, because it has no live DB credentials by design (dependency-free, CI-safe).]*

**Honest limit, stated once here rather than re-litigated per item above:** items 1–13 and part of 15 are *instructions a compliant agent follows*, not something this repository can force an arbitrary LLM session to obey — nothing in Git or CI can stop a future session from querying or writing to the wrong project. Only items 9 (partially), 14, and 15 (partially) have an actual automated check behind them. **Verify the exact project ref before every schema-changing or destructive operation against either** — never assume which project is the target.

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
