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

Current Phase: **Phase 8 (Offline Conversion) — IN PROGRESS**. Execution order 7→9→8→10 (`32`). Phases 2–7 + 9 COMPLETE. Supabase-native backend (ADR-0014); transport ADR-0023. **Phase 10 is NOT ready** — evidence in `32` under Phase 10; blocker is Phase 8's unbuilt n8n workflow, gated behind the Foundation Completion Programme.

Current Module: Phase-8 offline-conversion engine. ORVION-side pipeline implemented, deployed, verified live on Primary. Remaining: the n8n workflow itself — build and verify against the `MASTER_INTEGRATION_CATALOG.md §2` contract with the **eight** mandatory `§2a` corrections. The real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; schema and migration-count differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 183 migrations** (latest `202607059400`), ledger `a4e519b1bb1cf003274c4a153ce610bb`, full-function-surface hash `69f4d1ab766f60d958e0bbd41c36dc4f` (253 functions) and structural-surface hash `9a0e2b6c2c42779bcbf417a3438b3404` (3,388 objects across ten surfaces) identical on both; **75 tables**; 71/601 catalog; **8 reporting views**; **72 client RPCs**. Every figure re-read live from BOTH environments 2026-09-01; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **88 files / 1211 assertions**, plus **376 end-to-end HTTP assertions** across six scripts, Pass A = Pass B. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11.** Reconciled 2026-09-01: eighteen previously-listed IDs are now DECIDED and are engineering tasks, not open questions (evidence: the OWNER-1 row in the register — cited there, not listed here, because every ID on THIS line is read as an open decision). Genuinely open: **QUO-4** (open since 08-31 and missing from this line until 09-01 — GOV-9's own failure mode; evidence in the register) · **RET-1** (legal-retention period; counsel required) · **FIN-7** + **VOID-1** + **VERIFY-1** (unimplemented finance capabilities whose columns already exist; an Invoice state machine would be NEW canon) · **TRANS-1** (classify the 13 ungoverned status columns against canon 26 first) · **DELIV-1** + **PH8-2** (model the existing lease semantics before adding states) · **PLAN-1** (the three "Limited" ceilings canon leaves undefined — a pricing decision) · **DOC-LC-2** · **DOC-LC-3** · **CANON-26-1** · **LIC-1** (external dependency).

Last Completed: **PARENT-1 — the parent's state is a rule on every door (2026-09-01), `202607059400`, DEPLOYED.** Four RPCs refuse a write because of the PARENT row's state — an unaccepted quotation, a cancelled booking item, an archived document, a closed conversation — and **not one of those rules existed on the table door** `authenticated` reaches through PostgREST. The population was **derived from `app.status_transitions` + `pg_proc` + `pg_trigger`, not listed**: twelve candidate pairs, reduced to four by READING each function rather than trusting the match (**MEAS-1**). All four reproduced live with the RPC as positive control; closed with ONE guard and four BEFORE INSERT triggers, messages copied verbatim. The other four care/conversation tables came back clean **with the reason recorded**, not the count. Narrative: `session-2026-09-01-parent-state.md`.

Next capability: **executable without the owner — the remaining Batch-6 tables**, per `MASTER_EXECUTION_PLAN.md`, which owns the order. The care/conversation family is CLOSED on every door it has, and the parent-state class is pinned by a catalog-derived assertion that fails in both directions. API-3 is CLOSED (`MASTER_API_CONTRACT.md` owns the count). **Owner-blocked work is NOT listed here** — the `Open owner decisions` line above is the single list; duplicating it here is how it went stale. **SEC-1 is DECIDED, not open** (RLS for row scope + capability enforcement on writable surfaces + business rules in the RPC + path-independent integrity). The n8n workflow stays GATED behind the Foundation Completion Programme; **CONV-3** records what the integration phase must add, now including the message-level idempotency index its writer must ship with it.

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
