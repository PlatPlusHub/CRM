-- pgTAP: Batch 6 slice 51 (exchange_rates) --
-- an exchange rate is set only with step-up, a rate that money cites keeps its meaning, and every set is recorded
-- (`20261114120000`).
-- ATTACK-CLASSES: AUTH TENANT=N/A DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY
--   TENANT=N/A -- tenant isolation is the unchanged scope_read and scope_insert policies (tests 26, 101).
--   STATE=N/A -- a rate has no lifecycle; its only change is a rewrite, which is checked and recorded here.
--   CONCURRENCY=N/A -- the citation check reads committed rows; a rate is cited only after it exists.
--   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

insert into auth.users (id, email) values
  ('16600000-0000-0000-0000-0000000000a1','finance@c166.test'),
  ('16600000-0000-0000-0000-0000000000a2','employee@c166.test');
insert into public.tenants (id, name, slug, status) values
  ('16600000-0000-0000-0000-000000000001','Rate Travel','rate-travel-166','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '16600000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('16600000-0000-0000-0000-00000000000a','16600000-0000-0000-0000-000000000001','Giza','giza-166');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('16600000-0000-0000-0000-0000000000c1','16600000-0000-0000-0000-000000000001','16600000-0000-0000-0000-00000000000a','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('16600000-0000-0000-0000-000000000011','16600000-0000-0000-0000-000000000001','Finance','finance@c166.test',true,'16600000-0000-0000-0000-0000000000a1'),
  ('16600000-0000-0000-0000-000000000012','16600000-0000-0000-0000-000000000001','Employee','employee@c166.test',true,'16600000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('16600000-0000-0000-0000-000000000001','16600000-0000-0000-0000-000000000011','16600000-0000-0000-0000-00000000000a','16600000-0000-0000-0000-0000000000c1',true),
  ('16600000-0000-0000-0000-000000000001','16600000-0000-0000-0000-000000000012','16600000-0000-0000-0000-00000000000a','16600000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '16600000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('16600000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
             ('16600000-0000-0000-0000-000000000012','employee')) v(uid, role_code)
join public.roles r on r.code = v.role_code;
-- R1 is cited by a booking item; R2 is cited by nothing.
insert into public.exchange_rates (id, tenant_id, from_currency_code, to_currency_code, rate, effective_at) values
  ('16600000-0000-0000-0000-0000000000e1','16600000-0000-0000-0000-000000000001','USD','EGP',48.5,now() - interval '1 day'),
  ('16600000-0000-0000-0000-0000000000e2','16600000-0000-0000-0000-000000000001','EUR','EGP',52,now() - interval '1 day');
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('16600000-0000-0000-0000-0000000000d1','16600000-0000-0000-0000-000000000001','person','Rate Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('16600000-0000-0000-0000-0000000000f1','16600000-0000-0000-0000-000000000001','16600000-0000-0000-0000-00000000000a','16600000-0000-0000-0000-0000000000c1','16600000-0000-0000-0000-0000000000d1','16600000-0000-0000-0000-000000000012','16600000-0000-0000-0000-00000000000a','16600000-0000-0000-0000-0000000000c1','draft','Rate booking','BK-166-1');
insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code, currency_code,
                                  cost_amount, selling_amount, exchange_rate_id) values
  ('16600000-0000-0000-0000-000000000001','16600000-0000-0000-0000-0000000000f1','flight_ticket','draft','USD',100,120,'16600000-0000-0000-0000-0000000000e1');

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.exchange_rates'::regclass and not tgisinternal
     and tgname in ('exchange_rates_guard_write', 'exchange_rates_emit_set')),
  2, 'both triggers are installed on exchange_rates');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16600000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

select throws_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('16600000-0000-0000-0000-000000000001','GBP','EGP',61,now())$$,
  '42501', 'multi-factor authentication required for this role',
  'a finance manager cannot set a rate from a password-only session');

select set_config('request.jwt.claims', '{"sub":"16600000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select lives_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('16600000-0000-0000-0000-000000000001','GBP','EGP',61,now())$$,
  'a finance manager at aal2 sets a rate');

select throws_ok(
  $$update public.exchange_rates set rate = 99 where id = '16600000-0000-0000-0000-0000000000e1'$$,
  '23514', 'exchange rate 16600000-0000-0000-0000-0000000000e1 is cited by recorded money: set a new rate and record an adjustment',
  'a rate a booking item cites cannot be rewritten');

select throws_ok(
  $$update public.exchange_rates set effective_at = now() - interval '1 year', from_currency_code = 'EGP', to_currency_code = 'USD'
    where id = '16600000-0000-0000-0000-0000000000e1'$$,
  '23514', 'exchange rate 16600000-0000-0000-0000-0000000000e1 is cited by recorded money: set a new rate and record an adjustment',
  '...nor re-dated or turned around');

select lives_ok(
  $$update public.exchange_rates set rate = 53 where id = '16600000-0000-0000-0000-0000000000e2'$$,
  'a rate nothing cites may still be corrected');

select set_config('request.jwt.claims', '{"sub":"16600000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);

select throws_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('16600000-0000-0000-0000-000000000001','GBP','EGP',62,now())$$,
  '42501', 'permission denied: SET_EXCHANGE_RATE',
  'an employee without SET_EXCHANGE_RATE cannot set a rate');

reset role;
select set_config('request.jwt.claims', null, true);

select throws_ok(
  $$update public.exchange_rates set rate = 99 where id = '16600000-0000-0000-0000-0000000000e1'$$,
  '23514', 'exchange rate 16600000-0000-0000-0000-0000000000e1 is cited by recorded money: set a new rate and record an adjustment',
  'a cited rate keeps its meaning for every writer, a system writer too');

select lives_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('16600000-0000-0000-0000-000000000001','SAR','EGP',13,now())$$,
  'the guard''s one exemption: a session-less platform write sets a rate');

select is((select rate from public.exchange_rates where id = '16600000-0000-0000-0000-0000000000e1'), 48.5::numeric,
  'the cited rate is still 48.5');

select is(
  (select count(*)::int from public.events e join public.users u on u.id = e.actor_user_id
   where e.tenant_id = '16600000-0000-0000-0000-000000000001' and e.event_type_code = 'exchange_rate_set'
     and u.full_name = 'Finance' and e.payload -> 'current' ->> 'from_currency_code' = 'GBP'
     and e.payload ->> 'previous' is null and e.severity_code = 'critical'),
  1, 'the new rate is recorded once, as exchange_rate_set by its setter, at canon 27''s severity');

select is(
  (select count(*)::int from public.events e
   where e.tenant_id = '16600000-0000-0000-0000-000000000001' and e.event_type_code = 'exchange_rate_set'
     and e.entity_id = '16600000-0000-0000-0000-0000000000e2'
     and (e.payload -> 'previous' ->> 'rate')::numeric = 52 and (e.payload -> 'current' ->> 'rate')::numeric = 53),
  1, 'the correction is recorded with the previous and the current rate');

select * from finish();
rollback;
