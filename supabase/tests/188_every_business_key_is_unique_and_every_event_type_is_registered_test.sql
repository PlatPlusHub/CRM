-- pgTAP: Batch 6 exit -- every business key is unique per its owner, and every event type is registered before it is written.
--
-- EC-8: the registry row "N1, DC-5, RC-4, R8, B3, RC-1 | TERMINAL IN SUBSTANCE" left six findings to the gate evaluation,
--   to be re-verified against their migrations. Measured at `5bed4ed` (277 migrations), DC-5 (`202607054600`), RC-4
--   (`202607048900`) and RC-1 already have behavioural tests (DC-5: 48, 49, 97, 116, 175; RC-4: 23, 45, 53; RC-1: 42,
--   66, 148). Two had none, and this test is theirs:
--     R8/B3 (`202607048800_group2_integrity_constraints.sql`) -- five business-key UNIQUE constraints, all validated:
--       bookings (tenant_id, booking_reference), quotations (tenant_id, quotation_number), subscription_plans
--       (plan_code), feature_entitlements (subscription_plan_id, feature_code) and usage_counters (tenant_id,
--       usage_metric_code, period_start, period_end). No test named any of them.
--     N1 (`202607049100_event_type_registry_enforcement.sql`, current body `20261114160000`) -- app.record_event refuses
--       an event_type_code, and a severity_code, that the catalog does not register. No test pinned the refusal.
--   Assertion 1 pins the exact five keys; assertions 2-9 prove each key refuses a duplicate inside its owner and, where
--   the owner is a tenant, admits the same value in another tenant (the key is not wider than its owner); assertions
--   10-12 prove the event registry refuses an unknown type and an unknown severity and admits a registered type.
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

insert into auth.users (id, email, email_confirmed_at) values
  ('c1880000-0000-0000-0000-0000000000a1','owner@a188.test', now()),
  ('c1880000-0000-0000-0000-0000000000a2','owner@b188.test', now());
insert into public.tenants (id, name, slug, status) values
  ('c1880000-0000-0000-0000-000000000001','A188 Travel','a188','active'),
  ('c1880000-0000-0000-0000-000000000002','B188 Travel','b188','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and t.id in ('c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-000000000002');
insert into public.branches (id, tenant_id, name, slug) values
  ('c1880000-0000-0000-0000-00000000000a','c1880000-0000-0000-0000-000000000001','HQ','a188-hq'),
  ('c1880000-0000-0000-0000-00000000000b','c1880000-0000-0000-0000-000000000002','HQ','b188-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('c1880000-0000-0000-0000-0000000000c1','c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-00000000000a','management','Exec'),
  ('c1880000-0000-0000-0000-0000000000c2','c1880000-0000-0000-0000-000000000002','c1880000-0000-0000-0000-00000000000b','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('c1880000-0000-0000-0000-000000000011','c1880000-0000-0000-0000-000000000001','Owner A','owner@a188.test',true,'c1880000-0000-0000-0000-0000000000a1'),
  ('c1880000-0000-0000-0000-000000000012','c1880000-0000-0000-0000-000000000002','Owner B','owner@b188.test',true,'c1880000-0000-0000-0000-0000000000a2');
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('c1880000-0000-0000-0000-0000000000d1','c1880000-0000-0000-0000-000000000001','person','Customer A'),
  ('c1880000-0000-0000-0000-0000000000d2','c1880000-0000-0000-0000-000000000002','person','Customer B');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id) values
  ('c1880000-0000-0000-0000-0000000000b1','c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-00000000000a','c1880000-0000-0000-0000-0000000000c1','c1880000-0000-0000-0000-0000000000d1','confirmed','Trip','BK-188-1','c1880000-0000-0000-0000-000000000011');
insert into public.quotations (id, tenant_id, customer_id, quotation_status_code, quotation_number, currency_code) values
  ('c1880000-0000-0000-0000-0000000000e1','c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-0000000000d1','sent','QT-188-1','EGP');
insert into public.usage_counters (id, tenant_id, usage_metric_code, period_start, period_end) values
  ('c1880000-0000-0000-0000-0000000000f1','c1880000-0000-0000-0000-000000000001','t188_metric','2026-10-01','2026-10-31');

-- 1. R8/B3: exactly the five business keys, each UNIQUE over its exact columns and validated.
select set_eq(
  $$select c.conrelid::regclass::text || ' ' || c.conname::text || ' ' || pg_get_constraintdef(c.oid)
      from pg_constraint c
     where c.contype = 'u' and c.convalidated
       and c.conname in ('bookings_tenant_reference_key','quotations_tenant_number_key','subscription_plans_code_key',
                         'feature_entitlements_plan_feature_key','usage_counters_tenant_metric_period_key')$$,
  $$values ('bookings bookings_tenant_reference_key UNIQUE (tenant_id, booking_reference)'),
           ('quotations quotations_tenant_number_key UNIQUE (tenant_id, quotation_number)'),
           ('subscription_plans subscription_plans_code_key UNIQUE (plan_code)'),
           ('feature_entitlements feature_entitlements_plan_feature_key UNIQUE (subscription_plan_id, feature_code)'),
           ('usage_counters usage_counters_tenant_metric_period_key UNIQUE (tenant_id, usage_metric_code, period_start, period_end)')$$,
  'R8/B3: the five business keys exist, are UNIQUE over their exact columns and are validated'
);

-- 2-3. A booking reference is unique inside its tenant, and only there.
select throws_ok(
  $$insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id)
    values ('c1880000-0000-0000-0000-0000000000b2','c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-00000000000a','c1880000-0000-0000-0000-0000000000c1','c1880000-0000-0000-0000-0000000000d1','confirmed','Trip 2','BK-188-1','c1880000-0000-0000-0000-000000000011')$$,
  '23505', null,
  'R8/B3: a second booking with the same reference in the same tenant is refused'
);
select lives_ok(
  $$insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id)
    values ('c1880000-0000-0000-0000-0000000000b3','c1880000-0000-0000-0000-000000000002','c1880000-0000-0000-0000-00000000000b','c1880000-0000-0000-0000-0000000000c2','c1880000-0000-0000-0000-0000000000d2','confirmed','Trip B','BK-188-1','c1880000-0000-0000-0000-000000000012')$$,
  'R8/B3: another tenant may use the same booking reference'
);

