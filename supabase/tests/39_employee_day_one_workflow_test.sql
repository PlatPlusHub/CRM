-- pgTAP: SPEC-154 -- can an ordinary employee actually do their job on day one?
--
-- This is the "first-day employee" test the programme was missing. Every other capability built here
-- -- creation events, 360 timelines, the subscription gate, financial privacy -- exists to support a
-- workflow the front-line role could not previously execute at all: before this migration `employee`
-- held 13 permissions and could not create a quotation, create a booking, create a booking item,
-- close a lead, complete a task, resolve a complaint, send a message or upload a document, while
-- canon 28's Employee column says it should.
--
-- The whole file runs as a real `authenticated` employee. Each positive step is a genuine business
-- action through its real RPC, so the sequence below IS the customer journey, executed end to end by
-- the role that will actually execute it. The denials that follow prove the grant did not become a
-- promotion.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into auth.users (id, email) values
  ('39000000-0000-0000-0000-0000000000a1','emp@day1.test'),
  ('39000000-0000-0000-0000-0000000000a2','other@day1.test');
insert into public.tenants (id, name, slug, status) values
  ('39000000-0000-0000-0000-000000000001','Day1 Travel','day1-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '39000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('39000000-0000-0000-0000-00000000000a','39000000-0000-0000-0000-000000000001','Cairo','day1-cairo'),
  ('39000000-0000-0000-0000-00000000000b','39000000-0000-0000-0000-000000000001','Alex','day1-alex');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('39000000-0000-0000-0000-0000000000c1','39000000-0000-0000-0000-000000000001','39000000-0000-0000-0000-00000000000a','sales','Cairo Sales'),
  ('39000000-0000-0000-0000-0000000000c2','39000000-0000-0000-0000-000000000001','39000000-0000-0000-0000-00000000000b','sales','Alex Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('39000000-0000-0000-0000-000000000011','39000000-0000-0000-0000-000000000001','Day One','emp@day1.test',true,'39000000-0000-0000-0000-0000000000a1'),
  ('39000000-0000-0000-0000-000000000012','39000000-0000-0000-0000-000000000001','Alex Colleague','other@day1.test',true,'39000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('39000000-0000-0000-0000-000000000001','39000000-0000-0000-0000-000000000011','39000000-0000-0000-0000-00000000000a','39000000-0000-0000-0000-0000000000c1',true),
  ('39000000-0000-0000-0000-000000000001','39000000-0000-0000-0000-000000000012','39000000-0000-0000-0000-00000000000b','39000000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '39000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('39000000-0000-0000-0000-000000000011'::uuid),('39000000-0000-0000-0000-000000000012'::uuid)) v(u)
join public.roles r on r.code = 'employee';

-- An Alexandria booking owned by the colleague: the cross-branch control for the denials at the end.
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('39000000-0000-0000-0000-0000000000d9','39000000-0000-0000-0000-000000000001','person','Alex Customer','+201007770000');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference)
values ('39000000-0000-0000-0000-0000000000f9','39000000-0000-0000-0000-000000000001',
        '39000000-0000-0000-0000-00000000000b','39000000-0000-0000-0000-0000000000c2',
        '39000000-0000-0000-0000-0000000000d9','39000000-0000-0000-0000-000000000012',
        '39000000-0000-0000-0000-00000000000b','39000000-0000-0000-0000-0000000000c2',
        'draft','Alex booking','BK-DAY1-ALX');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"39000000-0000-0000-0000-0000000000a1"}', true);

-- =============================================================================================
-- THE JOURNEY. Enquiry -> customer -> lead -> quotation -> won -> booking -> booking item.
-- Every step is the real RPC. Before SPEC-154 the sequence stopped dead at step 3.
-- =============================================================================================
select lives_ok(
  $$select app.create_customer('person','Walk-in Customer', p_primary_phone => '+201005550001')$$,
  'DAY ONE 1/8: the employee registers the customer who just walked in');

select lives_ok(
  $$select app.create_lead('39000000-0000-0000-0000-00000000000a','39000000-0000-0000-0000-0000000000c1',
      'direct_call','Umrah enquiry',
      p_customer_id => (select id from public.customers where tenant_id = '39000000-0000-0000-0000-000000000001' and full_name='Walk-in Customer'))$$,
  'DAY ONE 2/8: ...opens a lead for the enquiry');

select lives_ok(
  $$select app.create_task('Call the customer back','call_customer',
      p_related_entity_type => 'lead',
      p_related_entity_id => (select id from public.leads where tenant_id = '39000000-0000-0000-0000-000000000001' and title='Umrah enquiry'))$$,
  'DAY ONE 3/8: ...schedules the follow-up call');

select lives_ok(
  $$select app.create_quotation(
      (select id from public.customers where tenant_id = '39000000-0000-0000-0000-000000000001' and full_name='Walk-in Customer'), 'EGP',
      p_lead_id => (select id from public.leads where tenant_id = '39000000-0000-0000-0000-000000000001' and title='Umrah enquiry'))$$,
  'DAY ONE 4/8: ...QUOTES the customer -- the step that was impossible before, and the reason the role existed');

select lives_ok(
  $$select app.add_quotation_item((select id from public.quotations where tenant_id = '39000000-0000-0000-0000-000000000001'), 'umrah', 25000)$$,
  'DAY ONE 5/8: ...prices the package');

select lives_ok(
  $$select app.advance_quotation((select id from public.quotations where tenant_id = '39000000-0000-0000-0000-000000000001'), 'sent', 'emailed to customer')$$,
  'DAY ONE 6/8: ...sends it');

select lives_ok(
  $$select app.create_booking(
      p_customer_id => (select id from public.customers where tenant_id = '39000000-0000-0000-0000-000000000001' and full_name='Walk-in Customer'),
      p_lead_id     => (select id from public.leads where tenant_id = '39000000-0000-0000-0000-000000000001' and title='Umrah enquiry'),
      p_title       => 'Umrah booking',
      p_branch_id   => '39000000-0000-0000-0000-00000000000a',
      p_department_id => '39000000-0000-0000-0000-0000000000c1')$$,
  'DAY ONE 7/8: ...BOOKS it once the customer accepts');

select lives_ok(
  $$select app.create_booking_item(
      (select id from public.bookings where tenant_id = '39000000-0000-0000-0000-000000000001' and title='Umrah booking'), 'umrah', 'EGP')$$,
  'DAY ONE 8/8: ...and adds the service line. The journey completes end to end.');

-- =============================================================================================
-- The work is genuinely recorded, not merely permitted.
-- =============================================================================================
-- Scoped to THIS customer: the fixture also creates the Alexandria customer, so a bare count would
-- assert something about the fixture rather than about the journey.
select is(
  (select count(*)::int from public.events e
    where e.event_type_code='customer_created'
      and e.entity_id = (select id from public.customers where tenant_id = '39000000-0000-0000-0000-000000000001' and full_name='Walk-in Customer')),
  1, 'the journey left a customer_created event for the customer the employee registered -- WP-01 and SPEC-154 compose');

select is(
  (select t.event_type_code from app.customer_timeline(
      (select id from public.customers where tenant_id = '39000000-0000-0000-0000-000000000001' and full_name='Walk-in Customer')) t order by t.seq limit 1),
  'customer_created',
  'CUSTOMER 360 begins at the beginning for a customer the EMPLOYEE created');

-- =============================================================================================
-- THE GRANT IS NOT A PROMOTION. Each denial below has a positive control above: the same actor,
-- in the same session, just performed eight real business actions -- so these refusals are about
-- authority, not about a broken fixture.
-- =============================================================================================
-- SPEC-154-A changed this deliberately. The employee owns the item they just created, and canon 28
-- gives Employee ENTER_COST with scope `assigned`, so pricing their OWN work is correct. The
-- colleague's-item case is proven in `40_financial_scope_test.sql`.
select lives_ok(
  $$update public.booking_items set cost_amount = 12000
     where id = (select id from public.booking_items where tenant_id = '39000000-0000-0000-0000-000000000001')$$,
  'NOW ALLOWED: the employee prices their OWN booking item -- canon 28 ENTER_COST, scope assigned');

select throws_ok(
  $$update public.booking_items set finance_approval_status_code = 'approved'
     where id = (select id from public.booking_items where tenant_id = '39000000-0000-0000-0000-000000000001')$$,
  '42501', null,
  'STILL DENIED: approving finance on their own item');

select throws_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('39000000-0000-0000-0000-000000000001','USD','EGP', 1, now())$$,
  '42501', null,
  'STILL DENIED: setting the company exchange rate');

select throws_ok(
  $$insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
    select '39000000-0000-0000-0000-000000000001','39000000-0000-0000-0000-000000000011', r.id, 'tenant'
      from public.roles r where r.code='owner'$$,
  '42501', null,
  'STILL DENIED: promoting themselves to owner -- SPEC-138 holds after the grant');

-- =============================================================================================
-- Branch isolation survives the grant. The employee can now create bookings; that must not mean
-- reaching another branch's booking.
-- =============================================================================================
select is(
  (select count(*)::int from public.bookings where id='39000000-0000-0000-0000-0000000000f9'),
  0,
  'STILL DENIED: the Alexandria colleague''s booking is invisible -- CREATE_BOOKING did not become cross-branch reach');

select isnt(
  (select count(*)::int from public.bookings), 0,
  'CONTROL: ...while their OWN booking is visible, so the denial above is branch scope and not an empty table');

select finish();
rollback;
