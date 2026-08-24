-- pgTAP: write authority over identity, organization and configuration (SPEC-138).
--
-- The assertion this file exists for is the first one: an ordinary employee running a single INSERT
-- against `user_role_assignments` could make themselves an owner. That statement satisfied the old
-- policy (`tenant_id = app.current_tenant_id()` -- and it *is* their tenant), which meant every
-- permission check in ORVION, and the whole read-scope model, was advisory.
--
-- Like test 21 this runs as `authenticated`, because as `postgres` the escalation is not even
-- expressible -- the table owner bypasses RLS, so the attack would "fail" for entirely the wrong
-- reason and the test would prove nothing.
--
-- Every denial is paired with the corresponding grant. A rule that blocks the attacker but also
-- blocks the administrator is not a fix, it is an outage.
create extension if not exists pgtap with schema extensions;

begin;
select plan(12);

insert into auth.users (id, email) values
  ('22000000-0000-0000-0000-0000000000a1','worker@example.com'),
  ('22000000-0000-0000-0000-0000000000a2','chief@example.com');

insert into public.tenants (id, name, slug, status) values
  ('22000000-0000-0000-0000-000000000001','Authority Travel','authority-travel','active');
insert into public.branches (id, tenant_id, name, slug) values
  ('22000000-0000-0000-0000-00000000000a','22000000-0000-0000-0000-000000000001','Giza','giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('22000000-0000-0000-0000-0000000000c1','22000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-00000000000a','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('22000000-0000-0000-0000-000000000011','22000000-0000-0000-0000-000000000001','Worker','worker@example.com',true,'22000000-0000-0000-0000-0000000000a1'),
  ('22000000-0000-0000-0000-000000000012','22000000-0000-0000-0000-000000000001','Chief','chief@example.com',true,'22000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('22000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000011','22000000-0000-0000-0000-00000000000a','22000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '22000000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('22000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('22000000-0000-0000-0000-000000000012'::uuid,'ceo')) as v(uid, role_code)
join public.roles r on r.code = v.role_code;

set local role authenticated;

-- ---------------------------------------------------------------------------------------------
-- The employee. Everything here must be refused.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"22000000-0000-0000-0000-0000000000a1"}', true);

-- Sanity: the employee is a real, working user in this tenant. Without this, the refusals below
-- could all be a broken session rather than a working control.
select is(app.current_tenant_id(), '22000000-0000-0000-0000-000000000001'::uuid,
  'the employee has a genuine authenticated session in their tenant');

select throws_ok(
  $$insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
    values ('22000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000011',
            (select id from public.roles where code = 'owner'), 'tenant')$$,
  '42501', null,
  'AN EMPLOYEE CANNOT MAKE THEMSELVES OWNER -- the escalation SPEC-138 exists to close');

select throws_ok(
  $$insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type, branch_id)
    values ('22000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000011',
            (select id from public.roles where code = 'branch_manager'), 'branch',
            '22000000-0000-0000-0000-00000000000a')$$,
  '42501', null,
  '...nor promote themselves to branch manager, which would hand them VIEW_BRANCH_DATA');

-- UPDATE is refused DIFFERENTLY from INSERT, and the difference matters. A failed WITH CHECK raises
-- 42501; a row excluded by the USING clause is simply not visible to the UPDATE, so the statement
-- succeeds having matched zero rows and raises nothing at all. Asserting an exception here would
-- have been asserting the wrong thing -- what has to be true is that the data did not change. Any
-- future application code that treats "no error" as "the update happened" would be wrong for the
-- same reason.
update public.user_role_assignments set scope_type = 'platform'
 where user_id = '22000000-0000-0000-0000-000000000011';
select is(
  (select scope_type from public.user_role_assignments
    where user_id = '22000000-0000-0000-0000-000000000011'),
  'tenant',
  '...nor widen the scope of a role assignment they already hold -- the UPDATE matches zero rows and changes nothing');

select throws_ok(
  $$insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
    values ('22000000-0000-0000-0000-000000000001','22000000-0000-0000-0000-000000000011',
            '22000000-0000-0000-0000-00000000000a','22000000-0000-0000-0000-0000000000c1',false)$$,
  '42501', null,
  '...nor place themselves in another branch, which would hand them that branch''s records');

select throws_ok(
  $$insert into public.branches (tenant_id, name, slug)
    values ('22000000-0000-0000-0000-000000000001','Rogue Branch','rogue')$$,
  '42501', null,
  '...nor invent a branch');

update public.tenants set name = 'Renamed By An Employee'
 where id = '22000000-0000-0000-0000-000000000001';
select is(
  (select name from public.tenants where id = '22000000-0000-0000-0000-000000000001'),
  'Authority Travel',
  '...nor rewrite company settings -- the tenant row is readable but not writable by an employee');

select throws_ok(
  $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label, sort_order, is_active, is_system)
    values ('22000000-0000-0000-0000-000000000001','lead_source','back_door','Back Door',950,true,false)$$,
  '42501', null,
  '...nor extend the controlled vocabulary the catalog triggers validate against');

-- Reading is untouched: an employee still needs to see their own org context.
select is((select count(*)::int from public.user_role_assignments
            where user_id = '22000000-0000-0000-0000-000000000011'), 1,
  'the employee can still READ their own role assignment -- only writing was restricted');
select is((select count(*)::int from public.branches), 1,
  'the employee can still read their tenant''s branches');

-- ---------------------------------------------------------------------------------------------
-- The CEO. The same operations must still work, through the real RPCs.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"22000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);

select lives_ok(
  $$select app.create_branch('Heliopolis','heliopolis')$$,
  'A CEO can still create a branch through the real RPC -- the control blocks the attacker, not the administrator');

select lives_ok(
  $$select app.assign_user_role('22000000-0000-0000-0000-000000000011','senior_employee','tenant')$$,
  'A CEO can still grant a role through the real RPC');

select * from finish();
rollback;
