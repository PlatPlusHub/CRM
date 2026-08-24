-- pgTAP: assignment history and the originating employee (SPEC-140).
--
-- The scenario is the owner's, stated verbatim in the directive of 2026-08-24 §7: "Employee A
-- receives the lead. Employee B later takes ownership. ... The system must preserve all three facts.
-- Do not overwrite historical responsibility." Canon 04 said the same thing first -- "Preserve the
-- original assignee in lead history", "No assignment history may be deleted" -- and none of it was
-- enforced: there was no reassignment RPC at all, so the only way to hand a lead over was a direct
-- UPDATE that wrote no history and erased the first employee.
--
-- Runs as postgres. Unlike tests 21-23 the subject here is triggers and RPC behaviour rather than
-- RLS, and triggers fire for the table owner too -- so the ordinary role is the honest one to use.
create extension if not exists pgtap with schema extensions;

begin;
select plan(14);

insert into auth.users (id, email) values ('24000000-0000-0000-0000-0000000000a1','boss@example.com');
insert into public.tenants (id, name, slug, status) values
  ('24000000-0000-0000-0000-000000000001','History Travel','history-travel','active');
insert into public.branches (id, tenant_id, name, slug) values
  ('24000000-0000-0000-0000-00000000000a','24000000-0000-0000-0000-000000000001','Aswan','aswan');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('24000000-0000-0000-0000-0000000000c1','24000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-00000000000a','sales','Aswan Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('24000000-0000-0000-0000-000000000011','24000000-0000-0000-0000-000000000001','Manager','boss@example.com',true,'24000000-0000-0000-0000-0000000000a1'),
  ('24000000-0000-0000-0000-000000000021','24000000-0000-0000-0000-000000000001','Employee A','a@example.com',true,null),
  ('24000000-0000-0000-0000-000000000022','24000000-0000-0000-0000-000000000001','Employee B','b@example.com',true,null);
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '24000000-0000-0000-0000-000000000001', u, '24000000-0000-0000-0000-00000000000a','24000000-0000-0000-0000-0000000000c1', true
from unnest(array['24000000-0000-0000-0000-000000000011'::uuid,
                  '24000000-0000-0000-0000-000000000021',
                  '24000000-0000-0000-0000-000000000022']) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '24000000-0000-0000-0000-000000000001','24000000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'branch_manager';

select set_config('request.jwt.claims', '{"sub":"24000000-0000-0000-0000-0000000000a1"}', true);

create temp table l as
select app.create_lead('24000000-0000-0000-0000-00000000000a','24000000-0000-0000-0000-0000000000c1',
                       'whatsapp','Aswan package') as id;

-- ---------------------------------------------------------------------------------------------
-- A receives it, B takes over.
-- ---------------------------------------------------------------------------------------------
select lives_ok(
  $$select app.assign_lead((select id from l), '24000000-0000-0000-0000-000000000021', 'first touch')$$,
  'Employee A receives the lead');

select lives_ok(
  $$select app.reassign_lead((select id from l), '24000000-0000-0000-0000-000000000022', 'A is away')$$,
  'Employee B takes it over through app.reassign_lead -- the path app.assign_lead has been naming since it was written, and which did not exist');

select is(
  (select string_agg(u.full_name, ' -> ' order by la.assigned_at)
     from public.lead_assignments la join public.users u on u.id = la.assigned_user_id
    where la.lead_id = (select id from l)),
  'Employee A -> Employee B',
  'BOTH FACTS SURVIVE -- the timeline shows who received it and who received it next');

select is(
  (select o.first_user_id from app.lead_origin((select id from l)) o),
  '24000000-0000-0000-0000-000000000021'::uuid,
  'the ORIGINATING employee is still Employee A after the handover, not the current assignee');

select is(
  (select o.current_user_id from app.lead_origin((select id from l)) o),
  '24000000-0000-0000-0000-000000000022'::uuid,
  '...and the current assignee is correctly Employee B -- first and current are distinguishable, which is the whole requirement');

select is(
  (select count(*)::int from public.lead_assignments
    where lead_id = (select id from l) and is_current),
  1,
  'exactly one assignment is current -- a handover closes the previous one rather than leaving two open');

select is(
  (select la.unassigned_at is not null from public.lead_assignments la
    where la.lead_id = (select id from l) and la.assigned_user_id = '24000000-0000-0000-0000-000000000021'),
  true,
  'A''s row is CLOSED, not deleted -- canon 04: "No assignment history may be deleted"');

-- ---------------------------------------------------------------------------------------------
-- The history cannot be quietly rewritten or bypassed.
-- ---------------------------------------------------------------------------------------------
select throws_ok(
  format($$update public.lead_assignments set assigned_user_id = '24000000-0000-0000-0000-000000000022'
            where lead_id = '%s' and assigned_user_id = '24000000-0000-0000-0000-000000000021'$$,
         (select id from l)),
  '42501', null,
  'history cannot be rewritten to name a different employee -- which would be worse than deletion, leaving a plausible timeline that is false');

select throws_ok(
  format($$delete from public.lead_assignments where lead_id = '%s'$$, (select id from l)),
  '42501', null,
  'and it cannot be deleted');

select throws_ok(
  format($$update public.leads set assigned_user_id = '24000000-0000-0000-0000-000000000021' where id = '%s'$$,
         (select id from l)),
  '23514', null,
  'THE DIRECT UPDATE THAT USED TO ERASE THE FIRST EMPLOYEE NOW FAILS -- the assignee cannot move without the timeline saying so');

select throws_ok(
  format($$select app.reassign_lead('%s','24000000-0000-0000-0000-000000000022','again')$$, (select id from l)),
  null, 'lead is already assigned to that employee',
  'reassigning to the employee who already holds it is refused, rather than writing a meaningless second row');

-- ---------------------------------------------------------------------------------------------
-- The customer half of "first employee".
-- ---------------------------------------------------------------------------------------------
select lives_ok(
  $$select app.create_customer('person','Aswan Customer', null, null, null, '+201005557777')$$,
  'a customer is created');

select is(
  (select first_registered_user_id from public.customers where full_name = 'Aswan Customer'),
  '24000000-0000-0000-0000-000000000011'::uuid,
  'the customer records WHO first took them on -- canon 03 recorded only the branch, the owner directive adds the employee');

select throws_ok(
  $$update public.customers set first_registered_user_id = '24000000-0000-0000-0000-000000000022'
     where full_name = 'Aswan Customer'$$,
  '42501', null,
  '...and it is frozen: "permanently preserve" is not a property a plain nullable column has');

select * from finish();
rollback;
