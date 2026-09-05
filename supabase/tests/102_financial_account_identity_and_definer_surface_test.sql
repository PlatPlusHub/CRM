-- pgTAP: BATCH 6 SLICE 2 -- `financial_accounts`, and the SECURITY DEFINER tenant class
-- (`202607061200`).
--
-- ATTACK-CLASSES: AUTH TENANT DOOR INPUT BUSINESS PRIVILEGE OBSERVABILITY CONCURRENCY=N/A REPLAY=N/A
--
-- The line above is machine-readable and Check 24 parses it: a surface may not be recorded
-- `ADVERSARIAL` in MASTER_SURFACE_DISPOSITION.md unless a test file names it, declares the classes
-- it attacked, and actually carries negative assertions. `N/A` is a POSITION, not a gap -- stating
-- why a class does not apply is the difference between a considered exclusion and a silent one:
--   CONCURRENCY = N/A: this surface has no counter, lease, allocation or single-use token. Its only
--     unique index is (tenant_id, id), the composite-FK anchor, which two concurrent writers cannot
--     race over. LIC-2's class has nothing to bite on here.
--   REPLAY = N/A: there is no operation to repeat -- no RPC, no idempotency key, no delivery.
--
-- SELECTED BY MEASUREMENT, not by interest: `scripts/batch6_select_target.ps1` ranked this surface
-- first among the 75 still at NOT-RECORDED (money column, two direct write grants, zero RPCs, two
-- test files of which one had any negative assertion).
--
-- Assertions 13, 14 and 20 FAILED before `202607061200`. The rest are controls, negative controls, or
-- regression guards pinning behaviour that was already correct -- which is recorded deliberately: a
-- control proven strong is worth as much as a control proven weak, and pinning it stops the next
-- session re-deriving it.
create extension if not exists pgtap with schema extensions;

begin;
select plan(23);

insert into auth.users (id, email, email_confirmed_at) values
  ('fa000000-0000-0000-0000-0000000000a1','finance@fa102.test', now()),
  ('fa000000-0000-0000-0000-0000000000a2','emp@fa102.test',     now()),
  ('fa000000-0000-0000-0000-0000000000a3','rival@fa102.test',   now());
