-- pgTAP: Batch 6 slice 9 -- `leads`. LEAD-1 (the door that answered its own authority question),
-- LEAD-2/LEAD-3/LEAD-4 (the lifecycle preconditions that lived only inside the RPCs).
--
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE BUSINESS OBSERVABILITY PRIVILEGE INPUT REPLAY=N/A CONCURRENCY=N/A
--
-- REPLAY=N/A       every write here is idempotent in the only sense that matters to this surface:
--                  re-issuing the same UPDATE re-runs the same guards on the same row and reaches
--                  the same verdict. The lead carries no single-use token and no counter.
-- CONCURRENCY=N/A  `leads` has no read-modify-write path a client can drive. The one place two
--                  legitimate actors could combine badly is the SLA reassignment, which is owned by
--                  `lead_assignments_one_current_idx` and `app.process_lead_sla`'s advisory lock and
--                  is tested where those live (`63_sla_escalation_test`, `66_scheduled_job_isolation_test`).
--
-- THE POINT OF THIS FILE, in one line: slice 8 recorded the seize-plus-transition as a VERIFIED
-- NON-DEFECT because it was refused. It IS refused -- but by a coherence constraint and an integrity
-- trigger, neither of which is the authorization model. Assertions 12-15 remove both and ask the
-- question again, which is the only way to tell an INCIDENTAL DEFENSE from an INTENTIONAL CONTROL.
create extension if not exists pgtap with schema extensions;

begin;
select plan(20);

insert into auth.users (id, email, email_confirmed_at) values
  ('a9000000-0000-0000-0000-0000000000a1','handler@la.test',   now()),
  ('a9000000-0000-0000-0000-0000000000a2','colleague@la.test', now()),
  ('a9000000-0000-0000-0000-0000000000a3','manager@la.test',   now());
