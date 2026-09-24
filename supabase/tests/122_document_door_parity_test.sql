-- pgTAP: SPEC-216 / DOC-4, DOC-5, DOC-6, DOC-LC-3 -- Batch 6 slice 16, `public.documents`.
--
-- The table door may not give a document a state its own RPCs cannot give it. `authenticated`
-- holds table-level INSERT and UPDATE and every document RPC is SECURITY INVOKER through that same
-- grant, so PostgREST serves the table beside them; before `20260924140000` the door judged the
-- capability and the transition and none of the state the RPCs define.
--
-- ATTACK-CLASSES: DOOR STATE PRIVILEGE BUSINESS TENANT=N/A CONCURRENCY=N/A REPLAY=N/A
--   TENANT=N/A -- every column this guard judges is tenant-qualified by a composite FK and by
--     `scope_isolation`; the guard adds no tenant predicate that could be the refuser.
--   CONCURRENCY=N/A -- the guard reads one row's own columns and one version row; it keeps no
--     counter, lease or balance another transaction could race.
--   REPLAY=N/A -- nothing here is single-use; a repeated statement meets the same rule.
--   AUTH, INPUT and OBSERVABILITY are NOT declared: both doors behave alike at `aal1`, the value
--   CHECKs are older files', and a document created at the door records no `document_uploaded` --
--   probed and not pinned, because its creator is server-derived (61) and it carries no file.
--
-- THE ACTORS are chosen so no other control can be the refuser. `emp` is an `employee` at `aal2`:
-- UPLOAD_DOCUMENT and CREATE_DOCUMENT_VERSION, and neither ARCHIVE_DOCUMENT nor
-- MANAGE_TENANT_SETTINGS. `fm` is a `finance_manager`: it sees the confidential payment proof
-- (VIEW_FINANCIAL_DOCUMENTS) and holds no MANAGE_TENANT_SETTINGS. `bm` is a `branch_manager` holding
-- ARCHIVE_DOCUMENT, so its refusal is the state rule and not a permission. `owner` holds everything.
create extension if not exists pgtap with schema extensions;

begin;
select plan(25);

insert into auth.users (id, email) values
  ('12200000-0000-0000-0000-0000000000a1','emp@d122.test'),
  ('12200000-0000-0000-0000-0000000000a2','owner@d122.test'),
  ('12200000-0000-0000-0000-0000000000a3','fm@d122.test'),
  ('12200000-0000-0000-0000-0000000000a4','bm@d122.test');
insert into public.tenants (id, name, slug, status) values
  ('12200000-0000-0000-0000-000000000001','D122 Travel','d122-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '12200000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('12200000-0000-0000-0000-00000000000a','12200000-0000-0000-0000-000000000001','Cairo','d122-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('12200000-0000-0000-0000-0000000000c1','12200000-0000-0000-0000-000000000001','12200000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('12200000-0000-0000-0000-000000000011','12200000-0000-0000-0000-000000000001','Emp','emp@d122.test',true,'12200000-0000-0000-0000-0000000000a1'),
  ('12200000-0000-0000-0000-000000000012','12200000-0000-0000-0000-000000000001','Owner','owner@d122.test',true,'12200000-0000-0000-0000-0000000000a2'),
  ('12200000-0000-0000-0000-000000000013','12200000-0000-0000-0000-000000000001','FM','fm@d122.test',true,'12200000-0000-0000-0000-0000000000a3'),
  ('12200000-0000-0000-0000-000000000014','12200000-0000-0000-0000-000000000001','BM','bm@d122.test',true,'12200000-0000-0000-0000-0000000000a4');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '12200000-0000-0000-0000-000000000001', u, '12200000-0000-0000-0000-00000000000a', '12200000-0000-0000-0000-0000000000c1', true
from unnest(array['12200000-0000-0000-0000-000000000011'::uuid,'12200000-0000-0000-0000-000000000012',
                  '12200000-0000-0000-0000-000000000013','12200000-0000-0000-0000-000000000014']) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '12200000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('12200000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('12200000-0000-0000-0000-000000000012'::uuid,'owner'),
             ('12200000-0000-0000-0000-000000000013'::uuid,'finance_manager'),
             ('12200000-0000-0000-0000-000000000014'::uuid,'branch_manager')) v(u, rc)
join public.roles r on r.code = v.rc;
insert into public.suppliers (id, tenant_id, name, supplier_type_code) values
  ('12200000-0000-0000-0000-0000000000e1','12200000-0000-0000-0000-000000000001','Nile Air','airline');

-- Written as `postgres`, which the guard admits: the owner's confidential contract and its version,
-- which `emp` cannot see.
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code, is_confidential, created_by) values
  ('12200000-0000-0000-0000-0000000000d1','12200000-0000-0000-0000-000000000001','contract','Owner contract','active',true,'12200000-0000-0000-0000-000000000012');
