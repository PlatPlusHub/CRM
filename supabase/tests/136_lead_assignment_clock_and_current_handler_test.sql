-- ATTACK-CLASSES: PRIVILEGE DOOR TENANT BUSINESS STATE INPUT AUTH=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
-- SPEC-232 / Batch 6 Slice 30. `lead_assignments` audited; ASGN-4 and ASGN-5 repaired. The SLA job
-- supervises a lead through its CURRENT assignment row, and that row's `assigned_at` is the SLA clock.
-- A manager holding ASSIGN_LEAD or REASSIGN_LEAD could close the handler's current row and write
-- nothing after it (ASGN-4), or re-insert it a century ahead (ASGN-5), and either way the SLA skipped
-- the lead on every pass with no event and no notice. Backdated, the same clock named a colleague as a
-- lead's first handler. `20260928120000` derives the clock on INSERT in ASGN-2's trigger and checks at
-- COMMIT that the current row names the lead's assignee. A mutation installs the pre-repair trigger and
-- drops the check in a savepoint, watches the SLA lose both leads, and restores both.
-- AUTH=N/A: `app.authorize` charges ASSIGN_LEAD/REASSIGN_LEAD identically on the RPCs and the table;
-- neither repair is a step-up control.
-- CONCURRENCY=N/A: two current rows for one lead are `lead_assignments_one_current_idx`'s (`77_...`),
-- and overlapping SLA passes are LEAD-5's (`63_...`).
-- REPLAY=N/A: no token, nonce or idempotency key lives on an assignment.
-- OBSERVABILITY=N/A: the SLA's warning and notices are asserted as the BUSINESS consequence; the table
-- door emitting no assignment event is the registered CAMP-4 class, not this file's.
create extension if not exists pgtap with schema extensions;

begin;
select plan(19);

insert into auth.users (id,email,email_confirmed_at) values
  ('13600000-0000-0000-0000-0000000000a1','emp@la136.test',now()),
  ('13600000-0000-0000-0000-0000000000a2','bm@la136.test',now()),
  ('13600000-0000-0000-0000-0000000000a3','dm@la136.test',now()),
  ('13600000-0000-0000-0000-0000000000a5','col@la136.test',now());
