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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 145 migrations** (latest `202607055600`), ledger fingerprint `89cd195343e88cd3f3faae44bbfe8f46` on all three; 74 tables; 71/601 catalog; 137 `app` functions; **73 `public` HTTP endpoints + 8 exposed reporting views**; 119 policies; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. API surface hash `731cbd41ce480d714802b3de9a255c7a` identical on both. **Storage: 1 private bucket, 2 policies, 0 objects.** n8n: **0 workflows** (re-proven live 2026-08-28), 2 credentials. **repo = local = Primary parity HOLDS, re-proven 2026-08-28.** Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`.**: **SEC-1/RPC-1** · PH8-2/PH8-3 · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **ORPH-1** · **SCHED-1** · **RBAC-2** · **PERM-1** · **LEAD-2** · **TASK-2** (a started task emits `task_assigned`) · **TRANS-1** (transition rules duplicated) · **RLS-1** (read scope is write scope on 11 tables) · **`suppliers.credit_limit_amount` visibility**. RESOLVED 2026-08-27/28: PP-2, SPP-1/SPP-2, POL-1, RBAC-1, CUR-1, FND-1, GRANT-1, API-1, **FIN-2, TASK-1**.

Last Completed: **Phase C first pass — the journey branches, and two dead capabilities (2026-08-28, `202607055600`), EARNED/CLOSED.** Walking the branches an agency actually works — refund, cancellation, complaint, service request, supplier payment, approvals, conversations, tasks, document versioning — over HTTP as real users found **FIN-2**: an employee could not REQUEST finance approval, because the guard treated writing `finance_approval_status_code='pending'` as APPROVING. The whole approval workflow was dead for the only role that needs it. And **TASK-1**: an employee could create and complete a task but not START one. Fixing TASK-1 exposed **TRANS-1** — transition permissions live in TWO places (`advance_*` inline VALUES and `app.status_transitions`, which the trigger reads), so the first fix drifted them apart; both are now corrected and compared by a permanent guard. Narrative: `phase-c-journey-branches-2026-08-28.md`.

Next capability: **Phase C continued — the system-wide table-by-table audit** (all 74 tables: schema, FKs, RLS, grants, triggers, events, reporting, integrations), then the manager/finance/CEO role journeys over HTTP, then SCHED-1. The n8n workflow stays GATED. Suite **54 files / 615 assertions**, plus **36 storage + 29 journey + 26 branch** end-to-end HTTP assertions. Security posture, each proven by a named test: read scope, RBAC + finance write authority, plan gating, lifecycle/archive against direct DML, financial + document privacy, audit-spine integrity, subscription lifecycle + platform-vs-tenant authority, per-passenger financial authority, personal-scope reporting, document write integrity, payment-proof lifecycle, object-store authorization, retention + orphan reconciliation, privilege-change audit on every path, policy role scope, wrapper safety, the exposed API surface pinned by name, **and transition-permission parity across both sources**.

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
