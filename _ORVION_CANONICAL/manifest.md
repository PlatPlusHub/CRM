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

Open owner decisions — **IDs only; definitions, evidence and status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11.** Every ID here is read as OPEN, so a decided one is removed rather than annotated. The 2026-09-04 resolution review re-derived all eight and **closed five** on evidence that already existed: **BOOK-2** (canon 31 defines the overrides), **PLAN-1** (canon 28's `Limited` means *scope*; canon 17 owns the numbers), **CANON-26-1** (not a defect — every non-paying state blocks writes), **DOC-LC-3**, **SUP-4c** (engineering). Genuinely open: **CUST-3** (does ORVION offer a customer receivable ceiling at all — engineering pre-solved; recommend YES, mirroring the shipped supplier-ceiling pattern, warn-only) · **VOID-1** (draft-only voiding, an ETA cancellation window, or credit notes — canon defines no invoice machine and no void permission; recommend draft-only) · **RET-1** (**compliance, and now dated** — Egypt's PDPL executive regulations (Decree 816/2025) are in force, they require a documented retention period tied to purpose, and the transitional period ends this November; keep NULL until counsel answers, but raise it now).

Last Completed: **Owner-decision resolution review (2026-09-04) — eight re-derived from the implementation, five closed, owner input 8 → 3.** Tested against `AGENTS.md §6` — an owner decision is legitimate only after canon, schema, implementation, consumers, tests and **authoritative external documentation** are exhausted *in that order*; **five failed, because canon or the code already answered them**. `BOOK-2` was defined verbatim in `31_schema_draft.md`. `PLAN-1`'s "three undefined Limited ceilings" was a misreading: canon 28 marks **five** features `Limited` and uses the word for *scope* in its role columns; canon 17 owns every number and supplies two; the other three have no metric to count. `CANON-26-1` is not a defect: `subscription_allows_write` blocks writes in every non-paying state. `DOC-LC-3`'s "contradiction" was two authorities over **two different columns** (`is_archived` is generic across 13 tables). `SUP-4c` is settled by `12 CFR 32.9`'s mark-to-market rule. Narrative: `session-2026-09-04-owner-decision-resolution-review.md`.

Next capability: **GOV-18, still the next guard** — widen Check 2's open-detection beyond a bare `OPEN` cell, with a mutation proof both ways (15 findings are closed in substance but unreadable in form; 35 of 54 open rows use a richer form). Then the newly-unblocked engineering, none needing owner input: **(2) SUP-4c** — convert exposure into the ceiling's currency at the spot rate, reporting un-convertible exposure rather than dropping it (`exchange_rates` is governed and unread today); **(3) DOC-LC-3** — the implication `lifecycle_status_code='archived' ⟹ is_archived`; **(4) BOOK-2** — the passenger-share invariant; **(5) GOV-20**, **(6) GOV-19**, **(7) GOV-16**; **(8) DELIV-1 + PH8-2**. Then the RBAC-6 class (HTTP probe first, not a migration), per `MASTER_EXECUTION_PLAN.md`, which owns the order.

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
