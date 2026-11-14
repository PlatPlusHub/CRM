-- pgTAP: Batch 6 slice 51 (user_permission_grants, USR-3) --
-- a permission grant is written only with step-up, and every change of who holds what is recorded
-- (`20261114130000`).
-- ATTACK-CLASSES: AUTH TENANT=N/A DOOR STATE=N/A INPUT=N/A CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY
--   TENANT=N/A -- tenant isolation is the unchanged scope policies (tests 10, 83).
--   STATE=N/A -- liveness is the only state; its changes are checked here.
--   INPUT=N/A -- effect and period are the unchanged checks of the table.
--   CONCURRENCY=N/A -- one row per change; no counter or claim.
--   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
--   BUSINESS=N/A -- which permissions a tenant may grant is SUB-3's guard (test 120), unchanged.
create extension if not exists pgtap with schema extensions;

begin;
select plan(10);

insert into auth.users (id, email) values
  ('16700000-0000-0000-0000-0000000000a1','ceo@c167.test'),
  ('16700000-0000-0000-0000-0000000000a2','first@c167.test'),
  ('16700000-0000-0000-0000-0000000000a3','second@c167.test');
insert into public.tenants (id, name, slug, status) values
  ('16700000-0000-0000-0000-000000000001','Grant Travel','grant-travel-167','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '16700000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('16700000-0000-0000-0000-000000000011','16700000-0000-0000-0000-000000000001','Ceo','ceo@c167.test',true,'16700000-0000-0000-0000-0000000000a1'),
  ('16700000-0000-0000-0000-000000000012','16700000-0000-0000-0000-000000000001','First','first@c167.test',true,'16700000-0000-0000-0000-0000000000a2'),
  ('16700000-0000-0000-0000-000000000013','16700000-0000-0000-0000-000000000001','Second','second@c167.test',true,'16700000-0000-0000-0000-0000000000a3');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '16700000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('16700000-0000-0000-0000-000000000011'::uuid,'ceo'),
             ('16700000-0000-0000-0000-000000000012','employee'),
             ('16700000-0000-0000-0000-000000000013','employee')) v(uid, role_code)
join public.roles r on r.code = v.role_code;
insert into public.user_permission_grants (id, tenant_id, user_id, permission_id, effect)
select '16700000-0000-0000-0000-0000000000e1', '16700000-0000-0000-0000-000000000001',
       '16700000-0000-0000-0000-000000000012', p.id, 'grant'
from public.permissions p where p.key = 'VIEW_DEPARTMENT_RECORDS';

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.user_permission_grants'::regclass and not tgisinternal
     and tgname = 'user_permission_grants_guard_authority'),
  1, 'the authority guard is installed on user_permission_grants');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16700000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

select throws_ok(
  $$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
    select '16700000-0000-0000-0000-000000000001', '16700000-0000-0000-0000-000000000011', p.id, 'grant'
    from public.permissions p where p.key = 'VIEW_ADVANCED_DASHBOARDS'$$,
  '42501', 'multi-factor authentication required for this role',
  'USR-3: a ceo cannot grant itself a permission from a password-only session');

select set_config('request.jwt.claims', '{"sub":"16700000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select lives_ok(
  $$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
    select '16700000-0000-0000-0000-000000000001', '16700000-0000-0000-0000-000000000011', p.id, 'grant'
    from public.permissions p where p.key = 'VIEW_ADVANCED_DASHBOARDS'$$,
  'a ceo at aal2 grants a permission');

select lives_ok(
  $$update public.user_permission_grants set user_id = '16700000-0000-0000-0000-000000000013'
    where id = '16700000-0000-0000-0000-0000000000e1'$$,
  'a ceo at aal2 moves a live grant from one user to another');

reset role;

select is(
  (select string_agg(u.full_name || ':' || e.event_type_code, ',' order by u.full_name)
   from public.events e join public.users u on u.id = e.entity_id
   where e.tenant_id = '16700000-0000-0000-0000-000000000001' and e.entity_type = 'user'
     and e.actor_user_id = '16700000-0000-0000-0000-000000000011'
     and e.payload ->> 'permission_key' = 'VIEW_DEPARTMENT_RECORDS'),
  'First:permission_revoked,Second:permission_granted',
  'the move is recorded twice: revoked from the first user, granted to the second');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16700000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select lives_ok(
  $$update public.user_permission_grants set effect = 'deny' where id = '16700000-0000-0000-0000-0000000000e1'$$,
  'a ceo at aal2 turns the live grant into a deny');

select lives_ok(
  $$update public.user_permission_grants set reason = 'reviewed' where id = '16700000-0000-0000-0000-0000000000e1'$$,
  'a reason edit is allowed');

reset role;
select set_config('request.jwt.claims', null, true);

select lives_ok(
  $$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
    select '16700000-0000-0000-0000-000000000001', '16700000-0000-0000-0000-000000000012', p.id, 'grant'
    from public.permissions p where p.key = 'VIEW_ADVANCED_DASHBOARDS'$$,
  'the guard''s one exemption: a session-less platform write grants a permission');

select is(
  (select count(*)::int from public.events e
   where e.tenant_id = '16700000-0000-0000-0000-000000000001' and e.entity_id = '16700000-0000-0000-0000-000000000013'
     and e.event_type_code = 'permission_revoked'),
  2, 'grant to deny is recorded as the grant leaving and the deny taking effect; the reason edit adds nothing');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16700000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);

select throws_ok(
  $$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
    select '16700000-0000-0000-0000-000000000001', '16700000-0000-0000-0000-000000000012', p.id, 'grant'
    from public.permissions p where p.key = 'MANAGE_PERMISSIONS'$$,
  '42501', 'permission denied: MANAGE_PERMISSIONS',
  'an employee cannot grant itself MANAGE_PERMISSIONS');

select * from finish();
rollback;