insert into public.tenants (id,name,slug,status) values
  ('13600000-0000-0000-0000-000000000001','LA136 Travel','la136-travel','active'),
  ('13600000-0000-0000-0000-000000000002','LA136 Other','la136-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise' and t.id::text like '13600000-%';
insert into public.branches (id,tenant_id,name,slug) values
  ('13600000-0000-0000-0000-00000000000a','13600000-0000-0000-0000-000000000001','Cairo','la136-cairo'),
  ('13600000-0000-0000-0000-00000000000b','13600000-0000-0000-0000-000000000002','Giza','la136-giza');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('13600000-0000-0000-0000-0000000000c1','13600000-0000-0000-0000-000000000001','13600000-0000-0000-0000-00000000000a','sales','Sales'),
  ('13600000-0000-0000-0000-0000000000c2','13600000-0000-0000-0000-000000000002','13600000-0000-0000-0000-00000000000b','sales','Giza Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('13600000-0000-0000-0000-000000000011','13600000-0000-0000-0000-000000000001','Handler','emp@la136.test',true,'13600000-0000-0000-0000-0000000000a1'),
  ('13600000-0000-0000-0000-000000000012','13600000-0000-0000-0000-000000000001','Branch Manager','bm@la136.test',true,'13600000-0000-0000-0000-0000000000a2'),
  ('13600000-0000-0000-0000-000000000013','13600000-0000-0000-0000-000000000001','Dept Manager','dm@la136.test',true,'13600000-0000-0000-0000-0000000000a3'),
  ('13600000-0000-0000-0000-000000000010','13600000-0000-0000-0000-000000000001','Colleague','col@la136.test',true,'13600000-0000-0000-0000-0000000000a5'),
  ('13600000-0000-0000-0000-000000000091','13600000-0000-0000-0000-000000000002','Other','other@la136.test',true,null);
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary)
select '13600000-0000-0000-0000-000000000001', u, '13600000-0000-0000-0000-00000000000a','13600000-0000-0000-0000-0000000000c1', true
from unnest(array['13600000-0000-0000-0000-000000000011'::uuid,'13600000-0000-0000-0000-000000000012'::uuid,
                  '13600000-0000-0000-0000-000000000013'::uuid,'13600000-0000-0000-0000-000000000010'::uuid]) u;
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '13600000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('13600000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('13600000-0000-0000-0000-000000000012','branch_manager'),
             ('13600000-0000-0000-0000-000000000013','department_manager'),
             ('13600000-0000-0000-0000-000000000010','employee')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.leads (id,tenant_id,branch_id,department_id,lead_source_code,title,lead_status_code)
select ('13600000-0000-0000-0000-0000000000e'||n)::uuid, '13600000-0000-0000-0000-000000000001',
       '13600000-0000-0000-0000-00000000000a','13600000-0000-0000-0000-0000000000c1','direct_call','L'||n,'new'
from generate_series(1,5) n;
-- Session-less fixture: a closed history row in the other tenant.
insert into public.leads (id,tenant_id,branch_id,department_id,lead_source_code,title,lead_status_code) values
  ('13600000-0000-0000-0000-0000000000e9','13600000-0000-0000-0000-000000000002','13600000-0000-0000-0000-00000000000b','13600000-0000-0000-0000-0000000000c2','direct_call','Other lead','new');
insert into public.lead_assignments (id,tenant_id,lead_id,assigned_user_id,is_current) values
  ('13600000-0000-0000-0000-0000000000f9','13600000-0000-0000-0000-000000000002','13600000-0000-0000-0000-0000000000e9','13600000-0000-0000-0000-000000000091',false);

create temp table s136 (k text primary key, v text) on commit drop;
insert into s136 values
  ('derive', (select md5(pg_get_functiondef('app.derive_assignment_actor'::regproc)))),
  ('check', (select md5(pg_get_functiondef(to_regproc('app.enforce_lead_current_assignment')))));
grant select on s136 to authenticated;

-- The branch manager hands L1, L2, L4 and L5 to the handler and L3 to the department manager.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13600000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select app.assign_lead(('13600000-0000-0000-0000-0000000000e'||n)::uuid,
                       case n when 3 then '13600000-0000-0000-0000-000000000013'::uuid else '13600000-0000-0000-0000-000000000011'::uuid end,
                       'fixture')
from generate_series(1,5) n;

-- ================================================================================================
-- 1-2. The population: a manager writes this table, the handler does not.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"13600000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select is(array[app.has_permission('ASSIGN_LEAD'), app.has_permission('REASSIGN_LEAD')], array[true,true],
  'CONTROL: the department manager holds both assignment keys');
select set_config('request.jwt.claims','{"sub":"13600000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok($$update public.lead_assignments set is_current = false where lead_id = '13600000-0000-0000-0000-0000000000e1' and is_current$$,
  '42501','permission denied: one of ASSIGN_LEAD or REASSIGN_LEAD is required to write lead_assignments',
  'PRIVILEGE: the handler cannot touch their own assignment');

-- ================================================================================================
-- 3-5. ASGN-4: at COMMIT the current row names the lead's assignee, and a real handover still commits.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"13600000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok($q$do $x$ begin
    update public.lead_assignments set is_current = false, unassigned_at = now()
     where lead_id = '13600000-0000-0000-0000-0000000000e1' and is_current;
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','a lead''s current assignment must name the lead''s assignee: hand a lead over with app.reassign_lead',
  'DOOR: closing the handler''s current row with nothing after it is refused at commit (ASGN-4)');
select throws_ok($q$do $x$ begin
    update public.lead_assignments set is_current = false, unassigned_at = now()
     where lead_id = '13600000-0000-0000-0000-0000000000e5' and is_current;
    insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, is_current)
    values ('13600000-0000-0000-0000-000000000001','13600000-0000-0000-0000-0000000000e5','13600000-0000-0000-0000-000000000010',true);
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','a lead''s current assignment must name the lead''s assignee: hand a lead over with app.reassign_lead',
  'STATE: a current row naming someone other than the lead''s assignee is refused at commit (ASGN-4)');
