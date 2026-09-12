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

Current Module: Phase-8 offline-conversion / Foundation Completion Programme Batch 6. The Agent Control Plane is closed: the contract partition is mechanically enforced against the Git baseline, the manifest pointer and contract Status are one invariant checked both ways, engineering method lives in `ENGINEERING_METHOD.md` so routine execution no longer reads it, and the evidence chain is now as deterministic as the write-authority chain. The n8n workflow remains governed by `MASTER_INTEGRATION_CATALOG.md §2/§2a`; the real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: Last fully verified 2026-09-09. **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 218 migrations** (latest `20260909180403`), ledger `70ba44e108ff9936f5d5f1bf8e27e349`, full-function-surface hash `32d4b5546e0914afb5a451a42f02a4e6` (296 functions) and structural-surface hash `31ea232c2c2f57d232632193688615d1` (3,620 objects across ten surfaces) identical on both, all ten matching. Re-read live from Primary 2026-09-09; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). **77 tables**; 71/618 catalog; **8 reporting views**; **79 client RPCs**. Suite **117 files / 1915 assertions** (Pass A = Pass B) plus **449 end-to-end HTTP assertions** across six scripts, last passed 2026-09-09.

Batch 6 surface coverage: **12 of 77 surfaces have a recorded audit disposition**, all twelve at `ADVERSARIAL` (`MASTER_SURFACE_DISPOSITION.md`, Checks 22 and 24). Batch 6 is **NOT complete**; exit criteria EC-1…EC-11 and the adversarial method live in `MASTER_EXECUTION_PLAN.md`. The next slice is ranked by `scripts/batch6_select_target.ps1`, which stores nothing. **Its ranking was INVERTED until 2026-09-08 and is now EXPOSURE-ordered**; `Score` is a diagnostic, not the sort key. Primary last recorded **zero business rows** (2026-09-08; not re-read this session).

Active Change Request: `changes/SPEC-171-a-cancellation-is-not-a-governing-act.md`

Open owner decisions — **MAIL-1**, **RET-1**. These are exact external prerequisites, not unresolved architecture: MAIL-1 has technically selected Resend but production activation still requires owner authorization and counsel/PDPC confirmation for the actual cross-border destination; RET-1's retention/closure architecture and legal-hold override are implemented, while counsel must supply the actual per-type periods as tenant configuration. No email is sent and no retention policy is seeded while those prerequisites remain. The other eight decisions in the 2026-09-09 closure are resolved and removed from this OPEN line; evidence lives in `MASTER_GAP_REGISTER.md`.

Last Completed: **SPEC-170 cancellation is executable, Complete (2026-09-12).** `Cancelled` was a legal state the Gate could never commit: closing forces the manifest pointer to be cleared, leaving no governing contract, dropping control to the PLAN arm, which rejects the files a closure must write. A contract approved on a false premise had no legal exit. `$script:TerminalStatuses` is now the single list of closed states and the committed path is judged against the contract's own final status, so `Complete` keeps the stricter rule. No new error code. `SPEC-169` cancelled with it, its refuted premise preserved. Suite 132 → 137 assertions.

Narrative: `agent-control-plane-corrective-repair-2026-09-11.md` — the latest *session report* (Check 10 pairs this with `reports/README.md`). `SPEC-160` deliberately wrote none: its contract, tests and Git own the evidence.

Current session blocker: **None.**

Other open work is owned elsewhere and is never restated as the next action: `MASTER_EXECUTION_PLAN.md` owns Batch 6 order, the Phase-10 Meta-ecosystem Learn-Before-Designing research and the communications-domain Design Challenge; `MASTER_INTEGRATION_CATALOG.md §2/§2a` owns the preserved n8n workflow build steps.

Next capability: **Simple Acceptance — corrective CR for the two proven Phase C blockers.** (1) acceptance cleanup ran `npx supabase stop` without `npm ci` and silently installed `supabase@2.117.0` against a lockfile pinning `2.109.0`, reporting success; (2) `orvion-acceptance` runs none of the four guard-calibration suites `Repository Consistency` runs, so the intended single required check is weaker than what it replaces. Also make branch assertions 122–124 non-vacuous. **Phase C forbidden until an exact-SHA shadow success path is proven.** Batch 6 Slice 12 resumes after.

---

# Governance and Ownership

This document owns only the state above. Every other responsibility belongs elsewhere, by design, and is not restated here:

- Project identity, vision, and platform boundaries — `PROJECT_CONTEXT.md`.
- Engineering principles, execution rules, and workflow — `AGENTS.md` (with `GOVERNANCE.md` for knowledge governance and `CR_LIFECYCLE.md` for CR mechanics). `PROTOCOL.md` is retired to a pointer and owns nothing.
- Document discovery and reading order — `AGENTS.md §4` (the single, mandatory boot sequence); `README.md` is the one-hop router into it.
- Phase and module progress — `_ORVION_CANONICAL/32_execution_roadmap.md`, the single source of truth for that state.
- Per-capability history and rationale — the git log, `changes/*.md`, and `reports/`.

End of Document.
