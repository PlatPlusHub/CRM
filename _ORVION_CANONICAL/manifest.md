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

Live state (verified 2026-08-21): Primary at **92 migrations**, latest `202607050300`; repository, local stack and Primary agree by ledger fingerprint `384ec4114530c662e1fe732ec9dc2cb6`; 72 tables; 67/569 catalog types/values; all Phase-8 tables at 0 rows. n8n instance `plat.app.n8n.cloud`: **0 workflows**, 0 executions, 2 credentials. Only credential *existence* is agent-verified — targets, the `datamanager` scope, and whether either authenticates remain unverified (`MASTER_INTEGRATION_CATALOG.md §4`).

Active Change Request: None.

Open owner decisions: **SEC-1** (write-path model — whether `authenticated` keeps direct table DML, which bypasses `app.authorize()`; decide before the first frontend); PH8-2/PH8-3 (consent surface, E.164 policy); C4/C5 (subscription activation-code, grace); A3 (money-storage ADR); AUDIT-2 (`feature_entitlements` seed); AUDIT-3/AUDIT-4. All carry evidence and next-step owners in `MASTER_GAP_REGISTER.md`.

Last Completed: **SPEC-126 — canonical input and catalog governance (2026-08-21)**, from the pre-n8n health gate. Five vocabulary/identity defects were reproduced behaviourally, then fixed and re-verified on Primary: catalog codes accepted casing and whitespace variants, a value could be created under an unregistered family, `catalog_values` uniqueness was global although the table is tenant-scoped, and customer identity matched by exact case-sensitive equality. Migration `202607050300`; guard `supabase/tests/11_vocabulary_and_input_governance_test.sql`; suite 11 files / 46 tests PASS. Phone normalization is formatting-only, so PH8-3 stays open. Detail: `changes/SPEC-126-canonical-input-and-catalog-governance.md`.

Next capability: **Build and verify the n8n offline-conversion workflow via the n8n MCP.** Execute in this order:
1. **Prove the n8n MCP tools respond** with a real data call — `✔ Connected` is a health check, not proof (`AGENTS.md §2`). If the tools are absent, run `claude mcp get n8n` from this repository directory and stop; only a fresh session can load them.
2. **Read** `MASTER_INTEGRATION_CATALOG.md §2` (the contract, including the SPEC-123 delivery lease) and **`§2a` — EIGHT mandatory corrections.** The four highest-consequence: acking a `validateOnly` run as success permanently marks real conversions delivered that were never delivered (1); missing `transactionId` silently double-counts under the lease's at-least-once delivery (4); an unset request-level `encoding` risks Google reading the SHA-256 digests under the wrong encoding (7); and acking a row whose `fieldWarnings` entry rejected its identifier marks an unmatched conversion `sent` (8).
3. **Independently inspect the live n8n instance** — confirm the workflow's non-existence yourself, and re-confirm the two owner-reported-only credentials now that MCP can see them.
4. **Re-assess PH8-2…PH8-8** in `MASTER_GAP_REGISTER.md` before implementing. PH8-1 is RESOLVED and live (SPEC-123, Primary only).
5. **Build only after 1–4**, then **verify node-by-node through a fresh MCP read-back** — never trust the creation call's own response.

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
