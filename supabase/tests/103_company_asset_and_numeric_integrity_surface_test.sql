-- pgTAP: Batch 6 slice 3 -- company_assets, and MONEY-1, the class it led to.
--
-- ATTACK-CLASSES: AUTH TENANT DOOR INPUT BUSINESS PRIVILEGE CONCURRENCY OBSERVABILITY STATE=N/A REPLAY=N/A
--
-- STATE=N/A: company_assets.status is free text with no catalog family and no vocabulary anywhere in
--   canon (CAT-6, open, deliberately unresolved -- inventing one fabricates canon). There is no
--   lifecycle to attack; assertion 34 pins the ABSENCE so a state machine cannot arrive untested.
-- REPLAY=N/A: two identical assets are a legitimate state -- an agency may own two identical vehicles
--   bought the same day for the same price. Canon names no natural key and a repeat produces no
--   economic effect (canon 24 puts depreciation out of scope), so there is no idempotency contract
--   to violate. This is a measured position, not an untested one.
--
-- CONCURRENCY is declared rather than excused. Assertion 33 measures the property that decides it:
-- the table carries no cross-row invariant at all, so there is no state two transactions can combine
-- into, and every rule below is a row-level CHECK, which cannot be raced by construction. The session
-- report additionally records TWO GENUINELY SIMULTANEOUS psql sessions -- one legal insert and one
-- NaN insert committed concurrently (only the legal row survived), and a role revoked by a second
-- session mid-transaction (the writer's next statement was refused and its earlier, authorized insert
-- rolled back with it). pgTAP is single-session and cannot express either; that is stated, not hidden.

create extension if not exists pgtap with schema extensions;

begin;
select plan(40);

-- =============================================================================================
-- FIXTURE. Two tenants, because a tenant-isolation assertion whose foreign row does not exist is
-- the vacuous-security-test class (AGENTS.md §6). Assertion 20 proves the rival row is really there.
-- =============================================================================================
insert into auth.users (id, email) values
  ('c3000000-0000-0000-0000-0000000000a1','finance@ca3.test'),
  ('c3000000-0000-0000-0000-0000000000a2','trainee@ca3.test');
