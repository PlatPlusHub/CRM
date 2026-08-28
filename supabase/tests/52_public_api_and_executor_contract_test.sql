-- pgTAP: API-1's wrapper safety rule, the executor's claim contract, and FND-1.
--
-- Assertion 1 is the important one and it is a CLASS guard, not a check on two functions. ORVION
-- keeps its logic in the private `app` schema, which PostgREST does not expose, so every endpoint it
-- will ever have must be a `public` wrapper. A wrapper written `security definer` would run as its
-- owner, so PostgreSQL would check EXECUTE on the inner `app.*` function against the OWNER instead
-- of the caller -- turning the wrapper into a privilege-escalation bridge that hands any caller the
-- private schema's full authority. That mistake is one word long and invisible in review. This
-- assertion makes it unshippable, for the two wrappers that exist today and the ~130 API-1 will add.
--
-- What this file CANNOT prove is that the endpoints are reachable over HTTP -- pgTAP never opens a
-- socket, which is precisely why API-1 went unnoticed for the whole programme while the suite was
-- green. `scripts/verify_storage_end_to_end.ps1` is where reachability is proven, with real bytes.
create extension if not exists pgtap with schema extensions;

begin;
select plan(15);

-- =============================================================================================
-- 1-3. THE WRAPPER RULE.
-- =============================================================================================
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f' and p.prosecdef
      -- Extension-owned functions are not ORVION's API surface.
      and not exists (select 1 from pg_depend d
                       where d.objid = p.oid and d.deptype = 'e')),
  0,
  'NO public-schema function is SECURITY DEFINER -- a definer wrapper would be a privilege bridge into app');

select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
      and not exists (select 1 from unnest(coalesce(p.proconfig, '{}')) c where c like 'search_path=%')),
  0,
  '...and every one of them pins search_path, exactly as the app functions must');

