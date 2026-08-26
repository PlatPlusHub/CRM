-- pgTAP: financial write authority (SPEC-145).
--
-- Every assertion here is an ADVERSARIAL one: a real authenticated employee attempting the write
-- directly, skipping the RPC entirely. That is the only way to test the claim the owner's directive
-- actually makes -- "the database must remain safe if the RPC is bypassed". Testing through the RPC
-- would prove nothing, because the RPC was already checking these permissions; what was missing was
-- anything obliging a caller to use it.
--
-- Before SPEC-145 an ordinary employee could set the company exchange rate, write journal entries,
-- edit the chart of accounts, approve their own refund request, overwrite a colleague's cost, clear
-- a cost lock, and mark an item finance-approved -- all with plain SQL.
--
-- Three actors, chosen because canon 28 separates them:
--   employee        -- holds none of the finance permissions
--   senior_employee -- holds ENTER_COST / ENTER_SELLING_PRICE, but NOT EDIT_LOCKED_COST or APPROVE_FINANCE
--   finance_manager -- holds the finance set
-- The middle actor is what makes the test meaningful: it proves the lock moves a cost out of
-- operations' reach rather than simply blocking everyone.
create extension if not exists pgtap with schema extensions;

begin;
select plan(15);

insert into auth.users (id, email) values
  ('29000000-0000-0000-0000-0000000000a1','emp@example.com'),
  ('29000000-0000-0000-0000-0000000000a2','senior@example.com'),
  ('29000000-0000-0000-0000-0000000000a3','fin@example.com');

insert into public.tenants (id, name, slug, status) values
  ('29000000-0000-0000-0000-000000000001','Finance Travel','finance-travel','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.branches (id, tenant_id, name, slug) values
  ('29000000-0000-0000-0000-00000000000a','29000000-0000-0000-0000-000000000001','Zamalek','zamalek');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('29000000-0000-0000-0000-0000000000c1','29000000-0000-0000-0000-000000000001','29000000-0000-0000-0000-00000000000a','sales','Zamalek Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('29000000-0000-0000-0000-000000000011','29000000-0000-0000-0000-000000000001','Employee','emp@example.com',true,'29000000-0000-0000-0000-0000000000a1'),
  ('29000000-0000-0000-0000-000000000012','29000000-0000-0000-0000-000000000001','Senior','senior@example.com',true,'29000000-0000-0000-0000-0000000000a2'),
  ('29000000-0000-0000-0000-000000000013','29000000-0000-0000-0000-000000000001','Finance','fin@example.com',true,'29000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '29000000-0000-0000-0000-000000000001', u, '29000000-0000-0000-0000-00000000000a','29000000-0000-0000-0000-0000000000c1', true
from unnest(array['29000000-0000-0000-0000-000000000011'::uuid,'29000000-0000-0000-0000-000000000012','29000000-0000-0000-0000-000000000013']) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '29000000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('29000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('29000000-0000-0000-0000-000000000012'::uuid,'senior_employee'),
             ('29000000-0000-0000-0000-000000000013'::uuid,'finance_manager')) as v(uid, role_code)
join public.roles r on r.code = v.role_code;

insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('29000000-0000-0000-0000-0000000000d1','29000000-0000-0000-0000-000000000001','person','Finance Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('29000000-0000-0000-0000-0000000000f1','29000000-0000-0000-0000-000000000001',
   '29000000-0000-0000-0000-00000000000a','29000000-0000-0000-0000-0000000000c1',
   '29000000-0000-0000-0000-0000000000d1','29000000-0000-0000-0000-000000000012',
   '29000000-0000-0000-0000-00000000000a','29000000-0000-0000-0000-0000000000c1',
   'draft','Zamalek booking','BK-ZAM-0001');
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
                                  owner_user_id, owner_branch_id, owner_department_id,
                                  currency_code, cost_amount, selling_amount) values
  ('29000000-0000-0000-0000-0000000000f2','29000000-0000-0000-0000-000000000001',
   '29000000-0000-0000-0000-0000000000f1','hotel','draft',
   '29000000-0000-0000-0000-000000000012',
   '29000000-0000-0000-0000-00000000000a','29000000-0000-0000-0000-0000000000c1',
   'EGP', 3000, 5000);
insert into public.approval_requests (id, tenant_id, approval_type_code, approval_status_code,
                                      requested_by, related_entity_type, related_entity_id, booking_item_id, reason) values
  ('29000000-0000-0000-0000-0000000000f3','29000000-0000-0000-0000-000000000001','refund_approval','pending',
   '29000000-0000-0000-0000-000000000011','booking_item','29000000-0000-0000-0000-0000000000f2',
   '29000000-0000-0000-0000-0000000000f2','customer changed plans');

set local role authenticated;

-- ---------------------------------------------------------------------------------------------
-- The ordinary employee, acting directly against the tables.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"29000000-0000-0000-0000-0000000000a1"}', true);

