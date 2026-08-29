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

Current Phase: **Phase 8 (Offline Conversion) — IN PROGRESS**. Execution order 7→9→8→10 (`32`). Phases 2–7 + 9 COMPLETE (Phase 9's six outputs re-proven live 2026-08-30). Supabase-native backend (ADR-0014); transport = Data Manager API + ECL via n8n outbox (ADR-0023). **Phase 10 is NOT ready** — evidence in `32` under Phase 10; blocker is Phase 8's unbuilt n8n workflow, gated behind the Foundation Completion Programme.

Current Module: Phase-8 offline-conversion engine. ORVION-side pipeline implemented, deployed, verified live on Primary. Remaining: the n8n workflow itself — build and verify against the `MASTER_INTEGRATION_CATALOG.md §2` contract with the **eight** mandatory `§2a` corrections. The real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; schema and migration-count differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 160 migrations** (latest `202607057100`), ledger fingerprint `9e5fb52c92ce30a8b6d0559be3da7110` and full-function-surface hash `d98abbdd9aea724630f2d97f91a21b08` (230 functions) identical on both; **75 tables**; 71/601 catalog; **154 `app` functions**; **76 `public` functions = 71 client RPCs + `moddatetime` + 4 service_role-only**, plus **8 reporting views**; **122 policies**; **229 triggers**; **3 pg_cron jobs**; **1 Edge Function (`storage-executor`, ACTIVE)**. Storage: 1 private bucket, 2 policies, 0 objects. n8n: **0 workflows**, 2 credentials. Every figure re-read live from BOTH environments 2026-08-30; **parity PROVEN, Primary's values read from Primary rather than supplied to the guard** (GUARD-1). Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11** (A3's row points on to `MASTER_ARCHITECTURE_DECISIONS.md` item 11): **SEC-1** (write-path architecture; part of the Phase-8 gate) · **TRANS-1** · PH8-2/PH8-3 · **PH8-5** · A3 · AUDIT-4 · PLAN-1 · **BLOCKED-4** · **BLOCKED-5** · **CANON-26-1** · **LIC-1** · **PP-1** · **RET-1** · **RET-2** · **DEL-1** · **EVT-2** · **SCHED-1** · **AUTH-1** · **DOC-EXP-1** · **SPP-3** · **SYSADMIN-1** · **FIN-5** · **VOID-1** · **FIN-7** (new 2026-08-29: canon defines sixteen state machines and no INVOICE one) · **DELIV-1** (new 2026-08-29; subsumed by PH8-2's decision) · **`suppliers.credit_limit_amount` visibility**. Resolved 2026-08-29 by the business-decision closure audit, from canon and live evidence: LEAD-2 · LEAD-3 · RBAC-2 · PERM-1 · TASK-3 · ORPH-1. Resolved items and their evidence: `MASTER_GAP_REGISTER.md`; RLS-1 merged into SEC-1.

Last Completed: **Pre-Phase-10 program reconciliation (2026-08-30, no migration).** Roadmap, plan, canon, register, index and guards checked against live systems rather than each other. **Phase 10 determined NOT READY** — Phase 8's only remaining deliverable is an n8n workflow, the instance holds **zero**, and the build is gated behind the Foundation Completion Programme. Phase 9 acceptance re-proven. Five governance defects fixed — **GOV-2** (the API contract was Living-Authoritative with no SSOT row), **GOV-3** (seven findings defined in Masters but missing from the register), **GOV-4** (Check 2's ID vocabulary frozen at the 2026-07 prefixes), **GOV-5** (four Living docs restated live state and all four went stale), **GOV-6** (two Batch-6 items already closed) — and guards gained **Check 11**. Narrative: `session-2026-08-30-program-reconciliation.md`.

Next capability: **executable without the owner** — **DOC-LC-1** (wire canon's Document Lifecycle machine into `app.status_transitions`; permissions derivable from the existing writers), then continue **API-3** (30 left; `create_journal_entry`, `merge_customer_identity` next), then Batch 6's remaining engineering items (`MASTER_EXECUTION_PLAN.md`). **Needs the owner:** **SEC-1**'s write-path architecture — largest open item, part of the Phase-8 gate — plus DOC-EXP-1, **FIN-7**, SCHED-1, RET-1, RET-2, AUTH-1, FIN-5, SYSADMIN-1, VOID-1, SPP-3, PH8-2, TRANS-1, and releasing the Foundation Completion gate itself. The n8n workflow stays GATED; **CONV-3** records what the integration phase must add. Suite **68 files / 816 assertions**, plus **235 end-to-end HTTP assertions** across six scripts — proven **order-independent**, green on a fresh `db reset` and again under every suite's residue. Security posture is proven test-by-test; `MASTER_GAP_REGISTER.md` names the file for each.

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
