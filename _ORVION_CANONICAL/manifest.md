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

Current Module: Phase-8 offline-conversion engine. ORVION-side pipeline implemented, deployed, verified live on Primary. Remaining: the n8n workflow itself — build and verify against the `MASTER_INTEGRATION_CATALOG.md §2` contract with the **eight** mandatory `§2a` corrections. The real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; schema and migration-count differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 133 migrations** (latest `202607054400`), ledger fingerprint `721d571fb9fa7fdbc7e79f4d91eb0e87` on all three; 73 tables; 69/591 catalog types/values; 71 permissions; 66 feature entitlements; reference data seeded; 127 `app` functions; 117 policies; 8 `reporting` views; **2 pg_cron jobs** (lead SLA, subscription lifecycle). **Storage: 0 buckets, 0 objects, 0 storage policies** — WP-04-B territory. **repo = local = Primary parity HOLDS, re-proven 2026-08-27.** Prove it with `scripts/check_database_parity.ps1` — never the repository guard, which reads files only. Primary holds **zero business rows**. n8n: **0 workflows** (live 2026-08-26), 2 credentials.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, which is their one authoritative home.** Restating them here is what repeatedly pushed this file over its leanness budget (owner directive 2026-08-27 §22): **SEC-1/RPC-1** · PH8-2/PH8-3 · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** (a known limitation, not a decision). RESOLVED: BLOCKED-1/2 + canon C5 (SPEC-157), canon C4 (SPEC-158), BLOCKED-3 (SPEC-155), AUDIT-2/3.

Last Completed: **WP-04-A — document write integrity (2026-08-27, `202607054400`), EARNED/CLOSED.** Closes DOC-1/DOC-3: the storage path is now system-derived on every path and a version's identity is immutable. Narrative and evidence: `MASTER_EXECUTION_PLAN.md` Batch 6 and `wp-04a-document-write-integrity-2026-08-27.md`. Also EARNED/CLOSED this day: SPEC-156, SPEC-157, SPEC-158, SPEC-159, SPEC-159-A.

Next capability: **Foundation Hardening — Zero-Known-Debt (owner directive 2026-08-24, extended 2026-08-27). The n8n workflow stays GATED.** Suite 46 files / 510 assertions. Security posture, each proven by a named test: read scope, RBAC + finance write authority, plan gating, lifecycle/archive against direct DML, financial + document privacy, audit-spine integrity, subscription lifecycle + platform-vs-tenant authority, per-passenger financial authority, personal-scope reporting, document write integrity. Ordered backlog — **one home, `MASTER_EXECUTION_PLAN.md` Batch 6**: next is **WP-04-B** (payment-proof path end to end, then the narrowed subscription gate, then the storage-provider evaluation), followed by notifications, Employee/Supplier/Branch 360, and the 72-table sweep.

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
