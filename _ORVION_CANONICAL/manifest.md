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

This file holds ONLY current state. Detailed per-SPEC history is NOT restated here — it lives in the git log, `changes/*.md`, and `reports/`. Keeping this file lean keeps every session/`resume` cheap (it is re-read on every bootstrap), and the consistency guard enforces that mechanically on three axes: total lines, total characters, and per-line length.

---

# Current Development Status

Update this section continuously; keep it to current state only. `Last Completed` names only the single most recent capability — replace it each time, never chain a "Prior:" history (git log + `changes/` + `reports/` hold history). If any field starts becoming a changelog, trim it.

Current Phase: **Phase 8 (Offline Conversion) — IN PROGRESS**. Execution order 7→9→8→10 (`32`). Phases 2–7 + 9 COMPLETE. Supabase-native backend (ADR-0014); transport = Data Manager API + ECL via n8n outbox (ADR-0023).

Current Module: Phase-8 offline-conversion engine. The ORVION-side pipeline is implemented, deployed, and independently verified live on Primary. Remaining Phase-8 work is the n8n workflow itself: build and verify it against the `MASTER_INTEGRATION_CATALOG.md §2` contract, applying the **eight** mandatory `§2a` corrections. The real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; schema and migration-count differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: **repository and local stack at 112 migrations** (latest `202607052300`), ledger fingerprint `5cdd944b34ee6e869a30dd24aed6dce4`; 72 tables; 68/583 catalog types/values; 70 permissions; 66 feature entitlements; reference data seeded (82 countries / 82 nationalities / 20 languages / 18 currencies). **Primary `vrvtsxexkiiiivlkdxzp` is at 102 migrations and is 13 BEHIND — repo = local = Primary parity does NOT hold and cannot be verified: the `supabase-primary` MCP is disconnected, no project is linked, and no access token is present. Re-authorize interactively before any freeze claim.** n8n instance `plat.app.n8n.cloud`: 0 workflows, 0 executions, 2 credentials (existence only; targets and scopes unverified).

Active Change Request: None.

Open owner decisions: **SEC-1/RPC-1** (write-path model — `authenticated` still holds direct DML on CRM tables; the identity/organization half was closed by SPEC-138); PH8-2/PH8-3 (consent surface, E.164 policy); C4/C5 (subscription activation-code, grace); A3 (money-storage ADR); AUDIT-4 (customer-level consent); **PLAN-1** (the three features canon marks "Limited" with no ceiling; where the plan gate sits). AUDIT-2 and AUDIT-3 are RESOLVED. Evidence in `MASTER_GAP_REGISTER.md`.

Last Completed: **SPEC-144 — document read scope (2026-08-24)**, completing SPEC-137, which named documents in its plan and never implemented them. All three document tables were still tenant-only while every record they attach to was branch-scoped, so any employee could read any passport scan in the company; `document_versions.storage_path` is the field that retrieves the file, and `is_confidential` was decorative. Found by auditing permission coverage, not by re-reading the migration. Detail: `changes/SPEC-144-document-read-scope.md`.

Next capability: **Final Foundation Hardening & Zero-Debt Gate (owner directive 2026-08-24, second directive). The n8n workflow stays GATED.** Eight CRs landed in the first programme — SPEC-137 (read scope), SPEC-138 (RBAC write authority), SPEC-139 (financial privacy), SPEC-140 (assignment history + `reassign_lead`), SPEC-141 (CAT-5/CAT-6 + plan matrix), SPEC-142 (duplicate prevention), SPEC-143 (event visibility + 360 timelines), SPEC-144 (document scope). SPEC-145 (financial write authority) SPEC-146 (plan gating) SPEC-147 (resolution-path indexes) and SPEC-148 (access-revocation coverage) landed in the second. Suite 31 files / 276 tests; **65 of 70 permissions enforced at a real check point** (2 more have no tenant-writable surface to guard; 3 gate surfaces that do not exist yet — the API tiers and advanced dashboards — and are plan-mapped so they deny correctly the moment a consumer appears); 115 migrations. The scope model has now been measured at realistic volume (PERF-1). Remaining, in order:
1. **Remaining governed writes** — booking-item costing (`ENTER_COST`/`ENTER_SELLING_PRICE`/`EDIT_LOCKED_COST`), exchange rates, approval review, platform admin, the API scope pair, the `task_overdue` sweep. `reassign_lead` is DONE (SPEC-140).
3. **Table-by-table and column-by-column audit**, catalog/dropdown completeness, Customer/Lead/Employee/Branch 360 proof, performance sanity at realistic volume.
4. **Primary deployment and verification** — blocked on re-authorization; nothing else closes the freeze without it.
Evidence and open items are in `MASTER_GAP_REGISTER.md`. The workflow build steps remain preserved and unchanged in `MASTER_INTEGRATION_CATALOG.md §2/§2a`.

Also open and autonomous: the Phase-10 Meta-ecosystem Learn-Before-Designing research + communications-domain Design Challenge.

Prior phases (summary; full history in git log + `changes/` + `reports/`): Phase 2 (Database Foundation) COMPLETE; Phase 3 (Identity & Access) COMPLETE; Phase 4 (CRM Core) COMPLETE at SPEC-072; Phase 5 (Booking Core) COMPLETE through SPEC-083; Phase 9 (Reports, Tier A) COMPLETE.

---

# Governance and Ownership

This document owns only the state above. Every other responsibility belongs elsewhere, by design, and is not restated here:

- Project identity, vision, and platform boundaries — `PROJECT_CONTEXT.md`.
- Engineering principles, execution rules, and workflow — `AGENTS.md` (with `GOVERNANCE.md` for knowledge governance and `CR_LIFECYCLE.md` for CR mechanics). `PROTOCOL.md` is retired to a pointer and owns nothing.
- Document discovery and reading order — `AGENTS.md §4` (the single, mandatory boot sequence); `README.md` is the one-hop router into it.
- Phase and module progress — `_ORVION_CANONICAL/32_execution_roadmap.md`, the single source of truth for that state.
- Per-capability history and rationale — the git log, `changes/*.md`, and `reports/`.

End of Document.
