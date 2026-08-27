-- pgTAP: WP-04-D -- document retention, deletion, recovery and orphan reconciliation.
--
-- THE SHAPE OF THIS PACKAGE IS DICTATED BY A PLATFORM FACT, and assertion 12 is the one that pins
-- it: Supabase's own `storage.protect_delete()` trigger refuses every SQL DELETE against
-- `storage.objects`, and `pg_net` is not installed, so the database can neither destroy an object
-- nor ask the Storage API to. The database therefore owns the DECISION and an external executor
-- owns the BYTES. Everything below tests the decision side, which is the side that can be tested.
--
-- The most important assertion in the file is 2, and it asserts that nothing happens: with the
-- retention period still an open business decision, a four-hundred-day-old superseded version is
-- NOT selected for destruction. "Retention cannot accidentally become delete-immediately" is a
-- property of the default, not of a validation someone has to remember to run.
create extension if not exists pgtap with schema extensions;

begin;
select plan(25);

insert into auth.users (id, email) values
  ('49000000-0000-0000-0000-0000000000a1','owner@rt.test');
insert into public.tenants (id, name, slug, status) values
  ('49000000-0000-0000-0000-00000000000a','RT Travel','rt-travel','active'),
  ('49000000-0000-0000-0000-00000000000b','RT Other','rt-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and t.id in ('49000000-0000-0000-0000-00000000000a','49000000-0000-0000-0000-00000000000b');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('49000000-0000-0000-0000-000000000011','49000000-0000-0000-0000-00000000000a','RT Owner','owner@rt.test',true,'49000000-0000-0000-0000-0000000000a1');

-- Mirror-image documents, one per tenant, each with a superseded v1 and a current v2. The mirror is
-- what makes the cross-tenant assertions meaningful: every finding type occurs on both sides, so a
-- leak would be visible as a path under the wrong tenant rather than as a missing row.
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code) values
  ('49000000-0000-0000-0000-0000000000d1','49000000-0000-0000-0000-00000000000a','passport','A Passport','active'),
  ('49000000-0000-0000-0000-0000000000d2','49000000-0000-0000-0000-00000000000b','passport','B Passport','active');

insert into public.document_versions
    (id, tenant_id, document_id, version_number, file_name, file_type_code, is_current, uploaded_at) values
  ('49000000-0000-0000-0000-0000000000f1','49000000-0000-0000-0000-00000000000a','49000000-0000-0000-0000-0000000000d1',1,'a-v1.pdf','pdf',false, now() - interval '400 days'),
  ('49000000-0000-0000-0000-0000000000f2','49000000-0000-0000-0000-00000000000a','49000000-0000-0000-0000-0000000000d1',2,'a-v2.pdf','pdf',true,  now() - interval '1 day'),
  ('49000000-0000-0000-0000-0000000000f3','49000000-0000-0000-0000-00000000000b','49000000-0000-0000-0000-0000000000d2',1,'b-v1.pdf','pdf',false, now() - interval '400 days'),
  ('49000000-0000-0000-0000-0000000000f4','49000000-0000-0000-0000-00000000000b','49000000-0000-0000-0000-0000000000d2',2,'b-v2.pdf','pdf',true,  now() - interval '1 day');

update public.documents set current_version_id = '49000000-0000-0000-0000-0000000000f2'
 where id = '49000000-0000-0000-0000-0000000000d1';
update public.documents set current_version_id = '49000000-0000-0000-0000-0000000000f4'
 where id = '49000000-0000-0000-0000-0000000000d2';

-- Only the CURRENT versions got their bytes uploaded, so each tenant has exactly one metadata row
-- with no object. Plus one true orphan per tenant: bytes with no metadata anywhere.
insert into storage.objects (bucket_id, name)
select 'documents', dv.storage_path from public.document_versions dv where dv.is_current;
insert into storage.objects (bucket_id, name) values
  ('documents','49000000-0000-0000-0000-00000000000a/49000000-0000-0000-0000-0000000000cc/1'),
  ('documents','49000000-0000-0000-0000-00000000000b/49000000-0000-0000-0000-0000000000cc/1');

-- =============================================================================================
-- 1-2. THE DEFAULT IS "RETAIN FOREVER", and it holds against a genuinely ancient version.
-- =============================================================================================
select ok(
  app.document_retention_days() is null or app.document_retention_days() >= 1,
  'the retention period is either UNDECIDED (null) or at least one day -- never zero or negative');

create temp table run1 as select app.reconcile_document_storage() as j;

select is(
  (select (j ->> 'retention_expired')::int from run1),
  0,
  'with retention UNDECIDED, a 400-day-old superseded version is NOT marked for destruction');

