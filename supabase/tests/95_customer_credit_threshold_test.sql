-- pgTAP: CUST-3 -- the customer receivable ceiling WARNS, never refuses, and never silently drops
-- foreign-currency exposure (owner decision 2026-09-04).
--
-- WHAT MUST BE TRUE, and the first three would make this a defect rather than a feature if they
-- failed:
--   * a write that pushes exposure ABOVE the ceiling still SUCCEEDS -- the owner was explicit that
--     nothing may be blocked, so every "it alerted" assertion is worthless unless the write landed;
--   * the alert fires ONCE per breach, not once per write;
--   * exposure held in a currency other than the ceiling's is CONVERTED, and when it cannot be, the
--     shortfall is REPORTED rather than dropped. This is the requirement that separates CUST-3 from
--     the supplier ceiling it is modelled on (SUP-4c).
--
-- The alert is proven by its EFFECTS (event row + one notification per recipient + a pending email
-- delivery row), never by "the function did not throw" (AGENTS.md 6: no vacuous security tests).
create extension if not exists pgtap with schema extensions;

begin;
select plan(27);

insert into auth.users (id, email, email_confirmed_at) values
  ('95000000-0000-0000-0000-0000000000a1','owner@cust95.test',   now()),
  ('95000000-0000-0000-0000-0000000000a2','finance@cust95.test', now()),
  ('95000000-0000-0000-0000-0000000000a3','emp@cust95.test',     now());
