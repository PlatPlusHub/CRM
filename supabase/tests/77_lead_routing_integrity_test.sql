-- pgTAP: the API-3 lead-routing family -- LEAD-6, ASGN-1, ASGN-2, ASGN-3 (202607058100).
--
-- Before this file, `app.assign_lead_round_robin` had NO behavioural coverage at all: its only
-- appearance in the suite was as a name in `53_api_surface_test.sql`'s endpoint list, which is the
-- CUST-2 shape -- a guard that cannot see what an endpoint does. A trainee-routing defect and three
-- table-door defects lived behind that list.
--
-- Role choice, stated rather than assumed: the subjects here are TRIGGERS, an INDEX and RPC
-- selection logic, all of which apply to the table owner too, so most of the file runs as postgres
-- with a JWT claim set -- the idiom `24_assignment_history_test.sql` states and uses. The final
-- section re-proves the two refusals through the real `authenticated` role, because that is the
-- door PostgREST actually opens and BOOK-1's lesson is that the two are not the same test.
--
-- Every negative assertion here is preceded by a positive control that proves the actor holds the
-- capability, the row is visible, and the legal path genuinely changes something. Both new guards
-- are attacked by defect injection (the PAR-4 pattern): drop the enforcer inside a savepoint,
-- assert the violation SUCCEEDS, roll back, assert it is refused again.
create extension if not exists pgtap with schema extensions;

begin;
select plan(22);

insert into auth.users (id, email) values
  ('77000000-0000-0000-0000-0000000000a1','mgr@routing.example'),
  ('77000000-0000-0000-0000-0000000000a2','other@routing.example');
