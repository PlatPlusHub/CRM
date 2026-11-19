# Change Request — SPEC-319

## Status

[ ] Draft
[ ] Approved
[ ] In Progress
[x] Complete
[ ] Cancelled

## Objective

Apply the existing archive authority when creating a CRM booking, passenger, supplier or task. Require archive metadata on signed-in creation to come from the server, including the existing customer path.

## Business Reason

The native Batch 6 selector returns zero unrecorded surfaces. The action registry explicitly points bookings, passengers, suppliers and tasks at ARCH-2. The isolated certified baseline reproduced missing permission checks and forged attribution on each of the four. The existing customers binding denied unauthorized archived creation and still accepted an active row with caller-supplied archive metadata. The four target tables have the same authority and metadata columns, existing update trigger, release boundary and native proof. The selector exception records that decision.

## Risks

The existing SECURITY DEFINER function retains its owner, privileges and pinned search path. The UPDATE branch and applicable workflow guards retain their behavior. Session-less import behavior is preserved. Inspect attended lock risk for all four tables before Primary deployment. Do not modify existing business rows. Verify that the 80 exposed RPCs and grants keep the same API and that an ordinary employee journey reaches all affected creation routines.

## Supersedes / Depends On

Depends on SPEC-317, SPEC-318, CUST-11, SPEC-215 and SPEC-230. It replaces only the two open archive-at-entry assertions in Test 134.

## Write Scope

- `changes/SPEC-319-archive-authority-applies-at-entry.md`
- `supabase/migrations/20261119203357_archive_authority_applies_at_entry.sql`
- `supabase/tests/134_task_queue_authority_test.sql`
- `supabase/tests/182_archive_authority_applies_at_entry_test.sql`
- `reports/master/MASTER_EXECUTION_PLAN.md`
- `reports/master/MASTER_GAP_REGISTER.md`
- `reports/master/MASTER_SURFACE_DISPOSITION.md`
- `reports/master/MASTER_API_CONTRACT.md`
- `reports/evidence/primary-ledger-evidence.json`
- `_ORVION_CANONICAL/manifest.md`
- `ai-map.json`
- `repository-index.md`

## Out of Scope — Files Forbidden to Modify

- `supabase/config.toml`
- `scripts/check_agent_continuity.ps1`
- `scripts/check_repository_consistency.ps1`
- `scripts/batch6_select_target.ps1`
- `scripts/readiness_population.ps1`
- `_ORVION_CANONICAL/28_permissions_matrix.md`
- `_ORVION_CANONICAL/32_execution_roadmap.md`

Every other product path and migration is out of scope. Keep the existing gates for Founder Secondary, integrations, accounting, legal and owner decisions. Leads, invoices, quotations and booking items keep their existing ARCH-2 assessment or repair obligations. Previously recorded customer-note policy and stricter entry rules for documents, service requests and complaints retain their existing bindings.

## Required Reading

- `CR_LIFECYCLE.md` §§4–9 and `ENGINEERING_METHOD.md` §§2 and 5.
- `_ORVION_CANONICAL/28_permissions_matrix.md` and migration `20260909114354_customers_slice11_closure.sql`.
- `reports/master/MASTER_EXECUTION_PLAN.md` Batch 6 action registry, ARCH-2 and recorded selector exceptions.
- `reports/master/MASTER_GAP_REGISTER.md` ARCH-2 and the four affected exit surface dispositions.
- `supabase/tests/33_archive_authority_test.sql`, `supabase/tests/111_customer_surface_test.sql` and `supabase/tests/134_task_queue_authority_test.sql`.

## Runtime Checkpoint

Resume Step: DONE
Blocker: None
Recovery Attempt: 0

## Required Capabilities

- docker
- supabase-local
- supabase-primary
- github

## Additional Verification

- `pwsh -NoProfile -File scripts/verify_api_end_to_end.ps1`

## Pre-Approval Evidence

Change Class: Significant

### Draft Assurance

Pass 1 Design: Reuse app.enforce_archive_authority for signed-in INSERT through the existing bookings, passengers, suppliers and tasks triggers. Add the active-row metadata check to the common INSERT branch and preserve existing UPDATE, session-less and stricter workflow rules. Use one migration with a shared test and update the task witness in place.

