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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 201 migrations** (latest `202607061200`), ledger `9f574e3bb3080400047533e6c33b97b3`, full-function-surface hash `25d0575a7a85c95f826958b7c57b7722` (277 functions) and structural-surface hash `d339ae18c6cf10d030b3c0158bb009fe` (3,539 objects across ten surfaces) identical on both; **77 tables**; 71/611 catalog; **8 reporting views**; **75 client RPCs**. Every figure re-read live from BOTH environments 2026-09-05; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **102 files / 1520 assertions**, plus **430 end-to-end HTTP assertions** across six scripts — the HTTP total is unchanged and was **not re-run this session**, verified safe by measurement rather than assumption: no HTTP script references `financial_accounts` or either revoked helper. Primary holds **zero business rows**.

Batch 6 surface coverage: **3 of 77 surfaces have a recorded audit disposition**, all three at `ADVERSARIAL` (`MASTER_SURFACE_DISPOSITION.md`, Checks 22 and 24). Batch 6 is **NOT complete** and its exit criteria are EC-1…EC-11 in `MASTER_EXECUTION_PLAN.md`, which also owns the standing adversarial method and the class taxonomy. The next slice is chosen by `scripts/batch6_select_target.ps1`, which ranks by measurement and stores nothing.

Active Change Request: None.

Open owner decisions — **MAIL-1**, and nothing else. IDs here are read as OPEN, so a decided one is removed rather than annotated; evidence lives in `MASTER_GAP_REGISTER.md` (Checks 11/14). MAIL-1 is not engineering and not blocking: ORVION sends no mail, every alert already writes a `pending` `notification_deliveries` row, and the database half of delivery is provider-neutral by design. Before any dispatcher can send, the owner must supply the **transactional email provider AND the Egyptian PDPC cross-border transfer licence naming its destination** — Law 151/2020's Executive Regulations (Decision 81/2025, in force) require a separate licence before personal data leaves Egypt, and no adequacy list exists, so the licence decides the shortlist rather than the reverse. **RET-1's retention periods remain a counsel dependency and are not an owner *decision* to make unaided** — the mechanism seeds ZERO policy rows, so nothing is destroyable while it waits.

Last Completed: **Batch 6 becomes an adversarial assurance programme, and slice 2 runs under it (2026-09-05).** `MASTER_EXECUTION_PLAN.md` now owns the loop, a **closed ten-class attack taxonomy** declared per slice in its own test file, and the selection rule; **Check 24 (ADV-1)** refuses `ADVERSARIAL` without a declaring test file carrying negative assertions. `scripts/batch6_select_target.ps1` picks the next slice by measurement and **stores nothing**. It chose `financial_accounts`; `202607061200` closed **FA-1** and **SECDEF-1**. **FA-2 recorded and deliberately NOT fixed** — an owner/canon question. Narrative: `session-2026-09-05-batch6-adversarial-program.md`.

Next capability: **the n8n notification-dispatch workflow, which this unblocked** — its contract is `app.claim_notification_deliveries` / `app.record_notification_delivery_result`, and it needs MAIL-1 answered first because it is the half that actually sends. Independent of that, and needing no owner input: **Batch 6 slice 2** — the next surfaces to convert from `NOT-RECORDED` in `MASTER_SURFACE_DISPOSITION.md`, using the model slice 1 established; then **DELIV-1** (one `reporting` view over exhausted work — `dead_lettered` now makes it trivial, and it covers SPEC-123's outbox too), **GOV-20**, **GOV-19**, **CUST-6**, **GOV-16**, **DOC-LC-3**, **BOOK-2**, **PH8-2**, then the RBAC-6 class. `MASTER_EXECUTION_PLAN.md` owns the order.

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
