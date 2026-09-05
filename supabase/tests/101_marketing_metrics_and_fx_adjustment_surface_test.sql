-- pgTAP: BATCH 6 SLICE 1 -- `campaign_daily_metrics` and `exchange_rate_adjustments` (`202607061100`).
--
-- ATTACK-CLASSES: AUTH TENANT DOOR INPUT BUSINESS REPLAY PRIVILEGE STATE=N/A CONCURRENCY=N/A OBSERVABILITY=N/A
--
-- Declared retrospectively when slice 2 introduced the vocabulary and Check 24 (ADV-1) began
-- requiring it. The classes describe what this file already attacked; nothing was added to the
-- assertions to earn them. The three exclusions are positions, not gaps: STATE = neither table has
-- a status column or a row in app.status_transitions; CONCURRENCY = the only contended object is the
-- CDM-1 unique index, and a duplicate campaign-day is refused identically whether the second writer
-- arrives a millisecond or a month later; OBSERVABILITY = neither surface has a registered event
-- type, so there is no expected audit trace whose absence could be a defect.
--
-- WHY THESE TWO. Chosen by measurement, not by list: of ORVION's 77 tables, 75 are named in at least
-- one pgTAP file and these two were named in NONE. Being named in a test is a floor rather than
-- coverage, but a table no test mentions at all is definitively unswept -- and before the surface
-- disposition record existed these were the only two surfaces that could be ASSERTED un-audited.
--
-- WHAT THE AUDIT PROVED, and the shape of the proof. Neither table has any consumer: zero functions
-- and zero views reference either one, so the table door is not a bypass of an intended RPC door --
-- it IS the door (SEC-2's ratified reading). That makes RLS the complete enforcement layer here, so
-- these assertions attack RLS directly rather than an RPC, and every denial below is paired with a
-- positive control proving the actor could otherwise have succeeded. Three permissions govern the
-- pair and all three are held by real roles, so none of this is a test of an unreachable capability.
--
-- Assertions 6, 8, 9, 16, 17, 18, 20 and 21 FAILED before `202607061100`. The rest are controls,
-- negative controls, or regression guards on behaviour that was already correct and is now pinned.
create extension if not exists pgtap with schema extensions;

begin;
select plan(21);

insert into auth.users (id, email, email_confirmed_at) values
  ('a1000000-0000-0000-0000-0000000000a1','owner@mkt101.test',   now()),
  ('a1000000-0000-0000-0000-0000000000a2','finance@mkt101.test', now()),
  ('a1000000-0000-0000-0000-0000000000a3','emp@mkt101.test',     now());
insert into public.tenants (id, name, slug, status) values
  ('a1000000-0000-0000-0000-000000000001','Mkt101 Travel','mkt101','active'),
  ('a1000000-0000-0000-0000-000000000002','Rival101 Travel','rival101','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise'
  and t.id in ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-000000000002');
insert into public.branches (id, tenant_id, name, slug) values
  ('a1000000-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-000000000001','HQ','mkt101-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('a1000000-0000-0000-0000-0000000000c1','a1000000-0000-0000-0000-000000000001',
   'a1000000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('a1000000-0000-0000-0000-000000000011','a1000000-0000-0000-0000-000000000001','Owner','owner@mkt101.test',true,'a1000000-0000-0000-0000-0000000000a1'),
  ('a1000000-0000-0000-0000-000000000012','a1000000-0000-0000-0000-000000000001','Finance','finance@mkt101.test',true,'a1000000-0000-0000-0000-0000000000a2'),
  ('a1000000-0000-0000-0000-000000000013','a1000000-0000-0000-0000-000000000001','Emp','emp@mkt101.test',true,'a1000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select 'a1000000-0000-0000-0000-000000000001', u,
       'a1000000-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-0000000000c1', true
from unnest(array['a1000000-0000-0000-0000-000000000011'::uuid,
                  'a1000000-0000-0000-0000-000000000012'::uuid,
                  'a1000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'a1000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('a1000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('a1000000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('a1000000-0000-0000-0000-000000000013'::uuid,'employee')) v(u,rc)
join public.roles r on r.code = v.rc;

-- A campaign in EACH tenant. The rival's campaign exists so that assertion 13 is a TENANT test and
-- not an FK test: with a matching (tenant_id, marketing_campaign_id) pair available, the only thing
-- left to refuse the write is RLS.
insert into public.marketing_campaigns (id, tenant_id, platform_code, campaign_name, status_code) values
  ('a1000000-0000-0000-0000-0000000000cc','a1000000-0000-0000-0000-000000000001','google_ads','Umrah Q3','active'),
  ('a1000000-0000-0000-0000-0000000000cd','a1000000-0000-0000-0000-000000000002','google_ads','Rival Q3','active');

-- The FX chain. `exchange_rate_adjustments` records a POST-LOCK correction: which rate a booking item
-- was priced at, and which rate replaced it.
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('a1000000-0000-0000-0000-0000000000d1','a1000000-0000-0000-0000-000000000001','person','Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id) values
  ('a1000000-0000-0000-0000-0000000000b1','a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-00000000000a','a1000000-0000-0000-0000-0000000000c1','a1000000-0000-0000-0000-0000000000d1','confirmed','Trip','BR-MKT101-1','a1000000-0000-0000-0000-000000000011');
insert into public.suppliers (id, tenant_id, name, supplier_type_code) values
  ('a1000000-0000-0000-0000-0000000000e1','a1000000-0000-0000-0000-000000000001','Air','airline');
insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code) values
  ('a1000000-0000-0000-0000-0000000000f1','a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000b1','a1000000-0000-0000-0000-0000000000e1','flight_ticket','USD',400,500,'confirmed');
insert into public.exchange_rates (id, tenant_id, from_currency_code, to_currency_code, rate, effective_at) values
  ('a1000000-0000-0000-0000-0000000000ea','a1000000-0000-0000-0000-000000000001','USD','EGP',48.0, now() - interval '2 days'),
  ('a1000000-0000-0000-0000-0000000000eb','a1000000-0000-0000-0000-000000000001','USD','EGP',49.5, now() - interval '1 day');

-- =============================================================================================
-- 1-3. THE AUTHORIZATION MODEL, MEASURED. These pin WHY RLS is allowed to be the whole layer here.
--      If either table ever grows an RPC, assertion 1 fails and this file must be re-reasoned.
-- =============================================================================================
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('app','public','reporting')
      and (p.prosrc like '%campaign_daily_metrics%' or p.prosrc like '%exchange_rate_adjustments%')),
  0,
  'neither surface has ANY function consumer -- so the table door is not a bypass of an RPC door, it IS the door, and RLS is the complete enforcement layer');

select is(
  (select count(distinct p.key)::int from public.permissions p
     join public.role_permissions rp on rp.permission_id = p.id
    where p.key in ('VIEW_MARKETING_DASHBOARD','MANAGE_MARKETING_CAMPAIGN','CREATE_EXCHANGE_RATE_ADJUSTMENT')),
  3,
  'all three permissions governing these two surfaces are held by at least one role -- neither table is an unreachable capability');

select is(
  (select count(*)::int from pg_policies
    where schemaname='public' and tablename='campaign_daily_metrics'
      and with_check like '%MANAGE_MARKETING_CAMPAIGN%'
      and qual like '%VIEW_MARKETING_DASHBOARD%'),
  1,
  'RLS-1 SHAPE: the WRITE half of the metrics policy names a WRITE permission while its READ half names the read one -- the two are not the same permission');

-- =============================================================================================
-- 4-7. CDM-1. A DAILY METRIC IS ONE ROW A DAY. Canon 31 says metrics "may be imported from
--      integrations"; an import is retried, and before `202607061100` a retry silently doubled
--      every figure for that campaign-day.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok($$
  insert into public.campaign_daily_metrics
    (id, tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code, impressions, clicks)
  values ('a1000000-0000-0000-0000-0000000000dd','a1000000-0000-0000-0000-000000000001',
          'a1000000-0000-0000-0000-0000000000cc', date '2026-08-01', 1200.0000, 'EGP', 50000, 900)$$,
  'CONTROL: a holder of MANAGE_MARKETING_CAMPAIGN can record a campaign-day -- so the refusals below are refusals of the ACT, not of the actor');

select is(
  (select count(*)::int from public.campaign_daily_metrics where id='a1000000-0000-0000-0000-0000000000dd'),
  1,
  'CONTROL: the row is really there -- "it did not throw" is not evidence that a write occurred');

select throws_ok($$
  insert into public.campaign_daily_metrics
    (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code)
  values ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000cc',
          date '2026-08-01', 1200.0000, 'EGP')$$,
  '23505',
  null,
  'CDM-1: a SECOND row for the same campaign and the same day is refused -- a retried import can no longer double every figure');

select lives_ok($$
  insert into public.campaign_daily_metrics
    (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code)
  values ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000cc',
          date '2026-08-02', 300.0000, 'EGP')$$,
  'NEGATIVE CONTROL: the NEXT day is still a legal row -- the key constrains the campaign-day, not the campaign');

-- =============================================================================================
-- 8-10. CDM-2. A MEASURE MAY BE UNKNOWN, NEVER NEGATIVE. Arithmetic, not policy: NULL stays legal
--       on every one of the six because canon marks all six nullable.
-- =============================================================================================
select throws_ok($$
  insert into public.campaign_daily_metrics
    (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code)
  values ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000cc',
          date '2026-08-03', -1.0000, 'EGP')$$,
  '23514',
  null,
  'CDM-2: negative spend is refused');

select throws_ok($$
  insert into public.campaign_daily_metrics
    (tenant_id, marketing_campaign_id, metric_date, impressions)
  values ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000cc',
          date '2026-08-04', -5)$$,
  '23514',
  null,
  'CDM-2: a negative COUNT is refused too -- the constraint covers the four measures, not only the two money columns');

