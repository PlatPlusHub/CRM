-- pgTAP: RET-1 -- retention is a POLICY PER DOCUMENT TYPE, and it still deletes nothing by default.
--
-- WHAT MUST BE TRUE:
--   * with NO policy, nothing is ever a candidate, however ancient the version -- and that is the
--     SHIPPED state, because the migration seeds zero rows;
--   * a policy makes candidates of SUPERSEDED versions only, and only past the threshold;
--   * the policy is resolved PER DOCUMENT TYPE, so configuring one type leaves every other type
--     retained -- this is the whole point of replacing the zero-arg global;
--   * a policy is TENANT-SCOPED: one tenant's decision never reaches another's documents;
--   * withdrawal is DEACTIVATION, and it withdraws the work at the claim path too;
--   * a period below one day cannot be STORED, not merely cannot be obeyed.
--
-- Every claim is proven by the findings the scan actually produces, never by "the function returned
-- something" (AGENTS.md §6).
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into public.tenants (id, name, slug, status) values
  ('97000000-0000-0000-0000-00000000000a','Ret97 A','ret97-a','active'),
  ('97000000-0000-0000-0000-00000000000b','Ret97 B','ret97-b','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise'
  and t.id in ('97000000-0000-0000-0000-00000000000a','97000000-0000-0000-0000-00000000000b');

-- Tenant A holds TWO document types; tenant B mirrors the passport. The two types are what make the
-- per-type assertion meaningful, and the mirror is what makes the tenant assertion meaningful: a
-- leak in either direction shows up as a finding on the wrong side rather than as a missing row.
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code) values
  ('97000000-0000-0000-0000-0000000000d1','97000000-0000-0000-0000-00000000000a','passport','A Passport','active'),
  ('97000000-0000-0000-0000-0000000000d2','97000000-0000-0000-0000-00000000000a','visa',    'A Visa',    'active'),
  ('97000000-0000-0000-0000-0000000000d3','97000000-0000-0000-0000-00000000000b','passport','B Passport','active');

insert into public.document_versions
    (id, tenant_id, document_id, version_number, file_name, file_type_code, is_current, uploaded_at) values
  ('97000000-0000-0000-0000-0000000000f1','97000000-0000-0000-0000-00000000000a','97000000-0000-0000-0000-0000000000d1',1,'a-p1.pdf','pdf',false, now() - interval '400 days'),
  ('97000000-0000-0000-0000-0000000000f2','97000000-0000-0000-0000-00000000000a','97000000-0000-0000-0000-0000000000d1',2,'a-p2.pdf','pdf',true,  now() - interval '400 days'),
  ('97000000-0000-0000-0000-0000000000f3','97000000-0000-0000-0000-00000000000a','97000000-0000-0000-0000-0000000000d2',1,'a-v1.pdf','pdf',false, now() - interval '400 days'),
  ('97000000-0000-0000-0000-0000000000f4','97000000-0000-0000-0000-00000000000a','97000000-0000-0000-0000-0000000000d2',2,'a-v2.pdf','pdf',true,  now() - interval '400 days'),
  ('97000000-0000-0000-0000-0000000000f5','97000000-0000-0000-0000-00000000000b','97000000-0000-0000-0000-0000000000d3',1,'b-p1.pdf','pdf',false, now() - interval '400 days'),
  ('97000000-0000-0000-0000-0000000000f6','97000000-0000-0000-0000-00000000000b','97000000-0000-0000-0000-0000000000d3',2,'b-p2.pdf','pdf',true,  now() - interval '400 days');

update public.documents set current_version_id='97000000-0000-0000-0000-0000000000f2' where id='97000000-0000-0000-0000-0000000000d1';
update public.documents set current_version_id='97000000-0000-0000-0000-0000000000f4' where id='97000000-0000-0000-0000-0000000000d2';
update public.documents set current_version_id='97000000-0000-0000-0000-0000000000f6' where id='97000000-0000-0000-0000-0000000000d3';

-- EVERY version's bytes exist, so `missing_object` cannot muddy the retention counts below.
insert into storage.objects (bucket_id, name)
select 'documents', dv.storage_path from public.document_versions dv
where dv.tenant_id in ('97000000-0000-0000-0000-00000000000a','97000000-0000-0000-0000-00000000000b');

-- =============================================================================================
-- 1-4. THE SHIPPED DEFAULT. No policy anywhere, so nothing is a candidate at any age.
-- =============================================================================================
select is(
  (select count(*)::int from public.document_retention_policies),
  0,
  'RET-1: the migration seeds ZERO policy rows -- ORVION invents no legal period for anyone');

select is(
  app.document_retention_days('97000000-0000-0000-0000-00000000000a','passport'),
  null,
  'RET-1: with no policy the resolver returns NULL, and NULL still means RETAIN');

select lives_ok(
  $$select app.reconcile_document_storage()$$,
  'RET-1: the scan runs cleanly with retention entirely unconfigured');

