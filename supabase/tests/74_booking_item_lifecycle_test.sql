-- pgTAP: BOOK-1 -- a closed booking cannot earn new revenue, on any path.
--
-- API-3, booking/passenger family. `app.create_booking_item` refuses to add an item to an archived,
-- completed or cancelled booking; `app.link_passenger_to_booking_item` refuses to attach a passenger
-- to an item on such a booking, or to an item that is itself cancelled, no_show or archived. Each
-- rule lived in exactly one function.
--
-- REPRODUCED as an ordinary `employee` holding CREATE_BOOKING_ITEM, ENTER_COST and
-- ENTER_SELLING_PRICE -- the same permissions the RPC charges. Against a booking driven to
-- `cancelled` through the legal RPC path, the RPC refused and a direct INSERT succeeded: selling
-- 5000, cost 3000, gross profit 2000, and `commission_rate` 0.10 derived automatically by
-- `booking_items_derive_commission_rate`. `gross_profit = selling - cost` and
-- `employee_commission = max(gross,0) x 10%` are ratified rules, so a trip that never happened
-- produced 200 of commission while the booking beside it still read `cancelled`. Nothing was
-- emitted either -- `booking_item_created` comes from the RPC, so the direct path is unaudited.
--
-- NOT the aggregate-across-rows subclass, and that is worth recording: SEC-1's clause-3 filter would
-- NOT have found this. The rule is about ANOTHER ROW IN ANOTHER TABLE -- the parent's status -- which
-- a CHECK cannot reference and a foreign key cannot qualify. The filter is a lead, not a sieve.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into auth.users (id, email) values
  ('74000000-0000-0000-0000-0000000000a1','emp@book.test'),
  ('74000000-0000-0000-0000-0000000000a2','other@book.test');
insert into public.tenants (id, name, slug, status) values
  ('74000000-0000-0000-0000-000000000001','Book Travel','book-travel','active'),
  ('74000000-0000-0000-0000-000000000002','Rival Travel','book-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and t.id in ('74000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000002');
insert into public.branches (id, tenant_id, name, slug) values
  ('74000000-0000-0000-0000-00000000000a','74000000-0000-0000-0000-000000000001','Cairo','book-cairo'),
  ('74000000-0000-0000-0000-00000000000b','74000000-0000-0000-0000-000000000002','Giza','book-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('74000000-0000-0000-0000-0000000000c1','74000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-00000000000a','sales','Sales'),
  ('74000000-0000-0000-0000-0000000000c2','74000000-0000-0000-0000-000000000002','74000000-0000-0000-0000-00000000000b','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('74000000-0000-0000-0000-000000000011','74000000-0000-0000-0000-000000000001','Emp','emp@book.test',true,'74000000-0000-0000-0000-0000000000a1'),
  ('74000000-0000-0000-0000-000000000012','74000000-0000-0000-0000-000000000002','Other','other@book.test',true,'74000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('74000000-0000-0000-0000-000000000001','74000000-0000-0000-0000-000000000011','74000000-0000-0000-0000-00000000000a','74000000-0000-0000-0000-0000000000c1',true),
  ('74000000-0000-0000-0000-000000000002','74000000-0000-0000-0000-000000000012','74000000-0000-0000-0000-00000000000b','74000000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant' from (values
  ('74000000-0000-0000-0000-000000000001'::uuid,'74000000-0000-0000-0000-000000000011'::uuid,'employee'),
  ('74000000-0000-0000-0000-000000000002'::uuid,'74000000-0000-0000-0000-000000000012'::uuid,'employee')) v(t,u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('74000000-0000-0000-0000-0000000000d1','74000000-0000-0000-0000-000000000001','person','Buyer');
insert into public.passengers (id, tenant_id, first_name, family_name, full_name, passenger_type_code) values
  ('74000000-0000-0000-0000-00000000f1a1','74000000-0000-0000-0000-000000000001','Pax','One','Pax One','adult'),
  ('74000000-0000-0000-0000-00000000f1a2','74000000-0000-0000-0000-000000000001','Pax','Two','Pax Two','adult');

-- =============================================================================================
-- 1-3. STRUCTURE, and the two design decisions that differ from the guards beside it.
-- =============================================================================================
select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where t.tgname in ('booking_items_enforce_lifecycle','booking_item_passengers_enforce_lifecycle')
      and not t.tgisinternal
      and (t.tgtype & 2) <> 0 and (t.tgtype & 4) <> 0 and (t.tgtype & 16) <> 0),
  2,
  'both lifecycle triggers exist as BEFORE INSERT OR UPDATE -- UPDATE matters because an item can be MOVED into a closed booking');

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where t.tgname in ('booking_items_enforce_lifecycle','booking_item_passengers_enforce_lifecycle')
      and t.tgconstraint <> 0),
  0,
  'DELIBERATE: plain BEFORE triggers, not DEFERRED constraint triggers -- unlike FIN-8/FIN-10 this invariant holds at every instant, and deferring it would break the legal order (add items, THEN cancel)');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app'
      and p.proname in ('enforce_booking_item_lifecycle','enforce_booking_item_passenger_lifecycle')
      and p.prosrc ~ 'auth\.uid\(\)'),
  0,
  'no session-less exemption -- this is INTEGRITY, not authorization, so a migration does not escape it either (unlike guard_booking_item_financials, which does)');

