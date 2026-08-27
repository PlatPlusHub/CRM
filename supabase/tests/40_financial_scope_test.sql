-- pgTAP: SPEC-154-A -- canon's `assigned` scope on ENTER_COST / ENTER_SELLING_PRICE is ENFORCED,
-- not merely documented.
--
-- SPEC-154 could not grant these two permissions: `app.guard_booking_item_financials` asked only
-- whether the ROLE held ENTER_COST and never whether the ITEM was the caller's, so granting would
-- have let an employee price a COLLEAGUE's booking item -- exceeding canon 28's "Assigned only"
-- rather than implementing it. The permission was withheld and this package recorded. The guard is
-- now scope-aware and the permissions are granted.
--
-- The matrix below is the whole point: the SAME actor, holding the SAME permission, is allowed on
-- their own item and refused on someone else's. That contrast is what proves scope exists -- a test
-- that only showed the denial could be satisfied by simply not granting the permission at all.
create extension if not exists pgtap with schema extensions;

begin;
select plan(15);

insert into auth.users (id, email) values
  ('40000000-0000-0000-0000-0000000000a1','emp@fin.test'),
  ('40000000-0000-0000-0000-0000000000a2','colleague@fin.test'),
  ('40000000-0000-0000-0000-0000000000a3','alex@fin.test'),
  ('40000000-0000-0000-0000-0000000000a4','fin@fin.test'),
  ('40000000-0000-0000-0000-0000000000a5','owner@fin.test');
insert into public.tenants (id, name, slug, status) values
  ('40000000-0000-0000-0000-000000000001','Fin Travel','fin-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '40000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('40000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-000000000001','Cairo','fin-cairo'),
  ('40000000-0000-0000-0000-00000000000b','40000000-0000-0000-0000-000000000001','Alex','fin-alex');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('40000000-0000-0000-0000-0000000000c1','40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-00000000000a','sales','Cairo Sales'),
  ('40000000-0000-0000-0000-0000000000c2','40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-00000000000b','sales','Alex Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('40000000-0000-0000-0000-000000000011','40000000-0000-0000-0000-000000000001','Me','emp@fin.test',true,'40000000-0000-0000-0000-0000000000a1'),
  ('40000000-0000-0000-0000-000000000012','40000000-0000-0000-0000-000000000001','Colleague','colleague@fin.test',true,'40000000-0000-0000-0000-0000000000a2'),
  ('40000000-0000-0000-0000-000000000013','40000000-0000-0000-0000-000000000001','Alex Emp','alex@fin.test',true,'40000000-0000-0000-0000-0000000000a3'),
  ('40000000-0000-0000-0000-000000000014','40000000-0000-0000-0000-000000000001','Finance','fin@fin.test',true,'40000000-0000-0000-0000-0000000000a4'),
  ('40000000-0000-0000-0000-000000000015','40000000-0000-0000-0000-000000000001','Owner','owner@fin.test',true,'40000000-0000-0000-0000-0000000000a5');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000011','40000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-0000000000c1',true),
  ('40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000012','40000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-0000000000c1',true),
  ('40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000013','40000000-0000-0000-0000-00000000000b','40000000-0000-0000-0000-0000000000c2',true),
  ('40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000014','40000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-0000000000c1',true),
  ('40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-000000000015','40000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '40000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values
  ('40000000-0000-0000-0000-000000000011'::uuid,'employee'),
  ('40000000-0000-0000-0000-000000000012'::uuid,'employee'),
  ('40000000-0000-0000-0000-000000000013'::uuid,'employee'),
  ('40000000-0000-0000-0000-000000000014'::uuid,'finance_manager'),
  ('40000000-0000-0000-0000-000000000015'::uuid,'owner')) v(u, rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('40000000-0000-0000-0000-0000000000d1','40000000-0000-0000-0000-000000000001','person','Fin Customer','+201008881111');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('40000000-0000-0000-0000-0000000000f1','40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-0000000000c1','40000000-0000-0000-0000-0000000000d1','40000000-0000-0000-0000-000000000011','40000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-0000000000c1','draft','Cairo booking','BK-FIN-1'),
  ('40000000-0000-0000-0000-0000000000f2','40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-00000000000b','40000000-0000-0000-0000-0000000000c2','40000000-0000-0000-0000-0000000000d1','40000000-0000-0000-0000-000000000013','40000000-0000-0000-0000-00000000000b','40000000-0000-0000-0000-0000000000c2','draft','Alex booking','BK-FIN-2');

-- MINE, COLLEAGUE'S (same branch+department), and ANOTHER BRANCH'S. Same tenant throughout, so the
-- only variable under test is ownership/branch -- not tenancy.
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
                                  owner_user_id, owner_branch_id, owner_department_id, currency_code) values
  ('40000000-0000-0000-0000-0000000000e1','40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-0000000000f1','hotel','draft','40000000-0000-0000-0000-000000000011','40000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-0000000000c1','EGP'),
  ('40000000-0000-0000-0000-0000000000e2','40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-0000000000f1','hotel','draft','40000000-0000-0000-0000-000000000012','40000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-0000000000c1','EGP'),
  ('40000000-0000-0000-0000-0000000000e3','40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-0000000000f2','hotel','draft','40000000-0000-0000-0000-000000000013','40000000-0000-0000-0000-00000000000b','40000000-0000-0000-0000-0000000000c2','EGP');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"40000000-0000-0000-0000-0000000000a1"}', true);

-- =============================================================================================
-- A. CONTROLS FIRST. The actor holds the permission and can see the colleague's row -- so every
--    denial below is about SCOPE, never about a missing permission or an invisible row.
-- =============================================================================================
select ok(app.has_permission('ENTER_COST'),
  'CONTROL: the employee genuinely HOLDS ENTER_COST -- otherwise the denials would prove nothing');
select ok(app.has_permission('ENTER_SELLING_PRICE'),
  'CONTROL: ...and ENTER_SELLING_PRICE');
select is(
  (select count(*)::int from public.booking_items where id='40000000-0000-0000-0000-0000000000e2'),
  1,
  'CONTROL: the colleague''s item IS visible to them (department scope) -- so the refusal below is scope, not invisibility');

-- =============================================================================================
-- B. OWN ITEM -- allowed. Canon 28: ENTER_COST / ENTER_SELLING_PRICE, scope `assigned`.
-- =============================================================================================
select lives_ok(
  $$update public.booking_items set cost_amount = 1000 where id='40000000-0000-0000-0000-0000000000e1'$$,
  'ALLOWED: the employee prices their OWN item -- cost');
select lives_ok(
  $$update public.booking_items set selling_amount = 1500 where id='40000000-0000-0000-0000-0000000000e1'$$,
  'ALLOWED: ...and its selling price');
-- Read back as postgres: SPEC-139 withholds SELECT on `cost_amount` from `authenticated` entirely,
-- so even the OWNER of the item cannot read the column directly (they would use app.item_financials).
-- The employee can WRITE their own cost and still not SELECT it -- write authority and read privacy
-- are genuinely independent here, which is the SPEC-139 design.
reset role;
select is(
  (select cost_amount from public.booking_items where id='40000000-0000-0000-0000-0000000000e1'),
  1000::numeric,
  '...and the value actually persisted -- "did not throw" is not evidence that a write occurred');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"40000000-0000-0000-0000-0000000000a1"}', true);

