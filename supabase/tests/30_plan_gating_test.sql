-- pgTAP: plan / feature entitlement gating (SPEC-146).
--
-- Canon 28 states "Plan denial overrides user role permission". SPEC-141 seeded the matrix -- 66 rows
-- straight from canon 28 and canon 17 -- and nothing read it. A Starter tenant whose plan excludes
-- Booking could create bookings all day, because the only question anyone asked was whether the ROLE
-- permitted it.
--
-- The gate sits inside `app.has_permission`, so these assertions deliberately attack it from three
-- different directions, because a gate that only held on one of them would be no gate at all:
--   1. `app.authorize` -- the RPC path
--   2. an RLS policy -- the direct PostgREST read path
--   3. a trigger -- the direct PostgREST write path
create extension if not exists pgtap with schema extensions;

begin;
select plan(13);

insert into auth.users (id, email) values
  ('31000000-0000-0000-0000-0000000000a1','boss@example.com'),
  ('31000000-0000-0000-0000-0000000000a2','senior@example.com'),
  ('31000000-0000-0000-0000-0000000000a3','nosub@example.com');

-- Two tenants: one on Starter, one with no subscription at all.
insert into public.tenants (id, name, slug, status) values
  ('31000000-0000-0000-0000-000000000001','Starter Travel','starter-travel','active'),
  ('31000000-0000-0000-0000-000000000002','Unsold Travel','unsold-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code, starts_at)
select '31000000-0000-0000-0000-000000000001', id, 'active', now()
from public.subscription_plans where plan_code = 'starter';

insert into public.branches (id, tenant_id, name, slug) values
  ('31000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-000000000001','Maadi','maadi'),
  ('31000000-0000-0000-0000-00000000000b','31000000-0000-0000-0000-000000000002','Nasr','nasr');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('31000000-0000-0000-0000-0000000000c1','31000000-0000-0000-0000-000000000001','31000000-0000-0000-0000-00000000000a','sales','Maadi Sales'),
  ('31000000-0000-0000-0000-0000000000c2','31000000-0000-0000-0000-000000000002','31000000-0000-0000-0000-00000000000b','sales','Nasr Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('31000000-0000-0000-0000-000000000011','31000000-0000-0000-0000-000000000001','Boss','boss@example.com',true,'31000000-0000-0000-0000-0000000000a1'),
  ('31000000-0000-0000-0000-000000000012','31000000-0000-0000-0000-000000000001','Senior','senior@example.com',true,'31000000-0000-0000-0000-0000000000a2'),
  ('31000000-0000-0000-0000-000000000013','31000000-0000-0000-0000-000000000002','NoSub','nosub@example.com',true,'31000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('31000000-0000-0000-0000-000000000001','31000000-0000-0000-0000-000000000011','31000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-0000000000c1',true),
  ('31000000-0000-0000-0000-000000000001','31000000-0000-0000-0000-000000000012','31000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-0000000000c1',true),
  ('31000000-0000-0000-0000-000000000002','31000000-0000-0000-0000-000000000013','31000000-0000-0000-0000-00000000000b','31000000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.tid, v.uid, r.id, 'tenant'
from (values ('31000000-0000-0000-0000-000000000001'::uuid,'31000000-0000-0000-0000-000000000011'::uuid,'branch_manager'),
             ('31000000-0000-0000-0000-000000000001'::uuid,'31000000-0000-0000-0000-000000000012'::uuid,'senior_employee'),
             ('31000000-0000-0000-0000-000000000002'::uuid,'31000000-0000-0000-0000-000000000013'::uuid,'branch_manager')) as v(tid, uid, role_code)
join public.roles r on r.code = v.role_code;

insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('31000000-0000-0000-0000-0000000000d1','31000000-0000-0000-0000-000000000001','person','Starter Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('31000000-0000-0000-0000-0000000000f1','31000000-0000-0000-0000-000000000001',
   '31000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-0000000000c1',
   '31000000-0000-0000-0000-0000000000d1','31000000-0000-0000-0000-000000000012',
   '31000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-0000000000c1',
   'draft','Starter booking','BK-MAA-0001');
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
                                  owner_user_id, owner_branch_id, owner_department_id, currency_code) values
  ('31000000-0000-0000-0000-0000000000f2','31000000-0000-0000-0000-000000000001',
   '31000000-0000-0000-0000-0000000000f1','hotel','draft',
   '31000000-0000-0000-0000-000000000012',
   '31000000-0000-0000-0000-00000000000a','31000000-0000-0000-0000-0000000000c1','EGP');

set local role authenticated;

-- ---------------------------------------------------------------------------------------------
-- Starter excludes Booking (canon 28) -- and the role says yes.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"31000000-0000-0000-0000-0000000000a1"}', true);

select is(
  (select count(*)::int from public.role_permissions rp
     join public.permissions p on p.id = rp.permission_id
     join public.roles r on r.id = rp.role_id
    where r.code = 'branch_manager' and p.key = 'CREATE_BOOKING'),
  1,
  'the ROLE grants CREATE_BOOKING -- so anything refused below is the plan speaking, not the role');

select is(app.plan_allows('booking'), false,
  'the Starter plan excludes Booking (canon 28 Feature Access By Plan)');

select is(app.has_permission('CREATE_BOOKING'), false,
  'PLAN DENIAL OVERRIDES ROLE PERMISSION -- the exact sentence canon 28 states, now true');

select throws_ok(
  $$select app.authorize('CREATE_BOOKING')$$,
  '42501', null,
  '...and the RPC path refuses, because every RPC authorizes through the same function');

select is(app.has_permission('CREATE_LEAD'), true,
  '...while CRM itself is included on Starter, so the plan removes only what it excludes');

-- Direct write path: the SPEC-145 trigger calls app.authorize, so plan denial reaches plain SQL too.
select set_config('request.jwt.claims', '{"sub":"31000000-0000-0000-0000-0000000000a2"}', true);
select throws_ok(
  $$update public.booking_items set cost_amount = 500 where id = '31000000-0000-0000-0000-0000000000f2'$$,
  '42501', null,
  'THE DIRECT SQL PATH IS GATED TOO -- ENTER_COST depends on the Booking feature, so a Starter tenant cannot price work its plan does not include');

-- Direct read path: an RLS policy calling has_permission.
select is((select count(*)::int from public.marketing_campaigns), 0,
  '...and the read path likewise, through the policies that call the same function');

-- ---------------------------------------------------------------------------------------------
-- Upgrade the plan. Nothing else changes -- no role edit, no policy edit.
-- ---------------------------------------------------------------------------------------------
reset role;
update public.subscriptions
   set subscription_plan_id = (select id from public.subscription_plans where plan_code = 'enterprise')
 where tenant_id = '31000000-0000-0000-0000-000000000001';
set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"31000000-0000-0000-0000-0000000000a1"}', true);
select is(app.has_permission('CREATE_BOOKING'), true,
  'UPGRADING THE PLAN restores the permission with no change to roles or policies -- the plan is a separate axis, exactly as canon describes');

select set_config('request.jwt.claims', '{"sub":"31000000-0000-0000-0000-0000000000a2"}', true);
select lives_ok(
  $$update public.booking_items set cost_amount = 500 where id = '31000000-0000-0000-0000-0000000000f2'$$,
  '...and the same direct write now succeeds');

-- ---------------------------------------------------------------------------------------------
-- Suspension and PERMISSIONS -- corrected by SPEC-152.
--
-- These two assertions previously read the other way round, and encoded the defect rather than the
-- rule: `plan_allows` used to fold subscription STATE into permission evaluation, so a suspended
-- tenant lost plan-gated *permissions* -- which denied READS. The owner's rule is the opposite:
-- reads survive every restricted state so a lapsed tenant can still inspect and export its own
-- data; it is WRITES that stop. State is now enforced by the per-table write gate
-- (`35_subscription_write_gate_test.sql`), and `plan_allows` is back to its single job: does the
-- PLAN include this feature.
-- ---------------------------------------------------------------------------------------------
reset role;
update public.subscriptions set subscription_status_code = 'suspended'
 where tenant_id = '31000000-0000-0000-0000-000000000001';
set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"31000000-0000-0000-0000-0000000000a1"}', true);
select is(app.has_permission('CREATE_BOOKING'), true,
  'a SUSPENDED subscription no longer strips plan-gated PERMISSIONS -- reads must survive, and the write is stopped by the SPEC-152 gate instead');
select is(app.has_permission('CREATE_LEAD'), true,
  '...and an ungated permission is likewise untouched');

-- ---------------------------------------------------------------------------------------------
-- A tenant with no subscription at all. Plan gating alone still permits: nothing has been sold to
-- them, so no FEATURE has been denied. Their WRITES are denied separately and unconditionally by
-- the SPEC-152 gate, which is what stops this from being a fail-open hole.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"31000000-0000-0000-0000-0000000000a3"}', true);
select is(app.has_permission('CREATE_BOOKING'), true,
  'a tenant with NO subscription retains plan-gated permissions for READ purposes -- writes are refused by the write gate, not here');

-- ---------------------------------------------------------------------------------------------
-- What a UI or an n8n workflow should ask, instead of inferring capability from a failed write.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"31000000-0000-0000-0000-0000000000a1"}', true);
select is(
  (select limit_value from app.tenant_capabilities() where feature_code = 'max_branches'),
  null,
  'app.tenant_capabilities reports Enterprise as having no branch ceiling -- "Unlimited" is the absence of a limit, not a number to compare against');

select * from finish();
rollback;