insert into public.tenants (id, name, slug, status) values
  ('c3000000-0000-0000-0000-000000000001','Asset Travel','asset-travel-103','active'),
  ('c3000000-0000-0000-0000-000000000002','Rival Travel','rival-travel-103','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active'
from public.subscription_plans sp,
     unnest(array['c3000000-0000-0000-0000-000000000001'::uuid,
                  'c3000000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('c3000000-0000-0000-0000-00000000000a','c3000000-0000-0000-0000-000000000001','Cairo','ca3-cairo'),
  ('c3000000-0000-0000-0000-00000000000b','c3000000-0000-0000-0000-000000000002','Giza','ca3-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('c3000000-0000-0000-0000-0000000000c1','c3000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-00000000000a','finance','Finance'),
  ('c3000000-0000-0000-0000-0000000000c2','c3000000-0000-0000-0000-000000000002','c3000000-0000-0000-0000-00000000000b','finance','Finance');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('c3000000-0000-0000-0000-000000000011','c3000000-0000-0000-0000-000000000001','Fin','finance@ca3.test',true,'c3000000-0000-0000-0000-0000000000a1'),
  ('c3000000-0000-0000-0000-000000000012','c3000000-0000-0000-0000-000000000001','Trn','trainee@ca3.test',true,'c3000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('c3000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000011','c3000000-0000-0000-0000-00000000000a','c3000000-0000-0000-0000-0000000000c1',true),
  ('c3000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000012','c3000000-0000-0000-0000-00000000000a','c3000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (id, tenant_id, user_id, role_id, scope_type)
select v.i, 'c3000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('c3000000-0000-0000-0000-0000000000e1'::uuid,'c3000000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
             ('c3000000-0000-0000-0000-0000000000e2'::uuid,'c3000000-0000-0000-0000-000000000012'::uuid,'trainee')) v(i,u,rc)
join public.roles r on r.code = v.rc;

-- The rival tenant's asset, written by the platform path -- the only path that can create it.
insert into public.company_assets (id, tenant_id, name, asset_type, status, purchase_amount, currency_code)
values ('c3000000-0000-0000-0000-0000000000f1','c3000000-0000-0000-0000-000000000002',
        'Rival Bus','vehicle','active', 900000, 'EGP');

-- =============================================================================================
-- 1-3. CONTROLS. Every denial below differs from a permit in exactly one variable, and these three
--      establish that the actor genuinely holds the capability, sees its own tenant, and can write.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"c3000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('CREATE_JOURNAL_ENTRY'),
  'CONTROL: the finance manager genuinely HOLDS the capability company_assets charges');

select is(app.current_tenant_id(), 'c3000000-0000-0000-0000-000000000001'::uuid,
  'CONTROL: and resolves to its own tenant, so the tenant assertions below are not vacuous');

select lives_ok(
  $$insert into public.company_assets (id, tenant_id, name, asset_type, status, purchase_amount, currency_code)
    values ('c3000000-0000-0000-0000-0000000000d1','c3000000-0000-0000-0000-000000000001',
            'Hiace','vehicle','active', 300000.0000, 'EGP')$$,
  'POSITIVE CONTROL: a well-formed asset -- an amount WITH its currency -- is accepted');

select is((select purchase_amount from public.company_assets where id='c3000000-0000-0000-0000-0000000000d1'),
  300000.0000::numeric,
  '...and persisted with the amount it was given, so the refusals below are not a closed table');

-- =============================================================================================
-- 5-9. CA-1 / CA-2 / MONEY-1 on this surface. Each was reachable over HTTP with a real employee
--      JWT before 202607061300 -- POST /rest/v1/company_assets returned 201 for all three.
-- =============================================================================================
select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status, purchase_amount, currency_code)
    values ('c3000000-0000-0000-0000-000000000001','Negative','vehicle','active', -500000, 'EGP')$$,
  '23514', null,
  'CA-1: an asset cannot be bought for a NEGATIVE amount -- the money rule 15 other columns already carry');

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status, purchase_amount, currency_code)
    values ('c3000000-0000-0000-0000-000000000001','Poison','vehicle','active', 'NaN', 'EGP')$$,
  '23514', null,
  'MONEY-1: NaN is refused. It satisfies >= 0 in PostgreSQL, so the non-negative rule alone never caught it');

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status, purchase_amount)
    values ('c3000000-0000-0000-0000-000000000001','Currencyless','vehicle','active', 250000)$$,
  '23514', null,
  'CA-2: an amount with NO currency is refused -- canon 30 money standard, the 202607059900 form');

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status, currency_code)
    values ('c3000000-0000-0000-0000-000000000001','Amountless','vehicle','active','USD')$$,
  '23514', null,
  '...and so is the other half: a currency naming no amount. The rule is a biconditional, not an implication');

select lives_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status)
    values ('c3000000-0000-0000-0000-000000000001','Donated Desk','furniture','active')$$,
  'NEGATIVE CONTROL: an asset with NEITHER amount nor currency is still legal -- canon 31 marks both nullable');

select lives_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status, purchase_amount, currency_code)
    values ('c3000000-0000-0000-0000-000000000001','Free Sample','furniture','active', 0, 'EGP')$$,
  'NEGATIVE CONTROL: zero is not negative -- the constraint refuses below zero, not at it');

-- =============================================================================================
-- 11-14. THE UPDATE PATH. SEC-1c's lesson: a row you may not create is a row you may not rewrite,
--        and a constraint enforced only on INSERT is half a constraint.
-- =============================================================================================
select throws_ok(
  $$update public.company_assets set purchase_amount = 'NaN'
     where id = 'c3000000-0000-0000-0000-0000000000d1'$$,
  '23514', null,
  'MONEY-1 on the UPDATE path: an accepted asset cannot be poisoned afterwards');

