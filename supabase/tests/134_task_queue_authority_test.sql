-- ATTACK-CLASSES: PRIVILEGE DOOR TENANT AUTH STATE INPUT=N/A BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
-- SPEC-230 / Batch 6 Slice 28. `tasks` audited; TASK-4 repaired. A task's accountable owner is the
-- triple owner / department / branch, and `scope_isolation` supervises it by the last two: the
-- department queue and the branch. `app.assign_task` charges ASSIGN_TASK to move any of the three;
-- the table door used to charge it only for the owner (TASK-1), so an employee moved their own task
-- out of their manager's queue. `20260927130000` widens TASK-1's guard to the triple. This file pins
-- that refusal on every column, the RPC's matching refusal, what legitimately stays open, and the
-- surface's other refusals (tenant, step-up, DELETE, the non-holder, the state machine). A mutation
-- installs the pre-repair guard in a savepoint, watches the move land, and restores it byte for byte.
-- It also pins two OPEN defects as they stand, not as desired behaviour; each assertion fails when its
-- finding is repaired: ENTRY-1 (a user DENIED COMPLETE_TASK creates a task born `completed`) and
-- ARCH-2 (a user without ARCHIVE_RECORD creates a task born archived under another user's name).
-- INPUT=N/A: catalog codes and the related-entity reference are pinned by `12_...` and `15_...`.
-- BUSINESS=N/A: no money, no PII, and no function, view or trigger reads a task outside its own RPCs.
-- CONCURRENCY=N/A: no counter, balance or uniqueness is derived from a task.
-- REPLAY=N/A: no token, nonce or idempotency key lives on a task.
-- OBSERVABILITY=N/A: the direct door emits no task event (CAMP-4's shape), and nothing reads task
-- events; TASK-4's refusal leaves nothing to observe.
create extension if not exists pgtap with schema extensions;

begin;
select plan(30);

insert into auth.users (id,email,email_confirmed_at) values
  ('13400000-0000-0000-0000-0000000000a1','owner@tq134.test',now()),
  ('13400000-0000-0000-0000-0000000000a2','dm@tq134.test',now()),
  ('13400000-0000-0000-0000-0000000000a3','emp@tq134.test',now()),
  ('13400000-0000-0000-0000-0000000000a4','denied@tq134.test',now()),
  ('13400000-0000-0000-0000-0000000000a5','trainee@tq134.test',now());
insert into public.tenants (id,name,slug,status) values
  ('13400000-0000-0000-0000-000000000001','TQ134 Travel','tq134-travel','active'),
  ('13400000-0000-0000-0000-000000000002','TQ134 Other','tq134-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise' and t.id::text like '13400000-%';
insert into public.branches (id,tenant_id,name,slug) values
  ('13400000-0000-0000-0000-0000000000b1','13400000-0000-0000-0000-000000000001','Cairo','tq134-cairo'),
  ('13400000-0000-0000-0000-0000000000b2','13400000-0000-0000-0000-000000000001','Giza','tq134-giza'),
  ('13400000-0000-0000-0000-0000000000b9','13400000-0000-0000-0000-000000000002','Other','tq134-other-b');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('13400000-0000-0000-0000-0000000000d1','13400000-0000-0000-0000-000000000001','13400000-0000-0000-0000-0000000000b1','sales','Cairo Sales'),
  ('13400000-0000-0000-0000-0000000000d2','13400000-0000-0000-0000-000000000001','13400000-0000-0000-0000-0000000000b2','sales','Giza Sales'),
  ('13400000-0000-0000-0000-0000000000d9','13400000-0000-0000-0000-000000000002','13400000-0000-0000-0000-0000000000b9','sales','Other Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('13400000-0000-0000-0000-000000000011','13400000-0000-0000-0000-000000000001','Owner','owner@tq134.test',true,'13400000-0000-0000-0000-0000000000a1'),
  ('13400000-0000-0000-0000-000000000012','13400000-0000-0000-0000-000000000001','Dept Manager','dm@tq134.test',true,'13400000-0000-0000-0000-0000000000a2'),
  ('13400000-0000-0000-0000-000000000013','13400000-0000-0000-0000-000000000001','Employee','emp@tq134.test',true,'13400000-0000-0000-0000-0000000000a3'),
  ('13400000-0000-0000-0000-000000000014','13400000-0000-0000-0000-000000000001','Denied','denied@tq134.test',true,'13400000-0000-0000-0000-0000000000a4'),
  ('13400000-0000-0000-0000-000000000015','13400000-0000-0000-0000-000000000001','Trainee','trainee@tq134.test',true,'13400000-0000-0000-0000-0000000000a5'),
  ('13400000-0000-0000-0000-000000000091','13400000-0000-0000-0000-000000000002','Other Owner','other@tq134.test',true,null);
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type,branch_id,department_id)
select '13400000-0000-0000-0000-000000000001', v.u, r.id, v.sc, v.b, v.d
from (values ('13400000-0000-0000-0000-000000000011'::uuid,'owner','tenant',null::uuid,null::uuid),
             ('13400000-0000-0000-0000-000000000012','department_manager','department','13400000-0000-0000-0000-0000000000b1','13400000-0000-0000-0000-0000000000d1'),
             ('13400000-0000-0000-0000-000000000013','employee','tenant',null,null),
             ('13400000-0000-0000-0000-000000000014','employee','tenant',null,null),
             ('13400000-0000-0000-0000-000000000015','trainee','tenant',null,null)) v(u,rc,sc,b,d)
join public.roles r on r.code = v.rc;
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary)
select '13400000-0000-0000-0000-000000000001', u, '13400000-0000-0000-0000-0000000000b1', '13400000-0000-0000-0000-0000000000d1', true
from unnest(array['13400000-0000-0000-0000-000000000012','13400000-0000-0000-0000-000000000013',
                  '13400000-0000-0000-0000-000000000014','13400000-0000-0000-0000-000000000015']::uuid[]) u;
insert into public.user_permission_grants (tenant_id,user_id,permission_id,effect,reason)
select '13400000-0000-0000-0000-000000000001','13400000-0000-0000-0000-000000000014',p.id,'deny','SPEC-230 fixture'
from public.permissions p where p.key = 'COMPLETE_TASK';
-- Session-less fixtures: the employee's queue task, a task for the completion control, one in the other tenant.
insert into public.tasks (id,tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title) values
  ('13400000-0000-0000-0000-0000000000e1','13400000-0000-0000-0000-000000000001','13400000-0000-0000-0000-000000000013','13400000-0000-0000-0000-0000000000d1','13400000-0000-0000-0000-0000000000b1','follow_up','open','Assigned to the employee'),
  ('13400000-0000-0000-0000-0000000000e2','13400000-0000-0000-0000-000000000001','13400000-0000-0000-0000-000000000014','13400000-0000-0000-0000-0000000000d1','13400000-0000-0000-0000-0000000000b1','follow_up','open','Assigned to the denied employee'),
  ('13400000-0000-0000-0000-0000000000e9','13400000-0000-0000-0000-000000000002','13400000-0000-0000-0000-000000000091','13400000-0000-0000-0000-0000000000d9','13400000-0000-0000-0000-0000000000b9','follow_up','open','Other tenant');

create temp table s134 (k text primary key, v text) on commit drop;
insert into s134 values ('guard', (select md5(pg_get_functiondef('app.guard_task_reassignment'::regproc))));
grant select on s134 to authenticated;

-- ================================================================================================
-- 1-4. The population: the employee works tasks but cannot assign them, the department manager
--      supervises the employee's task through the department queue, and the denied employee is refused
--      completion by the RPC.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select is(array[app.has_permission('CREATE_TASK'), app.has_permission('COMPLETE_TASK'),
                app.has_permission('ASSIGN_TASK'), app.has_permission('ARCHIVE_RECORD')],
  array[true,true,false,false],
  'CONTROL: the employee creates and completes tasks, and holds neither ASSIGN_TASK nor ARCHIVE_RECORD');
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select is((select count(*)::int from public.tasks where id = '13400000-0000-0000-0000-0000000000e1'), 1,
  'CONTROL: the department manager sees the employee''s task through the department queue');
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a4","aal":"aal2"}',true);
select is(array[app.has_permission('CREATE_TASK'), app.has_permission('COMPLETE_TASK')], array[true,false],
  'CONTROL: the denied employee creates tasks and is explicitly denied COMPLETE_TASK');
select throws_ok($$select app.advance_task('13400000-0000-0000-0000-0000000000e2','completed')$$,
  '42501','permission denied: COMPLETE_TASK',
  'CONTROL: the RPC refuses the denied employee completing their task');

-- ================================================================================================
-- 5-10. TASK-4: moving a task's department or branch is a change of hands, on both doors.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok($$select app.assign_task('13400000-0000-0000-0000-0000000000e1','13400000-0000-0000-0000-000000000013',
                                          '13400000-0000-0000-0000-0000000000d2','13400000-0000-0000-0000-0000000000b2')$$,
  '42501','permission denied: ASSIGN_TASK',
  'PRIVILEGE: the RPC refuses the employee moving their own task to another branch and department');
