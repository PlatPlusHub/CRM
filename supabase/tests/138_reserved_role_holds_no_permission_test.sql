-- SPEC-236 / SYSADMIN-1. The owner decided on 2026-09-01 that `system_administrator` is RESERVED:
-- it stays in the role catalog and in `app.requires_mfa`, and ORVION invents no permissions for it.
-- This file is the assertion half of that decision; canon 28 carries the documentation half.
-- Assertion 3 is what makes assertion 2 mean something: a member holding ONLY this role is resolved by
-- `app.has_permission` against the whole permission catalog and holds nothing, while a control member
-- holding `employee` in the same tenant holds something.
create extension if not exists pgtap with schema extensions;

begin;
select plan(3);

insert into auth.users (id,email,email_confirmed_at) values
  ('13800000-0000-0000-0000-0000000000a1','sysadmin@ra138.test',now()),
  ('13800000-0000-0000-0000-0000000000a2','emp@ra138.test',now());
insert into public.tenants (id,name,slug,status) values
  ('13800000-0000-0000-0000-000000000001','RA138 Travel','ra138-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '13800000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('13800000-0000-0000-0000-000000000011','13800000-0000-0000-0000-000000000001','Reserved','sysadmin@ra138.test',true,'13800000-0000-0000-0000-0000000000a1'),
  ('13800000-0000-0000-0000-000000000012','13800000-0000-0000-0000-000000000001','Control','emp@ra138.test',true,'13800000-0000-0000-0000-0000000000a2');
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '13800000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('13800000-0000-0000-0000-000000000011'::uuid,'system_administrator'),
             ('13800000-0000-0000-0000-000000000012','employee')) v(u,rc)
join public.roles r on r.code = v.rc;

select is((select is_active from public.roles where code = 'system_administrator'), true,
  'CONTROL: system_administrator is a real, active, assignable role -- reserved, not retired');
select is((select count(*)::int from public.role_permissions rp join public.roles r on r.id = rp.role_id
            where r.code = 'system_administrator'), 0,
  'SYSADMIN-1: system_administrator holds no permission by design (owner decision 2026-09-01)');

create temp table held (who text, n int) on commit drop;
grant insert on held to authenticated;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13800000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
insert into held select 'reserved', count(*) from public.permissions p where app.has_permission(p.key);
select set_config('request.jwt.claims','{"sub":"13800000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
insert into held select 'control', count(*) from public.permissions p where app.has_permission(p.key);
reset role;
select is((select array[(select n from held where who = 'reserved') = 0, (select n from held where who = 'control') > 0]),
  array[true, true],
  'A member holding only system_administrator resolves to no permission, while an employee in the same tenant resolves to some');

select * from finish();
rollback;
