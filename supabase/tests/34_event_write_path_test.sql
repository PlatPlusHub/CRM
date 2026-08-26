-- pgTAP: WP-00 -- the audit spine may only be written through app.record_event, and what it
-- writes is authoritative rather than caller-supplied.
--
-- Discovery-to-guard for the forgery proven on 2026-08-26. Running as a real `authenticated`
-- employee is the whole point: the defect was invisible to a postgres-role test, because postgres
-- bypasses both the grant and the policy that were the only things standing in the way.
--
-- The failure being guarded: an employee inserted straight into public.events an event that was
-- attributed to a COLLEAGUE, described a lead they could not read, used an event_type_code absent
-- from the registry, and was backdated 400 days -- and because public.events carries
-- `forbid_mutation`, that forged row could never be corrected or removed by anyone.
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email) values
  ('34000000-0000-0000-0000-0000000000a1','cairo@evt.test'),
  ('34000000-0000-0000-0000-0000000000a2','alex@evt.test');
insert into public.tenants (id, name, slug, status) values
  ('34000000-0000-0000-0000-000000000001','Evt Travel','evt-travel','active'),
  ('34000000-0000-0000-0000-000000000002','Other Tenant','evt-other','active');
insert into public.branches (id, tenant_id, name, slug) values
  ('34000000-0000-0000-0000-00000000000a','34000000-0000-0000-0000-000000000001','Cairo','cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('34000000-0000-0000-0000-0000000000c1','34000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-00000000000a','sales','Cairo Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('34000000-0000-0000-0000-000000000011','34000000-0000-0000-0000-000000000001','Cairo Employee','cairo@evt.test',true,'34000000-0000-0000-0000-0000000000a1'),
  ('34000000-0000-0000-0000-000000000012','34000000-0000-0000-0000-000000000001','Alex Employee','alex@evt.test',true,'34000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('34000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-000000000011','34000000-0000-0000-0000-00000000000a','34000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '34000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-000000000011'::uuid, r.id,'tenant'
from public.roles r where r.code = 'employee';

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"34000000-0000-0000-0000-0000000000a1"}', true);

-- ---------------------------------------------------------------------------------------------
-- 1-2. The privilege layer: the direct route is gone. These are the exact statements that
--      succeeded before this migration.
-- ---------------------------------------------------------------------------------------------
select throws_ok(
  $$insert into public.events (tenant_id, event_type_code, severity_code, actor_user_id, entity_type, entity_id, created_at)
    values ('34000000-0000-0000-0000-000000000001','lead_created','info',
            '34000000-0000-0000-0000-000000000012','lead','34000000-0000-0000-0000-0000000000e9',
            now() - interval '400 days')$$,
  '42501',
  'permission denied for table events',
  'an employee CANNOT insert directly into public.events -- the forgery path is closed at the grant');

select throws_ok(
  $$insert into public.security_events (tenant_id, user_id, security_event_type_code, created_at)
    values ('34000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-000000000012',
            'login_failure', now() - interval '400 days')$$,
  '42501',
  'permission denied for table security_events',
  'nor into public.security_events -- a colleague cannot be framed with a fabricated login failure');

-- ---------------------------------------------------------------------------------------------
-- 3. Positive baseline. The governed path must still work, or this migration would have traded a
--    forgery hole for a broken CRM. A test that only proves a denial is the failure mode this
--    repository has already been bitten by.
-- ---------------------------------------------------------------------------------------------
select lives_ok(
  $$select app.create_task('Call the customer back','call_customer')$$,
  'the ordinary RPC path still emits its event -- app.create_task succeeds end to end');

select is(
  (select count(*)::int from public.events where event_type_code = 'task_created'),
  1,
  '...and exactly one task_created event reached the spine through app.record_event');

-- ---------------------------------------------------------------------------------------------
-- 4-7. What record_event writes is authoritative, not caller-supplied.
-- ---------------------------------------------------------------------------------------------
select is(
  (select actor_user_id from public.events where event_type_code = 'task_created'),
  '34000000-0000-0000-0000-000000000011'::uuid,
  'the actor is the caller, taken from the session rather than from the arguments');

select ok(
  (select created_at from public.events where event_type_code = 'task_created') > now() - interval '1 minute',
  'the timestamp is server-side: created_at is not in record_event''s column list, so it cannot be backdated');

-- Reattribution attempt through the surviving RPC surface: authenticated keeps EXECUTE on
-- record_event (45 of its 50 callers are SECURITY INVOKER), so the function itself must refuse to
-- believe a caller-supplied actor.
select lives_ok(
  $$select app.record_event('34000000-0000-0000-0000-000000000001','customer_created','customer',
        '34000000-0000-0000-0000-0000000000d9','34000000-0000-0000-0000-000000000012')$$,
  'a direct record_event call naming a colleague as actor is accepted...');

select is(
  (select actor_user_id from public.events where event_type_code = 'customer_created'),
  '34000000-0000-0000-0000-000000000011'::uuid,
  '...but the colleague is ignored and the event is attributed to whoever actually called it -- self-incriminating, not forgery');

select throws_ok(
  $$select app.record_event('34000000-0000-0000-0000-000000000002','customer_created','customer',
        '34000000-0000-0000-0000-0000000000d9')$$,
  '42501',
  null,
  'a caller cannot write an event into another tenant, even via the governed function');

select throws_ok(
  $$select app.record_event('34000000-0000-0000-0000-000000000001','not_a_registered_event','customer',
        '34000000-0000-0000-0000-0000000000d9')$$,
  null,
  null,
  'the event_type registry is now unbypassable -- the direct INSERT that used to skip it is gone');

-- ---------------------------------------------------------------------------------------------
-- 8. The system/integration path must survive. app.process_lead_sla, the two n8n conversion RPCs
--    and app.capture_attribution_click all run with NO user session and pass a tenant read from a
--    row. Pinning tenant to the session unconditionally would have broken the n8n contract, so the
--    no-session branch is a behaviour this test pins down rather than an accident.
-- ---------------------------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', null, true);
select lives_ok(
  $$select app.record_event('34000000-0000-0000-0000-000000000001','offline_conversion_sent',
        'offline_conversion','34000000-0000-0000-0000-0000000000f9', null)$$,
  'a system-context call with no session still writes, supplying its own tenant and a null actor');

select finish();
rollback;
