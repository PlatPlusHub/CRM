-- pgTAP: SPEC-300 (Batch 6 Slice 45, USR-3, UBA-1, UBA-3, UBA-5) --
-- a placement changes only with the RPC's authority, leaves a record on every door, and is
-- internally consistent (`20261111120000`).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY
--   CONCURRENCY=N/A -- the one race on this table, two current primaries, is refused by the existing
--     unique index; nothing here adds or relies on ordering.
--   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
create extension if not exists pgtap with schema extensions;

begin;
select plan(17);

insert into auth.users (id, email) values
  ('16000000-0000-0000-0000-0000000000a1','ceo@c160.test'),
  ('16000000-0000-0000-0000-0000000000a2','u1@c160.test'),
  ('16000000-0000-0000-0000-0000000000a3','u2@c160.test');
insert into public.tenants (id, name, slug, status) values
  ('16000000-0000-0000-0000-000000000001','Placement Travel','placement-travel-160','active'),
  ('16000000-0000-0000-0000-000000000002','Other Travel','other-travel-160','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '16000000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('16000000-0000-0000-0000-0000000000b1','16000000-0000-0000-0000-000000000001','B1','b1-160'),
  ('16000000-0000-0000-0000-0000000000b2','16000000-0000-0000-0000-000000000001','B2','b2-160'),
  ('16000000-0000-0000-0000-0000000000b9','16000000-0000-0000-0000-000000000002','B9','b9-160');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('16000000-0000-0000-0000-0000000000d1','16000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-0000000000b1','sales','S1'),
  ('16000000-0000-0000-0000-0000000000d2','16000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-0000000000b2','sales','S2');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('16000000-0000-0000-0000-000000000011','16000000-0000-0000-0000-000000000001','CEO','ceo@c160.test',true,'16000000-0000-0000-0000-0000000000a1'),
  ('16000000-0000-0000-0000-000000000012','16000000-0000-0000-0000-000000000001','U1','u1@c160.test',true,'16000000-0000-0000-0000-0000000000a2'),
  ('16000000-0000-0000-0000-000000000013','16000000-0000-0000-0000-000000000001','U2','u2@c160.test',true,'16000000-0000-0000-0000-0000000000a3');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '16000000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('16000000-0000-0000-0000-000000000011'::uuid,'ceo'),
             ('16000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('16000000-0000-0000-0000-000000000013'::uuid,'employee')) v(uid, role_code)
join public.roles r on r.code = v.role_code;
insert into public.user_branch_assignments (id, tenant_id, user_id, branch_id, department_id, is_primary) values
  ('16000000-0000-0000-0000-0000000000e1','16000000-0000-0000-0000-000000000001','16000000-0000-0000-0000-000000000012','16000000-0000-0000-0000-0000000000b1','16000000-0000-0000-0000-0000000000d1',true);

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.user_branch_assignments'::regclass and not tgisinternal
     and tgname in ('user_branch_assignments_guard_authority', 'user_branch_assignments_emit_transfer')
     and pg_get_triggerdef(oid) like '%INSERT OR UPDATE%'),
  2,
  'the authority guard and the emitter both fire on INSERT and UPDATE');

-- The ceo at aal1: the RPC refuses (control), and now so does the table door.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
select throws_ok(
  $$select app.assign_user_branch('16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b2')$$,
  '42501', null,
  'control: the RPC refuses a password-only session');
select throws_ok(
  $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id)
    values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b2')$$,
  '42501', null,
  'USR-3: the direct INSERT at aal1 is refused too (measured before the repair: accepted)');
select throws_ok(
  $$update public.user_branch_assignments set branch_id = '16000000-0000-0000-0000-0000000000b2', department_id = '16000000-0000-0000-0000-0000000000d2'
    where id = '16000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'USR-3: the direct UPDATE at aal1 is refused too (measured before the repair: moved a primary)');

-- The ceo at aal2.
select set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select throws_ok(
  $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id)
    values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b1', '16000000-0000-0000-0000-0000000000d2')$$,
  '23503', null,
  'UBA-3: a department of another branch is refused on the table door, as the RPC refuses it');
