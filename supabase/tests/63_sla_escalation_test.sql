-- pgTAP: SLA-1 -- the manager escalation canon makes MANDATORY, proven to fire.
--
-- canon 04 § SLA Escalation Rule and canon 10 § Lead Notifications both require the employee's
-- MANAGER to be notified at 15 minutes, and again on reassignment at 30. canon 10 lists "Manager
-- escalation" among the notifications a user cannot mute. It never fired.
--
-- The reason it never fired is the shape this programme keeps meeting: `app.process_lead_sla` asked
-- `user_role_assignments.branch_id / department_id` alone, while ORVION's authoritative definition
-- of governance -- `app.visible_branch_ids()` / `app.visible_department_ids()` -- is a UNION that
-- also includes the manager's `user_branch_assignments` PLACEMENT. `app.assign_user_role` defaults
-- to `scope_type = 'tenant'` with both scope columns NULL, so for every role assignment ORVION's own
-- RPC creates, the old predicate was `NULL = uuid` -- never true.
--
-- Assertion 1 is what makes the rest meaningful: the manager CAN see the lead. A "was not notified"
-- result against a manager who could not see the lead anyway would prove nothing, and a "now is
-- notified" result would not prove the right person was reached.
--
-- Assertion 5 is the other half of the same discipline: widening a scope test is only correct if it
-- did not widen into "notify every manager in the tenant".
--
-- A NOTE ON THE FIXTURE, because the first version of this file passed assertion 10 for the WRONG
-- REASON. `app.process_lead_sla`'s reassignment pool is "everyone placed in the branch/department",
-- which includes the MANAGERS -- and with no prior assignments the tie breaks on `u.id asc`, so the
-- lead went to the branch manager. Their "reassigned to you" notice then satisfied an assertion that
-- claimed to be counting manager escalations. The colleague is therefore given the LOWEST id here so
-- the round robin picks them deterministically and the two roles never overlap.
--
-- Whether a manager belongs in that pool at all is a separate, genuinely open question -- canon 04
-- says "reassign to another eligible employee" and defines neither "eligible" nor whether a manager
-- qualifies. It is recorded as LEAD-3 and deliberately NOT changed here: this migration is about who
-- is NOTIFIED, not about who receives the work.
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

insert into auth.users (id, email) values
  ('63000000-0000-0000-0000-0000000000a1','emp@sla.test'),
  ('63000000-0000-0000-0000-0000000000a2','bm@sla.test'),
  ('63000000-0000-0000-0000-0000000000a3','dm@sla.test'),
  ('63000000-0000-0000-0000-0000000000a4','other@sla.test'),
  ('63000000-0000-0000-0000-0000000000a5','emp2@sla.test');
