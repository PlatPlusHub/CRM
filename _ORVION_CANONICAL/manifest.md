# ORVION Project Manifest

Version: 2.1
Status: Canonical
Purpose: Repository State
Loaded After: AGENTS.md

---

# Purpose

This document tells any agent or human where the project currently stands.

It exists to answer one question: what phase, task, and Change Request is active right now.

For where to begin, what to read, and who governs conduct, see `README.md` and `AGENTS.md` — this document does not restate their responsibilities.

This file holds ONLY current state. Detailed per-SPEC history is NOT restated here — it lives in the git log, `changes/*.md`, and `reports/`. Keeping this file lean keeps every session/`resume` cheap (it is re-read on every bootstrap), and the consistency guard enforces that mechanically on three axes: total lines, total characters, and per-line length.

---

# Current Development Status

Update this section continuously; keep it to current state only. `Last Completed` names only the single most recent capability — replace it each time, never chain a "Prior:" history (git log + `changes/` + `reports/` hold history). If any field starts becoming a changelog, trim it.

Current Phase: **Phase 8 (Offline Conversion) — IN PROGRESS**. Execution order 7→9→8→10 (`32`). Phases 2–7 + 9 COMPLETE. Supabase-native backend (ADR-0014); transport = Data Manager API + ECL via n8n outbox (ADR-0023).

Current Module: Phase-8 offline-conversion engine. ORVION-side pipeline implemented, deployed, verified live on Primary. Remaining: the n8n workflow itself — build and verify against the `MASTER_INTEGRATION_CATALOG.md §2` contract with the **eight** mandatory `§2a` corrections. The real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; schema and migration-count differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 143 migrations** (latest `202607055400`), ledger fingerprint `028708a3c36ee155e5eb932973abd5e2` on all three; 74 tables; 71/601 catalog types/values; 137 `app` functions; **2 `public` HTTP endpoints** (the only ones that exist — see API-1); 119 policies; 8 `reporting` views; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. **Storage: 1 private bucket (`documents`), 2 storage policies, 0 objects.** n8n: **0 workflows** (re-proven live 2026-08-27), 2 credentials. **repo = local = Primary parity HOLDS, re-proven 2026-08-27.** Prove it with `scripts/check_database_parity.ps1` — never the repository guard, which reads files only. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, which is their one authoritative home.** Restating them here is what repeatedly pushed this file over its leanness budget (owner directive 2026-08-27 §22): **SEC-1/RPC-1** · PH8-2/PH8-3 · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **ORPH-1** · **SCHED-1** · **RBAC-2** · **`suppliers.credit_limit_amount` visibility**. RESOLVED this day: PP-2, SPP-1/SPP-2, POL-1, RBAC-1, CUR-1, **FND-1, GRANT-1**. RESOLVED: BLOCKED-1/2 + canon C5 (SPEC-157), canon C4 (SPEC-158), BLOCKED-3 (SPEC-155), AUDIT-2/3.

Last Completed: **WP-04-E — the storage executor, storage proven end to end, and API-1 (2026-08-27, `202607055300`/`5400` + Edge Function `storage-executor`), EARNED/CLOSED.** The byte half of WP-04-D's split now exists: an Edge Function chosen because the platform injects `SUPABASE_SERVICE_ROLE_KEY` itself, so the route needs **zero new secrets**. Storage is PROVEN end to end for the first time — 36 real-HTTP assertions with real bytes (`scripts/verify_storage_end_to_end.ps1`). The sweep found **API-1**: every `app.*` RPC and every `reporting` view is unreachable over HTTP (PostgREST exposes only `public`, `graphql_public`), invisible to a green suite because every RPC test speaks SQL, not HTTP. Also closed **FND-1** and **GRANT-1**. Narrative: `MASTER_EXECUTION_PLAN.md` Batch 6 and `wp-04e-storage-executor-and-api-reachability-2026-08-27.md`.

Next capability: **API-1 — the client-facing endpoint surface. Now the single largest thing between ORVION and a usable system: the database is complete and unreachable.** The n8n workflow stays GATED. Suite 52 files / 600 assertions, plus 36 end-to-end HTTP assertions. Security posture, each proven by a named test: read scope, RBAC + finance write authority, plan gating, lifecycle/archive against direct DML, financial + document privacy, audit-spine integrity, subscription lifecycle + platform-vs-tenant authority, per-passenger financial authority, personal-scope reporting, document write integrity, payment-proof lifecycle, object-store authorization, retention + orphan reconciliation, privilege-change audit on every path, policy role scope, **wrapper safety (`security invoker` only) and the executor contract**. Ordered backlog — **one home, `MASTER_EXECUTION_PLAN.md` Batch 6**: **API-1**, then SCHED-1, the customer-journey pass over HTTP, notifications, and the 74-table sweep.

The workflow build steps remain preserved and unchanged in `MASTER_INTEGRATION_CATALOG.md §2/§2a`.

Also open and autonomous: the Phase-10 Meta-ecosystem Learn-Before-Designing research + communications-domain Design Challenge.

---

# Governance and Ownership

This document owns only the state above. Every other responsibility belongs elsewhere, by design, and is not restated here:

- Project identity, vision, and platform boundaries — `PROJECT_CONTEXT.md`.
- Engineering principles, execution rules, and workflow — `AGENTS.md` (with `GOVERNANCE.md` for knowledge governance and `CR_LIFECYCLE.md` for CR mechanics). `PROTOCOL.md` is retired to a pointer and owns nothing.
- Document discovery and reading order — `AGENTS.md §4` (the single, mandatory boot sequence); `README.md` is the one-hop router into it.
- Phase and module progress — `_ORVION_CANONICAL/32_execution_roadmap.md`, the single source of truth for that state.
- Per-capability history and rationale — the git log, `changes/*.md`, and `reports/`.

End of Document.
