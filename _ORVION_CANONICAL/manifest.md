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

Open owner decisions — **NONE. Zero open owner decisions for the first time in this programme.** IDs here are read as OPEN, so a decided one is removed rather than annotated; evidence lives in `MASTER_GAP_REGISTER.md` (Checks 11/14). The 2026-09-04 review closed five of eight on existing evidence (**BOOK-2**, **PLAN-1**, **CANON-26-1**, **DOC-LC-3**, **SUP-4c**); the owner then **APPROVED the remaining three**, now ENGINEERING tasks where implementation is owed, not questions: **CUST-3 = YES** (offer a nullable, tenant-supplied customer receivable ceiling; warning-only; no default value; no dunning) · **VOID-1 = BUILD THE REAL ARCHITECTURE** (an internal invoice void lifecycle modelled **separately** from the external ETA fiscal lifecycle, the boundary represented so a future ETA integration maps on without redesign; draft-only rejected; no ETA windows hard-coded) · **RET-1 = BUILD THE MECHANISM** (retention keyed by `document_type_code`; `NULL` still means no deletion policy; fail-closed; no legal periods invented — counsel supplies values later). **Genuinely open: none.**

Last Completed: **GOV-18 (2026-09-04) — Check 2's open-detector widened and mutation-proven; it found two real defects on its first run.** Re-measured, not quoted: the bare `| OPEN |` cell covered **20 of 84** open rows, so Check 2 and AUD-04's cross-Master pass were blind to **76%** of the open population — how GOV-17's five printed CLEAN. Each row's status cell is now found from **its own table header** (index 9 here, 2 and 5/6 elsewhere; without it a widened match would read the `Cert` ✅ and the `Owner Decision` `pending`), and the open vocabulary was **derived by enumerating every leading token**. Terminal verdicts stay out; detail blocks are deliberately not scanned for `open`, being an append-only narrative where an early `BLOCKED` before a later `RESOLVED` is correct history. Proven by `scripts/test_status_contradiction_guard.ps1`: **25 assertions, 0 failures**, both directions — its own control caught a harness defect first. It then flagged **ATTR-1** and **CAT-5**, stale GOV-19 splits, both reconciled on live evidence. Open ids visible: **20 → 82**. Narrative: `session-2026-09-04-gov18-cust3-void1-ret1.md`.

Next capability: **the three owner-approved decisions, in the owner's order — (1) CUST-3, (2) VOID-1, (3) RET-1.** **CUST-3** — a nullable, tenant-supplied customer receivable ceiling mirroring the shipped supplier pattern: warning-only, per-currency, no default, no dunning. **VOID-1** — the internal invoice void lifecycle, modelled **separately** from the external ETA fiscal lifecycle, with the boundary represented so a future ETA integration maps onto it without redesign; no speculative ETA windows encoded. **RET-1** — retention keyed by `document_type_code`, `NULL` still meaning no deletion, fail-closed, no legal periods invented. Then **GOV-20**, **GOV-19**, **GOV-16**, **SUP-4c**, **DOC-LC-3**, **BOOK-2**, **DELIV-1 + PH8-2**, then the RBAC-6 class, per `MASTER_EXECUTION_PLAN.md`.

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
