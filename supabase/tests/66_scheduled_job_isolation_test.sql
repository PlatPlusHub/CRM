-- pgTAP: SCHED-2 / CONV-1 -- a scheduled job may lose an item, but never a batch, and never silently.
--
-- Two properties, proven separately because they fail separately:
--
--   CONV-1 (§1-7)  A tenant whose subscription lapses must have its conversions DEFERRED, not
--                  DESTROYED. Reproduced before the fix: the mapper filtered the restricted tenant
--                  out of its set-based INSERT and advanced the cursor past their event anyway, so
--                  restoring the tenant to good standing recovered nothing, on that run or any
--                  later one. Everywhere else in ORVION "a batch skips a lapsed tenant" means
--                  DEFER -- process_lead_sla retries a minute later, platform_resolve_storage_finding
--                  refuses and leaves the finding open. The mapper was the only place it meant
--                  discard, and only because it owns a cursor.
--
--   SCHED-2 (§8-17) One item's failure must not abort the batch, and the failure must survive the
--                  cron invocation that produced it. `app.reconcile_document_storage` already had
--                  both properties; its three siblings had neither.
--
-- A NOTE ON THE INJECTED RAISE. §8 onwards installs a trigger that raises for ONE fixture row. No
-- naturally reachable raise exists in either loop body today -- every write was traced -- so the
-- defect is latent, and a test written against today's reachable raise sources would measure the
-- list rather than the property. The list is what changes; the property is what must hold. The
-- injected raise stands in for any future constraint, trigger or data fault, which is exactly what
-- WP-03 turned out to be: a trigger correct for a user write and dangerous inside a batch.
create extension if not exists pgtap with schema extensions;

begin;
select plan(20);

