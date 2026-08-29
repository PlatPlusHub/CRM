-- ORVION -- the STRUCTURAL surface hash, for comparing local against Primary.
--
-- PAR-3 (2026-08-30). `check_database_parity.ps1` compared the migration ledger and the FUNCTION
-- surface, and nothing else. Reproduced on local against a clean reset: dropping
-- `payment_allocations_within_invoice_total` -- FIN-10's financial ceiling, a High-severity fix
-- shipped the day before -- left every gate reporting success:
--
--     check_repository_consistency.ps1  REPOSITORY CONSISTENCY: CLEAN   exit 0
--     check_database_parity.ps1         DATABASE PARITY: CLEAN          exit 0
--     MASTER_API_CONTRACT.md            "matches the live surface"
--     scripts/verify_database.sql       ALL CHECKS PASSED (75 tables)
--     supabase/tests/72_*.sql           FAILED 2 of 16      <-- the only layer that noticed
--
-- The one layer with the sensitivity runs against LOCAL only; pgTAP is never run against Primary.
-- So the sole bridge to Primary was comparing 233 objects out of roughly 3,265, and could not have
-- seen a missing trigger, a widened grant, a rewritten RLS policy, a dropped constraint or a deleted
-- status-transition row -- which is to say, it could not see the deliverable of the last four
-- packages, every one of which shipped a TRIGGER.
--
-- WHY ONE SHARED FILE RATHER THAN A QUERY IN THE POWERSHELL AND ANOTHER PASTED AT PRIMARY: PAR-1a.
-- The comment-stripping pattern below must be built with `chr(10)`; written as '--[^\n]*' it means
-- "not a backslash and not the letter n", stops at the first `n` in a comment, and lets two databases
-- that genuinely differ hash identically. Two hand-copied variants of this SQL is exactly how that
-- happens again, so BOTH SIDES RUN THIS FILE. Local via psql; Primary via the supabase-primary MCP.
--
-- Output: one row per surface (key | hash | count), then `_combined` -- the value the guard compares.
-- A per-surface breakdown is printed either way, so a mismatch says WHICH surface drifted rather
-- than only that something did.
--
-- Scope note, deliberately stated: this hashes STRUCTURE plus `app.status_transitions`, which is
-- behaviour-bearing seed data read by `app.enforce_status_transition` at runtime. It does not hash
-- tenant data, and must not -- Primary carries real rows that local never will.

with
fn as (select md5(string_agg(h, ',' order by h)) x, count(*) n from (
  select md5(n.nspname || '.' || p.proname || '|' ||
             regexp_replace(regexp_replace(pg_get_functiondef(p.oid),
               '--[^' || chr(10) || ']*', '', 'g'), '\s+', ' ', 'g')) h
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname in ('app','public','reporting') and p.prokind = 'f') t),

-- Triggers: the object type every recent package shipped. `pg_get_triggerdef` carries the table,
-- timing, events, WHEN clause and function; the three flags carry deferrability and whether the
-- trigger is enabled -- a trigger disabled with ALTER TABLE ... DISABLE TRIGGER still has an
-- identical definition, so tgenabled is part of the identity, not decoration.
tg as (select md5(string_agg(h, ',' order by h)) x, count(*) n from (
  select md5(regexp_replace(pg_get_triggerdef(t.oid), '\s+', ' ', 'g') || '|' ||
             t.tgenabled::text || '|' || t.tgdeferrable::text || '|' || t.tginitdeferred::text) h
  from pg_trigger t
  join pg_class c on c.oid = t.tgrelid
  join pg_namespace n on n.oid = c.relnamespace
  where not t.tgisinternal and n.nspname in ('public','app')) t),

-- Policies: the security boundary itself. `roles` is included because a policy granted to a
-- different role is a different policy, and SEC-3 was a WITH CHECK that named the wrong thing.
pol as (select md5(string_agg(h, ',' order by h)) x, count(*) n from (
  select md5(schemaname || '.' || tablename || '.' || policyname || '|' || cmd || '|' ||
             coalesce(array_to_string(roles, ','), '') || '|' ||
             coalesce(regexp_replace(qual, '\s+', ' ', 'g'), '~') || '|' ||
             coalesce(regexp_replace(with_check, '\s+', ' ', 'g'), '~')) h
  from pg_policies where schemaname in ('public','app')) t),

