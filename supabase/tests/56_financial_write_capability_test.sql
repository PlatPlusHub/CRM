-- pgTAP: FIN-3 / FIN-4 -- money costs the same permission on every path.
--
-- REPRODUCED BEFORE FIXED. An `employee` (RECORD_PAYMENT = false) inserted a 999,999 EGP payment
-- against a booking they owned, by direct DML. `app.record_payment` charges RECORD_PAYMENT, held by
-- ceo, finance_manager and owner only; the table accepted the row from someone holding none of it.
--
-- The money policies all NAME a permission, which is why a sweep counting "policies referencing
-- has_permission" scored them as guarded. The permission named is `VIEW_FINANCIAL_DOCUMENTS` -- a
-- READ permission -- sitting in an OR with a pure visibility test, so the effective rule was "you
-- may write money about anything you can see". `journal_entries` had it right all along
-- (`has_permission('CREATE_JOURNAL_ENTRY')`), which is what makes this an omission rather than a
-- design choice: the ledger was guarded and the cash was not.
--
-- Every denial below is paired with the positive control that proves the actor could otherwise have
-- reached the row -- the employee owns the booking, and the same insert succeeds for finance.
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

insert into auth.users (id, email) values
  ('56000000-0000-0000-0000-0000000000a1','emp@fin.test'),
  ('56000000-0000-0000-0000-0000000000a2','fin@fin.test');
insert into public.tenants (id, name, slug, status) values
  ('56000000-0000-0000-0000-000000000001','Fin Travel','fin-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '56000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('56000000-0000-0000-0000-00000000000a','56000000-0000-0000-0000-000000000001','Cairo','fin-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('56000000-0000-0000-0000-0000000000c1','56000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('56000000-0000-0000-0000-000000000011','56000000-0000-0000-0000-000000000001','Emp','emp@fin.test',true,'56000000-0000-0000-0000-0000000000a1'),
  ('56000000-0000-0000-0000-000000000012','56000000-0000-0000-0000-000000000001','Fin','fin@fin.test',true,'56000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('56000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000011','56000000-0000-0000-0000-00000000000a','56000000-0000-0000-0000-0000000000c1',true),
  ('56000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-000000000012','56000000-0000-0000-0000-00000000000a','56000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '56000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('56000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('56000000-0000-0000-0000-000000000012'::uuid,'finance_manager')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('56000000-0000-0000-0000-0000000000d1','56000000-0000-0000-0000-000000000001','person','C','+201000000031');
-- The employee OWNS this booking, so every denial below is about capability and never about reach.
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id) values
  ('56000000-0000-0000-0000-0000000000b1','56000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-00000000000a','56000000-0000-0000-0000-0000000000c1','56000000-0000-0000-0000-0000000000d1','draft','T','BR-FIN-1','56000000-0000-0000-0000-000000000011');
insert into public.quotations (id, tenant_id, customer_id, currency_code, quotation_status_code, quotation_number, owner_user_id) values
  ('56000000-0000-0000-0000-0000000000f1','56000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-0000000000d1','EGP','draft','QT-FIN-1','56000000-0000-0000-0000-000000000011');

-- =============================================================================================
-- 1-2. THE EMPLOYEE CAN REACH THE ROW. Without this the denials below prove nothing.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"56000000-0000-0000-0000-0000000000a1"}', true);

select is(
  (select count(*)::int from public.bookings where id = '56000000-0000-0000-0000-0000000000b1'),
  1,
  'POSITIVE CONTROL: the employee can see the booking they own');

select is(
  app.has_permission('RECORD_PAYMENT'), false,
  '...and holds no RECORD_PAYMENT -- which is exactly what the RPC charges');

-- =============================================================================================
-- 3-6. FIN-3: DIRECT DML NOW COSTS WHAT THE RPC ALWAYS COST.
-- =============================================================================================
select throws_ok(
  $$insert into public.payments (tenant_id, payment_direction_code, customer_id, booking_id, amount, currency_code, payment_method_code, paid_at)
    values ('56000000-0000-0000-0000-000000000001','customer_payment','56000000-0000-0000-0000-0000000000d1','56000000-0000-0000-0000-0000000000b1', 999999,'EGP','cash', now())$$,
  '42501', null,
  'an employee CANNOT record a payment by direct DML -- the forgery this test reproduced');

select throws_ok(
  $$insert into public.invoices (tenant_id, customer_id, booking_id, currency_code, total_amount, status_code, invoice_number, invoice_date)
    values ('56000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-0000000000d1','56000000-0000-0000-0000-0000000000b1','EGP', 500,'draft','INV-FIN-9', current_date)$$,
  '42501', null,
  '...nor raise an invoice');

select throws_ok(
  $$insert into public.refunds (tenant_id, customer_id, booking_id, amount, currency_code, refund_status_code, refund_reason_code)
    values ('56000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-0000000000d1','56000000-0000-0000-0000-0000000000b1', 500,'EGP','requested','customer_cancelled')$$,
  '42501', null,
  '...nor a refund');

-- The employee DOES hold CREATE_QUOTATION, so quotation lines must still work. A guard that broke
-- the frontline's own job would be a worse defect than the one it fixed.
select lives_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, unit_price, quantity, total_amount, currency_code)
    values ('56000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-0000000000f1','hotel', 100, 1, 100, 'EGP')$$,
  'POSITIVE CONTROL: the same employee CAN add a quotation line -- they hold CREATE_QUOTATION');

-- =============================================================================================
-- 7-9. FINANCE CAN DO ITS JOB. The denials above are about the role, not about the guard.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"56000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$insert into public.invoices (tenant_id, customer_id, booking_id, currency_code, total_amount, status_code, invoice_number, invoice_date)
    values ('56000000-0000-0000-0000-000000000001','56000000-0000-0000-0000-0000000000d1','56000000-0000-0000-0000-0000000000b1','EGP', 500,'draft','INV-FIN-1', current_date)$$,
  'finance raises the invoice the employee could not');