-- =============================================================================================
-- 3-6. DETECTION, in both directions, and the cross-tenant proof.
-- =============================================================================================
select is(
  (select count(*)::int from public.document_storage_findings
    where finding_type_code = 'missing_object'
      and tenant_id = '49000000-0000-0000-0000-00000000000a'),
  1,
  'metadata without an object is found -- v1 only, because v2''s bytes are there');

select is(
  (select count(*)::int from public.document_storage_findings
    where finding_type_code = 'missing_object'),
  2,
  '...on BOTH tenants, so the loop really iterated past the first one');

select is(
  (select count(*)::int from public.document_storage_findings
    where finding_type_code = 'orphan_object'),
  2,
  'an object with no metadata row is found -- the other half, reachable when a PUT outlives a rollback');

select is(
  (select count(*)::int from public.document_storage_findings
    where storage_path is not null
      and split_part(storage_path, '/', 1) <> tenant_id::text),
  0,
  'CROSS-TENANT: no finding names a path outside its own tenant''s prefix');

-- =============================================================================================
-- 7-9. IDEMPOTENCY AND NON-DESTRUCTION. A reconciler that could damage what it inspects would be
--      worse than none. It writes findings and touches nothing else -- ever.
-- =============================================================================================
create temp table before_counts as
  select (select count(*) from public.document_storage_findings) as findings,
         (select count(*) from public.document_versions)         as versions,
         (select count(*) from storage.objects)                  as objects;

select app.reconcile_document_storage();

select is(
  (select count(*)::int from public.document_storage_findings),
  (select findings::int from before_counts),
  'a second run creates NO duplicate findings -- the identity index makes re-running safe');

select is(
  (select count(*)::int from public.document_versions),
  (select versions::int from before_counts),
  '...and destroys no metadata');

select is(
  (select count(*)::int from storage.objects),
  (select objects::int from before_counts),
  '...and destroys no objects');

-- =============================================================================================
-- 10-11. AUTHORITY. Reconciliation reads across every tenant, which is precisely the authority no
--        tenant user may hold. Both halves are checked: cannot run it, cannot read its output.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"49000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$select app.reconcile_document_storage()$$,
  '42501', null,
  'an authenticated tenant user cannot RUN reconciliation -- it spans every tenant');

select throws_ok(
  $$select count(*) from public.document_storage_findings$$,
  '42501', null,
  '...and cannot READ the findings either -- no grant, and a deny-all policy behind it');

reset role;
select set_config('request.jwt.claims', null, true);

-- =============================================================================================
-- 12-13. THE PLATFORM CONSTRAINT THAT SHAPED THIS PACKAGE, pinned so we learn if it ever changes,
--        and the schedule that makes detection routine rather than incidental.
-- =============================================================================================
select throws_ok(
  $$delete from storage.objects where bucket_id = 'documents'$$,
  '42501', null,
  'the database CANNOT delete an object -- storage.protect_delete refuses every SQL DELETE');

select is(
  (select count(*)::int from cron.job where jobname = 'document-storage-reconciliation'),
  1,
  'reconciliation is scheduled, so a discrepancy surfaces on its own rather than when someone looks');

-- =============================================================================================
-- 14-15. THE DAY THE BUSINESS DECIDES. One line of one function changes and the retention path
--        comes alive -- proved by changing exactly that line and nothing else.
-- =============================================================================================
create or replace function app.document_retention_days()
returns integer language sql immutable set search_path = '' as $fn$ select 30::integer; $fn$;

select app.reconcile_document_storage();

select is(
  (select count(*)::int from public.document_storage_findings
    where finding_type_code = 'retention_expired'),
  2,
  'with retention set to 30 days, both 400-day-old superseded versions become eligible');

select is(
  (select count(*)::int from public.document_storage_findings f
     join public.document_versions dv on dv.id = f.document_version_id
    where f.finding_type_code = 'retention_expired' and dv.is_current),
  0,
  '...and NO current version is ever eligible, at any age');

-- =============================================================================================
-- 16-18. DESTRUCTION -- the one path in ORVION that deletes a document_versions row, and what it
--        must leave behind. The finding is not erased with the version: it is the only surviving
--        record that this path ever existed.
-- =============================================================================================
select lives_ok(
  $$select app.platform_resolve_storage_finding(
      (select id from public.document_storage_findings
        where finding_type_code = 'retention_expired'
          and tenant_id = '49000000-0000-0000-0000-00000000000a'),
      'object_deleted', 'executor destroyed the object')$$,
  'the executor reports the bytes destroyed, and the database removes the metadata that named them');

select is(
  (select count(*)::int from public.document_versions
    where id = '49000000-0000-0000-0000-0000000000f1'),
  0,
  '...the superseded version is gone');

