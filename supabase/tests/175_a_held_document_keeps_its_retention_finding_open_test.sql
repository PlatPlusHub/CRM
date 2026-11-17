-- pgTAP: Batch 6 slice 55 (document_storage_findings) --
-- RET-5: a legal hold stops every resolution of a retention finding recorded before the hold, so a
-- held version is never destroyed and its finding is neither closed nor aged while the hold stands.
-- ATTACK-CLASSES: AUTH=N/A TENANT DOOR STATE INPUT=N/A CONCURRENCY=N/A REPLAY PRIVILEGE=N/A BUSINESS=N/A OBSERVABILITY=N/A
--   AUTH, PRIVILEGE=N/A -- the resolver is `service_role` only and `authenticated` holds no grant on
--     the table (tests 49, 52 and 60 pin both); this file is about what the platform caller may do.
--   INPUT=N/A -- an unknown or null code, an unknown finding and a second resolve are refused
--     before the hold check, unchanged (test 49).
--   CONCURRENCY=N/A -- the hold and the resolve each take the finding's row; the claim already
--     skips a held document, and the resolver now rechecks at the moment of destruction.
--   BUSINESS=N/A -- a finding carries no money.
--   OBSERVABILITY=N/A -- the destroy event is unchanged; a refusal writes nothing.
create extension if not exists pgtap with schema extensions;

begin;
select plan(14);

insert into auth.users (id, email) values
  ('17500000-0000-0000-0000-0000000000a1','owner@c175.test');
