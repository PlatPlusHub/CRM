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

Current Module: Phase-8 offline-conversion engine — ORVION-side pipeline IMPLEMENTED. **SPEC-122** (migration `202607050000`, `orvion_integration`'s missing `app`-schema `USAGE` grant + a permanent grant/schema-usage completeness guard) is committed to git (`6fdaa2c`, pushed) and **deployed + verified live on both Primary and Secondary** (`vrvtsxexkiiiivlkdxzp` and `brplkqmbzffpxqgkkdzo`, 89/89 migrations each, version-for-version and name-for-name identical, grant confirmed via `has_schema_privilege` on both). **The two authoritative Supabase projects are synchronized** (`MASTER_CERTIFICATION_STATUS.md`, CERTIFIED synchronized; full detail `MASTER_INTEGRATION_CATALOG.md §0/§4`). Primary is reached via the official Supabase Remote MCP over OAuth; re-verified reachable with a real data call (`list_migrations`) 2026-08-17. **CORRECTED 2026-08-17 (see `MASTER_INTEGRATION_CATALOG.md §3/§4` "Phase-8 execution checkpoint — CORRECTED" for the full account):** an earlier same-day entry here and in the catalog claimed the n8n workflow was built and manually validated; that was never independently verified and was contradicted by the owner directly inspecting the n8n UI (empty, no nodes, no executions) — the session making that claim had no tool able to reach n8n. The workflow still does **not** exist. `orvion_integration` login-enabled state is independently verified (`pg_roles.rolcanlogin`, via `supabase-primary` MCP); the Google OAuth client and "Postgres credential tested in n8n" claims remain **owner-reported only**, not independently verified, and should not be treated as fact until re-confirmed directly against the live n8n instance — same evidentiary category as the workflow claim that proved wrong. A synthetic test fixture mistakenly inserted into Primary on that false premise was fully deleted and re-verified at zero rows (Primary's `tenants` table is back to 0 rows). **n8n MCP — FIXED and CONNECTED 2026-08-20 (the 2026-08-17 "only a fresh session is needed" diagnosis was wrong):** the server had been registered only for the pre-migration `.../GitHub/ORVION` path, so no fresh session could ever have loaded its tools; that orphaned entry was removed and the server re-registered at **project scope in `.mcp.json`** (travels with the repository) and approved — `claude mcp get n8n` now reports `✔ Connected`, no OAuth prompt. **ORVION-side pipeline independently re-verified live on Primary the same day** (4 outbox RPCs + `record_offline_conversion` executable by `orvion_integration`, `app` USAGE true, `rolcanlogin` true, 89 migrations, 5 event-type codes seeded; `tenants`/`attribution_clicks`/`offline_conversions`/`deliveries` all 0 rows). Detail: `MASTER_INTEGRATION_CATALOG.md §4` (2026-08-20 checkpoint), `.workstation/manifest.md §4`. — **A FRESH SESSION is now the one and only remaining prerequisite** (verified: MCP tool registries build at session start, so the tools are absent in the session that registered them). **PH8-1 is RESOLVED (SPEC-123, migration `202607050100`, owner-approved 2026-08-20)** — the delivery lease/visibility timeout; committed and locally verified, **not yet deployed to Primary/Secondary (owner-gated step; the two projects are therefore 90 local vs 89 deployed until it is)**. Remaining Phase-8 work: build and verify the `§2` workflow via the n8n MCP, applying the **six** mandatory `§2a` spec corrections, against pre-production's empty tables; the real-GCLID test stays on hold until genuine ad-click traffic exists. Known constraint: Google Auth Platform is Testing status, so n8n's refresh token expires every 7 days until OAuth verification is completed — deferred to a pre-go-live gate, not a Phase-8 blocker. n8n's production Supabase target is USER-CONFIRMED as Primary (`§0`).

Active Change Request: None.

Context & remaining owner decisions (detail in the linked reports — not restated): sequencing is DECIDED (RC-4/Reports before Phase 8, 2026-07-16) and transport is DECIDED (ADR-0023: Data Manager API + ECL via n8n outbox). **Still-open owner decisions:** C4/C5 (activation-code, subscription grace — at the subscription-lifecycle trigger); A3 (money-storage ADR) + live-DB V-series re-verification — at the next comprehensive DB audit; Google OAuth / integration-role credentials for Phase-8 n8n go-live.

