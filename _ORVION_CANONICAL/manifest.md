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

Current Module: Foundation Completion Programme Batch 6, resuming at Slice 33 (`journal_entries`, measured 2026-10-08) by the owner's 2026-10-07 order (`32` Phase 8). Slice 32 is closed by SPEC-245; the n8n workflow follows Batch 6 and stays governed by `MASTER_INTEGRATION_CATALOG.md §2/§2a/§2b`; the real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: Last fully verified 2026-10-08. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 242 migrations** (latest `20261008120000`), ledger `5f8565a14fcf6ef6cc7bca0218a4bcd9`, full-function-surface hash `f704b7836a75f3f623a4112a28e5a779` (320 functions) identical on both; structural-surface hash `f18fcf70d3293eb80c4ec0536e1cced1` (3,110 objects) identical on both — **all ten surfaces identical** (`PAR-5` resolved by `SPEC-207`). Re-read live from Primary 2026-10-08; ledger **read FROM Primary** (GUARD-1). **78 tables**; 71/622 catalog; **8 reporting views**; **80 client RPCs**. Suite **145 files / 2657 assertions** (Pass A = Pass B) plus **458 end-to-end HTTP assertions** across six scripts, last passed 2026-10-08.

Batch 6 surface coverage: **33 of 78 surfaces have a recorded audit disposition**, all thirty-three at `ADVERSARIAL` (`MASTER_SURFACE_DISPOSITION.md`, Checks 22 and 24). Batch 6 is **NOT complete**; exit criteria EC-1…EC-11 and the adversarial method live in `MASTER_EXECUTION_PLAN.md`. The next slice is ranked by `scripts/batch6_select_target.ps1`, which stores nothing. **Its ranking was INVERTED until 2026-09-08 and is now EXPOSURE-ordered**; `Score` is a diagnostic, not the sort key. Primary bookings, booking_items, passengers and booking_item_passengers tables had zero rows at SPEC-224 deployment precheck (2026-09-26).

Active Change Request: changes/SPEC-246-a-posted-journal-entry-is-never-rewritten.md

Open owner decisions — **MAIL-1**, **RET-1**, **PH8-10**. These are exact external prerequisites, not unresolved architecture: MAIL-1 has technically selected Resend but production activation still requires owner authorization and counsel/PDPC confirmation for the actual cross-border destination; RET-1's retention/closure architecture and legal-hold override are implemented, while counsel must supply the actual per-type periods as tenant configuration; PH8-10 awaits Google evidence that click-less phone conversions are credited. No email is sent and no retention policy is seeded while those prerequisites remain. The other eight decisions in the 2026-09-09 closure are resolved and removed from this OPEN line; evidence lives in `MASTER_GAP_REGISTER.md`.

Last Completed: **SPEC-245 closed Batch 6 Slice 32: a journal line is written only with its entry, and the balance check judges every entry a line leaves or joins (JE-3, JE-4; 2026-10-08).**

Narrative: `agent-control-plane-corrective-repair-2026-09-11.md` — the latest *session report* (Check 10 pairs this with `reports/README.md`). `SPEC-160` deliberately wrote none: its contract, tests and Git own the evidence.

Current session blocker: **None.**

Other open work is owned elsewhere and is never restated as the next action: `MASTER_EXECUTION_PLAN.md` owns Batch 6 order, the Phase-10 Meta-ecosystem Learn-Before-Designing research and the communications-domain Design Challenge; `MASTER_INTEGRATION_CATALOG.md §2/§2a` owns the preserved n8n workflow build steps.

Next capability: **Foundation Completion Programme — Batch 6 Slice 33**, measured target `journal_entries` (Exposure 10, coverage 52; owns JE-5), ranked by `scripts/batch6_select_target.ps1`; Batch 6 runs until EC-1…EC-11 hold (`MASTER_EXECUTION_PLAN.md`), then the Phase-8 order in `32` resumes: bounded boundary revalidation → n8n workflow → Direct Call Quality Feedback Loop → PH8-10 evidence → Smart Bidding handoff when earned. **The control-plane optimization chapter is CLOSED** — reopening it requires newly earned evidence (a real incident, a false green or false red, a measured material cost, or a proven safety/governance gap), never a further search for theoretical optimizations. Standing facts: Ruleset 22950574 requires `orvion-acceptance` on the default branch with `non_fast_forward`, `deletion` and zero bypass; candidates are published by `scripts/publish_candidate.ps1`, which proves the committed range first and replaces a rejected preflight candidate only under a caller-pinned lease; `main` is promoted by pushing the exact accepted SHA. Migration CI was compared on one candidate by SPEC-203: it agreed exactly.

---

# Governance and Ownership

This document owns only the state above. Every other responsibility belongs elsewhere, by design, and is not restated here:

- Project identity, vision, and platform boundaries — `PROJECT_CONTEXT.md`.
- Engineering principles, execution rules, and workflow — `AGENTS.md` (with `GOVERNANCE.md` for knowledge governance and `CR_LIFECYCLE.md` for CR mechanics). `PROTOCOL.md` is retired to a pointer and owns nothing.
- Document discovery and reading order — `AGENTS.md §4` (the single, mandatory boot sequence); `README.md` is the one-hop router into it.
- Phase and module progress — `_ORVION_CANONICAL/32_execution_roadmap.md`, the single source of truth for that state.
- Per-capability history and rationale — the git log, `changes/*.md`, and `reports/`.

End of Document.
