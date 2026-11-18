-- pgTAP: Batch 6 slice 57 (role_permissions, permissions, roles) --
-- the role and permission matrix is fixed, platform-owned product reference data (RBAC-2; per-user
-- grants and denies are RBAC-5's user_permission_grants, not these tables): every member of every
-- tenant reads all of it, no member writes any of it (an owner at aal2 is refused by the missing grant),
-- anon and orvion_integration hold no privilege on it, and no role holds the platform authority
-- REVIEW_SUBSCRIPTION_PAYMENT (test 42 pins MANAGE_SUBSCRIPTION). The authority readers
-- honour is_active: a deactivated permission is gone from app.has_permission, app.effective_permissions
-- and app.eligible_lead_handlers and a user grant does not win it back; a deactivated role drops the
-- same three and app.requires_mfa; app.assign_user_role refuses an inactive role. Each is proven after
-- a positive control. No migration: each door held when probed, so this file pins what was measured and
-- was not yet pinned (tests 10, 30, 31 and 42 keep the grant ceiling, the plan gate, the employee-role
-- deactivation of CREATE_CUSTOMER and MANAGE_SUBSCRIPTION).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
--   CONCURRENCY, REPLAY=N/A -- only migrations write the three tables; no member or function path
--     writes them, so there is no race or replay to attack.
--   BUSINESS=N/A -- the matrix carries no amount or limit; the plan gate is test 30's.
--   OBSERVABILITY=N/A -- a migration's change to the matrix records no event by design; the
--     member-facing writes are refused before any row or event exists.
create extension if not exists pgtap with schema extensions;

begin;
select plan(14);

select set_config('t179.totals',
  (select count(*) from public.role_permissions)::text || '/' || (select count(*) from public.permissions)
    || '/' || (select count(*) from public.roles), true);

insert into auth.users (id, email) values
  ('17900000-0000-0000-0000-0000000000a1','owner@c179.test'),
  ('17900000-0000-0000-0000-0000000000a2','employee@c179.test'),
  ('17900000-0000-0000-0000-0000000000a3','trainee@c179.test'),
  ('17900000-0000-0000-0000-0000000000a4','manager@c179.test'),
  ('17900000-0000-0000-0000-0000000000a5','other@c179.test');
insert into public.tenants (id, name, slug, status) values
  ('17900000-0000-0000-0000-000000000001','Matrix Travel','matrix-travel-179','active'),
  ('17900000-0000-0000-0000-000000000002','Other Travel','other-travel-179','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code, starts_at)
select v.t, sp.id, 'active', now() - interval '2 days' from public.subscription_plans sp,
  (values ('17900000-0000-0000-0000-000000000001'::uuid), ('17900000-0000-0000-0000-000000000002')) v(t)
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('17900000-0000-0000-0000-0000000000b1','17900000-0000-0000-0000-000000000001','Giza','giza-179');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('17900000-0000-0000-0000-0000000000c1','17900000-0000-0000-0000-000000000001','17900000-0000-0000-0000-0000000000b1','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('17900000-0000-0000-0000-000000000011','17900000-0000-0000-0000-000000000001','Owner','owner@c179.test',true,'17900000-0000-0000-0000-0000000000a1'),
  ('17900000-0000-0000-0000-000000000012','17900000-0000-0000-0000-000000000001','Employee','employee@c179.test',true,'17900000-0000-0000-0000-0000000000a2'),
  ('17900000-0000-0000-0000-000000000013','17900000-0000-0000-0000-000000000001','Trainee','trainee@c179.test',true,'17900000-0000-0000-0000-0000000000a3'),
  ('17900000-0000-0000-0000-000000000014','17900000-0000-0000-0000-000000000001','Manager','manager@c179.test',true,'17900000-0000-0000-0000-0000000000a4'),
  ('17900000-0000-0000-0000-000000000015','17900000-0000-0000-0000-000000000002','Other','other@c179.test',true,'17900000-0000-0000-0000-0000000000a5');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '17900000-0000-0000-0000-000000000001', u, '17900000-0000-0000-0000-0000000000b1', '17900000-0000-0000-0000-0000000000c1', true
from unnest(array['17900000-0000-0000-0000-000000000012','17900000-0000-0000-0000-000000000013','17900000-0000-0000-0000-000000000014']::uuid[]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values
  ('17900000-0000-0000-0000-000000000001'::uuid, '17900000-0000-0000-0000-000000000011'::uuid, 'owner'),
  ('17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-000000000012', 'employee'),
  ('17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-000000000013', 'trainee'),
  ('17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-000000000014', 'branch_manager'),
  ('17900000-0000-0000-0000-000000000002', '17900000-0000-0000-0000-000000000015', 'owner')) v(t, u, c)
join public.roles r on r.code = v.c;

select is(
  (select count(*) from public.permissions where key = 'REVIEW_SUBSCRIPTION_PAYMENT')::text || '/'
    || (select count(*) from public.role_permissions rp join public.permissions p on p.id = rp.permission_id
        where p.key = 'REVIEW_SUBSCRIPTION_PAYMENT'),
  '1/0', 'REVIEW_SUBSCRIPTION_PAYMENT exists and no role holds it: platform authority stays out of the tenant role matrix');
select is(
  (select count(*)::int from unnest(array['anon','orvion_integration']) r,
     unnest(array['public.role_permissions','public.permissions','public.roles']) t,
     unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
   where has_table_privilege(r, t, p)),
  0, 'anon and orvion_integration hold no privilege of any kind on the three tables');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a3","aal":"aal1"}', true);
select is(
  (select count(*) from public.role_permissions)::text || '/' || (select count(*) from public.permissions)
    || '/' || (select count(*) from public.roles),
  current_setting('t179.totals'),
  'a trainee at aal1 reads the whole role and permission matrix: product reference data, not tenant data');

select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a5","aal":"aal2"}', true);
select is(
  (select count(*) from public.role_permissions)::text || '/' || (select count(*) from public.permissions)
    || '/' || (select count(*) from public.roles),
  current_setting('t179.totals'),
  'another tenant''s owner reads the same whole matrix');

select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select throws_ok(
  $$insert into public.role_permissions (role_id, permission_id)
    select (select id from public.roles where code = 'trainee'), id from public.permissions where key = 'MANAGE_PERMISSIONS'$$,
  '42501', 'permission denied for table role_permissions',
  'the owner at aal2 cannot grant a role a permission: no member holds INSERT on the matrix');
select throws_ok(
  $$update public.permissions set required_feature_code = null where key = 'CREATE_BOOKING'$$,
  '42501', 'permission denied for table permissions',
  'the owner at aal2 cannot lift a permission''s plan gate: no member holds UPDATE on permissions');
select throws_ok(
  $$update public.roles set is_active = false where code = 'trainee'$$,
  '42501', 'permission denied for table roles',
  'the owner at aal2 cannot deactivate a role: no member holds UPDATE on roles');

select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select is(
  app.has_permission('CLOSE_LEAD')::text || '/' || (select count(*) from app.effective_permissions() where permission_key = 'CLOSE_LEAD')
    || '/' || coalesce((select string_agg(h::text, ',' order by h) from app.eligible_lead_handlers(
      '17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-0000000000b1', '17900000-0000-0000-0000-0000000000c1') h), ''),
  'true/1/17900000-0000-0000-0000-000000000012,17900000-0000-0000-0000-000000000014',
  'control: the employee holds CLOSE_LEAD by its role and is, with the branch manager, an eligible lead handler');

reset role;
update public.permissions set is_active = false where key = 'CLOSE_LEAD';
set local role authenticated;
select is(
  app.has_permission('CLOSE_LEAD')::text || '/' || (select count(*) from app.effective_permissions() where permission_key = 'CLOSE_LEAD')
    || '/' || coalesce((select string_agg(h::text, ',' order by h) from app.eligible_lead_handlers(
      '17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-0000000000b1', '17900000-0000-0000-0000-0000000000c1') h), ''),
  'false/0/',
  'a deactivated permission is gone from has_permission, effective_permissions and the lead handler pool');

reset role;
-- the grant guard asks who grants: the tenant's owner at aal2, who holds MANAGE_PERMISSIONS
select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
select '17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-000000000012', id, 'grant'
from public.permissions where key = 'CLOSE_LEAD';
select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
set local role authenticated;
select is(app.has_permission('CLOSE_LEAD'), false,
  'a user grant does not win back a deactivated permission');

reset role;
delete from public.user_permission_grants where user_id = '17900000-0000-0000-0000-000000000012';
update public.permissions set is_active = true where key = 'CLOSE_LEAD';
update public.roles set is_active = false where code = 'employee';
set local role authenticated;
select is(
  app.has_permission('CLOSE_LEAD')::text || '/' || (select count(*) from app.effective_permissions() where permission_key = 'CLOSE_LEAD')
    || '/' || coalesce((select string_agg(h::text, ',' order by h) from app.eligible_lead_handlers(
      '17900000-0000-0000-0000-000000000001', '17900000-0000-0000-0000-0000000000b1', '17900000-0000-0000-0000-0000000000c1') h), '') || '/' || (select count(*) from app.effective_permissions() where from_role),
  'false/1/17900000-0000-0000-0000-000000000014/0',
  'a deactivated role grants nothing: no CLOSE_LEAD, no permission from the role, and only the branch manager stays a handler');

reset role;
update public.roles set is_active = true where code = 'employee';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17900000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select is(app.requires_mfa()::text || '/' || app.has_permission('MANAGE_PERMISSIONS'), 'true/true',
  'control: the owner requires MFA and holds MANAGE_PERMISSIONS');

reset role;
update public.roles set is_active = false where code = 'senior_employee';
set local role authenticated;
select throws_ok(
  $$select app.assign_user_role('17900000-0000-0000-0000-000000000013', 'senior_employee')$$,
  'P0001', 'unknown or inactive role: senior_employee',
  'the owner at aal2 cannot assign a deactivated role');

reset role;
update public.roles set is_active = false where code = 'owner';
set local role authenticated;
select is(app.requires_mfa()::text || '/' || app.has_permission('MANAGE_PERMISSIONS'), 'false/false',
  'a deactivated owner role neither requires MFA nor grants MANAGE_PERMISSIONS: the readers agree');

select * from finish();
rollback;
