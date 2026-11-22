-- pgTAP: Batch 6 exit -- every permission is enforced or carries its reason, and every table states its isolation basis.
--
-- Catalog-driven, like `01_rls_coverage_test.sql`: nothing below is a fixture, every assertion reads the live catalog,
-- so a new permission, table or policy is judged the moment it exists.
--
-- RPC-1 (EC-2): the programme opened with 37 permissions enforced nowhere. Measured at `790aa96` (277 migrations), and
--   identically on Platinum Primary, every one of the 77 permissions is named by an `app`/`public` function or an RLS
--   predicate except four, each with a recorded reason:
--     MANAGE_ROLES          -- the role matrix (`roles`, `permissions`, `role_permissions`) grants no member a write,
--                              so there is no writable surface to charge it on; the absent grant is stronger than a check.
--     ACCESS_API_FULL,
--     ACCESS_API_READ_ONLY,
--     VIEW_ADVANCED_DASHBOARDS -- the surfaces they name do not exist yet; no role holds them, so they grant nothing.
--   Assertion 1 is a set equality: a fifth unenforced permission fails it, and closing one of the four must remove it
--   here, so the ceiling can only shrink.
--
-- EC-3: every `public` table has row-level security, and its basis is one of four, pinned by name where it is not the
--   tenant predicate:
--     TENANT      -- every policy on the table names `current_tenant_id()`;
--     REFERENCE   -- platform-owned reference data: members SELECT `true`, write nothing;
--     PLATFORM    -- closed to every member (`false` policy, no privilege); only the platform's functions touch it;
--     IDENTITY    -- owned by the signed-in identity: every policy names `auth.uid()`.
--   `anon` holds no privilege on any `public` table.
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

create temporary view t186_permission_use as
with fsrc as (
  select string_agg(pg_get_functiondef(p.oid), E'\n') as src
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname in ('app','public') and p.prokind in ('f','p')),
psrc as (
  select string_agg(coalesce(qual,'') || ' ' || coalesce(with_check,''), E'\n') as src from pg_policies)
select pe.key,
       position('''' || pe.key || '''' in fsrc.src) > 0 or position('''' || pe.key || '''' in psrc.src) > 0 as enforced
  from public.permissions pe, fsrc, psrc;

create temporary view t186_basis as
select c.relname::text as tbl,
       case
         when exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname
                        and coalesce(p.qual,'') || coalesce(p.with_check,'') like '%current_tenant_id%')
           then 'TENANT'
         when c.relname in ('catalog_types','countries','currencies','feature_entitlements','languages',
                            'nationalities','permissions','role_permissions','roles','subscription_plans')
           then 'REFERENCE'
         when c.relname in ('document_storage_findings','integration_cursors','scheduled_job_findings',
                            'tenant_license_activations')
           then 'PLATFORM'
         when c.relname in ('otp_challenges','totp_enrollments','trusted_devices')
           then 'IDENTITY'
         else 'NONE'
       end as basis
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind in ('r','p');

-- 1. RPC-1 ceiling: exactly four permissions are enforced nowhere.
select set_eq(
  $$select key from t186_permission_use where not enforced$$,
  $$values ('ACCESS_API_FULL'),('ACCESS_API_READ_ONLY'),('MANAGE_ROLES'),('VIEW_ADVANCED_DASHBOARDS')$$,
  'RPC-1: only the four reasoned permissions are enforced nowhere -- the set can only shrink');

-- 2. The three that gate absent surfaces are held by no role.
select is(
  (select count(*)::int from public.role_permissions rp join public.permissions pe on pe.id = rp.permission_id
    where pe.key in ('ACCESS_API_FULL','ACCESS_API_READ_ONLY','VIEW_ADVANCED_DASHBOARDS')),
  0,
  'RPC-1: no role holds a permission whose surface does not exist');

