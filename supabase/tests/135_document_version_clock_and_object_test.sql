-- ATTACK-CLASSES: PRIVILEGE DOOR TENANT BUSINESS CONCURRENCY INPUT AUTH=N/A STATE=N/A REPLAY=N/A OBSERVABILITY=N/A
-- SPEC-231 / Batch 6 Slice 29. `document_versions` audited; DOC-7 and DOC-8 repaired. A superseded
-- version becomes a destruction candidate once `uploaded_at + retention_days` has passed, and the
-- period is the tenant's legal setting, costing MANAGE_TENANT_SETTINGS. The table door let any
-- CREATE_DOCUMENT_VERSION holder write that clock (DOC-7): backdating destroyed a version the policy
-- keeps, forward-dating took a due version off the executor's list. And two concurrent inserts derived
-- one object key for two rows (DOC-8), so retention of one row could delete the other's bytes.
-- `20260927140000` derives the clock on INSERT, freezes it on UPDATE, and makes the object key unique.
-- A mutation installs the pre-repair trigger and drops the index in a savepoint, watches the backdate
-- make the owner's version claimable and a second row land on one key, and restores both.
-- AUTH=N/A: both doors accept CREATE_DOCUMENT_VERSION at `aal1` (SPEC-216); the freeze is not a
-- step-up control.
-- STATE=N/A: a version has no lifecycle column; the parent's state is `guard_parent_state_allows_write`'s,
-- and "the current version is never eligible" is pinned by `49_...` and `116_...`.
-- REPLAY=N/A: no token, nonce or idempotency key lives on a version.
-- OBSERVABILITY=N/A: nothing reads a version event outside the event registry; the refusals leave
-- nothing to observe. Trainee refusal, path and number derivation and renumbering are `46_...`'s.
create extension if not exists pgtap with schema extensions;

begin;
select plan(20);

insert into auth.users (id,email,email_confirmed_at) values
  ('13500000-0000-0000-0000-0000000000a1','owner@dv135.test',now()),
  ('13500000-0000-0000-0000-0000000000a3','emp@dv135.test',now());
insert into public.tenants (id,name,slug,status) values
  ('13500000-0000-0000-0000-000000000001','DV135 Travel','dv135-travel','active'),
  ('13500000-0000-0000-0000-000000000002','DV135 Other','dv135-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise' and t.id::text like '13500000-%';
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('13500000-0000-0000-0000-000000000011','13500000-0000-0000-0000-000000000001','Owner','owner@dv135.test',true,'13500000-0000-0000-0000-0000000000a1'),
  ('13500000-0000-0000-0000-000000000013','13500000-0000-0000-0000-000000000001','Employee','emp@dv135.test',true,'13500000-0000-0000-0000-0000000000a3');
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '13500000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('13500000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('13500000-0000-0000-0000-000000000013','employee')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.suppliers (id,tenant_id,supplier_type_code,name) values
  ('13500000-0000-0000-0000-0000000005a1','13500000-0000-0000-0000-000000000001','airline','DV135 Air');
-- Session-less fixture: a version in the other tenant.
insert into public.documents (id,tenant_id,document_type_code,title,lifecycle_status_code) values
  ('13500000-0000-0000-0000-0000000000c9','13500000-0000-0000-0000-000000000002','contract','Other contract','active');
insert into public.document_versions (id,tenant_id,document_id,version_number,file_name,file_type_code,is_current,uploaded_at) values
  ('13500000-0000-0000-0000-0000000000e9','13500000-0000-0000-0000-000000000002','13500000-0000-0000-0000-0000000000c9',1,'other.pdf','pdf',true,'2026-01-01');

create temp table s135 (k text primary key, v text) on commit drop;
insert into s135 values
  ('fn', (select md5(pg_get_functiondef('app.enforce_document_version_integrity'::regproc))));
grant select, insert on s135 to authenticated;

-- The owner uploads a contract, replaces it, and sets the counsel-advised 3650-day period.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13500000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
insert into s135 select 'doc', app.upload_document('contract','Supplier contract','orig.pdf','pdf','supplier','13500000-0000-0000-0000-0000000005a1',100);
insert into s135 select 'v1', current_version_id from public.documents where id = (select v from s135 where k = 'doc')::uuid;
insert into s135 select 'v2', app.add_document_version((select v from s135 where k = 'doc')::uuid,'amended.pdf','pdf',120);
insert into public.document_retention_policies (tenant_id, document_type_code, retention_days, reason, is_active)
values ('13500000-0000-0000-0000-000000000001','contract',3650,'counsel: ten years',true);
reset role;
insert into s135 select 'v1_at', uploaded_at::text from public.document_versions where id = (select v from s135 where k = 'v1')::uuid;

-- ================================================================================================
-- 1-4. The population: the employee writes versions but not retention, sees both of the owner's
--      versions, and cannot touch the policy; v1 is superseded, so only its age protects it.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13500000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select is(array[app.has_permission('CREATE_DOCUMENT_VERSION'), app.has_permission('MANAGE_TENANT_SETTINGS')],
  array[true,false],
  'CONTROL: the employee writes document versions and does not hold MANAGE_TENANT_SETTINGS');
select is((select count(*)::int from public.document_versions where document_id = (select v from s135 where k = 'doc')::uuid), 2,
  'CONTROL: the employee sees both of the owner''s versions');
update public.document_retention_policies set retention_days = 1 where tenant_id = '13500000-0000-0000-0000-000000000001';
reset role;
select is((select retention_days from public.document_retention_policies where tenant_id = '13500000-0000-0000-0000-000000000001'), 3650,
  'CONTROL: the retention period is out of the employee''s reach');
select is((select dv.is_current or d.current_version_id = dv.id from public.document_versions dv
            join public.documents d on d.id = dv.document_id where dv.id = (select v from s135 where k = 'v1')::uuid), false,
  'CONTROL: v1 is superseded, so its age alone decides when retention may destroy it');

-- ================================================================================================
-- 5-9. DOC-7: the retention clock is the server's, on INSERT and on UPDATE.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13500000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok(format($$update public.document_versions set uploaded_at = '2000-01-01' where id = %L$$, (select v from s135 where k = 'v1')),
  '42501','a document version''s identity is immutable: add a new version instead of rewriting one',
  'DOOR: the employee cannot backdate the owner''s superseded version into retention (DOC-7)');
