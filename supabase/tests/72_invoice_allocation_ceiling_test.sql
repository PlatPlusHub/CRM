-- pgTAP: FIN-10 -- an invoice cannot be paid more than it is worth.
--
-- The second instance of FIN-8's class, and found by LOOKING for it rather than tripping over it:
-- a set-level business invariant enforced in exactly one function. `app.record_payment` refuses to
-- allocate more to an invoice than it is worth -- and takes `pg_advisory_xact_lock` on the invoice
-- first, so the author knew it was a statement about a SET of rows. Nothing enforced it elsewhere.
--
-- REPRODUCED as a `finance_manager` holding RECORD_PAYMENT, the same permission the RPC charges:
-- invoice total 1000, RPC allocated 400, RPC then REFUSED 900 -- and a direct INSERT of a 900
-- allocation succeeded, leaving 1300 allocated against a 1000 invoice, still reporting itself unpaid.
--
-- `payment_allocations` already has `CHECK (allocated_amount >= 0)`, a PER-ROW rule. "The SUM of
-- allocations must not exceed the invoice total" spans rows in two tables; a CHECK cannot say it.
create extension if not exists pgtap with schema extensions;

begin;
select plan(18);

insert into auth.users (id, email) values
  ('72000000-0000-0000-0000-0000000000a1','fin@alloc.test'),
  ('72000000-0000-0000-0000-0000000000a2','emp@alloc.test');