Pass 2 Adversarial Review: Test 182 runs each selected table with an authenticated creator who lacks ARCHIVE_RECORD, then a holder of the permission, with tenant, branch, ownership, active subscription and matching MFA so the finding can be isolated. The baseline failed 17 assertions: four archived-insert denials, four standalone-reason denials, five active-row metadata denials and four instances of server attribution. Existing customer authority and legitimate entry serve as controls. Full-suite and HTTP proofs check other write paths, including booking and passenger RPCs. Existing archived rows and the established trusted import boundary are outside the write.

Pass 3 Evidence Refresh: 2026-11-19. Using certified baseline 243fd86c53715a4eb69f02e97353cfa2ad90ea8e, the isolated prototype passed 182 pgTAP files and 3381 assertions including Tests 33, 111, 134 and 182, the database smoke and 35 HTTP assertions with process exit 0. The API contract re-generated with an identical Git-normalized blob. Local ledger: 273, latest 20261119203357, fingerprint 68c065e6e3a2ea0fe8f5c55277220a0f. The measured local parity delta is one function body and four existing trigger definitions; function count 352, structural object count 3188. The rollback-only negative proved an enabled INSERT trigger can be removed from the catalog predicate and is restored. Platinum Primary must be measured independently at Step 5.

Selected Version: SPEC-319; selected: one existing authority, four widened INSERT bindings and one existing customer-binding correction, proven at each table in one suite

### Consumer Closure

Applicability: APPLICABLE

| Changed fact or surface | Relevant consumer | Disposition | Evidence / preserved behavior |
| --- | --- | --- | --- |
| Creation and archive authority | public.bookings, public.passengers, public.suppliers, public.tasks and their creation RPCs | WRITE | Uses the same archive authority and actor/time attribution as UPDATE. Test 182 proves ordinary creation, unauthorized archive/reason/metadata and privileged stamps on each path. Existing SQL and HTTP fixtures verify RPCs. |
| Active-row archive metadata | Existing public.customers INSERT binding | WRITE | Preserve permission-positive/negative behavior and privileged stamps. Refuse active-row caller stamps. Test 182 and the existing customer suite verify. |
| Existing archive UPDATE | All thirteen existing bindings | VERIFY | Preserve byte-identical UPDATE branch, ACL and row behavior. Test 33 and other native tests run. |
| Batch 6 action registry, ARCH-2 and surface disposition | Execution plan, gap register, four exit surface rows and customers | WRITE | Record one selector exception, exact evidence for five surfaces, suppliers and tasks AUDITED after successful Primary proof, bookings and passengers AUDITED-OPEN, and ARCH-2 OPEN pending its remaining member work. The registry derives the two completed rows and fifteen due obligations. |
| API, parity and discovery | API contract, Primary evidence, manifest and generated discovery | WRITE | Verify unchanged API blob. Refresh exact Primary/local evidence and native discovery. |
| Next capability and boundary | Boot, Batch 6 governance, catalog and permission models | UNAFFECTED | Keep constitutional gates, the 78 recorded surfaces and the established exit criteria. |

Unresolved Material Consumers: None

### Execution-Boundary Satisfiability

Applicability: APPLICABLE

Irreversible Action Step: Step 6 (Platinum Primary deployment)

| Invariant | Required At | Red Opens After Step | Restored By Step | Mandatory Gate Before Step |
| --- | --- | --- | --- | --- |
| Exact approved payload, functional proof, fresh Primary identity and recovery evidence | BEFORE_IRREVERSIBLE_ACTION | NONE | NONE | Step 5 |
| Recorded ledger matches the actual Primary ledger | BEFORE_COMPLETION | Step 1 | Step 7 | Step 8 |
| Repository/local migration figures and test figures match the prepared payload | BEFORE_IRREVERSIBLE_ACTION | Step 1 | Step 5 | Step 6 |
| Generated evidence and unified Live state match the deployed implementation | BEFORE_COMPLETION | Step 6 | Step 7 | Step 8 |

### Permanent-Control Admission

Applicability: APPLICABLE

Existing Mechanism Reusable: YES

Existing Mechanism: app.enforce_archive_authority shares ARCHIVE_RECORD, actor attribution and security-definer behavior across thirteen existing trigger bindings, with five INSERT bindings after repair.

Added Property: Every selected signed-in creator needs ARCHIVE_RECORD when supplying an archive state or reason, may not supply actor or time on an active row, and receives server time and actor on an archived row.

Causal Negative: Test 182 against the unmodified certified baseline failed the exact seventeen assertions. Test 134 already recorded the task consequence.

