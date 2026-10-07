-- pgTAP: PH8-9 -- a Google Data Manager ingestion acknowledgement is not a delivery. A delivery
-- carries Google's request identity while Google processes it, is never re-claimed or lease-swept
-- meanwhile, and becomes `sent` only on Google's terminal SUCCESS for that request.
--
-- ATTACK-CLASSES: BUSINESS REPLAY STATE INPUT PRIVILEGE TENANT DOOR OBSERVABILITY AUTH=N/A CONCURRENCY=N/A
--   AUTH=N/A -- these RPCs belong to the integration role, which has no session; `authenticated`
--     cannot execute them (assertion 2).
--   CONCURRENCY=N/A -- pgTAP runs one session. Every transition locks the delivery row and judges
--     its state under the lock; the two-session proofs (two workers resolving one request, an
--     ingestion committed and read back by a new connection) are recorded in SPEC-243.
--
-- THE FIXTURE, built as the platform (no session), the way the integration role meets it. Two
-- tenants; every click-path conversion carries a consented click. Conversions are inserted
-- directly so that each one isolates one rule; the mapper's own production of all five types is
-- Test 137's and Test 142's, which run unchanged against this claim.
--   k1  qualified_lead        -> ingested, PROCESSING, UNKNOWN, SUCCESS: the one path to `sent`
--   k2  qualified_phone_call  -> customer consent granted: claimed
--   k3  booking_created       -> FAILED, re-claimed under the same transaction identity
--   k4  payment_received      -> value 100 EGP
--   k5  ticket_issued         <- `booking_issued` of booking B1          (the issue)
--   k6  ticket_issued         <- a second `booking_issued` of B1         (the reissue)
--   k7  ticket_issued         <- `booking_issued` of booking B2
--   k8  qualified_phone_call  -> no consent record: never claimed
--   k9  qualified_lead        -> Google ingested it, the run died before recording: lease
--   k10 qualified_lead        -> PARTIAL_SUCCESS
--   k11 qualified_lead        -> Google never resolves it: deadline
--   k12 qualified_lead        -> a material `fieldWarnings` entry
--   k13 qualified_lead        -> a `validateOnly` run, then the retry ceiling
--   m1  qualified_lead        (tenant two)
-- The ticket conversions' own `booking_id` is left NULL on purpose: the transaction identity is
-- read from the append-only source event, never from that updatable column.
create extension if not exists pgtap with schema extensions;

begin;
select plan(45);

do $$ begin perform set_config('request.jwt.claims', null, true); end $$;

