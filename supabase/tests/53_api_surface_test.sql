-- pgTAP: API-1 -- the exposed surface is exactly what was classified, and nothing else.
--
-- THIS FILE IS THE GUARD THE OWNER DIRECTIVE ASKED FOR: "add a permanent guard preventing
-- accidental exposure of internal `app.*` helpers". It pins the exposed set BY NAME. Adding an
-- endpoint requires deliberately editing the list below, which is the point -- accidental exposure
-- becomes a failing test rather than a silent publication.
--
-- Assertions 4-6 matter most. ORVION grants many internal helpers to `authenticated` because its
-- own SECURITY INVOKER functions call them on the caller's behalf -- `record_event` above all,
-- which WP-00 made the audit spine's sole writer. If `record_event` ever gained a public wrapper,
-- any authenticated user could mint arbitrary registered event types about arbitrary entities in
-- their own tenant: audit forgery through the front door. That is why the exclusions are asserted
-- explicitly rather than left as an absence.
--
-- What this file cannot prove is HTTP reachability -- pgTAP never opens a socket, which is exactly
-- how API-1 stayed invisible for the whole programme. `scripts/verify_api_end_to_end.ps1` proves
-- that over the real door.
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

create temporary table _expected_endpoints (name text primary key) on commit drop;
insert into _expected_endpoints (name) values
    ('activate_membership'),
    ('add_customer_contact_method'),
    ('add_customer_note'),
    ('add_document_version'),
    ('add_quotation_item'),
    ('advance_booking'),
    ('advance_booking_item'),
    ('advance_complaint'),
    ('advance_conversation'),
    ('advance_lead'),
    ('advance_marketing_campaign'),
    ('advance_quotation'),
    ('advance_refund'),
    ('advance_service_request'),
    ('advance_task'),
    ('archive_document'),
    ('assign_lead'),
    ('assign_lead_round_robin'),
    ('assign_task'),
    ('assign_user_branch'),
    ('assign_user_role'),
    ('claim_storage_actions'),
    ('convert_lead'),
    ('create_booking'),
    ('create_booking_item'),
    ('create_branch'),
    ('create_complaint'),
    ('create_customer'),
    ('create_department'),
    ('create_invoice'),
    ('create_journal_entry'),
    ('create_lead'),
    ('create_marketing_campaign'),
    ('create_passenger'),
    ('create_quotation'),
    ('create_service_request'),
    ('create_supplier'),
    ('create_task'),
    ('create_tenant_user'),
    ('current_placement'),
    ('customer_timeline'),
    ('expiring_documents'),
    ('financial_documents'),
    ('find_customer_duplicates'),
    ('issue_invoice'),
    ('issue_receipt'),
    ('lead_booking_readiness'),
    ('lead_origin'),
    ('lead_timeline'),
    ('link_internal_supplier'),
    ('link_passenger_to_booking_item'),
    ('merge_customer_identity'),
    ('my_memberships'),
    ('my_trusted_devices'),
    ('reassign_lead'),
    ('record_lead_interaction'),
    ('record_offline_conversion'),
    ('record_payment'),
    ('record_refund'),
    ('record_supplier_payment'),
    ('record_trusted_device'),
    ('redeem_license_token'),
    ('request_finance_approval'),
    ('resolve_storage_finding'),
    -- SCHED-1: platform-only, service_role alone. How far behind the storage executor is must not
    -- be probeable by a tenant, let alone anonymously.
    ('storage_action_backlog'),
    ('review_finance_approval'),
    ('revoke_trusted_device'),
    ('revoke_user_role'),
    ('seed_default_chart_of_accounts'),
    ('send_conversation_message'),
    ('start_conversation'),
    ('tenant_capabilities'),
    ('upload_document'),
    ('upload_subscription_payment_proof');

-- =============================================================================================
-- 1-3. THE EXPOSED SET IS EXACTLY THE CLASSIFIED SET.
-- =============================================================================================
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
      and not exists (select 1 from _expected_endpoints e where e.name = p.proname)),
  0,
  'no public function exists that is NOT on the classified endpoint list');

select is(
  (select count(*)::int from _expected_endpoints e
    where not exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                       where n.nspname = 'public' and p.prokind = 'f' and p.proname = e.name)),
  0,
  '...and every classified endpoint actually exists');

select is(
  (select count(*)::int from _expected_endpoints),
  74,
  'POSITIVE CONTROL: 74 endpoints are pinned, so the two zeros above are not drawn from an empty set');

