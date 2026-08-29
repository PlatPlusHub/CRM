-- pgTAP: QUO-1 -- a quotation's total is the sum of its items, on every path.
--
-- The third instance of the FIN-8 class, and the first that is a DERIVED VALUE rather than a
-- refusal. `app.add_quotation_item` recomputes `quotations.total_amount` from the items after every
-- insert -- so the total is DEFINED as that sum -- and maintained on that one path only, while
-- `quotation_items` is directly writable by any of the six CREATE_QUOTATION roles.
--
-- REPRODUCED as an ordinary `employee`: RPC added a 1000 item (total 1000), a direct INSERT of a
-- 5000 item left total=1000 / items=6000, and a direct UPDATE left total=1000 / items=5001. The
-- header a customer is quoted and the lines it is built from disagreed by any amount, in either
-- direction -- and `advance_quotation` reads `total_amount` when the quotation is sent and accepted,
-- so the wrong number is the one that travels into the booking.
--
-- RECOMPUTED rather than REFUSED, which is the one place this differs from FIN-8/FIN-10: those guard
-- invariants, where rejecting the write is the only correct answer. This is a derived value with no
-- independent source -- `quotations` has no discount or override column -- so the database can
-- simply keep it right. Refusing a legitimate line to protect a number it can compute would be the
-- larger change, not the safer one.
create extension if not exists pgtap with schema extensions;

begin;
select plan(13);

insert into auth.users (id, email) values ('73000000-0000-0000-0000-0000000000a1','emp@quo.test');
insert into public.tenants (id, name, slug, status) values
  ('73000000-0000-0000-0000-000000000001','Quo Travel','quo-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '73000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('73000000-0000-0000-0000-00000000000a','73000000-0000-0000-0000-000000000001','Cairo','quo-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('73000000-0000-0000-0000-0000000000c1','73000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('73000000-0000-0000-0000-000000000011','73000000-0000-0000-0000-000000000001','Emp','emp@quo.test',true,'73000000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('73000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000011','73000000-0000-0000-0000-00000000000a','73000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '73000000-0000-0000-0000-000000000001','73000000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'employee';
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('73000000-0000-0000-0000-0000000000d1','73000000-0000-0000-0000-000000000001','person','Buyer');

-- =============================================================================================
-- 1-3. STRUCTURE, and the evidence that this is a DEFINITION rather than a new business rule.
-- =============================================================================================
select ok(
  (select count(*) from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where c.relname = 'quotation_items' and t.tgname = 'quotation_items_recompute_total'
      and not t.tgisinternal
      and (t.tgtype & 4) <> 0 and (t.tgtype & 16) <> 0 and (t.tgtype & 8) <> 0) = 1,
  'the recompute trigger covers INSERT, UPDATE and DELETE -- a line can be added, edited or removed');

select is(
  (select count(*)::int from information_schema.columns
    where table_schema = 'public' and table_name = 'quotations'
      and column_name ~ 'discount|override|adjust'),
  0,
  'EVIDENCE THIS IS A DEFINITION, NOT A NEW RULE: `quotations` has no discount, override or adjustment column, so the total has no source other than its items');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'recompute_quotation_total' and p.prosrc ~ 'auth\.uid\(\)'),
  0,
  'no session-less exemption -- a stale total left by a platform path is exactly as wrong as one left by a tenant user');

-- =============================================================================================
-- 4-6. THE AUTHORIZED PATH IS UNCHANGED.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"73000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select ok(app.has_permission('CREATE_QUOTATION'),
  'POSITIVE CONTROL: an ordinary employee holds CREATE_QUOTATION -- this is a six-role capability, not an administrative one');

select lives_ok(
  $q$select app.add_quotation_item(
      app.create_quotation('73000000-0000-0000-0000-0000000000d1','EGP'), 'flight_ticket', 1000, 1)$q$,
  'THE ONE THAT MATTERS: the RPC still adds a line -- a guard that blocked this would stop the agency quoting at all');

select is(
  (select q.total_amount::text || '/' || (select coalesce(sum(qi.total_amount),0)::text from public.quotation_items qi where qi.quotation_id = q.id)
     from public.quotations q where q.tenant_id = '73000000-0000-0000-0000-000000000001'),
  '1000.0000/1000.0000',
  '...and header and lines agree, as they always did on this path');

