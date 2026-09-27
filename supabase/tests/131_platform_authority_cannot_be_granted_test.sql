-- ATTACK-CLASSES: AUTH DOOR PRIVILEGE TENANT BUSINESS STATE OBSERVABILITY REPLAY=N/A INPUT=N/A CONCURRENCY=N/A
-- SPEC-227 / Batch 6 Slice 25. `subscriptions` is platform-owned: SPEC-157 keeps MANAGE_SUBSCRIPTION
-- and REVIEW_SUBSCRIPTION_PAYMENT held by no role, so the RLS gates on `subscriptions` and on payment
-- proof review deny every tenant user (`42_...` assertion 20 pins the role half). SUB-3: the per-user
-- grant path of RBAC-3 let a MANAGE_PERMISSIONS holder grant either permission to itself and then
-- activate its own subscription on any plan and approve its own payment proof. This file pins the
-- repair to the control that owns it, `user_permission_grants_guard_platform_authority`: every shape
-- of the grant is refused by the guard's own message, the subscription and the proof stay untouched,
-- ordinary grants and a deny of either key still land, and disabling the trigger inside a savepoint
-- lets the same owner grant itself the permission, move a lapsed starter tenant to lifetime
-- enterprise and approve its own proof -- which is the measured consequence, not a hypothetical.
-- REPLAY=N/A: the grant is a set membership (unique per user, permission and effect); no token,
-- counter or single-use value lives on this surface.
-- INPUT=N/A: status and billing-period codes are catalog-enforced by an existing trigger, and the
-- lifetime shape by two existing CHECKs, which `42_...` assertions 9-10 already pin.
-- CONCURRENCY=N/A: the lifecycle job and licence redemption own every concurrent write here, and
-- LIC-2's compare-and-swap is pinned by `80_...`.
create extension if not exists pgtap with schema extensions;

begin;
select plan(31);

insert into auth.users (id,email,email_confirmed_at) values
  ('13100000-0000-0000-0000-0000000000a1','owner@sub131.test',now()),
  ('13100000-0000-0000-0000-0000000000a2','employee@sub131.test',now()),
  ('13100000-0000-0000-0000-0000000000b1','owner@sub131b.test',now());
insert into public.tenants (id,name,slug,status) values
  ('13100000-0000-0000-0000-000000000001','SUB131 Travel','sub131-travel','active'),
  ('13100000-0000-0000-0000-000000000002','SUB131 Other','sub131-other','active');
insert into public.subscriptions
  (id,tenant_id,subscription_plan_id,subscription_status_code,ends_at,grace_ends_at,read_only_started_at)
select '13100000-0000-0000-0000-0000000000c1','13100000-0000-0000-0000-000000000001', p.id, 'read_only',
       now() - interval '40 days', now() - interval '10 days', now() - interval '10 days'
from public.subscription_plans p where p.plan_code = 'starter';
insert into public.subscriptions (id,tenant_id,subscription_plan_id,subscription_status_code,ends_at)
select '13100000-0000-0000-0000-0000000000c2','13100000-0000-0000-0000-000000000002', p.id, 'active',
       now() + interval '30 days'
from public.subscription_plans p where p.plan_code = 'enterprise';
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('13100000-0000-0000-0000-000000000011','13100000-0000-0000-0000-000000000001','Owner','owner@sub131.test',true,'13100000-0000-0000-0000-0000000000a1'),
  ('13100000-0000-0000-0000-000000000012','13100000-0000-0000-0000-000000000001','Employee','employee@sub131.test',true,'13100000-0000-0000-0000-0000000000a2'),
  ('13100000-0000-0000-0000-000000000021','13100000-0000-0000-0000-000000000002','Owner B','owner@sub131b.test',true,'13100000-0000-0000-0000-0000000000b1');
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('13100000-0000-0000-0000-000000000001'::uuid,'13100000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('13100000-0000-0000-0000-000000000001'::uuid,'13100000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('13100000-0000-0000-0000-000000000002'::uuid,'13100000-0000-0000-0000-000000000021'::uuid,'owner')) v(t,u,rc)
join public.roles r on r.code = v.rc;

create temp table s131 (k text primary key, v text) on commit drop;
insert into s131 values
  ('guard_md5', (select md5(pg_get_functiondef('app.guard_platform_permission_grant()'::regprocedure))));

