-- pgTAP: MONEY-2 -- the three money columns do NOT share one sign rule, and this file is the proof
-- that the difference is enforced rather than merely written down.
--
-- OWNER DECISION, 2026-09-09:
--   * financial_accounts.opening_balance -- SIGNED. An account may open overdrawn. No non-negative
--     rule, deliberately. Asserted here as a NEGATIVE space test, because the failure mode this
--     decision guards against is a later reader "completing the pattern" by symmetry.
--   * quotations.total_amount / quotation_items.total_amount -- never below zero, on every door.
--
-- Both doors are exercised. `authenticated` holds INSERT and UPDATE on both quotation tables, so
-- PostgREST serves them beside the RPC (BOOK-1), and the header total is DERIVED by
-- app.recompute_quotation_total -- so "the RPC cannot produce a negative" is not a proof that the
-- column cannot hold one.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into auth.users (id, email) values ('a2000000-0000-0000-0000-0000000000a1','emp@money2.test');
insert into public.tenants (id, name, slug, status) values
  ('a2000000-0000-0000-0000-000000000001','Money2 Travel','money2-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select 'a2000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('a2000000-0000-0000-0000-00000000000a','a2000000-0000-0000-0000-000000000001','Cairo','money2-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('a2000000-0000-0000-0000-0000000000c1','a2000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('a2000000-0000-0000-0000-000000000011','a2000000-0000-0000-0000-000000000001','Emp','emp@money2.test',true,'a2000000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('a2000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000011','a2000000-0000-0000-0000-00000000000a','a2000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'a2000000-0000-0000-0000-000000000001','a2000000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'employee';
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('a2000000-0000-0000-0000-0000000000d1','a2000000-0000-0000-0000-000000000001','person','Buyer');

-- =============================================================================================
-- 1-3. THE DECISION'S SHAPE: two columns constrained, one deliberately not.
-- =============================================================================================
select ok(
  (select count(*) from pg_constraint
    where conrelid = 'public.quotations'::regclass and contype = 'c'
      and conname = 'quotations_total_amount_nonneg_check') = 1,
  'quotations.total_amount carries a non-negative CHECK');

select ok(
  (select count(*) from pg_constraint
    where conrelid = 'public.quotation_items'::regclass and contype = 'c'
      and conname = 'quotation_items_total_amount_nonneg_check') = 1,
  'quotation_items.total_amount carries a non-negative CHECK');

select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.financial_accounts'::regclass and contype = 'c'
      and pg_get_constraintdef(oid) ~ 'opening_balance'
      and pg_get_constraintdef(oid) ~ '>=|>'),
  0,
  'THE DECISION, STATED AS AN ASSERTION: financial_accounts.opening_balance carries NO non-negative rule -- an account opening overdrawn is an ordinary banking fact, and MONEY-2 refused this constraint on purpose. This assertion fails the day someone adds it by symmetry.');

-- =============================================================================================
-- 4-5. POSITIVE CONTROL: the signed column really does accept a negative, and NaN is still refused.
--      Without assertion 4 the "no constraint" assertion above could be satisfied by a column
--      nothing can write to at all.
-- =============================================================================================
insert into public.financial_accounts (id, tenant_id, financial_account_type_code, name, currency_code, opening_balance)
values ('a2000000-0000-0000-0000-0000000000f1','a2000000-0000-0000-0000-000000000001','bank','Overdrawn Bank','EGP',-2500);

select is(
  (select opening_balance::text from public.financial_accounts where id = 'a2000000-0000-0000-0000-0000000000f1'),
  '-2500.0000',
  'POSITIVE CONTROL: an account opens at -2,500 and the row exists -- the signed decision is exercised, not merely asserted as an absence');

select throws_ok(
  $q$insert into public.financial_accounts (tenant_id, financial_account_type_code, name, currency_code, opening_balance)
     values ('a2000000-0000-0000-0000-000000000001','bank','NaN Bank','EGP','NaN')$q$,
  '23514',
  NULL,
  'MONEY-1 IS UNTOUCHED: the NaN defence on the same column still refuses a non-finite opening balance');

-- =============================================================================================
-- 6-9. THE RPC DOOR. The authorized path must still work, and must still permit zero.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"a2000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select ok(app.has_permission('CREATE_QUOTATION'),
  'POSITIVE CONTROL: the actor genuinely holds CREATE_QUOTATION, so every refusal below is about the sign rule and not about authority');

