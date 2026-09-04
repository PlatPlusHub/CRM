-- pgTAP: VOID-1 -- the internal invoice void, and the boundary it must never cross.
--
-- WHAT MUST BE TRUE, and the last two are the whole point of the owner's decision:
--   * a void is a real internal act -- authorized, audited, terminal, and enforced on BOTH doors;
--   * it is REFUSED once money is allocated, because ORVION's own `customer_balance` arithmetic
--     would otherwise produce a credit balance backed by no document;
--   * an internal void asserts NOTHING about the external tax authority, and an externally
--     `accepted` document cannot be voided internally at all;
--   * an externally `cancelled` document does NOT void the ORVION invoice -- no mapping is defined,
--     and this test pins that no code invents one.
--
-- Every refusal is asserted by its EXACT error code and by the row NOT having moved. "It threw" is
-- not evidence; "it threw and the invoice is still issued" is (AGENTS.md §6).
create extension if not exists pgtap with schema extensions;

begin;
-- 32, not 31: the defect-injection assertion is RECORDED and then discarded by
-- `rollback to savepoint` (pgTAP keeps results in a table), while pgTAP's own counter is not rolled
-- back. The plan must match the COUNTER, so the injection assertion is counted even though its row
-- does not survive. Stated here because a bare number would look like an off-by-one.
select plan(32);

insert into auth.users (id, email, email_confirmed_at) values
  ('96000000-0000-0000-0000-0000000000a1','owner@void96.test',   now()),
  ('96000000-0000-0000-0000-0000000000a2','finance@void96.test', now()),
  ('96000000-0000-0000-0000-0000000000a3','emp@void96.test',     now());
