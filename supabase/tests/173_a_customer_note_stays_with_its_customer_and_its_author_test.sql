-- pgTAP: Batch 6 slice 54 (customer_notes, CUST-15 and CUST-16) --
-- a customer note stays with its customer and its author (`20261116120000`).
-- ATTACK-CLASSES: AUTH=N/A TENANT=N/A DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
--   AUTH=N/A -- CREATE_CUSTOMER is the unchanged capability guard (tests 58, 85).
--   TENANT=N/A -- tenant isolation is the unchanged policy and composite foreign keys.
--   STATE=N/A -- the archive authority is unchanged (`enforce_archive_authority`).
--   CONCURRENCY, REPLAY=N/A -- each note is its own row; adding one twice is two notes, as through the RPC.
--   BUSINESS=N/A -- a note carries no money.
--   OBSERVABILITY=N/A -- notes record no event on any door, the RPC's included.
create extension if not exists pgtap with schema extensions;

begin;
select plan(14);

insert into auth.users (id, email) values
  ('17300000-0000-0000-0000-0000000000a1','employee@c173.test'),
  ('17300000-0000-0000-0000-0000000000a2','owner@c173.test');
insert into public.tenants (id, name, slug, status) values
  ('17300000-0000-0000-0000-000000000001','Note Travel','note-travel-173','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '17300000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('17300000-0000-0000-0000-00000000000a','17300000-0000-0000-0000-000000000001','Giza','giza-173');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('17300000-0000-0000-0000-0000000000c1','17300000-0000-0000-0000-000000000001','17300000-0000-0000-0000-00000000000a','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('17300000-0000-0000-0000-000000000011','17300000-0000-0000-0000-000000000001','Employee','employee@c173.test',true,'17300000-0000-0000-0000-0000000000a1'),
  ('17300000-0000-0000-0000-000000000012','17300000-0000-0000-0000-000000000001','Owner','owner@c173.test',true,'17300000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('17300000-0000-0000-0000-000000000001','17300000-0000-0000-0000-000000000011','17300000-0000-0000-0000-00000000000a','17300000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '17300000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('17300000-0000-0000-0000-000000000011'::uuid, 'employee'), ('17300000-0000-0000-0000-000000000012', 'owner')) v(u, c)
join public.roles r on r.code = v.c;
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('17300000-0000-0000-0000-0000000000d1','17300000-0000-0000-0000-000000000001','person','Note One'),
  ('17300000-0000-0000-0000-0000000000d2','17300000-0000-0000-0000-000000000001','person','Note Two');

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.customer_notes'::regclass and not tgisinternal
     and tgname = 'customer_notes_guard_note_integrity'),
  1, 'the note guard is installed on customer_notes');
select is(
  (select string_agg(p || '=' || has_table_privilege('authenticated', 'public.customer_notes', p), ' ' order by p)
   from unnest(array['DELETE', 'INSERT', 'SELECT', 'UPDATE']) p),
  'DELETE=false INSERT=true SELECT=true UPDATE=true', 'the grants are unchanged: notes stay pinnable and archivable');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17300000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select lives_ok(
  $$insert into public.customer_notes (id, tenant_id, customer_id, note_text) values
    ('17300000-0000-0000-0000-0000000000e2','17300000-0000-0000-0000-000000000001','17300000-0000-0000-0000-0000000000d1','Prefers morning calls')$$,
  'the owner adds a note at the table door');

select set_config('request.jwt.claims', '{"sub":"17300000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
select lives_ok(
  $$insert into public.customer_notes (id, tenant_id, customer_id, note_text) values
    ('17300000-0000-0000-0000-0000000000e1','17300000-0000-0000-0000-000000000001','17300000-0000-0000-0000-0000000000d1','  Called, no answer  ')$$,
  'an employee adds a note at the table door');
select is(
  (select note_text from public.customer_notes where id = '17300000-0000-0000-0000-0000000000e1'),
  'Called, no answer', 'CUST-16: the door trims the text as the RPC does');
select throws_ok(
  $$insert into public.customer_notes (tenant_id, customer_id, note_text)
    values ('17300000-0000-0000-0000-000000000001','17300000-0000-0000-0000-0000000000d1','   ')$$,
  '23502', null, 'CUST-16: a blank note is refused at the door, as the RPC refuses one');
select lives_ok(
  $$update public.customer_notes set note_text = 'Called twice, no answer'
    where id = '17300000-0000-0000-0000-0000000000e1'$$,
  'the author may still correct their own note');
select throws_ok(
  $$update public.customer_notes set customer_id = '17300000-0000-0000-0000-0000000000d2'
    where id = '17300000-0000-0000-0000-0000000000e1'$$,
  '23514', null, 'CUST-15: a note cannot be moved to another customer, even by its author');
select throws_ok(
  $$update public.customer_notes set note_text = 'Customer asked to be ignored'
    where id = '17300000-0000-0000-0000-0000000000e2'$$,
  '42501', null, 'CUST-15: an employee cannot rewrite the owner''s note');
select throws_ok(
  $$update public.customer_notes set note_text = '   '
    where id = '17300000-0000-0000-0000-0000000000e2'$$,
  '42501', null, 'CUST-15: an employee cannot blank the owner''s note');
select lives_ok(
  $$update public.customer_notes set is_pinned = true, created_at = '2019-01-01'
    where id = '17300000-0000-0000-0000-0000000000e2'$$,
  'an employee may still pin the owner''s note');

create temp table rpc_note on commit drop as
select app.add_customer_note('17300000-0000-0000-0000-0000000000d2', '  Visa renewed  ') as id;
select is(
  (select note_text from public.customer_notes where id = (select id from rpc_note)),
  'Visa renewed', 'the RPC still adds its trimmed note');

reset role;
select is(
  (select customer_id::text || ':' || note_text || ':' || created_by::text || ':' || is_pinned::text
   from public.customer_notes where id = '17300000-0000-0000-0000-0000000000e2'),
  '17300000-0000-0000-0000-0000000000d1:Prefers morning calls:17300000-0000-0000-0000-000000000012:true',
  'CUST-15: the owner''s note keeps its customer, its text and its author; only the pin changed');
select is(
  (select created_at = now() from public.customer_notes where id = '17300000-0000-0000-0000-0000000000e2'),
  true, 'CUST-15: a note''s created_at is kept on update');

select * from finish();
rollback;