insert into public.tenants (id, name, slug, status) values
  ('72000000-0000-0000-0000-000000000001','Alloc Travel','alloc-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '72000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('72000000-0000-0000-0000-00000000000a','72000000-0000-0000-0000-000000000001','Cairo','alloc-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('72000000-0000-0000-0000-0000000000c1','72000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-00000000000a','finance','Finance');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('72000000-0000-0000-0000-000000000011','72000000-0000-0000-0000-000000000001','Fin','fin@alloc.test',true,'72000000-0000-0000-0000-0000000000a1'),
  ('72000000-0000-0000-0000-000000000012','72000000-0000-0000-0000-000000000001','Emp','emp@alloc.test',true,'72000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('72000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000011','72000000-0000-0000-0000-00000000000a','72000000-0000-0000-0000-0000000000c1',true),
  ('72000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-000000000012','72000000-0000-0000-0000-00000000000a','72000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '72000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('72000000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
             ('72000000-0000-0000-0000-000000000012'::uuid,'employee')) v(u, rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('72000000-0000-0000-0000-0000000000d1','72000000-0000-0000-0000-000000000001','person','Payer');
-- The invoice is created here with a KNOWN id rather than through app.create_invoice, so that no
-- assertion below has to find it with a subquery. Assertion 14's first version did exactly that and
-- was VACUOUS: as the employee the `insert ... select` read ZERO rows -- the invoice is invisible to
-- them -- so it inserted nothing, raised nothing, and "passed" as a denial. That is the trap
-- AGENTS.md s6 names, caught here by the test's own failure rather than by review.
insert into public.invoices (id, tenant_id, customer_id, invoice_number, currency_code, total_amount, status_code, invoice_date)
values ('72000000-0000-0000-0000-0000000000e1','72000000-0000-0000-0000-000000000001',
        '72000000-0000-0000-0000-0000000000d1','INV-ALLOC-1','EGP',1000,'draft', current_date);

-- =============================================================================================
-- 1-2. STRUCTURE. Both sides of the inequality, and the deliberate difference from the
--      AUTHORIZATION guards beside it.
-- =============================================================================================
select is(
  (select count(*)::int from pg_trigger t
    where t.tgname in ('payment_allocations_within_invoice_total','invoices_total_covers_allocations')
      and not t.tgisinternal and t.tgconstraint <> 0 and t.tgdeferrable and t.tginitdeferred),
  2,
  'BOTH sides are guarded as deferred constraint triggers -- allocations can exceed the total by GROWING, or by the total SHRINKING beneath them');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'enforce_invoice_allocation_ceiling'
      and p.prosrc ~ 'auth\.uid\(\)'),
  0,
  'DELIBERATE: no session-less exemption -- integrity, not authorization, exactly as FIN-8 (an over-allocated invoice written by a migration is just as wrong)');

-- =============================================================================================
-- 3-7. THE AUTHORIZED PATH IS UNCHANGED. Positive controls before any refusal.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"72000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('RECORD_PAYMENT'),
  'POSITIVE CONTROL: the finance manager holds RECORD_PAYMENT -- every refusal below is the invariant, not the permission');

select lives_ok(
  $q$select app.issue_invoice('72000000-0000-0000-0000-0000000000e1', 'go')$q$,
  'the 1000 EGP invoice is issued');

select lives_ok(
  $q$select app.record_payment(
      '72000000-0000-0000-0000-0000000000e1', 400, 'cash')$q$,
  'THE ONE THAT MATTERS: a partial payment still works -- a guard that blocked this would pass every refusal below while stopping the agency taking money');

select lives_ok(
  $q$select app.record_payment(
      '72000000-0000-0000-0000-0000000000e1', 600, 'cash')$q$,
  '...and so does the balance, allocating the invoice exactly to its total');

select is(
  (select sum(pa.allocated_amount)::text || '/' || (select i.status_code from public.invoices i where i.tenant_id='72000000-0000-0000-0000-000000000001')
     from public.payment_allocations pa where pa.tenant_id = '72000000-0000-0000-0000-000000000001'),
  '1000.0000/paid',
  '...leaving 1000 allocated and the invoice PAID -- the RPC''s own side effects intact');

select throws_ok(
  $q$select app.record_payment(
      '72000000-0000-0000-0000-0000000000e1', 1, 'cash')$q$,
  null, null,
  'and the RPC still refuses one more piastre, exactly as before');

-- =============================================================================================
-- 8-10. THE REPRODUCTION, on the direct path, from BOTH directions.
-- =============================================================================================
select throws_ok(
  $q$do $x$
     begin
       insert into public.payments (id, tenant_id, customer_id, amount, currency_code, payment_method_code, payment_direction_code, paid_at)
       values ('72000000-0000-0000-0000-0000000000f1','72000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-0000000000d1',900,'EGP','cash','customer_payment', now());
       insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
       values ('72000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-0000000000f1','72000000-0000-0000-0000-0000000000e1', 900, 'EGP');
       execute 'set constraints all immediate';
     end $x$$q$,
  '23514', null,
  'REPRODUCTION CLOSED: a direct allocation beyond the invoice total is refused -- 1300 against a 1000 invoice was the original probe');

select throws_ok(
  $q$do $x$
     begin
       update public.invoices set total_amount = 100 where tenant_id = '72000000-0000-0000-0000-000000000001';
       execute 'set constraints all immediate';
     end $x$$q$,
  '23514', null,
  'and the OTHER direction is refused too -- shrinking the invoice beneath what is already allocated, which a trigger on the allocations alone would have missed');

select is(
  (select sum(pa.allocated_amount)::text from public.payment_allocations pa
    where pa.tenant_id = '72000000-0000-0000-0000-000000000001'),
  '1000.0000',
  'NON-MUTATION: still exactly 1000 allocated after both refusals');

-- =============================================================================================
-- 11. The forcing mechanism can PASS -- without this every refusal above could be the harness.
-- =============================================================================================
select lives_ok(
  $q$do $x$
     begin
       update public.invoices set total_amount = 1500 where tenant_id = '72000000-0000-0000-0000-000000000001';
       execute 'set constraints all immediate';
     end $x$$q$,
  'NOT A VACUOUS HARNESS: RAISING the invoice total above the allocations passes the same forced check -- so the refusals are the constraint, not the mechanism');

-- =============================================================================================
-- 12-14. AUTHORIZATION is untouched by this package, and the class is pinned.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"72000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select ok(not app.has_permission('RECORD_PAYMENT'),
  'POSITIVE CONTROL: the ordinary employee does NOT hold RECORD_PAYMENT');

-- The employee cannot SEE the invoice either, which is correct (SPEC-139 financial privacy) -- and
-- is asserted so the refusal below is known to be authority rather than an empty query.
select is(
  (select count(*)::int from public.invoices where id = '72000000-0000-0000-0000-0000000000e1'),
  0,
  'the employee cannot even SEE the invoice -- so the next assertion must use a CONCRETE id, not a subquery');

select throws_ok(
  $q$insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
     values ('72000000-0000-0000-0000-000000000001','72000000-0000-0000-0000-0000000000f1','72000000-0000-0000-0000-0000000000e1', 1, 'EGP')$q$,
  '42501', null,
  'and is refused the allocation table outright -- FIN-3''s capability guard is untouched by this package');

reset role;
select cmp_ok(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where t.tgconstraint <> 0 and not t.tgisinternal
      and c.relname in ('journal_entries','journal_entry_lines','payment_allocations','invoices')),
  '>=', 4,
  'THE CLASS: every money table carrying a SET-LEVEL invariant now enforces it as a constraint trigger -- FIN-8 and FIN-10 are the same defect, and this is where a third instance would be added');

