-- pgTAP: ATTR-1 -- `created_by` is derived from the session, never declared by the caller.
--
-- FIN-4 established the rule on `approval_requests.requested_by`: DERIVE, DO NOT VALIDATE, so the
-- forgery is unrepresentable rather than merely refused. This file proves the same rule now holds
-- for the twenty tables that carry `created_by` and accept a direct INSERT.
--
-- Assertion 7 is the class guard and the one that matters beyond today: a table added later with a
-- `created_by` column and no trigger fails here, instead of quietly reopening the hole.
create extension if not exists pgtap with schema extensions;

begin;
select plan(8);

insert into auth.users (id, email) values
  ('61000000-0000-0000-0000-0000000000a1','emp@cb.test'),
  ('61000000-0000-0000-0000-0000000000a2','colleague@cb.test');
insert into public.tenants (id, name, slug, status) values
  ('61000000-0000-0000-0000-000000000001','CB Travel','cb-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '61000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('61000000-0000-0000-0000-00000000000a','61000000-0000-0000-0000-000000000001','Cairo','cb-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('61000000-0000-0000-0000-0000000000c1','61000000-0000-0000-0000-000000000001','61000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('61000000-0000-0000-0000-000000000011','61000000-0000-0000-0000-000000000001','Emp','emp@cb.test',true,'61000000-0000-0000-0000-0000000000a1'),
  ('61000000-0000-0000-0000-000000000012','61000000-0000-0000-0000-000000000001','Colleague','colleague@cb.test',true,'61000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '61000000-0000-0000-0000-000000000001', u, '61000000-0000-0000-0000-00000000000a','61000000-0000-0000-0000-0000000000c1', true
from unnest(array['61000000-0000-0000-0000-000000000011'::uuid,'61000000-0000-0000-0000-000000000012'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '61000000-0000-0000-0000-000000000001', u, r.id, 'tenant'
from unnest(array['61000000-0000-0000-0000-000000000011'::uuid,'61000000-0000-0000-0000-000000000012'::uuid]) u
join public.roles r on r.code = 'employee';

-- =============================================================================================
-- 1-3. THE FORGERY IS UNREPRESENTABLE, not refused. The employee CAN write the row -- they hold
--      CREATE_CUSTOMER -- so the assertion below is about attribution, not about permission.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"61000000-0000-0000-0000-0000000000a1"}', true);

select lives_ok(
  $$insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone, created_by)
    values ('61000000-0000-0000-0000-0000000000d1','61000000-0000-0000-0000-000000000001','person','Forged Attribution','+201000000061',
            '61000000-0000-0000-0000-000000000012')$$,
  'POSITIVE CONTROL: the employee CAN create a customer by direct DML and names their COLLEAGUE as creator');

select is(
  (select created_by from public.customers where id = '61000000-0000-0000-0000-0000000000d1'),
  '61000000-0000-0000-0000-000000000011'::uuid,
  '...and the row is attributed to the ACTUAL author -- the colleague they named was overwritten, not rejected');

update public.customers set created_by = '61000000-0000-0000-0000-000000000012'
 where id = '61000000-0000-0000-0000-0000000000d1';

select is(
  (select created_by from public.customers where id = '61000000-0000-0000-0000-0000000000d1'),
  '61000000-0000-0000-0000-000000000011'::uuid,
  '...and it is IMMUTABLE: an UPDATE cannot re-attribute it a moment later either');

-- =============================================================================================
-- 4-5. `documents` specifically, because there `created_by` is not only history. Its
--      `scope_isolation` policy reads `created_by = current_user_id()` as one of the visibility
--      grants, so a forged value would be an authorization value, not just a misleading one.
-- =============================================================================================
select lives_ok(
  $$insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code,
                                  is_confidential, created_by)
    values ('61000000-0000-0000-0000-0000000000e1','61000000-0000-0000-0000-000000000001','other','Forged doc','active',
            false,'61000000-0000-0000-0000-000000000012')$$,
  'POSITIVE CONTROL: the employee can file a document and again names the colleague as its creator');

select is(
  (select created_by from public.documents where id = '61000000-0000-0000-0000-0000000000e1'),
  '61000000-0000-0000-0000-000000000011'::uuid,
  '...and on `documents` that matters twice over: created_by is one of scope_isolation''s visibility grants, so a forged value would be an AUTHORIZATION value, not merely a misleading one');

-- =============================================================================================
-- 6. THE SYSTEM PATH KEEPS ITS OWN ATTRIBUTION. Provisioning, cron and the integration role write
--    rows before any session exists and must not be rewritten to null.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone, created_by)
values ('61000000-0000-0000-0000-0000000000d2','61000000-0000-0000-0000-000000000001','person','System Row','+201000000062',
        '61000000-0000-0000-0000-000000000012');

select is(
  (select created_by from public.customers where id = '61000000-0000-0000-0000-0000000000d2'),
  '61000000-0000-0000-0000-000000000012'::uuid,
  'a SESSION-LESS write keeps the attribution it set -- the platform path is exempt from the check, never from the record');

-- =============================================================================================
-- 7-8. THE CLASS, PINNED. Every table that has a `created_by` column and accepts a direct INSERT
--      must carry the trigger. A table added later without one fails HERE rather than silently
--      reopening the hole -- which is the difference between fixing an instance and fixing a class.
-- =============================================================================================
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     join information_schema.columns col
       on col.table_schema = 'public' and col.table_name = c.relname and col.column_name = 'created_by'
    where n.nspname = 'public' and c.relkind = 'r'
      and has_table_privilege('authenticated', c.oid, 'INSERT')
      and not exists (
        select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
         where t.tgrelid = c.oid and not t.tgisinternal and p.proname = 'derive_created_by')),
  0,
  'EVERY insertable table with a created_by column carries the derivation -- a new one without it fails here');

select cmp_ok(
  (select count(*)::int from pg_trigger t join pg_proc p on p.oid = t.tgfoid
    where not t.tgisinternal and p.proname = 'derive_created_by'),
  '>=', 20,
  'POSITIVE CONTROL: twenty tables actually carry it, so the zero above is not drawn from an empty set');

select finish();
rollback;
