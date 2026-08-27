-- pgTAP: RBAC-4 -- a manager must never see less than the people they manage.
--
-- Phase C's role journeys found a department manager who could see ZERO bookings in the department
-- they manage, while every employee in that department could see them all. The `bookings`,
-- `booking_items` and `quotations` policies gate department reads on `VIEW_DEPARTMENT_RECORDS`, and
-- the seed granted it to `employee` and `senior_employee` but not to `department_manager`.
--
-- That is an inversion, not a restriction, and it is the kind that a permission matrix makes easy:
-- permissions are granted role by role, so nobody is ever shown the containment relationship
-- between them. This file states the relationship as an invariant.
--
-- The rule asserted is deliberately narrow -- DEPARTMENT-scoped read gates only. It is NOT "managers
-- have every permission their staff have": a department manager legitimately lacks things an
-- employee has no business needing either, and a manager's job is supervision, not a superset. What
-- cannot hold is a manager seeing FEWER records of the very scope they are defined by. Canon 28:
-- "Department-level manager inside one branch. Can manage employees and work inside their
-- department and branch only."
create extension if not exists pgtap with schema extensions;

begin;
select plan(4);

-- Department-scoped READ gates. Each is a permission whose whole meaning is "may read records
-- belonging to my department".
create temporary table _dept_read_gates (key text primary key) on commit drop;
insert into _dept_read_gates values
  ('VIEW_DEPARTMENT_RECORDS'),   -- bookings, booking items, quotations (canon 28 amendment note 2)
  ('VIEW_DEPARTMENT_QUEUE'),     -- leads
  ('VIEW_DEPARTMENT_TASK_QUEUE');-- tasks

create temporary view _role_perm as
select r.code as role_code, p.key as permission_key
from public.roles r
join public.role_permissions rp on rp.role_id = r.id
join public.permissions p on p.id = rp.permission_id;

select ok(
  (select count(*) from _role_perm where role_code = 'employee'
     and permission_key in (select key from _dept_read_gates)) >= 1,
  'POSITIVE CONTROL: the employee actually holds department read gates, so the check below is not vacuous');

-- =============================================================================================
-- 2. THE INVARIANT. Any department read gate an employee holds, the department manager holds.
-- =============================================================================================
select is(
  (select count(*)::int
     from _role_perm e
    where e.role_code = 'employee'
      and e.permission_key in (select key from _dept_read_gates)
      and not exists (select 1 from _role_perm m
                       where m.role_code = 'department_manager'
                         and m.permission_key = e.permission_key)),
  0,
  'the department manager holds every department read gate an employee holds -- no manager sees less than their staff');

select is(
  (select count(*)::int
     from _role_perm s
    where s.role_code = 'senior_employee'
      and s.permission_key in (select key from _dept_read_gates)
      and not exists (select 1 from _role_perm m
                       where m.role_code = 'department_manager'
                         and m.permission_key = s.permission_key)),
  0,
  '...and every one a senior employee holds');

-- =============================================================================================
-- 4. THE BOUNDARY THAT MUST NOT MOVE WITH IT. Canon 28 amendment note 3 is explicit: "Department
--    managers are still excluded, per 'Department Manager manages only their department inside
--    their branch'." Fixing the department scope must never quietly widen it to the branch.
-- =============================================================================================
select is(
  (select count(*)::int from _role_perm
    where role_code = 'department_manager'
      and permission_key in ('VIEW_BRANCH_DATA', 'VIEW_ALL_BRANCHES')),
  0,
  'the department manager still holds NO branch-wide read -- the department fix did not widen to the branch');

select finish();
rollback;