Positive Test Design: Test 182 uses the same eligible creator for ordinary active inserts and an archive-capable owner for archived inserts, then reads the authoritative metadata. Native verification exercises existing RPCs and update controls.

Negative Test Design: Test 182 requires SQLSTATE 42501 with the expected permission or server metadata message. Test 134 separately proves that the refused task was not stored.

Non-Empty Population Obligation: The test creates authenticated eligible actors, an active tenant, the shared branch and department, and genuine successful active and archived writes for every tested surface.

Mutation Obligation: A rollback-only isolated check proves the enabled INSERT trigger predicate fails when the selected trigger is disabled, then passes after restore. The pre-repair full causal negative is saved independently.

Post-Implementation Proof Obligation: Match the transmitted migration, independent Primary schema and ledger, five intended INSERT bindings and unchanged counts. Run required tests and native Finish and Review. Keep unresolved surfaces and findings on their existing triggers.

## Implementation Steps

1. Check whether `supabase/migrations/20261119203357_archive_authority_applies_at_entry.sql` contains `-- ARCH-2: extend the existing archive authority`; if so record Already Applied when its Git blob is ec8e125c0b20c282cacaad51d1a05a429039aaaf, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the shared archive-at-creation authority migration), and change nothing else:

   ```text
   -- ARCH-2: extend the existing archive authority to creation on four CRM surfaces.

   create or replace function app.enforce_archive_authority()
   returns trigger language plpgsql security definer set search_path = '' as $$
   declare v_permission text; v_actor uuid;
   begin
       if (select auth.uid()) is null then return new; end if;
       if tg_op='INSERT' then
           if not new.is_archived
              and (new.archived_at is not null or new.archived_by is not null) then
               raise exception 'archive metadata is set by the server' using errcode='42501';
           end if;
           if new.is_archived or new.archive_reason is not null then
               v_permission:=case when tg_table_name='documents' then 'ARCHIVE_DOCUMENT' else 'ARCHIVE_RECORD' end;
               perform app.authorize(v_permission);
               v_actor:=app.current_user_id();
               if new.is_archived then new.archived_at:=now(); new.archived_by:=v_actor; end if;
           end if;
           return new;
       end if;
       if tg_op='UPDATE' and new.is_archived is not distinct from old.is_archived
          and (new.archived_at is distinct from old.archived_at
               or new.archived_by is distinct from old.archived_by) then
           raise exception 'archive metadata is immutable once the archive state is set' using errcode='42501';
       end if;
       -- Reason is caller-authored, unlike the server-stamped time/actor. Corrections remain
       -- possible, but cost the archive capability even when the boolean does not change.
       if new.is_archived is not distinct from old.is_archived then
           if new.archive_reason is distinct from old.archive_reason then
               perform app.authorize(case when tg_table_name='documents' then 'ARCHIVE_DOCUMENT' else 'ARCHIVE_RECORD' end);
           end if;
           return new;
       end if;
       v_permission:=case when tg_table_name='documents' then 'ARCHIVE_DOCUMENT' else 'ARCHIVE_RECORD' end;
       perform app.authorize(v_permission);
       v_actor:=app.current_user_id();
       if new.is_archived then new.archived_at:=now(); new.archived_by:=v_actor;
       else new.archived_at:=null; new.archived_by:=null; end if;
       return new;
   end; $$;

   create or replace trigger bookings_enforce_archive_authority
   before insert or update on public.bookings
   for each row execute function app.enforce_archive_authority();

   create or replace trigger passengers_enforce_archive_authority
   before insert or update on public.passengers
   for each row execute function app.enforce_archive_authority();

   create or replace trigger suppliers_enforce_archive_authority
   before insert or update on public.suppliers
   for each row execute function app.enforce_archive_authority();

   create or replace trigger tasks_enforce_archive_authority
   before insert or update on public.tasks
   for each row execute function app.enforce_archive_authority();
   ```

   The resulting file's Git blob is ec8e125c0b20c282cacaad51d1a05a429039aaaf.

