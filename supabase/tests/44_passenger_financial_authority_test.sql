-- pgTAP: SPEC-159-A -- the per-passenger financial columns get the authority and the privacy their
-- siblings on `booking_items` have had since SPEC-139 / SPEC-145 / SPEC-154-A.
--
-- This defect was found by the SPEC-159 lineage pass, not by a failing test -- `link_passenger_to_-
-- booking_item` had NO test coverage at all, which is how a second financial write path stayed
-- unguarded through four financial packages.
--
-- Every denial below is preceded by controls proving the actor HOLDS the permission and CAN SEE the
-- colleague's row, so each refusal is about scope alone and not about a missing grant or an empty
-- fixture (AGENTS.md §6, no vacuous security tests).
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

insert into auth.users (id, email) values
  ('44000000-0000-0000-0000-0000000000a1','emp-a@pax.test'),
  ('44000000-0000-0000-0000-0000000000a2','emp-b@pax.test');
insert into public.tenants (id, name, slug, status) values
  ('44000000-0000-0000-0000-000000000001','Pax Travel','pax-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '44000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('44000000-0000-0000-0000-00000000000a','44000000-0000-0000-0000-000000000001','Cairo','pax-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('44000000-0000-0000-0000-0000000000c1','44000000-0000-0000-0000-000000000001','44000000-0000-0000-0000-00000000000a','sales','Sales');

-- Two employees in the SAME department. That is what makes the colleague's row visible, and
-- therefore what makes the scope denials meaningful rather than incidental.
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('44000000-0000-0000-0000-000000000011','44000000-0000-0000-0000-000000000001','Emp A','emp-a@pax.test',true,'44000000-0000-0000-0000-0000000000a1'),
  ('44000000-0000-0000-0000-000000000012','44000000-0000-0000-0000-000000000001','Emp B','emp-b@pax.test',true,'44000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('44000000-0000-0000-0000-000000000001','44000000-0000-0000-0000-000000000011','44000000-0000-0000-0000-00000000000a','44000000-0000-0000-0000-0000000000c1',true),
  ('44000000-0000-0000-0000-000000000001','44000000-0000-0000-0000-000000000012','44000000-0000-0000-0000-00000000000a','44000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '44000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('44000000-0000-0000-0000-000000000011'::uuid),
             ('44000000-0000-0000-0000-000000000012'::uuid)) v(u)
join public.roles r on r.code = 'employee';

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('44000000-0000-0000-0000-0000000000d1','44000000-0000-0000-0000-000000000001','person','Pax Customer','+201005550000');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                            owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('44000000-0000-0000-0000-0000000000f1','44000000-0000-0000-0000-000000000001','44000000-0000-0000-0000-00000000000a','44000000-0000-0000-0000-0000000000c1','44000000-0000-0000-0000-0000000000d1','44000000-0000-0000-0000-000000000011','44000000-0000-0000-0000-00000000000a','44000000-0000-0000-0000-0000000000c1','draft','Pax booking','BK-PAX-1');

-- Item 1 belongs to A; item 2 belongs to colleague B.
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
      owner_user_id, sales_owner_user_id, operational_owner_user_id,
      owner_branch_id, owner_department_id, currency_code) values
  ('44000000-0000-0000-0000-0000000000e1','44000000-0000-0000-0000-000000000001','44000000-0000-0000-0000-0000000000f1','flight_ticket','draft',
   '44000000-0000-0000-0000-000000000011','44000000-0000-0000-0000-000000000011','44000000-0000-0000-0000-000000000011',
   '44000000-0000-0000-0000-00000000000a','44000000-0000-0000-0000-0000000000c1','EGP'),
  ('44000000-0000-0000-0000-0000000000e2','44000000-0000-0000-0000-000000000001','44000000-0000-0000-0000-0000000000f1','flight_ticket','draft',
   '44000000-0000-0000-0000-000000000012','44000000-0000-0000-0000-000000000012','44000000-0000-0000-0000-000000000012',
   '44000000-0000-0000-0000-00000000000a','44000000-0000-0000-0000-0000000000c1','EGP');

insert into public.passengers (id, tenant_id, first_name, family_name, full_name, passenger_type_code) values
  ('44000000-0000-0000-0000-0000000000b1','44000000-0000-0000-0000-000000000001','Nour','Hassan','Nour Hassan','adult'),
  ('44000000-0000-0000-0000-0000000000b2','44000000-0000-0000-0000-000000000001','Omar','Hassan','Omar Hassan','adult'),
  ('44000000-0000-0000-0000-0000000000b3','44000000-0000-0000-0000-000000000001','Sara','Hassan','Sara Hassan','adult');

-- A pre-existing priced link on the COLLEAGUE's item, seeded before any session exists so the guard
-- lets it through (canon 35 principle 6). Assertions 11-12 attack this row.
insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id,
                                            selling_amount_override, cost_amount_override)
values ('44000000-0000-0000-0000-000000000001','44000000-0000-0000-0000-0000000000e2',
        '44000000-0000-0000-0000-0000000000b3', 5000, 4000);

-- =============================================================================================
-- 1-2. PRIVACY. The financial columns leave `authenticated`'s reach; the operational ones stay.
--      Asserted as column privileges rather than by a failing SELECT, because a table-level grant
--      silently covers columns added later -- which is exactly how this hole appeared.
-- =============================================================================================
select ok(
  not has_column_privilege('authenticated','public.booking_item_passengers','cost_amount_override','SELECT')
  and not has_column_privilege('authenticated','public.booking_item_passengers','selling_amount_override','SELECT'),
  'the per-passenger money is no longer readable by authenticated -- SPEC-139 parity, one table late');

select ok(
  has_column_privilege('authenticated','public.booking_item_passengers','passenger_id','SELECT')
  and has_column_privilege('authenticated','public.booking_item_passengers','booking_item_id','SELECT'),
  '...while the OPERATIONAL columns are untouched -- who is travelling is not a financial secret');

-- =============================================================================================
-- 3-5. CONTROLS. Without these three, every denial below could be explained by a missing
--      permission or an invisible row instead of by scope.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"44000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select ok(app.has_permission('ENTER_COST') and app.has_permission('ENTER_SELLING_PRICE'),
  'CONTROL: employee A HOLDS both financial permissions (SPEC-154-A granted them)');