select is(
  (select count(*)::int from public.document_storage_findings
    where finding_type_code = 'retention_expired'
      and tenant_id = '49000000-0000-0000-0000-00000000000a'
      and storage_path is not null
      and document_version_id is null
      and resolution_code = 'object_deleted'),
  1,
  '...while the finding SURVIVES with its path -- the id nulls out, the audit record does not');

-- =============================================================================================
-- 19-20. RECOVERY. A missing object is a recoverable state, so resolving it must never destroy the
--        metadata -- that row is the only remaining evidence the object ever existed. And a
--        discrepancy that is still observable REOPENS, whatever the executor reported.
-- =============================================================================================
select app.platform_resolve_storage_finding(
    (select id from public.document_storage_findings
      where finding_type_code = 'missing_object'
        and tenant_id = '49000000-0000-0000-0000-00000000000b'),
    'object_restored', 'claimed re-uploaded');

select is(
  (select count(*)::int from public.document_versions
    where id = '49000000-0000-0000-0000-0000000000f3'),
  1,
  'resolving a MISSING-object finding destroys nothing -- the metadata is the evidence, not the debris');

select app.reconcile_document_storage();

select is(
  (select count(*)::int from public.document_storage_findings
    where finding_type_code = 'missing_object'
      and tenant_id = '49000000-0000-0000-0000-00000000000b'
      and resolved_at is null),
  1,
  '...and because the object is still absent, the finding REOPENS -- observable beats reported');

-- =============================================================================================
-- 21-23. REFUSALS.
-- =============================================================================================
select throws_ok(
  $$select app.platform_resolve_storage_finding(
      (select id from public.document_storage_findings
        where finding_type_code = 'orphan_object' limit 1), 'made_up_code')$$,
  'unknown resolution code: made_up_code',
  'an invented resolution code is refused rather than stored');

select throws_ok(
  $$select app.platform_resolve_storage_finding(
      (select id from public.document_storage_findings
        where finding_type_code = 'retention_expired'
          and resolution_code = 'object_deleted'), 'dismissed')$$,
  null, null,
  'an already-resolved finding cannot be resolved twice');

-- B lapses. Its superseded version is now frozen: canon 28 promises a restricted tenant that its
-- data may be READ and EXPORTED, and destroying it under retention would break that promise.
update public.subscriptions set subscription_status_code = 'expired'
 where tenant_id = '49000000-0000-0000-0000-00000000000b';

select throws_ok(
  $$select app.platform_resolve_storage_finding(
      (select id from public.document_storage_findings
        where finding_type_code = 'retention_expired'
          and tenant_id = '49000000-0000-0000-0000-00000000000b'),
      'object_deleted')$$,
  '42501', null,
  'a RESTRICTED tenant''s data is not destroyed under retention -- refused explicitly, before the delete');

-- =============================================================================================
-- 24-25. SKIP, NEVER RAISE. The WP-03 lesson, applied to a new cross-tenant batch. One tenant is
--        poisoned so its scan genuinely raises; the run must complete, the healthy tenant must be
--        processed anyway, and the failure must stay discoverable rather than vanish.
-- =============================================================================================
create function pg_temp.poison_tenant_b() returns trigger language plpgsql as $$
begin
    if new.tenant_id = '49000000-0000-0000-0000-00000000000b'
       and new.finding_type_code <> 'tenant_scan_failed' then
        raise exception 'injected failure for tenant B';
    end if;
    return new;
end $$;

create trigger zz_poison before insert on public.document_storage_findings
    for each row execute function pg_temp.poison_tenant_b();

-- A NEW orphan appears under tenant A, so "tenant A was processed" is proved by new work rather
-- than by rows that were already there before the poison.
insert into storage.objects (bucket_id, name) values
  ('documents','49000000-0000-0000-0000-00000000000a/49000000-0000-0000-0000-0000000000dd/1');

create temp table run_poisoned as select app.reconcile_document_storage() as j;

select is(
  (select (j ->> 'tenants_failed')::int from run_poisoned),
  1,
  'the run COMPLETES with a poisoned tenant, and reports the failure in its summary');

select ok(
  (select count(*) from public.document_storage_findings
    where tenant_id = '49000000-0000-0000-0000-00000000000a'
      and storage_path like '%0000000000dd/1') = 1
  and (select count(*) from public.document_storage_findings
        where tenant_id = '49000000-0000-0000-0000-00000000000b'
          and finding_type_code = 'tenant_scan_failed') = 1,
  '...the HEALTHY tenant was still scanned and found the new orphan, and B''s failure is recorded');

drop trigger zz_poison on public.document_storage_findings;

select finish();
rollback;