2. Check whether `supabase/tests/134_task_queue_authority_test.sql` contains `the rejected archived task was not stored`; if so record Already Applied when its Git blob is a8c0ef7d4a916bfbcef68668691b4028a0d8c27a, and otherwise stop and report. Otherwise make exactly these 4 edits (the bounded task queue test update), each matched once, and change nothing else:

   a) replace the line
   ```text
   -- The ARCH-2 assertions retain the pending archive-at-entry evidence.
   ```
   with
   ```text
   -- The ARCH-2 assertions cover refused archive-at-entry and absence of the rejected task.
   ```

   b) replace the line
   ```text
   select lives_ok($$insert into public.tasks (id,tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title,
   ```
   with
   ```text
   select throws_ok($$insert into public.tasks (id,tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title,
   ```

   c) replace the line
   ```text
     'OPEN ARCH-2: the employee without ARCHIVE_RECORD still creates a task born archived');
   ```
   with
   ```text
     '42501','permission denied: ARCHIVE_RECORD',
     'ARCH-2: an employee without ARCHIVE_RECORD cannot create an archived task');
   ```

   d) replace the lines
   ```text
   select is((select archived_by::text || ':' || archived_at::date::text from public.tasks where id = '13400000-0000-0000-0000-0000000000f2'),
     '13400000-0000-0000-0000-000000000011:2020-01-01',
     'OPEN ARCH-2: it names the owner as archiver at a caller-authored time');
   ```
   with
   ```text
   select is((select count(*)::int from public.tasks where id = '13400000-0000-0000-0000-0000000000f2'), 0,
     'ARCH-2: the rejected archived task was not stored');
   ```

   The resulting file's Git blob is a8c0ef7d4a916bfbcef68668691b4028a0d8c27a.

