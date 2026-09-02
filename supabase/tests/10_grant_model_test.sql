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
select plan(8);

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

-- 5. No ORVION function -- in `app` OR in `public` -- is executable by PUBLIC. Every RPC carries an
--    explicit grant to its intended role, so a PUBLIC EXECUTE only widens reach, and in `app` it
--    would become live exposure the moment anyone granted anon USAGE on the schema, since 13 of
--    those are SECURITY DEFINER.
--
--    WIDENED 2026-08-28 from `app` alone. `public` is where API-1 put the 74 HTTP endpoints and
--    where `pg_default_acl` grants anon/authenticated EXECUTE on new functions by default (SPEC-124's
--    class) -- so checking only `app` left the schema that is actually exposed unchecked. Same shape
--    of mistake as the transition guard that covered one function out of ten.
--
--    Extension-owned functions are excluded by `pg_depend`, not by name: `public.moddatetime` is
--    Supabase's, owned by supabase_admin, and its ACL is not ORVION's to manage. Excluding it by
--    membership means a future extension is handled too, and a future ORVION function is not.
select is(
  (select count(*)::int
     from pg_proc p
     join pg_namespace n on n.oid = p.pronamespace
     cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) as g(grantor, grantee, privilege_type, is_grantable)
    where n.nspname in ('app', 'public') and p.prokind = 'f'
      and g.privilege_type = 'EXECUTE' and g.grantee = 0
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')),
  0,
  'no ORVION function in app or public grants EXECUTE to PUBLIC');

