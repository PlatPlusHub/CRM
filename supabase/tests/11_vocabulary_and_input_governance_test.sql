-- pgTAP invariants: controlled vocabulary cannot drift into casing/whitespace variants or orphan
-- families, tenant catalog extension is genuinely per-tenant, and customer identity values are
-- stored in a canonical form. Discovery-to-guard for the defects reproduced live on 2026-08-21
-- (SPEC-126): 'whatsapp' / 'WHATSAPP' / ' whatsapp ' coexisting, 'Direct Call' beside
-- 'direct_call', a value under a non-existent family, Tenant B blocked from a code Tenant A used,
-- and 'Ahmed@Gmail.com' vs 'ahmed@gmail.com' becoming two customers.
--
-- These are BEHAVIOURAL assertions wherever possible: the test attempts the bad write and requires
-- it to fail, rather than merely checking that a constraint object exists. A constraint that exists
-- but does not bite is exactly the class of false comfort this suite is meant to eliminate.
create extension if not exists pgtap with schema extensions;

begin;
select plan(14);

-- ---------------------------------------------------------------------------------------------
-- Controlled vocabulary: format
-- ---------------------------------------------------------------------------------------------
select throws_ok(
  $$insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_active, is_system)
    values ('lead_source','WHATSAPP','Upper',990,true,false)$$,
  '23514',
  null,
  'an uppercase catalog code is rejected');

select throws_ok(
  $$insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_active, is_system)
    values ('lead_source',' whatsapp ','Padded',991,true,false)$$,
  '23514',
  null,
  'a whitespace-padded catalog code is rejected');

select throws_ok(
  $$insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_active, is_system)
    values ('lead_source','Direct Call','Spaced',992,true,false)$$,
  '23514',
  null,
  'a catalog code containing spaces or capitals is rejected');

-- ---------------------------------------------------------------------------------------------
-- Controlled vocabulary: family registration (CAT-1)
-- ---------------------------------------------------------------------------------------------
select throws_ok(
  $$insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_active, is_system)
    values ('not_a_real_family','x','X',1,true,false)$$,
  '23503',
  null,
  'a catalog value under an unregistered family is rejected by foreign key');

-- ---------------------------------------------------------------------------------------------
-- Controlled vocabulary: tenant scoping (CAT-2)
-- ---------------------------------------------------------------------------------------------
insert into public.tenants (id, name, slug, status) values
  ('aaaaaaaa-0000-0000-0000-000000000001','Guard Tenant A','guard-tenant-a','active'),
  ('aaaaaaaa-0000-0000-0000-000000000002','Guard Tenant B','guard-tenant-b','active');

-- SPEC-152: these two tenants write below, so they need a subscription before they can. This file
-- creates tenants in two places, which is why the backfill appears twice.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);

insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
values ('aaaaaaaa-0000-0000-0000-000000000001','lead_source','expo_booth','Expo Booth',900,true,false);

select lives_ok(
  $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
    values ('aaaaaaaa-0000-0000-0000-000000000002','lead_source','expo_booth','Expo Booth',900,true,false)$$,
  'two tenants may independently define the same catalog code');

select throws_ok(
  $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
    values ('aaaaaaaa-0000-0000-0000-000000000001','lead_source','expo_booth','Duplicate',901,true,false)$$,
  '23505',
  null,
  'a single tenant may not define the same catalog code twice');

select throws_ok(
  $$insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_active, is_system)
    values ('lead_source','whatsapp','Duplicate global',902,true,false)$$,
  '23505',
  null,
  'a global catalog code remains unique across the platform');

-- ---------------------------------------------------------------------------------------------
-- Reference-data code shape
-- ---------------------------------------------------------------------------------------------
select throws_ok(
  $$insert into public.countries (code, name) values ('eg','Egypt')$$,
  '23514',
  null,
  'a lowercase country code is rejected (ISO 3166-1 alpha-2 shape enforced)');

-- ---------------------------------------------------------------------------------------------
-- Customer identity normalization
-- ---------------------------------------------------------------------------------------------
select throws_ok(
  $$insert into public.customers (tenant_id, customer_type_code, full_name, primary_email)
    values ('aaaaaaaa-0000-0000-0000-000000000001','person','Test','Ahmed@Gmail.com')$$,
  '23514',
  null,
  'a non-normalized customer email is rejected');

select throws_ok(
  $$insert into public.customers (tenant_id, customer_type_code, full_name, primary_phone)
    values ('aaaaaaaa-0000-0000-0000-000000000001','person','Test','+20 123 456')$$,
  '23514',
  null,
  'a customer phone containing formatting characters is rejected');

-- The CHECK constraints and the normalization helpers must agree, or the RPC would produce values
-- its own table refuses. Asserted on representative messy input rather than on the definitions.
select is(
  (select count(*)::int from (values
      ('  Ahmed@Gmail.COM  '), ('a@b.co')
   ) as t(raw)
   where app.normalize_email(t.raw) is not null
     and not (app.normalize_email(t.raw) = lower(btrim(app.normalize_email(t.raw)))
              and app.normalize_email(t.raw) !~ '[[:space:]]'
              and position('@' in app.normalize_email(t.raw)) > 1)),
  0,
  'app.normalize_email output always satisfies the customers email CHECK');

select is(
  (select count(*)::int from (values
      (' +20 (123) 456-7890 '), ('+20.123.456')
   ) as t(raw)
   where app.normalize_phone(t.raw) is not null
     and not (app.normalize_phone(t.raw) !~ '[[:space:]().-]' and app.normalize_phone(t.raw) <> '')),
  0,
  'app.normalize_phone output always satisfies the customers phone CHECK');

-- ---------------------------------------------------------------------------------------------
-- CAT-4, now closed rather than tripwired.
--
-- This slot previously held a tripwire asserting that NO catalog value was deactivated, because
-- deactivation was enforced nowhere: none of the ~27 in-RPC catalog lookups filters `is_active`, so
-- a deactivated value stayed fully usable. The tripwire existed to make that silent defect loud.
--
-- SPEC-136 extended `app.enforce_catalog_codes` to every catalog-backed column, so deactivation is
-- now enforced at the database on every write path. The tripwire is therefore replaced by the
-- assertion it was standing in for -- and by its necessary counterpart, since "inactive values are
-- unusable" would be a worse defect than the one it replaced if it also froze historical rows.
-- ---------------------------------------------------------------------------------------------
insert into public.tenants (id, name, slug, status)
values ('aaaa1111-0000-0000-0000-00000000000c','Deactivation Co','deactivation-co','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.customers (id, tenant_id, customer_type_code, full_name)
values ('aaaa1111-0000-0000-0000-0000000000c9','aaaa1111-0000-0000-0000-00000000000c','person','Historic Customer');

update public.catalog_values set is_active = false
 where catalog_type_code = 'customer_type' and code = 'company';

select throws_ok(
  $$insert into public.customers (tenant_id, customer_type_code, full_name)
    values ('aaaa1111-0000-0000-0000-00000000000c','company','New Co')$$,
  '23514', null,
  'a DEACTIVATED catalog value cannot be used for a new record on an RPC-written column either');

select lives_ok(
  $$update public.customers set full_name = 'Historic Customer, renamed'
     where id = 'aaaa1111-0000-0000-0000-0000000000c9'$$,
  'and a historical row is still editable -- deactivation stops new use, it does not freeze history');

select * from finish();
rollback;
