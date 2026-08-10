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

This file holds ONLY current state. Detailed per-SPEC history is NOT restated here — it lives in the git log, `changes/*.md`, and `reports/`. Keeping this file lean keeps every session/`resume` cheap (it is re-read on every bootstrap).

---

# Current Development Status

Update this section continuously; keep it to current state only. `Last Completed` names only the single most recent capability — replace it each time, never chain a "Prior:" history (git log + `changes/` + `reports/` hold history). If any field starts becoming a changelog, trim it.

Current Phase: **Phase 8 (Offline Conversion) — IN PROGRESS** (started 2026-07-17; Phase 9 Tier A COMPLETE the same day). Execution order 7→9→8→10 (`32`). Phases 2–7 + 9 COMPLETE. Supabase-native backend (ADR-0014); transport = Data Manager API + ECL via n8n outbox (ADR-0023).

Current Module: Phase-8 offline-conversion engine — ORVION-side pipeline IMPLEMENTED. **ORVION has TWO authoritative Supabase projects that must stay synchronized — full topology + safety rules: `MASTER_INTEGRATION_CATALOG.md §0`.** SPEC-120 is deployed and migration-version-reconciled (2026-08-10) on the **secondary/mirror** (`orvion-core`, ref `brplkqmbzffpxqgkkdzo`) — re-verified live: 569 catalog values, 3 subscription plans, all 4 refund events present, `customer_merged` absent. **The primary project (ref `vrvtsxexkiiiivlkdxzp`) is not reachable from this repository's current Supabase MCP connection (different account) — its SPEC-120 status is unverified** and must be confirmed/applied separately. Remaining Phase-8 item is outside the repository: n8n workflow activation after owner-exclusive Google OAuth `datamanager` credentials and the `orvion_integration` password are provisioned (`MASTER_INTEGRATION_CATALOG.md §3`).

Active Change Request: None.

Context & remaining owner decisions (detail in the linked reports — not restated): sequencing is DECIDED (RC-4/Reports before Phase 8, 2026-07-16) and transport is DECIDED (ADR-0023: Data Manager API + ECL via n8n outbox). **Still-open owner decisions:** C4/C5 (activation-code, subscription grace — at the subscription-lifecycle trigger); A3 (money-storage ADR) + live-DB V-series re-verification — at the next comprehensive DB audit; Google OAuth / integration-role credentials for Phase-8 n8n go-live.

Last Completed: SPEC-120/121 deployed to production (2026-08-10) — see Current Module above for verification detail. SPEC-120 corrected the canonical customer-merge event, registered four refund lifecycle events, seeded the three subscription plans, and added the event-vocabulary guard; SPEC-121 added the corresponding status-transition guard (local-only — a guard, not schema/data). `feature_entitlements` seeding remains an open owner decision (ambiguous mapping from canon — see `changes/SPEC-120-*.md` Notes and `reports/future-backlog.md`), not implemented.

Next capability: **The autonomous frontier is reached.** Every remaining roadmap item is either **owner-gated** — Phase-8 n8n workflow (needs Google OAuth `datamanager` + `orvion_integration` password, `MASTER_INTEGRATION_CATALOG.md §3`); subscription lifecycle (C4/C5 business policy); HR (owner scheduling); Phase-10 comms *implementation* (Meta accounts/verification) — or **evidence-gated** (Phase 9 Tier B on measured cost; composite indexes A2 on volume). **One autonomous option remains open:** the Phase-10 Meta-ecosystem Learn-Before-Designing research + communications-domain Design Challenge (research and design are autonomous; only implementation needs owner accounts) — start it if the owner wants Phase 10 designed ahead of credentials, otherwise the repo idles clean awaiting the catalog-§3 inputs.

Prior phases (summary; full history in git log + `changes/` + `reports/`): Phase 2 (Database Foundation, migrations 1–20) COMPLETE; Phase 3 (Identity & Access) COMPLETE; Phase 4 (CRM Core) COMPLETE at SPEC-072; Phase 5 (Booking Core) COMPLETE — SPEC-073…080 (booking / item / passenger creation + linkage, item + booking transitions, internal supplier linkage) plus SPEC-081–083 (finance-gate execution-approval control) done; negative-balance risk flag deferred to Finance Core per ADR-0020.

---

# Governance and Ownership

This document owns only the state above. Every other responsibility belongs elsewhere, by design, and is not restated here:

- Project identity, vision, and platform boundaries — `PROJECT_CONTEXT.md`.
- Engineering principles, execution rules, and workflow — `AGENTS.md` (with `GOVERNANCE.md` for knowledge governance and `CR_LIFECYCLE.md` for CR mechanics). `PROTOCOL.md` is retired to a pointer and owns nothing.
- Document discovery and reading order — `AGENTS.md §4` (the single, mandatory boot sequence); `README.md` is the one-hop router into it.
- Phase and module progress — `_ORVION_CANONICAL/32_execution_roadmap.md`, the single source of truth for that state.
- Per-capability history and rationale — the git log, `changes/*.md`, and `reports/`.

End of Document.
