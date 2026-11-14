-- pgTAP: Batch 6 slice 51 (catalog_values) --
-- a tenant catalog value is written only with step-up, only in a family open to tenants, never as a system value, and
-- keeps its family and code (`20261114140000`).
-- ATTACK-CLASSES: AUTH TENANT=N/A DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY=N/A
--   TENANT=N/A -- global values stay read-only to tenants through the unchanged policies (tests 07, 08).
--   STATE=N/A -- activation is the only state; deactivation stays allowed and is what enforce_catalog_codes reads.
--   CONCURRENCY=N/A -- one row per write; uniqueness is the unchanged partial indexes.
--   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
--   OBSERVABILITY=N/A -- a tenant setting's label, order or activation is not recorded (slice 51 position).
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email) values
  ('16800000-0000-0000-0000-0000000000a1','owner@c168.test'),
  ('16800000-0000-0000-0000-0000000000a2','employee@c168.test');
insert into public.tenants (id, name, slug, status) values
  ('16800000-0000-0000-0000-000000000001','Catalog Travel','catalog-travel-168','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '16800000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('16800000-0000-0000-0000-000000000011','16800000-0000-0000-0000-000000000001','Owner','owner@c168.test',true,'16800000-0000-0000-0000-0000000000a1'),
  ('16800000-0000-0000-0000-000000000012','16800000-0000-0000-0000-000000000001','Employee','employee@c168.test',true,'16800000-0000-0000-0000-0000000000a2');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '16800000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('16800000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('16800000-0000-0000-0000-000000000012','employee')) v(uid, role_code)
join public.roles r on r.code = v.role_code;
insert into public.catalog_values (id, tenant_id, catalog_type_code, code, label) values
  ('16800000-0000-0000-0000-0000000000e1','16800000-0000-0000-0000-000000000001','supplier_type','charter168','Charter');
insert into public.suppliers (id, tenant_id, supplier_type_code, name) values
  ('16800000-0000-0000-0000-0000000000f1','16800000-0000-0000-0000-000000000001','charter168','Charter Supplier');

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.catalog_values'::regclass and not tgisinternal and tgname = 'catalog_values_guard_write'),
  1, 'the guard is installed on catalog_values');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16800000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);

select throws_ok(
  $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
    values ('16800000-0000-0000-0000-000000000001','supplier_type','barge168','Barge')$$,
  '42501', 'multi-factor authentication required for this role',
  'an owner cannot add a tenant value from a password-only session');

select set_config('request.jwt.claims', '{"sub":"16800000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select lives_ok(
  $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
    values ('16800000-0000-0000-0000-000000000001','supplier_type','barge168','Barge')$$,
  'an owner at aal2 adds a value to a family open to tenants');

select throws_ok(
  $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
    values ('16800000-0000-0000-0000-000000000001','payment_direction','sideways','Sideways')$$,
  '42501', 'catalog family payment_direction does not take tenant values',
  'a tenant cannot add a value to a platform-owned family');

select throws_ok(
  $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label, is_system)
    values ('16800000-0000-0000-0000-000000000001','supplier_type','sys168','Sys',true)$$,
  '42501', 'a tenant catalog value cannot be a system value',
  'a tenant value cannot claim to be a system value');

select throws_ok(
  $$update public.catalog_values set code = 'renamed168' where id = '16800000-0000-0000-0000-0000000000e1'$$,
  '42501', 'a catalog value keeps its family and code: add a new value and deactivate this one',
  'a value in use cannot be renamed under the rows that use it');

select throws_ok(
  $$update public.catalog_values set catalog_type_code = 'lead_source' where id = '16800000-0000-0000-0000-0000000000e1'$$,
  '42501', 'a catalog value keeps its family and code: add a new value and deactivate this one',
  '...nor moved to another family');

select lives_ok(
  $$update public.catalog_values set label = 'Charter (old)', is_active = false where id = '16800000-0000-0000-0000-0000000000e1'$$,
  'a value may be relabelled and deactivated');

select set_config('request.jwt.claims', '{"sub":"16800000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);

select throws_ok(
  $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
    values ('16800000-0000-0000-0000-000000000001','supplier_type','emp168','E')$$,
  '42501', 'permission denied: MANAGE_TENANT_SETTINGS',
  'an employee cannot add a tenant value');

reset role;

select is(
  (select count(*)::int from public.suppliers s join public.catalog_values cv
     on cv.tenant_id = s.tenant_id and cv.catalog_type_code = 'supplier_type' and cv.code = s.supplier_type_code
   where s.id = '16800000-0000-0000-0000-0000000000f1'),
  1, 'the supplier still finds the value it uses');

select set_config('request.jwt.claims', null, true);

select lives_ok(
  $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
    values ('16800000-0000-0000-0000-000000000001','supplier_type','plat168','Platform')$$,
  'the guard''s one exemption: a session-less platform write adds a tenant value');

select * from finish();
rollback;
