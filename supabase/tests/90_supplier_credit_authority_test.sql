-- pgTAP: SUP-2 / SUP-3 / SUP-4a -- who may SET a supplier's credit ceiling, and in what currency.
--
-- WHY THIS FILE EXISTS AT ALL. The migrations it covers (`202607059600`, `202607059700`,
-- `202607059900`) were recovered from Primary on 2026-09-03 after being applied there and never
-- committed. The database returns SQL; it does not return tests. This file is the reconstructed
-- behavioural half, written against the recovered migrations rather than copied from them.
--
-- THE THREE FACTS UNDER TEST, each of which was a separate defect:
--   SUP-2  -- the ceiling's WRITE cost less than its READ, so branch_manager, department_manager and
--             senior_employee could set a figure they are refused permission to know.
--   SUP-3  -- the owner's decision: credit management is its OWN permission, MANAGE_SUPPLIER_CREDIT,
--             orthogonal to ASSIGN_SUPPLIER in BOTH directions.
--   SUP-4a -- a ceiling with no currency is not an amount; the pair is enforced by CHECK.
--
-- `86_supplier_credit_visibility_test.sql` covers the READ half and is not repeated here.
create extension if not exists pgtap with schema extensions;

begin;
select plan(15);

insert into auth.users (id, email, email_confirmed_at) values
  ('90000000-0000-0000-0000-0000000000a1','owner@sup90.test',  now()),
  ('90000000-0000-0000-0000-0000000000a2','senior@sup90.test', now()),
  ('90000000-0000-0000-0000-0000000000a3','fin@sup90.test',    now());