-- =============================================================================================
-- 4-6. THE EXCLUSIONS. Named explicitly, because an absence proves nothing on its own.
-- =============================================================================================
select is(
  (select count(*)::int from (values
      ('authorize'),('record_event'),('mfa_satisfied'),('requires_mfa'),
      ('normalize_email'),('normalize_phone'),('plan_allows'),('plan_limit'),
      ('sub_status_family'),('subscription_allows_write'),('subscription_transition_allowed'),
      ('commission_rate_default'),('document_bucket'),('document_storage_path'),
      ('is_my_booking_item')) as h(name)
    where exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                   where n.nspname = 'public' and p.proname = h.name)),
  0,
  'NO internal helper is exposed -- above all record_event, the audit spine''s only writer');

select is(
  (select count(*)::int from (values
      ('current_tenant_id'),('current_user_id'),('has_permission'),('has_tenant_wide_read'),
      ('is_financial_document_type'),('visible_branch_ids'),('visible_department_ids'),
      ('item_financials'),('customer_balance'),('supplier_balance')) as h(name)
    where exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
                   where n.nspname = 'public' and p.prokind = 'f' and p.proname = h.name)),
  0,
  '...nor any RLS or reporting-view helper -- they would be a permission-probing oracle');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f' and p.proname like 'platform\_%'),
  0,
  '...nor any platform_* function -- platform authority is never a tenant endpoint');

-- =============================================================================================
-- 7-9. THE GRANT MODEL ON THE SURFACE ITSELF.
-- =============================================================================================
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
      and has_function_privilege('anon', p.oid, 'EXECUTE')),
  0,
  'anon can execute NO endpoint -- ORVION has no anonymous flow');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f' and p.prosecdef
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')),
  0,
  'NO endpoint is SECURITY DEFINER -- that would bridge the caller into the private schema');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.prokind = 'f'
      and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e')
      and not exists (select 1 from unnest(coalesce(p.proconfig,'{}')) c where c like 'search_path=%')),
  0,
  '...and every endpoint pins search_path');

-- =============================================================================================
-- 10-11. THE REPORTING VIEWS. `security_invoker` is the whole tenant-isolation property: without
--        it a view runs as its owner and every report becomes a cross-tenant read.
-- =============================================================================================
select is(
  (select count(*)::int from (values ('booking_item_profit'), ('booking_pipeline'), ('customer_outstanding'), ('lead_performance'), ('my_sales_performance'), ('sales_activity'), ('subscription_state'), ('supplier_outstanding')) as v(name)
    where coalesce((select o.option_value from pg_class c join pg_namespace n on n.oid = c.relnamespace
                      cross join lateral pg_options_to_table(c.reloptions) o
                     where n.nspname='public' and c.relname = v.name and o.option_name='security_invoker'),
                   'false') <> 'true'),
  0,
  'every exposed reporting view is security_invoker, so RLS still filters as the caller');

select is(
  (select count(*)::int from (values ('booking_item_profit'), ('booking_pipeline'), ('customer_outstanding'), ('lead_performance'), ('my_sales_performance'), ('sales_activity'), ('subscription_state'), ('supplier_outstanding')) as v(name)
    where has_table_privilege('anon', ('public.' || v.name)::regclass, 'SELECT')),
  0,
  '...and anon can read none of them');

-- =============================================================================================
-- 12. THE WRAPPER PRESERVES AUTHORIZATION -- behaviourally, not by inspection. A user holding no
--     role must be refused through the endpoint exactly as through the app function, because the
--     wrapper carries the caller's identity and adds no authority of its own.
-- =============================================================================================
insert into auth.users (id, email) values ('53000000-0000-0000-0000-0000000000a1','nobody@api.test');
insert into public.tenants (id, name, slug, status) values
  ('53000000-0000-0000-0000-000000000001','API Travel','api-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '53000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('53000000-0000-0000-0000-00000000000a','53000000-0000-0000-0000-000000000001','Cairo','api-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('53000000-0000-0000-0000-0000000000c1','53000000-0000-0000-0000-000000000001','53000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('53000000-0000-0000-0000-000000000011','53000000-0000-0000-0000-000000000001','No Role','nobody@api.test',true,'53000000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('53000000-0000-0000-0000-000000000001','53000000-0000-0000-0000-000000000011','53000000-0000-0000-0000-00000000000a','53000000-0000-0000-0000-0000000000c1',true);

select set_config('request.jwt.claims','{"sub":"53000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select throws_ok(
  $q$select public.create_customer('person','Walk In', p_primary_phone => '+201000000001')$q$,
  '42501', null,
  'a user with no role is refused BY THE ENDPOINT -- the wrapper carries the caller, not the owner');

select finish();
rollback;
