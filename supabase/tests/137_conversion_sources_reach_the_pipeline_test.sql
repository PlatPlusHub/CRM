-- ATTACK-CLASSES: BUSINESS DOOR STATE INPUT REPLAY PRIVILEGE=N/A TENANT=N/A AUTH=N/A CONCURRENCY=N/A OBSERVABILITY=N/A
-- SPEC-233. ORVION's four live Google Ads conversion actions, each driven from its SANCTIONED business
-- path rather than a hand-inserted event: a lead qualified through `app.advance_lead`, a booking made
-- through `app.create_booking`, invoiced, paid through `app.record_payment` and issued through
-- `app.advance_booking`, then the real mapper and the real claim. CONV-7: `app.record_payment` pays an
-- invoice and leaves `payments.booking_id` NULL, and the mapper found a payment's lead only through
-- that column, so `payment_received` -- the one conversion that carries revenue -- never fired on the
-- sanctioned path. `20260928140000` follows the invoice named by the event instead. A mutation installs
-- the pre-repair resolution in a savepoint and watches `payment_received` vanish.
-- CONV-8: a handler's direct qualification and an employee's direct booking emitted no source event,
-- so they produced no conversion; assertions 15-16 pinned that and were written to FAIL on repair.
-- `20260928160000` gave each event a trigger as its single producer, and 15-16 now assert the
-- repaired behaviour; the door parity itself is `139_...`'s.
-- PRIVILEGE=N/A: each RPC's capability is its own surface's test; this file proves the pipeline.
-- TENANT=N/A: conversion provenance across tenants is CONV-6's (`119_...`).
-- AUTH=N/A: step-up belongs to each RPC and is unchanged.
-- CONCURRENCY=N/A: the mapper serialises on its cursor row (`for update`); nothing here changes it.
-- OBSERVABILITY=N/A: the silent drop is asserted as BUSINESS; delivery health is PH8-2/DELIV-1.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into auth.users (id,email,email_confirmed_at) values
  ('13700000-0000-0000-0000-0000000000a1','own@cv137.test',now()),
  ('13700000-0000-0000-0000-0000000000a2','emp@cv137.test',now());
