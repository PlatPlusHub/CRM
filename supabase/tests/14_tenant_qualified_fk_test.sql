-- pgTAP invariants: a tenant-scoped foreign key can only reference a row in the SAME tenant.
-- Discovery-to-guard for TENANT-1 (SPEC-129), reproduced live on 2026-08-21:
--     insert into bookings (tenant_id, customer_id, ...) values (TENANT_B, TENANT_A_CUSTOMER, ...);
--     -- ACCEPTED, and the join then showed booking_tenant <> customer_tenant
-- across 189 single-column FKs, 50 child tables and 26 parents, with zero composite tenant keys.
--
-- Assertion 1 is the important one: it is CATALOG-DRIVEN, so a foreign key added by a future
-- migration between two tenant-scoped tables is covered automatically and cannot silently
-- re-introduce the hole. Assertions 3 and 4 are behavioural and are deliberately paired -- proving
-- the bad write fails is only half the guarantee; proving the legitimate write still succeeds is
-- what stops an over-broad constraint from passing as a fix.
create extension if not exists pgtap with schema extensions;

begin;
select plan(4);

-- 1. No tenant-scoped -> tenant-scoped FK may be single-column.
select is(
  (select count(*)::int
     from pg_constraint con
     join pg_class t  on t.oid = con.conrelid
     join pg_class rt on rt.oid = con.confrelid
     join pg_namespace n on n.oid = t.relnamespace
    where con.contype = 'f' and n.nspname = 'public'
      and exists (select 1 from pg_attribute a where a.attrelid = t.oid  and a.attname = 'tenant_id' and not a.attisdropped)
      and exists (select 1 from pg_attribute a where a.attrelid = rt.oid and a.attname = 'tenant_id' and not a.attisdropped)
      and not exists (
            select 1 from unnest(con.conkey) k(attnum)
            join pg_attribute a on a.attrelid = con.conrelid and a.attnum = k.attnum
            where a.attname = 'tenant_id')),
  0,
  'every FK between two tenant-scoped tables carries tenant_id (no single-column cross-tenant path)');

-- 2. Every tenant-scoped parent exposes the composite natural key those FKs target.
select is(
  (select count(*)::int
     from (select distinct rt.relname, rt.oid
             from pg_constraint con
             join pg_class t  on t.oid = con.conrelid
             join pg_class rt on rt.oid = con.confrelid
             join pg_namespace n on n.oid = t.relnamespace
            where con.contype = 'f' and n.nspname = 'public'
              and exists (select 1 from pg_attribute a where a.attrelid = t.oid  and a.attname = 'tenant_id' and not a.attisdropped)
              and exists (select 1 from pg_attribute a where a.attrelid = rt.oid and a.attname = 'tenant_id' and not a.attisdropped)) p
    where not exists (
      select 1 from pg_constraint u
      where u.conrelid = p.oid and u.contype in ('u','p')
        and (select array_agg(a.attname::text order by a.attname::text)
               from unnest(u.conkey) k(attnum)
               join pg_attribute a on a.attrelid = u.conrelid and a.attnum = k.attnum)
            = array['id','tenant_id']::text[])),
  0,
  'every tenant-scoped FK parent has a UNIQUE (tenant_id, id) key');

-- Fixture for the behavioural pair.
insert into public.tenants (id, name, slug, status) values
  ('dddd0000-0000-0000-0000-00000000000a','FK Tenant A','fk-a','active'),
  ('dddd0000-0000-0000-0000-00000000000b','FK Tenant B','fk-b','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('dddd0000-0000-0000-0000-0000000000c1','dddd0000-0000-0000-0000-00000000000a','person','Tenant A Customer'),
  ('dddd0000-0000-0000-0000-0000000000c2','dddd0000-0000-0000-0000-00000000000b','person','Tenant B Customer');
insert into public.branches (id, tenant_id, name, slug) values
  ('dddd0000-0000-0000-0000-0000000000b1','dddd0000-0000-0000-0000-00000000000b','BR','fk-br');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('dddd0000-0000-0000-0000-0000000000d1','dddd0000-0000-0000-0000-00000000000b','dddd0000-0000-0000-0000-0000000000b1','sales','DP');

-- 3. The cross-tenant reference is refused by the database itself.
select throws_ok(
  $$insert into public.bookings (tenant_id, customer_id, branch_id, department_id, booking_status_code, title, booking_reference)
    values ('dddd0000-0000-0000-0000-00000000000b','dddd0000-0000-0000-0000-0000000000c1',
            'dddd0000-0000-0000-0000-0000000000b1','dddd0000-0000-0000-0000-0000000000d1','draft','X','FK-REF-1')$$,
  '23503', null,
  'a booking cannot reference a customer belonging to another tenant');

-- 4. The legitimate same-tenant write is unaffected.
select lives_ok(
  $$insert into public.bookings (tenant_id, customer_id, branch_id, department_id, booking_status_code, title, booking_reference)
    values ('dddd0000-0000-0000-0000-00000000000b','dddd0000-0000-0000-0000-0000000000c2',
            'dddd0000-0000-0000-0000-0000000000b1','dddd0000-0000-0000-0000-0000000000d1','draft','X','FK-REF-2')$$,
  'a booking referencing its own tenant''s customer still succeeds');

select * from finish();
rollback;
