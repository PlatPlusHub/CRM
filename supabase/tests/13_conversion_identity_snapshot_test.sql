-- pgTAP invariants: the identity delivered for an offline conversion is HISTORICAL TRUTH, fixed at
-- conversion-creation time, and is never re-derived from the live customer record. Discovery-to-
-- guard for ATTR-1 (SPEC-128).
--
-- Before the fix, app.claim_conversion_deliveries ended with
--     left join public.leads l on l.id = oc.lead_id
--     left join public.customers cu on cu.id = l.customer_id
-- so a customer who corrected their email after the conversion silently rewrote the identity of a
-- past business event, and a retry could send different user data than the first attempt for the
-- same transactionId. Both are asserted against below, behaviourally.
--
-- The retry assertion is the one that matters most for Google: at-least-once delivery is only safe
-- if every attempt for a given transactionId carries identical identity.
create extension if not exists pgtap with schema extensions;

begin;
select plan(9);

-- ---------------------------------------------------------------------------------------------
-- Fixture: two tenants, so isolation can be asserted rather than assumed.
-- ---------------------------------------------------------------------------------------------
insert into public.tenants (id, name, slug, status) values
  ('cccccccc-0000-0000-0000-00000000000a','Snap Tenant A','snap-a','active'),
  ('cccccccc-0000-0000-0000-00000000000b','Snap Tenant B','snap-b','active');

insert into public.branches (id, tenant_id, name, slug) values
  ('cccccccc-0000-0000-0000-0000000000b1','cccccccc-0000-0000-0000-00000000000a','BR','snap-br');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('cccccccc-0000-0000-0000-0000000000d1','cccccccc-0000-0000-0000-00000000000a','cccccccc-0000-0000-0000-0000000000b1','sales','DP');

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_email, primary_phone) values
  ('cccccccc-0000-0000-0000-0000000000c1','cccccccc-0000-0000-0000-00000000000a','person','Ahmed','ahmed@example.com','+201234567890');

insert into public.attribution_clicks (id, tenant_id, attribution_source_code, gclid, consent_ad_user_data, consent_ad_personalization) values
  ('cccccccc-0000-0000-0000-0000000000e1','cccccccc-0000-0000-0000-00000000000a','google_ads','GCLID-SNAP-1','granted','granted'),
  ('cccccccc-0000-0000-0000-0000000000e2','cccccccc-0000-0000-0000-00000000000a','google_ads','GCLID-SNAP-2','granted','granted');

insert into public.leads (id, tenant_id, branch_id, department_id, lead_source_code, lead_status_code, title, customer_id, attribution_click_id) values
  ('cccccccc-0000-0000-0000-0000000000f1','cccccccc-0000-0000-0000-00000000000a','cccccccc-0000-0000-0000-0000000000b1','cccccccc-0000-0000-0000-0000000000d1','google_ads_form','qualified','L1','cccccccc-0000-0000-0000-0000000000c1','cccccccc-0000-0000-0000-0000000000e1');

-- Conversion WITH identity, snapshotted exactly as both creation paths do.
insert into public.offline_conversions
  (id, tenant_id, lead_id, attribution_click_id, conversion_event_type_code, conversion_at,
   customer_id, customer_email, customer_phone)
values
  ('cccccccc-0000-0000-0000-00000000a001','cccccccc-0000-0000-0000-00000000000a',
   'cccccccc-0000-0000-0000-0000000000f1','cccccccc-0000-0000-0000-0000000000e1',
   'qualified_lead', now() - interval '1 hour',
   'cccccccc-0000-0000-0000-0000000000c1','ahmed@example.com','+201234567890');

-- ---------------------------------------------------------------------------------------------
-- 1. THE CUSTOMER CHANGES AFTER THE CONVERSION. This is the defect, reproduced as an assertion.
-- ---------------------------------------------------------------------------------------------
update public.customers
   set primary_email = 'ahmed.new@example.com', primary_phone = '+209999999999'
 where id = 'cccccccc-0000-0000-0000-0000000000c1';

select is(
  (select customer_email from app.claim_conversion_deliveries('google_ads', 10)
    where conversion_id = 'cccccccc-0000-0000-0000-00000000a001'),
  'ahmed@example.com',
  'the delivered email is the value that was true at conversion time, not the customer''s current email');

