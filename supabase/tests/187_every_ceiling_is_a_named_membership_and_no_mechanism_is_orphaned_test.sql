-- pgTAP: Batch 6 exit -- every ceiling is a named membership, and no mechanism is orphaned, duplicated or switched off.
--
-- Catalog-driven, like `186_every_permission_is_enforced_and_every_table_states_its_isolation_basis_test.sql`: every
-- assertion reads the live catalog, so a new event code, table, trigger, policy, index or function is judged the moment
-- it exists.
--
-- EC-7: four suite ceilings were numeric bounds with slack, so a population could grow silently until it met
--   the bound. Measured at `23be9e2` (277 migrations), and identically on Platinum Primary, each population is pinned
--   here by name; the numeric bounds in Tests 07 and 10 stay and this test is their exact membership:
--     Test 07 `<= 42`  -- 39 `event_type` codes named by no `app` function and no trigger (reserved vocabulary);
--     Test 10 `<= 56`  -- 52 `public` tables `authenticated` may INSERT into;
--     Test 10 `<= 20`  -- 5 of them with no capability-checking INSERT trigger;
--     Test 10 `<= 3`   -- 2 of those with no capability-naming INSERT policy either (the identity tables, whose
--                         policies name `auth.uid()` -- Test 186 basis IDENTITY).
--   A new member fails its set equality; removing one must remove it here, so each ceiling can only shrink.
--
-- EC-11: the per-surface sweep for orphaned, duplicate and superseded mechanisms over `public`, `app` and `reporting`:
--   no disabled trigger, no duplicate trigger, index or policy, no invalid index, no unvalidated constraint, no
--   unowned sequence, and exactly one function reachable from nothing at runtime:
--     app.document_retention_days(uuid,text) -- superseded by RET-1's `document_retention_policies`, which the scan and
--       claim paths join directly; kept as the tested per-tenant lookup (Test 97), executable by no client role.
--       Trigger: remove it when RET-1's owner decision retires the lookup, or a caller appears (then it leaves this set).
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

create temporary view t187_insertable as
select c.oid, c.relname::text as tbl
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r' and has_table_privilege('authenticated', c.oid, 'INSERT');

create temporary view t187_no_trigger as
select i.* from t187_insertable i
 where not exists (select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
                    where t.tgrelid = i.oid and not t.tgisinternal and (t.tgtype & 4) <> 0
                      and pg_get_functiondef(p.oid) ~ '(app\.authorize|app\.has_permission|app\.require_lead_handler)');

create temporary view t187_no_capability as
select nt.* from t187_no_trigger nt
 where not exists (select 1 from pg_policies pp
                    where pp.schemaname = 'public' and pp.tablename = nt.tbl and pp.cmd in ('INSERT','ALL')
                      and coalesce(pp.with_check,'') ~ 'has_permission\(''(?!VIEW_|SEE_)[A-Z_]+''');

create temporary view t187_unused_event as
with fsrc as (
  select coalesce(string_agg(pg_get_functiondef(p.oid), E'\n'),'') as s
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace where n.nspname = 'app'),
tsrc as (
  select coalesce(string_agg(pg_get_triggerdef(t.oid), E'\n'),'') as s from pg_trigger t where not t.tgisinternal)
select cv.code::text as code
  from public.catalog_values cv, fsrc, tsrc
 where cv.catalog_type_code = 'event_type' and position(cv.code in fsrc.s) = 0 and position(cv.code in tsrc.s) = 0;

create temporary view t187_scope as
select c.oid, c.relname, n.nspname
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname in ('public','app','reporting');

-- 1. Test 07 ceiling as membership: the reserved event vocabulary.
select set_eq(
  'select code from t187_unused_event',
  $$values ('account_locked'),('approval_resubmitted'),('booking_item_cost_entered'),('booking_item_cost_locked'),
           ('booking_item_locked_cost_edited'),('booking_item_sub_status_changed'),('booking_item_supplier_assigned'),
           ('company_asset_created'),('customer_cross_branch_activity_detected'),('customer_identity_match_found'),
           ('document_expiry_warning'),('exchange_rate_adjustment_created'),('finance_approval_resubmitted'),
           ('financial_account_created'),('lead_reopened'),('login_attempt'),('login_failure'),('login_success'),
           ('notification_created'),('notification_failed'),('notification_read'),('notification_sent'),
           ('offline_conversion_retried'),('offline_conversion_send_attempted'),('otp_expired'),('otp_failed'),
           ('otp_requested'),('otp_verified'),('passenger_document_added'),('passenger_passport_expiry_warning'),
           ('password_changed'),('password_reset'),('supplier_assigned_to_booking_item'),('task_overdue'),
           ('totp_challenge_failure'),('totp_challenge_success'),('totp_enrolled'),('trusted_device_expired'),
           ('user_branch_transfer_started')$$,
  'EC-7: the 39 event codes no function or trigger emits are exactly the reserved vocabulary (Test 07 <= 42)'
);

