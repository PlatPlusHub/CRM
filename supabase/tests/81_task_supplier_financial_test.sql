-- pgTAP: the final API-3 family -- TASK-1, TASK-2, SUP-1 (202607058600), plus the first behavioural
-- coverage of `app.financial_documents`.
--
-- Assertion 20 pinned SPEC-154-B while it was an open owner decision. The owner decided it on
-- 2026-08-31 (Option C) and `202607058700` implemented it, so that assertion is now a RULE and its
-- expected value flipped 1 -> 0. The full behavioural matrix lives in test 82.
--
-- Runs as postgres with a JWT claim except where RLS is the subject: triggers and RPC logic apply to
-- the table owner too, and `user_branch_assignments.scope_read` is tenant-wide, so the placement
-- lookup behaves identically for an ordinary caller (verified before relying on it).
create extension if not exists pgtap with schema extensions;

begin;
select plan(20);

insert into auth.users (id, email) values
  ('81000000-0000-0000-0000-0000000000a1','mgr@f81.example'),
  ('81000000-0000-0000-0000-0000000000a2','emp@f81.example'),
  ('81000000-0000-0000-0000-0000000000a3','fin@f81.example');
insert into public.tenants (id, name, slug, status) values
  ('81000000-0000-0000-0000-000000000001','F81 Travel','f81-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '81000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('81000000-0000-0000-0000-00000000000a','81000000-0000-0000-0000-000000000001','Cairo','f81-cairo'),
  ('81000000-0000-0000-0000-00000000000b','81000000-0000-0000-0000-000000000001','Giza','f81-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('81000000-0000-0000-0000-0000000000c1','81000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-00000000000a','sales','Cairo Sales'),
  ('81000000-0000-0000-0000-0000000000c2','81000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-00000000000b','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('81000000-0000-0000-0000-000000000011','81000000-0000-0000-0000-000000000001','Manager','mgr@f81.example',true,'81000000-0000-0000-0000-0000000000a1'),
  ('81000000-0000-0000-0000-000000000021','81000000-0000-0000-0000-000000000001','Employee','emp@f81.example',true,'81000000-0000-0000-0000-0000000000a2'),
  ('81000000-0000-0000-0000-000000000031','81000000-0000-0000-0000-000000000001','Finance','fin@f81.example',true,'81000000-0000-0000-0000-0000000000a3');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '81000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000011', r.id,'tenant' from public.roles r where r.code='branch_manager';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '81000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000021', r.id,'tenant' from public.roles r where r.code='employee';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '81000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000031', r.id,'tenant' from public.roles r where r.code='finance_manager';
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '81000000-0000-0000-0000-000000000001', u, '81000000-0000-0000-0000-00000000000a','81000000-0000-0000-0000-0000000000c1', true
from unnest(array['81000000-0000-0000-0000-000000000011'::uuid,'81000000-0000-0000-0000-000000000021']) u;
-- Finance is placed in GIZA with a transfer already SCHEDULED -- still today's placement.
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary, ends_at)
values ('81000000-0000-0000-0000-000000000001','81000000-0000-0000-0000-000000000031','81000000-0000-0000-0000-00000000000b','81000000-0000-0000-0000-0000000000c2',true, now() + interval '30 days');

select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-0000000000a2"}',true);

-- ================================================================================================
-- TASK-1 -- a task changes hands only with ASSIGN_TASK.
-- ================================================================================================
select ok(app.has_permission('CREATE_TASK'),
  'POSITIVE CONTROL: the employee genuinely holds CREATE_TASK');

select ok(not app.has_permission('ASSIGN_TASK'),
  '...and genuinely does NOT hold ASSIGN_TASK -- the two are different role sets, which is what makes this a real gap');

create temp table t1 as select app.create_task('Call the customer','call_customer',
  '81000000-0000-0000-0000-000000000021','81000000-0000-0000-0000-0000000000c1','81000000-0000-0000-0000-00000000000a') as id;

select is(
  (select owner_user_id from public.tasks where id = (select id from t1)),
  '81000000-0000-0000-0000-000000000021'::uuid,
  'POSITIVE CONTROL: the employee creates a task and owns it, so the refusals below are about reassignment');

select throws_ok(
  format($$select app.assign_task('%s','81000000-0000-0000-0000-000000000011',null,null,'via rpc')$$, (select id from t1)),
  '42501', null,
  'the RPC refuses the employee -- ASSIGN_TASK is not theirs');

select throws_ok(
  format($$update public.tasks set owner_user_id = '81000000-0000-0000-0000-000000000011' where id = '%s'$$, (select id from t1)),
  '42501', null,
  'TASK-1: and so does the TABLE -- before 202607058600 this returned UPDATE 1 and emitted no task_assigned event, so the task changed hands unauthorized AND unaudited');

select lives_ok(
  format($$update public.tasks set title = 'Call the customer back' where id = '%s'$$, (select id from t1)),
  'NEGATIVE CONTROL: the same employee can still EDIT their own task -- the new rule fires only when the owner changes, so ordinary work stays under CREATE_TASK');

savepoint m1;
drop trigger tasks_guard_reassignment on public.tasks;
select lives_ok(
  format($$update public.tasks set owner_user_id = '81000000-0000-0000-0000-000000000011' where id = '%s'$$, (select id from t1)),
  'MUTATION: with tasks_guard_reassignment dropped the reassignment SUCCEEDS -- proving that trigger is the enforcer');
select is(
  (select count(*)::int from public.events where entity_id = (select id from t1) and event_type_code = 'task_assigned'),
  0,
  '...and it emits no task_assigned event, which is exactly the unaudited state reproduced before the fix');
rollback to savepoint m1;

-- ================================================================================================
-- TASK-2 -- a placement scheduled to end is still today's placement.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-0000000000a1"}',true);

select lives_ok(
  format($$select app.assign_task('%s','81000000-0000-0000-0000-000000000031',null,null,'hand to Giza')$$, (select id from t1)),
  'POSITIVE CONTROL: a manager holding ASSIGN_TASK can reassign');

select is(
  (select owner_branch_id from public.tasks where id = (select id from t1)),
  '81000000-0000-0000-0000-00000000000b'::uuid,
  'TASK-2: the task moves to the new owner''s GIZA branch even though their transfer is SCHEDULED -- before the fix the lookup matched nothing and the task silently kept CAIRO, the previous owner''s branch');

-- ================================================================================================
-- SUP-1 -- the supplier-link table now carries the RPC's rules.
-- ================================================================================================
create temp table cust as select app.create_customer('person','F81 Customer',null,null,null,'+201119995555',null,null,null,null,false,null,false) as id;
create temp table bk as select app.create_booking((select id from cust),null,'F81 booking','81000000-0000-0000-0000-00000000000a','81000000-0000-0000-0000-0000000000c1') as id;
create temp table bi as select app.create_booking_item((select id from bk),'hotel','EGP',1000,2000) as id;

select lives_ok(
  format($$select app.link_internal_supplier('%s','81000000-0000-0000-0000-00000000000a','81000000-0000-0000-0000-0000000000c1','legal')$$, (select id from bi)),
  'POSITIVE CONTROL: a coherent provider pair links successfully, so the refusals below are the rule and not a broken fixture');

select throws_ok(
  format($$insert into public.internal_supplier_links (tenant_id, booking_item_id, provider_branch_id, provider_department_id, requester_branch_id, requester_department_id)
           values ('81000000-0000-0000-0000-000000000001','%s','81000000-0000-0000-0000-00000000000a','81000000-0000-0000-0000-0000000000c2','81000000-0000-0000-0000-00000000000a','81000000-0000-0000-0000-0000000000c1')$$, (select id from bi)),
  '23514', null,
  'SUP-1: a provider department that is not IN the provider branch is refused on the table door -- the composite FKs prove each id exists, neither proves the pair is coherent');

select lives_ok(
  format($$insert into public.internal_supplier_links (tenant_id, booking_item_id, provider_branch_id, provider_department_id, requester_branch_id, requester_department_id)
           values ('81000000-0000-0000-0000-000000000001','%s','81000000-0000-0000-0000-00000000000b','81000000-0000-0000-0000-0000000000c2','81000000-0000-0000-0000-00000000000b','81000000-0000-0000-0000-0000000000c2')$$, (select id from bi)),
  'a coherent pair still inserts by direct DML -- the guard does not block legitimate writes');

select is(
  (select requester_branch_id from public.internal_supplier_links
    where booking_item_id = (select id from bi) and provider_branch_id = '81000000-0000-0000-0000-00000000000b'),
  '81000000-0000-0000-0000-00000000000a'::uuid,
  '...and the FORGED requester is discarded: it is derived from the item''s own org unit (Cairo), not accepted from the caller who sent Giza');

savepoint m2;
select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-0000000000a1"}',true);
select app.advance_booking_item((select id from bi),'cancelled','customer changed mind',null,'customer_cancelled');
select throws_ok(
  format($$insert into public.internal_supplier_links (tenant_id, booking_item_id, provider_branch_id, provider_department_id, requester_branch_id, requester_department_id)
           values ('81000000-0000-0000-0000-000000000001','%s','81000000-0000-0000-0000-00000000000a','81000000-0000-0000-0000-0000000000c1','81000000-0000-0000-0000-00000000000a','81000000-0000-0000-0000-0000000000c1')$$, (select id from bi)),
  '23514', null,
  'SUP-1: a CANCELLED booking item cannot acquire a supplier link by direct DML either -- the rule the RPC enforces now holds on both doors');
rollback to savepoint m2;

savepoint m3;
drop trigger internal_supplier_links_guard_integrity on public.internal_supplier_links;
select lives_ok(
  format($$insert into public.internal_supplier_links (tenant_id, booking_item_id, provider_branch_id, provider_department_id, requester_branch_id, requester_department_id)
           values ('81000000-0000-0000-0000-000000000001','%s','81000000-0000-0000-0000-00000000000a','81000000-0000-0000-0000-0000000000c2','81000000-0000-0000-0000-00000000000a','81000000-0000-0000-0000-0000000000c1')$$, (select id from bi)),
  'MUTATION: with internal_supplier_links_guard_integrity dropped the mismatched pair INSERTS -- proving that trigger is the enforcer');
rollback to savepoint m3;

-- ================================================================================================
-- financial_documents -- what is enforced, and what is an open decision.
-- ================================================================================================
create temp table d1 as select app.upload_document('invoice','August invoice','inv.pdf','pdf','booking',(select id from bk),null,null,false) as id;
create temp table d2 as select app.upload_document('invoice','Confidential invoice','inv2.pdf','pdf','booking',(select id from bk),null,null,true) as id;

select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select cmp_ok(
  (select count(*)::int from app.financial_documents()), '>=', 2,
  'POSITIVE CONTROL: a finance_manager holding VIEW_FINANCIAL_DOCUMENTS reads the tenant''s financial documents');

select set_config('request.jwt.claims','{"sub":"81000000-0000-0000-0000-0000000000a2"}',true);
select throws_ok(
  $$select count(*) from app.financial_documents()$$,
  '42501', null,
  'an employee without VIEW_FINANCIAL_DOCUMENTS is refused by the endpoint');

-- The temp tables holding the fixture ids are owned by postgres; the role we are about to become
-- needs to read them. This grants access to the TEST's own scratch tables only.
grant select on d1, d2 to authenticated;

set local role authenticated;
select is(
  (select count(*)::int from public.documents where id = (select id from d2)),
  0,
  'ENFORCED: a CONFIDENTIAL financial document is invisible to that employee through the TABLE too -- this is the property the RLS policy genuinely guarantees');

select is(
  (select count(*)::int from public.documents where id = (select id from d1)),
  0,
  'SPEC-154-B, DECIDED 2026-08-31 (was pinned here as an open owner decision): a NON-confidential financial document is NOT readable by an employee who is not the responsible user -- this booking is the MANAGER''s. Until 202607058700 this returned 1. Full matrix: 82_financial_document_responsibility_test.sql.');
reset role;

select finish();
rollback;
