# Change Request — SPEC-120

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Fix two live regressions found by the 2026-08-10 repository audit (`app.merge_customer_identity` and `app.advance_refund` emitting unregistered `event_type` codes), seed the previously-missing `subscription_plans` reference rows, and add a permanent pgTAP guard against this class of event-vocabulary/catalog drift.

---

## Business Reason

A full-repository audit (treating `supabase/migrations/**` as ground truth, not the manifest) proved by live execution that two capabilities marked "Complete" (Phase 4 customer merge, Phase 6 refund lifecycle) were non-functional: `202607049100` hardened `app.record_event` to reject unregistered `event_type_code` values, but two RPCs written before that hardening emitted codes that were never registered, so every call aborted. Left unfixed, the owner-approved capabilities silently do not work. The audit also found `subscription_plans` was never seeded by any migration despite `17_saas_plan_matrix.md` naming the plans unambiguously, and that no automated check would have caught either gap before it reached this point (Discovery-to-guard, `AGENTS.md §1`/`GOVERNANCE.md §18`).

---

## Risks

Low, all additive or narrowly-scoped fixes: `app.merge_customer_identity` and `app.advance_refund` keep their exact signatures (`CREATE OR REPLACE` preserves existing grants); the new catalog rows and `subscription_plans` rows are pure inserts guarded by `on conflict ... do nothing`; the new pgTAP test is read-only introspection wrapped in `begin/rollback`. No canon business rule, RLS policy, or existing event's severity/meaning was changed except the two corrected literals themselves.

---

## Supersedes / Depends On

