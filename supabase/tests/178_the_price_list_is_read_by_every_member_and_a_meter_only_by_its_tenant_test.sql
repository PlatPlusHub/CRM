-- pgTAP: Batch 6 slice 56 (catalog_types, feature_entitlements, usage_counters) --
-- the catalog types and every plan's entitlements are product reference data that every member of
-- every tenant reads in full; a usage meter is read only inside its own tenant; an unknown feature
-- code is allowed; the most privileged member, an owner at aal2, is refused by the missing grant when
-- it tries to raise a plan limit, add a catalog type or reset its own meter (no migration: each door
-- held when probed, so this file pins what was measured and was not yet pinned; tests 10, 58 and 117
-- keep the grant lists and the INSERT refusal on meters).
-- ATTACK-CLASSES: AUTH=N/A TENANT DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
--   AUTH=N/A -- every read here is a SELECT that no second factor guards; no member writes any of
--     the three tables (tests 10 and 58).
--   STATE=N/A -- no row of the three has a lifecycle a member drives; no function writes them.
--   CONCURRENCY, REPLAY=N/A -- nothing writes a meter (test 117); reads change no state.
--   BUSINESS=N/A -- the plans' prices and limits are read, never charged here; ceilings are not
--     enforced (test 117).
--   OBSERVABILITY=N/A -- reading reference data and meters records no event on any door.
create extension if not exists pgtap with schema extensions;

begin;
select plan(10);

select set_config('t178.totals',
  (select count(*) from public.catalog_types)::text || '/' || (select count(*) from public.feature_entitlements)
    || '/' || (select count(*) from public.subscription_plans), true);

insert into auth.users (id, email) values
  ('17800000-0000-0000-0000-0000000000a1','trainee@c178.test'),
  ('17800000-0000-0000-0000-0000000000a2','other@c178.test');
insert into public.tenants (id, name, slug, status) values
  ('17800000-0000-0000-0000-000000000001','Meter Travel','meter-travel-178','active'),
  ('17800000-0000-0000-0000-000000000002','Other Travel','other-travel-178','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select v.t, sp.id, 'active' from public.subscription_plans sp,
  (values ('17800000-0000-0000-0000-000000000001'::uuid), ('17800000-0000-0000-0000-000000000002')) v(t)
where sp.plan_code = 'enterprise';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('17800000-0000-0000-0000-000000000011','17800000-0000-0000-0000-000000000001','Trainee','trainee@c178.test',true,'17800000-0000-0000-0000-0000000000a1'),
  ('17800000-0000-0000-0000-000000000012','17800000-0000-0000-0000-000000000002','Other','other@c178.test',true,'17800000-0000-0000-0000-0000000000a2');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values
  ('17800000-0000-0000-0000-000000000001'::uuid, '17800000-0000-0000-0000-000000000011'::uuid, 'trainee'),
  ('17800000-0000-0000-0000-000000000002', '17800000-0000-0000-0000-000000000012', 'owner')) v(t, u, c)
join public.roles r on r.code = v.c;
insert into public.usage_counters (id, tenant_id, usage_metric_code, period_start, period_end, used_value) values
  ('17800000-0000-0000-0000-0000000000e1','17800000-0000-0000-0000-000000000001','monthly_leads','2026-10-01','2026-10-31',3),
  ('17800000-0000-0000-0000-0000000000e2','17800000-0000-0000-0000-000000000002','monthly_leads','2026-10-01','2026-10-31',5);

select is(
  (select count(*)::int from public.catalog_types where ownership_type is null),
  0, 'every catalog type names its ownership (the column is nullable; no seeded row leaves it empty)');
select is(
  (select count(*)::int from public.feature_entitlements where limit_value is not null and limit_value <> trunc(limit_value)),
  0, 'every plan limit is a whole number (test 117 pins the range; nothing writes the rows but migrations)');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"17800000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
select is(
  (select count(*) from public.catalog_types)::text || '/' || (select count(*) from public.feature_entitlements)
    || '/' || (select count(distinct subscription_plan_id) from public.feature_entitlements),
  current_setting('t178.totals'),
  'a trainee at aal1 reads every catalog type and every plan''s entitlements: product reference data, not tenant data');
select is(
  (select string_agg(id::text, ',') from public.usage_counters),
  '17800000-0000-0000-0000-0000000000e1', 'the trainee reads its own tenant''s meter and no other');
select is(app.plan_allows('no_such_feature'), true,
  'a feature code no plan names is allowed: plan gating fails open by design (202607052500)');

select set_config('request.jwt.claims', '{"sub":"17800000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select is(
  (select count(*) from public.catalog_types)::text || '/' || (select count(*) from public.feature_entitlements)
    || '/' || (select count(distinct subscription_plan_id) from public.feature_entitlements),
  current_setting('t178.totals'),
  'another tenant''s owner reads the same full reference data');
select is(
  (select string_agg(id::text, ',') from public.usage_counters),
  '17800000-0000-0000-0000-0000000000e2', 'another tenant''s owner reads only its own meter, never the first tenant''s');
select throws_ok(
  $$update public.feature_entitlements set limit_value = limit_value + 1000 where limit_value is not null$$,
  '42501', 'permission denied for table feature_entitlements',
  'the owner at aal2 cannot raise a plan limit: no member holds UPDATE on the entitlements');
select throws_ok(
  $$insert into public.catalog_types (code, name, ownership_type) values ('c178_own', 'Own', 'system')$$,
  '42501', 'permission denied for table catalog_types',
  'the owner at aal2 cannot add a catalog type: the refusal is the missing grant, not a policy');
select throws_ok(
  $$update public.usage_counters set used_value = 0$$,
  '42501', 'permission denied for table usage_counters',
  'the owner at aal2 cannot reset its own tenant''s meter: the tenant policy is FOR ALL, so the grant is the door');

select * from finish();
rollback;
