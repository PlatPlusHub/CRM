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

Current Module: Phase-8 offline-conversion engine — ORVION-side pipeline IMPLEMENTED. Local-repo state (88 migrations) was confirmed synchronized across BOTH authoritative Supabase projects as of 2026-08-10 (full comparison, `MASTER_INTEGRATION_CATALOG.md §0`); **SPEC-122 (migration `202607050000`, adds `orvion_integration`'s missing `app`-schema `USAGE` grant + a permanent grant/schema-usage completeness guard) landed 2026-08-15, repo-verified only (clean local `db reset`, full pgTAP suite, smoke-test all green) — NOT yet deployed to Primary or Secondary, so local/production are currently one migration out of sync; deploying `202607050000` to both is the concrete next action before Phase-8 n8n go-live.** Remaining Phase-8 items: that deployment; then n8n workflow activation after owner-exclusive Google OAuth `datamanager` credentials and the `orvion_integration` password are provisioned (`MASTER_INTEGRATION_CATALOG.md §3`). Google Ads Data Manager technical validation (account/conversion-action USER-CONFIRMED, transactionId strategy recommended, one `validateOnly` test executed — result in `§4`) and the internal pipeline validation that found the SPEC-122 gap are both tracked in `MASTER_INTEGRATION_CATALOG.md §4`; n8n's production Supabase target is USER-CONFIRMED as Primary (`§0`).

Active Change Request: None.

Context & remaining owner decisions (detail in the linked reports — not restated): sequencing is DECIDED (RC-4/Reports before Phase 8, 2026-07-16) and transport is DECIDED (ADR-0023: Data Manager API + ECL via n8n outbox). **Still-open owner decisions:** C4/C5 (activation-code, subscription grace — at the subscription-lifecycle trigger); A3 (money-storage ADR) + live-DB V-series re-verification — at the next comprehensive DB audit; Google OAuth / integration-role credentials for Phase-8 n8n go-live.

Last Completed: SPEC-122 (2026-08-15, owner-approved) — fixed a real, dynamically-discovered Phase-8 blocker (`orvion_integration` had `EXECUTE` grants on its 4 RPCs but no `USAGE` on the `app` schema, so none were actually callable) via migration `202607050000` plus a permanent guard (`scripts/verify_database.sql` Check 10, proven load-bearing by a negative-case test). Repo-verified only (local `db reset` + full pgTAP suite + smoke-test all green) — **not yet deployed to Primary or Secondary**, not yet committed to git. Full detail: `MASTER_INTEGRATION_CATALOG.md §4`, `changes/SPEC-122-*.md`.

Next capability: **Deploy SPEC-122's migration (`202607050000`) to both Primary and Secondary Supabase projects**, verifying each per `MASTER_INTEGRATION_CATALOG.md §0`'s synchronization rules — the concrete, owner-approved, not-yet-executed next step. After that, every remaining roadmap item is either **owner-gated** — Phase-8 n8n workflow (needs Google OAuth `datamanager` + `orvion_integration` password, `MASTER_INTEGRATION_CATALOG.md §3`); subscription lifecycle (C4/C5 business policy); HR (owner scheduling); Phase-10 comms *implementation* (Meta accounts/verification) — or **evidence-gated** (Phase 9 Tier B on measured cost; composite indexes A2 on volume). **One autonomous option remains open:** the Phase-10 Meta-ecosystem Learn-Before-Designing research + communications-domain Design Challenge.

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