insert into public.tenants (id, name, slug, status) values
-- Slugs are prefixed per file, as every sibling test does (`ledger-rival`, `merge-rival`,
-- `book-rival`). Pass B caught the first draft of this file using the bare slug `rival-travel`,
-- which `verify_api_end_to_end.ps1` COMMITS: Pass A was green and Pass B lost all 22 assertions to
-- a `tenants_slug_key` collision. That is the TEST-2 class, and the protocol is what found it.
  ('77000000-0000-0000-0000-000000000001','Routing Travel','routing-travel','active'),
  ('77000000-0000-0000-0000-000000000002','Routing Rival','routing-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.branches (id, tenant_id, name, slug) values
  ('77000000-0000-0000-0000-00000000000a','77000000-0000-0000-0000-000000000001','Main','routing-main'),
  ('77000000-0000-0000-0000-00000000000b','77000000-0000-0000-0000-000000000001','Annexe','routing-annexe');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('77000000-0000-0000-0000-0000000000c1','77000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-00000000000a','sales','Main Sales'),
  ('77000000-0000-0000-0000-0000000000c2','77000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-00000000000b','sales','Annexe Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('77000000-0000-0000-0000-000000000011','77000000-0000-0000-0000-000000000001','Manager','mgr@routing.example',true,'77000000-0000-0000-0000-0000000000a1'),
  ('77000000-0000-0000-0000-000000000021','77000000-0000-0000-0000-000000000001','Employee','emp@routing.example',true,null),
  ('77000000-0000-0000-0000-000000000031','77000000-0000-0000-0000-000000000001','Trainee','trn@routing.example',true,null);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '77000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000011', r.id,'tenant' from public.roles r where r.code='branch_manager';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '77000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000021', r.id,'tenant' from public.roles r where r.code='employee';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '77000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000031', r.id,'tenant' from public.roles r where r.code='trainee';
-- All three are PLACED in Main Sales. Only the trainee lacks CLOSE_LEAD.
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '77000000-0000-0000-0000-000000000001', u, '77000000-0000-0000-0000-00000000000a','77000000-0000-0000-0000-0000000000c1', true
from unnest(array['77000000-0000-0000-0000-000000000011'::uuid,
                  '77000000-0000-0000-0000-000000000021',
                  '77000000-0000-0000-0000-000000000031']) u;
-- Annexe Sales holds ONLY the trainee: the "nobody is eligible" case.
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
values ('77000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-000000000031','77000000-0000-0000-0000-00000000000b','77000000-0000-0000-0000-0000000000c2', false);

select set_config('request.jwt.claims','{"sub":"77000000-0000-0000-0000-0000000000a1"}',true);

-- ================================================================================================
-- POSITIVE CONTROLS -- the actor is real and the definition of "eligible" is the one canon means.
-- ================================================================================================
select ok(app.has_permission('ASSIGN_LEAD'), 'POSITIVE CONTROL: the actor genuinely holds ASSIGN_LEAD, so a later refusal is about the rule under test and not about the actor');

select is(
  (select count(*)::int from app.eligible_lead_handlers(
     '77000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-00000000000a','77000000-0000-0000-0000-0000000000c1')),
  2,
  'the eligible pool in Main Sales is TWO -- the manager and the employee, both of whom hold CLOSE_LEAD');

select ok(
  not exists (select 1 from app.eligible_lead_handlers(
     '77000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-00000000000a','77000000-0000-0000-0000-0000000000c1') e
     where e = '77000000-0000-0000-0000-000000000031'),
  'the trainee is PLACED in Main Sales but is NOT eligible -- eligibility is authority, not proximity (LEAD-3)');

-- ================================================================================================
-- LEAD-6 -- round-robin routes by eligibility, not by placement.
-- ================================================================================================
-- Seed both eligible people with a prior assignment, so that under the OLD predicate the
-- never-assigned trainee would have sorted FIRST ("nulls first") and won. This is what makes the
-- next assertion discriminating rather than incidental.
create temp table seed1 as select app.create_lead('77000000-0000-0000-0000-00000000000a','77000000-0000-0000-0000-0000000000c1','whatsapp','seed A') as id;
select app.assign_lead((select id from seed1),'77000000-0000-0000-0000-000000000011','seed');
create temp table seed2 as select app.create_lead('77000000-0000-0000-0000-00000000000a','77000000-0000-0000-0000-0000000000c1','whatsapp','seed B') as id;
select app.assign_lead((select id from seed2),'77000000-0000-0000-0000-000000000021','seed');

create temp table rr as select app.create_lead('77000000-0000-0000-0000-00000000000a','77000000-0000-0000-0000-0000000000c1','whatsapp','round robin target') as id;
select lives_ok(
  $$select app.assign_lead_round_robin((select id from rr), 'auto')$$,
  'round-robin assigns the lead');

select isnt(
  (select assigned_user_id from public.leads where id = (select id from rr)),
  '77000000-0000-0000-0000-000000000031'::uuid,
  'LEAD-6: round-robin did NOT route to the trainee, although the trainee is placed here and would have sorted first under the old placement-only predicate');

select ok(
  exists (select 1 from app.eligible_lead_handlers(
     '77000000-0000-0000-0000-000000000001','77000000-0000-0000-0000-00000000000a','77000000-0000-0000-0000-0000000000c1') e
     where e = (select assigned_user_id from public.leads where id = (select id from rr))),
  '...and the person it DID choose is in the eligible pool, so the lead reached someone who can bring it to an outcome');

create temp table rr2 as select app.create_lead('77000000-0000-0000-0000-00000000000b','77000000-0000-0000-0000-0000000000c2','whatsapp','annexe target') as id;
select throws_ok(
  $$select app.assign_lead_round_robin((select id from rr2), 'auto')$$,
  null, 'no eligible employee for round-robin',
  'where the only person placed is ineligible, round-robin REFUSES rather than routing to someone who cannot close the lead');

select is(
  (select assigned_user_id from public.leads where id = (select id from rr2)),
  null,
  '...and that lead is left unassigned rather than silently handed to the trainee');

-- ================================================================================================
-- ASGN-1 -- exactly one current assignment per lead, enforced by the index rather than by an RPC.
-- ================================================================================================
select is(
  (select count(*)::int from public.lead_assignments where lead_id = (select id from rr) and is_current),
  1,
  'POSITIVE CONTROL: the legal path leaves exactly ONE current assignment, so the duplicate below is the only thing being tested');

select throws_ok(
  format($$insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_by, is_current)
           values ('77000000-0000-0000-0000-000000000001','%s','77000000-0000-0000-0000-000000000021',
                   '77000000-0000-0000-0000-000000000011', true)$$, (select id from rr)),
  '23505', null,
  'ASGN-1: a SECOND current assignment for the same lead is refused by the database, on the table door the RPC does not own');

-- Defect injection (PAR-4): prove the index is what refuses it.
savepoint before_mutation;
drop index public.lead_assignments_one_current_idx;
select lives_ok(
  format($$insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_by, is_current)
           values ('77000000-0000-0000-0000-000000000001','%s','77000000-0000-0000-0000-000000000021',
                   '77000000-0000-0000-0000-000000000011', true)$$, (select id from rr)),
  'MUTATION: with lead_assignments_one_current_idx dropped the duplicate SUCCEEDS -- proving the index is the enforcer and this test is not passing for some unrelated reason');
