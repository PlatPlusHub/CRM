-- pgTAP invariants: the polymorphic related_entity_type / related_entity_id pair is genuinely
-- enforced -- paired, vocabulary-controlled, existent, and same-tenant. Discovery-to-guard for
-- REL-1 (SPEC-130), reproduced live on 2026-08-21:
--     insert into tasks (..., related_entity_type, related_entity_id)
--     values (..., 'BoOkInG', '7777...7777');   -- ACCEPTED, pointing at no booking at all
--
-- The tenant assertion is the one worth reading twice: SPEC-129 closed cross-tenant references for
-- real foreign keys, but a polymorphic id is not a foreign key and was left behind by that fix.
-- This closes the same hole on the polymorphic side.
create extension if not exists pgtap with schema extensions;

begin;
select plan(8);

insert into public.tenants (id, name, slug, status) values
  ('eeee0000-0000-0000-0000-00000000000a','Ref Tenant A','ref-a','active'),
  ('eeee0000-0000-0000-0000-00000000000b','Ref Tenant B','ref-b','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.users (id, tenant_id, full_name, email, is_active) values
  ('eeee0000-0000-0000-0000-0000000000a1','eeee0000-0000-0000-0000-00000000000a','U','ref@example.com',true);
insert into public.branches (id, tenant_id, name, slug) values
  ('eeee0000-0000-0000-0000-0000000000b1','eeee0000-0000-0000-0000-00000000000a','BR','ref-br');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('eeee0000-0000-0000-0000-0000000000d1','eeee0000-0000-0000-0000-00000000000a','eeee0000-0000-0000-0000-0000000000b1','sales','DP');
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('eeee0000-0000-0000-0000-0000000000c1','eeee0000-0000-0000-0000-00000000000a','person','Tenant A Customer'),
  ('eeee0000-0000-0000-0000-0000000000c2','eeee0000-0000-0000-0000-00000000000b','person','Tenant B Customer');

-- 1. The exact reproduction: a mis-spelled discriminator.
select throws_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, title, related_entity_type, related_entity_id)
    values ('eeee0000-0000-0000-0000-00000000000a','eeee0000-0000-0000-0000-0000000000a1',
            'eeee0000-0000-0000-0000-0000000000d1','eeee0000-0000-0000-0000-0000000000b1',
            'call_customer','open','T','BoOkInG','eeee0000-0000-0000-0000-0000000000c1')$$,
  '23514', null,
  'a mis-cased related_entity_type is refused');

-- 2. A dangling reference -- correct type, id that names nothing.
select throws_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, title, related_entity_type, related_entity_id)
    values ('eeee0000-0000-0000-0000-00000000000a','eeee0000-0000-0000-0000-0000000000a1',
            'eeee0000-0000-0000-0000-0000000000d1','eeee0000-0000-0000-0000-0000000000b1',
            'call_customer','open','T','customer','eeee0000-0000-0000-0000-0000000000ff')$$,
  '23503', null,
  'a related_entity_id that identifies no row is refused');

-- 3. CROSS-TENANT: correct type, real row, wrong tenant.
select throws_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, title, related_entity_type, related_entity_id)
    values ('eeee0000-0000-0000-0000-00000000000a','eeee0000-0000-0000-0000-0000000000a1',
            'eeee0000-0000-0000-0000-0000000000d1','eeee0000-0000-0000-0000-0000000000b1',
            'call_customer','open','T','customer','eeee0000-0000-0000-0000-0000000000c2')$$,
  '23503', null,
  'a task cannot reference an entity belonging to another tenant');

-- 4/5. Pairing: neither half may stand alone.
select throws_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, title, related_entity_type)
    values ('eeee0000-0000-0000-0000-00000000000a','eeee0000-0000-0000-0000-0000000000a1',
            'eeee0000-0000-0000-0000-0000000000d1','eeee0000-0000-0000-0000-0000000000b1',
            'call_customer','open','T','customer')$$,
  '23514', null,
  'a related_entity_type without an id is refused');

select throws_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, title, related_entity_id)
    values ('eeee0000-0000-0000-0000-00000000000a','eeee0000-0000-0000-0000-0000000000a1',
            'eeee0000-0000-0000-0000-0000000000d1','eeee0000-0000-0000-0000-0000000000b1',
            'call_customer','open','T','eeee0000-0000-0000-0000-0000000000c1')$$,
  '23514', null,
  'a related_entity_id without a type is refused');

-- 6/7. The legitimate cases must still work -- both a real reference and no reference at all.
select lives_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, title, related_entity_type, related_entity_id)
    values ('eeee0000-0000-0000-0000-00000000000a','eeee0000-0000-0000-0000-0000000000a1',
            'eeee0000-0000-0000-0000-0000000000d1','eeee0000-0000-0000-0000-0000000000b1',
            'call_customer','open','Call this customer','customer','eeee0000-0000-0000-0000-0000000000c1')$$,
  'a task about a real same-tenant customer is accepted');

select lives_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, title)
    values ('eeee0000-0000-0000-0000-00000000000a','eeee0000-0000-0000-0000-0000000000a1',
            'eeee0000-0000-0000-0000-0000000000d1','eeee0000-0000-0000-0000-0000000000b1',
            'follow_up','open','Standalone task')$$,
  'a task with no related entity at all is accepted');

-- 8. Every seeded related_entity_type must resolve to a real, tenant-scoped table. This is what
--    makes the `code || 's'` derivation safe rather than hopeful: adding a value that does not
--    resolve fails here instead of at some employee's first write.
select is(
  (select count(*)::int from public.catalog_values cv
    where cv.catalog_type_code = 'related_entity_type'
      and (to_regclass('public.' || quote_ident(cv.code || 's')) is null
           or not exists (select 1 from pg_attribute a
                          join pg_class c on c.oid = a.attrelid
                          join pg_namespace n on n.oid = c.relnamespace
                          where n.nspname = 'public' and c.relname = cv.code || 's'
                            and a.attname = 'tenant_id' and not a.attisdropped))),
  0,
  'every related_entity_type value resolves to an existing tenant-scoped table');

select * from finish();
rollback;