3. Check whether `supabase/tests/182_archive_authority_applies_at_entry_test.sql` contains `select plan(32);`; if so record Already Applied when its Git blob is 5ffffdeb43e3ae777957cafbb35fac99fdbc2e48, and otherwise stop and report. Otherwise create this file with exactly the following UTF-8 content and one final newline (the five-surface regression test), and change nothing else:

   ```text
   -- ARCH-2: the same archive authority must govern entry on every selected surface.
   create extension if not exists pgtap with schema extensions;

   begin;
   select plan(32);

   insert into auth.users (id, email) values
       ('18200000-0000-0000-0000-0000000000a1', 'senior@archive.test'),
       ('18200000-0000-0000-0000-0000000000a2', 'owner@archive.test');
   insert into public.tenants (id, name, slug, status)
   values ('18200000-0000-0000-0000-000000000001', 'Archive entry test', 'archive-entry-test', 'active');
   insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
   select '18200000-0000-0000-0000-000000000001', id, 'active'
   from public.subscription_plans
   where plan_code = 'enterprise';
   insert into public.branches (id, tenant_id, name, slug)
   values ('18200000-0000-0000-0000-00000000000a', '18200000-0000-0000-0000-000000000001', 'Cairo', 'archive-entry-cairo');
   insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
   values ('18200000-0000-0000-0000-00000000000b', '18200000-0000-0000-0000-000000000001', '18200000-0000-0000-0000-00000000000a', 'sales', 'Sales');
   insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id)
   values
       ('18200000-0000-0000-0000-000000000011', '18200000-0000-0000-0000-000000000001', 'Senior', 'senior@archive.test', true, '18200000-0000-0000-0000-0000000000a1'),
       ('18200000-0000-0000-0000-000000000012', '18200000-0000-0000-0000-000000000001', 'Owner', 'owner@archive.test', true, '18200000-0000-0000-0000-0000000000a2');
   insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
   select tenant_id, id, '18200000-0000-0000-0000-00000000000a', '18200000-0000-0000-0000-00000000000b', true
   from public.users where tenant_id = '18200000-0000-0000-0000-000000000001';
   insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
   select '18200000-0000-0000-0000-000000000001', v.user_id, r.id, 'tenant'
   from (values
       ('18200000-0000-0000-0000-000000000011'::uuid, 'senior_employee'),
       ('18200000-0000-0000-0000-000000000012'::uuid, 'owner')
   ) v(user_id, role_code)
   join public.roles r on r.code = v.role_code;

   insert into public.customers (id, tenant_id, customer_type_code, full_name)
   values ('18200000-0000-0000-0000-0000000000c1', '18200000-0000-0000-0000-000000000001', 'person', 'Archive Test Customer');

   -- Same archive inputs on each real entry shape. The task fixture stays in the allowed open state.
   create temporary table archive_entry_cases (surface text primary key, statement text not null);
   insert into archive_entry_cases values
       ('bookings', $sql$insert into public.bookings
           (id, tenant_id, branch_id, department_id, customer_id, owner_user_id, owner_branch_id,
            owner_department_id, booking_status_code, title, booking_reference, is_archived, archive_reason, archived_at, archived_by)
           values (%1$L, '18200000-0000-0000-0000-000000000001', '18200000-0000-0000-0000-00000000000a',
            '18200000-0000-0000-0000-00000000000b', '18200000-0000-0000-0000-0000000000c1',
            app.current_user_id(), '18200000-0000-0000-0000-00000000000a', '18200000-0000-0000-0000-00000000000b',
            'draft', 'Archive entry booking', %1$L, %2$L, %3$L, %4$L, %5$L)$sql$),
       ('customers', $sql$insert into public.customers
           (id, tenant_id, customer_type_code, full_name, is_archived, archive_reason, archived_at, archived_by)
           values (%1$L, '18200000-0000-0000-0000-000000000001', 'person', 'Archive entry customer', %2$L, %3$L, %4$L, %5$L)$sql$),
       ('passengers', $sql$insert into public.passengers
           (id, tenant_id, first_name, family_name, full_name, passenger_type_code, is_archived, archive_reason, archived_at, archived_by)
           values (%1$L, '18200000-0000-0000-0000-000000000001', 'Archive', 'Passenger', 'Archive Passenger',
            'adult', %2$L, %3$L, %4$L, %5$L)$sql$),
       ('suppliers', $sql$insert into public.suppliers
           (id, tenant_id, name, supplier_type_code, is_archived, archive_reason, archived_at, archived_by)
           values (%1$L, '18200000-0000-0000-0000-000000000001', 'Archive entry supplier ' || %1$L,
            'airline', %2$L, %3$L, %4$L, %5$L)$sql$),
       ('tasks', $sql$insert into public.tasks
           (id, tenant_id, owner_user_id, owner_department_id, owner_branch_id, task_type_code, task_status_code, title,
            is_archived, archive_reason, archived_at, archived_by)
           values (%1$L, '18200000-0000-0000-0000-000000000001', app.current_user_id(),
            '18200000-0000-0000-0000-00000000000b', '18200000-0000-0000-0000-00000000000a', 'follow_up', 'open',
            'Archive entry task', %2$L, %3$L, %4$L, %5$L)$sql$);
   grant select on archive_entry_cases to authenticated;

   select set_config('request.jwt.claims','{"sub":"18200000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
   set local role authenticated;
   select ok(app.has_permission('ASSIGN_SUPPLIER') and app.has_permission('CREATE_BOOKING')
             and app.has_permission('CREATE_BOOKING_ITEM') and app.has_permission('CREATE_TASK')
             and app.has_permission('CREATE_CUSTOMER') and not app.has_permission('ARCHIVE_RECORD'),
             'senior can create on all selected paths and has no archive authority');
   select lives_ok(format(statement, '18200000-0000-0000-0000-000000000101', false, null, null, null),
                   surface || ': ordinary creation succeeds') from archive_entry_cases order by surface;
   select throws_ok(format(statement, '18200000-0000-0000-0000-000000000102', true, 'reported', null, null),
                    '42501', 'permission denied: ARCHIVE_RECORD',
                    surface || ': creating archived requires archive authority') from archive_entry_cases order by surface;
   select throws_ok(format(statement, '18200000-0000-0000-0000-000000000103', false, 'reported', null, null),
                    '42501', 'permission denied: ARCHIVE_RECORD',
                    surface || ': an archive reason alone requires archive authority') from archive_entry_cases order by surface;
   select throws_ok(format(statement, '18200000-0000-0000-0000-000000000104', false, null, '2020-01-01',
                     '18200000-0000-0000-0000-000000000012'),
                    '42501', 'archive metadata is set by the server',
                    surface || ': an active row cannot claim archive metadata') from archive_entry_cases order by surface;

   select set_config('request.jwt.claims','{"sub":"18200000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
   select ok(app.has_permission('ARCHIVE_RECORD'), 'owner holds archive authority');
   select lives_ok(format(statement, '18200000-0000-0000-0000-000000000105', true, 'approved', '2020-01-01',
                    '18200000-0000-0000-0000-000000000011'),
                   surface || ': authorized creation may archive and supply a reason') from archive_entry_cases order by surface;
   reset role;

   select results_eq(
       format('select is_archived, archive_reason, archived_at = now(), archived_by from public.%I where id = %L',
              surface, '18200000-0000-0000-0000-000000000105'),
       $$values (true, 'approved'::text, true, '18200000-0000-0000-0000-000000000012'::uuid)$$,
       surface || ': archived actor and time come from the server'
   ) from archive_entry_cases order by surface;

   select * from finish();
   rollback;
   ```

   The resulting file's Git blob is 5ffffdeb43e3ae777957cafbb35fac99fdbc2e48.

