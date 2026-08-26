-- pgTAP: document read scope (SPEC-144).
--
-- Documents were named in SPEC-137's plan and never reached its migration, so all three document
-- tables stayed tenant-only while every record they attach to was branch-scoped. For a table holding
-- passport scans and financial records that is the widest remaining hole in the read model, and it
-- was found by auditing permission coverage rather than by re-reading the migration -- both
-- VIEW_TRAVEL_DOCUMENTS and VIEW_FINANCIAL_DOCUMENTS showed as enforced nowhere.
--
-- Runs as `authenticated`. The chain under test is three policies deep (version -> document -> link
-- -> parent), so it can only be checked by actually querying it.
create extension if not exists pgtap with schema extensions;

begin;
select plan(10);

insert into auth.users (id, email) values
  ('28000000-0000-0000-0000-0000000000a1','uploader@example.com'),
  ('28000000-0000-0000-0000-0000000000a2','otherbranch@example.com'),
  ('28000000-0000-0000-0000-0000000000a3','fin@example.com');

insert into public.tenants (id, name, slug, status) values
  ('28000000-0000-0000-0000-000000000001','Doc Travel','doc-travel','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.branches (id, tenant_id, name, slug) values
  ('28000000-0000-0000-0000-00000000000a','28000000-0000-0000-0000-000000000001','Giza','giza'),
  ('28000000-0000-0000-0000-00000000000b','28000000-0000-0000-0000-000000000001','Suez','suez');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('28000000-0000-0000-0000-0000000000c1','28000000-0000-0000-0000-000000000001','28000000-0000-0000-0000-00000000000a','sales','Giza Sales'),
  ('28000000-0000-0000-0000-0000000000c2','28000000-0000-0000-0000-000000000001','28000000-0000-0000-0000-00000000000b','sales','Suez Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('28000000-0000-0000-0000-000000000011','28000000-0000-0000-0000-000000000001','Uploader','uploader@example.com',true,'28000000-0000-0000-0000-0000000000a1'),
  ('28000000-0000-0000-0000-000000000012','28000000-0000-0000-0000-000000000001','Other Branch','otherbranch@example.com',true,'28000000-0000-0000-0000-0000000000a2'),
  ('28000000-0000-0000-0000-000000000013','28000000-0000-0000-0000-000000000001','Finance','fin@example.com',true,'28000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('28000000-0000-0000-0000-000000000001','28000000-0000-0000-0000-000000000011','28000000-0000-0000-0000-00000000000a','28000000-0000-0000-0000-0000000000c1',true),
  ('28000000-0000-0000-0000-000000000001','28000000-0000-0000-0000-000000000012','28000000-0000-0000-0000-00000000000b','28000000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '28000000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('28000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('28000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('28000000-0000-0000-0000-000000000013'::uuid,'finance_manager')) as v(uid, role_code)
join public.roles r on r.code = v.role_code;

insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('28000000-0000-0000-0000-0000000000d1','28000000-0000-0000-0000-000000000001','person','Doc Customer');

-- A Giza booking, with an ordinary travel document and a confidential one attached.
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('28000000-0000-0000-0000-0000000000f1','28000000-0000-0000-0000-000000000001',
   '28000000-0000-0000-0000-00000000000a','28000000-0000-0000-0000-0000000000c1',
   '28000000-0000-0000-0000-0000000000d1','28000000-0000-0000-0000-000000000011',
   '28000000-0000-0000-0000-00000000000a','28000000-0000-0000-0000-0000000000c1',
   'draft','Giza booking','BK-GIZ-0001');

insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code, is_confidential, created_by) values
  ('28000000-0000-0000-0000-0000000000e1','28000000-0000-0000-0000-000000000001','passport','Passport scan','active',false,'28000000-0000-0000-0000-000000000011'),
  ('28000000-0000-0000-0000-0000000000e2','28000000-0000-0000-0000-000000000001','passport','Sensitive passport','active',true,'28000000-0000-0000-0000-000000000011'),
  ('28000000-0000-0000-0000-0000000000e3','28000000-0000-0000-0000-000000000001','invoice','Confidential invoice copy','active',true,'28000000-0000-0000-0000-000000000011');
insert into public.document_links (tenant_id, document_id, booking_id) values
  ('28000000-0000-0000-0000-000000000001','28000000-0000-0000-0000-0000000000e1','28000000-0000-0000-0000-0000000000f1'),
  ('28000000-0000-0000-0000-000000000001','28000000-0000-0000-0000-0000000000e2','28000000-0000-0000-0000-0000000000f1'),
  ('28000000-0000-0000-0000-000000000001','28000000-0000-0000-0000-0000000000e3','28000000-0000-0000-0000-0000000000f1');
insert into public.document_versions (tenant_id, document_id, version_number, file_name, file_type_code, storage_path, is_current) values
  ('28000000-0000-0000-0000-000000000001','28000000-0000-0000-0000-0000000000e1',1,'passport.pdf','pdf','docs/passport.pdf',true);

set local role authenticated;

-- ---------------------------------------------------------------------------------------------
-- The other branch. This is the hole that existed until this migration.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"28000000-0000-0000-0000-0000000000a2"}', true);

select is((select count(*)::int from public.bookings), 0,
  'the Suez employee cannot see the Giza booking -- the anchor, so the document results below mean something');

select is((select count(*)::int from public.documents), 0,
  'AND CANNOT SEE THE PASSPORT SCAN ATTACHED TO IT -- until this migration, every document in the company was readable by everyone in it');

select is((select count(*)::int from public.document_links), 0,
  '...nor even the link, which would otherwise disclose that the document exists and what it hangs off');

select is((select count(*)::int from public.document_versions), 0,
  '...nor the stored file path, which is the part that would actually retrieve the scan');

-- ---------------------------------------------------------------------------------------------
-- The uploader, in the right branch.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"28000000-0000-0000-0000-0000000000a1"}', true);

select is((select count(*)::int from public.documents), 3,
  'the uploader reads all three of their own documents');

select is((select count(*)::int from public.document_versions), 1,
  '...and the version behind them');

-- ---------------------------------------------------------------------------------------------
-- Confidentiality has to mean something beyond branch.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"28000000-0000-0000-0000-0000000000a3"}', true);

-- SPEC-145 corrected this rule. SPEC-144 granted finance ANY confidential document, which read the
-- flag as "sensitive, therefore finance" -- but canon 28 separates VIEW_FINANCIAL_DOCUMENTS (Finance
-- Manager: Yes) from VIEW_TRAVEL_DOCUMENTS (Finance Manager: *Optional*, and not granted) precisely
-- so that seeing the money does not mean seeing the passport. Finance now gets financial document
-- TYPES, confidential or not, and no travel documents at all.
select is((select count(*)::int from public.documents where document_type_code = 'invoice'), 1,
  'the finance manager reads the confidential INVOICE -- a financial document type, which is what VIEW_FINANCIAL_DOCUMENTS names');

select is((select count(*)::int from public.documents where document_type_code = 'passport' and is_confidential), 0,
  '...and NOT the confidential passport: "confidential" does not mean "financial", and canon marks travel documents Optional for this role');

select is((select count(*)::int from public.documents where document_type_code = 'passport' and not is_confidential), 0,
  '...nor the ordinary passport scan, which SPEC-145''s finance visibility of bookings would otherwise have leaked through the document link');

select is((select count(*)::int from public.documents), 1,
  '...so finance sees exactly one document here, and it is the financial one');

select * from finish();
rollback;