None. Depends on the repository state as of commit `32ddc89` (the audited baseline) being unchanged, which was verified (`git status`/`git log` clean) before any fix was written.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607049700_fix_customer_identity_merge_event.sql`
- `supabase/migrations/202607049800_register_refund_lifecycle_events.sql`
- `supabase/migrations/202607049900_seed_subscription_plans.sql`
- `supabase/tests/07_event_vocabulary_registry_test.sql`
- `scripts/verify_database.sql`
- `_ORVION_CANONICAL/27_event_catalog.md`
- `_ORVION_CANONICAL/manifest.md`
- `reports/future-backlog.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_CERTIFICATION_STATUS.md`
- `changes/SPEC-120-audit-remediation-event-vocabulary.md`
- `ai-map.json`, `repository-index.md` (regenerated only, via their owning scripts)

---

## Out of Scope — Files Forbidden to Modify

- any other `supabase/migrations/**` (terminal migrations never edited)
- any `reports/history/**` (immutable)
- `AGENTS.md`, `README.md`, `GOVERNANCE.md`, `CR_LIFECYCLE.md`, `_ORVION_CANONICAL/32_execution_roadmap.md` — no phase/roadmap change; this is a same-phase correctness fix
- `feature_entitlements` seed data — genuinely ambiguous per canon (see Notes); reported, not implemented

---

## Minimum Reading List

- `reports/master/MASTER_GAP_REGISTER.md`, `MASTER_CERTIFICATION_STATUS.md`
- `_ORVION_CANONICAL/25_catalog_registry.md`, `27_event_catalog.md`, `17_saas_plan_matrix.md`
- `supabase/migrations/202607044900_merge_customer_identity.sql`, `202607047600_advance_refund.sql`, `202607049100_event_type_registry_enforcement.sql`

---

## Implementation Steps

1. Determine canonical resolution for `customer_merged`: canon `27_event_catalog.md` already registers `customer_identity_merged` (Severity: critical) for exactly this merge event. Correct the RPC to emit canon's name, not the catalog. Verification: `202607049700` recreates `app.merge_customer_identity` with the same signature, emitting `customer_identity_merged`/`critical`.
2. Determine canonical resolution for the four unregistered refund codes: `refund_status_code` (canon 25, seeded verbatim) already defines all six states the RPC transitions between, and `202607047600`'s own header already documented "Emits refund_approved/rejected/processing/completed/cancelled" — the RPC and its states are canonical; only the event-catalog registration was incomplete. Complete canon `27` (insert `refund_approved`/`refund_rejected`/`refund_cancelled`/`refund_processing`, Severity: info, matching what the RPC has always emitted) and seed the catalog (`202607049800`). The RPC itself is unchanged.
3. Seed `subscription_plans` (`202607049900`) from `17_saas_plan_matrix.md`'s three named plans (Starter/Professional/Enterprise) and their one-line descriptions, verbatim. Do NOT seed `feature_entitlements` — see Notes for the specific ambiguity.
4. Add `supabase/tests/07_event_vocabulary_registry_test.sql`: a pgTAP guard that introspects every `app.*` function's `pg_get_functiondef()` for (a) literals passed directly to `record_event(...)` and (b) literals resolved through a `values (...) as t(..., ev|evt, ...)` transition-mapping table (column-alias-aware, not position-hardcoded), and asserts every literal found has a matching `event_type` catalog row.
5. Update `scripts/verify_database.sql` CHECK 6b: catalog_values count 565 → 569 (+4 refund events), matching the now-larger, correct catalog.
6. Verify: clean `npx supabase db reset` (88 migrations); full pgTAP suite (7 files, 9 assertions) green; smoke test green; both RPCs re-tested live end-to-end with real fixture data (tenant/customers/refunds) — merge + all 8 refund transitions execute and emit the correct event/severity; guard mutation-tested (reintroducing the old `customer_merged` literal inside a rolled-back transaction reliably fails it).

---

## Acceptance Criteria

- [x] `app.merge_customer_identity` emits `customer_identity_merged`/`critical`, matching canon 27.
- [x] `app.advance_refund` succeeds on all 8 canonical transitions (previously 6 aborted).
- [x] `refund_approved`/`refund_rejected`/`refund_cancelled`/`refund_processing` registered in canon 27 and seeded (catalog_values: 565 → 569, verified live).
- [x] `subscription_plans` seeded with the 3 canon-17 plans; `feature_entitlements` deliberately not seeded (ambiguity reported below, not guessed).
- [x] New pgTAP test 07 passes on the fixed code and is proven (mutation-tested) to fail if the same class of defect recurs.
- [x] Clean `db reset` (88 migrations) succeeds; smoke test passes with the corrected count; all 9 pgTAP assertions (existing 6 + new 3-in-1) pass.
- [x] No RLS, search_path, grant, or FK invariant regressed (full pgTAP suite + smoke test re-verified after the fix).

---

## Execution Log

### 2026-08-10 — Claude (Sonnet 5)

Outcome: Complete

Step results:
- Step 1: Applied — `202607049700_fix_customer_identity_merge_event.sql`.
- Step 2: Applied — canon `27` updated; `202607049800_register_refund_lifecycle_events.sql`.
- Step 3: Applied — `202607049900_seed_subscription_plans.sql`. `feature_entitlements` explicitly deferred (see Notes) — this is a partial-scope decision, not an oversight.
- Step 4: Applied — `supabase/tests/07_event_vocabulary_registry_test.sql`. First version had a regex bug (the outer pattern consumed each mapping table's first tuple's opening paren, silently dropping the first transition's literal from the scan — caught by manually inspecting the scan's intermediate results rather than trusting a green "0 unregistered" result at face value). Corrected and re-verified: scan recovers all previously-missing literals (confirmed `refund_approved` and others now present), zero false positives on non-event status literals (`sent`/`draft`/`approved`/etc. spot-checked), and mutation-tested — reintroducing the old `customer_merged` literal inside a rolled-back transaction makes the guard fail as expected.
- Step 5: Applied — `scripts/verify_database.sql` CHECK 6b + comment + final notice updated to 569.
- Step 6: Verified — clean `db reset` (88 migrations, no errors); smoke test `ALL CHECKS PASSED (72 tables, ..., 67/569 catalog, ...)`; all 7 pgTAP files / 9 `ok` assertions green; both RPCs re-tested live via a real tenant/customer/refund fixture (rolled back after, no residual data) — merge emits `customer_identity_merged`/`critical`; all 8 refund transitions (`requested→approved→processing→completed`, `requested→rejected`, `requested→cancelled`, `requested→approved→cancelled`, `requested→approved→processing→cancelled`) succeed.

Commits: (see push for this run)

---

## Verification Notes

### 2026-08-10 — Claude (Sonnet 5)

Verdict: Confirmed Complete

Findings: Independently re-ran smoke test + full pgTAP suite against the same reset database after all fixes landed — all green. Re-confirmed live via direct SQL that `catalog_values` = 569, `customer_identity_merged`/`refund_approved`/`refund_rejected`/`refund_cancelled`/`refund_processing` all exist as seeded `event_type` rows, and `subscription_plans` has exactly 3 rows (`starter`/`professional`/`enterprise`). No file outside Scope was modified. `feature_entitlements` was deliberately left unseeded; reported to the owner as a decision point, not silently implemented or silently skipped without record.

Recommendation to human: Set Status to Complete. A follow-up decision is needed on `feature_entitlements` (see Notes) before that table can be seeded.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] No section was added, removed, or restructured outside the approved steps.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] The regex bug in the first draft of the guard was caught and corrected before being reported as done, not guessed past (Test-Before-Trust).
- [x] Supersedes / Depends On: None.
- [x] The repository is in a clean, releasable state.

---

## Notes

**`feature_entitlements` — reported ambiguity, not implemented (owner decision needed).** `17_saas_plan_matrix.md` gives a numeric limits table (Users/Branches/Monthly Leads/Monthly Bookings/Storage/Automations) and prose Included/Excluded feature lists per plan, and `25_catalog_registry.md` separately defines a concrete 15-value `feature_code` vocabulary (`crm`, `booking`, `documents`, `suppliers`, `finance_lite`, `full_finance`, `basic_reporting`, `advanced_dashboards`, `api_read_only`, `api_full`, `automation`, `integrations`, `offline_conversion`, `ai_dashboard`, `multi_branch` — itself never seeded as `catalog_values`, by design: `202607043100`'s own header excludes `feature_code` as "seeded elsewhere," i.e. directly as `feature_entitlements` rows, the same pattern as `role_code`/`permission_key`). Concrete, unresolved gaps before any row could be safely inserted:
1. Canon's six numeric limits (Users/Branches/Monthly Leads/Monthly Bookings/Storage/Automations) have no target column — `feature_entitlements.feature_code` only carries the 15 boolean-style codes above, none of which are `users`/`branches`/etc. (those live in the separate, already-seeded `usage_metric_code` catalog, consumed by the per-tenant `usage_counters` table, not by any static per-plan template table). There is no schema field today that stores "Professional plan's Monthly Leads cap = 10,000."
2. "Unlimited" (Enterprise, most metrics) and "Custom" (Enterprise storage) are not numeric; `feature_entitlements.limit_value`/`usage_counters.limit_value` are both `numeric`. No convention (checked `30_database_conventions.md`) defines a NULL-means-unlimited or sentinel-value rule.
3. "Enterprise includes all approved features" is not an enumerated list — some Professional-tier features (`documents`, `suppliers`, `basic_reporting`) are not explicitly re-listed under Enterprise, and canon-17 itself flags `ai_dashboard` as conditional ("where approved"). Whether Enterprise is a literal superset of Professional, and what "where approved" resolves to, cannot be derived from canon alone.
4. `offline_conversion` (a seeded `feature_code` candidate value) has zero mention in any plan's Included/Excluded list in canon-17.

None of these are answerable from repository evidence without inventing business policy, which was explicitly out of scope for this task. **Concrete decision needed from the owner:** (a) where do the six numeric per-plan limits get stored (new column/table, or repurpose `feature_entitlements.limit_value` against a different code set); (b) how is "Unlimited"/"Custom" encoded; (c) is Enterprise a literal superset of Professional plus its explicit additions, or does each plan need its full feature list restated; (d) which plan(s) get `offline_conversion` and how `ai_dashboard`'s "where approved" resolves. Logged in `reports/future-backlog.md` with this trigger.