4. Check whether `reports/master/MASTER_EXECUTION_PLAN.md` contains `Recorded exception, 2026-11-19, CRM archive at entry`; if so record Already Applied when its Git blob is b7aa489315d5cf5618e45d3ad927ae6237d9b943, and otherwise stop and report. Otherwise make exactly this one edit (the current owner-authorized selector exception), each matched once, and change nothing else:

   a) immediately after the lines
   ```text
   **Recorded exception, 2026-11-19, CRM task entry.** After CRM SPEC-317 Remote Certify at `a17473dbe478a2c2268ce9c503bf6e4832b7affb`, the owner authorized bounded discovery and one next Draft because the native selector has zero unrecorded surfaces. SPEC-318 selects the proven task member of ENTRY-1, supported by SPEC-230 and Test 134. The task guard and regression tests share one insertion boundary. Campaign entry requires a material consequence and booking-item entry has a separate authorized lifecycle. ARCH-2 and STEPUP-1 retain their independent authority. This selection does not close an obligation. Original Gate 1 and Primary deployment authorization remain separate.

   ```
   insert
   ```text
   **Recorded exception, 2026-11-19, CRM archive at entry.** After CRM SPEC-318 Remote Certify at `243fd86c53715a4eb69f02e97353cfa2ad90ea8e`, the owner authorized one consolidated repair and continuous native execution because the selector has zero unrecorded surfaces. SPEC-319 selects the bookings, passengers, suppliers and tasks members of ARCH-2, which share the archive authority, and the active-row archive metadata check on the existing customers binding. Test 182 proves each selected effect on one isolated schema. Closure is evaluated after deployment. The Original, deployment and release gates remain enforced.

   ```

   The resulting file's Git blob is b7aa489315d5cf5618e45d3ad927ae6237d9b943.

5. **Establish readiness and the exact Primary preflight.** Run the native DATABASE readiness, including full SQL tests, HTTP and smoke, API generation and Git blob comparison. Verify 273 migrations, fingerprint `68c065e6e3a2ea0fe8f5c55277220a0f`, 182 files and 3381 assertions. Compare the catalog against the isolated and certified evidence. Verify four widened bindings, the unchanged customer binding, unchanged authority/ACL, and the expected function and trigger differences with all other parity signatures stable. Read live Primary project `vrvtsxexkiiiivlkdxzp`: require 272 migrations, latest 20261119112137, fingerprint `b2e617f87c56ee17dfab43629ce88609`, absent target and certified Primary parity. Preserve scoped baseline row counts, fresh lock evidence and the native exact-DDL and recovery prerequisites. Verify the tracked file Git blob, SHA-256 and the MD5 received by the intended connected Primary route.

   While these measurements agree, update only the manifest Live state on the uncommitted tree to the following:

   ```text
   Live state: SPEC-319 pre-deploy verification. **Repository and local stack at 273 migrations** (latest `20261119203357`), ledger `68c065e6e3a2ea0fe8f5c55277220a0f`. **Platinum Primary `vrvtsxexkiiiivlkdxzp` verified separately at 272 migrations**, with the target absent. Structural parity awaits Gate 2. **80 client RPCs**. Suite **182 files / 3381 assertions**.
   ```

   Require the unchanged consistency guard to report only the missing exact Primary row under RECOVER-1. In the isolated Sandbox, use native Approve and literal replay and check only this expected refusal. The real implementation commit and DONE belong after Primary readback, parity and record updates.

6. **Apply the exact migration once after Gate 2 with separately recorded current authority.** Use the authorized CRM Platinum Primary path for `vrvtsxexkiiiivlkdxzp`. Reconfirm project, baseline, raw file MD5, active Draft, lock window and recovery readiness immediately before the write. Verify one expected ledger row and four exact trigger changes with the existing customer binding, function, catalog fingerprints and scoped row counts afterward. If the connector allocates a temporary ledger version, reconcile only that exact row in a guarded transaction once the stored migration statement digest and intended version absence are proven. On error or ambiguity preserve the actual database state and follow the native RECOVER-1 decision; no blind retry. A reversal requires a separately authorized corrective migration restoring the prior function and trigger definitions.

