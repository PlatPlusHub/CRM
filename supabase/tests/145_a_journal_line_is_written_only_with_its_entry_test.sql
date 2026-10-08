-- pgTAP: Batch 6 slice 32 -- a journal line is written only with its entry, and a posted line
-- never changes.
--
-- ATTACK-CLASSES: DOOR BUSINESS STATE PRIVILEGE AUTH TENANT OBSERVABILITY INPUT=N/A REPLAY=N/A CONCURRENCY=N/A
--   INPUT=N/A -- the RPC's line rules and the per-row CHECKs are FIN-8's and JE-1's, pinned by `70_...`
--     and `89_...`; this file asks who may write a line at all.
--   REPLAY=N/A -- a journal entry has no idempotency key; each posting is a new entry by design.
--   CONCURRENCY=N/A -- pgTAP runs one session. The two-session proof that two transactions emptying
--     one entry from two sides cannot both commit is recorded in the Change Request.
--
-- Canon 07: a correction after approval is a new event, adjustment or reversal, and the register's
-- closure of `journal_entries`' void columns applies it to the ledger -- a POSTED double-entry record
-- is corrected by a compensating reversal, never by mutation. A journal entry has no draft state:
-- `app.create_journal_entry` writes it and all its lines in one call and records
-- `journal_entry_created` with the total.
--   JE-3: a CREATE_JOURNAL_ENTRY holder rewrote, re-parented, re-accounted and appended to posted
--         lines at the table, at aal1 as well as aal2, while the event kept the original total.
--   JE-4: the balance check judged only the entry a line moved TO, so an entry could be emptied.
--
-- THE FIXTURE. One tenant: its `finance_manager` posts through the RPC, an `employee` holds no ledger
-- permission. A second tenant's `finance_manager` attacks across the boundary.
create extension if not exists pgtap with schema extensions;

begin;
select plan(19);

insert into auth.users (id, email) values
  ('14500000-0000-0000-0000-0000000000a1','fin@j145.test'),
  ('14500000-0000-0000-0000-0000000000a2','emp@j145.test'),
  ('14500000-0000-0000-0000-0000000000a3','fin@j145b.test');
