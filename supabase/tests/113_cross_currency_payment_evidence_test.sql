-- pgTAP: FA-2 -- a financial account may receive a foreign-currency payment, but never silently.
--
-- OWNER DECISION, 2026-09-09. Same-currency posting proceeds normally; cross-currency posting must
-- carry explicit conversion evidence, and that evidence is a reference into the FX model ORVION
-- already has (`public.exchange_rates`, the shape `booking_items.exchange_rate_id` established) --
-- no second FX model was introduced.
--
-- The reachable door for posting into a financial account is the TABLE door: `app.record_payment`
-- never sets `financial_account_id` (it pays an invoice), so a rule enforced only inside that RPC
-- would enforce nothing at all here. This file therefore attacks the table door, as the RLS/grant
-- model actually exposes it, and separately proves the RPC path is undisturbed.
create extension if not exists pgtap with schema extensions;

begin;
select plan(20);

insert into auth.users (id, email) values ('fa200000-0000-0000-0000-0000000000a1','fin@fa2.test');
insert into public.tenants (id, name, slug, status) values
  ('fa200000-0000-0000-0000-000000000001','FA2 Travel','fa2-travel','active'),
  ('fa200000-0000-0000-0000-000000000002','FA2 Other','fa2-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.subscription_plans sp
cross join (values ('fa200000-0000-0000-0000-000000000001'::uuid),('fa200000-0000-0000-0000-000000000002'::uuid)) t(id)
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('fa200000-0000-0000-0000-00000000000a','fa200000-0000-0000-0000-000000000001','Cairo','fa2-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('fa200000-0000-0000-0000-0000000000c1','fa200000-0000-0000-0000-000000000001','fa200000-0000-0000-0000-00000000000a','finance','Finance');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('fa200000-0000-0000-0000-000000000011','fa200000-0000-0000-0000-000000000001','Fin','fin@fa2.test',true,'fa200000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('fa200000-0000-0000-0000-000000000001','fa200000-0000-0000-0000-000000000011','fa200000-0000-0000-0000-00000000000a','fa200000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'fa200000-0000-0000-0000-000000000001','fa200000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'finance_manager';
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('fa200000-0000-0000-0000-0000000000d1','fa200000-0000-0000-0000-000000000001','person','Payer');

-- A USD bank account, and an EGP one, in the same tenant.
insert into public.financial_accounts (id, tenant_id, financial_account_type_code, name, currency_code) values
  ('fa200000-0000-0000-0000-0000000000f1','fa200000-0000-0000-0000-000000000001','bank','USD Bank','USD'),
  ('fa200000-0000-0000-0000-0000000000f2','fa200000-0000-0000-0000-000000000001','bank','EGP Bank','EGP');

-- The tenant's own EGP -> USD rate, and a decoy for an unrelated pair.
insert into public.exchange_rates (id, tenant_id, from_currency_code, to_currency_code, rate, effective_at) values
  ('fa200000-0000-0000-0000-0000000000e1','fa200000-0000-0000-0000-000000000001','EGP','USD',0.0200,now() - interval '1 day'),
  ('fa200000-0000-0000-0000-0000000000e2','fa200000-0000-0000-0000-000000000001','USD','EGP',50.0000,now() - interval '1 day');
-- Another tenant's rate, for the cross-tenant assertion.
insert into public.exchange_rates (id, tenant_id, from_currency_code, to_currency_code, rate, effective_at) values
  ('fa200000-0000-0000-0000-0000000000e9','fa200000-0000-0000-0000-000000000002','EGP','USD',0.0200,now() - interval '1 day');

-- =============================================================================================
-- 1-3. THE FX MODEL'S NUMERIC FLOOR -- where it actually lives, which is the column type.
-- =============================================================================================
select is(
  (select format_type(a.atttypid, a.atttypmod) from pg_attribute a
    where a.attrelid = 'public.exchange_rates'::regclass and a.attname = 'rate'),
  'numeric(18,8)',
  'THE INFINITE-RATE QUESTION, PINNED WHERE IT IS ACTUALLY ANSWERED: rate > 0 is TRUE for Infinity and the NaN check does not exclude it, so on inspection an infinite rate looked storable -- it is not, because the column is a CONSTRAINED numeric. No redundant CHECK was added for it; widening this type to bare numeric would reopen the hole and must fail here.');

select throws_ok(
  $q$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
     values ('fa200000-0000-0000-0000-000000000001','EGP','USD','Infinity',now())$q$,
  '22003', NULL,
  'MEASURED, NOT ASSUMED: an infinite rate is refused with 22003 numeric field overflow -- by the column type, before any CHECK is evaluated. This is why no finite-rate constraint was shipped.');

select lives_ok(
  $q$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
     values ('fa200000-0000-0000-0000-000000000001','EGP','GBP',0.0150,now())$q$,
  'POSITIVE CONTROL: an ordinary finite rate still stores -- the overflow above is the extreme case, not the normal one');

-- =============================================================================================
-- 4-7. SAME CURRENCY: the ordinary path is untouched, and a rate on it is a contradiction.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"fa200000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('RECORD_PAYMENT'),
  'POSITIVE CONTROL: the actor genuinely holds RECORD_PAYMENT, so every refusal below is about currency and not about authority');

select lives_ok(
  $q$insert into public.payments (id, tenant_id, payment_direction_code, customer_id, financial_account_id,
                                  payment_method_code, currency_code, amount)
     values ('fa200000-0000-0000-0000-0000000000b1','fa200000-0000-0000-0000-000000000001','customer_payment',
             'fa200000-0000-0000-0000-0000000000d1','fa200000-0000-0000-0000-0000000000f2','cash','EGP',1000)$q$,
  'THE ONE THAT MATTERS: an EGP payment into the EGP account still posts -- FA-2 must not make ordinary same-currency work harder');

select is(
  (select account_currency_code || '/' || account_amount::text || '/' || coalesce(exchange_rate_id::text,'none')
     from public.payments where id = 'fa200000-0000-0000-0000-0000000000b1'),
  'EGP/1000.0000/none',
  '...and the row carries the account currency and the account-currency value, both server-derived, with no rate attached');

select throws_ok(
  $q$insert into public.payments (tenant_id, payment_direction_code, customer_id, financial_account_id,
                                  payment_method_code, currency_code, amount, exchange_rate_id)
     values ('fa200000-0000-0000-0000-000000000001','customer_payment','fa200000-0000-0000-0000-0000000000d1',
             'fa200000-0000-0000-0000-0000000000f2','cash','EGP',1000,'fa200000-0000-0000-0000-0000000000e1')$q$,
  '23514', NULL,
  'a rate attached to a SAME-currency posting is refused: no conversion applies, so the evidence would describe something that did not happen');

-- =============================================================================================
-- 8-13. CROSS CURRENCY: permitted, but only with evidence that actually explains the posting.
-- =============================================================================================
select throws_ok(
  $q$insert into public.payments (tenant_id, payment_direction_code, customer_id, financial_account_id,
                                  payment_method_code, currency_code, amount)
     values ('fa200000-0000-0000-0000-000000000001','customer_payment','fa200000-0000-0000-0000-0000000000d1',
             'fa200000-0000-0000-0000-0000000000f1','cash','EGP',5000)$q$,
  '23514', NULL,
  'THE REPRODUCTION, CLOSED: an EGP payment into the USD account with no conversion evidence is refused -- before FA-2 this row simply asserted that a USD account received 5,000 of something');

select throws_ok(
  $q$insert into public.payments (tenant_id, payment_direction_code, customer_id, financial_account_id,
                                  payment_method_code, currency_code, amount, exchange_rate_id)
     values ('fa200000-0000-0000-0000-000000000001','customer_payment','fa200000-0000-0000-0000-0000000000d1',
             'fa200000-0000-0000-0000-0000000000f1','cash','EGP',5000,'fa200000-0000-0000-0000-0000000000e2')$q$,
  '23514', NULL,
  'A RATE IS NOT ENOUGH -- IT MUST BE THE RIGHT ONE: the USD->EGP row is refused for an EGP->USD posting, so evidence cannot be satisfied by attaching any rate the caller happens to hold');

select throws_ok(
  $q$insert into public.payments (tenant_id, payment_direction_code, customer_id, financial_account_id,
                                  payment_method_code, currency_code, amount, exchange_rate_id)
     values ('fa200000-0000-0000-0000-000000000001','customer_payment','fa200000-0000-0000-0000-0000000000d1',
             'fa200000-0000-0000-0000-0000000000f1','cash','EGP',5000,'fa200000-0000-0000-0000-0000000000e9')$q$,
  '23514', NULL,
  'TENANT BOUNDARY: another tenant''s EGP->USD rate -- the correct PAIR -- cannot be borrowed as evidence. The BEFORE trigger''s own tenant-qualified lookup refuses it first, so the composite foreign key behind it never has to.');

select lives_ok(
  $q$insert into public.payments (id, tenant_id, payment_direction_code, customer_id, financial_account_id,
                                  payment_method_code, currency_code, amount, exchange_rate_id, account_amount, account_currency_code)
     values ('fa200000-0000-0000-0000-0000000000b2','fa200000-0000-0000-0000-000000000001','customer_payment',
             'fa200000-0000-0000-0000-0000000000d1','fa200000-0000-0000-0000-0000000000f1','cash','EGP',5000,
             'fa200000-0000-0000-0000-0000000000e1', 999999, 'JPY')$q$,
  'THE AUTHORIZED CROSS-CURRENCY PATH: with the correct rate attached the posting is permitted -- FA-2 does not forbid foreign-currency receipts, it forbids silent ones');

select is(
  (select currency_code || ' ' || amount::text || ' -> ' || account_currency_code || ' ' || account_amount::text
     from public.payments where id = 'fa200000-0000-0000-0000-0000000000b2'),
  'EGP 5000.0000 -> USD 100.0000',
  'DERIVED, NOT ACCEPTED: the caller sent account_amount 999999 and account_currency_code JPY, and both were discarded and recomputed from the rate (5000 * 0.02 = 100 USD)');

select is(
  (select er.rate::text || ' @ ' || (er.effective_at is not null)::text
     from public.payments p join public.exchange_rates er on er.id = p.exchange_rate_id
    where p.id = 'fa200000-0000-0000-0000-0000000000b2'),
  '0.02000000 @ true',
  'THE EVIDENCE IS REACHABLE: original amount, original currency, account currency, the rate, its instant and its source all resolve from the stored row');

-- =============================================================================================
-- 14-15. NO ACCOUNT, NO CONVERSION -- and the RPC path is undisturbed.
-- =============================================================================================
select throws_ok(
  $q$insert into public.payments (tenant_id, payment_direction_code, customer_id,
                                  payment_method_code, currency_code, amount, exchange_rate_id)
     values ('fa200000-0000-0000-0000-000000000001','customer_payment','fa200000-0000-0000-0000-0000000000d1',
             'cash','EGP',100,'fa200000-0000-0000-0000-0000000000e1')$q$,
  '23514', NULL,
  'a payment posted to NO account cannot claim a conversion: there is no account currency to convert into');

select lives_ok(
  $q$insert into public.payments (id, tenant_id, payment_direction_code, customer_id,
                                  payment_method_code, currency_code, amount)
     values ('fa200000-0000-0000-0000-0000000000b3','fa200000-0000-0000-0000-000000000001','customer_payment',
             'fa200000-0000-0000-0000-0000000000d1','cash','EGP',100)$q$,
  'THE RPC PATH IS UNDISTURBED: app.record_payment never sets financial_account_id, and a payment shaped the way it writes one still posts with no conversion fields at all');

-- =============================================================================================
-- 16-17. HISTORICAL CONVERSION FACTS SURVIVE FINANCIAL FINALISATION.
-- =============================================================================================
reset role;
update public.payments set verified_at = now(), verified_by = 'fa200000-0000-0000-0000-000000000011'
 where id = 'fa200000-0000-0000-0000-0000000000b2';
set local role authenticated;

select throws_ok(
  $q$update public.payments set amount = 9999 where id = 'fa200000-0000-0000-0000-0000000000b2'$q$,
  '23514', NULL,
  'after verification the money itself is history and cannot be rewritten in place');

select throws_ok(
  $q$update public.payments set exchange_rate_id = 'fa200000-0000-0000-0000-0000000000e2'
      where id = 'fa200000-0000-0000-0000-0000000000b2'$q$,
  '23514', NULL,
  '...and so is the conversion that produced the account-currency figure -- a correction after verification is a new record, not an edit');

-- =============================================================================================
-- 18. NO SECOND FX MODEL.
-- =============================================================================================
reset role;
select is(
  (select count(*)::int from information_schema.columns
    where table_schema = 'public' and table_name = 'payments'
      and column_name in ('exchange_rate','fx_rate','conversion_rate','rate')),
  0,
  'NO SECOND FX MODEL: payments stores a REFERENCE to public.exchange_rates -- the shape booking_items.exchange_rate_id already established -- and no rate column of its own');

-- =============================================================================================
-- 19-20. LOAD-BEARING (PAR-4 defect injection).
-- =============================================================================================
savepoint before_enforcer_mutation;
drop trigger payments_guard_currency_conversion on public.payments;

insert into public.payments (id, tenant_id, payment_direction_code, customer_id, financial_account_id,
                             payment_method_code, currency_code, amount)
values ('fa200000-0000-0000-0000-0000000000b9','fa200000-0000-0000-0000-000000000001','customer_payment',
        'fa200000-0000-0000-0000-0000000000d1','fa200000-0000-0000-0000-0000000000f1','cash','EGP',5000);

select is(
  (select currency_code || '/' || coalesce(account_currency_code,'none') || '/' || coalesce(account_amount::text,'none')
     from public.payments where id = 'fa200000-0000-0000-0000-0000000000b9'),
  'EGP/none/none',
  'MUTATION: with the named trigger dropped the identical EGP-into-USD posting SUCCEEDS and records no conversion at all -- which is FA-2 exactly, so that trigger is what closes it');

rollback to savepoint before_enforcer_mutation;

select throws_ok(
  $q$insert into public.payments (tenant_id, payment_direction_code, customer_id, financial_account_id,
                                  payment_method_code, currency_code, amount)
     values ('fa200000-0000-0000-0000-000000000001','customer_payment','fa200000-0000-0000-0000-0000000000d1',
             'fa200000-0000-0000-0000-0000000000f1','cash','EGP',5000)$q$,
  '23514', NULL,
  'RESTORED: with the trigger back the identical posting is refused again');

select finish();
rollback;
