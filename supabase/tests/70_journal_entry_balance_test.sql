-- pgTAP: FIN-8 -- a ledger entry that does not balance is not a ledger entry.
--
-- The defect, reproduced before the fix, as a `finance_manager` holding the very permission the RPC
-- charges: `app.create_journal_entry` refused an unbalanced entry, and a direct INSERT of ONE line
-- carrying a 1,000,000 debit and no credit at all succeeded in the same transaction, emitting no
-- event. `journal_entry_lines_debit_xor_credit_check` is a PER-ROW constraint -- it proves each line
-- is a debit or a credit and can say nothing about whether the ENTRY balances, because that is a
-- statement about a SET of rows and a CHECK cannot express it.
--
-- ON `set constraints all immediate` BELOW. The invariant is only true BETWEEN statements, so the
-- triggers are `deferrable initially deferred` and fire at COMMIT. A pgTAP file never commits, so a
-- deferred check would never run here and every denial below would pass vacuously. Each negative is
-- therefore wrapped in a DO block that forces the check at a point the test can observe. That is
-- also why assertion 13 exists: it proves the forcing mechanism can still PASS, so the refusals are
-- the constraint working rather than the harness always raising.
create extension if not exists pgtap with schema extensions;

begin;
select plan(17);

insert into auth.users (id, email) values
  ('70000000-0000-0000-0000-0000000000a1','fin@ledger.test'),
  ('70000000-0000-0000-0000-0000000000a2','emp@ledger.test'),
  ('70000000-0000-0000-0000-0000000000a3','other@ledger.test');
insert into public.tenants (id, name, slug, status) values
  ('70000000-0000-0000-0000-000000000001','Ledger Travel','ledger-travel','active'),
  ('70000000-0000-0000-0000-000000000002','Rival Travel','ledger-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise' and t.id in ('70000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000002');
insert into public.branches (id, tenant_id, name, slug) values
  ('70000000-0000-0000-0000-00000000000a','70000000-0000-0000-0000-000000000001','Cairo','ledger-cairo'),
  ('70000000-0000-0000-0000-00000000000b','70000000-0000-0000-0000-000000000002','Giza','ledger-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('70000000-0000-0000-0000-0000000000c1','70000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-00000000000a','finance','Finance'),
  ('70000000-0000-0000-0000-0000000000c2','70000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-00000000000b','finance','Finance');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('70000000-0000-0000-0000-000000000011','70000000-0000-0000-0000-000000000001','Fin','fin@ledger.test',true,'70000000-0000-0000-0000-0000000000a1'),
  ('70000000-0000-0000-0000-000000000012','70000000-0000-0000-0000-000000000001','Emp','emp@ledger.test',true,'70000000-0000-0000-0000-0000000000a2'),
  ('70000000-0000-0000-0000-000000000013','70000000-0000-0000-0000-000000000002','Other Fin','other@ledger.test',true,'70000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('70000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000011','70000000-0000-0000-0000-00000000000a','70000000-0000-0000-0000-0000000000c1',true),
  ('70000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-000000000012','70000000-0000-0000-0000-00000000000a','70000000-0000-0000-0000-0000000000c1',true),
  ('70000000-0000-0000-0000-000000000002','70000000-0000-0000-0000-000000000013','70000000-0000-0000-0000-00000000000b','70000000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant' from (values
  ('70000000-0000-0000-0000-000000000001'::uuid,'70000000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
  ('70000000-0000-0000-0000-000000000001'::uuid,'70000000-0000-0000-0000-000000000012'::uuid,'employee'),
  ('70000000-0000-0000-0000-000000000002'::uuid,'70000000-0000-0000-0000-000000000013'::uuid,'finance_manager')) v(t,u,rc)
join public.roles r on r.code = v.rc;

-- =============================================================================================
-- 1-3. STRUCTURE, including the design decision that differs from the guards beside it.
-- =============================================================================================
select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where t.tgname in ('journal_entries_must_balance','journal_entry_lines_must_balance')
      and not t.tgisinternal and t.tgconstraint <> 0 and t.tgdeferrable and t.tginitdeferred),
  2,
  'both balance triggers exist as DEFERRED CONSTRAINT triggers -- the invariant is only true between statements');

select ok(
  (select count(*) from pg_trigger where tgname = 'journal_entry_lines_must_balance'
     and (tgtype & 4) <> 0 and (tgtype & 16) <> 0 and (tgtype & 8) <> 0) = 1,
  '...and the lines trigger covers INSERT, UPDATE and DELETE -- an entry can be unbalanced by removing a line, not only by adding one');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'enforce_journal_entry_balanced'
      and p.prosrc ~ 'auth\.uid\(\)'),
  0,
  'DELIBERATE: no session-less exemption -- this is data integrity, not authorization, so the platform does not escape it either (unlike enforce_status_transition)');

-- =============================================================================================
-- 4-6. AUTHORIZATION. Unchanged by this package, and proven so rather than assumed.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"70000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select ok(not app.has_permission('CREATE_JOURNAL_ENTRY'),
  'POSITIVE CONTROL: the ordinary employee does NOT hold CREATE_JOURNAL_ENTRY');