-- =============================================================================================
-- C. COLLEAGUE'S ITEM -- denied. Same actor, same permission, same branch and department.
-- =============================================================================================
select throws_ok(
  $$update public.booking_items set cost_amount = 9999 where id='40000000-0000-0000-0000-0000000000e2'$$,
  '42501', null,
  'DENIED: pricing a COLLEAGUE''s item -- the exact over-grant that made SPEC-154 withhold this permission');
select throws_ok(
  $$update public.booking_items set selling_amount = 9999 where id='40000000-0000-0000-0000-0000000000e2'$$,
  '42501', null,
  'DENIED: ...and its selling price');
reset role;
select is(
  (select cost_amount from public.booking_items where id='40000000-0000-0000-0000-0000000000e2'),
  0::numeric,
  '...and the colleague''s figure is untouched');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"40000000-0000-0000-0000-0000000000a1"}', true);

-- =============================================================================================
-- D. ANOTHER BRANCH -- denied, and invisible.
-- =============================================================================================
select is(
  (select count(*)::int from public.booking_items where id='40000000-0000-0000-0000-0000000000e3'),
  0,
  'DENIED: the other branch''s item is not even visible -- branch isolation is upstream of pricing');

-- =============================================================================================
-- E. DIRECT INSERT is guarded too -- the bypass path, not only UPDATE.
-- =============================================================================================
select throws_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code,
                                      owner_user_id, owner_branch_id, owner_department_id, currency_code, cost_amount)
    values ('40000000-0000-0000-0000-000000000001','40000000-0000-0000-0000-0000000000f1','hotel','draft',
            '40000000-0000-0000-0000-000000000012','40000000-0000-0000-0000-00000000000a','40000000-0000-0000-0000-0000000000c1','EGP', 5000)$$,
  '42501', null,
  'DENIED: creating an item priced for someone ELSE -- INSERT is scoped exactly as UPDATE is');

-- =============================================================================================
-- F. THE LOCK still bites, and is still finance-only. Scope did not replace authority.
-- =============================================================================================
-- The claim must be cleared too, not just the DB role: the guard's service exemption keys on
-- `auth.uid()`, which still resolves from request.jwt.claims after `reset role` alone.
reset role;
select set_config('request.jwt.claims', null, true);
update public.booking_items set cost_locked_at = now() where id='40000000-0000-0000-0000-0000000000e1';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"40000000-0000-0000-0000-0000000000a1"}', true);

select throws_ok(
  $$update public.booking_items set cost_amount = 2000 where id='40000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'DENIED: once LOCKED, even their own item needs EDIT_LOCKED_COST -- SPEC-145 authority survives SPEC-154-A');

select throws_ok(
  $$update public.booking_items set cost_locked_at = null where id='40000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'DENIED: ...and they cannot clear the lock to get around it');

-- =============================================================================================
-- G. FINANCE keeps its authority -- on an item it does NOT own, which is the whole point of
--    EDIT_LOCKED_COST carrying canon scope `tenant` rather than `assigned`.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"40000000-0000-0000-0000-0000000000a4","aal":"aal2"}', true);
select lives_ok(
  $$update public.booking_items set cost_amount = 3000 where id='40000000-0000-0000-0000-0000000000e1'$$,
  'ALLOWED: finance edits a LOCKED cost on an item it does not own -- assignment scope must not reach EDIT_LOCKED_COST');

-- =============================================================================================
-- H. OWNER keeps tenant-wide reach -- the single deliberate exemption in the new predicate.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"40000000-0000-0000-0000-0000000000a5","aal":"aal2"}', true);
select lives_ok(
  $$update public.booking_items set selling_amount = 7777 where id='40000000-0000-0000-0000-0000000000e2'$$,
  'ALLOWED: the owner prices an item they do not personally own -- has_tenant_wide_read() is the exemption');

select finish();
rollback;