select is(
  (select count(*)::int from public.document_storage_findings
    where finding_type_code='retention_expired'
      and tenant_id in ('97000000-0000-0000-0000-00000000000a','97000000-0000-0000-0000-00000000000b')),
  0,
  'RET-1 (FAIL-CLOSED BY THE SHAPE OF THE QUERY): six 400-day-old versions and NOT ONE candidate -- the INNER JOIN has no policy to join to');

-- =============================================================================================
-- 5-9. ONE TYPE, ONE TENANT. Configuring `passport` for tenant A must move exactly one version.
-- =============================================================================================
insert into public.document_retention_policies (tenant_id, document_type_code, retention_days, reason)
values ('97000000-0000-0000-0000-00000000000a','passport', 30, 'test fixture: a decided period');

select is(
  app.document_retention_days('97000000-0000-0000-0000-00000000000a','passport'),
  30,
  'RET-1: the resolver returns the configured period for THAT tenant and THAT type');

select is(
  app.document_retention_days('97000000-0000-0000-0000-00000000000a','visa'),
  null,
  'RET-1 (PER TYPE): the SAME tenant''s `visa` is still UNDECIDED -- one decision does not leak to another document type');

select is(
  app.document_retention_days('97000000-0000-0000-0000-00000000000b','passport'),
  null,
  'RET-1 (PER TENANT): tenant B''s `passport` is still UNDECIDED -- one tenant''s legal decision never reaches another''s documents');

select lives_ok($$select app.reconcile_document_storage()$$, 'the scan runs with one policy configured');

select set_eq(
  $$select document_version_id::text from public.document_storage_findings
     where finding_type_code='retention_expired'
       and tenant_id in ('97000000-0000-0000-0000-00000000000a','97000000-0000-0000-0000-00000000000b')$$,
  $$values ('97000000-0000-0000-0000-0000000000f1')$$,
  'RET-1: EXACTLY ONE candidate -- tenant A''s superseded passport v1. Not its current v2, not its visa, and nothing of tenant B''s');

-- =============================================================================================
-- 10-11. THE CURRENT VERSION IS NEVER A CANDIDATE, at any age, under any policy.
-- =============================================================================================
select is(
  (select count(*)::int from public.document_storage_findings f
     join public.document_versions dv on dv.id = f.document_version_id
    where f.finding_type_code='retention_expired' and dv.is_current),
  0,
  'RET-1: no CURRENT version is ever a candidate -- and both checks (`is_current` and the document''s own `current_version_id`) still guard it');

select is(
  (select (details->>'document_type_code') from public.document_storage_findings
    where finding_type_code='retention_expired'
      and document_version_id='97000000-0000-0000-0000-0000000000f1'),
  'passport',
  'RET-1: the finding records WHICH type''s policy made it a candidate -- an operator can see the rule that fired');

-- =============================================================================================
-- 12-13. THE THRESHOLD IS REAL. A period longer than the version''s age retains it.
-- =============================================================================================
update public.document_retention_policies set retention_days = 9000
 where tenant_id='97000000-0000-0000-0000-00000000000a' and document_type_code='passport';

select is(
  (select count(*)::int from app.claim_storage_actions(500)
    where tenant_id='97000000-0000-0000-0000-00000000000a'),
  0,
  'RET-1: raising the period beyond the version''s age WITHDRAWS the work at the claim path -- re-verified there, not trusted from a days-old finding');

update public.document_retention_policies set retention_days = 30
 where tenant_id='97000000-0000-0000-0000-00000000000a' and document_type_code='passport';

select is(
  (select count(*)::int from app.claim_storage_actions(500)
    where tenant_id='97000000-0000-0000-0000-00000000000a'),
  1,
  '...and restoring it brings the work back -- the claim path reads the policy live');

-- =============================================================================================
-- 14-15. WITHDRAWAL IS DEACTIVATION, and it must withdraw the work too.
-- =============================================================================================
update public.document_retention_policies set is_active = false
 where tenant_id='97000000-0000-0000-0000-00000000000a' and document_type_code='passport';

select is(
  app.document_retention_days('97000000-0000-0000-0000-00000000000a','passport'),
  null,
  'RET-1: a DEACTIVATED policy resolves to NULL -- withdrawal restores "retain", and the record of what was configured survives');

select is(
  (select count(*)::int from app.claim_storage_actions(500)
    where tenant_id='97000000-0000-0000-0000-00000000000a'),
  0,
  '...and the executor can no longer claim the work -- a withdrawn legal decision stops the deletion it authorised');

-- =============================================================================================
-- 16. A DESTRUCTIVE PERIOD CANNOT BE STORED. Not "is coerced" -- cannot be stored.
-- =============================================================================================
select throws_ok(
  $$insert into public.document_retention_policies (tenant_id, document_type_code, retention_days)
     values ('97000000-0000-0000-0000-00000000000b','visa', 0)$$,
  '23514',
  null,
  'RET-1: `retention_days = 0` -- "destroy on sight" -- is refused by a CHECK constraint, so the hazard cannot reach the database at all');

select * from finish();
rollback;