-- 4-5. A quotation number is unique inside its tenant, and only there.
select throws_ok(
  $$insert into public.quotations (id, tenant_id, customer_id, quotation_status_code, quotation_number, currency_code)
    values ('c1880000-0000-0000-0000-0000000000e2','c1880000-0000-0000-0000-000000000001','c1880000-0000-0000-0000-0000000000d1','sent','QT-188-1','EGP')$$,
  '23505', null,
  'R8/B3: a second quotation with the same number in the same tenant is refused'
);
select lives_ok(
  $$insert into public.quotations (id, tenant_id, customer_id, quotation_status_code, quotation_number, currency_code)
    values ('c1880000-0000-0000-0000-0000000000e3','c1880000-0000-0000-0000-000000000002','c1880000-0000-0000-0000-0000000000d2','sent','QT-188-1','EGP')$$,
  'R8/B3: another tenant may use the same quotation number'
);

-- 6. A plan code is unique across the platform.
select throws_ok(
  $$insert into public.subscription_plans (plan_code, name) values ('enterprise', 'Enterprise copy')$$,
  '23505', null,
  'R8/B3: a second subscription plan with an existing plan code is refused'
);

-- 7. A plan grants a feature at most once.
select throws_ok(
  $$insert into public.feature_entitlements (subscription_plan_id, feature_code)
    select fe.subscription_plan_id, fe.feature_code from public.feature_entitlements fe
     order by fe.subscription_plan_id, fe.feature_code limit 1$$,
  '23505', null,
  'R8/B3: a second entitlement of the same feature on the same plan is refused'
);

-- 8-9. A usage counter is unique per tenant, metric and period, and only per tenant.
select throws_ok(
  $$insert into public.usage_counters (id, tenant_id, usage_metric_code, period_start, period_end)
    values ('c1880000-0000-0000-0000-0000000000f2','c1880000-0000-0000-0000-000000000001','t188_metric','2026-10-01','2026-10-31')$$,
  '23505', null,
  'R8/B3: a second usage counter for the same tenant, metric and period is refused'
);
select lives_ok(
  $$insert into public.usage_counters (id, tenant_id, usage_metric_code, period_start, period_end)
    values ('c1880000-0000-0000-0000-0000000000f3','c1880000-0000-0000-0000-000000000002','t188_metric','2026-10-01','2026-10-31')$$,
  'R8/B3: another tenant may count the same metric over the same period'
);

-- 10-12. N1: the event registry is enforced at the write path.
select throws_matching(
  $$select app.record_event('c1880000-0000-0000-0000-000000000001'::uuid, 't188_not_a_registered_code', 'branch',
                            'c1880000-0000-0000-0000-00000000000a'::uuid)$$,
  '^unknown event_type_code: t188_not_a_registered_code',
  'N1: record_event refuses an event type the catalog does not register'
);
select throws_matching(
  $$select app.record_event('c1880000-0000-0000-0000-000000000001'::uuid, 'branch_created', 'branch',
                            'c1880000-0000-0000-0000-00000000000a'::uuid, null, null, null, null, null, 't188_not_a_severity')$$,
  '^unknown severity_code: t188_not_a_severity',
  'N1: record_event refuses a severity the catalog does not register'
);
select lives_ok(
  $$select app.record_event('c1880000-0000-0000-0000-000000000001'::uuid, 'branch_created', 'branch',
                            'c1880000-0000-0000-0000-00000000000a'::uuid)$$,
  'N1: record_event admits a registered event type (positive control)'
);

select * from finish();
rollback;
