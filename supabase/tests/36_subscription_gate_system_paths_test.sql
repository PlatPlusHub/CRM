-- pgTAP: WP-03 post-package discovery -- the subscription gate must not become a cross-tenant
-- denial of service, and its two "is this safe?" questions answered behaviourally.
--
-- SPEC-152 attached the write gate to 42 tables. The gate RAISES, which is right for a user's own
-- write and wrong for a system path that spans tenants: an unhandled exception aborts the whole
-- statement or function, so ONE lapsed tenant denies service to every other tenant. Neither defect
-- below was visible by reading the gate; both were found by asking which SECURITY DEFINER functions
-- write a gated table.
--
-- Every denial here is paired with a positive baseline. A denial test whose fixture could not have
-- performed the operation anyway proves nothing, and this repository has already shipped one.
create extension if not exists pgtap with schema extensions;

begin;
select plan(10);

-- Two tenants: A is healthy, B is suspended. B is the poison pill.
insert into auth.users (id, email) values
  ('36000000-0000-0000-0000-0000000000a1','a@sys.test'),
  ('36000000-0000-0000-0000-0000000000b1','b@sys.test');
insert into public.tenants (id, name, slug, status) values
  ('36000000-0000-0000-0000-00000000000A','Healthy Tenant','sys-healthy','active'),
  ('36000000-0000-0000-0000-00000000000B','Lapsed Tenant','sys-lapsed','active');

-- Both start ACTIVE so the mirror-image fixtures can be built at all; B is suspended further down,
-- immediately before the assertion that needs it. The gate is live during fixture construction, so
-- building B's data while suspended is impossible -- itself a demonstration that the gate works.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and t.id in ('36000000-0000-0000-0000-00000000000A','36000000-0000-0000-0000-00000000000B');

-- Mirror-image fixtures so the only difference between the tenants is subscription state.
insert into public.branches (id, tenant_id, name, slug) values
  ('36000000-0000-0000-0000-0000000000aa','36000000-0000-0000-0000-00000000000A','A Branch','sys-a-br'),
  ('36000000-0000-0000-0000-0000000000bb','36000000-0000-0000-0000-00000000000B','B Branch','sys-b-br');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('36000000-0000-0000-0000-0000000000ac','36000000-0000-0000-0000-00000000000A','36000000-0000-0000-0000-0000000000aa','sales','A Sales'),
  ('36000000-0000-0000-0000-0000000000bc','36000000-0000-0000-0000-00000000000B','36000000-0000-0000-0000-0000000000bb','sales','B Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('36000000-0000-0000-0000-0000000000a2','36000000-0000-0000-0000-00000000000A','A One','a@sys.test',true,'36000000-0000-0000-0000-0000000000a1'),
  ('36000000-0000-0000-0000-0000000000a3','36000000-0000-0000-0000-00000000000A','A Two','a2@sys.test',true,null),
  ('36000000-0000-0000-0000-0000000000b2','36000000-0000-0000-0000-00000000000B','B One','b@sys.test',true,'36000000-0000-0000-0000-0000000000b1'),
  ('36000000-0000-0000-0000-0000000000b3','36000000-0000-0000-0000-00000000000B','B Two','b2@sys.test',true,null);
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('36000000-0000-0000-0000-00000000000A','36000000-0000-0000-0000-0000000000a2','36000000-0000-0000-0000-0000000000aa','36000000-0000-0000-0000-0000000000ac',true),
  ('36000000-0000-0000-0000-00000000000A','36000000-0000-0000-0000-0000000000a3','36000000-0000-0000-0000-0000000000aa','36000000-0000-0000-0000-0000000000ac',true),
  ('36000000-0000-0000-0000-00000000000B','36000000-0000-0000-0000-0000000000b2','36000000-0000-0000-0000-0000000000bb','36000000-0000-0000-0000-0000000000bc',true),
  ('36000000-0000-0000-0000-00000000000B','36000000-0000-0000-0000-0000000000b3','36000000-0000-0000-0000-0000000000bb','36000000-0000-0000-0000-0000000000bc',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant' from (values
  ('36000000-0000-0000-0000-00000000000A'::uuid,'36000000-0000-0000-0000-0000000000a2'::uuid),
  ('36000000-0000-0000-0000-00000000000A'::uuid,'36000000-0000-0000-0000-0000000000a3'::uuid),
  ('36000000-0000-0000-0000-00000000000B'::uuid,'36000000-0000-0000-0000-0000000000b2'::uuid),
  ('36000000-0000-0000-0000-00000000000B'::uuid,'36000000-0000-0000-0000-0000000000b3'::uuid)
) as v(t,u) join public.roles r on r.code = 'employee';

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('36000000-0000-0000-0000-0000000000ad','36000000-0000-0000-0000-00000000000A','person','A Customer','+201005551111');

-- Both tenants get an SLA-overdue assigned lead. Only A's may be acted upon.
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_status_code, lead_source_code, title) values
  ('36000000-0000-0000-0000-0000000000ae','36000000-0000-0000-0000-00000000000A','36000000-0000-0000-0000-0000000000aa','36000000-0000-0000-0000-0000000000ac','36000000-0000-0000-0000-0000000000ad','assigned','manual_entry','A overdue lead'),
  ('36000000-0000-0000-0000-0000000000be','36000000-0000-0000-0000-00000000000B','36000000-0000-0000-0000-0000000000bb','36000000-0000-0000-0000-0000000000bc',null,'assigned','manual_entry','B overdue lead');
insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_at, assignment_reason, is_current) values
  ('36000000-0000-0000-0000-00000000000A','36000000-0000-0000-0000-0000000000ae','36000000-0000-0000-0000-0000000000a2', now() - interval '10 hours','initial',true),
  ('36000000-0000-0000-0000-00000000000B','36000000-0000-0000-0000-0000000000be','36000000-0000-0000-0000-0000000000b2', now() - interval '10 hours','initial',true);

-- B lapses HERE, with its data already in place -- the poison pill for the shared batch below.
update public.subscriptions set subscription_status_code = 'suspended'
 where tenant_id = '36000000-0000-0000-0000-00000000000B';

-- =============================================================================================
-- 1-4. DEFECT 1 -- app.process_lead_sla loops over leads across ALL tenants with no tenant filter
--      and writes gated tables inside the loop. Before the fix, tenant B's suspended subscription
--      raised and rolled back the ENTIRE run, so tenant A silently lost its SLA automation.
-- =============================================================================================
select lives_ok(
  $$select * from app.process_lead_sla('1 hour'::interval, '100 hours'::interval)$$,
  'process_lead_sla COMPLETES with a suspended tenant in scope -- one lapsed tenant must not abort the shared run');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'lead_sla_warning' and tenant_id = '36000000-0000-0000-0000-00000000000A'),
  1,
  '...and the HEALTHY tenant was still processed -- the positive half, without which "it did not throw" would be meaningless');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'lead_sla_warning' and tenant_id = '36000000-0000-0000-0000-00000000000B'),
  0,
  '...while the suspended tenant was skipped rather than written to');

select is(
  (select count(*)::int from public.notifications where tenant_id = '36000000-0000-0000-0000-00000000000B'),
  0,
  '...and no notification leaked into the suspended tenant either');

-- =============================================================================================
-- 5-6. DEFECT 2 -- app.map_outcomes_to_conversions inserts a batch of conversions with ONE
--      set-based statement spanning tenants. One restricted tenant's row aborted the whole INSERT,
--      and because that happens before the cursor UPDATE, the mapper stalled permanently for
--      everyone -- re-reading the same poisoned batch forever.
-- =============================================================================================
-- B is briefly reactivated to build its half of the batch. The suspended tenant's lead MUST carry a
-- click and a qualifying event, or its rows would never reach the INSERT at all and the regression
-- could not reproduce -- the test would then pass for the wrong reason.
update public.subscriptions set subscription_status_code = 'active'
 where tenant_id = '36000000-0000-0000-0000-00000000000B';

insert into public.attribution_clicks (id, tenant_id, attribution_source_code, gclid, clicked_at) values
  ('36000000-0000-0000-0000-0000000000af','36000000-0000-0000-0000-00000000000A','google_ads','GCL-A-1', now()),
  ('36000000-0000-0000-0000-0000000000bf','36000000-0000-0000-0000-00000000000B','google_ads','GCL-B-1', now());
update public.leads set attribution_click_id = '36000000-0000-0000-0000-0000000000af'
 where id = '36000000-0000-0000-0000-0000000000ae';
update public.leads set attribution_click_id = '36000000-0000-0000-0000-0000000000bf'
 where id = '36000000-0000-0000-0000-0000000000be';
select app.record_event('36000000-0000-0000-0000-00000000000A','lead_qualified','lead','36000000-0000-0000-0000-0000000000ae');
select app.record_event('36000000-0000-0000-0000-00000000000B','lead_qualified','lead','36000000-0000-0000-0000-0000000000be');

-- ...and lapses again, so the mapper meets a genuinely poisoned batch.
update public.subscriptions set subscription_status_code = 'suspended'
 where tenant_id = '36000000-0000-0000-0000-00000000000B';

select lives_ok(
  $$select app.map_outcomes_to_conversions(500)$$,
  'map_outcomes_to_conversions COMPLETES with a suspended tenant in the batch -- the n8n mapper must not stall for everyone');

select is(
  (select count(*)::int from public.offline_conversions where tenant_id = '36000000-0000-0000-0000-00000000000A'),
  1,
  '...and the healthy tenant''s conversion WAS created -- proving the batch really reached the insert');

select is(
  (select count(*)::int from public.offline_conversions where tenant_id = '36000000-0000-0000-0000-00000000000B'),
  0,
  '...while the suspended tenant produced none');

select ok(
  (select last_seq from public.integration_cursors where name = 'outcome_conversion_mapper') > 0,
  '...and the cursor ADVANCED -- the stall was the worse half of this defect, since it repeats forever');

-- =============================================================================================
-- 9. CHECK A -- the gate reads tenant_id from the ROW, so a write that CHANGES tenant_id must be
--    refused by RLS. Baseline first: the same UPDATE without the tenant change must succeed.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"36000000-0000-0000-0000-0000000000a1"}', true);
select lives_ok(
  $$update public.customers set full_name = 'Renamed Legitimately'
     where id = '36000000-0000-0000-0000-0000000000ad'$$,
  'BASELINE: a same-tenant UPDATE succeeds, so the denial below is about the tenant change and not about the fixture');

select throws_ok(
  $$update public.customers set tenant_id = '36000000-0000-0000-0000-00000000000B'
     where id = '36000000-0000-0000-0000-0000000000ad'$$,
  '42501', null,
  'a customer cannot be MOVED into another tenant -- the gate would have approved the target tenant, RLS WITH CHECK is what refuses');

select finish();
rollback;
