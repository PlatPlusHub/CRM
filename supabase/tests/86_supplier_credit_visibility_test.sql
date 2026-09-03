-- pgTAP: PD-24 / SUP-1 -- who may read a supplier's credit ceiling.
--
-- SEC-1c closed the WRITE half (a trainee rewrote `credit_limit_amount` 1000 -> 999999). This file
-- pins the READ half, and the two halves are different questions: one is authorization to change a
-- value, the other is authorization to KNOW it.
--
-- The permission was derived, not chosen: `app.supplier_balance` already refuses to report a
-- supplier's financial position without VIEW_FINANCIAL_DOCUMENTS, and the credit limit is the
-- ceiling on exactly that position. The mechanism was derived too: `booking_items` already withholds
-- `cost_amount` and `commission_rate` from `authenticated` by COLUMN grant while leaving the row
-- readable. Assertion 1 pins that precedent alongside the new one, so a future reader can see the
-- rule is a class rather than a one-off.
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

insert into auth.users (id, email, email_confirmed_at) values
  ('86000000-0000-0000-0000-0000000000a1','owner@sup86.test',   now()),
  ('86000000-0000-0000-0000-0000000000a2','trainee@sup86.test', now()),
  ('86000000-0000-0000-0000-0000000000a3','fin@sup86.test',     now());
