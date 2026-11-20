-- ATTACK-CLASSES: AUTH DOOR PRIVILEGE TENANT REPLAY OBSERVABILITY STATE=N/A INPUT=N/A BUSINESS=N/A CONCURRENCY=N/A
-- SPEC-226 / Batch 6 Slice 24 records the branch audit. BRANCH-1 now requires the same
-- step-up for table writes, the branch RPC and branch business hours. The capability guard
-- enforces permission on INSERT independently of RLS. RLS still owns the tenant fence and
-- UPDATE visibility. DELETE has no grant, and the slug remains unique per tenant.
-- BRANCH-2 remains open. Assertion 19 records the direct creation event gap at its own gate.
-- STATE=N/A: `branches` has no status machine and nothing reads `is_active`.
-- INPUT=N/A: `branch_type` is free text by CAT-6's recorded canon position; nothing reads `slug`,
-- `name`, `primary_phone`, `address` or `created_at`. A caller-supplied `created_at` is the
-- schema-wide question SPEC-216 recorded for every table with such a column, not a `branches`
-- finding, so it is deliberately not pinned here.
-- BUSINESS=N/A: canon 28 makes `max_branches` readable and unenforced on every door alike.
-- CONCURRENCY=N/A: no counter, allocator or lock lives on this surface.
create extension if not exists pgtap with schema extensions;

begin;
select plan(29);

insert into auth.users (id,email,email_confirmed_at) values
  ('13000000-0000-0000-0000-0000000000a1','owner@br130.test',now()),
  ('13000000-0000-0000-0000-0000000000a2','employee@br130.test',now()),
  ('13000000-0000-0000-0000-0000000000b1','owner@br130b.test',now());
insert into public.tenants (id,name,slug,status) values
  ('13000000-0000-0000-0000-000000000001','BR130 Travel','br130-travel','active'),
  ('13000000-0000-0000-0000-000000000002','BR130 Other','br130-other','active');
insert into public.subscriptions (tenant_id,subscription_plan_id,subscription_status_code)
select v.t, p.id, 'active'
from public.subscription_plans p,
     (values ('13000000-0000-0000-0000-000000000001'::uuid),('13000000-0000-0000-0000-000000000002'::uuid)) v(t)
where p.plan_code='enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('13000000-0000-0000-0000-00000000000a','13000000-0000-0000-0000-000000000001','Main','br130-main'),
  ('13000000-0000-0000-0000-00000000000b','13000000-0000-0000-0000-000000000002','Other Main','br130b-main');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('13000000-0000-0000-0000-000000000011','13000000-0000-0000-0000-000000000001','Owner','owner@br130.test',true,'13000000-0000-0000-0000-0000000000a1'),
  ('13000000-0000-0000-0000-000000000012','13000000-0000-0000-0000-000000000001','Employee','employee@br130.test',true,'13000000-0000-0000-0000-0000000000a2'),
  ('13000000-0000-0000-0000-000000000021','13000000-0000-0000-0000-000000000002','Owner B','owner@br130b.test',true,'13000000-0000-0000-0000-0000000000b1');
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('13000000-0000-0000-0000-000000000001'::uuid,'13000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('13000000-0000-0000-0000-000000000001'::uuid,'13000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('13000000-0000-0000-0000-000000000002'::uuid,'13000000-0000-0000-0000-000000000021'::uuid,'owner')) v(t,u,rc)
join public.roles r on r.code = v.rc;

create temp table s130 (k text primary key, v text) on commit drop;
grant all on s130 to authenticated;
insert into s130 values
  ('policy_insert', (select md5(coalesce(with_check,'')) from pg_policies
                      where schemaname='public' and tablename='branches' and policyname='scope_insert'));