insert into public.document_versions (id, tenant_id, document_id, version_number, file_name, file_type_code, storage_path, is_current) values
  ('12200000-0000-0000-0000-0000000000f1','12200000-0000-0000-0000-000000000001','12200000-0000-0000-0000-0000000000d1',1,'o.pdf','pdf','d122/o1.pdf',true);
update public.documents set current_version_id = '12200000-0000-0000-0000-0000000000f1' where id = '12200000-0000-0000-0000-0000000000d1';

-- The version `title` currently points at, and whether it is that document's own current one.
create function pg_temp.d122_ptr(p_title text) returns text language sql as $$
  select coalesce(dv.version_number::text, '-') || '/' || coalesce((dv.document_id = d.id and dv.is_current)::text, '-')
  from public.documents d left join public.document_versions dv on dv.id = d.current_version_id
  where d.tenant_id = '12200000-0000-0000-0000-000000000001' and d.title = p_title
$$;
grant execute on function pg_temp.d122_ptr(text) to authenticated;

-- =============================================================================================
-- 1-3. THE ACTOR, and the doors that stay open.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"12200000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;

select ok(app.has_permission('UPLOAD_DOCUMENT') and app.has_permission('CREATE_DOCUMENT_VERSION')
          and not app.has_permission('ARCHIVE_DOCUMENT') and not app.has_permission('MANAGE_TENANT_SETTINGS'),
  'PREMISE: emp holds UPLOAD_DOCUMENT and CREATE_DOCUMENT_VERSION and neither ARCHIVE_DOCUMENT nor MANAGE_TENANT_SETTINGS');

select lives_ok($$select app.upload_document('contract','Emp contract','a.pdf','pdf','supplier','12200000-0000-0000-0000-0000000000e1',100,null,false);
                  select app.upload_document('contract','Emp visa letter','c.pdf','pdf','supplier','12200000-0000-0000-0000-0000000000e1',100,null,false)$$,
  'POSITIVE CONTROL: the RPC still creates a document and points it at its first version');

select lives_ok($$insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code)
                  values ('12200000-0000-0000-0000-000000000001','other','Door doc','active');
                  update public.documents set title = 'Door doc, renamed' where title = 'Door doc'$$,
  'POSITIVE CONTROL: the table door still creates a document in the state the RPCs create one, and its title stays editable -- the door is held to the RPCs, not closed');

-- =============================================================================================
-- 4-8. THE ENTRY STATE. Every creating RPC births a document active, unarchived and unheld.
-- =============================================================================================
select throws_ok($$insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code,
                     legal_hold_active, legal_hold_reason, legal_hold_changed_at, legal_hold_changed_by)
                   values ('12200000-0000-0000-0000-000000000001','contract','Held','active',
                     true,'forged by emp','2019-01-01','12200000-0000-0000-0000-000000000012')$$,
  '23514', null,
  'DOC-4: a document cannot be born under a legal hold -- before 20260924140000 an employee refused placing a hold by UPDATE created one held here, naming the owner as placer, dated 2019, with no event');

select throws_ok($$insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code,
                     legal_hold_reason, legal_hold_changed_at, legal_hold_changed_by)
                   values ('12200000-0000-0000-0000-000000000001','contract','Released','active',
                     'released by court order','2019-01-01','12200000-0000-0000-0000-000000000012')$$,
  '23514', null,
  'DOC-4: nor born carrying the evidence of a hold -- a "release" the owner never made');

select throws_ok($$insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code,
                     is_archived, archived_at, archived_by, archive_reason)
                   values ('12200000-0000-0000-0000-000000000001','contract','Born archived','active',
                     true,'2019-01-01','12200000-0000-0000-0000-000000000012','forged')$$,
  '23514', null,
  'ARCH-2 on documents: a document cannot be born archived, with an archiver and a time of the caller''s choosing');

select throws_ok($$insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code)
                   values ('12200000-0000-0000-0000-000000000001','contract','Born superseded','superseded')$$,
  '23514', null,
  'ENTRY-1 on documents: a document cannot be born in a lifecycle state -- here one nothing writes (DOC-LC-2)');

select throws_ok($$insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code, current_version_id)
                   values ('12200000-0000-0000-0000-000000000001','contract','Borrowed','active','12200000-0000-0000-0000-0000000000f1')$$,
  '23514', null,
  'DOC-5: a new document has no version, so it cannot be born pointing at one -- here the owner''s confidential version, which the FK alone admitted');

-- =============================================================================================
-- 9-13. THE VERSION POINTER. Only the version write path moves it, and only to its own current one.
-- =============================================================================================
select throws_ok($$update public.documents
                      set current_version_id = (select current_version_id from public.documents where title = 'Emp visa letter')
                    where title = 'Emp contract'$$,
  '23514', null,
  'DOC-5: a document cannot be pointed at ANOTHER document''s current version -- one the caller can see, so the refusal is the rule and not visibility');

