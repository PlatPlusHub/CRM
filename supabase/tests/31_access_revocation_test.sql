-- pgTAP: what happens when access is TAKEN AWAY (SPEC-148).
--
-- The owner's directive asks three questions that no test answered: what happens when an employee
-- leaves, when an employee loses a permission they previously had, and when a role assignment
-- expires. Every other test in this suite grants access and checks it works. Access controls fail
-- in the other direction too, and that failure is silent -- a departed employee whose session still
-- resolves is not something anyone notices until it matters.
--
-- Runs as `authenticated`, because the whole subject is what the resolution primitives return once
-- the underlying grant is gone.
create extension if not exists pgtap with schema extensions;

begin;
select plan(10);

insert into auth.users (id, email) values
  ('32000000-0000-0000-0000-0000000000a1','leaver@example.com'),
  ('32000000-0000-0000-0000-0000000000a2','expiring@example.com');

insert into public.tenants (id, name, slug, status) values
  ('32000000-0000-0000-0000-000000000001','Revocation Travel','revocation-travel','active');
insert into public.branches (id, tenant_id, name, slug) values
  ('32000000-0000-0000-0000-00000000000a','32000000-0000-0000-0000-000000000001','Dokki','dokki');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('32000000-0000-0000-0000-0000000000c1','32000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-00000000000a','sales','Dokki Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('32000000-0000-0000-0000-000000000011','32000000-0000-0000-0000-000000000001','Leaver','leaver@example.com',true,'32000000-0000-0000-0000-0000000000a1'),
  ('32000000-0000-0000-0000-000000000012','32000000-0000-0000-0000-000000000001','Expiring','expiring@example.com',true,'32000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('32000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000011','32000000-0000-0000-0000-00000000000a','32000000-0000-0000-0000-0000000000c1',true),
  ('32000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-000000000012','32000000-0000-0000-0000-00000000000a','32000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '32000000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('32000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('32000000-0000-0000-0000-000000000012'::uuid,'employee')) as v(uid, role_code)
join public.roles r on r.code = v.role_code;

-- A lead owned by someone else in the same department, so the department clause is what grants it.
insert into public.leads (id, tenant_id, branch_id, department_id,
                          lead_source_code, lead_status_code, title) values
  ('32000000-0000-0000-0000-0000000000e1','32000000-0000-0000-0000-000000000001',
   '32000000-0000-0000-0000-00000000000a','32000000-0000-0000-0000-0000000000c1',
   'whatsapp','new','Dokki lead');
-- Assignment is an act with a timeline (SPEC-140), and owner mirrors assignee (SPEC-151).
insert into public.lead_assignments (tenant_id, lead_id, assigned_user_id, is_current) values
  ('32000000-0000-0000-0000-000000000001','32000000-0000-0000-0000-0000000000e1','32000000-0000-0000-0000-000000000012',true);
update public.leads set assigned_user_id = '32000000-0000-0000-0000-000000000012',
                        owner_user_id    = '32000000-0000-0000-0000-000000000012'
 where id = '32000000-0000-0000-0000-0000000000e1';

set local role authenticated;

-- ---------------------------------------------------------------------------------------------
-- Baseline. Without this, every "cannot see" below is satisfied by a broken fixture.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"32000000-0000-0000-0000-0000000000a1"}', true);
select is((select count(*)::int from public.leads), 1,
  'the employee can see their department colleague''s lead -- the baseline everything below removes');
select is(app.has_permission('CREATE_CUSTOMER'), true,
  '...and holds an ordinary permission');

-- ---------------------------------------------------------------------------------------------
-- The employee leaves.
-- ---------------------------------------------------------------------------------------------
reset role;
update public.users set is_active = false where id = '32000000-0000-0000-0000-000000000011';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"32000000-0000-0000-0000-0000000000a1"}', true);

select is(app.current_tenant_id(), null,
  'A DEPARTED EMPLOYEE RESOLVES TO NO TENANT -- deactivation is not a UI convention, it cuts the resolution chain at its root');
select is(app.current_user_id(), null,
  '...and to no user, so the assigned scope cannot match either');
select is((select count(*)::int from public.leads), 0,
  '...and sees nothing, on every table at once, because every policy resolves through the same primitive');
select is(app.has_permission('CREATE_CUSTOMER'), false,
  '...and holds nothing, so an RPC would refuse them as well as a direct read');

-- ---------------------------------------------------------------------------------------------
-- A role assignment expires. The user is still active; only the grant has run out.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"32000000-0000-0000-0000-0000000000a2"}', true);
select is(app.has_permission('CREATE_CUSTOMER'), true,
  'the second employee still holds their permission while the assignment is current');

reset role;
update public.user_role_assignments set ends_at = now() - interval '1 day'
 where user_id = '32000000-0000-0000-0000-000000000012';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"32000000-0000-0000-0000-0000000000a2"}', true);

select is(app.has_permission('CREATE_CUSTOMER'), false,
  'AN EXPIRED ROLE ASSIGNMENT STOPS GRANTING -- `ends_at` is enforced, not decorative');
-- This assertion was originally written the other way round -- "their own lead is still visible,
-- because ownership is a fact about the record and not a permission" -- and it failed. The
-- implementation is right and the expectation was wrong. Canon 28 makes seeing your assigned work a
-- PERMISSION (`VIEW_ASSIGNED_LEADS`), which SPEC-146 began enforcing; an employee whose role
-- assignment has lapsed holds no permissions at all, so they hold that one no longer either. Role
-- expiry is therefore a COMPLETE revocation rather than a partial one, which is the safer semantic
-- and the one canon supports.
select is((select count(*)::int from public.leads), 0,
  '...and this removes even their OWN lead: seeing assigned work is itself a permission (canon 28), so an expired assignment revokes completely rather than partially');

-- Deactivating the role itself must have the same effect as expiry, or a tenant could disable a role
-- and leave its holders fully empowered.
reset role;
update public.user_role_assignments set ends_at = null where user_id = '32000000-0000-0000-0000-000000000012';
update public.roles set is_active = false where code = 'employee';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"32000000-0000-0000-0000-0000000000a2"}', true);
select is(app.has_permission('CREATE_CUSTOMER'), false,
  'deactivating the ROLE revokes it too -- the same result by a different route, which is what makes the control trustworthy');

select * from finish();
rollback;
