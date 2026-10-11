-- SPEC-262 (Batch 6 Slice 39): both complaint doors give one initial state, one owner and filing
-- scope, one created event, one event per lifecycle move, a server-stamped resolution and closure
-- and a reasoned reopen; a signed-in UPDATE cannot move the owner or scope or rewrite the resolution.
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE OBSERVABILITY PRIVILEGE INPUT BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A
--   BUSINESS=N/A: a complaint carries no money; customer-booking coherence is stated by no canon rule
--     on either door and is recorded, not invented, in the disposition record.
--   CONCURRENCY=N/A: creation reads no shared row and claims nothing; two creations are two rows, and
--     two moves of one complaint are serialized by its row lock and judged by the unchanged
--     status-transition trigger.
--   REPLAY=N/A: creation is not idempotent by design; repeating it opens another complaint on purpose.
create extension if not exists pgtap with schema extensions;

begin;
select plan(53);

insert into auth.users(id,email) values
  ('a3620000-0000-0000-0000-0000000000a1','employee@c262.test'),
  ('a3620000-0000-0000-0000-0000000000a2','trainee@c262.test'),
  ('a3620000-0000-0000-0000-0000000000a3','colleague@c262.test'),
  ('a3620000-0000-0000-0000-0000000000a5','nobranch@c262.test');
insert into public.tenants(id,name,slug,status) values
  ('a3620000-0000-0000-0000-000000000001','C262 Travel','c262-travel','active'),
  ('a3620000-0000-0000-0000-000000000009','C262 Rival','c262-rival','active');
insert into public.subscriptions(tenant_id,subscription_plan_id,subscription_status_code)
select 'a3620000-0000-0000-0000-000000000001',id,'active'
from public.subscription_plans where plan_code='enterprise';
insert into public.branches(id,tenant_id,name,slug) values
  ('a3620000-0000-0000-0000-000000000002','a3620000-0000-0000-0000-000000000001','Main','c262-main'),
  ('a3620000-0000-0000-0000-000000000004','a3620000-0000-0000-0000-000000000001','Other','c262-other');
insert into public.departments(id,tenant_id,branch_id,department_type_code,name) values
  ('a3620000-0000-0000-0000-000000000003','a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-000000000002','sales','Sales'),
  ('a3620000-0000-0000-0000-000000000005','a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-000000000004','sales','Other Sales');