select ok(app.has_permission('CREATE_BOOKING_ITEM'),
  'CONTROL: ...and CREATE_BOOKING_ITEM, which is all the RPC used to ask for');

select is(
  (select count(*)::int from public.booking_items where id = '44000000-0000-0000-0000-0000000000e2'),
  1,
  'CONTROL: A can SEE the colleague''s booking item (same department) -- so refusals below are about SCOPE');

-- =============================================================================================
-- 6-7. A prices a passenger on their OWN item. Allowed, and it actually persists.
-- =============================================================================================
select lives_ok(
  $$select app.link_passenger_to_booking_item(
      '44000000-0000-0000-0000-0000000000e1','44000000-0000-0000-0000-0000000000b1', 3000, 2000)$$,
  'A prices a passenger on their OWN item -- allowed');

reset role;
select set_config('request.jwt.claims', null, true);
select is(
  (select selling_amount_override::int || '/' || cost_amount_override::int
     from public.booking_item_passengers
    where booking_item_id = '44000000-0000-0000-0000-0000000000e1'
      and passenger_id = '44000000-0000-0000-0000-0000000000b1'),
  '3000/2000',
  '...and the figures were really written -- "it did not throw" is not evidence of a write');

-- =============================================================================================
-- 8-10. THE BYPASS THAT USED TO WORK. A prices a passenger on the COLLEAGUE's item. Before this
--       package the RPC asked only for CREATE_BOOKING_ITEM and never checked whose item it was.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"44000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select throws_ok(
  $$select app.link_passenger_to_booking_item(
      '44000000-0000-0000-0000-0000000000e2','44000000-0000-0000-0000-0000000000b1', null, 9000)$$,
  '42501', null,
  'A cannot attach a COST to a colleague''s item -- the RPC used to allow this outright');

select throws_ok(
  $$select app.link_passenger_to_booking_item(
      '44000000-0000-0000-0000-0000000000e2','44000000-0000-0000-0000-0000000000b1', 9000, null)$$,
  '42501', null,
  '...nor a SELLING PRICE');

select lives_ok(
  $$select app.link_passenger_to_booking_item(
      '44000000-0000-0000-0000-0000000000e2','44000000-0000-0000-0000-0000000000b2')$$,
  '...but linking a passenger with NO price still works -- operational work is not financial work');

-- =============================================================================================
-- 11-12. DIRECT DML, which is the path that never needed the RPC. `authenticated` holds INSERT and
--        UPDATE on this table, so the guard has to be a trigger to be worth anything.
-- =============================================================================================
select throws_ok(
  $$update public.booking_item_passengers set cost_amount_override = 1
     where booking_item_id = '44000000-0000-0000-0000-0000000000e2'
       and passenger_id = '44000000-0000-0000-0000-0000000000b3'$$,
  '42501', null,
  'a direct UPDATE of a colleague''s per-passenger cost is refused -- the trigger, not the RPC, is the guard');

select throws_ok(
  $$select cost_amount_override from public.booking_item_passengers
     where booking_item_id = '44000000-0000-0000-0000-0000000000e2'$$,
  '42501', null,
  'and A cannot even READ the colleague''s per-passenger cost -- the privacy half, at the SQL level');

select finish();
rollback;
