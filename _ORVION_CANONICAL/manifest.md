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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 193 migrations** (latest `202607060400`), ledger `6e46c83ce978322be0d911618e9a0c1f`, full-function-surface hash `712148c491e987422ec6331b1d9af3e6` (273 functions) and structural-surface hash `ee2ab94e7571a7b48e88a86b6c6aadc5` (3,484 objects across ten surfaces) identical on both; **76 tables**; 71/607 catalog; **8 reporting views**; **75 client RPCs**. Every figure re-read live from BOTH environments 2026-09-04; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **96 files / 1407 assertions**, Pass A = Pass B, plus **430 end-to-end HTTP assertions** across six scripts. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **NONE. Zero open owner decisions for the first time in this programme.** IDs here are read as OPEN, so a decided one is removed rather than annotated; evidence lives in `MASTER_GAP_REGISTER.md` (Checks 11/14). The 2026-09-04 review closed five of eight on existing evidence (**BOOK-2**, **PLAN-1**, **CANON-26-1**, **DOC-LC-3**, **SUP-4c**); the owner then **APPROVED the remaining three**, now ENGINEERING tasks where implementation is owed, not questions: **CUST-3 = YES** (offer a nullable, tenant-supplied customer receivable ceiling; warning-only; no default value; no dunning) · **VOID-1 = BUILD THE REAL ARCHITECTURE** (an internal invoice void lifecycle modelled **separately** from the external ETA fiscal lifecycle, the boundary represented so a future ETA integration maps on without redesign; draft-only rejected; no ETA windows hard-coded) · **RET-1 = BUILD THE MECHANISM** (retention keyed by `document_type_code`; `NULL` still means no deletion policy; fail-closed; no legal periods invented — counsel supplies values later). **Genuinely open: none.**

Last Completed: **GOV-18, CUST-3, then VOID-1 (2026-09-04)** — three of the session's four capabilities, each verified through the full `§5a` protocol and deployed. **VOID-1** built the internal invoice void the owner required, cleanly separated from the external ETA fiscal lifecycle and with **no day-count of any kind encoded**: canon 26 gained the Invoice State Machine it never had, `voided` is reachable from `draft`/`issued`/`overdue` and is TERMINAL, and every rule is derived — the money refusal from `app.customer_balance`'s own arithmetic and `payment_allocations` rather than the status word, and the ONE external touchpoint is a refusal to void a document the authority has ACCEPTED. An externally recorded `cancelled` does NOT void the ORVION invoice, and a test pins that nothing invents that mapping. `journal_entries`' void columns are CLOSED BY DESIGN — a posted entry is reversed, never voided. Assertion 22 of `83_actor_attribution_test` demanded its own update when `invoices.voided_by` became derived. Narrative: `session-2026-09-04-gov18-cust3-void1-ret1.md`.

Next capability: **RET-1 — the last of the owner's four, and the only one not yet built.** A retention mechanism keyed by `document_type_code`, with `NULL` still meaning *no deletion policy defined*, fail-closed, superseded versions only, and **no legal period invented** — approved values arrive later from counsel. Blast radius measured: `app.document_retention_days()` is a ZERO-ARG global, called by `reconcile_document_storage` and `claim_storage_actions` and OVERRIDDEN by three pgTAP files and `verify_storage_end_to_end.ps1`. Replacing it with a per-type policy table also removes a PAR-2 hazard. Then: **GOV-20**, **GOV-19**, **GOV-16**, **SUP-4c**, **SUP-4d**, **CUST-4**, **CUST-5**, **DOC-LC-3**, **BOOK-2**, **DELIV-1 + PH8-2**, then the RBAC-6 class per `MASTER_EXECUTION_PLAN.md`.

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
