-- pgTAP: Batch 6 slice 33 -- a posted journal entry is never rewritten.
--
-- ATTACK-CLASSES: DOOR BUSINESS STATE PRIVILEGE AUTH TENANT OBSERVABILITY INPUT=N/A REPLAY=N/A CONCURRENCY=N/A
--   INPUT=N/A -- what the RPC accepts at creation is its own contract; this file asks who may change
--     a header after it is posted.
--   REPLAY=N/A -- a journal entry has no idempotency key; each posting is a new entry by design.
--   CONCURRENCY=N/A -- no signed-in operation changes a header, so there is no header invariant two
--     sessions could race; the line balance race is JE-4's, pinned by `145_...`.
--
-- Canon 07 and 30: a correction after approval is a new event, adjustment, reversal or new journal
-- entry. The register's `journal_entries` closure (VOID-1): a POSTED double-entry record is corrected
-- by a compensating reversal, never by mutation, and its void columns are never given a writer.
--   JE-5: a CREATE_JOURNAL_ENTRY holder, at aal1 as well, backdated, re-described, re-sourced and
--         voided a posted header at the table while its event kept the original truth.
--
-- Every refusal below is asserted AT THE STATEMENT. Nothing here runs `set constraints ... immediate`,
-- so no deferred balance check queued by the RPC can refuse in a rule's place.
--
-- THE FIXTURE. One tenant: its `finance_manager` posts through the RPC, an `employee` holds no ledger
-- permission. A second tenant's `finance_manager` looks across the boundary.
create extension if not exists pgtap with schema extensions;

begin;
select plan(17);

insert into auth.users (id, email) values
  ('14600000-0000-0000-0000-0000000000a1','fin@j146.test'),
  ('14600000-0000-0000-0000-0000000000a2','emp@j146.test'),
  ('14600000-0000-0000-0000-0000000000a3','fin@j146b.test');