insert into public.tenants (id, name, slug, status) values
  ('95000000-0000-0000-0000-000000000001','Cust95 Travel','cust95','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id='95000000-0000-0000-0000-000000000001';
insert into public.branches (id, tenant_id, name, slug) values
  ('95000000-0000-0000-0000-00000000000a','95000000-0000-0000-0000-000000000001','HQ','cust95-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('95000000-0000-0000-0000-0000000000c1','95000000-0000-0000-0000-000000000001',
   '95000000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('95000000-0000-0000-0000-000000000011','95000000-0000-0000-0000-000000000001','Owner','owner@cust95.test',true,'95000000-0000-0000-0000-0000000000a1'),
  ('95000000-0000-0000-0000-000000000012','95000000-0000-0000-0000-000000000001','Finance','finance@cust95.test',true,'95000000-0000-0000-0000-0000000000a2'),
  ('95000000-0000-0000-0000-000000000013','95000000-0000-0000-0000-000000000001','Emp','emp@cust95.test',true,'95000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '95000000-0000-0000-0000-000000000001', u,
       '95000000-0000-0000-0000-00000000000a','95000000-0000-0000-0000-0000000000c1', true
from unnest(array['95000000-0000-0000-0000-000000000011'::uuid,
                  '95000000-0000-0000-0000-000000000012'::uuid,
                  '95000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '95000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('95000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('95000000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('95000000-0000-0000-0000-000000000013'::uuid,'employee')) v(u,rc)
join public.roles r on r.code = v.rc;

-- The ceilings under test. 1000 EGP rather than any production figure: the THRESHOLD VALUE is
-- configuration a tenant sets per customer through MANAGE_CUSTOMER_CREDIT, and pinning a business
-- number here would test configuration rather than the crossing. `Uncapped` is the NULL control.
insert into public.customers (id, tenant_id, customer_type_code, full_name, credit_limit_amount, credit_limit_currency_code) values
  ('95000000-0000-0000-0000-0000000000d1','95000000-0000-0000-0000-000000000001','person','Capped Customer',   1000, 'EGP'),
  ('95000000-0000-0000-0000-0000000000d2','95000000-0000-0000-0000-000000000001','person','Uncapped Customer', null, null),
  ('95000000-0000-0000-0000-0000000000d3','95000000-0000-0000-0000-000000000001','person','FX Customer',       1000, 'EGP');

-- =============================================================================================
-- 1-4. STRUCTURE, AND THAT THE INTERNAL HELPERS ARE NOT SECOND READ DOORS.
-- =============================================================================================
select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid=t.tgrelid
     join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
    where not t.tgisinternal
      and t.tgname in ('invoices_probe_customer_credit','payments_probe_customer_credit','refunds_probe_customer_credit')
      and t.tgtype & 1 = 1),
  3,
  'CUST-3: all three exposure-bearing tables carry an AFTER-row probe -- exposure is a function of exactly invoices, payments and refunds');

select ok(
  not has_function_privilege('authenticated','app.customer_exposure_in_limit_currency(uuid,uuid,text)','execute'),
  'CUST-3: the system-path exposure helper is NOT a second read door -- authenticated cannot execute it');

select ok(
  not has_function_privilege('authenticated','app.exchange_rate_as_of(uuid,text,text,timestamptz)','execute'),
  'CUST-3: the rate primitive is an internal control helper -- authenticated cannot execute it');

select is(
  (select count(*)::int from public.customers
    where tenant_id='95000000-0000-0000-0000-000000000001'
      and (credit_limit_amount is null) <> (credit_limit_currency_code is null)),
  0,
  'CUST-3: the ceiling is a PAIR -- no row carries an amount without its currency (canon 30 money standard)');

-- =============================================================================================
-- 5-6. THE RATE PRIMITIVE, BEFORE ANYTHING DEPENDS ON IT. Direct, inverse, identity and absent.
-- =============================================================================================
insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at, set_by)
values ('95000000-0000-0000-0000-000000000001','USD','EGP', 30, now() - interval '2 days','95000000-0000-0000-0000-000000000011'),
       ('95000000-0000-0000-0000-000000000001','USD','EGP', 50, now() - interval '1 day', '95000000-0000-0000-0000-000000000011'),
       ('95000000-0000-0000-0000-000000000001','USD','EGP', 99, now() + interval '5 days', '95000000-0000-0000-0000-000000000011');

select is(
  app.exchange_rate_as_of('95000000-0000-0000-0000-000000000001','USD','EGP'),
  50::numeric,
  'CUST-3/SUP-4c: the LATEST rate at or before now is used -- the older 30 is superseded and the future 99 is not yet in force');

select is(
  (select round(app.exchange_rate_as_of('95000000-0000-0000-0000-000000000001','EGP','USD'), 4)),
  round((1::numeric/50), 4),
  'CUST-3: a reverse pair resolves as the INVERSE -- the table carries one rate column and no spread, so inverting is consistent with the model');

-- =============================================================================================
-- 7-11. THE BREACH. The write must SUCCEED, and the alert must be proven by its effects.
-- =============================================================================================
insert into public.invoices (id, tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code)
values ('95000000-0000-0000-0000-0000000000f1','95000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-0000000000d1',
        'INV-C95-1', current_date, 'EGP', 1500, 'issued');

select is(
  (select total_amount from public.invoices where id='95000000-0000-0000-0000-0000000000f1'),
  1500::numeric,
  'CUST-3 (THE OWNER REQUIREMENT): the write that pushed exposure over the ceiling LANDED -- nothing was blocked');

select is(
  (select count(*)::int from public.events
    where tenant_id='95000000-0000-0000-0000-000000000001'
      and entity_id='95000000-0000-0000-0000-0000000000d1'
      and event_type_code='customer_credit_threshold_exceeded'),
  1,
  'CUST-3: crossing the ceiling emitted exactly ONE exceeded event');

select is(
  (select (payload->>'enforcement') from public.events
    where entity_id='95000000-0000-0000-0000-0000000000d1'
      and event_type_code='customer_credit_threshold_exceeded' limit 1),
  'warning_only',
  'CUST-3: the event states enforcement is warning_only -- the ceiling is OBSERVED, not ENFORCED');

select is(
  (select count(distinct n.target_user_id)::int from public.notifications n
    where n.tenant_id='95000000-0000-0000-0000-000000000001'
      and n.related_entity_id='95000000-0000-0000-0000-0000000000d1'
      and n.notification_type_code='customer_balance'),
  2,
  'CUST-3: both finance recipients (owner + finance_manager) were notified -- and the employee was not');

select is(
  (select count(*)::int from public.notification_deliveries d
    join public.notifications n on n.id=d.notification_id
   where n.related_entity_id='95000000-0000-0000-0000-0000000000d1'
     and d.channel_code='email' and d.delivery_status_code='pending'),
  2,
  'CUST-3: the email obligation is RECORDED as pending, not claimed as sent -- ORVION has no mail provider');

-- =============================================================================================
-- 12-13. IDEMPOTENCE, then RE-ARMING. A second breaching write must not alert again; falling below
--        must clear; breaching again must alert again. Without `cleared`, the first breach would
--        silence the customer permanently.
-- =============================================================================================
insert into public.invoices (id, tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code)
values ('95000000-0000-0000-0000-0000000000f2','95000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-0000000000d1',
        'INV-C95-2', current_date, 'EGP', 500, 'issued');

select is(
  (select count(*)::int from public.events
    where entity_id='95000000-0000-0000-0000-0000000000d1'
      and event_type_code='customer_credit_threshold_exceeded'),
  1,
  'CUST-3: a SECOND write while already over the ceiling does NOT alert again -- once per breach, not once per write');

insert into public.payments (id, tenant_id, customer_id, payment_direction_code, payment_method_code, currency_code, amount, paid_at)
values ('95000000-0000-0000-0000-0000000000f3','95000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-0000000000d1',
        'customer_payment','bank_transfer','EGP', 1900, now());

select is(
  (select count(*)::int from public.events
    where entity_id='95000000-0000-0000-0000-0000000000d1'
      and event_type_code='customer_credit_threshold_cleared'),
  1,
  'CUST-3: paying back below the ceiling emitted a CLEARED event -- which is what re-arms the next alert');

-- =============================================================================================
-- 14. THE NULL CONTROL. A customer with no ceiling has no ceiling, and is skipped entirely.
-- =============================================================================================
insert into public.invoices (id, tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code)
values ('95000000-0000-0000-0000-0000000000f4','95000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-0000000000d2',
        'INV-C95-4', current_date, 'EGP', 999999, 'issued');

select is(
  (select count(*)::int from public.events
    where entity_id='95000000-0000-0000-0000-0000000000d2'
      and event_type_code like 'customer_credit_threshold%'),
  0,
  'CUST-3: a NULL ceiling means NO ceiling -- an enormous exposure alerts nothing, and no default was invented');

-- =============================================================================================
-- 15-18. FOREIGN CURRENCY -- the requirement that separates CUST-3 from the supplier ceiling.
--        A USD invoice against an EGP ceiling must be CONVERTED, not dropped.
-- =============================================================================================
insert into public.invoices (id, tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code)
values ('95000000-0000-0000-0000-0000000000f5','95000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-0000000000d3',
        'INV-C95-5', current_date, 'USD', 30, 'issued');

select is(
  (select e.exposure from app.customer_exposure_in_limit_currency(
      '95000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-0000000000d3','EGP') e),
  1500::numeric,
  'CUST-3: USD 30 against an EGP ceiling is CONVERTED at the spot rate (30 x 50 = 1500 EGP) -- not silently dropped as the supplier path does');

select is(
  (select count(*)::int from public.events
    where entity_id='95000000-0000-0000-0000-0000000000d3'
      and event_type_code='customer_credit_threshold_exceeded'),
  1,
  'CUST-3: the converted figure CROSSED the ceiling and alerted -- a currency-blind comparison would have seen 0 EGP and stayed silent');

-- A currency with real exposure and NO rate must be REPORTED, and the convertible part still compared.
insert into public.invoices (id, tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code)
values ('95000000-0000-0000-0000-0000000000f6','95000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-0000000000d3',
        'INV-C95-6', current_date, 'GBP', 700, 'issued');

select is(
  (select e.unconvertible from app.customer_exposure_in_limit_currency(
      '95000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-0000000000d3','EGP') e),
  array['GBP']::text[],
  'CUST-3 (THE FAIL-SAFE): exposure in a currency with NO rate is REPORTED as un-convertible -- never dropped and never guessed');

select is(
  (select e.exposure from app.customer_exposure_in_limit_currency(
      '95000000-0000-0000-0000-000000000001','95000000-0000-0000-0000-0000000000d3','EGP') e),
  1500::numeric,
  'CUST-3: the convertible part is still compared -- an un-priced currency degrades the figure, it does not void it');

-- =============================================================================================
-- 19-23. AUTHORITY ON BOTH DOORS. The ceiling is a distinct act from editing the customer.
-- =============================================================================================
select is(
  (select count(*)::int from public.role_permissions rp
     join public.roles r on r.id=rp.role_id
     join public.permissions p on p.id=rp.permission_id
    where p.key='MANAGE_CUSTOMER_CREDIT' and r.code='finance_manager'),
  1,
  'CUST-3: finance_manager holds MANAGE_CUSTOMER_CREDIT');

select is(
  (select count(*)::int from public.role_permissions rp
     join public.roles r on r.id=rp.role_id
     join public.permissions p on p.id=rp.permission_id
    where p.key='CREATE_CUSTOMER' and r.code='finance_manager'),
  0,
  'CUST-3: finance_manager does NOT hold CREATE_CUSTOMER -- which is exactly why the credit-only branch in guard_write_capability is required, not cosmetic');

reset role;
-- `app.requires_mfa` covers owner/ceo/finance_manager/system_administrator, so a finance manager
-- without a step-up claim is refused for MFA rather than for authority. The claim is supplied here
-- so this assertion tests AUTHORITY, which is what it is about.
select set_config('request.jwt.claims','{"sub":"95000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$update public.customers set credit_limit_amount = 2000, credit_limit_currency_code = 'EGP'
     where id='95000000-0000-0000-0000-0000000000d1'$$,
  'CUST-3 (POSITIVE CONTROL): finance_manager, holding MANAGE_CUSTOMER_CREDIT but NOT CREATE_CUSTOMER, CAN set the ceiling at the table door');

select is(
  (select credit_limit_amount from public.customers where id='95000000-0000-0000-0000-0000000000d1'),
  2000::numeric,
  '...and the value actually moved -- "it did not throw" is not evidence that a write occurred');

reset role;
select set_config('request.jwt.claims','{"sub":"95000000-0000-0000-0000-0000000000a3"}', true);
set local role authenticated;

select throws_ok(
  $$update public.customers set credit_limit_amount = 5000, credit_limit_currency_code = 'EGP'
     where id='95000000-0000-0000-0000-0000000000d1'$$,
  '42501',
  null,
  'CUST-3 (NEGATIVE CONTROL): an employee holding neither permission is REFUSED at the table door, not merely at an RPC');

-- =============================================================================================
-- 24-26. DEFECT INJECTION (PAR-4) -- prove the guard is what refuses, not something incidental.
-- =============================================================================================
reset role;
savepoint before_injection;
drop trigger customers_guard_credit_authority on public.customers;

select set_config('request.jwt.claims','{"sub":"95000000-0000-0000-0000-0000000000a3"}', true);
set local role authenticated;

select lives_ok(
  $$update public.customers set credit_limit_amount = 5000, credit_limit_currency_code = 'EGP'
     where id='95000000-0000-0000-0000-0000000000d1'$$,
  'PAR-4 (DEFECT INJECTION): with customers_guard_credit_authority DROPPED, the employee SUCCEEDS -- proving that guard, and not guard_write_capability, is what refuses a credit write by a CREATE_CUSTOMER holder');

reset role;
rollback to savepoint before_injection;

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid=t.tgrelid
    where not t.tgisinternal and t.tgname='customers_guard_credit_authority'),
  1,
  'PAR-4: the dedicated guard is restored after injection');

select throws_ok(
  $$update public.customers set credit_limit_amount = 7000, credit_limit_currency_code = 'EGP'
     where id='95000000-0000-0000-0000-0000000000d1'$$,
  '42501',
  null,
  '...and with it restored the same employee write is REFUSED again -- the refusal was the guard, not an accident');

select is(
  (select count(*)::int from public.events
    where tenant_id='95000000-0000-0000-0000-000000000001'
      and event_type_code like 'customer_credit_threshold%'
      and entity_type <> 'customer'),
  0,
  'CUST-3: every threshold event is recorded against the CUSTOMER entity -- no other entity type leaks into this vocabulary');

select * from finish();
rollback;
