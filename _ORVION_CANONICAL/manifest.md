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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 181 migrations** (latest `202607059200`), ledger `67a9e05e43c733594a76dd7e6ce6da31`, full-function-surface hash `d9b0dd9cb6dfaa3ac2f38a9cc7601408` (247 functions) and structural-surface hash `71f87b282df0598ccc100e367e6f7e4c` (3,373 objects across ten surfaces) identical on both; **75 tables**; 71/601 catalog; **8 reporting views**; **72 client RPCs**. Every figure re-read live from BOTH environments 2026-09-01; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **86 files / 1154 assertions**, plus **371 end-to-end HTTP assertions** across six scripts, Pass A = Pass B. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11.** Reconciled 2026-09-01 against the owner's decision directive (**OWNER-1**): eighteen previously-listed IDs are now DECIDED and are engineering tasks, not open questions. Genuinely open: **RET-1** (legal-retention period; secondary sources only, counsel required) · **FIN-7** + **VOID-1** (an Invoice state machine would be NEW canon — canon 26 defines six machines and no invoice; must be presented before amendment) · **TRANS-1** (classify the 13 ungoverned status columns against canon 26 first) · **DELIV-1** + **PH8-2** (model the existing lease semantics before adding states) · **PLAN-1** (the three "Limited" ceilings canon leaves undefined — a pricing decision) · **DOC-LC-2** · **DOC-LC-3** · **CANON-26-1** · **LIC-1** (external dependency).

Last Completed: **PD-23 measurement + state reconciliation (2026-09-01) — no migration, and that is the conclusion.** **OWNER-1:** the open-decision line had not moved after the owner's directive, so **eighteen settled questions still presented as blocked**; reconciled 29 -> 12. **PD-23 PROVEN structurally:** no function anywhere references `usage_counters` (not even a read), 0 rows, and **`app.plan_limit` has no caller**; the boolean half IS enforced (`has_permission` -> `plan_allows`). **Not built, derived:** canon 28 already says "ceilings are readable, not enforced" and canon 09 says the limits "must be reviewed before pricing is finalized". Semantics differ per metric — users/branches/storage CURRENT-STATE, leads/bookings PERIODIC, automations external. Not user-forgeable (`authenticated` SELECT only). **Class re-scan:** of 23 tables with no function producer, all but three are seeded reference data or intentional direct-DML; the inert three are already recorded. **MEAS-2 FIXED** — Check 11 now tests register SUBJECTS, mutation-tested. Narrative: `session-2026-09-01-pd23-and-state-reconciliation.md`.

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