Last Completed: **SPEC-123 — conversion delivery lease / visibility timeout (2026-08-20, owner-approved: "I approve PH8-1. Proceed with the Lease / Visibility Timeout solution")**, resolving PH8-1: a delivery claimed but never acked was stranded `pending` forever, silently losing revenue attribution. Migration `202607050100` sweeps expired 30-minute leases to `failed` (`LEASE_EXPIRED`, `offline_conversion_failed` event flagged `expired_lease`) before claiming, so the existing retry path recovers the conversion — no new RPC, no new n8n node, no schema change, no new status vocabulary. Verified against the live local database, not just tests: PH8-1 reproduced pre-fix; two live two-session proofs (no double-claim; expiry race → exactly one event and one new attempt); exercised under `set role orvion_integration` including a refused zombie ack; partial index added only after measuring 57.0 ms → 0.173 ms at 200k rows. `db reset` clean (90 migrations), pgTAP 9 files/28 tests PASS, smoke-test `ALL CHECKS PASSED`. New finding **PH8-5** raised (no `transactionId` sent to Google → the lease's at-least-once delivery can double-count; now mandatory `§2a` correction 4). Detail: `changes/SPEC-123-conversion-delivery-lease.md`. **Not yet deployed to Primary/Secondary.**

Next capability: (current objective) **Build and verify the n8n offline-conversion workflow via the n8n MCP server.** Execute in this order — the sequence matters, and step 1 is where the previous attempt failed:
1. **Verify the n8n MCP tools are actually loaded in your session** (not merely that `claude mcp list` says Connected — tools are absent in any session that added the server mid-run, and absent entirely if the server is registered to another project scope). Since 2026-08-20 it is registered at project scope in `.mcp.json` and approved, reporting `✔ Connected` — so if the tools ARE present, prove it with a real n8n data call and continue; if they are absent, run `claude mcp get n8n` **from this repository directory** and stop, because only a fresh session can load them.
2. **Read `AGENTS.md §4` boot sequence, `MASTER_INTEGRATION_CATALOG.md §2` (the contract, including the SPEC-123 delivery lease) and `§2a` (SIX MANDATORY spec corrections — high-severity: acking a `validateOnly` run as success permanently marks real conversions delivered that were never delivered; and correction 4, `transactionId`, without which the lease's at-least-once delivery silently double-counts conversions).**
3. **Independently inspect the live n8n instance via MCP** — list workflows/credentials; establish what actually exists rather than trusting this file. The workflow is recorded as non-existent; confirm that yourself, and re-confirm the two owner-reported-only claims (Google OAuth credential, Postgres credential) now that MCP can see them.
4. **Re-assess PH8-2…PH8-5** (`MASTER_GAP_REGISTER.md`) against what you find before implementing — **PH8-1 is RESOLVED** (SPEC-123) but its migration must be **deployed to Primary/Secondary before the workflow runs unattended**; PH8-5 is mandatory at build time (`§2a` 4); PH8-2/PH8-3 are unresolved owner decisions; PH8-4 is informational.
5. **Build only after 1–4.**
6. **Verify the created workflow node-by-node through a fresh MCP read-back — never trust the creation call's own response** (n8n's MCP is Public Preview with documented node-selection rough edges; and treating a create/execute report as proof is precisely the failure corrected in `§4`).

**no paid n8n upgrade is required** (MCP is available on all editions). `orvion_integration` login is independently verified. The real-GCLID test stays owner/data-dependent until genuine ad-click traffic exists — no fabricated conversions or click IDs, and `validateOnly` must not be flipped to false without owner approval. Other remaining roadmap items stay either **owner-gated** — subscription lifecycle (C4/C5 business policy); HR (owner scheduling); Phase-10 comms *implementation* (Meta accounts/verification) — or **evidence-gated** (Phase 9 Tier B on measured cost; composite indexes A2 on volume; Google OAuth verification at pre-go-live). **One autonomous option remains open:** the Phase-10 Meta-ecosystem Learn-Before-Designing research + communications-domain Design Challenge.

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
