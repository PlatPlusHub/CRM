# Change Request — SPEC-330

## Status

[ ] Draft
[x] Approved
[ ] In Progress
[ ] Complete
[ ] Cancelled

## Objective

Close the two remaining CRM `B6-EXIT` engineering readings that need a permanent check: re-measure RPC-1 under EC-2 and state the isolation basis of every public table under EC-3. One catalog-driven pgTAP test (Test 186) pins both. RPC-1 is resolved and leaves the Action Registry, and the cold-start guard suite plants its own F3 witness because no live member remains due at `B6-EXIT`.

## Business Reason

The registry at 790aa963f2b7dc8049a9dd691f54ed61d22e920f has one engineering obligation due at `B6-EXIT`: RPC-1, "its remaining permissions are re-measured under EC-2". EC-2 also asks for the RPC-1 remeasurement, and EC-3 asks for a stated isolation basis for every surface. Measured at 790aa963f2b7dc8049a9dd691f54ed61d22e920f (277 migrations), and identically on Platinum Primary read-only, 73 of the 77 permissions are named by an `app`/`public` function or an RLS predicate. The four that are not each have a reason: MANAGE_ROLES gates nothing because no member role may write the role matrix, and ACCESS_API_FULL, ACCESS_API_READ_ONLY and VIEW_ADVANCED_DASHBOARDS name surfaces that do not exist, and no role holds them. All 78 public tables have row-level security: 61 rest on the tenant predicate in every policy, 10 are reference data, 4 are platform-only and 3 are identity-owned. `anon` holds nothing. No check pins either fact, so a new unenforced permission or a table without a basis would pass unnoticed.

## Risks

A test that reads the live catalog could pass vacuously, or could freeze a weakness as accepted. Assertion 1 is a set equality, so a fifth unenforced permission fails it and closing one of the four must remove it. The ceiling can only shrink. The non-tenant bases are pinned by table name, and each basis is checked against grants and policies, so a reference table that gains a member write fails. Removing RPC-1 leaves no live member due at `B6-EXIT`, and that took away the cold-start suite's F3 witness (the suite reported 41 passed, 1 failed on this payload). F3 now moves PAY-9's open row to `B6-EXIT` inside its own mutation and keeps its exact assertion. This contract changes no migration, function, policy, grant or database object, and no exit criterion is marked met.

## Supersedes / Depends On

Extends the SPEC-329 reconciliation and the SPEC-325 fixture repair of the same suite. Uses the RPC-1 programme closures (SPEC-131/132 onward), SPEC-312 to SPEC-316 for the reference and identity surfaces, and the SPEC-316 HTTP cross-tenant evidence. Those terminal contracts are immutable.

## Write Scope

- `changes/SPEC-330-every-permission-is-enforced-and-every-table-states-its-isolation-basis.md`
- `supabase/tests/186_every_permission_is_enforced_and_every_table_states_its_isolation_basis_test.sql`
- `scripts/test_cold_start_state_guard.ps1`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `scripts/readiness_population.ps1`
- `scripts/readiness_selftest.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/check_agent_continuity.ps1`
- `.github/workflows/repository-consistency.yml`
- `supabase/config.toml`

Migrations, product code, any Primary write, Founder Secondary, frontend work, integration activation, email delivery and every owner decision are out of scope.

## Required Reading

- `CR_LIFECYCLE.md` sections 4–9.
- `reports/master/MASTER_EXECUTION_PLAN.md` Action Registry and the exit criteria EC-2 and EC-3.
- `reports/master/MASTER_GAP_REGISTER.md` RPC-1.
- `supabase/tests/01_rls_coverage_test.sql` (the catalog-driven precedent).
- `scripts/test_cold_start_state_guard.ps1` section F and CRM SPEC-325.

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

Pass 1 Design: One new pgTAP test, Test 186, read entirely from the catalog with no fixture, like Test 01. Assertions 1–3 pin RPC-1 to its four reasoned members. Assertions 4–11 state every public table's isolation basis (TENANT, REFERENCE, PLATFORM or IDENTITY), check each basis against its grants and policies, and confirm that `anon` holds nothing. The plan, register and manifest record the result, and the cold-start suite's F3 plants its own witness.

Pass 2 Adversarial Review: Applied in a rolled-back transaction, a mutation set (a new permission named nowhere, a reference table granted INSERT, a platform table given a `true` policy, a tenant table given a policy without the tenant predicate, an identity policy without `auth.uid()`, a table without row-level security and an `anon` SELECT grant) failed every one of the 11 assertions. The unmutated catalog passes all 11. F3's planted row exists only inside the mutated copy and is restored with the plan. The suite still requires the OVERDUE line at the probed REACHED boundary.

