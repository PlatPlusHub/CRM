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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 181 migrations** (latest `202607059200`), ledger `67a9e05e43c733594a76dd7e6ce6da31`, full-function-surface hash `d9b0dd9cb6dfaa3ac2f38a9cc7601408` (247 functions) and structural-surface hash `71f87b282df0598ccc100e367e6f7e4c` (3,373 objects across ten surfaces) identical on both; **75 tables**; 71/601 catalog; **8 reporting views**; **72 client RPCs**. Every figure re-read live from BOTH environments 2026-09-01; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **86 files / 1154 assertions**, plus **371 end-to-end HTTP assertions** across six scripts, Pass A = Pass B. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **IDs only; every definition, its evidence and its status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11.** Reconciled 2026-09-01: eighteen previously-listed IDs are now DECIDED and are engineering tasks, not open questions (evidence: the OWNER-1 row in the register — cited there, not listed here, because every ID on THIS line is read as an open decision). Genuinely open: **RET-1** (legal-retention period; secondary sources only, counsel required) · **FIN-7** + **VOID-1** (an Invoice state machine would be NEW canon — canon 26 defines six machines and no invoice; must be presented before amendment) · **TRANS-1** (classify the 13 ungoverned status columns against canon 26 first) · **DELIV-1** + **PH8-2** (model the existing lease semantics before adding states) · **PLAN-1** (the three "Limited" ceilings canon leaves undefined — a pricing decision) · **DOC-LC-2** · **DOC-LC-3** · **CANON-26-1** · **LIC-1** (external dependency).

Last Completed: **Cold-start consistency pass (2026-09-01) — COLD-1, no migration.** Booted the repository as a fresh session would and asked what it would misunderstand. **One class, four instances, three presenting settled work as a live blocker:** canon 32's Phase-8 gate list (stale a SECOND time — naming DOC-LC-1, API-3, SPEC-154-B and **SEC-1** after all four were resolved/closed/shipped/decided), this file's `Next capability` (a duplicate blocker list, so one file asserted SEC-1 both decided and open), and `MASTER_EXECUTION_PLAN.md` item 8. **High for cold-start impact:** a fresh LLM would have read a settled architecture as open and could have re-proposed the RPC-only write model the owner REJECTED. Fixed by **deleting the restatements, not refreshing them**. **Check 14** makes it mechanical: every id on the open-decision enumeration must still be OPEN in the register, decided-set derived from the register itself, no exemption list. It immediately found **two defects in my own artifacts and one in itself** — all fixed, none exempted. Narrative: `session-2026-09-01-cold-start-consistency.md`.

Next capability: **executable without the owner — ATTR-2's remaining `_by` actor columns, then the care/conversation slice**, per `MASTER_EXECUTION_PLAN.md` Batch 6, which owns the order. API-3 is CLOSED (`MASTER_API_CONTRACT.md` owns the count). **Owner-blocked work is NOT listed here** — the `Open owner decisions` line above is the single list, reconciled 2026-09-01; duplicating it here is how it went stale. **SEC-1 is DECIDED, not open** (keep the refined architecture: RLS for row scope + capability enforcement on writable surfaces + business rules in the RPC + path-independent integrity). The n8n workflow stays GATED behind the Foundation Completion Programme; **CONV-3** records what the integration phase must add. Live suite figures are in `Live state` above, not restated here.

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
