-- pgTAP invariant: the end-user table/function privilege model matches the model migration
-- 202607043400 decided and migration 202607050200 restored. Discovery-to-guard for the live-only
-- privilege drift found 2026-08-21 (SPEC-124): on the hosted project, Supabase's default ACL
-- (ALTER DEFAULT PRIVILEGES ... GRANT ALL ON TABLES TO anon, authenticated) silently gave anon full
-- DML on all 72 public tables and gave authenticated DELETE/TRUNCATE, contradicting both the
-- "anon: nothing (login required)" and the archive-not-delete decisions in 202607043400.
--
-- This test is the permanent guard. It is catalog-driven -- it introspects every public base table
-- rather than naming them -- so a table added by a future migration is covered automatically and
-- cannot silently re-introduce the defect. Critically, it fails on the LOCAL stack too: the
-- assertions are about the intended end state, not about which environment produced the drift.
create extension if not exists pgtap with schema extensions;

begin;
select plan(5);

-- 1. anon holds no DML of any kind on any public base table. ORVION has no anonymous flow; every
--    RLS policy is scoped to {authenticated}, so an anon grant is pure attack surface.
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     cross join lateral (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE'),('TRUNCATE')) as p(priv)
    where n.nspname = 'public' and c.relkind = 'r'
      and has_table_privilege('anon', c.oid, p.priv)),
  0,
  'anon holds no SELECT/INSERT/UPDATE/DELETE/TRUNCATE on any public base table');

-- 2. authenticated never holds DELETE or TRUNCATE: 30_database_conventions.md is archive-not-delete,
--    and no app.* RPC issues DELETE or TRUNCATE anywhere. A DELETE grant is reachable in practice
--    because the tenant_isolation policies are FOR ALL, so USING permits DELETE of in-tenant rows.
select is(
  (select count(*)::int
     from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     cross join lateral (values ('DELETE'),('TRUNCATE')) as p(priv)
    where n.nspname = 'public' and c.relkind = 'r'
      and has_table_privilege('authenticated', c.oid, p.priv)),
  0,
  'authenticated holds no DELETE or TRUNCATE on any public base table');

-- 3. The ten global/reference config tables stay read-only for authenticated: they are
--    platform-managed, and a tenant user must never be able to mint a role, permission, plan,
--    currency or country.
select is(
  (select count(*)::int
     from unnest(array[
       'catalog_types','countries','currencies','feature_entitlements','languages',
       'nationalities','permissions','role_permissions','roles','subscription_plans'
     ]) as t(relname)
     cross join lateral (values ('INSERT'),('UPDATE')) as p(priv)
    where has_table_privilege('authenticated', ('public.' || quote_ident(t.relname))::regclass, p.priv)),
  0,
  'the ten global/reference tables are read-only for authenticated (no INSERT, no UPDATE)');

-- 4. The audit backbone is READ-ONLY at the privilege layer for end users, and append-only at the
--    trigger layer. Until WP-00 (202607053000) authenticated also held INSERT, and the only INSERT
--    policy checked tenant membership -- so an employee could write an event attributed to a
--    colleague, about a record they could not read, with an unregistered event type, backdated by
--    an explicit created_at, and the append-only trigger then made that forgery permanent.
--    app.record_event (SECURITY DEFINER) is now the sole writer; the grant is the gate.
select is(
  (select count(*)::int
     from unnest(array['events','security_events']) as t(relname)
    cross join lateral (values ('INSERT'),('UPDATE'),('DELETE')) as p(priv)
    where has_table_privilege('authenticated', ('public.' || quote_ident(t.relname))::regclass, p.priv)
       or not has_table_privilege('authenticated', ('public.' || quote_ident(t.relname))::regclass, 'SELECT')),
  0,
  'events and security_events grant authenticated SELECT only -- no INSERT, UPDATE or DELETE');

-- 5. No app-schema function is executable by PUBLIC. Every app.* RPC carries an explicit grant to
--    its intended role, so a PUBLIC EXECUTE only widens reach -- and would become live exposure the
--    moment anyone granted anon USAGE on schema app, since 13 of these are SECURITY DEFINER.
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) as g(grantor, grantee, privilege_type, is_grantable)
    where n.nspname = 'app' and p.prokind = 'f'
      and g.privilege_type = 'EXECUTE' and g.grantee = 0),
  0,
  'no app-schema function grants EXECUTE to PUBLIC');

select * from finish();
rollback;
