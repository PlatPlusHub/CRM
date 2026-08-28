-- pgTAP: the master-data write paths resolved by RPC-2, exercised through the REAL authorization
-- chain in the manner established by test 17.
--
-- RPC-2 asked which permission governs four entities that have none of their own. This test asserts
-- the answers that were determined from canon, and -- more importantly -- asserts the BEHAVIOUR each
-- one is supposed to produce: normalized contact data, duplicate prevention where duplicates are
-- accidental, and no duplicate prevention where repetition is a legitimate business fact.
--
-- It also proves the MFA boundary in BOTH directions, which no previous test did: the same owner
-- identity is refused without an aal2 claim and succeeds with one.
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

insert into auth.users (id, email) values
  ('22220000-0000-0000-0000-0000000000aa','ops@example.com'),
  ('22220000-0000-0000-0000-0000000000bb','boss@example.com');
insert into public.tenants (id, name, slug, status) values
  ('22220000-0000-0000-0000-000000000001','Master Data Co','masterdata','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.branches (id, tenant_id, name, slug) values
  ('22220000-0000-0000-0000-000000000002','22220000-0000-0000-0000-000000000001','Main','md-main');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('22220000-0000-0000-0000-000000000003','22220000-0000-0000-0000-000000000001','22220000-0000-0000-0000-000000000002','operations','Ops');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('22220000-0000-0000-0000-000000000004','22220000-0000-0000-0000-000000000001','Ops User','ops@example.com',true,'22220000-0000-0000-0000-0000000000aa'),
  ('22220000-0000-0000-0000-000000000005','22220000-0000-0000-0000-000000000001','Boss','boss@example.com',true,'22220000-0000-0000-0000-0000000000bb');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '22220000-0000-0000-0000-000000000001','22220000-0000-0000-0000-000000000004', r.id, 'tenant'
  from public.roles r where r.code = 'branch_manager';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '22220000-0000-0000-0000-000000000001','22220000-0000-0000-0000-000000000005', r.id, 'tenant'
  from public.roles r where r.code = 'owner';
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('22220000-0000-0000-0000-0000000000c1','22220000-0000-0000-0000-000000000001','person','Master Cust');

select set_config('request.jwt.claims', '{"sub":"22220000-0000-0000-0000-0000000000aa"}', true);

-- 1-3. Contact methods: normalized, and an accidental duplicate refused.
select lives_ok(
  $$select app.add_customer_contact_method('22220000-0000-0000-0000-0000000000c1','email','  Ahmed@Gmail.COM ')$$,
  'an operations user can add a customer contact method');

select is(
  (select value from public.customer_contact_methods where tenant_id = '22220000-0000-0000-0000-000000000001' and contact_method_type_code = 'email'),
  'ahmed@gmail.com',
  'the contact value is canonicalized exactly as customers.primary_email is');

select throws_ok(
  $$select app.add_customer_contact_method('22220000-0000-0000-0000-0000000000c1','email','AHMED@gmail.com')$$,
  '23505', null,
  'the same address in different casing is refused as an accidental duplicate');

-- 4. Two distinct phones are legitimate and must still be allowed.
select lives_ok(
  $$select app.add_customer_contact_method('22220000-0000-0000-0000-0000000000c1','secondary_phone','+201000000002')$$,
  'a genuinely different contact method is still accepted');

-- 5-6. Notes: repetition is a business fact, not a duplicate.
select lives_ok(
  $$select app.add_customer_note('22220000-0000-0000-0000-0000000000c1','Called, no answer')$$,
  'a customer note can be recorded');

select lives_ok(
  $$select app.add_customer_note('22220000-0000-0000-0000-0000000000c1','Called, no answer')$$,
  'the same note text can be recorded again -- calling twice is a fact, not a duplicate record');

-- 7-9. Suppliers: created, normalized, and protected from case-variant duplicates.
select lives_ok(
  $$select app.create_supplier('  EgyptAir  ','airline',' +20 (2) 2696-0000 ','  Bookings@EgyptAir.COM ')$$,
  'an operations user can create a supplier');

select is(
  (select email || ' / ' || phone from public.suppliers where tenant_id = '22220000-0000-0000-0000-000000000001' and name = 'EgyptAir'),
  'bookings@egyptair.com / +20226960000',
  'supplier contact data is canonicalized the same way customer contact data is');

select throws_ok(
  $$select app.create_supplier('EGYPTAIR','airline')$$,
  '23505', null,
  'the same supplier in different casing is refused -- payables must not split across two records');

-- 10-12. Marketing campaigns require MANAGE_MARKETING_CAMPAIGN, held only by MFA-gated roles.
select set_config('request.jwt.claims', '{"sub":"22220000-0000-0000-0000-0000000000bb"}', true);

select throws_like(
  $$select app.create_marketing_campaign('Umrah Ramadan','google_ads','G-123')$$,
  '%multi-factor%',
  'an owner WITHOUT an aal2 claim cannot act at all -- MFA is enforced, not documented');

select set_config('request.jwt.claims', '{"sub":"22220000-0000-0000-0000-0000000000bb","aal":"aal2"}', true);

select lives_ok(
  $$select app.create_marketing_campaign('Umrah Ramadan','google_ads','G-123')$$,
  'the same owner WITH an aal2 claim can create the campaign');

select throws_ok(
  $$select app.create_marketing_campaign('Umrah Ramadan Retarget','google_ads','G-123')$$,
  '23505', null,
  'the same platform campaign id cannot be recorded twice -- attribution must not split');

select * from finish();
rollback;