insert into public.tenants (id, name, slug, status) values
  ('86000000-0000-0000-0000-000000000001','Sup86 Travel','sup86','active'),
  ('86000000-0000-0000-0000-000000000002','Other Agency','sup86-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id in ('86000000-0000-0000-0000-000000000001','86000000-0000-0000-0000-000000000002');
insert into public.branches (id, tenant_id, name, slug) values
  ('86000000-0000-0000-0000-00000000000a','86000000-0000-0000-0000-000000000001','HQ','sup86-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('86000000-0000-0000-0000-0000000000c1','86000000-0000-0000-0000-000000000001','86000000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('86000000-0000-0000-0000-000000000011','86000000-0000-0000-0000-000000000001','Owner','owner@sup86.test',true,'86000000-0000-0000-0000-0000000000a1'),
  ('86000000-0000-0000-0000-000000000012','86000000-0000-0000-0000-000000000001','Trainee','trainee@sup86.test',true,'86000000-0000-0000-0000-0000000000a2'),
  ('86000000-0000-0000-0000-000000000013','86000000-0000-0000-0000-000000000001','Fin','fin@sup86.test',true,'86000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '86000000-0000-0000-0000-000000000001', u,
       '86000000-0000-0000-0000-00000000000a','86000000-0000-0000-0000-0000000000c1', true
from unnest(array['86000000-0000-0000-0000-000000000011'::uuid,'86000000-0000-0000-0000-000000000012'::uuid,
                  '86000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '86000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('86000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('86000000-0000-0000-0000-000000000012'::uuid,'trainee'),
             ('86000000-0000-0000-0000-000000000013'::uuid,'finance_manager')) v(u,rc)
join public.roles r on r.code = v.rc;

-- SUP-4a (202607059900): the ceiling is the PAIR (amount, currency) and
-- `suppliers_credit_limit_currency_check` refuses one without the other. A fixture that sets only the
-- amount now fails at INSERT, which is the constraint doing its job -- so the fixture states the
-- denomination, as any real credit ceiling must.
insert into public.suppliers (id, tenant_id, name, supplier_type_code, credit_limit_amount, credit_limit_currency_code) values
  ('86000000-0000-0000-0000-0000000000e1','86000000-0000-0000-0000-000000000001','Our Airline','airline', 25000, 'EGP'),
  ('86000000-0000-0000-0000-0000000000e2','86000000-0000-0000-0000-000000000002','Their Airline','airline', 99000, 'EGP');

-- =============================================================================================
-- 1-2. STRUCTURE: the column grant, and the precedent it copies.
-- =============================================================================================
select is(
  (select count(*)::int from information_schema.role_column_grants
    where table_schema='public' and table_name='suppliers'
      and column_name='credit_limit_amount' and grantee in ('authenticated','anon')
      and privilege_type='SELECT'),
  0,
  'SUP-1: authenticated and anon hold NO column-level SELECT on suppliers.credit_limit_amount');

select is(
  (select count(*)::int from information_schema.role_column_grants
    where table_schema='public' and table_name='booking_items'
      and column_name in ('cost_amount','commission_rate') and grantee='authenticated'
      and privilege_type='SELECT'),
  0,
  '...the same shape booking_items already used for cost_amount and commission_rate -- this is a class, not a one-off');

-- =============================================================================================
-- 3-5. THE TRAINEE. The row stays readable; only the ceiling is withheld.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"86000000-0000-0000-0000-0000000000a2"}', true);

-- This control names a REAL column on purpose. The first draft used `count(*)`, which needs no
-- column privilege at all and therefore passed whether or not the trainee could read anything --
-- the vacuous shape this repository keeps finding in its own tests. Selecting `name` is what proves
-- the revoke withheld one column rather than closing the table. Verified over HTTP too:
-- `GET /suppliers?select=id,name` returns 200 with the row, `select=id,credit_limit_amount` returns
-- 403, and `select=*` returns 403 -- which is the SAME behaviour `booking_items` already has, so
-- clients on such tables must name their columns. That cost is the pattern's, not this migration's.
select is(
  (select s.name from public.suppliers s where s.id = '86000000-0000-0000-0000-0000000000e1'),
  'Our Airline',
  'CONTROL: the trainee still reads the supplier NAME -- the revoke withholds a column, not the record');

select is(
  app.has_permission('VIEW_FINANCIAL_DOCUMENTS'), false,
  'CONTROL: ...and holds no VIEW_FINANCIAL_DOCUMENTS -- the premise of the two refusals below');

select throws_ok(
  $$select credit_limit_amount from public.suppliers where id = '86000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'SUP-1: reading the column DIRECTLY is refused -- this is the door PostgREST actually serves');

-- =============================================================================================
-- 6-7. ...and the RPC withholds it too, so the gated reader is not a way around the grant.
-- =============================================================================================
select is(
  (select permitted from public.supplier_credit('86000000-0000-0000-0000-0000000000e1')),
  false,
  'the gated reader reports permitted=false for the trainee');

select ok(
  (select credit_limit_amount is null from public.supplier_credit('86000000-0000-0000-0000-0000000000e1')),
  '...and returns NO amount -- "permitted=false" beside a populated value would be theatre');

-- =============================================================================================
-- 8-10. FINANCE CAN. A fix that hid the field from everyone would be a capability regression.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"86000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;

select is(
  app.has_permission('VIEW_FINANCIAL_DOCUMENTS'), true,
  'CONTROL: finance_manager DOES hold VIEW_FINANCIAL_DOCUMENTS');

select is(
  (select permitted from public.supplier_credit('86000000-0000-0000-0000-0000000000e1')),
  true,
  'POSITIVE CONTROL: finance is permitted');

select is(
  (select credit_limit_amount from public.supplier_credit('86000000-0000-0000-0000-0000000000e1')),
  25000::numeric,
  '...and receives the REAL amount -- not a null that would pass a weaker assertion');

-- SUP-4a: the amount alone is the ill-formed value the constraint exists to end, so the reader that
-- serves it must carry the denomination too. Without this assertion the widened reader could return
-- a NULL currency beside a real amount and every other assertion here would still pass.
select is(
  (select credit_limit_currency_code from public.supplier_credit('86000000-0000-0000-0000-0000000000e1')),
  'EGP',
  '...WITH its denomination -- an amount whose currency the API drops is the SUP-4a defect at the door');

-- =============================================================================================
-- 11. CROSS-TENANT. The reader is SECURITY DEFINER, which is exactly how a leak gets built.
-- =============================================================================================
select throws_ok(
  $$select * from public.supplier_credit('86000000-0000-0000-0000-0000000000e2')$$,
  '42501', null,
  'CROSS-TENANT: finance cannot read another tenant''s ceiling by guessing an id -- the DEFINER reader checks the caller''s tenant, not its own rights');

select * from finish();
rollback;
