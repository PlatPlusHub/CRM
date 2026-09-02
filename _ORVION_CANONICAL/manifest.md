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

This file holds ONLY current state. Detailed per-SPEC history is NOT restated here — it lives in the git log, `changes/*.md`, and `reports/`. Keeping this file lean keeps every session/`resume` cheap (it is re-read on every bootstrap), and Check 5 of the consistency guard enforces that mechanically.

---

# Current Development Status

Update this section continuously; keep it to current state only. `Last Completed` names only the single most recent capability — replace it each time, never chain a "Prior:" history (git log + `changes/` + `reports/` hold history). If any field starts becoming a changelog, trim it.

Current Phase: **Phase 8 (Offline Conversion) — IN PROGRESS**. Execution order 7→9→8→10 (`32`). Phases 2–7 + 9 COMPLETE. Supabase-native backend (ADR-0014); transport ADR-0023. **Phase 10 is NOT ready** — evidence in `32` under Phase 10; blocker is Phase 8's unbuilt n8n workflow, gated behind the Foundation Completion Programme.

Current Module: Phase-8 offline-conversion engine. ORVION-side pipeline implemented, deployed, verified live on Primary. Remaining: the n8n workflow itself — build and verify against the `MASTER_INTEGRATION_CATALOG.md §2` contract with the **eight** mandatory `§2a` corrections. The real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; schema and migration-count differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 188 migrations** (latest `202607059900`), ledger `0b98c574902c95689cf5111d6e39294f`, full-function-surface hash `b8a72aa22579faa9009c9d9aa0d0ec4d` (256 functions) and structural-surface hash `1fa67c9a20a59faf884c111b8059bcfe` (3,441 objects across ten surfaces) identical on both; **76 tables**; 71/601 catalog; **8 reporting views**; **72 client RPCs**. Every figure re-read live from BOTH environments 2026-09-02; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **92 files / 1301 assertions**, plus **395 end-to-end HTTP assertions** across six scripts, Pass A = Pass B. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11.** Every ID on THIS line is read as an open decision; a decided one leaves the line, and the register's OWNER-1 row holds the 2026-09-01 reconciliation that removed eighteen of them. Genuinely open: **QUO-4** · **SUP-4b** (which operation a supplier credit ceiling refuses, what overrides it, and whether it binds on all suppliers) · **RET-1** (legal-retention period; counsel required) · **FIN-7** + **VOID-1** + **VERIFY-1** (unimplemented finance capabilities whose columns already exist; an Invoice state machine would be NEW canon) · **TRANS-1** (classify the 13 ungoverned status columns against canon 26 first) · **DELIV-1** + **PH8-2** (model the existing lease semantics before adding states) · **PLAN-1** (the three "Limited" ceilings canon leaves undefined — a pricing decision) · **DOC-LC-2** · **DOC-LC-3** · **CANON-26-1** · **LIC-1** (external dependency).

Last Completed: **RBAC-3 + SUP-4a — capability grants become per-user, and the ceiling gets its currency (2026-09-02, `202607059800`/`202607059900`), deployed, parity re-proven.** OWNER-DIRECTED architecture decision, recorded as **ADR-0027**: rebuild was authorised and **rejected on evidence** — `role_permissions` was the only edge into `permissions` (one missing user→permission edge) while `has_permission` is already resolved by **60 RLS policies, 61 triggers, 76 functions**, so the grant model was refactored and the enforcement plane left untouched. `user_permission_grants` gives per-user grant/deny with **deny-override > user grant > role grant, then the plan gate**; roles stay overridable bundles; `capability_group`/`action_kind` derived from canon 28 for the dashboard. **No privilege expanded** — pinned by assertion. `finance_manager` gains Supplier Management per the owner. **SUP-4a:** `suppliers` was the ONLY money column in ORVION without a currency (canon 30), which is what made the ceiling incomparable — fixed. **SUP-4b stays OPEN** (which operation the ceiling refuses). Narrative: `session-2026-09-02-capability-authorization.md`.

Next capability: **executable without the owner — the remaining Batch-6 tables**, per `MASTER_EXECUTION_PLAN.md`, which owns the order. API-3 is CLOSED (`MASTER_API_CONTRACT.md` owns the count). **Owner-blocked work is NOT listed here** — the `Open owner decisions` line above is the single list; duplicating it here is how it went stale. **SEC-1 is DECIDED, not open** (RLS for row scope + capability enforcement on writable surfaces + business rules in the RPC + path-independent integrity). The n8n workflow stays GATED behind the Foundation Completion Programme; **CONV-3** records what the integration phase must add, now including the message-level idempotency index its writer must ship with it.

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
