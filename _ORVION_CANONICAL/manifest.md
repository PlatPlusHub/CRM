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

Live state: **repository, local AND Primary all at 178 migrations** (latest `202607058900`), ledger `f3298da92ae6321665fa0e1ee6e71cfd`, function surface `f9f1824d8c8d000c78c048e0a8861fe5` (244), structural surface `8e74bf6b8a4c3c6cb2aac86c848f38b1` (3,368 objects / ten surfaces — PAR-3, `scripts/parity_surface.sql`). **`DATABASE PARITY: CLEAN` (exit 0) — all three axes proven against values read FROM Primary (GUARD-1)**, 2026-08-31: the owner approved deployment and `202607058100`–`202607058900` (nine) were applied. **No undeployed migrations.** **75 tables**; 71/601 catalog; **8 reporting views**; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. Storage: 1 bucket, 0 objects. n8n: **0 workflows**. Read live 2026-08-31; Primary's values read FROM Primary (GUARD-1). Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11** (A3's row points on to `MASTER_ARCHITECTURE_DECISIONS.md` item 11): **SEC-1** · **TRANS-1** · PH8-2/PH8-3 · **PH8-5** · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **SCHED-1** · **AUTH-1** · **DOC-EXP-1** · **SPP-3** · **SYSADMIN-1** · **FIN-5** · **VOID-1** · **FIN-7** · **DELIV-1** · **DOC-LC-2** · **DOC-LC-3** · **`suppliers.credit_limit_amount` visibility**. Resolved items and their evidence: `MASTER_GAP_REGISTER.md`; RLS-1 merged into SEC-1.

Last Completed: **Batch-6 table-by-table audit, first slice (2026-08-31), `202607058800`/`202607058900` — DEPLOYED to Primary 2026-08-31 with the eight before them.** Slice chosen by measuring guard and test coverage across the 54 writable tables: three clean results (SPEC-138 covers identity/organization writes; the accounting core requires its canon-28 permission; every FK into `exchange_rates` is tenant-qualified) and four defects. **FX-1** a negative or zero exchange rate was insertable; **FX-2/3/4** three actor columns were accepted from the caller — chief among them **FX-3 (Medium)**, the record of who granted a role, where the RPC recorded the owner who called it and the direct INSERT recorded the manager being promoted. **The method failure is the lesson:** a hand-written actor-column list reported one gap and looked finished, so the detector became `83_actor_attribution_test.sql` assertion 22 — it asks the schema, carries no exemption list, found FX-4, and **closes GOV-8**. No new ADR: all four are instances of ADR-0024/0025. Narrative: `session-2026-08-31-batch6-attribution.md`.

Next capability: **executable without the owner** — **API-3 is CLOSED — 71 of 71 endpoints carry HTTP execution evidence** (generated count; `MASTER_API_CONTRACT.md` owns it). Next is the rest of Batch 6 (see the plan). **Needs the owner:** **SEC-1**'s write-path architecture — largest open item, part of the Phase-8 gate — plus DOC-EXP-1, **FIN-7**, SCHED-1, RET-1, RET-2, AUTH-1, FIN-5, SYSADMIN-1, VOID-1, SPP-3, PH8-2, TRANS-1, and releasing the Foundation Completion gate itself. The n8n workflow stays GATED; **CONV-3** records what the integration phase must add. Suite **83 files / 1,110 assertions**, plus **366 end-to-end HTTP assertions** across six scripts — proven **order-independent**, green on a fresh `db reset` and again under every suite's residue. Security posture is proven test-by-test; `MASTER_GAP_REGISTER.md` names the file for each.

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