select lives_ok(
  $q$select app.add_quotation_item(
      app.create_quotation('a2000000-0000-0000-0000-0000000000d1','EGP'), 'flight_ticket', 1000, 1)$q$,
  'THE ONE THAT MATTERS: an ordinary priced line still goes in -- the constraint does not break quoting');

select lives_ok(
  $q$select app.add_quotation_item(
      (select id from public.quotations where tenant_id = 'a2000000-0000-0000-0000-000000000001' limit 1),
      'flight_ticket', 0, 1)$q$,
  'ZERO REMAINS LEGAL: a complimentary (zero-priced) line is accepted -- the rule is >= 0, never > 0');

select is(
  (select total_amount::text from public.quotations where tenant_id = 'a2000000-0000-0000-0000-000000000001'),
  '1000.0000',
  'the derived header still equals the sum of its lines after both inserts');

-- =============================================================================================
-- 10-13. THE TABLE DOOR -- the one the RPC cannot speak for.
-- =============================================================================================
select throws_ok(
  $q$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, quantity, unit_price, total_amount, currency_code)
     select 'a2000000-0000-0000-0000-000000000001', q.id, 'flight_ticket', 1, 0, -900, 'EGP'
     from public.quotations q where q.tenant_id = 'a2000000-0000-0000-0000-000000000001' limit 1$q$,
  '23514',
  NULL,
  'TABLE DOOR, INSERT: a directly inserted negative LINE total is refused -- this is the door PostgREST serves beside the RPC');

select throws_ok(
  $q$update public.quotation_items set total_amount = -1
      where tenant_id = 'a2000000-0000-0000-0000-000000000001' and total_amount = 1000$q$,
  '23514',
  NULL,
  'TABLE DOOR, UPDATE: an existing line cannot be edited below zero either');

select throws_ok(
  $q$update public.quotations set total_amount = -500
      where tenant_id = 'a2000000-0000-0000-0000-000000000001'$q$,
  '23514',
  NULL,
  'TABLE DOOR, THE DERIVED HEADER: a hand-written negative total is refused. app.recompute_quotation_total can never produce one -- a sum of non-negative lines is non-negative -- so this constraint exists precisely for the writer that is not the calculator');

select is(
  (select total_amount::text from public.quotations where tenant_id = 'a2000000-0000-0000-0000-000000000001'),
  '1000.0000',
  'and the header is unchanged after all three refusals -- no partial write survived');

-- =============================================================================================
-- 14. ONE ARITHMETIC AUTHORITY: no second calculator was introduced alongside the constraints.
-- =============================================================================================
reset role;
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('app','public') and p.prokind = 'f'
      and p.proname <> 'recompute_quotation_total'
      and p.prosrc ~ 'update\s+public\.quotations[^;]*set[^;]*total_amount'),
  0,
  'ONE ARITHMETIC AUTHORITY: app.recompute_quotation_total is still the only function that writes quotations.total_amount -- MONEY-2 added constraints, not a duplicate calculator');

-- =============================================================================================
-- 15-16. LOAD-BEARING (PAR-4 defect injection). A constraint that exists and is not what refuses
--        the write would satisfy assertions 1-2 and prove nothing.
-- =============================================================================================
savepoint before_enforcer_mutation;
alter table public.quotations drop constraint quotations_total_amount_nonneg_check;

update public.quotations set total_amount = -500
 where tenant_id = 'a2000000-0000-0000-0000-000000000001';

select is(
  (select total_amount::text from public.quotations where tenant_id = 'a2000000-0000-0000-0000-000000000001'),
  '-500.0000',
  'MUTATION: with the named constraint dropped the identical UPDATE SUCCEEDS and the header goes negative -- so that constraint is what closes MONEY-2 on this door, and nothing else was doing it');

rollback to savepoint before_enforcer_mutation;

select throws_ok(
  $q$update public.quotations set total_amount = -500
      where tenant_id = 'a2000000-0000-0000-0000-000000000001'$q$,
  '23514',
  NULL,
  'RESTORED: with the constraint back the identical UPDATE is refused again');

select finish();
rollback;
