# Change Request — SPEC-331

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close the CRM `B6-EXIT` ceiling reading of EC-7 and the mechanism sweep of EC-11 with one permanent check, and resolve two EC-8 record conflicts. One catalog-driven pgTAP test (Test 187) turns the four numeric suite ceilings of Tests 07 and 10 into named memberships and sweeps `public`, `app` and `reporting` for orphaned, duplicate and switched-off mechanisms. Two surfaces whose findings were already resolved are re-dispositioned AUDITED, five register statuses are re-worded to the settled vocabulary with their superseded text kept, and the two registry rows they leave are removed.

## Business Reason

At 23be9e2cee6e29ef8ffb5c751554a65651a0f994, four suite ceilings are numeric bounds with slack: Test 07 `<= 42` over 39 reserved event codes, and Test 10 `<= 56`, `<= 20` and `<= 3` over 52, 5 and 2 tables. A population can grow silently until it meets its bound, so EC-7 asks for each ceiling as a named membership or a monotonic bound. EC-11 asks for the per-surface review of orphaned, duplicate and superseded mechanisms, and no check pins it. EC-8 asks for the remaining plan, finding and disposition conflicts to be resolved. `booking_item_passengers` and `financial_accounts` stay AUDITED-OPEN although PAX-5, PAX-6 and FA-2 were resolved on 2026-09-09 (migrations `20260909131000`, `20260909132000` and `20260909133000`; Tests 104, 113 and 114). OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 are settled in substance but carry statuses outside the settled vocabulary, so the registry still lists them. Measured at 23be9e2cee6e29ef8ffb5c751554a65651a0f994 (277 migrations), and identically on Platinum Primary read-only, the sweep finds no disabled, duplicate, invalid, unvalidated or unowned mechanism and exactly one runtime-unreachable function, `app.document_retention_days(uuid,text)`, which RET-1's policy table supersedes.

## Risks

A test that reads the live catalog could pass vacuously or freeze a weakness as accepted. Assertions 1–4 and 12 are set equalities, so a new member fails and removing one must remove it from the set: each ceiling can only shrink, and the numeric bounds in Tests 07 and 10 stay. Assertions 5–11 are emptiness checks over the whole scope. Re-wording a status could erase history, so each re-worded status and Next keeps its superseded text. Re-dispositioning a surface could hide an open finding, so each AUDITED row cites the test and migration that resolved it. The unreachable function is recorded with its reason and trigger, not removed, because RET-1 is an owner decision. This contract changes no migration, function, policy, grant or database object, and no exit criterion is marked met.

## Supersedes / Depends On

Extends the SPEC-330 catalog-driven proof (Test 186) and the SPEC-329 reconciliation. Uses the 2026-09-09 resolutions of PAX-5, PAX-6 and FA-2, SPEC-116 for OPS-2, the 2026-08-28 merger of RLS-1 into SEC-1, the 2026-08-29 API-2 delivery guarded by Check L3, the 2026-09-04 TAX-1 retraction and the 2026-08-31 SPEC-154-B fix behind FIN-DOC-1. Those terminal contracts are immutable.

## Write Scope