insert into public.tenants (id, name, slug, status) values
  ('90000000-0000-0000-0000-000000000001','Sup90 Travel','sup90','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '90000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('90000000-0000-0000-0000-00000000000a','90000000-0000-0000-0000-000000000001','HQ','sup90-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('90000000-0000-0000-0000-0000000000c1','90000000-0000-0000-0000-000000000001','90000000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('90000000-0000-0000-0000-000000000011','90000000-0000-0000-0000-000000000001','Owner','owner@sup90.test',true,'90000000-0000-0000-0000-0000000000a1'),
  ('90000000-0000-0000-0000-000000000012','90000000-0000-0000-0000-000000000001','Senior','senior@sup90.test',true,'90000000-0000-0000-0000-0000000000a2'),
  ('90000000-0000-0000-0000-000000000013','90000000-0000-0000-0000-000000000001','Fin','fin@sup90.test',true,'90000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '90000000-0000-0000-0000-000000000001', u,
       '90000000-0000-0000-0000-00000000000a','90000000-0000-0000-0000-0000000000c1', true
from unnest(array['90000000-0000-0000-0000-000000000011'::uuid,
                  '90000000-0000-0000-0000-000000000012'::uuid,
                  '90000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '90000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('90000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('90000000-0000-0000-0000-000000000012'::uuid,'senior_employee'),
             ('90000000-0000-0000-0000-000000000013'::uuid,'finance_manager')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.suppliers (id, tenant_id, name, supplier_type_code, credit_limit_amount, credit_limit_currency_code) values
  ('90000000-0000-0000-0000-0000000000e1','90000000-0000-0000-0000-000000000001','Airline A','airline', 10000, 'EGP');
insert into public.suppliers (id, tenant_id, name, supplier_type_code) values
  ('90000000-0000-0000-0000-0000000000e2','90000000-0000-0000-0000-000000000001','Airline B','airline');

-- =============================================================================================
-- 1-3. SUP-4a STRUCTURE. The pair is enforced by the database, not by the RPC alone -- otherwise
--      direct DML would reintroduce exactly the ill-formed value the constraint exists to end.
-- =============================================================================================
select ok(
  (select count(*) = 1 from information_schema.columns
    where table_schema='public' and table_name='suppliers'
      and column_name='credit_limit_currency_code'),
  'SUP-4a: suppliers carries credit_limit_currency_code -- the money standard canon 30 states for every other amount column');

select throws_ok(
  $$insert into public.suppliers (tenant_id, name, supplier_type_code, credit_limit_amount)
    values ('90000000-0000-0000-0000-000000000001','Amount With No Currency','airline', 5000)$$,
  '23514', null,
  'SUP-4a: an amount with NO currency is refused by CHECK -- on the TABLE door, so no path can write one');

select throws_ok(
  $$insert into public.suppliers (tenant_id, name, supplier_type_code, credit_limit_currency_code)
    values ('90000000-0000-0000-0000-000000000001','Currency With No Amount','airline','EGP')$$,
  '23514', null,
  '...and a currency with NO amount is refused too -- the constraint binds in both directions, not just the one that was found');

-- =============================================================================================
-- 4-6. SUP-3 ORTHOGONALITY, DIRECTION ONE: ASSIGN_SUPPLIER does NOT imply credit management.
--      senior_employee is the load-bearing actor -- it holds ASSIGN_SUPPLIER and neither
--      MANAGE_SUPPLIER_CREDIT nor VIEW_FINANCIAL_DOCUMENTS, which is exactly the gap SUP-2 found.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-0000000000a2"}', true);

select is(
  app.has_permission('ASSIGN_SUPPLIER'), true,
  'CONTROL: senior_employee DOES hold ASSIGN_SUPPLIER -- so every refusal below is about the ceiling, not about the table');

select is(
  app.has_permission('MANAGE_SUPPLIER_CREDIT'), false,
  'CONTROL: ...and does NOT hold MANAGE_SUPPLIER_CREDIT');

-- POSITIVE control first: the actor can genuinely write this table. Without it, the refusal below
-- would be indistinguishable from "senior_employee cannot touch suppliers at all", which is the
-- vacuous shape `AGENTS.md §6` forbids.
select lives_ok(
  $$update public.suppliers set name = 'Airline A Renamed'
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  'POSITIVE CONTROL: senior_employee CAN rename the supplier -- ordinary master-data work still costs only ASSIGN_SUPPLIER');

select throws_ok(
  $$update public.suppliers set credit_limit_amount = 999999
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'SUP-2/SUP-3: ...but CANNOT move the credit ceiling -- ASSIGN_SUPPLIER does not imply MANAGE_SUPPLIER_CREDIT');

-- Re-denominating is a change to the ceiling even when the number is untouched: EGP 10,000 and
-- USD 10,000 are different exposures. SUP-4a widened the guard for exactly this.
select throws_ok(
  $$update public.suppliers set credit_limit_currency_code = 'USD'
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'SUP-4a: ...nor RE-DENOMINATE it -- changing EGP to USD changes what the agency may owe as surely as changing the number');

-- =============================================================================================
-- 9-11. DIRECTION TWO: MANAGE_SUPPLIER_CREDIT does NOT imply supplier administration, and the
--       owner's rule 1 -- finance_manager CAN move the ceiling -- actually holds.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;

select is(
  app.has_permission('MANAGE_SUPPLIER_CREDIT'), true,
  'CONTROL: finance_manager holds MANAGE_SUPPLIER_CREDIT -- the owner''s SUP-3 rule 1');

select lives_ok(
  $$update public.suppliers set credit_limit_amount = 20000, credit_limit_currency_code = 'EGP'
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  'SUP-3: finance_manager CAN set the ceiling -- and setting it writes BOTH columns, which is the case the row-image comparison had to be widened for');

-- Read back through the GATED READER, not off the table. SUP-1 revoked column SELECT on
-- `credit_limit_amount` from `authenticated` outright, so `select credit_limit_amount from
-- public.suppliers` raises 42501 even for finance -- which the first draft of this assertion did,
-- and which is the column revoke proving it is in force rather than a problem. `supplier_credit` is
-- the door finance actually has, so reading through it proves persistence AND the read path at once.
select is(
  (select credit_limit_amount from public.supplier_credit('90000000-0000-0000-0000-0000000000e1')),
  20000::numeric,
  '...and it PERSISTED, read back through the gated reader -- "did not throw" is not evidence that a write occurred');

-- =============================================================================================
-- 12-13. THE MUTATION SEQUENCE (PAR-4). Everything above proves the ceiling is refused; none of it
--        proves WHICH guard refuses -- and the first draft of this file assumed the answer and was
--        wrong, which is why the sequence below is in two steps rather than one.
--
--        The ceiling turns out to have TWO INDEPENDENT ENFORCERS, and that is a finding, not an
--        inconvenience:
--          1. `suppliers_guard_credit_authority` -- the dedicated trigger (SUP-2/SUP-3/SUP-4a);
--          2. the credit-only branch inside `app.guard_write_capability` -- which REPLACES the
--             table's ASSIGN_SUPPLIER charge with MANAGE_SUPPLIER_CREDIT when the write touches
--             only the ceiling, so it refuses the same actor for the same reason.
--        Dropping either one alone leaves the ceiling defended. A single-trigger mutation would
--        therefore have reported "the guard is load-bearing" while measuring the OTHER guard --
--        exactly the masking `AGENTS.md §21` warns about, caught here by the assertion failing.
--
--        Deliberately not last: pgTAP's counter lives in a temp table, so an assertion inside a
--        rolled-back savepoint is not counted (TEST-3).
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

savepoint before_mutation;
drop trigger suppliers_guard_credit_authority on public.suppliers;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-0000000000a2"}', true);

select throws_ok(
  $$update public.suppliers set credit_limit_amount = 999999
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'MUTATION 1: with the DEDICATED trigger dropped the ceiling is STILL refused -- guard_write_capability''s credit-only branch is a second, independent enforcer');

reset role;
select set_config('request.jwt.claims', null, true);
drop trigger suppliers_guard_write_capability on public.suppliers;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-0000000000a2"}', true);

select lives_ok(
  $$update public.suppliers set credit_limit_amount = 999999
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  'MUTATION 2: with BOTH dropped it moves again -- so those two triggers are the COMPLETE enforcement set, and the refusals above are neither RLS nor a constraint nor a coincidence');

reset role;
select set_config('request.jwt.claims', null, true);
rollback to savepoint before_mutation;

-- The session must be re-established after the rollback, or the next probe measures "never
-- attempted" rather than "denied" -- the confusion this repository already met in tests 70 and 72.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-0000000000a2"}', true);

select throws_ok(
  $$update public.suppliers set credit_limit_amount = 999999
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  '...and with the trigger restored it is refused again -- the pair is what makes the refusals load-bearing');

-- =============================================================================================
-- 14. THE RPC DOOR. SUP-4a made `app.create_supplier` refuse a half-stated ceiling explicitly, so
--     the caller is told WHICH half is missing rather than reading a constraint name.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$select app.create_supplier('Half Stated','airline', null, null, null, 5000, null)$$,
  '23514', null,
  'SUP-4a: the RPC refuses an amount with no currency too -- both doors, which is ADR-0024');

select * from finish();
rollback;