-- 3. MANAGE_ROLES has no surface: no member may write the role matrix.
select is(
  (select count(*)::int
     from unnest(array['roles','permissions','role_permissions']) t
     cross join unnest(array['authenticated','anon']) r
     cross join unnest(array['INSERT','UPDATE','DELETE','TRUNCATE']) pr
    where has_table_privilege(r, 'public.' || t, pr)),
  0,
  'RPC-1: no member role may write roles, permissions or role_permissions, so MANAGE_ROLES gates nothing');

-- 4. Every public table has row-level security.
select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity),
  0,
  'EC-3: every public table has row-level security enabled');

-- 5. Every table has a stated basis, and the named bases are exactly the seventeen that are not TENANT.
select is(
  (select string_agg(tbl, ',' order by tbl) from t186_basis where basis = 'NONE'),
  null,
  'EC-3: every public table has a stated isolation basis');

select set_eq(
  $$select tbl from t186_basis b where basis <> 'TENANT'
      and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = b.tbl
                        and coalesce(p.qual,'') || coalesce(p.with_check,'') like '%current_tenant_id%')$$,
  $$values ('catalog_types'),('countries'),('currencies'),('feature_entitlements'),('languages'),('nationalities'),
           ('permissions'),('role_permissions'),('roles'),('subscription_plans'),
           ('document_storage_findings'),('integration_cursors'),('scheduled_job_findings'),('tenant_license_activations'),
           ('otp_challenges'),('totp_enrollments'),('trusted_devices')$$,
  'EC-3: exactly seventeen tables rest on a basis other than the tenant predicate');

-- 6. TENANT: no policy on a tenant table omits the tenant predicate (no permissive side door).
select is(
  (select string_agg(p.tablename || '.' || p.policyname, ',' order by 1)
     from pg_policies p join t186_basis b on b.tbl = p.tablename
    where p.schemaname = 'public' and b.basis = 'TENANT'
      and coalesce(p.qual,'') || coalesce(p.with_check,'') not like '%current_tenant_id%'),
  null,
  'EC-3 TENANT: every policy on a tenant table names current_tenant_id()');

-- 7. REFERENCE: members read, never write; every policy is a SELECT.
select is(
  (select string_agg(b.tbl, ',' order by 1) from t186_basis b
    where b.basis = 'REFERENCE'
      and (not has_table_privilege('authenticated', 'public.' || b.tbl, 'SELECT')
           or has_table_privilege('authenticated', 'public.' || b.tbl, 'INSERT,UPDATE,DELETE,TRUNCATE')
           or exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = b.tbl and p.cmd <> 'SELECT'))),
  null,
  'EC-3 REFERENCE: members read platform reference data and write none of it');

-- 8. PLATFORM: closed to every member.
select is(
  (select string_agg(b.tbl, ',' order by 1) from t186_basis b
    where b.basis = 'PLATFORM'
      and (has_table_privilege('authenticated', 'public.' || b.tbl, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE')
           or exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = b.tbl
                        and (coalesce(p.qual,'false') <> 'false' or coalesce(p.with_check,'false') <> 'false')))),
  null,
  'EC-3 PLATFORM: platform-only tables grant no member any privilege and every policy is false');

-- 9. IDENTITY: every policy binds the row to the signed-in identity.
select is(
  (select string_agg(p.tablename || '.' || p.policyname, ',' order by 1)
     from pg_policies p join t186_basis b on b.tbl = p.tablename
    where p.schemaname = 'public' and b.basis = 'IDENTITY'
      and (coalesce(p.qual,'') not like '%auth.uid()%'
           or (p.cmd in ('ALL','INSERT','UPDATE') and coalesce(p.with_check,'') not like '%auth.uid()%'))),
  null,
  'EC-3 IDENTITY: every policy on an identity-owned table names auth.uid() on read and write');

-- 10. anon holds nothing on any public table.
select is(
  (select string_agg(c.relname, ',' order by 1) from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind in ('r','p')
      and has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE,TRUNCATE')),
  null,
  'EC-3: anon holds no privilege on any public table');

select * from finish();
rollback;
