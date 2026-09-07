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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 203 migrations** (latest `202607061400`), ledger `36d87db9a2a106de2808d608c59ec6c2`, full-function-surface hash `8754ef0acd7e6dcb8a8574020c119239` (277 functions) and structural-surface hash `06a3c59e6a0c4585c97a29a1f2cc739a` (3,562 objects across ten surfaces) identical on both; **77 tables**; 71/611 catalog; **8 reporting views**; **75 client RPCs**. Every figure re-read live from BOTH environments 2026-09-07; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **104 files / 1602 assertions** (Pass A = Pass B), plus **430 end-to-end HTTP assertions** across six scripts, **all six re-run this session and green** — required, not optional, because `202607061400` puts a capability trigger on `booking_item_passengers`, and `verify_journey_branches` is the suite that writes it.

Batch 6 surface coverage: **5 of 77 surfaces have a recorded audit disposition**, all five at `ADVERSARIAL` (`MASTER_SURFACE_DISPOSITION.md`, Checks 22 and 24). Batch 6 is **NOT complete** and its exit criteria are EC-1…EC-11 in `MASTER_EXECUTION_PLAN.md`, which also owns the standing adversarial method and the class taxonomy. The next slice is chosen by `scripts/batch6_select_target.ps1`, which ranks by measurement and stores nothing — **except that `booking_items` is already named**, because slice 4 reproduced a High finding on it (**BOOK-3**) before its sweep began. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **MAIL-1**, and nothing else. IDs here are read as OPEN, so a decided one is removed rather than annotated; evidence lives in `MASTER_GAP_REGISTER.md` (Checks 11/14). MAIL-1 is not engineering and not blocking: ORVION sends no mail, every alert already writes a `pending` `notification_deliveries` row, and the database half of delivery is provider-neutral by design. Before any dispatcher can send, the owner must supply the **transactional email provider AND the Egyptian PDPC cross-border transfer licence naming its destination** — the register holds the legal evidence and why the licence decides the shortlist rather than the reverse. **RET-1's retention periods remain a counsel dependency, not an owner *decision* to make unaided** — the mechanism seeds ZERO policy rows, so nothing is destroyable while it waits.

Last Completed: **Batch 6 slice 4 — `booking_item_passengers` (2026-09-07).** `202607061400` closed **PAX-1**, **PAX-2** and **PAX-3**. **MEAS-2** is why it had been invisible: all three SEC-1 ceilings CREDITED this table for a guard that short-circuits, so the count never moved when the hole closed. Root-causing that produced **BOOK-3** (High, open) on `booking_items`. **PAX-4/5/6** are open by decision, not omission. Narrative: `session-2026-09-07-batch6-slice4-booking-item-passengers.md`.

Next capability: **the n8n notification-dispatch workflow, which P3 unblocked** — its contract is `app.claim_notification_deliveries` / `app.record_notification_delivery_result`, and it needs MAIL-1 answered first because it is the half that actually sends. Independent of that, and needing no owner input: **Batch 6 slice 5 — `booking_items`, NOT selector-chosen.** A reproduced High finding (**BOOK-3**) outranks a ranking; run the selector afterwards for slice 6. Then **DELIV-1** (one `reporting` view over exhausted work — `dead_lettered` now makes it trivial, and it covers SPEC-123's outbox too), **GOV-20**, **GOV-19**, **CUST-6**, **GOV-16**, **DOC-LC-3**, **BOOK-2**, **PH8-2**, then the RBAC-6 class. `MASTER_EXECUTION_PLAN.md` owns the order.

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
