-- pgTAP: SCHED-1 (partial) -- the executor's backlog is measurable, and it measures what the
-- executor actually consumes.
--
-- The storage executor exists, is ACTIVE, and is proven end to end over HTTP -- but nothing invokes
-- it on a schedule, and every route to fixing that needs one owner-placed secret. What needed no
-- decision was making the gap VISIBLE: without this, an executor that never runs (or runs and then
-- breaks) simply leaves bytes on disk and says nothing.
--
-- The assertion that matters most is 3. A monitor that measures a DIFFERENT population than the
-- worker consumes is worse than no monitor, because it reports zero while work piles up. So
-- `app.storage_action_backlog` calls `app.claim_storage_actions` rather than restating its rules,
-- and this file proves the two agree -- including on the RET-2 exclusion, where they could most
-- easily have drifted apart.
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into public.tenants (id, name, slug, status) values
  ('60000000-0000-0000-0000-00000000000a','Backlog A','backlog-a','active'),
  ('60000000-0000-0000-0000-00000000000b','Backlog B','backlog-b','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from (values ('60000000-0000-0000-0000-00000000000a'::uuid),('60000000-0000-0000-0000-00000000000b'::uuid)) t(id)
cross join public.subscription_plans sp where sp.plan_code = 'enterprise';

-- One document per tenant, each with a superseded v1 and a current v2. v1 is the destroyable one.
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code, is_confidential)
values ('60000000-0000-0000-0000-0000000000d1','60000000-0000-0000-0000-00000000000a','other','A doc','active',false),
       ('60000000-0000-0000-0000-0000000000d2','60000000-0000-0000-0000-00000000000b','other','B doc','active',false);
insert into public.document_versions (id, tenant_id, document_id, version_number, file_name, file_type_code, storage_path, is_current, uploaded_at)
values ('60000000-0000-0000-0000-0000000000f1','60000000-0000-0000-0000-00000000000a','60000000-0000-0000-0000-0000000000d1',1,'a1.pdf','pdf','60000000-0000-0000-0000-00000000000a/d1/1',false, now() - interval '400 days'),
       ('60000000-0000-0000-0000-0000000000f2','60000000-0000-0000-0000-00000000000a','60000000-0000-0000-0000-0000000000d1',2,'a2.pdf','pdf','60000000-0000-0000-0000-00000000000a/d1/2',true,  now()),
       ('60000000-0000-0000-0000-0000000000f3','60000000-0000-0000-0000-00000000000b','60000000-0000-0000-0000-0000000000d2',1,'b1.pdf','pdf','60000000-0000-0000-0000-00000000000b/d2/1',false, now() - interval '400 days'),
       ('60000000-0000-0000-0000-0000000000f4','60000000-0000-0000-0000-00000000000b','60000000-0000-0000-0000-0000000000d2',2,'b2.pdf','pdf','60000000-0000-0000-0000-00000000000b/d2/2',true,  now());
update public.documents set current_version_id = '60000000-0000-0000-0000-0000000000f2' where id = '60000000-0000-0000-0000-0000000000d1';
update public.documents set current_version_id = '60000000-0000-0000-0000-0000000000f4' where id = '60000000-0000-0000-0000-0000000000d2';

-- =============================================================================================
-- 1-2. THE DEFAULT IS SILENCE, AND THAT IS CORRECT. Retention is an open business decision
--      (RET-1): `app.document_retention_days()` returns NULL, which means retain forever. Nothing
--      is destroyable, so nothing is outstanding -- and the monitor must say zero rather than
--      inventing work.
-- =============================================================================================
select is(
  (select pending_actions from app.storage_action_backlog()),
  0,
  'with retention undecided, there is no backlog -- the monitor does not manufacture work from a null policy');

select is(
  (select count(*)::int from app.claim_storage_actions(500)),
  0,
  'CONTROL: and the executor would claim nothing either -- the two agree at zero as well as above it');

