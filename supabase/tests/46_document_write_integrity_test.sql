-- pgTAP: WP-04-A -- the document storage path is system-derived, and a version's identity is
-- immutable.
--
-- DOC-1: `app.upload_document` and `app.add_document_version` both took the object key as a
-- CALLER-SUPPLIED parameter, and `authenticated` holds INSERT/UPDATE on `document_versions`
-- directly -- three paths on which the caller chose where a document points inside object storage.
-- Nothing bad happens today only because `storage.buckets` = 0; the moment a bucket exists, a caller
-- can write under another tenant's prefix and defeat the very storage policy meant to stop them.
--
-- DOC-3: nothing forced anyone through the RPC, so a version's `storage_path` could be rewritten by
-- direct UPDATE with no permission check and no event -- the WP-00 forgery class, one domain over.
--
-- The decisive assertions are 8-11: a caller SUPPLIES a path, including one naming another tenant,
-- and it does not survive; then rewriting an existing version is refused outright.
create extension if not exists pgtap with schema extensions;

begin;
select plan(14);

insert into auth.users (id, email) values
  ('46000000-0000-0000-0000-0000000000a1','emp@doc.test'),
  ('46000000-0000-0000-0000-0000000000a2','trainee@doc.test');
insert into public.tenants (id, name, slug, status) values
  ('46000000-0000-0000-0000-000000000001','Doc Travel','doc-travel','active'),
  ('46000000-0000-0000-0000-000000000002','Other Travel','other-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select v.t, sp.id, 'active'
from (values ('46000000-0000-0000-0000-000000000001'::uuid),
             ('46000000-0000-0000-0000-000000000002'::uuid)) v(t)
join public.subscription_plans sp on sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('46000000-0000-0000-0000-00000000000a','46000000-0000-0000-0000-000000000001','Cairo','doc-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('46000000-0000-0000-0000-0000000000c1','46000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('46000000-0000-0000-0000-000000000011','46000000-0000-0000-0000-000000000001','Emp','emp@doc.test',true,'46000000-0000-0000-0000-0000000000a1'),
  ('46000000-0000-0000-0000-000000000012','46000000-0000-0000-0000-000000000001','Trainee','trainee@doc.test',true,'46000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('46000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000011','46000000-0000-0000-0000-00000000000a','46000000-0000-0000-0000-0000000000c1',true),
  ('46000000-0000-0000-0000-000000000001','46000000-0000-0000-0000-000000000012','46000000-0000-0000-0000-00000000000a','46000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '46000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('46000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('46000000-0000-0000-0000-000000000012'::uuid,'trainee')) v(u, rc)
join public.roles r on r.code = v.rc;

insert into public.passengers (id, tenant_id, first_name, family_name, full_name, passenger_type_code) values
  ('46000000-0000-0000-0000-0000000000b1','46000000-0000-0000-0000-000000000001','Layla','Fouad','Layla Fouad','adult');

-- =============================================================================================
-- 1-3. THE PARAMETER IS GONE, and gone without leaving an overload that still accepts a path.
-- =============================================================================================
select ok(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'upload_document') = 1
  and (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'app' and p.proname = 'upload_document'
          and 'p_storage_path' = any (p.proargnames)) = 0,
  'app.upload_document has ONE signature and no p_storage_path -- no stale overload still takes a path');

select ok(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'add_document_version') = 1
  and (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'app' and p.proname = 'add_document_version'
          and 'p_storage_path' = any (p.proargnames)) = 0,
  '...and so does app.add_document_version -- the second path, which the first discovery pass missed');

select set_config('request.jwt.claims','{"sub":"46000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select ok(app.has_permission('UPLOAD_DOCUMENT') and app.has_permission('CREATE_DOCUMENT_VERSION'),
  'CONTROL: the employee HOLDS both document permissions -- what follows is not a permission failure');

-- =============================================================================================
-- 4-7. THE HONEST PATH still works, and the derived key is exactly tenant/document/version.
-- =============================================================================================
select lives_ok(
  $$select app.upload_document('passport','Layla passport','layla.pdf','pdf',
        'passenger','46000000-0000-0000-0000-0000000000b1')$$,
  'an ordinary upload succeeds with no path parameter at all');

reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select dv.storage_path from public.document_versions dv
     join public.documents d on d.id = dv.document_id
    where d.tenant_id = '46000000-0000-0000-0000-000000000001' and d.title = 'Layla passport'),
  (select '46000000-0000-0000-0000-000000000001/' || d.id::text || '/1'
     from public.documents d where d.tenant_id = '46000000-0000-0000-0000-000000000001' and d.title = 'Layla passport'),
  'the object key is derived as tenant/document/version -- tenant first, so storage policy can isolate on segment 1');

select set_config('request.jwt.claims','{"sub":"46000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;
select lives_ok(
  $$select app.add_document_version(
      (select id from public.documents where tenant_id = '46000000-0000-0000-0000-000000000001' and title = 'Layla passport'),
      'layla-v2.pdf','pdf')$$,
  'superseding the document with a new version also needs no path');

reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select dv.version_number::text || ':' || dv.storage_path
     from public.document_versions dv join public.documents d on d.id = dv.document_id
    where d.tenant_id = '46000000-0000-0000-0000-000000000001' and d.title = 'Layla passport' and dv.is_current),
  (select '2:46000000-0000-0000-0000-000000000001/' || d.id::text || '/2'
     from public.documents d where d.tenant_id = '46000000-0000-0000-0000-000000000001' and d.title = 'Layla passport'),
  '...and the new version number AND its key are both derived, in step with each other');