select throws_ok($$update public.tasks set owner_department_id = '13400000-0000-0000-0000-0000000000d2',
                                          owner_branch_id = '13400000-0000-0000-0000-0000000000b2'
                   where id = '13400000-0000-0000-0000-0000000000e1'$$,
  '42501','permission denied: ASSIGN_TASK',
  'DOOR: the table refuses the same move (TASK-4)');
select throws_ok($$update public.tasks set owner_department_id = '13400000-0000-0000-0000-0000000000d2'
                   where id = '13400000-0000-0000-0000-0000000000e1'$$,
  '42501','permission denied: ASSIGN_TASK',
  'DOOR: moving the department alone is refused');
select throws_ok($$update public.tasks set owner_branch_id = '13400000-0000-0000-0000-0000000000b2'
                   where id = '13400000-0000-0000-0000-0000000000e1'$$,
  '42501','permission denied: ASSIGN_TASK',
  'DOOR: moving the branch alone is refused');
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select is((select array[owner_department_id::text, owner_branch_id::text] from public.tasks
            where id = '13400000-0000-0000-0000-0000000000e1'),
  array['13400000-0000-0000-0000-0000000000d1','13400000-0000-0000-0000-0000000000b1'],
  'PRIVILEGE: after the refusals the task is still in the department manager''s queue');
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok($$update public.tasks set owner_user_id = '13400000-0000-0000-0000-000000000014'
                   where id = '13400000-0000-0000-0000-0000000000e1'$$,
  '42501','permission denied: ASSIGN_TASK',
  'DOOR: handing the task to a colleague stays refused (TASK-1)');