select set_config('request.jwt.claims','{"sub":"13600000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select lives_ok($q$do $x$ begin
    perform app.reassign_lead('13600000-0000-0000-0000-0000000000e2','13600000-0000-0000-0000-000000000010','handover');
    execute 'set constraints all immediate';
    execute 'set constraints all deferred';
  end $x$$q$,
  'CONTROL: app.reassign_lead closes, inserts, then moves the lead, and commits');

-- ================================================================================================
-- 6-11. ASGN-5: the SLA clock is the server's on INSERT and stays frozen on UPDATE.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"13600000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select lives_ok($q$do $x$ begin
    insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_at, unassigned_at, is_current)
    values ('13600000-0000-0000-0000-000000000001','13600000-0000-0000-0000-0000000000e4','13600000-0000-0000-0000-000000000010',
            '2000-01-01', '2000-01-02', false);
    execute 'set constraints all immediate';
    execute 'set constraints all deferred';
  end $x$$q$,
  'CONTROL: a closed history row is still legal at the table (verify_lifecycle_branches asserts it over HTTP)');
select is((select assigned_at from public.lead_assignments
            where lead_id = '13600000-0000-0000-0000-0000000000e4' and assigned_user_id = '13600000-0000-0000-0000-000000000010' and not is_current), now(),
  'INPUT: ...born at the server''s clock, whatever it claimed (ASGN-5)');
select is((select first_user_id from app.lead_origin('13600000-0000-0000-0000-0000000000e4')), '13600000-0000-0000-0000-000000000011'::uuid,
  'lead_origin still names the real first handler, not the backdated colleague (ASGN-5)');
select throws_ok($$update public.lead_assignments set assigned_at = now() + interval '1 day' where lead_id = '13600000-0000-0000-0000-0000000000e4' and is_current$$,
  '42501','lead assignment history is immutable; only unassigned_at and is_current may change',
  'CONTROL: the clock stays frozen on UPDATE');
do $x$ begin
  update public.lead_assignments set is_current = false, unassigned_at = now()
   where lead_id = '13600000-0000-0000-0000-0000000000e3' and is_current;
  insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_at, is_current)
  values ('13600000-0000-0000-0000-000000000001','13600000-0000-0000-0000-0000000000e3','13600000-0000-0000-0000-000000000013',
          now() + interval '100 years', true);
end $x$;
select is((select assigned_at from public.lead_assignments where lead_id = '13600000-0000-0000-0000-0000000000e3' and is_current), now(),
  'INPUT: the department manager re-recording their own lead a century ahead is born at the server''s clock (ASGN-5)');
reset role;
select set_config('request.jwt.claims','',true);
insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_at, unassigned_at, is_current)
values ('13600000-0000-0000-0000-000000000001','13600000-0000-0000-0000-0000000000e5','13600000-0000-0000-0000-000000000010',
        '2000-01-01', '2000-01-02', false);
select is((select assigned_at from public.lead_assignments
            where lead_id = '13600000-0000-0000-0000-0000000000e5' and assigned_user_id = '13600000-0000-0000-0000-000000000010' and not is_current), '2000-01-01'::timestamptz,
  'CONTROL: the session-less platform path still writes the clock it sets');

-- ================================================================================================
-- 12. TENANT: another tenant's history cannot be reached.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13600000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
update public.lead_assignments set unassigned_at = now() where id = '13600000-0000-0000-0000-0000000000f9';
reset role;
select is((select unassigned_at from public.lead_assignments where id = '13600000-0000-0000-0000-0000000000f9'), null,
  'TENANT: the manager''s UPDATE of another tenant''s history changes nothing');

-- ================================================================================================
-- 13-14. BUSINESS: every assigned lead stays under SLA supervision, and the escalation reaches upward.
-- ================================================================================================
select set_config('request.jwt.claims','',true);
create temp table w13 on commit drop as select * from app.process_lead_sla(interval '0 seconds', interval '999 days');
select is((select array_agg(l.title order by l.title) from w13 join public.leads l on l.id = w13.lead_id
            where l.tenant_id = '13600000-0000-0000-0000-000000000001' and w13.action = 'warned'),
  array['L1','L2','L3','L4','L5'],
  'BUSINESS: the SLA warns on every assigned lead, including the two the manager tried to take out of supervision');