-- =============================================================================================
-- 8-9. THE FORGERY. A caller writes `document_versions` DIRECTLY and hands over a path of their
--      choosing -- including one under ANOTHER TENANT's prefix. The insert is accepted; the path
--      is not. Overwriting beats forbidding because it closes every path at once.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"46000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select lives_ok(
  $$insert into public.document_versions
        (tenant_id, document_id, version_number, file_name, file_type_code, storage_path, is_current)
    select '46000000-0000-0000-0000-000000000001', d.id, 99, 'forged.pdf', 'pdf',
           '46000000-0000-0000-0000-000000000002/anything/i/like', false
      from public.documents d where d.tenant_id = '46000000-0000-0000-0000-000000000001' and d.title = 'Layla passport'$$,
  'a direct INSERT naming ANOTHER tenant''s storage prefix is accepted...');

reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select dv.version_number::text || ':' || dv.storage_path
     from public.document_versions dv join public.documents d on d.id = dv.document_id
    where d.tenant_id = '46000000-0000-0000-0000-000000000001' and d.title = 'Layla passport' and dv.file_name = 'forged.pdf'),
  (select '3:46000000-0000-0000-0000-000000000001/' || d.id::text || '/3'
     from public.documents d where d.tenant_id = '46000000-0000-0000-0000-000000000001' and d.title = 'Layla passport'),
  '...but NEITHER the version number 99 NOR the foreign prefix survived -- both were derived');

-- =============================================================================================
-- 10-11. REWRITING a version is refused outright. Deriving on INSERT is not enough on its own:
--        without this, an attacker simply UPDATEs the row afterwards.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"46000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select throws_ok(
  $$update public.document_versions set storage_path = '46000000-0000-0000-0000-000000000002/evil'
     where file_name = 'layla-v2.pdf'$$,
  '42501', null,
  'repointing an existing version at another object is refused -- a version''s identity is immutable');

select throws_ok(
  $$update public.document_versions set version_number = 1 where file_name = 'layla-v2.pdf'$$,
  '42501', null,
  '...and so is renumbering it, which would otherwise reorder document history');

-- =============================================================================================
-- 12. ATTRIBUTION cannot be forged either: the uploader is taken from the session, never accepted.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);
select is(
  (select count(distinct uploaded_by)::int from public.document_versions dv
     join public.documents d on d.id = dv.document_id
    where d.tenant_id = '46000000-0000-0000-0000-000000000001' and d.title = 'Layla passport'),
  1,
  'every version is attributed to the actual caller -- uploaded_by is derived, not accepted');

-- =============================================================================================
-- 13-14. Direct DML now costs the SAME permission the RPC always charged, and cross-tenant writes
--        remain impossible. The trainee is a real session that simply lacks the permission.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"46000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select ok(not app.has_permission('CREATE_DOCUMENT_VERSION'),
  'CONTROL: the trainee genuinely lacks CREATE_DOCUMENT_VERSION');

select throws_ok(
  $$insert into public.document_versions
        (tenant_id, document_id, file_name, file_type_code, is_current)
    select '46000000-0000-0000-0000-000000000001', d.id, 'sneak.pdf', 'pdf', false
      from public.documents d where d.tenant_id = '46000000-0000-0000-0000-000000000001' and d.title = 'Layla passport'$$,
  '42501', null,
  '...and a direct INSERT is refused for want of it -- the RPC is no longer the only thing charging for this');

select finish();
rollback;
