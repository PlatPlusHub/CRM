-- pgTAP: lifecycle transition enforcement (SPEC-149).
--
-- THE BYPASS THIS CLOSES, reproduced before the fix: an authenticated employee who does NOT hold
-- `ISSUE_BOOKING` ran `update bookings set booking_status_code = 'issued'` and the booking went from
-- `draft` straight to `issued` -- skipping pending_approval, confirmed and in_progress -- with zero
-- events, no authorization and no negative-balance check. Every `advance_*` RPC was correct; nothing
-- obliged anyone to call one.
--
-- The assertions separate the two things a transition guard must do, because a guard that did only
-- one of them would look correct and protect nothing:
--   * is this (from -> to) a transition the business recognises?
--   * does the caller hold the capability that governs it?
--
-- The last assertion is a DRIFT GUARD, and its shape is a lesson rather than a formality. The
-- registry was first built from the `advance_*` RPCs alone and immediately failed test 24, because
-- `app.assign_lead` also moves a lead's status and is not an `advance_*` function. Scanning only the
-- functions named like transition RPCs would repeat exactly that mistake, so the guard scans EVERY
-- app function for a status-literal assignment.
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email) values
  ('33000000-0000-0000-0000-0000000000a1','emp@example.com'),
  ('33000000-0000-0000-0000-0000000000a2','mgr@example.com');

