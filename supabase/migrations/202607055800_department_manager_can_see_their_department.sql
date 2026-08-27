-- RBAC-4 -- a department manager could not see their own department's bookings, while every
--            employee they manage could.
--
-- ================================================================================================
-- FOUND BY the Phase C role journeys: the first role-by-role walk ORVION has had. The department
-- manager, over HTTP, reading their own branch's pipeline:
--
--     DEPTMGR bookings=0  pipeline=0
--             VIEW_DEPARTMENT_QUEUE=true  visible_depts=1  visible_branches=1
--
-- ...with the booking sitting in exactly that department and that branch. Everything the manager
-- needed resolved correctly; the row was still invisible.
--
-- THE CAUSE. The `bookings` policy gates department-scoped reads on `VIEW_DEPARTMENT_RECORDS`:
--
--     branch_id in visible_branch_ids
--     and ( VIEW_BRANCH_DATA
--           or (VIEW_DEPARTMENT_RECORDS and department_id in visible_department_ids) )
--
-- and the seed grants that permission to `employee` and `senior_employee` -- and not to
-- `department_manager`. `branch_manager`, `ceo` and `owner` are unaffected because they satisfy the
-- other disjunct. So the omission lands on exactly one role, and it is the one whose entire job is
-- that department.
--
-- The result is an inversion: a department manager saw FEWER bookings than the employees reporting
-- to them, in the department they manage. `VIEW_DEPARTMENT_RECORDS` is also canon's read gate for
-- booking items and quotations, so the same manager could not see their department's sales items or
-- quotations either -- the three objects the role exists to supervise.
--
-- ================================================================================================
-- WHY THIS IS A DEFECT AND NOT A POLICY DECISION I AM MAKING
--
-- Canon 28 defines the role: "Department-level manager inside one branch. Can manage employees and
-- **work inside their department and branch only**." A manager who cannot read their department's
-- bookings cannot manage that work.
--
-- Canon 28's own amendment note introduces the permission for this purpose: "`VIEW_DEPARTMENT_
-- RECORDS` is added. Canon names a `VIEW_*` permission for leads, tasks, conversations, complaints
-- and service requests, and none for bookings, booking items or quotations. Rather than stretch
-- `VIEW_DEPARTMENT_QUEUE` (a leads concept) over a booking, this permission is the department-read
-- gate for those three."
--
-- And the same note is explicit about where department managers ARE deliberately excluded -- item 3,
-- `VIEW_BRANCH_DATA`: "Department managers are still excluded, per 'Department Manager manages only
-- their department inside their branch'." That exclusion is about BRANCH-wide reading, and it is
-- untouched here. Nothing in canon excludes a department manager from their own department.
--
-- This grant therefore restores the scope canon already describes. It widens nothing: the manager
-- gains exactly the department-read gate that every employee in that same department already holds,
-- and remains unable to read any other department or any other branch.
-- ================================================================================================

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'department_manager'
  and p.key = 'VIEW_DEPARTMENT_RECORDS'
  and not exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_id = p.id
  );