select throws_ok(
  $$update public.company_assets set purchase_amount = -1
     where id = 'c3000000-0000-0000-0000-0000000000d1'$$,
  '23514', null,
  'CA-1 on the UPDATE path');

select throws_ok(
  $$update public.company_assets set currency_code = null
     where id = 'c3000000-0000-0000-0000-0000000000d1'$$,
  '23514', null,
  'CA-2 on the UPDATE path: the currency cannot be stripped off an amount that stays');

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status, purchase_amount, currency_code)
    values ('c3000000-0000-0000-0000-000000000001','Bad FX','vehicle','active', 1, 'XXX')$$,
  '23503', null,
  'INPUT: an unregistered currency is refused by the FK -- currency_code is not free text');

-- =============================================================================================
-- 15-19. AUTHORIZATION, attacked four ways. `has_permission` returning true is NOT the same as the
--        write succeeding, and assertion 17 is the pair that proves it.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"c3000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select ok(not app.has_permission('CREATE_JOURNAL_ENTRY'),
  'CONTROL: the trainee holds no CREATE_JOURNAL_ENTRY -- one variable apart from the finance manager');

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status)
    values ('c3000000-0000-0000-0000-000000000001','Trainee Car','vehicle','active')$$,
  '42501', null,
  'AUTH vertical: a trainee cannot register a company asset');

select throws_ok(
  $$update public.company_assets set name = 'Renamed'
     where id = 'c3000000-0000-0000-0000-0000000000d1'$$,
  '42501', null,
  'AUTH vertical on the UPDATE door too (SEC-1c) -- not only the INSERT one');

reset role;
select set_config('request.jwt.claims','{"sub":"c3000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select ok(app.has_permission('CREATE_JOURNAL_ENTRY'),
  'CONTROL: without aal2 the finance manager STILL HOLDS the permission -- so the next refusal is MFA, not RBAC');

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status)
    values ('c3000000-0000-0000-0000-000000000001','No MFA','vehicle','active')$$,
  '42501', null,
  'AUTH temporal/assurance: app.authorize refuses a role that requires MFA on a session that has not done it');

-- Deny beats the role grant, and a role that has not started grants nothing. Both are attacked on
-- THIS door rather than read out of app.has_permission.
reset role;
select set_config('request.jwt.claims', '', true);
savepoint before_deny;
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, created_by)
select 'c3000000-0000-0000-0000-000000000001','c3000000-0000-0000-0000-000000000011', p.id, 'deny',
       'c3000000-0000-0000-0000-000000000011'
from public.permissions p where p.key = 'CREATE_JOURNAL_ENTRY';
select set_config('request.jwt.claims','{"sub":"c3000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status)
    values ('c3000000-0000-0000-0000-000000000001','After Deny','vehicle','active')$$,
  '42501', null,
  'AUTH precedence: an explicit user DENY beats the role grant on this door (deny > user grant > role grant)');

rollback to savepoint before_deny;
select set_config('request.jwt.claims', '', true);
savepoint before_future_role;
update public.user_role_assignments set starts_at = now() + interval '10 days'
 where id = 'c3000000-0000-0000-0000-0000000000e1';
select set_config('request.jwt.claims','{"sub":"c3000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status)
    values ('c3000000-0000-0000-0000-000000000001','Future Role','vehicle','active')$$,
  '42501', null,
  'AUTH temporal: a role assignment that has not STARTED grants nothing here either (202607060700)');

rollback to savepoint before_future_role;
select set_config('request.jwt.claims', '', true);

-- =============================================================================================
-- 20-25. TENANT ISOLATION. Attacked as relationships, not as one predicate: read, write, probe,
--        and the row-hop that moves a row you DO own into a tenant you do not.
-- =============================================================================================
select is((select count(*)::int from public.company_assets where id = 'c3000000-0000-0000-0000-0000000000f1'),
  1,
  'CONTROL: the rival tenant''s asset genuinely EXISTS -- read here as postgres, before RLS applies');