insert into public.users(id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('a3620000-0000-0000-0000-000000000011','a3620000-0000-0000-0000-000000000001','Employee','employee@c262.test',true,'a3620000-0000-0000-0000-0000000000a1'),
  ('a3620000-0000-0000-0000-000000000012','a3620000-0000-0000-0000-000000000001','Trainee','trainee@c262.test',true,'a3620000-0000-0000-0000-0000000000a2'),
  ('a3620000-0000-0000-0000-000000000013','a3620000-0000-0000-0000-000000000001','Colleague','colleague@c262.test',true,'a3620000-0000-0000-0000-0000000000a3'),
  ('a3620000-0000-0000-0000-000000000015','a3620000-0000-0000-0000-000000000001','Nobranch','nobranch@c262.test',true,'a3620000-0000-0000-0000-0000000000a5');
insert into public.user_branch_assignments(tenant_id,user_id,branch_id,department_id,is_primary) values
  ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-000000000011','a3620000-0000-0000-0000-000000000002','a3620000-0000-0000-0000-000000000003',true),
  ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-000000000012','a3620000-0000-0000-0000-000000000002','a3620000-0000-0000-0000-000000000003',true),
  ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-000000000013','a3620000-0000-0000-0000-000000000004','a3620000-0000-0000-0000-000000000005',true);
insert into public.user_role_assignments(tenant_id,user_id,role_id,scope_type)
select 'a3620000-0000-0000-0000-000000000001',v.u,r.id,'tenant'
from (values ('a3620000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('a3620000-0000-0000-0000-000000000012'::uuid,'trainee'),
             ('a3620000-0000-0000-0000-000000000013'::uuid,'employee'),
             ('a3620000-0000-0000-0000-000000000015'::uuid,'employee')) v(u,code)
join public.roles r on r.code=v.code;
insert into public.customers(id,tenant_id,customer_type_code,full_name,primary_phone) values
  ('a3620000-0000-0000-0000-0000000000c1','a3620000-0000-0000-0000-000000000001','person','C262 Customer','+201000026201');

-- The employee: Main / Sales, CREATE_COMPLAINT and RESOLVE_COMPLAINT, no ARCHIVE_RECORD.
select set_config('request.jwt.claims','{"sub":"a3620000-0000-0000-0000-0000000000a1"}',true);
set local role authenticated;
select ok(current_user = 'authenticated'
    and auth.uid() = 'a3620000-0000-0000-0000-0000000000a1'::uuid
    and app.has_permission('CREATE_COMPLAINT') and app.has_permission('RESOLVE_COMPLAINT')
    and not app.has_permission('ARCHIVE_RECORD'),
    'the actor is the employee, holding CREATE_COMPLAINT and RESOLVE_COMPLAINT and not ARCHIVE_RECORD');
select is((select count(*)::int from public.customers where id='a3620000-0000-0000-0000-0000000000c1'),1,
    'the employee sees the parent customer');
select lives_ok($$
  insert into public.complaints(id,tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title,
    owner_user_id,owner_branch_id,owner_department_id)
  values ('a3620000-0000-0000-0000-0000000000d1','a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1',
    'baggage','high','new','Forged owner',
    'a3620000-0000-0000-0000-000000000013','a3620000-0000-0000-0000-000000000002','a3620000-0000-0000-0000-000000000003')
$$,'a direct creation naming a colleague as owner succeeds');
select lives_ok($$
  insert into public.complaints(id,tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title,
    owner_user_id,owner_branch_id,owner_department_id)
  values ('a3620000-0000-0000-0000-0000000000d2','a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1',
    'other','normal','new','Forged filing',
    'a3620000-0000-0000-0000-000000000011','a3620000-0000-0000-0000-000000000004','a3620000-0000-0000-0000-000000000005')
$$,'a direct creation filed under another branch and department succeeds');
select ok((select owner_user_id='a3620000-0000-0000-0000-000000000011'::uuid
    and owner_branch_id='a3620000-0000-0000-0000-000000000002'::uuid
    and owner_department_id='a3620000-0000-0000-0000-000000000003'::uuid
    from public.complaints where id='a3620000-0000-0000-0000-0000000000d1'),
    'the forged owner is replaced by the creator and the creator''s placement');
select ok((select owner_branch_id='a3620000-0000-0000-0000-000000000002'::uuid
    and owner_department_id='a3620000-0000-0000-0000-000000000003'::uuid
    from public.complaints where id='a3620000-0000-0000-0000-0000000000d2'),
    'the forged filing scope is replaced by the creator''s placement');
select is((select count(*)::int from public.events where event_type_code='complaint_created'
    and entity_id in ('a3620000-0000-0000-0000-0000000000d1','a3620000-0000-0000-0000-0000000000d2')),2,
    'each direct creation emits exactly one created event');
select ok((select entity_type='complaint' and previous_state is null and new_state='new'
    and severity_code='warning'
    and actor_user_id='a3620000-0000-0000-0000-000000000011'::uuid
    and payload->>'customer_id'='a3620000-0000-0000-0000-0000000000c1'
    and payload->>'complaint_category_code'='baggage'
    and payload->>'complaint_severity_code'='high'
    from public.events where event_type_code='complaint_created'
      and entity_id='a3620000-0000-0000-0000-0000000000d1'),
    'the direct event carries the complaint, its state, the creator, the RPC''s payload and canon 27''s warning');
select is((select count(*)::int from app.customer_timeline('a3620000-0000-0000-0000-0000000000c1')
    where event_type_code='complaint_created'),2,'both direct creations reach the customer timeline');

select set_config('c262.rpc_id',app.create_complaint('a3620000-0000-0000-0000-0000000000c1','Through the RPC','other')::text,true);
select is((select count(*)::int from public.complaints where id=current_setting('c262.rpc_id')::uuid
    and complaint_status_code='new' and owner_user_id='a3620000-0000-0000-0000-000000000011'
    and owner_branch_id='a3620000-0000-0000-0000-000000000002'),1,
    'the RPC returns a persisted new complaint owned and filed by the actor');
select is((select count(*)::int from public.events where event_type_code='complaint_created'
    and entity_id=current_setting('c262.rpc_id')::uuid and severity_code='warning'
    and actor_user_id='a3620000-0000-0000-0000-000000000011'),1,
    'the RPC emits exactly one created event, attributed to the actor, as a warning');
select throws_ok($$update public.complaints set owner_user_id='a3620000-0000-0000-0000-000000000013'
    where id=current_setting('c262.rpc_id')::uuid$$,
    '23514',null,'the creator cannot hand the complaint to a colleague in another branch afterwards');
select throws_ok($$update public.complaints set owner_branch_id='a3620000-0000-0000-0000-000000000004',
      owner_department_id='a3620000-0000-0000-0000-000000000005'
    where id=current_setting('c262.rpc_id')::uuid$$,
    '23514',null,'the creator cannot refile the complaint under another branch afterwards');
select lives_ok($$update public.complaints set title='Through the RPC, retitled', description='more detail'
    where id=current_setting('c262.rpc_id')::uuid$$,
    'an ordinary edit of the complaint still succeeds');

select throws_ok($$insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title,owner_user_id,owner_branch_id,owner_department_id)
    values ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1','other','normal','closed','Born closed','a3620000-0000-0000-0000-000000000011','a3620000-0000-0000-0000-000000000002','a3620000-0000-0000-0000-000000000003')$$,
    '23514',null,'a complaint cannot be created closed');
select throws_ok($$insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title,resolved_at)
    values ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1','other','normal','new','Born resolved','2020-01-01')$$,
    '23514',null,'a complaint cannot be created with a resolution time');