7. **Record verified closure and resolve RECOVER-1.** From actual live Primary and local evidence, record ordered ledger and all ten parity surfaces, replace the interim Live state with the literal native fields `full-function-surface hash` and `structural-surface hash` carrying the matched hashes, retain suite count and regenerate discovery. Update ARCH-2 with evidence for the four members and customer metadata, keeping its remaining members OPEN. Update the five corresponding disposition rows only. With verified evidence, mark suppliers and tasks AUDITED, keep bookings and passengers AUDITED-OPEN for BOOK-11/BOOK-12 and PAX-8, and retain the customers AUDITED disposition. The native registry must report 15 B6-EXIT obligations and classify only suppliers and tasks as newly completed, without changing exit criteria or unrelated triggers. Require repository consistency and parity evidence PASS before Runtime Checkpoint DONE and the implementation commit.

8. **Verify and release through the native lifecycle.** Run timed and watched Finish, independent Review, Complete and bind with exact evidence. Set `Last Completed: **SPEC-319: Archive authority enforced at creation.**`, clear the active pointer, regenerate discovery and bind the exact candidate. Publish, hosted preflight, Promote, main checks and Remote Certify use separate native exact-candidate records and the current delegated authority.

## Acceptance Criteria

- [x] Exact migration applies existing archive authority at creation and enforces server-owned metadata. `check: blob supabase/migrations/20261119203357_archive_authority_applies_at_entry.sql ec8e125c0b20c282cacaad51d1a05a429039aaaf`
- [x] Task queue test retains its earlier controls and records refused archive creation. `check: blob supabase/tests/134_task_queue_authority_test.sql a8c0ef7d4a916bfbcef68668691b4028a0d8c27a`
- [x] Test 182 proves the authority and attribution of all five selected cases. `check: blob supabase/tests/182_archive_authority_applies_at_entry_test.sql 5ffffdeb43e3ae777957cafbb35fac99fdbc2e48`
- [x] The recorded selector exception is exact. `check: blob reports/master/MASTER_EXECUTION_PLAN.md b7aa489315d5cf5618e45d3ad927ae6237d9b943`
- [x] The regenerated API contract matches baseline. `check: same reports/master/MASTER_API_CONTRACT.md @243fd86c53715a4eb69f02e97353cfa2ad90ea8e`
- [x] Native selection stays intact. `check: same scripts/batch6_select_target.ps1 @243fd86c53715a4eb69f02e97353cfa2ad90ea8e`
- [x] The measured manifest test count is present. `check: has _ORVION_CANONICAL/manifest.md "Suite **182 files / 3381 assertions**"`
- [x] Verified Primary and local ledger and all ten surfaces agree. Suppliers and tasks complete, bookings and passengers remain open for recorded reasons, ARCH-2 stays open for its remaining members.

## Execution Log

None.

### 2026-11-19 — Original implementation checkpoint

Outcome: Complete (implementation steps; native Finish and independent Review pending).

- Steps 1–4 applied from the exact approved Draft. All four frozen output blobs match. The temporary prototype and Sandbox remain isolated.
- Step 5 passed native readiness at this approval head. Both SQL passes ran 182 files and 3381 assertions. The HTTP process exited 0 with 35 passed, database smoke passed, and the measured API blob equals the certified baseline. The unchanged pre-deploy guard reported only the expected RECOVER-1 difference.
- Step 6 applied migration 20261119203357 once to Platinum Primary under the separately recorded Gate 2. Original SHA-256 8D781F1C9053AE82988F560ABB599175579E7272731D89DEA072B5D459FEA09F and transmitted MD5 904a8f4d882705e4afa994d5b9a148aa match the stored statement. The connector's temporary version was reconciled under the exact-row guard. Independent readback matched all 273 ledger entries, thirteen trigger definitions, function identity and all ten parity surfaces. All five scoped tables retained their measured row counts.
- Step 7 refreshed the genuine Primary ledger, manifest and projection. The native ledger, parity and consistency verifiers passed. The registry derived 15 exit obligations and exactly two completions, suppliers and tasks. Bookings and passengers and the residual ARCH-2 members remain open.
- Step 8 enters native timed and watched Finish on the clean implementation commit, followed by independent Review and binding.

## Verification Notes

None.


### 2026-11-19 — Gate 1 approval recorded

