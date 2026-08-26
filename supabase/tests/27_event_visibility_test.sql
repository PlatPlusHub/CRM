-- pgTAP: audit-trail visibility and the 360 timelines (SPEC-143).
--
-- SPEC-137 scoped every operational table by branch, department and assignment, and left `events`
-- on its original tenant-only policy. The result was that a Cairo employee could not read an
-- Alexandria booking but COULD read the entire event stream describing it -- every status change,
-- every reason, every payload. The more thoroughly the entities were scoped, the more the audit
-- trail stood out as the way around it.
--
-- Runs as `authenticated`, because the whole subject is an RLS policy.
create extension if not exists pgtap with schema extensions;

begin;
select plan(9);

insert into auth.users (id, email) values
  ('27000000-0000-0000-0000-0000000000a1','cairo@example.com'),
  ('27000000-0000-0000-0000-0000000000a2','alex@example.com'),
  ('27000000-0000-0000-0000-0000000000a3','owner@example.com');

insert into public.tenants (id, name, slug, status) values
  ('27000000-0000-0000-0000-000000000001','Timeline Travel','timeline-travel','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.branches (id, tenant_id, name, slug) values
  ('27000000-0000-0000-0000-00000000000a','27000000-0000-0000-0000-000000000001','Cairo','cairo'),
  ('27000000-0000-0000-0000-00000000000b','27000000-0000-0000-0000-000000000001','Alexandria','alexandria');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('27000000-0000-0000-0000-0000000000c1','27000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-00000000000a','sales','Cairo Sales'),
  ('27000000-0000-0000-0000-0000000000c2','27000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-00000000000b','sales','Alex Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('27000000-0000-0000-0000-000000000011','27000000-0000-0000-0000-000000000001','Cairo Employee','cairo@example.com',true,'27000000-0000-0000-0000-0000000000a1'),
  ('27000000-0000-0000-0000-000000000012','27000000-0000-0000-0000-000000000001','Alex Employee','alex@example.com',true,'27000000-0000-0000-0000-0000000000a2'),
  ('27000000-0000-0000-0000-000000000013','27000000-0000-0000-0000-000000000001','Owner','owner@example.com',true,'27000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('27000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000011','27000000-0000-0000-0000-00000000000a','27000000-0000-0000-0000-0000000000c1',true),
  ('27000000-0000-0000-0000-000000000001','27000000-0000-0000-0000-000000000012','27000000-0000-0000-0000-00000000000b','27000000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '27000000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('27000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('27000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('27000000-0000-0000-0000-000000000013'::uuid,'owner')) as v(uid, role_code)
join public.roles r on r.code = v.role_code;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('27000000-0000-0000-0000-0000000000d1','27000000-0000-0000-0000-000000000001','person','Timeline Customer','+201009998888');

-- An Alexandria booking, and an event describing it.
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('27000000-0000-0000-0000-0000000000f1','27000000-0000-0000-0000-000000000001',
   '27000000-0000-0000-0000-00000000000b','27000000-0000-0000-0000-0000000000c2',
   '27000000-0000-0000-0000-0000000000d1','27000000-0000-0000-0000-000000000012',
   '27000000-0000-0000-0000-00000000000b','27000000-0000-0000-0000-0000000000c2',
   'draft','Alexandria booking','BK-ALX-0001');

insert into public.events (tenant_id, event_type_code, severity_code, actor_user_id, entity_type, entity_id,
                           previous_state, new_state, reason, payload) values
  ('27000000-0000-0000-0000-000000000001','booking_created','info','27000000-0000-0000-0000-000000000012',
   'booking','27000000-0000-0000-0000-0000000000f1', null, 'draft', 'created in Alexandria',
   '{"note":"commercially sensitive detail"}'::jsonb),
  ('27000000-0000-0000-0000-000000000001','customer_created','info','27000000-0000-0000-0000-000000000012',
   'customer','27000000-0000-0000-0000-0000000000d1', null, null, null, null);

set local role authenticated;

-- ---------------------------------------------------------------------------------------------
-- The bypass that existed until this migration.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"27000000-0000-0000-0000-0000000000a1"}', true);

select is((select count(*)::int from public.bookings), 0,
  'the Cairo employee cannot see the Alexandria booking -- SPEC-137 holding, and the anchor for what follows');

select is((select count(*)::int from public.events where entity_type = 'booking'), 0,
  'AND CANNOT READ ITS EVENT STREAM EITHER -- previously the audit trail described in full a record the reader was refused');

select is((select count(*)::int from public.events where entity_type = 'customer'), 1,
  '...while customer events stay visible, because the customer master itself is tenant-visible by canon 05 -- the rule follows the subject rather than blanket-hiding the table');

-- The owner (tenant-wide) must still see everything, or the audit trail is useless to the people
-- who need it most.
select set_config('request.jwt.claims', '{"sub":"27000000-0000-0000-0000-0000000000a3"}', true);
select is((select count(*)::int from public.events), 2,
  'the owner reads the whole stream -- a scoped audit trail that hides events from the owner would be a worse defect than the one it fixes');

-- The employee who performed the action keeps sight of it.
select set_config('request.jwt.claims', '{"sub":"27000000-0000-0000-0000-0000000000a2"}', true);
select is((select count(*)::int from public.events where entity_type = 'booking'), 1,
  'the Alexandria employee reads the event for their own branch''s booking');

-- ---------------------------------------------------------------------------------------------
-- The 360 timelines, and the fact that they are not a way around the scope model.
-- ---------------------------------------------------------------------------------------------
select is((select count(*)::int from app.customer_timeline('27000000-0000-0000-0000-0000000000d1')), 2,
  'CUSTOMER 360: the timeline assembles the customer''s own events and their booking''s into one chronological stream');

select set_config('request.jwt.claims', '{"sub":"27000000-0000-0000-0000-0000000000a1"}', true);
select is((select count(*)::int from app.customer_timeline('27000000-0000-0000-0000-0000000000d1')), 1,
  '...and the SAME call returns only what the caller may see -- the timeline inherits the scope model rather than routing around it');

select is(
  (select entity_type from app.customer_timeline('27000000-0000-0000-0000-0000000000d1') limit 1),
  'customer',
  '...specifically the customer event, not the out-of-branch booking event');

-- Ordering is by `seq`, not `created_at`: a multi-step RPC writes several events in the same
-- instant, and ordering by timestamp alone would return them in an arbitrary order.
select set_config('request.jwt.claims', '{"sub":"27000000-0000-0000-0000-0000000000a3"}', true);
select is(
  (select array_agg(t.seq order by t.seq) = array_agg(t.seq)
     from app.customer_timeline('27000000-0000-0000-0000-0000000000d1') t),
  true,
  'the timeline is returned in a total order that survives same-instant events (seq, not created_at)');

select * from finish();
rollback;