select throws_ok(
  $q$insert into public.journal_entries (tenant_id, source_type_code, entry_date)
     values ('70000000-0000-0000-0000-000000000001','manual_entry', current_date)$q$,
  '42501', null,
  'and is still refused the ledger by direct DML -- FIN-3''s guard is untouched by this package');

reset role;
select set_config('request.jwt.claims','{"sub":"70000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('CREATE_JOURNAL_ENTRY'),
  'POSITIVE CONTROL: the finance manager DOES hold it -- so every refusal below is the invariant, not the permission');

-- =============================================================================================
-- 7-9. THE RPC still enforces what it always did.
-- =============================================================================================
select lives_ok(
  $q$select app.seed_default_chart_of_accounts()$q$,
  'the tenant has a chart of accounts -- the fixture is real');

select isnt(
  (select app.create_journal_entry('manual_entry', current_date, 'balanced',
     '[{"account_code":"1000","debit":1000,"currency":"EGP"},{"account_code":"4000","credit":1000,"currency":"EGP"}]'::jsonb)),
  null,
  'THE ONE THAT MATTERS: a balanced entry through the RPC still succeeds -- a guard that blocked this too would pass every refusal below while closing the ledger');

select throws_ok(
  $q$select app.create_journal_entry('manual_entry', current_date, 'bad',
     '[{"account_code":"1000","debit":1000,"currency":"EGP"},{"account_code":"4000","credit":1,"currency":"EGP"}]'::jsonb)$q$,
  null, null,
  'the RPC still refuses an unbalanced entry, exactly as before');

-- =============================================================================================
-- 10-13. THE REPRODUCTION, on the direct path, in all four shapes it can take.
-- =============================================================================================
select throws_ok(
  $q$do $x$
     begin
       insert into public.journal_entries (id, tenant_id, source_type_code, entry_date)
       values ('70000000-0000-0000-0000-0000000000e1','70000000-0000-0000-0000-000000000001','manual_entry', current_date);
       insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, debit_amount, credit_amount, currency_code)
       select '70000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-0000000000e1', id, 1000000, 0, 'EGP'
       from public.chart_of_accounts where tenant_id = '70000000-0000-0000-0000-000000000001' and code = '1000';
       execute 'set constraints all immediate';
     end $x$$q$,
  '23514', null,
  'REPRODUCTION CLOSED: the original probe -- ONE line, 1,000,000 debit, no credit -- is now refused on the direct path');