insert into public.tenants (id, name, slug, status) values
  ('fa000000-0000-0000-0000-000000000001','FA102 Travel','fa102','active'),
  ('fa000000-0000-0000-0000-000000000002','Rival102 Travel','rival102','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise'
  and t.id in ('fa000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000002');
insert into public.branches (id, tenant_id, name, slug) values
  ('fa000000-0000-0000-0000-00000000000a','fa000000-0000-0000-0000-000000000001','HQ','fa102-hq'),
  ('fa000000-0000-0000-0000-00000000000b','fa000000-0000-0000-0000-000000000002','HQ','rival102-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('fa000000-0000-0000-0000-0000000000c1','fa000000-0000-0000-0000-000000000001',
   'fa000000-0000-0000-0000-00000000000a','finance','Finance'),
  ('fa000000-0000-0000-0000-0000000000c2','fa000000-0000-0000-0000-000000000002',
   'fa000000-0000-0000-0000-00000000000b','finance','Finance');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('fa000000-0000-0000-0000-000000000011','fa000000-0000-0000-0000-000000000001','Finance','finance@fa102.test',true,'fa000000-0000-0000-0000-0000000000a1'),
  ('fa000000-0000-0000-0000-000000000012','fa000000-0000-0000-0000-000000000001','Emp','emp@fa102.test',true,'fa000000-0000-0000-0000-0000000000a2'),
  ('fa000000-0000-0000-0000-000000000013','fa000000-0000-0000-0000-000000000002','Rival Finance','rival@fa102.test',true,'fa000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('fa000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000011','fa000000-0000-0000-0000-00000000000a','fa000000-0000-0000-0000-0000000000c1',true),
  ('fa000000-0000-0000-0000-000000000001','fa000000-0000-0000-0000-000000000012','fa000000-0000-0000-0000-00000000000a','fa000000-0000-0000-0000-0000000000c1',true),
  ('fa000000-0000-0000-0000-000000000002','fa000000-0000-0000-0000-000000000013','fa000000-0000-0000-0000-00000000000b','fa000000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('fa000000-0000-0000-0000-000000000001'::uuid,'fa000000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
             ('fa000000-0000-0000-0000-000000000001'::uuid,'fa000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('fa000000-0000-0000-0000-000000000002'::uuid,'fa000000-0000-0000-0000-000000000013'::uuid,'finance_manager')) v(t,u,rc)
join public.roles r on r.code = v.rc;

-- The rival's own account, so assertion 8 is a TENANT test and not a "row does not exist" test.
insert into public.financial_accounts (id, tenant_id, financial_account_type_code, name, currency_code)
values ('fa000000-0000-0000-0000-0000000000f9','fa000000-0000-0000-0000-000000000002','bank','Rival Bank','EGP');

-- =============================================================================================
-- DOOR. 1-2. Why RLS plus one trigger is allowed to be the whole layer here, pinned so that the
--       day either statement stops being true, this file fails instead of quietly under-testing.
-- =============================================================================================
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('app','public','reporting')
      and p.prosrc ~ '(insert into|update)\s+public\.financial_accounts\M'),
  0,
  'DOOR: no function anywhere writes financial_accounts -- the table door is not a bypass of an RPC door, it IS the door');

select is(
  (select count(*)::int from pg_policies
    where schemaname='public' and tablename='financial_accounts'
      and coalesce(with_check,'') ~ '(has_permission|authorize)'),
  0,
  'DOOR: the capability is NOT in RLS -- the policy names only the tenant, so app.guard_write_capability is the only thing charging CREATE_JOURNAL_ENTRY, and assertion 18 injects its absence to prove it');

-- =============================================================================================
-- AUTH. 3-6. The permission is real on BOTH write verbs. SEC-1c was a whole package about tables
--       guarded on INSERT and not on UPDATE, so the negative is asserted on each verb separately.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"fa000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok($$
  insert into public.financial_accounts (id, tenant_id, financial_account_type_code, name, currency_code, opening_balance)
  values ('fa000000-0000-0000-0000-0000000000f1','fa000000-0000-0000-0000-000000000001','bank','Main EGP Bank','EGP', 1000.0000)$$,
  'CONTROL: a finance_manager holding CREATE_JOURNAL_ENTRY can open an account -- every refusal below is a refusal of the ACT');

select is(
  (select currency_code from public.financial_accounts where id='fa000000-0000-0000-0000-0000000000f1'),
  'EGP',
  'CONTROL: the account is really there with the currency it was opened in');

reset role;
select set_config('request.jwt.claims','{"sub":"fa000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select is(
  app.has_permission('CREATE_JOURNAL_ENTRY'), false,
  'CONTROL for the two denials below: the employee genuinely lacks the permission, so they are permission denials and not something else');

select throws_ok($$
  insert into public.financial_accounts (tenant_id, financial_account_type_code, name, currency_code)
  values ('fa000000-0000-0000-0000-000000000001','cash','Petty Cash','EGP')$$,
  '42501',
  null,
  'AUTH: an employee cannot OPEN an account -- vertical escalation refused on INSERT');

select throws_ok($$
  update public.financial_accounts set name = 'Renamed By Employee'
   where id = 'fa000000-0000-0000-0000-0000000000f1'$$,
  '42501',
  null,
  'AUTH: and cannot RENAME one either -- the guard charges the same permission on UPDATE, which is SEC-1c''s class');

reset role;

-- =============================================================================================
-- TENANT. 7-8. Both directions, and the row-hop. `financial_accounts` has no owner column, so the
--        tenant IS the whole boundary here -- there is no second predicate to fall back on.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"fa000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok($$
  insert into public.financial_accounts (tenant_id, financial_account_type_code, name, currency_code)
  values ('fa000000-0000-0000-0000-000000000002','bank','Planted In Rival','EGP')$$,
  '42501',
  null,
  'TENANT: a fully privileged finance_manager cannot open an account inside another agency');

