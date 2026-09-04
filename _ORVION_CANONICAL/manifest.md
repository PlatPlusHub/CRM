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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 191 migrations** (latest `202607060200`), ledger `a54dd1d0c303b24fbbfccbae13b787de`, full-function-surface hash `334a5bf9d6ccea0a1990e3b55444f654` (261 functions) and structural-surface hash `8130e14bd2ef3d286da1a2f383ed4773` (3,455 objects across ten surfaces) identical on both; **76 tables**; 71/603 catalog; **8 reporting views**; **73 client RPCs**. Every figure re-read live from BOTH environments 2026-09-04; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **94 files / 1347 assertions**, plus **414 end-to-end HTTP assertions** across six scripts, Pass A = Pass B. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; definitions, evidence and status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11.** Every ID here is read as OPEN, so a decided one is removed rather than annotated. The 2026-09-04 census pass 2 dispositioned **all 100** non-closed register rows: **69 are scheduling backlog** (design accepted, batch assigned — *not* decisions), 10 superseded, 8 engineering defects, 2 already resolved, **0 evidence gaps**. The genuine business/policy choices, each narrowed to one question: **SUP-4c** (the conversion instant only) · **CUST-3** (do customers get a receivable ceiling) · **VOID-1** (draft-only voiding vs an ETA window vs credit notes) · **PLAN-1** (three "Limited" integers) · **DOC-LC-3** (does un-archiving exist) · **CANON-26-1** (admit `active → suspended`) · **RET-1** (a finite retention period; NULL = retain-forever is in force) · **RET-2** (a departed tenant's data) · **BLOCKED-4** (commission on ownership transfer) · **BLOCKED-5** (trial re-grant) · **AUDIT-4** (consent-record scope) · **BOOK-2** (per-passenger override meaning) · **A3** (ratify an ADR or accept the canon convention).

Last Completed: **Decision census pass 2 (2026-09-04) — all 100 non-closed register rows dispositioned, and FIN-7 shipped.** The manifest surfaced 15 and the previous pass estimated ~45; a positional census of column 9 found **237 ids: 131 closed, 35 DESIGN-READY, 100 non-closed**. The central finding: `Owner Decision` is a **scheduling** column, not a question column — the register's own policy says a Required finding's *design* must exist now and **implementation timing belongs to the owner** — so **69 of the 100 are product backlog**. **FIN-7 IMPLEMENTED and DEPLOYED** (`202607060200`): `draft → paid` was reproduced live at the table door, then six transitions read off `issue_invoice`/`record_payment` were registered and `enforce_status_transition` attached. **TAX-1 RETRACTED — never a defect**: the family exists as `tax_submission_status_code` with 5 values; the finding was built on truncated terminal output, and all 65 catalog pairs resolve. New: **GOV-17** (my own closure blocks used a Status form Check 2 cannot read) and **GOV-18** (Check 2 sees only a bare `OPEN` cell). Narrative: `session-2026-09-04-decision-census-pass-2.md`.

Next capability: **the engineering work whose decisions are now closed — none needs owner input.** In order: **(1) GOV-18** — widen Check 2's open-detection beyond a bare `OPEN` cell, with a mutation proof in both directions (it is blind to 35 of 54 open rows today); **(2) GOV-16** — a register→manifest guard that compares *decisions*, not open rows, now that the census shows 69 of 100 are backlog; **(3) DOC-LC-3's integrity half** — refuse the divergent `lifecycle_status_code`/`is_archived` pair without deciding un-archiving; **(4) DELIV-1 + PH8-2** — one `reporting` view distinguishing delivered / failed / in-flight / never-eligible. Then the RBAC-6 class (HTTP probe first, not a migration), per `MASTER_EXECUTION_PLAN.md`, which owns the order.

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
