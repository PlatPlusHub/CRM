-- pgTAP: the API-3 customer-data family -- CM-1, CM-2, PLACE-1 (202607058300).
--
-- Before this file `current_placement` appeared in the suite ONLY as a name in
-- `53_api_surface_test`'s endpoint inventory -- the CUST-2 shape -- while five write RPCs read it to
-- decide which branch a new customer, quotation, complaint, service request or conversation belongs
-- to. None of the three endpoints had HTTP evidence.
--
-- The actor is an `employee`: CREATE_CUSTOMER resolves to six roles including `employee`, and
-- `app.requires_mfa` does NOT list it, so no aal2 claim is needed and a refusal here cannot be an
-- MFA refusal wearing an integrity label. The one step that needs MANAGE_USERS uses an `owner` with
-- aal2, because `app.requires_mfa` does list that role.
--
-- Both new protections are attacked by defect injection (PAR-4): drop the enforcer inside a
-- savepoint, prove the prohibited state becomes reachable, roll back, prove it is refused again.
create extension if not exists pgtap with schema extensions;

begin;
select plan(19);

insert into auth.users (id, email) values
  ('79000000-0000-0000-0000-0000000000a1','emp@custdata.example'),
  ('79000000-0000-0000-0000-0000000000a2','own@custdata.example');
insert into public.tenants (id, name, slug, status) values
  ('79000000-0000-0000-0000-000000000001','Cust Data Travel','custdata-travel','active'),
  ('79000000-0000-0000-0000-000000000002','Cust Data Rival','custdata-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.branches (id, tenant_id, name, slug) values
  ('79000000-0000-0000-0000-00000000000a','79000000-0000-0000-0000-000000000001','Cairo','custdata-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('79000000-0000-0000-0000-0000000000c1','79000000-0000-0000-0000-000000000001','79000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('79000000-0000-0000-0000-000000000021','79000000-0000-0000-0000-000000000001','Employee','emp@custdata.example',true,'79000000-0000-0000-0000-0000000000a1'),
  ('79000000-0000-0000-0000-000000000011','79000000-0000-0000-0000-000000000001','Owner','own@custdata.example',true,'79000000-0000-0000-0000-0000000000a2');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '79000000-0000-0000-0000-000000000001','79000000-0000-0000-0000-000000000021', r.id,'tenant' from public.roles r where r.code='employee';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '79000000-0000-0000-0000-000000000001','79000000-0000-0000-0000-000000000011', r.id,'tenant' from public.roles r where r.code='owner';
insert into public.user_branch_assignments (id, tenant_id, user_id, branch_id, department_id, is_primary) values
  ('79000000-0000-0000-0000-0000000000b1','79000000-0000-0000-0000-000000000001','79000000-0000-0000-0000-000000000021','79000000-0000-0000-0000-00000000000a','79000000-0000-0000-0000-0000000000c1',true),
  ('79000000-0000-0000-0000-0000000000b2','79000000-0000-0000-0000-000000000001','79000000-0000-0000-0000-000000000011','79000000-0000-0000-0000-00000000000a','79000000-0000-0000-0000-0000000000c1',true);
-- A rival tenant's customer sharing the phone number, for the isolation assertion.
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone)
values ('79000000-0000-0000-0000-0000000000e9','79000000-0000-0000-0000-000000000002','person','Rival Customer','+201119998888');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"79000000-0000-0000-0000-0000000000a1"}',true);

select ok(app.has_permission('CREATE_CUSTOMER'),
  'POSITIVE CONTROL: the employee genuinely holds CREATE_CUSTOMER, so every refusal below is about the rule under test');

create temp table cust as
  select app.create_customer('person','Mona Fathy',null,null,null,'+201119998888',null,null,null,null,false,null,false) as id;

-- ================================================================================================
-- CM-1 -- "primary" is per channel.
-- ================================================================================================
select lives_ok(
  $$select app.add_customer_contact_method((select id from cust),'primary_phone','+201119998888', true)$$,
  'POSITIVE CONTROL: a primary phone is added');

select lives_ok(
  $$select app.add_customer_contact_method((select id from cust),'email','Mona@Example.COM', true)$$,
  'POSITIVE CONTROL: a primary email is added on the same customer');

select is(
  (select is_primary from public.customer_contact_methods
    where customer_id = (select id from cust) and contact_method_type_code = 'primary_phone'),
  true,
  'CM-1: adding a primary EMAIL no longer demotes the primary PHONE -- "primary" is per channel, which is exactly what customer_contact_methods_one_primary_per_type_idx encodes');

select is(
  (select count(*)::int from public.customer_contact_methods
    where customer_id = (select id from cust) and is_primary),
  2,
  '...so the customer legitimately holds two primaries, one per channel -- as customers.primary_phone and customers.primary_email do');

select lives_ok(
  $$select app.add_customer_contact_method((select id from cust),'primary_phone','+201110000001', true)$$,
  'a SECOND primary phone is added');

select is(
  (select count(*)::int from public.customer_contact_methods
    where customer_id = (select id from cust) and contact_method_type_code = 'primary_phone' and is_primary),
  1,
  '...and WITHIN the channel the demotion still happens -- exactly one primary phone survives, which is the rule 202607052100 wrote down');

