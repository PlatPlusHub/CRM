-- pgTAP: the API-3 marketing-campaign family -- CONV-4, CONV-5, CAMP-1 (202607058200).
--
-- Before this file, `create_marketing_campaign` had only `19_master_data_write_path_test`,
-- `advance_marketing_campaign` had vocabulary/parity checks, and `record_offline_conversion`
-- appeared in the suite ONLY as a name in `53_api_surface_test`'s endpoint inventory. None of the
-- three had HTTP evidence, and the two money rules the RPC enforces had no constraint behind them.
--
-- Why the money rules matter more than their row count suggests: `app.claim_conversion_deliveries`
-- returns `conversion_value` and `currency_code` VERBATIM into the payload n8n hands to Google's
-- Data Manager API, and filters only on platform, delivery status and attempt count. A value that
-- should never have existed is therefore not caught downstream -- it is DELIVERED.
--
-- The actor is an `owner` with `aal2`: MANAGE_MARKETING_CAMPAIGN resolves to `ceo` and `owner`
-- only, and `app.requires_mfa` lists both, so without the claim every refusal below would be an
-- MFA refusal wearing an integrity label -- the vacuous-assertion shape this suite exists to catch.
--
-- Each constraint is attacked by defect injection (the PAR-4 pattern): drop the enforcer inside a
-- savepoint, assert the prohibited write SUCCEEDS, roll back, assert it is refused again.
create extension if not exists pgtap with schema extensions;

begin;
select plan(19);

