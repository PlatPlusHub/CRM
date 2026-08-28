-- pgTAP: TRANS-2 and SEC-1's last table -- the lead's handler rule, now on the direct path too.
--
-- The rule is not invented here. `app.advance_lead` (non-closure), `app.convert_lead` and
-- `app.record_lead_interaction` all state it verbatim:
--
--     the assigned handler, OR ASSIGN_LEAD, and MFA satisfied
--
-- `app.status_transitions` has only a `permission_key` column, which cannot express "the assigned
-- handler" -- so eight `leads` rows carried NULL, and `app.enforce_status_transition` read null as
-- "no check". Direct DML could therefore walk a COLLEAGUE'S lead from `contacted` to `won` and on to
-- `converted` while every RPC refused the same person.
--
-- Every denial below is paired with a permit on the SAME lead and the SAME transition, so the pair
-- differs in exactly one variable: who is acting.
create extension if not exists pgtap with schema extensions;

begin;
select plan(14);

insert into auth.users (id, email) values
  ('59000000-0000-0000-0000-0000000000a1','handler@lh.test'),
  ('59000000-0000-0000-0000-0000000000a2','colleague@lh.test'),
  ('59000000-0000-0000-0000-0000000000a3','manager@lh.test');
insert into public.tenants (id, name, slug, status) values
  ('59000000-0000-0000-0000-000000000001','LH Travel','lh-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '59000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('59000000-0000-0000-0000-00000000000a','59000000-0000-0000-0000-000000000001','Cairo','lh-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('59000000-0000-0000-0000-0000000000c1','59000000-0000-0000-0000-000000000001','59000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('59000000-0000-0000-0000-000000000011','59000000-0000-0000-0000-000000000001','Handler','handler@lh.test',true,'59000000-0000-0000-0000-0000000000a1'),
  ('59000000-0000-0000-0000-000000000012','59000000-0000-0000-0000-000000000001','Colleague','colleague@lh.test',true,'59000000-0000-0000-0000-0000000000a2'),
  ('59000000-0000-0000-0000-000000000013','59000000-0000-0000-0000-000000000001','Manager','manager@lh.test',true,'59000000-0000-0000-0000-0000000000a3');
-- All three in the SAME department: that is what makes the colleague able to SEE the lead, which is
-- what makes the denial below about authority rather than about reach.
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '59000000-0000-0000-0000-000000000001', u, '59000000-0000-0000-0000-00000000000a','59000000-0000-0000-0000-0000000000c1', true
from unnest(array['59000000-0000-0000-0000-000000000011'::uuid,'59000000-0000-0000-0000-000000000012'::uuid,'59000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '59000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('59000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('59000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('59000000-0000-0000-0000-000000000013'::uuid,'branch_manager')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('59000000-0000-0000-0000-0000000000d1','59000000-0000-0000-0000-000000000001','person','LH Customer','+201000000059');
-- Seeded unassigned, then assigned through `app.assign_lead` as the manager. Setting
-- `assigned_user_id` directly is refused by SPEC-148's coherence trigger -- "a lead assignee may not
-- change without a current lead_assignments row" -- which is correct, and which my first version of
-- this fixture tripped over. The status is then walked to `contacted` session-less, the platform
-- path the guard deliberately exempts.
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code,
                          title, lead_status_code)
values ('59000000-0000-0000-0000-0000000000e1','59000000-0000-0000-0000-000000000001',
        '59000000-0000-0000-0000-00000000000a','59000000-0000-0000-0000-0000000000c1',
        '59000000-0000-0000-0000-0000000000d1','direct_call','Handler lead','new');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"59000000-0000-0000-0000-0000000000a3"}', true);
select app.assign_lead('59000000-0000-0000-0000-0000000000e1','59000000-0000-0000-0000-000000000011','training');
reset role;
select set_config('request.jwt.claims', null, true);
update public.leads set lead_status_code = 'contacted' where id = '59000000-0000-0000-0000-0000000000e1';

-- =============================================================================================
-- 1-4. TRANS-2. The colleague can SEE the lead and could previously WALK it.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"59000000-0000-0000-0000-0000000000a2"}', true);

select is(
  (select count(*)::int from public.leads where id = '59000000-0000-0000-0000-0000000000e1'),
  1,
  'POSITIVE CONTROL: the colleague SEES the handler''s lead (department queue) -- the denial below is authority');

select throws_ok(
  $$update public.leads set lead_status_code = 'qualified'
     where id = '59000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'TRANS-2: a colleague can no longer walk someone else''s pipeline by direct DML');

select throws_ok(
  $$select app.advance_lead('59000000-0000-0000-0000-0000000000e1','qualified')$$,
  '42501', null,
  '...and the RPC refuses them too -- the two paths now agree, which is the whole point');

reset role;
select set_config('request.jwt.claims','{"sub":"59000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select lives_ok(
  $$update public.leads set lead_status_code = 'qualified'
     where id = '59000000-0000-0000-0000-0000000000e1'$$,
  'POSITIVE CONTROL: the HANDLER can, on the same lead and the same transition');

-- =============================================================================================
-- 5-7. ASSIGN_LEAD is the other half of the rule, and closure still costs CLOSE_LEAD.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"59000000-0000-0000-0000-0000000000a3"}', true);
set local role authenticated;

select ok(
  app.has_permission('ASSIGN_LEAD'),
  'CONTROL: the branch manager holds ASSIGN_LEAD');

select lives_ok(
  $$update public.leads set lead_status_code = 'quotation_sent'
     where id = '59000000-0000-0000-0000-0000000000e1'$$,
  '...and may therefore move a lead they do not personally handle');

-- Closure carries CLOSE_LEAD in `app.status_transitions`, so it takes the permission branch and not
-- the new fallback -- no path became stricter than the RPC that walks it.
reset role;
select set_config('request.jwt.claims','{"sub":"59000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select lives_ok(
  $$select app.advance_lead('59000000-0000-0000-0000-0000000000e1','lost','no budget','price_rejected')$$,
  'the closure path is untouched: CLOSE_LEAD still governs it, through the RPC, for the handler');

-- =============================================================================================
-- 8-11. SEC-1's last table. `lead_interactions` charges what record_lead_interaction charges.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code,
                          title, lead_status_code)
values ('59000000-0000-0000-0000-0000000000e2','59000000-0000-0000-0000-000000000001',
        '59000000-0000-0000-0000-00000000000a','59000000-0000-0000-0000-0000000000c1',
        '59000000-0000-0000-0000-0000000000d1','direct_call','Second lead','new');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"59000000-0000-0000-0000-0000000000a3"}', true);
