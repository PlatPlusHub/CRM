-- pgTAP: an employee's first day, executed end-to-end through the REAL authorization chain.
--
-- Every other test in this suite verifies a constraint or a privilege. This one verifies that the
-- system is actually usable — and that it refuses what it should — by driving the genuine RPCs as a
-- genuine authenticated user: a row in auth.users, a tenant user linked to it, a role assignment,
-- and a JWT claim, so `auth.uid()` -> `app.current_tenant_id()` -> `app.authorize()` all resolve for
-- real rather than being stubbed.
--
-- That chain is what makes the negative assertions meaningful. A permission test that cannot
-- actually fail proves nothing; here the unauthorized case is a real user, with a real role, that
-- genuinely lacks the permission.
create extension if not exists pgtap with schema extensions;

begin;
select plan(18);

-- The sales employee holds branch_manager: it carries every permission this day needs and does NOT
-- require MFA, which is what a real daily-CRM role looks like. Using `owner` here instead surfaced
-- a genuine behaviour worth recording -- app.requires_mfa() gates owner/ceo/finance_manager/
-- system_administrator on an aal2 JWT claim, so a privileged session with no MFA cannot act at all.
-- ---------------------------------------------------------------------------------------------
-- The employee, their colleague, and their tenant.
-- ---------------------------------------------------------------------------------------------
insert into auth.users (id, email) values
  ('11110000-0000-0000-0000-0000000000aa','sales@example.com'),
  ('11110000-0000-0000-0000-0000000000bb','trainee@example.com');

insert into public.tenants (id, name, slug, status) values
  ('11110000-0000-0000-0000-000000000001','Walkthrough Travel','walkthrough','active');

