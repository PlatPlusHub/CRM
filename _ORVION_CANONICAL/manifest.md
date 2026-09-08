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

This file holds ONLY current state. Per-SPEC history lives in the git log, `changes/*.md` and `reports/`. Leanness keeps every bootstrap cheap, and Check 5 enforces it mechanically — the budget is never raised to fit, so trim instead.

---

# Current Development Status

Current state only. `Last Completed` names the single most recent capability — REPLACE it each time, never chain a "Prior:" history. If any field becomes a changelog, trim it.

Current Phase: **Phase 8 (Offline Conversion) — IN PROGRESS**. Execution order 7→9→8→10 (`32`). Phases 2–7 + 9 COMPLETE. Supabase-native backend (ADR-0014); transport ADR-0023. **Phase 10 is NOT ready** — evidence in `32` under Phase 10; blocker is Phase 8's unbuilt n8n workflow, gated behind the Foundation Completion Programme.

Current Module: Phase-8 offline-conversion engine. ORVION-side pipeline implemented, deployed, verified live on Primary. Remaining: the n8n workflow itself — build against the `MASTER_INTEGRATION_CATALOG.md §2` contract with its mandatory `§2a` corrections. The real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: Last fully verified 2026-09-08; Primary now UNPROVEN. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 209 migrations** (latest `202607062000`), ledger `102a08f0009493b58d2583ae28a0c17c`, full-function-surface hash `d0b08965d902ee9d9bc0bbb4c5d10745` (280 functions) and structural-surface hash `34add22404df8f87411f295bf72c069c` (3,568 objects across ten surfaces -- 3,566 plus slice 10's function and trigger) identical on both, all ten matching. All re-read live from BOTH environments 2026-09-08; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). **77 tables**; 71/611 catalog; **8 reporting views**; **75 client RPCs**. Suite **110 files / 1739 assertions** (Pass A = Pass B) plus **445 end-to-end HTTP assertions** across six scripts, last passed 2026-09-08; not re-run during the blocked 2026-09-09 bootstrap.

Batch 6 surface coverage: **11 of 77 surfaces have a recorded audit disposition**, all eleven at `ADVERSARIAL` (`MASTER_SURFACE_DISPOSITION.md`, Checks 22 and 24). Batch 6 is **NOT complete**; exit criteria EC-1…EC-11 and the adversarial method live in `MASTER_EXECUTION_PLAN.md`. The next slice is ranked by `scripts/batch6_select_target.ps1`, which stores nothing. **Its ranking was INVERTED until 2026-09-08 and is now EXPOSURE-ordered**; `Score` is a diagnostic, not the sort key. Primary last recorded **zero business rows** (2026-09-08; not re-read this session).

Active Change Request: None.

Open owner decisions — **MAIL-1**, **RET-1**, **AUDIT-2**, **PD-23**, **FA-2**, **MONEY-2**, **PAX-5**, **PAX-6**, **BOOK-8**, **BOOK-9**. IDs here are read as OPEN, so a decided one is removed rather than annotated; each one's exact question and evidence live in `MASTER_GAP_REGISTER.md` (Checks 11/14/25). **This line named only MAIL-1 until 2026-09-07**, when GOV-16's guard (**Check 25**) was written and measured seven registered decisions waiting behind it — a fresh session reads this line, not a 1,700-line register. **None blocks Batch 6, and in every case the shipped behaviour is the conservative reading.** MAIL-1 needs the **transactional email provider AND the Egyptian PDPC cross-border transfer licence naming its destination** (ORVION sends no mail; every alert already writes a `pending` `notification_deliveries` row). **RET-1's retention periods are counsel's, not an owner decision to make unaided** — the mechanism seeds ZERO policy rows, so nothing is destroyable while it waits.

Last Completed: **Batch 6 slice 10 -- `invoices` (2026-09-08).** `202607062000` closed INVOICE-1 through INVOICE-7. Slice-10 evidence: `session-2026-09-08-batch6-slice10-invoices.md`. Slice 11 is not started: Primary access failed during bootstrap. Narrative: `session-2026-09-09-batch6-slice11-primary-access-blocked.md`.

Current session blocker: dedicated `supabase-primary` tools are unavailable; account-level Supabase denied both Primary reads. Live parity is UNPROVEN. Restore Primary access and verify the baseline before Slice 11; customer disposition and coverage unchanged.

Next capability: **the n8n notification-dispatch workflow, which P3 unblocked** -- its contract is `app.claim_notification_deliveries` / `app.record_notification_delivery_result`, and it needs MAIL-1 answered first because it is the half that actually sends. Independent of that, and needing no owner input: **Batch 6 slice 11**, re-measured after slice 10 -- **`customers`** at exposure 17, then `quotations` and `users` at 15. Then **ENTRY-1**, **DELIV-1**, **GOV-20**, **CUST-6**, **DOC-LC-3**, **PH8-2**, then the RBAC-6 class. `MASTER_EXECUTION_PLAN.md` owns the order.

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
