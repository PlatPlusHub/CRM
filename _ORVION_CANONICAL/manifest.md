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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 160 migrations** (latest `202607057100`), ledger fingerprint `9e5fb52c92ce30a8b6d0559be3da7110` on all three; 74 tables; 71/601 catalog; 140 `app` functions; **74 `public` HTTP endpoints + 8 exposed reporting views**; 119 policies; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. **Storage: 1 private bucket, 2 policies, 0 objects.** n8n: **0 workflows** (re-proven live 2026-08-28), 2 credentials. **repo = local = Primary parity HOLDS, re-proven 2026-08-28.** Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`.**: **TRANS-1** · PH8-2/PH8-3 · **PH8-5** · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **SCHED-1** · **AUTH-1** · **DOC-EXP-1** · **SPP-3** · **SYSADMIN-1** · **FIN-5** · **VOID-1** · **FIN-7** (new 2026-08-29: canon defines sixteen state machines and no INVOICE one) · **DELIV-1** (new 2026-08-29; subsumed by PH8-2's decision) · **`suppliers.credit_limit_amount` visibility**. Resolved 2026-08-29 by the business-decision closure audit, from canon and live evidence: LEAD-2 · LEAD-3 · RBAC-2 · PERM-1 · TASK-3 · ORPH-1. Resolved items and their evidence: `MASTER_GAP_REGISTER.md`; RLS-1 merged into SEC-1.

Last Completed: **SEC-2 resolved, FIN-6 closed, API-3 begun (2026-08-29, `202607057100`).** **SEC-2 was never one question**: descriptive fields are INTENTIONAL (the permission catalog holds only specific mutation permissions, no `app` function updates a descriptive field, canon 28 names none — so the table endpoint IS the door and RLS scope is the chosen control); consequence-bearing fields with no guard are DEFECTS, and searching found **FIN-6** — an employee holding CREATE_INVOICE=f marked a 50,000 EGP invoice PAID with no payment, while the AMOUNT change was refused in the same transaction. **FIN-6b**: the same guard mapped `receipts` to a column that does not exist, so its UPDATE branch had been inert since FIN-3. **API-3** 33 → 30: the lead machine now has an HTTP walk and TRANS-2's handler rule is proven over the wire for the first time. Recorded: **FIN-7**, **DOC-LC-1**, and **PAR-1b**, which corrects yesterday's parity claim. Narrative: `session-2026-08-29-contract-to-finance.md`.

Next capability: **executable without the owner** — **DOC-LC-1** (wire canon's Document Lifecycle machine into `app.status_transitions`; permissions derivable from the existing writers), then continue **API-3** endpoint by endpoint (30 left; `create_journal_entry` and `merge_customer_identity` next). **Needs the owner:** DOC-EXP-1's recipient/lead-time/cadence, **FIN-7** (which invoice status changes are legal), SCHED-1's route and secret, RET-1, AUTH-1, FIN-5, SYSADMIN-1, VOID-1, SPP-3, PH8-2, TRANS-1. The n8n workflow stays GATED; **CONV-3** records what the integration phase must add. Suite **68 files / 816 assertions**, plus **235 end-to-end HTTP assertions** across six scripts — proven **order-independent**, green on a fresh `db reset` and again under every suite's residue. Security posture is proven test-by-test; `MASTER_GAP_REGISTER.md` names the file for each.

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
