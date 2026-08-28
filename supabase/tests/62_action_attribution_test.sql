-- pgTAP: ATTR-2 -- who DECIDED a request, and who UPLOADED a payment proof, are derived too.
--
-- ATTR-1 covered attributions stamped when a row is created. These two are stamped when an action
-- happens, and were deliberately left out of that migration rather than swept in on a name match.
--
-- The `approval_requests.reviewed_by` case is the interesting one, because FIN-2 established that
-- finance DECIDING a request is a different act from an employee OPENING one -- and the guard must
-- not re-attribute a decision every time some unrelated field on the row is touched.
create extension if not exists pgtap with schema extensions;

begin;
select plan(9);

insert into auth.users (id, email) values
  ('62000000-0000-0000-0000-0000000000a1','emp@at.test'),
  ('62000000-0000-0000-0000-0000000000a2','fin@at.test'),
  ('62000000-0000-0000-0000-0000000000a3','owner@at.test');
insert into public.tenants (id, name, slug, status) values
  ('62000000-0000-0000-0000-000000000001','AT Travel','at-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '62000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('62000000-0000-0000-0000-00000000000a','62000000-0000-0000-0000-000000000001','Cairo','at-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('62000000-0000-0000-0000-0000000000c1','62000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('62000000-0000-0000-0000-000000000011','62000000-0000-0000-0000-000000000001','Emp','emp@at.test',true,'62000000-0000-0000-0000-0000000000a1'),
  ('62000000-0000-0000-0000-000000000012','62000000-0000-0000-0000-000000000001','Fin','fin@at.test',true,'62000000-0000-0000-0000-0000000000a2'),
  ('62000000-0000-0000-0000-000000000013','62000000-0000-0000-0000-000000000001','Owner','owner@at.test',true,'62000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '62000000-0000-0000-0000-000000000001', u, '62000000-0000-0000-0000-00000000000a','62000000-0000-0000-0000-0000000000c1', true
from unnest(array['62000000-0000-0000-0000-000000000011'::uuid,'62000000-0000-0000-0000-000000000012'::uuid,'62000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '62000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('62000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('62000000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('62000000-0000-0000-0000-000000000013'::uuid,'owner')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('62000000-0000-0000-0000-0000000000d1','62000000-0000-0000-0000-000000000001','person','AT Customer','+201000000062');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id) values
  ('62000000-0000-0000-0000-0000000000b1','62000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-00000000000a','62000000-0000-0000-0000-0000000000c1','62000000-0000-0000-0000-0000000000d1','draft','T','BR-AT-1','62000000-0000-0000-0000-000000000011');
-- `app.request_finance_approval` takes a BOOKING ITEM, not a booking: the approval is about a
-- priced line, which is the level the money lives at.
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, currency_code,
                                  base_status_code, owner_user_id, cost_amount, selling_amount)
values ('62000000-0000-0000-0000-0000000000b2','62000000-0000-0000-0000-000000000001','62000000-0000-0000-0000-0000000000b1',
        'hotel','EGP','draft','62000000-0000-0000-0000-000000000011', 1000, 1500);
-- The proof needs a real document: `document_id` is NOT NULL and carries an FK.
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code, is_confidential)
values ('62000000-0000-0000-0000-0000000000e1','62000000-0000-0000-0000-000000000001','payment_proof','Proof','active',false);

-- =============================================================================================
-- 1-4. THE DECISION IS ATTRIBUTED TO WHOEVER MADE IT.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"62000000-0000-0000-0000-0000000000a1"}', true);

select lives_ok(
  $$select app.request_finance_approval('62000000-0000-0000-0000-0000000000b2','needs a discount')$$,
  'BASELINE: the employee opens a finance approval request');

select is(
  (select requested_by from public.approval_requests where tenant_id = '62000000-0000-0000-0000-000000000001'),
  '62000000-0000-0000-0000-000000000011'::uuid,
  'CONTROL: FIN-4''s derivation still holds -- the requester is the employee');

reset role;
select set_config('request.jwt.claims','{"sub":"62000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

-- Finance decides by direct DML and names the OWNER as reviewer. Finance CAN write this row
-- (approval_requests.scope_update permits it), so the assertion is about attribution, not authority.
select lives_ok(
  $$update public.approval_requests
       set approval_status_code = 'approved', reviewed_at = now(),
           reviewed_by = '62000000-0000-0000-0000-000000000013'
     where tenant_id = '62000000-0000-0000-0000-000000000001'$$,
  'POSITIVE CONTROL: finance CAN decide the request, and names the owner as the reviewer');

select is(
  (select reviewed_by from public.approval_requests where tenant_id = '62000000-0000-0000-0000-000000000001'),
  '62000000-0000-0000-0000-000000000012'::uuid,
  '...and the decision is attributed to FINANCE, who actually made it -- the owner they named was overwritten');

-- =============================================================================================
-- 5-6. AND AN UNRELATED UPDATE DOES NOT RE-ATTRIBUTE THE DECISION. This is why the trigger fires
--      on a CHANGE to reviewed_by rather than on every update: an already-decided request touched
--      by someone else must keep the reviewer it has.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"62000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$update public.approval_requests set rejection_reason = null
     where tenant_id = '62000000-0000-0000-0000-000000000001'$$,
  'the owner touches an unrelated field on the decided request');

select is(
  (select reviewed_by from public.approval_requests where tenant_id = '62000000-0000-0000-0000-000000000001'),
  '62000000-0000-0000-0000-000000000012'::uuid,
  '...and the reviewer is STILL finance -- a decision is not re-attributed to whoever edited last');

-- =============================================================================================
-- 7-8. THE PAYMENT PROOF'S UPLOADER, which is an insert-time attribution that ATTR-1 missed only
--      because the column is not called `created_by`.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"62000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$insert into public.subscription_payment_proofs
        (tenant_id, subscription_id, document_id, status_code, uploaded_by)
    select '62000000-0000-0000-0000-000000000001', s.id, '62000000-0000-0000-0000-0000000000e1',
           'pending', '62000000-0000-0000-0000-000000000011'
      from public.subscriptions s where s.tenant_id = '62000000-0000-0000-0000-000000000001'$$,
  'POSITIVE CONTROL: the owner files a payment proof and names the employee as uploader');

select is(
  (select uploaded_by from public.subscription_payment_proofs where tenant_id = '62000000-0000-0000-0000-000000000001'),
  '62000000-0000-0000-0000-000000000013'::uuid,
  '...and it is attributed to the owner, who actually uploaded it');

-- =============================================================================================
-- 9. THE SYSTEM PATH IS EXEMPT FROM THE CHECK, NEVER FROM THE RECORD.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

update public.approval_requests set reviewed_by = '62000000-0000-0000-0000-000000000013'
 where tenant_id = '62000000-0000-0000-0000-000000000001';

select is(
  (select reviewed_by from public.approval_requests where tenant_id = '62000000-0000-0000-0000-000000000001'),
  '62000000-0000-0000-0000-000000000013'::uuid,
  'a session-less platform write sets the attribution it means to set');

select finish();
rollback;