-- =============================================================================================
-- 3-6. THE DAY THE BUSINESS DECIDES. One line changes, and both the worker and the monitor must
--      see the SAME work appear. This is the assertion the whole function exists for.
-- =============================================================================================
-- RET-1 (`202607060500`): retention is now a POLICY ROW, not a redefined function. This inserts a
-- 30-day policy for every (tenant, document_type) present in this test and rolls back with the
-- transaction -- so the suite no longer MUTATES THE SCHEMA IT TESTS, which was PAR-2's hazard.
insert into public.document_retention_policies (tenant_id, document_type_code, retention_days)
select distinct d.tenant_id, d.document_type_code, 30 from public.documents d
on conflict (tenant_id, document_type_code) do update set retention_days = 30;

select app.reconcile_document_storage();

select is(
  (select pending_actions from app.storage_action_backlog()),
  (select count(*)::int from app.claim_storage_actions(500)),
  'THE POINT: the monitor counts exactly what the executor would claim -- one definition of outstanding work, not two');

select cmp_ok(
  (select pending_actions from app.storage_action_backlog()),
  '>=', 2,
  '...and it is a real number: both tenants have a destroyable superseded version');

-- The age is what distinguishes "running" from "never ran". A count alone cannot: a healthy system
-- with work in flight and a dead one both report a positive count.
update public.document_storage_findings
   set first_seen_at = now() - interval '9 days'
 where finding_type_code = 'retention_expired';

select cmp_ok(
  (select oldest_pending_age from app.storage_action_backlog()),
  '>', interval '8 days',
  'the OLDEST outstanding action carries its age -- the only signal that separates "in flight" from "nobody is running this"');

select is(
  (select unresolved_findings from app.storage_action_backlog()),
  (select count(*)::int from public.document_storage_findings where resolved_at is null),
  'unresolved_findings is the wider number and is reported separately -- not every finding is executable work');

-- =============================================================================================
-- 7-8. FND-1's CONTRACT, VISIBLE. A failed attempt must keep the work outstanding AND become
--      countable, otherwise a permanently-failing action looks identical to a healthy queue.
-- =============================================================================================
select lives_ok(
  $$select app.platform_resolve_storage_finding(
      (select id from public.document_storage_findings
        where finding_type_code = 'retention_expired'
          and tenant_id = '60000000-0000-0000-0000-00000000000a'),
      'failed', 'simulated storage outage')$$,
  'the executor reports a failure');

select is(
  (select attempted_and_failed from app.storage_action_backlog()),
  1,
  '...and it is STILL outstanding, now counted as attempted -- a failing action must not look like a healthy queue');

-- =============================================================================================
-- 9. RET-2 APPLIED IN BOTH PLACES, which is exactly where a hand-written monitor would drift.
--    A restricted tenant's data is frozen, so its actions are not claimable -- and must not be
--    reported as outstanding work either, or the platform would chase work it cannot do.
-- =============================================================================================
update public.subscriptions set subscription_status_code = 'suspended'
 where tenant_id = '60000000-0000-0000-0000-00000000000b';

select is(
  (select pending_actions from app.storage_action_backlog()),
  (select count(*)::int from app.claim_storage_actions(500)),
  'suspending a tenant removes its work from the executor AND from the monitor, together');

-- =============================================================================================
-- 10-11. EXPOSURE. Platform operational state is not a tenant surface, and certainly not a public
--        one: how far behind ORVION is should not be probeable by an anonymous caller.
-- =============================================================================================
select is(
  (select count(*)::int
     from unnest(array['anon','authenticated']) as r(role)
    where has_function_privilege(r.role, 'public.storage_action_backlog()', 'EXECUTE')),
  0,
  'neither anon nor authenticated may call the backlog endpoint');

select ok(
  has_function_privilege('service_role', 'public.storage_action_backlog()', 'EXECUTE'),
  'POSITIVE CONTROL: service_role can -- the endpoint exists and is reachable by the platform');

select finish();
rollback;