-- ================================================================================================
-- 1-3. The population: the owner holds the capability, the employee does not, and the owner's
--      step-up is required, so every aal1 result below is about step-up and nothing else.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
select ok(app.has_permission('MANAGE_BRANCHES'), 'CONTROL: the aal1 owner holds MANAGE_BRANCHES');
select ok(not app.mfa_satisfied(), 'CONTROL: the aal1 owner has not satisfied the step-up its role requires');
select is((select count(*)::int from public.branches where id='13000000-0000-0000-0000-00000000000a'), 1,
  'CONTROL: the aal1 owner can see the branch under attack');

-- ================================================================================================
-- 4-8. AUTH / DOOR. The branch table, RPC and child table all require step-up.
--      BRANCH-1 closes only the branch table's authority gap.
-- ================================================================================================
select throws_ok(
  $$select app.create_branch('Via RPC','br130-rpc-aal1')$$,
  '42501','multi-factor authentication required for this role',
  'the RPC door refuses the aal1 owner');
select throws_ok(
  $$insert into public.branch_business_hours (tenant_id,branch_id,day_of_week,opens_at,closes_at)
    values ('13000000-0000-0000-0000-000000000001','13000000-0000-0000-0000-00000000000a',1,'09:00','17:00')$$,
  '42501','multi-factor authentication required for this role',
  'the child table door refuses the aal1 owner the same capability');
select throws_ok(
  $$insert into public.branches (tenant_id,name,slug)
    values ('13000000-0000-0000-0000-000000000001','Squat aal1','br130-squat')$$,
  '42501','multi-factor authentication required for this role',
  'the branch table refuses creation without step-up');
select throws_ok(
  $$update public.branches set name='Hijacked', slug='br130-hijacked', is_active=false
    where id='13000000-0000-0000-0000-00000000000a'$$,
  '42501','multi-factor authentication required for this role',
  'the branch table refuses edits without step-up');
reset role;
select is(
  (select array[name, slug, is_active::text] from public.branches where id='13000000-0000-0000-0000-00000000000a'),
  array['Main','br130-main','true'],
  'the refused edit preserves the branch row');

-- ================================================================================================
-- 9-18. Owner at aal2: legitimate doors, the tenant boundary, DELETE, slug uniqueness, and the
--       record each door leaves.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok(
  $$insert into s130 values ('rpc', app.create_branch('Via RPC','br130-rpc')::text)$$,
  'the aal2 owner creates a branch through the RPC');
select lives_ok(
  $$insert into public.branches (id,tenant_id,name,slug)
    values ('13000000-0000-0000-0000-0000000000c1','13000000-0000-0000-0000-000000000001','Direct','br130-direct')$$,
  'the aal2 owner creates a branch through the table');
select lives_ok(
  $$update public.branches set primary_phone='+20 2 0000 0000' where id='13000000-0000-0000-0000-00000000000a'$$,
  'the aal2 owner edits a branch through the table');
select throws_ok(
  $$insert into public.branches (tenant_id,name,slug)
    values ('13000000-0000-0000-0000-000000000002','Plant','br130-plant')$$,
  '42501','new row violates row-level security policy for table "branches"',
  'TENANT: the owner cannot plant a branch in another tenant');
select throws_ok(
  $$update public.branches set tenant_id='13000000-0000-0000-0000-000000000002'
    where id='13000000-0000-0000-0000-00000000000a'$$,
  '42501','new row violates row-level security policy for table "branches"',
  'TENANT: the owner cannot relocate a branch into another tenant');
select is((select count(*)::int from public.branches where id='13000000-0000-0000-0000-00000000000b'), 0,
  'TENANT: the other tenant''s branch is invisible to the owner');
update public.branches set name='Seized' where id='13000000-0000-0000-0000-00000000000b';
select throws_ok(
  $$delete from public.branches where id='13000000-0000-0000-0000-0000000000c1'$$,
  '42501','permission denied for table branches',
  'no authenticated DELETE grant exists on branches');
select throws_ok(
  $$insert into public.branches (tenant_id,name,slug)
    values ('13000000-0000-0000-0000-000000000001','Duplicate','br130-main')$$,
  '23505', null,
  'REPLAY: a second branch cannot take a slug the tenant already uses');
