-- Migration: restore_least_privilege_grant_model
-- Plan reference: SPEC-124. Discovery-to-guard (GOVERNANCE.md §18) for a live-only privilege drift
-- found by the 2026-08-21 remediation pass.
--
-- WHAT WAS FOUND (live Primary vrvtsxexkiiiivlkdxzp, 2026-08-21):
--   anon           held SELECT, INSERT, UPDATE, DELETE on ALL 72 public tables
--   authenticated  held DELETE (and TRUNCATE) on ALL 72 public tables, and full DML on the ten
--                  global/reference tables that migration 202607043400 deliberately made read-only
-- Migration 202607043400 explicitly decided the opposite on both points: "anon: nothing (login
-- required)" and "DELETE is intentionally withheld (archive-not-delete)". So this is NOT a new
-- decision -- it is the restoration of an already-ratified grant model that the hosted environment
-- silently overrode.
--
-- ROOT CAUSE (verified, not inferred): Supabase's hosted projects ship a default-ACL entry
--   ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO
--   anon, authenticated, service_role
-- (visible in pg_default_acl as anon=arwdDxtm/postgres). Migrations run as postgres, so every
-- `create table` in this repository silently inherited full DML for anon and authenticated on the
-- hosted project. The local CLI stack carries no such default ACL, which is exactly why
-- `supabase db reset` + the smoke-test could never surface this: locally the grants already match
-- 202607043400's intent. The defect existed only where it mattered most.
--
-- WHY THIS IS SAFE:
--   * No app.* function performs DELETE or TRUNCATE anywhere (verified against pg_proc on Primary,
--     2026-08-21) -- the archive-not-delete convention is honoured in code, so revoking DELETE
--     breaks no RPC.
--   * No policy anywhere targets anon; every policy is scoped to {authenticated}. Revoking anon's
--     table privileges therefore removes a redundant-but-real privilege layer, not working access.
--   * ORVION has no anonymous flow (login required) and no client surface yet; Primary holds zero
--     tenants and zero users.
--   * service_role is deliberately untouched: it is the platform/back-office role (rolbypassrls),
--     and app.provision_tenant / app.process_lead_sla are granted to it by design.
--
-- SCOPE BOUNDARY (deliberate): this migration restores the DECIDED model only. It does NOT decide
-- whether `authenticated` should hold direct INSERT/UPDATE on tenant tables at all -- that is a
-- genuine open architectural question (direct PostgREST writes bypass app.authorize(), the state
-- machines, and event emission, because RLS scopes ROWS, not PERMISSIONS). That question is raised
-- as an owner decision in MASTER_GAP_REGISTER.md (SEC-1) and is intentionally NOT answered here.

-- ---------------------------------------------------------------------------------------------
-- 1. Clear every inherited table privilege for the two end-user roles. Explicit re-grants follow.
--    service_role and orvion_integration are intentionally not referenced.
-- ---------------------------------------------------------------------------------------------
revoke all on all tables in schema public from anon;
revoke all on all tables in schema public from authenticated;

-- ---------------------------------------------------------------------------------------------
-- 2. Re-assert migration 202607043400's grant model, exactly.
-- ---------------------------------------------------------------------------------------------

-- 2a. Global/reference config tables: read-only for authenticated (writes are platform-only).
do $$
declare r text;
begin
  foreach r in array array[
    'catalog_types','countries','currencies','feature_entitlements','languages',
    'nationalities','permissions','role_permissions','roles','subscription_plans'
  ]
  loop
    execute format('grant select on public.%I to authenticated', r);
  end loop;
end
$$;

-- 2b. Append-only audit tables: select + insert only (RLS + the immutability trigger enforce the rest).
grant select, insert on public.events to authenticated;
grant select, insert on public.security_events to authenticated;

-- 2c. Everything else: select, insert, update. No DELETE (archive-not-delete), no TRUNCATE.
do $$
declare r record;
begin
  for r in
    select c.relname
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and c.relname not in (
        'catalog_types','countries','currencies','feature_entitlements','languages',
        'nationalities','permissions','role_permissions','roles','subscription_plans',
        'events','security_events'
      )
  loop
    execute format('grant select, insert, update on public.%I to authenticated', r.relname);
  end loop;
end
$$;

-- ---------------------------------------------------------------------------------------------
-- 3. Root-cause fix: stop future tables from re-inheriting the same privileges. Without this, the
--    next `create table` on the hosted project silently re-introduces the exact defect above.
--    No-op on the local stack (no such default ACL exists there), so both environments converge.
-- ---------------------------------------------------------------------------------------------
alter default privileges for role postgres in schema public revoke all on tables from anon;
alter default privileges for role postgres in schema public revoke all on tables from authenticated;

-- ---------------------------------------------------------------------------------------------
-- 4. app-schema functions: remove the implicit PUBLIC EXECUTE that PostgreSQL grants by default.
--    Every app.* function already carries an explicit grant to its intended role(s), so the PUBLIC
--    grant adds reach without adding capability. It is unreachable today only because anon lacks
--    USAGE on schema app -- a single accidental `grant usage on schema app to anon` would expose
--    every SECURITY DEFINER RPC at once. Defense in depth, no behavioural change.
--    app.forbid_mutation is the one function whose only non-owner grant is PUBLIC; it is a trigger
--    function, and PostgreSQL checks EXECUTE at CREATE TRIGGER time (as the table owner, postgres),
--    never at fire time, so revoking PUBLIC does not affect the two append-only triggers.
-- ---------------------------------------------------------------------------------------------
revoke execute on all functions in schema app from public;