Pass 3 Evidence Refresh: 2026-11-22. In an isolated clone at 790aa963f2b7dc8049a9dd691f54ed61d22e920f carrying the payload:
- Test 186 passed 11 of 11 on the local stack (277 migrations).
- `readiness_population.ps1` reported REGISTRY complete, FUTURE-ONLY 57 and no COMPLETED member.
- Native repository consistency was CLEAN.
- All five hosted guard suites passed (19, 33, 13, 42 and 33 assertions, 0 failed).

Selected Version: SPEC-330; selected: one catalog-driven pgTAP test that pins RPC-1 to the four reasoned unenforced permissions and states every public table's isolation basis, with the plan, register and manifest records it settles and the F3 mutation witness planted instead of borrowed, the smallest change that closes the EC-2 remeasurement and the EC-3 basis without any database change

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| RPC-1 ceiling and table isolation bases | Full pgTAP suite and the `B6-EXIT` gate evaluation | WRITE | Test 186 adds 11 catalog assertions; the suite grows to 186 files and 3467 assertions. |
| RPC-1 registry row and register status | Action Registry, Check 29 and `readiness_population.ps1` | WRITE | RPC-1 is RESOLVED with its superseded text; the evaluator reports REGISTRY complete with no COMPLETED member. |
| EC-2 and EC-3 readings | Exit criteria | WRITE | They cite Test 186; no criterion is marked met. |
| Cold-start guard suite F3 | Hosted guard step "Attack the guards themselves" | WRITE | F3 plants PAY-9 at `B6-EXIT` inside its mutation; 42 passed, 0 failed. |
| Schema, grants, policies and API | Every product consumer | UNAFFECTED | No migration; the API contract has the same blob as the baseline. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: NONE

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Frozen source anchors and exact payloads | BEFORE_IMPLEMENTATION | NONE | NONE | NONE |
| Check 29 and the five hosted guard suites pass | BEFORE_COMPLETION | 3 | 2 | 6 |
| Full DATABASE readiness with Test 186 | BEFORE_COMPLETION | NONE | NONE | 6 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: The pgTAP suite and its catalog-driven precedent `supabase/tests/01_rls_coverage_test.sql`; `scripts/test_cold_start_state_guard.ps1` already attacks Check 29.

Added Property: Every permission is enforced by a function or an RLS predicate, or is one of four named and reasoned exceptions, and that set can only shrink. Every public table has row-level security and one stated isolation basis that its grants and policies satisfy, and `anon` holds nothing. F3 no longer depends on a live member staying due at `B6-EXIT`.

Causal Negative: At 790aa963f2b7dc8049a9dd691f54ed61d22e920f, adding a permission that is named nowhere, or a public table without a basis, passes the whole suite. RPC-1 stays a prose obligation with no check. With RPC-1 resolved, the unrepaired cold-start suite reports 41 passed and 1 failed (F3).

Positive Test Design: On the unmutated catalog Test 186 passes 11 of 11, and the restored records pass the guard after each cold-start mutation.

Negative Test Design: In a rolled-back transaction, each mutation fails its assertion: an unenforced permission, a role holding an absent-surface permission, a member write on the role matrix, a table without row-level security or basis, a tenant policy without the predicate, a reference write, a platform privilege or a non-false policy, an identity policy without `auth.uid()`, and an `anon` grant. F3 still requires the OVERDUE refusal.

Non-Empty Population Obligation: The catalog holds 77 permissions and 78 public tables, and the set equalities fail on an empty population. F3's planted PAY-9 row must exist (F-precondition).

Mutation Obligation: The mutation set above must fail all 11 assertions. Reverting F3 to the borrowed witness must reproduce 41 passed and 1 failed.

Post-Implementation Proof Obligation: The native Finish runs the full DATABASE protocol with Test 186 and all five hosted guard suites through Additional Verification with zero failures. Hosted preflight succeeds on the release candidate before any Promote.

## Implementation Steps

