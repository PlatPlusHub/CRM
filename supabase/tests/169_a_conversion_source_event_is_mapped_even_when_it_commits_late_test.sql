-- pgTAP: Batch 6 slice 52 (events, CONV-11) --
-- a conversion source event is mapped even when it commits after a later one (`20261114160000`).
-- ATTACK-CLASSES: AUTH=N/A TENANT=N/A DOOR=N/A STATE=N/A INPUT=N/A CONCURRENCY REPLAY PRIVILEGE=N/A BUSINESS OBSERVABILITY=N/A
--   AUTH, TENANT, DOOR, PRIVILEGE=N/A -- no authority changes: `record_event` keeps its tenant and actor rules
--     (test 34), and the mapper stays platform-only (tests 36, 66, 119).
--   STATE, INPUT=N/A -- no column, value or lifecycle changes; the mapper's window and deferral are tests 36, 66, 137-142.
--   OBSERVABILITY=N/A -- a skipped run records nothing by design: it is retried from the same cursor.
--   CONCURRENCY -- the defect needs two live sessions, which pgTAP does not have. It is proven by slice 52's
--     two-session harness with and without the repair (a source seq still open when the mapper ran is mapped by the
--     next run); here the lock it rests on is pinned: who takes it, in which form, and that the mapper releases it.
--   REPLAY -- a second run adds nothing (the source seq is the idempotency key, unchanged).
create extension if not exists pgtap with schema extensions;

begin;
select plan(10);

insert into public.tenants (id, name, slug, status) values
  ('16900000-0000-0000-0000-000000000001','Mapper Travel','mapper-travel-169','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '16900000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('16900000-0000-0000-0000-00000000000a','16900000-0000-0000-0000-000000000001','Giza','giza-169');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('16900000-0000-0000-0000-0000000000c1','16900000-0000-0000-0000-000000000001','16900000-0000-0000-0000-00000000000a','sales','Giza Sales');
-- A Google Ads call lead: its qualification forms a conversion with no click (PH8-4).
insert into public.leads (id, tenant_id, branch_id, department_id, lead_source_code, lead_status_code, title) values
  ('16900000-0000-0000-0000-0000000000e1','16900000-0000-0000-0000-000000000001','16900000-0000-0000-0000-00000000000a','16900000-0000-0000-0000-0000000000c1','google_ads_call','new','Call lead');

-- The lock, as `pg_locks` names a bigint advisory key.
create function pg_temp.held(p_mode text) returns int language sql as $$
  select count(*)::int from pg_locks
   where locktype = 'advisory' and pid = pg_backend_pid() and mode = p_mode and objsubid = 1
     and classid::bigint = ((hashtextextended('app.map_outcomes_to_conversions', 0) >> 32) & 4294967295)
     and objid::bigint = (hashtextextended('app.map_outcomes_to_conversions', 0) & 4294967295) $$;

select is(pg_temp.held('ShareLock'), 0, 'the fixture took no source lock');

select app.record_event('16900000-0000-0000-0000-000000000001', 'lead_contacted', 'lead',
                        '16900000-0000-0000-0000-0000000000e1');
select is(pg_temp.held('ShareLock'), 0, 'an event that is no conversion source takes no lock');

select app.record_event('16900000-0000-0000-0000-000000000001', 'lead_qualified', 'lead',
                        '16900000-0000-0000-0000-0000000000e1');
select is(pg_temp.held('ShareLock'), 1, 'a conversion source event is recorded under the shared form of the mapper''s lock, held to commit');

select ok(
  (select prosrc from pg_proc where oid = 'app.record_event(uuid,text,text,uuid,uuid,text,text,text,jsonb,text)'::regprocedure)
    ~ $re$if p_event_type_code in \('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued'\) then\s+perform pg_advisory_xact_lock_shared\(hashtextextended\('app\.map_outcomes_to_conversions', 0\)\);$re$,
  'exactly the four source types the mapper reads take it');

select ok(
  (select prosrc from pg_proc where oid = 'app.map_outcomes_to_conversions(integer)'::regprocedure)
    ~ $re$if not pg_try_advisory_lock\(hashtextextended\('app\.map_outcomes_to_conversions', 0\)\) then\s+return 0;$re$,
  'the mapper takes the exclusive form without waiting, and maps nothing when a source writer is open');

select is(
  (select count(*)::int from regexp_matches(
     (select prosrc from pg_proc where oid = 'app.map_outcomes_to_conversions(integer)'::regprocedure),
     'and e\.seq <= v_horizon', 'g')),
  2, 'both reads of the forward window stop at the horizon');

-- In this one transaction the source writer is the mapper's own session, so the lock is granted.
select is(app.map_outcomes_to_conversions(100000) >= 1, true, 'the mapper runs');
select is(
  (select count(*)::int from public.offline_conversions
   where tenant_id = '16900000-0000-0000-0000-000000000001' and lead_id = '16900000-0000-0000-0000-0000000000e1'
     and conversion_event_type_code = 'qualified_phone_call'),
  1, 'the qualification is mapped once');
select is(pg_temp.held('ExclusiveLock'), 0, 'the mapper released its lock: no source writer waits on it');

select is(app.map_outcomes_to_conversions(100000), 0, 'REPLAY: a second run adds nothing');

select * from finish();
rollback;