-- ================================================================================================
-- 11-15. What legitimately stays open: the owner's own work, the assigner, and the platform path.
-- ================================================================================================
select lives_ok($$update public.tasks set title = 'Call the customer back', priority_code = 'high', due_at = now() + interval '1 day'
                  where id = '13400000-0000-0000-0000-0000000000e1'$$,
  'CONTROL: the employee still edits, re-prioritises and reschedules their own task');
select lives_ok($$select app.advance_task('13400000-0000-0000-0000-0000000000e1','in_progress')$$,
  'CONTROL: the employee still starts their own task');
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($$select app.assign_task('13400000-0000-0000-0000-0000000000e1','13400000-0000-0000-0000-000000000013',
                                         '13400000-0000-0000-0000-0000000000d2','13400000-0000-0000-0000-0000000000b2','rebalance')$$,
  'CONTROL: an ASSIGN_TASK holder moves the task through the RPC');
select lives_ok($$update public.tasks set owner_department_id = '13400000-0000-0000-0000-0000000000d1',
                                         owner_branch_id = '13400000-0000-0000-0000-0000000000b1'
                  where id = '13400000-0000-0000-0000-0000000000e1'$$,
  'CONTROL: ...and back through the table');
reset role;
select set_config('request.jwt.claims','{}',true);
select lives_ok($$update public.tasks set owner_branch_id = '13400000-0000-0000-0000-0000000000b1'
                  where id = '13400000-0000-0000-0000-0000000000e2'$$,
  'CONTROL: the session-less platform path is exempt from authorization (canon 35 principle 6)');

-- ================================================================================================
-- 16-21. The surface's other refusals: tenant, step-up, DELETE, the non-holder, the state machine.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok($$insert into public.tasks (tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title)
                   values ('13400000-0000-0000-0000-000000000002','13400000-0000-0000-0000-000000000091','13400000-0000-0000-0000-0000000000d9',
                           '13400000-0000-0000-0000-0000000000b9','follow_up','open','planted')$$,
  '42501','new row violates row-level security policy for table "tasks"',
  'TENANT: the employee cannot plant a task in another tenant');
update public.tasks set title = 'rewritten' where id = '13400000-0000-0000-0000-0000000000e9';
select throws_ok($$delete from public.tasks where id = '13400000-0000-0000-0000-0000000000e1'$$,
  '42501','permission denied for table tasks',
  'DOOR: no one deletes a task (no grant)');
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a5","aal":"aal2"}',true);
select throws_ok($$insert into public.tasks (tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title)
                   values ('13400000-0000-0000-0000-000000000001','13400000-0000-0000-0000-000000000015','13400000-0000-0000-0000-0000000000d1',
                           '13400000-0000-0000-0000-0000000000b1','follow_up','open','trainee task')$$,
  '42501','permission denied: one of CREATE_TASK is required to write tasks',
  'PRIVILEGE: a trainee who may view assigned tasks cannot create one at the table');
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
select throws_ok($$insert into public.tasks (tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title)
                   values ('13400000-0000-0000-0000-000000000001','13400000-0000-0000-0000-000000000011','13400000-0000-0000-0000-0000000000d1',
                           '13400000-0000-0000-0000-0000000000b1','follow_up','open','aal1 task')$$,
  '42501','multi-factor authentication required for this role',
  'AUTH: an aal1 owner is refused step-up at the table door, as at the RPC');
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a4","aal":"aal2"}',true);
select throws_ok($$update public.tasks set task_status_code = 'completed' where id = '13400000-0000-0000-0000-0000000000e2'$$,
  '42501','permission denied: COMPLETE_TASK',
  'STATE: the table refuses the denied employee the same completion');
