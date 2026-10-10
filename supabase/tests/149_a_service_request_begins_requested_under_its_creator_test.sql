-- SPEC-257 (Batch 6 Slice 35): both service-request doors give one initial state, one owner and
-- filing scope, one created event, one event per lifecycle move, a server-stamped resolution time and
-- a reasoned reopen; a signed-in UPDATE cannot move the owner or scope.
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE OBSERVABILITY PRIVILEGE INPUT BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A
--   BUSINESS=N/A: a service request carries no money; customer-booking coherence is stated by no
--     canon rule on either door and is recorded, not invented, in the disposition record.
--   CONCURRENCY=N/A: creation reads no shared row and claims nothing; two creations are two rows, and
--     two moves of one request are serialized by its row lock and judged by the unchanged
--     status-transition trigger.
--   REPLAY=N/A: creation is not idempotent by design; repeating it opens another request on purpose.
create extension if not exists pgtap with schema extensions;

begin;
select plan(48);

insert into auth.users(id,email) values
  ('a3570000-0000-0000-0000-0000000000a1','employee@sr257.test'),
  ('a3570000-0000-0000-0000-0000000000a2','trainee@sr257.test'),
  ('a3570000-0000-0000-0000-0000000000a3','colleague@sr257.test'),
  ('a3570000-0000-0000-0000-0000000000a5','nobranch@sr257.test');
insert into public.tenants(id,name,slug,status) values
  ('a3570000-0000-0000-0000-000000000001','SR257 Travel','sr257-travel','active'),
  ('a3570000-0000-0000-0000-000000000009','SR257 Rival','sr257-rival','active');
insert into public.subscriptions(tenant_id,subscription_plan_id,subscription_status_code)
select 'a3570000-0000-0000-0000-000000000001',id,'active'
from public.subscription_plans where plan_code='enterprise';
insert into public.branches(id,tenant_id,name,slug) values
  ('a3570000-0000-0000-0000-000000000002','a3570000-0000-0000-0000-000000000001','Main','sr257-main'),
  ('a3570000-0000-0000-0000-000000000004','a3570000-0000-0000-0000-000000000001','Other','sr257-other');
insert into public.departments(id,tenant_id,branch_id,department_type_code,name) values
  ('a3570000-0000-0000-0000-000000000003','a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-000000000002','sales','Sales'),
  ('a3570000-0000-0000-0000-000000000005','a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-000000000004','sales','Other Sales');
