-- pgTAP: Batch 6 slice 54 (holidays) --
-- a holiday is written only by a tenant settings holder, in its own tenant (no migration: the
-- door held when probed, so this file pins it).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE=N/A INPUT=N/A CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
--   STATE=N/A -- a holiday has no lifecycle: no status and no archive.
--   INPUT=N/A -- a blank name and a second holiday on the same date are recorded positions: no
--     function, policy or view reads holidays, so neither changes what any reader decides.
--   CONCURRENCY, REPLAY=N/A -- each holiday is its own row; adding one twice is two rows, and
--     nothing reads them.
--   BUSINESS=N/A -- a holiday carries no money.
--   OBSERVABILITY=N/A -- holidays record no event on any door; a recorded position (tenant settings
--     that nothing reads).
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email) values
  ('17400000-0000-0000-0000-0000000000a1','employee@c174.test'),
  ('17400000-0000-0000-0000-0000000000a2','owner@c174.test'),
  ('17400000-0000-0000-0000-0000000000a3','manager@c174.test'),
  ('17400000-0000-0000-0000-0000000000a4','other@c174.test');
insert into public.tenants (id, name, slug, status) values
  ('17400000-0000-0000-0000-000000000001','Holiday Travel','holiday-travel-174','active'),
  ('17400000-0000-0000-0000-000000000002','Other Travel','other-travel-174','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select v.t, sp.id, 'active' from public.subscription_plans sp,
  (values ('17400000-0000-0000-0000-000000000001'::uuid), ('17400000-0000-0000-0000-000000000002')) v(t)
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('17400000-0000-0000-0000-00000000000a','17400000-0000-0000-0000-000000000001','Giza','giza-174');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('17400000-0000-0000-0000-0000000000c1','17400000-0000-0000-0000-000000000001','17400000-0000-0000-0000-00000000000a','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('17400000-0000-0000-0000-000000000011','17400000-0000-0000-0000-000000000001','Employee','employee@c174.test',true,'17400000-0000-0000-0000-0000000000a1'),
  ('17400000-0000-0000-0000-000000000012','17400000-0000-0000-0000-000000000001','Owner','owner@c174.test',true,'17400000-0000-0000-0000-0000000000a2'),
  ('17400000-0000-0000-0000-000000000013','17400000-0000-0000-0000-000000000001','Manager','manager@c174.test',true,'17400000-0000-0000-0000-0000000000a3'),
  ('17400000-0000-0000-0000-000000000014','17400000-0000-0000-0000-000000000002','Other','other@c174.test',true,'17400000-0000-0000-0000-0000000000a4');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('17400000-0000-0000-0000-000000000001','17400000-0000-0000-0000-000000000011','17400000-0000-0000-0000-00000000000a','17400000-0000-0000-0000-0000000000c1',true),
  ('17400000-0000-0000-0000-000000000001','17400000-0000-0000-0000-000000000013','17400000-0000-0000-0000-00000000000a','17400000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values
  ('17400000-0000-0000-0000-000000000001'::uuid, '17400000-0000-0000-0000-000000000011'::uuid, 'employee'),
  ('17400000-0000-0000-0000-000000000001', '17400000-0000-0000-0000-000000000012', 'owner'),
  ('17400000-0000-0000-0000-000000000001', '17400000-0000-0000-0000-000000000013', 'branch_manager'),
  ('17400000-0000-0000-0000-000000000002', '17400000-0000-0000-0000-000000000014', 'owner')) v(t, u, c)
join public.roles r on r.code = v.c;

select is(
  (select string_agg(p || '=' || has_table_privilege('authenticated', 'public.holidays', p), ' ' order by p)
   from unnest(array['DELETE', 'INSERT', 'SELECT', 'UPDATE']) p),
  'DELETE=false INSERT=true SELECT=true UPDATE=true', 'the grants are unchanged: a holiday is added and edited, never deleted');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17400000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select lives_ok(
  $$insert into public.holidays (id, tenant_id, name, holiday_date) values
    ('17400000-0000-0000-0000-0000000000e1','17400000-0000-0000-0000-000000000001','New Year','2026-01-01')$$,
  'the owner at aal2 adds a tenant-wide holiday');
select lives_ok(
  $$insert into public.holidays (tenant_id, branch_id, name, holiday_date) values
    ('17400000-0000-0000-0000-000000000001','17400000-0000-0000-0000-00000000000a','Giza Day','2026-05-01')$$,
  'the owner at aal2 adds a branch holiday');
select throws_ok(
  $$delete from public.holidays where id = '17400000-0000-0000-0000-0000000000e1'$$,
  '42501', null, 'not even the owner at aal2 deletes a holiday');

select set_config('request.jwt.claims', '{"sub":"17400000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select throws_ok(
  $$insert into public.holidays (tenant_id, name, holiday_date) values
    ('17400000-0000-0000-0000-000000000001','Eid','2026-03-20')$$,
  '42501', null, 'the owner at aal1 is refused: a tenant setting needs the second factor');

select set_config('request.jwt.claims', '{"sub":"17400000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
select is(
  (select count(*)::int from public.holidays where tenant_id = '17400000-0000-0000-0000-000000000001'),
  2, 'an employee reads the tenant''s holidays');
select throws_ok(
  $$insert into public.holidays (tenant_id, name, holiday_date) values
    ('17400000-0000-0000-0000-000000000001','Day off','2026-04-01')$$,
  '42501', null, 'an employee cannot add a holiday');
select throws_ok(
  $$update public.holidays set holiday_date = '2026-01-02' where id = '17400000-0000-0000-0000-0000000000e1'$$,
  '42501', null, 'an employee cannot move a holiday');

select set_config('request.jwt.claims', '{"sub":"17400000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
select throws_ok(
  $$insert into public.holidays (tenant_id, branch_id, name, holiday_date) values
    ('17400000-0000-0000-0000-000000000001','17400000-0000-0000-0000-00000000000a','Branch day','2026-04-01')$$,
  '42501', null, 'a branch manager cannot add even their own branch''s holiday');

select set_config('request.jwt.claims', '{"sub":"17400000-0000-0000-0000-0000000000a4","aal":"aal2"}', true);
select is(
  (select count(*)::int from public.holidays where tenant_id = '17400000-0000-0000-0000-000000000001'),
  0, 'another tenant''s owner sees none of the tenant''s holidays');
select throws_ok(
  $$insert into public.holidays (tenant_id, name, holiday_date) values
    ('17400000-0000-0000-0000-000000000001','Other day','2026-04-01')$$,
  '42501', null, 'another tenant''s owner cannot add a holiday for the tenant');

select * from finish();
rollback;
