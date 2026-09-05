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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 202 migrations** (latest `202607061300`), ledger `c6398307872fcfb9e2a9752cec6edc9d`, full-function-surface hash `25d0575a7a85c95f826958b7c57b7722` (277 functions) and structural-surface hash `2fb356c9f9ebe30ff3e24f17bd53548c` (3,561 objects across ten surfaces) identical on both; **77 tables**; 71/611 catalog; **8 reporting views**; **75 client RPCs**. Every figure re-read live from BOTH environments 2026-09-06; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). Suite **103 files / 1560 assertions** (Pass A = Pass B), plus **430 end-to-end HTTP assertions** across six scripts, **all six re-run this session and green** — required, not optional, because `202607061300` constrains `payments`, `invoices`, `refunds`, `booking_items` and `quotations`, the exact tables those journeys write. Primary holds **zero business rows**.

Batch 6 surface coverage: **4 of 77 surfaces have a recorded audit disposition**, all four at `ADVERSARIAL` (`MASTER_SURFACE_DISPOSITION.md`, Checks 22 and 24). Batch 6 is **NOT complete** and its exit criteria are EC-1…EC-11 in `MASTER_EXECUTION_PLAN.md`, which also owns the standing adversarial method and the class taxonomy. The next slice is chosen by `scripts/batch6_select_target.ps1`, which ranks by measurement and stores nothing.

Active Change Request: None.

Open owner decisions — **MAIL-1**, and nothing else. IDs here are read as OPEN, so a decided one is removed rather than annotated; evidence lives in `MASTER_GAP_REGISTER.md` (Checks 11/14). MAIL-1 is not engineering and not blocking: ORVION sends no mail, every alert already writes a `pending` `notification_deliveries` row, and the database half of delivery is provider-neutral by design. Before any dispatcher can send, the owner must supply the **transactional email provider AND the Egyptian PDPC cross-border transfer licence naming its destination** — the register holds the legal evidence and why the licence decides the shortlist rather than the reverse. **RET-1's retention periods remain a counsel dependency, not an owner *decision* to make unaided** — the mechanism seeds ZERO policy rows, so nothing is destroyable while it waits.

Last Completed: **Batch 6 slice 3 — `company_assets`, and the class it found underneath (2026-09-06).** The selector chose the surface; `202607061300` closed **CA-1** (an asset bought for a negative amount), **CA-2** (an amount denominated in nothing) and **MONEY-1**. MONEY-1 was found by attacking the slice's own draft repair: PostgreSQL ranks `numeric` NaN above every non-NaN value, so **every `>= 0` money CHECK in the repository admitted it** — reproduced over HTTP (201) and shown to turn `customer_outstanding.outstanding_balance` into NaN. All 32 numeric columns on public base tables now carry a no-NaN constraint. **CDM-3** records that slice 1 left `campaign_daily_metrics` able to book spend with no currency; **MONEY-2** is open and deliberately unanswered. Narrative: `session-2026-09-06-batch6-slice3-company-assets.md`.

Next capability: **the n8n notification-dispatch workflow, which P3 unblocked** — its contract is `app.claim_notification_deliveries` / `app.record_notification_delivery_result`, and it needs MAIL-1 answered first because it is the half that actually sends. Independent of that, and needing no owner input: **Batch 6 slice 4** — re-run `scripts/batch6_select_target.ps1` and take its top row rather than trusting any written-down candidate, since each slice changes the inputs; then **DELIV-1** (one `reporting` view over exhausted work — `dead_lettered` now makes it trivial, and it covers SPEC-123's outbox too), **GOV-20**, **GOV-19**, **CUST-6**, **GOV-16**, **DOC-LC-3**, **BOOK-2**, **PH8-2**, then the RBAC-6 class. `MASTER_EXECUTION_PLAN.md` owns the order.

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