-- =============================================================================================
-- 4-7. THE AUTHORIZED PATH IS UNCHANGED. Without these, every refusal below could be a guard that
--      simply blocks everything.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"74000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select ok(app.has_permission('CREATE_BOOKING_ITEM') and app.has_permission('ENTER_COST')
          and app.has_permission('ENTER_SELLING_PRICE'),
  'POSITIVE CONTROL: an ordinary employee holds every permission the RPC charges -- so each refusal below is the lifecycle rule, not the permission');

select lives_ok(
  $q$select app.create_booking_item(
       app.create_booking('74000000-0000-0000-0000-0000000000d1', null, 'Trip',
         '74000000-0000-0000-0000-00000000000a','74000000-0000-0000-0000-0000000000c1',
         current_date + 30, current_date + 40, 'EG', 'Cairo', null, null),
       'flight_ticket', 'EGP', 3000, 5000)$q$,
  'THE ONE THAT MATTERS: an item is still created on an OPEN booking -- a guard that blocked this would stop the agency selling at all');

select lives_ok(
  $q$select app.link_passenger_to_booking_item(
       (select id from public.booking_items limit 1),
       '74000000-0000-0000-0000-00000000f1a1', 5000, 3000)$q$,
  '...and a passenger is still linked while the booking is open, overrides and all');

select is(
  (select count(*)::int from public.booking_item_passengers),
  1,
  'and it actually wrote a row -- "it did not throw" is not evidence that a link was made');

-- =============================================================================================
-- 8. Cancelling a booking that ALREADY HAS ITEMS must keep working. This is the deliberate
--    asymmetry with FIN-10, which had to guard both sides of its inequality: here the mirror case
--    is correct business behaviour, so there is no trigger on `bookings` and that is a decision.
-- =============================================================================================
select lives_ok(
  $q$do $x$
     declare v_b uuid;
     begin
       select id into v_b from public.bookings limit 1;
       perform app.advance_booking(v_b, 'pending_approval', 'submit');
       perform app.advance_booking(v_b, 'cancelled', 'closure');
     end $x$$q$,
  'ASYMMETRY, deliberate: a booking that already carries items can still be cancelled -- only the reverse order is the violation');

-- =============================================================================================
-- 9-12. THE REPRODUCTION, on every path it can take.
-- =============================================================================================
select throws_ok(
  $q$select app.create_booking_item((select id from public.bookings limit 1), 'flight_ticket', 'EGP', 0, 0)$q$,
  null, null,
  'the RPC still refuses an item on a cancelled booking, exactly as before');