1. Check whether `supabase/tests/186_every_permission_is_enforced_and_every_table_states_its_isolation_basis_test.sql` contains `select plan(11);`; if so record Already Applied when its Git blob is 167a93e4abbb497b2856c323b193a449480489e3, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the catalog-driven RPC-1 ceiling and isolation basis test), and change nothing else:

   ```text
   -- pgTAP: Batch 6 exit -- every permission is enforced or carries its reason, and every table states its isolation basis.
   --
   -- Catalog-driven, like `01_rls_coverage_test.sql`: nothing below is a fixture, every assertion reads the live catalog,
   -- so a new permission, table or policy is judged the moment it exists.
   --
   -- RPC-1 (EC-2): the programme opened with 37 permissions enforced nowhere. Measured at `790aa96` (277 migrations), and
   --   identically on Platinum Primary, every one of the 77 permissions is named by an `app`/`public` function or an RLS
   --   predicate except four, each with a recorded reason:
   --     MANAGE_ROLES          -- the role matrix (`roles`, `permissions`, `role_permissions`) grants no member a write,
   --                              so there is no writable surface to charge it on; the absent grant is stronger than a check.
   --     ACCESS_API_FULL,
   --     ACCESS_API_READ_ONLY,
   --     VIEW_ADVANCED_DASHBOARDS -- the surfaces they name do not exist yet; no role holds them, so they grant nothing.
   --   Assertion 1 is a set equality: a fifth unenforced permission fails it, and closing one of the four must remove it
   --   here, so the ceiling can only shrink.
   --
   -- EC-3: every `public` table has row-level security, and its basis is one of four, pinned by name where it is not the
   --   tenant predicate:
   --     TENANT      -- every policy on the table names `current_tenant_id()`;
   --     REFERENCE   -- platform-owned reference data: members SELECT `true`, write nothing;
   --     PLATFORM    -- closed to every member (`false` policy, no privilege); only the platform's functions touch it;
   --     IDENTITY    -- owned by the signed-in identity: every policy names `auth.uid()`.
   --   `anon` holds no privilege on any `public` table.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(11);

   create temporary view t186_permission_use as
   with fsrc as (
     select string_agg(pg_get_functiondef(p.oid), E'\n') as src
       from pg_proc p join pg_namespace n on n.oid = p.pronamespace
      where n.nspname in ('app','public') and p.prokind in ('f','p')),
   psrc as (
     select string_agg(coalesce(qual,'') || ' ' || coalesce(with_check,''), E'\n') as src from pg_policies)
   select pe.key,
          position('''' || pe.key || '''' in fsrc.src) > 0 or position('''' || pe.key || '''' in psrc.src) > 0 as enforced
     from public.permissions pe, fsrc, psrc;

   create temporary view t186_basis as
   select c.relname::text as tbl,
          case
            when exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname
                           and coalesce(p.qual,'') || coalesce(p.with_check,'') like '%current_tenant_id%')
              then 'TENANT'
            when c.relname in ('catalog_types','countries','currencies','feature_entitlements','languages',
                               'nationalities','permissions','role_permissions','roles','subscription_plans')
              then 'REFERENCE'
            when c.relname in ('document_storage_findings','integration_cursors','scheduled_job_findings',
                               'tenant_license_activations')
              then 'PLATFORM'
            when c.relname in ('otp_challenges','totp_enrollments','trusted_devices')
              then 'IDENTITY'
            else 'NONE'
          end as basis
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p');

   -- 1. RPC-1 ceiling: exactly four permissions are enforced nowhere.
   select set_eq(
     $$select key from t186_permission_use where not enforced$$,
     $$values ('ACCESS_API_FULL'),('ACCESS_API_READ_ONLY'),('MANAGE_ROLES'),('VIEW_ADVANCED_DASHBOARDS')$$,
     'RPC-1: only the four reasoned permissions are enforced nowhere -- the set can only shrink');

   -- 2. The three that gate absent surfaces are held by no role.
   select is(
     (select count(*)::int from public.role_permissions rp join public.permissions pe on pe.id = rp.permission_id
       where pe.key in ('ACCESS_API_FULL','ACCESS_API_READ_ONLY','VIEW_ADVANCED_DASHBOARDS')),
     0,
     'RPC-1: no role holds a permission whose surface does not exist');

   -- 3. MANAGE_ROLES has no surface: no member may write the role matrix.
   select is(
     (select count(*)::int
        from unnest(array['roles','permissions','role_permissions']) t
        cross join unnest(array['authenticated','anon']) r
        cross join unnest(array['INSERT','UPDATE','DELETE','TRUNCATE']) pr
       where has_table_privilege(r, 'public.' || t, pr)),
     0,
     'RPC-1: no member role may write roles, permissions or role_permissions, so MANAGE_ROLES gates nothing');

   -- 4. Every public table has row-level security.
   select is(
     (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity),
     0,
     'EC-3: every public table has row-level security enabled');

   -- 5. Every table has a stated basis, and the named bases are exactly the seventeen that are not TENANT.
   select is(
     (select string_agg(tbl, ',' order by tbl) from t186_basis where basis = 'NONE'),
     null,
     'EC-3: every public table has a stated isolation basis');

   select set_eq(
     $$select tbl from t186_basis b where basis <> 'TENANT'
         and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = b.tbl
                           and coalesce(p.qual,'') || coalesce(p.with_check,'') like '%current_tenant_id%')$$,
     $$values ('catalog_types'),('countries'),('currencies'),('feature_entitlements'),('languages'),('nationalities'),
              ('permissions'),('role_permissions'),('roles'),('subscription_plans'),
              ('document_storage_findings'),('integration_cursors'),('scheduled_job_findings'),('tenant_license_activations'),
              ('otp_challenges'),('totp_enrollments'),('trusted_devices')$$,
     'EC-3: exactly seventeen tables rest on a basis other than the tenant predicate');

   -- 6. TENANT: no policy on a tenant table omits the tenant predicate (no permissive side door).
   select is(
     (select string_agg(p.tablename || '.' || p.policyname, ',' order by 1)
        from pg_policies p join t186_basis b on b.tbl = p.tablename
       where p.schemaname = 'public' and b.basis = 'TENANT'
         and coalesce(p.qual,'') || coalesce(p.with_check,'') not like '%current_tenant_id%'),
     null,
     'EC-3 TENANT: every policy on a tenant table names current_tenant_id()');

   -- 7. REFERENCE: members read, never write; every policy is a SELECT.
   select is(
     (select string_agg(b.tbl, ',' order by 1) from t186_basis b
       where b.basis = 'REFERENCE'
         and (not has_table_privilege('authenticated', 'public.' || b.tbl, 'SELECT')
              or has_table_privilege('authenticated', 'public.' || b.tbl, 'INSERT,UPDATE,DELETE,TRUNCATE')
              or exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = b.tbl and p.cmd <> 'SELECT'))),
     null,
     'EC-3 REFERENCE: members read platform reference data and write none of it');

   -- 8. PLATFORM: closed to every member.
   select is(
     (select string_agg(b.tbl, ',' order by 1) from t186_basis b
       where b.basis = 'PLATFORM'
         and (has_table_privilege('authenticated', 'public.' || b.tbl, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
              or exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = b.tbl
                           and (coalesce(p.qual,'false') <> 'false' or coalesce(p.with_check,'false') <> 'false')))),
     null,
     'EC-3 PLATFORM: platform-only tables grant no member any privilege and every policy is false');

   -- 9. IDENTITY: every policy binds the row to the signed-in identity.
   select is(
     (select string_agg(p.tablename || '.' || p.policyname, ',' order by 1)
        from pg_policies p join t186_basis b on b.tbl = p.tablename
       where p.schemaname = 'public' and b.basis = 'IDENTITY'
         and (coalesce(p.qual,'') not like '%auth.uid()%'
              or (p.cmd in ('ALL','INSERT','UPDATE') and coalesce(p.with_check,'') not like '%auth.uid()%'))),
     null,
     'EC-3 IDENTITY: every policy on an identity-owned table names auth.uid() on read and write');

   -- 10. anon holds nothing on any public table.
   select is(
     (select string_agg(c.relname, ',' order by 1) from pg_class c join pg_namespace n on n.oid = c.relnamespace
       where n.nspname = 'public' and c.relkind in ('r','p')
         and has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE')),
     null,
     'EC-3: anon holds no privilege on any public table');

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 167a93e4abbb497b2856c323b193a449480489e3.

2. Check whether `scripts/test_cold_start_state_guard.ps1` contains `The witness is planted, not borrowed`; if so record Already Applied when its Git blob is b36a1b40bccf9ec5a3b4a106f6356ea7e9108ffb, and otherwise stop and report. Otherwise make exactly this one edit (F3 plants its own open B6-EXIT member inside the mutation), each matched once, and change nothing else:

   a) replace the line
   ```text
       Write-S $PLAN $planOriginal.Replace('| Batch 6, this plan | NEXT |', '| Batch 6, this plan | REACHED 2026-10-12 probe |')
   ```
   with
   ```text
       # The witness is planted, not borrowed: once no live member is due at B6-EXIT (SPEC-330 resolved RPC-1, the
       # last), F3 must still prove the guard, so PAY-9's open row is moved to that boundary inside the mutation.
       Write-S $PLAN $planOriginal.Replace($payRow, $payRow.Replace('| `FIRST-BOOKING` |', '| `B6-EXIT` |')).Replace('| Batch 6, this plan | NEXT |', '| Batch 6, this plan | REACHED 2026-10-12 probe |')
   ```

   The resulting file's Git blob is b36a1b40bccf9ec5a3b4a106f6356ea7e9108ffb.

3. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Last updated: 2026-11-22 (CRM exit bundle E, SPEC-330.`; if so record Already Applied when its Git blob is dced60ebeefbe45fb56365039dba27b7018c0038, and otherwise stop and report. Otherwise make exactly these 5 edits (RPC-1 leaves the registry, the EC-2 and EC-3 readings cite Test 186, and the dated SPEC-330 header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-22 (CRM exit bundle D, SPEC-329. The exit evidence is reconciled at `30501ca` after bundles A to C: the Action registry prunes the eighteen members the register and the surface record have settled, OD-9 is recorded as decided by the owner (AFTER: FE-0 begins only after `B6-EXIT`), and the EC-2, EC-4 and EC-5 readings name what remains.)
   ```
   with
   ```text
   Last updated: 2026-11-22 (CRM exit bundle E, SPEC-330. Test 186 re-measures RPC-1 at `790aa96`: four permissions are enforced nowhere, each with its recorded reason, as a set that can only shrink, so RPC-1 is resolved and leaves the registry. It also states the isolation basis of every public table, and the EC-2 and EC-3 readings cite it.)

   Previously: 2026-11-22 (CRM exit bundle D, SPEC-329. The exit evidence is reconciled at `30501ca` after bundles A to C: the Action registry prunes the eighteen members the register and the surface record have settled, OD-9 is recorded as decided by the owner (AFTER: FE-0 begins only after `B6-EXIT`), and the EC-2, EC-4 and EC-5 readings name what remains.)
   ```

   b) replace the line
   ```text
   **CRM exit evidence at `30501ca`, reconciled 2026-11-22 (SPEC-329), after the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```
   with
   ```text
   **CRM exit evidence at `790aa96`, measured 2026-11-22 (SPEC-330, Test 186), after the reconciliation at `30501ca` (SPEC-329) and the reading at `28e9052` of 2026-11-19.** EC-1 is proven by Check 22 and the 78 recorded dispositions. EC-9 is proven by SPEC-316's Primary readback and matching repository/local/Primary parity at 271 migrations.
   ```

   c) replace the lines
   ```text
   - **EC-2 (partial):** Tests 57/58 carry 54/17/3. PAX-4 is fixed and STEPUP-1 is resolved for its `B6-EXIT` members (SPEC-320/324, Tests 58/130/183). Finish the per-writable-surface rationale and the RPC-1 permission remeasurement.
   - **EC-3 (partial):** SPEC-316 HTTP evidence covers cross-tenant denial for the paths it exercises. Provide a stated isolation basis for every surface, including the partial and platform-managed paths.
   ```
   with
   ```text
   - **EC-2 (members closed; confirmed at the gate evaluation):** Tests 57/58 carry 54/17/3, and `MASTER_SURFACE_DISPOSITION.md` states each writable surface's rationale. PAX-4 is fixed and STEPUP-1 is resolved for its `B6-EXIT` members (SPEC-320/324, Tests 58/130/183). RPC-1 is resolved by SPEC-330: Test 186 pins the four permissions enforced nowhere (MANAGE_ROLES, whose role matrix no member may write, and ACCESS_API_FULL, ACCESS_API_READ_ONLY and VIEW_ADVANCED_DASHBOARDS, whose surfaces do not exist and which no role holds) as a set that can only shrink.
   - **EC-3 (members closed; confirmed at the gate evaluation):** SPEC-316 HTTP evidence covers cross-tenant denial for the paths it exercises. Test 186 states the isolation basis of every public table from the catalog: all 78 have row-level security; 61 rest on the tenant predicate in every policy, 10 are reference data members read and never write, 4 are platform-only (no member privilege, `false` policies) and 3 are identity-owned (`auth.uid()` on read and write); `anon` holds no privilege on any of them. A new table without a basis fails it.
   ```

   d) replace the lines
   ```text
   | DC-3 | FUTURE-ONLY | engineering | `ENABLE-INVENTORY` | — | Concurrency control before inventory ships |
   | RPC-1 | FUTURE-ONLY | engineering | `B6-EXIT` | EC-2 | Its remaining permissions are re-measured under EC-2 |
   ```
   with
   ```text
   | DC-3 | FUTURE-ONLY | engineering | `ENABLE-INVENTORY` | — | Concurrency control before inventory ships |
   ```

   e) immediately after the lines
   ```text
   **Recorded exception, 2026-11-22, CRM exit bundle D.** After CRM SPEC-328 at `30501ca5f3d94862165898c3b7de86d84090b87b`, the owner decided OD-9 on 2026-11-22: AFTER, so FE-0 begins only after `B6-EXIT` and the app check profile is an engineering recommendation in FE-0's own Draft. SPEC-329 is record-only: it prunes the eighteen Action registry members that `scripts/readiness_population.ps1` derives as COMPLETED, records OD-9 as decided and removes its row, and restates the EC-2, EC-4 and EC-5 readings against the evidence of bundles A to C. It changes no migration, test or database object and closes no obligation by itself. EC-2's rationale and RPC-1, and EC-3, EC-6, EC-7, EC-8, EC-10 and EC-11, keep their recorded work. The Original and release gates remain enforced.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-22, CRM exit bundle E.** After CRM SPEC-329 at `790aa963f2b7dc8049a9dd691f54ed61d22e920f`, the Batch 6 run mode 2 delegation continues to `B6-EXIT`. SPEC-330 adds Test 186, read entirely from the catalog with no fixture: RPC-1 is re-measured to the four permissions enforced nowhere, each with its recorded reason, and every public table states its isolation basis. RPC-1 is resolved and its registry row removed; the EC-2 and EC-3 readings cite Test 186. It changes no migration or database object. EC-6, EC-7, EC-8, EC-10 and EC-11 keep their recorded work, and the Original and release gates remain enforced.

   ```

   The resulting file's Git blob is dced60ebeefbe45fb56365039dba27b7018c0038.

4. Check whether `reports/master/MASTER_GAP_REGISTER.md` contains `CRM SPEC-330 resolves RPC-1`; if so record Already Applied when its Git blob is 657998b4f24cac8845fa787d6bfd6364cfd0464a, and otherwise stop and report. Otherwise make exactly these 2 edits (RPC-1 resolved with its superseded text, and the dated header), each matched once, and change nothing else:

   a) replace the line
   ```text
   Last updated: 2026-11-22 (CRM SPEC-329 records OD-9 as decided by the owner: AFTER. FE-0 begins only after `B6-EXIT`; APP-1's sequencing follows it. No finding changes status otherwise.)
   ```
   with
   ```text
   Last updated: 2026-11-22 (CRM SPEC-330 resolves RPC-1: Test 186 re-measures it to four permissions enforced nowhere, each with its recorded reason, as a set that can only shrink. No other finding changes status.)

   Previously: 2026-11-22 (CRM SPEC-329 records OD-9 as decided by the owner: AFTER. FE-0 begins only after `B6-EXIT`; APP-1's sequencing follows it. No finding changes status otherwise.)
   ```

   b) replace the line
   ```text
   | RPC-1 | **35 of 72 tables had no RPC write path.** For those, a direct PostgREST write was the ONLY path - no app.authorize(), no state-machine validation, no event. **Decisive evidence this is an implementation gap, not a design choice: 37 of 69 seeded permissions were enforced NOWHERE**, mapping exactly onto the entities missing RPCs. **No business decision blocks it** - canon 26 already defines every affected lifecycle | architecture | High | R | 5+ | A | + | **OPEN - programme underway, 10 of 37 permissions closed (37 to 27).** SPEC-131 delivered Tasks; SPEC-132 delivered the customer-service domain (SEND_MESSAGE, CLOSE_CONVERSATION, ESCALATE_CONVERSATION, CREATE_COMPLAINT, RESOLVE_COMPLAINT, CREATE_SERVICE_REQUEST, RESOLVE_SERVICE_REQUEST) plus the end-to-end employee walkthrough test. **Remaining 27, all determinable from canon except those in RPC-2:** exchange rates, subscriptions, approval review, lead reassignment, booking-item costing, platform admin, the API-scope pair, the system-set task_overdue sweep, and 14 VIEW_* read-scope permissions which belong to AUDIT-3 rather than to a write path | engineering: continue entity by entity, following SPEC-131/132 | health-gate-2-2026-08-21 | 08-21 | 08-21 |
   ```
   with
   ```text
   | RPC-1 | **35 of 72 tables had no RPC write path.** For those, a direct PostgREST write was the ONLY path - no app.authorize(), no state-machine validation, no event. **Decisive evidence this is an implementation gap, not a design choice: 37 of 69 seeded permissions were enforced NOWHERE**, mapping exactly onto the entities missing RPCs. **No business decision blocks it** - canon 26 already defines every affected lifecycle | architecture | High | R | 5+ | A | + | **RESOLVED 2026-11-22 (CRM SPEC-330, Test 186).** Re-measured at `790aa96` (277 migrations) and identically on Platinum Primary: 73 of the 77 permissions are named by an `app`/`public` function or an RLS predicate. The four that are not carry their reason: MANAGE_ROLES gates nothing because no member role may write `roles`, `permissions` or `role_permissions`; ACCESS_API_FULL, ACCESS_API_READ_ONLY and VIEW_ADVANCED_DASHBOARDS name surfaces that do not exist and no role holds them. Test 186 pins the four as a set equality, so a fifth unenforced permission fails it and closing one must remove it. **Superseded text:** OPEN - programme underway, 10 of 37 permissions closed (37 to 27). SPEC-131 delivered Tasks; SPEC-132 delivered the customer-service domain (SEND_MESSAGE, CLOSE_CONVERSATION, ESCALATE_CONVERSATION, CREATE_COMPLAINT, RESOLVE_COMPLAINT, CREATE_SERVICE_REQUEST, RESOLVE_SERVICE_REQUEST) plus the end-to-end employee walkthrough test. **Remaining 27, all determinable from canon except those in RPC-2:** exchange rates, subscriptions, approval review, lead reassignment, booking-item costing, platform admin, the API-scope pair, the system-set task_overdue sweep, and 14 VIEW_* read-scope permissions which belong to AUDIT-3 rather than to a write path | resolved; a new unenforced permission fails Test 186 | health-gate-2-2026-08-21 | 08-21 | 11-22 |
   ```

   The resulting file's Git blob is 657998b4f24cac8845fa787d6bfd6364cfd0464a.

5. Check whether `_ORVION_CANONICAL/manifest.md` contains `Suite **186 files / 3467 assertions**.`; if so record Already Applied when its Git blob is 85e19acf8ccc3845109d9a60de893d1fa2e4e700, and otherwise stop and report. Otherwise make exactly this one edit (the measured suite figure), each matched once, and change nothing else:

   a) replace the line
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **185 files / 3456 assertions**.
   ```
   with
   ```text
   Live state: **Repository, local stack and Platinum Primary `vrvtsxexkiiiivlkdxzp` at 277 migrations** (latest `20261122100000`), ledger `7d224a770526c87f171b9525b0817701`. full-function-surface hash `ca519b79e522cff13cd309456f618a14` (358 functions), structural-surface hash `0bb1e5b10e0bde5bd344f706366150ee` (3,204 objects). All ten surfaces match. Ledger read FROM Primary 2026-11-22. **80 client RPCs**. Suite **186 files / 3467 assertions**.
   ```

   The resulting file's Git blob is 85e19acf8ccc3845109d9a60de893d1fa2e4e700.

6. **Establish readiness and verify.** Run the native DATABASE readiness: full SQL tests at 277 migrations with 186 files and 3467 assertions including Test 186 at 11 of 11, smoke and HTTP, and API generation with the API contract unchanged. Run the native repository guard and the five hosted guard suites named in Additional Verification. Confirm that `readiness_population.ps1` reports REGISTRY complete with no COMPLETED member and RPC-1 absent from the registry. Confirm the exact scope and `git diff --check`. Make no Primary write. Synchronize the contract and native discovery artifacts, set Runtime Checkpoint DONE and commit the implementation. Native timed Finish, Review, Complete and release follow under their own authority. At native completion set `Last Completed: **SPEC-330: Every permission is enforced and every table states its isolation basis.**` via the normal lifecycle.

## Acceptance Criteria

- [ ] Test 186 pins the RPC-1 ceiling and every table's isolation basis. `check: blob supabase/tests/186_every_permission_is_enforced_and_every_table_states_its_isolation_basis_test.sql 167a93e4abbb497b2856c323b193a449480489e3`
- [ ] F3 plants its own `B6-EXIT` witness and keeps its assertion. `check: blob scripts/test_cold_start_state_guard.ps1 b36a1b40bccf9ec5a3b4a106f6356ea7e9108ffb`
- [ ] The plan removes RPC-1 from the registry and the EC-2 and EC-3 readings cite Test 186. `check: blob reports/master/MASTER_EXECUTION_PLAN.md dced60ebeefbe45fb56365039dba27b7018c0038`
- [ ] The register records RPC-1 as resolved with its superseded text. `check: blob reports/master/MASTER_GAP_REGISTER.md 657998b4f24cac8845fa787d6bfd6364cfd0464a`
- [ ] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **186 files / 3467 assertions**"`
- [ ] The API contract is unchanged. `check: same reports/master/MASTER_API_CONTRACT.md @790aa963f2b7dc8049a9dd691f54ed61d22e920f`
- [ ] The surface dispositions are preserved. `check: same reports/master/MASTER_SURFACE_DISPOSITION.md @790aa963f2b7dc8049a9dd691f54ed61d22e920f`
- [ ] The registry evaluator is preserved. `check: same scripts/readiness_population.ps1 @790aa963f2b7dc8049a9dd691f54ed61d22e920f`
- [ ] The repository guard is preserved. `check: same scripts/check_repository_consistency.ps1 @790aa963f2b7dc8049a9dd691f54ed61d22e920f`
- [ ] The native evaluator is preserved. `check: same scripts/check_agent_continuity.ps1 @790aa963f2b7dc8049a9dd691f54ed61d22e920f`
- [ ] Full DATABASE readiness and all five hosted guard suites pass in the native Finish; no exit criterion is marked met.

## Execution Log

None.

## Verification Notes

None.


### 2026-11-22 — Gate 1 approval recorded

DELEGATED Original Gate 1 for CRM SPEC-330 only under DEC-02 and Batch 6 PLAN section 2 run mode 2 as redefined by the owner on 2026-11-21 (owner-2026-11-21-run-modes-redefined.txt, SHA-256 35E35600BB9D2D69EBF0A85BE8E6256260617F9A8B47F74A091565BC53AF69DD), continuing Batch 6 under the owner OD-9 decision of 2026-11-22 (SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D). Exact Draft SHA-256 DF4F4B38FE49E97EDEB89460839B0AC17A530CF681395058CBA4D9023587CDEF, Git blob 0e4713a81c95a17e391bad7423e8df433fa9dda4, CRM baseline 790aa96. Native isolated Approve c922cf9 and implement 05197b1 passed with 5 committed blobs verified, and the native repository consistency on the sandbox final tree is CLEAN (sandbox-final-consistency.log SHA-256 9300211AA1D4D9E02211544A9093539F3D35A415DEF12A2702C5B9E67FF2E0BE). One pgTAP test and records; no migration, no Primary write. Gate 1 only. Immediately before allocation the hash, the Draft blob 0e4713a81c95a17e391bad7423e8df433fa9dda4, all 4 source anchors, the baseline HEAD 790aa963f2b7dc8049a9dd691f54ed61d22e920f against refreshed origin/main 790aa963f2b7dc8049a9dd691f54ed61d22e920f and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as f8cee99. No implementation performed before this transition.

## Review Gate

- [ ] Every change matches the accepted implementation steps.
- [ ] All changed paths are within Write Scope.
- [ ] Every acceptance criterion is confirmed by local evidence.
- [ ] Native Finish evidence and independent Review are present.

## Notes

Baseline: 790aa963f2b7dc8049a9dd691f54ed61d22e920f (SPEC-329 Complete and released; main is 790aa963f2b7dc8049a9dd691f54ed61d22e920f).

Authority: DELEGATED under the Workbench Batch 6 run mode 2 record, answered by the constitution; never typed by the owner. The owner's words of 2026-11-22, Workbench `data/records/batch6/owner-words/owner-2026-11-22-od9-after-and-decision-responsibility.txt`, SHA-256 1A7B5647FA270EBB6E514414C2FF6E1D88E6D81872733B196797318BDDA9920D, direct Batch 6 to finish first; this contract grants nothing beyond that.

| Path | Baseline Git blob |
| --- | --- |
| `scripts/test_cold_start_state_guard.ps1` | `2ddd674cc7b372c0a74e5997bfee206570f2f49d` |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `9a2c647c9ba24676c5dbf55c82e53b0c710ac8cc` |
| `reports/master/MASTER_GAP_REGISTER.md` | `3c670c12a0e9adcabdd364cae99bb5dbf72cc83b` |
| `_ORVION_CANONICAL/manifest.md` | `7a726dde58f33b968bd8fa490fd0312f3749e1d3` |
