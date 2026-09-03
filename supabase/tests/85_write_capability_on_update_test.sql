-- pgTAP: SEC-1c -- a row you may not create is a row you may not rewrite.
--
-- The defect this pins: `app.guard_write_capability` was attached BEFORE INSERT only on thirteen
-- tables. On four of them (customers, passengers, suppliers, customer_notes) the UPDATE `WITH CHECK`
-- was tenant isolation and nothing else; on eight more it named only VIEW_* permissions, which is
-- RLS-1 ("a read permission confers write authority") and was merged into SEC-1.
--
-- Every refusal below is paired with the two controls that stop it being vacuous: the actor is
-- proven to LACK the permission, and the row is proven VISIBLE first. Without the visibility control
-- a denial cannot be distinguished from "the row was never reachable" -- the exact shape
-- `AGENTS.md §6` forbids. Assertions 9-12 are the positive controls: a fix that stopped legitimate
-- roles working would be a worse defect than the one it closed, and finance losing the ability to
-- issue a booking is the specific regression SEC-1b avoided by leaving UPDATE unguarded at all.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into auth.users (id, email, email_confirmed_at) values
  ('85000000-0000-0000-0000-0000000000a1','owner@sec1c.test',   now()),
  ('85000000-0000-0000-0000-0000000000a2','trainee@sec1c.test', now()),
  ('85000000-0000-0000-0000-0000000000a3','fin@sec1c.test',     now());
insert into public.tenants (id, name, slug, status) values
  ('85000000-0000-0000-0000-000000000001','SEC1c Travel','sec1c','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '85000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('85000000-0000-0000-0000-00000000000a','85000000-0000-0000-0000-000000000001','HQ','sec1c-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('85000000-0000-0000-0000-0000000000c1','85000000-0000-0000-0000-000000000001','85000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('85000000-0000-0000-0000-000000000011','85000000-0000-0000-0000-000000000001','Owner','owner@sec1c.test',true,'85000000-0000-0000-0000-0000000000a1'),
  ('85000000-0000-0000-0000-000000000012','85000000-0000-0000-0000-000000000001','Trainee','trainee@sec1c.test',true,'85000000-0000-0000-0000-0000000000a2'),
  ('85000000-0000-0000-0000-000000000013','85000000-0000-0000-0000-000000000001','Fin','fin@sec1c.test',true,'85000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '85000000-0000-0000-0000-000000000001', u,
       '85000000-0000-0000-0000-00000000000a','85000000-0000-0000-0000-0000000000c1', true
from unnest(array['85000000-0000-0000-0000-000000000011'::uuid,'85000000-0000-0000-0000-000000000012'::uuid,
                  '85000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '85000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('85000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('85000000-0000-0000-0000-000000000012'::uuid,'trainee'),
             ('85000000-0000-0000-0000-000000000013'::uuid,'finance_manager')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('85000000-0000-0000-0000-0000000000d1','85000000-0000-0000-0000-000000000001','person','Real Customer');
insert into public.passengers (id, tenant_id, first_name, family_name, full_name, passenger_type_code) values
  ('85000000-0000-0000-0000-0000000000d2','85000000-0000-0000-0000-000000000001','Real','Passenger','Real Passenger','adult');
-- SUP-4a (202607059900): `suppliers_credit_limit_currency_check` makes the ceiling a PAIR, so an
-- amount without its denomination no longer inserts. The fixture states the currency.
insert into public.suppliers (id, tenant_id, name, supplier_type_code, credit_limit_amount, credit_limit_currency_code) values
  ('85000000-0000-0000-0000-0000000000d3','85000000-0000-0000-0000-000000000001','Airline','airline', 1000, 'EGP');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id) values
  ('85000000-0000-0000-0000-0000000000b1','85000000-0000-0000-0000-000000000001','85000000-0000-0000-0000-00000000000a','85000000-0000-0000-0000-0000000000c1','85000000-0000-0000-0000-0000000000d1','confirmed','Trip','BR-SEC1C-1','85000000-0000-0000-0000-000000000011');

-- =============================================================================================
-- 1-3. STRUCTURE. The class, not the three tables the defect was reproduced on.
-- =============================================================================================
select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and t.tgname like '%\_guard\_write\_capability'
      and (t.tgtype & 4) <> 0 and (t.tgtype & 16) = 0),
  0,
  'SEC-1c: NO table carries the write-capability guard on INSERT only -- the INSERT-only shape WAS the defect');

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and t.tgname like '%\_guard\_write\_capability'
      and c.relname = any (array['approval_requests','bookings','complaints','conversations','customer_notes',
                                 'customers','documents','leads','passengers','quotations',
                                 'service_requests','suppliers','tasks'])
      and (t.tgtype & 2) <> 0 and (t.tgtype & 4) <> 0 and (t.tgtype & 16) <> 0),
  13,
  '...and all thirteen fire BEFORE INSERT OR UPDATE');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'guard_write_capability' and p.prosrc ~ 'auth\.uid\(\)'),
  1,
  'the session-less early return is intact -- process_lead_sla and the platform paths are unchanged');

