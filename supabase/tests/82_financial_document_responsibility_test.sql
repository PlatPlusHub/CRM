-- pgTAP: SPEC-154-B -- a financial document follows the work, not the department (`202607058700`).
--
-- The whole point of this file is one comparison: TWO ordinary employees, in the SAME department,
-- with the SAME role and the SAME permissions, differing only in whether they are the responsible
-- user for the booking the document hangs off. Before `202607058700` they read the invoice
-- identically. If a future change makes them identical again, assertions 5 and 6 fail together.
--
-- Every document below is uploaded by the MANAGER, so `created_by` can never explain a read.
create extension if not exists pgtap with schema extensions;

begin;
select plan(21);

insert into auth.users (id, email) values
  ('82000000-0000-0000-0000-0000000000a1','mgr@f82.example'),
  ('82000000-0000-0000-0000-0000000000a2','resp@f82.example'),
  ('82000000-0000-0000-0000-0000000000a3','fin@f82.example'),
  ('82000000-0000-0000-0000-0000000000a4','coll@f82.example');
insert into public.tenants (id, name, slug, status) values
  ('82000000-0000-0000-0000-000000000001','F82 Travel','f82-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '82000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('82000000-0000-0000-0000-00000000000a','82000000-0000-0000-0000-000000000001','Cairo','f82-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('82000000-0000-0000-0000-0000000000c1','82000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-00000000000a','sales','Cairo Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('82000000-0000-0000-0000-000000000011','82000000-0000-0000-0000-000000000001','Manager','mgr@f82.example',true,'82000000-0000-0000-0000-0000000000a1'),
  ('82000000-0000-0000-0000-000000000021','82000000-0000-0000-0000-000000000001','Responsible','resp@f82.example',true,'82000000-0000-0000-0000-0000000000a2'),
  ('82000000-0000-0000-0000-000000000031','82000000-0000-0000-0000-000000000001','Finance','fin@f82.example',true,'82000000-0000-0000-0000-0000000000a3'),
  ('82000000-0000-0000-0000-000000000022','82000000-0000-0000-0000-000000000001','Colleague','coll@f82.example',true,'82000000-0000-0000-0000-0000000000a4');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '82000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('82000000-0000-0000-0000-000000000011'::uuid,'branch_manager'),
             ('82000000-0000-0000-0000-000000000021'::uuid,'employee'),
             ('82000000-0000-0000-0000-000000000022'::uuid,'employee'),
             ('82000000-0000-0000-0000-000000000031'::uuid,'finance_manager')) v(u,code)
join public.roles r on r.code = v.code;
-- Same branch, same department, for all four: the denial below must come from responsibility and
-- from nothing else.
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '82000000-0000-0000-0000-000000000001', u, '82000000-0000-0000-0000-00000000000a','82000000-0000-0000-0000-0000000000c1', true
from unnest(array['82000000-0000-0000-0000-000000000011'::uuid,'82000000-0000-0000-0000-000000000021',
                  '82000000-0000-0000-0000-000000000022','82000000-0000-0000-0000-000000000031']) u;

insert into public.customers (id, tenant_id, customer_type_code, full_name, first_registered_branch_id)
values ('82000000-0000-0000-0000-0000000000cc','82000000-0000-0000-0000-000000000001','person','F82 Customer','82000000-0000-0000-0000-00000000000a');
insert into public.bookings (id, tenant_id, customer_id, title, booking_reference, branch_id, department_id,
                             owner_user_id, owner_branch_id, owner_department_id, booking_status_code)
values ('82000000-0000-0000-0000-0000000000b1','82000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-0000000000cc',
        'F82 booking','F82-0001','82000000-0000-0000-0000-00000000000a','82000000-0000-0000-0000-0000000000c1',
        '82000000-0000-0000-0000-000000000021','82000000-0000-0000-0000-00000000000a','82000000-0000-0000-0000-0000000000c1','draft');
insert into public.invoices (id, tenant_id, customer_id, booking_id, invoice_number, invoice_date, currency_code, status_code)
values ('82000000-0000-0000-0000-0000000000f1','82000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-0000000000cc',
        '82000000-0000-0000-0000-0000000000b1','F82-INV-1', current_date, 'EGP', 'draft');

insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code, is_confidential, created_by) values
  ('82000000-0000-0000-0000-0000000000d1','82000000-0000-0000-0000-000000000001','invoice','Invoice (open)','active',false,'82000000-0000-0000-0000-000000000011'),
  ('82000000-0000-0000-0000-0000000000d2','82000000-0000-0000-0000-000000000001','invoice','Invoice (confidential)','active',true,'82000000-0000-0000-0000-000000000011'),
  ('82000000-0000-0000-0000-0000000000d3','82000000-0000-0000-0000-000000000001','quotation','Quotation','active',false,'82000000-0000-0000-0000-000000000011'),
  ('82000000-0000-0000-0000-0000000000d4','82000000-0000-0000-0000-000000000001','passport','Passport scan','active',false,'82000000-0000-0000-0000-000000000011'),
  ('82000000-0000-0000-0000-0000000000d5','82000000-0000-0000-0000-000000000001','receipt','Receipt on the INVOICE','active',false,'82000000-0000-0000-0000-000000000011');
