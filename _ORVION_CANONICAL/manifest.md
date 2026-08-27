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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 148 migrations** (latest `202607055900`), ledger fingerprint `54bdef85d1d286ae77f92ed0681baaff` on all three; 74 tables; 71/601 catalog; 139 `app` functions; **73 `public` HTTP endpoints + 8 exposed reporting views**; 119 policies; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. **Storage: 1 private bucket, 2 policies, 0 objects.** n8n: **0 workflows** (re-proven live 2026-08-28), 2 credentials. **repo = local = Primary parity HOLDS, re-proven 2026-08-28.** Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`.**: **SEC-1** (the direct-DML capability boundary — an architectural decision; exposure measured and capped) · PH8-2/PH8-3 · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **ORPH-1** · **SCHED-1** · **RBAC-2** · **PERM-1** · **LEAD-2** · **TRANS-1** · **TASK-3** · **FIN-5** (which permission opens each approval type) · **SYSADMIN-1** (a role with zero permissions) · **`suppliers.credit_limit_amount` visibility**. RESOLVED 2026-08-27/28: PP-2, SPP-1/SPP-2, POL-1, RBAC-1, CUR-1, FND-1, GRANT-1, API-1, FIN-2, TASK-1, TASK-2, RBAC-4, **FIN-3, FIN-4**. RLS-1 merged into SEC-1.

Last Completed: **FIN-3/FIN-4 — money now costs the same permission on every path (2026-08-28, `202607055900`), EARNED/CLOSED.** The SEC-1 inventory found that every money table's policy NAMED a permission — `VIEW_FINANCIAL_DOCUMENTS`, a **read** permission, OR'd with a plain visibility test — so the effective rule was "you may write money about anything you can see". Reproduced: an employee holding no `RECORD_PAYMENT` inserted a 999,999 EGP payment by direct DML. `journal_entries` had required the real capability all along, which is what made this an omission rather than a design choice: **the ledger was guarded and the cash was not.** Six tables now charge exactly the permission their own RPC charges. **FIN-4**: `requested_by` on an approval request is now derived, not accepted, so nobody can open a request in a colleague's name. Narrative: `phase-c-financial-capability-2026-08-28.md`.

Next capability: **SEC-1 — the direct-DML capability boundary. An architectural decision, with the full per-table inventory now in the plan.** The n8n workflow stays GATED. Suite **56 files / 633 assertions**, plus **118 end-to-end HTTP assertions** across four scripts (storage 36, employee journey 29, journey branches 26, role journeys 27). Security posture, each proven by a named test: read scope, RBAC + finance write authority, plan gating, lifecycle/archive against direct DML, financial + document privacy, audit-spine integrity, subscription lifecycle + platform-vs-tenant authority, per-passenger financial authority, personal-scope reporting, document write integrity, payment-proof lifecycle, object-store authorization, retention + orphan reconciliation, privilege-change audit, policy role scope, wrapper safety, the exposed API surface pinned by name, transition-permission parity, role coherence, the SEC-1 exposure ceiling, **and financial write capability on every path**.

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
