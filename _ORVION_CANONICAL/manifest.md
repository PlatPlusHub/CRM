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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 141 migrations** (latest `202607055200`), ledger fingerprint `db6975b3b3f025e47bc4e270752292c3` on all three; 74 tables; 71/601 catalog types/values; 71 permissions; 66 feature entitlements; reference data seeded; 136 `app` functions; 119 policies; 8 `reporting` views; **3 pg_cron jobs** (lead SLA, subscription lifecycle, document-storage reconciliation). **Storage: 1 private bucket (`documents`), 2 storage policies, 0 objects.** n8n: **0 workflows** (re-proven live 2026-08-27), 2 credentials. **repo = local = Primary parity HOLDS, re-proven 2026-08-27.** Prove it with `scripts/check_database_parity.ps1` — never the repository guard, which reads files only. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, which is their one authoritative home.** Restating them here is what repeatedly pushed this file over its leanness budget (owner directive 2026-08-27 §22): **SEC-1/RPC-1** · PH8-2/PH8-3 · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** (document retention period) · **RET-2** (a departed tenant's stored data) · **DEL-1** (byte deletion needs an executor outside the database) · **EVT-2** (42 producerless event types) · **`suppliers.credit_limit_amount` visibility**. RESOLVED this day: PP-2, SPP-1/SPP-2, **POL-1, RBAC-1, CUR-1**. RESOLVED: BLOCKED-1/2 + canon C5 (SPEC-157), canon C4 (SPEC-158), BLOCKED-3 (SPEC-155), AUDIT-2/3.

Last Completed: **WP-04-D — document retention, storage reconciliation, and the post-WP-04 discovery sweep (2026-08-27, `202607054900`–`202607055200`), EARNED/CLOSED.** The database provably cannot delete a storage object (`storage.protect_delete` + no `pg_net`), so the package splits the concern: **the database owns the decision, an external executor owns the bytes.** Retention defaults to NULL = retain forever, so "delete immediately" is unreachable by construction. The sweep also closed **POL-1**, **RBAC-1** (privilege revocation was never audited, and direct-DML grants were not either) and **CUR-1**. Narrative: `MASTER_EXECUTION_PLAN.md` Batch 6 and `wp-04d-retention-reconciliation-and-rbac-audit-2026-08-27.md`. Also EARNED/CLOSED this day: SPEC-156/157/158/159/159-A, WP-04-A/B/C.

Next capability: **Foundation Hardening — Zero-Known-Debt (owner directive 2026-08-24, extended 2026-08-27). The n8n workflow stays GATED.** Suite 51 files / 585 assertions. Security posture, each proven by a named test: read scope, RBAC + finance write authority, plan gating, lifecycle/archive against direct DML, financial + document privacy, audit-spine integrity, subscription lifecycle + platform-vs-tenant authority, per-passenger financial authority, personal-scope reporting, document write integrity, payment-proof lifecycle + narrowed document gate, object-store authorization (= document authorization), **retention + orphan reconciliation**, **privilege-change audit on every path**, **policy role scope**. Ordered backlog — **one home, `MASTER_EXECUTION_PLAN.md` Batch 6**: next is **WP-04-E** (the storage executor — the byte half of WP-04-D's split), then the customer-journey end-to-end pass, notifications, Employee/Supplier/Branch 360, and the 74-table sweep.

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
