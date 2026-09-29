-- pgTAP: PAY-3 -- a payment is recorded on every door.
--
-- `app.map_outcomes_to_conversions` turns `payment_recorded` into `payment_received`, the one Google
-- Ads conversion that carries revenue. Until the PAY-3 migration `payment_recorded` and
-- `supplier_payment_recorded` each had one producer, their RPC, while `authenticated` holds INSERT on
-- `payments` and `payment_allocations` behind RECORD_PAYMENT (PAY-1, PAY-2, FIN-10). A payment made
-- at the table door emitted nothing, so it never became a conversion. Now one DEFERRED constraint
-- trigger is the single producer: it records the payment at commit, when the allocation naming its
-- invoice exists, and the RPCs no longer emit the event themselves.
--
-- A deferred trigger fires at COMMIT, and this file rolls back, so after each write it fires the
-- pending events with `set constraints payments_emit_recorded immediate` -- while the writer's
-- session is still current -- and returns the trigger to `deferred` for the next write.
--
-- ATTACK-CLASSES: DOOR BUSINESS INPUT STATE OBSERVABILITY PRIVILEGE REPLAY TENANT=N/A AUTH=N/A CONCURRENCY=N/A
--   TENANT=N/A -- `app.record_event` takes the tenant from the row, which RLS already confined, and
--     the allocation lookup is tenant-scoped; conversion provenance across tenants is CONV-6's.
--   AUTH=N/A -- the door's capability and step-up are PAY-2's (`126_...`) and are unchanged.
--   CONCURRENCY=N/A -- the emitter is one row-level call at commit that reads only its own
--     payment's allocations; allocation serialisation is FIN-10's.
--
-- THE ACTORS. `owner` holds RECORD_PAYMENT. `employee` does not. Every lead carries a consented
-- first-touch Google Ads click, so every attributable customer payment becomes a conversion.
create extension if not exists pgtap with schema extensions;

begin;
select plan(20);

insert into auth.users (id,email,email_confirmed_at) values
  ('14000000-0000-0000-0000-0000000000a1','own@p140.test',now()),
  ('14000000-0000-0000-0000-0000000000a2','emp@p140.test',now());
