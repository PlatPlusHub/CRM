-- pgTAP: RET-1 / RET-2 -- legal hold overrides every retention-deletion path.
create extension if not exists pgtap with schema extensions;

begin;
select plan(18);

insert into auth.users (id, email) values
  ('b6000000-0000-0000-0000-0000000000a1','owner@hold.test'),
  ('b6000000-0000-0000-0000-0000000000a2','ceo-denied@hold.test');
insert into public.tenants (id, name, slug, status) values
  ('b6000000-0000-0000-0000-000000000001','Hold A','hold-a','active'),
  ('b6000000-0000-0000-0000-000000000002','Hold B','hold-b','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.subscription_plans sp
cross join (values ('b6000000-0000-0000-0000-000000000001'::uuid),
                   ('b6000000-0000-0000-0000-000000000002'::uuid)) t(id)
where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('b6000000-0000-0000-0000-000000000011','b6000000-0000-0000-0000-000000000001','A','hold-a-branch');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('b6000000-0000-0000-0000-000000000021','b6000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000011','operations','Operations');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('b6000000-0000-0000-0000-000000000031','b6000000-0000-0000-0000-000000000001','Owner','owner@hold.test',true,'b6000000-0000-0000-0000-0000000000a1'),
  ('b6000000-0000-0000-0000-000000000032','b6000000-0000-0000-0000-000000000001','CEO denied hold','ceo-denied@hold.test',true,'b6000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary) values
  ('b6000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000031','b6000000-0000-0000-0000-000000000011','b6000000-0000-0000-0000-000000000021',true),
  ('b6000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000032','b6000000-0000-0000-0000-000000000011','b6000000-0000-0000-0000-000000000021',true);
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select 'b6000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('b6000000-0000-0000-0000-000000000031'::uuid,'owner'),
             ('b6000000-0000-0000-0000-000000000032'::uuid,'ceo')) v(u,rc)
join public.roles r on r.code=v.rc;
insert into public.user_permission_grants(tenant_id,user_id,permission_id,effect,reason)
select 'b6000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000032',p.id,'deny','negative control'
from public.permissions p where p.key='MANAGE_TENANT_SETTINGS';

insert into public.documents (id,tenant_id,document_type_code,title,lifecycle_status_code) values
  ('b6000000-0000-0000-0000-0000000000d1','b6000000-0000-0000-0000-000000000001','invoice','Held invoice','active'),
  ('b6000000-0000-0000-0000-0000000000d2','b6000000-0000-0000-0000-000000000002','invoice','Other invoice','active');
insert into public.document_versions
  (id,tenant_id,document_id,version_number,file_name,file_type_code,storage_path,is_current,uploaded_at) values
  ('b6000000-0000-0000-0000-0000000000f1','b6000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-0000000000d1',1,'a-old.pdf','pdf','b6000000-0000-0000-0000-000000000001/b6000000-0000-0000-0000-0000000000d1/1-a-old.pdf',false,now()-interval '400 days'),
  ('b6000000-0000-0000-0000-0000000000f2','b6000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-0000000000d1',2,'a-current.pdf','pdf','b6000000-0000-0000-0000-000000000001/b6000000-0000-0000-0000-0000000000d1/2-a-current.pdf',true,now()-interval '400 days'),
  ('b6000000-0000-0000-0000-0000000000f3','b6000000-0000-0000-0000-000000000002','b6000000-0000-0000-0000-0000000000d2',1,'b-old.pdf','pdf','b6000000-0000-0000-0000-000000000002/b6000000-0000-0000-0000-0000000000d2/1-b-old.pdf',false,now()-interval '400 days'),
  ('b6000000-0000-0000-0000-0000000000f4','b6000000-0000-0000-0000-000000000002','b6000000-0000-0000-0000-0000000000d2',2,'b-current.pdf','pdf','b6000000-0000-0000-0000-000000000002/b6000000-0000-0000-0000-0000000000d2/2-b-current.pdf',true,now()-interval '400 days');
update public.documents set current_version_id='b6000000-0000-0000-0000-0000000000f2' where id='b6000000-0000-0000-0000-0000000000d1';
update public.documents set current_version_id='b6000000-0000-0000-0000-0000000000f4' where id='b6000000-0000-0000-0000-0000000000d2';
insert into storage.objects (bucket_id,name)
select 'documents',storage_path from public.document_versions where tenant_id in
  ('b6000000-0000-0000-0000-000000000001','b6000000-0000-0000-0000-000000000002');

select is((select count(*)::int from public.document_retention_policies),0,
  'NO POLICY remains the shipped default: no retention value is guessed');
select lives_ok($$select app.reconcile_document_storage()$$,'the no-policy scan runs');
select is((select count(*)::int from public.document_storage_findings where finding_type_code='retention_expired'),0,
  'NO POLICY means RETAIN: no old version becomes a candidate');

insert into public.document_retention_policies(tenant_id,document_type_code,retention_days,reason) values
  ('b6000000-0000-0000-0000-000000000001','invoice',30,'test-approved period'),
  ('b6000000-0000-0000-0000-000000000002','invoice',30,'test-approved period');

select set_config('request.jwt.claims','{"sub":"b6000000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select ok(not app.has_permission('MANAGE_TENANT_SETTINGS'),
  'negative control: a tenant-wide CEO can see and edit the document but a per-user deny removes legal-hold authority');
select throws_ok(
  $$select app.set_document_legal_hold('b6000000-0000-0000-0000-0000000000d1',true,'litigation notice')$$,
  '42501',null,'an ordinary document writer who can see the row cannot place a legal hold');

reset role;
select set_config('request.jwt.claims','{"sub":"b6000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select ok(app.has_permission('MANAGE_TENANT_SETTINGS'),
  'positive control: the owner genuinely holds the reused retention-policy authority');
select lives_ok(
  $$select app.set_document_legal_hold('b6000000-0000-0000-0000-0000000000d1',true,'litigation notice received')$$,
  'the sanctioned path places the hold');

reset role;
select is(
  (select legal_hold_active::text||'|'||legal_hold_reason||'|'||legal_hold_changed_by::text
     from public.documents where id='b6000000-0000-0000-0000-0000000000d1'),
  'true|litigation notice received|b6000000-0000-0000-0000-000000000031',
  'hold state carries a reason and server-derived actor');
select is(
  (select count(*)::int from public.events where entity_id='b6000000-0000-0000-0000-0000000000d1'
    and event_type_code='document_legal_hold_placed'),1,
  'placing the hold emits exactly one immutable business event');
select lives_ok($$select app.reconcile_document_storage()$$,'the multi-tenant scan runs with one held tenant');
select set_eq(
  $$select document_version_id::text from public.document_storage_findings where finding_type_code='retention_expired'$$,
  $$values ('b6000000-0000-0000-0000-0000000000f3')$$,
  'SCAN: the held tenant contributes no candidate, while another tenant remains independently eligible');
select is(
  (select count(*)::int from app.claim_storage_actions(500) where tenant_id='b6000000-0000-0000-0000-000000000001'),0,
  'CLAIM: legal hold is rechecked and blocks execution, not merely reporting');

select set_config('request.jwt.claims','{"sub":"b6000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select lives_ok(
  $$select app.set_document_legal_hold('b6000000-0000-0000-0000-0000000000d1',false,'counsel released the hold')$$,
  'the same sanctioned path explicitly releases the hold');
reset role;
select is(
  (select count(*)::int from public.events where entity_id='b6000000-0000-0000-0000-0000000000d1'
    and event_type_code='document_legal_hold_released'),1,
  'release emits exactly one immutable event of its own');
select lives_ok($$select app.reconcile_document_storage()$$,'the scan runs after release');
select set_eq(
  $$select document_version_id::text from public.document_storage_findings where finding_type_code='retention_expired'$$,
  $$values ('b6000000-0000-0000-0000-0000000000f1'),('b6000000-0000-0000-0000-0000000000f3')$$,
  'RELEASE: ordinary per-type eligibility resumes for the formerly held document');
select is(
  (select count(*)::int from public.document_storage_findings f join public.document_versions dv on dv.id=f.document_version_id
    where f.finding_type_code='retention_expired' and dv.is_current),0,
  'CURRENT VERSION: never eligible at any age, with or without a hold');
select throws_ok(
  $$insert into public.document_retention_policies(tenant_id,document_type_code,retention_days)
    values ('b6000000-0000-0000-0000-000000000001','visa',0)$$,
  '23514',null,'INVALID PERIOD: zero remains structurally fail-closed');

select * from finish();
rollback;
