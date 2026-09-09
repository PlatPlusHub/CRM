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

Live state: Last fully verified 2026-09-09. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 218 migrations** (latest `20260909180403`), ledger `70ba44e108ff9936f5d5f1bf8e27e349`, full-function-surface hash `32d4b5546e0914afb5a451a42f02a4e6` (296 functions) and structural-surface hash `31ea232c2c2f57d232632193688615d1` (3,620 objects across ten surfaces) identical on both, all ten matching. Re-read live from Primary 2026-09-09; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). **77 tables**; 71/618 catalog; **8 reporting views**; **79 client RPCs**. Suite **117 files / 1915 assertions** (Pass A = Pass B) plus **449 end-to-end HTTP assertions** across six scripts, last passed 2026-09-09.

Batch 6 surface coverage: **12 of 77 surfaces have a recorded audit disposition**, all twelve at `ADVERSARIAL` (`MASTER_SURFACE_DISPOSITION.md`, Checks 22 and 24). Batch 6 is **NOT complete**; exit criteria EC-1…EC-11 and the adversarial method live in `MASTER_EXECUTION_PLAN.md`. The next slice is ranked by `scripts/batch6_select_target.ps1`, which stores nothing. **Its ranking was INVERTED until 2026-09-08 and is now EXPOSURE-ordered**; `Score` is a diagnostic, not the sort key. Primary last recorded **zero business rows** (2026-09-08; not re-read this session).

Active Change Request: None.

Open owner decisions — **MAIL-1**, **RET-1**. These are exact external prerequisites, not unresolved architecture: MAIL-1 has technically selected Resend but production activation still requires owner authorization and counsel/PDPC confirmation for the actual cross-border destination; RET-1's retention/closure architecture and legal-hold override are implemented, while counsel must supply the actual per-type periods as tenant configuration. No email is sent and no retention policy is seeded while those prerequisites remain. The other eight decisions in the 2026-09-09 closure are resolved and removed from this OPEN line; evidence lives in `MASTER_GAP_REGISTER.md`.

Last Completed: **Ten-decision closure, CLOSED (2026-09-09).** Eight decisions are implemented or resolved by measurement; MAIL-1 and RET-1 retain only explicit external activation/configuration prerequisites. Batch 6 remains exactly 12/77 and slice 12 was not started; evidence: `session-2026-09-09-ten-decision-closure.md`.

Narrative: `session-2026-09-09-ten-decision-closure.md`

Current session blocker: **None.** The 2026-09-09 Windows/Docker port blocker is RESOLVED -- local rebuilt from repository migrations and parity re-proven against live Primary reads at 211 migrations.

Next capability: **Decision-closure complete. Start Batch 6 Slice 12 on quotations in a NEW session.** Slice 12 was not started here; Batch 6 remains 12/77. `MASTER_EXECUTION_PLAN.md` owns subsequent programme order.

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
