-- pgTAP: SPEC-152 / WP-03 -- subscription state governs business writes.
--
-- Runs as a real `authenticated` employee wherever behaviour is the subject. The defect this guards
-- was live and INVERTED, not merely absent: `read_only` permitted writes while
-- `suspended`/`expired`/`cancelled` denied reads -- the opposite of the owner's rule, which keeps
-- reads available so a lapsed tenant can still inspect and export its own data.
--
-- Both directions are asserted deliberately. A test that only proves denial would pass just as well
-- against a system that denies everything, and this repository has already been bitten by a test
-- that passed because its fixture was empty.
create extension if not exists pgtap with schema extensions;

begin;
select plan(27);

insert into auth.users (id, email) values
  ('35000000-0000-0000-0000-0000000000a1','emp@sub.test');
insert into public.tenants (id, name, slug, status) values
  ('35000000-0000-0000-0000-000000000001','Sub Travel','sub-travel','active');
insert into public.branches (id, tenant_id, name, slug) values
  ('35000000-0000-0000-0000-00000000000a','35000000-0000-0000-0000-000000000001','Cairo','cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('35000000-0000-0000-0000-0000000000c1','35000000-0000-0000-0000-000000000001','35000000-0000-0000-0000-00000000000a','sales','Cairo Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('35000000-0000-0000-0000-000000000011','35000000-0000-0000-0000-000000000001','Employee','emp@sub.test',true,'35000000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('35000000-0000-0000-0000-000000000001','35000000-0000-0000-0000-000000000011','35000000-0000-0000-0000-00000000000a','35000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '35000000-0000-0000-0000-000000000001','35000000-0000-0000-0000-000000000011'::uuid, r.id,'tenant'
from public.roles r where r.code = 'employee';

-- Pre-existing data, so the read assertions below have something to find -- without it the "reads
-- still work" tests would pass vacuously. The gate is already live at this point (it fires for every
-- role, superuser included), so the tenant must be in a writable state to seed at all. That the
-- next two statements are ORDER-DEPENDENT is itself evidence the gate is real.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '35000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'professional';

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('35000000-0000-0000-0000-0000000000d1','35000000-0000-0000-0000-000000000001','person','Existing Customer','+201004443333');

-- ---------------------------------------------------------------------------------------------
-- Helper: put the tenant into a given subscription state.
-- ---------------------------------------------------------------------------------------------
create or replace function pg_temp.set_state(p_state text) returns void
language plpgsql as $$
begin
    -- Payment proofs FK to subscriptions with ON DELETE RESTRICT, so they must go first once the
    -- exemption test above has created one.
    delete from public.subscription_payment_proofs where tenant_id = '35000000-0000-0000-0000-000000000001';
    delete from public.subscriptions where tenant_id = '35000000-0000-0000-0000-000000000001';
    if p_state is not null then
        insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
        select '35000000-0000-0000-0000-000000000001', sp.id, p_state
        from public.subscription_plans sp where sp.plan_code = 'professional';
    end if;
end;
$$;

-- =============================================================================================
-- 1-3. PERMITTED STATES -- the positive baseline.
-- =============================================================================================
select pg_temp.set_state('trial');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"35000000-0000-0000-0000-0000000000a1"}', true);
select lives_ok(
  $$select app.create_customer('person','Trial Customer', p_primary_phone => '+201001112221')$$,
  'trial: an ordinary CRM write SUCCEEDS');

reset role;
select pg_temp.set_state('active');
set local role authenticated;
select lives_ok(
  $$select app.create_customer('person','Active Customer', p_primary_phone => '+201001112222')$$,
  'active: an ordinary CRM write SUCCEEDS');

reset role;
select pg_temp.set_state('grace_period');
set local role authenticated;
select lives_ok(
  $$select app.create_customer('person','Grace Customer', p_primary_phone => '+201001112223')$$,
  'grace_period: an ordinary CRM write SUCCEEDS -- a tenant inside its grace window keeps working');

-- =============================================================================================
-- 4-7. RESTRICTED STATES -- writes denied through the RPC path.
-- =============================================================================================
reset role; select pg_temp.set_state('read_only'); set local role authenticated;
select throws_ok(
  $$select app.create_customer('person','Nope', p_primary_phone => '+201009990001')$$,
  '42501', null,
  'read_only: write DENIED -- this is the exact case plan_allows previously permitted');

reset role; select pg_temp.set_state('suspended'); set local role authenticated;
select throws_ok(
  $$select app.create_customer('person','Nope', p_primary_phone => '+201009990002')$$,
  '42501', null, 'suspended: write DENIED');

reset role; select pg_temp.set_state('expired'); set local role authenticated;
select throws_ok(
  $$select app.create_customer('person','Nope', p_primary_phone => '+201009990003')$$,
  '42501', null, 'expired: write DENIED');

