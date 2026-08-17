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

Current Module: Phase-8 offline-conversion engine — ORVION-side pipeline IMPLEMENTED. **SPEC-122** (migration `202607050000`, `orvion_integration`'s missing `app`-schema `USAGE` grant + a permanent grant/schema-usage completeness guard) is committed to git (`6fdaa2c`, pushed) and **deployed + verified live on both Primary and Secondary** (`vrvtsxexkiiiivlkdxzp` and `brplkqmbzffpxqgkkdzo`, 89/89 migrations each, version-for-version and name-for-name identical, grant confirmed via `has_schema_privilege` on both). **The two authoritative Supabase projects are synchronized** (`MASTER_CERTIFICATION_STATUS.md`, CERTIFIED synchronized; full detail `MASTER_INTEGRATION_CATALOG.md §0/§4`). Primary is reached via the official Supabase Remote MCP over OAuth; re-verified reachable with a real data call (`list_migrations`) 2026-08-17. **CORRECTED 2026-08-17 (see `MASTER_INTEGRATION_CATALOG.md §3/§4` "Phase-8 execution checkpoint — CORRECTED" for the full account):** an earlier same-day entry here and in the catalog claimed the n8n workflow was built and manually validated; that was never independently verified and was contradicted by the owner directly inspecting the n8n UI (empty, no nodes, no executions) — this environment has no tool that can reach n8n (no MCP, no API, no working browser automation) and never did. `orvion_integration` login-enabled state is independently verified (`pg_roles.rolcanlogin`, via `supabase-primary` MCP); the Google OAuth client and "Postgres credential tested in n8n" claims remain **owner-reported only**, not independently verified, and should not be treated as fact until re-confirmed directly against the n8n UI — same evidentiary category as the workflow claim that proved wrong. A synthetic test fixture mistakenly inserted into Primary on the false premise a workflow existed to claim it was fully deleted and re-verified at zero rows. **Remaining Phase-8 work: establish a real n8n access path (owner rebuilding manually with stronger verification, or a working API/MCP/browser route), then build and verify the `§2` n8n workflow (map → claim → hash-at-edge → send → ack) against pre-production's empty tables before any real-GCLID test**, which stays on hold until genuine ad-click traffic exists. Known constraint: Google Auth Platform is Testing status, so n8n's refresh token expires every 7 days until OAuth verification is completed — deferred to a pre-go-live gate, not a Phase-8 blocker. n8n's production Supabase target is USER-CONFIRMED as Primary (`§0`).

Active Change Request: None.

Context & remaining owner decisions (detail in the linked reports — not restated): sequencing is DECIDED (RC-4/Reports before Phase 8, 2026-07-16) and transport is DECIDED (ADR-0023: Data Manager API + ECL via n8n outbox). **Still-open owner decisions:** C4/C5 (activation-code, subscription grace — at the subscription-lifecycle trigger); A3 (money-storage ADR) + live-DB V-series re-verification — at the next comprehensive DB audit; Google OAuth / integration-role credentials for Phase-8 n8n go-live.

Last Completed: SPEC-122 deployed to Primary (2026-08-15, owner-approved: "approve the schema usage grant fix", then "deploy SPEC-122 to Primary and Secondary", then explicitly "proceed with the next single step: deploy SPEC-122 to Primary" once Primary's OAuth connection was verified) — fixed a real, dynamically-discovered Phase-8 blocker (`orvion_integration` had `EXECUTE` grants on its 4 RPCs but no `USAGE` on the `app` schema, so none were actually callable). Migration `202607050000` + permanent guard (`scripts/verify_database.sql` Check 10) committed (`6fdaa2c`) and pushed; verified locally (pgTAP + smoke-test) and now live on **both** Primary and Secondary (grant confirmed pre/post via `has_schema_privilege` on each, versions reconciled, 89/89 migrations version-for-version and name-for-name identical). Full detail: `MASTER_INTEGRATION_CATALOG.md §4`, `MASTER_CERTIFICATION_STATUS.md`, `changes/SPEC-122-*.md`.

Next capability: (current objective) **Establish a real, verifiable n8n access path, then build and verify the n8n offline-conversion workflow.** `orvion_integration` login is independently verified; Google OAuth client creation and the n8n Postgres credential remain owner-reported only (never independently confirmed — full account and why `MASTER_INTEGRATION_CATALOG.md §3/§4` "Phase-8 execution checkpoint — CORRECTED"). The n8n workflow itself does **not** exist — an earlier claim that it was built and validated was contradicted by the owner's direct UI inspection and is corrected in the catalog. This environment has no tool that can reach n8n (no MCP, no API, no working browser automation). Remaining work: confirm/establish n8n access, rebuild the `§2` contract (map → claim → hash-at-edge → send → ack) with independently-checkable evidence this time, run non-destructive validation against pre-production's empty tables, and stop at the real-GCLID boundary (no fabricated conversions/click IDs) — that step stays owner/data-dependent until genuine ad-click traffic exists. Other remaining roadmap items stay either **owner-gated** — subscription lifecycle (C4/C5 business policy); HR (owner scheduling); Phase-10 comms *implementation* (Meta accounts/verification) — or **evidence-gated** (Phase 9 Tier B on measured cost; composite indexes A2 on volume; Google OAuth verification at pre-go-live). **One autonomous option remains open:** the Phase-10 Meta-ecosystem Learn-Before-Designing research + communications-domain Design Challenge.

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
