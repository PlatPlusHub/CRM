-- pgTAP: WP-04-C -- the document object store, and PP-2's missing link branch.
--
-- Supabase Storage was selected on ONE decisive property, and assertions 4-7 are what prove it:
-- `storage.objects` is a PostgreSQL table with RLS, so an object is visible exactly when its
-- `document_versions` row is visible -- the confidential/financial/branch/ownership rules proved by
-- SPEC-139 and SPEC-154 apply to the BYTES without a single rule being restated. No other candidate
-- provider can do that; each would need a second authorization system that cannot see ORVION's RLS.
--
-- Assertion 8 is the §17 guard: `document_links.scope_isolation` had to be dropped and recreated to
-- gain one branch, which is exactly the edit where a branch silently disappears and every other test
-- still passes. It pins all nine.
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

insert into auth.users (id, email) values
  ('48000000-0000-0000-0000-0000000000a1','owner@st.test'),
  ('48000000-0000-0000-0000-0000000000a2','emp@st.test');
insert into public.tenants (id, name, slug, status) values
  ('48000000-0000-0000-0000-000000000001','ST Travel','st-travel','active'),
  ('48000000-0000-0000-0000-000000000002','Other ST','other-st','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select v.t, sp.id, 'active'
from (values ('48000000-0000-0000-0000-000000000001'::uuid),
             ('48000000-0000-0000-0000-000000000002'::uuid)) v(t)
join public.subscription_plans sp on sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('48000000-0000-0000-0000-00000000000a','48000000-0000-0000-0000-000000000001','Cairo','st-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('48000000-0000-0000-0000-0000000000c1','48000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('48000000-0000-0000-0000-000000000011','48000000-0000-0000-0000-000000000001','ST Owner','owner@st.test',true,'48000000-0000-0000-0000-0000000000a1'),
  ('48000000-0000-0000-0000-000000000012','48000000-0000-0000-0000-000000000001','ST Emp','emp@st.test',true,'48000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('48000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-000000000011','48000000-0000-0000-0000-00000000000a','48000000-0000-0000-0000-0000000000c1',true),
  ('48000000-0000-0000-0000-000000000001','48000000-0000-0000-0000-000000000012','48000000-0000-0000-0000-00000000000a','48000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '48000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('48000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('48000000-0000-0000-0000-000000000012'::uuid,'employee')) v(u, rc)
join public.roles r on r.code = v.rc;

-- =============================================================================================
-- 1-3. THE BUCKET is private and constrains what the STORE will accept -- which matters because
--      recording metadata and pushing bytes are two different calls.
-- =============================================================================================
select is(
  (select public::text from storage.buckets where id = 'documents'),
  'false',
  'the documents bucket is PRIVATE -- no anonymous URL exists for any object in it');

select ok(
  (select allowed_mime_types from storage.buckets where id = 'documents')
    @> array['application/pdf','image/jpeg','image/png','image/webp'],
  '...and the STORE itself constrains MIME types, mirroring what app.upload_document accepts');

select is(
  (select file_size_limit from storage.buckets where id = 'documents'),
  10485760::bigint,
  '...and enforces a size ceiling, so a valid metadata row cannot smuggle an arbitrary payload');

-- =============================================================================================
-- 4-7. OBJECT AUTHORIZATION IS DOCUMENT AUTHORIZATION. The owner creates a confidential financial
--      document; the employee cannot see the row, and therefore cannot see the bytes either --
--      without a single visibility rule being restated in the storage policy.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"48000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$select app.upload_subscription_payment_proof('bank.pdf','pdf', 4096)$$,
  'the tenant admin uploads a payment proof -- creating the metadata the object will hang on');

reset role;
select set_config('request.jwt.claims', null, true);

-- Stand in for the byte upload the client performs after the metadata transaction. Inserted as
-- postgres because the fixture is establishing state, not testing the write path; assertions 6-7
-- test the READ path as the two real roles.
insert into storage.objects (bucket_id, name, owner)
select 'documents', dv.storage_path, null
from public.document_versions dv
join public.documents d on d.id = dv.document_id
where d.document_type_code = 'payment_proof';

select set_config('request.jwt.claims','{"sub":"48000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select is(
  (select count(*)::int from storage.objects where bucket_id = 'documents'),
  1,
  'the OWNER can see the object, because the owner can see its document_versions row');

reset role;
select set_config('request.jwt.claims','{"sub":"48000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.document_versions dv
     join public.documents d on d.id = dv.document_id
    where d.document_type_code = 'payment_proof'),
  0,
  'CONTROL: the EMPLOYEE cannot see the payment-proof version row (confidential + financial)');

select is(
  (select count(*)::int from storage.objects where bucket_id = 'documents'),
  0,
  '...and therefore cannot see the OBJECT either -- one mechanism, not two');

-- =============================================================================================
-- 8. PP-2 / §17. The policy was dropped and recreated to gain one branch. Every link target must
--    still be represented -- a dropped branch is a regression even when the new branch works.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select count(*)::int from (
      select unnest(array['booking_id','booking_item_id','invoice_id','quotation_id','receipt_id',
                          'passenger_id','supplier_id','subscription_payment_proof_id',
                          'has_tenant_wide_read']) as needle) n
    where position(n.needle in (
      select pg_get_expr(pol.polqual, pol.polrelid)
      from pg_policy pol join pg_class c on c.oid = pol.polrelid
      where c.relname = 'document_links' and pol.polname = 'scope_isolation')) = 0),
  0,
  'all NINE document_links branches survive the rewrite -- including the one PP-2 added');

-- =============================================================================================
-- 9-10. THE PP-2 BRANCH IS REAL, not decorative: the link is now visible because it is a
--       payment-proof link, rather than because the actor happened to hold VIEW_ALL_BRANCHES.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"48000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.document_links
    where subscription_payment_proof_id is not null),
  1,
  'the owner sees the payment-proof link');

reset role;
select set_config('request.jwt.claims','{"sub":"48000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;
select is(
  (select count(*)::int from public.document_links
    where subscription_payment_proof_id is not null),
  0,
  '...and the employee does NOT -- the branch defers to subscription_payment_proofs'' own RLS');

-- =============================================================================================
-- 11-12. WRITE PATHS. No UPDATE or DELETE policy exists on storage.objects, deliberately:
--        documents are versioned, so overwriting an object in place would defeat the audit trail.
--        RLS with no policy denies, which is the fail-closed default this relies on.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and cmd in ('UPDATE','DELETE')),
  0,
  'there is NO update or delete policy on storage.objects -- superseding writes a new version, never an overwrite');

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'storage' and tablename = 'objects' and cmd in ('SELECT','INSERT')),
  2,
  '...and exactly two policies exist, one to read and one to receive the upload');

select finish();
rollback;