select throws_ok($$insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title,closed_at)
    values ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1','other','normal','new','Born closed at','2020-01-02')$$,
    '23514',null,'a complaint cannot be created with a closure time');
select throws_ok($$insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title,resolution_notes)
    values ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1','other','normal','new','Born noted','forged resolution')$$,
    '23514',null,'a complaint cannot be created with a resolution note');
select throws_ok($$insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title,
      is_archived,archived_at,archive_reason)
    values ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1','other','normal','new','Born archived',
      true,'2020-01-01','forged narrative')$$,
    '23514',null,'a complaint cannot be created archived without ARCHIVE_RECORD');
select throws_ok($$insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title,archived_by)
    values ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1','other','normal','new','Forged archiver',
      'a3620000-0000-0000-0000-000000000013')$$,
    '23514',null,'a complaint cannot be created naming an archiver');
select throws_ok($$insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title)
    values ('a3620000-0000-0000-0000-000000000009','a3620000-0000-0000-0000-0000000000c1','other','normal','new','Rival tenant')$$,
    '42501',null,'a complaint cannot be created under another tenant');
select is((select count(*)::int from public.events where event_type_code='complaint_created'
    and tenant_id='a3620000-0000-0000-0000-000000000001'),3,'refused creations emit no created event');
select lives_ok($$select app.advance_complaint(current_setting('c262.rpc_id')::uuid,'acknowledged','logged with the customer')$$,
    'the RPC still advances a complaint created through it');
select is((select count(*)::int from public.events where event_type_code='complaint_acknowledged'
    and entity_id=current_setting('c262.rpc_id')::uuid and reason='logged with the customer'),1,
    'the transition still emits exactly one event with its reason');

-- The colleague: Other / Other Sales, an employee with department visibility there.
reset role;
select set_config('request.jwt.claims','{"sub":"a3620000-0000-0000-0000-0000000000a3"}',true);
set local role authenticated;
select ok(auth.uid() = 'a3620000-0000-0000-0000-0000000000a3'::uuid and app.has_permission('VIEW_COMPLAINT'),
    'the colleague holds VIEW_COMPLAINT');
select is((select count(*)::int from public.complaints
    where id in ('a3620000-0000-0000-0000-0000000000d1','a3620000-0000-0000-0000-0000000000d2')),0,
    'the colleague named as owner, and the branch named as filing scope, see neither complaint');

-- An employee with no primary branch assignment.
reset role;
select set_config('request.jwt.claims','{"sub":"a3620000-0000-0000-0000-0000000000a5"}',true);
set local role authenticated;
select throws_ok($$insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title,owner_user_id)
    values ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1','other','normal','new','No branch',
      'a3620000-0000-0000-0000-000000000015')$$,
    '42501',null,'a creator with no primary branch is refused, as the RPC refuses it');

-- The trainee: Main / Sales, without CREATE_COMPLAINT.
reset role;
select set_config('request.jwt.claims','{"sub":"a3620000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;
select ok(auth.uid() = 'a3620000-0000-0000-0000-0000000000a2'::uuid and not app.has_permission('CREATE_COMPLAINT'),
    'the trainee lacks CREATE_COMPLAINT');
select throws_ok($$insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title)
    values ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1','other','normal','new','Trainee')$$,
    '42501',null,'a trainee''s direct creation is refused');

-- Session-less platform writes keep their nullable owner, and the entry state still binds them.
reset role;
select set_config('request.jwt.claims','',true);
select throws_ok($$insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title)
    values ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1','other','normal','closed','Platform closed')$$,
    '23514',null,'a session-less creation cannot be created closed either');