insert into public.tenants (id, name, slug, status) values
  ('14600000-0000-0000-0000-000000000001','J146 Travel','j146-travel','active'),
  ('14600000-0000-0000-0000-000000000002','J146 Rival','j146-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['14600000-0000-0000-0000-000000000001'::uuid,'14600000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('14600000-0000-0000-0000-000000000011','14600000-0000-0000-0000-000000000001','Fin','fin@j146.test',true,'14600000-0000-0000-0000-0000000000a1'),
  ('14600000-0000-0000-0000-000000000012','14600000-0000-0000-0000-000000000001','Emp','emp@j146.test',true,'14600000-0000-0000-0000-0000000000a2'),
  ('14600000-0000-0000-0000-000000000021','14600000-0000-0000-0000-000000000002','Rival fin','fin@j146b.test',true,'14600000-0000-0000-0000-0000000000a3');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('14600000-0000-0000-0000-000000000001'::uuid,'14600000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
             ('14600000-0000-0000-0000-000000000001','14600000-0000-0000-0000-000000000012','employee'),
             ('14600000-0000-0000-0000-000000000002','14600000-0000-0000-0000-000000000021','finance_manager')) v(t,u,rc)
join public.roles r on r.code = v.rc;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14600000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select app.seed_default_chart_of_accounts();
reset role;

create function pg_temp.e() returns uuid language sql as $$ select current_setting('j146.e')::uuid $$;
-- The header as the RPC wrote it, and the event's account of it, in one comparable string each.
create function pg_temp.header() returns text language sql as $$
  select je.entry_date || '|' || coalesce(je.description, '-') || '|' || je.source_type_code || '|'
      || coalesce(je.source_entity_id::text, '-') || '|' || je.created_at || '|' || je.created_by || '|'
      || je.is_voided || '|' || coalesce(je.voided_at::text, '-') || '|' || coalesce(je.voided_by::text, '-') || '|'
      || coalesce(je.void_reason, '-')
    from public.journal_entries je where je.id = pg_temp.e() $$;
create function pg_temp.lines() returns text language sql as $$
  select string_agg(l.chart_account_id || '/' || l.debit_amount || '/' || l.credit_amount || '/' || l.currency_code, ','
                    order by l.debit_amount desc, l.credit_amount desc)
    from public.journal_entry_lines l where l.journal_entry_id = pg_temp.e() $$;

-- =============================================================================================
-- 1-2. THE DOOR, and the one writer behind it. Column-aware: a column grant reaches a column with no table grant at all.
-- =============================================================================================
select ok(has_table_privilege('authenticated','public.journal_entries','SELECT')
          and not has_any_column_privilege('authenticated','public.journal_entries','INSERT')
          and not has_any_column_privilege('authenticated','public.journal_entries','UPDATE')
          and not has_table_privilege('authenticated','public.journal_entries','DELETE'),
  'DOOR: a signed-in user may read journal entries and holds no table or column door into them');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14600000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($q$
  select set_config('j146.e', app.create_journal_entry('manual_entry', '2026-10-01', 'E1',
    '[{"account_code":"1000","debit":1000,"currency":"EGP"},{"account_code":"4000","credit":1000,"currency":"EGP"}]'::jsonb)::text, true)$q$,
  'POSITIVE CONTROL: the finance manager posts an entry through the RPC, which needs no table grant');
reset role;
select set_config('j146.header', pg_temp.header(), true);
select set_config('j146.lines', pg_temp.lines(), true);

-- =============================================================================================
-- 3-9. JE-5 at aal2: no header field of a posted entry is rewritten, and none can be added alone.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14600000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select ok(app.has_permission('CREATE_JOURNAL_ENTRY') and app.mfa_satisfied(),
  'PREMISE: the finance manager holds CREATE_JOURNAL_ENTRY at aal2, so each refusal below is the missing door');

select throws_ok($q$update public.journal_entries set entry_date = '2001-01-01' where id = pg_temp.e()$q$,
  '42501', 'permission denied for table journal_entries',
  'JE-5: a posted entry cannot be backdated -- its date is the period it is booked in');
select throws_ok($q$update public.journal_entries set description = 'rewritten' where id = pg_temp.e()$q$,
  '42501', 'permission denied for table journal_entries',
  'JE-5: ...nor re-described while its event keeps the original narrative');
select throws_ok($q$update public.journal_entries set source_type_code = 'refund',
                      source_entity_id = '14600000-0000-0000-0000-00000000dead' where id = pg_temp.e()$q$,
  '42501', 'permission denied for table journal_entries',
  'JE-5: ...nor re-sourced to a refund that does not exist');
select throws_ok($q$update public.journal_entries set is_voided = true, voided_at = now(), void_reason = 'by hand',
                      voided_by = '14600000-0000-0000-0000-000000000012' where id = pg_temp.e()$q$,
  '42501', 'permission denied for table journal_entries',
  'JE-5: ...nor voided through the closed void columns, naming another user as the voider (VOID-1)');
select throws_ok($q$update public.journal_entries set created_at = '2001-01-01' where id = pg_temp.e()$q$,
  '42501', 'permission denied for table journal_entries',
  'JE-5: ...nor have its creation time rewritten');
select throws_ok($q$insert into public.journal_entries (tenant_id, source_type_code, entry_date, description)
                    values ('14600000-0000-0000-0000-000000000001','manual_entry','2026-10-01','bare header')$q$,
  '42501', 'permission denied for table journal_entries',
  'DOOR: a bare header is refused by authority at the statement, not left to the balance check at COMMIT');

-- =============================================================================================
-- 10-12. The same caller at aal1, where the RPC refuses for want of step-up.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"14600000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
select ok(app.has_permission('CREATE_JOURNAL_ENTRY') and not app.mfa_satisfied(),
  'PREMISE: at aal1 the permission is still held and step-up is not satisfied -- the RLS policies never asked');
select throws_ok($q$update public.journal_entries set entry_date = '2001-01-01', description = 'aal1' where id = pg_temp.e()$q$,
  '42501', 'permission denied for table journal_entries',
  'JE-5 / STEPUP-1: an aal1 session cannot rewrite the header the RPC would not let it post');
select throws_ok($q$insert into public.journal_entries (tenant_id, source_type_code, entry_date)
                    values ('14600000-0000-0000-0000-000000000001','manual_entry','2026-10-01')$q$,
  '42501', 'permission denied for table journal_entries',
  '...nor insert a header at aal1');

-- =============================================================================================
-- 13. The employee, who never held the permission.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"14600000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select throws_ok($q$update public.journal_entries set description = 'employee' where id = pg_temp.e()$q$,
  '42501', 'permission denied for table journal_entries',
  'an employee is refused at the door too');

-- =============================================================================================
-- 14-15. TENANT. The rival agency's finance manager holds the same permission.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"14600000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select is((select count(*)::int from public.journal_entries where tenant_id = '14600000-0000-0000-0000-000000000001'),
  0, 'TENANT: the rival finance manager reads none of this ledger');
select throws_ok($q$update public.journal_entries set description = 'rival' where id = pg_temp.e()$q$,
  '42501', 'permission denied for table journal_entries',
  'TENANT: ...and has no door to write it');
reset role;
select set_config('request.jwt.claims', '', true);

-- =============================================================================================
-- 16-17. NON-MUTATION and the event's account.
-- =============================================================================================
select ok(pg_temp.header() = current_setting('j146.header') and pg_temp.lines() = current_setting('j146.lines'),
  'NON-MUTATION: the header and its lines are byte-for-byte what the RPC wrote');

select is((select string_agg(e.event_type_code || '|' || e.new_state || '|' || e.reason || '|'
                             || (e.payload ->> 'total_amount') || '|' || e.actor_user_id, ';')
             from public.events e where e.entity_id = pg_temp.e()),
  'journal_entry_created|manual_entry|E1|1000|14600000-0000-0000-0000-000000000011',
  'OBSERVABILITY: the one event still agrees with the header -- the posting, its source, its narrative, its total, its actor');

select * from finish();
rollback;
