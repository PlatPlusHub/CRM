-- pgTAP: Batch 6 slice 52 (internal_supplier_links, ISL-1 and ISL-2) --
-- an internal supplier link is appended, never rewritten, and recorded on every door (`20261114170000`).
-- ATTACK-CLASSES: AUTH=N/A TENANT=N/A DOOR STATE INPUT=N/A CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY
--   AUTH=N/A -- ASSIGN_SUPPLIER and its step-up are the unchanged capability guard (tests 57, 58).
--   TENANT=N/A -- tenant isolation is the unchanged policy and composite foreign keys (test 81).
--   INPUT=N/A -- the department-in-branch and item-state rules are the unchanged integrity guard (test 81).
--   CONCURRENCY, REPLAY=N/A -- each link is its own row; appending twice is two links, as through the RPC.
--   BUSINESS=N/A -- a link carries no money.
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email) values
  ('17000000-0000-0000-0000-0000000000a1','senior@c170.test');
insert into public.tenants (id, name, slug, status) values
  ('17000000-0000-0000-0000-000000000001','Link Travel','link-travel-170','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '17000000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-000000000001','Giza','giza-170'),
  ('17000000-0000-0000-0000-00000000000b','17000000-0000-0000-0000-000000000001','Alex','alex-170');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('17000000-0000-0000-0000-0000000000c1','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-00000000000a','sales','Giza Sales'),
  ('17000000-0000-0000-0000-0000000000c2','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-00000000000b','sales','Alex Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('17000000-0000-0000-0000-000000000011','17000000-0000-0000-0000-000000000001','Senior','senior@c170.test',true,'17000000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-000000000011','17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '17000000-0000-0000-0000-000000000001', '17000000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'senior_employee';
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('17000000-0000-0000-0000-0000000000d1','17000000-0000-0000-0000-000000000001','person','Link Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('17000000-0000-0000-0000-0000000000f1','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1','17000000-0000-0000-0000-0000000000d1','17000000-0000-0000-0000-000000000011','17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1','draft','Link booking','BK-170-1');
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code, currency_code, cost_amount, selling_amount) values
  ('17000000-0000-0000-0000-0000000000f2','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-0000000000f1','flight_ticket','draft','USD',100,120),
  ('17000000-0000-0000-0000-0000000000f3','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-0000000000f1','hotel','draft','USD',50,60);

create function pg_temp.linked(p_link uuid) returns setof public.events language sql as $$
  select * from public.events where event_type_code = 'internal_supplier_linked' and payload ->> 'link_id' = p_link::text $$;

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.internal_supplier_links'::regclass and not tgisinternal
     and tgname in ('internal_supplier_links_emit_linked', 'internal_supplier_links_append_only')),
  2, 'both triggers are installed on internal_supplier_links');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17000000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

select lives_ok(
  $$insert into public.internal_supplier_links (id, tenant_id, booking_item_id, provider_branch_id, provider_department_id,
                                                requester_branch_id, requester_department_id)
    values ('17000000-0000-0000-0000-0000000000e1','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-0000000000f2',
            '17000000-0000-0000-0000-00000000000b','17000000-0000-0000-0000-0000000000c2',
            '17000000-0000-0000-0000-00000000000b','17000000-0000-0000-0000-0000000000c2')$$,
  'a senior employee links an item to Alex at the table door');

reset role;
select is(
  (select count(*)::int from pg_temp.linked('17000000-0000-0000-0000-0000000000e1') e join public.users u on u.id = e.actor_user_id
   where u.full_name = 'Senior' and e.entity_type = 'booking_item' and e.entity_id = '17000000-0000-0000-0000-0000000000f2'
     and e.payload ->> 'provider_branch_id' = '17000000-0000-0000-0000-00000000000b'
     and e.payload ->> 'requester_branch_id' = '17000000-0000-0000-0000-00000000000a' and e.reason is null),
  1, 'ISL-1: the door link is recorded once, by its actor, with the derived requester');
set local role authenticated;

create temp table rpc_link on commit drop as
select app.link_internal_supplier('17000000-0000-0000-0000-0000000000f3', '17000000-0000-0000-0000-00000000000b',
                                  '17000000-0000-0000-0000-0000000000c2', 'Alex holds the hotel allotment') as id;
insert into public.internal_supplier_links (id, tenant_id, booking_item_id, provider_branch_id, provider_department_id,
                                            requester_branch_id, requester_department_id)
values ('17000000-0000-0000-0000-0000000000e2','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-0000000000f3',
        '17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1',
        '17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1');

reset role;
select is(
  (select count(*) || '/' || count(*) filter (where reason = 'Alex holds the hotel allotment')
   from pg_temp.linked((select id from rpc_link))),
  '1/1', 'the RPC link is recorded once, not twice, with the caller''s reason');
select is(
  (select count(*)::int from pg_temp.linked('17000000-0000-0000-0000-0000000000e2') where reason is null),
  1, 'the reason is consumed: the next link in the same transaction carries none');
set local role authenticated;

select throws_ok(
  $$update public.internal_supplier_links set provider_branch_id = '17000000-0000-0000-0000-00000000000a',
                                              provider_department_id = '17000000-0000-0000-0000-0000000000c1'
    where id = '17000000-0000-0000-0000-0000000000e1'$$,
  'P0001', 'append-only table: UPDATE is not permitted on internal_supplier_links',
  'ISL-2: a link''s provider cannot be rewritten in place');

select throws_ok(
  $$update public.internal_supplier_links set booking_item_id = '17000000-0000-0000-0000-0000000000f3', created_at = '2019-01-01'
    where id = '17000000-0000-0000-0000-0000000000e1'$$,
  'P0001', 'append-only table: UPDATE is not permitted on internal_supplier_links',
  '...nor moved to another item or back-dated');

reset role;
select set_config('request.jwt.claims', null, true);

select throws_ok(
  $$update public.internal_supplier_links set provider_branch_id = provider_branch_id where id = '17000000-0000-0000-0000-0000000000e1'$$,
  'P0001', 'append-only table: UPDATE is not permitted on internal_supplier_links',
  'append-only binds every writer, a session-less one too');

select throws_ok(
  $$delete from public.internal_supplier_links where id = '17000000-0000-0000-0000-0000000000e1'$$,
  'P0001', 'append-only table: DELETE is not permitted on internal_supplier_links',
  '...and no writer deletes a link');

insert into public.internal_supplier_links (id, tenant_id, booking_item_id, provider_branch_id, provider_department_id,
                                            requester_branch_id, requester_department_id)
values ('17000000-0000-0000-0000-0000000000e3','17000000-0000-0000-0000-000000000001','17000000-0000-0000-0000-0000000000f2',
        '17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1',
        '17000000-0000-0000-0000-00000000000a','17000000-0000-0000-0000-0000000000c1');
select is(
  (select count(*)::int from pg_temp.linked('17000000-0000-0000-0000-0000000000e3') where actor_user_id is null),
  1, 'a session-less link is recorded too, with no actor');

select is(
  (select provider_branch_id from public.internal_supplier_links where id = '17000000-0000-0000-0000-0000000000e1'),
  '17000000-0000-0000-0000-00000000000b'::uuid, 'the first link still names Alex: a new provider is a new row');

select * from finish();
rollback;
