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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 153 migrations** (latest `202607056400`), ledger fingerprint `63dba916b60bfc75d5c47b79c8bfe9f0` on all three; 74 tables; 71/601 catalog; 140 `app` functions; **74 `public` HTTP endpoints + 8 exposed reporting views**; 119 policies; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. **Storage: 1 private bucket, 2 policies, 0 objects.** n8n: **0 workflows** (re-proven live 2026-08-28), 2 credentials. **repo = local = Primary parity HOLDS, re-proven 2026-08-28.** Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`.**: **TRANS-1** (narrowed 2026-08-28: no live disagreement, but unifying the runtime source needs a decision on where per-entity extras live). **SEC-1 RESOLVED 2026-08-28** — its three remaining tables are INTENTIONAL by canon 34 · PH8-2/PH8-3 · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **ORPH-1** · **SCHED-1** · **RBAC-2** · **PERM-1** · **LEAD-2** · **TASK-3** · **FIN-5** (which permission opens each approval type) · **SYSADMIN-1** (a role with zero permissions) · **`suppliers.credit_limit_amount` visibility**. Newly recorded: **AUTH-1**, **DOC-EXP-1**, **ATTR-2**. Resolved items and their evidence: `MASTER_GAP_REGISTER.md`; RLS-1 merged into SEC-1.

Last Completed: **ATTR-1 — `created_by` is derived, not declared (2026-08-28, `202607056400`), EARNED/CLOSED.** Found by sweeping the class: every table `authenticated` may INSERT, checked for columns naming an actor. `archived_by` and `requested_by` are already derived; **`created_by` was not, on twenty tables** — so any tenant user could create a customer, booking, invoice or payment **attributed to a colleague**, and on `documents` that column is one of `scope_isolation`'s visibility grants. `app.derive_created_by()` applies FIN-4's ratified DERIVE-DO-NOT-VALIDATE shape and holds the value **immutable on UPDATE** (safe: no function anywhere updates it, verified first). Recorded rather than swept in: **ATTR-2**, the action attributions. Also widened: `10`'s PUBLIC-EXECUTE guard checked the `app` schema only, leaving `public` — where the 74 endpoints live — unchecked. Narrative: `created-by-and-the-attribution-class-2026-08-28.md`.

Next capability: **ATTR-2** (action attributions — engineering, no decision needed), then the gaps that **need the owner rather than more engineering** — SCHED-1's route and secret, RET-1's retention period, DOC-EXP-1's notification cadence, AUTH-1, FIN-5, SYSADMIN-1 and TRANS-1's unification. The n8n workflow stays GATED. Suite **61 files / 708 assertions**, plus **179 end-to-end HTTP assertions** across five scripts — and the pgTAP suite is now proven **order-independent**, re-run green both on a fresh `db reset` and with every HTTP suite's residue in place. Security posture is proven test-by-test rather than asserted here; `MASTER_GAP_REGISTER.md` names the file for each.

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