-- 2. Test 10 ceiling as membership: the tables a member may INSERT into.
select set_eq(
  'select tbl from t187_insertable',
  $$values ('approval_requests'),('booking_item_passengers'),('booking_items'),('bookings'),('branch_business_hours'),
           ('branches'),('campaign_daily_metrics'),('catalog_values'),('chart_of_accounts'),('company_assets'),
           ('complaints'),('conversation_messages'),('conversations'),('customer_contact_methods'),
           ('customer_identity_signals'),('customer_notes'),('customers'),('departments'),('document_links'),
           ('document_retention_policies'),('document_versions'),('documents'),('exchange_rate_adjustments'),
           ('exchange_rates'),('financial_accounts'),('holidays'),('internal_supplier_links'),('invoices'),
           ('lead_assignments'),('lead_interactions'),('leads'),('marketing_campaigns'),('offline_conversions'),
           ('passengers'),('payment_allocations'),('payments'),('quotation_items'),('quotations'),('receipts'),
           ('refunds'),('service_requests'),('subscription_payment_proofs'),('subscriptions'),('suppliers'),('tasks'),
           ('tenants'),('totp_enrollments'),('trusted_devices'),('user_branch_assignments'),('user_permission_grants'),
           ('user_role_assignments'),('users')$$,
  'EC-7: the 52 member-insertable tables are named (Test 10 <= 56)'
);

-- 3. Test 10 ceiling as membership: insertable with no capability-checking INSERT trigger.
select set_eq(
  'select tbl from t187_no_trigger',
  $$values ('subscription_payment_proofs'),('subscriptions'),('tenants'),('totp_enrollments'),('trusted_devices')$$,
  'EC-7: the 5 insertable tables without a capability trigger are named (Test 10 <= 20)'
);

-- 4. Test 10 ceiling as membership: no capability trigger and no capability policy.
select set_eq(
  'select tbl from t187_no_capability',
  $$values ('totp_enrollments'),('trusted_devices')$$,
  'EC-7: only the 2 identity tables carry no INSERT capability of any kind (Test 10 <= 3)'
);

-- 5. No trigger is switched off.
select is_empty(
  $$select t.tgname from pg_trigger t join t187_scope s on s.oid = t.tgrelid
     where not t.tgisinternal and t.tgenabled = 'D'$$,
  'EC-11: no trigger in public, app or reporting is disabled'
);

-- 6. No trigger is defined twice (same table, function, timing/events, arguments and condition).
select is_empty(
  $$select t.tgrelid::regclass::text
      from pg_trigger t join t187_scope s on s.oid = t.tgrelid
     where not t.tgisinternal
     group by t.tgrelid, regexp_replace(pg_get_triggerdef(t.oid), '^CREATE (CONSTRAINT )?TRIGGER \S+ ', '')
    having count(*) > 1$$,
  'EC-11: no duplicate trigger'
);

-- 7. No index is defined twice.
select is_empty(
  $$select i.indrelid::regclass::text
      from pg_index i join t187_scope s on s.oid = i.indrelid
     group by i.indrelid, i.indkey::text, i.indclass::text, i.indisunique,
              coalesce(pg_get_expr(i.indexprs, i.indrelid),''), coalesce(pg_get_expr(i.indpred, i.indrelid),'')
    having count(*) > 1$$,
  'EC-11: no duplicate index'
);

-- 8. No policy is defined twice.
select is_empty(
  $$select tablename::text from pg_policies
     where schemaname in ('public','app','reporting')
     group by schemaname, tablename, permissive, cmd, roles::text, coalesce(qual,''), coalesce(with_check,'')
    having count(*) > 1$$,
  'EC-11: no duplicate policy'
);

-- 9. No index is left invalid and no constraint unvalidated.
select is_empty(
  $$select i.indexrelid::regclass::text from pg_index i join t187_scope s on s.oid = i.indrelid where not i.indisvalid$$,
  'EC-11: no invalid index'
);

select is_empty(
  $$select c.conname::text from pg_constraint c join pg_namespace n on n.oid = c.connamespace
     where not c.convalidated and n.nspname in ('public','app','reporting')$$,
  'EC-11: no unvalidated constraint'
);

-- 10. No sequence outlives its column.
select is_empty(
  $$select s.relname::text from t187_scope s join pg_class c on c.oid = s.oid
     where c.relkind = 'S' and not exists (select 1 from pg_depend d where d.objid = s.oid and d.deptype in ('a','i'))$$,
  'EC-11: no unowned sequence'
);

-- 11. Exactly one function is reachable from nothing at runtime: no trigger, function, policy, view or cron job names
--     it, and no client role may execute it.
select set_eq(
  $$select p.oid::regprocedure::text
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname in ('public','app','reporting')
       and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
       and not exists (select 1 from pg_trigger t where t.tgfoid = p.oid)
       and not exists (select 1 from pg_proc q where q.oid <> p.oid and q.prosrc ilike '%' || p.proname || '%')
       and not exists (select 1 from pg_policies pp
                        where coalesce(pp.qual,'') || coalesce(pp.with_check,'') ilike '%' || p.proname || '%')
       and not exists (select 1 from pg_views v where v.definition ilike '%' || p.proname || '%')
       and not exists (select 1 from cron.job j where j.command ilike '%' || p.proname || '%')
       and not has_function_privilege('anon', p.oid, 'EXECUTE')
       and not has_function_privilege('authenticated', p.oid, 'EXECUTE')
       and not has_function_privilege('service_role', p.oid, 'EXECUTE')
       and not has_function_privilege('orvion_integration', p.oid, 'EXECUTE')$$,
  $$values ('app.document_retention_days(uuid,text)')$$,
  'EC-11: the only runtime-unreachable function is the superseded RET-1 lookup'
);

select * from finish();
rollback;
