-- pgTAP behavioral guard for PH8-1 (SPEC-123): the delivery lease / visibility timeout in
-- app.claim_conversion_deliveries. This is the permanent guard required by GOVERNANCE.md §18
-- (discovery-to-guard): the defect it closes — a claimed-but-never-acked delivery stranded
-- 'pending' forever — must not be able to silently return.
--
-- Unlike tests 01-08 (structural invariant scans) this is a behavioral test, because the
-- property under guard is a state machine, not a schema shape. All fixture rows are created
-- and rolled back inside this transaction: they never persist, never leave the local database,
-- and never reach Google. Click identifiers below are self-evidently non-real placeholders.
--
-- Side-effecting steps are wrapped in DO blocks so only pgTAP's own assertions write to the
-- TAP stream.
--
-- Concurrency note: "two workers cannot double-claim" cannot be exercised from a single
-- transaction (it needs two live sessions), so it is guarded here structurally — the claim
-- query must retain `for update ... skip locked`. The live two-session proof is recorded in
-- SPEC-123's Verification Notes.
create extension if not exists pgtap with schema extensions;

begin;
select plan(17);

-- Fixture builder: one tenant with a consent-granted attribution click and one conversion.
create function pg_temp.mk_fixture(p_slug text)
returns table (tenant_id uuid, conversion_id uuid)
language plpgsql
as $$
declare
    v_tenant uuid; v_branch uuid; v_dept uuid; v_cust uuid; v_lead uuid; v_click uuid; v_conv uuid;
begin
    insert into public.tenants (name, slug, status)
        values (p_slug, p_slug, 'active') returning id into v_tenant;
    insert into public.branches (tenant_id, name, slug)
        values (v_tenant, 'Main', p_slug || '-main') returning id into v_branch;
    insert into public.departments (tenant_id, branch_id, department_type_code, name)
        values (v_tenant, v_branch, 'sales', 'Sales') returning id into v_dept;
    insert into public.customers (tenant_id, customer_type_code, full_name, primary_email, primary_phone)
        values (v_tenant, 'person', 'Lease Test Customer',
                p_slug || '@example.invalid', '01000000000') returning id into v_cust;
    insert into public.leads (tenant_id, branch_id, department_id, lead_source_code,
                              lead_status_code, title, customer_id)
        values (v_tenant, v_branch, v_dept, 'google_ads_form', 'qualified',
                'Lease Test Lead', v_cust) returning id into v_lead;
    insert into public.attribution_clicks (tenant_id, attribution_source_code, gclid,
                                           consent_ad_user_data, consent_ad_personalization, lead_id)
        values (v_tenant, 'google_ads', 'NOT-A-REAL-CLICK-ID-' || p_slug,
                'granted', 'granted', v_lead) returning id into v_click;
    insert into public.offline_conversions (tenant_id, lead_id, attribution_click_id,
                                            conversion_event_type_code)
        values (v_tenant, v_lead, v_click, 'qualified_lead') returning id into v_conv;
    return query select v_tenant, v_conv;
end;
$$;

-- Age every in-flight delivery of a conversion past the 30-minute lease, touching nothing else.
create function pg_temp.expire(p_conv uuid) returns void
language sql as $$
    update public.offline_conversion_deliveries
       set created_at = now() - interval '31 minutes'
     where offline_conversion_id = p_conv and delivery_status_code = 'pending';
$$;

create temporary table _fx (label text primary key, tenant_id uuid, conversion_id uuid) on commit drop;

create function pg_temp.conv(p_label text) returns uuid
language sql stable as $$ select conversion_id from _fx where label = p_label $$;

insert into _fx select 'a', * from pg_temp.mk_fixture('lease-test-a');
insert into _fx select 'b', * from pg_temp.mk_fixture('lease-test-b');

-- ---------------------------------------------------------------- 1. baseline claim works
select is(
  (select count(*)::int from app.claim_conversion_deliveries('google_ads', 50)),
  2,
  'Both eligible conversions are claimed on the first run');

-- ------------------------------------------- 2. a FRESH pending lease is NOT reclaimable
select is(
  (select count(*)::int from app.claim_conversion_deliveries('google_ads', 50)),
  0,
  'A fresh pending lease is not reclaimable — an in-flight worker keeps its rows');

-- --------------------------------------------- 3-8. an EXPIRED pending lease IS reclaimable
do $$ begin perform pg_temp.expire(pg_temp.conv('a')); end $$;

