-- pgTAP: Batch 6 slice 10 -- `invoices`, the financial document that could be rewritten after it
-- was issued. INVOICE-1 .. INVOICE-7 (202607062000).
--
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT BUSINESS PRIVILEGE OBSERVABILITY REPLAY CONCURRENCY=N/A
--
-- CONCURRENCY=N/A is not "unexamined". Invoice numbering is the one invoice-specific race, and it
-- was measured live rather than reasoned about: two overlapping transactions each calling
-- `app.create_invoice` in the same tenant and year produced `INV-2026-0001` and `INV-2026-0002`,
-- the second blocking ~2s on `pg_advisory_xact_lock` until the first committed. That needs two
-- sessions; pgTAP runs in one, so asserting it here would prove only that a single session can
-- count. `payment_allocations` concurrency is already carried by `72_invoice_allocation_ceiling`.
--
-- THE ACTOR IS AN `employee` WHO OWNS THE BOOKING THE INVOICE HANGS OFF. That is what makes the
-- refusals mean something: the invoices RLS policy admits them through
-- `exists (select 1 from bookings b where b.id = invoices.booking_id)`, so the row is genuinely
-- visible and `authenticated` genuinely holds UPDATE. Assertions 1-2 prove both before anything is
-- refused (AGENTS.md s6, "no vacuous security tests").
--
-- WHAT THIS FILE DOES **NOT** OVERTURN. Assertion 7 of `68_financial_status_capability_test.sql`
-- records as INTENTIONAL that the financial guard is column-scoped rather than a row freeze --
-- "ORVION governs mutation by consequence, not by table". That principle stands; assertion 11 below
-- re-proves it on `due_date`, which has no reader anywhere in the schema. What slice 10 changed is
-- the CONSEQUENCE SET, and only where a reader was measured: `currency_code`
-- (`app.customer_balance`, `app.customer_exposure_in_limit_currency`), `customer_id` (whose debt),
-- `invoice_number` (the identifier in the books).
create extension if not exists pgtap with schema extensions;

begin;
select plan(25);

insert into auth.users (id, email) values
  ('a1000000-0000-0000-0000-0000000000a1','fin@inv10.test'),
  ('a1000000-0000-0000-0000-0000000000a2','agent@inv10.test'),
  ('a1000000-0000-0000-0000-0000000000a3','ceo@inv10.test');