-- =============================================================================================
-- CONV-1 FIXTURE. Two tenants, one attributed lead each, one conversion-worthy event each.
-- Both created while ACTIVE, because the gate would refuse the fixture itself otherwise -- which
-- is itself a small proof that the gate is real.
-- =============================================================================================
insert into public.tenants (id, name, slug, status) values
  ('66000000-0000-0000-0000-000000000001','Conv Good','sched-good','active'),
  ('66000000-0000-0000-0000-000000000002','Conv Lapsed','sched-lapsed','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active'
from public.subscription_plans sp,
     unnest(array['66000000-0000-0000-0000-000000000001'::uuid,
                  '66000000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('66000000-0000-0000-0000-00000000000a','66000000-0000-0000-0000-000000000001','G','sched-g'),
  ('66000000-0000-0000-0000-00000000000b','66000000-0000-0000-0000-000000000002','L','sched-l');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('66000000-0000-0000-0000-0000000000c1','66000000-0000-0000-0000-000000000001','66000000-0000-0000-0000-00000000000a','sales','GD'),
  ('66000000-0000-0000-0000-0000000000c2','66000000-0000-0000-0000-000000000002','66000000-0000-0000-0000-00000000000b','sales','LD');
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('66000000-0000-0000-0000-0000000000d1','66000000-0000-0000-0000-000000000001','person','CG','+201000000661'),
  ('66000000-0000-0000-0000-0000000000d2','66000000-0000-0000-0000-000000000002','person','CL','+201000000662');
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code, title, lead_status_code) values
  ('66000000-0000-0000-0000-0000000000e1','66000000-0000-0000-0000-000000000001','66000000-0000-0000-0000-00000000000a','66000000-0000-0000-0000-0000000000c1','66000000-0000-0000-0000-0000000000d1','google_ads_call','LG','new'),
  ('66000000-0000-0000-0000-0000000000e2','66000000-0000-0000-0000-000000000002','66000000-0000-0000-0000-00000000000b','66000000-0000-0000-0000-0000000000c2','66000000-0000-0000-0000-0000000000d2','google_ads_call','LL','new');
select app.capture_attribution_click(
    p_tenant_id => '66000000-0000-0000-0000-000000000001',
    p_attribution_source_code => 'google_ads', p_gclid => 'SCHED-G',
    p_lead_id => '66000000-0000-0000-0000-0000000000e1');
select app.capture_attribution_click(
    p_tenant_id => '66000000-0000-0000-0000-000000000002',
    p_attribution_source_code => 'google_ads', p_gclid => 'SCHED-L',
    p_lead_id => '66000000-0000-0000-0000-0000000000e2');
select app.record_event('66000000-0000-0000-0000-000000000001','lead_qualified','lead',
                        '66000000-0000-0000-0000-0000000000e1',null,null,null,'sched fixture',null);
select app.record_event('66000000-0000-0000-0000-000000000002','lead_qualified','lead',
                        '66000000-0000-0000-0000-0000000000e2',null,null,null,'sched fixture',null);

-- The lapse happens AFTER the work exists, which is the real-world order.
update public.subscriptions set subscription_status_code = 'read_only'
where tenant_id = '66000000-0000-0000-0000-000000000002';

select app.map_outcomes_to_conversions(500);

-- =============================================================================================
-- 1-4. RUN 1: the good tenant maps, the lapsed tenant does not, and the skip is RECORDED.
-- =============================================================================================
select is(
  (select count(*)::int from public.offline_conversions
    where tenant_id = '66000000-0000-0000-0000-000000000001'),
  1,
  'POSITIVE CONTROL: the mapper works -- the good tenant''s conversion is recorded');

select is(
  (select count(*)::int from public.offline_conversions
    where tenant_id = '66000000-0000-0000-0000-000000000002'),
  0,
  'the LAPSED tenant''s conversion is not written -- the subscription gate still applies');

select is(
  (select count(*)::int from public.scheduled_job_findings
    where job_name = 'map_outcomes_to_conversions'
      and finding_type_code = 'item_deferred'
      and tenant_id = '66000000-0000-0000-0000-000000000002'
      and resolved_at is null),
  1,
  'CONV-1: ...and the skip is RECORDED as deferred work -- the half that did not exist');

select cmp_ok(
  (select last_seq from public.integration_cursors where name = 'outcome_conversion_mapper'),
  '>=',
  (select e.seq from public.events e
    where e.entity_id = '66000000-0000-0000-0000-0000000000e2'
      and e.event_type_code = 'lead_qualified'),
  '...while the cursor still ADVANCES past it -- one tenant''s lapse must not block every other tenant');

-- =============================================================================================
-- 5-7. THE TENANT RETURNS TO GOOD STANDING. This is where the conversion used to stay lost.
-- =============================================================================================
update public.subscriptions set subscription_status_code = 'active'
where tenant_id = '66000000-0000-0000-0000-000000000002';

select app.map_outcomes_to_conversions(500);

select is(
  (select count(*)::int from public.offline_conversions
    where tenant_id = '66000000-0000-0000-0000-000000000002'),
  1,
  'CONV-1 FIXED: the recovered tenant''s conversion is mapped on the next run -- deferred, not destroyed');

select is(
  (select count(*)::int from public.scheduled_job_findings
    where job_name = 'map_outcomes_to_conversions'
      and tenant_id = '66000000-0000-0000-0000-000000000002'
      and resolved_at is null),
  0,
  '...and the deferral is resolved, so the recovery does not repeat forever');

select app.map_outcomes_to_conversions(500);
select is(
  (select count(*)::int from public.offline_conversions
    where tenant_id = '66000000-0000-0000-0000-000000000002'),
  1,
  '...and a third run adds nothing -- recovery is idempotent on source_event_seq');

-- =============================================================================================
-- 8-13. SCHED-2a: one lead's failure must not abort every tenant's SLA automation.
-- =============================================================================================
insert into auth.users (id, email) values
  ('66000000-0000-0000-0000-0000000000f1','g@sched.test'),
  ('66000000-0000-0000-0000-0000000000f2','l@sched.test');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('66000000-0000-0000-0000-000000000011','66000000-0000-0000-0000-000000000001','GH','g@sched.test',true,'66000000-0000-0000-0000-0000000000f1'),
  ('66000000-0000-0000-0000-000000000012','66000000-0000-0000-0000-000000000002','LH','l@sched.test',true,'66000000-0000-0000-0000-0000000000f2');
insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assignment_reason, is_current) values
  ('66000000-0000-0000-0000-000000000001','66000000-0000-0000-0000-0000000000e1','66000000-0000-0000-0000-000000000011','sched fixture',true),
  ('66000000-0000-0000-0000-000000000002','66000000-0000-0000-0000-0000000000e2','66000000-0000-0000-0000-000000000012','sched fixture',true);
update public.leads set assigned_user_id = '66000000-0000-0000-0000-000000000011',
                        owner_user_id    = '66000000-0000-0000-0000-000000000011',
                        lead_status_code = 'assigned'
where id = '66000000-0000-0000-0000-0000000000e1';
update public.leads set assigned_user_id = '66000000-0000-0000-0000-000000000012',
                        owner_user_id    = '66000000-0000-0000-0000-000000000012',
                        lead_status_code = 'assigned'
where id = '66000000-0000-0000-0000-0000000000e2';

-- The injected raise. See the file header: this stands in for ANY raise, because the property under
-- test is isolation, not today's list of raise sources.
create function pg_temp.poison_notification() returns trigger language plpgsql as $p$
begin
    if new.related_entity_id = '66000000-0000-0000-0000-0000000000e2' then
        raise exception 'injected failure for the poison lead' using errcode = 'XX000';
    end if;
    return new;
end $p$;
create trigger sched_poison before insert on public.notifications
    for each row execute function pg_temp.poison_notification();

select lives_ok(
  $$select * from app.process_lead_sla(interval '0 seconds', interval '999 days')$$,
  'SCHED-2a: the pass COMPLETES although one lead raises -- before this, the raise aborted every tenant');

select is(
  (select count(*)::int from public.notifications
    where related_entity_id = '66000000-0000-0000-0000-0000000000e1'
      and notification_type_code = 'lead_sla_warning'),
  1,
  'POSITIVE CONTROL: the HEALTHY tenant''s lead was warned -- the pass survived by working, not by doing nothing');

select is(
  (select count(*)::int from public.notifications
    where related_entity_id = '66000000-0000-0000-0000-0000000000e2'),
  0,
  '...and the poisoned lead produced nothing, so the isolation rolled its work back rather than half-applying it');

select is(
  (select sqlstate from public.scheduled_job_findings
    where job_name = 'process_lead_sla' and finding_type_code = 'item_failed'
      and entity_id = '66000000-0000-0000-0000-0000000000e2'),
  'XX000',
  'SCHED-2a: the failure SURVIVES the cron invocation, with the sqlstate that caused it');

drop trigger sched_poison on public.notifications;
select app.process_lead_sla(interval '0 seconds', interval '999 days');

select is(
  (select count(*)::int from public.notifications
    where related_entity_id = '66000000-0000-0000-0000-0000000000e2'
      and notification_type_code = 'lead_sla_warning'),
  1,
  'the next pass RECOVERS the previously failing lead -- retry is automatic and needs no operator');

select is(
  (select count(*)::int from public.scheduled_job_findings
    where job_name = 'process_lead_sla' and finding_type_code = 'item_failed'
      and entity_id = '66000000-0000-0000-0000-0000000000e2' and resolved_at is null),
  0,
  '...and the finding self-heals, exactly as reconcile_document_storage''s tenant_scan_failed does');

-- =============================================================================================
-- 14-17. SCHED-2b: the same property for the subscription lifecycle, which had NO isolation at all.
-- =============================================================================================
update public.subscriptions
   set subscription_status_code = 'trial', ends_at = now() - interval '1 day'
 where tenant_id in ('66000000-0000-0000-0000-000000000001','66000000-0000-0000-0000-000000000002');

create function pg_temp.poison_subscription() returns trigger language plpgsql as $p$
begin
    if new.tenant_id = '66000000-0000-0000-0000-000000000002' then
        raise exception 'injected failure for the poison subscription' using errcode = 'XX000';
    end if;
    return new;
end $p$;
create trigger sched_poison_sub before update on public.subscriptions
    for each row execute function pg_temp.poison_subscription();

select lives_ok(
  $$select app.process_subscription_lifecycle()$$,
  'SCHED-2b: the lifecycle run COMPLETES although one tenant raises');

select is(
  (select subscription_status_code from public.subscriptions
    where tenant_id = '66000000-0000-0000-0000-000000000001'),
  'expired',
  'POSITIVE CONTROL: the healthy tenant''s trial DID expire -- subscription state gates every write, so a stalled lifecycle keeps lapsed tenants writable');

select is(
  (select subscription_status_code from public.subscriptions
    where tenant_id = '66000000-0000-0000-0000-000000000002'),
  'trial',
  '...and the poisoned tenant was left untouched rather than half-transitioned');

select is(
  (select sqlstate from public.scheduled_job_findings
    where job_name = 'process_subscription_lifecycle' and finding_type_code = 'item_failed'
      and tenant_id = '66000000-0000-0000-0000-000000000002'),
  'XX000',
  'SCHED-2b: and its failure is discoverable after the cron invocation ended');

drop trigger sched_poison_sub on public.subscriptions;

-- =============================================================================================
-- 18-20. THE READER, AND ITS BOUNDARY. Operational state is not a tenant surface.
-- =============================================================================================
select is(
  (select open_items::int from app.scheduled_job_health()
    where job_name = 'process_subscription_lifecycle' and finding_type_code = 'item_failed'),
  1,
  'app.scheduled_job_health() reports the outstanding item -- what failed, for which job');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"66000000-0000-0000-0000-0000000000f1"}', true);

select throws_ok(
  $$select * from public.scheduled_job_health()$$,
  '42501',
  null,
  'an authenticated tenant user CANNOT read platform operational health -- same boundary as storage_action_backlog');

-- Note the error class: this is a GRANT refusal, not an empty RLS result. The deny-all policy is
-- the statement of intent (SPEC-158's shape); the absent grant is what actually stops the read.
-- SEC-1's preference exactly -- remove unnecessary access rather than invent a permission for it.
select throws_ok(
  $$select count(*) from public.scheduled_job_findings$$,
  '42501',
  null,
  'NEGATIVE CONTROL: ...and the findings table is not even granted to a tenant user, though rows exist');

select finish();
rollback;
