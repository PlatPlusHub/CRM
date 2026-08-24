-- pgTAP: employee financial privacy (SPEC-139).
--
-- The rule under test is the owner's: "Do not expose another employee's profit merely because the
-- employee can see the booking." That sentence contains both halves, and both are asserted here --
-- the colleague must still SEE the booking item (hiding the record was explicitly ruled out, and
-- would break the continuity SPEC-137 exists to provide) while the margin on it stays hidden.
--
-- Runs as `authenticated`, because as `postgres` neither the column grant nor the RLS scope applies
-- and every assertion would pass without proving anything.
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

insert into auth.users (id, email) values
  ('23000000-0000-0000-0000-0000000000a1','seller@example.com'),
  ('23000000-0000-0000-0000-0000000000a2','peer@example.com'),
  ('23000000-0000-0000-0000-0000000000a3','money@example.com');

insert into public.tenants (id, name, slug, status) values
  ('23000000-0000-0000-0000-000000000001','Margin Travel','margin-travel','active');
insert into public.branches (id, tenant_id, name, slug) values
  ('23000000-0000-0000-0000-00000000000a','23000000-0000-0000-0000-000000000001','Luxor','luxor');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('23000000-0000-0000-0000-0000000000c1','23000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-00000000000a','sales','Luxor Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('23000000-0000-0000-0000-000000000011','23000000-0000-0000-0000-000000000001','Seller','seller@example.com',true,'23000000-0000-0000-0000-0000000000a1'),
  ('23000000-0000-0000-0000-000000000012','23000000-0000-0000-0000-000000000001','Peer','peer@example.com',true,'23000000-0000-0000-0000-0000000000a2'),
  ('23000000-0000-0000-0000-000000000013','23000000-0000-0000-0000-000000000001','Finance','money@example.com',true,'23000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('23000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000011','23000000-0000-0000-0000-00000000000a','23000000-0000-0000-0000-0000000000c1',true),
  ('23000000-0000-0000-0000-000000000001','23000000-0000-0000-0000-000000000012','23000000-0000-0000-0000-00000000000a','23000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '23000000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('23000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('23000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('23000000-0000-0000-0000-000000000013'::uuid,'finance_manager')) as v(uid, role_code)
join public.roles r on r.code = v.role_code;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('23000000-0000-0000-0000-0000000000d1','23000000-0000-0000-0000-000000000001','person','Margin Customer','+201115559876');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('23000000-0000-0000-0000-0000000000f1','23000000-0000-0000-0000-000000000001',
   '23000000-0000-0000-0000-00000000000a','23000000-0000-0000-0000-0000000000c1',
   '23000000-0000-0000-0000-0000000000d1','23000000-0000-0000-0000-000000000011',
   '23000000-0000-0000-0000-00000000000a','23000000-0000-0000-0000-0000000000c1',
   'draft','Nile cruise','BK-LUX-0001');

-- Seller's own item: sells for 5000, costs 3000, so the margin is 2000 and the commission rate is
-- the seller's own earnings basis.
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
                                  owner_user_id, sales_owner_user_id, owner_branch_id, owner_department_id,
                                  currency_code, cost_amount, selling_amount, commission_rate) values
  ('23000000-0000-0000-0000-0000000000f2','23000000-0000-0000-0000-000000000001',
   '23000000-0000-0000-0000-0000000000f1','hotel','draft',
   '23000000-0000-0000-0000-000000000011','23000000-0000-0000-0000-000000000011',
   '23000000-0000-0000-0000-00000000000a','23000000-0000-0000-0000-0000000000c1',
   'EGP', 3000, 5000, 0.10);

set local role authenticated;

-- ---------------------------------------------------------------------------------------------
-- The colleague. Must keep the work, lose the margin.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"23000000-0000-0000-0000-0000000000a2"}', true);

select is((select count(*)::int from public.booking_items
            where id = '23000000-0000-0000-0000-0000000000f2'), 1,
  'THE COLLEAGUE STILL SEES THE BOOKING ITEM -- hiding the record was ruled out, and would break department continuity');

select is((select selling_amount from public.booking_items
            where id = '23000000-0000-0000-0000-0000000000f2'), 5000::numeric,
  '...and still sees what the customer pays, which is operational information they need');

select throws_ok(
  $$select cost_amount from public.booking_items where id = '23000000-0000-0000-0000-0000000000f2'$$,
  '42501', null,
  '...but CANNOT read the cost column -- the column privilege is gone, not merely filtered');

select throws_ok(
  $$select commission_rate from public.booking_items where id = '23000000-0000-0000-0000-0000000000f2'$$,
  '42501', null,
  '...nor the commission rate, which canon 31 records as the sales-commission basis');

select throws_ok(
  $$select * from public.booking_items where id = '23000000-0000-0000-0000-0000000000f2'$$,
  '42501', null,
  '...and cannot reach either of them by asking for everything');

-- The accessor is the only path to the numbers, so it has to hold the line too -- otherwise the
-- column grant would just be an inconvenience rather than a control.
select is((select f.profit from app.item_financials('23000000-0000-0000-0000-0000000000f2') f), null,
  'the gated accessor returns NULL profit to the colleague -- the record is present, the margin is not');
select is((select f.permitted from app.item_financials('23000000-0000-0000-0000-0000000000f2') f), false,
  '...and says so explicitly rather than being indistinguishable from a zero-margin item');

select is((select p.profit from app.booking_item_profit(null,'23000000-0000-0000-0000-0000000000f2') p), null,
  'and the reporting primitive behind reporting.booking_item_profit masks it as well');

-- ADR-0022 makes the `reporting` schema the read path, so the guarantee has to hold at the surface
-- an application will actually query -- not only in the primitive underneath it.
select is((select count(*)::int from reporting.booking_item_profit
            where booking_item_id = '23000000-0000-0000-0000-0000000000f2'), 1,
  'the colleague still gets the ROW from the reporting view -- the report is not broken for them');
select is((select profit from reporting.booking_item_profit
            where booking_item_id = '23000000-0000-0000-0000-0000000000f2'), null,
  '...with the margin column empty, which is the whole shape of this rule: present record, absent number');

-- ---------------------------------------------------------------------------------------------
-- The seller and the finance manager. Both must still get the numbers.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"23000000-0000-0000-0000-0000000000a1"}', true);
select is((select f.profit from app.item_financials('23000000-0000-0000-0000-0000000000f2') f), 2000::numeric,
  'THE SELLER sees the margin on their own work -- canon 28''s "assigned related only"');

select set_config('request.jwt.claims', '{"sub":"23000000-0000-0000-0000-0000000000a3"}', true);
select is((select f.profit from app.item_financials('23000000-0000-0000-0000-0000000000f2') f), 2000::numeric,
  'THE FINANCE MANAGER sees it too -- a privacy rule that blocked finance would be an outage, not a control');

select * from finish();
rollback;
