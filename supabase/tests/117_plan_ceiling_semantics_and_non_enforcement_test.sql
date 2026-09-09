-- AUDIT-2 / PD-23: numeric plan ceilings are stored, NULL is the only no-ceiling value,
-- and the ceiling subsystem remains intentionally readable rather than enforced.
create extension if not exists pgtap with schema extensions;

begin;
select plan(10);

select is((select count(*)::int from public.feature_entitlements), 66,
  'the complete three-plan entitlement matrix is seeded (22 features per plan)');

select is((select count(*)::int from public.feature_entitlements where limit_value is not null), 12,
  'exactly the six numeric metrics on starter and professional carry stored ceilings');

select is((select count(*)::int from public.feature_entitlements fe join public.subscription_plans sp on sp.id=fe.subscription_plan_id
            where sp.plan_code='enterprise' and fe.feature_code like 'max_%' and fe.limit_value is null), 6,
  'enterprise represents unlimited numeric metrics as NULL, never as a magic number');

select is((select count(*)::int from public.feature_entitlements where limit_value is not null and (limit_value < 0 or limit_value >= 2147483647)), 0,
  'no negative or large sentinel value impersonates unlimited');

select is((select count(*)::int from public.usage_counters), 0,
  'usage_counters remains empty until pricing activation earns a producer');

select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where p.prokind='f' and not (n.nspname='app' and p.proname='plan_limit')
              and pg_get_functiondef(p.oid) ~ '(^|[^a-z_])plan_limit([^a-z_]|$)'), 0,
  'app.plan_limit has no function caller: a readable ceiling is not a hidden write gate');

select is((select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
            where p.prokind='f' and pg_get_functiondef(p.oid) ~ 'public[.]usage_counters'), 0,
  'usage_counters has no function producer or reader');

select is((select count(*)::int from pg_policies where coalesce(qual,'') ~ 'plan_limit|usage_counters'
                                                  or coalesce(with_check,'') ~ 'plan_limit|usage_counters'), 0,
  'no RLS policy secretly enforces a numeric ceiling');

select is((select string_agg(t.tgname, ',' order by t.tgname) from pg_trigger t
            where not t.tgisinternal and t.tgrelid='public.usage_counters'::regclass),
  'usage_counters_set_updated_at',
  'usage_counters has only its timestamp-maintenance trigger, not a ceiling enforcer');

select ok(
  pg_get_functiondef('app.plan_allows(text)'::regprocedure) ~ 'fe[.]is_enabled'
  and pg_get_functiondef('app.has_permission(text)'::regprocedure) ~ 'app[.]plan_allows',
  'the independently enforced plan mechanism remains boolean feature gating through app.plan_allows');

select finish();
rollback;
