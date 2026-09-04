-- pgTAP: SUP-4b -- the credit ceiling WARNS and never refuses (owner decision 2026-09-04).
--
-- WHAT MUST BE TRUE, and the first three are the ones that would make this feature a defect rather
-- than a feature if they failed:
--   * a write that pushes exposure ABOVE the ceiling still SUCCEEDS -- the owner was explicit that
--     nothing may be blocked, so every "it alerted" assertion below is worthless unless the write
--     that triggered it also landed;
--   * the alert fires ONCE per breach, not once per write and not once per read;
--   * a supplier that falls back below and breaches again alerts AGAIN -- the reason the `cleared`
--     event exists at all.
--
-- The alert is proven by its EFFECTS (event row + one notification per recipient + a pending email
-- delivery row), never by "the function did not throw".
create extension if not exists pgtap with schema extensions;

begin;
select plan(23);

insert into auth.users (id, email, email_confirmed_at) values
  ('93000000-0000-0000-0000-0000000000a1','owner@sup93.test',   now()),
  ('93000000-0000-0000-0000-0000000000a2','finance@sup93.test', now()),
  ('93000000-0000-0000-0000-0000000000a3','emp@sup93.test',     now());
insert into public.tenants (id, name, slug, status) values
  ('93000000-0000-0000-0000-000000000001','Sup93 Travel','sup93','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id='93000000-0000-0000-0000-000000000001';
insert into public.branches (id, tenant_id, name, slug) values
  ('93000000-0000-0000-0000-00000000000a','93000000-0000-0000-0000-000000000001','HQ','sup93-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('93000000-0000-0000-0000-0000000000c1','93000000-0000-0000-0000-000000000001',
   '93000000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('93000000-0000-0000-0000-000000000011','93000000-0000-0000-0000-000000000001','Owner','owner@sup93.test',true,'93000000-0000-0000-0000-0000000000a1'),
  ('93000000-0000-0000-0000-000000000012','93000000-0000-0000-0000-000000000001','Finance','finance@sup93.test',true,'93000000-0000-0000-0000-0000000000a2'),
  ('93000000-0000-0000-0000-000000000013','93000000-0000-0000-0000-000000000001','Emp','emp@sup93.test',true,'93000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '93000000-0000-0000-0000-000000000001', u,
       '93000000-0000-0000-0000-00000000000a','93000000-0000-0000-0000-0000000000c1', true
from unnest(array['93000000-0000-0000-0000-000000000011'::uuid,
                  '93000000-0000-0000-0000-000000000012'::uuid,
                  '93000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '93000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('93000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('93000000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('93000000-0000-0000-0000-000000000013'::uuid,'employee')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('93000000-0000-0000-0000-0000000000d1','93000000-0000-0000-0000-000000000001','person','Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id) values
  ('93000000-0000-0000-0000-0000000000b1','93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-00000000000a','93000000-0000-0000-0000-0000000000c1','93000000-0000-0000-0000-0000000000d1','confirmed','Trip','BR-SUP93-1','93000000-0000-0000-0000-000000000011');

-- The ceiling under test. 1000 EGP rather than 100,000: the THRESHOLD VALUE is configuration the
-- owner sets per supplier through MANAGE_SUPPLIER_CREDIT, and a test that hard-coded the production
-- number would be pinning a business value as if it were a rule. What is under test is the crossing.
-- A second supplier carries NO ceiling, which is the control for "NULL means no ceiling".
insert into public.suppliers (id, tenant_id, name, supplier_type_code, credit_limit_amount, credit_limit_currency_code) values
  ('93000000-0000-0000-0000-0000000000e1','93000000-0000-0000-0000-000000000001','Capped Air','airline', 1000, 'EGP'),
  ('93000000-0000-0000-0000-0000000000e2','93000000-0000-0000-0000-000000000001','Uncapped Air','airline', null, null);

-- =============================================================================================
-- 1-3. THE STRUCTURE, AND THAT THE INTERNAL HELPER IS NOT A SECOND READ DOOR.
-- =============================================================================================
select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid=t.tgrelid
     join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
    where not t.tgisinternal
      and t.tgname in ('booking_items_probe_supplier_credit','payments_probe_supplier_credit')
      and t.tgtype & 1 = 1),
  2,
  'SUP-4b: both exposure-bearing tables carry an AFTER-row probe -- exposure is a function of exactly these two');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='app' and p.proname='supplier_exposure_in_limit_currency'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  0,
  'the ungated system-path exposure helper is NOT executable by authenticated -- SUP-1 withheld this figure and a second read door would hand it back');

select is(
  (select count(*)::int from public.catalog_values
    where catalog_type_code='event_type' and code in ('supplier_credit_threshold_exceeded','supplier_credit_threshold_cleared')),
  2,
  'both threshold event types are registered -- app.record_event refuses an unregistered code, so an unregistered one would fail closed');

-- =============================================================================================
-- 4-6. BELOW THE CEILING: the write lands, and NOTHING is announced.
-- =============================================================================================
insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code, cost_locked_at) values
  ('93000000-0000-0000-0000-0000000000f1','93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-0000000000b1','93000000-0000-0000-0000-0000000000e1','flight_ticket','EGP',400,500,'confirmed', now());

select is(
  (select count(*)::int from public.booking_items where id='93000000-0000-0000-0000-0000000000f1'),
  1,
  'CONTROL: the below-threshold write landed -- so the silence below is silence about a real row');

select is(
  app.supplier_exposure_in_limit_currency('93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-0000000000e1','EGP'),
  400::numeric,
  'exposure is the locked cost, computed exactly as app.supplier_balance defines it');

select is(
  (select count(*)::int from public.events
    where entity_id='93000000-0000-0000-0000-0000000000e1' and event_type_code like 'supplier_credit_threshold%'),
  0,
  'BELOW THRESHOLD: no threshold event -- 400 against a ceiling of 1000 says nothing');

-- =============================================================================================
-- 7-9. AT THE CEILING EXACTLY. `>` not `>=`: a supplier exactly at its ceiling has not exceeded it.
-- =============================================================================================
insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code, cost_locked_at) values
  ('93000000-0000-0000-0000-0000000000f2','93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-0000000000b1','93000000-0000-0000-0000-0000000000e1','hotel','EGP',600,700,'confirmed', now());

select is(
  (select count(*)::int from public.booking_items where id='93000000-0000-0000-0000-0000000000f2'),
  1,
  'AT THRESHOLD: the write is NOT blocked');

select is(
  app.supplier_exposure_in_limit_currency('93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-0000000000e1','EGP'),
  1000::numeric,
  '...and exposure now equals the ceiling exactly');

select is(
  (select count(*)::int from public.events
    where entity_id='93000000-0000-0000-0000-0000000000e1' and event_type_code='supplier_credit_threshold_exceeded'),
  0,
  'AT THRESHOLD: still no alert -- the ceiling is EXCEEDED only above it, not at it');

-- =============================================================================================
-- 10-16. ABOVE THE CEILING. The write must succeed AND the alert must exist, with recipients.
-- =============================================================================================
insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code, cost_locked_at) values
  ('93000000-0000-0000-0000-0000000000f3','93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-0000000000b1','93000000-0000-0000-0000-0000000000e1','visa','EGP',500,600,'confirmed', now());

select is(
  (select count(*)::int from public.booking_items where id='93000000-0000-0000-0000-0000000000f3'),
  1,
  'ABOVE THRESHOLD: THE WRITE STILL LANDS -- the owner decision is WARN, not REFUSE, and this is the assertion that proves it');

select is(
  app.supplier_exposure_in_limit_currency('93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-0000000000e1','EGP'),
  1500::numeric,
  '...and exposure is now 1500 against a ceiling of 1000');

select is(
  (select count(*)::int from public.events
    where entity_id='93000000-0000-0000-0000-0000000000e1' and event_type_code='supplier_credit_threshold_exceeded'),
  1,
  'ALERT: exactly one threshold event was recorded -- auditable on the same spine as every other business event');

select is(
  (select (payload->>'exposure')::numeric from public.events
    where entity_id='93000000-0000-0000-0000-0000000000e1' and event_type_code='supplier_credit_threshold_exceeded'),
  1500::numeric,
  '...and its payload carries the measured exposure, not a restated constant');

select is(
  (select payload->>'enforcement' from public.events
    where entity_id='93000000-0000-0000-0000-0000000000e1' and event_type_code='supplier_credit_threshold_exceeded'),
  'warning_only',
  '...and records that this is warning-only, so a later reader cannot mistake it for a refusal');

select set_eq(
  $$select target_user_id from public.notifications
     where related_entity_id='93000000-0000-0000-0000-0000000000e1'
       and notification_type_code='supplier_balance'$$,
  $$values ('93000000-0000-0000-0000-000000000011'::uuid),
         ('93000000-0000-0000-0000-000000000012'::uuid)$$,
  'RECIPIENTS: exactly the Company Owner and the Finance Manager -- measured as a SET, so the employee being absent is proven rather than hoped');

select ok(
  (select body like '%Capped Air%' and body like '%1500%' and body like '%1000%'
     from public.notifications
    where related_entity_id='93000000-0000-0000-0000-0000000000e1'
      and target_user_id='93000000-0000-0000-0000-000000000011'),
  'CONTENT: the notification names the supplier, the exposure and the ceiling');

-- =============================================================================================
-- 17-18. THE EMAIL DELIVERY BOUNDARY, ASSERTED HONESTLY.
--        ORVION has no email provider. The obligation is recorded as `pending` on the existing
--        delivery ledger; this asserts the CONTRACT exists, and deliberately does NOT assert that
--        anything was sent, because nothing was.
-- =============================================================================================
select is(
  (select count(*)::int from public.notification_deliveries nd
     join public.notifications n on n.id = nd.notification_id
    where n.related_entity_id='93000000-0000-0000-0000-0000000000e1'
      and nd.channel_code='email'),
  2,
  'EMAIL CONTRACT: one email delivery row per recipient exists on the canonical delivery ledger');

select is(
  (select distinct nd.delivery_status_code from public.notification_deliveries nd
     join public.notifications n on n.id = nd.notification_id
    where n.related_entity_id='93000000-0000-0000-0000-0000000000e1' and nd.channel_code='email'),
  'pending',
  '...and every one is PENDING, not sent -- no dispatcher exists in ORVION and this test refuses to pretend one does');

-- =============================================================================================
-- 19-20. IDEMPOTENCY. Another write above the ceiling, and repeated reads, must add nothing.
-- =============================================================================================
insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code, cost_locked_at) values
  ('93000000-0000-0000-0000-0000000000f4','93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-0000000000b1','93000000-0000-0000-0000-0000000000e1','transport','EGP',300,400,'confirmed', now());

