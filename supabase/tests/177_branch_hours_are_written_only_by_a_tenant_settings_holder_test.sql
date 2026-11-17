-- pgTAP: Batch 6 slice 55 (branch_business_hours) --
-- a branch's hours are written only by a holder of MANAGE_BRANCHES at aal2, in its own tenant (no
-- migration: the door held when probed, so this file pins it).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE=N/A INPUT=N/A CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
--   STATE=N/A -- an hours row has no lifecycle: no status and no archive.
--   INPUT=N/A -- a day outside 0-6, closing before opening, closed with times, two rows for one
--     branch and day, a written `created_at` and a move between the tenant's branches are recorded
--     positions: no function, policy or view reads the hours, so none changes what any reader
--     decides.
--   CONCURRENCY, REPLAY=N/A -- each row is its own row; adding one twice is two rows, and nothing
--     reads them.
--   BUSINESS=N/A -- hours carry no money.
--   OBSERVABILITY=N/A -- hours record no event on any door; a recorded position (tenant settings
--     that nothing reads).
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email) values
  ('17700000-0000-0000-0000-0000000000a1','employee@c177.test'),
  ('17700000-0000-0000-0000-0000000000a2','owner@c177.test'),
  ('17700000-0000-0000-0000-0000000000a3','manager@c177.test'),
  ('17700000-0000-0000-0000-0000000000a4','other@c177.test');
insert into public.tenants (id, name, slug, status) values
  ('17700000-0000-0000-0000-000000000001','Hours Travel','hours-travel-177','active'),
  ('17700000-0000-0000-0000-000000000002','Other Travel','other-travel-177','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select v.t, sp.id, 'active' from public.subscription_plans sp,
  (values ('17700000-0000-0000-0000-000000000001'::uuid), ('17700000-0000-0000-0000-000000000002')) v(t)
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('17700000-0000-0000-0000-00000000000a','17700000-0000-0000-0000-000000000001','Giza','giza-177');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('17700000-0000-0000-0000-0000000000c1','17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-00000000000a','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('17700000-0000-0000-0000-000000000011','17700000-0000-0000-0000-000000000001','Employee','employee@c177.test',true,'17700000-0000-0000-0000-0000000000a1'),
  ('17700000-0000-0000-0000-000000000012','17700000-0000-0000-0000-000000000001','Owner','owner@c177.test',true,'17700000-0000-0000-0000-0000000000a2'),
  ('17700000-0000-0000-0000-000000000013','17700000-0000-0000-0000-000000000001','Manager','manager@c177.test',true,'17700000-0000-0000-0000-0000000000a3'),
  ('17700000-0000-0000-0000-000000000014','17700000-0000-0000-0000-000000000002','Other','other@c177.test',true,'17700000-0000-0000-0000-0000000000a4');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-000000000011','17700000-0000-0000-0000-00000000000a','17700000-0000-0000-0000-0000000000c1',true),
  ('17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-000000000013','17700000-0000-0000-0000-00000000000a','17700000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values
  ('17700000-0000-0000-0000-000000000001'::uuid, '17700000-0000-0000-0000-000000000011'::uuid, 'employee'),
  ('17700000-0000-0000-0000-000000000001', '17700000-0000-0000-0000-000000000012', 'owner'),
  ('17700000-0000-0000-0000-000000000001', '17700000-0000-0000-0000-000000000013', 'branch_manager'),
  ('17700000-0000-0000-0000-000000000002', '17700000-0000-0000-0000-000000000014', 'owner')) v(t, u, c)
join public.roles r on r.code = v.c;

select is(
  (select string_agg(p || '=' || has_table_privilege('authenticated', 'public.branch_business_hours', p), ' ' order by p)
   from unnest(array['DELETE', 'INSERT', 'SELECT', 'UPDATE']) p),
  'DELETE=false INSERT=true SELECT=true UPDATE=true', 'the grants are unchanged: hours are added and edited, never deleted');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17700000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select lives_ok(
  $$insert into public.branch_business_hours (id, tenant_id, branch_id, day_of_week, opens_at, closes_at) values
    ('17700000-0000-0000-0000-0000000000e1','17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-00000000000a',1,'09:00','17:00')$$,
  'the owner at aal2 sets Monday''s hours');
select lives_ok(
  $$update public.branch_business_hours set closes_at = '18:00' where id = '17700000-0000-0000-0000-0000000000e1'$$,
  'the owner at aal2 edits them');
select throws_ok(
  $$delete from public.branch_business_hours where id = '17700000-0000-0000-0000-0000000000e1'$$,
  '42501', null, 'not even the owner at aal2 deletes an hours row');

select set_config('request.jwt.claims', '{"sub":"17700000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select throws_ok(
  $$insert into public.branch_business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at) values
    ('17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-00000000000a',2,'09:00','17:00')$$,
  '42501', null, 'the owner at aal1 is refused: a branch setting needs the second factor');

select set_config('request.jwt.claims', '{"sub":"17700000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select is(
  (select count(*)::int from public.branch_business_hours where tenant_id = '17700000-0000-0000-0000-000000000001'),
  1, 'an employee reads the tenant''s hours');
select throws_ok(
  $$update public.branch_business_hours set opens_at = '06:00' where id = '17700000-0000-0000-0000-0000000000e1'$$,
  '42501', null, 'an employee cannot change the hours');

select set_config('request.jwt.claims', '{"sub":"17700000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
select throws_ok(
  $$insert into public.branch_business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at) values
    ('17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-00000000000a',3,'09:00','17:00')$$,
  '42501', null, 'a branch manager cannot set even their own branch''s hours');
select throws_ok(
  $$update public.branch_business_hours set closes_at = '23:00' where id = '17700000-0000-0000-0000-0000000000e1'$$,
  '42501', null, 'a branch manager cannot change their own branch''s hours');

select set_config('request.jwt.claims', '{"sub":"17700000-0000-0000-0000-0000000000a4","aal":"aal2"}', true);
select is(
  (select count(*)::int from public.branch_business_hours where tenant_id = '17700000-0000-0000-0000-000000000001'),
  0, 'another tenant''s owner sees none of the tenant''s hours');
select throws_ok(
  $$insert into public.branch_business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at) values
    ('17700000-0000-0000-0000-000000000001','17700000-0000-0000-0000-00000000000a',4,'09:00','17:00')$$,
  '42501', null, 'another tenant''s owner cannot set the tenant''s hours');

select * from finish();
rollback;