insert into public.tenants (id, name, slug, status) values
  ('63000000-0000-0000-0000-000000000001','SLA Travel','sla-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '63000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('63000000-0000-0000-0000-00000000000a','63000000-0000-0000-0000-000000000001','Cairo','sla-cairo'),
  ('63000000-0000-0000-0000-00000000000b','63000000-0000-0000-0000-000000000001','Alex','sla-alex');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('63000000-0000-0000-0000-0000000000c1','63000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-00000000000a','sales','Cairo Sales'),
  ('63000000-0000-0000-0000-0000000000c2','63000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-00000000000b','sales','Alex Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('63000000-0000-0000-0000-000000000011','63000000-0000-0000-0000-000000000001','Handler','emp@sla.test',true,'63000000-0000-0000-0000-0000000000a1'),
  ('63000000-0000-0000-0000-000000000012','63000000-0000-0000-0000-000000000001','Branch Manager','bm@sla.test',true,'63000000-0000-0000-0000-0000000000a2'),
  ('63000000-0000-0000-0000-000000000013','63000000-0000-0000-0000-000000000001','Dept Manager','dm@sla.test',true,'63000000-0000-0000-0000-0000000000a3'),
  ('63000000-0000-0000-0000-000000000014','63000000-0000-0000-0000-000000000001','Other Branch Manager','other@sla.test',true,'63000000-0000-0000-0000-0000000000a4'),
  ('63000000-0000-0000-0000-000000000010','63000000-0000-0000-0000-000000000001','Colleague','emp2@sla.test',true,'63000000-0000-0000-0000-0000000000a5');

-- Cairo: handler, both managers, and a second employee for the reassignment to land on.
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '63000000-0000-0000-0000-000000000001', u, '63000000-0000-0000-0000-00000000000a','63000000-0000-0000-0000-0000000000c1', true
from unnest(array['63000000-0000-0000-0000-000000000011'::uuid,'63000000-0000-0000-0000-000000000012'::uuid,
                  '63000000-0000-0000-0000-000000000013'::uuid,'63000000-0000-0000-0000-000000000010'::uuid]) u;
-- Alexandria: a manager of the SAME roles who governs a DIFFERENT branch.
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
values ('63000000-0000-0000-0000-000000000001','63000000-0000-0000-0000-000000000014',
        '63000000-0000-0000-0000-00000000000b','63000000-0000-0000-0000-0000000000c2', true);

-- TENANT-scoped roles throughout: exactly what `app.assign_user_role` produces by default, and the
-- configuration under which the defect was reproduced.
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '63000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('63000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('63000000-0000-0000-0000-000000000012'::uuid,'branch_manager'),
             ('63000000-0000-0000-0000-000000000013'::uuid,'department_manager'),
             ('63000000-0000-0000-0000-000000000014'::uuid,'branch_manager'),
             ('63000000-0000-0000-0000-000000000010'::uuid,'employee')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('63000000-0000-0000-0000-0000000000d1','63000000-0000-0000-0000-000000000001','person','SLA Customer','+201000000063');
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code, title, lead_status_code)
values ('63000000-0000-0000-0000-0000000000e1','63000000-0000-0000-0000-000000000001',
        '63000000-0000-0000-0000-00000000000a','63000000-0000-0000-0000-0000000000c1',
        '63000000-0000-0000-0000-0000000000d1','direct_call','SLA lead','new');

-- Assigned through the real RPC, by the manager, because assignment is supervisory.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"63000000-0000-0000-0000-0000000000a2"}', true);
select app.assign_lead('63000000-0000-0000-0000-0000000000e1','63000000-0000-0000-0000-000000000011','SLA fixture');

-- =============================================================================================
-- 1. THE CONTROL THAT MAKES EVERYTHING BELOW MEAN SOMETHING.
-- =============================================================================================
select is(
  (select count(*)::int from public.leads where id = '63000000-0000-0000-0000-0000000000e1'),
  1,
  'POSITIVE CONTROL: the branch manager CAN see the lead -- so "not notified" was never about reach');

-- =============================================================================================
-- 2-5. THE WARNING PATH. Zero warn window, distant reassign window, so only the warning runs and
--      no assignment history is touched (it is immutable, and correctly so).
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select count(*)::int from app.process_lead_sla(interval '0 seconds', interval '999 days')
    where lead_id = '63000000-0000-0000-0000-0000000000e1' and action = 'warned'),
  1,
  'the lead is warned exactly once by the pass');

select is(
  (select count(*)::int from public.notifications
    where related_entity_id = '63000000-0000-0000-0000-0000000000e1'
      and target_user_id = '63000000-0000-0000-0000-000000000011'
      and notification_type_code = 'lead_sla_warning'),
  1,
  'the ASSIGNED EMPLOYEE is notified exactly once -- canon 04, and unchanged by this migration');

select is(
  (select count(*)::int from public.notifications
    where related_entity_id = '63000000-0000-0000-0000-0000000000e1'
      and target_user_id in ('63000000-0000-0000-0000-000000000012','63000000-0000-0000-0000-000000000013')
      and notification_type_code = 'lead_sla_warning'),
  2,
  'SLA-1: BOTH managers of the lead''s branch and department are notified -- the canon-mandated escalation that never fired');

select is(
  (select count(*)::int from public.notifications
    where related_entity_id = '63000000-0000-0000-0000-0000000000e1'
      and target_user_id = '63000000-0000-0000-0000-000000000014'),
  0,
  'NEGATIVE CONTROL: a branch_manager who governs ANOTHER branch is NOT notified -- the scope test was widened, not removed');

