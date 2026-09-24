-- CM-3: both contact creation doors emit one authoritative event for the customer timeline.
-- ATTACK-CLASSES: AUTH TENANT DOOR INPUT OBSERVABILITY REPLAY
create extension if not exists pgtap with schema extensions;

begin;
select plan(28);

insert into auth.users(id,email) values
  ('a2180000-0000-0000-0000-0000000000a1','employee@cm3.test'),
  ('a2180000-0000-0000-0000-0000000000a2','trainee@cm3.test');
insert into public.tenants(id,name,slug,status) values
  ('a2180000-0000-0000-0000-000000000001','CM3 Travel','cm3-travel','active');
insert into public.subscriptions(tenant_id,subscription_plan_id,subscription_status_code)
select 'a2180000-0000-0000-0000-000000000001',id,'active'
from public.subscription_plans where plan_code='enterprise';
insert into public.branches(id,tenant_id,name,slug) values
  ('a2180000-0000-0000-0000-000000000002','a2180000-0000-0000-0000-000000000001','Main','cm3-main');
insert into public.departments(id,tenant_id,branch_id,department_type_code,name) values
  ('a2180000-0000-0000-0000-000000000003','a2180000-0000-0000-0000-000000000001',
   'a2180000-0000-0000-0000-000000000002','sales','Sales');
