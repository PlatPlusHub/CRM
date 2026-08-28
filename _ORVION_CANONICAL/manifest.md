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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 151 migrations** (latest `202607056200`), ledger fingerprint `5c5b340536257dbf221ce3dad1dba536` on all three; 74 tables; 71/601 catalog; 140 `app` functions; **73 `public` HTTP endpoints + 8 exposed reporting views**; 119 policies; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. **Storage: 1 private bucket, 2 policies, 0 objects.** n8n: **0 workflows** (re-proven live 2026-08-28), 2 credentials. **repo = local = Primary parity HOLDS, re-proven 2026-08-28.** Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`.**: **TRANS-1** (narrowed 2026-08-28: no live disagreement, but unifying the runtime source needs a decision on where per-entity extras live). **SEC-1 RESOLVED 2026-08-28** — its three remaining tables are INTENTIONAL by canon 34 · PH8-2/PH8-3 · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **ORPH-1** · **SCHED-1** · **RBAC-2** · **PERM-1** · **LEAD-2** · **TASK-3** · **FIN-5** (which permission opens each approval type) · **SYSADMIN-1** (a role with zero permissions) · **`suppliers.credit_limit_amount` visibility**. Newly recorded: **AUTH-1**, **DOC-EXP-1**. Resolved items and their evidence: `MASTER_GAP_REGISTER.md`; RLS-1 merged into SEC-1.

Last Completed: **TRANS-2 and SEC-1's last table (2026-08-28, `202607056200`), EARNED/CLOSED.** Begins with a correction: `202607056100` said `app.record_lead_interaction` "authorizes nothing". It does — *"the assigned handler, OR ASSIGN_LEAD, plus MFA"*, inline with `has_permission` rather than `authorize`, which my permission-shaped detector could not see. Chasing the rule found the larger half: **eight `leads` transitions carry a NULL `permission_key`, and the trigger checked nothing when null** — so direct DML could walk a colleague's lead from `contacted` to `won` to `converted` while every RPC refused. Fixed by `app.require_lead_handler`, and **a null now means "apply this table's named fallback" — a table with neither FAILS CLOSED**. TRANS-1 investigated: no live disagreement, an `event` column NOT proven the right home, but its guard was checking ONE function out of ten and is rewritten. Ceilings **54/17/3**; the three are canon-34 Human Identity tables, so **SEC-1 has no unexplained residue left**. Narrative: `lead-handler-authority-and-trans-2026-08-28.md`.

Next capability: **SCHED-1** — nothing invokes the storage executor on a schedule, and the executor, the retention architecture and the reconciliation job now all exist. The n8n workflow stays GATED. Suite **59 files / 689 assertions**, plus **175 end-to-end HTTP assertions** across five scripts — and the pgTAP suite is now proven **order-independent**, re-run green both on a fresh `db reset` and with every HTTP suite's residue in place. Security posture, each proven by a named test: read scope, RBAC + finance write authority, plan gating, lifecycle/archive against direct DML, financial + document privacy, audit-spine integrity, subscription lifecycle + platform-vs-tenant authority, per-passenger financial authority, personal-scope reporting, document write integrity, payment-proof lifecycle, object-store authorization, retention + orphan reconciliation, privilege-change audit, policy role scope, wrapper safety, the exposed API surface pinned by name, transition-permission parity, role coherence, financial write capability, **the write-capability map**, and the SEC-1 residue ceiling.

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
