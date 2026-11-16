-- pgTAP: Batch 6 slice 53 (conversation_messages, CHAT-3 and CHAT-4) --
-- a conversation message is timed and recorded on every door (`20261115180000`).
-- ATTACK-CLASSES: AUTH=N/A TENANT=N/A DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE=N/A BUSINESS=N/A OBSERVABILITY
--   AUTH=N/A -- SEND_MESSAGE is the unchanged capability guard (tests 57, 58, 67).
--   TENANT=N/A -- tenant and parent visibility are the unchanged policy (tests 67, 88).
--   STATE=N/A -- a closed conversation is the unchanged parent-state guard (test 88).
--   CONCURRENCY, REPLAY=N/A -- each message is its own row; sending twice is two messages, as through the RPC.
--   PRIVILEGE=N/A -- no grant changes; the sender and rewrite guards are unchanged (test 67).
--   BUSINESS=N/A -- a message carries no money.
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email) values
  ('17100000-0000-0000-0000-0000000000a1','employee@c171.test');
insert into public.tenants (id, name, slug, status) values
  ('17100000-0000-0000-0000-000000000001','Message Travel','message-travel-171','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '17100000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('17100000-0000-0000-0000-00000000000a','17100000-0000-0000-0000-000000000001','Giza','giza-171');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('17100000-0000-0000-0000-0000000000c1','17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-00000000000a','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('17100000-0000-0000-0000-000000000011','17100000-0000-0000-0000-000000000001','Employee','employee@c171.test',true,'17100000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-000000000011','17100000-0000-0000-0000-00000000000a','17100000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '17100000-0000-0000-0000-000000000001', '17100000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'employee';
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('17100000-0000-0000-0000-0000000000d1','17100000-0000-0000-0000-000000000001','person','Message Customer');
insert into public.conversations (id, tenant_id, customer_id, owner_user_id, owner_branch_id, owner_department_id,
                                  current_branch_id, current_department_id, channel_code, conversation_status_code,
                                  created_at, updated_at) values
  ('17100000-0000-0000-0000-0000000000f1','17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-0000000000d1',
   '17100000-0000-0000-0000-000000000011','17100000-0000-0000-0000-00000000000a','17100000-0000-0000-0000-0000000000c1',
   '17100000-0000-0000-0000-00000000000a','17100000-0000-0000-0000-0000000000c1','whatsapp','open',
   now() - interval '2 days', now() - interval '2 days');

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.conversation_messages'::regclass and not tgisinternal
     and tgname = 'conversation_messages_emit_recorded'),
  1, 'the emitter is installed on conversation_messages');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17100000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

select lives_ok(
  $$insert into public.conversation_messages (id, tenant_id, conversation_id, sender_type_code, message_direction_code,
                                              message_text, sent_at, received_at)
    values ('17100000-0000-0000-0000-0000000000e1','17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-0000000000f1',
            'user','outbound','  door  ','2019-01-01',now() + interval '1 year')$$,
  'an employee sends a message at the table door, naming 2019 and a year ahead');
select throws_ok(
  $$update public.conversation_messages set sent_at = '2019-01-01'
    where id = '17100000-0000-0000-0000-0000000000e1'$$,
  '42501', null, 'CHAT-4: the employee cannot back-date the derived time afterwards');

reset role;
select is(
  (select count(*)::int from public.events e join public.users u on u.id = e.actor_user_id
   where e.event_type_code = 'conversation_message_sent' and u.full_name = 'Employee'
     and e.entity_type = 'conversation' and e.entity_id = '17100000-0000-0000-0000-0000000000f1'
     and e.payload ->> 'message_id' = '17100000-0000-0000-0000-0000000000e1' and e.payload ->> 'direction' = 'outbound'),
  1, 'CHAT-3: the door message is recorded once, by its actor, on its conversation');
select ok(
  (select updated_at = now() from public.conversations where id = '17100000-0000-0000-0000-0000000000f1'),
  'CHAT-3: the door message moves its conversation');
select is(
  (select message_text || ' sent=' || (sent_at = now()) || ' recv=' || coalesce(received_at::text, 'none')
   from public.conversation_messages where id = '17100000-0000-0000-0000-0000000000e1'),
  'door sent=true recv=none', 'CHAT-4: the door message''s times and text are derived, not supplied');
set local role authenticated;

insert into public.conversation_messages (id, tenant_id, conversation_id, sender_type_code, message_direction_code,
                                          message_text, sent_at)
values ('17100000-0000-0000-0000-0000000000e2','17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-0000000000f1',
        'customer','inbound','   ','2019-01-01');
create temp table rpc_msg on commit drop as
select app.send_conversation_message('17100000-0000-0000-0000-0000000000f1', 'outbound', 'user', '  hi  ') as id;

reset role;
select is(
  (select coalesce(m.message_text, 'none') || ' sent=' || coalesce(m.sent_at::text, 'none') || ' recv=' || (m.received_at = now())
          || ' events=' || (select count(*) from public.events e where e.event_type_code = 'conversation_message_received'
                             and e.payload ->> 'message_id' = m.id::text)
   from public.conversation_messages m where m.id = '17100000-0000-0000-0000-0000000000e2'),
  'none sent=none recv=true events=1', 'an inbound door message is received now, holds no blank text and is recorded as received');
select is(
  (select count(*)::int from public.events where payload ->> 'message_id' = (select id from rpc_msg)::text),
  1, 'the RPC message is recorded once, not twice');
select is(
  (select message_text || ' sent=' || (sent_at = now()) from public.conversation_messages where id = (select id from rpc_msg)),
  'hi sent=true', 'the RPC message keeps its trimmed text and its time');

select set_config('request.jwt.claims', null, true);
insert into public.conversation_messages (id, tenant_id, conversation_id, sender_type_code, message_direction_code,
                                          message_text, received_at)
values ('17100000-0000-0000-0000-0000000000e3','17100000-0000-0000-0000-000000000001','17100000-0000-0000-0000-0000000000f1',
        'customer','inbound','replayed','2026-01-01');
select is(
  (select received_at::date::text from public.conversation_messages where id = '17100000-0000-0000-0000-0000000000e3'),
  '2026-01-01', 'a session-less integration keeps the time it received the message');
select is(
  (select count(*)::int from public.events
   where payload ->> 'message_id' = '17100000-0000-0000-0000-0000000000e3' and actor_user_id is null),
  1, 'a session-less message is recorded too, with no actor');

select * from finish();
rollback;
