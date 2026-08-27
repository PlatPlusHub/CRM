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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 144 migrations** (latest `202607055500`), ledger fingerprint `95b67f1335820f641091f202c6610cd3` on all three; 74 tables; 71/601 catalog; 137 `app` functions; **73 `public` HTTP endpoints + 8 exposed reporting views** (API-1); 119 policies; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. API surface hash `731cbd41ce480d714802b3de9a255c7a` identical on local and Primary. **Storage: 1 private bucket, 2 policies, 0 objects.** n8n: **0 workflows** (re-proven live 2026-08-28), 2 credentials. **repo = local = Primary parity HOLDS, re-proven 2026-08-28.** Prove it with `scripts/check_database_parity.ps1`. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, which is their one authoritative home.**: **SEC-1/RPC-1** · PH8-2/PH8-3 · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **ORPH-1** · **SCHED-1** · **RBAC-2** · **PERM-1** · **LEAD-2** (no `walk_in` lead source) · **`suppliers.credit_limit_amount` visibility**. RESOLVED 2026-08-27/28: PP-2, SPP-1/SPP-2, POL-1, RBAC-1, CUR-1, FND-1, GRANT-1, **API-1**.

Last Completed: **API-1 — ORVION's application API surface (2026-08-28, `202607055500`), EARNED/CLOSED.** The database stops being unreachable. The surface was **classified before anything was wrapped**: of 137 `app` functions, 20 are triggers, 7 RLS helpers, 4 view helpers, 6 platform-only, 14 system/batch, and of the 86 remaining **15 are internal helpers deliberately NOT exposed** — above all `record_event`, the audit spine's sole writer, which "just expose the `app` schema" would have published as an endpoint. **71 capabilities + 8 reporting views** are now live, every wrapper `security invoker` so it adds reachability and zero authority. Verified on Primary over HTTP: `upload_document` → 401 (live, anon refused), `record_event`/`authorize`/`has_permission`/`platform_*` → 404 PGRST202 (absent). **The full employee revenue journey now runs end to end over HTTP** — 29 assertions, `scripts/verify_api_end_to_end.ps1` — with gross 6000 → commission 600 → company profit 5400 read from the employee's own report endpoint. Narrative: `api-1-application-surface-and-employee-journey-2026-08-28.md`.

Next capability: **Phase C — the system-wide zero-debt audit** (schema · RLS · RBAC · functions · triggers · events · finance · documents · subscriptions · reporting · integrations · testing · governance), then SCHED-1. The n8n workflow stays GATED. Suite **53 files / 612 assertions**, plus **36 storage + 29 journey end-to-end HTTP assertions**. Security posture, each proven by a named test: read scope, RBAC + finance write authority, plan gating, lifecycle/archive against direct DML, financial + document privacy, audit-spine integrity, subscription lifecycle + platform-vs-tenant authority, per-passenger financial authority, personal-scope reporting, document write integrity, payment-proof lifecycle, object-store authorization, retention + orphan reconciliation, privilege-change audit on every path, policy role scope, wrapper safety, **and the exposed API surface pinned by name**. Ordered backlog — **one home, `MASTER_EXECUTION_PLAN.md` Batch 6**.

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
