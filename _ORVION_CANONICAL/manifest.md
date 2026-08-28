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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 159 migrations** (latest `202607057000`), ledger fingerprint `28cd2ca6d89881750b5cd2bfb84f9238` on all three; 74 tables; 71/601 catalog; 140 `app` functions; **74 `public` HTTP endpoints + 8 exposed reporting views**; 119 policies; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. **Storage: 1 private bucket, 2 policies, 0 objects.** n8n: **0 workflows** (re-proven live 2026-08-28), 2 credentials. **repo = local = Primary parity HOLDS, re-proven 2026-08-28.** Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`.**: **TRANS-1** · PH8-2/PH8-3 · **PH8-5** · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **SCHED-1** · **AUTH-1** · **DOC-EXP-1** · **SPP-3** · **SYSADMIN-1** · **FIN-5** · **VOID-1** · **SEC-2** (new 2026-08-29: no `update_*` RPC exists to read an edit permission from) · **DELIV-1** (new 2026-08-29; subsumed by PH8-2's decision) · **`suppliers.credit_limit_amount` visibility**. Resolved 2026-08-29 by the business-decision closure audit, from canon and live evidence: LEAD-2 · LEAD-3 · RBAC-2 · PERM-1 · TASK-3 · ORPH-1. Resolved items and their evidence: `MASTER_GAP_REGISTER.md`; RLS-1 merged into SEC-1.

Last Completed: **The care journeys — complaints and conversations over HTTP (2026-08-29, `202607057000`), EARNED/CLOSED.** Both state machines walked end to end on real JWTs; new suite `verify_care_journeys.ps1` (38). **SEC-1b**: SEC-1 was NOT closed — the ceiling asked whether a table had a trigger MENTIONING app.authorize, never WHEN it fires, and the two it matched are UPDATE-only; corrected residue 3 → 15. Reproduced: a **trainee** with no write permission inserted a complaint and a conversation by direct DML, and over the wire, in the same breath the RPC refused them. Twelve tables now guarded ON INSERT. Also **ATTR-4**, **CONV-2**, **COMP-1**, and two guard findings about this package itself — **TEST-2** and **PAR-1a** (which corrects yesterday's byte-identity claim). Narrative: `the-care-journeys-and-the-ceiling-that-counted-wrong-2026-08-29.md`.

Next capability: **executable without the owner** — §19's API capability contract (endpoint, request, response, permission, RLS scope, error states, pagination) for each employee-facing workflow, which must precede any WeWeb work; and the service-request lifecycle, the last after-sales branch with no dedicated HTTP walk. **Needs the owner:** DOC-EXP-1's recipient/lead-time/cadence, **SEC-2**'s edit-permission model, SCHED-1's route and secret, RET-1, AUTH-1, FIN-5, SYSADMIN-1, VOID-1, SPP-3, PH8-2, TRANS-1. The n8n workflow stays GATED. Suite **67 files / 805 assertions**, plus **220 end-to-end HTTP assertions** across six scripts — proven **order-independent**, green on a fresh `db reset` and again with every HTTP suite's residue in place. Security posture is proven test-by-test rather than asserted here; `MASTER_GAP_REGISTER.md` names the file for each.

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
