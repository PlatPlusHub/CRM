-- pgTAP: FIN-6 / FIN-6b -- the STATUS of a financial document is as consequential as its amount.
--
-- Found while resolving SEC-2, and it is the half of SEC-2 that was never a business decision.
-- `app.guard_financial_capability` charged the write capability on UPDATE "only when a MONETARY
-- column changes" (FIN-3's own words, and correct reasoning for `refunds` and `quotation_items`,
-- whose status IS governed by `app.enforce_status_transition`). For `invoices` it was not correct:
-- `app.status_transitions` has ZERO rows for invoices and canon 26 defines no Invoice State Machine,
-- so nothing governed the status at all.
--
-- REPRODUCED before the fix -- an employee holding CREATE_INVOICE = f, RECORD_PAYMENT = f, on an
-- invoice they can see because it belongs to their own booking:
--
--     mark a 50,000 EGP invoice 'paid' with no payment  ->  SUCCEEDED
--     change the invoice AMOUNT                          ->  REFUSED: permission denied
--
-- The second line is what made the first conclusive: the guard was present and working and simply
-- did not cover the status.
--
-- §4 is the assertion this file exists for as much as the denials: FINANCE MUST STILL BE ABLE TO DO
-- IT. A guard that stopped the employee and also stopped the finance manager would pass every
-- refusal above while breaking the product.
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email) values
  ('68000000-0000-0000-0000-0000000000a1','emp@fin6.test'),
  ('68000000-0000-0000-0000-0000000000a2','fin@fin6.test');