insert into public.tenants (id, name, slug, status) values
  ('14500000-0000-0000-0000-000000000001','J145 Travel','j145-travel','active'),
  ('14500000-0000-0000-0000-000000000002','J145 Rival','j145-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['14500000-0000-0000-0000-000000000001'::uuid,'14500000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('14500000-0000-0000-0000-000000000011','14500000-0000-0000-0000-000000000001','Fin','fin@j145.test',true,'14500000-0000-0000-0000-0000000000a1'),
  ('14500000-0000-0000-0000-000000000012','14500000-0000-0000-0000-000000000001','Emp','emp@j145.test',true,'14500000-0000-0000-0000-0000000000a2'),
  ('14500000-0000-0000-0000-000000000021','14500000-0000-0000-0000-000000000002','Rival fin','fin@j145b.test',true,'14500000-0000-0000-0000-0000000000a3');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('14500000-0000-0000-0000-000000000001'::uuid,'14500000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
             ('14500000-0000-0000-0000-000000000001','14500000-0000-0000-0000-000000000012','employee'),
             ('14500000-0000-0000-0000-000000000002','14500000-0000-0000-0000-000000000021','finance_manager')) v(t,u,rc)
join public.roles r on r.code = v.rc;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14500000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select app.seed_default_chart_of_accounts();
reset role;

create function pg_temp.acct(p_code text) returns uuid language sql as $$
  select id from public.chart_of_accounts where tenant_id = '14500000-0000-0000-0000-000000000001' and code = p_code $$;
create function pg_temp.e(p_n int) returns uuid language sql as $$ select current_setting('j145.e' || p_n)::uuid $$;
-- One line per row, ordered: amount, currency, account code.
create function pg_temp.lines(p_n int) returns text language sql as $$
  select string_agg(l.debit_amount::int || '/' || l.credit_amount::int || '/' || l.currency_code || '/' || ca.code, ','
                    order by l.debit_amount desc, l.credit_amount desc, ca.code)
    from public.journal_entry_lines l join public.chart_of_accounts ca on ca.id = l.chart_account_id
   where l.journal_entry_id = pg_temp.e(p_n) $$;

-- =============================================================================================
-- 1-3. THE DOOR, and the one writer behind it.
-- =============================================================================================
select ok(has_table_privilege('authenticated','public.journal_entry_lines','SELECT')
          and not has_table_privilege('authenticated','public.journal_entry_lines','INSERT')
          and not has_table_privilege('authenticated','public.journal_entry_lines','UPDATE')
          and not has_table_privilege('authenticated','public.journal_entry_lines','DELETE'),
  'DOOR: a signed-in user may read journal lines and holds no table door into them');

select is((select p.prosecdef::text || ' ' || coalesce(array_to_string(p.proconfig, ','), '-')
             || ' ' || has_function_privilege('authenticated', p.oid, 'EXECUTE')::text
             from pg_proc p where p.oid = 'app.create_journal_entry(text,date,text,jsonb,uuid)'::regprocedure),
  'true search_path="" true',
  'DOOR: the RPC is the one writer -- definer, empty search_path, callable by a signed-in user, so it needs no table grant');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14500000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($q$
  select set_config('j145.e1', app.create_journal_entry('manual_entry', current_date, 'E1',
    '[{"account_code":"1000","debit":1000,"currency":"EGP"},{"account_code":"4000","credit":1000,"currency":"EGP"}]'::jsonb)::text, true);
  select set_config('j145.e2', app.create_journal_entry('manual_entry', current_date, 'E2',
    '[{"account_code":"1000","debit":500,"currency":"EGP"},{"account_code":"4000","credit":500,"currency":"EGP"}]'::jsonb)::text, true);
  select set_config('j145.e4', app.create_journal_entry('manual_entry', current_date, 'E4',
    '[{"account_code":"1000","debit":100,"currency":"EGP"},{"account_code":"4000","credit":100,"currency":"EGP"},
      {"account_code":"5000","debit":50,"currency":"EGP"},{"account_code":"4100","credit":50,"currency":"EGP"}]'::jsonb)::text, true)$q$,
  'POSITIVE CONTROL: the finance manager posts three entries through the RPC');

-- =============================================================================================
-- 4-10. JE-3: a posted line is not rewritten, re-parented, re-accounted or appended to.
-- =============================================================================================
select ok(app.has_permission('CREATE_JOURNAL_ENTRY'),
  'PREMISE: the finance manager holds CREATE_JOURNAL_ENTRY at aal2, so each refusal below is the missing door');

select throws_ok($q$
  update public.journal_entry_lines
     set debit_amount = case when debit_amount > 0 then 7000 else 0 end,
         credit_amount = case when credit_amount > 0 then 7000 else 0 end,
         currency_code = 'USD', description = 'rewritten', created_at = '2001-01-01'
   where journal_entry_id = pg_temp.e(1)$q$,
  '42501', 'permission denied for table journal_entry_lines',
  'JE-3: a posted 1000/1000 entry cannot be rewritten to 7000/7000 in USD, backdated, even balanced');

select lives_ok($q$update public.chart_of_accounts set is_active = false
                  where tenant_id = '14500000-0000-0000-0000-000000000001' and code = '1100'$q$,
  'PREMISE: account 1100 is retired at its own door');
select throws_ok($q$update public.journal_entry_lines set chart_account_id = pg_temp.acct('1100')
                    where journal_entry_id = pg_temp.e(1) and debit_amount > 0$q$,
  '42501', 'permission denied for table journal_entry_lines',
  'JE-3: a posted line cannot be moved onto the retired account the RPC refuses (JE-1 on every door)');

select throws_ok($q$update public.journal_entry_lines set journal_entry_id = pg_temp.e(2)
                    where journal_entry_id = pg_temp.e(1)$q$,
  '42501', 'permission denied for table journal_entry_lines',
  'JE-3: posted lines cannot be moved to another entry');

select throws_ok($q$
  insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, debit_amount, credit_amount, currency_code)
  values ('14500000-0000-0000-0000-000000000001', pg_temp.e(1), pg_temp.acct('1000'), 5000, 0, 'EGP'),
         ('14500000-0000-0000-0000-000000000001', pg_temp.e(1), pg_temp.acct('4000'), 0, 5000, 'EGP')$q$,
  '42501', 'permission denied for table journal_entry_lines',
  'JE-3: a balanced pair cannot be appended to a posted entry -- one PostgREST request would hold both');

select is(pg_temp.lines(1) || ' | ' || pg_temp.lines(2) || ' | ' ||
          (select string_agg(e.payload ->> 'total_amount', ',' order by (e.payload ->> 'total_amount')::numeric)
             from public.events e
            where e.tenant_id = '14500000-0000-0000-0000-000000000001' and e.event_type_code = 'journal_entry_created'),
  '1000/0/EGP/1000,0/1000/EGP/4000 | 500/0/EGP/1000,0/500/EGP/4000 | 150,500,1000',
  'BUSINESS: every posted entry still says what its journal_entry_created event says it was');

-- =============================================================================================
-- 11-15. Step-up, privilege, tenant and JE-2: the RPC's authority is the only authority.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"14500000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
select throws_ok($q$select app.create_journal_entry('manual_entry', current_date, 'aal1',
    '[{"account_code":"1000","debit":1,"currency":"EGP"},{"account_code":"4000","credit":1,"currency":"EGP"}]'::jsonb)$q$,
  null, 'multi-factor authentication required for this role',
  'AUTH: without step-up the finance manager cannot post');
select throws_ok($q$update public.journal_entry_lines set debit_amount = case when debit_amount > 0 then 9 else 0 end,
                    credit_amount = case when credit_amount > 0 then 9 else 0 end where journal_entry_id = pg_temp.e(2)$q$,
  '42501', 'permission denied for table journal_entry_lines',
  'AUTH: ...and cannot rewrite a posted entry at the table instead (STEPUP-1''s journal_entry_lines member)');

select set_config('request.jwt.claims','{"sub":"14500000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select throws_ok($q$select app.create_journal_entry('manual_entry', current_date, 'employee',
    '[{"account_code":"1000","debit":1,"currency":"EGP"},{"account_code":"4000","credit":1,"currency":"EGP"}]'::jsonb)$q$,
  '42501', 'permission denied: CREATE_JOURNAL_ENTRY',
  'PRIVILEGE: an employee cannot post -- the definer RPC still charges the permission');