select is(
  (select count(*)::int from app.claim_conversion_deliveries('google_ads', 50)),
  1,
  'An expired pending lease is reclaimed — and only that one (the fresh lease is untouched)');

select is(
  (select count(*)::int from public.offline_conversion_deliveries
    where offline_conversion_id = pg_temp.conv('a')),
  2,
  'Reclaiming creates exactly one new delivery row — no duplicate active records');

select is(
  (select count(*)::int from public.offline_conversion_deliveries
    where offline_conversion_id = pg_temp.conv('a') and delivery_status_code = 'pending'),
  1,
  'Exactly one delivery is active (pending) after reclamation');

select is(
  (select attempt_number from public.offline_conversion_deliveries
    where offline_conversion_id = pg_temp.conv('a') and delivery_status_code = 'pending'),
  2,
  'Attempt history is not reset — the reclaimed attempt is number 2, not 1');

select ok(
  (select bool_and(error_message like 'LEASE_EXPIRED:%')
     from public.offline_conversion_deliveries
    where offline_conversion_id = pg_temp.conv('a') and delivery_status_code = 'retried'),
  'The expired attempt is retained as retried and carries its LEASE_EXPIRED reason');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'offline_conversion_failed'
      and payload ->> 'expired_lease' = 'true'
      and entity_id = pg_temp.conv('a')),
  1,
  'Lease expiry emits an offline_conversion_failed event flagged expired_lease');

-- ---------------------------------------- 9-10. an unrelated tenant is completely unaffected
select is(
  (select count(*)::int from public.offline_conversion_deliveries
    where offline_conversion_id = pg_temp.conv('b') and delivery_status_code = 'pending'),
  1,
  'The other tenant''s in-flight delivery is untouched by another tenant''s expiry');

select is(
  (select count(*)::int from public.offline_conversion_deliveries
    where offline_conversion_id = pg_temp.conv('b')),
  1,
  'The other tenant gained no delivery rows from another tenant''s reclamation');

-- ------------------------- 11-12. a SENT delivery is never turned back into claimable work
do $$
begin
    perform app.record_conversion_delivery_result(
        (select id from public.offline_conversion_deliveries
          where offline_conversion_id = pg_temp.conv('b') and delivery_status_code = 'pending'),
        true, '{"ok":true}'::jsonb, null);
    update public.offline_conversion_deliveries
       set created_at = now() - interval '24 hours'
     where offline_conversion_id = pg_temp.conv('b');
end $$;

select is(
  (select count(*)::int from app.claim_conversion_deliveries('google_ads', 50)),
  0,
  'A successfully sent delivery is never reclaimed, however old it is');

select is(
  (select delivery_status_code from public.offline_conversion_deliveries
    where offline_conversion_id = pg_temp.conv('b')),
  'sent',
  'The sent delivery keeps its terminal state after an expiry sweep');

-- ---------- 13-15. expired leases consume attempts: the retry ceiling still stops at 5 rows
do $$
begin
    for i in 1..3 loop   -- drive attempts 3, 4 and 5 purely through lease expiry
        perform pg_temp.expire(pg_temp.conv('a'));
        perform app.claim_conversion_deliveries('google_ads', 50);
    end loop;
end $$;

select is(
  (select count(*)::int from public.offline_conversion_deliveries
    where offline_conversion_id = pg_temp.conv('a')),
  5,
  'Expired attempts count toward the ceiling — five delivery rows, not more');

do $$ begin perform pg_temp.expire(pg_temp.conv('a')); end $$;

select is(
  (select count(*)::int from app.claim_conversion_deliveries('google_ads', 50)),
  0,
  'With the ceiling exhausted an expired lease is not reclaimed — the limit is not bypassed');

select is(
  (select delivery_status_code from public.offline_conversion_deliveries
    where offline_conversion_id = pg_temp.conv('a') and attempt_number = 5),
  'failed',
  'The final expired attempt terminalizes to failed rather than looking in-flight forever');

-- ------------------------------ 16-17. structural guards (cannot be silently removed)
select ok(
  (select pg_get_functiondef(p.oid) ~* 'for\s+update\s+of\s+oc\s+skip\s+locked'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'claim_conversion_deliveries'),
  'The claim query still serializes concurrent workers with FOR UPDATE ... SKIP LOCKED');

select ok(
  (select pg_get_functiondef(p.oid) like '%LEASE_EXPIRED%'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'claim_conversion_deliveries'),
  'The lease-expiry step is still present in app.claim_conversion_deliveries');

select * from finish();
rollback;