-- =============================================================================================
-- 4-8. THE REPRODUCER, refused. Controls first: the trainee lacks the permission AND sees the row.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"85000000-0000-0000-0000-0000000000a2"}', true);

select ok(
  not app.has_permission('CREATE_CUSTOMER')
  and not app.has_permission('CREATE_BOOKING_ITEM')
  and not app.has_permission('ASSIGN_SUPPLIER'),
  'CONTROL: the trainee holds none of CREATE_CUSTOMER / CREATE_BOOKING_ITEM / ASSIGN_SUPPLIER');

select is(
  (select count(*)::int from public.customers  where id = '85000000-0000-0000-0000-0000000000d1')
  + (select count(*)::int from public.passengers where id = '85000000-0000-0000-0000-0000000000d2')
  + (select count(*)::int from public.suppliers  where id = '85000000-0000-0000-0000-0000000000d3'),
  3,
  'CONTROL: ...and CAN SEE all three rows -- so every refusal below is capability, never reach');

select throws_ok(
  $$update public.customers set full_name = 'Overwritten By Trainee'
     where id = '85000000-0000-0000-0000-0000000000d1'$$,
  '42501', null,
  'REPRODUCER: a trainee can no longer rewrite a customer -- this succeeded before 202607059100');

select throws_ok(
  $$update public.passengers set full_name = 'Overwritten Passenger'
     where id = '85000000-0000-0000-0000-0000000000d2'$$,
  '42501', null,
  '...nor a passenger, whose name is what appears on a ticket');

-- 202607059600 (SUP-2): this assertion and its mutation pair below name `phone`, not
-- `credit_limit_amount`, and the change is deliberate. The credit column now carries a SECOND guard
-- (`suppliers_guard_credit_authority`), so a mutation that drops `suppliers_guard_write_capability`
-- alone can no longer make that write succeed -- the `lives_ok` half would fail and, worse, the
-- `throws_ok` half would keep passing on the OTHER trigger's refusal, quietly measuring nothing.
-- The ordering is not incidental: PostgreSQL fires BEFORE row triggers in NAME order, and
-- 'c' < 'w', so `suppliers_guard_credit_authority` always speaks FIRST -- a refusal on the ceiling
-- would be attributed to the capability guard while actually coming from the credit one.
-- `phone` is an ordinary column reachable only through the capability guard, so these three
-- assertions once again pin exactly the trigger they name. Who may set the CEILING is owned by
-- `90_supplier_credit_write_authority_test.sql`, where its own defect injection lives.
select throws_ok(
  $$update public.suppliers set phone = '+20 111 111 1111'
     where id = '85000000-0000-0000-0000-0000000000d3'$$,
  '42501', null,
  '...nor a supplier record, which carries the agency''s commercial relationships');

-- =============================================================================================
-- 9-12. POSITIVE CONTROLS. The union set exists so that these keep working.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"85000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$update public.customers set full_name = 'Renamed By Owner'
     where id = '85000000-0000-0000-0000-0000000000d1'$$,
  'POSITIVE CONTROL: the owner, holding CREATE_CUSTOMER, still updates a customer');