select lives_ok(format($$insert into public.document_versions (tenant_id, document_id, file_name, file_type_code, is_current, uploaded_at)
                         values ('13500000-0000-0000-0000-000000000001', %L, 'late.pdf', 'pdf', false, '2000-01-01')$$, (select v from s135 where k = 'doc')),
  'CONTROL: the employee may still add a version at the table');
reset role;
select is((select uploaded_at from public.document_versions where document_id = (select v from s135 where k = 'doc')::uuid and file_name = 'late.pdf'), now(),
  'INPUT: ...born at the server''s clock, whatever it claimed (DOC-7)');
select is((select uploaded_at::text from public.document_versions where id = (select v from s135 where k = 'v1')::uuid), (select v from s135 where k = 'v1_at'),
  'the owner''s version keeps its real upload time');
create temp table r9 on commit drop as select app.reconcile_document_storage() as j;
select is((select count(*)::int from public.document_storage_findings f
            where f.tenant_id = '13500000-0000-0000-0000-000000000001' and f.finding_type_code = 'retention_expired'), 0,
  'BUSINESS: nothing of this tenant is a destruction candidate under its ten-year policy');

-- ================================================================================================
-- 10-13. Retention still works, and a due version cannot be taken off the list.
-- ================================================================================================
select set_config('request.jwt.claims','',true);
select lives_ok(format($$update public.document_versions set uploaded_at = now() - interval '4000 days' where id = %L$$, (select v from s135 where k = 'v1')),
  'CONTROL: the session-less platform path still writes the clock');
create temp table r11 on commit drop as select app.reconcile_document_storage() as j;
select is((select count(*)::int from app.claim_storage_actions(500) c
            where c.storage_path = (select storage_path from public.document_versions where id = (select v from s135 where k = 'v1')::uuid)), 1,
  'BUSINESS: a version eleven years old is due under the ten-year policy and the executor may claim it');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13500000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok(format($$update public.document_versions set uploaded_at = '2999-01-01' where id = %L$$, (select v from s135 where k = 'v1')),
  '42501','a document version''s identity is immutable: add a new version instead of rewriting one',
  'DOOR: the employee cannot forward-date it off the list -- a hold without the hold''s authority (DOC-7)');
select lives_ok(format($$select app.add_document_version(%L, 'third.pdf', 'pdf', 10)$$, (select v from s135 where k = 'doc')),
  'CONTROL: adding a version, which demotes the current one by UPDATE, still works');

-- ================================================================================================
-- 14-15. DOC-8: one object key names one version.
-- ================================================================================================
reset role;
select set_config('request.jwt.claims','',true);
select is((select count(*)::int from pg_index i where i.indrelid = 'public.document_versions'::regclass and i.indisunique
            and i.indpred is null and i.indnatts = 1
            and i.indkey[0] = (select attnum from pg_attribute where attrelid = 'public.document_versions'::regclass and attname = 'storage_path')), 1,
  'CONCURRENCY basis: `storage_path` is unique, so two racing inserts that derive the same version number cannot both commit');