select lives_ok($$
  insert into public.campaign_daily_metrics
    (tenant_id, marketing_campaign_id, metric_date)
  values ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000cc',
          date '2026-08-05')$$,
  'NEGATIVE CONTROL: an all-NULL measure row is still legal -- a CHECK is not evaluated against NULL, and canon marks every measure nullable');

reset role;

-- =============================================================================================
-- 11-13. CDM: THE PERMISSION IS REAL, AND SO IS THE TENANT BOUNDARY. Assertion 11 proves the
--        employee's refusal in 12 is not merely "the row was invisible" by measuring both halves.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.campaign_daily_metrics),
  0,
  'an employee holding neither marketing permission sees ZERO metric rows -- the read half of the policy charges VIEW_MARKETING_DASHBOARD');

select throws_ok($$
  insert into public.campaign_daily_metrics
    (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code)
  values ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000cc',
          date '2026-08-06', 10.0000, 'EGP')$$,
  '42501',
  null,
  'an employee cannot INSERT a metric row -- refused by the policy WITH CHECK, which is where the write permission lives');

reset role;

select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok($$
  insert into public.campaign_daily_metrics
    (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code)
  values ('a1000000-0000-0000-0000-000000000002','a1000000-0000-0000-0000-0000000000cd',
          date '2026-08-07', 10.0000, 'EGP')$$,
  '42501',
  null,
  'TENANT CROSSING: a fully privileged owner cannot write a metric row into ANOTHER tenant -- the campaign belongs to that tenant, so the composite FK is satisfied and only RLS is left to refuse it');

