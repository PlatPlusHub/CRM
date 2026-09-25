-- ATTACK-CLASSES: AUTH DOOR PRIVILEGE BUSINESS TENANT=N/A STATE=N/A INPUT=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
-- SPEC-221 / PAY-2. A visible payment's economic fields require RECORD_PAYMENT on UPDATE.
-- Every refusal names the guard's own message: RLS WITH CHECK also raises 42501, so the
-- SQLSTATE alone cannot say which authority refused. The mutation below restores the old
-- amount-only mapping, proves the same employee's direction, customer and currency rewrites
-- land and move real balances, then restores the installed function exactly.
-- OBSERVABILITY=N/A: direct-creation events are PAY-3, separately open and not this repair.
create extension if not exists pgtap with schema extensions;

begin;
select plan(33);

insert into auth.users (id,email,email_confirmed_at) values
  ('12600000-0000-0000-0000-0000000000a1','owner@pay126.test',now()),
  ('12600000-0000-0000-0000-0000000000a2','employee@pay126.test',now());
insert into public.tenants (id,name,slug,status) values
  ('12600000-0000-0000-0000-000000000001','PAY126 Travel','pay126-travel','active');
insert into public.subscriptions (tenant_id,subscription_plan_id,subscription_status_code)
select '12600000-0000-0000-0000-000000000001',id,'active'
from public.subscription_plans where plan_code='enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('12600000-0000-0000-0000-00000000000a','12600000-0000-0000-0000-000000000001','Main','pay126-main');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('12600000-0000-0000-0000-0000000000c1','12600000-0000-0000-0000-000000000001',
   '12600000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('12600000-0000-0000-0000-000000000011','12600000-0000-0000-0000-000000000001','Owner','owner@pay126.test',true,'12600000-0000-0000-0000-0000000000a1'),
  ('12600000-0000-0000-0000-000000000012','12600000-0000-0000-0000-000000000001','Employee','employee@pay126.test',true,'12600000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary) values
  ('12600000-0000-0000-0000-000000000001','12600000-0000-0000-0000-000000000011','12600000-0000-0000-0000-00000000000a','12600000-0000-0000-0000-0000000000c1',true),
  ('12600000-0000-0000-0000-000000000001','12600000-0000-0000-0000-000000000012','12600000-0000-0000-0000-00000000000a','12600000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '12600000-0000-0000-0000-000000000001',v.user_id,r.id,'tenant'
from (values
  ('12600000-0000-0000-0000-000000000011'::uuid,'owner'),
  ('12600000-0000-0000-0000-000000000012'::uuid,'employee')) v(user_id,role_code)
join public.roles r on r.code=v.role_code;
-- Make the employee's payment visible independently of its booking fields, so a refusal
-- after changing booking_id or customer_id cannot be credited to RLS losing visibility.
insert into public.user_permission_grants (tenant_id,user_id,permission_id,effect,reason)
select '12600000-0000-0000-0000-000000000001','12600000-0000-0000-0000-000000000012',id,'grant','PAY-2 visibility control'
from public.permissions where key='VIEW_FINANCIAL_DOCUMENTS';
insert into public.customers (id,tenant_id,customer_type_code,full_name) values
  ('12600000-0000-0000-0000-0000000000d1','12600000-0000-0000-0000-000000000001','person','Payer'),
  ('12600000-0000-0000-0000-0000000000d2','12600000-0000-0000-0000-000000000001','person','FX Payer');
insert into public.suppliers (id,tenant_id,name,supplier_type_code) values
  ('12600000-0000-0000-0000-0000000000e1','12600000-0000-0000-0000-000000000001','Supplier','airline');
insert into public.bookings (id,tenant_id,branch_id,department_id,customer_id,booking_status_code,title,booking_reference,owner_user_id) values
  ('12600000-0000-0000-0000-0000000000b1','12600000-0000-0000-0000-000000000001','12600000-0000-0000-0000-00000000000a',
   '12600000-0000-0000-0000-0000000000c1','12600000-0000-0000-0000-0000000000d1','confirmed','Booking','PAY126-BOOK',
   '12600000-0000-0000-0000-000000000012');
insert into public.booking_items (id,tenant_id,booking_id,service_type_code,base_status_code,currency_code,owner_user_id) values
  ('12600000-0000-0000-0000-0000000000b2','12600000-0000-0000-0000-000000000001','12600000-0000-0000-0000-0000000000b1',
   'flight_ticket','confirmed','EGP','12600000-0000-0000-0000-000000000012');
insert into public.financial_accounts (id,tenant_id,financial_account_type_code,name,currency_code) values
  ('12600000-0000-0000-0000-0000000000f1','12600000-0000-0000-0000-000000000001','bank','EGP Bank','EGP'),
  ('12600000-0000-0000-0000-0000000000f2','12600000-0000-0000-0000-000000000001','bank','USD Bank','USD');
insert into public.exchange_rates (id,tenant_id,from_currency_code,to_currency_code,rate,effective_at) values
  ('12600000-0000-0000-0000-0000000000f3','12600000-0000-0000-0000-000000000001','EGP','USD',0.0200,now()-interval '2 days'),
  ('12600000-0000-0000-0000-0000000000f4','12600000-0000-0000-0000-000000000001','EGP','USD',0.0210,now()-interval '1 day');
insert into public.payments (id,tenant_id,payment_direction_code,customer_id,booking_id,currency_code,payment_method_code,amount) values
  ('12600000-0000-0000-0000-0000000000a3','12600000-0000-0000-0000-000000000001','customer_payment',
   '12600000-0000-0000-0000-0000000000d1','12600000-0000-0000-0000-0000000000b1','EGP','cash',100);
insert into public.payments (id,tenant_id,payment_direction_code,customer_id,financial_account_id,exchange_rate_id,currency_code,payment_method_code,amount) values
  ('12600000-0000-0000-0000-0000000000a4','12600000-0000-0000-0000-000000000001','customer_payment',
   '12600000-0000-0000-0000-0000000000d2','12600000-0000-0000-0000-0000000000f2','12600000-0000-0000-0000-0000000000f3','EGP','cash',100);

select set_config('request.jwt.claims','{"sub":"12600000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select ok(app.has_permission('VIEW_FINANCIAL_DOCUMENTS') and not app.has_permission('RECORD_PAYMENT'),
  'employee has payment read capability but not RECORD_PAYMENT');
select is((select count(*) from public.payments where id='12600000-0000-0000-0000-0000000000a3'),1::bigint,
  'employee can see the exact payment row before any UPDATE');
select is((select paid_amount from app.customer_balance('12600000-0000-0000-0000-0000000000d1') where currency_code='EGP'),
  100::numeric,'nonempty baseline: the customer has 100 EGP paid');
select throws_ok($$update public.payments set payment_direction_code='customer_refund' where id='12600000-0000-0000-0000-0000000000a3'$$,
  '42501','permission denied: RECORD_PAYMENT','direction rewrite requires RECORD_PAYMENT');
select throws_ok($$update public.payments set customer_id=null where id='12600000-0000-0000-0000-0000000000a3'$$,
  '42501','permission denied: RECORD_PAYMENT','customer reassignment requires RECORD_PAYMENT');
select throws_ok($$update public.payments set supplier_id='12600000-0000-0000-0000-0000000000e1' where id='12600000-0000-0000-0000-0000000000a3'$$,
  '42501','permission denied: RECORD_PAYMENT','supplier reassignment requires RECORD_PAYMENT');
select throws_ok($$update public.payments set booking_id=null where id='12600000-0000-0000-0000-0000000000a3'$$,
  '42501','permission denied: RECORD_PAYMENT','booking reassignment requires RECORD_PAYMENT');
select throws_ok($$update public.payments set booking_item_id='12600000-0000-0000-0000-0000000000b2' where id='12600000-0000-0000-0000-0000000000a3'$$,
  '42501','permission denied: RECORD_PAYMENT','item attribution requires RECORD_PAYMENT');
select throws_ok($$update public.payments set financial_account_id='12600000-0000-0000-0000-0000000000f1' where id='12600000-0000-0000-0000-0000000000a3'$$,
  '42501','permission denied: RECORD_PAYMENT','bank posting requires RECORD_PAYMENT');
select throws_ok($$update public.payments set currency_code='USD' where id='12600000-0000-0000-0000-0000000000a3'$$,
  '42501','permission denied: RECORD_PAYMENT','denomination rewrite requires RECORD_PAYMENT');
select throws_ok($$update public.payments set payment_method_code='bank_transfer' where id='12600000-0000-0000-0000-0000000000a3'$$,
  '42501','permission denied: RECORD_PAYMENT','payment method rewrite requires RECORD_PAYMENT');
select throws_ok($$update public.payments set paid_at=paid_at-interval '1 day' where id='12600000-0000-0000-0000-0000000000a3'$$,
  '42501','permission denied: RECORD_PAYMENT','paid-time rewrite requires RECORD_PAYMENT');
select throws_ok($$update public.payments set exchange_rate_id='12600000-0000-0000-0000-0000000000f4' where id='12600000-0000-0000-0000-0000000000a4'$$,
  '42501','permission denied: RECORD_PAYMENT','rate-evidence rewrite requires RECORD_PAYMENT');
select throws_ok($$update public.payments set amount=101 where id='12600000-0000-0000-0000-0000000000a3'$$,
  '42501','permission denied: RECORD_PAYMENT','existing amount mapping still refuses the same employee');
select is(array[(select paid_amount from app.customer_balance('12600000-0000-0000-0000-0000000000d1') where currency_code='EGP'),
                 (select paid_amount from app.customer_balance('12600000-0000-0000-0000-0000000000d2') where currency_code='EGP')],
  array[100,100]::numeric[],'refused economic changes leave both customers'' paid balances unchanged');
-- Assigning a guarded field its own value is not a change and acquires no capability requirement.
select lives_ok($$update public.payments set reference_number='NOTE-1', payment_direction_code=payment_direction_code,
                  customer_id=customer_id, currency_code=currency_code where id='12600000-0000-0000-0000-0000000000a3'$$,
  'reference-only metadata UPDATE remains available');
select is((select reference_number from public.payments where id='12600000-0000-0000-0000-0000000000a3'),
  'NOTE-1','reference edit changed exactly the visible payment');

reset role;
select set_config('request.jwt.claims','{"sub":"12600000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select ok(app.has_permission('RECORD_PAYMENT'),'owner genuinely holds RECORD_PAYMENT');
select lives_ok($$update public.payments set amount=101 where id='12600000-0000-0000-0000-0000000000a3'$$,
  'authorized preverification amount correction still lands');
select is((select amount from public.payments where id='12600000-0000-0000-0000-0000000000a3'),
  101::numeric,'owner changed the nonempty payment');
reset role;
select set_config('request.jwt.claims',null,true);
select lives_ok($$update public.payments set reference_number='SYSTEM-1', payment_method_code='bank_transfer'
                  where id='12600000-0000-0000-0000-0000000000a3'$$,
  'session-less system update of a newly guarded field remains available');
select is((select payment_method_code from public.payments where id='12600000-0000-0000-0000-0000000000a3'),
  'bank_transfer','the session-less path changed the guarded field, so the null-session exemption is live');
select is((select count(*)::int from pg_trigger where tgrelid='public.payments'::regclass and not tgisinternal),
  9,'the installed payment trigger inventory remains unchanged');
select ok(position('when ''payment_allocations'' then array[''allocated_amount'']' in pg_get_functiondef('app.guard_financial_capability()'::regprocedure))>0,
  'another financial surface retains its old mapping');

-- Install the old amount-only payments mapping as a live mutant, inspect it, attack it,
-- restore the original function, and verify byte-identical pg_get_functiondef output.
create temporary table pay126_original as
select pg_get_functiondef('app.guard_financial_capability()'::regprocedure) as definition,
       md5(pg_get_functiondef('app.guard_financial_capability()'::regprocedure)) as digest;
do $mutation$
declare v text; p integer; q integer;
begin
  select definition into v from pay126_original;
  p:=strpos(v,'when ''payments''            then array[''amount'', ''payment_direction_code''');
  q:=strpos(v,'when ''payment_allocations'' then array[''allocated_amount'']');
  if p=0 or q<=p then raise exception 'HARNESS ERROR: mutation anchors absent'; end if;
  v:=substring(v from 1 for p-1)
     || 'when ''payments''            then array[''amount'']' || E'\n                  '
     || substring(v from q);
  execute v;
end
$mutation$;
select ok(position('when ''payments''            then array[''amount'']' in pg_get_functiondef('app.guard_financial_capability()'::regprocedure))>0
       and position('''payment_direction_code''' in pg_get_functiondef('app.guard_financial_capability()'::regprocedure))=0,
  'mutation installed: amount remains mapped and the new payment fields are absent');
select set_config('request.jwt.claims','{"sub":"12600000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
-- With no remaining EGP contribution customer_balance returns no EGP row, so absence reads as 0.
select lives_ok($$update public.payments set payment_direction_code='customer_refund' where id='12600000-0000-0000-0000-0000000000a3'$$,
  'mutation survives: same employee now reclassifies the same payment');
select is(coalesce((select paid_amount from app.customer_balance('12600000-0000-0000-0000-0000000000d1') where currency_code='EGP'),0),
  0::numeric,'mutated direction rewrite removes the 101 EGP the customer had paid');
select lives_ok($$update public.payments set customer_id=null where id='12600000-0000-0000-0000-0000000000a4'$$,
  'mutation survives: same employee now detaches a payment from its customer');
select is(coalesce((select paid_amount from app.customer_balance('12600000-0000-0000-0000-0000000000d2') where currency_code='EGP'),0),
  0::numeric,'mutated customer rewrite removes the 100 EGP the second customer had paid');
select lives_ok($$update public.payments set currency_code='USD' where id='12600000-0000-0000-0000-0000000000a3'$$,
  'mutation survives: same employee now rewrites the denomination');
select is((select array[a3.payment_direction_code, a3.currency_code, coalesce(a4.customer_id::text,'<null>')]
           from public.payments a3, public.payments a4
           where a3.id='12600000-0000-0000-0000-0000000000a3' and a4.id='12600000-0000-0000-0000-0000000000a4'),
  array['customer_refund','USD','<null>'],'all three unauthorized rewrites persisted under the mutant');
reset role;
do $restore$
declare v text;
begin
  select definition into v from pay126_original;
  execute v;
end
$restore$;
select is(md5(pg_get_functiondef('app.guard_financial_capability()'::regprocedure)),
  (select digest from pay126_original),'original installed function restored exactly');
select set_config('request.jwt.claims','{"sub":"12600000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select throws_ok($$update public.payments set payment_direction_code='customer_payment' where id='12600000-0000-0000-0000-0000000000a3'$$,
  '42501','permission denied: RECORD_PAYMENT','restored mapping again refuses the unauthorized reclassification');

select finish();
rollback;