insert into public.document_links (tenant_id, document_id, booking_id)
select '82000000-0000-0000-0000-000000000001', d, '82000000-0000-0000-0000-0000000000b1'
from unnest(array['82000000-0000-0000-0000-0000000000d1'::uuid,'82000000-0000-0000-0000-0000000000d2',
                  '82000000-0000-0000-0000-0000000000d3','82000000-0000-0000-0000-0000000000d4']) d;
-- d5 hangs off the INVOICE, not the booking: it proves the chain invoice -> booking -> owner.
insert into public.document_links (tenant_id, document_id, invoice_id) values
  ('82000000-0000-0000-0000-000000000001','82000000-0000-0000-0000-0000000000d5','82000000-0000-0000-0000-0000000000f1');

-- ================================================================================================
-- Positive controls first: the two employees really are equivalent except for responsibility.
--
-- `set local role authenticated` is not decoration. RLS does not apply to the table owner, so every
-- read below would pass as `postgres` whatever the policy said -- which is exactly how the first
-- run of this file "passed" four assertions it had no right to. The role stays switched until the
-- mutation block needs DDL.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;

select ok(not app.has_permission('VIEW_FINANCIAL_DOCUMENTS'),
  'POSITIVE CONTROL: the responsible employee genuinely does NOT hold VIEW_FINANCIAL_DOCUMENTS -- so the read below is the assigned-related rule, not the permission');

-- Measured, not read off the seed: `employee` DOES hold VIEW_TRAVEL_DOCUMENTS in the live grant set
-- (`202607043600` did not give it to them; a later package did). It is asserted here because it is
-- load-bearing in the opposite direction to the one you would guess -- the travel permission is
-- consulted only for callers who ALSO hold VIEW_FINANCIAL_DOCUMENTS, so it cannot be what admits or
-- denies anything below.
select ok(app.has_permission('VIEW_TRAVEL_DOCUMENTS'),
  'POSITIVE CONTROL: the same employee DOES hold VIEW_TRAVEL_DOCUMENTS -- so the denial below is not the travel gate, and travel documents stay readable');

select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a4"}',true);

select is(
  (select count(*)::int from public.bookings where id = '82000000-0000-0000-0000-0000000000b1'),
  1,
  'POSITIVE CONTROL: the department colleague CAN read the booking -- operational continuity (owner directive 2026-08-24 amendment 1) is intact, which is what makes the denial below meaningful rather than incidental');

select ok(not app.is_document_responsible('82000000-0000-0000-0000-0000000000d1'),
  '...and is genuinely NOT a responsible user for what that document hangs off');

-- ================================================================================================
-- THE RULE (canon 08: "directly related to that lead or booking" / "cannot browse unrelated").
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a2"}',true);
select is(
  (select count(*)::int from public.documents where id = '82000000-0000-0000-0000-0000000000d1'),
  1,
  'SPEC-154-B: the RESPONSIBLE employee reads the non-confidential invoice document for their own booking');

select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a4"}',true);
select is(
  (select count(*)::int from public.documents where id = '82000000-0000-0000-0000-0000000000d1'),
  0,
  'SPEC-154-B: the DEPARTMENT COLLEAGUE does not -- before 202607058700 this returned 1, identically to the responsible employee, because the policy tested only whether the LINK was visible');

select is(
  (select count(*)::int from public.documents where id = '82000000-0000-0000-0000-0000000000d3'),
  1,
  'NEGATIVE CONTROL: the same colleague still reads the QUOTATION document -- canon puts quotations in CRM, not Finance, and amendment 2 minted VIEW_DEPARTMENT_RECORDS for exactly this continuity');

select is(
  (select count(*)::int from public.documents where id = '82000000-0000-0000-0000-0000000000d4'),
  1,
  'NEGATIVE CONTROL: ...and still reads the passport scan on that booking, so the change is confined to financial documents');

select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a2"}',true);
select is(
  (select count(*)::int from public.documents where id = '82000000-0000-0000-0000-0000000000d2'),
  0,
  'is_confidential remains an INDEPENDENT control: being responsible does not open a confidential financial document (canon 25 defines it as a per-document visibility level; canon 08/28 define financial strictness per TYPE -- the two are not collapsed)');

-- ================================================================================================
-- Finance and management are unaffected, except where canon says they should be.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select is(
  (select count(*)::int from public.documents where document_type_code = 'invoice'),
  2,
  'the finance_manager reads BOTH invoice documents, confidential and not -- VIEW_FINANCIAL_DOCUMENTS is untouched');