insert into public.tenants (id,name,slug,status) values
  ('14000000-0000-0000-0000-000000000001','P140 Travel','p140-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '14000000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('14000000-0000-0000-0000-00000000000a','14000000-0000-0000-0000-000000000001','Cairo','p140-cairo');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('14000000-0000-0000-0000-0000000000c1','14000000-0000-0000-0000-000000000001','14000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('14000000-0000-0000-0000-000000000011','14000000-0000-0000-0000-000000000001','Owner','own@p140.test',true,'14000000-0000-0000-0000-0000000000a1'),
  ('14000000-0000-0000-0000-000000000012','14000000-0000-0000-0000-000000000001','Employee','emp@p140.test',true,'14000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary)
select '14000000-0000-0000-0000-000000000001', u, '14000000-0000-0000-0000-00000000000a','14000000-0000-0000-0000-0000000000c1', true
from unnest(array['14000000-0000-0000-0000-000000000011'::uuid,'14000000-0000-0000-0000-000000000012'::uuid]) u;
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '14000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('14000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('14000000-0000-0000-0000-000000000012','employee')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id,tenant_id,customer_type_code,full_name,primary_phone,primary_email) values
  ('14000000-0000-0000-0000-0000000000d1','14000000-0000-0000-0000-000000000001','person','Buyer','+201000000140','buyer@p140.test');
insert into public.suppliers (id,tenant_id,name,supplier_type_code) values
  ('14000000-0000-0000-0000-0000000000f1','14000000-0000-0000-0000-000000000001','Nile Air','airline');
insert into public.leads (id,tenant_id,branch_id,department_id,customer_id,lead_source_code,title,lead_status_code)
select ('14000000-0000-0000-0000-0000000000e'||n)::uuid, '14000000-0000-0000-0000-000000000001',
       '14000000-0000-0000-0000-00000000000a','14000000-0000-0000-0000-0000000000c1',
       '14000000-0000-0000-0000-0000000000d1','google_ads_form','L'||n,'new'
from generate_series(1,5) n;
select app.capture_attribution_click('14000000-0000-0000-0000-000000000001','google_ads','GCLID-140-'||n,
         null,null,null,null,null,null,null,null,null,null,'granted','granted',
         null, ('14000000-0000-0000-0000-0000000000e'||n)::uuid)
from generate_series(1,5) n;

create temp table s140 (k text primary key, v text) on commit drop;
grant select, insert on s140 to authenticated;
-- One line per payment: event count / actor / event type / payload.
create function pg_temp.p140(p_payment uuid) returns text language sql as $$
  select count(e.id)::text || '/' || coalesce(max(e.actor_user_id::text), '-') || '/'
         || coalesce(max(e.event_type_code), '-') || '/' || coalesce(max(e.reason), '-') || '/' || coalesce(max(e.payload::text), '-')
  from public.events e where e.entity_id = p_payment and e.event_type_code in ('payment_recorded', 'supplier_payment_recorded')
$$;
grant execute on function pg_temp.p140(uuid) to authenticated;

-- The owner works L1-L5 to a booking each, and invoices and issues five of them.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select app.assign_lead(('14000000-0000-0000-0000-0000000000e'||n)::uuid, '14000000-0000-0000-0000-000000000011', 'fixture') from generate_series(1,5) n;
select app.record_lead_interaction(('14000000-0000-0000-0000-0000000000e'||n)::uuid, 'phone_call') from generate_series(1,5) n;
insert into s140 select 'bk'||n, app.create_booking(p_customer_id=>'14000000-0000-0000-0000-0000000000d1',
                                                  p_lead_id=>('14000000-0000-0000-0000-0000000000e'||n)::uuid, p_title=>'Trip '||n)::text
from generate_series(1,5) n;
insert into s140 select 'inv'||n, app.create_invoice('14000000-0000-0000-0000-0000000000d1','EGP',5000,(select v from s140 where k='bk'||n)::uuid)::text
from generate_series(1,5) n;
select app.issue_invoice((select v from s140 where k='inv'||n)::uuid) from generate_series(1,5) n;

-- =============================================================================================
-- 1-3. The RPCs: still exactly one event each, now produced by the trigger.
-- =============================================================================================
select ok(has_table_privilege('authenticated','public.payments','INSERT') and has_table_privilege('authenticated','public.payment_allocations','INSERT')
          and app.has_permission('RECORD_PAYMENT'),
  'PREMISE: authenticated holds INSERT on payments and payment_allocations, and the owner holds RECORD_PAYMENT -- the table door is a governed, designed door');

insert into s140 select 'rpc', app.record_payment((select v from s140 where k='inv1')::uuid, 5000, 'cash', now(), 'RCPT-1')::text;
set constraints payments_emit_recorded immediate;
set constraints payments_emit_recorded deferred;
select is(pg_temp.p140((select v from s140 where k='rpc')::uuid),
  '1/14000000-0000-0000-0000-000000000011/payment_recorded/RCPT-1/{"amount": 5000.0000, "invoice_id": "' || (select v from s140 where k='inv1') || '", "currency_code": "EGP", "invoice_new_status": "paid"}',
  'DOOR: the RPC path records exactly ONE payment_recorded, with the caller, its reference and the RPC''s payload keys -- including the invoice it paid, which the mapper follows (CONV-7)');

insert into s140 select 'srpc', app.record_supplier_payment('14000000-0000-0000-0000-0000000000f1', 900, 'EGP', 'cash',
                                                           (select v from s140 where k='bk1')::uuid, now(), 'SUP-1')::text;
set constraints payments_emit_recorded immediate;
set constraints payments_emit_recorded deferred;
select is(pg_temp.p140((select v from s140 where k='srpc')::uuid),
  '1/14000000-0000-0000-0000-000000000011/supplier_payment_recorded/SUP-1/{"amount": 900.0000, "booking_id": "' || (select v from s140 where k='bk1') || '", "supplier_id": "14000000-0000-0000-0000-0000000000f1", "currency_code": "EGP"}',
  'DOOR: app.record_supplier_payment records exactly ONE supplier_payment_recorded with its own payload keys');

-- =============================================================================================
-- 4-10. PAY-3: the table door.
-- =============================================================================================
select lives_ok($$
  with p as (insert into public.payments (tenant_id, payment_direction_code, customer_id, currency_code, payment_method_code, amount, paid_at)
             values ('14000000-0000-0000-0000-000000000001','customer_payment','14000000-0000-0000-0000-0000000000d1','EGP','bank_transfer',5000,now())
             returning id)
  insert into s140 select 'doorA', id::text from p$$,
  'POSITIVE CONTROL: the owner still records a customer payment at the table door -- it is recorded, not closed');
insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
values ('14000000-0000-0000-0000-000000000001', (select v from s140 where k='doorA')::uuid, (select v from s140 where k='inv2')::uuid, 5000, 'EGP');
set constraints payments_emit_recorded immediate;
set constraints payments_emit_recorded deferred;
select is(pg_temp.p140((select v from s140 where k='doorA')::uuid),
  '1/14000000-0000-0000-0000-000000000011/payment_recorded/-/{"amount": 5000.0000, "invoice_id": "' || (select v from s140 where k='inv2') || '", "currency_code": "EGP", "invoice_new_status": "issued"}',
  'PAY-3: a door payment allocated to an invoice in the same transaction records ONE payment_recorded naming its writer and that invoice -- before the PAY-3 migration it had zero events');

with p as (
      insert into public.payments (tenant_id, payment_direction_code, customer_id, booking_id, currency_code, payment_method_code, amount, paid_at)
      values ('14000000-0000-0000-0000-000000000001','customer_payment','14000000-0000-0000-0000-0000000000d1',(select v from s140 where k='bk3')::uuid,'EGP','cash',1200,now())
      returning id)
insert into s140 select 'doorB', id::text from p;
set constraints payments_emit_recorded immediate;
set constraints payments_emit_recorded deferred;
select is(pg_temp.p140((select v from s140 where k='doorB')::uuid),
  '1/14000000-0000-0000-0000-000000000011/payment_recorded/-/{"amount": 1200.0000, "invoice_id": null, "currency_code": "EGP", "invoice_new_status": null}',
  'PAY-3: a door payment naming its booking and no invoice records ONE payment_recorded, with no invoice -- the mapper attributes it through payments.booking_id');

with p as (
      insert into public.payments (tenant_id, payment_direction_code, customer_id, currency_code, payment_method_code, amount, paid_at)
      values ('14000000-0000-0000-0000-000000000001','customer_payment','14000000-0000-0000-0000-0000000000d1','EGP','cash',600,now())
      returning id)
insert into s140 select 'doorM', id::text from p;
insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
select '14000000-0000-0000-0000-000000000001', (select v from s140 where k='doorM')::uuid, (select v from s140 where k='inv'||n)::uuid, 300, 'EGP'
from generate_series(4,5) n;
set constraints payments_emit_recorded immediate;
set constraints payments_emit_recorded deferred;
select is(pg_temp.p140((select v from s140 where k='doorM')::uuid),
  '1/14000000-0000-0000-0000-000000000011/payment_recorded/-/{"amount": 600.0000, "invoice_id": null, "currency_code": "EGP", "invoice_new_status": null}',
  'INPUT: a payment split across two invoices names neither -- the emitter refuses to guess which booking the revenue belongs to');

with p as (
      insert into public.payments (tenant_id, payment_direction_code, supplier_id, booking_id, currency_code, payment_method_code, amount, paid_at)
      values ('14000000-0000-0000-0000-000000000001','supplier_payment','14000000-0000-0000-0000-0000000000f1',(select v from s140 where k='bk3')::uuid,'EGP','cash',700,now())
      returning id)
insert into s140 select 'doorS', id::text from p;
set constraints payments_emit_recorded immediate;
set constraints payments_emit_recorded deferred;
select is(pg_temp.p140((select v from s140 where k='doorS')::uuid),
  '1/14000000-0000-0000-0000-000000000011/supplier_payment_recorded/-/{"amount": 700.0000, "booking_id": "' || (select v from s140 where k='bk3') || '", "supplier_id": "14000000-0000-0000-0000-0000000000f1", "currency_code": "EGP"}',
  'PAY-3: a supplier payment at the door records ONE supplier_payment_recorded, never payment_recorded -- money paid out is not revenue');
reset role;

select set_config('request.jwt.claims','{"sub":"14000000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select throws_ok($$insert into public.payments (tenant_id, payment_direction_code, customer_id, booking_id, currency_code, payment_method_code, amount, paid_at)
                   values ('14000000-0000-0000-0000-000000000001','customer_payment','14000000-0000-0000-0000-0000000000d1',
                           (select v from s140 where k='bk4')::uuid,'EGP','cash',50,now())$$,
  '42501', 'permission denied: RECORD_PAYMENT',
  'PRIVILEGE: an employee without RECORD_PAYMENT is still refused at the door by the guard''s own message');
set constraints payments_emit_recorded immediate;
set constraints payments_emit_recorded deferred;
reset role;
select is((select count(*)::int from public.payments where tenant_id = '14000000-0000-0000-0000-000000000001' and amount = 50), 0,
  '...and a refused payment leaves no payment behind to record');

-- =============================================================================================
-- 11-12. What is not recorded: later edits and later allocations.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"14000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
update public.payments set reference_number = 'LATE-REF', amount = 1100 where id = (select v from s140 where k='doorB')::uuid;
insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
values ('14000000-0000-0000-0000-000000000001', (select v from s140 where k='doorB')::uuid, (select v from s140 where k='inv3')::uuid, 1100, 'EGP');
set constraints payments_emit_recorded immediate;
set constraints payments_emit_recorded deferred;
select is(pg_temp.p140((select v from s140 where k='doorB')::uuid),
  '1/14000000-0000-0000-0000-000000000011/payment_recorded/-/{"amount": 1200.0000, "invoice_id": null, "currency_code": "EGP", "invoice_new_status": null}',
  'STATE: a later edit and a later allocation record no second payment_recorded -- the event is the payment''s creation, stated as it was recorded');
reset role;

select is((select count(*)::int from public.events e join public.payments p on p.id = e.entity_id
            where p.tenant_id = '14000000-0000-0000-0000-000000000001' and e.event_type_code = 'payment_allocation_created'
              and p.id = (select v from s140 where k='doorB')::uuid), 0,
  '...and payment_allocation_created stays the allocation''s own event, keyed to the allocation, not the payment');

-- =============================================================================================
-- 13-15. The pipeline, the emitter's privileges, and the platform path.
-- =============================================================================================
select set_config('request.jwt.claims','',true);
insert into public.payments (tenant_id, payment_direction_code, customer_id, booking_id, currency_code, payment_method_code, amount, paid_at, reference_number)
values ('14000000-0000-0000-0000-000000000001','customer_payment','14000000-0000-0000-0000-0000000000d1',
        (select v from s140 where k='bk5')::uuid,'EGP','cash',300,now(),'SYS-1');
set constraints payments_emit_recorded immediate;
set constraints payments_emit_recorded deferred;

create temp table run1 on commit drop as select app.map_outcomes_to_conversions(100000) as n;
select is((select array_agg(l.title || ':' || oc.conversion_event_type_code || '=' || oc.conversion_value::text || '@' || (oc.source_event_seq = e.seq)::text
                            order by l.title, oc.conversion_value)
             from public.offline_conversions oc
             join public.leads l on l.id = oc.lead_id
             join public.events e on e.seq = oc.source_event_seq
            where oc.tenant_id = '14000000-0000-0000-0000-000000000001' and oc.conversion_event_type_code = 'payment_received'),
  array['L1:payment_received=5000.0000@true','L2:payment_received=5000.0000@true','L3:payment_received=1100.0000@true','L5:payment_received=300.0000@true'],
  'BUSINESS: the RPC payment, the door payment through its invoice, the door payment through its booking and the platform payment each yield ONE payment_received keyed to its own event -- the split payment and both supplier payments yield none');

select ok(
  (select prosecdef from pg_proc where oid = 'app.emit_payment_recorded'::regproc)
  and not has_function_privilege('public', 'app.emit_payment_recorded()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'app.emit_payment_recorded()', 'EXECUTE')
  and (select count(*) = 1 from pg_trigger t
        where t.tgrelid = 'public.payments'::regclass and not t.tgisinternal and t.tgfoid = 'app.emit_payment_recorded'::regproc
          and t.tgconstraint <> 0 and t.tgdeferrable and t.tginitdeferred
          and (t.tgtype & 1) = 1 and (t.tgtype & 2) = 0 and (t.tgtype & 4) <> 0 and (t.tgtype & 8) = 0 and (t.tgtype & 16) = 0),
  'PRIVILEGE: app.emit_payment_recorded is SECURITY DEFINER, executable by neither PUBLIC nor authenticated, and fires once, AFTER INSERT ROW, deferred to commit');

select is((select count(*)::text || '/' || coalesce(max(e.actor_user_id::text), '-') || '/' || max(e.reason)
             from public.events e join public.payments p on p.id = e.entity_id
            where p.reference_number = 'SYS-1' and e.event_type_code = 'payment_recorded'),
  '1/-/SYS-1',
  'the session-less platform path is recorded too, with a null actor');

-- =============================================================================================
-- 16-18. LOAD-BEARING: remove the emitter and the door is silent again; restore it and it records.
-- TEST-3: the in-savepoint assertion is re-asserted after the rollback so it is counted.
-- =============================================================================================
savepoint m140;
drop trigger payments_emit_recorded on public.payments;
select set_config('request.jwt.claims','{"sub":"14000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
insert into public.payments (tenant_id, payment_direction_code, customer_id, booking_id, currency_code, payment_method_code, amount, paid_at, reference_number)
values ('14000000-0000-0000-0000-000000000001','customer_payment','14000000-0000-0000-0000-0000000000d1',
        (select v from s140 where k='bk4')::uuid,'EGP','cash',400,now(),'MUT-1');
reset role;
select set_config('request.jwt.claims','',true);
create temp table mrun on commit drop as select app.map_outcomes_to_conversions(100000) as n;
select is((select count(*)::text from public.events e join public.payments p on p.id = e.entity_id
            where p.reference_number = 'MUT-1' and e.event_type_code = 'payment_recorded') || '|' || (select n from mrun),
  '0|0',
  'MUTATION: with payments_emit_recorded dropped, the door payment is silent again and the revenue conversion never exists -- so this trigger is what closes PAY-3');
rollback to savepoint m140;

select set_config('request.jwt.claims','{"sub":"14000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
insert into public.payments (tenant_id, payment_direction_code, customer_id, booking_id, currency_code, payment_method_code, amount, paid_at, reference_number)
values ('14000000-0000-0000-0000-000000000001','customer_payment','14000000-0000-0000-0000-0000000000d1',
        (select v from s140 where k='bk4')::uuid,'EGP','cash',400,now(),'MUT-1');
set constraints payments_emit_recorded immediate;
set constraints payments_emit_recorded deferred;
reset role;
select set_config('request.jwt.claims','',true);
create temp table rrun on commit drop as select app.map_outcomes_to_conversions(100000) as n;
select is((select count(*)::text from public.events e join public.payments p on p.id = e.entity_id
            where p.reference_number = 'MUT-1' and e.event_type_code = 'payment_recorded') || '|' || (select n from rrun),
  '1|1',
  'RESTORED: with the mutation rolled back the identical payment is recorded again and becomes one conversion');

create temp table run3 on commit drop as select app.map_outcomes_to_conversions(100000) as n;
select is((select n from run3), 0,
  'REPLAY: a further mapper run adds nothing');

-- =============================================================================================
-- 19-20. COMPLETENESS.
-- =============================================================================================
select is((select count(*)::int from public.payments p
            where p.tenant_id = '14000000-0000-0000-0000-000000000001'
              and p.payment_direction_code in ('customer_payment', 'supplier_payment')
              and (select count(*) from public.events e where e.entity_id = p.id
                     and e.event_type_code = case p.payment_direction_code when 'supplier_payment' then 'supplier_payment_recorded' else 'payment_recorded' end) <> 1),
  0,
  'COMPLETENESS: every in-scope customer_payment and supplier_payment in the tenant carries exactly one creation event of its own direction -- refund directions are outside SPEC-238 and remain PAY-4''s');

select is((select count(*)::int from public.events e join public.payments p on p.id = e.entity_id
            where p.tenant_id = '14000000-0000-0000-0000-000000000001' and p.payment_direction_code = 'supplier_payment'
              and e.event_type_code = 'payment_recorded'), 0,
  'BUSINESS: no supplier payment is ever recorded as payment_recorded, so none can become revenue');

select * from finish();
rollback;