select ok(
  (select count(*) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')) >= 2,
  'POSITIVE CONTROL: ORVION public endpoints actually exist, so the two zeros above are not vacuous');

-- =============================================================================================
-- 4-6. AUTHORITY. The endpoints are platform-only on BOTH layers -- the grant and the inner
--      function agree, which is the property that makes the wrapper safe to expose.
-- =============================================================================================
select is(
  (select count(*)::int from (values ('anon'),('authenticated')) r(role)
    where has_function_privilege(r.role, 'public.claim_storage_actions(integer)', 'EXECUTE')),
  0,
  'neither anon nor authenticated may execute the claim endpoint');

select is(
  (select count(*)::int from (values ('anon'),('authenticated')) r(role)
    where has_function_privilege(r.role, 'public.resolve_storage_finding(uuid,text,text)', 'EXECUTE')),
  0,
  '...nor the resolve endpoint');

select ok(
  has_function_privilege('service_role', 'public.claim_storage_actions(integer)', 'EXECUTE')
  and has_function_privilege('service_role', 'public.resolve_storage_finding(uuid,text,text)', 'EXECUTE'),
  'POSITIVE CONTROL: service_role can execute both -- the denials above are about role, not existence');

-- GRANT-1 at the class: the DEFAULT itself must not hand anon/authenticated execute on new public
-- functions, or every wrapper API-1 adds is born reachable by anonymous callers.
select is(
  (select count(*)::int from pg_default_acl d
    where d.defaclnamespace = 'public'::regnamespace and d.defaclobjtype = 'f'
      and d.defaclrole = 'postgres'::regrole
      and (d.defaclacl::text like '%anon=X%' or d.defaclacl::text like '%authenticated=X%')),
  0,
  'the default privileges for new public functions grant nothing to anon or authenticated');

-- =============================================================================================
-- Fixture for the claim contract.
-- =============================================================================================
insert into public.tenants (id, name, slug, status) values
  ('52000000-0000-0000-0000-000000000001','Claim Travel','claim-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '52000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code)
values ('52000000-0000-0000-0000-0000000000d1','52000000-0000-0000-0000-000000000001','passport','P','active');
insert into public.document_versions (id, tenant_id, document_id, version_number, file_name, file_type_code, is_current, uploaded_at) values
  ('52000000-0000-0000-0000-0000000000f1','52000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-0000000000d1',1,'v1.pdf','pdf',false, now() - interval '400 days'),
  ('52000000-0000-0000-0000-0000000000f2','52000000-0000-0000-0000-000000000001','52000000-0000-0000-0000-0000000000d1',2,'v2.pdf','pdf',true, now());
update public.documents set current_version_id = '52000000-0000-0000-0000-0000000000f2'
 where id = '52000000-0000-0000-0000-0000000000d1';

-- =============================================================================================
-- 7-10. THE CLAIM CONTRACT. Every eligibility question lives in the database, so the executor
--       never decides anything. Each assertion removes one reason and requires the work to vanish.
-- =============================================================================================
select app.reconcile_document_storage();

select is(
  (select count(*)::int from app.claim_storage_actions()),
  0,
  'with retention UNDECIDED there is no work at all, however old the version');

create or replace function app.document_retention_days()
returns integer language sql immutable set search_path = '' as $fn$ select 30::integer; $fn$;
select app.reconcile_document_storage();

select is(
  (select count(*)::int from app.claim_storage_actions()),
  1,
  'with retention set, the superseded version becomes exactly one claimable action');

select is(
  (select storage_path from app.claim_storage_actions()),
  app.document_storage_path('52000000-0000-0000-0000-000000000001',
                            '52000000-0000-0000-0000-0000000000d1', 1),
  '...naming the system-derived path, never anything a caller supplied');

-- RET-2 enforced where the work is handed out, not only where it is refused. Without this the
-- executor would collect work it is structurally forbidden to finish and burn an attempt each run.
update public.subscriptions set subscription_status_code = 'expired'
 where tenant_id = '52000000-0000-0000-0000-000000000001';

select is(
  (select count(*)::int from app.claim_storage_actions()),
  0,
  'a RESTRICTED tenant''s work is never handed out -- RET-2 applied at claim time');

update public.subscriptions set subscription_status_code = 'active'
 where tenant_id = '52000000-0000-0000-0000-000000000001';

-- =============================================================================================
-- 11. A version that became current again disappears from the work list -- the finding is stale,
--     and destruction must follow the CURRENT truth rather than the recorded one.
-- =============================================================================================
update public.document_versions set is_current = false where id = '52000000-0000-0000-0000-0000000000f2';
update public.documents set current_version_id = '52000000-0000-0000-0000-0000000000f1'
 where id = '52000000-0000-0000-0000-0000000000d1';
update public.document_versions set is_current = true where id = '52000000-0000-0000-0000-0000000000f1';

select is(
  (select count(*)::int from app.claim_storage_actions()),
  0,
  'a version promoted back to CURRENT is withdrawn from the work list');

-- Put it back so the FND-1 assertions have a real open finding to work on.
update public.document_versions set is_current = false where id = '52000000-0000-0000-0000-0000000000f1';
update public.documents set current_version_id = '52000000-0000-0000-0000-0000000000f2'
 where id = '52000000-0000-0000-0000-0000000000d1';
update public.document_versions set is_current = true where id = '52000000-0000-0000-0000-0000000000f2';

-- =============================================================================================
-- 12-14. FND-1. WP-04-D registered `failed` as "stays discoverable" and then wrote a resolver that
--        marked it resolved -- and reconciliation reopens only missing_object/orphan_object, never
--        retention_expired. A retention action that failed once would have been hidden forever.
--        That is PH8-1's shape, which this programme has already paid for once.
-- =============================================================================================
select is(
  (select app.platform_resolve_storage_finding(
     (select id from public.document_storage_findings
       where tenant_id = '52000000-0000-0000-0000-000000000001'
         and finding_type_code = 'retention_expired' and resolved_at is null),
     'failed', 'simulated storage outage')),
  'failed',
  'a failure is accepted and reported back');

select is(
  (select resolved_at is null and attempt_count = 1 and last_error = 'simulated storage outage'
     from public.document_storage_findings
    where tenant_id = '52000000-0000-0000-0000-000000000001'
      and finding_type_code = 'retention_expired'),
  true,
  '...and the finding stays OPEN with the attempt counted and the reason kept');

select is(
  (select count(*)::int from app.claim_storage_actions()),
  1,
  '...so the very next run claims it again -- failed work is retried, never lost');

select finish();
rollback;
