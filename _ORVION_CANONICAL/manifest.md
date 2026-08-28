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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 157 migrations** (latest `202607056800`), ledger fingerprint `0c48b1fd30c03d2dcf3137cfb4b171f3` on all three; 74 tables; 71/601 catalog; 140 `app` functions; **74 `public` HTTP endpoints + 8 exposed reporting views**; 119 policies; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. **Storage: 1 private bucket, 2 policies, 0 objects.** n8n: **0 workflows** (re-proven live 2026-08-28), 2 credentials. **repo = local = Primary parity HOLDS, re-proven 2026-08-28.** Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`.**: **TRANS-1** · PH8-2/PH8-3 · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **SCHED-1** · **AUTH-1** · **DOC-EXP-1** · **SPP-3** · **SYSADMIN-1** · **`suppliers.credit_limit_amount` visibility**. Narrowed 2026-08-29 with new evidence, still owner-blocked: **FIN-5**, **VOID-1**. **Resolved 2026-08-29 by the owner's business-decision closure audit — from canon and live evidence, without asking again: LEAD-2 · LEAD-3 · RBAC-2 · PERM-1 · TASK-3 · ORPH-1.** Newly open (engineering, not owner): **LEAD-4**, **GUARD-1** (mitigated). Resolved items and their evidence: `MASTER_GAP_REGISTER.md`; RLS-1 merged into SEC-1.

Last Completed: **ATTR-3 + LEAD-3 — acquisition lineage made immutable, and an overdue lead made to reach someone who can work it (2026-08-29, `202607056700`/`202607056800`), EARNED/CLOSED.** §8 item J answered by measurement: neither reassignment path rewrites attribution, and both now assert it. The owner's stronger rule was false — any employee could re-anchor a lead to another click, moving a future Google Ads conversion and its revenue between campaigns; the same hole existed on `offline_conversions`, the revenue end of the same chain. One first-touch trigger now covers both. LEAD-3 asked whether managers belong in the SLA reassignment pool; the permission matrix says yes, and the measurement found the real defect — the pool was PROXIMITY, not authority, and reassigned an overdue lead to a **trainee** who can neither quote nor close. Also recorded: **GUARD-1**, `check_database_parity.ps1` reported "primary proven" from a fingerprint I supplied to it. Narrative: `acquisition-lineage-and-the-eligible-handler-2026-08-29.md`.

Next capability: **executable without the owner — LEAD-4's class:** three scheduled jobs (`process_lead_sla`, `process_subscription_lifecycle`, `reconcile_document_storage`) report their failure modes only through a return value, and `pg_cron` reads none of them; `app.storage_action_backlog()` is the precedent for the surface that fixes it. **Needs the owner:** DOC-EXP-1's recipient/lead-time/cadence (the largest remaining operational hole), SCHED-1's route and secret, RET-1, AUTH-1, FIN-5, SYSADMIN-1, VOID-1, SPP-3, TRANS-1. The n8n workflow stays GATED. Suite **65 files / 761 assertions**, plus **179 end-to-end HTTP assertions** across five scripts — proven **order-independent**, green both on a fresh `db reset` and with every HTTP suite's residue in place. Security posture is proven test-by-test rather than asserted here; `MASTER_GAP_REGISTER.md` names the file for each.

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