-- ================================================================================================
-- 1-5. The population: the owner administers permissions, holds neither platform permission, sees
--      its own subscription, and its tenant is lapsed with a pending renewal proof -- so every
--      refusal below is about platform authority and nothing else.
-- ================================================================================================
select ok(not app.subscription_allows_write('13100000-0000-0000-0000-000000000001'),
  'CONTROL: the tenant is read_only, so its write gate is closed');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select ok(app.has_permission('MANAGE_PERMISSIONS'), 'CONTROL: the owner holds MANAGE_PERMISSIONS');
select ok(not app.has_permission('MANAGE_SUBSCRIPTION') and not app.has_permission('REVIEW_SUBSCRIPTION_PAYMENT'),
  'CONTROL: the owner holds neither platform permission');
select is((select count(*)::int from public.subscriptions where id='13100000-0000-0000-0000-0000000000c1'), 1,
  'CONTROL: the owner can see the subscription under attack');
select lives_ok($$select app.upload_subscription_payment_proof('renewal.pdf','pdf',20480,'renewal')$$,
  'CONTROL: the lapsed owner can upload a pending renewal proof, the one path canon 28 preserves');

-- ================================================================================================
-- 6-10. PRIVILEGE. Every shape of granting platform authority is refused by the guard's own
--       message: to oneself, to a colleague, by re-pointing an ordinary grant, by flipping a deny,
--       and on the session-less path, so no platform tidy-up can mint a holder either.
-- ================================================================================================
insert into public.user_permission_grants (id,tenant_id,user_id,permission_id,effect)
select '13100000-0000-0000-0000-0000000000f1','13100000-0000-0000-0000-000000000001','13100000-0000-0000-0000-000000000012', id, 'grant'
from public.permissions where key = 'CREATE_CUSTOMER';
insert into public.user_permission_grants (id,tenant_id,user_id,permission_id,effect)
select '13100000-0000-0000-0000-0000000000f2','13100000-0000-0000-0000-000000000001','13100000-0000-0000-0000-000000000012', id, 'deny'
from public.permissions where key = 'MANAGE_SUBSCRIPTION';

select throws_ok(
  $$insert into public.user_permission_grants (tenant_id,user_id,permission_id,effect)
    select '13100000-0000-0000-0000-000000000001','13100000-0000-0000-0000-000000000011', id, 'grant'
    from public.permissions where key = 'MANAGE_SUBSCRIPTION'$$,
  '42501','permission denied: MANAGE_SUBSCRIPTION is platform authority and cannot be granted to a tenant user',
  'the owner cannot grant itself MANAGE_SUBSCRIPTION');
select throws_ok(
  $$insert into public.user_permission_grants (tenant_id,user_id,permission_id,effect)
    select '13100000-0000-0000-0000-000000000001','13100000-0000-0000-0000-000000000012', id, 'grant'
    from public.permissions where key = 'REVIEW_SUBSCRIPTION_PAYMENT'$$,
  '42501','permission denied: REVIEW_SUBSCRIPTION_PAYMENT is platform authority and cannot be granted to a tenant user',
  'the owner cannot grant a colleague REVIEW_SUBSCRIPTION_PAYMENT');
select throws_ok(
  $$update public.user_permission_grants
       set permission_id = (select id from public.permissions where key = 'MANAGE_SUBSCRIPTION')
     where id = '13100000-0000-0000-0000-0000000000f1'$$,
  '42501','permission denied: MANAGE_SUBSCRIPTION is platform authority and cannot be granted to a tenant user',
  'an ordinary grant cannot be re-pointed at platform authority');
select throws_ok(
  $$update public.user_permission_grants set effect = 'grant' where id = '13100000-0000-0000-0000-0000000000f2'$$,
  '42501','permission denied: MANAGE_SUBSCRIPTION is platform authority and cannot be granted to a tenant user',
  'a deny of platform authority cannot be flipped into a grant');
reset role;
select set_config('request.jwt.claims', null, true);
select throws_ok(
  $$insert into public.user_permission_grants (tenant_id,user_id,permission_id,effect)
    select '13100000-0000-0000-0000-000000000001','13100000-0000-0000-0000-000000000011', id, 'grant'
    from public.permissions where key = 'MANAGE_SUBSCRIPTION'$$,
  '42501','permission denied: MANAGE_SUBSCRIPTION is platform authority and cannot be granted to a tenant user',
  'the session-less path cannot mint a tenant holder of platform authority either');