select is(
  (select customer_phone from public.offline_conversions where id = 'cccccccc-0000-0000-0000-00000000a001'),
  '+201234567890',
  'the stored snapshot is unaffected by the customer edit');

select isnt(
  (select primary_email from public.customers where id = 'cccccccc-0000-0000-0000-0000000000c1'),
  (select customer_email from public.offline_conversions where id = 'cccccccc-0000-0000-0000-00000000a001'),
  'the live customer and the historical snapshot have genuinely diverged (the test is meaningful)');

-- ---------------------------------------------------------------------------------------------
-- 2. RETRY STABILITY. Fail the attempt, re-claim, and require identical identity -- at-least-once
--    delivery is only safe for Google if every attempt for one transactionId carries the same
--    user data.
-- ---------------------------------------------------------------------------------------------
update public.offline_conversion_deliveries
   set delivery_status_code = 'failed', error_message = 'simulated failure'
 where offline_conversion_id = 'cccccccc-0000-0000-0000-00000000a001';

select is(
  (select customer_email from app.claim_conversion_deliveries('google_ads', 10)
    where conversion_id = 'cccccccc-0000-0000-0000-00000000a001'),
  'ahmed@example.com',
  'a RETRY delivers the same identity as the first attempt');

select is(
  (select max(attempt_number) from public.offline_conversion_deliveries
    where offline_conversion_id = 'cccccccc-0000-0000-0000-00000000a001'),
  2,
  'the retry really was a second attempt (the previous assertion is not trivially true)');

-- ---------------------------------------------------------------------------------------------
-- 3. NULL / optional identity. A lead not yet linked to a customer still produces a deliverable
--    conversion -- click-ID-only matching is valid and must not be withheld.
-- ---------------------------------------------------------------------------------------------
insert into public.leads (id, tenant_id, branch_id, department_id, lead_source_code, lead_status_code, title, attribution_click_id) values
  ('cccccccc-0000-0000-0000-0000000000f2','cccccccc-0000-0000-0000-00000000000a','cccccccc-0000-0000-0000-0000000000b1','cccccccc-0000-0000-0000-0000000000d1','google_ads_form','qualified','L2','cccccccc-0000-0000-0000-0000000000e2');
insert into public.offline_conversions
  (id, tenant_id, lead_id, attribution_click_id, conversion_event_type_code, conversion_at)
values
  ('cccccccc-0000-0000-0000-00000000a002','cccccccc-0000-0000-0000-00000000000a',
   'cccccccc-0000-0000-0000-0000000000f2','cccccccc-0000-0000-0000-0000000000e2',
   'qualified_lead', now() - interval '30 minutes');

select is(
  (select count(*)::int from app.claim_conversion_deliveries('google_ads', 10)
    where conversion_id = 'cccccccc-0000-0000-0000-00000000a002'
      and customer_email is null and customer_phone is null and gclid = 'GCLID-SNAP-2'),
  1,
  'a conversion with no customer identity is still delivered, on its click ID alone');

-- ---------------------------------------------------------------------------------------------
-- 4. Tenant isolation of the snapshot relationship.
-- ---------------------------------------------------------------------------------------------
select throws_ok(
  $$insert into public.offline_conversions (tenant_id, conversion_event_type_code, customer_id)
    values ('cccccccc-0000-0000-0000-00000000000b','qualified_lead','cccccccc-0000-0000-0000-0000000000c1')$$,
  null, null,
  'a conversion cannot be created in tenant B snapshotting tenant A''s customer without violating a constraint')
  ;

-- ---------------------------------------------------------------------------------------------
-- 5. The snapshot must be canonical, for the same reason the source is (SPEC-126): an identity
--    differing only in casing is a different identity to Google's matcher.
-- ---------------------------------------------------------------------------------------------
select throws_ok(
  $$insert into public.offline_conversions (tenant_id, conversion_event_type_code, customer_email)
    values ('cccccccc-0000-0000-0000-00000000000a','qualified_lead','Ahmed@Gmail.com')$$,
  '23514', null,
  'a non-normalized email snapshot is refused');

select throws_ok(
  $$insert into public.offline_conversions (tenant_id, conversion_event_type_code, customer_phone)
    values ('cccccccc-0000-0000-0000-00000000000a','qualified_lead','+20 123 456')$$,
  '23514', null,
  'a phone snapshot containing formatting characters is refused');

select * from finish();
rollback;