select is((select count(*)::int from public.notifications
            where related_entity_id = '13600000-0000-0000-0000-0000000000e3' and notification_type_code = 'lead_sla_warning'
              and target_user_id = '13600000-0000-0000-0000-000000000012'), 1,
  'BUSINESS: the branch manager is told when the department manager''s own lead breaches (canon 10: not mutable)');

-- ================================================================================================
-- 15-17. Mutation: the pre-repair trigger is installed and the commit check dropped in a savepoint.
-- ================================================================================================
set constraints all immediate;
set constraints all deferred;
savepoint m1;
create or replace function app.derive_assignment_actor()
returns trigger language plpgsql set search_path = '' as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    new.assigned_by := app.current_user_id();
    return new;
end
$fn$;
drop trigger if exists lead_assignments_current_names_the_assignee on public.lead_assignments;
select isnt((select md5(pg_get_functiondef('app.derive_assignment_actor'::regproc))), (select v from s136 where k = 'derive'),
  'MUTANT INSTALLED: the trigger no longer derives the clock, and the commit check is gone');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13600000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
update public.lead_assignments set is_current = false, unassigned_at = now()
 where lead_id = '13600000-0000-0000-0000-0000000000e4' and is_current;
update public.lead_assignments set is_current = false, unassigned_at = now()
 where lead_id = '13600000-0000-0000-0000-0000000000e1' and is_current;
insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, assigned_at, is_current)
values ('13600000-0000-0000-0000-000000000001','13600000-0000-0000-0000-0000000000e1','13600000-0000-0000-0000-000000000011',
        now() + interval '100 years', true);
reset role;
select set_config('request.jwt.claims','',true);
create temp table m16 on commit drop as select * from app.process_lead_sla(interval '0 seconds', interval '0 seconds');
select is((select array_agg(l.title order by l.title) from m16 join public.leads l on l.id = m16.lead_id
            where l.tenant_id = '13600000-0000-0000-0000-000000000001'),
  array['L2','L3','L5'],
  'MUTANT: the SLA silently drops the lead with no current row (L4) and the lead a century ahead (L1)');
rollback to savepoint m1;
select is(array[(select md5(pg_get_functiondef('app.derive_assignment_actor'::regproc))),
                (select md5(pg_get_functiondef(to_regproc('app.enforce_lead_current_assignment')))),
                (select count(*)::text from pg_trigger where tgname = 'lead_assignments_current_names_the_assignee'
                   and tgrelid = 'public.lead_assignments'::regclass and tgdeferrable and tginitdeferred),
                (select count(*)::text from public.lead_assignments where lead_id = '13600000-0000-0000-0000-0000000000e4' and is_current)],
  array[(select v from s136 where k = 'derive'), (select v from s136 where k = 'check'), '1', '1'],
  'RESTORED: both functions are byte-identical, the deferred check is back, and no mutant close survived');

-- ================================================================================================
-- 18-19. The SLA's own handover, a platform path the check does not exempt, still commits.
-- ================================================================================================
create temp table r18 on commit drop as select * from app.process_lead_sla(interval '0 seconds', interval '0 seconds');
select lives_ok('set constraints all immediate',
  'CONTROL: the SLA''s reassignments satisfy the commit check with no session-less exemption');
select is(array[(select count(*)::int from r18 join public.leads l on l.id = r18.lead_id
                  where l.tenant_id = '13600000-0000-0000-0000-000000000001' and r18.action = 'reassigned'),
                (select count(*)::int from public.leads l
                  left join public.lead_assignments la on la.lead_id = l.id and la.is_current
                  where l.tenant_id = '13600000-0000-0000-0000-000000000001' and l.assigned_user_id is distinct from la.assigned_user_id)],
  array[5, 0],
  'STATE: all five leads were handed over and every current row names its lead''s assignee');

select * from finish();
rollback;