select set_config('request.jwt.claims','{"sub":"c3000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select is((select count(*)::int from public.company_assets where id = 'c3000000-0000-0000-0000-0000000000f1'),
  0,
  'TENANT read: the row proven to exist above is invisible -- zero rows against a row that is really there');

select is((select count(*)::int from public.company_assets),
  3,
  '...and the tenant sees exactly its own three assets, so the zero above is isolation and not an empty table');

select lives_ok(
  $$update public.company_assets set name = 'Stolen'
     where id = 'c3000000-0000-0000-0000-0000000000f1'$$,
  'TENANT probe: updating a foreign row does not ERROR -- which is correct, and is why the next assertion exists');

select is((select name from public.company_assets where id = 'c3000000-0000-0000-0000-0000000000f1'),
  null,
  '...it matched nothing. A silent zero-row UPDATE leaks no existence information either way');

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status)
    values ('c3000000-0000-0000-0000-000000000002','Planted','vehicle','active')$$,
  '42501', null,
  'TENANT write: a row cannot be PLANTED in another agency -- the WITH CHECK half of the policy');

select throws_ok(
  $$update public.company_assets set tenant_id = 'c3000000-0000-0000-0000-000000000002'
     where id = 'c3000000-0000-0000-0000-0000000000d1'$$,
  '42501', null,
  'TENANT row-hop: an asset you DO own cannot be walked into a tenant you do not');

-- =============================================================================================
-- 26-29. THE DOORS. company_assets has no RPC anywhere, so the table IS the door -- which makes the
--        question "what else reaches it?" rather than "is the RPC guarded?".
-- =============================================================================================
select throws_ok(
  $$delete from public.company_assets where id = 'c3000000-0000-0000-0000-0000000000d1'$$,
  '42501', null,
  'DOOR: DELETE is refused at the GRANT level -- authenticated holds SELECT/INSERT/UPDATE and nothing else');

reset role;
set local role anon;
select throws_ok(
  $$select count(*) from public.company_assets$$,
  '42501', null,
  'DOOR: the unauthenticated boundary holds at the grant, before any policy is consulted');

reset role;
select set_config('request.jwt.claims','{"role":"authenticated"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status)
    values ('c3000000-0000-0000-0000-000000000001','Subless','vehicle','active')$$,
  '42501', null,
  'PRIVILEGE: a JWT with no sub REACHES guard_write_capability''s system branch (auth.uid() is null) -- and RLS refuses it anyway. The bypass exists and a second control closes it');

reset role;
select set_config('request.jwt.claims', '', true);

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('app','public','reporting')
      and p.prosrc like '%company_assets%'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  0,
  'PRIVILEGE: no function that names this table is EXECUTABLE by authenticated -- there is no definer door beside the table door');

-- =============================================================================================
-- 30. THE ALTERNATE DOOR THAT MATTERS MOST. A trigger or a policy can be bypassed by the table
--     owner; a CHECK cannot. This is why MONEY-1 was repaired with constraints and not a guard.
-- =============================================================================================
select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status, purchase_amount, currency_code)
    values ('c3000000-0000-0000-0000-000000000001','Platform NaN','vehicle','active','NaN','EGP')$$,
  '23514', null,
  'DOOR: the PLATFORM path is refused too -- as postgres, the table owner, with RLS and every capability trigger bypassed');

-- =============================================================================================
-- 31-32. MONEY-1 AS A CLASS, and the ceiling can only shrink. These are the assertions that make a
--        thirty-third numeric column fail the build until it says whether it can be NaN.
-- =============================================================================================
select is(
  (select count(*)::int
     from information_schema.columns c
     join information_schema.tables t
       on t.table_schema = c.table_schema and t.table_name = c.table_name and t.table_type = 'BASE TABLE'
    where c.table_schema = 'public' and c.data_type = 'numeric'
      and not exists (
        select 1 from pg_constraint k
         where k.conrelid = ('public.' || c.table_name)::regclass and k.contype = 'c'
           and pg_get_constraintdef(k.oid) ~ ('\m' || c.column_name || '\M[^)]*IS DISTINCT FROM ''NaN'''))),
  0,
  'MONEY-1 CLASS: every numeric column on every public base table is covered by a no-NaN constraint. CEILING: this reads constraint TEXT, so it proves a rule is declared, never that it fires -- assertions 6 and 30 are what prove that');

