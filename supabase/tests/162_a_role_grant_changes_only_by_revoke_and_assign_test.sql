-- pgTAP: Batch 6 slice 5 (URA-1, URA-2, URA-3) --
-- a role grant's holder, role, scope and start are fixed once written; a session changes a grant only
-- by ending it or starting it, which is charged and recorded (`20261111140000`).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY
--   CONCURRENCY=N/A -- the guard reads only the row's own OLD and NEW images; no ordering is relied on.
--   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
create extension if not exists pgtap with schema extensions;

begin;
select plan(19);

insert into auth.users (id, email) values
  ('16200000-0000-0000-0000-0000000000a1','ceo@c162.test'),
  ('16200000-0000-0000-0000-0000000000a2','owner@c162.test'),
  ('16200000-0000-0000-0000-0000000000a3','e@c162.test'),
  ('16200000-0000-0000-0000-0000000000a4','x@c162.test'),
  ('16200000-0000-0000-0000-0000000000a5','lone@c162.test');
insert into public.tenants (id, name, slug, status) values
  ('16200000-0000-0000-0000-000000000001','Role Travel','role-travel-162','active'),
  ('16200000-0000-0000-0000-000000000003','Lone Travel','lone-travel-162','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  (values ('16200000-0000-0000-0000-000000000001'::uuid), ('16200000-0000-0000-0000-000000000003'::uuid)) v(t)
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('16200000-0000-0000-0000-0000000000b1','16200000-0000-0000-0000-000000000001','B1','b1-162'),
  ('16200000-0000-0000-0000-0000000000b2','16200000-0000-0000-0000-000000000001','B2','b2-162');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('16200000-0000-0000-0000-000000000011','16200000-0000-0000-0000-000000000001','CEO','ceo@c162.test',true,'16200000-0000-0000-0000-0000000000a1'),
  ('16200000-0000-0000-0000-000000000012','16200000-0000-0000-0000-000000000001','Owner','owner@c162.test',true,'16200000-0000-0000-0000-0000000000a2'),
  ('16200000-0000-0000-0000-000000000013','16200000-0000-0000-0000-000000000001','E','e@c162.test',true,'16200000-0000-0000-0000-0000000000a3'),
  ('16200000-0000-0000-0000-000000000014','16200000-0000-0000-0000-000000000001','X','x@c162.test',true,'16200000-0000-0000-0000-0000000000a4'),
  ('16200000-0000-0000-0000-000000000015','16200000-0000-0000-0000-000000000003','Lone','lone@c162.test',true,'16200000-0000-0000-0000-0000000000a5');
insert into public.user_role_assignments (id, tenant_id, user_id, role_id, scope_type, branch_id, is_active)
select v.id, v.tid, v.uid, r.id, v.scope, v.br, v.live
from (values
  ('16200000-0000-0000-0000-0000000000e1'::uuid,'16200000-0000-0000-0000-000000000001'::uuid,'16200000-0000-0000-0000-000000000011'::uuid,'ceo','tenant',null::uuid,true),
  ('16200000-0000-0000-0000-0000000000e2','16200000-0000-0000-0000-000000000001','16200000-0000-0000-0000-000000000012','owner','tenant',null,true),
  ('16200000-0000-0000-0000-0000000000e3','16200000-0000-0000-0000-000000000001','16200000-0000-0000-0000-000000000013','employee','tenant',null,true),
  ('16200000-0000-0000-0000-0000000000e4','16200000-0000-0000-0000-000000000001','16200000-0000-0000-0000-000000000014','employee','branch','16200000-0000-0000-0000-0000000000b1',true),
  ('16200000-0000-0000-0000-0000000000e5','16200000-0000-0000-0000-000000000001','16200000-0000-0000-0000-000000000014','trainee','tenant',null,true),
  ('16200000-0000-0000-0000-0000000000e6','16200000-0000-0000-0000-000000000003','16200000-0000-0000-0000-000000000015','owner','tenant',null,true),
  ('16200000-0000-0000-0000-0000000000e7','16200000-0000-0000-0000-000000000001','16200000-0000-0000-0000-000000000013','senior_employee','tenant',null,true),
  ('16200000-0000-0000-0000-0000000000e8','16200000-0000-0000-0000-000000000001','16200000-0000-0000-0000-000000000014','senior_employee','tenant',null,false)
) v(id, tid, uid, code, scope, br, live)
join public.roles r on r.code = v.code;

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.user_role_assignments'::regclass and not tgisinternal
     and tgname = 'user_role_assignments_guard_change'
     and pg_get_triggerdef(oid) like '%BEFORE UPDATE ON public.user_role_assignments%'),
  1,
  'the guard fires BEFORE UPDATE');

-- The ceo at aal1: the RPC refuses (control), and so does every re-point at the door.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16200000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
select throws_ok(
  $$select app.assign_user_role('16200000-0000-0000-0000-000000000013', 'owner')$$,
  '42501', null,
  'control: the RPC refuses a password-only session');
