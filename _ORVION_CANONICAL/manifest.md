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

This file holds ONLY current state. Detailed per-SPEC history is NOT restated here — it lives in the git log, `changes/*.md`, and `reports/`. Keeping this file lean keeps every session/`resume` cheap (it is re-read on every bootstrap), and Check 5 of the consistency guard enforces that mechanically.

---

# Current Development Status

Update this section continuously; keep it to current state only. `Last Completed` names only the single most recent capability — replace it each time, never chain a "Prior:" history (git log + `changes/` + `reports/` hold history). If any field starts becoming a changelog, trim it.

Current Phase: **Phase 8 (Offline Conversion) — IN PROGRESS**. Execution order 7→9→8→10 (`32`). Phases 2–7 + 9 COMPLETE. Supabase-native backend (ADR-0014); transport ADR-0023. **Phase 10 is NOT ready** — evidence in `32` under Phase 10; blocker is Phase 8's unbuilt n8n workflow, gated behind the Foundation Completion Programme.

Current Module: Phase-8 offline-conversion engine. ORVION-side pipeline implemented, deployed, verified live on Primary. Remaining: the n8n workflow itself — build and verify against the `MASTER_INTEGRATION_CATALOG.md §2` contract with the mandatory `§2a` corrections (that file owns how many). The real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; schema and migration-count differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 190 migrations** (latest `202607060100`), ledger `1eaa2ec7d64f0403c8587c01aab6975f`, full-function-surface hash `334a5bf9d6ccea0a1990e3b55444f654` (261 functions) and structural-surface hash `9a33ada33f678bb8596b8c3eccbca586` (3,448 objects across ten surfaces) identical on both; **76 tables**; 71/603 catalog; **8 reporting views**; **73 client RPCs**. Every figure re-read live from BOTH environments 2026-09-04; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **93 files / 1326 assertions**, plus **414 end-to-end HTTP assertions** across six scripts, Pass A = Pass B. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11.** Every ID on this line is read as an OPEN decision, so a decided one is removed rather than annotated. **Eight were closed by the 2026-09-04 decision-debt pass** and are gone from this line — see the register's closure section. Genuinely open, each narrowed to one question: **SUP-4c** (only the conversion instant remains; base currency, rate source and as-of rule all already exist) · **CUST-3** (do customers get a receivable ceiling at all) · **VOID-1** (draft-only voiding, an ETA cancellation window, or credit notes) · **PLAN-1** (three integers canon marks "Limited" and never defines) · **DOC-LC-3** (does un-archiving exist; the integrity half is engineering) · **CANON-26-1** (admit `active → suspended`) · **RET-1** (a finite retention period; NULL = retain-forever is already in force and blocks nothing) · **RET-2** (what ORVION owes a departed tenant's data).

Last Completed: **Decision-debt closure pass and the GitHub identity repair (2026-09-04).** Eight open decisions were re-derived from the implementation rather than trusted as labelled, and **none needed the owner**: **FIN-7** (the invoice state machine already exists in the RPCs — `issue_invoice` refuses anything but `draft`, `record_payment` DERIVES `paid`/`partially_paid`; only the second door is unguarded), **VERIFY-1** (canon 07 makes verifying and approving one act), **TRANS-1** (keep the guarded duplication; the cure needs polymorphism no constraint can check), **LIC-1** (accepted residual), **DELIV-1 + PH8-2** (observability), **QUO-4** (canon's scope column says department), **DOC-LC-2** (a VERSION supersedes, a DOCUMENT does not). **RET-1** reclassified safe-default-in-force; **SUP-4c** narrowed to one question — `tenants.default_currency_code` and a tenant-maintained `exchange_rates` already exist. New: **TAX-1**, **GOV-15**, **GOV-16**. **`origin` re-qualified as PlatPlusHub and `bootstrap.ps1` fixed** — the 2026-08-30 re-clone had silently restored the Shehabhub path. **No migration, no database change.** Narrative: `session-2026-09-04-decision-debt-closure.md`.

Next capability: **the four implementations whose decisions the 2026-09-04 pass closed — none needs owner input**, and they precede the Batch-6 table sweep under the rule *eliminate resolvable decision debt first, then continue execution*. In order: **(1) FIN-7's second door** — register the six invoice transitions read off `issue_invoice`/`record_payment` and attach `enforce_status_transition` to `invoices`, with a positive control per RPC path and a full `§5a` run; **(2) TAX-1** — the `tax_submission_status` guard argument guards an empty set; **(3) DOC-LC-3's integrity half** — refuse the divergent `lifecycle_status_code`/`is_archived` pair; **(4) DELIV-1 + PH8-2** — one `reporting` view. Then the RBAC-6 class (HTTP probe first, not a migration), per `MASTER_EXECUTION_PLAN.md`, which owns the order.

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
