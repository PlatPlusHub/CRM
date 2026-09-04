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

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 194 migrations** (latest `202607060500`), ledger `6802ac41eaf6f4f17f0bf4cde7b3a720`, full-function-surface hash `8af5dd7786b940fe4208a1c00d28a7e9` (273 functions) and structural-surface hash `bf9883b7cad716e085620058135b3b82` (3,521 objects across ten surfaces) identical on both; **77 tables**; 71/607 catalog; **8 reporting views**; **75 client RPCs**. Every figure re-read live from BOTH environments 2026-09-04; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **97 files / 1423 assertions**, Pass A = Pass B, plus **430 end-to-end HTTP assertions** across six scripts. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **NONE, and all three of the owner's 2026-09-04 approvals are now BUILT.** IDs here are read as OPEN, so a decided one is removed rather than annotated; evidence lives in `MASTER_GAP_REGISTER.md` (Checks 11/14). The 2026-09-04 review closed five of eight on existing evidence (**BOOK-2**, **PLAN-1**, **CANON-26-1**, **DOC-LC-3**, **SUP-4c**); the owner then approved the remaining three, and this session implemented and deployed all of them: **CUST-3** (`202607060300`) · **VOID-1** (`202607060400`) · **RET-1** (`202607060500`). **One thing still waits on the owner, and it is not an engineering question:** RET-1's mechanism is built and seeds ZERO policy rows, so retention is undecided and nothing is destroyable — the **retention period per `document_type_code`** must come from counsel, reconciling Egypt's PDPL (Decree 816/2025, in force) against tax and commercial record-keeping minimums, and it drops into `public.document_retention_policies` with no schema change. **Genuinely open: none.**

Last Completed: **GOV-18, CUST-3, VOID-1 and RET-1 (2026-09-04) — all four owner-directed capabilities, each verified through the full `§5a` protocol and deployed to Primary.** **GOV-18** widened Check 2's open-detector (20 of 84 open rows were visible) and is mutation-proven both ways. **CUST-3** shipped a nullable, tenant-supplied, warning-only customer ceiling that CONVERTS foreign-currency exposure and REPORTS what it cannot price. **VOID-1** built the internal invoice void with **no day-count encoded anywhere**, canon 26's first Invoice State Machine, and one refusal where it meets the external ETA lifecycle. **RET-1** replaced a zero-arg global retention function with a per-`document_type_code` policy table — zero rows seeded, fail-closed by INNER JOIN rather than by a WHERE clause, and it removed the PAR-2 hazard that made three earlier sessions chase the same drift. **The guards caught fourteen real defects in this session's own work before any of it shipped.** Narrative: `session-2026-09-04-gov18-cust3-void1-ret1.md`.

Next capability: **the governance backlog these four exposed, none of it needing owner input.** In order: **(1) GOV-20** — bind a ratification record to the rows it ratifies (Check 14 reads each id's own cell and cannot see a verdict stored in another row's prose); **(2) GOV-19** — split the four identity-split ids (`ATTR-1`/`CAT-5`/`CAT-6`/`SEC-3`); **(3) SUP-4d** — the supplier ceiling never re-evaluates when the CEILING moves, found by an HTTP probe on the customer side; **(4) CUST-5** — the supplier credit-only branch is correct only by accident (a row-image comparison no mutating BEFORE trigger happens to disturb); **(5) GOV-16**, **(6) SUP-4c**, **(7) CUST-4**, **(8) DOC-LC-3**, **(9) BOOK-2**, **(10) DELIV-1 + PH8-2**. Then the RBAC-6 class, per `MASTER_EXECUTION_PLAN.md`, which owns the order.

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
