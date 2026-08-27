-- pgTAP: SPEC-159 -- an employee sees their own results, and only their own.
--
-- The owner's rule (§10): the employee may see their sales, cost, gross profit, commission and the
-- company profit their work generated; they may NEVER see another employee's commission or margin,
-- company-wide totals, or branch-wide financials -- "enforced in the database, UI hiding is not
-- security".
--
-- The decisive assertions are 5 and 9: the colleague's rows are ABSENT rather than masked, and the
-- view cannot be turned into a colleague's report by filtering on their user id. A masked row would
-- still disclose that a colleague made a sale, to which customer, on which date.
create extension if not exists pgtap with schema extensions;

begin;
select plan(10);

insert into auth.users (id, email) values
  ('45000000-0000-0000-0000-0000000000a1','emp-a@perf.test'),
  ('45000000-0000-0000-0000-0000000000a2','emp-b@perf.test'),
  ('45000000-0000-0000-0000-0000000000a3','owner@perf.test');
insert into public.tenants (id, name, slug, status) values
  ('45000000-0000-0000-0000-000000000001','Perf Travel','perf-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '45000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('45000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-000000000001','Cairo','perf-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('45000000-0000-0000-0000-0000000000c1','45000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('45000000-0000-0000-0000-000000000011','45000000-0000-0000-0000-000000000001','Emp A','emp-a@perf.test',true,'45000000-0000-0000-0000-0000000000a1'),
  ('45000000-0000-0000-0000-000000000012','45000000-0000-0000-0000-000000000001','Emp B','emp-b@perf.test',true,'45000000-0000-0000-0000-0000000000a2'),
  ('45000000-0000-0000-0000-000000000013','45000000-0000-0000-0000-000000000001','The Owner','owner@perf.test',true,'45000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('45000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-000000000011','45000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-0000000000c1',true),
  ('45000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-000000000012','45000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-0000000000c1',true),
  ('45000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-000000000013','45000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '45000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('45000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('45000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('45000000-0000-0000-0000-000000000013'::uuid,'owner')) v(u, rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('45000000-0000-0000-0000-0000000000d1','45000000-0000-0000-0000-000000000001','person','Perf Customer','+201006660000');
insert into public.suppliers (id, tenant_id, supplier_type_code, name) values
  ('45000000-0000-0000-0000-0000000000b9','45000000-0000-0000-0000-000000000001','airline','EgyptAir');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                            owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('45000000-0000-0000-0000-0000000000f1','45000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-0000000000c1','45000000-0000-0000-0000-0000000000d1','45000000-0000-0000-0000-000000000011','45000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-0000000000c1','draft','Perf booking','BK-PERF-1');

-- A: one live airline sale (2000 - 1000), one CANCELLED sale, one ARCHIVED sale.
-- B: one live sale of their own, which A must never see.
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
      owner_user_id, sales_owner_user_id, operational_owner_user_id, owner_branch_id, owner_department_id,
      supplier_id, currency_code, cost_amount, selling_amount, is_archived) values
  ('45000000-0000-0000-0000-0000000000e1','45000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-0000000000f1','flight_ticket','confirmed',
   '45000000-0000-0000-0000-000000000011','45000000-0000-0000-0000-000000000011','45000000-0000-0000-0000-000000000011',
   '45000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-0000000000c1','45000000-0000-0000-0000-0000000000b9','EGP',1000,2000,false),
  ('45000000-0000-0000-0000-0000000000e2','45000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-0000000000f1','hotel','cancelled',
   '45000000-0000-0000-0000-000000000011','45000000-0000-0000-0000-000000000011','45000000-0000-0000-0000-000000000011',
   '45000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-0000000000c1',null,'EGP',500,9000,false),
  ('45000000-0000-0000-0000-0000000000e3','45000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-0000000000f1','visa','confirmed',
   '45000000-0000-0000-0000-000000000011','45000000-0000-0000-0000-000000000011','45000000-0000-0000-0000-000000000011',
   '45000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-0000000000c1',null,'EGP',100,8000,true),
  ('45000000-0000-0000-0000-0000000000e4','45000000-0000-0000-0000-000000000001','45000000-0000-0000-0000-0000000000f1','hotel','confirmed',
   '45000000-0000-0000-0000-000000000012','45000000-0000-0000-0000-000000000012','45000000-0000-0000-0000-000000000012',
   '45000000-0000-0000-0000-00000000000a','45000000-0000-0000-0000-0000000000c1',null,'EGP',700,1700,false);

-- =============================================================================================
-- 1-4. THE EMPLOYEE'S OWN RESULTS, and the owner's arithmetic end to end through the report.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"45000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select is(
  (select count(*)::int from reporting.my_sales_performance),
  1,
  'A sees exactly ONE row: the live sale. The cancelled and archived items do not earn commission');

select is(
  (select selling_amount::int || '/' || cost_amount::int || '/' || gross_profit::int
     from reporting.my_sales_performance),
  '2000/1000/1000',
  '...with cost visible through the report even though the raw column is unreadable');

select is(
  (select employee_commission::int || '/' || company_profit::int from reporting.my_sales_performance),
  '100/900',
  '...and the owner rule holds end to end: 10% of gross to the employee, the rest to the company');

select is(
  (select supplier_name || ':' || supplier_type_code from reporting.my_sales_performance),
  'EgyptAir:airline',
  'AIRLINE performance is supplier performance filtered by type -- no invented airline dimension');

-- =============================================================================================
-- 5-6. THE COLLEAGUE. Absent, not masked -- and unreachable by filtering.
-- =============================================================================================
select is(
  (select count(*)::int from reporting.my_sales_performance
    where sales_owner_user_id = '45000000-0000-0000-0000-000000000012'),
  0,
  'the colleague''s sale is ABSENT from A''s report -- not a masked row disclosing that it exists');

select is(
  (select count(*)::int from reporting.my_sales_performance
    where booking_item_id = '45000000-0000-0000-0000-0000000000e4'),
  0,
  '...and naming the colleague''s item id directly does not surface it either');

-- =============================================================================================
-- 7-8. NO COMPANY-WIDE TOTAL. Aggregating the view can only ever total the caller's own work --
--      which is the difference between a personal report and an accidental management report.
-- =============================================================================================
select is(
  (select coalesce(sum(company_profit), 0)::int from reporting.my_sales_performance),
  900,
  'summing the report yields A''s OWN company-profit contribution, never the tenant total (which is 1900)');

select throws_ok(
  $$select cost_amount from public.booking_items where id = '45000000-0000-0000-0000-0000000000e4'$$,
  '42501', null,
  'and the report gave A no new way to read a raw cost column -- SPEC-139 is untouched');

-- =============================================================================================
-- 9. THE COLLEAGUE'S OWN VIEW is symmetrical, which proves the scope follows the caller rather
--       than being a property of the fixture.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"45000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select is(
  (select booking_item_id::text || ':' || employee_commission::int
     from reporting.my_sales_performance),
  '45000000-0000-0000-0000-0000000000e4:100',
  'B sees exactly their own sale and their own commission -- the same view, a different answer');

-- =============================================================================================
-- 10. IT IS PERSONAL FOR EVERY ROLE. The tenant owner has VIEW_ALL_BRANCHES and can read every
--     booking item in the tenant, yet this view still answers only "what did I sell". A personal
--     report that widens for privileged roles is a management report wearing a disguise.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"45000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;

select is(
  (select count(*)::int from reporting.my_sales_performance),
  0,
  'the OWNER sees zero rows -- they sold nothing. Tenant-wide read does not widen a personal report');

select finish();
rollback;
