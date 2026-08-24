-- pgTAP: conditional sub-status vocabulary and the plan matrix (SPEC-141).
--
-- CAT-5 is the interesting half. `booking_items.sub_status_code` is the one catalog-backed column
-- whose governing family depends on ANOTHER column -- canon 26's Sub-Status Rule gives ticket, visa
-- and hotel separate vocabularies -- so a static column->family mapping could not express it and
-- SPEC-136 correctly left it out rather than get it confidently wrong. The rule was never missing;
-- it lived in `app.create_booking_item` and nowhere else. These assertions check that it now holds
-- on the direct path too, and that it is genuinely CONDITIONAL: the same value is valid for one
-- service type and rejected for another.
create extension if not exists pgtap with schema extensions;

begin;
select plan(13);

insert into public.tenants (id, name, slug, status) values
  ('25000000-0000-0000-0000-000000000001','Vocab Travel','vocab-travel','active');
insert into public.branches (id, tenant_id, name, slug) values
  ('25000000-0000-0000-0000-00000000000a','25000000-0000-0000-0000-000000000001','Tanta','tanta');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('25000000-0000-0000-0000-0000000000c1','25000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-00000000000a','ticketing','Tanta Ticketing');
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('25000000-0000-0000-0000-0000000000d1','25000000-0000-0000-0000-000000000001','person','Vocab Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id,
                             booking_status_code, title, booking_reference) values
  ('25000000-0000-0000-0000-0000000000f1','25000000-0000-0000-0000-000000000001',
   '25000000-0000-0000-0000-00000000000a','25000000-0000-0000-0000-0000000000c1',
   '25000000-0000-0000-0000-0000000000d1','draft','Vocab booking','BK-TAN-0001');

-- ---------------------------------------------------------------------------------------------
-- The mapping is conditional, and both directions prove it.
-- ---------------------------------------------------------------------------------------------
select lives_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code, currency_code, sub_status_code)
    values ('25000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-0000000000f1','flight_ticket','draft','EGP','ticketed')$$,
  'a ticket may be "ticketed" -- the value belongs to ticket_sub_status');

select throws_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code, currency_code, sub_status_code)
    values ('25000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-0000000000f1','hotel','draft','EGP','ticketed')$$,
  '23514', null,
  'A HOTEL MAY NOT BE "ticketed" -- the same value is valid for one service type and wrong for another, which is what makes this rule conditional rather than a flat catalog');

select lives_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code, currency_code, sub_status_code)
    values ('25000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-0000000000f1','hotel','draft','EGP','checked_in')$$,
  '...and a hotel may be "checked_in", which a ticket may not');

select throws_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code, currency_code, sub_status_code)
    values ('25000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-0000000000f1','flight_ticket','draft','EGP','checked_in')$$,
  '23514', null,
  '...proving the reverse, so neither result is an accident of which value happened to be tried');

select throws_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code, currency_code, sub_status_code)
    values ('25000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-0000000000f1','umrah','draft','EGP','reserved')$$,
  '23514', null,
  'a service type with NO sub-status family rejects any sub-status rather than silently accepting one');

select lives_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code, currency_code)
    values ('25000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-0000000000f1','umrah','draft','EGP')$$,
  '...while the same service type is perfectly valid with no sub-status at all');

-- Deactivation must bite here exactly as it does for every other catalog-backed column (CAT-4).
update public.catalog_values set is_active = false
 where catalog_type_code = 'visa_sub_status' and code = 'rejected';
select throws_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code, currency_code, sub_status_code)
    values ('25000000-0000-0000-0000-000000000001','25000000-0000-0000-0000-0000000000f1','visa','draft','EGP','rejected')$$,
  '23514', null,
  'a DEACTIVATED sub-status cannot be used, so this column obeys the same deactivation rule as the rest');

-- ---------------------------------------------------------------------------------------------
-- CAT-6: the platform discriminator.
-- ---------------------------------------------------------------------------------------------
select throws_ok(
  $$insert into public.catalog_types (code, name, ownership_type) values ('bogus_family','Bogus','tenant_owned')$$,
  '23514', null,
  'catalog_types.ownership_type rejects a value outside its two-value domain');

-- ---------------------------------------------------------------------------------------------
-- The plan matrix. It was entirely empty, with no reader, while canon 28 states "Plan denial
-- overrides user role permission".
-- ---------------------------------------------------------------------------------------------
select is((select count(*)::int from public.feature_entitlements), 66,
  'the plan matrix is seeded -- 16 capability switches + 6 numeric ceilings across 3 plans');

select is(
  (select is_enabled from public.feature_entitlements fe
     join public.subscription_plans p on p.id = fe.subscription_plan_id
    where p.plan_code = 'starter' and fe.feature_code = 'booking'),
  false,
  'Starter does not include Booking (canon 28 §Feature Access By Plan)');

select is(
  (select limit_value from public.feature_entitlements fe
     join public.subscription_plans p on p.id = fe.subscription_plan_id
    where p.plan_code = 'professional' and fe.feature_code = 'max_branches'),
  3::numeric,
  'Professional is capped at 3 branches (canon 17 §Plan Limits) -- which is also what "Multi Branch: Limited" means');

select is(
  (select limit_value from public.feature_entitlements fe
     join public.subscription_plans p on p.id = fe.subscription_plan_id
    where p.plan_code = 'enterprise' and fe.feature_code = 'max_branches'),
  null,
  'Enterprise is uncapped -- "Unlimited" is the absence of a ceiling, not a sentinel number that would later be mistaken for one');

select throws_ok(
  $$insert into public.feature_entitlements (subscription_plan_id, feature_code, is_enabled)
    select id, 'made_up_feature', true from public.subscription_plans where plan_code = 'starter'$$,
  '23514', null,
  'and an unrecognised feature code is rejected, so the matrix cannot drift away from canon by insertion');

select * from finish();
rollback;