select throws_ok(
  $q$insert into public.booking_items
       (tenant_id, booking_id, service_type_code, base_status_code, currency_code,
        cost_amount, selling_amount, owner_user_id, sales_owner_user_id, operational_owner_user_id,
        owner_branch_id, owner_department_id)
     select '74000000-0000-0000-0000-000000000001', b.id, 'flight_ticket', 'draft', 'EGP',
            3000, 5000, '74000000-0000-0000-0000-000000000011','74000000-0000-0000-0000-000000000011',
            '74000000-0000-0000-0000-000000000011','74000000-0000-0000-0000-00000000000a',
            '74000000-0000-0000-0000-0000000000c1'
       from public.bookings b limit 1$q$,
  '23514', null,
  'REPRODUCTION CLOSED: the original probe -- 5000 of selling on a CANCELLED booking by direct DML, commission derived automatically -- is refused');

select throws_ok(
  $q$select app.link_passenger_to_booking_item(
       (select id from public.booking_items limit 1),
       '74000000-0000-0000-0000-00000000f1a2', 999, 111)$q$,
  null, null,
  'the RPC still refuses a passenger on an item whose booking is cancelled');

select throws_ok(
  $q$insert into public.booking_item_passengers
       (tenant_id, booking_item_id, passenger_id, selling_amount_override, cost_amount_override)
     select '74000000-0000-0000-0000-000000000001', bi.id, '74000000-0000-0000-0000-00000000f1a2', 999, 111
       from public.booking_items bi limit 1$q$,
  '23514', null,
  'REPRODUCTION CLOSED (passengers): and the direct link is refused too -- the item exists and is visible, so this is the lifecycle rule rather than an empty query');

-- =============================================================================================
-- 13. NON-MUTATION. The refusals above must have changed nothing.
-- =============================================================================================
select is(
  (select count(*)::int from public.booking_items)::text || '/' ||
  (select count(*)::int from public.booking_item_passengers)::text,
  '1/1',
  'NON-MUTATION: still exactly the one legal item and the one legal passenger link after four refusals');

-- =============================================================================================
-- 14. TENANT ISOLATION is untouched by this package, and proven rather than assumed.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"74000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.bookings),
  0,
  'the rival tenant''s employee sees none of this -- so nothing above leaked across the tenant boundary');

-- =============================================================================================
-- 15-16. LOAD-BEARING (PAR-4): is the NAMED trigger what refuses, or would something else have?
--        The mutation lives inside a savepoint and is rolled back; the file is a transaction that
--        rolls back regardless.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"74000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

savepoint before_enforcer_mutation;
reset role;
drop trigger booking_items_enforce_lifecycle on public.booking_items;
set local role authenticated;

select lives_ok(
  $q$insert into public.booking_items
       (tenant_id, booking_id, service_type_code, base_status_code, currency_code,
        cost_amount, selling_amount, owner_user_id, sales_owner_user_id, operational_owner_user_id,
        owner_branch_id, owner_department_id)
     select '74000000-0000-0000-0000-000000000001', b.id, 'flight_ticket', 'draft', 'EGP',
            3000, 5000, '74000000-0000-0000-0000-000000000011','74000000-0000-0000-0000-000000000011',
            '74000000-0000-0000-0000-000000000011','74000000-0000-0000-0000-00000000000a',
            '74000000-0000-0000-0000-0000000000c1'
       from public.bookings b limit 1$q$,
  'MUTATION: with the lifecycle trigger dropped, the SAME insert succeeds again -- so that trigger is what refuses it, not the financial guard and not RLS');

rollback to savepoint before_enforcer_mutation;

select throws_ok(
  $q$insert into public.booking_items
       (tenant_id, booking_id, service_type_code, base_status_code, currency_code,
        cost_amount, selling_amount, owner_user_id, sales_owner_user_id, operational_owner_user_id,
        owner_branch_id, owner_department_id)
     select '74000000-0000-0000-0000-000000000001', b.id, 'flight_ticket', 'draft', 'EGP',
            3000, 5000, '74000000-0000-0000-0000-000000000011','74000000-0000-0000-0000-000000000011',
            '74000000-0000-0000-0000-000000000011','74000000-0000-0000-0000-00000000000a',
            '74000000-0000-0000-0000-0000000000c1'
       from public.bookings b limit 1$q$,
  '23514', null,
  'RESTORED: and with the trigger back the identical insert is refused again -- the mutation, not a leftover, is what changed the outcome');

select finish();
rollback;