select is(
  (select count(*)::int from public.documents where id = '82000000-0000-0000-0000-0000000000d3'),
  0,
  'MEASURED CONSEQUENCE, asserted so it cannot change silently: that finance_manager no longer reads the QUOTATION document. It reached them only through `is_financial_document_type`, and canon 28 has exactly two document VIEW permissions -- a non-financial document is governed by VIEW_TRAVEL_DOCUMENTS, which canon marks Optional for this role');

select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select is(
  (select count(*)::int from public.documents where id = '82000000-0000-0000-0000-0000000000d1'),
  1,
  'the UPLOADER keeps their own upload -- which is what keeps canon 08''s worked example whole ("an employee can upload and view a customer''s bank transfer receipt for their assigned booking")');

-- ================================================================================================
-- The classifier now matches canon.
-- ================================================================================================
select ok(not app.is_financial_document_type('quotation'),
  'a quotation is NOT a financial document: canon 07 omits it, canon 28 governs it under CRM at assigned/department scope, and `app.financial_documents()` has never returned one');

select ok(app.is_financial_document_type('invoice')
      and app.is_financial_document_type('receipt')
      and app.is_financial_document_type('payment_proof'),
  '...while invoice, receipt and payment_proof still are');

-- ================================================================================================
-- The derivation itself, and the chain through a financial parent.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a2"}',true);
select ok(app.is_document_responsible('82000000-0000-0000-0000-0000000000d1'),
  'app.is_document_responsible resolves the booking owner');

select is(
  (select count(*)::int from public.documents where id = '82000000-0000-0000-0000-0000000000d5'),
  1,
  'CHAIN: a receipt document hanging off the INVOICE (not the booking) still reaches its responsible employee -- invoices and receipts have no owner of their own, so responsibility resolves through the booking they are FOR');

select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a4"}',true);
select is(
  (select count(*)::int from public.documents where id = '82000000-0000-0000-0000-0000000000d5'),
  0,
  '...and the colleague does not reach it through that chain either');

-- ================================================================================================
-- The endpoint is deliberately unchanged: a tenant-wide finance register is not the per-document
-- read canon grants the assigned employee.
-- ================================================================================================
select throws_ok(
  $$select count(*) from app.financial_documents()$$,
  '42501', null,
  'the finance REGISTER still refuses an ordinary employee -- SPEC-154-B moved the per-document read to RLS and left the tenant-wide listing where canon puts it');

select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select cmp_ok(
  (select count(*)::int from app.financial_documents()), '>=', 3,
  'POSITIVE CONTROL: and still serves the finance_manager, so the refusal above is the permission and not a broken endpoint');

-- ================================================================================================
-- MUTATION: prove the POLICY is the enforcer, by restoring the pre-migration form of the one
-- disjunct that changed and watching the colleague read the invoice again (PAR-4 pattern).
-- ================================================================================================
reset role;
savepoint m1;
drop policy scope_isolation on public.documents;
create policy scope_isolation on public.documents for all to authenticated
using (
    tenant_id = (select app.current_tenant_id())
    and (
        (select app.has_tenant_wide_read())
        or created_by = (select app.current_user_id())
        or (is_confidential and (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS'))
            and app.is_financial_document_type(document_type_code))
        or (not is_confidential
            and exists (select 1 from public.document_links dl where dl.document_id = public.documents.id)
            and ( not (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS'))
                  or app.is_financial_document_type(document_type_code)
                  or (select app.has_permission('VIEW_TRAVEL_DOCUMENTS')) ))
    )
);
select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a4"}',true);
set local role authenticated;
select is(
  (select count(*)::int from public.documents where id = '82000000-0000-0000-0000-0000000000d1'),
  1,
  'MUTATION: with the pre-migration disjunct restored the colleague reads the invoice document again -- proving that policy branch, and not some other guard, is what enforces SPEC-154-B');
reset role;
rollback to savepoint m1;

-- PAR-4's closing move, which the first draft of this file was missing: prove the enforcer came
-- BACK. It also fixes a counting trap worth stating, because it silently bit test 80 first --
-- pgTAP's assertion counter lives in a temp table, so `rollback to savepoint` undoes the count of
-- anything asserted inside the mutated region. With the mutation assertion last, every `ok` line is
-- still emitted and `finish()` reports "planned 20 but ran 19", which the suite's PASS hides.
select set_config('request.jwt.claims','{"sub":"82000000-0000-0000-0000-0000000000a4"}',true);
set local role authenticated;
select is(
  (select count(*)::int from public.documents where id = '82000000-0000-0000-0000-0000000000d1'),
  0,
  '...and once the mutation is rolled back the colleague is refused again -- the rule is restored, not merely observed once');
reset role;

select * from finish();
rollback;