insert into public.tenants (id,name,slug,status) values
  ('13700000-0000-0000-0000-000000000001','CV137 Travel','cv137-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '13700000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('13700000-0000-0000-0000-00000000000a','13700000-0000-0000-0000-000000000001','Cairo','cv137-cairo');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('13700000-0000-0000-0000-0000000000c1','13700000-0000-0000-0000-000000000001','13700000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('13700000-0000-0000-0000-000000000011','13700000-0000-0000-0000-000000000001','Owner','own@cv137.test',true,'13700000-0000-0000-0000-0000000000a1'),
  ('13700000-0000-0000-0000-000000000012','13700000-0000-0000-0000-000000000001','Handler','emp@cv137.test',true,'13700000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary)
select '13700000-0000-0000-0000-000000000001', u, '13700000-0000-0000-0000-00000000000a','13700000-0000-0000-0000-0000000000c1', true
from unnest(array['13700000-0000-0000-0000-000000000011'::uuid,'13700000-0000-0000-0000-000000000012'::uuid]) u;
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '13700000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('13700000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('13700000-0000-0000-0000-000000000012','employee')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id,tenant_id,customer_type_code,full_name,primary_phone,primary_email) values
  ('13700000-0000-0000-0000-0000000000d1','13700000-0000-0000-0000-000000000001','person','Buyer','+201000000137','buyer@cv137.test');
insert into public.leads (id,tenant_id,branch_id,department_id,customer_id,lead_source_code,title,lead_status_code)
select ('13700000-0000-0000-0000-0000000000e'||n)::uuid, '13700000-0000-0000-0000-000000000001',
       '13700000-0000-0000-0000-00000000000a','13700000-0000-0000-0000-0000000000c1',
       '13700000-0000-0000-0000-0000000000d1','google_ads_form','L'||n,'new'
from generate_series(1,6) n;
-- The capture path the integration uses. L3 has no click; L4's click carries denied consent.
select app.capture_attribution_click('13700000-0000-0000-0000-000000000001','google_ads','GCLID-137-'||n,
         null,null,null,null,null,null,null,null,null,null,
         case when n = 4 then 'denied' else 'granted' end, case when n = 4 then 'denied' else 'granted' end,
         null, ('13700000-0000-0000-0000-0000000000e'||n)::uuid)
from generate_series(1,6) n where n <> 3;

create temp table s137 (k text primary key, v text) on commit drop;
insert into s137 values ('mapper', (select md5(pg_get_functiondef('app.map_outcomes_to_conversions(integer)'::regprocedure))));
grant select, insert on s137 to authenticated;

-- The owner hands every lead to the handler, then works L1-L4 through the sanctioned RPCs.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13700000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select app.assign_lead(('13700000-0000-0000-0000-0000000000e'||n)::uuid, '13700000-0000-0000-0000-000000000012', 'fixture')
from generate_series(1,6) n;
select app.record_lead_interaction(('13700000-0000-0000-0000-0000000000e'||n)::uuid, 'phone_call') from generate_series(1,4) n;
select app.advance_lead(('13700000-0000-0000-0000-0000000000e'||n)::uuid, 'qualified') from unnest(array[1,3,4]) n;
insert into s137 select 'bk', app.create_booking(p_customer_id=>'13700000-0000-0000-0000-0000000000d1',
                                               p_lead_id=>'13700000-0000-0000-0000-0000000000e2', p_title=>'Cairo trip')::text;
insert into s137 select 'inv', app.create_invoice('13700000-0000-0000-0000-0000000000d1','EGP',5000,(select v from s137 where k='bk')::uuid)::text;
select app.issue_invoice((select v from s137 where k='inv')::uuid);
insert into s137 select 'pay', app.record_payment((select v from s137 where k='inv')::uuid, 5000, 'cash')::text;
-- PAY-3: `payment_recorded` is recorded at COMMIT by a deferred trigger, once the allocation naming the
-- invoice exists. This file rolls back, so it fires the pending event here, in the payer's session.
set constraints payments_emit_recorded immediate;
set constraints payments_emit_recorded deferred;
select app.advance_booking((select v from s137 where k='bk')::uuid, 'pending_approval');
select app.advance_booking((select v from s137 where k='bk')::uuid, 'confirmed');
select app.advance_booking((select v from s137 where k='bk')::uuid, 'in_progress');
select app.advance_booking((select v from s137 where k='bk')::uuid, 'issued');

-- The handler reaches the same two outcomes through the table door (CONV-8).
select set_config('request.jwt.claims','{"sub":"13700000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select app.record_lead_interaction('13700000-0000-0000-0000-0000000000e5', 'phone_call');
update public.leads set lead_status_code = 'qualified' where id = '13700000-0000-0000-0000-0000000000e5';
insert into public.bookings (tenant_id,branch_id,department_id,customer_id,lead_id,booking_status_code,title,booking_reference)
values ('13700000-0000-0000-0000-000000000001','13700000-0000-0000-0000-00000000000a','13700000-0000-0000-0000-0000000000c1',
        '13700000-0000-0000-0000-0000000000d1','13700000-0000-0000-0000-0000000000e6','draft','Door booking','CV137-DOOR');
reset role;
select set_config('request.jwt.claims','',true);

-- ================================================================================================
-- 1-3. The population, and the premise the defect rests on.
-- ================================================================================================
select is((select array_agg(l.title || ':' || coalesce(ac.consent_ad_user_data, 'none') order by l.title)
             from public.leads l left join public.attribution_clicks ac on ac.id = l.attribution_click_id
            where l.tenant_id = '13700000-0000-0000-0000-000000000001'),
  array['L1:granted','L2:granted','L3:none','L4:denied','L5:granted','L6:granted'],
  'CONTROL: every lead carries a first-touch Google Ads click except L3, and L4''s consent is denied');
select is((select array_agg(c order by t) from (select e.event_type_code t, count(*)::int c from public.events e
            where e.tenant_id = '13700000-0000-0000-0000-000000000001'
              and e.event_type_code in ('booking_created','booking_issued','lead_qualified','payment_recorded')
            group by 1) x),
  array[2, 1, 4, 1],
  'CONTROL: the sanctioned paths emitted booking_created, booking_issued, three lead_qualified and payment_recorded -- and the table door one more booking_created and lead_qualified (CONV-8)');
select is((select booking_id from public.payments where id = (select v from s137 where k='pay')::uuid), null,
  'CONTROL: app.record_payment pays the invoice and leaves payments.booking_id NULL -- the premise of CONV-7');

-- ================================================================================================
-- 4-6. Mutation: the pre-repair resolution (payments.booking_id only) in a savepoint.
-- ================================================================================================
savepoint m1;
create or replace function app.map_outcomes_to_conversions(p_batch integer default 500)
returns integer language plpgsql security definer set search_path = '' as $fn$
declare v_n integer;
begin
    insert into public.offline_conversions
        (tenant_id, lead_id, booking_id, payment_id, attribution_click_id, conversion_event_type_code,
         conversion_value, currency_code, conversion_at, source_event_seq, customer_id, customer_email, customer_phone)
    select r.tenant_id, l.id, r.booking_id, r.payment_id, l.attribution_click_id, r.conversion_type,
           r.conv_value, r.conv_ccy, r.created_at, r.seq, cu.id, cu.primary_email, cu.primary_phone
    from (
        select b.seq, b.tenant_id, b.created_at,
               case b.event_type_code when 'lead_qualified' then 'qualified_lead' when 'booking_created' then 'booking_created'
                    when 'payment_recorded' then 'payment_received' when 'booking_issued' then 'ticket_issued' end as conversion_type,
               coalesce(case when b.event_type_code = 'lead_qualified' then b.entity_id end,
                        case when b.event_type_code = 'booking_created' then (b.payload ->> 'lead_id')::uuid end,
                        case when b.event_type_code = 'booking_issued' then bk.lead_id end,
                        case when b.event_type_code = 'payment_recorded' then pbk.lead_id end) as lead_id,
               case when b.event_type_code = 'payment_recorded' then p.id end as payment_id,
               case when b.event_type_code in ('booking_created','booking_issued') then b.entity_id
                    when b.event_type_code = 'payment_recorded' then p.booking_id end as booking_id,
               case when b.event_type_code = 'payment_recorded' then p.amount end as conv_value,
               case when b.event_type_code = 'payment_recorded' then p.currency_code end as conv_ccy
        from public.events b
        left join public.bookings bk on b.event_type_code = 'booking_issued' and bk.id = b.entity_id
        left join public.payments p on b.event_type_code = 'payment_recorded' and p.id = b.entity_id
        left join public.bookings pbk on p.booking_id = pbk.id
        where b.event_type_code in ('lead_qualified','booking_created','payment_recorded','booking_issued')
    ) r
    join public.leads l on l.id = r.lead_id
    left join public.customers cu on cu.id = l.customer_id and cu.tenant_id = r.tenant_id
    where l.attribution_click_id is not null
    on conflict (source_event_seq) where source_event_seq is not null do nothing;
    get diagnostics v_n = row_count;
    return v_n;
end $fn$;
select isnt((select md5(pg_get_functiondef('app.map_outcomes_to_conversions(integer)'::regprocedure))), (select v from s137 where k='mapper'),
  'MUTANT INSTALLED: the mapper resolves a payment''s lead through payments.booking_id alone');
create temp table mut on commit drop as select app.map_outcomes_to_conversions(100000) as n;
select is((select array_agg(oc.conversion_event_type_code order by oc.source_event_seq) from public.offline_conversions oc
            where oc.lead_id = '13700000-0000-0000-0000-0000000000e2'),
  array['booking_created','ticket_issued'],
  'MUTANT: the paid booking yields booking_created and ticket_issued and no payment_received');
rollback to savepoint m1;
select is((select md5(pg_get_functiondef('app.map_outcomes_to_conversions(integer)'::regprocedure))), (select v from s137 where k='mapper'),
  'RESTORED: the mapper is byte-identical to the repaired definition');

-- ================================================================================================
-- 7-11. The real mapper: every live conversion action, exactly once.
-- ================================================================================================
create temp table run1 on commit drop as select app.map_outcomes_to_conversions(100000) as n;
select is((select array_agg(oc.conversion_event_type_code || '@' || (oc.source_event_seq = e.seq)::text)
             from public.offline_conversions oc
             join public.events e on e.tenant_id = oc.tenant_id and e.event_type_code = 'lead_qualified' and e.entity_id = oc.lead_id
            where oc.lead_id = '13700000-0000-0000-0000-0000000000e1'),
  array['qualified_lead@true'],
  'BUSINESS: a lead qualified through app.advance_lead yields one qualified_lead, keyed to its own event');
select is((select array_agg(oc.conversion_event_type_code order by oc.source_event_seq) from public.offline_conversions oc
            where oc.lead_id = '13700000-0000-0000-0000-0000000000e2'),
  array['booking_created','payment_received','ticket_issued'],
  'BUSINESS: the booked, paid and issued lead yields booking_created, payment_received and ticket_issued (CONV-7)');
select is((select array_agg(oc.conversion_event_type_code || '|' || coalesce(oc.conversion_value::text, '-') || '|' || coalesce(oc.currency_code, '-')
                            || '|' || (oc.booking_id = (select v from s137 where k='bk')::uuid)::text
                            || '|' || coalesce((oc.payment_id = (select v from s137 where k='pay')::uuid)::text, '-')
                            order by oc.source_event_seq)
             from public.offline_conversions oc where oc.lead_id = '13700000-0000-0000-0000-0000000000e2'),
  array['booking_created|-|-|true|-','payment_received|5000.0000|EGP|true|true','ticket_issued|-|-|true|-'],
  'INPUT: only payment_received carries revenue, 5000 EGP, and all three name the booking; the payment names the payment');
select is((select count(*)::int from public.offline_conversions where lead_id = '13700000-0000-0000-0000-0000000000e3'), 0,
  'BUSINESS: a qualified lead with no attribution click is not a conversion');
create temp table run2 on commit drop as select app.map_outcomes_to_conversions(100000) as n;
select is(array[(select n from run2), (select count(*)::int from public.offline_conversions where tenant_id = '13700000-0000-0000-0000-000000000001')],
  array[0, 7],
  'REPLAY: a second mapper run adds nothing; the tenant holds seven conversions, one per source event');

-- ================================================================================================
-- 12-14. Identity, consent and transaction identity at the claim.
-- ================================================================================================
update public.customers set primary_email = 'changed@cv137.test' where id = '13700000-0000-0000-0000-0000000000d1';
select is((select array_agg(distinct customer_email) from public.offline_conversions where tenant_id = '13700000-0000-0000-0000-000000000001'),
  array['buyer@cv137.test'],
  'STATE: a later edit of the customer does not rewrite the identity each conversion was made with');
create temp table claimed on commit drop as select * from app.claim_conversion_deliveries('google_ads', 100000);
select is((select array_agg(l.title || ':' || oc.conversion_event_type_code order by l.title, oc.source_event_seq)
             from public.offline_conversions oc join public.leads l on l.id = oc.lead_id
            where oc.tenant_id = '13700000-0000-0000-0000-000000000001'
              and not exists (select 1 from claimed c where c.conversion_id = oc.id)),
  array['L4:qualified_lead'],
  'STATE: L4''s conversion exists and is never claimed, because its consent is denied -- suppressed, not failed');
select is((select array_agg(distinct (c.conversion_id = oc.id and c.attempt_number = 1 and c.delivery_id is not null)::text)
             from claimed c join public.offline_conversions oc on oc.id = c.conversion_id
            where oc.tenant_id = '13700000-0000-0000-0000-000000000001'),
  array['true'],
  'REPLAY: each claimed row carries its conversion id, the stable transaction identity, on attempt 1');

-- ================================================================================================
-- 15-16. CONV-8, CLOSED: the table door records the same act, so it reaches the pipeline.
-- ================================================================================================
select is((select array[l.lead_status_code, (select string_agg(oc.conversion_event_type_code, ',') from public.offline_conversions oc where oc.lead_id = l.id)]
             from public.leads l where l.id = '13700000-0000-0000-0000-0000000000e5'),
  array['qualified','qualified_lead'],
  'CONV-8 CLOSED: the handler''s direct qualification produces the qualified_lead conversion, exactly once');
select is((select array[b.booking_status_code, (select string_agg(oc.conversion_event_type_code, ',') from public.offline_conversions oc where oc.lead_id = b.lead_id)]
             from public.bookings b where b.lead_id = '13700000-0000-0000-0000-0000000000e6'),
  array['draft','booking_created'],
  'CONV-8 CLOSED: the employee''s direct booking produces the booking_created conversion, exactly once');

select * from finish();
rollback;