- `changes/SPEC-331-every-ceiling-is-a-named-membership-and-no-mechanism-is-orphaned.md`
- `supabase/tests/187_every_ceiling_is_a_named_membership_and_no_mechanism_is_orphaned_test.sql`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_API_CONTRACT.md`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `scripts/test_cold_start_state_guard.ps1`
- `.github/workflows/repository-consistency.yml`
- `supabase/config.toml`

Migrations, product code, any Primary write, Founder Secondary, frontend work, integration activation, email delivery and every owner decision are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9.
- `reports/master/MASTER_EXECUTION_PLAN.md` Action Registry and the exit criteria EC-7, EC-8 and EC-11.
- `reports/master/MASTER_GAP_REGISTER.md` OPS-2, RLS-1, API-2, TAX-1, FIN-DOC-1 and RET-1.
- `reports/master/MASTER_SURFACE_DISPOSITION.md` rows `booking_item_passengers` and `financial_accounts`.
- `supabase/tests/07_event_catalog_coverage_test.sql`, `supabase/tests/10_member_insert_capability_test.sql` and `supabase/tests/186_every_permission_is_enforced_and_every_table_states_its_isolation_basis_test.sql`.

## Runtime Checkpoint

Resume Step: 1
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- github

## Additional Verification

- pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1
- pwsh -NoProfile -File scripts/test_future_date_guard.ps1
- pwsh -NoProfile -File scripts/test_status_contradiction_guard.ps1
- pwsh -NoProfile -File scripts/test_primary_ledger_guard.ps1
- pwsh -NoProfile -File scripts/test_cold_start_state_guard.ps1
- pwsh -NoProfile -File scripts/readiness_selftest.ps1

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: One new pgTAP test, Test 187, read entirely from the catalog with no fixture, like Test 186. Assertions 1–4 pin the four numeric ceilings of Tests 07 and 10 as set equalities over named members. Assertions 5–11 sweep `public`, `app` and `reporting` for a disabled trigger, a duplicate trigger, index or policy, an invalid index, an unvalidated constraint and an unowned sequence. Assertion 12 names the one runtime-unreachable function. The plan, register, disposition and manifest record the result.

Pass 2 Adversarial Review: Applied in a rolled-back transaction, a mutation set failed every one of the 12 assertions. It added a function naming a reserved event code, a new member-insertable table with no capability trigger or policy, a disabled trigger, two identical triggers, indexes and policies, an index marked invalid, a NOT VALID constraint, an unowned sequence and a new function no client role may execute. The unmutated catalog passes all 12. Each re-worded status keeps its superseded text, and each AUDITED row cites its resolving test and migration.

Pass 3 Evidence Refresh: 2026-11-22. In an isolated clone at 23be9e2cee6e29ef8ffb5c751554a65651a0f994 carrying the payload:
- Test 187 passed 12 of 12 on the local stack (277 migrations).
- `readiness_population.ps1` reported REGISTRY complete, NOT DUE 33 (40 less the seven re-worded or re-dispositioned members) and no COMPLETED member.
- Native repository consistency was CLEAN.
- All five hosted guard suites passed (19, 33, 13, 42 and 33 assertions, 0 failed).

Selected Version: SPEC-331; selected: one catalog-driven pgTAP test that pins the four numeric suite ceilings of Tests 07 and 10 as named memberships and sweeps public, app and reporting for disabled, duplicate, invalid, unvalidated, unowned and unreachable mechanisms, with the plan, register, disposition and manifest records it settles, the smallest change that closes the EC-7 ceilings and the EC-11 sweep and resolves two EC-8 record conflicts without any database change

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Suite ceilings and mechanism sweep | Full pgTAP suite and the `B6-EXIT` gate evaluation | WRITE | Test 187 adds 12 catalog assertions; the suite grows to 187 files and 3479 assertions. |
| Two registry rows and five register statuses | Action Registry, Check 29 and `readiness_population.ps1` | WRITE | The statuses are settled with their superseded text; the evaluator reports REGISTRY complete with no COMPLETED member. |
| Two surface dispositions | Disposition summary, Check 29 and `batch6_select_target.ps1` | WRITE | 64 AUDITED and 11 AUDITED-OPEN; each AUDITED row cites its resolving test and migration. |
| EC-7, EC-8 and EC-11 readings | Exit criteria | WRITE | They cite Test 187 and the re-dispositions; no criterion is marked met. |
| Schema, grants, policies and API | Every product consumer | UNAFFECTED | No migration; the API contract has the same blob as the baseline. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchors and exact payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Check 29 and the five hosted guard suites pass | BEFORE_COMPLETION | 2 | 4 | 6 |
| Full DATABASE readiness with Test 187 | BEFORE_COMPLETION | NONE | NONE | 6 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: The pgTAP suite and its catalog-driven precedents `supabase/tests/01_rls_coverage_test.sql` and `supabase/tests/186_every_permission_is_enforced_and_every_table_states_its_isolation_basis_test.sql`.

Added Property: Each of the four numeric ceilings has an exact named membership that can only shrink. No trigger in scope is disabled or duplicated, no index is duplicated or invalid, no policy is duplicated, no constraint is unvalidated, no sequence is unowned, and the only function reachable from nothing at runtime is the named, reasoned RET-1 lookup.

Causal Negative: At 23be9e2cee6e29ef8ffb5c751554a65651a0f994, a new reserved event code or a new member-insertable table passes the whole suite until its numeric bound is reached, and a disabled trigger, a duplicate index or policy, an invalid index, an unvalidated constraint, an unowned sequence or a new orphaned function passes it entirely.

Positive Test Design: On the unmutated catalog Test 187 passes 12 of 12.

Negative Test Design: In a rolled-back transaction, each mutation fails its assertion: a reserved event code gains an emitter, a new member-insertable table without a capability trigger or policy, a disabled trigger, a duplicate trigger, index and policy, an invalid index, a NOT VALID constraint, an unowned sequence and a new function no client role may execute.

Non-Empty Population Obligation: The catalog holds 39 reserved event codes, 52 member-insertable tables, 5 without a capability trigger, 2 without any INSERT capability and one unreachable function, and each set equality fails on an empty population.

Mutation Obligation: The mutation set above must fail all 12 assertions.

Post-Implementation Proof Obligation: The native Finish runs the full DATABASE protocol with Test 187 and all five hosted guard suites through Additional Verification with zero failures. Hosted preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `supabase/tests/187_every_ceiling_is_a_named_membership_and_no_mechanism_is_orphaned_test.sql` contains `select plan(12);`; if so record Already Applied when its Git blob is 4b7acb723de2ecea6b5ea08190af4b5161566ad3, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the catalog-driven ceiling membership and mechanism sweep test), and change nothing else:

   ```text
   -- pgTAP: Batch 6 exit -- every ceiling is a named membership, and no mechanism is orphaned, duplicated or switched off.
   --
   -- Catalog-driven, like `186_every_permission_is_enforced_and_every_table_states_its_isolation_basis_test.sql`: every
   -- assertion reads the live catalog, so a new event code, table, trigger, policy, index or function is judged the moment
   -- it exists.
   --
   -- EC-7: four suite ceilings were numeric bounds with slack, so a population could grow silently until it met
   --   the bound. Measured at `23be9e2` (277 migrations), and identically on Platinum Primary, each population is pinned
   --   here by name; the numeric bounds in Tests 07 and 10 stay and this test is their exact membership:
   --     Test 07 `<= 42`  -- 39 `event_type` codes named by no `app` function and no trigger (reserved vocabulary);
   --     Test 10 `<= 56`  -- 52 `public` tables `authenticated` may INSERT into;
   --     Test 10 `<= 20`  -- 5 of them with no capability-checking INSERT trigger;
   --     Test 10 `<= 3`   -- 2 of those with no capability-naming INSERT policy either (the identity tables, whose
   --                         policies name `auth.uid()` -- Test 186 basis IDENTITY).
   --   A new member fails its set equality; removing one must remove it here, so each ceiling can only shrink.
   --
   -- EC-11: the per-surface sweep for orphaned, duplicate and superseded mechanisms over `public`, `app` and `reporting`:
   --   no disabled trigger, no duplicate trigger, index or policy, no invalid index, no unvalidated constraint, no
   --   unowned sequence, and exactly one function reachable from nothing at runtime:
   --     app.document_retention_days(uuid,text) -- superseded by RET-1's `document_retention_policies`, which the scan and
   --       claim paths join directly; kept as the tested per-tenant lookup (Test 97), executable by no client role.
   --       Trigger: remove it when RET-1's owner decision retires the lookup, or a caller appears (then it leaves this set).
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(12);

   create temporary view t187_insertable as
   select c.oid, c.relname::text as tbl
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r' and has_table_privilege('authenticated', c.oid, 'INSERT');

   create temporary view t187_no_trigger as
   select i.* from t187_insertable i
    where not exists (select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
                       where t.tgrelid = i.oid and not t.tgisinternal and (t.tgtype & 4) <> 0
                         and pg_get_functiondef(p.oid) ~ '(app\.authorize|app\.has_permission|app\.require_lead_handler)');

   create temporary view t187_no_capability as
   select nt.* from t187_no_trigger nt
    where not exists (select 1 from pg_policies pp
                       where pp.schemaname = 'public' and pp.tablename = nt.tbl and pp.cmd in ('INSERT','ALL')
                         and coalesce(pp.with_check,'') ~ 'has_permission\(''(?!VIEW_|SEE_)[A-Z_]+''');

   create temporary view t187_unused_event as
   with fsrc as (
     select coalesce(string_agg(pg_get_functiondef(p.oid), E'\n'),'') as s
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'app'),
   tsrc as (
     select coalesce(string_agg(pg_get_triggerdef(t.oid), E'\n'),'') as s from pg_trigger t where not t.tgisinternal)
   select cv.code::text as code
     from public.catalog_values cv, fsrc, tsrc
    where cv.catalog_type_code = 'event_type' and position(cv.code in fsrc.s) = 0 and position(cv.code in tsrc.s) = 0;

   create temporary view t187_scope as
   select c.oid, c.relname, n.nspname
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname in ('public','app','reporting');

   -- 1. Test 07 ceiling as membership: the reserved event vocabulary.
   select set_eq(
     'select code from t187_unused_event',
     $$values ('account_locked'),('approval_resubmitted'),('booking_item_cost_entered'),('booking_item_cost_locked'),
              ('booking_item_locked_cost_edited'),('booking_item_sub_status_changed'),('booking_item_supplier_assigned'),
              ('company_asset_created'),('customer_cross_branch_activity_detected'),('customer_identity_match_found'),
              ('document_expiry_warning'),('exchange_rate_adjustment_created'),('finance_approval_resubmitted'),
              ('financial_account_created'),('lead_reopened'),('login_attempt'),('login_failure'),('login_success'),
              ('notification_created'),('notification_failed'),('notification_read'),('notification_sent'),
              ('offline_conversion_retried'),('offline_conversion_send_attempted'),('otp_expired'),('otp_failed'),
              ('otp_requested'),('otp_verified'),('passenger_document_added'),('passenger_passport_expiry_warning'),
              ('password_changed'),('password_reset'),('supplier_assigned_to_booking_item'),('task_overdue'),
              ('totp_challenge_failure'),('totp_challenge_success'),('totp_enrolled'),('trusted_device_expired'),
              ('user_branch_transfer_started')$$,
     'EC-7: the 39 event codes no function or trigger emits are exactly the reserved vocabulary (Test 07 <= 42)'
   );

   -- 2. Test 10 ceiling as membership: the tables a member may INSERT into.
   select set_eq(
     'select tbl from t187_insertable',
     $$values ('approval_requests'),('booking_item_passengers'),('booking_items'),('bookings'),('branch_business_hours'),
              ('branches'),('campaign_daily_metrics'),('catalog_values'),('chart_of_accounts'),('company_assets'),
              ('complaints'),('conversation_messages'),('conversations'),('customer_contact_methods'),
              ('customer_identity_signals'),('customer_notes'),('customers'),('departments'),('document_links'),
              ('document_retention_policies'),('document_versions'),('documents'),('exchange_rate_adjustments'),
              ('exchange_rates'),('financial_accounts'),('holidays'),('internal_supplier_links'),('invoices'),
              ('lead_assignments'),('lead_interactions'),('leads'),('marketing_campaigns'),('offline_conversions'),
              ('passengers'),('payment_allocations'),('payments'),('quotation_items'),('quotations'),('receipts'),
              ('refunds'),('service_requests'),('subscription_payment_proofs'),('subscriptions'),('suppliers'),('tasks'),
              ('tenants'),('totp_enrollments'),('trusted_devices'),('user_branch_assignments'),('user_permission_grants'),
              ('user_role_assignments'),('users')$$,
     'EC-7: the 52 member-insertable tables are named (Test 10 <= 56)'
   );

   -- 3. Test 10 ceiling as membership: insertable with no capability-checking INSERT trigger.
   select set_eq(
     'select tbl from t187_no_trigger',
     $$values ('subscription_payment_proofs'),('subscriptions'),('tenants'),('totp_enrollments'),('trusted_devices')$$,
     'EC-7: the 5 insertable tables without a capability trigger are named (Test 10 <= 20)'
   );

   -- 4. Test 10 ceiling as membership: no capability trigger and no capability policy.
   select set_eq(
     'select tbl from t187_no_capability',
     $$values ('totp_enrollments'),('trusted_devices')$$,
     'EC-7: only the 2 identity tables carry no INSERT capability of any kind (Test 10 <= 3)'
   );

   -- 5. No trigger is switched off.
   select is_empty(
     $$select t.tgname from pg_trigger t join t187_scope s on s.oid = t.tgrelid
        where not t.tgisinternal and t.tgenabled = 'D'$$,
     'EC-11: no trigger in public, app or reporting is disabled'
   );

   -- 6. No trigger is defined twice (same table, function, timing/events, arguments and condition).
   select is_empty(
     $$select t.tgrelid::regclass::text
         from pg_trigger t join t187_scope s on s.oid = t.tgrelid
        where not t.tgisinternal
        group by t.tgrelid, regexp_replace(pg_get_triggerdef(t.oid), '^CREATE (CONSTRAINT )?TRIGGER \S+ ', '')
       having count(*) > 1$$,
     'EC-11: no duplicate trigger'
   );

   -- 7. No index is defined twice.
   select is_empty(
     $$select i.indrelid::regclass::text
         from pg_index i join t187_scope s on s.oid = i.indrelid
        group by i.indrelid, i.indkey::text, i.indclass::text, i.indisunique,
                 coalesce(pg_get_expr(i.indexprs, i.indrelid),''), coalesce(pg_get_expr(i.indpred, i.indrelid),'')
       having count(*) > 1$$,
     'EC-11: no duplicate index'
   );

   -- 8. No policy is defined twice.
   select is_empty(
     $$select tablename::text from pg_policies
        where schemaname in ('public','app','reporting')
        group by schemaname, tablename, permissive, cmd, roles::text, coalesce(qual,''), coalesce(with_check,'')
       having count(*) > 1$$,
     'EC-11: no duplicate policy'
   );

   -- 9. No index is left invalid and no constraint unvalidated.
   select is_empty(
     $$select i.indexrelid::regclass::text from pg_index i join t187_scope s on s.oid = i.indrelid where not i.indisvalid$$,
     'EC-11: no invalid index'
   );

   select is_empty(
     $$select c.conname::text from pg_constraint c join pg_namespace n on n.oid = c.connamespace
        where not c.convalidated and n.nspname in ('public','app','reporting')$$,
     'EC-11: no unvalidated constraint'
   );

   -- 10. No sequence outlives its column.
   select is_empty(
     $$select s.relname::text from t187_scope s join pg_class c on c.oid = s.oid
        where c.relkind = 'S' and not exists (select 1 from pg_depend d where d.objid = s.oid and d.deptype in ('a','i'))$$,
     'EC-11: no unowned sequence'
   );

   -- 11. Exactly one function is reachable from nothing at runtime: no trigger, function, policy, view or cron job names
   --     it, and no client role may execute it.
   select set_eq(
     $$select p.oid::regprocedure::text
         from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname in ('public','app','reporting')
          and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
          and not exists (select 1 from pg_trigger t where t.tgfoid = p.oid)
          and not exists (select 1 from pg_proc q where q.oid <> p.oid and q.prosrc ilike '%' || p.proname || '%')
          and not exists (select 1 from pg_policies pp
                           where coalesce(pp.qual,'') || coalesce(pp.with_check,'') ilike '%' || p.proname || '%')
          and not exists (select 1 from pg_views v where v.definition ilike '%' || p.proname || '%')
          and not exists (select 1 from cron.job j where j.command ilike '%' || p.proname || '%')
          and not has_function_privilege('anon', p.oid, 'EXECUTE')
          and not has_function_privilege('authenticated', p.oid, 'EXECUTE')
          and not has_function_privilege('service_role', p.oid, 'EXECUTE')
          and not has_function_privilege('orvion_integration', p.oid, 'EXECUTE')$$,
     $$values ('app.document_retention_days(uuid,text)')$$,
     'EC-11: the only runtime-unreachable function is the superseded RET-1 lookup'
   );

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 4b7acb723de2ecea6b5ea08190af4b5161566ad3.

2. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Last updated: 2026-11-22 (CRM exit bundle F, SPEC-331.`; if so record Already Applied when its Git blob is f5f0acb106e9c1e3520ede80b8cc48110788a787, and otherwise stop and report. Otherwise make exactly these 7 edits (two settled registry rows leave, the EC-7, EC-8 and EC-11 readings cite Test 187, and the dated SPEC-331 header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-22 (CRM exit bundle E, SPEC-330. Test 186 re-measures RPC-1 at `790aa96`: four permissions are enforced nowhere, each with its recorded reason, as a set that can only shrink, so RPC-1 is resolved and leaves the registry. It also states the isolation basis of every public table, and the EC-2 and EC-3 readings cite it.)
   ```
   with
   ```text
   Last updated: 2026-11-22 (CRM exit bundle F, SPEC-331. Test 187 pins the four numeric suite ceilings of Tests 07 and 10 as named memberships and sweeps `public`, `app` and `reporting` for disabled, duplicate, invalid, unvalidated, unowned and unreachable mechanisms. Two surfaces are re-dispositioned AUDITED and five register statuses are re-worded to the settled vocabulary, so their two registry rows leave.)

   Previously: 2026-11-22 (CRM exit bundle E, SPEC-330. Test 186 re-measures RPC-1 at `790aa96`: four permissions are enforced nowhere, each with its recorded reason, as a set that can only shrink, so RPC-1 is resolved and leaves the registry. It also states the isolation basis of every public table, and the EC-2 and EC-3 readings cite it.)
   ```

   b) replace the line
   ```text
   **CRM exit evidence at `790aa96`, measured 2026-11-22 (SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```
   with
   ```text
   **CRM exit evidence at `23be9e2`, measured 2026-11-22 (SPEC-331, Test 187; SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```

   c) replace the lines
   ```text
   - **EC-7 (partial):** Existing member repairs carry permanent tests. Cross-check each material closure to its actual assertion and each ceiling to a named membership or monotonic bound. A test that records an open behavior still needs a matching repair or justified invariant.
   - **EC-8 (partial):** Native freshness checks and the reconciled records establish bounded coherence. Complete the existing gate-evaluation disposition work and resolve any remaining plan/finding/disposition conflicts.
   ```
   with
   ```text
   - **EC-7 (ceilings closed; closures cross-checked at the gate evaluation):** Existing member repairs carry permanent tests. Test 187 turns the four numeric ceilings with slack into named memberships: Test 07 `<= 42` is the 39 event codes no function or trigger emits, and Test 10 `<= 56`, `<= 20` and `<= 3` are the 52 member-insertable tables, the 5 of them without a capability trigger and the 2 identity tables without any INSERT capability. Each is a set equality, so a new member fails and a removed one must leave the set. Cross-checking each material closure to its actual assertion stays with the gate evaluation.
   - **EC-8 (partial):** Native freshness checks and the reconciled records establish bounded coherence. SPEC-331 resolves two record conflicts: `booking_item_passengers` and `financial_accounts` are AUDITED, because PAX-5, PAX-6 and FA-2 were resolved on 2026-09-09 (Tests 104, 113 and 114). OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 now carry settled statuses, and each keeps its superseded text. N1, DC-5, RC-4, R8, B3 and RC-1 stay with the gate evaluation, which re-verifies them against their migrations.
   ```

   d) replace the line
   ```text
   - **EC-11 (open):** AUTH-1 gives the inert authentication-table retirement trigger. Finish the per-surface review of orphaned, duplicate and superseded mechanisms with current reasons and triggers.
   ```
   with
   ```text
   - **EC-11 (swept; confirmed at the gate evaluation):** Test 187 sweeps every table, trigger, index, policy, constraint, sequence and function in `public`, `app` and `reporting`. It finds no disabled or duplicate trigger, no duplicate or invalid index, no duplicate policy, no unvalidated constraint and no unowned sequence. Exactly one function is reachable from nothing at runtime: `app.document_retention_days(uuid,text)`. It is superseded by RET-1's policy table and kept as the tested lookup, and it leaves the set when RET-1's owner decision retires it or a caller appears. AUTH-1 keeps the retirement trigger for the inert authentication tables, and the `documents`/`quotations` re-sweep keeps its gate-evaluation row.
   ```

   e) replace the lines
   ```text
   | GOV-9, GOV-15, GOV-20, GUARD-1, SYNC-1, PAR-7, CTRL-3, DC-27, CTRL-5, CI-2, TEST-4, PERF-2, CTRL-6 | ACCEPTED RESIDUAL | engineering | `OWN-TRIGGER` | — | Control plane and governance, none a Day-1 business function. The control-plane chapter is closed, and each reopens only on its own trigger |
   | OPS-2, RLS-1, API-2, TAX-1, FIN-DOC-1 | TERMINAL IN SUBSTANCE | engineering | `GATE-EVAL` | — | Each carries a terminal verdict outside the settled vocabulary: implemented, merged, delivered, retracted, closed. Re-worded to settled at the first evaluation |
   ```
   with
   ```text
   | GOV-9, GOV-15, GOV-20, GUARD-1, SYNC-1, PAR-7, CTRL-3, DC-27, CTRL-5, CI-2, TEST-4, PERF-2, CTRL-6 | ACCEPTED RESIDUAL | engineering | `OWN-TRIGGER` | — | Control plane and governance, none a Day-1 business function. The control-plane chapter is closed, and each reopens only on its own trigger |
   ```

   f) replace the lines
   ```text
   | DC-3 | FUTURE-ONLY | engineering | `ENABLE-INVENTORY` | — | Concurrency control before inventory ships |
   | `booking_item_passengers`, `financial_accounts` | SURFACE | engineering | `GATE-EVAL` | — | Still `AUDITED-OPEN` for decisions the register has since settled (PAX-5, PAX-6, BOOK-8, BOOK-9, FA-2); re-dispositioned at the first evaluation (EC-8) |
   ```
   with
   ```text
   | DC-3 | FUTURE-ONLY | engineering | `ENABLE-INVENTORY` | — | Concurrency control before inventory ships |
   ```

   g) immediately after the lines
   ```text
   **Recorded exception, 2026-11-22, CRM exit bundle E.** After CRM SPEC-329 at `790aa963f2b7dc8049a9dd691f54ed61d22e920f`, the Batch 6 run mode 2 delegation continues to `B6-EXIT`. SPEC-330 adds Test 186, read entirely from the catalog with no fixture: RPC-1 is re-measured to the four permissions enforced nowhere, each with its recorded reason, and every public table states its isolation basis. RPC-1 is resolved and its registry row removed; the EC-2 and EC-3 readings cite Test 186. It changes no migration or database object. EC-6, EC-7, EC-8, EC-10 and EC-11 keep their recorded work, and the Original and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-22, CRM exit bundle F.** After CRM SPEC-330 at `23be9e2cee6e29ef8ffb5c751554a65651a0f994`, the Batch 6 run mode 2 delegation continues to `B6-EXIT`. SPEC-331 adds Test 187, which reads entirely from the catalog and uses no fixture. It pins the four numeric suite ceilings as named memberships and records the EC-11 mechanism sweep. Two surfaces whose findings were already resolved are re-dispositioned, and five register statuses are re-worded with their superseded text kept. The two registry rows leave, and the EC-7, EC-8 and EC-11 readings cite the result. It changes no migration or database object. The gate-evaluation rows keep their work, and the Original and release gates remain enforced.

   ```

   The resulting file's Git blob is f5f0acb106e9c1e3520ede80b8cc48110788a787.

3. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `CRM SPEC-331 re-words`; if so record Already Applied when its Git blob is 434c9a8db2f30d450ea7dccb564032be32f5dc4e, and otherwise stop and report. Otherwise make exactly these 7 edits (OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 carry settled statuses with their superseded text, and the dated header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-22 (CRM SPEC-330 resolves RPC-1: Test 186 re-measures it to four permissions enforced nowhere, each with its recorded reason, as a set that can only shrink. No other finding changes status.)
   ```
   with
   ```text
   Last updated: 2026-11-22 (CRM SPEC-331 re-words OPS-2, RLS-1, API-2, TAX-1 and FIN-DOC-1 to the settled vocabulary, each keeping its superseded text, and adds no finding. Test 187 pins the suite ceilings and the mechanism sweep.)

   Previously: 2026-11-22 (CRM SPEC-330 resolves RPC-1: Test 186 re-measures it to four permissions enforced nowhere, each with its recorded reason, as a set that can only shrink. No other finding changes status.)
   ```

   b) replace the line
   ```text
   | FIN-DOC-1 | New evidence sharpening **SPEC-154-B**, not a new decision | privacy scope | — | — | 6 | — | 📋 | **EVIDENCE ONLY — attaches to the existing SPEC-154-B owner decision and creates no new one.** Measured with a discriminating control: a `finance_manager` holding VIEW_FINANCIAL_DOCUMENTS reads the tenant's financial documents through `app.financial_documents()`; an `employee` is refused **42501** by that endpoint. Through the TABLE, that same employee reads a **NON-confidential** invoice document (RLS branch: not confidential AND has links AND the caller lacks VIEW_FINANCIAL_DOCUMENTS) while a **CONFIDENTIAL** one is correctly invisible. So the confidentiality boundary IS enforced and the endpoint's guard is not a privacy boundary for non-confidential financial documents. **What this adds to SPEC-154-B:** the decision is not only "who may hold the permission" but "should the RLS branch exclude financial TYPES regardless of the confidential flag" — and canon 28 states BOTH *"assigned employee may view financial documents directly related to their lead/booking"* AND *"financial documents require stricter visibility"*, which the binary permission cannot express. Deliberately NOT fixed: forcing `is_confidential` on financial types would satisfy the second rule by destroying the first. Pinned by assertion 20 of `81_task_supplier_financial_test.sql` so the boundary cannot move silently. **Also recorded:** `202607048200`'s header claims *"RLS on documents is tenant-wide"* — measurably false since the SPEC-139/DOC packages tightened it; the endpoint is stricter than its own comment says, so the staleness is harmless but noted (a comment is a claim) | **CLOSED by SPEC-154-B, 2026-08-31** | api-3-closure-2026-08-30 | 08-30 | 08-31 |
   ```
   with
   ```text
   | FIN-DOC-1 | New evidence sharpening **SPEC-154-B**, not a new decision | privacy scope | — | — | 6 | — | 📋 | **CLOSED 2026-11-22 (SPEC-331 re-wording): the evidence attached to SPEC-154-B, which the owner decided and engineering fixed on 2026-08-31.** Superseded text: **EVIDENCE ONLY — attaches to the existing SPEC-154-B owner decision and creates no new one.** Measured with a discriminating control: a `finance_manager` holding VIEW_FINANCIAL_DOCUMENTS reads the tenant's financial documents through `app.financial_documents()`; an `employee` is refused **42501** by that endpoint. Through the TABLE, that same employee reads a **NON-confidential** invoice document (RLS branch: not confidential AND has links AND the caller lacks VIEW_FINANCIAL_DOCUMENTS) while a **CONFIDENTIAL** one is correctly invisible. So the confidentiality boundary IS enforced and the endpoint's guard is not a privacy boundary for non-confidential financial documents. **What this adds to SPEC-154-B:** the decision is not only "who may hold the permission" but "should the RLS branch exclude financial TYPES regardless of the confidential flag" — and canon 28 states BOTH *"assigned employee may view financial documents directly related to their lead/booking"* AND *"financial documents require stricter visibility"*, which the binary permission cannot express. Deliberately NOT fixed: forcing `is_confidential` on financial types would satisfy the second rule by destroying the first. Pinned by assertion 20 of `81_task_supplier_financial_test.sql` so the boundary cannot move silently. **Also recorded:** `202607048200`'s header claims *"RLS on documents is tenant-wide"* — measurably false since the SPEC-139/DOC packages tightened it; the endpoint is stricter than its own comment says, so the staleness is harmless but noted (a comment is a claim) | **CLOSED by SPEC-154-B, 2026-08-31** | api-3-closure-2026-08-30 | 08-30 | 08-31 |
   ```

   c) replace the line
   ```text
   - **Finding:** `scripts/verify_database.sql` raises on the first broken invariant but did not set `ON_ERROR_STOP`, so psql exited 0 on failure — the smoke-test was silently non-gating for every caller (local + never run in CI). **Status: ✅ IMPLEMENTED (SPEC-116).** File now self-arms `\set ON_ERROR_STOP on` (verified: pass→0, fail→3) and CI runs it after every `db reset`.
   ```
   with
   ```text
   - **Finding:** `scripts/verify_database.sql` raises on the first broken invariant but did not set `ON_ERROR_STOP`, so psql exited 0 on failure — the smoke-test was silently non-gating for every caller (local + never run in CI). **Status:** ✅ IMPLEMENTED (SPEC-116). File now self-arms `\set ON_ERROR_STOP on` (verified: pass→0, fail→3) and CI runs it after every `db reset`.
   ```

   d) replace the line
   ```text
   - **Category:** authorization model / misleading contract · **Severity:** Medium · **Status:** OBSOLETE (merged into SEC-1) · **Owner:** —
   ```
   with
   ```text
   - **Category:** authorization model / misleading contract · **Severity:** Medium · **Status:** CLOSED 2026-08-28 by merger into SEC-1 (re-worded 2026-11-22, SPEC-331; superseded text: OBSOLETE, merged into SEC-1) · **Owner:** —
   ```

   e) replace the line
   ```text
   - **Category:** authorization model · **Severity:** — · **Status:** OBSOLETE (merged) · **Owner:** —
   ```
   with
   ```text
   - **Category:** authorization model · **Severity:** — · **Status:** CLOSED 2026-08-28 by merger into SEC-1 (re-worded 2026-11-22, SPEC-331; superseded text: OBSOLETE, merged) · **Owner:** —
   ```

   f) replace the line
   ```text
   - **Category:** interface governance · **Severity:** n/a (deliverable) · **Status:** DELIVERED · **Owner:** engineering
   ```
   with
   ```text
   - **Category:** interface governance · **Severity:** n/a (deliverable) · **Status:** IMPLEMENTED 2026-08-29, guarded by Check L3 (re-worded 2026-11-22, SPEC-331; superseded text: DELIVERED) · **Owner:** engineering
   ```

   g) replace the line
   ```text
   - **Category:** dead structure / vocabulary · **Severity:** Low today, High the day e-invoicing is wired · **Status:** 📋 **OPEN — engineering** · **Owner:** engineering
   ```
   with
   ```text
   - **Category:** dead structure / vocabulary · **Severity:** Low today, High the day e-invoicing is wired · **Status:** PROVEN NOT A DEFECT, retracted 2026-09-04; see the retraction below (re-worded 2026-11-22, SPEC-331; superseded text: 📋 **OPEN — engineering**) · **Owner:** engineering
   ```

   The resulting file's Git blob is 434c9a8db2f30d450ea7dccb564032be32f5dc4e.

4. Check whether `reports/master/MASTER_SURFACE_DISPOSITION.md` contains `CRM SPEC-331 re-dispositions`; if so record Already Applied when its Git blob is 62db5668af68eaa6f34a108d6cacb13b261ed0d8, and otherwise stop and report. Otherwise make exactly these 4 edits (booking_item_passengers and financial_accounts are AUDITED with their superseded Next, and the dated header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-22 (CRM SPEC-327 adds one-currency ledger and positive-payment proof on both doors. journal_entry_lines and payments become AUDITED because JE-2 is contained fail-closed and PAY-4 is fixed.)
   ```
   with
   ```text
   Last updated: 2026-11-22 (CRM SPEC-331 re-dispositions booking_item_passengers and financial_accounts as AUDITED, because PAX-5, PAX-6 and FA-2 were resolved on 2026-09-09.)

   Previously: 2026-11-22 (CRM SPEC-327 adds one-currency ledger and positive-payment proof on both doors. journal_entry_lines and payments become AUDITED because JE-2 is contained fail-closed and PAY-4 is fixed.)
   ```

   b) replace the line
   ```text
   **78 of 78 recorded · 62 `AUDITED` · 13 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 0 `NOT-RECORDED`.**
   ```
   with
   ```text
   **78 of 78 recorded · 64 `AUDITED` · 11 `AUDITED-OPEN` · 3 `PARTIAL` · 0 `EXEMPT` · 0 `NOT-RECORDED`.**
   ```

   c) replace the line
   ```text
   | `booking_item_passengers` | **AUDITED-OPEN** | ADVERSARIAL | `session-2026-09-07-batch6-slice4-booking-item-passengers` | PAX-1, PAX-2, PAX-3, PAX-5, PAX-6 | PAX-5 (owner: manifest immutability after issuance) and PAX-6 (canon: no event vocabulary for a manifest change) — both decisions, neither engineering |
   ```
   with
   ```text
   | `booking_item_passengers` | **AUDITED** | ADVERSARIAL | `session-2026-09-07-batch6-slice4-booking-item-passengers` | PAX-1, PAX-2, PAX-3, PAX-5, PAX-6 | `104_booking_item_passenger_manifest_surface_test.sql` and `114_passenger_manifest_freeze_and_events_test.sql`: PAX-5 is resolved (migration `20260909132000`; the manifest freezes at `issued`, and a correction needs `CORRECT_PASSENGER_MANIFEST`, a fresh reason and a server-derived actor and time). PAX-6 is resolved (migration `20260909133000`; link, replace and remove each emit exactly one immutable event on every path). Re-dispositioned 2026-11-22 by SPEC-331; superseded Next: PAX-5 (owner: manifest immutability after issuance) and PAX-6 (canon: no event vocabulary for a manifest change), both decisions, neither engineering |
   ```

   d) replace the line
   ```text
   | `financial_accounts` | **AUDITED-OPEN** | ADVERSARIAL | `session-2026-09-05-batch6-adversarial-program` | FA-1, FA-2 | FA-2 is an owner question: may a bank account receive a payment in another currency? |
   ```
   with
   ```text
   | `financial_accounts` | **AUDITED** | ADVERSARIAL | `session-2026-09-05-batch6-adversarial-program` | FA-1, FA-2 | `113_cross_currency_payment_evidence_test.sql`: FA-2 is resolved (migration `20260909131000`). A payment into an account in another currency needs explicit conversion evidence: the rate, the account-currency amount and a server-derived evidence time. Re-dispositioned 2026-11-22 by SPEC-331; superseded Next: FA-2 is an owner question: may a bank account receive a payment in another currency? |
   ```

   The resulting file's Git blob is 62db5668af68eaa6f34a108d6cacb13b261ed0d8.