insert into public.tenants (id, name, slug, status) values
  ('96000000-0000-0000-0000-000000000001','Void96 Travel','void96','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id='96000000-0000-0000-0000-000000000001';
insert into public.branches (id, tenant_id, name, slug) values
  ('96000000-0000-0000-0000-00000000000a','96000000-0000-0000-0000-000000000001','HQ','void96-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('96000000-0000-0000-0000-0000000000c1','96000000-0000-0000-0000-000000000001',
   '96000000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('96000000-0000-0000-0000-000000000011','96000000-0000-0000-0000-000000000001','Owner','owner@void96.test',true,'96000000-0000-0000-0000-0000000000a1'),
  ('96000000-0000-0000-0000-000000000012','96000000-0000-0000-0000-000000000001','Finance','finance@void96.test',true,'96000000-0000-0000-0000-0000000000a2'),
  ('96000000-0000-0000-0000-000000000013','96000000-0000-0000-0000-000000000001','Emp','emp@void96.test',true,'96000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '96000000-0000-0000-0000-000000000001', u,
       '96000000-0000-0000-0000-00000000000a','96000000-0000-0000-0000-0000000000c1', true
from unnest(array['96000000-0000-0000-0000-000000000011'::uuid,
                  '96000000-0000-0000-0000-000000000012'::uuid,
                  '96000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '96000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('96000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('96000000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('96000000-0000-0000-0000-000000000013'::uuid,'employee')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('96000000-0000-0000-0000-0000000000d1','96000000-0000-0000-0000-000000000001','person','Void Customer');

-- Six invoices, each isolating one rule.
insert into public.invoices (id, tenant_id, customer_id, invoice_number, invoice_date, currency_code, total_amount, status_code) values
  ('96000000-0000-0000-0000-0000000000f1','96000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-0000000000d1','INV-V96-1', current_date,'EGP', 1000, 'draft'),
  ('96000000-0000-0000-0000-0000000000f2','96000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-0000000000d1','INV-V96-2', current_date,'EGP', 1000, 'issued'),
  ('96000000-0000-0000-0000-0000000000f3','96000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-0000000000d1','INV-V96-3', current_date,'EGP', 1000, 'issued'),
  ('96000000-0000-0000-0000-0000000000f4','96000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-0000000000d1','INV-V96-4', current_date,'EGP', 1000, 'issued'),
  ('96000000-0000-0000-0000-0000000000f5','96000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-0000000000d1','INV-V96-5', current_date,'EGP', 1000, 'paid'),
  ('96000000-0000-0000-0000-0000000000f6','96000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-0000000000d1','INV-V96-6', current_date,'EGP', 1000, 'overdue');

-- f3 has ALLOCATED PAYMENT. f4 was ACCEPTED by the authority. Both are set here with no session, on
-- the platform path, so the fixtures themselves are not what is under test.
insert into public.payments (id, tenant_id, customer_id, payment_direction_code, payment_method_code, currency_code, amount, paid_at) values
  ('96000000-0000-0000-0000-0000000000e1','96000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-0000000000d1','customer_payment','bank_transfer','EGP', 400, now());
insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code) values
  ('96000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-0000000000e1','96000000-0000-0000-0000-0000000000f3', 400, 'EGP');
update public.invoices
   set external_submission_status_code = 'accepted',
       external_submission_id = 'ETA-DOC-UUID-0001',
       external_submitted_at = now(), external_response_at = now()
 where id = '96000000-0000-0000-0000-0000000000f4';

-- =============================================================================================
-- 1-6. THE THREE LIFECYCLES ARE SEPARATE, AND THE STRUCTURE SAYS SO.
-- =============================================================================================
select is(
  (select count(*)::int from app.status_transitions
    where table_name='invoices' and to_status='voided'),
  3,
  'VOID-1: exactly three states may be voided -- draft, issued and overdue');

select set_eq(
  $$select from_status from app.status_transitions where table_name='invoices' and to_status='voided'$$,
  $$values ('draft'),('issued'),('overdue')$$,
  'VOID-1: partially_paid and paid are ABSENT -- an invoice carrying allocated money is corrected by a refund, not a void');

select is(
  (select count(*)::int from app.status_transitions where table_name='invoices' and from_status='voided'),
  0,
  'VOID-1: nothing LEAVES voided -- it is terminal, and enforce_status_transition refuses every exit for free');

select is(
  (select permission_key from app.status_transitions
    where table_name='invoices' and to_status='voided' limit 1),
  'VOID_INVOICE',
  'VOID-1: voiding costs its own permission, not CREATE_INVOICE');

select ok(
  (select count(*) from public.catalog_values
    where catalog_type_code='tax_submission_status_code' and code='cancelled' and is_active) = 1,
  'VOID-1: the EXTERNAL lifecycle can now represent a cancellation -- a fact ORVION records, never one it performs');

select ok(
  (select count(*) from information_schema.columns
    where table_schema='public' and table_name='invoices' and column_name='corrects_invoice_id') = 1,
  'VOID-1: the credit/debit-note ANCHOR exists so a future workflow can reference the original deterministically');

-- =============================================================================================
-- 7-11. THE HAPPY PATH, THROUGH THE RPC, AS FINANCE.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"96000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$select app.void_invoice('96000000-0000-0000-0000-0000000000f1','entered in error')$$,
  'VOID-1: finance_manager, holding VOID_INVOICE, CAN void a draft invoice');

select is(
  (select status_code from public.invoices where id='96000000-0000-0000-0000-0000000000f1'),
  'voided',
  '...and the invoice actually MOVED -- "it did not throw" is not evidence that a write occurred');

select ok(
  (select voided_at is not null and voided_by = '96000000-0000-0000-0000-000000000012'
     from public.invoices where id='96000000-0000-0000-0000-0000000000f1'),
  'VOID-1: voided_at and voided_by are DERIVED from the session, never caller-supplied (ATTR-3 / FIN-4 class)');

select is(
  (select void_reason from public.invoices where id='96000000-0000-0000-0000-0000000000f1'),
  'entered in error',
  'VOID-1: the reason the caller gave is what is stored');

select is(
  (select count(*)::int from public.events
    where entity_id='96000000-0000-0000-0000-0000000000f1' and event_type_code='invoice_voided'),
  1,
  'VOID-1: the act is AUDITED as one intention, not inferred from a column diff');

-- =============================================================================================
-- 12-13. AN ISSUED, UNPAID, UNSUBMITTED INVOICE IS VOIDABLE. This is the case draft-only refused.
-- =============================================================================================
select lives_ok(
  $$select app.void_invoice('96000000-0000-0000-0000-0000000000f2','customer cancelled before payment')$$,
  'VOID-1 (THE OWNER REQUIREMENT): an ISSUED invoice can be voided -- draft-only was rejected as a final answer');

select is(
  (select status_code from public.invoices where id='96000000-0000-0000-0000-0000000000f2'),
  'voided',
  '...and it moved');

-- =============================================================================================
-- 14-17. THE MONEY RULE. Derived from ORVION's own balance arithmetic, not from an opinion.
-- =============================================================================================
select throws_ok(
  $$select app.void_invoice('96000000-0000-0000-0000-0000000000f3','try to void a part-paid invoice')$$,
  '23514',
  null,
  'VOID-1: an invoice with ALLOCATED PAYMENT is REFUSED -- customer_balance would otherwise drop the invoice and keep the payment');

select is(
  (select status_code from public.invoices where id='96000000-0000-0000-0000-0000000000f3'),
  'issued',
  '...and it did NOT move -- the refusal is real, not cosmetic');

-- The precondition is the ALLOCATION, not the status word: f3 still reads `issued`, and it is the
-- payment_allocations row that refuses. This is what makes a direct table write unable to slip past.
select ok(
  (select sum(allocated_amount) from public.payment_allocations
    where invoice_id='96000000-0000-0000-0000-0000000000f3') > 0,
  'VOID-1: ...and the refusal came from payment_allocations while status_code still said `issued` -- the status word alone was never trusted');

select is(
  (select outstanding_balance from app.customer_balance('96000000-0000-0000-0000-0000000000d1', null) limit 1),
  3600::numeric,
  'VOID-1: customer_balance is coherent -- f2 LEFT the sum when it was voided, and the four still-live invoices (4000) minus the 400 allocated payment remain');

-- =============================================================================================
-- 18-20. THE BOUNDARY. An externally ACCEPTED document cannot be voided internally.
-- =============================================================================================
select throws_ok(
  $$select app.void_invoice('96000000-0000-0000-0000-0000000000f4','try to void an accepted document')$$,
  '23514',
  null,
  'VOID-1 (THE SEPARATION): an EXTERNALLY ACCEPTED invoice is REFUSED -- ORVION performs no external cancellation and will not make the two records disagree');

select is(
  (select status_code from public.invoices where id='96000000-0000-0000-0000-0000000000f4'),
  'issued',
  '...and it did NOT move');

select is(
  (select external_submission_status_code from public.invoices where id='96000000-0000-0000-0000-0000000000f4'),
  'accepted',
  '...and the EXTERNAL state is untouched by the attempt -- the internal act never rewrites what the authority said');

-- =============================================================================================
-- 21-23. THE MAPPING THAT DOES NOT EXIST, PINNED SO NOTHING INVENTS IT.
-- =============================================================================================
reset role;
update public.invoices set external_submission_status_code='cancelled' where id='96000000-0000-0000-0000-0000000000f6';

select is(
  (select status_code from public.invoices where id='96000000-0000-0000-0000-0000000000f6'),
  'overdue',
  'VOID-1: recording an EXTERNAL cancellation does NOT void the ORVION invoice -- no mapping is defined, and none was invented');

select is(
  (select voided_at from public.invoices where id='96000000-0000-0000-0000-0000000000f6'),
  null,
  '...and no internal void field was touched by the external fact');

select is(
  (select count(*)::int from public.events
    where entity_id='96000000-0000-0000-0000-0000000000f6' and event_type_code='invoice_voided'),
  0,
  '...and no internal void event was emitted -- an external state change is not an internal act');

-- =============================================================================================
-- 24-27. AUTHORITY, ON BOTH DOORS.
-- =============================================================================================
-- THE EMPLOYEE MUST BE ABLE TO SEE THE ROW, OR THE NEXT REFUSAL PROVES NOTHING.
-- `invoices` RLS admits a caller holding VIEW_FINANCIAL_DOCUMENTS or reaching the invoice through a
-- booking. These fixtures have no booking, so an employee sees NOTHING -- and the first version of
-- this test asserted a table-door refusal that was really an UPDATE matching zero rows. That is the
-- vacuous-security-test class `AGENTS.md §6` names, caught by its own companion assertion. Visibility
-- is granted per-user through RBAC-5's `user_permission_grants`, which also exercises that model.
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '96000000-0000-0000-0000-000000000001','96000000-0000-0000-0000-000000000013', p.id, 'grant',
       'test fixture: make the invoice VISIBLE so the void refusal is about authority, not visibility'
from public.permissions p where p.key = 'VIEW_FINANCIAL_DOCUMENTS';

select set_config('request.jwt.claims','{"sub":"96000000-0000-0000-0000-0000000000a3"}', true);
set local role authenticated;

select is(
  (select status_code from public.invoices where id='96000000-0000-0000-0000-0000000000f6'),
  'overdue',
  'POSITIVE CONTROL: the employee CAN SEE this invoice -- so every refusal below is about authority, never about an UPDATE matching zero rows');

select throws_ok(
  $$select app.void_invoice('96000000-0000-0000-0000-0000000000f6','employee tries the RPC')$$,
  '42501',
  null,
  'VOID-1: an employee holding no VOID_INVOICE is REFUSED at the RPC');

select throws_ok(
  $$update public.invoices set status_code='voided', void_reason='employee tries the table'
     where id='96000000-0000-0000-0000-0000000000f6'$$,
  '42501',
  null,
  'VOID-1: ...and REFUSED at the TABLE DOOR too -- authenticated holds UPDATE on invoices, so PostgREST serves it beside the RPC');

select is(
  (select status_code from public.invoices where id='96000000-0000-0000-0000-0000000000f6'),
  'overdue',
  '...and neither attempt moved it');

reset role;
select set_config('request.jwt.claims','{"sub":"96000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$update public.invoices set status_code='voided' where id='96000000-0000-0000-0000-0000000000f6'$$,
  '23514',
  null,
  'VOID-1: even an authorized voider must give a REASON -- canon 26 demands one for archiving, and a void is the stronger act');

-- =============================================================================================
-- 28-30. TERMINALITY, THE SPLIT-STATE GUARD, AND DEFECT INJECTION.
-- =============================================================================================
select throws_ok(
  $$update public.invoices set status_code='issued' where id='96000000-0000-0000-0000-0000000000f1'$$,
  '23514',
  null,
  'VOID-1: a voided invoice cannot be UN-voided -- terminal, with a real message rather than a generic transition refusal');

select throws_ok(
  $$update public.invoices set voided_at = now() where id='96000000-0000-0000-0000-0000000000f6'$$,
  '23514',
  null,
  'VOID-1 (DOC-LC-3 APPLIED BEFORE IT COULD HAPPEN): voided_at cannot move without the status -- the split state that made `documents` unre-versionable is unreachable here');

reset role;
savepoint before_injection;
drop trigger invoices_guard_void on public.invoices;

select set_config('request.jwt.claims','{"sub":"96000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$update public.invoices set status_code='voided', void_reason='x'
     where id='96000000-0000-0000-0000-0000000000f3'$$,
  'PAR-4 (DEFECT INJECTION): with invoices_guard_void DROPPED, the part-paid invoice CAN be voided -- proving that guard, and not the transition table, is what enforces the money rule');

reset role;
rollback to savepoint before_injection;

-- The savepoint rollback also DISCARDS pgTAP's recorded row for the assertion above -- results live
-- in a table, so anything recorded after the savepoint is undone with it. Re-asserting here both
-- restores the count and proves the injection was actually undone, which is the more useful claim.
select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid=t.tgrelid
    where not t.tgisinternal and t.tgname='invoices_guard_void')
  || '/' ||
  (select status_code from public.invoices where id='96000000-0000-0000-0000-0000000000f3'),
  '1/issued',
  'PAR-4: the guard is restored and the part-paid invoice is still `issued` -- the injection left nothing behind');

select * from finish();
rollback;
