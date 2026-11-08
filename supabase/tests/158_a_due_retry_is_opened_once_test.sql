-- pgTAP: SPEC-298 (Batch 6 Slice 43, ND-1) -- a due retry is opened once (`20261108120000`).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY REPLAY PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
--   BUSINESS=N/A -- a delivery carries no money and re-denominates no history; sending one message
--     twice is CONCURRENCY's question.
--   OBSERVABILITY=N/A -- opening a retry is not a canon-27 event; each attempt's result is, and
--     `100_...` pins those events.
--   CONCURRENCY -- two overlapping dispatchers need two live sessions, which pgTAP does not have.
--     The race is proven by SPEC-298's two-session harness, with and without the repair; here the
--     key it rests on is pinned, injected and re-asserted.
--
-- ND-1: `app.claim_notification_deliveries` step 2 opened attempt N+1 behind a `not exists` that
-- cannot see another dispatcher's uncommitted attempt N+1, and nothing made the attempt number
-- unique per chain. Two overlapping claims each opened and claimed attempt 2, so the recipient was
-- sent the same message twice. The repair makes (notification_id, channel_code, attempt_number)
-- unique and has step 2 skip a key another dispatcher holds.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into auth.users (id, email) values
  ('15800000-0000-0000-0000-0000000000a1','rec@c158.test'),
  ('15800000-0000-0000-0000-0000000000a2','peer@c158.test'),
  ('15800000-0000-0000-0000-0000000000a3','rival@c158b.test');
insert into public.tenants (id, name, slug, status) values
  ('15800000-0000-0000-0000-000000000001','C158 Travel','c158-travel','active'),
  ('15800000-0000-0000-0000-000000000002','C158 Rival','c158-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['15800000-0000-0000-0000-000000000001'::uuid,'15800000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('15800000-0000-0000-0000-000000000011','15800000-0000-0000-0000-000000000001','Recipient','rec@c158.test',true,'15800000-0000-0000-0000-0000000000a1'),
  ('15800000-0000-0000-0000-000000000012','15800000-0000-0000-0000-000000000001','Peer','peer@c158.test',true,'15800000-0000-0000-0000-0000000000a2'),
  ('15800000-0000-0000-0000-000000000021','15800000-0000-0000-0000-000000000002','Rival','rival@c158b.test',true,'15800000-0000-0000-0000-0000000000a3');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('15800000-0000-0000-0000-000000000001'::uuid,'15800000-0000-0000-0000-000000000011'::uuid),
             ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-000000000012'),
             ('15800000-0000-0000-0000-000000000002','15800000-0000-0000-0000-000000000021')) v(t,u)
join public.roles r on r.code = 'employee';
insert into public.notifications (id, tenant_id, target_user_id, notification_type_code, title, body) values
  ('15800000-0000-0000-0000-0000000000f1','15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-000000000011','supplier_balance','Alert','Body');
-- Attempt 1 on email, failed six minutes ago: its retry is due (backoff 5 minutes).
insert into public.notification_deliveries (id, tenant_id, notification_id, channel_code, delivery_status_code, attempt_number, claimed_at, failed_at, error_message) values
  ('15800000-0000-0000-0000-0000000000d1','15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','email','failed',1,
   now() - interval '7 minutes', now() - interval '6 minutes','provider said 421');

create function pg_temp.as_(sub text) returns text language sql as $$
  select set_config('request.jwt.claims', json_build_object('sub', sub, 'aal', 'aal1')::text, true) $$;
create function pg_temp.chain() returns text language sql as $$
  select string_agg(attempt_number || ':' || delivery_status_code || ':' || (claimed_at is not null)::text, ','
                    order by attempt_number, claimed_at is null)
    from public.notification_deliveries
   where notification_id = '15800000-0000-0000-0000-0000000000f1' and channel_code = 'email' $$;

-- =============================================================================================
-- 1-2. THE KEY. One row per attempt number per chain, replacing the plain chain index.
-- =============================================================================================
select is(
  (select pg_get_constraintdef(oid) from pg_constraint
    where conrelid = 'public.notification_deliveries'::regclass and conname = 'notification_deliveries_attempt_key'),
  'UNIQUE (notification_id, channel_code, attempt_number)',
  'ND-1: (notification_id, channel_code, attempt_number) is unique -- two dispatchers can never both hold attempt N+1');
select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and indexname = 'notification_deliveries_chain_idx'),
  0,
  'ND-1: the plain chain index is gone, replaced by the key that covers the same columns (EC-11: no duplicate mechanism)');

-- =============================================================================================
-- 3-4. INPUT. A second attempt 1 is refused on the platform path; the key is per channel.
-- =============================================================================================
select throws_ok($$
  insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code)
  values ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','email','pending')$$,
  '23505', null,
  'INPUT: a second attempt 1 on the same chain is refused 23505, even for the platform (postgres) writer');
select lives_ok($$
  insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code)
  values ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','whatsapp','pending')$$,
  'POSITIVE CONTROL: attempt 1 of the same notification on another channel is its own chain and is accepted');

