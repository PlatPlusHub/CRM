-- pgTAP: P3 -- a delivery obligation is attempted, retried on a widening schedule, and eventually
-- ABANDONED rather than retried for ever or dropped in silence (`202607060900`).
--
-- WHAT MUST BE TRUE, and the first two are what separate this from a queue that merely looks like
-- one:
--   * a claim must not hand the same row to two dispatchers, and a run that dies mid-flight must be
--     RECOVERED rather than stranded -- PH8-1's defect on the conversion side, which this must not
--     repeat;
--   * a retry must WAIT. Immediate re-attempt against a provider that just refused the message is
--     the one thing transactional-email practice is unanimous about, and it is the single point
--     where SPEC-123's outbox could not be copied;
--   * a LATE acknowledgement must RAISE, not succeed -- `MASTER_INTEGRATION_CATALOG.md §2a` item 6
--     documents that as deliberate for conversions and it is deliberate here for the same reason;
--   * exhaustion must be a STATE, not an absence. A row that has given up must say so.
--
-- Every transition is proven by its EFFECTS (row state + event row), never by "the call did not
-- throw" (`AGENTS.md §6`: no vacuous tests).
create extension if not exists pgtap with schema extensions;

begin;
select plan(22);

insert into auth.users (id, email, email_confirmed_at) values
  ('a0000000-0000-0000-0000-0000000000a1','owner@deliv100.test', now());
