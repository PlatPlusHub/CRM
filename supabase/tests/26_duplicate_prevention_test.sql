-- pgTAP: duplicate prevention (SPEC-142).
--
-- Every rule here already existed inside an RPC as a check-then-insert. This file asserts the thing
-- that check could never provide: that the DATABASE refuses the duplicate, so the rule survives a
-- direct write and a concurrent one. Each constraint is asserted in both directions -- the duplicate
-- rejected AND the legitimate second record accepted -- because a constraint that blocks real
-- business is a worse defect than the one it prevents, and the owner's directive says so directly.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into public.tenants (id, name, slug, status) values
  ('26000000-0000-0000-0000-000000000001','Dup Travel','dup-travel','active'),
  ('26000000-0000-0000-0000-000000000002','Other Travel','other-travel','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.branches (id, tenant_id, name, slug) values
  ('26000000-0000-0000-0000-00000000000a','26000000-0000-0000-0000-000000000001','Minya','minya'),
  ('26000000-0000-0000-0000-00000000000b','26000000-0000-0000-0000-000000000001','Sohag','sohag');

-- ---------------------------------------------------------------------------------------------
-- Customer primary phone: canon 05's rule AND canon 05's exception.
-- ---------------------------------------------------------------------------------------------
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('26000000-0000-0000-0000-0000000000d1','26000000-0000-0000-0000-000000000001','person','Original','+201000000001');

select throws_ok(
  $$insert into public.customers (tenant_id, customer_type_code, full_name, primary_phone)
    values ('26000000-0000-0000-0000-000000000001','person','Accidental Duplicate','+201000000001')$$,
  '23505', null,
  'THE DATABASE refuses a duplicate primary phone -- not just the RPC, which two concurrent callers could both pass');

select lives_ok(
  $$insert into public.customers (tenant_id, customer_type_code, full_name, primary_phone, duplicate_phone_approved)
    values ('26000000-0000-0000-0000-000000000001','person','Approved Exception','+201000000001', true)$$,
  '...while canon 05''s "unless an approved exception exists" still works -- and now leaves a trace, which it never did before');

select lives_ok(
  $$insert into public.customers (tenant_id, customer_type_code, full_name, primary_phone)
    values ('26000000-0000-0000-0000-000000000002','person','Different Company','+201000000001')$$,
  '...and uniqueness is per COMPANY, so another tenant''s customer with the same number is unaffected');

update public.customers set is_archived = true, archived_at = now()
 where id = '26000000-0000-0000-0000-0000000000d1';
select lives_ok(
  $$insert into public.customers (tenant_id, customer_type_code, full_name, primary_phone)
    values ('26000000-0000-0000-0000-000000000001','person','Re-registered','+201000000001')$$,
  '...and an archived customer does not hold their number hostage forever');

-- ---------------------------------------------------------------------------------------------
-- Contact methods.
-- ---------------------------------------------------------------------------------------------
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('26000000-0000-0000-0000-0000000000d2','26000000-0000-0000-0000-000000000001','person','Contactable');
insert into public.customer_contact_methods (tenant_id, customer_id, contact_method_type_code, value, is_primary)
values ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-0000000000d2','whatsapp','+201000000009', true);

select throws_ok(
  $$insert into public.customer_contact_methods (tenant_id, customer_id, contact_method_type_code, value)
    values ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-0000000000d2','whatsapp','+201000000009')$$,
  '23505', null,
  'the same contact value cannot be added twice to the same customer');

select throws_ok(
  $$insert into public.customer_contact_methods (tenant_id, customer_id, contact_method_type_code, value, is_primary)
    values ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-0000000000d2','whatsapp','+201000000010', true)$$,
  '23505', null,
  '...and a customer cannot have two PRIMARY numbers of one type -- "primary" is a singular word');

select lives_ok(
  $$insert into public.customer_contact_methods (tenant_id, customer_id, contact_method_type_code, value, is_primary)
    values ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-0000000000d2','whatsapp','+201000000010', false)$$,
  '...while a second NON-primary number of the same type is ordinary and allowed');

-- ---------------------------------------------------------------------------------------------
-- Organization and master data.
-- ---------------------------------------------------------------------------------------------
insert into public.departments (tenant_id, branch_id, department_type_code, name)
values ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-00000000000a','sales','Sales');

select throws_ok(
  $$insert into public.departments (tenant_id, branch_id, department_type_code, name)
    values ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-00000000000a','sales','Sales')$$,
  '23505', null,
  'one branch cannot hold two departments called "Sales"');

select lives_ok(
  $$insert into public.departments (tenant_id, branch_id, department_type_code, name)
    values ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-00000000000b','sales','Sales')$$,
  '...but every branch has its own Sales department, which is the normal case and must keep working');

insert into public.suppliers (tenant_id, supplier_type_code, name)
values ('26000000-0000-0000-0000-000000000001','airline','Egypt Air');
select throws_ok(
  $$insert into public.suppliers (tenant_id, supplier_type_code, name)
    values ('26000000-0000-0000-0000-000000000001','airline','Egypt Air')$$,
  '23505', null,
  'a supplier cannot be entered twice under the same name');

-- ---------------------------------------------------------------------------------------------
-- Integration idempotency. n8n's delivery contract is at-least-once, so a retry WILL happen.
-- ---------------------------------------------------------------------------------------------
insert into public.attribution_clicks (tenant_id, attribution_source_code, gclid)
values ('26000000-0000-0000-0000-000000000001','google_ads','Cj0KCQiA-EXAMPLE-1');

select throws_ok(
  $$insert into public.attribution_clicks (tenant_id, attribution_source_code, gclid)
    values ('26000000-0000-0000-0000-000000000001','google_ads','Cj0KCQiA-EXAMPLE-1')$$,
  '23505', null,
  'A REPLAYED CLICK IS ONE CLICK -- a duplicate here becomes a duplicate conversion reported to Google, because the mapper joins leads to their attribution click');

select lives_ok(
  $$insert into public.attribution_clicks (tenant_id, attribution_source_code, gclid)
    values ('26000000-0000-0000-0000-000000000001','google_ads','Cj0KCQiA-EXAMPLE-2')$$,
  '...while a genuinely different click is a different row');

insert into public.conversations (tenant_id, customer_id, channel_code, conversation_status_code, external_conversation_id)
values ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-0000000000d2','whatsapp','open','wamid.EXAMPLE1');
select throws_ok(
  $$insert into public.conversations (tenant_id, customer_id, channel_code, conversation_status_code, external_conversation_id)
    values ('26000000-0000-0000-0000-000000000001','26000000-0000-0000-0000-0000000000d2','whatsapp','open','wamid.EXAMPLE1')$$,
  '23505', null,
  'a WhatsApp thread replayed by the provider resolves to the existing conversation rather than opening a second one beside it');

insert into public.marketing_campaigns (tenant_id, platform_code, external_campaign_id, campaign_name, status_code)
values ('26000000-0000-0000-0000-000000000001','google_ads','12345','Summer Umrah','active');
select throws_ok(
  $$insert into public.marketing_campaigns (tenant_id, platform_code, external_campaign_id, campaign_name, status_code)
    values ('26000000-0000-0000-0000-000000000001','google_ads','12345','Summer Umrah (resynced)','active')$$,
  '23505', null,
  'a campaign synced twice is one campaign');

-- ---------------------------------------------------------------------------------------------
-- Exchange rates: ambiguity here silently decides what a booking cost.
-- ---------------------------------------------------------------------------------------------
insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
values ('26000000-0000-0000-0000-000000000001','USD','EGP', 48.5, '2026-08-24T00:00:00Z');

select throws_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('26000000-0000-0000-0000-000000000001','USD','EGP', 49.0, '2026-08-24T00:00:00Z')$$,
  '23505', null,
  'one currency pair cannot have two rates at the same instant -- "the latest rate at or before X" must have exactly one answer');

select lives_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('26000000-0000-0000-0000-000000000001','USD','EGP', 49.0, '2026-08-25T00:00:00Z')$$,
  '...while a NEW rate at a later instant is the entire point of a temporal rate table');

select * from finish();
rollback;
