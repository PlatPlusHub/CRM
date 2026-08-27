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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 130 migrations** (latest `202607054100`), ledger fingerprint `538237ee27a3aa6a41da26f6ac146b3f` on all three; 73 tables; 69/591 catalog types/values; 71 permissions; 66 feature entitlements; reference data seeded; 124 `app` functions; 117 policies; **2 pg_cron jobs** (lead SLA, subscription lifecycle). **repo = local = Primary parity HOLDS, re-proven 2026-08-27.** Prove it with `scripts/check_database_parity.ps1` — never the repository guard, which reads files only. Primary holds **zero business rows**. n8n: **0 workflows** (live 2026-08-26), 2 credentials.

Active Change Request: None.

Open owner decisions: **SEC-1/RPC-1** (write-path model; identity half closed by SPEC-138, audit-spine half by WP-00; three further proven forgeries left unfixed because each IS the SEC-1 decision — `wp-00-event-write-path-integrity-2026-08-26.md §5`). Also open: PH8-2/PH8-3; A3; AUDIT-4; **PLAN-1**. **LIC-1** (known limitation, not a decision): a REFUSED license redemption is not audited — `raise` rolls back its own audit row and PostgreSQL has no autonomous transaction; stated in code and pinned by a test rather than faked. BLOCKED BY EXTERNAL DEPENDENCY (out-of-transaction audit hop). New: **BLOCKED-4** (does commission follow a booking-item reassignment, once reassignment exists?), **BLOCKED-5** (may the Platform Owner ever deliberately re-grant a trial?), **CANON-26-1** (canon admits `suspended` only from `read_only` — may an ACTIVE tenant be suspended in one step?). RESOLVED: BLOCKED-1/2 + C5 (SPEC-157), **C4 (SPEC-158)**, BLOCKED-3 (SPEC-155), AUDIT-2/3. Evidence in `MASTER_GAP_REGISTER.md`.

Last Completed: **SPEC-158 — tenant license activation credential (2026-08-27, `202607054100`), EARNED/CLOSED; closes canon C4**, open since 2026-07-15. Decided on evidence as a single-use, hashed, expiring token and deliberately **NOT TOTP**: `totp_enrollments` stores no secret by design and canon 34/ADR-0017 keep every factor in Supabase Auth, so a per-tenant seed would be the first auth secret ORVION ever stored — and TOTP repeats where this must be single-use. Plaintext returned once and never persisted; replay closed by consumption; rotation is re-issuance; `public.security_events` gained its first producers. Proven in `43_license_activation_test.sql`. Same session, also EARNED/CLOSED: **SPEC-156** (`202607053900`) and **SPEC-157** (`202607054000`) — see the plan and report. Detail: `subscription-licensing-platform-authority-alignment-2026-08-27.md`.

Next capability: **Foundation Hardening — Zero-Known-Debt (owner directive 2026-08-24). The n8n workflow stays GATED.** Suite 43 files / 474 assertions. Security posture, each proven by a named test: read scope, RBAC + finance write authority, plan gating, lifecycle/archive against direct DML, financial + document privacy, **audit-spine integrity (WP-00)**, **subscription lifecycle + platform-vs-tenant authority (SPEC-157)**. Remaining, in order:

1. **SPEC-159 — employee performance & earnings report.** Must route through `app.item_financials` (`authenticated` cannot SELECT `cost_amount`/`commission_rate` — proven), reusing the `reporting` security-invoker precedent; commission attributes to `sales_owner_user_id`.
2. Then: **WP-04 documents/storage** (zero buckets/policies; also WP-03's `documents` exemption and the missing `payment_proof` type); **notifications** (no producer — also owns subscription expiry warnings); **Employee/Supplier/Branch 360**; **72-table sweep**. Full backlog: `MASTER_EXECUTION_PLAN.md` Batch 6.

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
