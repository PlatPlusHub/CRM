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

Open owner decisions — **IDs only; definitions, evidence and status live in `MASTER_GAP_REGISTER.md`, enforced by Check 11.** Every ID here is read as OPEN, so a decided one is removed rather than annotated. The 2026-09-04 reconciliation dispositioned **all 151** non-closed findings across BOTH register substrates (table rows *and* detail blocks, as Check 11 defines them): **76 scheduling backlog** (design accepted, batch assigned — *not* decisions), **17 decided by the owner on 2026-09-01 with implementation owed**, 17 superseded, 16 engineering defects, 15 closed-but-unreadable, 2 already resolved, **0 evidence gaps**. Genuinely open: **SUP-4c** (the conversion instant only) · **CUST-3** (do customers get a receivable ceiling) · **VOID-1** (draft-only voiding vs an ETA window vs credit notes) · **PLAN-1** (three "Limited" integers) · **DOC-LC-3** (does un-archiving exist) · **CANON-26-1** (admit `active → suspended`) · **BOOK-2** (per-passenger override meaning) · **RET-1** (a finite retention period; NULL = retain-forever is in force, so this is compliance, not a blocker).

Last Completed: **Decision census RECONCILIATION (2026-09-04) — the counts now close, and five settled decisions were taken back off this line.** Pass 2's totals never closed (`35+71 ≠ 100`) because it censused ONE substrate: Check 11 defines a finding as a table row **or** a `###` detail block, and the union is **314 findings — 163 closed, 151 non-closed** (`VOID-1`, `RET-1`, `RET-2` have no table row at all). Its `G=10` counted table rows while the prose beside it named 13 — two populations, one label. **The material finding: `OWNER-1` records eighteen decisions the owner ratified 2026-09-01, and pass 2 put five of them back here** (`BLOCKED-4`, `BLOCKED-5`, `AUDIT-4`, `RET-2`, `A3`) — proven from git history, where they were absent by decision. Only `BOOK-2` was a genuine addition. Their own rows still said `BLOCKED`/`OPEN`, dated before the ratification, so **Check 14 could not see it — GOV-20**; all 17 now carry the verdict on their own cell, mutation-proven both ways. **GOV-19 widened** to the 4 measured identity splits. Narrative: `session-2026-09-04-decision-census-reconciliation.md`.

Next capability: **GOV-18, now safe to start** — widen Check 2's open-detection beyond a bare `OPEN` cell, with a mutation proof in both directions. Its population is now measured: **15 findings are closed in substance but unreadable in form** (`PROVEN NOT A DEFECT`, `CONTROL APPLIED`, `BUILT`, `RECONCILED`), and 35 of 54 open rows use a richer form than the bare cell. Then, in order: **(2) GOV-20** — bind a ratification to the rows it ratifies; **(3) GOV-19** — split the 4 identity-split ids (`ATTR-1`/`CAT-5`/`CAT-6`/`SEC-3`); **(4) GOV-16** — a register→manifest guard comparing *decisions*, not open rows; **(5) DOC-LC-3's integrity half**; **(6) DELIV-1 + PH8-2** — one `reporting` view. Then the RBAC-6 class (HTTP probe first, not a migration), per `MASTER_EXECUTION_PLAN.md`, which owns the order.

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
