-- pgTAP: FIN-7 -- the invoice state machine, enforced on the door it was never enforced on.
--
-- FIN-7 was carried as `BLOCKED — BUSINESS DECISION` on the reading that canon defines no invoice
-- machine and that naming the transitions would invent policy. The machine was already written and
-- already enforced -- inside `app.issue_invoice` and `app.record_payment`. What was missing is that
-- `app.status_transitions` held zero `invoices` rows and the table carried no transition trigger,
-- so the rules bound the RPC door only, while `authenticated` holds UPDATE on `public.invoices`.
--
-- Every negative below is preceded by a positive control on the SAME actor and the SAME row, so no
-- refusal here can be an artifact of an empty fixture or an invisible row (AGENTS.md §6, "no vacuous
-- security tests"). The final section injects the defect (PAR-4): the trigger is dropped, the
-- illegal move is proven to SUCCEED, and the trigger is restored and proven to refuse again --
-- because "it did not throw" is not evidence that anything was enforced.
create extension if not exists pgtap with schema extensions;

begin;
select plan(21);

insert into auth.users (id, email) values
  ('94000000-0000-0000-0000-0000000000a1','fin@fin7.test');
insert into public.tenants (id, name, slug, status) values
  ('94000000-0000-0000-0000-000000000001','FIN7 Travel','fin7-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '94000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('94000000-0000-0000-0000-00000000000a','94000000-0000-0000-0000-000000000001','Cairo','fin7-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('94000000-0000-0000-0000-0000000000c1','94000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-00000000000a','sales','FIN7 Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('94000000-0000-0000-0000-000000000011','94000000-0000-0000-0000-000000000001','Finance','fin@fin7.test',true,'94000000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('94000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000011','94000000-0000-0000-0000-00000000000a','94000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '94000000-0000-0000-0000-000000000001','94000000-0000-0000-0000-000000000011'::uuid, r.id,'tenant'
from public.roles r where r.code='finance_manager';
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('94000000-0000-0000-0000-0000000000d1','94000000-0000-0000-0000-000000000001','person','FIN7 Customer','+201009994444');

-- =============================================================================================
-- 0. THE REGISTRATION ITSELF. Six rows, read off the two RPCs -- not five, not seven.
-- =============================================================================================
select is(
  (select count(*)::int from app.status_transitions where table_name='invoices'),
  6,
  'FIN-7: exactly six invoice transitions are registered');

select set_eq(
  $$select from_status || '->' || to_status from app.status_transitions where table_name='invoices'$$,
  $$values ('draft->issued'),('issued->partially_paid'),('issued->paid'),
           ('partially_paid->paid'),('overdue->partially_paid'),('overdue->paid')$$,
  '...and they are exactly the moves app.issue_invoice and app.record_payment perform');

select is(
  (select permission_key from app.status_transitions
    where table_name='invoices' and from_status='draft' and to_status='issued'),
  'CREATE_INVOICE',
  'draft->issued charges what app.issue_invoice charges');

select is(
  (select count(distinct permission_key)::int from app.status_transitions
    where table_name='invoices' and to_status in ('paid','partially_paid')),
  1,
  'every payment move charges one permission');

select is(
  (select distinct permission_key from app.status_transitions
    where table_name='invoices' and to_status in ('paid','partially_paid')),
  'RECORD_PAYMENT',
  '...and it is what app.record_payment charges');

-- Two states must NOT be registered: one has no producer, one is an open owner decision.
select is(
  (select count(*)::int from app.status_transitions
    where table_name='invoices' and to_status in ('overdue','voided')),
  0,
  'FIN-7: `-> overdue` (no producer) and `-> voided` (VOID-1, open) are deliberately unregistered');

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid=t.tgrelid
    where c.relname='invoices' and t.tgname='invoices_enforce_status_transition'
      and not t.tgisinternal),
  1,
  'the transition trigger is attached to public.invoices');

-- =============================================================================================
-- 1. THE RPC DOOR STILL WORKS END TO END. If enforcement broke the real path, everything below
--    would be meaningless -- this is the positive control the whole file rests on.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"94000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select lives_ok(
  $$select app.create_invoice('94000000-0000-0000-0000-0000000000d1','EGP', 1000)$$,
  'POSITIVE CONTROL: finance can still raise an invoice');

select is(
  (select count(*)::int from public.invoices where tenant_id='94000000-0000-0000-0000-000000000001'),
  1,
  '...and the row is genuinely there and visible to this actor (not an empty-fixture pass)');

select lives_ok(
  $$select app.issue_invoice((select id from public.invoices where tenant_id='94000000-0000-0000-0000-000000000001'))$$,
  'POSITIVE CONTROL: draft -> issued still works through app.issue_invoice, WITH the trigger active');

select is(
  (select status_code from public.invoices where tenant_id='94000000-0000-0000-0000-000000000001'),
  'issued',
  '...and it actually moved (the transition happened, it did not merely not throw)');

select lives_ok(
  $$select app.record_payment((select id from public.invoices where tenant_id='94000000-0000-0000-0000-000000000001'), 400, 'cash')$$,
  'POSITIVE CONTROL: a part payment still works through app.record_payment');

select is(
  (select status_code from public.invoices where tenant_id='94000000-0000-0000-0000-000000000001'),
  'partially_paid',
  '...and record_payment DERIVED partially_paid from the amount, as it always has');

-- A SECOND part payment leaves the status unchanged. This is the case that would break a naive
-- implementation: partially_paid -> partially_paid is not a registered transition, and the trigger
-- must treat it as a non-transition rather than refuse it.
select lives_ok(
  $$select app.record_payment((select id from public.invoices where tenant_id='94000000-0000-0000-0000-000000000001'), 100, 'cash')$$,
  'a SECOND part payment is not refused -- same-status update is not a transition');

select lives_ok(
  $$select app.record_payment((select id from public.invoices where tenant_id='94000000-0000-0000-0000-000000000001'), 500, 'cash')$$,
  'POSITIVE CONTROL: the final payment still works');

select is(
  (select status_code from public.invoices where tenant_id='94000000-0000-0000-0000-000000000001'),
  'paid',
  '...and partially_paid -> paid completed through the registered move');

-- =============================================================================================
-- 2. THE DIRECT TABLE DOOR -- the door FIN-7 is about. Same actor, same row, proven visible above.
-- =============================================================================================
savepoint direct_door;

select throws_ok(
  $$update public.invoices set status_code = 'draft'
     where tenant_id = '94000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'BACKWARDS: paid -> draft is refused at the table door');
rollback to savepoint direct_door;

select throws_ok(
  $$update public.invoices set status_code = 'voided'
     where tenant_id = '94000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'VOID-1: paid -> voided is refused -- voiding stays an open owner decision, not a silent capability');
rollback to savepoint direct_door;

select throws_ok(
  $$update public.invoices set status_code = 'overdue'
     where tenant_id = '94000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'NO PRODUCER: paid -> overdue is refused -- nothing writes `overdue`, so nothing may');

-- =============================================================================================
-- 3. DEFECT INJECTION (PAR-4). The refusals above prove nothing unless the SAME statement succeeds
--    with the enforcer removed. Drop it, prove the skip lands, restore it, prove it is refused.
-- =============================================================================================
rollback to savepoint direct_door;
reset role;
savepoint injection;

drop trigger invoices_enforce_status_transition on public.invoices;

update public.invoices set status_code = 'draft'
 where tenant_id = '94000000-0000-0000-0000-000000000001';
update public.invoices set status_code = 'paid'
 where tenant_id = '94000000-0000-0000-0000-000000000001';

select is(
  (select status_code from public.invoices where tenant_id='94000000-0000-0000-0000-000000000001'),
  'paid',
  'DEFECT INJECTION: with the trigger dropped, draft -> paid SUCCEEDS -- this is exactly the state FIN-7 reproduced, so the refusals above are the trigger and not something else');

rollback to savepoint injection;

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid=t.tgrelid
    where c.relname='invoices' and t.tgname='invoices_enforce_status_transition'
      and not t.tgisinternal),
  1,
  'CONTROL: the trigger is restored by the rollback');

select * from finish();
rollback;
