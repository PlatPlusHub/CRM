-- pgTAP: Batch 6 slice 4 (DEP-1, DEP-2, DEP-3) --
-- a department stays in its branch, and changes only with the RPC's authority and a record on
-- every door (`20261111130000`).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY
--   CONCURRENCY=N/A -- the one race on this table, two active departments of one name in a branch, is
--     refused by the existing partial unique index; nothing here adds or relies on ordering.
--   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
create extension if not exists pgtap with schema extensions;

begin;
select plan(17);

insert into auth.users (id, email) values
  ('16100000-0000-0000-0000-0000000000a1','ceo@c161.test'),
  ('16100000-0000-0000-0000-0000000000a2','u1@c161.test');
insert into public.tenants (id, name, slug, status) values
  ('16100000-0000-0000-0000-000000000001','Department Travel','department-travel-161','active'),
  ('16100000-0000-0000-0000-000000000002','Other Travel','other-travel-161','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '16100000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('16100000-0000-0000-0000-0000000000b1','16100000-0000-0000-0000-000000000001','B1','b1-161'),
  ('16100000-0000-0000-0000-0000000000b2','16100000-0000-0000-0000-000000000001','B2','b2-161'),
  ('16100000-0000-0000-0000-0000000000b9','16100000-0000-0000-0000-000000000002','B9','b9-161');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('16100000-0000-0000-0000-0000000000d1','16100000-0000-0000-0000-000000000001','16100000-0000-0000-0000-0000000000b1','sales','S1'),
  ('16100000-0000-0000-0000-0000000000d3','16100000-0000-0000-0000-000000000001','16100000-0000-0000-0000-0000000000b1','operations','O3');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('16100000-0000-0000-0000-000000000011','16100000-0000-0000-0000-000000000001','CEO','ceo@c161.test',true,'16100000-0000-0000-0000-0000000000a1'),
  ('16100000-0000-0000-0000-000000000012','16100000-0000-0000-0000-000000000001','U1','u1@c161.test',true,'16100000-0000-0000-0000-0000000000a2');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '16100000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('16100000-0000-0000-0000-000000000011'::uuid,'ceo'),
             ('16100000-0000-0000-0000-000000000012'::uuid,'employee')) v(uid, role_code)
join public.roles r on r.code = v.role_code;

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.departments'::regclass and not tgisinternal
     and tgname in ('departments_guard_write', 'departments_emit_change')
     and pg_get_triggerdef(oid) like '%INSERT OR UPDATE%'),
  2,
  'the guard and the emitter both fire on INSERT and UPDATE');

-- The ceo at aal1: the RPC refuses (control), and now so does the table door.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16100000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
select throws_ok(
  $$select app.create_department('16100000-0000-0000-0000-0000000000b1', 'sales', 'RPC aal1')$$,
  '42501', null,
  'control: the RPC refuses a password-only session');
select throws_ok(
  $$insert into public.departments (tenant_id, branch_id, department_type_code, name)
    values ('16100000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-0000000000b2', 'sales', 'Door aal1')$$,
  '42501', null,
  'DEP-1: the direct INSERT at aal1 is refused too (measured before the repair: created)');
select throws_ok(
  $$update public.departments set name = 'Hijacked', is_active = false where id = '16100000-0000-0000-0000-0000000000d1'$$,
  '42501', null,
  'DEP-1: the direct UPDATE at aal1 is refused too (measured before the repair: renamed and deactivated)');

-- The ceo at aal2.
select set_config('request.jwt.claims', '{"sub":"16100000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select throws_ok(
  $$update public.departments set branch_id = '16100000-0000-0000-0000-0000000000b2' where id = '16100000-0000-0000-0000-0000000000d3'$$,
  '23514', null,
  'DEP-3: a department cannot move to another branch, even unplaced (measured before the repair: moved, stranding its lead)');
select is(
  (select branch_id::text from public.departments where id = '16100000-0000-0000-0000-0000000000d3'),
  '16100000-0000-0000-0000-0000000000b1',
  '...and it is still in its branch');

select lives_ok(
  $$insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
    values ('16100000-0000-0000-0000-0000000000d4', '16100000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-0000000000b2', 'sales', 'Door aal2')$$,
  'the stepped-up administrator still writes through the table door');
select is(
  (select count(*)::int from public.events
   where entity_id = '16100000-0000-0000-0000-0000000000d4' and event_type_code = 'department_created'
     and payload->>'name' = 'Door aal2' and actor_user_id = '16100000-0000-0000-0000-000000000011'),
  1,
  'DEP-2: the door''s creation is recorded, with the actor (measured before the repair: 0 events)');

update public.departments set name = 'Renamed', is_active = false where id = '16100000-0000-0000-0000-0000000000d4';
select is(
  (select count(*)::int from public.events
   where entity_id = '16100000-0000-0000-0000-0000000000d4' and event_type_code = 'department_changed'
     and payload->'previous'->>'name' = 'Door aal2' and payload->'current'->>'name' = 'Renamed'
     and payload->'current'->>'is_active' = 'false' and new_state = 'inactive'
     and actor_user_id = '16100000-0000-0000-0000-000000000011'),
  1,
  'DEP-2: a rename and deactivation is recorded once, with both states and the actor (measured before the repair: 0 events)');

update public.departments set updated_at = now() where id = '16100000-0000-0000-0000-0000000000d4';
select is(
  (select count(*)::int from public.events
   where entity_id = '16100000-0000-0000-0000-0000000000d4' and event_type_code = 'department_changed'),
  1,
  '...and an update that moves no name, type or active flag records nothing');

select lives_ok(
  $$select app.create_department('16100000-0000-0000-0000-0000000000b1', 'sales', 'RPC aal2')$$,
  'the RPC still creates a department');
select is(
  (select count(*)::int from public.events e join public.departments d on d.id = e.entity_id
   where d.name = 'RPC aal2' and e.event_type_code = 'department_created'),
  1,
  'the RPC''s creation is recorded exactly once (its own call moved to the trigger, not duplicated)');

select throws_ok(
  $$insert into public.departments (tenant_id, branch_id, department_type_code, name)
    values ('16100000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-0000000000b9', 'sales', 'Elsewhere')$$,
  '23503', null,
  'a branch of another tenant is refused on the table door (the tenant-composite FK), unchanged');

-- An employee is refused before any write.
select set_config('request.jwt.claims', '{"sub":"16100000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select throws_ok(
  $$insert into public.departments (tenant_id, branch_id, department_type_code, name)
    values ('16100000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-0000000000b1', 'sales', 'Emp')$$,
  '42501', null,
  'an employee is refused, unchanged');

-- No session (migrations, seeds, provisioning): exempt from the charge and silent, as before; the
-- branch is fixed on this path too.
reset role;
select set_config('request.jwt.claims', '', true);
select lives_ok(
  $$insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
    values ('16100000-0000-0000-0000-0000000000d5', '16100000-0000-0000-0000-000000000001', '16100000-0000-0000-0000-0000000000b1', 'sales', 'Platform')$$,
  'a platform path without a session still creates a department');
select is(
  (select count(*)::int from public.events where entity_id = '16100000-0000-0000-0000-0000000000d5'),
  0,
  '...and records nothing, as before the repair');
select throws_ok(
  $$update public.departments set branch_id = '16100000-0000-0000-0000-0000000000b2' where id = '16100000-0000-0000-0000-0000000000d5'$$,
  '23514', null,
  'DEP-3: the branch is fixed on the session-less path too');

select * from finish();
rollback;