-- =============================================================================================
-- 17-18. LOAD-BEARING: are the NAMED triggers what refuses, or would something else have anyway?
--
-- PAR-3 (2026-08-30) made this necessary. Every assertion above proves the violation IS refused;
-- none proves WHAT refuses it, and a test that passes for the wrong reason stops failing the moment
-- the real enforcer is removed. That is not hypothetical here: dropping
-- `payment_allocations_within_invoice_total` on a clean local left the repository guard, the parity
-- guard, the API contract and the smoke test ALL reporting success -- this file was the only layer
-- that noticed, so it is worth knowing precisely which line of it does the noticing.
--
-- The mutation is applied inside a SAVEPOINT and rolled back, so it never outlives the assertion
-- (and the whole file is inside a transaction that rolls back regardless). Both directions are
-- asserted: the violation must SUCCEED while the triggers are gone, and be REFUSED once restored.
-- One without the other proves half of it.
-- =============================================================================================
-- Back to the finance_manager who legitimately holds CREATE_INVOICE. Assertion 15 left the EMPLOYEE
-- session in place, and without this the mutation probe fails on 42501 before it ever reaches the
-- ceiling -- which would have proved authorization, not enforcement. Exactly the confusion this pair
-- exists to prevent: "operation denied" and "operation never attempted" are different results.
select set_config('request.jwt.claims','{"sub":"72000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

savepoint before_enforcer_mutation;
reset role;
drop trigger payment_allocations_within_invoice_total on public.payment_allocations;
drop trigger invoices_total_covers_allocations on public.invoices;
set local role authenticated;

select lives_ok(
  $q$do $x$
     begin
       update public.invoices set total_amount = 1 where tenant_id = '72000000-0000-0000-0000-000000000001';
       execute 'set constraints all immediate';
     end $x$$q$,
  'MUTATION: with both ceiling triggers dropped, the SAME violation now SUCCEEDS -- 1000 allocated against a total of 1. The refusals above are those triggers, not some other constraint doing the work');

rollback to savepoint before_enforcer_mutation;

select throws_ok(
  $q$do $x$
     begin
       update public.invoices set total_amount = 1 where tenant_id = '72000000-0000-0000-0000-000000000001';
       execute 'set constraints all immediate';
     end $x$$q$,
  '23514', null,
  'RESTORED: and with the triggers back, the identical statement is refused again -- so the mutation, not a leftover, is what changed the outcome');

select finish();
rollback;