-- ================================================================================================
-- CM-2 -- the canonical form holds on the table, not only inside the RPC.
-- ================================================================================================
select is(
  (select value from public.customer_contact_methods
    where customer_id = (select id from cust) and contact_method_type_code = 'email'),
  'mona@example.com',
  'POSITIVE CONTROL: the RPC stored the canonical form, so the refusal below is about the direct path');

select throws_ok(
  format($$insert into public.customer_contact_methods (tenant_id, customer_id, contact_method_type_code, value)
           values ('79000000-0000-0000-0000-000000000001','%s','email','  MONA@example.com  ')$$, (select id from cust)),
  '23514', null,
  'CM-2: a DENORMALIZED value is refused on the table door -- 202607052100 claimed the unique index made this hold on the direct path, and it did not, because that index covers the RAW value');

select lives_ok(
  format($$insert into public.customer_contact_methods (tenant_id, customer_id, contact_method_type_code, value)
           values ('79000000-0000-0000-0000-000000000001','%s','secondary_phone','+201112223333')$$, (select id from cust)),
  'NEGATIVE CONTROL ON THE CONSTRAINT ITSELF: an already-canonical value still inserts by direct DML -- the rule does not over-reach into legitimate writes');

savepoint m1;
reset role;
alter table public.customer_contact_methods drop constraint customer_contact_methods_value_normalized_check;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"79000000-0000-0000-0000-0000000000a1"}',true);
select lives_ok(
  format($$insert into public.customer_contact_methods (tenant_id, customer_id, contact_method_type_code, value)
           values ('79000000-0000-0000-0000-000000000001','%s','email','  MONA@example.com  ')$$, (select id from cust)),
  'MUTATION: with customer_contact_methods_value_normalized_check dropped the denormalized value INSERTS -- proving the constraint is the enforcer');
select is(
  (select count(*)::int from public.customer_contact_methods
    where customer_id = (select id from cust) and contact_method_type_code = 'email'),
  2,
  '...and it produces exactly the corrupt state reproduced before the fix: TWO rows for one logical address, which the unique index cannot see and app.merge_customer_identity compares with t.value = s.value');
rollback to savepoint m1;

-- ================================================================================================
-- PLACE-1 -- a placement scheduled to end is still current.
-- ================================================================================================
select is(
  (select branch_id from app.current_placement()),
  '79000000-0000-0000-0000-00000000000a'::uuid,
  'POSITIVE CONTROL: current_placement answers while the placement is open-ended');

-- The owner schedules the employee's transfer, through the door RLS already permits.
select set_config('request.jwt.claims','{"sub":"79000000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select lives_ok(
  $$update public.user_branch_assignments set ends_at = now() + interval '30 days'
     where id = '79000000-0000-0000-0000-0000000000b1'$$,
  'POSITIVE CONTROL: an owner holding MANAGE_USERS schedules the transfer -- canon 03 provides for exactly this');
select set_config('request.jwt.claims','{"sub":"79000000-0000-0000-0000-0000000000a1"}',true);

select is(
  (select branch_id from app.current_placement()),
  '79000000-0000-0000-0000-00000000000a'::uuid,
  'PLACE-1: the placement is still returned while it is merely SCHEDULED to end -- it used to return nothing, and all five consumers read it with SELECT INTO, so nothing became a silent NULL branch');

create temp table cust2 as
  select app.create_customer('person','Sara Ali',null,null,null,'+201117776666',null,null,null,null,false,null,false) as id;
select is(
  (select first_registered_branch_id from public.customers where id = (select id from cust2)),
  '79000000-0000-0000-0000-00000000000a'::uuid,
  '...and the customer registered during the scheduled transfer carries the branch, which canon 03 requires the system to record');

savepoint m2;
select set_config('request.jwt.claims','{"sub":"79000000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
update public.user_branch_assignments set ends_at = now() - interval '1 day'
 where id = '79000000-0000-0000-0000-0000000000b1';
select set_config('request.jwt.claims','{"sub":"79000000-0000-0000-0000-0000000000a1"}',true);
select is(
  (select count(*)::int from app.current_placement()),
  0,
  'NEGATIVE CONTROL ON THE FIX: a placement that has ALREADY ended is still excluded -- the widened window did not become "any placement ever"');
rollback to savepoint m2;

-- ================================================================================================
-- find_customer_duplicates -- matching and tenant isolation.
-- ================================================================================================
select is(
  (select count(*)::int from app.find_customer_duplicates('+20 111 999-8888', null, null, null, null)),
  1,
  'find_customer_duplicates matches through normalization: a presentationally formatted phone finds the customer stored in canonical form');

select ok(
  not exists (select 1 from app.find_customer_duplicates('+20 111 999-8888', null, null, null, null) d
              where d.customer_id = '79000000-0000-0000-0000-0000000000e9'),
  'TENANT ISOLATION: the RIVAL tenant customer holding the SAME phone number is not returned -- find_customer_duplicates is SECURITY INVOKER, so RLS bounds it');

select finish();
rollback;