select lives_ok(
  $$insert into public.payments (tenant_id, payment_direction_code, customer_id, booking_id, amount, currency_code, payment_method_code, paid_at)
    values ('56000000-0000-0000-0000-000000000001','customer_payment','56000000-0000-0000-0000-0000000000d1','56000000-0000-0000-0000-0000000000b1', 500,'EGP','cash', now())$$,
  '...and records the payment');

select is(
  (select count(*)::int from public.payments where booking_id = '56000000-0000-0000-0000-0000000000b1'),
  1,
  '...and it persisted -- the positive path writes a real row, so the denials are not blanket');

-- =============================================================================================
-- 10-11. FIN-4: an approval request cannot name someone else as its requester. DERIVED, not
--        validated -- whatever the caller sends is overwritten, so forgery is unrepresentable.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"56000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select lives_ok(
  $$insert into public.approval_requests (tenant_id, approval_type_code, approval_status_code, requested_by, related_entity_type, related_entity_id, requested_at)
    values ('56000000-0000-0000-0000-000000000001','finance_execution_approval','pending','56000000-0000-0000-0000-000000000012','booking','56000000-0000-0000-0000-0000000000b1', now())$$,
  'the employee opens an approval request naming FINANCE as the requester');

select is(
  (select requested_by from public.approval_requests
    where related_entity_id = '56000000-0000-0000-0000-0000000000b1'),
  '56000000-0000-0000-0000-000000000011'::uuid,
  '...and it is recorded against the EMPLOYEE -- the attribution they supplied was overwritten');

-- =============================================================================================
-- 12. THE SYSTEM PATH stays open. Provisioning, cron and the storage executor write money-adjacent
--     rows session-lessly; a guard that charged them a permission would break tenant creation.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select lives_ok(
  $$insert into public.payments (tenant_id, payment_direction_code, customer_id, booking_id, amount, currency_code, payment_method_code, paid_at)
    values ('56000000-0000-0000-0000-000000000001','customer_payment','56000000-0000-0000-0000-0000000000d1','56000000-0000-0000-0000-0000000000b1', 1,'EGP','cash', now())$$,
  'a SESSION-LESS write is permitted -- exempt from the capability check, never from the record');

select finish();
rollback;