-- =============================================================================================
-- 6-7. SEC-1, MEASURED. RLS scopes WHICH ROWS a caller reaches; it does not enforce WHAT they may
--      do. Capability lives in the `app.*` RPCs -- which direct DML bypasses -- and in a partial set
--      of guard triggers covering archive, status transitions and financial columns. Creation and
--      ordinary field edits are unguarded on the direct path across most of the schema.
--
--      REPRODUCED 2026-08-28, not theorised: a role holding only VIEW_ALL_BRANCHES and
--      VIEW_ASSIGNED_LEADS (CREATE_BOOKING = false, CREATE_TASK = false) renamed a booking,
--      retitled a task, and INSERTED a customer -- all by direct DML, all accepted.
--
--      Resolving it is SEC-1, an open owner decision (revoke `authenticated` table writes and make
--      the RPCs the only door, or enforce canon 28's matrix on every table). Both are architectural
--      and neither may be invented here. What CAN be done now is stop the exposure growing: these
--      two assertions pin it, so a table added later without a capability guard fails the suite
--      instead of quietly widening the surface. The numbers may fall; they must never rise.
--
--      THE DETECTOR WAS WIDENED 2026-08-28, AND THE REASON IS A DEFECT IT CAUSED. It used to look
--      for `app.authorize` alone. `app.record_lead_interaction`, `app.convert_lead` and
--      `app.advance_lead` do not call it -- they enforce "the assigned handler, OR ASSIGN_LEAD, plus
--      MFA" inline with `app.has_permission` and an explicit raise. A permission-shaped search could
--      not see an assignment-shaped rule, so `202607056100` recorded that
--      `record_lead_interaction` "authorizes nothing" and left `lead_interactions` open as a
--      business question. It was not a question: it was the SEC-1 pattern, and `202607056200` closed
--      it. Measuring authorization by ONE function name is how a guard reports a hole that is not
--      there and misses one that is.
--
--      THE SECOND NUMBER COUNTS CAPABILITY TRIGGERS ONLY, and that is deliberate after a
--      measurement error of mine. A sweep that also credited "the policy mentions has_permission"
--      scored the money tables as guarded -- but the permission they named was
--      `VIEW_FINANCIAL_DOCUMENTS`, a READ permission, OR'd with a plain visibility test. Naming a
--      permission is not requiring the right one. FIN-3 (`202607055900`) then added real capability
--      triggers to payments, payment_allocations, receipts, refunds, invoices and quotation_items,
--      which is why this ceiling drops from 40 to 36 rather than rising.
--
--      RAISED 54 -> 55 by `202607059800` (RBAC-3), which added ONE administration table,
--      `user_permission_grants`. The ceiling is a deliberate speed bump, not a law: it exists so a
--      table cannot join the direct-write surface unnoticed. This one joined it on purpose, and its
--      capability requirement lives in its per-command RLS policies (MANAGE_PERMISSIONS), which is
--      the SPEC-138 shape `user_role_assignments` already uses -- which is also why it raises the
--      SECOND number below rather than being caught by it.
-- =============================================================================================
select cmp_ok(
  (select count(*)::int
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and has_table_privilege('authenticated', c.oid, 'INSERT')),
  '<=', 55,
  'SEC-1 ceiling: at most 55 tables accept a direct INSERT from authenticated');

select cmp_ok(
  (select count(*)::int
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and has_table_privilege('authenticated', c.oid, 'INSERT')
      -- SEC-1b (2026-08-29): `(t.tgtype & 4) <> 0` -- the trigger must fire ON INSERT. Without it
      -- this detector counted `enforce_status_transition` and `enforce_archive_authority`, which
      -- call app.authorize but are BEFORE **UPDATE** ONLY, so every status-bearing and every
      -- archivable table was credited with protection it did not have on the path being measured.
      -- Thirteen tables were credited that way; twelve of them had no INSERT-path check at all.
      and not exists (
        select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
         where t.tgrelid = c.oid and not t.tgisinternal and (t.tgtype & 4) <> 0
           and pg_get_functiondef(p.oid) ~
               '(app\.authorize|app\.has_permission|app\.require_lead_handler)')),
  '<=', 19,
  '...and at most 19 of them have NO capability trigger that FIRES ON INSERT -- 18 + user_permission_grants (RBAC-3), whose capability check is in its RLS policies like user_role_assignments, not a trigger');

-- SEC-1b, 2026-08-29 -- READ THE NUMBERS CAREFULLY. The middle ceiling ROSE from 17 to 18 while the
-- exposure FELL. Both are the same correction: the detectors now require the trigger to fire ON
-- INSERT, which stopped crediting UPDATE-only guards. Under the corrected predicate the residue was
-- 15, not 3 -- twelve ordinary business tables (bookings, complaints, conversations, customer_notes,
-- customers, documents, leads, passengers, quotations, service_requests, suppliers, tasks) had no
-- capability check on their INSERT path, and a `trainee` holding NO write permission was proven to
-- insert a complaint and a conversation by direct DML in the same transaction that
-- `app.create_complaint` refused them. `202607057000` guards all twelve, returning the residue to 3.
--
-- The residue that matters: neither a capability trigger NOR a policy WITH CHECK naming a real
-- write permission. Thirteen tables when this was first measured; FOUR now, and each of the three
-- groups was closed by a different action rather than by one sweeping rule (`202607056100`):
--
--   * `attribution_clicks`, `notifications`, `notification_deliveries`,
--     `offline_conversion_deliveries`, `usage_counters` -- every writer is SECURITY DEFINER and none
--     is executable by `authenticated`, so the GRANT was revoked. They leave this count by leaving
--     the population above it: authenticated can no longer INSERT them at all.
--   * `branch_business_hours`, `holidays`, `financial_accounts`, `company_assets` -- no RPC writes
--     them, so the permission was read out of what ORVION already charges for the same object
--     (`branches` -> MANAGE_BRANCHES; `chart_of_accounts`/`journal_entries` -> CREATE_JOURNAL_ENTRY).
--
-- What remains is FOUR, and three of them are INTENTIONAL rather than residue: `otp_challenges`,
-- `totp_enrollments` and `trusted_devices` belong to the Human Identity, and canon 34 states that
-- row-ownership by `auth.uid()` IS their authorization model -- `58_...` proves that boundary holds
-- instead of asserting it. The genuine open item is `lead_interactions`, where
-- `app.record_lead_interaction` (SECURITY INVOKER, granted to authenticated) authorizes nothing:
-- there is no bypass to close, only an undecided question about what logging an interaction costs.
select cmp_ok(
  (select count(*)::int
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and has_table_privilege('authenticated', c.oid, 'INSERT')
      and not exists (
        select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
         where t.tgrelid = c.oid and not t.tgisinternal and (t.tgtype & 4) <> 0
           and pg_get_functiondef(p.oid) ~
               '(app\.authorize|app\.has_permission|app\.require_lead_handler)')
      and not exists (
        select 1 from pg_policies pp
         where pp.schemaname = 'public' and pp.tablename = c.relname
           and pp.cmd in ('INSERT','ALL')
           and coalesce(pp.with_check,'') ~ 'has_permission\(''(?!VIEW_|SEE_)[A-Z_]+''')),
  '<=', 3,
  '...and at most 3 have no capability enforcement of ANY kind -- all three INTENTIONAL by canon 34');

select * from finish();
rollback;