reset role;

-- =============================================================================================
-- 14-18. ERA-1. A POST-LOCK RATE CORRECTION IS WRITTEN ONCE. Canon 31 gives this table no
--        `updated_at` while giving one to every table it means to be updated -- so canon already
--        said this, and nothing enforced it.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select lives_ok($$
  insert into public.exchange_rate_adjustments
    (id, tenant_id, booking_item_id, original_exchange_rate_id, new_exchange_rate_id, reason_code, reason_text)
  values ('a1000000-0000-0000-0000-0000000000ac','a1000000-0000-0000-0000-000000000001',
          'a1000000-0000-0000-0000-0000000000f1','a1000000-0000-0000-0000-0000000000ea',
          'a1000000-0000-0000-0000-0000000000eb','incorrect_rate','Rate keyed from the wrong day')$$,
  'CONTROL: a finance_manager holding CREATE_EXCHANGE_RATE_ADJUSTMENT can RECORD a correction -- the immutability below is not a disguised authorization failure');

select is(
  (select created_by from public.exchange_rate_adjustments where id='a1000000-0000-0000-0000-0000000000ac'),
  'a1000000-0000-0000-0000-000000000012'::uuid,
  'ATTR-1 REGRESSION GUARD: created_by is DERIVED from the session, not taken from the caller');