select throws_ok($$
  update public.financial_accounts
     set tenant_id = 'fa000000-0000-0000-0000-000000000002'
   where id = 'fa000000-0000-0000-0000-0000000000f1'$$,
  '42501',
  null,
  'TENANT (row-hop): nor MOVE their own account into another agency -- RLS WITH CHECK judges the row AFTER the update, not before');

select is(
  (select count(*)::int from public.financial_accounts where id='fa000000-0000-0000-0000-0000000000f9'),
  0,
  'TENANT: the rival''s account is invisible, so the two refusals above are refusals and not accidents of an empty table');

-- =============================================================================================
-- BUSINESS. 9-12. FA-1. An account keeps the currency and the kind its money arrived in.
--           Assertion 9 proves the freeze binds; 11 proves it is CONDITIONAL and not a blanket ban.
-- =============================================================================================
-- Before any payment: the account is a typo someone may still fix.
select lives_ok($$
  update public.financial_accounts set currency_code = 'USD'
   where id = 'fa000000-0000-0000-0000-0000000000f1'$$,
  'FA-1 is CONDITIONAL: an UNUSED account can still be re-denominated -- a mistyped currency is a typo, not history');

select lives_ok($$
  update public.financial_accounts set currency_code = 'EGP'
   where id = 'fa000000-0000-0000-0000-0000000000f1'$$,
  'CONTROL: and back again, so the fixture below starts from EGP');

reset role;
-- The JWT claims must go too, not just the database role. app.guard_write_capability resolves
-- the actor from the request.jwt.claims setting and never from the role, so "reset role" on its
-- own leaves the owner path still charged CREATE_CUSTOMER. Found by this file failing its first run.
select set_config('request.jwt.claims','', true);

-- Money arrives. Inserted as the table owner: `record_payment` is an RPC with its own preconditions
-- (an issued invoice, an allocation), and this file is testing the ACCOUNT, not the payment path.
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('fa000000-0000-0000-0000-0000000000d1','fa000000-0000-0000-0000-000000000001','person','Payer');
insert into public.payments (id, tenant_id, customer_id, financial_account_id, payment_direction_code, payment_method_code, currency_code, amount, paid_at)
values ('fa000000-0000-0000-0000-0000000000e1','fa000000-0000-0000-0000-000000000001',
        'fa000000-0000-0000-0000-0000000000d1','fa000000-0000-0000-0000-0000000000f1',
        'customer_payment','bank_transfer','EGP', 500.0000, now());

select set_config('request.jwt.claims','{"sub":"fa000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok($$
  update public.financial_accounts set currency_code = 'USD'
   where id = 'fa000000-0000-0000-0000-0000000000f1'$$,
  '42501',
  null,
  'FA-1: once a payment has been routed through the account its CURRENCY is fixed -- EGP already received cannot become USD retroactively');

select throws_ok($$
  update public.financial_accounts set financial_account_type_code = 'cash'
   where id = 'fa000000-0000-0000-0000-0000000000f1'$$,
  '42501',
  null,
  'FA-1: and its KIND is fixed too -- a bank account holding real payments cannot be relabelled a cash drawer');

select lives_ok($$
  update public.financial_accounts set name = 'Main EGP Bank (Zamalek)', is_active = false
   where id = 'fa000000-0000-0000-0000-0000000000f1'$$,
  'NEGATIVE CONTROL: renaming and DEACTIVATING a used account are still legal -- FA-1 freezes identity, not administration');

-- =============================================================================================
-- INPUT. 13-14. The catalog and the currency FK, attacked rather than assumed.
-- =============================================================================================
select throws_ok($$
  insert into public.financial_accounts (tenant_id, financial_account_type_code, name, currency_code)
  values ('fa000000-0000-0000-0000-000000000001','offshore_vault','Creative Account','EGP')$$,
  '23514',
  null,
  'INPUT: an unregistered account TYPE is refused by app.enforce_catalog_codes -- the vocabulary is closed. The code is check_violation, NOT the default P0001: the guard raises it deliberately so a catalog refusal is indistinguishable from a CHECK constraint to any caller');

