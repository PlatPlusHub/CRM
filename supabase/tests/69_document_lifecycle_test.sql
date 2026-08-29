-- pgTAP: DOC-LC-1 -- canon 26's Document Lifecycle State Machine, wired at last.
--
-- The defect, reproduced before the fix: `app.enforce_archive_authority` watches `is_archived` and
-- returns early when that boolean is unchanged, so `documents.lifecycle_status_code` was governed by
-- nothing but the catalog check -- which asks whether a code EXISTS, never whether the MOVE is
-- legal. A `trainee` holding no write permission set a colleague's document to 'archived' by direct
-- DML in the same transaction `app.archive_document` refused them.
--
-- It is not cosmetic: BOTH document write paths read `lifecycle_status_code = 'archived'` as a
-- refusal condition, so the row could never be re-versioned NOR properly archived afterwards, while
-- `is_archived` stayed false so nothing reading the boolean reported it as archived.
--
-- Assertion 8 is the one that matters most, and it is the FIN-6 lesson: a guard that stopped the
-- trainee AND the manager would satisfy every denial below while breaking the business.
create extension if not exists pgtap with schema extensions;

begin;
select plan(19);

insert into auth.users (id, email) values
  ('69000000-0000-0000-0000-0000000000a1','mgr@doclc.test'),
  ('69000000-0000-0000-0000-0000000000a2','emp@doclc.test'),
  ('69000000-0000-0000-0000-0000000000a3','trainee@doclc.test');