select throws_ok(
  $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id, starts_at, ends_at)
    values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b2', now(), now() - interval '1 day')$$,
  '23514', null,
  'UBA-5: a placement cannot end before it starts');
select lives_ok(
  $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id)
    values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b2', '16000000-0000-0000-0000-0000000000d2')$$,
  'the stepped-up administrator still writes through the table door');

select lives_ok(
  $$update public.user_branch_assignments set branch_id = '16000000-0000-0000-0000-0000000000b2', department_id = '16000000-0000-0000-0000-0000000000d2'
    where id = '16000000-0000-0000-0000-0000000000e1'$$,
  'the administrator re-points u1''s primary to B2');
select is(
  (select count(*)::int from public.events
   where entity_id = '16000000-0000-0000-0000-000000000012' and event_type_code = 'user_branch_assignment_changed'
     and payload->'previous'->>'branch_id' = '16000000-0000-0000-0000-0000000000b1'
     and payload->'current'->>'branch_id' = '16000000-0000-0000-0000-0000000000b2'
     and actor_user_id = '16000000-0000-0000-0000-000000000011'),
  1,
  'UBA-1: the re-point is recorded, with both placements and the actor (measured before the repair: 0 events)');

select lives_ok(
  $$update public.user_branch_assignments set reason = 'filed' where id = '16000000-0000-0000-0000-0000000000e1'$$,
  'an edit no reader consumes is accepted');
select is(
  (select count(*)::int from public.events
   where entity_id = '16000000-0000-0000-0000-000000000012' and event_type_code = 'user_branch_assignment_changed'),
  1,
  '...and records nothing: the emitter fires on placement changes, not column churn');

update public.user_branch_assignments set ends_at = now() where id = '16000000-0000-0000-0000-0000000000e1';
select is(
  (select count(*)::int from public.events
   where entity_id = '16000000-0000-0000-0000-000000000012' and event_type_code = 'user_branch_assignment_changed'
     and payload->'previous'->>'ends_at' is null and payload->'current'->>'ends_at' is not null),
  1,
  'UBA-1: ending a placement is recorded');

update public.user_branch_assignments set user_id = '16000000-0000-0000-0000-000000000013' where id = '16000000-0000-0000-0000-0000000000e1';
select is(
  (select count(*)::int from public.events
   where entity_id in ('16000000-0000-0000-0000-000000000012', '16000000-0000-0000-0000-000000000013')
     and event_type_code = 'user_branch_assignment_changed'
     and payload->'current'->>'user_id' = '16000000-0000-0000-0000-000000000013'
     and payload->'previous'->>'user_id' = '16000000-0000-0000-0000-000000000012'),
  2,
  'UBA-1: a row handed to another user is recorded for both of them');

-- An employee is still refused by RLS before the guard is reached.
select set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select throws_ok(
  $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id)
    values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000012', '16000000-0000-0000-0000-0000000000b2')$$,
  '42501', null,
  'an employee is refused by RLS, unchanged');

-- No session (migrations, seeds, provisioning): exempt from the charge, as every sibling guard is.
reset role;
select set_config('request.jwt.claims', '', true);
select lives_ok(
  $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id)
    values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000012', '16000000-0000-0000-0000-0000000000b1')$$,
  'a platform path without a session still places a user');

-- Back to the stepped-up administrator: the tenant boundary, and the RPC's own record.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select throws_ok(
  $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id)
    values ('16000000-0000-0000-0000-000000000001', '16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b9')$$,
  '23503', null,
  'a branch of another tenant is refused on the table door (the tenant-composite FK), unchanged');
do $$ begin perform app.assign_user_branch('16000000-0000-0000-0000-000000000013', '16000000-0000-0000-0000-0000000000b1'); end $$;
select is(
  (select count(*) filter (where event_type_code = 'user_branch_transfer_completed') || '/' ||
          count(*) filter (where event_type_code = 'user_branch_assignment_changed')
   from public.events where entity_id = '16000000-0000-0000-0000-000000000013'),
  '1/1',
  'the RPC records its own transfer once, and the UPDATE emitter adds nothing to it (the 1 change is the hand-over)');

select * from finish();
rollback;
