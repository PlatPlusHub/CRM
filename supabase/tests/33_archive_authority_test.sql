-- pgTAP: archive authority (SPEC-150).
--
-- ORVION is archive-oriented rather than delete-oriented, and correctly grants `authenticated` no
-- DELETE on any table. That makes archiving the deletion mechanism -- so an unauthorized archive is
-- an unauthorized deletion, and an unaudited restore alongside it.
--
-- Reproduced before the fix: an ordinary employee archived a booking AND a customer with plain SQL,
-- with zero events, `archived_by` left null, and then un-archived the booking. Thirteen tables carry
-- `is_archived`; exactly one of them (`documents`) had a governed path.
create extension if not exists pgtap with schema extensions;

begin;
select plan(9);

insert into auth.users (id, email) values
  ('34000000-0000-0000-0000-0000000000a1','emp@example.com'),
  ('34000000-0000-0000-0000-0000000000a2','mgr@example.com');

insert into public.tenants (id, name, slug, status) values
  ('34000000-0000-0000-0000-000000000001','Archive Travel','archive-travel','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.branches (id, tenant_id, name, slug) values
  ('34000000-0000-0000-0000-00000000000a','34000000-0000-0000-0000-000000000001','Shubra','shubra');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('34000000-0000-0000-0000-0000000000c1','34000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-00000000000a','sales','Shubra Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('34000000-0000-0000-0000-000000000011','34000000-0000-0000-0000-000000000001','Employee','emp@example.com',true,'34000000-0000-0000-0000-0000000000a1'),
  ('34000000-0000-0000-0000-000000000012','34000000-0000-0000-0000-000000000001','Manager','mgr@example.com',true,'34000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('34000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-000000000011','34000000-0000-0000-0000-00000000000a','34000000-0000-0000-0000-0000000000c1',true),
  ('34000000-0000-0000-0000-000000000001','34000000-0000-0000-0000-000000000012','34000000-0000-0000-0000-00000000000a','34000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '34000000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('34000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('34000000-0000-0000-0000-000000000012'::uuid,'branch_manager')) as v(uid, role_code)
join public.roles r on r.code = v.role_code;

insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('34000000-0000-0000-0000-0000000000d1','34000000-0000-0000-0000-000000000001','person','Archive Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('34000000-0000-0000-0000-0000000000f1','34000000-0000-0000-0000-000000000001',
   '34000000-0000-0000-0000-00000000000a','34000000-0000-0000-0000-0000000000c1',
   '34000000-0000-0000-0000-0000000000d1','34000000-0000-0000-0000-000000000011',
   '34000000-0000-0000-0000-00000000000a','34000000-0000-0000-0000-0000000000c1',
   'draft','Shubra booking','BK-SHU-0001');

set local role authenticated;

-- ---------------------------------------------------------------------------------------------
-- The employee. Canon 28 gives the archive profile "Employee: No".
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"34000000-0000-0000-0000-0000000000a1"}', true);

select is((select count(*)::int from public.bookings), 1,
  'the employee can see and normally edit this booking -- so the refusals below are the archive guard, not RLS');

select throws_ok(
  $$update public.bookings set is_archived = true where id = '34000000-0000-0000-0000-0000000000f1'$$,
  '42501', null,
  'AN EMPLOYEE CANNOT ARCHIVE A BOOKING -- with no DELETE grant anywhere, archiving is how a record is removed, and it was ungoverned');

select throws_ok(
  $$update public.customers set is_archived = true where id = '34000000-0000-0000-0000-0000000000d1'$$,
  '42501', null,
  '...nor a customer, which is the record the whole CRM history hangs off');

-- The employee must still be able to do ordinary work on the same rows.
select lives_ok(
  $$update public.bookings set title = 'Renamed by employee' where id = '34000000-0000-0000-0000-0000000000f1'$$,
  '...while ordinary edits are untouched -- the guard fires on archiving, not on every write');

-- ---------------------------------------------------------------------------------------------
-- The manager, who holds the canon 28 archive profile.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"34000000-0000-0000-0000-0000000000a2"}', true);

select lives_ok(
  $$update public.bookings set is_archived = true where id = '34000000-0000-0000-0000-0000000000f1'$$,
  'the branch manager CAN archive -- the control blocks the wrong actor, not the right one');

-- Attribution is stamped by the system, not typed by the person. The manager set neither column.
select is(
  (select archived_by from public.bookings where id = '34000000-0000-0000-0000-0000000000f1'),
  '34000000-0000-0000-0000-000000000012'::uuid,
  '...and the system stamps WHO archived it, without being asked -- previously archived_by stayed null');
select is(
  (select archived_at is not null from public.bookings where id = '34000000-0000-0000-0000-0000000000f1'),
  true,
  '...and WHEN');

-- ---------------------------------------------------------------------------------------------
-- Restoring is the same authority. A control that let anyone un-archive would make the archive
-- itself meaningless.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"34000000-0000-0000-0000-0000000000a1"}', true);
select throws_ok(
  $$update public.bookings set is_archived = false where id = '34000000-0000-0000-0000-0000000000f1'$$,
  '42501', null,
  'the employee cannot UN-archive it either -- otherwise the archive would be a suggestion');

select set_config('request.jwt.claims', '{"sub":"34000000-0000-0000-0000-0000000000a2"}', true);
update public.bookings set is_archived = false where id = '34000000-0000-0000-0000-0000000000f1';
select is(
  (select archived_by is null and archived_at is null from public.bookings where id = '34000000-0000-0000-0000-0000000000f1'),
  true,
  '...and when the manager restores it, the stale archive attribution is cleared rather than left to imply it is still archived');

select * from finish();
rollback;