select is(
  (select count(*)::int from information_schema.role_table_grants
    where table_schema='public' and table_name='exchange_rate_adjustments'
      and grantee='authenticated' and privilege_type in ('UPDATE','DELETE')),
  0,
  'ERA-1 layer 2: authenticated holds neither UPDATE nor DELETE -- the PostgREST door is closed before any row is reached');

select is(
  (select count(*)::int from pg_policies
    where schemaname='public' and tablename='exchange_rate_adjustments' and cmd in ('UPDATE','DELETE')),
  0,
  'ERA-1 layer 3: no policy promises an UPDATE or a DELETE the table no longer performs -- scope_update and scope_delete are gone, not merely unreachable');

reset role;

-- Layer 1 is proven as the table OWNER, deliberately. The two layers above already stop
-- `authenticated`, so an assertion run as `authenticated` would pass even if the trigger were
-- missing -- it would be measuring the grant twice and the trigger never. This is the only path
-- that reaches app.forbid_mutation() at all.
select throws_ok($$
  update public.exchange_rate_adjustments
     set original_exchange_rate_id = 'a1000000-0000-0000-0000-0000000000eb'
   where id = 'a1000000-0000-0000-0000-0000000000ac'$$,
  'P0001',
  'append-only table: UPDATE is not permitted on exchange_rate_adjustments',
  'ERA-1 layer 1: even the table owner cannot rewrite which rate was originally locked -- the trigger closes the path the two grant layers do not cover');

-- =============================================================================================
-- 19-21. PAR-4 DEFECT INJECTION. A passing test is not evidence that the named enforcer is what
--        did the enforcing. Drop it inside a savepoint, prove the violation SUCCEEDS, roll back,
--        and prove it is refused again -- the closing move TEST-3 exists to require.
-- =============================================================================================
savepoint before_injection;
drop index public.campaign_daily_metrics_campaign_day_key;

select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok($$
  insert into public.campaign_daily_metrics
    (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code)
  values ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000cc',
          date '2026-08-01', 1200.0000, 'EGP')$$,
  'DEFECT INJECTION: with the unique index dropped the duplicate campaign-day SUCCEEDS -- so assertion 6 is that index and nothing else');

reset role;
rollback to savepoint before_injection;

select set_config('request.jwt.claims','{"sub":"a1000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok($$
  insert into public.campaign_daily_metrics
    (tenant_id, marketing_campaign_id, metric_date, spend_amount, currency_code)
  values ('a1000000-0000-0000-0000-000000000001','a1000000-0000-0000-0000-0000000000cc',
          date '2026-08-01', 1200.0000, 'EGP')$$,
  '23505',
  null,
  'TEST-3 CLOSING MOVE: after the rollback the duplicate is refused again -- an injection assertion placed last is never counted, because the rollback undoes the counter');

reset role;

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid=t.tgrelid
     join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
     join pg_proc p on p.oid=t.tgfoid
    where c.relname='exchange_rate_adjustments' and p.proname='forbid_mutation' and not t.tgisinternal),
  1,
  'the append-only trigger survived the rollback -- the savepoint restored the enforcer it borrowed');

select * from finish();
rollback;