insert into public.tenants (id,name,slug,status) values
  ('14300000-0000-0000-0000-000000000001','PH143 Travel','ph143-travel','active'),
  ('14300000-0000-0000-0000-000000000002','PH143 Other','ph143-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['14300000-0000-0000-0000-000000000001'::uuid,'14300000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('14300000-0000-0000-0000-00000000000a','14300000-0000-0000-0000-000000000001','Cairo','ph143-cairo'),
  ('14300000-0000-0000-0000-00000000000b','14300000-0000-0000-0000-000000000002','Giza','ph143-giza');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('14300000-0000-0000-0000-0000000000c1','14300000-0000-0000-0000-000000000001','14300000-0000-0000-0000-00000000000a','sales','Sales'),
  ('14300000-0000-0000-0000-0000000000c2','14300000-0000-0000-0000-000000000002','14300000-0000-0000-0000-00000000000b','sales','Sales');
insert into public.customers (id,tenant_id,customer_type_code,full_name,primary_phone,primary_email) values
  ('14300000-0000-0000-0000-0000000000d1','14300000-0000-0000-0000-000000000001','person','Buyer','+201000014301','buyer@ph143.test'),
  ('14300000-0000-0000-0000-0000000000d2','14300000-0000-0000-0000-000000000001','person','Caller','+201000014302',null),
  ('14300000-0000-0000-0000-0000000000d3','14300000-0000-0000-0000-000000000001','person','Silent','+201000014303',null),
  ('14300000-0000-0000-0000-0000000000d4','14300000-0000-0000-0000-000000000002','person','Other','+201000014304','other@ph143.test');
insert into public.leads (id,tenant_id,branch_id,department_id,customer_id,lead_source_code,title,lead_status_code) values
  ('14300000-0000-0000-0000-0000000000e1','14300000-0000-0000-0000-000000000001','14300000-0000-0000-0000-00000000000a','14300000-0000-0000-0000-0000000000c1','14300000-0000-0000-0000-0000000000d1','google_ads_form','L1','qualified'),
  ('14300000-0000-0000-0000-0000000000e2','14300000-0000-0000-0000-000000000002','14300000-0000-0000-0000-00000000000b','14300000-0000-0000-0000-0000000000c2','14300000-0000-0000-0000-0000000000d4','google_ads_form','L2','qualified');
insert into public.attribution_clicks (id,tenant_id,attribution_source_code,gclid,consent_ad_user_data,consent_ad_personalization,lead_id) values
  ('14300000-0000-0000-0000-0000000000f1','14300000-0000-0000-0000-000000000001','google_ads','NOT-A-REAL-CLICK-143-1','granted','granted','14300000-0000-0000-0000-0000000000e1'),
  ('14300000-0000-0000-0000-0000000000f2','14300000-0000-0000-0000-000000000002','google_ads','NOT-A-REAL-CLICK-143-2','granted','granted','14300000-0000-0000-0000-0000000000e2');
insert into public.customer_consents (tenant_id,customer_id,purpose_code,consent_status_code,channel_code) values
  ('14300000-0000-0000-0000-000000000001','14300000-0000-0000-0000-0000000000d2','ad_user_data','granted','phone');

-- Source events, recorded by the platform as the emitters record them.
create temporary table _ev (label text primary key, seq bigint) on commit drop;
-- Two statements: an event written by a function is invisible to the statement that called it.
create temporary table _evid (label text primary key, id uuid) on commit drop;
insert into _evid
select v.label, app.record_event('14300000-0000-0000-0000-000000000001', v.t, v.et, v.eid)
from (values ('q2','lead_qualified','lead','14300000-0000-0000-0000-0000000000e1'::uuid),
             ('i1','booking_issued','booking','14300000-0000-0000-0000-0000000000b1'),
             ('i2','booking_issued','booking','14300000-0000-0000-0000-0000000000b1'),
             ('i3','booking_issued','booking','14300000-0000-0000-0000-0000000000b2'),
             ('q8','lead_qualified','lead','14300000-0000-0000-0000-0000000000e1')) v(label, t, et, eid);
insert into _ev select x.label, e.seq from _evid x join public.events e on e.id = x.id;

create temporary table _k (label text primary key, id uuid not null) on commit drop;
insert into _k values
  ('k1','14300000-0000-0000-0000-000000000101'),('k2','14300000-0000-0000-0000-000000000102'),
  ('k3','14300000-0000-0000-0000-000000000103'),('k4','14300000-0000-0000-0000-000000000104'),
  ('k5','14300000-0000-0000-0000-000000000105'),('k6','14300000-0000-0000-0000-000000000106'),
  ('k7','14300000-0000-0000-0000-000000000107'),('k8','14300000-0000-0000-0000-000000000108'),
  ('k9','14300000-0000-0000-0000-000000000109'),('k10','14300000-0000-0000-0000-000000000110'),
  ('k11','14300000-0000-0000-0000-000000000111'),('k12','14300000-0000-0000-0000-000000000112'),
  ('k13','14300000-0000-0000-0000-000000000113'),('m1','14300000-0000-0000-0000-000000000201');

insert into public.offline_conversions
  (id,tenant_id,lead_id,attribution_click_id,conversion_event_type_code,conversion_value,currency_code,
   conversion_at,source_event_seq,customer_id,customer_email,customer_phone)
select k.id, case when k.label = 'm1' then '14300000-0000-0000-0000-000000000002'::uuid
                  else '14300000-0000-0000-0000-000000000001'::uuid end,
       case when k.label = 'm1' then '14300000-0000-0000-0000-0000000000e2'::uuid
            when k.label in ('k2','k8') then null else '14300000-0000-0000-0000-0000000000e1'::uuid end,
       case when k.label = 'm1' then '14300000-0000-0000-0000-0000000000f2'::uuid
            when k.label in ('k2','k8') then null else '14300000-0000-0000-0000-0000000000f1'::uuid end,
       case k.label when 'k2' then 'qualified_phone_call' when 'k8' then 'qualified_phone_call'
                    when 'k3' then 'booking_created' when 'k4' then 'payment_received'
                    when 'k5' then 'ticket_issued' when 'k6' then 'ticket_issued'
                    when 'k7' then 'ticket_issued' else 'qualified_lead' end,
       case when k.label = 'k4' then 100 end, case when k.label = 'k4' then 'EGP' end,
       now() - interval '1 day' + (row_number() over (order by k.label)) * interval '1 minute',
       (select seq from _ev where label = case k.label when 'k2' then 'q2' when 'k5' then 'i1'
                                                       when 'k6' then 'i2' when 'k7' then 'i3'
                                                       when 'k8' then 'q8' end),
       case when k.label = 'k2' then '14300000-0000-0000-0000-0000000000d2'::uuid
            when k.label = 'k8' then '14300000-0000-0000-0000-0000000000d3'::uuid
            when k.label = 'm1' then '14300000-0000-0000-0000-0000000000d4'::uuid
            else '14300000-0000-0000-0000-0000000000d1'::uuid end,
       case when k.label in ('k2','k8') then null when k.label = 'm1' then 'other@ph143.test' else 'buyer@ph143.test' end,
       case k.label when 'k2' then '+201000014302' when 'k8' then '+201000014303' end
from _k k;

create function pg_temp.k(p text) returns uuid language sql stable as $$ select id from _k where label = p $$;
-- The newest attempt of a conversion, and its status.
create function pg_temp.d(p text) returns uuid language sql stable as $$
  select id from public.offline_conversion_deliveries
  where offline_conversion_id = pg_temp.k(p) order by attempt_number desc limit 1 $$;
create function pg_temp.st(p text) returns text language sql stable as $$
  select delivery_status_code from public.offline_conversion_deliveries where id = pg_temp.d(p) $$;
create function pg_temp.ev(p text, t text) returns int language sql stable as $$
  select count(*)::int from public.events where entity_id = pg_temp.k(p) and event_type_code = t $$;

-- Every claim of this file, kept per call, restricted to this file's conversions.
create temporary table _claimed (call int, label text, delivery_id uuid, conversion_event_type_code text,
                                 attempt_number int, transaction_id uuid) on commit drop;
create function pg_temp.claim(p_call int) returns int language plpgsql as $$
declare n int;
begin
  insert into _claimed
  select p_call, k.label, c.delivery_id, c.conversion_event_type_code, c.attempt_number, c.transaction_id
  from app.claim_conversion_deliveries('google_ads', 100000) c join _k k on k.id = c.conversion_id;
  get diagnostics n = row_count;
  return n;
end $$;
create function pg_temp.claimed(p_call int) returns text language sql stable as $$
  select coalesce(string_agg(label, ',' order by label), '') from _claimed where call = p_call $$;
create function pg_temp.mine_due() returns text language sql stable as $$
  select coalesce(string_agg(k.label || ':' || c.provider_request_id, ',' order by k.label), '')
  from app.conversion_status_checks_due('google_ads', 100000) c join _k k on k.id = c.conversion_id $$;
-- What a writing call returned, kept so the state it wrote is read by a LATER statement.
create temporary table _r (label text primary key, v text) on commit drop;
create function pg_temp.note(p_label text, p_v text) returns void language sql as $$
  insert into _r values (p_label, p_v) $$;
create function pg_temp.got(p_label text) returns text language sql stable as $$
  select v from _r where label = p_label $$;

-- =============================================================================================
-- PRIVILEGE. 1-3.
-- =============================================================================================
select ok(
  (select bool_and(has_function_privilege('orvion_integration', f, 'execute')
               and not has_function_privilege('authenticated', f, 'execute')
               and not has_function_privilege('anon', f, 'execute'))
   from unnest(array['app.claim_conversion_deliveries(text,integer)',
                     'app.record_conversion_ingestion(uuid,text,text,jsonb)',
                     'app.conversion_status_checks_due(text,integer)',
                     'app.record_conversion_provider_status(uuid,text,text,jsonb)']::regprocedure[]) f),
  'PRIVILEGE: the four delivery RPCs are the integration role''s, never a signed-in or anonymous caller''s');

select ok(
  (select bool_and(p.prosecdef and p.proconfig = array['search_path=""'])
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'app' and p.proname in ('claim_conversion_deliveries','record_conversion_ingestion',
                                              'conversion_status_checks_due','record_conversion_provider_status'))
  and to_regprocedure('app.record_conversion_delivery_result(uuid,boolean,jsonb,text)') is null,
  'PRIVILEGE: each is SECURITY DEFINER with an empty search_path, and the boolean that meant "accepted" is gone');

select ok(has_schema_privilege('orvion_integration', 'app', 'USAGE'),
  'PRIVILEGE: the integration role holds USAGE on app, so its EXECUTE on the four is usable');

-- =============================================================================================
-- BUSINESS. 4-6. The claim: every type, its consent, its stable Google transaction identity.
-- =============================================================================================
select is(pg_temp.claim(1), 13, 'BUSINESS: the first claim takes every eligible conversion of both tenants');

select is(pg_temp.claimed(1), 'k1,k10,k11,k12,k13,k2,k3,k4,k5,k6,k7,k9,m1',
  'BUSINESS: all five conversion types are claimed, and the phone call without recorded consent (k8) is not');

select is(
  (select string_agg(label || '=' || case when transaction_id = pg_temp.k(label) then 'own'
                                          when transaction_id = '14300000-0000-0000-0000-0000000000b1' then 'B1'
                                          when transaction_id = '14300000-0000-0000-0000-0000000000b2' then 'B2'
                                          else 'other' end, ',' order by label)
   from _claimed where call = 1 and label in ('k1','k2','k3','k4','k5','k6','k7')),
  'k1=own,k2=own,k3=own,k4=own,k5=B1,k6=B1,k7=B2',
  'BUSINESS: a conversion''s transactionId is its own id, except that an issue and a reissue of one booking share that booking''s, read from the source event');

-- =============================================================================================
-- STATE / OBSERVABILITY. 7-11. Ingestion is not delivery.
-- =============================================================================================
select is(app.record_conversion_ingestion(pg_temp.d('k1'), 'REQ-143-K1', null, '{"requestId":"REQ-143-K1"}'),
  'ingested', 'STATE: Google''s requestId moves the delivery to ingested');

select is(
  (select delivery_status_code || ':' || provider_request_id || ':' || (ingested_at is not null)
          || ':' || (sent_at is null) || ':' || (response_payload ->> 'requestId')
   from public.offline_conversion_deliveries where id = pg_temp.d('k1')),
  'ingested:REQ-143-K1:true:true:REQ-143-K1',
  'STATE: the request identity, its time and Google''s response are kept; nothing is sent');

select is(
  (select count(*)::int from public.events e join _k k on k.id = e.entity_id
   where e.event_type_code = 'offline_conversion_sent'),
  0, 'OBSERVABILITY: an HTTP 200 with a requestId records no sent event');

select throws_ok(
  $$select app.record_conversion_ingestion(pg_temp.d('k1'), 'REQ-143-K1-SECOND')$$,
  'P0001', null,
  'STATE: an ingested delivery cannot take a second, conflicting request identity');

select throws_ok(
  $$select app.record_conversion_ingestion(pg_temp.d('m1'), 'REQ-143-K1')$$,
  '23505', null,
  'TENANT: a request already attached to one tenant''s delivery cannot be attached to another''s');

-- =============================================================================================
-- INPUT. 12-15.
-- =============================================================================================
select throws_ok($$select app.record_conversion_ingestion(pg_temp.d('k3'), '')$$, '23514', null,
  'INPUT: an empty request id cannot enter ingested');
select throws_ok($$select app.record_conversion_ingestion(pg_temp.d('k3'), 'REQ 143')$$, '23514', null,
  'INPUT: a malformed request id cannot enter ingested');
select throws_ok($$select app.record_conversion_ingestion(pg_temp.d('k3'), null, null)$$, '22023', null,
  'INPUT: a missing request id with no error is refused');
select throws_ok($$select app.record_conversion_ingestion(pg_temp.d('k3'), 'REQ-143-K3', 'and an error')$$,
  '22023', null, 'INPUT: a request id and an error together are refused');

-- =============================================================================================
-- REPLAY / STATE. 16-17. Never re-claimed, never lease-swept.
-- =============================================================================================
select is(pg_temp.claim(2), 0, 'REPLAY: nothing pending or ingested is claimed again');

update public.offline_conversion_deliveries set created_at = now() - interval '31 minutes'
where id = pg_temp.d('k1');
do $$ begin perform pg_temp.claim(3); end $$;
select is(
  pg_temp.st('k1') || ':' || (select count(*) from public.offline_conversion_deliveries
                               where offline_conversion_id = pg_temp.k('k1'))
  || ':' || (select count(*) from public.events where entity_id = pg_temp.k('k1')
               and payload ->> 'expired_lease' = 'true'),
  'ingested:1:0',
  'STATE: the 30-minute pre-send lease does not sweep an ingested delivery');

-- =============================================================================================
-- BUSINESS. 18-25. Status checks and the non-terminal answers.
-- =============================================================================================
select is(pg_temp.mine_due(), '', 'BUSINESS: a delivery ingested moments ago is not yet due for a status check');

update public.offline_conversion_deliveries set ingested_at = now() - interval '31 minutes'
where id = pg_temp.d('k1');
select is(pg_temp.mine_due(), 'k1:REQ-143-K1',
  'BUSINESS: 30 minutes after ingestion it is due, with its request id, and nothing that is not ingested is listed');

select is(app.record_conversion_provider_status(pg_temp.d('k1'), 'REQ-143-K1', 'PROCESSING', '{"requestStatus":"PROCESSING"}'),
  'ingested', 'STATE: PROCESSING leaves the delivery ingested');

select is(pg_temp.mine_due() || '|' || pg_temp.st('k1') || ':' ||
          (select provider_status_code from public.offline_conversion_deliveries where id = pg_temp.d('k1')),
  '|ingested:PROCESSING', 'BUSINESS: a delivery just checked is not due again at once, and is not sent');

update public.offline_conversion_deliveries set provider_checked_at = now() - interval '61 minutes'
where id = pg_temp.d('k1');
select is(pg_temp.mine_due(), 'k1:REQ-143-K1', 'BUSINESS: an hour after its last check it is due again');

select is(app.record_conversion_provider_status(pg_temp.d('k1'), 'REQ-143-K1', 'REQUEST_STATUS_UNKNOWN'),
  'ingested', 'STATE: REQUEST_STATUS_UNKNOWN fails closed -- still ingested, never sent');

select throws_ok(
  $$select app.record_conversion_provider_status(pg_temp.d('k1'), 'REQ-143-OTHER', 'SUCCESS')$$,
  '22023', null, 'REPLAY: a status for another request never resolves this delivery');

select throws_ok(
  $$select app.record_conversion_provider_status(pg_temp.d('k1'), 'REQ-143-K1', 'DONE')$$,
  '22023', null, 'INPUT: a status outside Google''s vocabulary is refused');

-- =============================================================================================
-- STATE / OBSERVABILITY. 26-31. SUCCESS, once.
-- =============================================================================================
select is(app.record_conversion_provider_status(pg_temp.d('k1'), 'REQ-143-K1', 'SUCCESS', '{"requestStatus":"SUCCESS"}'),
  'sent', 'STATE: SUCCESS makes it sent');

select is(
  (select count(*)::int || ':' || min(e.previous_state) || ':' || min(e.payload ->> 'provider_request_id')
          || ':' || bool_and(d.sent_at is not null and d.provider_status_code = 'SUCCESS')
   from public.events e join public.offline_conversion_deliveries d on d.id = pg_temp.d('k1')
   where e.entity_id = pg_temp.k('k1') and e.event_type_code = 'offline_conversion_sent'),
  '1:ingested:REQ-143-K1:true',
  'OBSERVABILITY: one sent event, from ingested, naming its request');

select is(app.record_conversion_provider_status(pg_temp.d('k1'), 'REQ-143-K1', 'SUCCESS'),
  'sent', 'REPLAY: a repeated SUCCESS is accepted as the same fact');

select is(pg_temp.ev('k1', 'offline_conversion_sent'), 1,
  'REPLAY: and records no second sent event');

select throws_ok(
  $$select app.record_conversion_provider_status(pg_temp.d('k1'), 'REQ-143-K1', 'FAILED')$$,
  'P0001', null, 'STATE: FAILED after sent cannot reverse the terminal state');

update public.offline_conversion_deliveries
   set created_at = now() - interval '48 hours', ingested_at = now() - interval '48 hours'
 where id = pg_temp.d('k1');
do $$ begin perform pg_temp.note('c4', pg_temp.claim(4)::text); end $$;
select is(pg_temp.got('c4') || ':' || pg_temp.st('k1'), '0:sent',
  'STATE: a sent delivery is never claimed again, however old');

-- =============================================================================================
-- STATE / REPLAY. 32-36. FAILED and PARTIAL_SUCCESS re-enter the retry path; a stale answer
-- from an earlier attempt touches nothing.
-- =============================================================================================
do $$ begin perform app.record_conversion_ingestion(pg_temp.d('k3'), 'REQ-143-K3'); end $$;
do $$ begin perform pg_temp.note('k3', app.record_conversion_provider_status(pg_temp.d('k3'), 'REQ-143-K3', 'FAILED', '{"requestStatus":"FAILED"}')); end $$;
select is(pg_temp.got('k3')
          || ':' || (select error_message like 'PROVIDER_FAILED:%' from public.offline_conversion_deliveries
                     where id = pg_temp.d('k3'))
          || ':' || pg_temp.ev('k3', 'offline_conversion_failed') || ':' || pg_temp.ev('k3', 'offline_conversion_sent'),
  'failed:true:1:0', 'STATE: FAILED becomes failed with its reason and event, never sent');

create temporary table _old on commit drop as select pg_temp.d('k3') as id;
do $$ begin perform pg_temp.claim(5); end $$;
select is(
  (select string_agg(attempt_number || ':' || delivery_status_code, ',' order by attempt_number)
   from public.offline_conversion_deliveries where offline_conversion_id = pg_temp.k('k3'))
  || '|' || (select transaction_id = pg_temp.k('k3') from _claimed where call = 5 and label = 'k3'),
  '1:retried,2:pending|true',
  'BUSINESS: the failed conversion is re-claimed as attempt 2 under the same transaction identity');

select throws_ok(
  $$select app.record_conversion_provider_status((select id from _old), 'REQ-143-K3', 'SUCCESS')$$,
  'P0001', null, 'REPLAY: a late SUCCESS for the obsolete attempt is refused');

select throws_ok(
  $$select app.record_conversion_provider_status(pg_temp.d('k3'), 'REQ-143-K3', 'SUCCESS')$$,
  '22023', null, 'REPLAY: the obsolete attempt''s request cannot resolve the new attempt');

do $$ begin perform app.record_conversion_ingestion(pg_temp.d('k10'), 'REQ-143-K10'); end $$;
do $$ begin perform pg_temp.note('k10', app.record_conversion_provider_status(pg_temp.d('k10'), 'REQ-143-K10', 'PARTIAL_SUCCESS')); end $$;
do $$ begin perform pg_temp.note('c6', pg_temp.claim(6)::text); end $$;
select is(pg_temp.got('k10')
          || ':' || pg_temp.ev('k10', 'offline_conversion_sent') || ':' || pg_temp.got('c6')
          || ':' || pg_temp.st('k10'),
  'failed:0:1:pending',
  'STATE: PARTIAL_SUCCESS on a one-event request is not success: failed, then re-claimed');

-- =============================================================================================
-- STATE. 37-38. The deadline, and only past it.
-- =============================================================================================
do $$ begin perform app.record_conversion_ingestion(pg_temp.d('k11'), 'REQ-143-K11'); end $$;
update public.offline_conversion_deliveries set ingested_at = now() - interval '25 hours'
where id = pg_temp.d('k11');
do $$ begin perform pg_temp.note('c7', pg_temp.claim(7)::text); end $$;
select is(pg_temp.got('c7') || ':' || pg_temp.st('k11'), '0:ingested',
  'STATE: inside its deadline an unresolved delivery stays ingested');

update public.offline_conversion_deliveries set ingested_at = now() - interval '27 hours'
where id = pg_temp.d('k11');
do $$ begin perform pg_temp.claim(8); end $$;
select is(
  (select string_agg(attempt_number || ':' || delivery_status_code || ':' || coalesce(split_part(error_message, ':', 1), '-'),
                     ',' order by attempt_number)
   from public.offline_conversion_deliveries where offline_conversion_id = pg_temp.k('k11'))
  || '|' || (select count(*) from public.events where entity_id = pg_temp.k('k11')
               and payload ->> 'provider_deadline' = 'true')
  || '|' || pg_temp.ev('k11', 'offline_conversion_sent'),
  '1:retried:PROVIDER_DEADLINE,2:pending:-|1|0',
  'STATE: past its deadline it is failed with PROVIDER_DEADLINE and its event, and re-claimed -- never sent');

-- =============================================================================================
-- BUSINESS. 39-41. Ingestion-time refusals and a crash before the request was recorded.
-- =============================================================================================
do $$ begin perform pg_temp.note('k12', app.record_conversion_ingestion(pg_temp.d('k12'), null,
            'FIELD_WARNING events[0].userData.userIdentifiers[0]: identifier dropped',
            '{"requestId":"REQ-143-K12","fieldWarnings":[{"field":"events[0].userData.userIdentifiers[0]"}]}')); end $$;
select is(pg_temp.got('k12')
          || ':' || pg_temp.ev('k12', 'offline_conversion_failed') || ':' || pg_temp.ev('k12', 'offline_conversion_sent')
          || ':' || (select coalesce(provider_request_id, '-') from public.offline_conversion_deliveries where id = pg_temp.d('k12')),
  'failed:1:0:-',
  'BUSINESS: a material fieldWarning is refused at ingestion -- failed and retryable, never sent, its request never polled');

do $$ begin perform pg_temp.note('k13', app.record_conversion_ingestion(pg_temp.d('k13'), null, 'VALIDATE_ONLY_RUN -- not a real delivery')); end $$;
select is(pg_temp.got('k13') || ':' || pg_temp.st('k13') || ':' || pg_temp.ev('k13', 'offline_conversion_sent'),
  'failed:failed:0', 'BUSINESS: a validateOnly run is never a delivery');

update public.offline_conversion_deliveries set created_at = now() - interval '31 minutes'
where id = pg_temp.d('k9');
do $$ begin perform pg_temp.claim(9); end $$;
select is(
  (select string_agg(attempt_number || ':' || delivery_status_code, ',' order by attempt_number)
   from public.offline_conversion_deliveries where offline_conversion_id = pg_temp.k('k9'))
  || '|' || (select bool_and(transaction_id = pg_temp.k('k9')) from _claimed where label = 'k9'),
  '1:retried,2:pending|true',
  'BUSINESS: a run that died after Google ingested but before recording it is recovered by the lease, under the same transaction identity');

-- =============================================================================================
-- BUSINESS / DOOR. 42-45. The reissue identity on retry, the ceiling, and the table door.
-- =============================================================================================
do $$ begin perform app.record_conversion_ingestion(pg_temp.d('k5'), null, 'HTTP 503'); end $$;
do $$ begin perform pg_temp.claim(10); end $$;
select is(
  (select string_agg(attempt_number || ':' || (transaction_id = '14300000-0000-0000-0000-0000000000b1'),
                     ',' order by attempt_number) from _claimed where label = 'k5'),
  '1:true,2:true', 'BUSINESS: the issue''s retry keeps its booking''s transaction identity');

do $$
begin
  for i in 1..4 loop
    perform pg_temp.claim(100 + i);
    perform app.record_conversion_ingestion(pg_temp.d('k13'), null, 'HTTP 500');
  end loop;
end $$;
do $$ begin perform pg_temp.note('c200', pg_temp.claim(200)::text); end $$;
select is(pg_temp.got('c200') || ':' || (select count(*) from public.offline_conversion_deliveries
                                         where offline_conversion_id = pg_temp.k('k13')),
  '0:5', 'STATE: ingestion failures still stop at the retry ceiling of five attempts');

select throws_ok(
  $$update public.offline_conversion_deliveries set delivery_status_code = 'sent', sent_at = now()
    where id = pg_temp.d('k4')$$,
  '23514', null, 'DOOR: even the platform cannot mark a delivery sent without a recorded SUCCESS');

select throws_ok(
  $$update public.offline_conversion_deliveries set delivery_status_code = 'ingested'
    where id = pg_temp.d('k4')$$,
  '23514', null, 'DOOR: nor ingested without a request identity');

select * from finish();
rollback;