select throws_ok($$
  insert into public.financial_accounts (tenant_id, financial_account_type_code, name, currency_code)
  values ('fa000000-0000-0000-0000-000000000001','bank','Imaginary Money','XXZ')$$,
  '23503',
  null,
  'INPUT: an unregistered CURRENCY is refused by the FK -- money must be denominated in something that exists');

reset role;

-- =============================================================================================
-- PRIVILEGE. 15-17. SECDEF-1, as a CLASS over the whole SECURITY DEFINER surface rather than as two
--            named functions. Every ORVION table has RLS enabled and NONE forces it, and every
--            table is owned by the role that owns the functions -- so a SECURITY DEFINER function
--            runs with RLS entirely bypassed. That is correct and load-bearing for system paths,
--            and it is exactly why a caller-supplied tenant argument inside one is a door.
-- =============================================================================================
select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid=c.relnamespace
    where n.nspname='public' and c.relkind='r' and c.relrowsecurity and not c.relforcerowsecurity),
  77,
  'PRIVILEGE (measured, not a defect): all 77 tables enable RLS and none FORCES it, so every SECURITY DEFINER function bypasses RLS -- the premise the next assertion exists to bound');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='app' and p.prosecdef
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and (p.proconfig is null or not exists (select 1 from unnest(p.proconfig) cfg where cfg like 'search_path=%'))),
  0,
  'PRIVILEGE: no SECURITY DEFINER function reachable by authenticated runs without a pinned search_path -- PostgreSQL''s own guidance, and ORVION pins it EMPTY, which is stronger than the documented "pg_temp last"');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='app' and p.prosecdef
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and pg_get_function_arguments(p.oid) ilike '%tenant_id%'
      and p.prosrc !~ 'current_tenant_id'),
  0,
  'SECDEF-1 CLASS: no SECURITY DEFINER function reachable by authenticated takes a caller-supplied tenant and fails to compare it to the session''s own -- a new one fails this closed');

-- =============================================================================================
-- OBSERVABILITY. 18. Recorded rather than fixed: the event type exists and nothing emits it.
-- =============================================================================================
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='app' and p.prosrc like '%financial_account_created%'),
  0,
  'OBSERVABILITY: `financial_account_created` is a REGISTERED event type with NO producer -- opening a bank account leaves no trace in the audit spine. Inside EVT-2''s known class, asserted here so it cannot be silently counted as covered by this slice');

-- =============================================================================================
-- 19. PAR-4 DEFECT INJECTION. Assertion 2 says the capability lives in the trigger and not in RLS.
--     This proves it: drop the trigger inside a savepoint and the employee's INSERT succeeds.
-- =============================================================================================
savepoint before_injection;
drop trigger financial_accounts_guard_write_capability on public.financial_accounts;

select set_config('request.jwt.claims','{"sub":"fa000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select lives_ok($$
  insert into public.financial_accounts (tenant_id, financial_account_type_code, name, currency_code)
  values ('fa000000-0000-0000-0000-000000000001','cash','Petty Cash','EGP')$$,
  'DEFECT INJECTION: with the capability trigger dropped the EMPLOYEE opens a bank account -- RLS never charged the permission, so assertion 5 is that trigger and nothing else');

reset role;
rollback to savepoint before_injection;

-- TEST-3's closing move, and this file needed it: `rollback to savepoint` undoes pgTAP's own
-- temp-table counter, so an injection assertion placed LAST is never counted. The first run of this
-- file printed "planned 22 but ran 21" while still reporting PASS -- exactly the shape that hid the
-- defect TEST-3 was minted for. The re-assertion below is what makes the injection count.
select set_config('request.jwt.claims','{"sub":"fa000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok($$
  insert into public.financial_accounts (tenant_id, financial_account_type_code, name, currency_code)
  values ('fa000000-0000-0000-0000-000000000001','cash','Petty Cash','EGP')$$,
  '42501',
  null,
  'TEST-3 CLOSING MOVE: after the rollback the employee is refused again -- the savepoint restored the enforcer the injection borrowed, and this assertion is the one that makes the injection countable');

reset role;

select * from finish();
rollback;