-- =============================================================================================
-- 5-7. THE CLAIM still opens a due retry, exactly once, and claims it in the same call.
-- =============================================================================================
select is(
  (select count(*)::int from app.claim_notification_deliveries('email', 50) c
    where c.notification_id = '15800000-0000-0000-0000-0000000000f1'),
  1,
  'POSITIVE CONTROL: the claim opens the due retry and returns it once');
select is(pg_temp.chain(), '1:failed:true,2:pending:true',
  'POSITIVE CONTROL: the chain is attempt 1 failed and one attempt 2, claimed -- the failure is preserved, never mutated');
select is(
  (select count(*)::int from app.claim_notification_deliveries('email', 50) c
    where c.notification_id = '15800000-0000-0000-0000-0000000000f1')
  || '|' || pg_temp.chain(),
  '0|1:failed:true,2:pending:true',
  'REPLAY: a second claim returns nothing for this notification and opens no further attempt');

-- =============================================================================================
-- 8-9. INJECTION (PAR-4, TEST-3). Without the key a second attempt 2 lands; restored, it is refused.
-- =============================================================================================
savepoint no_key;
alter table public.notification_deliveries drop constraint notification_deliveries_attempt_key;
insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code, attempt_number)
values ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','email','pending',2);
select is(pg_temp.chain(), '1:failed:true,2:pending:true,2:pending:false',
  'INJECTION: with the key dropped, a second attempt 2 is stored -- the state two racing dispatchers produced (ND-1)');
rollback to savepoint no_key;
select throws_ok($$
  insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code, attempt_number)
  values ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','email','pending',2)$$,
  '23505', null,
  'INJECTION RE-ASSERTED: after the rollback the key is back and the second attempt 2 is refused 23505');

-- =============================================================================================
-- 10. THE CLAIM SKIPS A HELD KEY. A diagnostic tripwire, labelled as one: it reads the function's
--     text, so it proves the clause is present, not that it works. The two-session harness is the
--     evidence that it works; this only fails loudly if the clause is ever edited away.
-- =============================================================================================
select ok(
  position('on conflict on constraint notification_deliveries_attempt_key do nothing'
           in pg_get_functiondef('app.claim_notification_deliveries(text,integer)'::regprocedure)) > 0,
  'TRIPWIRE (diagnostic): step 2 skips an attempt another dispatcher holds instead of failing the whole claim');

-- =============================================================================================
-- 11-13. PRIVILEGE, AUTH and STATE: the claim is still a definer RPC for the integration role only.
-- =============================================================================================
select is(
  (select p.prosecdef::text || '|' || coalesce(array_to_string(p.proconfig, ','), '')
     from pg_proc p where p.oid = 'app.claim_notification_deliveries(text,integer)'::regprocedure),
  'true|search_path=""',
  'PRIVILEGE: the replaced claim is still SECURITY DEFINER with an empty search_path');
select is(
  has_function_privilege('orvion_integration','app.claim_notification_deliveries(text,integer)','execute')::text
  || '|' || has_function_privilege('authenticated','app.claim_notification_deliveries(text,integer)','execute')::text
  || '|' || has_function_privilege('anon','app.claim_notification_deliveries(text,integer)','execute')::text
  || '|' || has_function_privilege('authenticated','app.record_notification_delivery_result(uuid,boolean,jsonb,text)','execute')::text,
  'true|false|false|false',
  'AUTH: only orvion_integration may claim; neither authenticated nor anon may claim or record a result -- create or replace kept the ACL');
select throws_ok($$
  select app.record_notification_delivery_result('15800000-0000-0000-0000-0000000000d1', true, null, null)$$,
  'P0001', null,
  'STATE: a result for the failed attempt 1 raises -- only a pending delivery can be resolved');

-- =============================================================================================
-- 14-16. DOOR and TENANT, swept and pinned: no signed-in write; a delivery is read by its recipient only.
-- =============================================================================================
set local role authenticated;
select pg_temp.as_('15800000-0000-0000-0000-0000000000a1');
select throws_ok($$
  insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code, attempt_number)
  values ('15800000-0000-0000-0000-000000000001','15800000-0000-0000-0000-0000000000f1','email','pending',3)$$,
  '42501', null,
  'DOOR: the recipient cannot write a delivery at the table (authenticated holds SELECT only)');
select is(
  (select count(*)::int from public.notification_deliveries
    where notification_id = '15800000-0000-0000-0000-0000000000f1'),
  3,
  'TENANT POSITIVE CONTROL: the recipient reads its three deliveries (email 1 and 2, whatsapp 1)');
select pg_temp.as_('15800000-0000-0000-0000-0000000000a2');
select set_config('c158.peer', (select count(*)::text from public.notification_deliveries
    where notification_id = '15800000-0000-0000-0000-0000000000f1'), true);
select pg_temp.as_('15800000-0000-0000-0000-0000000000a3');
select is(
  current_setting('c158.peer') || '|' || (select count(*)::text from public.notification_deliveries
    where notification_id = '15800000-0000-0000-0000-0000000000f1'),
  '0|0',
  'TENANT: a same-tenant peer and a rival tenant''s user each read none of them');
reset role;

select * from finish();
rollback;
