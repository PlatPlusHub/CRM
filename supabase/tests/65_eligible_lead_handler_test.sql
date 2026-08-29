-- pgTAP: LEAD-3 -- an SLA-overdue lead is handed to someone who can actually work it.
--
-- LEAD-3 was filed as an owner decision: "the reassignment pool includes MANAGERS -- canon 04 says
-- 'another eligible employee' and defines neither term." Asking the permission matrix instead of
-- the word answers it: CLOSE_LEAD, CREATE_LEAD, CREATE_QUOTATION and VIEW_DEPARTMENT_QUEUE all
-- resolve to the SAME six roles, and branch_manager and department_manager are among them. So a
-- manager IS an eligible handler by ORVION's own definition, and assertion 3 pins that.
--
-- Underneath the question was a defect. The pool was never "eligible employees" -- it was "everyone
-- PLACED in the branch and department", with no reference to what any of them may do. Reproduced
-- live before the fix: one handler, one trainee, one finance manager, and the SLA reassigned the
-- overdue lead to the TRAINEE -- a role holding exactly two permissions in the entire system,
-- neither of which can quote, close or book. The rescue mechanism could park a lead where it can
-- never leave.
--
-- A NOTE ON THE FIXTURE, because it is doing real work. Every excluded user in Cairo carries a
-- LOWER id than the colleague who must win, and the round robin breaks its tie on `u.id asc` with
-- every `last_at` null. So each exclusion is LOAD-BEARING on assertion 7: if the trainee, the
-- finance manager, the deactivated user or the user whose role assignment has expired were still
-- eligible, that assertion would name them instead of failing quietly.
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

insert into auth.users (id, email)
select u, 'auth-' || right(u::text, 2) || '@lead3.test'
from unnest(array['65000000-0000-0000-0000-000000000011'::uuid,'65000000-0000-0000-0000-000000000012'::uuid,
                  '65000000-0000-0000-0000-000000000013'::uuid,'65000000-0000-0000-0000-000000000014'::uuid,
                  '65000000-0000-0000-0000-000000000015'::uuid,'65000000-0000-0000-0000-000000000016'::uuid,
                  '65000000-0000-0000-0000-000000000017'::uuid,'65000000-0000-0000-0000-000000000021'::uuid,
                  '65000000-0000-0000-0000-000000000022'::uuid,'65000000-0000-0000-0000-000000000023'::uuid]) u;