insert into public.tenants (id, name, slug, status) values
  ('33000000-0000-0000-0000-000000000001','Lifecycle Travel','lifecycle-travel','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.branches (id, tenant_id, name, slug) values
  ('33000000-0000-0000-0000-00000000000a','33000000-0000-0000-0000-000000000001','Heliopolis','heliopolis');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('33000000-0000-0000-0000-0000000000c1','33000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-00000000000a','sales','Helio Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('33000000-0000-0000-0000-000000000011','33000000-0000-0000-0000-000000000001','Employee','emp@example.com',true,'33000000-0000-0000-0000-0000000000a1'),
  ('33000000-0000-0000-0000-000000000012','33000000-0000-0000-0000-000000000001','Manager','mgr@example.com',true,'33000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('33000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000011','33000000-0000-0000-0000-00000000000a','33000000-0000-0000-0000-0000000000c1',true),
  ('33000000-0000-0000-0000-000000000001','33000000-0000-0000-0000-000000000012','33000000-0000-0000-0000-00000000000a','33000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '33000000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('33000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('33000000-0000-0000-0000-000000000012'::uuid,'branch_manager')) as v(uid, role_code)
join public.roles r on r.code = v.role_code;

insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('33000000-0000-0000-0000-0000000000d1','33000000-0000-0000-0000-000000000001','person','Lifecycle Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('33000000-0000-0000-0000-0000000000f1','33000000-0000-0000-0000-000000000001',
   '33000000-0000-0000-0000-00000000000a','33000000-0000-0000-0000-0000000000c1',
   '33000000-0000-0000-0000-0000000000d1','33000000-0000-0000-0000-000000000011',
   '33000000-0000-0000-0000-00000000000a','33000000-0000-0000-0000-0000000000c1',
   'draft','Helio booking','BK-HEL-0001');

set local role authenticated;

-- ---------------------------------------------------------------------------------------------
-- The exact bypass.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"33000000-0000-0000-0000-0000000000a1"}', true);

select is((select count(*)::int from public.bookings where id = '33000000-0000-0000-0000-0000000000f1'), 1,
  'the employee can see and would be able to update this booking -- so the refusals below are the guard, not RLS');
select is(app.has_permission('ISSUE_BOOKING'), false,
  '...and does not hold ISSUE_BOOKING');

select throws_ok(
  $$update public.bookings set booking_status_code = 'issued' where id = '33000000-0000-0000-0000-0000000000f1'$$,
  '23514', null,
  'THE BYPASS IS CLOSED -- draft cannot jump to issued by direct SQL, because it is not a transition the business recognises');

select is((select booking_status_code from public.bookings where id = '33000000-0000-0000-0000-0000000000f1'), 'draft',
  '...and the booking is untouched, rather than half-moved');

-- A LEGAL transition must still work for someone entitled to make it, or the guard is an outage.
-- The branch manager is used rather than the employee because the `employee` role holds NO booking
-- capability at all -- a first draft of this test asserted the employee could advance the booking and
-- failed, which is the role model working exactly as canon 28 describes it.
select set_config('request.jwt.claims', '{"sub":"33000000-0000-0000-0000-0000000000a2"}', true);
select lives_ok(
  $$update public.bookings set booking_status_code = 'pending_approval' where id = '33000000-0000-0000-0000-0000000000f1'$$,
  'the branch manager CAN make a legal transition -- draft -> pending_approval under CREATE_BOOKING');

-- ---------------------------------------------------------------------------------------------
-- Validity and authority are separate failures, and both must bite.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"33000000-0000-0000-0000-0000000000a1"}', true);
select throws_ok(
  $$update public.bookings set booking_status_code = 'confirmed' where id = '33000000-0000-0000-0000-0000000000f1'$$,
  '42501', null,
  'A LEGAL transition the employee is NOT entitled to make is refused on AUTHORITY -- pending_approval -> confirmed needs APPROVE_BOOKING');

select set_config('request.jwt.claims', '{"sub":"33000000-0000-0000-0000-0000000000a2"}', true);
select lives_ok(
  $$update public.bookings set booking_status_code = 'confirmed' where id = '33000000-0000-0000-0000-0000000000f1'$$,
  '...and the branch manager, who holds APPROVE_BOOKING, can make exactly that transition');

select throws_ok(
  $$update public.bookings set booking_status_code = 'refunded' where id = '33000000-0000-0000-0000-0000000000f1'$$,
  '23514', null,
  '...but even the manager cannot make an ILLEGAL one -- confirmed -> refunded is refused on VALIDITY, not authority, so the two checks are genuinely independent');

-- Ordinary edits that do not touch the status must not be caught by the guard.
select lives_ok(
  $$update public.bookings set title = 'Renamed' where id = '33000000-0000-0000-0000-0000000000f1'$$,
  'an edit that does not move the status is unaffected -- the guard fires on transitions, not on every write');

-- ---------------------------------------------------------------------------------------------
-- Drift guards.
-- ---------------------------------------------------------------------------------------------
reset role;
select is(
  (select count(*)::int from (
      select st.table_name, st.from_status, st.to_status
      from app.status_transitions st
      where st.table_name not in (
          select c.relname from pg_class c join pg_namespace n on n.oid = c.relnamespace
          where n.nspname = 'public' and c.relkind = 'r')
   ) z),
  0,
  'every table named in the transition registry actually exists');

-- Every status literal any app function can ASSIGN must be a destination the registry recognises.
-- Deliberately scans all app functions rather than only the `advance_*` ones: the registry was first
-- built from `advance_*` alone and missed `app.assign_lead`, `app.record_lead_interaction` and
-- `app.convert_lead`, which is precisely the gap this assertion exists to prevent recurring.
select is(
  (select coalesce(string_agg(distinct m.col || '=' || m.lit, ', '), '(none)')
   from pg_proc p
   join pg_namespace n on n.oid = p.pronamespace and n.nspname = 'app'
   cross join lateral (
       select mm[1] as col, mm[2] as lit
       from regexp_matches(p.prosrc,
            '(lead_status_code|booking_status_code|base_status_code|quotation_status_code|refund_status_code|task_status_code|conversation_status_code|complaint_status_code|service_request_status_code)\s*=\s*''([a-z_]+)''',
            'g') mm
   ) m
   where not exists (
       select 1 from app.status_transitions st
       where st.status_column = m.col and st.to_status = m.lit
   )),
  '(none)',
  'no app function can write a status the registry does not recognise as a destination -- a new transition RPC cannot silently escape the guard');

select * from finish();
rollback;