insert into public.tenants (id, name, slug, status) values
  ('a1000000-0000-0000-0000-000000000001','INV10 Travel','inv10-travel','active'),
  ('a1000000-0000-0000-0000-000000000002','INV10 Other','inv10-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.subscription_plans sp
cross join (values ('a1000000-0000-0000-0000-000000000001'::uuid),
                   ('a1000000-0000-0000-0000-000000000002'::uuid)) t(id)
where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('a1000000-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-000000000001','Cairo','inv10-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('a1000000-0000-0000-0000-0000000000c1','a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-00000000000a','sales','INV10 Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('a1000000-0000-0000-0000-000000000011','a1000000-0000-0000-0000-000000000001','Finance','fin@inv10.test',true,'a1000000-0000-0000-0000-0000000000a1'),
  ('a1000000-0000-0000-0000-000000000012','a1000000-0000-0000-0000-000000000001','Agent','agent@inv10.test',true,'a1000000-0000-0000-0000-0000000000a2'),
  ('a1000000-0000-0000-0000-000000000013','a1000000-0000-0000-0000-000000000001','Chief','ceo@inv10.test',true,'a1000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000011','a1000000-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-0000000000c1',true),
  ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000012','a1000000-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-0000000000c1',true),
  ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000013','a1000000-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000011'::uuid, r.id,'tenant'
from public.roles r where r.code='finance_manager';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000012'::uuid, r.id,'tenant'
from public.roles r where r.code='employee';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000013'::uuid, r.id,'tenant'
from public.roles r where r.code='ceo';
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('a1000000-0000-0000-0000-0000000000d1','a1000000-0000-0000-0000-000000000001','person','INV10 Customer','+201009991010'),
  ('a1000000-0000-0000-0000-0000000000d2','a1000000-0000-0000-0000-000000000001','person','INV10 Second','+201009992020'),
  ('a1000000-0000-0000-0000-0000000000d9','a1000000-0000-0000-0000-000000000002','person','OTHER tenant','+201009993030');
insert into public.bookings (id, tenant_id, customer_id, title, booking_reference, booking_status_code,
                            owner_user_id, branch_id, department_id, created_by) values
  ('a1000000-0000-0000-0000-0000000000b1','a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000d1','Umrah package','BK-INV10-1','draft',
   'a1000000-0000-0000-0000-000000000012','a1000000-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-0000000000c1','a1000000-0000-0000-0000-000000000012'),
  ('a1000000-0000-0000-0000-0000000000b2','a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000d1','Second package','BK-INV10-2','draft',
   'a1000000-0000-0000-0000-000000000012','a1000000-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-0000000000c1','a1000000-0000-0000-0000-000000000012');

-- The invoice is raised through the sanctioned RPC, by the actor entitled to raise it.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select app.create_invoice('a1000000-0000-0000-0000-0000000000d1','EGP', 50000,
                          'a1000000-0000-0000-0000-0000000000b1');
select app.issue_invoice((select id from public.invoices where tenant_id='a1000000-0000-0000-0000-000000000001'));

-- ================================================================================================
-- 1-3. THE ACTOR, THE REACH, AND THE POSITIVE CONTROL EVERY REFUSAL BELOW DEPENDS ON.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select ok(
  not app.has_permission('CREATE_INVOICE')
  and not app.has_permission('RECORD_PAYMENT')
  and not app.has_permission('VIEW_FINANCIAL_DOCUMENTS'),
  'the attacking actor holds NO financial permission at all -- not CREATE_INVOICE, not RECORD_PAYMENT, not even the read');

select is(
  (select count(*)::int from public.invoices where tenant_id='a1000000-0000-0000-0000-000000000001'),
  1,
  'REACH PROVEN: and they can SEE the invoice anyway -- the RLS policy admits them through the booking they own, so every refusal below is capability, not visibility');

select is(
  (select status_code from public.invoices where tenant_id='a1000000-0000-0000-0000-000000000001'),
  'issued',
  'POSITIVE CONTROL: the RPC door raised and issued the invoice -- 50,000 EGP, issued, before anything is attacked');

-- ================================================================================================
-- 4-9. INVOICE-1 / INVOICE-2. Each column is attacked ALONE, so the refusal names the mechanism under test.
--      Combining a frozen column with a guarded amount would let `guard_financial_capability`
--      answer instead, and the assertion would report a refusal it did not measure.
-- ================================================================================================
savepoint frozen;

select throws_ok(
  $$update public.invoices set currency_code = 'USD'
     where tenant_id = 'a1000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'INVOICE-1: the CURRENCY cannot be flipped -- 50,000 EGP became 50,000 USD in app.customer_balance and total_amount never moved');
rollback to savepoint frozen;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select throws_ok(
  $$update public.invoices set customer_id = 'a1000000-0000-0000-0000-0000000000d2'
     where tenant_id = 'a1000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'INVOICE-2: the invoice cannot be re-pointed at a different CUSTOMER -- whose debt this is, and whose credit ceiling it counts against');
rollback to savepoint frozen;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select throws_ok(
  $$update public.invoices set invoice_number = 'INV-2026-abcd'
     where tenant_id = 'a1000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'INVOICE-2/INVOICE-7: the NUMBER of an issued invoice cannot be rewritten -- this was also the door the tenant-wide numbering DoS came through');
rollback to savepoint frozen;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select throws_ok(
  $$update public.invoices set invoice_date = date '2020-01-01'
     where tenant_id = 'a1000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'INVOICE-2: the invoice DATE cannot be moved -- it is the period the document belongs to and the year its number was drawn from');
rollback to savepoint frozen;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select throws_ok(
  $$update public.invoices set corrects_invoice_id = 'a1000000-0000-0000-0000-0000000000d1'
     where tenant_id = 'a1000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'INVOICE-2: an invoice cannot be made to CLAIM it corrects another document -- provenance is not writable after the fact');
rollback to savepoint frozen;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select throws_ok(
  $$update public.invoices set booking_id = 'a1000000-0000-0000-0000-0000000000b2'
     where tenant_id = 'a1000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'INCIDENTAL DEFENCE, NAMED: re-parenting onto ANOTHER booking the same actor owns used to SUCCEED. Detaching it failed only because the resulting row was invisible to them -- RLS visibility, never authority');
rollback to savepoint frozen;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

-- ================================================================================================
-- 10-11. THE ROW IS INTACT, AND THE PRINCIPLE 68 RECORDED IS UNCHANGED.
-- ================================================================================================
select results_eq(
  $$select currency_code, total_amount, invoice_number, customer_id
      from public.invoices where tenant_id = 'a1000000-0000-0000-0000-000000000001'$$,
  $$values ('EGP', 50000.0000::numeric, 'INV-2026-0001', 'a1000000-0000-0000-0000-0000000000d1'::uuid)$$,
  'NON-MUTATION: after six refusals the row is byte-for-byte what the RPC wrote -- asserted on the row, not on the absence of an exception');

select lives_ok(
  $$update public.invoices set due_date = current_date + 30
     where tenant_id = 'a1000000-0000-0000-0000-000000000001'$$,
  'SEC-2 STILL INTENTIONAL: `due_date` -- which no function, view or policy reads -- still updates on the same row. The guard names columns by consequence; it did not become a row freeze (68 assertion 7 preserved)');
rollback to savepoint frozen;

-- ================================================================================================
-- 12-16. THE FINANCE ACTOR. Holding the capability is not permission to rewrite history.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select throws_ok(
  $$insert into public.invoices (tenant_id, customer_id, invoice_number, invoice_date,
                                 currency_code, total_amount, status_code)
    values ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000d1',
            'INV-2026-9001', current_date, 'EGP', 9999, 'paid')$$,
  '23514',
  null,
  'INVOICE-4: an invoice cannot be BORN paid -- 9,999 EGP declared settled with no payment, no allocation and no event');
rollback to savepoint frozen;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select throws_ok(
  $$insert into public.invoices (tenant_id, customer_id, invoice_number, invoice_date,
                                 currency_code, total_amount, status_code)
    values ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000d1',
            'INV-2026-9002', current_date, 'EGP', 8888, 'voided')$$,
  '23514',
  null,
  '...nor BORN voided -- which produced the exact split state (no void_reason, no voided_at) that app.guard_invoice_void refuses to produce on UPDATE');
rollback to savepoint frozen;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select lives_ok(
  $$update public.invoices set total_amount = 60000
     where tenant_id = 'a1000000-0000-0000-0000-000000000001'
       and status_code = 'draft'$$,
  'POSITIVE CONTROL: the draft-only rule is a rule about STATE, so the same statement is not a blanket freeze -- it simply matches no issued row here');

select lives_ok(
  $$select app.record_payment(
      (select id from public.invoices where tenant_id='a1000000-0000-0000-0000-000000000001'),
      50000, 'cash')$$,
  'POSITIVE CONTROL: finance can still take the money -- the invoice is now fully paid');

select throws_ok(
  $$update public.invoices set total_amount = 90000
     where tenant_id = 'a1000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'INVOICE-5: and the total of that PAID invoice can no longer move. It went 50,000 -> 90,000 with the status left `paid` and only 50,000 allocated -- and record_payment refuses a paid invoice, so nothing could ever close the gap');
rollback to savepoint frozen;

-- ================================================================================================
-- 17-18. INVOICE-6. Archive attribution, on `invoices` and on a SECOND table through the same guard --
--        because the defect was never invoice-specific and neither is the repair.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select results_eq(
  $$with a as (
      update public.invoices
         set is_archived = true,
             archived_by = 'a1000000-0000-0000-0000-000000000012',
             archived_at = timestamptz '2001-01-01'
       where tenant_id = 'a1000000-0000-0000-0000-000000000001'
      returning archived_by, archived_at)
    select archived_by, archived_at > now() - interval '1 minute' from a$$,
  $$values ('a1000000-0000-0000-0000-000000000011'::uuid, true)$$,
  'INVOICE-6: the archive is attributed to the actor who performed it and stamped NOW, discarding the caller''s forged user and 2001 timestamp -- which is what 202607052800''s own header always claimed it did');
rollback to savepoint frozen;
-- A different actor, because archiving a CUSTOMER also costs its own write capability -- which is
-- the point: the assertion must not pass by accident on a table the actor cannot write at all.
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);

select results_eq(
  $$with a as (
      update public.customers
         set is_archived = true,
             archived_by = 'a1000000-0000-0000-0000-000000000012',
             archived_at = timestamptz '2001-01-01'
       where id = 'a1000000-0000-0000-0000-0000000000d2'
      returning archived_by, archived_at)
    select archived_by, archived_at > now() - interval '1 minute' from a$$,
  $$values ('a1000000-0000-0000-0000-000000000013'::uuid, true)$$,
  '...and on `customers` too: one shared guard serves thirteen archivable tables, so the repair landed where every caller routes through rather than in an invoices-shaped copy');
rollback to savepoint frozen;

-- ================================================================================================
-- 19-22. INVOICE-7 (INPUT), TENANT and REPLAY.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select lives_ok(
  $q$do $x$
    begin
      insert into public.invoices (tenant_id, customer_id, invoice_number, invoice_date,
                                   currency_code, total_amount, status_code)
      values ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000d1',
              'INV-2026-abcd', current_date, 'EGP', 5, 'draft');
      perform app.create_invoice('a1000000-0000-0000-0000-0000000000d1','EGP', 7);
    end $x$$q$,
  'INVOICE-7: a malformed number sitting in the table no longer stops the tenant raising invoices -- `like` admitted `INV-2026-abcd` into a `::integer` cast and every subsequent app.create_invoice raised 22P02 for that tenant and year');

select is(
  (select invoice_number from public.invoices
    where tenant_id='a1000000-0000-0000-0000-000000000001' and total_amount = 7),
  'INV-2026-0002',
  '...and the sequence carried on correctly past it, rather than being poisoned or restarted');
rollback to savepoint frozen;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select throws_ok(
  $$insert into public.invoices (tenant_id, customer_id, invoice_number, invoice_date,
                                 currency_code, total_amount, status_code)
    values ('a1000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-0000000000d9',
            'INV-2026-7777', current_date, 'EGP', 1, 'draft')$$,
  '42501',
  null,
  'TENANT: an invoice cannot be forged into another tenant -- the RLS with-check refuses it, and this is the intentional control, not an incidental one');

select throws_ok(
  $$select app.issue_invoice(
      (select id from public.invoices where tenant_id='a1000000-0000-0000-0000-000000000001'))$$,
  'P0001',
  'only a draft invoice can be issued (is issued)',
  'REPLAY: issuing an already-issued invoice is refused by its own precondition, so a replayed call cannot re-emit the issuance event');

-- ================================================================================================
-- 23-25. DEFECT INJECTION (PAR-4). Everything above is worthless unless the SAME statement succeeds
--        with the named enforcer removed. Drop it, prove the seize LANDS AND MOVES THE ROW, roll
--        back, prove it is refused again by the restored trigger.
-- ================================================================================================
rollback to savepoint frozen;
reset role;
savepoint injection;

drop trigger invoices_guard_integrity on public.invoices;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
update public.invoices set currency_code = 'USD'
 where tenant_id = 'a1000000-0000-0000-0000-000000000001';

select is(
  (select currency_code from public.invoices where tenant_id='a1000000-0000-0000-0000-000000000001'),
  'USD',
  'DEFECT INJECTION: with invoices_guard_integrity dropped, the employee''s currency flip SUCCEEDS and the row MOVES -- so assertion 4 is that trigger and not RLS, a constraint, a foreign key or the financial guard');

rollback to savepoint injection;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select throws_ok(
  $$update public.invoices set currency_code = 'USD'
     where tenant_id = 'a1000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'RESTORED: the identical statement is refused again -- the mutation, not a leftover, is what changed the outcome (TEST-3: the session is re-established after the rollback)');

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where c.relname = 'invoices' and t.tgname = 'invoices_guard_integrity' and not t.tgisinternal),
  1,
  'CONTROL: the trigger is back on the table, so nothing after this file inherits a weakened invoices');

select * from finish();
rollback;
