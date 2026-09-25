-- SPEC-220: both creation doors have one creator, initial state and start event.
-- ATTACK-CLASSES: AUTH TENANT DOOR INPUT OBSERVABILITY REPLAY
create extension if not exists pgtap with schema extensions;

begin;
select plan(31);

insert into auth.users(id,email) values
  ('a2190000-0000-0000-0000-0000000000a1','employee@chat1.test'),
  ('a2190000-0000-0000-0000-0000000000a2','trainee@chat1.test'),
  ('a2190000-0000-0000-0000-0000000000a3','colleague@chat1.test');
insert into public.tenants(id,name,slug,status) values
  ('a2190000-0000-0000-0000-000000000001','CHAT1 Travel','chat1-travel','active');
insert into public.subscriptions(tenant_id,subscription_plan_id,subscription_status_code)
select 'a2190000-0000-0000-0000-000000000001',id,'active'
from public.subscription_plans where plan_code='enterprise';
insert into public.branches(id,tenant_id,name,slug) values
  ('a2190000-0000-0000-0000-000000000002','a2190000-0000-0000-0000-000000000001','Main','chat1-main'),
  ('a2190000-0000-0000-0000-000000000004','a2190000-0000-0000-0000-000000000001','Other','chat1-other');
insert into public.departments(id,tenant_id,branch_id,department_type_code,name) values
  ('a2190000-0000-0000-0000-000000000003','a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-000000000002','sales','Sales'),
  ('a2190000-0000-0000-0000-000000000005','a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-000000000004','sales','Other Sales');
