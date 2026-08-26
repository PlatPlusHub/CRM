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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 121 migrations** (latest `202607053200`), ledger fingerprint `4824852c1aec4d259815617ba3f049e7` on all three; 72 tables; 68/583 catalog types/values; 71 permissions; 66 feature entitlements; reference data seeded (82 countries / 82 nationalities / 20 languages / 18 currencies); 106 `app` functions; 116 policies. **repo = local = Primary parity HOLDS, re-proven 2026-08-26.** Prove it with `scripts/check_database_parity.ps1` — never from the repository guard, which reads files only and now says so. Primary holds **zero business rows**. n8n: **0 workflows** (live 2026-08-26), 2 credentials.

Active Change Request: None.

Open owner decisions: **SEC-1/RPC-1** (write-path model; identity half closed by SPEC-138, audit-spine half by WP-00). **New SEC-1 evidence 2026-08-26** — three more forgeries of authoritative history proven, left unfixed because each IS the SEC-1 decision: backdated `lead_assignments`, `customers.first_registered_user_id` attribution theft, `offline_conversions` snapshot mutation (`wp-00-event-write-path-integrity-2026-08-26.md §5`). Also open: PH8-2/PH8-3; C4/C5; A3; AUDIT-4; **PLAN-1**. AUDIT-2/AUDIT-3 RESOLVED. Evidence in `MASTER_GAP_REGISTER.md`.

Last Completed: **WP-03 / SPEC-152 — subscription state enforcement (2026-08-26, `202607053100`+`202607053200`), EARNED/CLOSED.** `app.plan_allows` inverted the owner's rule at both ends. State moved into `app.enforce_subscription_write_gate`, a BEFORE INSERT/UPDATE/DELETE trigger on **42** tables — not `has_permission`, which 32 of 89 write policies never call. Reads survive every restricted state; no subscription fails CLOSED for writes; 15 exemptions keep reactivation and provisioning open. Proven in `35_subscription_write_gate_test.sql`. Detail: `wp-03-subscription-state-enforcement-2026-08-26.md`.

Next capability: **Foundation Hardening — Zero-Known-Debt (owner directive 2026-08-24). The n8n workflow stays GATED.** Suite 36 files / 341 assertions; 121 migrations; 71 permissions. Security posture (each proven by a named test): branch/department/assigned read scope, RBAC + finance write authority, plan gating, lifecycle + archive enforced against direct DML, employee financial privacy, document privacy, **audit-spine write integrity (WP-00)**. Remaining, in order:

1. **Post-WP-03 discovery — DONE 2026-08-26 (`202607053200`)**, found **two cross-tenant abort defects**: `process_lead_sla` and `map_outcomes_to_conversions` hit the raising gate on other tenants' behalf, so one lapsed tenant aborted the shared run and stalled the n8n cursor. Fixed, guarded by `36_subscription_gate_system_paths_test.sql`. Detail: `wp-03-post-package-discovery-2026-08-26.md`. Next: **WP-01 — creation events** (`customer_created`, `lead_created`, `passenger_created`, `trusted_device_created` — re-introspect before trusting the list).
2. Then, each verified open 2026-08-26: **WP-02** (six `*_created` types with no producer, plus the missing `payment_proof` document type and `subscription_created`'s producer); **table/column sweep** (72 tables); **Employee/Supplier/Branch 360** primitives; **documents** (zero storage buckets/policies — `upload_document` points at storage that does not exist; must also revisit WP-03's broad `documents` exemption); **notifications** (no producer); **employee role is intake-only** (13 perms, no `CREATE_QUOTATION`/`CREATE_BOOKING`/`CONVERT_LEAD`).

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