insert into public.complaints(id,tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title)
values ('a3620000-0000-0000-0000-0000000000d3','a3620000-0000-0000-0000-000000000001',
    'a3620000-0000-0000-0000-0000000000c1','other','normal','new','Platform');
select ok((select owner_user_id is null and owner_branch_id is null
    from public.complaints where id='a3620000-0000-0000-0000-0000000000d3'),
    'a session-less creation keeps its nullable owner');
select is((select count(*)::int from public.events where event_type_code='complaint_created'
    and entity_id='a3620000-0000-0000-0000-0000000000d3' and actor_user_id is null and new_state='new'),1,
    'a session-less creation emits once and invents no actor');

select is((select count(*)::int from pg_trigger where tgname='complaints_guard_integrity'
    and tgrelid='public.complaints'::regclass and tgenabled='O' and tgtype=23),1,
    'one enabled row-level BEFORE INSERT OR UPDATE guard');
select is((select count(*)::int from pg_trigger where tgname='complaints_emit_created'
    and tgrelid='public.complaints'::regclass and tgenabled='O' and tgtype=5),1,
    'one enabled row-level AFTER INSERT event producer');
select ok(coalesce((select not prosecdef and not has_function_privilege('authenticated',oid,'EXECUTE')
    from pg_proc where oid=to_regprocedure('app.guard_complaint_integrity()')),false),
    'the guard is SECURITY INVOKER and not directly executable');
select ok(coalesce((select not prosecdef and not has_function_privilege('authenticated',oid,'EXECUTE')
    from pg_proc where oid=to_regprocedure('app.emit_complaint_created()')),false),
    'the event producer is SECURITY INVOKER and not directly executable');

-- COMP-3: the complaint's life after creation, on both doors. The employee again.
select set_config('request.jwt.claims','{"sub":"a3620000-0000-0000-0000-0000000000a1"}',true);
set local role authenticated;
update public.complaints set complaint_status_code='acknowledged' where id='a3620000-0000-0000-0000-0000000000d1';
update public.complaints set complaint_status_code='in_progress' where id='a3620000-0000-0000-0000-0000000000d1';
update public.complaints set complaint_status_code='resolved', resolved_at='2001-01-01', resolution_notes='forged at resolve'
where id='a3620000-0000-0000-0000-0000000000d1';
update public.complaints set resolved_at='2019-05-05', resolution_notes='rewritten later'
where id='a3620000-0000-0000-0000-0000000000d1';
update public.complaints set complaint_status_code='resolved' where id='a3620000-0000-0000-0000-0000000000d1';
update public.complaints set complaint_status_code='closed', closed_at='2001-02-02' where id='a3620000-0000-0000-0000-0000000000d1';
select is((select string_agg(event_type_code||':'||previous_state||'>'||new_state||':'||coalesce(actor_user_id::text,'-'),','
      order by event_type_code)
    from public.events where entity_id='a3620000-0000-0000-0000-0000000000d1' and event_type_code<>'complaint_created'),
    'complaint_acknowledged:new>acknowledged:a3620000-0000-0000-0000-000000000011,'
    'complaint_closed:resolved>closed:a3620000-0000-0000-0000-000000000011,'
    'complaint_in_progress:acknowledged>in_progress:a3620000-0000-0000-0000-000000000011,'
    'complaint_resolved:in_progress>resolved:a3620000-0000-0000-0000-000000000011',
    'each direct lifecycle move records exactly one canon-26 event as its actor; a no-op or field-only update records none');
select ok((select complaint_status_code='closed' and resolved_at=now() and closed_at=now() and resolution_notes is null
    from public.complaints where id='a3620000-0000-0000-0000-0000000000d1'),
    'the resolution and closure times and the resolution note are the server''s: forged values, at the move or afterwards, do not stand');
select throws_ok($$update public.complaints set complaint_status_code='in_progress'
    where id='a3620000-0000-0000-0000-0000000000d1'$$,
    '23514',null,'a closed complaint cannot be reopened at the table without a reason');
select app.advance_complaint('a3620000-0000-0000-0000-0000000000d2','acknowledged');
select app.advance_complaint('a3620000-0000-0000-0000-0000000000d2','in_progress');
select app.advance_complaint('a3620000-0000-0000-0000-0000000000d2','resolved','the bag was found and delivered');
select app.advance_complaint('a3620000-0000-0000-0000-0000000000d2','closed','customer satisfied');
select ok((select resolution_notes='the bag was found and delivered' and resolved_at=now() and closed_at=now()
    from public.complaints where id='a3620000-0000-0000-0000-0000000000d2'),
    'the RPC records the resolving reason as the resolution note (COMP-1) and stamps both times');