insert into public.tenants (id, name, slug, status) values
  ('a9000000-0000-0000-0000-000000000001','LA Travel','la-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select 'a9000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('a9000000-0000-0000-0000-00000000000a','a9000000-0000-0000-0000-000000000001','Cairo','la-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('a9000000-0000-0000-0000-0000000000c1','a9000000-0000-0000-0000-000000000001','a9000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('a9000000-0000-0000-0000-000000000011','a9000000-0000-0000-0000-000000000001','Handler','handler@la.test',true,'a9000000-0000-0000-0000-0000000000a1'),
  ('a9000000-0000-0000-0000-000000000012','a9000000-0000-0000-0000-000000000001','Colleague','colleague@la.test',true,'a9000000-0000-0000-0000-0000000000a2'),
  ('a9000000-0000-0000-0000-000000000013','a9000000-0000-0000-0000-000000000001','Manager','manager@la.test',true,'a9000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select 'a9000000-0000-0000-0000-000000000001', u,
       'a9000000-0000-0000-0000-00000000000a','a9000000-0000-0000-0000-0000000000c1', true
from unnest(array['a9000000-0000-0000-0000-000000000011'::uuid,'a9000000-0000-0000-0000-000000000012'::uuid,
                  'a9000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'a9000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('a9000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('a9000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('a9000000-0000-0000-0000-000000000013'::uuid,'branch_manager')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('a9000000-0000-0000-0000-0000000000d1','a9000000-0000-0000-0000-000000000001','person','Real Customer');

-- The lead reaches the handler through the sanctioned path, so `lead_assignments` carries a real
-- current row and no assertion below is measuring a fixture shortcut.
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code,
                          title, lead_status_code)
values ('a9000000-0000-0000-0000-0000000000e1','a9000000-0000-0000-0000-000000000001',
        'a9000000-0000-0000-0000-00000000000a','a9000000-0000-0000-0000-0000000000c1',
        'a9000000-0000-0000-0000-0000000000d1','direct_call','Handler lead','new');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
select app.assign_lead('a9000000-0000-0000-0000-0000000000e1','a9000000-0000-0000-0000-000000000011','initial');
reset role;
select set_config('request.jwt.claims', null, true);
update public.leads set lead_status_code = 'contacted' where id = 'a9000000-0000-0000-0000-0000000000e1';

-- =============================================================================================
-- 1-2. PROVE THE ACTOR AND THE REACH BEFORE ATTACKING (the seventh rule's second consequence).
--      `set local role` outside a transaction is a silent no-op, and a denial from a row that was
--      never reachable is not a denial at all.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select ok(
  current_user = 'authenticated'
  and (select auth.uid()) = 'a9000000-0000-0000-0000-0000000000a2'
  and app.current_user_id() = 'a9000000-0000-0000-0000-000000000012'
  and app.has_permission('CREATE_LEAD')
  and not app.has_permission('ASSIGN_LEAD')
  and not app.has_permission('REASSIGN_LEAD'),
  'ACTOR: the colleague is `authenticated`, resolves to their own user, HOLDS CREATE_LEAD and holds neither assignment key');

select is(
  (select count(*)::int from public.leads where id = 'a9000000-0000-0000-0000-0000000000e1'),
  1,
  'REACH: ...and SEES the handler''s lead through the department queue -- every refusal below is authority');

-- =============================================================================================
-- 3-5. LEAD-1. The seize, in all three shapes slice 8 could have run and ran only one of.
-- =============================================================================================
select throws_ok(
  $$update public.leads
       set assigned_user_id = 'a9000000-0000-0000-0000-000000000012',
           owner_user_id    = 'a9000000-0000-0000-0000-000000000012',
           lead_status_code = 'qualified'
     where id = 'a9000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'LEAD-1: SEIZE + TRANSITION in one statement is refused -- and 42501 means the AUTHORIZATION model refused it');

select throws_ok(
  $$update public.leads
       set assigned_user_id = 'a9000000-0000-0000-0000-000000000012',
           owner_user_id    = 'a9000000-0000-0000-0000-000000000012'
     where id = 'a9000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  '...and SEIZE ALONE is refused for the same reason: moving an assignment costs ASSIGN_LEAD or REASSIGN_LEAD');

select throws_ok(
  $$update public.leads set lead_status_code = 'qualified'
     where id = 'a9000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  '...and TRANSITION ALONE is still refused (TRANS-2, unchanged -- the fallback now reads OLD)');

select is(
  (select assigned_user_id::text || ' ' || lead_status_code from public.leads
    where id = 'a9000000-0000-0000-0000-0000000000e1'),
  'a9000000-0000-0000-0000-000000000011 contacted',
  'GROUND TRUTH: nothing moved -- an RLS-refused UPDATE degrades into a silent no-op, so this is read separately');

-- =============================================================================================
-- 7-9. POSITIVE CONTROLS. A fix that stopped the legitimate paths would be the worse defect.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$update public.leads set title = 'handler renamed it'
     where id = 'a9000000-0000-0000-0000-0000000000e1'$$,
  'POSITIVE CONTROL: the handler still edits their own lead -- the shortcut survives, read from OLD');

select is(
  (select title from public.leads where id = 'a9000000-0000-0000-0000-0000000000e1'),
  'handler renamed it',
  '...and it PERSISTED: "did not throw" is not evidence that a write occurred');

reset role;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$select app.reassign_lead('a9000000-0000-0000-0000-0000000000e1','a9000000-0000-0000-0000-000000000012','legitimate')$$,
  'POSITIVE CONTROL: REASSIGN_LEAD still moves the assignment through the RPC -- the door did not close on its own writer');

-- =============================================================================================
-- 10-11. LEAD-2 and LEAD-3. The state machine's entry arm and the converted precondition.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.leads (tenant_id, branch_id, department_id, lead_source_code, title, lead_status_code)
    values ('a9000000-0000-0000-0000-000000000001','a9000000-0000-0000-0000-00000000000a',
            'a9000000-0000-0000-0000-0000000000c1','direct_call','Born won','won')$$,
  '23514', null,
  'LEAD-2: a lead can no longer be BORN in a terminal status -- app.create_lead hardcodes ''new'' and the door now agrees');

reset role;
select set_config('request.jwt.claims', null, true);
update public.leads
   set lead_status_code = 'qualified', customer_id = null
 where id = 'a9000000-0000-0000-0000-0000000000e1';
update public.leads set lead_status_code = 'won' where id = 'a9000000-0000-0000-0000-0000000000e1';
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$update public.leads set lead_status_code = 'converted'
     where id = 'a9000000-0000-0000-0000-0000000000e1'$$,
  '23514', null,
  'LEAD-3: `converted` with no customer is refused -- app.convert_lead already refused it, the table door did not');

-- =============================================================================================
-- 12-13. LEAD-4. The edge no RPC offers, and the SLA escape it opened.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code,
                          title, lead_status_code)
values ('a9000000-0000-0000-0000-0000000000e2','a9000000-0000-0000-0000-000000000001',
        'a9000000-0000-0000-0000-00000000000a','a9000000-0000-0000-0000-0000000000c1',
        'a9000000-0000-0000-0000-0000000000d1','direct_call','SLA lead','new');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
select app.assign_lead('a9000000-0000-0000-0000-0000000000e2','a9000000-0000-0000-0000-000000000012','sla fixture');

reset role;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$update public.leads set lead_status_code = 'contacted'
     where id = 'a9000000-0000-0000-0000-0000000000e2'$$,
  '23514', null,
  'LEAD-4: the HANDLER cannot assert `contacted` with no interaction behind it -- that flip leaves process_lead_sla''s working set');

select lives_ok(
  $$select app.record_lead_interaction('a9000000-0000-0000-0000-0000000000e2','phone_call','a real call')$$,
  'POSITIVE CONTROL: ...and the sanctioned producer of that edge still produces it -- the RPC walks the lead to `contacted`');

-- =============================================================================================
-- 14. TENANT. The seize does not become reachable by pointing at another tenant's user.
-- =============================================================================================
select is(
  (select count(*)::int from public.leads where tenant_id <> 'a9000000-0000-0000-0000-000000000001'),
  0,
  'TENANT: the colleague sees no lead outside their own tenant -- RLS is unchanged by this migration');

-- =============================================================================================
-- 15-18. THE LOAD-BEARING PAIR, AND THE ONE THIS SLICE EXISTS FOR.
--
--        PAR-4 says a repair is not done until a defect injection proves the test detects its
--        absence. Here the injection has to remove THREE things, because the point of the finding is
--        that two of them were doing the work: `leads_owner_matches_assignee_chk` and
--        `leads_require_assignment_history` refuse the seize for reasons that have nothing to do
--        with authorization, and with them present a broken capability guard still looks green.
--
--        So: drop both incidental defences and assert the seize is STILL refused, and that the
--        refusal is 42501 rather than 23514. Then drop the repaired guard too and assert the seize
--        SUCCEEDS -- which is the state this table was in before `202607061900`. Roll back, restore
--        the session, and assert the refusal returns (TEST-3).
--
--        The statement is SEIZE-ONLY on a lead of its own, and both choices are deliberate. Adding a
--        transition would let `enforce_status_transition` -- which fires FIRST in trigger-name order
--        -- answer instead, so the assertion would report 42501 while measuring a different guard.
--        A fresh lead is used because assertion 9 legitimately reassigned the first one to this very
--        actor, and a seize you already own is not a seize.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code,
                          title, lead_status_code)
values ('a9000000-0000-0000-0000-0000000000e3','a9000000-0000-0000-0000-000000000001',
        'a9000000-0000-0000-0000-00000000000a','a9000000-0000-0000-0000-0000000000c1',
        'a9000000-0000-0000-0000-0000000000d1','direct_call','Mutation lead','new');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
select app.assign_lead('a9000000-0000-0000-0000-0000000000e3','a9000000-0000-0000-0000-000000000011','mutation fixture');
reset role;
select set_config('request.jwt.claims', null, true);

savepoint before_mutation;
alter table public.leads drop constraint leads_owner_matches_assignee_chk;
drop trigger leads_require_assignment_history on public.leads;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select throws_ok(
  $$update public.leads
       set assigned_user_id = 'a9000000-0000-0000-0000-000000000012',
           owner_user_id    = 'a9000000-0000-0000-0000-000000000012'
     where id = 'a9000000-0000-0000-0000-0000000000e3'$$,
  '42501', null,
  'INTENTIONAL CONTROL: with BOTH incidental defences removed the seize is STILL refused, and by the authorization model');

reset role;
select set_config('request.jwt.claims', null, true);
drop trigger leads_guard_write_capability on public.leads;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select lives_ok(
  $$update public.leads
       set assigned_user_id = 'a9000000-0000-0000-0000-000000000012',
           owner_user_id    = 'a9000000-0000-0000-0000-000000000012'
     where id = 'a9000000-0000-0000-0000-0000000000e3'$$,
  'MUTATION: remove the capability guard as well and the seize SUCCEEDS -- so assertion 15 is this guard and not a coincidence');

select is(
  (select assigned_user_id from public.leads where id = 'a9000000-0000-0000-0000-0000000000e3'),
  'a9000000-0000-0000-0000-000000000012'::uuid,
  '...and it MOVED -- the mutation is proven to have reached the row, not merely to have not thrown');

reset role;
select set_config('request.jwt.claims', null, true);
rollback to savepoint before_mutation;

-- The session must be re-established after the rollback, or the next probe measures "never
-- attempted" rather than "denied" (tests 70/72's confusion, and TEST-3's rule).
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"a9000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select throws_ok(
  $$update public.leads
       set assigned_user_id = 'a9000000-0000-0000-0000-000000000012',
           owner_user_id    = 'a9000000-0000-0000-0000-000000000012'
     where id = 'a9000000-0000-0000-0000-0000000000e3'$$,
  '42501', null,
  '...and with everything restored it is refused again -- the pair is what makes assertions 3-4 load-bearing');

-- =============================================================================================
-- 19-20. THE CLASS, PINNED. Both halves of the BOOK-5 question, so a future edit that reverts
--        either one fails here rather than in production.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'enforce_status_transition'
      and p.prosrc like '%to_jsonb(old) ->> ''assigned_user_id''%'),
  1,
  'BOOK-5 CLASS: the transition fallback resolves the handler from OLD -- reading NEW is what LI-1 and LEAD-1 both were');

-- A tripwire, and it says what it measures. It proves the leads branch of `guard_write_capability`
-- names `old.assigned_user_id` and does NOT decide the shortcut from `new`. It does NOT prove the
-- guard is correct -- only a behavioural assertion does that, which is what 3-6 and 15-18 are for.
select ok(
  (select p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'guard_write_capability')
    like '%in (old.assigned_user_id, old.owner_user_id)%',
  '...and the capability shortcut is decided from OLD too -- a text tripwire, deliberately over-matching');

select * from finish();
rollback;