select throws_ok(
  $q$do $x$
     begin
       insert into public.journal_entries (id, tenant_id, source_type_code, entry_date)
       values ('70000000-0000-0000-0000-0000000000e2','70000000-0000-0000-0000-000000000001','manual_entry', current_date);
       insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, debit_amount, credit_amount, currency_code)
       select '70000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-0000000000e2', id, 1000, 0, 'EGP'
       from public.chart_of_accounts where tenant_id = '70000000-0000-0000-0000-000000000001' and code = '1000';
       insert into public.journal_entry_lines (tenant_id, journal_entry_id, chart_account_id, debit_amount, credit_amount, currency_code)
       select '70000000-0000-0000-0000-000000000001','70000000-0000-0000-0000-0000000000e2', id, 0, 1, 'EGP'
       from public.chart_of_accounts where tenant_id = '70000000-0000-0000-0000-000000000001' and code = '4000';
       execute 'set constraints all immediate';
     end $x$$q$,
  '23514', null,
  'TWO lines and still unbalanced is refused too -- the line-count rule and the balance rule are separate, and this proves the second one fires');

select throws_ok(
  $q$do $x$
     begin
       insert into public.journal_entries (id, tenant_id, source_type_code, entry_date)
       values ('70000000-0000-0000-0000-0000000000e3','70000000-0000-0000-0000-000000000001','manual_entry', current_date);
       execute 'set constraints all immediate';
     end $x$$q$,
  '23514', null,
  'an entry with NO lines at all is refused -- invisible to a trigger on the lines, which is why both tables carry one');

select throws_ok(
  $q$do $x$
     declare v_e uuid;
     begin
       select je.id into v_e from public.journal_entries je
        where je.tenant_id = '70000000-0000-0000-0000-000000000001' and je.description = 'balanced';
       update public.journal_entry_lines set debit_amount = 999
        where journal_entry_id = v_e and debit_amount > 0;
       execute 'set constraints all immediate';
     end $x$$q$,
  '23514', null,
  'and an ALREADY VALID entry cannot be unbalanced by a later UPDATE -- the path a per-row CHECK could never have covered');

-- =============================================================================================
-- 14. The forcing mechanism can PASS. Without this, every refusal above could be the harness.
-- =============================================================================================
select lives_ok(
  $q$do $x$
     declare v_e uuid;
     begin
       select je.id into v_e from public.journal_entries je
        where je.tenant_id = '70000000-0000-0000-0000-000000000001' and je.description = 'balanced';
       update public.journal_entry_lines set debit_amount = 700 where journal_entry_id = v_e and debit_amount > 0;
       update public.journal_entry_lines set credit_amount = 700 where journal_entry_id = v_e and credit_amount > 0;
       execute 'set constraints all immediate';
     end $x$$q$,
  'NOT A VACUOUS HARNESS: a BALANCED correction (1000/1000 -> 700/700) passes the same forced check -- so the refusals above are the constraint, not the mechanism');

-- =============================================================================================
-- 15-16. SIDE EFFECTS and TENANT ISOLATION.
-- =============================================================================================
select is(
  (select count(*)::int from public.events
    where tenant_id = '70000000-0000-0000-0000-000000000001' and event_type_code = 'journal_entry_created'),
  1,
  'the RPC path emitted exactly one journal_entry_created event -- the audit spine saw the entry');

reset role;
select set_config('request.jwt.claims','{"sub":"70000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.journal_entries
    where tenant_id = '70000000-0000-0000-0000-000000000001'),
  0,
  'TENANT ISOLATION: the rival agency''s finance manager -- who holds CREATE_JOURNAL_ENTRY -- sees none of this ledger');

-- =============================================================================================
-- 17. The class, so the next money table cannot quietly arrive without this.
-- =============================================================================================
reset role;
select is(
  (select count(*)::int from pg_class c
    where c.relname = 'journal_entry_lines'
      and not exists (select 1 from pg_trigger t
                       where t.tgrelid = c.oid and t.tgconstraint <> 0 and not t.tgisinternal)),
  0,
  'journal_entry_lines carries at least one CONSTRAINT trigger -- pinned so the ledger cannot lose its set-level invariant silently');

select finish();
rollback;
