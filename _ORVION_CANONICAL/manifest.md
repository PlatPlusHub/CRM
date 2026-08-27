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

Current Module: Phase-8 offline-conversion engine. ORVION-side pipeline implemented, deployed, verified live on Primary. Remaining: the n8n workflow itself — build and verify against the `MASTER_INTEGRATION_CATALOG.md §2` contract with the **eight** mandatory `§2a` corrections. The real-GCLID test stays on hold until genuine ad-click traffic exists.

Deployment topology (owner-ratified 2026-08-20, permanent): `PlatPlusHub/CRM` deploys to **Primary `vrvtsxexkiiiivlkdxzp` only**. Secondary `brplkqmbzffpxqgkkdzo` is the `Shehabhub/ORVION` environment and is never a CRM target; schema and migration-count differences between the two are expected and valid. Detail: `MASTER_INTEGRATION_CATALOG.md §0/§4`.

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 129 migrations** (latest `202607054000`), ledger fingerprint `ae51b6a100053db2105723ed328b4141` on all three; 72 tables; 69/588 catalog types/values; 71 permissions; 66 feature entitlements; reference data seeded; 121 `app` functions; 116 policies; **2 pg_cron jobs** (lead SLA, subscription lifecycle). **repo = local = Primary parity HOLDS, re-proven 2026-08-27.** Prove it with `scripts/check_database_parity.ps1` — never the repository guard, which reads files only. Primary holds **zero business rows**. n8n: **0 workflows** (live 2026-08-26), 2 credentials.

Active Change Request: None.

Open owner decisions: **SEC-1/RPC-1** (write-path model; identity half closed by SPEC-138, audit-spine half by WP-00; three further proven forgeries left unfixed because each IS the SEC-1 decision — `wp-00-event-write-path-integrity-2026-08-26.md §5`). Also open: PH8-2/PH8-3; **C4** (license activation credential — mechanism DECIDED on evidence, builds as SPEC-158); A3; AUDIT-4; **PLAN-1**. New: **BLOCKED-4** (does commission follow a booking-item reassignment, once reassignment exists?), **BLOCKED-5** (may the Platform Owner ever deliberately re-grant a trial?), **CANON-26-1** (canon admits `suspended` only from `read_only` — may an ACTIVE tenant be suspended in one step?). RESOLVED: BLOCKED-1/2 + C5 (SPEC-157), BLOCKED-3 (SPEC-155), AUDIT-2/3. Evidence in `MASTER_GAP_REGISTER.md`.

Last Completed: **SPEC-156 + SPEC-157 (2026-08-27, `202607053900`/`202607054000`), EARNED/CLOSED; closes BLOCKED-1, BLOCKED-2 and canon C5.** SPEC-156 removed the `p_commission_rate` parameter SPEC-155 had made inert. SPEC-157 made the subscription lifecycle real: **provisioning now creates a 30-day full-feature (Enterprise) trial** — it previously created NO subscription, and `subscription_allows_write` fails closed, so every new tenant was silently write-dead on all 42 gated tables; trial stamp on `tenants`, write-once; `ends_at`/`grace_ends_at` load-bearing in the gate AND advanced by a daily `pg_cron` job per canon 26; durations are a 5-value catalog with **lifetime = `ends_at is null`**, CHECK-enforced; subscription events got their **first producers**. Platform authority is `service_role`-only functions, NOT a tenant permission — `app.has_permission` is tenant-bound by construction, so `MANAGE_SUBSCRIPTION` stays held by no role, pinned by a test. Proven in `42_subscription_lifecycle_test.sql`. Detail: `subscription-licensing-platform-authority-alignment-2026-08-27.md`.

Next capability: **Foundation Hardening — Zero-Known-Debt (owner directive 2026-08-24). The n8n workflow stays GATED.** Suite 42 files / 455 assertions. Security posture, each proven by a named test: read scope, RBAC + finance write authority, plan gating, lifecycle/archive against direct DML, financial + document privacy, **audit-spine integrity (WP-00)**, **subscription lifecycle + platform-vs-tenant authority (SPEC-157)**. Remaining, in order:

1. **SPEC-158 — tenant license activation credential** (canon C4). Decided on evidence and **NOT TOTP**: a single-use, hashed, expiring activation token. Reasoning: `subscription-licensing-platform-authority-alignment-2026-08-27.md` §G-LICENSE.
2. **SPEC-159 — employee performance & earnings report.** Must route through `app.item_financials` (`authenticated` cannot SELECT `cost_amount`/`commission_rate` — proven), reusing the `reporting` security-invoker precedent; commission attributes to `sales_owner_user_id`.
3. Then: **WP-04 documents/storage** (zero buckets/policies; also WP-03's `documents` exemption and the missing `payment_proof` type); **notifications** (no producer — also owns subscription expiry warnings); **Employee/Supplier/Branch 360**; **72-table sweep**. Full backlog: `MASTER_EXECUTION_PLAN.md` Batch 6.

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