insert into public.tenants (id, name, slug, status) values
  ('65000000-0000-0000-0000-000000000001','Lead3 Travel','lead3-travel','active'),
  ('65000000-0000-0000-0000-000000000002','Lead3 Other','lead3-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active'
from public.subscription_plans sp,
     unnest(array['65000000-0000-0000-0000-000000000001'::uuid,
                  '65000000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';

insert into public.branches (id, tenant_id, name, slug) values
  ('65000000-0000-0000-0000-00000000000a','65000000-0000-0000-0000-000000000001','Cairo','lead3-cairo'),
  ('65000000-0000-0000-0000-00000000000b','65000000-0000-0000-0000-000000000001','Alex','lead3-alex');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('65000000-0000-0000-0000-0000000000c1','65000000-0000-0000-0000-000000000001','65000000-0000-0000-0000-00000000000a','sales','Cairo Sales'),
  ('65000000-0000-0000-0000-0000000000c2','65000000-0000-0000-0000-000000000001','65000000-0000-0000-0000-00000000000b','sales','Alex Sales');

-- Cairo. Ids ascend in the order the round robin would consider them.
--   11 handler (employee, current assignee)   12 trainee            13 finance manager
--   14 employee but DEACTIVATED               15 employee whose role assignment EXPIRED
--   16 colleague (employee, active)  <- must win        17 branch manager (eligible, higher id)
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('65000000-0000-0000-0000-000000000011','65000000-0000-0000-0000-000000000001','Handler','auth-11@lead3.test',true,'65000000-0000-0000-0000-000000000011'),
  ('65000000-0000-0000-0000-000000000012','65000000-0000-0000-0000-000000000001','Trainee','auth-12@lead3.test',true,'65000000-0000-0000-0000-000000000012'),
  ('65000000-0000-0000-0000-000000000013','65000000-0000-0000-0000-000000000001','Finance Manager','auth-13@lead3.test',true,'65000000-0000-0000-0000-000000000013'),
  ('65000000-0000-0000-0000-000000000014','65000000-0000-0000-0000-000000000001','Deactivated','auth-14@lead3.test',false,'65000000-0000-0000-0000-000000000014'),
  ('65000000-0000-0000-0000-000000000015','65000000-0000-0000-0000-000000000001','Expired Role','auth-15@lead3.test',true,'65000000-0000-0000-0000-000000000015'),
  ('65000000-0000-0000-0000-000000000016','65000000-0000-0000-0000-000000000001','Colleague','auth-16@lead3.test',true,'65000000-0000-0000-0000-000000000016'),
  ('65000000-0000-0000-0000-000000000017','65000000-0000-0000-0000-000000000001','Branch Manager','auth-17@lead3.test',true,'65000000-0000-0000-0000-000000000017'),
-- Alexandria: a handler, a trainee and a finance manager. NOBODY here may work a lead.
  ('65000000-0000-0000-0000-000000000021','65000000-0000-0000-0000-000000000001','Alex Handler','auth-21@lead3.test',true,'65000000-0000-0000-0000-000000000021'),
  ('65000000-0000-0000-0000-000000000022','65000000-0000-0000-0000-000000000001','Alex Trainee','auth-22@lead3.test',true,'65000000-0000-0000-0000-000000000022'),
  ('65000000-0000-0000-0000-000000000023','65000000-0000-0000-0000-000000000001','Alex Finance','auth-23@lead3.test',true,'65000000-0000-0000-0000-000000000023');

insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '65000000-0000-0000-0000-000000000001', u,
       '65000000-0000-0000-0000-00000000000a','65000000-0000-0000-0000-0000000000c1', true
from unnest(array['65000000-0000-0000-0000-000000000011'::uuid,'65000000-0000-0000-0000-000000000012'::uuid,
                  '65000000-0000-0000-0000-000000000013'::uuid,'65000000-0000-0000-0000-000000000014'::uuid,
                  '65000000-0000-0000-0000-000000000015'::uuid,'65000000-0000-0000-0000-000000000016'::uuid,
                  '65000000-0000-0000-0000-000000000017'::uuid]) u;
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '65000000-0000-0000-0000-000000000001', u,
       '65000000-0000-0000-0000-00000000000b','65000000-0000-0000-0000-0000000000c2', true
from unnest(array['65000000-0000-0000-0000-000000000021'::uuid,'65000000-0000-0000-0000-000000000022'::uuid,
                  '65000000-0000-0000-0000-000000000023'::uuid]) u;

insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '65000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('65000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('65000000-0000-0000-0000-000000000012'::uuid,'trainee'),
             ('65000000-0000-0000-0000-000000000013'::uuid,'finance_manager'),
             ('65000000-0000-0000-0000-000000000014'::uuid,'employee'),
             ('65000000-0000-0000-0000-000000000016'::uuid,'employee'),
             ('65000000-0000-0000-0000-000000000017'::uuid,'branch_manager'),
             ('65000000-0000-0000-0000-000000000021'::uuid,'employee'),
             ('65000000-0000-0000-0000-000000000022'::uuid,'trainee'),
             ('65000000-0000-0000-0000-000000000023'::uuid,'finance_manager')) v(u,rc)
join public.roles r on r.code = v.rc;
-- SPEC-148: revocation is complete. An assignment that has ENDED confers nothing.
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type, starts_at, ends_at)
select '65000000-0000-0000-0000-000000000001','65000000-0000-0000-0000-000000000015', r.id, 'tenant',
       now() - interval '30 days', now() - interval '1 day'
from public.roles r where r.code = 'employee';

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('65000000-0000-0000-0000-0000000000d1','65000000-0000-0000-0000-000000000001','person','Lead3 Customer','+201000000065');
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code, title, lead_status_code) values
  ('65000000-0000-0000-0000-0000000000e1','65000000-0000-0000-0000-000000000001','65000000-0000-0000-0000-00000000000a','65000000-0000-0000-0000-0000000000c1','65000000-0000-0000-0000-0000000000d1','direct_call','Cairo lead','new'),
  ('65000000-0000-0000-0000-0000000000e2','65000000-0000-0000-0000-000000000001','65000000-0000-0000-0000-00000000000b','65000000-0000-0000-0000-0000000000c2','65000000-0000-0000-0000-0000000000d1','direct_call','Alex lead','new');

-- Assigned as the system does it (session-less, which app.process_lead_sla itself is). The RPC path
-- is already proven by 63_sla_escalation_test; what this file measures is the CANDIDATE SET.
insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assignment_reason, is_current) values
  ('65000000-0000-0000-0000-000000000001','65000000-0000-0000-0000-0000000000e1','65000000-0000-0000-0000-000000000011','fixture',true),
  ('65000000-0000-0000-0000-000000000001','65000000-0000-0000-0000-0000000000e2','65000000-0000-0000-0000-000000000021','fixture',true);
update public.leads set assigned_user_id = '65000000-0000-0000-0000-000000000011',
                        owner_user_id    = '65000000-0000-0000-0000-000000000011',
                        lead_status_code = 'assigned'
where id = '65000000-0000-0000-0000-0000000000e1';
update public.leads set assigned_user_id = '65000000-0000-0000-0000-000000000021',
                        owner_user_id    = '65000000-0000-0000-0000-000000000021',
                        lead_status_code = 'assigned'
where id = '65000000-0000-0000-0000-0000000000e2';