-- ================================================================================================
-- 11-15. BUSINESS / STATE. With no grant possible, the owner's direct writes to its subscription and
--        to its proof reach nothing, and a second subscription row cannot be born.
-- ================================================================================================
select is((select count(*)::int from public.user_permission_grants g join public.permissions p on p.id = g.permission_id
            where g.effect = 'grant' and p.key in ('MANAGE_SUBSCRIPTION','REVIEW_SUBSCRIPTION_PAYMENT')), 0,
  'no grant of platform authority exists after every attempt');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
update public.subscriptions
   set subscription_status_code = 'active', ends_at = null, grace_ends_at = null, read_only_started_at = null,
       billing_period_code = 'lifetime',
       subscription_plan_id = (select id from public.subscription_plans where plan_code = 'enterprise')
 where id = '13100000-0000-0000-0000-0000000000c1';
update public.subscription_payment_proofs set status_code = 'approved', review_notes = 'self'
 where tenant_id = '13100000-0000-0000-0000-000000000001';
select throws_ok(
  $$insert into public.subscriptions (tenant_id,subscription_plan_id,subscription_status_code)
    select '13100000-0000-0000-0000-000000000001', id, 'active' from public.subscription_plans where plan_code = 'enterprise'$$,
  '42501','new row violates row-level security policy for table "subscriptions"',
  'the owner cannot give its tenant a second, newer subscription row');
reset role;
select set_config('request.jwt.claims', null, true);

select is((select s.subscription_status_code || ':' || p.plan_code from public.subscriptions s
            join public.subscription_plans p on p.id = s.subscription_plan_id where s.id = '13100000-0000-0000-0000-0000000000c1'),
  'read_only:starter', 'the owner''s rewrite of its own subscription changed nothing');
select ok(not app.subscription_allows_write('13100000-0000-0000-0000-000000000001'),
  '...so the lapsed tenant''s write gate is still closed');
select is((select status_code from public.subscription_payment_proofs
            where tenant_id = '13100000-0000-0000-0000-000000000001'),
  'pending', 'the owner''s approval of its own proof changed nothing');

-- ================================================================================================
-- 16-18. The legitimate grant model is untouched: an ordinary grant, a deny of platform authority,
--        and a revocation all still land.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok(
  $$insert into public.user_permission_grants (tenant_id,user_id,permission_id,effect)
    select '13100000-0000-0000-0000-000000000001','13100000-0000-0000-0000-000000000012', id, 'grant'
    from public.permissions where key = 'CREATE_LEAD'$$,
  'an ordinary per-user grant still lands');
select lives_ok(
  $$insert into public.user_permission_grants (tenant_id,user_id,permission_id,effect)
    select '13100000-0000-0000-0000-000000000001','13100000-0000-0000-0000-000000000012', id, 'deny'
    from public.permissions where key = 'REVIEW_SUBSCRIPTION_PAYMENT'$$,
  'a deny of platform authority still lands: it removes nothing anyone may hold');
select lives_ok(
  $$update public.user_permission_grants set is_active = false where id = '13100000-0000-0000-0000-0000000000f1'$$,
  'an ordinary grant can still be revoked');

-- ================================================================================================
-- 19-22. TENANT / AUTH / DOOR. Another tenant's subscription is invisible; a user without
--        VIEW_SUBSCRIPTION_STATUS sees none; the platform functions are not executable by a signed-in
--        user; and there is no DELETE door.
-- ================================================================================================
select is((select count(*)::int from public.subscriptions where tenant_id = '13100000-0000-0000-0000-000000000002'), 0,
  'the owner cannot see another tenant''s subscription');
select set_config('request.jwt.claims','{"sub":"13100000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select is((select count(*)::int from public.subscriptions), 0,
  'an employee without VIEW_SUBSCRIPTION_STATUS sees no subscription');
reset role;
select set_config('request.jwt.claims', null, true);
select ok(not has_function_privilege('authenticated','app.platform_activate_subscription(uuid,text,text,boolean)','execute')
      and not has_function_privilege('authenticated','app.platform_transition_subscription(uuid,text,text)','execute')
      and not has_function_privilege('authenticated','app.platform_review_payment_proof(uuid,boolean,text,text,text,boolean)','execute'),
  'the platform subscription functions are not executable by a signed-in user');