reset role;
select is((select title from public.tasks where id = '13400000-0000-0000-0000-0000000000e9'), 'Other tenant',
  'TENANT: the employee''s UPDATE of another tenant''s task changed nothing');

-- ================================================================================================
-- 22-25. OPEN defects, pinned as they stand. Each assertion fails when its finding is repaired.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a4","aal":"aal2"}',true);
select lives_ok($$insert into public.tasks (id,tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title)
                  values ('13400000-0000-0000-0000-0000000000f1','13400000-0000-0000-0000-000000000001','13400000-0000-0000-0000-000000000014',
                          '13400000-0000-0000-0000-0000000000d1','13400000-0000-0000-0000-0000000000b1','follow_up','completed','born completed')$$,
  'OPEN ENTRY-1: the employee denied COMPLETE_TASK still creates a task born completed');
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select lives_ok($$insert into public.tasks (id,tenant_id,owner_user_id,owner_department_id,owner_branch_id,task_type_code,task_status_code,title,
                                            is_archived,archived_at,archived_by,archive_reason)
                  values ('13400000-0000-0000-0000-0000000000f2','13400000-0000-0000-0000-000000000001','13400000-0000-0000-0000-000000000013',
                          '13400000-0000-0000-0000-0000000000d1','13400000-0000-0000-0000-0000000000b1','follow_up','open','born archived',
                          true,'2020-01-01','13400000-0000-0000-0000-000000000011','archived by the owner')$$,
  'OPEN ARCH-2: the employee without ARCHIVE_RECORD still creates a task born archived');
reset role;
select is((select task_status_code || ':' || coalesce(completed_at::text,'-') from public.tasks where id = '13400000-0000-0000-0000-0000000000f1'),
  'completed:-',
  'OPEN ENTRY-1: it is terminal, with no completion time and no RPC having completed it');
select is((select archived_by::text || ':' || archived_at::date::text from public.tasks where id = '13400000-0000-0000-0000-0000000000f2'),
  '13400000-0000-0000-0000-000000000011:2020-01-01',
  'OPEN ARCH-2: it names the owner as archiver at a caller-authored time');

-- ================================================================================================
-- 26-30. Mutation: the pre-repair guard (owner only) is installed in a savepoint, the move lands,
--        and the guard is restored byte for byte.
-- ================================================================================================
savepoint m1;
create or replace function app.guard_task_reassignment()
returns trigger language plpgsql set search_path = '' as $fn$
begin
    if (select auth.uid()) is null then return new; end if;
    if new.owner_user_id is distinct from old.owner_user_id then
        perform app.authorize('ASSIGN_TASK');
    end if;
    return new;
end
$fn$;
select isnt((select md5(pg_get_functiondef('app.guard_task_reassignment'::regproc))), (select v from s134 where k = 'guard'),
  'MUTANT INSTALLED: the guard reads the owner alone');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select lives_ok($$update public.tasks set owner_department_id = '13400000-0000-0000-0000-0000000000d2',
                                         owner_branch_id = '13400000-0000-0000-0000-0000000000b2'
                  where id = '13400000-0000-0000-0000-0000000000e1'$$,
  'MUTANT: the employee moves their task out of the queue');
select set_config('request.jwt.claims','{"sub":"13400000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select is((select count(*)::int from public.tasks where id = '13400000-0000-0000-0000-0000000000e1'), 0,
  'MUTANT: and the department manager no longer sees it');
reset role;
rollback to savepoint m1;
select is((select md5(pg_get_functiondef('app.guard_task_reassignment'::regproc))), (select v from s134 where k = 'guard'),
  'RESTORED: the guard is byte-identical to the repaired definition');
select is((select owner_department_id::text || ':' || owner_branch_id::text from public.tasks where id = '13400000-0000-0000-0000-0000000000e1'),
  '13400000-0000-0000-0000-0000000000d1:13400000-0000-0000-0000-0000000000b1',
  'RESTORED: no mutant move survived');

select * from finish();
rollback;
