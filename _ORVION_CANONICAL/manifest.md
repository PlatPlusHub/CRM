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

Current Module: Phase-8 offline-conversion engine. The ORVION-side pipeline is implemented, deployed, and independently verified live on Primary. Remaining Phase-8 work is the n8n workflow itself: build and verify it against the `MASTER_INTEGRATION_CATALOG.md §2` contract, applying the **eight** mandatory `§2a` corrections. The real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; schema and migration-count differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state (verified 2026-08-21): Primary at **102 migrations**, latest `202607051300`; repository, local stack and Primary agree by ledger fingerprint `2f1083ef29820eb33757821a5e0cb280`; 72 tables; 68/583 catalog types/values; 70 permissions; all Phase-8 tables at 0 rows; reference data seeded (82 countries / 82 nationalities / 20 languages). n8n instance `plat.app.n8n.cloud`: **0 workflows**, 0 executions, 2 credentials. Only credential *existence* is agent-verified — targets, the `datamanager` scope, and whether either authenticates remain unverified (`MASTER_INTEGRATION_CATALOG.md §4`).

Active Change Request: None.

Open owner decisions: **SEC-1 + RPC-1** (write-path model — `authenticated` holds direct table DML which bypasses `app.authorize()`, AND 35 of 72 tables have no RPC at all, so the RPC-only option cannot be adopted until those RPCs exist; decide before the first frontend); PH8-2/PH8-3 (consent surface, E.164 policy); C4/C5 (subscription activation-code, grace); A3 (money-storage ADR); AUDIT-2 (`feature_entitlements` seed); AUDIT-3/AUDIT-4. All carry evidence and next-step owners in `MASTER_GAP_REGISTER.md`.

Last Completed: **SPEC-136 - complete catalog enforcement (2026-08-21)**, resolving CAT-4 and VOCAB-1's residual. SPEC-127 had covered only the 12 tables with no RPC; columns written by an RPC were validated on that path alone, so deactivation still did nothing and a direct PostgREST write bypassed the only check they had. Migration `202607051300` extends `app.enforce_catalog_codes` to every catalog-backed column - 35 catalog triggers now - closing both and materially reducing SEC-1's blast radius, without touching a single RPC. Deliberate exclusions recorded as **CAT-5** (sub-status, whose family depends on service type) and **CAT-6** (five columns with no catalog family at all). Suite 20 files / 127 tests PASS. Detail: `changes/SPEC-136-complete-catalog-enforcement.md`.

Next capability: **Foundation Completion Programme, in progress (owner directive 2026-08-24). The n8n workflow stays GATED behind it.** STEP 1 (AUDIT-3) and the escalation it exposed are done — SPEC-137 (read-scope model) and SPEC-138 (RBAC write authority), 104 migrations, suite 22 files / 163 tests. **Both are applied LOCALLY ONLY: the `supabase-primary` MCP disconnected and needs re-authorization in an interactive session, so Primary is behind by 3 migrations and parity is unverified — deploy and re-verify before treating the Foundation as frozen.** Remaining, in order:
1. **STEP 2 — remaining governed writes**: exchange rates, subscriptions, approval review, lead reassignment, booking-item costing, platform admin, the system-set `task_overdue` sweep. Follow the SPEC-131/132/134 pattern.
2. **STEP 3 — CAT-5** (`booking_items.sub_status_code`, family conditional on `service_type_code`) **and CAT-6** (the remaining catalog-less columns; `scope_type` was resolved by SPEC-137).
3. **STEPS 4-8** — table-by-table audit, catalog/dropdown audit, duplicate-prevention audit, configuration audit, and the 360 reporting-readiness audit (Customer / Lead / Employee / Supplier / Branch).
4. **STEPS 9-16** — employee walkthrough, n8n and Google compatibility verification, clean reset, full regression, Primary verification, fresh-eyes review.
Evidence and open items are in `MASTER_GAP_REGISTER.md`. The workflow build steps remain preserved and unchanged in `MASTER_INTEGRATION_CATALOG.md §2/§2a`.

Also open and autonomous: the Phase-10 Meta-ecosystem Learn-Before-Designing research + communications-domain Design Challenge.

Prior phases (summary; full history in git log + `changes/` + `reports/`): Phase 2 (Database Foundation) COMPLETE; Phase 3 (Identity & Access) COMPLETE; Phase 4 (CRM Core) COMPLETE at SPEC-072; Phase 5 (Booking Core) COMPLETE through SPEC-083; Phase 9 (Reports, Tier A) COMPLETE.

---

# Governance and Ownership

This document owns only the state above. Every other responsibility belongs elsewhere, by design, and is not restated here:

- Project identity, vision, and platform boundaries — `PROJECT_CONTEXT.md`.
- Engineering principles, execution rules, and workflow — `AGENTS.md` (with `GOVERNANCE.md` for knowledge governance and `CR_LIFECYCLE.md` for CR mechanics). `PROTOCOL.md` is retired to a pointer and owns nothing.
- Document discovery and reading order — `AGENTS.md §4` (the single, mandatory boot sequence); `README.md` is the one-hop router into it.
- Phase and module progress — `_ORVION_CANONICAL/32_execution_roadmap.md`, the single source of truth for that state.
- Per-capability history and rationale — the git log, `changes/*.md`, and `reports/`.

End of Document.