select ok(not has_table_privilege('authenticated','public.subscriptions','delete'),
  'authenticated holds no DELETE on subscriptions');

-- ================================================================================================
-- 23. OBSERVABILITY. The guard is attached BEFORE INSERT OR UPDATE, row-level and enabled.
-- ================================================================================================
select is((select tgenabled::text || ':' || tgtype::text || ':' || tgfoid::regproc::text from pg_trigger
            where tgrelid = 'public.user_permission_grants'::regclass and tgname = 'user_permission_grants_guard_platform_authority'),
  'O:23:app.guard_platform_permission_grant', 'the guard is attached BEFORE INSERT OR UPDATE FOR EACH ROW and enabled');

-- ================================================================================================
-- 24-28. MUTATION. With the guard disabled the same owner grants itself platform authority, moves
--        its lapsed starter tenant to lifetime enterprise and approves its own proof -- the measured
--        consequence of SUB-3. Rolled back to a savepoint.
-- ================================================================================================
savepoint m1;
alter table public.user_permission_grants disable trigger user_permission_grants_guard_platform_authority;
select is((select tgenabled::text from pg_trigger where tgname = 'user_permission_grants_guard_platform_authority'), 'D',
  'MUTANT installed: the guard is disabled');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok(
  $$insert into public.user_permission_grants (tenant_id,user_id,permission_id,effect)
    select '13100000-0000-0000-0000-000000000001','13100000-0000-0000-0000-000000000011', id, 'grant'
    from public.permissions where key in ('MANAGE_SUBSCRIPTION','REVIEW_SUBSCRIPTION_PAYMENT')$$,
  'MUTANT: the owner grants itself both platform permissions');
update public.subscriptions
   set subscription_status_code = 'active', ends_at = null, grace_ends_at = null, read_only_started_at = null,
       billing_period_code = 'lifetime',
       subscription_plan_id = (select id from public.subscription_plans where plan_code = 'enterprise')
 where id = '13100000-0000-0000-0000-0000000000c1';
update public.subscription_payment_proofs set status_code = 'approved', review_notes = 'self'
 where tenant_id = '13100000-0000-0000-0000-000000000001';
reset role;
select set_config('request.jwt.claims', null, true);
select is((select s.subscription_status_code || ':' || p.plan_code || ':' || s.billing_period_code from public.subscriptions s
            join public.subscription_plans p on p.id = s.subscription_plan_id where s.id = '13100000-0000-0000-0000-0000000000c1'),
  'active:enterprise:lifetime', 'MUTANT: the lapsed starter tenant made itself lifetime enterprise');
select ok(app.subscription_allows_write('13100000-0000-0000-0000-000000000001'),
  'MUTANT: ...and its write gate opened without payment');
select is((select status_code from public.subscription_payment_proofs
            where tenant_id = '13100000-0000-0000-0000-000000000001'),
  'approved', 'MUTANT: ...and it approved its own payment proof');
rollback to savepoint m1;

-- ================================================================================================
-- 29-31. RESTORED. The guard is enabled and byte-identical, no mutant write survived, and the
--        Platform Owner can still decide the proof the tenant could not touch.
-- ================================================================================================
select is((select tgenabled::text || ':' || (md5(pg_get_functiondef('app.guard_platform_permission_grant()'::regprocedure))
            = (select v from s131 where k = 'guard_md5'))::text
           from pg_trigger where tgname = 'user_permission_grants_guard_platform_authority'),
  'O:true', 'RESTORED: the guard is enabled and its definition is byte-identical');
select is((select s.subscription_status_code || ':' || (select count(*) from public.user_permission_grants g
            join public.permissions p on p.id = g.permission_id
            where g.effect = 'grant' and p.key in ('MANAGE_SUBSCRIPTION','REVIEW_SUBSCRIPTION_PAYMENT'))::text
           from public.subscriptions s where s.id = '13100000-0000-0000-0000-0000000000c1'),
  'read_only:0', 'RESTORED: no mutant grant or subscription rewrite survived');
select lives_ok(
  $$select app.platform_review_payment_proof(
      (select id from public.subscription_payment_proofs where tenant_id = '13100000-0000-0000-0000-000000000001'),
      true, 'platform decision')$$,
  'the Platform Owner can still decide the proof the tenant could not');

select * from finish();
rollback;
