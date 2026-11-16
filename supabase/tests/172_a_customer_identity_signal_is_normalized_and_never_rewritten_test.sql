-- pgTAP: Batch 6 slice 53 (customer_identity_signals, CUST-13 and CUST-14) --
-- a customer identity signal is normalized and never rewritten (`20261115180100`).
-- ATTACK-CLASSES: AUTH=N/A TENANT=N/A DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
--   AUTH=N/A -- CREATE_CUSTOMER is the unchanged capability guard (tests 57, 58).
--   TENANT=N/A -- tenant isolation is the unchanged policy and composite foreign keys.
--   STATE=N/A -- a signal has no state.
--   CONCURRENCY, REPLAY=N/A -- each signal is its own row; adding one twice is two signals, as through the RPC.
--   BUSINESS=N/A -- a signal carries no money.
--   OBSERVABILITY=N/A -- signals record no event on any door, the RPC's included; the customer's creation is recorded.
create extension if not exists pgtap with schema extensions;

begin;
select plan(10);

insert into auth.users (id, email) values
  ('17200000-0000-0000-0000-0000000000a1','employee@c172.test'),
  ('17200000-0000-0000-0000-0000000000a2','owner@c172.test');
insert into public.tenants (id, name, slug, status) values
  ('17200000-0000-0000-0000-000000000001','Signal Travel','signal-travel-172','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '17200000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('17200000-0000-0000-0000-00000000000a','17200000-0000-0000-0000-000000000001','Giza','giza-172');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('17200000-0000-0000-0000-0000000000c1','17200000-0000-0000-0000-000000000001','17200000-0000-0000-0000-00000000000a','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('17200000-0000-0000-0000-000000000011','17200000-0000-0000-0000-000000000001','Employee','employee@c172.test',true,'17200000-0000-0000-0000-0000000000a1'),
  ('17200000-0000-0000-0000-000000000012','17200000-0000-0000-0000-000000000001','Owner','owner@c172.test',true,'17200000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('17200000-0000-0000-0000-000000000001','17200000-0000-0000-0000-000000000011','17200000-0000-0000-0000-00000000000a','17200000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '17200000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('17200000-0000-0000-0000-000000000011'::uuid, 'employee'), ('17200000-0000-0000-0000-000000000012', 'owner')) v(u, c)
join public.roles r on r.code = v.c;
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('17200000-0000-0000-0000-0000000000d1','17200000-0000-0000-0000-000000000001','person','Signal One'),
  ('17200000-0000-0000-0000-0000000000d2','17200000-0000-0000-0000-000000000001','person','Signal Two');

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.customer_identity_signals'::regclass and not tgisinternal
     and tgname = 'customer_identity_signals_normalize_value'),
  1, 'the normalizer is installed on customer_identity_signals');
select is(
  (select string_agg(p || '=' || has_table_privilege('authenticated', 'public.customer_identity_signals', p), ' ' order by p)
   from unnest(array['DELETE', 'INSERT', 'SELECT', 'UPDATE']) p),
  'DELETE=false INSERT=true SELECT=true UPDATE=false', 'CUST-13: authenticated may add and read a signal, never rewrite or delete one');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17200000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

select lives_ok(
  $$insert into public.customer_identity_signals (id, tenant_id, customer_id, signal_type_code, signal_value) values
    ('17200000-0000-0000-0000-0000000000e1','17200000-0000-0000-0000-000000000001','17200000-0000-0000-0000-0000000000d2','phone','+20 100 765 4321'),
    ('17200000-0000-0000-0000-0000000000e2','17200000-0000-0000-0000-000000000001','17200000-0000-0000-0000-0000000000d2','email','Two@CB.test')$$,
  'an employee adds a raw phone and a mixed-case email at the table door');
select is(
  (select string_agg(signal_type_code || ':' || signal_value, ',' order by signal_type_code)
   from public.customer_identity_signals where customer_id = '17200000-0000-0000-0000-0000000000d2'),
  'email:two@cb.test,phone:+201007654321', 'CUST-14: the door stores each value as the duplicate reader compares it');
select is(
  (select string_agg(matched_signal_type, ',' order by matched_signal_type)
   from app.find_customer_duplicates(p_phone => '+201007654321', p_email => 'two@cb.test')
   where customer_id = '17200000-0000-0000-0000-0000000000d2'),
  'email,phone', 'CUST-14: the duplicate check finds the customer by both');
select throws_ok(
  $$insert into public.customer_identity_signals (tenant_id, customer_id, signal_type_code, signal_value)
    values ('17200000-0000-0000-0000-000000000001','17200000-0000-0000-0000-0000000000d2','phone','( - )')$$,
  '23502', null, 'a phone that normalizes to nothing is refused, as the RPC never stores one');

select throws_ok(
  $$update public.customer_identity_signals set customer_id = '17200000-0000-0000-0000-0000000000d1'
    where id = '17200000-0000-0000-0000-0000000000e1'$$,
  '42501', null, 'CUST-13: an employee cannot move a signal to another customer');
select set_config('request.jwt.claims', '{"sub":"17200000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select throws_ok(
  $$update public.customer_identity_signals set signal_type_code = 'passport_number'
    where id = '17200000-0000-0000-0000-0000000000e2'$$,
  '42501', null, 'CUST-13: the owner at aal2 cannot turn an email signal into a passport number');

select set_config('request.jwt.claims', '{"sub":"17200000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
create temp table rpc_customer on commit drop as
select app.create_customer('person', 'RPC Three', p_primary_phone => ' +20 (100) 555-0000 ') as id;
select is(
  (select string_agg(signal_type_code || ':' || signal_value, ',') from public.customer_identity_signals
   where customer_id = (select id from rpc_customer)),
  'phone:+201005550000', 'the RPC still seeds its normalized signal');

reset role;
select is(
  (select string_agg(signal_type_code || ':' || signal_value, ',' order by signal_type_code)
   from public.customer_identity_signals where customer_id = '17200000-0000-0000-0000-0000000000d2'),
  'email:two@cb.test,phone:+201007654321', 'CUST-13: both signals stay on the customer they were added to');

select * from finish();
rollback;
