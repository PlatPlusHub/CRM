-- pgTAP: SPEC-217 / RFD-1, RFD-2, ENTRY-1 (refunds), Batch 6 Slice 17.
-- ATTACK-CLASSES: DOOR AUTH TENANT STATE INPUT BUSINESS PRIVILEGE
-- OBSERVABILITY is excluded: RFD-3 records the separately proven event gap.
-- REPLAY and CONCURRENCY are not material: this guard reads only OLD and NEW,
-- charges a live capability, and maintains no lease or cross-row counter.
create extension if not exists pgtap with schema extensions;

begin;
select plan(28);

insert into auth.users (id, email) values
  ('12300000-0000-0000-0000-0000000000a1','finance@r123.test'),
  ('12300000-0000-0000-0000-0000000000a2','employee@r123.test');
insert into public.tenants (id, name, slug, status) values
  ('12300000-0000-0000-0000-000000000001','Refund One','r123-one','active'),
  ('12300000-0000-0000-0000-000000000002','Refund Two','r123-two','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id in ('12300000-0000-0000-0000-000000000001',
                                          '12300000-0000-0000-0000-000000000002');
insert into public.branches (id, tenant_id, name, slug) values
  ('12300000-0000-0000-0000-00000000000a','12300000-0000-0000-0000-000000000001','HQ','r123-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('12300000-0000-0000-0000-0000000000c1','12300000-0000-0000-0000-000000000001',
   '12300000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('12300000-0000-0000-0000-000000000011','12300000-0000-0000-0000-000000000001',
   'Finance','finance@r123.test',true,'12300000-0000-0000-0000-0000000000a1'),
  ('12300000-0000-0000-0000-000000000012','12300000-0000-0000-0000-000000000001',
   'Employee','employee@r123.test',true,'12300000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary) values
  ('12300000-0000-0000-0000-000000000001','12300000-0000-0000-0000-000000000011',
   '12300000-0000-0000-0000-00000000000a','12300000-0000-0000-0000-0000000000c1',true),
  ('12300000-0000-0000-0000-000000000001','12300000-0000-0000-0000-000000000012',
   '12300000-0000-0000-0000-00000000000a','12300000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '12300000-0000-0000-0000-000000000001',v.user_id,r.id,'tenant'
from (values ('12300000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
             ('12300000-0000-0000-0000-000000000012'::uuid,'employee')) v(user_id,role_code)
join public.roles r on r.code=v.role_code;
insert into public.customers (id,tenant_id,customer_type_code,full_name) values
  ('12300000-0000-0000-0000-0000000000d1','12300000-0000-0000-0000-000000000001','person','Customer One'),
  ('12300000-0000-0000-0000-0000000000d2','12300000-0000-0000-0000-000000000002','person','Customer Two');
insert into public.bookings (id,tenant_id,branch_id,department_id,customer_id,booking_status_code,title,
                             booking_reference,owner_user_id) values
  ('12300000-0000-0000-0000-0000000000b1','12300000-0000-0000-0000-000000000001',
   '12300000-0000-0000-0000-00000000000a','12300000-0000-0000-0000-0000000000c1',
   '12300000-0000-0000-0000-0000000000d1','draft','Refund booking','R123-1',
   '12300000-0000-0000-0000-000000000012');
insert into public.suppliers (id,tenant_id,supplier_type_code,name) values
  ('12300000-0000-0000-0000-0000000000e1','12300000-0000-0000-0000-000000000001','airline','Supplier One');

-- Session-less fixture: a real completed refund visible through the employee's booking.
insert into public.refunds (id,tenant_id,payment_direction_code,customer_id,booking_id,
                            refund_reason_code,currency_code,amount,refund_status_code,completed_at) values
  ('12300000-0000-0000-0000-0000000000f1','12300000-0000-0000-0000-000000000001',
   'customer_refund','12300000-0000-0000-0000-0000000000d1','12300000-0000-0000-0000-0000000000b1',
   'customer_cancelled','EGP',25000,'completed',now()),
  ('12300000-0000-0000-0000-0000000000f2','12300000-0000-0000-0000-000000000002',
   'customer_refund','12300000-0000-0000-0000-0000000000d2',null,
   'customer_cancelled','EGP',30,'completed',now());

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12300000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select ok(not app.has_permission('RECORD_REFUND'), 'employee truly lacks RECORD_REFUND');
select is((select count(*)::int from public.refunds where id='12300000-0000-0000-0000-0000000000f1'),1,
          'employee sees one real completed refund through the booking');
select is((select refunded_amount from app.customer_balance('12300000-0000-0000-0000-0000000000d1',null)),
          25000::numeric,'balance actually consumes that refund');
select throws_ok($q$update public.refunds set payment_direction_code='supplier_refund'
                   where id='12300000-0000-0000-0000-0000000000f1'$q$,
          '42501',null,'RFD-1: employee cannot remove the completed customer refund by changing direction');
select throws_ok($q$update public.refunds set currency_code='USD'
                   where id='12300000-0000-0000-0000-0000000000f1'$q$,
          '42501',null,'employee cannot redenominate the same completed refund');
select is((select refunded_amount from app.customer_balance('12300000-0000-0000-0000-0000000000d1',null)),
          25000::numeric,'refused edits leave the computed balance unchanged');
select is((select count(*)::int from public.refunds where id='12300000-0000-0000-0000-0000000000f2'),0,
          'foreign tenant refund is invisible to the employee');

reset role;
select set_config('request.jwt.claims','{"sub":"12300000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select ok(app.has_permission('RECORD_REFUND') and app.mfa_satisfied(),
          'finance has refund authority with MFA');
select lives_ok($q$select app.record_refund('12300000-0000-0000-0000-0000000000d1',17,'EGP',
                      'customer_cancelled','12300000-0000-0000-0000-0000000000b1',null)$q$,
          'RPC creates a positive requested customer refund');
select is((select count(*)::int from public.refunds where customer_id='12300000-0000-0000-0000-0000000000d1'
             and amount=17 and refund_status_code='requested' and completed_at is null),1,
          'RPC INSERT persisted in the required entry state');
select lives_ok($q$select app.advance_refund((select id from public.refunds where amount=17
                        and customer_id='12300000-0000-0000-0000-0000000000d1'),'approved');
                  select app.advance_refund((select id from public.refunds where amount=17
                        and customer_id='12300000-0000-0000-0000-0000000000d1'),'completed')$q$,
          'RPC still advances through approval to completion');
select is((select count(*)::int from public.events e join public.refunds r on r.id=e.entity_id
           where e.entity_type='refund' and r.amount=17 and r.customer_id='12300000-0000-0000-0000-0000000000d1'),
          3,'the unchanged RPCs still emit exactly three lifecycle events');
select ok((select completed_at=now() from public.refunds where amount=17
           and customer_id='12300000-0000-0000-0000-0000000000d1'),
          'RPC completion remains server-stamped');

insert into public.refunds (id,tenant_id,payment_direction_code,supplier_id,refund_reason_code,
                            currency_code,amount,refund_status_code) values
  ('12300000-0000-0000-0000-0000000000f3','12300000-0000-0000-0000-000000000001',
   'supplier_refund','12300000-0000-0000-0000-0000000000e1','supplier_cancelled','EGP',12,'requested');
select is((select count(*)::int from public.refunds where id='12300000-0000-0000-0000-0000000000f3'
           and supplier_id='12300000-0000-0000-0000-0000000000e1' and refund_status_code='requested'),
          1,'the direct supplier-refund creation path stays open');
update public.refunds set refund_status_code='approved' where id='12300000-0000-0000-0000-0000000000f3';
update public.refunds set refund_status_code='completed',completed_at='2001-01-01'
where id='12300000-0000-0000-0000-0000000000f3';
select ok((select completed_at=now() from public.refunds where id='12300000-0000-0000-0000-0000000000f3'),
          'direct legal completion derives its time instead of storing the caller-supplied time');
update public.refunds set completed_at='2002-01-01' where id='12300000-0000-0000-0000-0000000000f3';
select ok((select completed_at=now() from public.refunds where id='12300000-0000-0000-0000-0000000000f3'),
          'completion time remains immutable after the transition');
select throws_ok($q$insert into public.refunds (tenant_id,payment_direction_code,customer_id,booking_id,
                      refund_reason_code,currency_code,amount,refund_status_code) values
                    ('12300000-0000-0000-0000-000000000001','customer_refund',
                     '12300000-0000-0000-0000-0000000000d1','12300000-0000-0000-0000-0000000000b1',
                     'customer_cancelled','EGP',7,'completed')$q$,
          '23514',null,'ENTRY-1: a refund cannot be born completed');
select throws_ok($q$insert into public.refunds (tenant_id,payment_direction_code,customer_id,booking_id,
                      refund_reason_code,currency_code,amount,refund_status_code,completed_at) values
                    ('12300000-0000-0000-0000-000000000001','customer_refund',
                     '12300000-0000-0000-0000-0000000000d1','12300000-0000-0000-0000-0000000000b1',
                     'customer_cancelled','EGP',7,'requested','2001-01-01')$q$,
          '23514',null,'RFD-2: a requested refund cannot carry forged completion evidence');
select throws_ok($q$insert into public.refunds (tenant_id,payment_direction_code,customer_id,booking_id,
                      refund_reason_code,currency_code,amount,refund_status_code) values
                    ('12300000-0000-0000-0000-000000000001','customer_refund',
                     '12300000-0000-0000-0000-0000000000d1','12300000-0000-0000-0000-0000000000b1',
                     'customer_cancelled','EGP',0,'requested')$q$,
          '23514',null,'RFD-2: the table door cannot create a zero-value refund the RPC rejects');
select throws_ok($q$update public.refunds set amount=0 where id='12300000-0000-0000-0000-0000000000f3'$q$,
          '23514',null,'RFD-2: the same positive-amount rule survives UPDATE');
select is((select amount from public.refunds where id='12300000-0000-0000-0000-0000000000f3'),
          12::numeric,'the refused zero-value UPDATE left a real positive supplier refund');
select throws_ok($q$insert into public.refunds (tenant_id,payment_direction_code,customer_id,
                      refund_reason_code,currency_code,amount,refund_status_code) values
                    ('12300000-0000-0000-0000-000000000002','customer_refund',
                     '12300000-0000-0000-0000-0000000000d2','customer_cancelled','EGP',8,'requested')$q$,
          '42501',null,'tenant A finance cannot create a refund in tenant B');
select is((select count(*)::int from public.refunds where id='12300000-0000-0000-0000-0000000000f2'),0,
          'tenant A finance cannot see the foreign refund it might try to move');
select is((select created_by from public.refunds where id='12300000-0000-0000-0000-0000000000f3'),
          '12300000-0000-0000-0000-000000000011'::uuid,'created_by remains derived from the real actor');

select set_config('request.jwt.claims','{"sub":"12300000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
select throws_ok($q$update public.refunds set payment_direction_code='customer_refund'
                   where id='12300000-0000-0000-0000-0000000000f3'$q$,
          '42501',null,'the UPDATE authority also preserves the role MFA gate');
select is((select payment_direction_code from public.refunds where id='12300000-0000-0000-0000-0000000000f3'),
          'supplier_refund','MFA refusal leaves the same real supplier refund unchanged');

reset role;
select ok((select t.tgenabled='O' and t.tgtype=23 and not p.prosecdef
           from pg_trigger t join pg_proc p on p.oid=t.tgfoid
           where t.tgrelid='public.refunds'::regclass and t.tgname='refunds_guard_integrity'),
          'one enabled BEFORE INSERT OR UPDATE SECURITY INVOKER trigger guards refunds');
select ok(not has_function_privilege('authenticated','app.guard_refund_integrity()','EXECUTE'),
          'authenticated cannot call the trigger function directly');

select * from finish();
rollback;