DELEGATED Original Gate 1 for CRM SPEC-319 only. DEC-02 and Batch 6 Mode 2. Current owner source OWNER-DIRECTION.txt SHA-256 D7DDB062A5639F2372DE908F6C2ED8EE336E43382EFC6431AA18E6ADD88E3570. Frozen Draft SHA-256 61516730756BC8C5C00A4A661E6473B416C15548AA700DFBE60A06FB8F0128B5, Git blob dd32169f2112483002e050223e83763ad43196ad, from CRM baseline 243fd86c53715a4eb69f02e97353cfa2ad90ea8e. Native isolated Approve febc28679101e03495476c9fe81bc0294b70a885, identical native allocation, four exact payload files, isolated suite 182/3381, HTTP 35/0, smoke PASS, API identity, baseline causal negative, and the unchanged sandbox consistency evaluator reported RECOVER-1 only for the exact absent candidate migration. The scope comprises the four selected archive-at-entry members and existing customer-path metadata. Gate 2 and release have later exact-target prerequisites and separate delegated records. Immediately before allocation the hash, the Draft blob dd32169f2112483002e050223e83763ad43196ad, all 2 source anchors, the baseline HEAD 243fd86c53715a4eb69f02e97353cfa2ad90ea8e against refreshed origin/main 243fd86c53715a4eb69f02e97353cfa2ad90ea8e and a clean checkout were revalidated, and the pre-commit allocator admitted the identity; Draft allocated as 15c70f2. No implementation performed before this transition.


Verdict: Confirmed Complete

The Review checked the exact allocated Draft blob dd32169f2112483002e050223e83763ad43196ad, frozen SHA-256 61516730756BC8C5C00A4A661E6473B416C15548AA700DFBE60A06FB8F0128B5, implementation head ef9d0f174d5467f18fa632f6200ac9256ae3939b, all four committed payload blobs and the declared Git range. Fresh native Finish returned LOCAL_CERTIFY READY, receipt 2ca6cc0b86ee740c9905b5290a391b608b33db5fcca171dcac09cb0479e3de59, with all three native process exits zero. Native Original readiness passed 182 SQL files and 3381 assertions on each pass, 35 HTTP assertions, database smoke and identical generated API blob. The pre-deploy refusal was the expected exact target missing under RECOVER-1. The genuine independent Primary readback after the one migration and bounded ledger correction showed all 273 ordered ledger rows, the expected server-owned archive metadata and authority wiring, all ten parity surfaces matching local, and unchanged business-row counts. The native ledger and parity checks passed. No Founder write or integration change was in this range. The native registry derived exactly two newly completed surfaces, suppliers and tasks, and retains 15 Batch 6 exit obligations. Bookings and passengers and the residual ARCH-2 finding remain open. Publication and remote certification have their own recorded gates.


Local original native verification and truthful Review complete. Preserve this root's receipt 2ca6cc0b86ee740c9905b5290a391b608b33db5fcca171dcac09cb0479e3de59 and selected bytes. Candidate binding follows Complete; publication/promotion remain separately governed.

## Review Gate

- [x] Exact approved payload and allowed scope.
- [x] Isolated causal negative and native SQL, smoke, HTTP and API evidence.
- [x] Verified Primary identity, ledger, parity and registry changes.
- [x] Existing open items and governance gates retained.

## Notes

Baseline: 243fd86c53715a4eb69f02e97353cfa2ad90ea8e.

Owner authority: Workbench `data/records/batch6/archive-at-entry/OWNER-DIRECTION.txt`, SHA-256 `D7DDB062A5639F2372DE908F6C2ED8EE336E43382EFC6431AA18E6ADD88E3570`. The owner continued Mode 2 through the complete lifecycle and granted advance approval. DEC-02 and DEC-25 conditions apply at each exact native gate.

Isolated proof: `runtime/baseline-test-182.log`, `runtime/prototype-pgtap.log`, `runtime/prototype-smoke.log`, `runtime/prototype-http.log`, `runtime/prototype-catalog.log` and `runtime/prototype-parity.log`.

| Path | Baseline Git blob |
| --- | --- |
| `supabase/tests/134_task_queue_authority_test.sql` | `74612c13c8b24286eb7687ed55c285b6544b0532` |
| `reports/master/MASTER_EXECUTION_PLAN.md` | `c8ac9f40985fb8136dfb12ced623a2c8e9f2865f` |
