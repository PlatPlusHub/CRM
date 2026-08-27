-- pgTAP: WP-01 -- every entity whose creation event is registered and has a producer now emits it,
-- exactly once, correctly attributed, and the 360 timelines begin at the beginning.
--
-- Before this, four registered and ACTIVE `*_created` types were never emitted by anything, so a
-- customer's or lead's history started halfway through the relationship. Customer 360 could show
-- what happened to a customer but never that the customer had been created, by whom, or when.
--
-- The emission is a trigger rather than a line inside each RPC, for a reason this file asserts
-- directly: SEC-1 is still open, so `authenticated` keeps direct INSERT on these tables, and an
-- in-RPC event would be skipped entirely by a direct write.
create extension if not exists pgtap with schema extensions;

begin;
select plan(14);

insert into auth.users (id, email) values ('37000000-0000-0000-0000-0000000000a1','emp@evt1.test');
insert into public.tenants (id, name, slug, status) values
  ('37000000-0000-0000-0000-000000000001','Evt1 Travel','evt1-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '37000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('37000000-0000-0000-0000-00000000000a','37000000-0000-0000-0000-000000000001','Cairo','evt1-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('37000000-0000-0000-0000-0000000000c1','37000000-0000-0000-0000-000000000001','37000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('37000000-0000-0000-0000-000000000011','37000000-0000-0000-0000-000000000001','Employee','emp@evt1.test',true,'37000000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('37000000-0000-0000-0000-000000000001','37000000-0000-0000-0000-000000000011','37000000-0000-0000-0000-00000000000a','37000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '37000000-0000-0000-0000-000000000001','37000000-0000-0000-0000-000000000011'::uuid, r.id,'tenant'
from public.roles r where r.code = 'employee';

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"37000000-0000-0000-0000-0000000000a1"}', true);

-- =============================================================================================
-- 1-5. The RPC path: exactly one event, correct type, entity, tenant and actor.
-- =============================================================================================
select lives_ok(
  $$select app.create_customer('person','Timeline Customer', p_primary_phone => '+201006661111')$$,
  'BASELINE: an employee can create a customer at all -- without this the counts below would prove nothing');

select is(
  (select count(*)::int from public.events where event_type_code = 'customer_created'),
  1,
  'exactly ONE customer_created event -- not zero, and not two from a duplicated path');

select is(
  (select entity_type from public.events where event_type_code = 'customer_created'),
  'customer',
  'the event names the right entity_type, so the read policy can dispatch it to the customer''s own RLS');

select is(
  (select e.entity_id from public.events e where e.event_type_code = 'customer_created'),
  (select c.id from public.customers c where c.full_name = 'Timeline Customer'),
  '...and points at the customer that was actually created');

select is(
  (select actor_user_id from public.events where event_type_code = 'customer_created'),
  '37000000-0000-0000-0000-000000000011'::uuid,
  'the actor is the employee who created it -- "who first received this customer" is now answerable');

-- =============================================================================================
-- 6-8. Lead creation, including the state the lead was born in.
-- =============================================================================================
select lives_ok(
  $$select app.create_lead('37000000-0000-0000-0000-00000000000a','37000000-0000-0000-0000-0000000000c1',
      'manual_entry','New enquiry',
      p_customer_id => (select id from public.customers where full_name = 'Timeline Customer'))$$,
  'BASELINE: the employee can create a lead');

select is(
  (select count(*)::int from public.events where event_type_code = 'lead_created'),
  1,
  'exactly ONE lead_created event');

select isnt(
  (select new_state from public.events where event_type_code = 'lead_created'),
  null,
  '...carrying the state the lead was BORN in, so the timeline''s first entry is not stateless');

-- =============================================================================================
-- 9. Passenger creation.
-- =============================================================================================
-- Run as senior_employee, not employee: `app.create_passenger` gates on CREATE_BOOKING_ITEM, which
-- the ordinary `employee` role does not hold. Using `employee` here would have failed for a
-- PERMISSION reason and told us nothing about event emission. (That an employee cannot register a
-- traveller is a real day-one workflow question, recorded for the role audit -- not settled here.)
reset role;
-- ...and CLEAR the JWT claim with it. `reset role` changes the database role but leaves
-- `request.jwt.claims` set, so `auth.uid()` still resolves and every session-aware guard --
-- including RBAC-1's role-change trigger -- correctly reads this as a user write by someone
-- who lacks MANAGE_USERS. That hybrid (postgres role, employee identity) cannot occur in
-- production. Clearing the claim makes this fixture the system path it was always meant to be.
select set_config('request.jwt.claims', null, true);
insert into auth.users (id, email) values ('37000000-0000-0000-0000-0000000000a2','senior@evt1.test');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('37000000-0000-0000-0000-000000000012','37000000-0000-0000-0000-000000000001','Senior','senior@evt1.test',true,'37000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('37000000-0000-0000-0000-000000000001','37000000-0000-0000-0000-000000000012','37000000-0000-0000-0000-00000000000a','37000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '37000000-0000-0000-0000-000000000001','37000000-0000-0000-0000-000000000012'::uuid, r.id,'tenant'
from public.roles r where r.code = 'senior_employee';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"37000000-0000-0000-0000-0000000000a2"}', true);

select lives_ok(
  $$select app.create_passenger('Traveller','One', p_customer_id =>
      (select id from public.customers where full_name = 'Timeline Customer'))$$,
  'BASELINE: a senior_employee can create a passenger');

select is(
  (select count(*)::int from public.events where event_type_code = 'passenger_created'),
  1,
  'exactly ONE passenger_created event');

-- =============================================================================================
-- 11. THE 360 PAYOFF -- the customer's timeline now starts at the customer's creation.
-- =============================================================================================
select is(
  (select t.event_type_code from app.customer_timeline(
       (select id from public.customers where full_name = 'Timeline Customer')) t
    order by t.seq limit 1),
  'customer_created',
  'CUSTOMER 360 now BEGINS at customer_created -- previously the history started halfway through the relationship');

-- =============================================================================================
-- 12. DIRECT DML still emits. This is why the mechanism is a trigger and not a line in the RPC:
--     SEC-1 is open, so a direct INSERT is possible, and it must not create an entity whose
--     creation is permanently absent from the immutable spine.
-- =============================================================================================
select lives_ok(
  $$insert into public.customers (tenant_id, customer_type_code, full_name, primary_phone)
    values ('37000000-0000-0000-0000-000000000001','person','Direct Customer','+201006662222')$$,
  'a direct INSERT (no RPC) succeeds -- SEC-1 still permits it');

select is(
  (select count(*)::int from public.events where event_type_code = 'customer_created'),
  2,
  '...and it ALSO emitted its creation event -- an in-RPC emission would have missed this entirely');

-- =============================================================================================
-- 14. THE UPSERT EDGE CASE -- app.record_trusted_device UPDATEs a known device and only INSERTs a
--     new one. Re-trusting the same device must NOT emit a second "created" event, or every
--     re-login would forge a fresh creation into an append-only spine.
-- =============================================================================================
select app.record_trusted_device('device-abc');
select app.record_trusted_device('device-abc');
select is(
  (select count(*)::int from public.events where event_type_code = 'trusted_device_created'),
  1,
  'recording the SAME trusted device twice emits ONE created event -- the second call is an update, not a creation');

select finish();
rollback;