select is(
  (select count(*)::int from (
     select app.supplier_exposure_in_limit_currency('93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-0000000000e1','EGP')
     from generate_series(1,3)) s),
  3,
  'CONTROL: exposure was read three more times, so the next assertion measures reads as well as writes');

select is(
  (select count(*)::int from public.notifications
    where related_entity_id='93000000-0000-0000-0000-0000000000e1' and notification_type_code='supplier_balance'),
  2,
  'NO DUPLICATE ALERTS: a further over-ceiling write and three reads later, still exactly two notifications -- the event ledger is the idempotency key');

-- =============================================================================================
-- 21-22. THE CLEAR/RE-BREACH CYCLE -- why `cleared` exists. A payment brings the supplier back
--        under, and a later cost pushes it over again; that second breach MUST alert.
-- =============================================================================================
insert into public.payments (id, tenant_id, booking_id, supplier_id, payment_direction_code, payment_method_code, currency_code, amount, paid_at) values
  ('93000000-0000-0000-0000-00000000a001','93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-0000000000b1','93000000-0000-0000-0000-0000000000e1','supplier_payment','bank_transfer','EGP',1500, now());

select is(
  (select count(*)::int from public.events
    where entity_id='93000000-0000-0000-0000-0000000000e1' and event_type_code='supplier_credit_threshold_cleared'),
  1,
  'CLEARED: paying the supplier down below the ceiling records the clearing event -- without it the supplier would never alert again');

insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code, cost_locked_at) values
  ('93000000-0000-0000-0000-0000000000f5','93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-0000000000b1','93000000-0000-0000-0000-0000000000e1','tour_package','EGP',900,1000,'confirmed', now());

select is(
  (select count(*)::int from public.events
    where entity_id='93000000-0000-0000-0000-0000000000e1' and event_type_code='supplier_credit_threshold_exceeded'),
  2,
  'RE-BREACH ALERTS AGAIN: crossing back over after a clear produces a SECOND alert -- the pair is what makes the idempotency above a suppression rather than a mute');

-- =============================================================================================
-- 23. NULL CEILING MEANS NO CEILING. The uncapped supplier carries far more exposure than the
--     capped one ever did and must stay silent -- otherwise "no ceiling" would quietly become
--     "a ceiling of zero", which is the opposite of the recorded semantics.
-- =============================================================================================
insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code, cost_locked_at) values
  ('93000000-0000-0000-0000-0000000000f6','93000000-0000-0000-0000-000000000001','93000000-0000-0000-0000-0000000000b1','93000000-0000-0000-0000-0000000000e2','flight_ticket','EGP',999999,999999,'confirmed', now());

select is(
  (select count(*)::int from public.events
    where entity_id='93000000-0000-0000-0000-0000000000e2' and event_type_code like 'supplier_credit_threshold%'),
  0,
  'NULL CEILING: a supplier with no ceiling carrying 999,999 EGP of exposure produces no alert -- no ceiling is not a ceiling of zero');

select * from finish();
rollback;