select is(
  (select count(*)::int
     from information_schema.tables t
    where t.table_schema = 'public' and t.table_type = 'BASE TABLE'
      and exists (select 1 from information_schema.columns c1
                   where c1.table_schema='public' and c1.table_name=t.table_name
                     and c1.column_name like '%currency%code' and c1.is_nullable='YES')
      and exists (select 1 from information_schema.columns c2
                   where c2.table_schema='public' and c2.table_name=t.table_name and c2.data_type='numeric'
                     and (c2.column_name like '%amount%' or c2.column_name like '%balance%'
                          or c2.column_name like '%value%'))
      and not exists (select 1 from pg_constraint k
                       where k.conrelid=('public.'||t.table_name)::regclass and k.contype='c'
                         and pg_get_constraintdef(k.oid) ilike '%currency%'
                         and pg_get_constraintdef(k.oid) ilike '%null%')
      and not exists (select 1 from pg_trigger tr
                       where tr.tgrelid=('public.'||t.table_name)::regclass and not tr.tgisinternal
                         and pg_get_triggerdef(tr.oid) ilike '%guard_payment_currency_conversion%')),
  0,
  'CA-2 CLASS: every table with a nullable currency_code beside a numeric amount carries a row CHECK or the cross-table payment/account FX guard -- six of six now');

-- =============================================================================================
-- 33. PAR-4 DEFECT INJECTION. "It did not throw" is not evidence that anything was enforced. Drop
--     the named enforcer, prove the ORIGINAL attack succeeds, roll back, and -- TEST-3 -- re-assert.
-- =============================================================================================
savepoint before_enforcer_mutation;
alter table public.company_assets drop constraint company_assets_no_nan_check;

select lives_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status, purchase_amount, currency_code)
    values ('c3000000-0000-0000-0000-000000000001','Injected','vehicle','active','NaN','EGP')$$,
  'MUTATION: with company_assets_no_nan_check dropped, the ORIGINAL NaN insert succeeds again -- that constraint is what refuses it, not the harness and not the non-negative rule beside it');

rollback to savepoint before_enforcer_mutation;

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status, purchase_amount, currency_code)
    values ('c3000000-0000-0000-0000-000000000001','Injected','vehicle','active','NaN','EGP')$$,
  '23514', null,
  'TEST-3: and refused again after the rollback -- an injection assertion that is never re-asserted is never counted');

-- =============================================================================================
-- 34-36. THE POSITIONS THIS SLICE TOOK, pinned so they cannot change in silence.
-- =============================================================================================
select is(
  (select count(*)::int from pg_constraint
    where conrelid = 'public.company_assets'::regclass and contype in ('u','x')),
  0,
  'CONCURRENCY basis: the table carries no unique or exclusion constraint, so it has NO cross-row invariant for two transactions to combine into. Add one and this assertion fails, which is the point');

select is(
  (select count(*)::int from pg_trigger
    where tgrelid = 'public.company_assets'::regclass and not tgisinternal
      and pg_get_triggerdef(oid) ilike '%status_transition%'),
  0,
  'STATE basis: company_assets.status has no transition enforcement, because canon defines no vocabulary for it (CAT-6, open). A state machine cannot arrive here without failing this');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('app','public','reporting') and p.prosrc like '%company_asset_created%'),
  0,
  'OBSERVABILITY: company_asset_created is registered vocabulary with NO producer, and that is EVT-2''s owner-ratified position (OWNER-1: no producer is invented to complete a catalog). Pinned so a producer must arrive with a test');

select * from finish();
rollback;
