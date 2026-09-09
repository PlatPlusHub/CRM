-- pgTAP: Batch 6 Slice 11 customers. Local actor, integrity and mechanism proofs.
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT BUSINESS PRIVILEGE OBSERVABILITY REPLAY CONCURRENCY
-- Overlapping-session proofs live in scripts/verify_customer_concurrency.py.
create extension if not exists pgtap with schema extensions;

begin;
select plan(45);

insert into auth.users (id, email, email_confirmed_at) values
  ('b1100000-0000-0000-0000-0000000000a1','owner@slice11.test',   now()),
  ('b1100000-0000-0000-0000-0000000000a2','finance@slice11.test', now()),
  ('b1100000-0000-0000-0000-0000000000a3','emp@slice11.test',     now());
insert into public.tenants (id, name, slug, status) values
  ('b1100000-0000-0000-0000-000000000001','Slice11 Travel','slice11','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id='b1100000-0000-0000-0000-000000000001';
insert into public.branches (id, tenant_id, name, slug) values
  ('b1100000-0000-0000-0000-00000000000a','b1100000-0000-0000-0000-000000000001','HQ','slice11-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('b1100000-0000-0000-0000-0000000000c1','b1100000-0000-0000-0000-000000000001',
   'b1100000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('b1100000-0000-0000-0000-000000000011','b1100000-0000-0000-0000-000000000001','Owner','owner@slice11.test',true,'b1100000-0000-0000-0000-0000000000a1'),
  ('b1100000-0000-0000-0000-000000000012','b1100000-0000-0000-0000-000000000001','Finance','finance@slice11.test',true,'b1100000-0000-0000-0000-0000000000a2'),
  ('b1100000-0000-0000-0000-000000000013','b1100000-0000-0000-0000-000000000001','Emp','emp@slice11.test',true,'b1100000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select 'b1100000-0000-0000-0000-000000000001', u,
       'b1100000-0000-0000-0000-00000000000a','b1100000-0000-0000-0000-0000000000c1', true
from unnest(array['b1100000-0000-0000-0000-000000000011'::uuid,
                  'b1100000-0000-0000-0000-000000000012'::uuid,
                  'b1100000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'b1100000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('b1100000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('b1100000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('b1100000-0000-0000-0000-000000000013'::uuid,'employee')) v(u,rc)
join public.roles r on r.code = v.rc;

-- The ceilings under test. 1000 EGP rather than any production figure: the THRESHOLD VALUE is
-- configuration a tenant sets per customer through MANAGE_CUSTOMER_CREDIT, and pinning a business
-- number here would test configuration rather than the crossing. `Uncapped` is the NULL control.
insert into public.customers (id, tenant_id, customer_type_code, full_name, credit_limit_amount, credit_limit_currency_code) values
  ('b1100000-0000-0000-0000-0000000000d1','b1100000-0000-0000-0000-000000000001','person','Capped Customer',   1000, 'EGP'),
  ('b1100000-0000-0000-0000-0000000000d2','b1100000-0000-0000-0000-000000000001','person','Uncapped Customer', null, null),
  ('b1100000-0000-0000-0000-0000000000d3','b1100000-0000-0000-0000-000000000001','person','FX Customer',       1000, 'EGP');


-- END FIXTURE

-- Establish the actor and positive write before the discriminating pair.
select set_config('request.jwt.claims','{"sub":"b1100000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select is(current_user::text,'authenticated','the probe really runs as authenticated');
select is(auth.uid(),'b1100000-0000-0000-0000-0000000000a2'::uuid,'the JWT is the finance actor');
select ok(app.has_permission('MANAGE_CUSTOMER_CREDIT') and not app.has_permission('CREATE_CUSTOMER'),
 'finance holds credit authority and does not hold customer administration');
select is((select count(*)::int from public.customers where id='b1100000-0000-0000-0000-0000000000d1'),1,'target is visible');
update public.customers set credit_limit_amount=1001 where id='b1100000-0000-0000-0000-0000000000d1';
select is((select credit_limit_amount from public.customers where id='b1100000-0000-0000-0000-0000000000d1'),1001::numeric,'credit-only UPDATE changes the row');
select throws_ok($q$update public.customers set full_name='unauthorized' where id='b1100000-0000-0000-0000-0000000000d1'$q$,'42501',null,'finance cannot rename without credit change');
select throws_ok($q$update public.customers set credit_limit_amount=1002,full_name='unauthorized' where id='b1100000-0000-0000-0000-0000000000d1'$q$,'42501',null,'adding a ceiling change must not authorize the same rename');
select throws_ok($q$insert into public.customers(tenant_id,customer_type_code,full_name,credit_limit_amount,credit_limit_currency_code) values('b1100000-0000-0000-0000-000000000001','person','finance-created',1,'EGP')$q$,'42501',null,'a credit holder cannot create a customer by supplying a ceiling');

select set_config('request.jwt.claims','{"sub":"b1100000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select ok(app.has_permission('CREATE_CUSTOMER') and not app.has_permission('MANAGE_CUSTOMER_CREDIT') and not app.has_permission('ARCHIVE_RECORD'),'employee authority is independently established');
update public.customers set full_name='Employee correction' where id='b1100000-0000-0000-0000-0000000000d1';
select is((select full_name from public.customers where id='b1100000-0000-0000-0000-0000000000d1'),'Employee correction','employee can administer the customer');
select throws_ok($q$update public.customers set credit_limit_amount=1003 where id='b1100000-0000-0000-0000-0000000000d1'$q$,'42501',null,'customer authority cannot change a ceiling');
select throws_ok($q$update public.customers set is_archived=true where id='b1100000-0000-0000-0000-0000000000d1'$q$,'42501',null,'employee cannot archive');

-- The first-registration trigger changes NEW before the capability guard. Its automatic write
-- must not deny a legitimate credit-only update on a system-created customer.
reset role;
select is((select first_registered_user_id from public.customers where id='b1100000-0000-0000-0000-0000000000d1'), 'b1100000-0000-0000-0000-000000000012'::uuid,'first legitimate credit update stamps the real actor');
select set_config('request.jwt.claims','{"sub":"b1100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select ok(app.has_permission('ARCHIVE_RECORD') and app.has_permission('MERGE_CUSTOMER_IDENTITY'),'owner holds archive and merge');
update public.customers set is_archived=true,archived_at='2001-01-01',archived_by='b1100000-0000-0000-0000-000000000013' where id='b1100000-0000-0000-0000-0000000000d3';
select ok((select archived_at=now() and archived_by='b1100000-0000-0000-0000-000000000011' from public.customers where id='b1100000-0000-0000-0000-0000000000d3'),'archive transition stamps server time and actor');
select set_config('request.jwt.claims','{"sub":"b1100000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok($q$update public.customers set archived_at='2001-01-01',archived_by='b1100000-0000-0000-0000-000000000013' where id='b1100000-0000-0000-0000-0000000000d3'$q$,'42501',null,'metadata cannot be rewritten without changing archive state');
select throws_ok($q$insert into public.customers(tenant_id,customer_type_code,full_name,is_archived) values('b1100000-0000-0000-0000-000000000001','person','prearchived',true)$q$,'42501',null,'INSERT cannot bypass archive authority');

-- Structural, numeric and tenant controls, with a real positive authority.
select set_config('request.jwt.claims','{"sub":"b1100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok($q$update public.customers set credit_limit_amount=-1 where id='b1100000-0000-0000-0000-0000000000d1'$q$,'23514',null,'negative ceiling CHECK');
select throws_ok($q$update public.customers set credit_limit_amount='NaN' where id='b1100000-0000-0000-0000-0000000000d1'$q$,'23514',null,'NaN CHECK, independent of authority');
select throws_ok($q$update public.customers set credit_limit_amount='Infinity' where id='b1100000-0000-0000-0000-0000000000d1'$q$,'22003',null,'bounded numeric rejects Infinity');
select throws_ok($q$update public.customers set credit_limit_amount=1000000000000000 where id='b1100000-0000-0000-0000-0000000000d1'$q$,'22003',null,'bounded numeric rejects overflow');
update public.customers set credit_limit_amount=0 where id='b1100000-0000-0000-0000-0000000000d1';
select is((select credit_limit_amount from public.customers where id='b1100000-0000-0000-0000-0000000000d1'),0::numeric,'zero remains a legal tenant-supplied ceiling');
select throws_ok($q$update public.customers set credit_limit_currency_code=null where id='b1100000-0000-0000-0000-0000000000d1'$q$,'23514',null,'both-or-neither CHECK');
select throws_ok($q$update public.customers set credit_limit_currency_code='ZZZ' where id='b1100000-0000-0000-0000-0000000000d1'$q$,'23503',null,'currency FK');
select throws_ok($q$update public.customers set customer_type_code='invented' where id='b1100000-0000-0000-0000-0000000000d1'$q$,'23514',null,'customer type catalog guard');
select throws_ok($q$update public.customers set primary_phone='012 345' where id='b1100000-0000-0000-0000-0000000000d1'$q$,'23514',null,'table phone normalization CHECK');
select throws_ok($q$update public.customers set primary_email='UPPER@EXAMPLE.TEST' where id='b1100000-0000-0000-0000-0000000000d1'$q$,'23514',null,'table email normalization CHECK');
reset role;
select is((select count(*)::int from app.status_transitions where table_name='customers'),0,'ENTRY-1 does not apply: customers has no transition machine');
insert into public.tenants(id,name,slug,status) values('b1100000-0000-0000-0000-000000000002','Rival','slice11-rival','active');
insert into public.subscriptions(tenant_id,subscription_plan_id,subscription_status_code) select 'b1100000-0000-0000-0000-000000000002',id,'active' from public.subscription_plans where plan_code='enterprise';
select set_config('request.jwt.claims','{}',true);
insert into public.customers(id,tenant_id,customer_type_code,full_name) values('b1100000-0000-0000-0000-0000000000d9','b1100000-0000-0000-0000-000000000002','person','Rival customer');
select set_config('request.jwt.claims','{"sub":"b1100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select is((select count(*)::int from public.customers where id='b1100000-0000-0000-0000-0000000000d9'),0,'RLS hides a known real rival customer');
select throws_ok($q$insert into public.customers(tenant_id,customer_type_code,full_name) values('b1100000-0000-0000-0000-000000000002','person','cross tenant')$q$,'42501',null,'RLS WITH CHECK rejects foreign tenant INSERT');
select throws_ok($q$select app.customer_credit('b1100000-0000-0000-0000-0000000000d9')$q$,'42501','customer is not in your tenant','DEFINER credit reader explicitly checks tenant');
select throws_ok($q$select app.merge_customer_identity('b1100000-0000-0000-0000-0000000000d9','b1100000-0000-0000-0000-0000000000d2')$q$,'P0001','source customer is not in your tenant','merge source tenant check uses the actual foreign id');
select throws_ok($q$select app.merge_customer_identity('b1100000-0000-0000-0000-0000000000d1','b1100000-0000-0000-0000-0000000000d9')$q$,'P0001','target customer is not in your tenant','merge destination tenant check');
select throws_ok($q$select app.merge_customer_identity('b1100000-0000-0000-0000-0000000000d1','b1100000-0000-0000-0000-0000000000d1')$q$,'P0001','source and target customer must differ','self-merge rejected');
select throws_ok($q$select app.merge_customer_identity('b1100000-0000-0000-0000-0000000000d1','b1100000-0000-0000-0000-0000000000d3')$q$,'P0001','target customer is already archived','an archived target is not a surviving identity');

-- Every ADR-0019 referrer, not merely a note: build a real customer history.
reset role;
select set_config('request.jwt.claims','{}',true);
insert into public.bookings(id,tenant_id,branch_id,department_id,customer_id,booking_status_code,title,booking_reference)
values('b1100000-0000-0000-0000-0000000000b1','b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-00000000000a','b1100000-0000-0000-0000-0000000000c1','b1100000-0000-0000-0000-0000000000d1','draft','History','SLICE11');
insert into public.invoices(id,tenant_id,customer_id,booking_id,invoice_number,invoice_date,currency_code,total_amount,status_code)
values('b1100000-0000-0000-0000-0000000000f1','b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','b1100000-0000-0000-0000-0000000000b1','INV-SLICE11',current_date,'EGP',100,'issued');
insert into public.payments(tenant_id,customer_id,booking_id,payment_direction_code,payment_method_code,currency_code,amount)
values('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','b1100000-0000-0000-0000-0000000000b1','customer_payment','cash','EGP',20);
insert into public.refunds(tenant_id,customer_id,booking_id,payment_direction_code,currency_code,amount,refund_status_code)
values('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','b1100000-0000-0000-0000-0000000000b1','customer_refund','EGP',5,'completed');
insert into public.leads(tenant_id,customer_id,branch_id,department_id,lead_source_code,lead_status_code,title)
values('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','b1100000-0000-0000-0000-00000000000a','b1100000-0000-0000-0000-0000000000c1','manual_entry','new','History');
insert into public.quotations(tenant_id,customer_id,quotation_status_code,quotation_number,currency_code) values('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','draft','Q-SLICE11','EGP');
insert into public.passengers(tenant_id,customer_id,first_name,family_name,full_name,passenger_type_code) values('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','Slice','Eleven','Slice Eleven','adult');
insert into public.conversations(tenant_id,customer_id,channel_code,conversation_status_code) values('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','internal','open');
insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title) values('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','other','normal','new','History');
insert into public.service_requests(tenant_id,customer_id,service_request_type_code,service_request_status_code,title) values('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','other','requested','History');
insert into public.offline_conversions(tenant_id,customer_id,conversion_event_type_code) values('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','qualified_lead');
insert into public.customer_notes(tenant_id,customer_id,note_text) values('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','History');
insert into public.customer_identity_signals(tenant_id,customer_id,signal_type_code,signal_value) values('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','email','signal@slice11.test');
insert into public.customer_contact_methods(tenant_id,customer_id,contact_method_type_code,value,is_primary) values
('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d1','email','source@slice11.test',true),
('b1100000-0000-0000-0000-000000000001','b1100000-0000-0000-0000-0000000000d2','email','target@slice11.test',true);

select set_config('request.jwt.claims','{"sub":"b1100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select is((select outstanding_balance from app.customer_balance('b1100000-0000-0000-0000-0000000000d1')),85::numeric,'source balance is 100 - 20 + 5 before merge');
select lives_ok($q$select app.merge_customer_identity('b1100000-0000-0000-0000-0000000000d1','b1100000-0000-0000-0000-0000000000d2','duplicate identity')$q$,'authorized merge includes invoices and the complete dependent history');
select is((select outstanding_balance from app.customer_balance('b1100000-0000-0000-0000-0000000000d2')),85::numeric,'survivor balance preserves amount and currency');
reset role;
select is((select count(*)::int from public.customer_identity_merges where source_customer_id='b1100000-0000-0000-0000-0000000000d1' and target_customer_id='b1100000-0000-0000-0000-0000000000d2' and merged_by='b1100000-0000-0000-0000-000000000011'),1,'one attributed immutable merge record');
select is((select count(*)::int from public.events where tenant_id='b1100000-0000-0000-0000-000000000001' and event_type_code='customer_identity_merged'),1,'one critical merge event');
select is((select count(*)::int from public.customer_contact_methods where customer_id='b1100000-0000-0000-0000-0000000000d2'),2,'source and target contact values survive');
select is((select value from public.customer_contact_methods where customer_id='b1100000-0000-0000-0000-0000000000d2' and is_primary),'target@slice11.test','survivor primary wins');
set local role authenticated;
select throws_ok($q$select app.merge_customer_identity('b1100000-0000-0000-0000-0000000000d1','b1100000-0000-0000-0000-0000000000d2')$q$,'P0001','source customer is already archived (merged?)','merge replay is refused');
select throws_ok($q$select app.merge_customer_identity('b1100000-0000-0000-0000-0000000000d2','b1100000-0000-0000-0000-0000000000d1')$q$,'P0001','target customer is already archived','reverse merge cannot create a cycle');
select throws_ok($q$update public.invoices set customer_id='b1100000-0000-0000-0000-0000000000d3' where id='b1100000-0000-0000-0000-0000000000f1'$q$,'23514',null,'owner direct DML remains unable to move an invoice after the sanctioned merge');

select finish();
rollback;