insert into auth.users (id, email) values ('78000000-0000-0000-0000-0000000000a1','owner@mktg.example');
insert into public.tenants (id, name, slug, status) values
  ('78000000-0000-0000-0000-000000000001','Mktg Travel','mktg-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.branches (id, tenant_id, name, slug) values
  ('78000000-0000-0000-0000-00000000000a','78000000-0000-0000-0000-000000000001','Main','mktg-branch');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('78000000-0000-0000-0000-0000000000c1','78000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('78000000-0000-0000-0000-000000000011','78000000-0000-0000-0000-000000000001','Mktg Owner','owner@mktg.example',true,'78000000-0000-0000-0000-0000000000a1');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '78000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000011', r.id,'tenant'
from public.roles r where r.code='owner';
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
values ('78000000-0000-0000-0000-000000000001','78000000-0000-0000-0000-000000000011','78000000-0000-0000-0000-00000000000a','78000000-0000-0000-0000-0000000000c1',true);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);

-- ================================================================================================
-- POSITIVE CONTROLS -- the actor is real and the legal paths genuinely work.
-- ================================================================================================
select ok(app.has_permission('MANAGE_MARKETING_CAMPAIGN'),
  'POSITIVE CONTROL: the actor genuinely holds MANAGE_MARKETING_CAMPAIGN, so every refusal below is about the rule under test');

create temp table camp as
  select app.create_marketing_campaign('Umrah Ramadan','google_ads','G-REG-1', now()) as id;

select is(
  (select status_code from public.marketing_campaigns where id = (select id from camp)),
  'draft',
  'create_marketing_campaign opens the campaign in canon 26 initial state "draft"');

select lives_ok(
  $$select app.advance_marketing_campaign((select id from camp), 'active', 'go live')$$,
  'POSITIVE CONTROL: the legal transition draft -> active succeeds');

select throws_ok(
  $$select app.advance_marketing_campaign((select id from camp), 'draft', 'back to draft')$$,
  null, 'invalid marketing campaign transition active -> draft',
  'the RPC refuses a transition canon 26 does not define');

select throws_ok(
  format($$update public.marketing_campaigns set status_code = 'archived' where id = '%s'$$,
         (select id from camp)),
  null, null,
  'and the TABLE door refuses the same illegal move -- app.enforce_status_transition already governed this path, which is why no change was made to it');

-- ================================================================================================
-- CONV-4 -- a negative conversion value.
-- ================================================================================================
create temp table conv as
  select app.record_offline_conversion('booking_created', null, null, null, null, null,
                                       (select id from camp), 5000, 'EGP', now()) as id;

select is(
  (select conversion_value from public.offline_conversions where id = (select id from conv)),
  5000::numeric,
  'POSITIVE CONTROL: a legal conversion of 5000 EGP is recorded, so the refusals below are about the value and not about the endpoint');

select throws_ok(
  format($$select app.record_offline_conversion('booking_created', null,null,null,null,null,'%s', -5000, 'EGP', now())$$,
         (select id from camp)),
  null, 'conversion_value must be non-negative',
  'the RPC refuses a negative conversion value');

select throws_ok(
  format($$insert into public.offline_conversions (tenant_id, conversion_event_type_code, conversion_value, currency_code, marketing_campaign_id)
           values ('78000000-0000-0000-0000-000000000001','booking_created', -5000, 'EGP', '%s')$$,
         (select id from camp)),
  '23514', null,
  'CONV-4: and so does the TABLE, which is the door that reaches app.claim_conversion_deliveries and Google Ads');

savepoint m1;
reset role;
alter table public.offline_conversions drop constraint offline_conversions_value_nonneg_check;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok(
  format($$insert into public.offline_conversions (tenant_id, conversion_event_type_code, conversion_value, currency_code, marketing_campaign_id)
           values ('78000000-0000-0000-0000-000000000001','booking_created', -5000, 'EGP', '%s')$$,
         (select id from camp)),
  'MUTATION: with offline_conversions_value_nonneg_check dropped the negative value INSERTS -- proving the constraint is the enforcer');
select is(
  (select count(*)::int from public.offline_conversions where conversion_value < 0),
  1,
  '...and the row that would have been delivered to Google Ads really is there');
rollback to savepoint m1;

select throws_ok(
  format($$insert into public.offline_conversions (tenant_id, conversion_event_type_code, conversion_value, currency_code, marketing_campaign_id)
           values ('78000000-0000-0000-0000-000000000001','booking_created', -5000, 'EGP', '%s')$$,
         (select id from camp)),
  '23514', null,
  '...and with the constraint restored it is refused again');

-- ================================================================================================
-- CONV-5 -- a value with no currency.
-- ================================================================================================
select throws_ok(
  format($$select app.record_offline_conversion('booking_created', null,null,null,null,null,'%s', 7777, null, now())$$,
         (select id from camp)),
  null, 'currency_code is required when conversion_value is set',
  'the RPC refuses an amount with no currency');

select throws_ok(
  format($$insert into public.offline_conversions (tenant_id, conversion_event_type_code, conversion_value, currency_code, marketing_campaign_id)
           values ('78000000-0000-0000-0000-000000000001','booking_created', 7777, null, '%s')$$,
         (select id from camp)),
  '23514', null,
  'CONV-5: and so does the TABLE -- an amount with no currency is unusable, not merely imprecise, and it leaves ORVION for an external platform');

savepoint m2;
reset role;
alter table public.offline_conversions drop constraint offline_conversions_value_currency_check;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok(
  format($$insert into public.offline_conversions (tenant_id, conversion_event_type_code, conversion_value, currency_code, marketing_campaign_id)
           values ('78000000-0000-0000-0000-000000000001','booking_created', 7777, null, '%s')$$,
         (select id from camp)),
  'MUTATION: with offline_conversions_value_currency_check dropped the currency-less amount INSERTS -- proving that constraint is the enforcer');
rollback to savepoint m2;

select lives_ok(
  format($$insert into public.offline_conversions (tenant_id, conversion_event_type_code, marketing_campaign_id)
           values ('78000000-0000-0000-0000-000000000001','qualified_lead', '%s')$$,
         (select id from camp)),
  'NEGATIVE CONTROL ON THE CONSTRAINT ITSELF: a conversion carrying NO value and NO currency is still legal -- the pair rule does not over-reach into event types that carry no money');

-- ================================================================================================
-- CAMP-1 -- a campaign with no status.
-- ================================================================================================
select throws_ok(
  $$insert into public.marketing_campaigns (tenant_id, platform_code, campaign_name, status_code)
    values ('78000000-0000-0000-0000-000000000001','google_ads','No status', null)$$,
  '23502', null,
  'CAMP-1: a campaign cannot be created with NO status -- which used to leave it permanently unadvanceable while the RPC reported "campaign not found in your tenant" about a row that existed');

savepoint m3;
reset role;
alter table public.marketing_campaigns alter column status_code drop not null;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"78000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok(
  $$insert into public.marketing_campaigns (id, tenant_id, platform_code, campaign_name, status_code)
    values ('78000000-0000-0000-0000-0000000000f1','78000000-0000-0000-0000-000000000001','google_ads','No status', null)$$,
  'MUTATION: with the NOT NULL dropped the status-less campaign INSERTS -- proving that constraint is the enforcer');
select throws_ok(
  $$select app.advance_marketing_campaign('78000000-0000-0000-0000-0000000000f1','active','try')$$,
  null, 'campaign not found in your tenant',
  '...and it reproduces the original symptom exactly: the campaign exists, cannot be advanced, and the error message is false');
rollback to savepoint m3;

-- ================================================================================================
-- Tenant isolation on the conversion record.
-- ================================================================================================
select is(
  (select count(*)::int from public.offline_conversions where tenant_id <> '78000000-0000-0000-0000-000000000001'),
  0,
  'the owner reads no conversion belonging to another tenant -- offline_conversions RLS is tenant-scoped');

select finish();
rollback;