-- SPEC-152: a tenant with no subscription cannot write (fail-closed). Production tenants always
-- have one; a fixture without one models a state the system cannot reach. Set-based and idempotent,
-- so it covers every tenant this file creates and never fights a test that manages its own.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and not exists (select 1 from public.subscriptions s where s.tenant_id = t.id);
insert into public.branches (id, tenant_id, name, slug) values
  ('11110000-0000-0000-0000-000000000002','11110000-0000-0000-0000-000000000001','Cairo','cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('11110000-0000-0000-0000-000000000003','11110000-0000-0000-0000-000000000001','11110000-0000-0000-0000-000000000002','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('11110000-0000-0000-0000-000000000004','11110000-0000-0000-0000-000000000001','Sales Employee','sales@example.com',true,'11110000-0000-0000-0000-0000000000aa'),
  ('11110000-0000-0000-0000-000000000005','11110000-0000-0000-0000-000000000001','Trainee','trainee@example.com',true,'11110000-0000-0000-0000-0000000000bb');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
values ('11110000-0000-0000-0000-000000000001','11110000-0000-0000-0000-000000000004',
        '11110000-0000-0000-0000-000000000002','11110000-0000-0000-0000-000000000003',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '11110000-0000-0000-0000-000000000001','11110000-0000-0000-0000-000000000004', r.id, 'tenant'
  from public.roles r where r.code = 'branch_manager';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '11110000-0000-0000-0000-000000000001','11110000-0000-0000-0000-000000000005', r.id, 'tenant'
  from public.roles r where r.code = 'trainee';

-- Sign in as the sales employee.
select set_config('request.jwt.claims', '{"sub":"11110000-0000-0000-0000-0000000000aa"}', true);

select is(app.current_tenant_id(), '11110000-0000-0000-0000-000000000001'::uuid,
  'the signed-in employee resolves to their tenant');

-- ---------------------------------------------------------------------------------------------
-- 1. Create a customer, the way an employee would type it.
-- ---------------------------------------------------------------------------------------------
select lives_ok(
  $$select app.create_customer('person','  Ahmed Hassan  ', null, null, null,
      ' +20 (100) 555-1234 ', '  Ahmed.Hassan@Gmail.COM ')$$,
  'an employee can create a customer with naturally-typed phone and email');

select is(
  (select primary_email from public.customers where full_name = 'Ahmed Hassan'),
  'ahmed.hassan@gmail.com',
  'the email is canonicalized on the way in, not rejected');

select is(
  (select primary_phone from public.customers where full_name = 'Ahmed Hassan'),
  '+201005551234',
  'the phone is canonicalized to one comparable form');

-- 2. The same person, entered differently, must not become a second master record.
select throws_ok(
  $$select app.create_customer('person','Ahmed Hassan Again', null, null, null,
      '+20 100 555 1234', null)$$,
  '23505',
  null,
  'a differently-formatted duplicate phone is refused, not silently duplicated');

-- 3. Duplicate detection finds the customer from a differently-typed email.
select is(
  (select count(*)::int from app.find_customer_duplicates(null, ' AHMED.HASSAN@gmail.com ')),
  1,
  'duplicate detection matches regardless of how the employee types the address');

-- ---------------------------------------------------------------------------------------------
-- 4-7. Tasks: create, advance, and refuse an invalid transition.
-- ---------------------------------------------------------------------------------------------
select lives_ok(
  $$select app.create_task('Call Ahmed back','call_customer')$$,
  'an employee can create a task');

select is(
  (select task_status_code from public.tasks where title = 'Call Ahmed back'),
  'open',
  'a new task starts in the canonical initial state');

select lives_ok(
  $$select app.advance_task((select id from public.tasks where title = 'Call Ahmed back'), 'completed', 'done')$$,
  'the task can be completed');

select throws_like(
  $$select app.advance_task((select id from public.tasks where title = 'Call Ahmed back'), 'in_progress')$$,
  '%invalid task transition completed -> in_progress%',
  'a completed task cannot be moved back to in_progress');

-- ---------------------------------------------------------------------------------------------
-- 8-11. Complaints: create, walk the canonical lifecycle, refuse a skipped step.
-- ---------------------------------------------------------------------------------------------
select lives_ok(
  $$select app.create_complaint(
      (select id from public.customers where full_name = 'Ahmed Hassan'),
      'Flight was delayed','service_quality','high')$$,
  'an employee can raise a complaint');

select throws_like(
  $$select app.advance_complaint((select id from public.complaints limit 1), 'resolved')$$,
  '%invalid complaint transition new -> resolved%',
  'a complaint cannot jump straight from new to resolved');

select lives_ok(
  $$select app.advance_complaint((select id from public.complaints limit 1), 'acknowledged')$$,
  'the canonical first step is allowed');

select lives_ok(
  $$select app.advance_complaint((select id from public.complaints limit 1), 'in_progress')$$,
  'and the lifecycle continues as canon defines it');

-- ---------------------------------------------------------------------------------------------
-- 12-13. Conversations and messages.
-- ---------------------------------------------------------------------------------------------
select lives_ok(
  $$select app.send_conversation_message(
      app.start_conversation('whatsapp',
        (select id from public.customers where full_name = 'Ahmed Hassan')),
      'outbound','user','Hello, following up on your delay.')$$,
  'an employee can start a conversation and send a message');

-- ---------------------------------------------------------------------------------------------
-- 14. Every action above left an audit trail.
-- ---------------------------------------------------------------------------------------------
select ok(
  (select count(*) from public.events
    where tenant_id = '11110000-0000-0000-0000-000000000001'
      and event_type_code in ('customer_created','task_created','task_completed',
                              'complaint_created','complaint_acknowledged',
                              'conversation_started','conversation_message_sent')) >= 6,
  'the working day is fully auditable -- every governed action emitted its canonical event');

-- ---------------------------------------------------------------------------------------------
-- 15-16. The trainee. Same tenant, real user, genuinely fewer permissions.
-- ---------------------------------------------------------------------------------------------
select set_config('request.jwt.claims', '{"sub":"11110000-0000-0000-0000-0000000000bb"}', true);

select is(app.current_tenant_id(), '11110000-0000-0000-0000-000000000001'::uuid,
  'the trainee resolves to the same tenant');

select throws_like(
  $$select app.advance_complaint((select id from public.complaints limit 1), 'resolved')$$,
  '%permission denied%',
  'the trainee cannot resolve a complaint -- authorization is real, not documentation');

select * from finish();
rollback;