select throws_ok(
  $$update public.user_role_assignments set role_id = (select id from public.roles where code = 'owner')
     where id = '16200000-0000-0000-0000-0000000000e3'$$,
  '23514', null,
  'URA-1: an employee''s live grant cannot be re-pointed to owner (measured before the repair: landed at aal1, unrecorded)');
select throws_ok(
  $$update public.user_role_assignments set user_id = '16200000-0000-0000-0000-000000000014'
     where id = '16200000-0000-0000-0000-0000000000e2'$$,
  '23514', null,
  'URA-1: the owner''s grant cannot be moved to another user (measured: the owner lost everything, unrecorded)');
select throws_ok(
  $$update public.user_role_assignments set branch_id = '16200000-0000-0000-0000-0000000000b2'
     where id = '16200000-0000-0000-0000-0000000000e4'$$,
  '23514', null,
  'URA-1: a branch scope cannot be moved');
select throws_ok(
  $$update public.user_role_assignments set starts_at = now() + interval '1 year'
     where id = '16200000-0000-0000-0000-0000000000e2'$$,
  '23514', null,
  'URA-1: a live grant cannot be suspended by pushing its start ahead (measured: the owner lost MANAGE_USERS, unrecorded)');
select throws_ok(
  $$update public.user_role_assignments set ends_at = now() + interval '1 day'
     where id = '16200000-0000-0000-0000-0000000000e3'$$,
  '23514', null,
  'a live grant''s end does not move while it stays live');
select throws_ok(
  $$update public.user_role_assignments set is_active = false where id = '16200000-0000-0000-0000-0000000000e3'$$,
  '42501', null,
  'control: ending a grant at aal1 is still refused by app.emit_role_change (RBAC-1, unchanged)');

-- The ceo at aal2: re-points are refused as well; ending and starting grants are charged and recorded.
select set_config('request.jwt.claims', '{"sub":"16200000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select throws_ok(
  $$update public.user_role_assignments set role_id = (select id from public.roles where code = 'ceo')
     where id = '16200000-0000-0000-0000-0000000000e5'$$,
  '23514', null,
  'URA-2: a stepped-up session cannot re-point a grant either (measured: a trainee became ceo with no record)');
reset role;
select is(
  (select r.code from public.user_role_assignments ura join public.roles r on r.id = ura.role_id
    where ura.id = '16200000-0000-0000-0000-0000000000e5'),
  'trainee',
  '...and the grant is unchanged');
set local role authenticated;
select lives_ok(
  $$select app.revoke_user_role('16200000-0000-0000-0000-0000000000e5')$$,
  'the RPC revoke still ends a grant');
select lives_ok(
  $$update public.user_role_assignments set ends_at = now() - interval '1 minute'
     where id = '16200000-0000-0000-0000-0000000000e7'$$,
  'a direct expiry still ends a live grant');
select lives_ok(
  $$update public.user_role_assignments set is_active = true where id = '16200000-0000-0000-0000-0000000000e8'$$,
  'a direct reactivation still starts an inactive grant');
select lives_ok(
  $$update public.user_role_assignments set is_active = is_active where id = '16200000-0000-0000-0000-0000000000e3'$$,
  'an UPDATE that changes nothing still passes');
reset role;
select is(
  (select string_agg(event_type_code || ':' || (payload->>'assignment_id'), ',' order by payload->>'assignment_id')
     from public.events
    where tenant_id = '16200000-0000-0000-0000-000000000001'
      and actor_user_id = '16200000-0000-0000-0000-000000000011'
      and event_type_code in ('role_assigned', 'role_removed')),
  'role_removed:16200000-0000-0000-0000-0000000000e5,role_removed:16200000-0000-0000-0000-0000000000e7,role_assigned:16200000-0000-0000-0000-0000000000e8',
  'URA-2: every change a session can still make is recorded once, with its actor; the refused and no-op updates recorded nothing');

-- URA-3: the lone owner of tenant 3 at aal2.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16200000-0000-0000-0000-0000000000a5","aal":"aal2"}', true);
select throws_ok(
  $$update public.user_role_assignments set role_id = (select id from public.roles where code = 'employee')
     where id = '16200000-0000-0000-0000-0000000000e6'$$,
  '23514', null,
  'URA-3: the lone owner cannot demote their own grant (measured: the tenant was left with no MANAGE_USERS holder)');
select throws_ok(
  $$select app.revoke_user_role('16200000-0000-0000-0000-0000000000e6')$$,
  '42501', null,
  'control: ADMIN-2 still refuses the lone owner''s revoke');
select is(app.has_permission('MANAGE_USERS'), true, '...so the tenant keeps its administrator');

-- The one exemption: a session-less platform write is not checked (provisioning, migrations, fixtures).
reset role;
select set_config('request.jwt.claims', null, true);
select lives_ok(
  $$update public.user_role_assignments set starts_at = now() - interval '1 day'
     where id = '16200000-0000-0000-0000-0000000000e4'$$,
  'a session-less platform write still edits a grant');

select * from finish();
rollback;