reset role;
select is((select name from public.branches where id='13000000-0000-0000-0000-00000000000b'), 'Other Main',
  'TENANT: the cross-tenant UPDATE changed nothing');
select is(
  (select count(*)::int from public.events
    where entity_type='branch' and event_type_code='branch_created'
      and entity_id=(select v::uuid from s130 where k='rpc')), 1,
  'the RPC records exactly one branch_created');

-- ================================================================================================
-- 19. OBSERVABILITY: the table door's creation is silent. This pins the OPEN defect BRANCH-2; it is
--     NOT desired behaviour.
-- ================================================================================================
select is(
  (select count(*)::int from public.events
    where entity_type='branch' and entity_id='13000000-0000-0000-0000-0000000000c1'), 0,
  'BRANCH-2 is OPEN: a direct INSERT records no branch event (FAILS when BRANCH-2 is repaired)');

-- ================================================================================================
-- 20-23. PRIVILEGE: the guard refuses INSERT by a non-holder at aal2, and UPDATE matches
--        no row and changes nothing.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select ok(not app.has_permission('MANAGE_BRANCHES'), 'CONTROL: the employee does not hold MANAGE_BRANCHES');
select is((select count(*)::int from public.branches where id='13000000-0000-0000-0000-00000000000a'), 1,
  'CONTROL: the employee can see the branch under attack');
select throws_ok(
  $$insert into public.branches (tenant_id,name,slug)
    values ('13000000-0000-0000-0000-000000000001','Employee','br130-employee')$$,
  '42501','permission denied: one of MANAGE_BRANCHES is required to write branches',
  'PRIVILEGE: the employee cannot create a branch through the table');
update public.branches set name='Employee Rename' where id='13000000-0000-0000-0000-00000000000a';
reset role;
select is((select name from public.branches where id='13000000-0000-0000-0000-00000000000a'), 'Main',
  'PRIVILEGE: the employee''s UPDATE changed nothing');

-- ================================================================================================
-- 24-29. Remove each INSERT policy conjunct in its own savepoint. The capability guard still
--        refuses an actor without permission. The tenant restriction remains load-bearing.
--        Roll the changes back and check restoration.
-- ================================================================================================
savepoint m1;
alter policy scope_insert on public.branches
  with check (tenant_id = (select app.current_tenant_id()));
select isnt((select md5(with_check) from pg_policies where schemaname='public' and tablename='branches' and policyname='scope_insert'),
  (select v from s130 where k='policy_insert'), 'MUTANT 1 installed: scope_insert without the permission conjunct');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select throws_ok(
  $$insert into public.branches (tenant_id,name,slug)
    values ('13000000-0000-0000-0000-000000000001','Employee','br130-employee')$$,
  '42501','permission denied: one of MANAGE_BRANCHES is required to write branches',
  'MUTANT 1: the capability guard still refuses a non-holder');
reset role;
rollback to savepoint m1;

savepoint m2;
alter policy scope_insert on public.branches
  with check ((select app.has_permission('MANAGE_BRANCHES')));
select isnt((select md5(with_check) from pg_policies where schemaname='public' and tablename='branches' and policyname='scope_insert'),
  (select v from s130 where k='policy_insert'), 'MUTANT 2 installed: scope_insert without the tenant conjunct');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok(
  $$insert into public.branches (tenant_id,name,slug)
    values ('13000000-0000-0000-0000-000000000002','Plant','br130-plant')$$,
  'MUTANT 2: the cross-tenant plant lands, so the tenant conjunct is what refused it');
reset role;
rollback to savepoint m2;

select is((select md5(coalesce(with_check,'')) from pg_policies where schemaname='public' and tablename='branches' and policyname='scope_insert'),
  (select v from s130 where k='policy_insert'), 'RESTORED: scope_insert is byte-identical to its installed expression');
select is((select count(*)::int from public.branches where tenant_id='13000000-0000-0000-0000-000000000002'), 1,
  'RESTORED: no mutant write survived the rollback');

select * from finish();
rollback;
