-- pgTAP: Batch 6 slice 42 -- a used ledger account keeps its meaning.
--
-- ATTACK-CLASSES: AUTH TENANT DOOR BUSINESS INPUT PRIVILEGE CONCURRENCY OBSERVABILITY STATE=N/A REPLAY=N/A
--   STATE=N/A -- a chart account has no status machine; retiring it (`is_active`) is customization,
--     and the RPC's refusal of a retired account is JE-1's, pinned by `89_...` and `145_...`.
--   REPLAY=N/A -- a chart write has no effect to repeat; a second account with the same code is
--     INPUT's question and the (tenant, code) key's answer (assertion 11).
--   CONCURRENCY -- a posting in flight against a retype needs two live sessions, which pgTAP does
--     not have. The guard's row lock is proven by SPEC-278's two-session race, with and without it.
--
-- A chart account is what a journal line MEANS: the posting RPC resolves a line by the account's
-- code, and the account's type classifies the money posted to it. A posted entry is corrected by a
-- reversal, never by mutation (canon 07, 30; JE-3, JE-5). Canon 14 lets a company customize its
-- chart "according to permissions", and the seed RPC charges CREATE_JOURNAL_ENTRY with step-up.
--   COA-1: an aal1 finance manager retyped, recoded and replaced the code of a posted revenue account.
--   COA-2: every one of those writes was made at aal1, where the seed RPC refuses.
--
-- THE FIXTURE. One tenant: its `finance_manager` seeds and posts through the RPCs, an `employee` holds
-- no ledger permission. A second tenant's `finance_manager` looks across the boundary.
create extension if not exists pgtap with schema extensions;

begin;
select plan(25);

insert into auth.users (id, email) values
  ('15700000-0000-0000-0000-0000000000a1','fin@c157.test'),
  ('15700000-0000-0000-0000-0000000000a2','emp@c157.test'),
  ('15700000-0000-0000-0000-0000000000a3','fin@c157b.test');