select app.assign_lead('59000000-0000-0000-0000-0000000000e2','59000000-0000-0000-0000-000000000011','handler''s own');
reset role;
select set_config('request.jwt.claims', null, true);

select set_config('request.jwt.claims','{"sub":"59000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.lead_interactions (tenant_id, lead_id, user_id, interaction_type_code, summary)
    values ('59000000-0000-0000-0000-000000000001','59000000-0000-0000-0000-0000000000e2',
            '59000000-0000-0000-0000-000000000012','note','logged on a colleague''s lead')$$,
  '42501', null,
  'SEC-1: a colleague cannot log an interaction on someone else''s lead by direct DML either');

reset role;
select set_config('request.jwt.claims','{"sub":"59000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select lives_ok(
  $$insert into public.lead_interactions (tenant_id, lead_id, user_id, interaction_type_code, summary)
    values ('59000000-0000-0000-0000-000000000001','59000000-0000-0000-0000-0000000000e2',
            '59000000-0000-0000-0000-000000000011','note','the handler logs their own')$$,
  'POSITIVE CONTROL: the handler can, on the same lead');

select is(
  (select count(*)::int from public.lead_interactions where lead_id = '59000000-0000-0000-0000-0000000000e2'),
  1,
  '...and it persisted, so the denial above is not a blanket refusal');

reset role;
select set_config('request.jwt.claims','{"sub":"59000000-0000-0000-0000-0000000000a3"}', true);
set local role authenticated;

select lives_ok(
  $$insert into public.lead_interactions (tenant_id, lead_id, user_id, interaction_type_code, summary)
    values ('59000000-0000-0000-0000-000000000001','59000000-0000-0000-0000-0000000000e2',
            '59000000-0000-0000-0000-000000000013','note','the manager logs on the queue')$$,
  '...and so can ASSIGN_LEAD, which is the rule''s other half');

-- =============================================================================================
-- 12-14. THE SYSTEM PATH SURVIVES, AND THE CLASS IS PINNED.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select lives_ok(
  $$insert into public.lead_interactions (tenant_id, lead_id, user_id, interaction_type_code, summary)
    values ('59000000-0000-0000-0000-000000000001','59000000-0000-0000-0000-0000000000e2',
            null,'note','app.process_lead_sla is session-less and definer')$$,
  'the SYSTEM path still writes -- a guard that broke the SLA processor would be worse than the hole');

-- The new else-branch of enforce_status_transition is unreachable today, and that is exactly what
-- makes it a guard: `leads` is the only table with null permission_keys, so any future null on any
-- other table becomes a loud 42501 instead of a silent unguarded transition.
select is(
  (select count(*)::int from app.status_transitions
    where permission_key is null and table_name <> 'leads'),
  0,
  'only `leads` carries null permission_keys -- any other table adding one now FAILS CLOSED');

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and t.tgname = 'lead_interactions_guard_handler_authority'
      and c.relname = 'lead_interactions'),
  1,
  'lead_interactions carries the handler-authority guard');

select finish();
rollback;
