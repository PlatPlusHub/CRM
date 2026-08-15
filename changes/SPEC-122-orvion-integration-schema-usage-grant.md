# Change Request — SPEC-122

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

---

## Objective

Grant `orvion_integration` `USAGE` on schema `app` and add a permanent guard so a role holding a function-level `EXECUTE` grant without the prerequisite schema `USAGE` is caught at `db reset` time, not at first live call.

---

## Business Reason

An internal Phase-8 pipeline validation session (2026-08-15, local dev database, fully rolled back) found that `orvion_integration` — the role Phase-8's n8n workflow will use in production — has `EXECUTE` grants on all 4 of its RPCs (`app.map_outcomes_to_conversions`, `app.capture_attribution_click`, `app.claim_conversion_deliveries`, `app.record_conversion_delivery_result`, all granted by migration `202607049200`/`049300`/`049400`) but was never granted `USAGE` on the `app` schema itself. Schema `USAGE` is a prerequisite Postgres privilege independent of function-level grants; without it none of the existing `EXECUTE` grants are usable. The gap was invisible until an actual call was attempted as that role — this CR fixes it and adds a guard so the same class of defect cannot recur silently for any future integration role. Owner-approved 2026-08-15 ("approve the schema usage grant fix").

---

## Risks

Low. A single additive `GRANT USAGE ON SCHEMA` statement; no data, RLS, or existing-grant change. The added smoke-test check is read-only ACL introspection.

---

## Supersedes / Depends On

None. Depends on `202607049200_offline_conversion_core.sql` (creates the role and its function grants) already being applied.

---

## Scope — Files Allowed to Modify

- `supabase/migrations/202607050000_grant_orvion_integration_schema_usage.sql`
- `scripts/verify_database.sql`
- `changes/SPEC-122-orvion-integration-schema-usage-grant.md`
- `_ORVION_CANONICAL/manifest.md`
- `reports/master/MASTER_INTEGRATION_CATALOG.md`

---

## Out of Scope — Files Forbidden to Modify

- Any other `supabase/migrations/**` file.
- `supabase/tests/**` (existing pgTAP suite — not extended by this CR; the guard is added to the smoke-test per the file this defect class was actually caught by).
- Any other canon, ADR, or Master document.

---

## Minimum Reading List

- `supabase/migrations/202607049200_offline_conversion_core.sql` (the role and its existing function grants)
- `supabase/migrations/202607043700_provision_tenant_and_has_permission.sql` (precedent: `grant usage on schema app to service_role` for the identical reason)
- `scripts/verify_database.sql` (existing check-numbering convention)

---

## Implementation Steps

1. Create `supabase/migrations/202607050000_grant_orvion_integration_schema_usage.sql` containing `grant usage on schema app to orvion_integration;`. Verification: file does not yet exist (fresh CR) — create as written.
2. Add Check 10 to `scripts/verify_database.sql`: for every role holding function `EXECUTE` on a non-system schema, assert it also holds `USAGE` on that schema; update the final `ALL CHECKS PASSED` message to mention it. Verification: search for `CHECK 10` in the file — absent before this step, present after.
3. Run `npx supabase db reset`, then `npx supabase test db` (full pgTAP suite), then the smoke-test (`docker exec -i supabase_db_ORVION psql -U postgres -d postgres -f - < scripts/verify_database.sql`). Verification: all three succeed; smoke-test prints `ALL CHECKS PASSED` including the new grant/schema-usage clause.

---

## Acceptance Criteria

- [x] `grant usage on schema app to orvion_integration;` exists in a new migration, applied cleanly by `db reset`.
- [x] `verify_database.sql` Check 10 exists, is schema-general (not hardcoded to `orvion_integration` alone), and passes on the fixed database.
- [x] Full pgTAP suite (`supabase test db`) green after the fix.
- [x] Smoke-test green, printing the updated summary message.
- [x] No file outside Scope touched; no RLS, data, or existing-grant change made.

---

## Execution Log

### 2026-08-15 — Claude (Sonnet 5)

Outcome: Complete

Step results:
- Step 1: Applied — `supabase/migrations/202607050000_grant_orvion_integration_schema_usage.sql`.
- Step 2: Applied — Check 10 added to `scripts/verify_database.sql`.
- Step 3: Applied — `supabase db reset` clean (88 → 89 migrations); `supabase test db` and the smoke-test both verified in this session (see Verification Notes).

Commits: (not committed as of this entry — left for explicit owner instruction, per this session's established pattern)

### 2026-08-15 — Claude (Sonnet 5) — deployment run

Outcome: Blocked (partial — secondary complete, primary blocked by connector availability, not skipped)

Step results:
- Deploy `202607050000` to Secondary (`brplkqmbzffpxqgkkdzo`): Applied and verified — `has_schema_privilege` confirmed `false` before, `true` after; MCP-assigned version reconciled to `202607050000`; `list_migrations` re-confirms 89/89 version-for-version. Full detail: `MASTER_CERTIFICATION_STATUS.md` certification history (2026-08-15 entry), `MASTER_INTEGRATION_CATALOG.md §4`.
- Deploy `202607050000` to Primary (`vrvtsxexkiiiivlkdxzp`): Not attempted — no `supabase-primary` MCP server was connected in this session (confirmed via `ToolSearch` and `list_projects` returning only the secondary). No workaround attempted; reported as a blocker per `AGENTS.md` "no guessing."

Commits: `6fdaa2c` (repo-side migration + guard, committed and pushed in an earlier run this session, before this deployment run).

Blocker: Primary is not reachable from this session by any available tool. Resolving requires either a future session with the `supabase-primary` MCP server connected, or the owner applying `supabase/migrations/202607050000_grant_orvion_integration_schema_usage.sql` to primary directly.

---

## Verification Notes

### 2026-08-15 — Claude (Sonnet 5)

Verdict: Confirmed Complete

Findings: Independently re-ran against the live local database after `db reset` (not trusting the Execution Log's self-report): `supabase test db` — full pgTAP suite green; `scripts/verify_database.sql` — `ALL CHECKS PASSED` including new Check 10; direct re-run of this session's earlier internal-pipeline-validation SQL (same rolled-back-transaction technique) confirmed `SET ROLE orvion_integration; SELECT app.map_outcomes_to_conversions(500);` now succeeds where it previously failed with `permission denied for schema app`.

Recommendation to human: Set Status to Complete.

---

## Review Gate

- [x] Every change matches the Implementation Steps exactly.
- [x] No file outside the Scope list was modified or created.
- [x] Every Acceptance Criteria item is confirmed true.
- [x] The repository is in a clean, releasable state (pending owner commit instruction).

---

## Notes

This CR's fix was owner-approved narrowly ("approve the schema usage grant fix"); the accompanying permanent guard (Check 10) was added under the repository's standing discovery-to-guard duty (`AGENTS.md §2`/§18`) rather than a separate request — it is the same pairing precedent as SPEC-120/SPEC-121. Not committed automatically, per this session's established rhythm of the owner separately instructing commit and push.
