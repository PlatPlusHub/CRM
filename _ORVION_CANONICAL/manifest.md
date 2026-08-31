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

Current Phase: **Phase 8 (Offline Conversion) — IN PROGRESS**. Execution order 7→9→8→10 (`32`). Phases 2–7 + 9 COMPLETE. Supabase-native backend (ADR-0014); transport ADR-0023. **Phase 10 is NOT ready** — evidence in `32` under Phase 10; blocker is Phase 8's unbuilt n8n workflow, gated behind the Foundation Completion Programme.

Current Module: Phase-8 offline-conversion engine. ORVION-side pipeline implemented, deployed, verified live on Primary. Remaining: the n8n workflow itself — build and verify against the `MASTER_INTEGRATION_CATALOG.md §2` contract with the **eight** mandatory `§2a` corrections. The real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; schema and migration-count differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: **repository and local stack at 180 migrations** (latest `202607059100`), ledger `1b9b3c585513fc40897fe10e68e0bf5f`, structural surface `0b4ffdeff4299cf78ea0d231657014e5` (3,372 objects). **Primary `vrvtsxexkiiiivlkdxzp` remains at 179** (`1f64a99ca835e0a54a222944c1aadcf5`) — `202607059100` is IMPLEMENTED AND VERIFIED LOCALLY BUT NOT DEPLOYED, awaiting explicit owner approval for the Primary write. This divergence is deliberate and stated; the parity guard will report DRIFT until it is applied. Suite **85 files / 1143 assertions**, **366 end-to-end HTTP assertions** across six scripts, Pass A = Pass B. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11** (A3's row points on to `MASTER_ARCHITECTURE_DECISIONS.md` item 11): **SEC-1** · **TRANS-1** · PH8-2/PH8-3 · **PH8-5** · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **SCHED-1** · **AUTH-1** · **DOC-EXP-1** · **SPP-3** · **SYSADMIN-1** · **FIN-5** · **VOID-1** · **FIN-7** · **DELIV-1** · **DOC-LC-2** · **DOC-LC-3** · **`suppliers.credit_limit_amount` visibility**. Resolved items and their evidence: `MASTER_GAP_REGISTER.md`; RLS-1 merged into SEC-1.

Last Completed: **SEC-1c — a row you may not create is a row you may not rewrite (2026-09-01, `202607059100`).** `guard_write_capability` was attached BEFORE INSERT ONLY on 13 tables — the mirror of **SEC-1b**, in the direction nobody asked. REPRODUCED: a `trainee`, rows proven visible and its own INSERT refused, rewrote a customer, a passenger, and `suppliers.credit_limit_amount` 1000 -> 999999. **Permission DERIVED:** canon 28 defines no general edit permission, 12 tables already carried this guard on INSERT OR UPDATE, and `status_transitions.permission_key` records who may mutate each object — so UPDATE set = object-class permission UNION transition permissions. A CREATE-only rule was rejected on measured role holdings (would have broken `advance_booking`, `archive_document`, FIN-2). **Only HTTP caught the handler rule** — a trainee ASSIGNED a lead may log a call; pgTAP was fully green. **Re-scan 13 -> 0** (3 canon-34 identity tables are SEC-1's intentional residue; `lead_interactions` was a false positive of my own detector, **MEAS-3**). Test 85 (14); Pass A = Pass B **85/1143**; HTTP **366/366**. Narrative: `session-2026-09-01-sec-1c.md`.

Next capability: **executable without the owner** — **API-3 is CLOSED — 71 of 71 endpoints carry HTTP execution evidence** (generated count; `MASTER_API_CONTRACT.md` owns it). Next is the rest of Batch 6 (see the plan). **Needs the owner:** **SEC-1**'s write-path architecture — largest open item, part of the Phase-8 gate — plus DOC-EXP-1, **FIN-7**, SCHED-1, RET-1, RET-2, AUTH-1, FIN-5, SYSADMIN-1, VOID-1, SPP-3, PH8-2, TRANS-1, and releasing the Foundation Completion gate itself. The n8n workflow stays GATED; **CONV-3** records what the integration phase must add. Suite **84 files / 1,127 assertions**, plus **366 end-to-end HTTP assertions** across six scripts — proven **order-independent**, green on a fresh `db reset` and again under every suite's residue. Security posture is proven test-by-test; `MASTER_GAP_REGISTER.md` names the file for each.

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
