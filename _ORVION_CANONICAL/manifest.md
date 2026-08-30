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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 169 migrations** (latest `202607058000`), ledger fingerprint `4f79ecfdad3b2f1f424f72e70e414d86`, full-function-surface hash `a994108bd5cf44f9cc570180e72312a4` (236 functions) and **structural-surface hash `3a65328f42bd8c13b3f3048fa8f0158f` (3,348 objects across ten surfaces — PAR-3, `scripts/parity_surface.sql`)** identical on both; **75 tables**; 71/601 catalog; **160 `app` functions**; **76 `public` functions** (71 client RPCs), **8 reporting views**; **122 policies**; **238 triggers**; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. Storage: 1 bucket, 0 objects. n8n: **0 workflows**. Every figure re-read live from BOTH environments 2026-08-30; **parity PROVEN, Primary's values read FROM Primary** (GUARD-1). Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11** (A3's row points on to `MASTER_ARCHITECTURE_DECISIONS.md` item 11): **SEC-1** · **TRANS-1** · PH8-2/PH8-3 · **PH8-5** · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **SCHED-1** · **AUTH-1** · **DOC-EXP-1** · **SPP-3** · **SYSADMIN-1** · **FIN-5** · **VOID-1** · **FIN-7** · **DELIV-1** · **DOC-LC-2** · **DOC-LC-3** · **`suppliers.credit_limit_amount` visibility**. Resolved items and their evidence: `MASTER_GAP_REGISTER.md`; RLS-1 merged into SEC-1.

Last Completed: **Handoff-readiness pass (2026-08-30) — governance and continuity only; no migration, no roadmap change.** Reconciled every authority against live evidence and found five defects in the layer that RECORDS the work: **REG-1** (this register's only Critical row was escaped out of its own table and out of Check 2 — guarded by new **Check 13**, mutation-tested both ways), **REG-2** + **ROAD-1** (a coverage count and a Phase-10 evidence block restated live state and went stale — fixed by deletion and date-stamping, per GOV-5), **BOOT-1** (the verification protocol every package actually runs existed only in immutable history; now `AGENTS.md §5a`, with the seven evidence classes), **MF-1** (this file sat 5 characters under its budget; trimmed, never widened). Preceded by **ADMIN-1** — API-3's tenant-administration family, `202607058000`. Definitions and evidence: `MASTER_GAP_REGISTER.md`. Narrative: `session-2026-08-30-handoff-readiness.md` (its predecessor, `session-2026-08-30-tenant-administration.md`, carries ADMIN-1).

Next capability: **executable without the owner** — continue **API-3** (**16 left**; identity and tenant-administration families both closed — next is the lead-routing group: `assign_lead_round_robin`, `reassign_lead`, `lead_origin`, `lead_booking_readiness`), then Batch 6 (see the plan). **Needs the owner:** **SEC-1**'s write-path architecture — largest open item, part of the Phase-8 gate — plus DOC-EXP-1, **FIN-7**, SCHED-1, RET-1, RET-2, AUTH-1, FIN-5, SYSADMIN-1, VOID-1, SPP-3, PH8-2, TRANS-1, and releasing the Foundation Completion gate itself. The n8n workflow stays GATED; **CONV-3** records what the integration phase must add. Suite **76 files / 968 assertions**, plus **298 end-to-end HTTP assertions** across six scripts — proven **order-independent**, green on a fresh `db reset` and again under every suite's residue, and (since PAR-2) proven to leave the function surface **byte-equal to Primary** afterwards. Security posture is proven test-by-test; `MASTER_GAP_REGISTER.md` names the file for each.

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