select is(
  (select full_name from public.customers where id = '85000000-0000-0000-0000-0000000000d1'),
  'Renamed By Owner',
  '...and it PERSISTED -- "did not throw" is not evidence that a write occurred');

-- The specific regression SEC-1b avoided by leaving UPDATE unguarded: finance_manager holds
-- ISSUE/CANCEL/REFUND/REISSUE_BOOKING and NOT CREATE_BOOKING. A CREATE-only rule would strip it.
select set_config('request.jwt.claims','{"sub":"85000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);

select ok(
  not app.has_permission('CREATE_BOOKING') and app.has_permission('ISSUE_BOOKING'),
  'CONTROL: finance holds ISSUE_BOOKING but NOT CREATE_BOOKING -- the premise SEC-1b acted on');

select lives_ok(
  $$update public.bookings set title = 'Touched By Finance'
     where id = '85000000-0000-0000-0000-0000000000b1'$$,
  'POSITIVE CONTROL: ...and finance can STILL write the booking, because the UPDATE set is the UNION');

-- =============================================================================================
-- 13-14. CROSS-TENANT, and the mapping-completeness invariant.
-- =============================================================================================
select is(
  (select count(*)::int from public.suppliers where tenant_id <> '85000000-0000-0000-0000-000000000001'),
  0,
  'CROSS-TENANT: finance sees no supplier outside its own tenant -- RLS is unchanged by this migration');

reset role;
select set_config('request.jwt.claims', null, true);

-- Every table carrying the guard must have a mapping, or the guard raises rather than returning NEW.
-- Pinning it here keeps a future attachment from silently reaching the `v_perms is null` branch.
select is(
  (select count(*)::int
     from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_proc p on p.oid = t.tgfoid
     join pg_namespace n on n.oid = p.pronamespace
    where not t.tgisinternal and n.nspname = 'app' and p.proname = 'guard_write_capability'
      and not exists (
        select 1 from pg_proc g join pg_namespace gn on gn.oid = g.pronamespace
         where gn.nspname = 'app' and g.proname = 'guard_write_capability'
           and g.prosrc like '%''' || c.relname || '''%')),
  0,
  'every table carrying the guard is named in its mapping -- no attachment can reach the unmapped branch');

-- =============================================================================================
-- 15-16. PAR-4 LOAD-BEARING PAIR. Everything above proves the write is refused; none of it proves
--        the REFUSAL COMES FROM THIS TRIGGER. Without this pair, deleting `202607059100` entirely
--        could leave the file green if some other rule happened to refuse the same statement.
--        So: drop the trigger inside a savepoint, assert the violation SUCCEEDS, roll back, assert
--        it is refused again. A security test that cannot detect its own guard being removed is
--        incomplete (`AGENTS.md §6`).
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

savepoint before_mutation;
drop trigger suppliers_guard_write_capability on public.suppliers;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"85000000-0000-0000-0000-0000000000a2"}', true);

select lives_ok(
  $$update public.suppliers set phone = '+20 111 111 1111'
     where id = '85000000-0000-0000-0000-0000000000d3'$$,
  'MUTATION: with the trigger dropped the trainee CAN rewrite a supplier -- so the refusal above is this guard, not a coincidence');

reset role;
select set_config('request.jwt.claims', null, true);
rollback to savepoint before_mutation;

-- The session must be re-established after the rollback: an earlier assertion's role would make the
-- next probe measure "never attempted" rather than "denied", which is the confusion this repository
-- has already met twice in tests 70 and 72.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"85000000-0000-0000-0000-0000000000a2"}', true);

select throws_ok(
  $$update public.suppliers set phone = '+20 111 111 1111'
     where id = '85000000-0000-0000-0000-0000000000d3'$$,
  '42501', null,
  '...and with the trigger restored it is refused again -- the pair is what makes assertion 7 load-bearing');

select * from finish();
rollback;