insert into public.tenants (id, name, slug, status) values
  ('69000000-0000-0000-0000-000000000001','DocLC Travel','doclc-lifecycle','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '69000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('69000000-0000-0000-0000-00000000000a','69000000-0000-0000-0000-000000000001','Cairo','doclc-lc-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('69000000-0000-0000-0000-0000000000c1','69000000-0000-0000-0000-000000000001','69000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('69000000-0000-0000-0000-000000000011','69000000-0000-0000-0000-000000000001','Mgr','mgr@doclc.test',true,'69000000-0000-0000-0000-0000000000a1'),
  ('69000000-0000-0000-0000-000000000012','69000000-0000-0000-0000-000000000001','Emp','emp@doclc.test',true,'69000000-0000-0000-0000-0000000000a2'),
  ('69000000-0000-0000-0000-000000000013','69000000-0000-0000-0000-000000000001','Trainee','trainee@doclc.test',true,'69000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('69000000-0000-0000-0000-000000000001','69000000-0000-0000-0000-000000000011','69000000-0000-0000-0000-00000000000a','69000000-0000-0000-0000-0000000000c1',true),
  ('69000000-0000-0000-0000-000000000001','69000000-0000-0000-0000-000000000012','69000000-0000-0000-0000-00000000000a','69000000-0000-0000-0000-0000000000c1',true),
  ('69000000-0000-0000-0000-000000000001','69000000-0000-0000-0000-000000000013','69000000-0000-0000-0000-00000000000a','69000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '69000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('69000000-0000-0000-0000-000000000011'::uuid,'department_manager'),
             ('69000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('69000000-0000-0000-0000-000000000013'::uuid,'trainee')) v(u, rc)
join public.roles r on r.code = v.rc;
insert into public.passengers (id, tenant_id, first_name, family_name, full_name, passenger_type_code) values
  ('69000000-0000-0000-0000-0000000000b1','69000000-0000-0000-0000-000000000001','Nour','Adel','Nour Adel','adult');

-- =============================================================================================
-- 1-4. STRUCTURE. What is registered, and -- just as deliberately -- what is not.
-- =============================================================================================
select is(
  (select count(*)::int from app.status_transitions where table_name = 'documents'),
  2,
  'exactly TWO document transitions are registered -- canon names three, and the third has no producer');

select set_eq(
  $$select from_status || ' -> ' || to_status || ' / ' || coalesce(permission_key,'(null)')
      from app.status_transitions where table_name = 'documents'$$,
  $$values ('active -> archived / ARCHIVE_DOCUMENT'), ('superseded -> archived / ARCHIVE_DOCUMENT')$$,
  'both registered moves end at archived and charge ARCHIVE_DOCUMENT -- read out of app.archive_document, not chosen here');

select is(
  (select count(*)::int from app.status_transitions
    where table_name = 'documents' and to_status = 'superseded'),
  0,
  'DOC-LC-2 PINNED: active -> superseded is NOT registered, because documents.lifecycle_status_code = superseded has no producer');

select ok(
  (select count(*) from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where c.relname = 'documents' and t.tgname = 'documents_enforce_status_transition'
      and not t.tgisinternal
      and (t.tgtype & 2) <> 0      -- BEFORE
      and (t.tgtype & 16) <> 0     -- UPDATE
      and (t.tgtype & 4) = 0) = 1, -- and NOT insert: a machine governs moves, not births
  'the trigger is attached BEFORE UPDATE and deliberately not on INSERT');

-- =============================================================================================
-- 5. The producer evidence behind assertion 3 -- stated as an assertion so the claim cannot rot.
-- =============================================================================================
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.prokind = 'f'
      and p.prosrc ~ 'lifecycle_status_code\s*=\s*''superseded'''),
  0,
  'no app function anywhere sets lifecycle_status_code to superseded -- the omission in 3 is measured, not assumed');

select ok(
  (select count(*) from pg_trigger where tgrelid = 'public.documents'::regclass
     and tgname = 'documents_emit_superseded' and not tgisinternal) = 1,
  '...while document_superseded IS produced, by a trigger on current_version_id -- supersede is an event about the version pointer, not a document status');

-- =============================================================================================
-- 6-8. THE AUTHORIZED PATH MUST STILL WORK. Positive controls first (no vacuous denial).
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"69000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select ok(app.has_permission('ARCHIVE_DOCUMENT'),
  'POSITIVE CONTROL: the department manager genuinely HOLDS ARCHIVE_DOCUMENT');

select lives_ok(
  $$select app.upload_document('passport','Nour Passport','p.pdf','pdf','passenger','69000000-0000-0000-0000-0000000000b1')$$,
  'the manager can create a document -- the fixture is real');

-- The assertion that matters most: the guard must not have broken the business.
select lives_ok(
  $$select app.archive_document(
      (select id from public.documents
        where tenant_id = '69000000-0000-0000-0000-000000000001' and title = 'Nour Passport'),
      'passport expired')$$,
  'THE ONE THAT MATTERS: a holder of ARCHIVE_DOCUMENT can still archive -- a guard that stopped them too would pass every denial below while breaking the workflow');

select is(
  (select lifecycle_status_code || '/' || is_archived::text from public.documents
    where tenant_id = '69000000-0000-0000-0000-000000000001' and title = 'Nour Passport'),
  'archived/true',
  '...and both fields moved together, so the two representations agree');

-- =============================================================================================
-- 9-10. CANON: there is no way back to active, and no way to superseded.
-- =============================================================================================
select throws_ok(
  $$update public.documents set lifecycle_status_code = 'active'
     where tenant_id = '69000000-0000-0000-0000-000000000001' and title = 'Nour Passport'$$,
  '23514',
  null,
  'archived -> active is refused even for the manager -- canon 26 lists no transition back into active');

select throws_ok(
  $$update public.documents set lifecycle_status_code = 'superseded'
     where tenant_id = '69000000-0000-0000-0000-000000000001' and title = 'Nour Passport'$$,
  '23514',
  null,
  'and no move to superseded is permitted, from any state, while nothing produces it');

-- =============================================================================================
-- 11-15. THE REPRODUCTION, now refused -- for two different roles, with visibility proven first.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"69000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;
select lives_ok(
  $$select app.upload_document('national_id','Nour National ID','n.pdf','pdf','passenger','69000000-0000-0000-0000-0000000000b1')$$,
  'a second, still-active document for the denial tests');

reset role;
select set_config('request.jwt.claims','{"sub":"69000000-0000-0000-0000-0000000000a3"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.documents
    where tenant_id = '69000000-0000-0000-0000-000000000001' and title = 'Nour National ID'),
  1,
  'POSITIVE CONTROL: the trainee can SEE the document -- so the refusal below is authority, not RLS emptiness');

select throws_ok(
  $$update public.documents set lifecycle_status_code = 'archived'
     where tenant_id = '69000000-0000-0000-0000-000000000001' and title = 'Nour National ID'$$,
  '42501',
  null,
  'REPRODUCTION CLOSED: the trainee can no longer freeze a colleague''s document by direct DML');

reset role;
select set_config('request.jwt.claims','{"sub":"69000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select throws_ok(
  $$update public.documents set lifecycle_status_code = 'archived'
     where tenant_id = '69000000-0000-0000-0000-000000000001' and title = 'Nour National ID'$$,
  '42501',
  null,
  'and neither can an ordinary employee, who DOES hold UPLOAD_DOCUMENT and CREATE_DOCUMENT_VERSION but not ARCHIVE_DOCUMENT');

reset role;
select is(
  (select lifecycle_status_code || '/' || is_archived::text from public.documents
    where tenant_id = '69000000-0000-0000-0000-000000000001' and title = 'Nour National ID'),
  'active/false',
  'NON-MUTATION: after both refusals the document is untouched -- the throws are not hiding a partial write');

-- =============================================================================================
-- 18-19. DOC-LC-3, PINNED AS KNOWN STATE -- not fixed here, and deliberately so.
--        `documents` carries TWO representations of one concept: `lifecycle_status_code` (now
--        governed by canon 26's machine) and the older `is_archived` boolean (governed by
--        `app.enforce_archive_authority`). Both cost ARCHIVE_DOCUMENT, so no unauthorized path
--        splits them any more -- but an AUTHORIZED holder still can, by moving the boolean alone.
--        The result is `archived/false`: a document nothing can re-version (both write paths read
--        the STATUS) while everything reading the BOOLEAN reports it as not archived.
--
--        Not fixed in this package because the fix requires deciding whether un-archiving exists
--        at all, and the two authorities disagree: canon 26 lists NO transition back into `active`,
--        while `enforce_archive_authority` says in terms that "restoring is the same authority as
--        archiving". Synchronizing the fields in either direction removes one of them. That is a
--        canonical contradiction, not an engineering choice, so it is recorded as DOC-LC-3 and
--        pinned here instead -- a defect that is asserted cannot change silently.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"69000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select lives_ok(
  $$update public.documents set is_archived = false
     where tenant_id = '69000000-0000-0000-0000-000000000001' and title = 'Nour Passport'$$,
  'DOC-LC-3 (KNOWN, BLOCKED): an ARCHIVE_DOCUMENT holder can still move the BOOLEAN alone -- the machine governs the status column only');

select is(
  (select lifecycle_status_code || '/' || is_archived::text from public.documents
    where tenant_id = '69000000-0000-0000-0000-000000000001' and title = 'Nour Passport'),
  'archived/false',
  '...producing the split state, pinned so it cannot change unnoticed while the canon contradiction is open');

select finish();
rollback;
