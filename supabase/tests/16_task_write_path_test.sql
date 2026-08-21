-- pgTAP invariants: the Task write path is governed — authorization, canonical lifecycle, and
-- event emission — rather than being reachable only as a raw table write. Guard for the first
-- entity in the RPC-1 programme (SPEC-131).
--
-- Before this migration, `tasks` had no RPC at all: a direct PostgREST write was the only way to
-- create one, so CREATE_TASK / ASSIGN_TASK / COMPLETE_TASK were three of the 37 seeded permissions
-- enforced nowhere, no lifecycle rule applied, and no event was ever emitted.
--
-- The lifecycle assertions are taken from 26_state_machines.md, not invented here: `open ->
-- completed` is explicitly allowed ("tasks completed without a distinct in-progress step"), while
-- `completed -> in_progress` is not a listed transition, and `overdue` is marked System-set and so
-- is deliberately unreachable through the employee RPC.
create extension if not exists pgtap with schema extensions;

begin;
select plan(9);

insert into public.tenants (id, name, slug, status) values
  ('f0f00000-0000-0000-0000-00000000000a','Task Tenant','task-t','active');
insert into public.branches (id, tenant_id, name, slug) values
  ('f0f00000-0000-0000-0000-0000000000b1','f0f00000-0000-0000-0000-00000000000a','BR','task-br');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('f0f00000-0000-0000-0000-0000000000d1','f0f00000-0000-0000-0000-00000000000a','f0f00000-0000-0000-0000-0000000000b1','sales','DP');
insert into public.users (id, tenant_id, full_name, email, is_active) values
  ('f0f00000-0000-0000-0000-0000000000a1','f0f00000-0000-0000-0000-00000000000a','Owner','owner@example.com',true),
  ('f0f00000-0000-0000-0000-0000000000a2','f0f00000-0000-0000-0000-00000000000a','Other','other@example.com',true);
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('f0f00000-0000-0000-0000-0000000000c1','f0f00000-0000-0000-0000-00000000000a','person','Cust');

-- 1-3. The three RPCs exist and are reachable by `authenticated` but not by PUBLIC.
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname in ('create_task','assign_task','advance_task')),
  3,
  'the Task write path exists as three governed RPCs');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    cross join lateral aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) as g(grantor, grantee, privilege_type, is_grantable)
    where n.nspname = 'app' and p.proname in ('create_task','assign_task','advance_task')
      and g.privilege_type = 'EXECUTE' and g.grantee = 0),
  0,
  'none of the Task RPCs is executable by PUBLIC');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname in ('create_task','assign_task','advance_task')
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  3,
  'all three Task RPCs are executable by authenticated');

-- 4-6. Each RPC enforces its permission. Verified from source rather than by impersonation,
--      because app.authorize() resolves through auth.uid() which a pgTAP session does not have --
--      the permission NAMES are the contract, and three of them were previously enforced nowhere.
select ok(
  (select pg_get_functiondef(p.oid) ~ 'CREATE_TASK'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'create_task'),
  'create_task enforces CREATE_TASK');

select ok(
  (select pg_get_functiondef(p.oid) ~ 'ASSIGN_TASK'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'assign_task'),
  'assign_task enforces ASSIGN_TASK');

select ok(
  (select pg_get_functiondef(p.oid) ~ 'COMPLETE_TASK'
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'advance_task'),
  'advance_task enforces COMPLETE_TASK on its terminal transitions');

-- 7-8. The canonical lifecycle, asserted against the transition map the RPC actually carries.
select ok(
  (select pg_get_functiondef(p.oid) ~ '''in_progress'',\s*''completed'''
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'advance_task'),
  'in_progress -> completed is an allowed transition (canon 26)');

select is(
  (select (pg_get_functiondef(p.oid) ~ '''completed'',\s*''in_progress''')::text
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'advance_task'),
  'false',
  'completed is terminal -- completed -> in_progress is not reachable');

-- 9. `overdue` is System-set per canon, so it must not be an employee-reachable destination.
select is(
  (select (pg_get_functiondef(p.oid) ~ ',\s*''overdue'',')::text
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'advance_task'),
  'false',
  'overdue is not an employee-reachable destination (canon marks it System-set)');

select * from finish();
rollback;