reset role; select pg_temp.set_state('cancelled'); set local role authenticated;
select throws_ok(
  $$select app.create_customer('person','Nope', p_primary_phone => '+201009990004')$$,
  '42501', null, 'cancelled: write DENIED');

-- =============================================================================================
-- 8-11. THE EXPORT GUARANTEE -- reads must survive every restricted state.
--       Previously suspended/expired/cancelled were excluded from plan_allows, denying reads.
-- =============================================================================================
-- Asserted by identity rather than by count: tests 1-3 legitimately created customers of their own,
-- and an exact count here would couple this assertion to their side effects rather than to the
-- property being tested.
select is(
  (select full_name from public.customers where id = '35000000-0000-0000-0000-0000000000d1'),
  'Existing Customer',
  'cancelled: the tenant can still READ its customers -- the export guarantee');

reset role; select pg_temp.set_state('suspended'); set local role authenticated;
select isnt(
  (select count(*)::int from public.customers), 0,
  'suspended: reads still work');
select lives_ok(
  $$select count(*) from public.events$$,
  'suspended: the event stream is still readable -- the audit history is part of what a lapsed tenant may export');
select ok((select count(*) from public.catalog_values) > 0,
  'suspended: reference/catalog data still readable -- an export needs its lookups');

-- =============================================================================================
-- 12-14. DIRECT DML BYPASS -- the whole point. These tables' write policies never call
--        app.has_permission, so a gate placed there would have missed them entirely.
-- =============================================================================================
select throws_ok(
  $$insert into public.customers (tenant_id, customer_type_code, full_name, primary_phone)
    values ('35000000-0000-0000-0000-000000000001','person','Direct','+201008880001')$$,
  '42501', null,
  'suspended: DIRECT INSERT into customers DENIED -- no RPC involved');

select throws_ok(
  $$insert into public.suppliers (tenant_id, supplier_type_code, name)
    values ('35000000-0000-0000-0000-000000000001','airline','Direct Supplier')$$,
  '42501', null, 'suspended: DIRECT INSERT into suppliers DENIED');

select throws_ok(
  $$update public.customers set full_name = 'Renamed'
     where id = '35000000-0000-0000-0000-0000000000d1'$$,
  '42501', null, 'suspended: DIRECT UPDATE of an existing customer DENIED');

-- =============================================================================================
-- 15-17. EXEMPTIONS -- each a deliberate hole. A lapsed tenant must be able to get out.
-- =============================================================================================
-- The full reactivation path, not just its last row. `subscription_payment_proofs.document_id` is
-- NOT NULL with a tenant-qualified FK, so proof upload necessarily creates a `documents` row first
-- -- which is why `documents` had to join the exemption list. Testing only the proofs INSERT would
-- have hidden that.
--
-- Run as postgres deliberately: the subject here is the TRIGGER exemption, not RLS. An earlier
-- version of this block ran as the `employee` role and passed VACUOUSLY -- employee lacks
-- VIEW_SUBSCRIPTION_STATUS, so its `insert ... select ... from subscriptions` read zero rows and
-- inserted nothing, which lives_ok cannot distinguish from success. Who may upload proof is a
-- permission question covered by the permission model; what this file tests is that a suspended
-- subscription does not block the write.
reset role;
select lives_ok(
  $$insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code, is_confidential)
    values ('35000000-0000-0000-0000-0000000000e1','35000000-0000-0000-0000-000000000001',
            'other','Renewal payment proof','active', false)$$,
  'suspended: the document the proof hangs on CAN be created');

select lives_ok(
  $$insert into public.subscription_payment_proofs (tenant_id, subscription_id, document_id, uploaded_by, status_code)
    select '35000000-0000-0000-0000-000000000001', s.id,
           '35000000-0000-0000-0000-0000000000e1','35000000-0000-0000-0000-000000000011','pending'
      from public.subscriptions s
     where s.tenant_id = '35000000-0000-0000-0000-000000000001'$$,
  'suspended: the tenant CAN still upload a payment proof -- canon 28, and the only way back');

-- Guards the vacuity directly: the row must actually exist, not merely have not thrown.
select is(
  (select count(*)::int from public.subscription_payment_proofs
    where tenant_id = '35000000-0000-0000-0000-000000000001'),
  1,
  '...and the proof row is really there -- asserted because the previous version of this test passed on zero rows');

reset role;
select lives_ok(
  $$insert into public.events (tenant_id, event_type_code, severity_code, entity_type, entity_id)
    values ('35000000-0000-0000-0000-000000000001','customer_created','info','customer','35000000-0000-0000-0000-0000000000d1')$$,
  'suspended: the audit spine still records -- history must not stop because billing did');

select lives_ok(
  $$insert into public.users (tenant_id, full_name, email, is_active)
    values ('35000000-0000-0000-0000-000000000001','Admin Added','added@sub.test',true)$$,
  'suspended: identity administration still works -- provision_tenant writes users before any subscription exists');

