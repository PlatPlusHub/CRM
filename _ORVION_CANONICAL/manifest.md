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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 182 migrations** (latest `202607059300`), ledger `18e452ceacd1fa1c405a1e7f0c1e4f57`, full-function-surface hash `52e4cce73a66148df0c453fd9cca98ba` (252 functions) and structural-surface hash `5d61e551b759bc661eb5633e2986ee9a` (3,383 objects across ten surfaces) identical on both; **75 tables**; 71/601 catalog; **8 reporting views**; **72 client RPCs**. Every figure re-read live from BOTH environments 2026-09-01; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **87 files / 1186 assertions**, plus **371 end-to-end HTTP assertions** across six scripts, Pass A = Pass B. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11.** Reconciled 2026-09-01: eighteen previously-listed IDs are now DECIDED and are engineering tasks, not open questions (evidence: the OWNER-1 row in the register — cited there, not listed here, because every ID on THIS line is read as an open decision). Genuinely open: **RET-1** (legal-retention period; secondary sources only, counsel required) · **FIN-7** + **VOID-1** + **VERIFY-1** (unimplemented finance capabilities whose columns already exist; an Invoice state machine would be NEW canon) · **TRANS-1** (classify the 13 ungoverned status columns against canon 26 first) · **DELIV-1** + **PH8-2** (model the existing lease semantics before adding states) · **PLAN-1** (the three "Limited" ceilings canon leaves undefined — a pricing decision) · **DOC-LC-2** · **DOC-LC-3** · **CANON-26-1** · **LIC-1** (external dependency).

Last Completed: **ATTR-2 — the hand that records is not always the hand that acted (2026-09-01), `202607059300`, DEPLOYED.** Six actor columns were accepted from the caller on the direct-DML door while their only RPC already recorded the caller and offered **no parameter to name anyone else** — the two doors disagreed, and the difference was forgery, not a business fact. Reproduced with live positive AND negative controls; the sharpest: a finance_manager who genuinely holds RECORD_PAYMENT recorded a payment as received by the EMPLOYEE while ATTR-1's trigger corrected `created_by` **in the same statement**. **Two of the six were invisible to the detector meant to find them** — they carry an actor without a `_by` suffix (**MEAS-4**), and that same predicate was whitespace-sensitive enough to have missed this migration's own fix; replaced with a STRUCTURAL one. **`payments.received_by` was decided by measurement, not by the suffix**; `payments.verified_by` was deliberately NOT derived (**VERIFY-1**). Narrative: `session-2026-09-01-attr2.md`.

Next capability: **executable without the owner — the care/conversation slice (`complaints`, `service_requests`, `conversations`, `conversation_messages`, `quotation_items`)**, per `MASTER_EXECUTION_PLAN.md` Batch 6, which owns the order. ATTR-2 is CLOSED and the class is now pinned STRUCTURALLY, so a new actor column fails the suite whatever it is named. API-3 is CLOSED (`MASTER_API_CONTRACT.md` owns the count). **Owner-blocked work is NOT listed here** — the `Open owner decisions` line above is the single list; duplicating it here is how it went stale. **SEC-1 is DECIDED, not open** (RLS for row scope + capability enforcement on writable surfaces + business rules in the RPC + path-independent integrity). The n8n workflow stays GATED behind the Foundation Completion Programme; **CONV-3** records what the integration phase must add.

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
