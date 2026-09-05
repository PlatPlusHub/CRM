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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 197 migrations** (latest `202607060800`), ledger `aba2537d0bc95efd5869e4a5605f783e`, full-function-surface hash `03732ae5bd8a52392652f221165b0095` (274 functions) and structural-surface hash `a5961d69f6d76589424bdf37943adbf9` (3,524 objects across ten surfaces) identical on both; **77 tables**; 71/607 catalog; **8 reporting views**; **75 client RPCs**. Every figure re-read live from BOTH environments 2026-09-05; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **99 files / 1453 assertions**, Pass A = Pass B, plus **430 end-to-end HTTP assertions** across six scripts. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **MAIL-1**, and nothing else. IDs here are read as OPEN, so a decided one is removed rather than annotated; evidence lives in `MASTER_GAP_REGISTER.md` (Checks 11/14). MAIL-1 is not engineering and not blocking: ORVION sends no mail, every alert already writes a `pending` `notification_deliveries` row, and the database half of delivery is provider-neutral by design. Before any dispatcher can send, the owner must supply the **transactional email provider AND the Egyptian PDPC cross-border transfer licence naming its destination** — Law 151/2020's Executive Regulations (Decision 81/2025, in force) require a separate licence before personal data leaves Egypt, and no adequacy list exists, so the licence decides the shortlist rather than the reverse. **RET-1's retention periods remain a counsel dependency and are not an owner *decision* to make unaided** — the mechanism seeds ZERO policy rows, so nothing is destroyable while it waits.

Last Completed: **Decision-debt closure (2026-09-05) — three migrations, one CI defect, one new guard, two findings the audit did not have.** `202607060600` closes the supplier-credit package as ONE control: **CUST-4** non-negative ceiling · **SUP-4d** ceiling probe (lowering a ceiling under a standing exposure was silent) · **CUST-5** row-image comparison deleted · **SUP-4c** foreign-currency exposure converted through the generic rate authority and NAMED when it cannot be. `202607060700` closes **AUTH-2**, found this session: `app.has_permission` ignored `user_role_assignments.starts_at` while the grant path beside it honoured it, so a future-dated assignment granted its permissions immediately. `202607060800` closes **LEAD-5**: the minute-ly SLA pass could overlap itself and double-write a warning. **CI-1**: the consistency workflow ignored three paths four of its own checks read; **Check 20** refuses that now. Narrative: `session-2026-09-05-decision-debt-closure.md`.

Next capability: **P3 — the notification delivery ledger's missing half, and it needs no owner input.** `notification_deliveries` records obligations and nothing ever retries or abandons one: no `attempt_count`, no `next_attempt_at`, no `last_error`, no dead-letter state, and no claim/result pair — while `app.claim_conversion_deliveries` / `app.record_conversion_delivery_result` are the shipped precedent to model on rather than reinvent. Provider-neutral and therefore NOT blocked by MAIL-1; provider integration belongs in n8n, never in PostgreSQL. Also open, none needing owner input: **GOV-20** (bind a ratification record to the rows it ratifies), **GOV-19** (split `ATTR-1`/`CAT-5`/`CAT-6`/`SEC-3`), **CUST-6**, **GOV-16**, **DOC-LC-3**, **BOOK-2**, **DELIV-1 + PH8-2**, then the RBAC-6 class. `MASTER_EXECUTION_PLAN.md` owns the order.

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