select throws_ok($$update public.documents set current_version_id = null where title = 'Emp contract'$$,
  '23514', null,
  'DOC-5: nor pointed at nothing');

select lives_ok($$select app.add_document_version((select id from public.documents where title = 'Emp contract'), 'a2.pdf','pdf',100)$$,
  'POSITIVE CONTROL: app.add_document_version still moves the pointer to the version it has just made current');

select throws_ok($$update public.documents
                      set current_version_id = (select dv.id from public.document_versions dv join public.documents d on d.id = dv.document_id
                                                 where d.title = 'Emp contract' and dv.version_number = 1)
                    where title = 'Emp contract'$$,
  '23514', null,
  'DOC-5: nor pointed back at its own superseded version, which would make the pointer and is_current disagree');

select is(pg_temp.d122_ptr('Emp contract'), '2/true',
  'NON-MUTATION: after three refusals the document still points at its own current version, version 2');

-- =============================================================================================
-- 14-17. DOC-6: the payment-proof class cannot be left by retyping.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"12200000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select lives_ok($$select app.upload_subscription_payment_proof('proof.pdf','pdf',100,'bank transfer')$$,
  'POSITIVE CONTROL: the owner files a subscription payment proof');

reset role;
select set_config('request.jwt.claims','{"sub":"12200000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
set local role authenticated;
select throws_ok($$update public.documents set document_type_code = 'receipt', title = 'retyped'
                    where document_type_code = 'payment_proof'$$,
  '23514', null,
  'DOC-6: a finance manager cannot retype the payment proof out of its class -- before 20260924140000 this succeeded, because the capability guard reads the NEW type only');

select throws_ok($$select app.add_document_version((select id from public.documents where document_type_code = 'payment_proof'), 'forged.pdf','pdf',100)$$,
  '42501', null,
  'DOC-6: so the proof''s file still costs MANAGE_TENANT_SETTINGS -- before, the retype let this role replace the file the Platform Owner reviews');

reset role;
select is((select d.document_type_code || '/' || count(dv.id) from public.documents d
             join public.document_versions dv on dv.document_id = d.id
            where d.tenant_id = '12200000-0000-0000-0000-000000000001' and d.title like 'Subscription payment proof%'
            group by d.document_type_code),
  'payment_proof/1',
  'NON-MUTATION: the proof is still a payment_proof with its one original version');

-- =============================================================================================
-- 18-21. DOC-LC-3: `archived` implies `is_archived`, on every door.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"12200000-0000-0000-0000-0000000000a4","aal":"aal2"}',true);
set local role authenticated;
select lives_ok($$select app.archive_document((select id from public.documents where title = 'Emp contract'), 'superseded contract')$$,
  'POSITIVE CONTROL: app.archive_document still archives, moving both representations together');

select throws_ok($$update public.documents set is_archived = false where title = 'Emp contract'$$,
  '23514', null,
  'DOC-LC-3: an ARCHIVE_DOCUMENT holder cannot move the boolean back alone -- before, this left archived/false, a document neither write path will version');

select is((select lifecycle_status_code || '/' || is_archived from public.documents where title = 'Emp contract'),
  'archived/true', 'NON-MUTATION: the document stays archived/true');

select lives_ok($$update public.documents set is_archived = true where title = 'Emp visa letter';
                  update public.documents set is_archived = false where title = 'Emp visa letter'$$,
  'POSITIVE CONTROL: on a document still ACTIVE the boolean stays bidirectional for an archiver -- the constraint names the archived status only, as DOC-LC-3 was resolved');

-- =============================================================================================
-- 22-25. What stays governed exactly as before.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"12200000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select lives_ok($$select app.set_document_legal_hold((select id from public.documents where title = 'Emp visa letter'), true, 'litigation')$$,
  'POSITIVE CONTROL: a legal hold is still placed on an existing document through its RPC');

reset role;
select is((select legal_hold_active::text || '/' || legal_hold_changed_by::text || '/'
                  || (select count(*) from public.events e where e.entity_id = d.id and e.event_type_code = 'document_legal_hold_placed')
             from public.documents d where d.title = 'Emp visa letter'),
  'true/12200000-0000-0000-0000-000000000012/1',
  '...stamped with its real placer and recorded by exactly one event');

select ok((select tgtype = 23 from pg_trigger where tgname = 'documents_guard_integrity' and tgrelid = 'public.documents'::regclass)
          and not has_function_privilege('authenticated', 'app.guard_document_integrity()', 'EXECUTE'),
  'the guard is BEFORE INSERT OR UPDATE FOR EACH ROW, and nobody can call it directly');

select is((select count(*)::int from public.documents d where d.lifecycle_status_code = 'archived' and not d.is_archived), 0,
  'COMPLETENESS: no document anywhere is archived/false');

select finish();
rollback;
