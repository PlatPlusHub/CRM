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

Live state: **repository, local stack and Primary `vrvtsxexkiiiivlkdxzp` all at 205 migrations** (latest `202607061600`), ledger `f718a133a11b88b61fb791350fe0dfb2`, full-function-surface hash `8c012ce5ee5749923d94c0d54e6b867f` (277 functions, unchanged) and structural-surface hash `97c61119602a7353016bd4de6a1c7e80` (3,561 objects across ten surfaces — 3,563 less OTP-1's two revoked privileges) identical on both. All re-read live from BOTH environments 2026-09-07; **parity PROVEN, Primary values read FROM Primary** (GUARD-1). **77 tables**; 71/611 catalog; **8 reporting views**; **75 client RPCs**. Suite **106 files / 1662 assertions** (Pass A = Pass B) plus **430 end-to-end HTTP assertions** across six scripts, all re-run green this session.

Batch 6 surface coverage: **7 of 77 surfaces have a recorded audit disposition**, all seven at `ADVERSARIAL` (`MASTER_SURFACE_DISPOSITION.md`, Checks 22 and 24). Batch 6 is **NOT complete**; exit criteria EC-1…EC-11 and the adversarial method live in `MASTER_EXECUTION_PLAN.md`. The next slice is ranked by `scripts/batch6_select_target.ps1`, which stores nothing; **read its own caveat** — it subtracts test COVERAGE, and slices 4 and 5 both found High defects inside green ceilings. Primary holds **zero business rows**.

Active Change Request: None.

Open owner decisions — **MAIL-1**, **RET-1**, **AUDIT-2**, **PD-23**, **FA-2**, **MONEY-2**, **PAX-5**, **PAX-6**, **BOOK-8**, **BOOK-9**, **OTP-2**. IDs here are read as OPEN, so a decided one is removed rather than annotated; each one's exact question and evidence live in `MASTER_GAP_REGISTER.md` (Checks 11/14/25). **This line named only MAIL-1 until 2026-09-07**, when GOV-16's guard (**Check 25**) was written and measured seven registered decisions waiting behind it — a fresh session reads this line, not a 1,700-line register. **None blocks Batch 6, and in every case the shipped behaviour is the conservative reading.** MAIL-1 needs the **transactional email provider AND the Egyptian PDPC cross-border transfer licence naming its destination** (ORVION sends no mail; every alert already writes a `pending` `notification_deliveries` row). **RET-1's retention periods are counsel's, not an owner decision to make unaided** — the mechanism seeds ZERO policy rows, so nothing is destroyable while it waits.

Last Completed: **Batch 6 slice 6 — `otp_challenges` (2026-09-07).** It **disproved its own premise**: recorded as correctly unguarded *because pre-authentication*, but `anon` holds no grant and no policy there, and canon 34 § 7 makes OTP a **second factor at `aal1`** — intra-authentication, reachable by the actor it adjudicates. **OTP-1 (High, latent):** the subject could self-verify an expired challenge, zero its attempt counter, extend its expiry, redirect `sent_to_email`, forge a pre-verified row — all at `aal1`; repaired by REVOKE (`202607056100`'s mechanism), NOT a capability trigger. **Carry forward PAX-4:** 15 of its 20 "ungoverned" tables hold the check in an RLS policy — it counted enforcement sites of one kind and read it as governance; uncovered set **five, not twenty**. Opened **OTP-2**. Narrative: `session-2026-09-07-batch6-slice6-otp-challenges.md`.

Next capability: **the n8n notification-dispatch workflow, which P3 unblocked** — its contract is `app.claim_notification_deliveries` / `app.record_notification_delivery_result`, and it needs MAIL-1 answered first because it is the half that actually sends. Independent of that, and needing no owner input: **deploy `202607061600` to Primary** (one revoke), then **Batch 6 slice 7 — `trusted_devices`**: derived, not ranked. PAX-4's uncovered set is five; `otp_challenges` is closed, `totp_enrollments` waits on OTP-2, the other two are dispositioned. It is the only canon-34 table whose write grant is **load-bearing** (`app.record_trusted_device` is SECURITY INVOKER), so the question is BOOK-3's: does direct DML bypass what the RPC charges? Then **DELIV-1**, **GOV-20**, **CUST-6**, **DOC-LC-3**, **PH8-2**, then the RBAC-6 class. `MASTER_EXECUTION_PLAN.md` owns the order.

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