-- RLS ENABLEMENT, and it is NOT the same fact as the policies above -- found by attacking this very
-- file. `pg_policies` lists a policy whether or not row security is on, so `ALTER TABLE public.invoices
-- DISABLE ROW LEVEL SECURITY` removes the entire tenant boundary while leaving the policy hash
-- byte-identical: verified, the combined hash did not move at all. `verify_database.sql` CHECK 3 does
-- catch it -- but that runs against LOCAL, which is precisely the reason this file exists, so the flag
-- is compared here too. `relforcerowsecurity` matters separately: without it a table owner bypasses
-- every policy.
rls as (select md5(string_agg(h, ',' order by h)) x, count(*) n from (
  select md5(n.nspname || '.' || c.relname || '|' ||
             c.relrowsecurity::text || '|' || c.relforcerowsecurity::text) h
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
  where c.relkind = 'r' and n.nspname in ('public','app')) t),

con as (select md5(string_agg(h, ',' order by h)) x, count(*) n from (
  select md5(n.nspname || '.' || cl.relname || '.' || c.conname || '|' ||
             regexp_replace(pg_get_constraintdef(c.oid), '\s+', ' ', 'g')) h
  from pg_constraint c
  join pg_class cl on cl.oid = c.conrelid
  join pg_namespace n on n.oid = cl.relnamespace
  where n.nspname in ('public','app')) t),

-- Grants: SEC-1's entire model is "which table can `authenticated` write". A widened grant is a
-- silent privilege escalation that no function hash can see.
gr as (select md5(string_agg(h, ',' order by h)) x, count(*) n from (
  select md5(grantee || '|' || table_schema || '.' || table_name || '|' || privilege_type) h
  from information_schema.role_table_grants
  where table_schema in ('public','app','reporting')
    and grantee in ('authenticated','anon','service_role')) t),

-- `ordinal_position` is in the hash on purpose. CUST-1 was a consumer that read the FIRST column of
-- a key and silently became a no-op when TENANT-1 made those keys composite; position IS meaning to
-- anything that derives behaviour from the catalog, so two databases whose columns differ only in
-- order are not the same database.
col as (select md5(string_agg(h, ',' order by h)) x, count(*) n from (
  select md5(table_schema || '.' || table_name || '.' || column_name || '|' || data_type || '|' ||
             is_nullable || '|' || coalesce(column_default, '~') || '|' || ordinal_position::text) h
  from information_schema.columns
  where table_schema in ('public','app','reporting')) t),

-- Views: `prokind = 'f'` excludes these entirely, and all eight Phase 9 reporting outputs are views.
vw as (select md5(string_agg(h, ',' order by h)) x, count(*) n from (
  select md5(schemaname || '.' || viewname || '|' ||
             regexp_replace(definition, '\s+', ' ', 'g')) h
  from pg_views where schemaname in ('public','app','reporting')) t),

ix as (select md5(string_agg(h, ',' order by h)) x, count(*) n from (
  select md5(schemaname || '.' || indexname || '|' ||
             regexp_replace(indexdef, '\s+', ' ', 'g')) h
  from pg_indexes where schemaname in ('public','app','reporting')) t),

-- Seed data that IS behaviour: `app.enforce_status_transition` reads this table at runtime, so a
-- deleted row silently removes a legal transition and an added row silently legalises one.
-- DOC-LC-1 shipped two rows here and nothing else would have compared them.
st as (select md5(string_agg(h, ',' order by h)) x, count(*) n from (
  select md5(table_name || '|' || status_column || '|' || from_status || '|' || to_status || '|' ||
             coalesce(permission_key, '~')) h
  from app.status_transitions) t),

s as (
  select 1 o, 'functions'          k, x, n from fn  union all
  select 2, 'triggers',              x, n from tg  union all
  select 3, 'policies',              x, n from pol union all
  select 4, 'constraints',           x, n from con union all
  select 10, 'rls_enabled',          x, n from rls union all
  select 5, 'grants',                x, n from gr  union all
  select 6, 'columns',               x, n from col union all
  select 7, 'views',                 x, n from vw  union all
  select 8, 'indexes',               x, n from ix  union all
  select 9, 'status_transitions',    x, n from st
)
select k, x, n from (
  select o, k, x, n from s
  union all
  -- The combined value the guard compares. Computed HERE so both sides derive it the same way; a
  -- caller that concatenated the rows itself would be reimplementing the comparison, which is the
  -- PAR-1a mistake one layer up.
  select 99, '_combined',
         md5(string_agg(k || '=' || x || ':' || n, ';' order by o)),
         sum(n)::bigint
  from s
) z order by o;