insert into public.tenants (id, name, slug, status) values
  ('15700000-0000-0000-0000-000000000001','C157 Travel','c157-travel','active'),
  ('15700000-0000-0000-0000-000000000002','C157 Rival','c157-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['15700000-0000-0000-0000-000000000001'::uuid,'15700000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('15700000-0000-0000-0000-000000000011','15700000-0000-0000-0000-000000000001','Fin','fin@c157.test',true,'15700000-0000-0000-0000-0000000000a1'),
  ('15700000-0000-0000-0000-000000000012','15700000-0000-0000-0000-000000000001','Emp','emp@c157.test',true,'15700000-0000-0000-0000-0000000000a2'),
  ('15700000-0000-0000-0000-000000000021','15700000-0000-0000-0000-000000000002','Rival fin','fin@c157b.test',true,'15700000-0000-0000-0000-0000000000a3');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('15700000-0000-0000-0000-000000000001'::uuid,'15700000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
             ('15700000-0000-0000-0000-000000000001','15700000-0000-0000-0000-000000000012','employee'),
             ('15700000-0000-0000-0000-000000000002','15700000-0000-0000-0000-000000000021','finance_manager')) v(t,u,rc)
join public.roles r on r.code = v.rc;

create function pg_temp.as_(sub text, aal text) returns text language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', sub, 'aal', aal)::text, true) $$;
create function pg_temp.acct(c text) returns uuid language sql as $$
  select id from public.chart_of_accounts where tenant_id = '15700000-0000-0000-0000-000000000001' and code = c $$;
-- What the posted entry means: each line's account code, type and amounts, as `postgres` reads them.
create function pg_temp.meaning() returns text language sql as $$
  select string_agg(c.code || '/' || c.account_type || '/' || l.debit_amount || '/' || l.credit_amount, ','
                    order by l.debit_amount desc)
    from public.journal_entry_lines l join public.chart_of_accounts c on c.id = l.chart_account_id
   where l.journal_entry_id = current_setting('c157.e')::uuid $$;

-- =============================================================================================
-- 1-3. THE DOOR, and the sanctioned writers behind it.
-- =============================================================================================
select ok(has_table_privilege('authenticated','public.chart_of_accounts','INSERT')
          and has_table_privilege('authenticated','public.chart_of_accounts','UPDATE')
          and not has_table_privilege('authenticated','public.chart_of_accounts','DELETE'),
  'DOOR: a signed-in user may insert and update chart accounts (canon 14 customization) and never delete one');

set local role authenticated;
select pg_temp.as_('15700000-0000-0000-0000-0000000000a1','aal2');
select is(app.seed_default_chart_of_accounts(), 10,
  'POSITIVE CONTROL: the finance manager at aal2 seeds the default chart through the RPC, past the guard');
select lives_ok($q$
  select set_config('c157.e', app.create_journal_entry('manual_entry', '2026-10-01', 'E1',
    '[{"account_code":"1000","debit":1000,"currency":"EGP"},{"account_code":"4000","credit":1000,"currency":"EGP"}]'::jsonb)::text, true)$q$,
  'POSITIVE CONTROL: a 1000 sale is posted to cash 1000 and revenue 4000');
reset role;
select set_config('c157.meaning', pg_temp.meaning(), true);

-- =============================================================================================
-- 4-11. COA-1 at aal2: what a posted line means does not move. Customization of it still does.
-- =============================================================================================
set local role authenticated;
select pg_temp.as_('15700000-0000-0000-0000-0000000000a1','aal2');
select throws_ok($q$update public.chart_of_accounts set account_type = 'expense' where id = pg_temp.acct('4000')$q$,
  '23514', 'chart account 4000: its code and type are fixed once a journal line is posted to it',
  'COA-1: the posted revenue account cannot be retyped, which would turn the posted sale into an expense');
select throws_ok($q$update public.chart_of_accounts set code = '4999' where id = pg_temp.acct('4000')$q$,
  '23514', 'chart account 4000: its code and type are fixed once a journal line is posted to it',
  'COA-1: ...nor recoded, which would free 4000 for another account to take the RPC''s next posting');
select throws_ok($q$update public.chart_of_accounts set code = '1999', account_type = 'expense', name = 'cash too'
                    where id = pg_temp.acct('1000')$q$,
  '23514', 'chart account 1000: its code and type are fixed once a journal line is posted to it',
  'COA-1: ...and the debit side is fixed the same way, even when the name changes in the same statement');
select lives_ok($q$update public.chart_of_accounts set name = 'Ticket Sales' where id = pg_temp.acct('4000')$q$,
  'CUSTOMIZATION: a used account is renamed -- nothing reads the name (canon 14)');
select lives_ok($q$update public.chart_of_accounts set code = '6500', account_type = 'asset' where id = pg_temp.acct('6000')$q$,
  'CUSTOMIZATION: an account no line was posted to is recoded and retyped freely');
select lives_ok($q$update public.chart_of_accounts set is_active = false where id = pg_temp.acct('1100')$q$,
  'CUSTOMIZATION: an account is retired (JE-1: "a normal thing for an agency to do")');
select lives_ok($q$update public.chart_of_accounts set parent_account_id = pg_temp.acct('1100') where id = pg_temp.acct('1000')$q$,
  'CUSTOMIZATION: a used account is re-parented -- nothing reads the hierarchy');
select throws_ok($q$insert into public.chart_of_accounts (tenant_id, code, name, account_type)
                    values ('15700000-0000-0000-0000-000000000001','1000','Second cash','asset')$q$,
  '23505', null, 'INPUT: a second account with a code the tenant already has is refused by the (tenant, code) key');

-- =============================================================================================
-- 12-15. COA-2: the door asks for the step-up the RPC asks for.
-- =============================================================================================
select pg_temp.as_('15700000-0000-0000-0000-0000000000a1','aal1');
select ok(app.has_permission('CREATE_JOURNAL_ENTRY') and not app.mfa_satisfied(),
  'PREMISE: at aal1 the permission is held and step-up is not -- the RLS policies never asked');
select throws_ok($q$select app.seed_default_chart_of_accounts()$q$,
  '42501', 'multi-factor authentication required for this role',
  'CONTROL: the seed RPC refuses at aal1');
select throws_ok($q$insert into public.chart_of_accounts (tenant_id, code, name, account_type)
                    values ('15700000-0000-0000-0000-000000000001','7000','aal1','expense')$q$,
  '42501', 'multi-factor authentication required for this role',
  'COA-2: ...and so does the door, for an insert');
select throws_ok($q$update public.chart_of_accounts set name = 'aal1 rename' where id = pg_temp.acct('3000')$q$,
  '42501', 'multi-factor authentication required for this role',
  'COA-2: ...and for an update of an unused account');

-- =============================================================================================
-- 16-18. AUTH and TENANT. The employee never held the permission; the rival is another agency.
-- =============================================================================================
select pg_temp.as_('15700000-0000-0000-0000-0000000000a2','aal2');
select throws_ok($q$insert into public.chart_of_accounts (tenant_id, code, name, account_type)
                    values ('15700000-0000-0000-0000-000000000001','7100','emp','asset')$q$,
  '42501', null, 'AUTH: an employee cannot add an account');
select pg_temp.as_('15700000-0000-0000-0000-0000000000a3','aal2');
select is((select count(*)::int from public.chart_of_accounts where tenant_id = '15700000-0000-0000-0000-000000000001'), 0,
  'TENANT: the rival finance manager reads none of this chart');
select throws_ok($q$insert into public.chart_of_accounts (tenant_id, code, name, account_type)
                    values ('15700000-0000-0000-0000-000000000001','7200','rival','asset')$q$,
  '42501', null, 'TENANT: ...and cannot add an account to it');
reset role;
select set_config('request.jwt.claims', '', true);

-- =============================================================================================
-- 19-20. PRIVILEGE: a session-less caller keeps the platform path, never the integrity exemption.
-- =============================================================================================
select throws_ok($q$update public.chart_of_accounts set account_type = 'equity' where id = pg_temp.acct('4000')$q$,
  '23514', 'chart account 4000: its code and type are fixed once a journal line is posted to it',
  'PRIVILEGE: a session-less caller cannot retype a posted account either -- integrity, not authorization');
select lives_ok($q$insert into public.chart_of_accounts (tenant_id, code, name, account_type)
                   values ('15700000-0000-0000-0000-000000000001','7300','Platform','liability')$q$,
  'PRIVILEGE: ...and adds an account without a session (canon 35 principle 6)');

-- =============================================================================================
-- 21-22. DEFECT INJECTION (PAR-4), re-asserted after the rollback (TEST-3).
-- =============================================================================================
savepoint inject;
drop trigger chart_of_accounts_guard on public.chart_of_accounts;
set local role authenticated;
select pg_temp.as_('15700000-0000-0000-0000-0000000000a1','aal1');
select lives_ok($q$update public.chart_of_accounts set account_type = 'expense' where id = pg_temp.acct('4000')$q$,
  'INJECTION: without the guard, the aal1 retype of the posted account lands -- the refusals above are the guard''s');
reset role;
rollback to savepoint inject;
set local role authenticated;
select pg_temp.as_('15700000-0000-0000-0000-0000000000a1','aal2');
select throws_ok($q$update public.chart_of_accounts set account_type = 'expense' where id = pg_temp.acct('4000')$q$,
  '23514', 'chart account 4000: its code and type are fixed once a journal line is posted to it',
  'INJECTION: with the guard restored, the same retype is refused again');
reset role;
select set_config('request.jwt.claims', '', true);

-- =============================================================================================
-- 23-25. NON-MUTATION, the event's account, and the guard's privilege.
-- =============================================================================================
select is(pg_temp.meaning(), current_setting('c157.meaning'),
  'BUSINESS: the posted entry still means what it meant -- cash debited, revenue credited, 1000 each');
select is((select string_agg(e.event_type_code || '|' || (e.payload ->> 'total_amount') || '|' || e.actor_user_id, ';')
             from public.events e where e.entity_id = current_setting('c157.e')::uuid),
  'journal_entry_created|1000|15700000-0000-0000-0000-000000000011',
  'OBSERVABILITY: the one event still agrees with the ledger it describes');
select ok(not has_function_privilege('authenticated','app.guard_chart_account()','EXECUTE')
          and not has_function_privilege('anon','app.guard_chart_account()','EXECUTE'),
  'PRIVILEGE: neither authenticated nor anon may execute app.guard_chart_account');

select * from finish();
rollback;
