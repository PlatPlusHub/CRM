-- pgTAP invariants: the controlled vocabulary is authoritative AT THE POINT OF USE, not only in the
-- catalog table, and deactivation actually deactivates. Discovery-to-guard for VOCAB-1 / CAT-4,
-- reproduced live on 2026-08-21: tasks accepted task_type_code 'TOTALLY_MADE_UP', suppliers accepted
-- supplier_type_code 'MADE_UP_SUPPLIER', conversations accepted channel_code 'carrier_pigeon' --
-- because 35 of 72 tables have no RPC write path and nothing else validated those columns.
--
-- Every assertion here is behavioural: it attempts the write and requires the outcome. The
-- deactivation pair is the important one -- it proves the rule is "inactive values cannot be chosen
-- for new work, but history keeps what it already references", not the blunt "inactive is illegal"
-- that would make old rows uneditable.
create extension if not exists pgtap with schema extensions;

begin;
select plan(8);

insert into public.tenants (id, name, slug, status)
values ('bbbbbbbb-0000-0000-0000-000000000001','Vocab Tenant','vocab-tenant','active');
insert into public.users (id, tenant_id, full_name, email, is_active)
values ('bbbbbbbb-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000001','U','vocab@example.com',true);
insert into public.branches (id, tenant_id, name, slug)
values ('bbbbbbbb-0000-0000-0000-000000000003','bbbbbbbb-0000-0000-0000-000000000001','B','vocab-branch');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
values ('bbbbbbbb-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000003','sales','D');

-- 1-3. Invented codes are refused on tables that have no RPC write path.
select throws_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, title)
    values ('bbbbbbbb-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002',
            'bbbbbbbb-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000003',
            'TOTALLY_MADE_UP','open','T')$$,
  '23514', null,
  'an invented task_type_code is refused');

select throws_ok(
  $$insert into public.suppliers (tenant_id, name, supplier_type_code)
    values ('bbbbbbbb-0000-0000-0000-000000000001','S','MADE_UP_SUPPLIER')$$,
  '23514', null,
  'an invented supplier_type_code is refused');

select throws_ok(
  $$insert into public.conversations (tenant_id, channel_code, conversation_status_code)
    values ('bbbbbbbb-0000-0000-0000-000000000001','carrier_pigeon','open')$$,
  '23514', null,
  'an invented channel_code is refused');

-- 4. A genuine catalog value still works -- the guard must not block legitimate business writes.
select lives_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, priority_code, title)
    values ('bbbbbbbb-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002',
            'bbbbbbbb-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000003',
            'call_customer','open','high','Call the customer')$$,
  'a valid task_type_code / task_status_code / priority_code is accepted');

-- 5-7. Deactivation semantics (CAT-4). Deactivate a value, then prove the three behaviours that
-- together define the canonical rule.
update public.catalog_values set is_active = false
 where catalog_type_code = 'task_type_code' and code = 'send_quotation';

select throws_ok(
  $$insert into public.tasks (tenant_id, owner_user_id, owner_department_id, owner_branch_id,
       task_type_code, task_status_code, title)
    values ('bbbbbbbb-0000-0000-0000-000000000001','bbbbbbbb-0000-0000-0000-000000000002',
            'bbbbbbbb-0000-0000-0000-000000000004','bbbbbbbb-0000-0000-0000-000000000003',
            'send_quotation','open','T')$$,
  '23514', null,
  'a DEACTIVATED catalog value cannot be chosen for a new record');

insert into public.tasks (id, tenant_id, owner_user_id, owner_department_id, owner_branch_id,
    task_type_code, task_status_code, title)
values ('bbbbbbbb-0000-0000-0000-00000000000a','bbbbbbbb-0000-0000-0000-000000000001',
        'bbbbbbbb-0000-0000-0000-000000000002','bbbbbbbb-0000-0000-0000-000000000004',
        'bbbbbbbb-0000-0000-0000-000000000003','review_booking','open','Historical task');
update public.catalog_values set is_active = false
 where catalog_type_code = 'task_type_code' and code = 'review_booking';

select lives_ok(
  $$update public.tasks set title = 'Historical task, retitled'
     where id = 'bbbbbbbb-0000-0000-0000-00000000000a'$$,
  'a historical row referencing a since-deactivated value can still be edited');

select throws_ok(
  $$update public.tasks set task_type_code = 'send_quotation'
     where id = 'bbbbbbbb-0000-0000-0000-00000000000a'$$,
  '23514', null,
  'but that row cannot be MOVED onto a deactivated value');

-- 8. The trigger function itself must not be PUBLIC-executable (SPEC-124 invariant).
select is(
  (select count(*)::int
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) as g(grantor, grantee, privilege_type, is_grantable)
    where n.nspname = 'app' and p.proname = 'enforce_catalog_codes'
      and g.privilege_type = 'EXECUTE' and g.grantee = 0),
  0,
  'app.enforce_catalog_codes is not executable by PUBLIC');

select * from finish();
rollback;