-- =============================================================================================
-- 1. THE CONTROL THAT MAKES EVERY EXCLUSION BELOW MEAN SOMETHING: all six are PLACED here, so
--    none of the refusals is really "that user is somewhere else".
-- =============================================================================================
select is(
  (select count(*)::int from public.user_branch_assignments
    where tenant_id = '65000000-0000-0000-0000-000000000001'
      and branch_id = '65000000-0000-0000-0000-00000000000a'
      and department_id = '65000000-0000-0000-0000-0000000000c1'
      and user_id <> '65000000-0000-0000-0000-000000000011'),
  6,
  'POSITIVE CONTROL: six users besides the handler are PLACED in this branch and department');

-- =============================================================================================
-- 2-4. THE RULE. Eligibility is authority, not proximity.
-- =============================================================================================
select set_eq(
  $$select * from app.eligible_lead_handlers(
      '65000000-0000-0000-0000-000000000001','65000000-0000-0000-0000-00000000000a',
      '65000000-0000-0000-0000-0000000000c1','65000000-0000-0000-0000-000000000011')$$,
  $$values ('65000000-0000-0000-0000-000000000016'::uuid),
           ('65000000-0000-0000-0000-000000000017'::uuid)$$,
  'LEAD-3: of six placed users exactly TWO may work a lead -- the trainee, the finance manager, the deactivated user and the expired role assignment are all excluded');

select ok(
  '65000000-0000-0000-0000-000000000017'::uuid in (
    select * from app.eligible_lead_handlers(
      '65000000-0000-0000-0000-000000000001','65000000-0000-0000-0000-00000000000a',
      '65000000-0000-0000-0000-0000000000c1','65000000-0000-0000-0000-000000000011')),
  'LEAD-3 ANSWERED: a branch_manager IS eligible -- they hold every lead-working permission canon grants');

select is(
  (select count(*)::int from app.eligible_lead_handlers(
      '65000000-0000-0000-0000-000000000002','65000000-0000-0000-0000-00000000000a',
      '65000000-0000-0000-0000-0000000000c1', null)),
  0,
  'NEGATIVE CONTROL: asked on behalf of ANOTHER TENANT the same branch yields nobody');

-- =============================================================================================
-- 5-7. THE BEHAVIOUR. One pass warns both leads; the next reassigns the one that can be rescued.
-- =============================================================================================
select is(
  (select count(*)::int from app.process_lead_sla(interval '0 seconds', interval '999 days')
    where lead_id in ('65000000-0000-0000-0000-0000000000e1','65000000-0000-0000-0000-0000000000e2')
      and action = 'warned'),
  2,
  'both leads are warned, so both reassignment branches below are reachable');

select bag_eq(
  $$select lead_id::text, action from app.process_lead_sla(interval '0 seconds', interval '0 seconds')
     where lead_id in ('65000000-0000-0000-0000-0000000000e1','65000000-0000-0000-0000-0000000000e2')$$,
  $$values ('65000000-0000-0000-0000-0000000000e1','reassigned'),
           ('65000000-0000-0000-0000-0000000000e2','reassignment_blocked')$$,
  'one pass, two outcomes: Cairo is rescued and Alexandria reports that it could not be');

select is(
  (select assigned_user_id from public.leads where id = '65000000-0000-0000-0000-0000000000e1'),
  '65000000-0000-0000-0000-000000000016'::uuid,
  '...to the COLLEAGUE -- not to the trainee, the finance manager, the deactivated user or the expired role, every one of which sorts BEFORE them');

-- =============================================================================================
-- 8-10. THE BLOCKED CASE. Nothing may pretend to have happened.
-- =============================================================================================
select is(
  (select assigned_user_id from public.leads where id = '65000000-0000-0000-0000-0000000000e2'),
  '65000000-0000-0000-0000-000000000021'::uuid,
  'the Alexandria lead STAYS with its assignee -- parking it with someone who cannot act is worse than leaving it');

select is(
  (select count(*)::int from public.notifications
    where related_entity_id = '65000000-0000-0000-0000-0000000000e2'
      and notification_type_code = 'lead_reassigned'),
  0,
  '...and nobody was told it moved, because it did not');

select is(
  (select count(*)::int from public.lead_assignments
    where lead_id = '65000000-0000-0000-0000-0000000000e2'),
  1,
  '...and no assignment history row was written for a reassignment that did not occur');

-- =============================================================================================
-- 11-12. The rescued lead's own bookkeeping still holds -- the guard did not cost the feature.
-- =============================================================================================
select is(
  (select count(*)::int from public.notifications
    where related_entity_id = '65000000-0000-0000-0000-0000000000e1'
      and notification_type_code = 'lead_reassigned'
      and target_user_id = '65000000-0000-0000-0000-000000000016'),
  1,
  'the new assignee is still told the lead is theirs');

select is(
  (select count(*)::int from public.notifications
    where related_entity_id = '65000000-0000-0000-0000-0000000000e1'
      and notification_type_code = 'lead_reassigned'
      and target_user_id = '65000000-0000-0000-0000-000000000017'),
  1,
  'and SLA-1''s manager escalation still fires on the reassignment path');

select finish();
rollback;