insert into public.tenants (id, name, slug, status) values
  ('17500000-0000-0000-0000-000000000001','Held Travel','held-travel-175','active'),
  ('17500000-0000-0000-0000-000000000002','Free Travel','free-travel-175','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select v.t, sp.id, 'active' from public.subscription_plans sp,
  (values ('17500000-0000-0000-0000-000000000001'::uuid), ('17500000-0000-0000-0000-000000000002')) v(t)
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('17500000-0000-0000-0000-00000000000a','17500000-0000-0000-0000-000000000001','Giza','giza-175');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('17500000-0000-0000-0000-0000000000c1','17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-00000000000a','operations','Operations');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('17500000-0000-0000-0000-000000000011','17500000-0000-0000-0000-000000000001','Owner','owner@c175.test',true,'17500000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-000000000011','17500000-0000-0000-0000-00000000000a','17500000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '17500000-0000-0000-0000-000000000001', '17500000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'owner';

insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code) values
  ('17500000-0000-0000-0000-0000000000d1','17500000-0000-0000-0000-000000000001','invoice','Held invoice','active'),
  ('17500000-0000-0000-0000-0000000000d2','17500000-0000-0000-0000-000000000002','invoice','Free invoice','active');
insert into public.document_versions
  (id, tenant_id, document_id, version_number, file_name, file_type_code, storage_path, is_current, uploaded_at) values
  ('17500000-0000-0000-0000-0000000000f1','17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-0000000000d1',1,'a-old.pdf','pdf','17500000-0000-0000-0000-000000000001/17500000-0000-0000-0000-0000000000d1/1-a-old.pdf',false,now()-interval '400 days'),
  ('17500000-0000-0000-0000-0000000000f2','17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-0000000000d1',2,'a-current.pdf','pdf','17500000-0000-0000-0000-000000000001/17500000-0000-0000-0000-0000000000d1/2-a-current.pdf',true,now()-interval '400 days'),
  ('17500000-0000-0000-0000-0000000000f3','17500000-0000-0000-0000-000000000002','17500000-0000-0000-0000-0000000000d2',1,'b-old.pdf','pdf','17500000-0000-0000-0000-000000000002/17500000-0000-0000-0000-0000000000d2/1-b-old.pdf',false,now()-interval '400 days'),
  ('17500000-0000-0000-0000-0000000000f4','17500000-0000-0000-0000-000000000002','17500000-0000-0000-0000-0000000000d2',2,'b-current.pdf','pdf','17500000-0000-0000-0000-000000000002/17500000-0000-0000-0000-0000000000d2/2-b-current.pdf',true,now()-interval '400 days');
update public.documents set current_version_id = '17500000-0000-0000-0000-0000000000f2' where id = '17500000-0000-0000-0000-0000000000d1';
update public.documents set current_version_id = '17500000-0000-0000-0000-0000000000f4' where id = '17500000-0000-0000-0000-0000000000d2';
insert into storage.objects (bucket_id, name)
select 'documents', storage_path from public.document_versions where tenant_id in
  ('17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-000000000002');
insert into public.document_retention_policies (tenant_id, document_type_code, retention_days, reason) values
  ('17500000-0000-0000-0000-000000000001','invoice',30,'test-approved period'),
  ('17500000-0000-0000-0000-000000000002','invoice',30,'test-approved period');

-- The scan runs BEFORE the hold: the candidate is recorded while the document is free.
select app.reconcile_document_storage();
select set_eq(
  $$select document_version_id::text from public.document_storage_findings
     where finding_type_code = 'retention_expired'
       and tenant_id in ('17500000-0000-0000-0000-000000000001','17500000-0000-0000-0000-000000000002')$$,
  $$values ('17500000-0000-0000-0000-0000000000f1'), ('17500000-0000-0000-0000-0000000000f3')$$,
  'CONTROL: the scan before the hold records both old versions as retention candidates');

select set_config('request.jwt.claims', '{"sub":"17500000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select lives_ok(
  $$select app.set_document_legal_hold('17500000-0000-0000-0000-0000000000d1', true, 'litigation notice received')$$,
  'the owner places the hold after the candidate was recorded');
reset role;
select set_config('request.jwt.claims', '', true);

select is((select count(*)::int from app.claim_storage_actions(500) where tenant_id = '17500000-0000-0000-0000-000000000001'),
  0, 'CONTROL: the claim already skips the held candidate');

set local role service_role;
select throws_ok(
  $$select public.resolve_storage_finding(
      (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f1'),
      'object_deleted', 'executor deleted the object')$$,
  '23514', null, 'the executor''s door refuses to destroy a held document''s version');
reset role;
select throws_ok(
  $$select app.platform_resolve_storage_finding(
      (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f1'),
      'object_deleted', null)$$,
  '23514', null, 'the resolver refuses object_deleted while the hold stands');
select throws_ok(
  $$select app.platform_resolve_storage_finding(
      (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f1'),
      'dismissed', null)$$,
  '23514', null, 'the resolver refuses to dismiss a held candidate');
select throws_ok(
  $$select app.platform_resolve_storage_finding(
      (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f1'),
      'failed', 'timeout')$$,
  '23514', null, 'the resolver refuses to count an attempt on a held candidate');
select throws_ok(
  $$select app.platform_resolve_storage_finding(
      (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f1'),
      'object_restored', null)$$,
  '23514', null, 'the resolver refuses object_restored on a held candidate');

select is(
  (select f.resolved_at is null and f.resolution_code is null and f.attempt_count = 0
     and exists (select 1 from public.document_versions where id = '17500000-0000-0000-0000-0000000000f1')
     from public.document_storage_findings f where f.document_version_id = '17500000-0000-0000-0000-0000000000f1'),
  true, 'the held version still exists and its finding is open, unresolved and not aged');

select is(
  app.platform_resolve_storage_finding(
    (select id from public.document_storage_findings where document_version_id = '17500000-0000-0000-0000-0000000000f3'),
    'object_deleted', null),
  'object_deleted', 'POSITIVE CONTROL: the unheld tenant''s candidate is destroyed as before');
select is((select count(*)::int from public.document_versions where id = '17500000-0000-0000-0000-0000000000f3'),
  0, 'the unheld version''s metadata is gone');

select set_config('request.jwt.claims', '{"sub":"17500000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select lives_ok(
  $$select app.set_document_legal_hold('17500000-0000-0000-0000-0000000000d1', false, 'counsel released the hold')$$,
  'the owner releases the hold');
reset role;
select set_config('request.jwt.claims', '', true);

select is(
  app.platform_resolve_storage_finding(
    (select id from public.document_storage_findings
      where tenant_id = '17500000-0000-0000-0000-000000000001' and finding_type_code = 'retention_expired' and resolved_at is null),
    'object_deleted', null),
  'object_deleted', 'RELEASE: the same open finding is resolved once the hold is released');
select is((select count(*)::int from public.document_versions where id = '17500000-0000-0000-0000-0000000000f1'),
  0, 'the released version''s metadata is gone');

select * from finish();
rollback;