select set_config('request.jwt.claims','{"sub":"14500000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select is((select count(*)::int from public.journal_entry_lines), 0,
  'TENANT: another tenant''s finance manager reads none of this tenant''s lines');

-- JE-2 stays OPEN and is pinned as OPEN, not as desired behaviour: this fails when DC-11 decides
-- whether an entry is one currency or is translated to a base currency.
select set_config('request.jwt.claims','{"sub":"14500000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($q$select app.create_journal_entry('manual_entry', current_date, 'JE-2',
    '[{"account_code":"1000","debit":100,"currency":"USD"},{"account_code":"4000","credit":100,"currency":"EGP"}]'::jsonb)$q$,
  'JE-2 OPEN: a 100 USD debit still balances a 100 EGP credit through the RPC -- the accounting-model decision DC-11 owns');
reset role;
select set_config('request.jwt.claims','',true);

-- =============================================================================================
-- 16-19. JE-4: the balance check judges the entry a line left, for the platform too.
-- =============================================================================================
-- The RPC postings above left their entries' creation checks pending in this one transaction; fire
-- them now, so 16 is judged by the line trigger alone and not by E2's own creation check.
set constraints all immediate;
set constraints all deferred;

select throws_ok($q$do $x$ begin
    update public.journal_entry_lines set journal_entry_id = pg_temp.e(1) where journal_entry_id = pg_temp.e(2);
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514', null,
  'JE-4: even the platform cannot move every line out of an entry -- the entry it leaves is judged');

select lives_ok($q$do $x$ begin
    update public.journal_entry_lines set journal_entry_id = pg_temp.e(2)
     where journal_entry_id = pg_temp.e(4) and chart_account_id in (pg_temp.acct('5000'), pg_temp.acct('4100'));
    execute 'set constraints all immediate';
  end $x$$q$,
  'POSITIVE CONTROL: a move that leaves both entries balanced passes the same forced check -- the refusal above is the rule, not the harness');

select is(pg_temp.lines(2) || ' | ' || pg_temp.lines(4),
  '500/0/EGP/1000,50/0/EGP/5000,0/500/EGP/4000,0/50/EGP/4100 | 100/0/EGP/1000,0/100/EGP/4000',
  'STATE: the moved pair is on E2 and E4 keeps its other two lines');

select is((select count(*)::int from public.journal_entries je
            where je.tenant_id = '14500000-0000-0000-0000-000000000001'
              and (select count(*) from public.journal_entry_lines l where l.journal_entry_id = je.id) >= 2
              and (select sum(l.debit_amount) = sum(l.credit_amount) and sum(l.debit_amount) > 0
                     from public.journal_entry_lines l where l.journal_entry_id = je.id)),
  4,
  'OBSERVABILITY: every entry in the tenant has at least two lines and balances');

select * from finish();
rollback;