-- =============================================================================================
-- 18. MISSING SUBSCRIPTION -- must fail CLOSED for writes, never silently grant them.
-- =============================================================================================
select pg_temp.set_state(null);
set local role authenticated;
select throws_ok(
  $$select app.create_customer('person','No Sub', p_primary_phone => '+201007770001')$$,
  '42501', null,
  'NO subscription row: writes DENIED -- previously plan_allows'' coalesce(...,true) failed OPEN here');
select is(
  (select full_name from public.customers where id = '35000000-0000-0000-0000-0000000000d1'),
  'Existing Customer',
  '...while reads still work, so a tenant awaiting provisioning is not locked out of its own data');

-- =============================================================================================
-- 19-20. COVERAGE -- what keeps the generated attachment honest in both directions.
-- =============================================================================================
reset role;
select is(
  (select count(*)::int
     from information_schema.columns c
     join information_schema.tables t
       on t.table_schema = c.table_schema and t.table_name = c.table_name and t.table_type = 'BASE TABLE'
    where c.table_schema = 'public' and c.column_name = 'tenant_id'
      and c.table_name <> all (array['subscriptions','subscription_payment_proofs','events','security_events',
                                     'notification_deliveries','usage_counters','offline_conversion_deliveries',
                                     'documents','document_versions','document_links',
                                     'users','user_role_assignments','user_branch_assignments','branches','departments'])
      and not exists (
        select 1 from pg_trigger tg join pg_class pc on pc.oid = tg.tgrelid
         where pc.relname = c.table_name and not tg.tgisinternal
           and tg.tgname = c.table_name || '_enforce_subscription_write_gate')),
  0,
  'EVERY non-exempt tenant-scoped table carries the gate -- a table added later without one fails here');

select is(
  (select count(*)::int from pg_trigger tg join pg_class pc on pc.oid = tg.tgrelid
    where not tg.tgisinternal
      and tg.tgname like '%\_enforce\_subscription\_write\_gate'
      and pc.relname = any (array['subscriptions','subscription_payment_proofs','events','security_events',
                                  'notification_deliveries','usage_counters','offline_conversion_deliveries',
                                     'documents','document_versions','document_links',
                                  'users','user_role_assignments','user_branch_assignments','branches','departments'])),
  0,
  '...and NO exempt table carries it -- the exemptions stay narrow rather than drifting wider');

-- =============================================================================================
-- 24. PROVISIONING must survive the fail-closed rule. `app.provision_tenant` writes `users` and
--     `user_role_assignments` BEFORE any subscription exists, so if those tables were gated a
--     brand-new tenant would be born unusable -- and the still-open trial-plan business decision
--     would have become a hard blocker. This assertion is what stops a later session from
--     "tightening" the exemption list and silently breaking tenant creation.
-- =============================================================================================
--     SPEC-157 UPDATE: this assertion used to end with "...even though it has no subscription yet",
--     which faithfully recorded a DEFECT. `app.subscription_allows_write` returns FALSE when no
--     subscription row exists, so a tenant provisioned that way could create branches and users
--     (exempt tables) and then not a single customer, lead, booking or payment. Provisioning now
--     creates the 30-day trial subscription in the same transaction, and assertions 25-27 below are
--     the positive controls that prove it -- the denial half above is only meaningful because a
--     brand-new tenant demonstrably CAN write.
--
--     The session is cleared first because that is how this function is really called: it is granted
--     to `service_role` alone, which carries no `auth.uid()`. WP-00 pins a session-ful caller's
--     events to that caller's own tenant, so emitting `subscription_created` for a NEW tenant is
--     only legitimate from the session-less platform path -- which is exactly the WP-00 rule doing
--     its job, not an obstacle to work around.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select lives_ok(
  $$select app.provision_tenant('Gate Test Agency','gate-test-agency','owner@gate.test','Gate Owner')$$,
  'a brand-new tenant provisions cleanly, session-less, exactly as service_role calls it');

select ok(
  app.subscription_allows_write((select id from public.tenants where slug = 'gate-test-agency')),
  'SPEC-157: ...and it may WRITE on day one -- this returned FALSE before provisioning created a subscription');

select is(
  (select (trial_ends_at::date - trial_started_at::date) from public.tenants where slug = 'gate-test-agency'),
  30,
  '...on a 30-day trial stamped on the TENANT, so it survives every later subscription row');

select lives_ok(
  $$insert into public.customers (tenant_id, customer_type_code, full_name, primary_phone)
    select id, 'person', 'Day One Customer', '+201009990000'
      from public.tenants where slug = 'gate-test-agency'$$,
  '...and the gate itself passes the first real business row -- proven end to end, not inferred');

select finish();
rollback;