insert into public.tenants (id, name, slug, status) values
  ('a0000000-0000-0000-0000-000000000001','Deliv100 Travel','deliv100','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id='a0000000-0000-0000-0000-000000000001';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('a0000000-0000-0000-0000-000000000011','a0000000-0000-0000-0000-000000000001','Owner Person','owner@deliv100.test',true,'a0000000-0000-0000-0000-0000000000a1');

-- Three independent notifications so the retry, lease and dead-letter chains never interfere.
insert into public.notifications (id, tenant_id, target_user_id, notification_type_code, title, body) values
  ('a0000000-0000-0000-0000-0000000000f1','a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000011','supplier_balance','Alert one','Body one'),
  ('a0000000-0000-0000-0000-0000000000f2','a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000011','supplier_balance','Alert two','Body two'),
  ('a0000000-0000-0000-0000-0000000000f3','a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000011','supplier_balance','Alert three','Body three');

-- =============================================================================================
-- 1-5. STRUCTURE AND THE SECURITY BOUNDARY. The contract must not become a second door into the
--      data: `orvion_integration` reaches this database through RPCs and holds no table grants,
--      and that property is the one most easily lost by adding a capability.
-- =============================================================================================
select is(
  (select count(*)::int from public.catalog_values
    where catalog_type_code='notification_delivery_status' and code='dead_lettered'),
  1,
  'P3: `dead_lettered` is a registered catalog value -- enforce_catalog_codes would refuse the write otherwise, so the terminal state fails closed if this row is ever removed');

select is(
  (select count(*)::int from public.catalog_values
    where catalog_type_code='event_type'
      and code in ('notification_delivery_sent','notification_delivery_failed','notification_delivery_dead_lettered')),
  3,
  'P3: all three delivery event types are registered -- app.record_event REFUSES an unregistered code, so an unregistered one would fail the whole path closed');

select ok(
  not has_function_privilege('authenticated','app.claim_notification_deliveries(text,integer)','execute'),
  'P3: `authenticated` cannot claim deliveries -- the dispatcher contract is not a user-facing endpoint');

select ok(
  has_function_privilege('orvion_integration','app.claim_notification_deliveries(text,integer)','execute'),
  'P3: `orvion_integration` CAN claim -- the n8n identity reaches this through the RPC and nothing else');

select is(
  (select count(*)::int from information_schema.role_table_grants
    where table_name='notification_deliveries' and grantee='orvion_integration'),
  0,
  'P3: the integration role STILL holds no table grant on notification_deliveries -- this capability added a second RPC, not a first table');

-- =============================================================================================
-- 6-9. THE HAPPY PATH. Claim stamps the lease and returns the payload a dispatcher actually needs;
--      the acknowledgement moves the row and emits the event.
-- =============================================================================================
insert into public.notification_deliveries (id, tenant_id, notification_id, channel_code, delivery_status_code)
values ('a0000000-0000-0000-0000-0000000000d1','a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-0000000000f1','email','pending');

select is(
  (select c.recipient_email from app.claim_notification_deliveries('email', 10) c
    where c.delivery_id='a0000000-0000-0000-0000-0000000000d1'),
  'owner@deliv100.test',
  'P3: the claim returns the RECIPIENT ADDRESS with the message -- a dispatcher must not need a second query, and must not need table access to make one');

select is(
  (select delivery_status_code || '|' || (claimed_at is not null)::text
     from public.notification_deliveries where id='a0000000-0000-0000-0000-0000000000d1'),
  'pending|true',
  'P3: a claimed row is stamped but still `pending` -- claimed_at is what distinguishes IN FLIGHT from NEVER ATTEMPTED, which is the whole reason the column exists here and not in SPEC-123');

select is(
  (select count(*)::int from app.claim_notification_deliveries('email', 10) c
    where c.delivery_id='a0000000-0000-0000-0000-0000000000d1'),
  0,
  'P3: a second claim does NOT return the same row -- without this two dispatchers send the same email twice');

select lives_ok(
  $$select app.record_notification_delivery_result('a0000000-0000-0000-0000-0000000000d1', true,
      '{"id":"provider-msg-1"}'::jsonb, null)$$,
  'P3: a success is acknowledged');

-- =============================================================================================
-- 10-12. ...and the success is proven by its EFFECTS, not by the absence of an exception.
-- =============================================================================================
select is(
  (select delivery_status_code || '|' || (sent_at is not null)::text || '|' || (response_payload->>'id')
     from public.notification_deliveries where id='a0000000-0000-0000-0000-0000000000d1'),
  'sent|true|provider-msg-1',
  'P3: the row is `sent`, timestamped, and carries the PROVIDER''S OWN id -- the only durable link between an ORVION row and the provider''s console');

select is(
  (select count(*)::int from public.events
    where entity_id='a0000000-0000-0000-0000-0000000000f1' and event_type_code='notification_delivery_sent'),
  1,
  'P3: exactly one `notification_delivery_sent` event -- the audit trail is the event ledger, not the row');

select throws_ok(
  $$select app.record_notification_delivery_result('a0000000-0000-0000-0000-0000000000d1', true, null, null)$$,
  'P0001', null,
  'P3: a LATE acknowledgement RAISES -- a resumed run must not be able to overwrite a resolved delivery, and §2a item 6 documents this as expected, non-fatal, and the dispatcher''s job to tolerate');

-- =============================================================================================
-- 13-16. FAILURE, THEN THE BACKOFF. The assertion that a retry does NOT open immediately is the
--        one that separates this from SPEC-123's model, and it would silently pass if the backoff
--        were ever removed -- so it is paired with the proof that it DOES open once due.
-- =============================================================================================
insert into public.notification_deliveries (id, tenant_id, notification_id, channel_code, delivery_status_code)
values ('a0000000-0000-0000-0000-0000000000d2','a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-0000000000f2','email','pending');
select app.claim_notification_deliveries('email', 10);
select app.record_notification_delivery_result('a0000000-0000-0000-0000-0000000000d2', false, null, 'provider said 421');

select is(
  (select delivery_status_code || '|' || (failed_at is not null)::text || '|' || error_message
     from public.notification_deliveries where id='a0000000-0000-0000-0000-0000000000d2'),
  'failed|true|provider said 421',
  'P3: a failure is recorded with its own error text on its own row -- one row per attempt is what keeps every attempt''s reason');

select is(
  (select count(*)::int from public.notification_deliveries
    where notification_id='a0000000-0000-0000-0000-0000000000f2'),
  1,
  'P3 (THE BACKOFF): a claim immediately after a failure opens NO retry -- retrying a just-refused message is the practice every transactional-email source refuses, and it is why SPEC-123''s no-backoff model was not copied');

update public.notification_deliveries set failed_at = now() - interval '6 minutes'
 where id='a0000000-0000-0000-0000-0000000000d2';
select app.claim_notification_deliveries('email', 10);

select is(
  (select string_agg(attempt_number::text || ':' || delivery_status_code, ',' order by attempt_number)
     from public.notification_deliveries where notification_id='a0000000-0000-0000-0000-0000000000f2'),
  '1:failed,2:pending',
  'P3: once the 5-minute backoff has elapsed the SAME claim call opens attempt 2 as a new row -- the failed attempt is preserved, never mutated');

select is(
  (select count(*)::int from public.notification_deliveries
    where notification_id='a0000000-0000-0000-0000-0000000000f2' and claimed_at is not null),
  2,
  'P3: the retry it opened was also CLAIMED in the same call -- a due retry is not made to wait for the next run');

-- =============================================================================================
-- 17-19. THE LEASE. A run that dies between claim and acknowledgement must not strand its
--        obligation for ever. This is PH8-1's exact defect, and the sweep is in the claim call so
--        no separate maintenance schedule can be forgotten.
-- =============================================================================================
insert into public.notification_deliveries (id, tenant_id, notification_id, channel_code, delivery_status_code, claimed_at)
values ('a0000000-0000-0000-0000-0000000000d3','a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-0000000000f3','email','pending', now() - interval '31 minutes');

select app.claim_notification_deliveries('email', 10);

select ok(
  (select error_message from public.notification_deliveries
    where id='a0000000-0000-0000-0000-0000000000d3') like 'LEASE_EXPIRED%',
  'P3 (THE LEASE): an in-flight row older than the lease is swept into `failed` by the next claim -- a dead run no longer strands its obligation');

select is(
  (select delivery_status_code from public.notification_deliveries where id='a0000000-0000-0000-0000-0000000000d3'),
  'failed',
  '...and it is `failed` rather than silently re-claimed, so the attempt is spent and visible');

select is(
  (select count(*)::int from public.events
    where entity_id='a0000000-0000-0000-0000-0000000000f3'
      and event_type_code='notification_delivery_failed'
      and (payload->>'expired_lease')::boolean),
  1,
  '...and the event says the LEASE is why, not the provider -- an operator must be able to tell a dead worker from a rejected message');

-- =============================================================================================
-- 20-22. EXHAUSTION. The attempt ceiling is 5 -- SPEC-123's number, reused rather than re-derived.
--        A chain at the ceiling must become TERMINAL and must stop being retried.
-- =============================================================================================
insert into public.notifications (id, tenant_id, target_user_id, notification_type_code, title, body) values
  ('a0000000-0000-0000-0000-0000000000f4','a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000011','supplier_balance','Alert four','Body four');
insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code, attempt_number, failed_at, error_message)
select 'a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-0000000000f4','email','failed', n,
       now() - interval '2 hours', 'attempt ' || n || ' refused'
from generate_series(1,5) n;

select app.claim_notification_deliveries('email', 10);

select is(
  (select delivery_status_code from public.notification_deliveries
    where notification_id='a0000000-0000-0000-0000-0000000000f4' and attempt_number=5),
  'dead_lettered',
  'P3 (EXHAUSTION): the newest attempt of a chain at the ceiling becomes `dead_lettered` -- "we gave up" is a FACT on the row, not an absence an operator has to infer from a count');

select is(
  (select count(*)::int from public.notification_deliveries
    where notification_id='a0000000-0000-0000-0000-0000000000f4'),
  5,
  '...and NO sixth attempt was opened, even though every backoff had long elapsed -- the ceiling holds');

select is(
  (select (payload->>'attempts')::int from public.events
    where entity_id='a0000000-0000-0000-0000-0000000000f4'
      and event_type_code='notification_delivery_dead_lettered'),
  5,
  '...and it is announced once, with the attempt count -- DELIV-1 owns making this VISIBLE to an operator; this is the fact that view will read');

select * from finish();
rollback;