insert into public.users(id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('a2190000-0000-0000-0000-000000000011','a2190000-0000-0000-0000-000000000001','Employee','employee@chat1.test',true,'a2190000-0000-0000-0000-0000000000a1'),
  ('a2190000-0000-0000-0000-000000000012','a2190000-0000-0000-0000-000000000001','Trainee','trainee@chat1.test',true,'a2190000-0000-0000-0000-0000000000a2'),
  ('a2190000-0000-0000-0000-000000000013','a2190000-0000-0000-0000-000000000001','Colleague','colleague@chat1.test',true,'a2190000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments(tenant_id,user_id,branch_id,department_id,is_primary) values
  ('a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-000000000011','a2190000-0000-0000-0000-000000000002','a2190000-0000-0000-0000-000000000003',true),
  ('a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-000000000012','a2190000-0000-0000-0000-000000000002','a2190000-0000-0000-0000-000000000003',true),
  ('a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-000000000013','a2190000-0000-0000-0000-000000000004','a2190000-0000-0000-0000-000000000005',true);
insert into public.user_role_assignments(tenant_id,user_id,role_id,scope_type)
select 'a2190000-0000-0000-0000-000000000001',v.u,r.id,'tenant'
from (values ('a2190000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('a2190000-0000-0000-0000-000000000012'::uuid,'trainee'),
             ('a2190000-0000-0000-0000-000000000013'::uuid,'employee')) v(u,code)
join public.roles r on r.code=v.code;
insert into public.customers(id,tenant_id,customer_type_code,full_name,primary_phone) values
  ('a2190000-0000-0000-0000-0000000000c1','a2190000-0000-0000-0000-000000000001','person','CHAT1 Customer','+201000021900');

select set_config('request.jwt.claims','{"sub":"a2190000-0000-0000-0000-0000000000a1"}',true);
set local role authenticated;
select ok(app.has_permission('SEND_MESSAGE'),'employee holds SEND_MESSAGE');
select is((select count(*)::int from public.customers where id='a2190000-0000-0000-0000-0000000000c1'),1,'employee sees parent customer');
select lives_ok($$
  insert into public.conversations(id,tenant_id,customer_id,channel_code,conversation_status_code,
    owner_user_id,owner_branch_id,owner_department_id,current_branch_id,current_department_id,external_conversation_id)
  values ('a2190000-0000-0000-0000-0000000000d1','a2190000-0000-0000-0000-000000000001',
    'a2190000-0000-0000-0000-0000000000c1','whatsapp','open',
    'a2190000-0000-0000-0000-000000000013','a2190000-0000-0000-0000-000000000004',
    'a2190000-0000-0000-0000-000000000005','a2190000-0000-0000-0000-000000000004',
    'a2190000-0000-0000-0000-000000000005','chat1-direct')
$$,'authorized direct creation succeeds despite attempted owner forgery');
select is((select count(*)::int from public.conversations where id='a2190000-0000-0000-0000-0000000000d1'),1,'direct row persisted');
select ok((select conversation_status_code='open' and closed_at is null
    from public.conversations where id='a2190000-0000-0000-0000-0000000000d1'),'direct row begins open and unclosed');
select ok((select owner_user_id='a2190000-0000-0000-0000-000000000011'::uuid
    and owner_branch_id='a2190000-0000-0000-0000-000000000002'::uuid
    and owner_department_id='a2190000-0000-0000-0000-000000000003'::uuid
    and current_branch_id='a2190000-0000-0000-0000-000000000002'::uuid
    and current_department_id='a2190000-0000-0000-0000-000000000003'::uuid
    from public.conversations where id='a2190000-0000-0000-0000-0000000000d1'),
    'owner and filing scope derive from the caller placement');
select is((select count(*)::int from public.events where event_type_code='conversation_started'
    and entity_id='a2190000-0000-0000-0000-0000000000d1'),1,'direct creation emits exactly one event');
select ok((select entity_type='conversation' and new_state='open'
    and actor_user_id='a2190000-0000-0000-0000-000000000011'::uuid
    and payload->>'channel_code'='whatsapp'
    and payload->>'customer_id'='a2190000-0000-0000-0000-0000000000c1'
    and payload ? 'lead_id' and payload ? 'booking_id'
    from public.events where event_type_code='conversation_started'
      and entity_id='a2190000-0000-0000-0000-0000000000d1'),
    'direct event retains identity, state, actor and payload');
select is((select count(*)::int from app.customer_timeline('a2190000-0000-0000-0000-0000000000c1')
    where event_type_code='conversation_started'),1,'direct start reaches customer timeline');

select set_config('chat1.rpc_id',app.start_conversation('whatsapp',
    'a2190000-0000-0000-0000-0000000000c1')::text,true);
select is((select count(*)::int from public.conversations where id=current_setting('chat1.rpc_id')::uuid
    and conversation_status_code='open' and owner_user_id='a2190000-0000-0000-0000-000000000011'),1,
    'RPC returned a persisted open conversation owned by actor');
select is((select count(*)::int from public.events where event_type_code='conversation_started'
    and entity_id=current_setting('chat1.rpc_id')::uuid),1,'RPC emits exactly one event');
select is((select count(*)::int from app.customer_timeline('a2190000-0000-0000-0000-0000000000c1')
    where event_type_code='conversation_started'),2,'both starts reach customer timeline once');
select throws_ok($$insert into public.conversations(tenant_id,customer_id,channel_code,conversation_status_code)
    values ('a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-0000000000c1','whatsapp','closed')$$,
    '23514',null,'authenticated closed creation refused');
select throws_ok($$insert into public.conversations(tenant_id,customer_id,channel_code,conversation_status_code)
    values ('a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-0000000000c1','whatsapp','escalated')$$,
    '23514',null,'authenticated escalated creation refused');
select throws_ok($$insert into public.conversations(tenant_id,customer_id,channel_code,conversation_status_code,closed_at)
    values ('a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-0000000000c1','whatsapp','open',now())$$,
    '23514',null,'preclosed open creation refused');
select throws_ok($$insert into public.conversations(tenant_id,customer_id,channel_code,conversation_status_code,external_conversation_id)
    values ('a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-0000000000c1','whatsapp','open','chat1-direct')$$,
    '23505',null,'external thread deduplication remains');
select throws_ok($$insert into public.conversations(tenant_id,customer_id,channel_code,conversation_status_code)
    values ('a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-0000000000c1','carrier_pigeon','open')$$,
    '23514',null,'invalid channel catalog remains refused');
select is((select count(*)::int from public.events where event_type_code='conversation_started'
    and tenant_id='a2190000-0000-0000-0000-000000000001'),2,'all refused writes emitted no extra event');

reset role;
select set_config('request.jwt.claims','{"sub":"a2190000-0000-0000-0000-0000000000a3"}',true);
set local role authenticated;
select ok(app.has_permission('SEND_MESSAGE'),'colleague has conversation read capability');
select is((select count(*)::int from public.conversations where id='a2190000-0000-0000-0000-0000000000d1'),0,
    'colleague in other branch cannot read attempted forged-owner row');

reset role;
select set_config('request.jwt.claims','{"sub":"a2190000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;
select is((select count(*)::int from public.customers where id='a2190000-0000-0000-0000-0000000000c1'),1,
    'trainee sees parent before denial');
select ok(not app.has_permission('SEND_MESSAGE'),'trainee lacks SEND_MESSAGE');
select throws_ok($$insert into public.conversations(tenant_id,customer_id,channel_code,conversation_status_code)
    values ('a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-0000000000c1','whatsapp','open')$$,
    '42501',null,'trainee direct creation refused');

reset role;
select set_config('request.jwt.claims','',true);
select throws_ok($$insert into public.conversations(tenant_id,customer_id,channel_code,conversation_status_code)
    values ('a2190000-0000-0000-0000-000000000001','a2190000-0000-0000-0000-0000000000c1','whatsapp','closed')$$,
    '23514',null,'sessionless closed creation also refused');
insert into public.conversations(id,tenant_id,customer_id,channel_code,conversation_status_code)
values ('a2190000-0000-0000-0000-0000000000d2','a2190000-0000-0000-0000-000000000001',
    'a2190000-0000-0000-0000-0000000000c1','whatsapp','open');
select ok((select owner_user_id is null and owner_branch_id is null
    from public.conversations where id='a2190000-0000-0000-0000-0000000000d2'),
    'sessionless open creation retains nullable owner');
select ok((select actor_user_id is null and new_state='open'
    from public.events where event_type_code='conversation_started'
      and entity_id='a2190000-0000-0000-0000-0000000000d2'),
    'sessionless start event does not invent actor');
select is((select count(*)::int from public.events where event_type_code='conversation_started'
    and entity_id='a2190000-0000-0000-0000-0000000000d2'),1,'sessionless creation emits once');
select is((select count(*)::int from pg_trigger where tgname='conversations_guard_creation'
    and tgrelid='public.conversations'::regclass and tgenabled='O' and tgtype=7),1,
    'one enabled row-level BEFORE INSERT creation guard');
select is((select count(*)::int from pg_trigger where tgname='conversations_emit_started'
    and tgrelid='public.conversations'::regclass and tgenabled='O' and tgtype=5),1,
    'one enabled row-level AFTER INSERT event producer');
select ok((select not prosecdef and not has_function_privilege('authenticated',oid,'EXECUTE')
    from pg_proc where oid='app.guard_conversation_creation()'::regprocedure),
    'guard is invoker and not directly executable');
select ok((select not prosecdef and not has_function_privilege('authenticated',oid,'EXECUTE')
    from pg_proc where oid='app.emit_conversation_started()'::regprocedure),
    'emitter is invoker and not directly executable');

select finish();
rollback;