select is(
  (select count(*)::int from public.lead_assignments where lead_id = (select id from rr) and is_current),
  2,
  '...and the corrupt state it produces is exactly the one reproduced before the fix: two current handlers for one lead');
rollback to savepoint before_mutation;

select throws_ok(
  format($$insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_by, is_current)
           values ('77000000-0000-0000-0000-000000000001','%s','77000000-0000-0000-0000-000000000021',
                   '77000000-0000-0000-0000-000000000011', true)$$, (select id from rr)),
  '23505', null,
  '...and with the index restored it is refused again');

-- ================================================================================================
-- ASGN-2 -- assigned_by is derived from the session, never accepted from the caller.
-- ================================================================================================
select lives_ok(
  format($$insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_by, is_current)
           values ('77000000-0000-0000-0000-000000000001','%s','77000000-0000-0000-0000-000000000021',
                   '77000000-0000-0000-0000-000000000021', false)$$, (select id from rr)),
  'POSITIVE CONTROL: a closed history row inserts successfully, so the assertion below is about the VALUE stored and not about the insert being blocked');

select is(
  (select assigned_by from public.lead_assignments
    where lead_id = (select id from rr) and not is_current
    order by assigned_at desc limit 1),
  '77000000-0000-0000-0000-000000000011'::uuid,
  'ASGN-2: assigned_by is the SESSION actor (the manager), not the Employee id the caller supplied -- attribution cannot be forged on the table door (ATTR-1 class)');

-- ================================================================================================
-- ASGN-3 -- a lead in a terminal status cannot acquire a new handler by any door.
-- ================================================================================================
select lives_ok(
  format($$select app.advance_lead('%s','lost','not interested','not_interested')$$, (select id from rr)),
  'POSITIVE CONTROL: the lead is closed through the LEGAL path, so the refusal below is about the terminal rule and not about a broken fixture');

select is(
  (select lead_status_code from public.leads where id = (select id from rr)),
  'lost',
  '...and it really is in a terminal status now');

select throws_ok(
  format($$insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_by, is_current)
           values ('77000000-0000-0000-0000-000000000001','%s','77000000-0000-0000-0000-000000000011',
                   '77000000-0000-0000-0000-000000000011', false)$$, (select id from rr)),
  '23514', null,
  'ASGN-3: a closed lead cannot acquire a handler by direct DML -- the rule app.reassign_lead enforces now holds on the table door too');

savepoint before_trigger_mutation;
drop trigger lead_assignments_guard_target on public.lead_assignments;
select lives_ok(
  format($$insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_by, is_current)
           values ('77000000-0000-0000-0000-000000000001','%s','77000000-0000-0000-0000-000000000011',
                   '77000000-0000-0000-0000-000000000011', false)$$, (select id from rr)),
  'MUTATION: with lead_assignments_guard_target dropped the same insert SUCCEEDS -- proving that trigger is the enforcer');
rollback to savepoint before_trigger_mutation;

-- ================================================================================================
-- The tenant guard that makes the new EXECUTE grant safe.
-- ================================================================================================
select throws_ok(
  $$select count(*) from app.eligible_lead_handlers(
      '77000000-0000-0000-0000-000000000002','77000000-0000-0000-0000-00000000000a','77000000-0000-0000-0000-0000000000c1')$$,
  '42501', null,
  'app.eligible_lead_handlers is SECURITY DEFINER and now callable by authenticated -- a session asking about ANOTHER tenant is refused, so the grant is not a staff-enumeration oracle');

-- ================================================================================================
-- The real door: the same two refusals as `authenticated`, which is what PostgREST exposes.
-- ================================================================================================
-- The temp table holding the fixture id is owned by postgres; the role we are about to become
-- needs to read it. This grants access to the TEST's own scratch table only -- it changes nothing
-- about the subject under test.
grant select on seed1 to authenticated;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"77000000-0000-0000-0000-0000000000a1"}',true);

select ok(
  (select count(*) from public.leads where id = (select id from seed1)) = 1,
  'POSITIVE CONTROL as authenticated: the manager can SEE the lead, so the refusal below is not RLS hiding the row');

select throws_ok(
  format($$insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_by, is_current)
           values ('77000000-0000-0000-0000-000000000001','%s','77000000-0000-0000-0000-000000000021',
                   '77000000-0000-0000-0000-000000000011', true)$$, (select id from seed1)),
  '23505', null,
  'ASGN-1 holds through the REAL role: a second current assignment is refused for authenticated, which is the role PostgREST serves');

select finish();
rollback;