insert into public.tenants (id, name, slug, status) values
  ('68000000-0000-0000-0000-000000000001','Fin6 Travel','fin6-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '68000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('68000000-0000-0000-0000-00000000000a','68000000-0000-0000-0000-000000000001','Cairo','fin6-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('68000000-0000-0000-0000-0000000000c1','68000000-0000-0000-0000-000000000001','68000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('68000000-0000-0000-0000-000000000011','68000000-0000-0000-0000-000000000001','Employee','emp@fin6.test',true,'68000000-0000-0000-0000-0000000000a1'),
  ('68000000-0000-0000-0000-000000000012','68000000-0000-0000-0000-000000000001','Finance','fin@fin6.test',true,'68000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '68000000-0000-0000-0000-000000000001', u,
       '68000000-0000-0000-0000-00000000000a','68000000-0000-0000-0000-0000000000c1', true
from unnest(array['68000000-0000-0000-0000-000000000011'::uuid,
                  '68000000-0000-0000-0000-000000000012'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '68000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('68000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('68000000-0000-0000-0000-000000000012'::uuid,'finance_manager')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('68000000-0000-0000-0000-0000000000d1','68000000-0000-0000-0000-000000000001','person','Fin6 Customer','+201000000680');
insert into public.bookings (id, tenant_id, customer_id, branch_id, department_id, owner_user_id,
                             title, booking_status_code, booking_reference)
values ('68000000-0000-0000-0000-0000000000b1','68000000-0000-0000-0000-000000000001',
        '68000000-0000-0000-0000-0000000000d1','68000000-0000-0000-0000-00000000000a',
        '68000000-0000-0000-0000-0000000000c1','68000000-0000-0000-0000-000000000011',
        'Umrah package','draft','BK-FIN6-1');
insert into public.invoices (id, tenant_id, customer_id, booking_id, invoice_number, invoice_date,
                             currency_code, total_amount, status_code)
values ('68000000-0000-0000-0000-0000000000f1','68000000-0000-0000-0000-000000000001',
        '68000000-0000-0000-0000-0000000000d1','68000000-0000-0000-0000-0000000000b1',
        'INV-FIN6-1', current_date, 'EGP', 50000, 'issued');

-- =============================================================================================
-- 1-2. THE PREMISE, AND THE CONTROL THAT MAKES EVERY REFUSAL BELOW MEAN SOMETHING.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"68000000-0000-0000-0000-0000000000a1"}', true);

select ok(
  not app.has_permission('CREATE_INVOICE') and not app.has_permission('RECORD_PAYMENT'),
  'the employee holds NEITHER CREATE_INVOICE nor RECORD_PAYMENT');

select is(
  (select count(*)::int from public.invoices where id = '68000000-0000-0000-0000-0000000000f1'),
  1,
  'POSITIVE CONTROL: the employee CAN SEE the invoice -- it belongs to their own booking, so every refusal below is about capability and not reach');

-- =============================================================================================
-- 3-6. FIN-6. Asserted on the ROW as well as on the exception, because "an error was raised" would
--      pass even if the write had landed.
-- =============================================================================================
select throws_ok(
  $$update public.invoices set status_code = 'paid'
     where id = '68000000-0000-0000-0000-0000000000f1'$$,
  '42501',
  null,
  'FIN-6: the employee cannot declare the invoice PAID -- this succeeded until 202607057100');

select is(
  (select status_code from public.invoices where id = '68000000-0000-0000-0000-0000000000f1'),
  'issued',
  '...and the invoice is still ISSUED -- asserted on the row, not on the absence of an exception');

select throws_ok(
  $$update public.invoices set external_submission_status_code = 'accepted'
     where id = '68000000-0000-0000-0000-0000000000f1'$$,
  '42501',
  null,
  '...nor can they claim it was accepted by the tax authority -- the same class one column over');

select throws_ok(
  $$update public.invoices set total_amount = 1
     where id = '68000000-0000-0000-0000-0000000000f1'$$,
  '42501',
  null,
  'FIN-3 preserved: the amount is still guarded, and was the control that exposed FIN-6');

-- =============================================================================================
-- 7. SEC-2's INTENTIONAL half, pinned. The guard is COLUMN-scoped, not a row freeze: a descriptive
--    field on the very same row still updates. ORVION governs mutation by consequence, not by table,
--    and this assertion is where that boundary is recorded rather than merely argued.
-- =============================================================================================
select lives_ok(
  $$update public.invoices set due_date = current_date + 30
     where id = '68000000-0000-0000-0000-0000000000f1'$$,
  'SEC-2 (intentional): a NON-governed column on the same row still updates -- the guard names columns, it does not freeze rows');

-- =============================================================================================
-- 8-9. THE POSITIVE CONTROLS THAT MATTER MOST. Finance must still be able to run the business.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"68000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select lives_ok(
  $$update public.invoices set status_code = 'paid'
     where id = '68000000-0000-0000-0000-0000000000f1'$$,
  'POSITIVE CONTROL: FINANCE can still advance the invoice -- CREATE_INVOICE and RECORD_PAYMENT are held by the same three roles, so no working path was broken');

select is(
  (select status_code from public.invoices where id = '68000000-0000-0000-0000-0000000000f1'),
  'paid',
  '...and the change actually landed');

-- =============================================================================================
-- 10-11. FIN-6b, and the class guard for it. `receipts` was mapped to a column named `amount` --
--        which RECEIPTS DOES NOT HAVE; the money lives on the payment. `to_jsonb ->> 'amount'` is
--        NULL on both sides, so the UPDATE branch of this guard was INERT for receipts from the day
--        FIN-3 shipped. The to_jsonb comparison that fixed SPEC-159-A's binding hazard also removed
--        the compiler's ability to notice a column that is not there.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select count(*)::int from information_schema.columns
    where table_schema = 'public' and table_name = 'receipts' and column_name = 'amount'),
  0,
  'FIN-6b: `receipts` has no `amount` column at all -- which is why the old mapping guarded nothing');

select is(
  (select count(*)::int
     from (values ('payments','amount'),
                  ('payment_allocations','allocated_amount'),
                  ('receipts','external_submission_status_code'),
                  ('refunds','amount'),
                  ('invoices','total_amount'),
                  ('invoices','status_code'),
                  ('invoices','external_submission_status_code'),
                  ('quotation_items','unit_price'),
                  ('quotation_items','quantity')) as m(tbl, col)
    where not exists (
      select 1 from information_schema.columns c
       where c.table_schema = 'public' and c.table_name = m.tbl and c.column_name = m.col)),
  0,
  '...and EVERY column this guard maps now exists on its table -- the assertion that would have caught it');

select finish();
rollback;
