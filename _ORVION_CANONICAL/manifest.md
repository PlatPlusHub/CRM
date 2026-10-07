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

Current Module: Phase-8 offline-conversion / Foundation Completion Programme Batch 6. SPEC-242 completed the repository-only segmented-publication and full-range certification repair. The n8n workflow remains governed by `MASTER_INTEGRATION_CATALOG.md §2/§2a`; the real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: Last fully verified 2026-10-07. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 240 migrations** (latest `20261007120000`), ledger `5907e3b5a170d153797aff8cb08ca20e`, full-function-surface hash `e6bb8dd300da86442ff8bcd942912d94` (320 functions) identical on both; structural-surface hash `f8062e9459f894e1f4e0a5b8ef0b0efc` (3,114 objects) identical on both — **all ten surfaces identical** (`PAR-5` resolved by `SPEC-207`). Re-read live from Primary 2026-10-07; ledger **read FROM Primary** (GUARD-1). **78 tables**; 71/622 catalog; **8 reporting views**; **80 client RPCs**. Suite **143 files / 2615 assertions** (Pass A = Pass B) plus **451 end-to-end HTTP assertions** across six scripts, last passed 2026-10-07.

Batch 6 surface coverage: **31 of 78 surfaces have a recorded audit disposition**, all thirty-one at `ADVERSARIAL` (`MASTER_SURFACE_DISPOSITION.md`, Checks 22 and 24). Batch 6 is **NOT complete**; exit criteria EC-1…EC-11 and the adversarial method live in `MASTER_EXECUTION_PLAN.md`. The next slice is ranked by `scripts/batch6_select_target.ps1`, which stores nothing. **Its ranking was INVERTED until 2026-09-08 and is now EXPOSURE-ordered**; `Score` is a diagnostic, not the sort key. Primary bookings, booking_items, passengers and booking_item_passengers tables had zero rows at SPEC-224 deployment precheck (2026-09-26).

Active Change Request: changes/SPEC-243-a-conversion-is-sent-only-on-google-success.md

Open owner decisions — **MAIL-1**, **RET-1**, **PH8-10**. These are exact external prerequisites, not unresolved architecture: MAIL-1 has technically selected Resend but production activation still requires owner authorization and counsel/PDPC confirmation for the actual cross-border destination; RET-1's retention/closure architecture and legal-hold override are implemented, while counsel must supply the actual per-type periods as tenant configuration; PH8-10 awaits Google evidence that click-less phone conversions are credited. No email is sent and no retention policy is seeded while those prerequisites remain. The other eight decisions in the 2026-09-09 closure are resolved and removed from this OPEN line; evidence lives in `MASTER_GAP_REGISTER.md`.

Last Completed: **SPEC-242 completed the repository-only segmented-publication and full-range certification repair (2026-10-01).**

Narrative: `agent-control-plane-corrective-repair-2026-09-11.md` — the latest *session report* (Check 10 pairs this with `reports/README.md`). `SPEC-160` deliberately wrote none: its contract, tests and Git own the evidence.

Current session blocker: **None.**

Other open work is owned elsewhere and is never restated as the next action: `MASTER_EXECUTION_PLAN.md` owns Batch 6 order, the Phase-10 Meta-ecosystem Learn-Before-Designing research and the communications-domain Design Challenge; `MASTER_INTEGRATION_CATALOG.md §2/§2a` owns the preserved n8n workflow build steps.

Next capability: **Phase-8 Activation Closure** — close, disprove or owner-gate every condition in `MASTER_INTEGRATION_CATALOG.md §2b`, one contract at a time; **Batch 6 Slice 31 is paused until it closes**, then ranked by `scripts/batch6_select_target.ps1`. **The control-plane optimization chapter is CLOSED** — reopening it requires newly earned evidence (a real incident, a false green or false red, a measured material cost, or a proven safety/governance gap), never a further search for theoretical optimizations. Standing facts: Ruleset 22950574 requires `orvion-acceptance` on the default branch with `non_fast_forward`, `deletion` and zero bypass; candidates are published by `scripts/publish_candidate.ps1`, which proves the committed range first and replaces a rejected preflight candidate only under a caller-pinned lease; `main` is promoted by pushing the exact accepted SHA. Migration CI was compared on one candidate by SPEC-203: it agreed exactly.

---

# Governance and Ownership

This document owns only the state above. Every other responsibility belongs elsewhere, by design, and is not restated here:

- Project identity, vision, and platform boundaries — `PROJECT_CONTEXT.md`.
- Engineering principles, execution rules, and workflow — `AGENTS.md` (with `GOVERNANCE.md` for knowledge governance and `CR_LIFECYCLE.md` for CR mechanics). `PROTOCOL.md` is retired to a pointer and owns nothing.
- Document discovery and reading order — `AGENTS.md §4` (the single, mandatory boot sequence); `README.md` is the one-hop router into it.
- Phase and module progress — `_ORVION_CANONICAL/32_execution_roadmap.md`, the single source of truth for that state.
- Per-capability history and rationale — the git log, `changes/*.md`, and `reports/`.

End of Document.