insert into public.users(id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('a2180000-0000-0000-0000-000000000011','a2180000-0000-0000-0000-000000000001','Employee','employee@cm3.test',true,'a2180000-0000-0000-0000-0000000000a1'),
  ('a2180000-0000-0000-0000-000000000012','a2180000-0000-0000-0000-000000000001','Trainee','trainee@cm3.test',true,'a2180000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments(tenant_id,user_id,branch_id,department_id,is_primary)
select 'a2180000-0000-0000-0000-000000000001',u,
       'a2180000-0000-0000-0000-000000000002','a2180000-0000-0000-0000-000000000003',true
from unnest(array['a2180000-0000-0000-0000-000000000011'::uuid,
                  'a2180000-0000-0000-0000-000000000012'::uuid]) u;
insert into public.user_role_assignments(tenant_id,user_id,role_id,scope_type)
select 'a2180000-0000-0000-0000-000000000001',v.u,r.id,'tenant'
from (values ('a2180000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('a2180000-0000-0000-0000-000000000012'::uuid,'trainee')) v(u,code)
join public.roles r on r.code=v.code;
insert into public.customers(id,tenant_id,customer_type_code,full_name,primary_phone) values
  ('a2180000-0000-0000-0000-0000000000c1','a2180000-0000-0000-0000-000000000001','person','CM3 Customer','+201000021800');

select set_config('request.jwt.claims','{"sub":"a2180000-0000-0000-0000-0000000000a1"}',true);
set local role authenticated;
select ok(app.has_permission('CREATE_CUSTOMER'),'employee genuinely holds contact-create capability');
select is((select count(*)::int from public.customers where id='a2180000-0000-0000-0000-0000000000c1'),1,'employee sees the real parent customer');

select lives_ok($$
  insert into public.customer_contact_methods(id,tenant_id,customer_id,contact_method_type_code,value,is_primary,created_at)
  values ('a2180000-0000-0000-0000-0000000000d1','a2180000-0000-0000-0000-000000000001',
          'a2180000-0000-0000-0000-0000000000c1','primary_phone','+201000021801',true,'2001-01-01')
$$,'authorized direct INSERT succeeds');
select is((select count(*)::int from public.customer_contact_methods where id='a2180000-0000-0000-0000-0000000000d1'),1,'direct INSERT persisted a real row');
select is((select count(*)::int from public.events where event_type_code='customer_contact_added'
    and payload->>'contact_method_id'='a2180000-0000-0000-0000-0000000000d1'),1,'direct INSERT emits exactly one matching event');
select is((select actor_user_id from public.events where event_type_code='customer_contact_added'
    and payload->>'contact_method_id'='a2180000-0000-0000-0000-0000000000d1'),
    'a2180000-0000-0000-0000-000000000011'::uuid,'event actor is the real signed-in creator');
select ok((select entity_type='customer' and entity_id='a2180000-0000-0000-0000-0000000000c1'::uuid
                  and payload->>'contact_method_type_code'='primary_phone'
             from public.events where event_type_code='customer_contact_added'
               and payload->>'contact_method_id'='a2180000-0000-0000-0000-0000000000d1'),
          'event points to the owning customer and retains contact type');
select ok((select e.created_at >= transaction_timestamp() and e.created_at > m.created_at
             from public.events e join public.customer_contact_methods m
               on e.payload->>'contact_method_id'=m.id::text
            where m.id='a2180000-0000-0000-0000-0000000000d1'),
          'event time is server-owned even when the contact row has a caller-supplied old time');
select is((select count(*)::int from app.customer_timeline('a2180000-0000-0000-0000-0000000000c1')
            where event_type_code='customer_contact_added'),1,'direct addition appears in the customer timeline');

select set_config('cm3.rpc_id',app.add_customer_contact_method(
  'a2180000-0000-0000-0000-0000000000c1','email','  First@Example.COM  ',true)::text,true);
select is((select value from public.customer_contact_methods where id=current_setting('cm3.rpc_id')::uuid),
          'first@example.com','RPC keeps contact normalization');
select is((select count(*)::int from public.events where event_type_code='customer_contact_added'
    and payload->>'contact_method_id'=current_setting('cm3.rpc_id')),1,'RPC INSERT emits exactly one matching event');
select is((select count(*)::int from app.customer_timeline('a2180000-0000-0000-0000-0000000000c1')
            where event_type_code='customer_contact_added'),2,'both additions appear once in the timeline');
select is((select actor_user_id from public.events where event_type_code='customer_contact_added'
    and payload->>'contact_method_id'=current_setting('cm3.rpc_id')),
    'a2180000-0000-0000-0000-000000000011'::uuid,'RPC event preserves actor attribution');
select is((select is_primary from public.customer_contact_methods where id='a2180000-0000-0000-0000-0000000000d1'),
          true,'primary phone survives creation of a primary email');

select set_config('cm3.rpc_id_2',app.add_customer_contact_method(
  'a2180000-0000-0000-0000-0000000000c1','email','second@example.com',true)::text,true);
select ok((select not is_primary from public.customer_contact_methods where id=current_setting('cm3.rpc_id')::uuid)
          and (select is_primary from public.customer_contact_methods where id=current_setting('cm3.rpc_id_2')::uuid)
          and (select is_primary from public.customer_contact_methods where id='a2180000-0000-0000-0000-0000000000d1'),
          'RPC demotes only the previous primary of the same channel');
select is((select count(*)::int from public.events where event_type_code='customer_contact_added'
            and tenant_id='a2180000-0000-0000-0000-000000000001'),3,
          'three persisted user-created contacts have exactly three events');

select throws_ok($$insert into public.customer_contact_methods(tenant_id,customer_id,contact_method_type_code,value)
  values ('a2180000-0000-0000-0000-000000000001','a2180000-0000-0000-0000-0000000000c1',
          'email','second@example.com')$$,'23505',null,'duplicate direct contact is refused');
select is((select count(*)::int from public.events where event_type_code='customer_contact_added'
            and tenant_id='a2180000-0000-0000-0000-000000000001'),3,'duplicate refusal emitted no event');
select throws_ok($$insert into public.customer_contact_methods(tenant_id,customer_id,contact_method_type_code,value)
  values ('a2180000-0000-0000-0000-000000000001','a2180000-0000-0000-0000-0000000000c1',
          'email','  Third@Example.COM  ')$$,'23514',null,'denormalized direct contact is refused');
select is((select count(*)::int from public.events where event_type_code='customer_contact_added'
            and tenant_id='a2180000-0000-0000-0000-000000000001'),3,'normalization refusal emitted no event');

reset role;
select set_config('request.jwt.claims','{"sub":"a2180000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;
select is((select count(*)::int from public.customers where id='a2180000-0000-0000-0000-0000000000c1'),1,'trainee sees the parent; denial is not an empty-target result');
select ok(not app.has_permission('CREATE_CUSTOMER'),'trainee lacks contact-create capability');
select throws_ok($$insert into public.customer_contact_methods(tenant_id,customer_id,contact_method_type_code,value)
  values ('a2180000-0000-0000-0000-000000000001','a2180000-0000-0000-0000-0000000000c1',
          'email','trainee@example.com')$$,'42501',null,'trainee direct INSERT is refused by capability');
select is((select count(*)::int from public.events where event_type_code='customer_contact_added'
            and tenant_id='a2180000-0000-0000-0000-000000000001'),3,'capability refusal emitted no event');

reset role;
select set_config('request.jwt.claims','',true);
insert into public.customer_contact_methods(id,tenant_id,customer_id,contact_method_type_code,value)
values ('a2180000-0000-0000-0000-0000000000d4','a2180000-0000-0000-0000-000000000001',
        'a2180000-0000-0000-0000-0000000000c1','email','system@example.com');
select ok((select actor_user_id is null from public.events where event_type_code='customer_contact_added'
    and payload->>'contact_method_id'='a2180000-0000-0000-0000-0000000000d4'),
    'session-less insert emits with no invented human actor');
select is((select count(*)::int from public.events where event_type_code='customer_contact_added'
    and payload->>'contact_method_id'='a2180000-0000-0000-0000-0000000000d4'),1,
    'session-less insert also emits exactly once');
select is((select count(*)::int from pg_trigger where tgname='customer_contact_methods_emit_added_event'
    and tgrelid='public.customer_contact_methods'::regclass and tgenabled='O' and tgtype=5),1,
    'one enabled row-level AFTER INSERT emitter is attached');
select ok((select not prosecdef and not has_function_privilege('authenticated',oid,'EXECUTE')
    from pg_proc where oid='app.emit_customer_contact_added()'::regprocedure),
    'emitter is SECURITY INVOKER and not directly executable by authenticated');

select finish();
rollback;