-- =============================================================================================
-- 7-10. THE REPRODUCTION, on each direct path it can take.
-- =============================================================================================
insert into public.quotation_items (tenant_id, quotation_id, service_type_code, quantity, unit_price, total_amount, currency_code)
select '73000000-0000-0000-0000-000000000001', q.id, 'flight_ticket', 1, 5000, 5000, 'EGP'
from public.quotations q where q.tenant_id = '73000000-0000-0000-0000-000000000001';

select is(
  (select q.total_amount::text from public.quotations q where q.tenant_id = '73000000-0000-0000-0000-000000000001'),
  '6000.0000',
  'REPRODUCTION CLOSED (INSERT): a line added by direct DML is now reflected in the header -- it read 1000 against items of 6000 before');

update public.quotation_items set total_amount = 1, unit_price = 1
 where tenant_id = '73000000-0000-0000-0000-000000000001' and total_amount = 1000;

select is(
  (select q.total_amount::text from public.quotations q where q.tenant_id = '73000000-0000-0000-0000-000000000001'),
  '5001.0000',
  'REPRODUCTION CLOSED (UPDATE): editing a line''s price by direct DML moves the header too');

select is(
  (select q.total_amount::text || '/' || (select coalesce(sum(qi.total_amount),0)::text from public.quotation_items qi where qi.quotation_id = q.id)
     from public.quotations q where q.tenant_id = '73000000-0000-0000-0000-000000000001'),
  '5001.0000/5001.0000',
  'INVARIANT: header equals the sum of lines after every path exercised above');

reset role;
delete from public.quotation_items
 where tenant_id = '73000000-0000-0000-0000-000000000001' and total_amount = 5000;

select is(
  (select q.total_amount::text from public.quotations q where q.tenant_id = '73000000-0000-0000-0000-000000000001'),
  '1.0000',
  'REPRODUCTION CLOSED (DELETE): removing a line drops the header -- reachable only by a platform path, since `authenticated` holds no DELETE here, which is why the trigger covers it defensively');

-- =============================================================================================
-- 11. The class, so the next derived money total cannot arrive unguarded.
-- =============================================================================================
select cmp_ok(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal
      and (t.tgconstraint <> 0 or t.tgname = 'quotation_items_recompute_total')
      and c.relname in ('journal_entries','journal_entry_lines','payment_allocations','invoices','quotation_items')),
  '>=', 5,
  'THE CLASS: FIN-8, FIN-10 and QUO-1 are one defect -- a set-level rule living in a single function -- and every money table that carries one now enforces it path-independently');

-- =============================================================================================
-- 12-13. LOAD-BEARING: is `quotation_items_recompute_total` what keeps the total honest?
--
-- QUO-1 RECOMPUTES rather than refuses, so the mutation reads the other way round from FIN-8/FIN-10:
-- with the trigger dropped the total must go STALE, and on restore the next write must repair it.
-- Assertion 11 only counts that a trigger EXISTS; a trigger that exists and does nothing would pass
-- it. This pair is what makes that count mean something (PAR-3, 2026-08-30).
-- =============================================================================================
savepoint before_enforcer_mutation;
drop trigger quotation_items_recompute_total on public.quotation_items;

insert into public.quotation_items (tenant_id, quotation_id, service_type_code, quantity, unit_price, total_amount, currency_code)
select '73000000-0000-0000-0000-000000000001', q.id, 'flight_ticket', 1, 777, 777, 'EGP'
from public.quotations q where q.tenant_id = '73000000-0000-0000-0000-000000000001';

select isnt(
  (select q.total_amount::text from public.quotations q where q.tenant_id = '73000000-0000-0000-0000-000000000001'),
  (select coalesce(sum(qi.total_amount),0)::text from public.quotation_items qi where qi.tenant_id = '73000000-0000-0000-0000-000000000001'),
  'MUTATION: with the recompute trigger dropped the headline total goes STALE against its own items -- which is exactly the QUO-1 defect, so that trigger is what closes it');

rollback to savepoint before_enforcer_mutation;

insert into public.quotation_items (tenant_id, quotation_id, service_type_code, quantity, unit_price, total_amount, currency_code)
select '73000000-0000-0000-0000-000000000001', q.id, 'flight_ticket', 1, 777, 777, 'EGP'
from public.quotations q where q.tenant_id = '73000000-0000-0000-0000-000000000001';

select is(
  (select q.total_amount::text from public.quotations q where q.tenant_id = '73000000-0000-0000-0000-000000000001'),
  (select coalesce(sum(qi.total_amount),0)::text from public.quotation_items qi where qi.tenant_id = '73000000-0000-0000-0000-000000000001'),
  'RESTORED: with the trigger back the identical insert leaves header and lines agreeing again');

select finish();
rollback;