insert into public.users(id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('a3570000-0000-0000-0000-000000000011','a3570000-0000-0000-0000-000000000001','Employee','employee@sr257.test',true,'a3570000-0000-0000-0000-0000000000a1'),
  ('a3570000-0000-0000-0000-000000000012','a3570000-0000-0000-0000-000000000001','Trainee','trainee@sr257.test',true,'a3570000-0000-0000-0000-0000000000a2'),
  ('a3570000-0000-0000-0000-000000000013','a3570000-0000-0000-0000-000000000001','Colleague','colleague@sr257.test',true,'a3570000-0000-0000-0000-0000000000a3'),
  ('a3570000-0000-0000-0000-000000000015','a3570000-0000-0000-0000-000000000001','Nobranch','nobranch@sr257.test',true,'a3570000-0000-0000-0000-0000000000a5');
insert into public.user_branch_assignments(tenant_id,user_id,branch_id,department_id,is_primary) values
  ('a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-000000000011','a3570000-0000-0000-0000-000000000002','a3570000-0000-0000-0000-000000000003',true),
  ('a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-000000000012','a3570000-0000-0000-0000-000000000002','a3570000-0000-0000-0000-000000000003',true),
  ('a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-000000000013','a3570000-0000-0000-0000-000000000004','a3570000-0000-0000-0000-000000000005',true);
insert into public.user_role_assignments(tenant_id,user_id,role_id,scope_type)
select 'a3570000-0000-0000-0000-000000000001',v.u,r.id,'tenant'
from (values ('a3570000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('a3570000-0000-0000-0000-000000000012'::uuid,'trainee'),
             ('a3570000-0000-0000-0000-000000000013'::uuid,'employee'),
             ('a3570000-0000-0000-0000-000000000015'::uuid,'employee')) v(u,code)
join public.roles r on r.code=v.code;
insert into public.customers(id,tenant_id,customer_type_code,full_name,primary_phone) values
  ('a3570000-0000-0000-0000-0000000000c1','a3570000-0000-0000-0000-000000000001','person','SR257 Customer','+201000025701');

-- The employee: Main / Sales, CREATE_SERVICE_REQUEST and RESOLVE_SERVICE_REQUEST, no ARCHIVE_RECORD.
select set_config('request.jwt.claims','{"sub":"a3570000-0000-0000-0000-0000000000a1"}',true);
set local role authenticated;
select ok(current_user = 'authenticated'
    and auth.uid() = 'a3570000-0000-0000-0000-0000000000a1'::uuid
    and app.has_permission('CREATE_SERVICE_REQUEST') and not app.has_permission('ARCHIVE_RECORD'),
    'the actor is the employee, holding CREATE_SERVICE_REQUEST and not ARCHIVE_RECORD');
select is((select count(*)::int from public.customers where id='a3570000-0000-0000-0000-0000000000c1'),1,
    'the employee sees the parent customer');
select lives_ok($$
  insert into public.service_requests(id,tenant_id,customer_id,service_request_type_code,service_request_status_code,title,
    owner_user_id,owner_branch_id,owner_department_id)
  values ('a3570000-0000-0000-0000-0000000000d1','a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-0000000000c1',
    'other','requested','Forged owner',
    'a3570000-0000-0000-0000-000000000013','a3570000-0000-0000-0000-000000000002','a3570000-0000-0000-0000-000000000003')
$$,'a direct creation naming a colleague as owner succeeds');
select lives_ok($$
  insert into public.service_requests(id,tenant_id,customer_id,service_request_type_code,service_request_status_code,title,
    owner_user_id,owner_branch_id,owner_department_id)
  values ('a3570000-0000-0000-0000-0000000000d2','a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-0000000000c1',
    'other','requested','Forged filing',
    'a3570000-0000-0000-0000-000000000011','a3570000-0000-0000-0000-000000000004','a3570000-0000-0000-0000-000000000005')
$$,'a direct creation filed under another branch and department succeeds');
select ok((select owner_user_id='a3570000-0000-0000-0000-000000000011'::uuid
    and owner_branch_id='a3570000-0000-0000-0000-000000000002'::uuid
    and owner_department_id='a3570000-0000-0000-0000-000000000003'::uuid
    from public.service_requests where id='a3570000-0000-0000-0000-0000000000d1'),
    'the forged owner is replaced by the creator and the creator''s placement');
select ok((select owner_branch_id='a3570000-0000-0000-0000-000000000002'::uuid
    and owner_department_id='a3570000-0000-0000-0000-000000000003'::uuid
    from public.service_requests where id='a3570000-0000-0000-0000-0000000000d2'),
    'the forged filing scope is replaced by the creator''s placement');
select is((select count(*)::int from public.events where event_type_code='service_request_created'
    and entity_id in ('a3570000-0000-0000-0000-0000000000d1','a3570000-0000-0000-0000-0000000000d2')),2,
    'each direct creation emits exactly one created event');
select ok((select entity_type='service_request' and previous_state is null and new_state='requested'
    and actor_user_id='a3570000-0000-0000-0000-000000000011'::uuid
    and payload->>'customer_id'='a3570000-0000-0000-0000-0000000000c1'
    and payload->>'service_request_type_code'='other'
    from public.events where event_type_code='service_request_created'
      and entity_id='a3570000-0000-0000-0000-0000000000d1'),
    'the direct event carries the request, its state, the creator and the RPC''s payload');
select is((select count(*)::int from app.customer_timeline('a3570000-0000-0000-0000-0000000000c1')
    where event_type_code='service_request_created'),2,'both direct creations reach the customer timeline');

select set_config('sr257.rpc_id',app.create_service_request('a3570000-0000-0000-0000-0000000000c1','Through the RPC','other')::text,true);
select is((select count(*)::int from public.service_requests where id=current_setting('sr257.rpc_id')::uuid
    and service_request_status_code='requested' and owner_user_id='a3570000-0000-0000-0000-000000000011'
    and owner_branch_id='a3570000-0000-0000-0000-000000000002'),1,
    'the RPC returns a persisted requested request owned and filed by the actor');
select is((select count(*)::int from public.events where event_type_code='service_request_created'
    and entity_id=current_setting('sr257.rpc_id')::uuid
    and actor_user_id='a3570000-0000-0000-0000-000000000011'),1,'the RPC emits exactly one created event, attributed to the actor');
select throws_ok($$update public.service_requests set owner_user_id='a3570000-0000-0000-0000-000000000013'
    where id=current_setting('sr257.rpc_id')::uuid$$,
    '23514',null,'the creator cannot hand the request to a colleague in another branch afterwards');
select throws_ok($$update public.service_requests set owner_branch_id='a3570000-0000-0000-0000-000000000004',
      owner_department_id='a3570000-0000-0000-0000-000000000005'
    where id=current_setting('sr257.rpc_id')::uuid$$,
    '23514',null,'the creator cannot refile the request under another branch afterwards');
select lives_ok($$update public.service_requests set title='Through the RPC, retitled'
    where id=current_setting('sr257.rpc_id')::uuid$$,
    'an ordinary edit of the request still succeeds');

select throws_ok($$insert into public.service_requests(tenant_id,customer_id,service_request_type_code,service_request_status_code,title,owner_user_id,owner_branch_id,owner_department_id)
    values ('a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-0000000000c1','other','closed','Born closed','a3570000-0000-0000-0000-000000000011','a3570000-0000-0000-0000-000000000002','a3570000-0000-0000-0000-000000000003')$$,
    '23514',null,'a request cannot be created closed');
select throws_ok($$insert into public.service_requests(tenant_id,customer_id,service_request_type_code,service_request_status_code,title,resolved_at,owner_user_id,owner_branch_id,owner_department_id)
    values ('a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-0000000000c1','other','requested','Born resolved','2020-01-01','a3570000-0000-0000-0000-000000000011','a3570000-0000-0000-0000-000000000002','a3570000-0000-0000-0000-000000000003')$$,
    '23514',null,'a request cannot be created with a resolution time');
select throws_ok($$insert into public.service_requests(tenant_id,customer_id,service_request_type_code,service_request_status_code,title,
      is_archived,archived_at,archive_reason,owner_user_id,owner_branch_id,owner_department_id)
    values ('a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-0000000000c1','other','requested','Born archived',
      true,'2020-01-01','forged narrative','a3570000-0000-0000-0000-000000000011','a3570000-0000-0000-0000-000000000002','a3570000-0000-0000-0000-000000000003')$$,
    '23514',null,'a request cannot be created archived without ARCHIVE_RECORD');
select throws_ok($$insert into public.service_requests(tenant_id,customer_id,service_request_type_code,service_request_status_code,title,archived_by,owner_user_id,owner_branch_id,owner_department_id)
    values ('a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-0000000000c1','other','requested','Forged archiver',
      'a3570000-0000-0000-0000-000000000013','a3570000-0000-0000-0000-000000000011','a3570000-0000-0000-0000-000000000002','a3570000-0000-0000-0000-000000000003')$$,
    '23514',null,'a request cannot be created naming an archiver');
select throws_ok($$insert into public.service_requests(tenant_id,customer_id,service_request_type_code,service_request_status_code,title)
    values ('a3570000-0000-0000-0000-000000000009','a3570000-0000-0000-0000-0000000000c1','other','requested','Rival tenant')$$,
    '42501',null,'a request cannot be created under another tenant');
select is((select count(*)::int from public.events where event_type_code='service_request_created'
    and tenant_id='a3570000-0000-0000-0000-000000000001'),3,'refused creations emit no created event');
select lives_ok($$select app.advance_service_request(current_setting('sr257.rpc_id')::uuid,'in_progress','work started')$$,
    'the RPC still advances a request created through it');
select is((select count(*)::int from public.events where event_type_code='service_request_in_progress'
    and entity_id=current_setting('sr257.rpc_id')::uuid),1,'the transition still emits exactly one event');

-- The colleague: Other / Other Sales, an employee with department visibility there.
reset role;
select set_config('request.jwt.claims','{"sub":"a3570000-0000-0000-0000-0000000000a3"}',true);
set local role authenticated;
select ok(auth.uid() = 'a3570000-0000-0000-0000-0000000000a3'::uuid and app.has_permission('VIEW_SERVICE_REQUEST'),
    'the colleague holds VIEW_SERVICE_REQUEST');
select is((select count(*)::int from public.service_requests
    where id in ('a3570000-0000-0000-0000-0000000000d1','a3570000-0000-0000-0000-0000000000d2')),0,
    'the colleague named as owner, and the branch named as filing scope, see neither request');

-- An employee with no primary branch assignment.
reset role;
select set_config('request.jwt.claims','{"sub":"a3570000-0000-0000-0000-0000000000a5"}',true);
set local role authenticated;
select throws_ok($$insert into public.service_requests(tenant_id,customer_id,service_request_type_code,service_request_status_code,title,owner_user_id)
    values ('a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-0000000000c1','other','requested','No branch',
      'a3570000-0000-0000-0000-000000000015')$$,
    '42501',null,'a creator with no primary branch is refused, as the RPC refuses it');

-- The trainee: Main / Sales, without CREATE_SERVICE_REQUEST.
reset role;
select set_config('request.jwt.claims','{"sub":"a3570000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;
select ok(auth.uid() = 'a3570000-0000-0000-0000-0000000000a2'::uuid and not app.has_permission('CREATE_SERVICE_REQUEST'),
    'the trainee lacks CREATE_SERVICE_REQUEST');
select throws_ok($$insert into public.service_requests(tenant_id,customer_id,service_request_type_code,service_request_status_code,title)
    values ('a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-0000000000c1','other','requested','Trainee')$$,
    '42501',null,'a trainee''s direct creation is refused');

-- Session-less platform writes keep their nullable owner, and the entry state still binds them.
reset role;
select set_config('request.jwt.claims','',true);
select throws_ok($$insert into public.service_requests(tenant_id,customer_id,service_request_type_code,service_request_status_code,title)
    values ('a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-0000000000c1','other','closed','Platform closed')$$,
    '23514',null,'a session-less creation cannot be created closed either');
insert into public.service_requests(id,tenant_id,customer_id,service_request_type_code,service_request_status_code,title)
values ('a3570000-0000-0000-0000-0000000000d3','a3570000-0000-0000-0000-000000000001',
    'a3570000-0000-0000-0000-0000000000c1','other','requested','Platform');
select ok((select owner_user_id is null and owner_branch_id is null
    from public.service_requests where id='a3570000-0000-0000-0000-0000000000d3'),
    'a session-less creation keeps its nullable owner');
select is((select count(*)::int from public.events where event_type_code='service_request_created'
    and entity_id='a3570000-0000-0000-0000-0000000000d3' and actor_user_id is null and new_state='requested'),1,
    'a session-less creation emits once and invents no actor');

select is((select count(*)::int from pg_trigger where tgname='service_requests_guard_integrity'
    and tgrelid='public.service_requests'::regclass and tgenabled='O' and tgtype=23),1,
    'one enabled row-level BEFORE INSERT OR UPDATE guard');
select is((select count(*)::int from pg_trigger where tgname='service_requests_emit_created'
    and tgrelid='public.service_requests'::regclass and tgenabled='O' and tgtype=5),1,
    'one enabled row-level AFTER INSERT event producer');
select ok(coalesce((select not prosecdef and not has_function_privilege('authenticated',oid,'EXECUTE')
    from pg_proc where oid=to_regprocedure('app.guard_service_request_integrity()')),false),
    'the guard is SECURITY INVOKER and not directly executable');
select ok(coalesce((select not prosecdef and not has_function_privilege('authenticated',oid,'EXECUTE')
    from pg_proc where oid=to_regprocedure('app.emit_service_request_created()')),false),
    'the event producer is SECURITY INVOKER and not directly executable');

-- SR-2: the request's life after creation, on both doors. The employee again.
select set_config('request.jwt.claims','{"sub":"a3570000-0000-0000-0000-0000000000a1"}',true);
set local role authenticated;
update public.service_requests set service_request_status_code='in_progress'
where id='a3570000-0000-0000-0000-0000000000d1';
update public.service_requests set service_request_status_code='resolved', resolved_at='2001-01-01'
where id='a3570000-0000-0000-0000-0000000000d1';
update public.service_requests set resolved_at='2019-05-05' where id='a3570000-0000-0000-0000-0000000000d1';
update public.service_requests set service_request_status_code='resolved' where id='a3570000-0000-0000-0000-0000000000d1';
update public.service_requests set service_request_status_code='closed' where id='a3570000-0000-0000-0000-0000000000d1';
select is((select string_agg(event_type_code||':'||previous_state||'>'||new_state||':'||coalesce(actor_user_id::text,'-'),','
      order by event_type_code)
    from public.events where entity_id='a3570000-0000-0000-0000-0000000000d1' and event_type_code<>'service_request_created'),
    'service_request_closed:resolved>closed:a3570000-0000-0000-0000-000000000011,'
    'service_request_in_progress:requested>in_progress:a3570000-0000-0000-0000-000000000011,'
    'service_request_resolved:in_progress>resolved:a3570000-0000-0000-0000-000000000011',
    'each direct lifecycle move records exactly one canon-26 event as its actor; a no-op or field-only update records none');
select ok((select service_request_status_code='closed' and resolved_at=now()
    from public.service_requests where id='a3570000-0000-0000-0000-0000000000d1'),
    'the resolution time is the server''s: a forged resolved_at, at resolution or afterwards, does not stand');
select throws_ok($$update public.service_requests set service_request_status_code='in_progress'
    where id='a3570000-0000-0000-0000-0000000000d1'$$,
    '23514',null,'a closed request cannot be reopened at the table without a reason');
select app.advance_service_request('a3570000-0000-0000-0000-0000000000d2','in_progress','started');
select app.advance_service_request('a3570000-0000-0000-0000-0000000000d2','resolved','done');
select app.advance_service_request('a3570000-0000-0000-0000-0000000000d2','closed','confirmed');
select throws_ok($$select app.advance_service_request('a3570000-0000-0000-0000-0000000000d2','in_progress')$$,
    '23514',null,'the RPC cannot reopen a closed request without a reason (canon 27)');
select app.advance_service_request(current_setting('sr257.rpc_id')::uuid,'resolved','done');
select app.advance_service_request(current_setting('sr257.rpc_id')::uuid,'closed','confirmed');
select lives_ok($$select app.advance_service_request(current_setting('sr257.rpc_id')::uuid,'in_progress','the customer called back')$$,
    'the RPC reopens a closed request with a reason');
select is((select count(*)::int from public.events where entity_id=current_setting('sr257.rpc_id')::uuid
    and event_type_code='service_request_reopened' and previous_state='closed' and new_state='in_progress'
    and reason='the customer called back' and severity_code='warning'
    and actor_user_id='a3570000-0000-0000-0000-000000000011'),1,
    'the reopen records one warning event with its reason and actor (canon 27)');
select throws_ok($$update public.service_requests set service_request_status_code='in_progress'
    where id='a3570000-0000-0000-0000-0000000000d1'$$,
    '23514',null,'a reason handed to one transition is consumed by it and opens no other');
select is((select string_agg(event_type_code,',' order by event_type_code) from public.events
    where entity_id=current_setting('sr257.rpc_id')::uuid and event_type_code<>'service_request_created'),
    'service_request_closed,service_request_in_progress,service_request_reopened,service_request_resolved',
    'each RPC transition records exactly one event, none twice');
select throws_ok($$insert into public.service_requests(tenant_id,customer_id,service_request_type_code,service_request_status_code,title)
    values ('a3570000-0000-0000-0000-000000000001','a3570000-0000-0000-0000-0000000000c1','other','requested','   ')$$,
    '23514',null,'a request cannot be created at the table with a blank title, as the RPC refuses it');
select throws_ok($$update public.service_requests set title='' where id=current_setting('sr257.rpc_id')::uuid$$,
    '23514',null,'a request''s title cannot be blanked afterwards');

-- Session-less platform moves are recorded without an actor and keep their latitude.
reset role;
select set_config('request.jwt.claims','',true);
update public.service_requests set service_request_status_code='in_progress' where id='a3570000-0000-0000-0000-0000000000d3';
update public.service_requests set service_request_status_code='resolved', resolved_at='2020-02-02'
where id='a3570000-0000-0000-0000-0000000000d3';
select is((select count(*)::int from public.events where entity_id='a3570000-0000-0000-0000-0000000000d3'
    and event_type_code in ('service_request_in_progress','service_request_resolved') and actor_user_id is null),2,
    'session-less moves record one event each and invent no actor');
select ok((select resolved_at='2020-02-02'::timestamptz
    from public.service_requests where id='a3570000-0000-0000-0000-0000000000d3'),
    'a session-less write keeps the resolution time it carries, as a historical import would');

select is((select count(*)::int from pg_trigger where tgname='service_requests_emit_transition'
    and tgrelid='public.service_requests'::regclass and tgenabled='O' and tgtype=17),1,
    'one enabled row-level AFTER UPDATE transition producer');
select ok(coalesce((select not prosecdef and not has_function_privilege('authenticated',oid,'EXECUTE')
    from pg_proc where oid=to_regprocedure('app.emit_service_request_transition()')),false),
    'the transition producer is SECURITY INVOKER and not directly executable');

select finish();
rollback;