select throws_ok(format($$insert into public.document_versions (tenant_id, document_id, version_number, file_name, file_type_code, is_current)
                          values ('13500000-0000-0000-0000-000000000001', %L, 2, 'twin.pdf', 'pdf', false)$$, (select v from s135 where k = 'doc')),
  '23505', null,
  'CONCURRENCY: a second row for an existing object key is refused (DOC-8)');

-- ================================================================================================
-- 16. TENANT: another tenant's version cannot be reached.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13500000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
update public.document_versions set file_name = 'hijack.pdf' where id = '13500000-0000-0000-0000-0000000000e9';
reset role;
select is((select file_name from public.document_versions where id = '13500000-0000-0000-0000-0000000000e9'), 'other.pdf',
  'TENANT: the employee''s UPDATE of another tenant''s version changes nothing');

-- ================================================================================================
-- 17-20. Mutation: the pre-repair trigger is installed and the key index dropped in a savepoint.
-- ================================================================================================
select set_config('request.jwt.claims','',true);
update public.document_versions set uploaded_at = (select v from s135 where k = 'v1_at')::timestamptz where id = (select v from s135 where k = 'v1')::uuid;
delete from public.document_storage_findings where tenant_id = '13500000-0000-0000-0000-000000000001';
savepoint m1;
create or replace function app.enforce_document_version_integrity()
returns trigger language plpgsql set search_path = '' as $fn$
declare v_doc_type text;
begin
    if (select auth.uid()) is null then
        if tg_op = 'INSERT' and new.storage_path is null then
            new.storage_path := app.document_storage_path(new.tenant_id, new.document_id, coalesce(new.version_number, 1));
        end if;
        return new;
    end if;
    select d.document_type_code into v_doc_type from public.documents d where d.id = new.document_id and d.tenant_id = new.tenant_id;
    if v_doc_type = 'payment_proof' then perform app.authorize('MANAGE_TENANT_SETTINGS');
    else perform app.authorize('CREATE_DOCUMENT_VERSION'); end if;
    if tg_op = 'INSERT' then
        new.version_number := coalesce((select max(dv.version_number) from public.document_versions dv
                                         where dv.document_id = new.document_id and dv.tenant_id = new.tenant_id), 0) + 1;
        new.storage_path := app.document_storage_path(new.tenant_id, new.document_id, new.version_number);
        new.uploaded_by := app.current_user_id();
        return new;
    end if;
    if new.document_id is distinct from old.document_id or new.tenant_id is distinct from old.tenant_id
       or new.version_number is distinct from old.version_number or new.storage_path is distinct from old.storage_path
       or new.uploaded_by is distinct from old.uploaded_by then
        raise exception 'a document version''s identity is immutable: add a new version instead of rewriting one'
            using errcode = 'insufficient_privilege';
    end if;
    return new;
end
$fn$;
drop index public.document_versions_storage_path_idx;
select isnt((select md5(pg_get_functiondef('app.enforce_document_version_integrity'::regproc))), (select v from s135 where k = 'fn'),
  'MUTANT INSTALLED: the trigger neither derives nor freezes the clock, and the key index is gone');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13500000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
update public.document_versions set uploaded_at = '2000-01-01' where id = (select v from s135 where k = 'v1')::uuid;
reset role;
select set_config('request.jwt.claims','',true);
create temp table r18 on commit drop as select app.reconcile_document_storage() as j;
select is((select count(*)::int from app.claim_storage_actions(500) c
            where c.storage_path = (select storage_path from public.document_versions where id = (select v from s135 where k = 'v1')::uuid)), 1,
  'MUTANT: the employee''s backdate makes the owner''s version claimable for destruction, ten-year policy notwithstanding');
select lives_ok(format($$insert into public.document_versions (tenant_id, document_id, version_number, file_name, file_type_code, is_current)
                         values ('13500000-0000-0000-0000-000000000001', %L, 2, 'twin.pdf', 'pdf', false)$$, (select v from s135 where k = 'doc')),
  'MUTANT: and a second row lands on an existing object key');
rollback to savepoint m1;
select is(array[(select md5(pg_get_functiondef('app.enforce_document_version_integrity'::regproc))),
                (select count(*)::text from pg_indexes where indexname = 'document_versions_storage_path_idx'),
                (select uploaded_at::text from public.document_versions where id = (select v from s135 where k = 'v1')::uuid)],
  array[(select v from s135 where k = 'fn'), '1', (select v from s135 where k = 'v1_at')],
  'RESTORED: the trigger is byte-identical, the index is back, and no mutant backdate survived');

select * from finish();
rollback;