select is(app.current_tenant_id(), '29000000-0000-0000-0000-000000000001'::uuid,
  'the employee has a genuine authenticated session -- so every refusal below is a control, not a broken fixture');

select throws_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('29000000-0000-0000-0000-000000000001','USD','EGP', 1.0, now())$$,
  '42501', null,
  'AN EMPLOYEE CANNOT SET THE COMPANY EXCHANGE RATE -- which silently decides what every multi-currency booking cost');

select throws_ok(
  $$insert into public.journal_entries (tenant_id, source_type_code, entry_date)
    values ('29000000-0000-0000-0000-000000000001','manual_entry', current_date)$$,
  '42501', null,
  '...nor write a journal entry');

select throws_ok(
  $$insert into public.chart_of_accounts (tenant_id, code, name, account_type)
    values ('29000000-0000-0000-0000-000000000001','9999','Invented','asset')$$,
  '42501', null,
  '...nor add an account to the ledger''s structure');

-- Self-approval: the employee raised this request themselves.
update public.approval_requests set approval_status_code = 'approved'
 where id = '29000000-0000-0000-0000-0000000000f3';
select is(
  (select approval_status_code from public.approval_requests where id = '29000000-0000-0000-0000-0000000000f3'),
  'pending',
  '...AND CANNOT APPROVE THEIR OWN REFUND REQUEST -- the UPDATE matches zero rows, so the request stays pending');

select throws_ok(
  $$update public.booking_items set cost_amount = 1 where id = '29000000-0000-0000-0000-0000000000f2'$$,
  '42501', null,
  '...nor write a cost, even on an item they can legitimately see -- withholding SELECT on the column never withheld UPDATE');

-- ---------------------------------------------------------------------------------------------
-- The senior employee: entitled to price the work, not to overrule finance.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"29000000-0000-0000-0000-0000000000a2"}', true);

select lives_ok(
  $$update public.booking_items set cost_amount = 3200 where id = '29000000-0000-0000-0000-0000000000f2'$$,
  'a senior employee CAN enter a cost while it is unlocked -- the control blocks the wrong actor, not the right one');

select lives_ok(
  $$update public.booking_items set selling_amount = 5500 where id = '29000000-0000-0000-0000-0000000000f2'$$,
  '...and can set the selling price');

select throws_ok(
  $$update public.booking_items set cost_locked_at = now() where id = '29000000-0000-0000-0000-0000000000f2'$$,
  '42501', null,
  '...but cannot LOCK the cost, which is a finance act');

select throws_ok(
  $$update public.booking_items set finance_approval_status_code = 'approved'
     where id = '29000000-0000-0000-0000-0000000000f2'$$,
  '42501', null,
  '...nor mark the item finance-approved, which would bypass app.review_finance_approval entirely');

-- ---------------------------------------------------------------------------------------------
-- Finance locks it. The lock must then actually move the cost out of operations' reach.
-- ---------------------------------------------------------------------------------------------
-- MFA composes with the new guard, on the DIRECT path as well as through the RPC. A finance manager
-- whose session is not at aal2 cannot lock a cost with plain SQL either -- worth asserting, because
-- a guard that only held inside the RPC would leave exactly this gap open.
select set_config('request.jwt.claims', '{"sub":"29000000-0000-0000-0000-0000000000a3"}', true);
select throws_ok(
  $$update public.booking_items set cost_locked_at = now() where id = '29000000-0000-0000-0000-0000000000f2'$$,
  '42501', null,
  'a finance manager WITHOUT MFA cannot lock the cost even by direct SQL -- app.requires_mfa composes with the guard');

select set_config('request.jwt.claims', '{"sub":"29000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
select lives_ok(
  $$update public.booking_items set cost_locked_at = now() where id = '29000000-0000-0000-0000-0000000000f2'$$,
  '...and WITH MFA they can -- the finance manager locks the cost');

select set_config('request.jwt.claims', '{"sub":"29000000-0000-0000-0000-0000000000a2"}', true);
select throws_ok(
  $$update public.booking_items set cost_amount = 10 where id = '29000000-0000-0000-0000-0000000000f2'$$,
  '42501', null,
  'THE LOCK NOW BITES -- the same senior employee who could edit the cost a moment ago cannot, because EDIT_LOCKED_COST is a different authority');

select throws_ok(
  $$update public.booking_items set cost_locked_at = null where id = '29000000-0000-0000-0000-0000000000f2'$$,
  '42501', null,
  '...and cannot simply unlock it first, which would have made EDIT_LOCKED_COST unreachable in practice');

select set_config('request.jwt.claims', '{"sub":"29000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
select lives_ok(
  $$update public.booking_items set cost_amount = 3100 where id = '29000000-0000-0000-0000-0000000000f2'$$,
  '...while finance can still correct a locked cost, which is what the permission is for');

select * from finish();
rollback;