update public.complaints set resolution_notes='rewritten later' where id='a3620000-0000-0000-0000-0000000000d2';
select is((select resolution_notes from public.complaints where id='a3620000-0000-0000-0000-0000000000d2'),
    'the bag was found and delivered','a signed-in UPDATE cannot rewrite the resolution note afterwards');
select throws_ok($$select app.advance_complaint('a3620000-0000-0000-0000-0000000000d2','in_progress')$$,
    '23514',null,'the RPC cannot reopen a closed complaint without a reason (canon 27)');
select app.advance_complaint(current_setting('c262.rpc_id')::uuid,'in_progress','investigating');
select app.advance_complaint(current_setting('c262.rpc_id')::uuid,'resolved','refund agreed');
select app.advance_complaint(current_setting('c262.rpc_id')::uuid,'closed','confirmed');
select lives_ok($$select app.advance_complaint(current_setting('c262.rpc_id')::uuid,'in_progress','the customer called back')$$,
    'the RPC reopens a closed complaint with a reason');
select is((select count(*)::int from public.events where entity_id=current_setting('c262.rpc_id')::uuid
    and event_type_code='complaint_reopened' and previous_state='closed' and new_state='in_progress'
    and reason='the customer called back' and severity_code='warning'
    and actor_user_id='a3620000-0000-0000-0000-000000000011'),1,
    'the reopen records one warning event with its reason and actor (canon 27)');
select ok((select complaint_status_code='in_progress' and closed_at is null and resolved_at is not null
    and resolution_notes='refund agreed'
    from public.complaints where id=current_setting('c262.rpc_id')::uuid),
    'a reopened complaint is no longer closed, and keeps its earlier resolution');
select throws_ok($$update public.complaints set complaint_status_code='in_progress'
    where id='a3620000-0000-0000-0000-0000000000d1'$$,
    '23514',null,'a reason handed to one transition is consumed by it and opens no other');
select is((select string_agg(event_type_code,',' order by event_type_code) from public.events
    where entity_id=current_setting('c262.rpc_id')::uuid and event_type_code<>'complaint_created'),
    'complaint_acknowledged,complaint_closed,complaint_in_progress,complaint_reopened,complaint_resolved',
    'each RPC transition records exactly one event, none twice');
select throws_ok($$insert into public.complaints(tenant_id,customer_id,complaint_category_code,complaint_severity_code,complaint_status_code,title)
    values ('a3620000-0000-0000-0000-000000000001','a3620000-0000-0000-0000-0000000000c1','other','normal','new','   ')$$,
    '23514',null,'a complaint cannot be created at the table with a blank title, as the RPC refuses it');
select throws_ok($$update public.complaints set title='' where id=current_setting('c262.rpc_id')::uuid$$,
    '23514',null,'a complaint''s title cannot be blanked afterwards');

-- Session-less platform moves are recorded without an actor and keep their latitude.
reset role;
select set_config('request.jwt.claims','',true);
update public.complaints set complaint_status_code='acknowledged' where id='a3620000-0000-0000-0000-0000000000d3';
update public.complaints set complaint_status_code='in_progress' where id='a3620000-0000-0000-0000-0000000000d3';
update public.complaints set complaint_status_code='resolved', resolved_at='2020-02-02'
where id='a3620000-0000-0000-0000-0000000000d3';
select is((select count(*)::int from public.events where entity_id='a3620000-0000-0000-0000-0000000000d3'
    and event_type_code in ('complaint_acknowledged','complaint_in_progress','complaint_resolved') and actor_user_id is null),3,
    'session-less moves record one event each and invent no actor');
select ok((select resolved_at='2020-02-02'::timestamptz
    from public.complaints where id='a3620000-0000-0000-0000-0000000000d3'),
    'a session-less write keeps the resolution time it carries, as a historical import would');

select is((select count(*)::int from pg_trigger where tgname='complaints_emit_transition'
    and tgrelid='public.complaints'::regclass and tgenabled='O' and tgtype=17),1,
    'one enabled row-level AFTER UPDATE transition producer');
select ok(coalesce((select not prosecdef and not has_function_privilege('authenticated',oid,'EXECUTE')
    from pg_proc where oid=to_regprocedure('app.emit_complaint_transition()')),false),
    'the transition producer is SECURITY INVOKER and not directly executable');

select finish();
rollback;
