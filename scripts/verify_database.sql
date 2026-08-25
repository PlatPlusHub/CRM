\set ON_ERROR_STOP on
-- ORVION database verification smoke-test
-- Plan reference: 33_sql_migration_plan.md migration 20 (database verification)
-- Executable assertions over the completed database foundation (migrations 1-19). Run against a
-- freshly reset database: raises an exception on the first broken invariant, otherwise prints
-- "ALL CHECKS PASSED". CI-able: a non-zero exit signals a regression.
--   docker exec -i <db> psql -U postgres -d postgres -f - < scripts/verify_database.sql
-- Expected values track the frozen baseline: 72 public base tables, 68 catalog types, 583 catalog
-- values (565 + 4 refund lifecycle events registered by 202607049800, audit 2026-08-10; + 14
-- related_entity_type values seeded by 202607050700 / SPEC-130, which also added the 68th type). Documented referential exceptions to the restrict default (30 Referential Action Standard):
-- users.auth_user_id -> auth.users ON DELETE SET NULL (ADR-0011); trusted_devices / otp_challenges /
-- totp_enrollments -> auth.users ON DELETE CASCADE (ADR-0012).

do $$
declare
    n int;
    bad text;
begin
    -- 1. Required extensions
    select count(*) into n from pg_extension where extname in ('pgcrypto', 'moddatetime');
    if n <> 2 then raise exception 'CHECK 1 FAILED: expected pgcrypto + moddatetime, found %', n; end if;

    -- 2. Public base table count
    select count(*) into n from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
        where ns.nspname = 'public' and c.relkind = 'r';
    if n <> 72 then raise exception 'CHECK 2 FAILED: expected 72 public tables, found %', n; end if;

    -- 3. RLS enabled on every public base table
    select count(*) into n from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
        where ns.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;
    if n <> 0 then raise exception 'CHECK 3 FAILED: % public tables without RLS enabled', n; end if;

    -- 4. No RLS-enabled table left without any policy (would be fully locked)
    select string_agg(c.relname, ', ') into bad
        from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
        where ns.nspname = 'public' and c.relkind = 'r' and c.relrowsecurity
          and c.relname not in ('integration_cursors')  -- intentionally policy-less: locked to SECURITY DEFINER paths (mig 049300)
          and not exists (select 1 from pg_policies p where p.schemaname = 'public' and p.tablename = c.relname);
    if bad is not null then raise exception 'CHECK 4 FAILED: RLS tables with no policy: %', bad; end if;

    -- 5. Resolution primitives exist in the non-API app schema (canon 35 principle 4: every policy
    --    calls a primitive, so the mechanism evolves in one place).
    select count(*) into n from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
        where ns.nspname = 'app' and p.proname = 'current_tenant_id';
    if n <> 1 then raise exception 'CHECK 5 FAILED: app.current_tenant_id() not found (%)', n; end if;
    select count(distinct p.proname) into n from pg_proc p join pg_namespace ns on ns.oid = p.pronamespace
        where ns.nspname = 'app' and p.proname in
              ('current_user_id','has_tenant_wide_read','visible_branch_ids','visible_department_ids','current_placement');
    if n <> 5 then raise exception 'CHECK 5b FAILED: expected 5 read-scope primitives, found %', n; end if;

    -- 5c. The read-scope model is actually attached. A scope-bearing table that fell back to a bare
    --     tenant predicate would still pass every other check here while silently exposing every
    --     branch to every employee, so the policy NAME is asserted per table rather than counted.
    select count(*) into n from pg_policies
        where schemaname = 'public' and policyname = 'scope_isolation'
          and tablename in ('leads','bookings','booking_items','tasks','conversations','complaints',
                            'service_requests','quotations','conversation_messages','quotation_items',
                            'booking_item_passengers','lead_interactions','lead_assignments','invoices',
                            'payments','refunds','receipts','payment_allocations','notifications',
                            'notification_deliveries','customer_notes');
    if n <> 21 then raise exception 'CHECK 5c FAILED: expected 21 scope_isolation policies, found %', n; end if;

    -- 5d. Identity and organization tables must not be writable on the strength of tenancy alone --
    --     that was the path by which any employee could grant themselves the owner role.
    select count(*) into n from pg_policies
        where schemaname = 'public' and policyname = 'scope_insert'
          and tablename in ('user_role_assignments','user_branch_assignments','users','branches',
                            'departments','subscriptions','tenants');
    if n <> 7 then raise exception 'CHECK 5d FAILED: expected 7 permission-gated write policies, found %', n; end if;

    -- 5e. Employee financial privacy: the two margin columns must NOT be reachable through a
    --     table-level grant. A table-level SELECT covers every column including ones added later,
    --     so re-granting the table would silently re-expose one employee's commission to another.
    select count(*) into n from information_schema.role_column_grants
        where grantee = 'authenticated' and table_schema = 'public' and table_name = 'booking_items'
          and column_name in ('cost_amount', 'commission_rate') and privilege_type = 'SELECT';
    if n <> 0 then raise exception 'CHECK 5e FAILED: authenticated can read % margin column(s) on booking_items directly', n; end if;
    select count(*) into n from information_schema.role_table_grants
        where grantee = 'authenticated' and table_schema = 'public' and table_name = 'booking_items'
          and privilege_type = 'SELECT';
    if n <> 0 then raise exception 'CHECK 5e FAILED: booking_items carries a table-level SELECT grant, which overrides the column list'; end if;

    -- 5f. Assignment-history integrity (canon 04: "No assignment history may be deleted"). Both
    --     triggers are asserted by name: without the guard on `leads`, a direct UPDATE silently
    --     erases the first employee, which is the exact defect SPEC-140 closed.
    select count(*) into n from pg_trigger
        where tgname in ('lead_assignments_immutable', 'leads_require_assignment_history',
                         'customers_freeze_first_registration');
    if n <> 3 then raise exception 'CHECK 5f FAILED: expected 3 assignment/first-registration triggers, found %', n; end if;

    -- 5g. Lifecycle transition enforcement (SPEC-149). Asserted per table by trigger name: without
    --     these, `update bookings set booking_status_code = 'issued'` skips the state machine, the
    --     authorization and the events entirely, which is what the guard was built to stop.
    select count(*) into n from pg_trigger where tgname like '%_enforce_status_transition' and not tgisinternal;
    if n <> 10 then raise exception 'CHECK 5g FAILED: expected 10 status-transition triggers, found %', n; end if;
    select count(*) into n from app.status_transitions;
    if n < 100 then raise exception 'CHECK 5g FAILED: transition registry holds only % rows', n; end if;

    -- 6. System catalog seed present
    select count(*) into n from catalog_types;
    if n <> 68 then raise exception 'CHECK 6a FAILED: expected 68 catalog_types, found %', n; end if;
    select count(*) into n from catalog_values;
    if n <> 583 then raise exception 'CHECK 6b FAILED: expected 583 catalog_values, found %', n; end if;

    -- 7. Referential Action Standard: every public FK is restrict/no-action, except the documented
    --    exceptions (users.auth_user_id set null; 3 auth-support cascades to auth.users).
    select count(*) into n
        from pg_constraint c
        join pg_class t on t.oid = c.conrelid
        join pg_namespace ns on ns.oid = t.relnamespace
        where c.contype = 'f' and ns.nspname = 'public' and (
            c.confupdtype <> 'a'
            or not (
                c.confdeltype = 'r'
                or (c.confdeltype = 'c' and c.confrelid = 'auth.users'::regclass)
                or (c.confdeltype = 'n' and c.conname = 'users_auth_user_id_fkey')
            )
        );
    if n <> 0 then raise exception 'CHECK 7 FAILED: % public FK(s) deviate from the Referential Action Standard', n; end if;

    -- 8. Every table carrying updated_at has a maintenance trigger
    select string_agg(c.relname, ', ') into bad
        from pg_class c join pg_namespace ns on ns.oid = c.relnamespace
        where ns.nspname = 'public' and c.relkind = 'r'
          and exists (select 1 from pg_attribute a where a.attrelid = c.oid and a.attname = 'updated_at' and not a.attisdropped)
          and not exists (select 1 from pg_trigger tg where tg.tgrelid = c.oid and not tg.tgisinternal);
    if bad is not null then raise exception 'CHECK 8 FAILED: updated_at tables without a trigger: %', bad; end if;

    -- 9. Append-only immutability triggers on the audit tables
    select count(*) into n from pg_trigger where tgname in ('events_append_only', 'security_events_append_only');
    if n <> 2 then raise exception 'CHECK 9 FAILED: expected 2 append-only triggers, found %', n; end if;

    -- 10. Within ORVION's own schemas (app/public/reporting — never Supabase's platform-internal
    --     schemas such as realtime/storage/auth, which ORVION does not own and did not grant), no
    --     role holds function EXECUTE without schema USAGE (an unusable, silently-broken grant).
    --     Guards the exact defect class found 2026-08-15: orvion_integration had EXECUTE on 4
    --     app-schema RPCs but no USAGE on app itself, discovered only by an actual RPC call
    --     failing with "permission denied for schema app" — the function-level grant alone gave
    --     no warning. Generalized beyond that one role/schema so any future integration role hits
    --     this at db-reset time, not at first live call (SPEC-122).
    select string_agg(distinct pg_get_userbyid(g.grantee) || ' missing USAGE on schema ' || ns.nspname, ', ') into bad
        from pg_proc p
        join pg_namespace ns on ns.oid = p.pronamespace
        cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) as g(grantor, grantee, privilege_type, is_grantable)
        where g.privilege_type = 'EXECUTE'
          and g.grantee <> 0  -- 0 = PUBLIC pseudo-grantee; schema USAGE is checked per named role only
          and ns.nspname in ('app', 'public', 'reporting')
          and not has_schema_privilege(g.grantee, ns.oid, 'USAGE');
    if bad is not null then raise exception 'CHECK 10 FAILED: role(s) hold function EXECUTE without schema USAGE (unusable grant): %', bad; end if;

    raise notice 'ALL CHECKS PASSED (72 tables, RLS + policies, resolver + read-scope model, 68/583 catalog, FK standard, updated_at triggers, append-only audit, grant/schema-usage completeness)';
end
$$;