5. Check whether `_ORVION_CANONICAL/manifest.md` contains `Suite **187 files / 3479 assertions**.`; if so record Already Applied when its Git blob is 59eb3e6ee784b335f49eb1ba4403cb8a50c1509e, and otherwise stop and report. Otherwise make exactly this one edit (the measured suite figure), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **186 files / 3467 assertions**.
   ```
   with
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **187 files / 3479 assertions**.
   ```

   The resulting file's Git blob is 59eb3e6ee784b335f49eb1ba4403cb8a50c1509e.

6. **Establish readiness and verify.** Run the native DATABASE readiness: full SQL tests at 277 migrations with 187 files and 3479 assertions including Test 187 at 12 of 12, smoke and HTTP, and API generation with the API contract unchanged. Run the native repository guard and the five hosted guard suites named in Additional Verification. Confirm that `readiness_population.ps1` reports REGISTRY complete with no COMPLETED member. Confirm the exact scope and `git diff --check`. Make no Primary write. Synchronize the contract and native discovery artifacts, set Runtime Checkpoint DONE and commit the implementation. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-331: Every ceiling is a named membership and no mechanism is orphaned.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] Test 187 pins the four ceilings as named memberships and the mechanism sweep. `check: blob supabase/tests/187_every_ceiling_is_a_named_membership_and_no_mechanism_is_orphaned_test.sql 4b7acb723de2ecea6b5ea08190af4b5161566ad3`
- [ ] The plan removes the two settled registry rows and the EC-7, EC-8 and EC-11 readings cite the result. `check: blob reports/master/MASTER_EXECUTION_PLAN.md f5f0acb106e9c1e3520ede80b8cc48110788a787`
- [ ] The register carries the five settled statuses with their superseded text. `check: blob reports/master/MASTER_GAP_REGISTER.md 434c9a8db2f30d450ea7dccb564032be32f5dc4e`
- [ ] The two surfaces are AUDITED with their resolving evidence and superseded Next. `check: blob reports/master/MASTER_SURFACE_DISPOSITION.md 62db5668af68eaa6f34a108d6cacb13b261ed0d8`
- [ ] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **187 files / 3479 assertions**"`
- [ ] The API contract is unchanged. `check: same reports/master/MASTER_API_CONTRACT.md @23be9e2cee6e29ef8ffb5c751554a65651a0f994`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @23be9e2cee6e29ef8ffb5c751554a65651a0f994`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @23be9e2cee6e29ef8ffb5c751554a65651a0f994`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @23be9e2cee6e29ef8ffb5c751554a65651a0f994`
- [ ] The cold-start guard suite is preserved. `check: same scripts/test_cold_start_state_guard.ps1 @23be9e2cee6e29ef8ffb5c751554a65651a0f994`
- [ ] Full DATABASE readiness and all five hosted guard suites pass in the native Finish; no exit criterion is marked met.

## Execution Log

None.

## Verification Notes

None.


### 2026-11-22 — Gate 1 approval recorded

DELEGATED Original Gate 1 for CRM SPEC-331 only under DEC-02 and Batch 6 PLAN section 2 run mode 2 as redefined by the owner on 2026-11-21 (owner-2026-11-21-run-modes-redefined.txt, SHA-256 35E35600BB9D2D69EBF0A85BE8E6256260617F9A8B47F74A091565BC53AF69DD), continuing Batch 6 under the owner OD-9 decision of 2026-11-22 (SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D). Exact Draft SHA-256 3916118680FC141BE30551E27E0283D68F127472467A9262B69487CE3EEEF43D, Git blob d7707769fc4c0ccba5df8e3baf0b50255063762d, CRM baseline 23be9e2. Native isolated Approve f10a90f and implement 46ce248 passed with 5 committed blobs verified, and the native repository consistency on the sandbox final tree is CLEAN (sandbox-final-consistency.log SHA-256 BC67040154195AA3C470D80BBC40F7405D2D7BF0EAEB240E525D979C43D691D5). One pgTAP test and records; no migration, no Primary write. Gate 1 only. Immediately before allocation the hash, the Draft blob d7707769fc4c0ccba5df8e3baf0b50255063762d, all 4 source anchors, the baseline HEAD 23be9e2cee6e29ef8ffb5c751554a65651a0f994 against refreshed origin/main 23be9e2cee6e29ef8ffb5c751554a65651a0f994 and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 3cadeb7. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 23be9e2cee6e29ef8ffb5c751554a65651a0f994 (SPEC-330 Complete and released; main is 23be9e2cee6e29ef8ffb5c751554a65651a0f994).

Authority: DELEGATED under the Workbench Batch 6 run mode 2 record, answered by the constitution; never typed by the owner. The owner's words of 2026-11-22, Workbench `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D, direct Batch 6 to finish first; this contract grants nothing beyond that.

| Path | Baseline Git blob |
| --- | --- |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `dced60ebeefbe45fb56365039dba27b7018c0038` |
| `reports/master/MASTER_GAP_REGISTER.md` | `657998b4f24cac8845fa787d6bfd6364cfd0464a` |
| `reports/master/MASTER_SURFACE_DISPOSITION.md` | `f4fad84038b67bf00686d36e4a3c543314f68581` |
| `_ORVION_CANONICAL/manifest.md` | `643bee5fd1ad25b67c8819c6fe72da8c0da6d459` |