-- =============================================================================================
-- 6-7. Existing behaviour that must survive: one event, and no repeat warning on a second pass.
-- =============================================================================================
select is(
  (select count(*)::int from public.events
    where entity_id = '63000000-0000-0000-0000-0000000000e1' and event_type_code = 'lead_sla_warning'),
  1,
  'exactly one lead_sla_warning EVENT -- the notification fan-out did not multiply the audit record');

select is(
  (select count(*)::int from app.process_lead_sla(interval '0 seconds', interval '999 days')
    where lead_id = '63000000-0000-0000-0000-0000000000e1'),
  0,
  'a second pass warns nothing -- the already-warned guard still holds, so managers are not spammed every minute');

-- =============================================================================================
-- 8-9. THE REASSIGNMENT PATH. canon 10: "Notify reassigned employee. NOTIFY MANAGER." The manager
--      half was absent entirely -- not mis-scoped, simply not written.
-- =============================================================================================
select is(
  (select count(*)::int from app.process_lead_sla(interval '0 seconds', interval '0 seconds')
    where lead_id = '63000000-0000-0000-0000-0000000000e1' and action = 'reassigned'),
  1,
  'the overdue lead is reassigned once the reassign window passes');

-- Pinned so the assertions below cannot be satisfied by the new assignee's own notification.
select is(
  (select assigned_user_id from public.leads where id = '63000000-0000-0000-0000-0000000000e1'),
  '63000000-0000-0000-0000-000000000010'::uuid,
  '...to the COLLEAGUE, not to a manager -- the fixture pins the round robin so the next two assertions cannot overlap');

select is(
  (select count(*)::int from public.notifications
    where related_entity_id = '63000000-0000-0000-0000-0000000000e1'
      and notification_type_code = 'lead_reassigned'
      and target_user_id = '63000000-0000-0000-0000-000000000010'),
  1,
  'the NEW assignee is told the lead is theirs -- existing behaviour, preserved');

select is(
  (select count(*)::int from public.notifications
    where related_entity_id = '63000000-0000-0000-0000-0000000000e1'
      and notification_type_code = 'lead_reassigned'
      and target_user_id in ('63000000-0000-0000-0000-000000000012','63000000-0000-0000-0000-000000000013')),
  2,
  '...and BOTH managers are told it was reassigned -- canon 10''s second half, which had no code at all');

-- =============================================================================================
-- LEAD-5 (202607060800). THE JOB MUST NOT OVERLAP ITSELF.
--
-- `cron.job` schedules this at `* * * * *` and pg_cron does NOT wait for the previous pass, so any
-- pass exceeding sixty seconds runs concurrently with its successor. The REASSIGNMENT branch is
-- already protected by a constraint -- `lead_assignments_one_current_idx` is UNIQUE on (lead_id)
-- WHERE is_current, so a second concurrent reassignment cannot commit. The WARNING branch has no
-- such constraint: it reads whether a warning exists, then writes an event and one notification per
-- responsible manager, and two passes that read before either writes both do it.
--
-- WHAT IS AND IS NOT PROVEN HERE, stated rather than implied. pgTAP runs in ONE session and ONE
-- transaction, so genuine concurrency is not reproducible in this file and nothing below claims it.
-- What IS proven is the mechanism, behaviourally rather than by reading the source: the function
-- takes a TRANSACTION-SCOPED advisory lock on the key naming the job. Transaction-scoped means it is
-- still held now, three passes later, and therefore visible in `pg_locks`. Matching the exact key
-- rather than merely counting locks is what makes this assertion specific -- an unrelated advisory
-- lock taken by some other function would not satisfy it.
--
-- The key encoding is PostgreSQL's own: the single-argument bigint form stores the high word in
-- `classid`, the low word in `objid`, and sets `objsubid` to 1.
-- =============================================================================================
select is(
  (select count(*)::int from pg_locks l
    where l.locktype = 'advisory'
      and l.pid = pg_backend_pid()
      and l.objsubid = 1
      and l.classid = ((hashtextextended('app.process_lead_sla', 0) >> 32) & 4294967295)::oid
      and l.objid   =  (hashtextextended('app.process_lead_sla', 0)        & 4294967295)::oid),
  1,
  'LEAD-5: the SLA pass holds a transaction-scoped ADVISORY LOCK keyed on the job -- a second overlapping pass takes the TRY and returns, so the warning branch cannot double-write');

select finish();
rollback;
