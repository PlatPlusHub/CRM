-- pgTAP: SPEC-155 -- commission is SYSTEM-DERIVED. An employee cannot influence the basis of their
-- own compensation, on any write path.
--
-- Owner rule (2026-08-27, closing BLOCKED-3):
--     gross_profit        = selling_amount - cost_amount
--     employee_commission = max(gross_profit, 0) * 10%
--     company_profit      = gross_profit - employee_commission
--
-- SPEC-154-A granted ENTER_SELLING_PRICE per canon, and the financial guard bundled
-- `commission_rate` into it -- so an employee could set the percentage their own commission is
-- calculated from. The fix is an OVERWRITE, not a permission: the caller's value is discarded before
-- anything reads it, which closes every path at once rather than the paths someone remembered.
--
-- The decisive assertions are the ones where a caller SUPPLIES a rate and it does not survive.
create extension if not exists pgtap with schema extensions;

begin;
select plan(17);

insert into auth.users (id, email) values
  ('41000000-0000-0000-0000-0000000000a1','emp@com.test'),
  ('41000000-0000-0000-0000-0000000000a2','fin@com.test');
insert into public.tenants (id, name, slug, status) values
  ('41000000-0000-0000-0000-000000000001','Com Travel','com-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '41000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('41000000-0000-0000-0000-00000000000a','41000000-0000-0000-0000-000000000001','Cairo','com-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('41000000-0000-0000-0000-0000000000c1','41000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('41000000-0000-0000-0000-000000000011','41000000-0000-0000-0000-000000000001','Emp','emp@com.test',true,'41000000-0000-0000-0000-0000000000a1'),
  ('41000000-0000-0000-0000-000000000012','41000000-0000-0000-0000-000000000001','Fin','fin@com.test',true,'41000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('41000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000011','41000000-0000-0000-0000-00000000000a','41000000-0000-0000-0000-0000000000c1',true),
  ('41000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000012','41000000-0000-0000-0000-00000000000a','41000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '41000000-0000-0000-0000-000000000001', v.u, r.id,'tenant'
from (values ('41000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('41000000-0000-0000-0000-000000000012'::uuid,'finance_manager')) v(u,rc)
join public.roles r on r.code=v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('41000000-0000-0000-0000-0000000000d1','41000000-0000-0000-0000-000000000001','person','Com Customer','+201002220000');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('41000000-0000-0000-0000-0000000000f1','41000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-00000000000a','41000000-0000-0000-0000-0000000000c1','41000000-0000-0000-0000-0000000000d1','41000000-0000-0000-0000-000000000011','41000000-0000-0000-0000-00000000000a','41000000-0000-0000-0000-0000000000c1','draft','Com booking','BK-COM-1');

-- =============================================================================================
-- 1-2. The rule has ONE home, and it is the owner's number.
-- =============================================================================================
select is(app.commission_rate_default(), 0.10::numeric,
  'the canonical commission rate is 10%, held in exactly one function');

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid=t.tgrelid
    where c.relname='booking_items' and not t.tgisinternal
      and t.tgname='booking_items_derive_commission_rate'),
  1,
  'the derive trigger is attached to booking_items');

-- =============================================================================================
-- 3-6. THE MANIPULATION ATTEMPT. The employee owns this item, holds ENTER_SELLING_PRICE, and is
--      therefore fully entitled to price it -- which is exactly why the commission attempt is the
--      only variable under test.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"41000000-0000-0000-0000-0000000000a1"}', true);

select ok(app.has_permission('ENTER_SELLING_PRICE'),
  'CONTROL: the employee HOLDS ENTER_SELLING_PRICE -- so what follows is not a permission failure');

select lives_ok(
  $$insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
        owner_user_id, owner_branch_id, owner_department_id, currency_code,
        cost_amount, selling_amount, commission_rate)
    values ('41000000-0000-0000-0000-0000000000e1','41000000-0000-0000-0000-000000000001',
            '41000000-0000-0000-0000-0000000000f1','hotel','draft',
            '41000000-0000-0000-0000-000000000011','41000000-0000-0000-0000-00000000000a',
            '41000000-0000-0000-0000-0000000000c1','EGP', 1000, 2000, 0.90)$$,
  'the employee inserts their own item and SUPPLIES a 90% commission rate -- the insert is accepted...');

reset role;
select set_config('request.jwt.claims', null, true);
select is(
  (select commission_rate from public.booking_items where id='41000000-0000-0000-0000-0000000000e1'),
  0.10::numeric,
  '...but the 90% DID NOT SURVIVE -- the system overwrote it with the canonical rate');

select set_config('request.jwt.claims','{"sub":"41000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;
select lives_ok(
  $$update public.booking_items set commission_rate = 0.75
     where id='41000000-0000-0000-0000-0000000000e1'$$,
  'the employee then tries to RAISE it by direct UPDATE -- no error, because there is nothing to refuse...');

reset role;
select set_config('request.jwt.claims', null, true);
select is(
  (select commission_rate from public.booking_items where id='41000000-0000-0000-0000-0000000000e1'),
  0.10::numeric,
  '...and it is STILL 10% -- overwriting beats forbidding, because it closes every path at once');

-- =============================================================================================
-- 7-10. THE ARITHMETIC. selling 2000 - cost 1000 = 1000 gross; 10% = 100 commission; 900 company.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"41000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select is((select f.profit from app.item_financials('41000000-0000-0000-0000-0000000000e1') f),
  1000::numeric, 'GROSS PROFIT = selling - cost = 1000');
select is((select f.commission_amount from app.item_financials('41000000-0000-0000-0000-0000000000e1') f),
  100::numeric, 'EMPLOYEE COMMISSION = 10% of gross = 100');
select is((select f.company_profit from app.item_financials('41000000-0000-0000-0000-0000000000e1') f),
  900::numeric, 'COMPANY PROFIT = gross - commission = 900');
select ok((select f.permitted from app.item_financials('41000000-0000-0000-0000-0000000000e1') f),
  '...and the owning employee is permitted to see their own figures');

-- =============================================================================================
-- 11-12. A LOSS-MAKING ITEM pays no commission, and the company absorbs the whole loss --
--        max(gross, 0) means the employee is never charged for a negative margin.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
      owner_user_id, owner_branch_id, owner_department_id, currency_code, cost_amount, selling_amount)
values ('41000000-0000-0000-0000-0000000000e2','41000000-0000-0000-0000-000000000001',
        '41000000-0000-0000-0000-0000000000f1','hotel','draft',
        '41000000-0000-0000-0000-000000000011','41000000-0000-0000-0000-00000000000a',
        '41000000-0000-0000-0000-0000000000c1','EGP', 3000, 2500);

select set_config('request.jwt.claims','{"sub":"41000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;
select is((select f.commission_amount from app.item_financials('41000000-0000-0000-0000-0000000000e2') f),
  0::numeric, 'a LOSS pays ZERO commission -- max(gross, 0), not a negative payout');
select is((select f.company_profit from app.item_financials('41000000-0000-0000-0000-0000000000e2') f),
  -500::numeric, '...and the company absorbs the entire -500, rather than charging the employee for it');

-- =============================================================================================
-- 13. FINANCIAL PRIVACY is unchanged: the new figures are exactly as protected as cost always was.
--     Finance sees them on an item it does not own; that is VIEW_FINANCIAL_DOCUMENTS, not ownership.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"41000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select ok((select f.permitted from app.item_financials('41000000-0000-0000-0000-0000000000e1') f),
  'finance sees the commission figures on an item it does not own -- VIEW_FINANCIAL_DOCUMENTS');

-- =============================================================================================
-- 14. Creating a BARE item still needs only CREATE_BOOKING_ITEM. The derive trigger sets a
--     non-null commission_rate on every insert, so leaving it in the guard's condition would have
--     silently demanded ENTER_SELLING_PRICE for every item -- this proves it does not.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '41000000-0000-0000-0000-000000000001','41000000-0000-0000-0000-000000000012', r.id,'tenant'
from public.roles r where r.code='senior_employee';

select set_config('request.jwt.claims','{"sub":"41000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;
select lives_ok(
  $$select app.create_booking_item('41000000-0000-0000-0000-0000000000f1','hotel','EGP')$$,
  'a BARE item (no cost, no selling price) still creates under CREATE_BOOKING_ITEM alone');

-- =============================================================================================
-- 15-16. SPEC-156: the ignored parameter is GONE, and gone without leaving an overload behind.
--        A silently ignored input is worse than a rejected one -- it teaches the caller a false
--        rule. Assertion 16 is the one that matters: `create or replace` with a shorter argument
--        list would have left the 9-argument version callable alongside the new one, so proving
--        the parameter is absent is only meaningful once we prove there is exactly ONE signature.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'create_booking_item'),
  1,
  'app.create_booking_item has exactly ONE signature -- no stale overload survived the change');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'create_booking_item'
      and 'p_commission_rate' = any (p.proargnames)),
  0,
  '...and it no longer accepts p_commission_rate, which SPEC-155 had made inert');

select finish();
rollback;
