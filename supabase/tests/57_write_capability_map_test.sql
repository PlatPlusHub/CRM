-- pgTAP: SEC-1 (partial) -- nine tables now charge the permission their own RPC charges.
--
-- The rule these guards follow needs no business decision: the documented path already states what
-- each operation costs, and direct DML simply was not charging it. Where an RPC authorizes nothing
-- (`app.record_lead_interaction`, `app.capture_attribution_click`) or no RPC writes the table at
-- all, there is no evidence-based answer and nothing was guessed -- those tables remain under SEC-1.
--
-- Assertion 9 is the one that matters most and is the reason the UPDATE exclusion exists:
-- `approval_requests` is updated by `app.review_finance_approval`, and `finance_manager` does NOT
-- hold `CREATE_BOOKING_ITEM`. Charging the insert permission on UPDATE would have broken the
-- approval workflow FIN-2 repaired one migration earlier. This file proves it did not.
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email) values
  ('57000000-0000-0000-0000-0000000000a1','emp@wc.test'),
  ('57000000-0000-0000-0000-0000000000a2','fin@wc.test'),
  ('57000000-0000-0000-0000-0000000000a3','train@wc.test');
insert into public.tenants (id, name, slug, status) values
  ('57000000-0000-0000-0000-000000000001','WC Travel','wc-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '57000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('57000000-0000-0000-0000-00000000000a','57000000-0000-0000-0000-000000000001','Cairo','wc-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('57000000-0000-0000-0000-0000000000c1','57000000-0000-0000-0000-000000000001','57000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('57000000-0000-0000-0000-000000000011','57000000-0000-0000-0000-000000000001','Emp','emp@wc.test',true,'57000000-0000-0000-0000-0000000000a1'),
  ('57000000-0000-0000-0000-000000000012','57000000-0000-0000-0000-000000000001','Fin','fin@wc.test',true,'57000000-0000-0000-0000-0000000000a2'),
  ('57000000-0000-0000-0000-000000000013','57000000-0000-0000-0000-000000000001','Trainee','train@wc.test',true,'57000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '57000000-0000-0000-0000-000000000001', u, '57000000-0000-0000-0000-00000000000a','57000000-0000-0000-0000-0000000000c1', true
from unnest(array['57000000-0000-0000-0000-000000000011'::uuid,'57000000-0000-0000-0000-000000000012'::uuid,'57000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '57000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('57000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('57000000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('57000000-0000-0000-0000-000000000013'::uuid,'trainee')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('57000000-0000-0000-0000-0000000000d1','57000000-0000-0000-0000-000000000001','person','C','+201000000041');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id) values
  ('57000000-0000-0000-0000-0000000000b1','57000000-0000-0000-0000-000000000001','57000000-0000-0000-0000-00000000000a','57000000-0000-0000-0000-0000000000c1','57000000-0000-0000-0000-0000000000d1','draft','T','BR-WC-1','57000000-0000-0000-0000-000000000011');
insert into public.conversations (id, tenant_id, customer_id, channel_code, conversation_status_code) values
  ('57000000-0000-0000-0000-0000000000e1','57000000-0000-0000-0000-000000000001','57000000-0000-0000-0000-0000000000d1','whatsapp','open');

-- =============================================================================================
-- 1-3. THE TRAINEE, against a table it can genuinely SEE. `customers` is tenant-readable, so the
--      trainee reaches the parent row and the denial below is unambiguously about CAPABILITY.
--
--      The first version of this file aimed the trainee at `conversation_messages` and its own
--      positive control failed: a trainee cannot see conversations at all (no VIEW_CONVERSATION),
--      so the denial would have proved only that it could not reach the row -- exactly the vacuous
--      shape the directive forbids. The table under test was changed rather than the assertion
--      weakened.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"57000000-0000-0000-0000-0000000000a3"}', true);

select is(
  (select count(*)::int from public.customers where id = '57000000-0000-0000-0000-0000000000d1'),
  1,
  'POSITIVE CONTROL: the trainee can SEE the customer -- the denial below is capability, not reach');

select is(
  app.has_permission('CREATE_CUSTOMER'), false,
  '...and holds no CREATE_CUSTOMER');

select throws_ok(
  $$insert into public.customer_contact_methods (tenant_id, customer_id, contact_method_type_code, value)
    values ('57000000-0000-0000-0000-000000000001','57000000-0000-0000-0000-0000000000d1','primary_phone','+201000000099')$$,
  '42501', null,
  'a trainee CANNOT add a contact method by direct DML -- the table now charges what add_customer_contact_method charges');

-- =============================================================================================
-- 4-5. THE EMPLOYEE CAN. A guard that stopped the frontline doing its job would be the worse defect.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"57000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

-- The SAME table and the SAME row the trainee was refused, so the two assertions differ in exactly
-- one variable: the actor's capability. (An earlier draft used `conversation_messages` here and hit
-- an RLS refusal instead -- the fixture's conversation had no branch or assignment, so the employee
-- could not see the parent either. Keeping both controls on one reachable row removes that noise.)
select lives_ok(
  $$insert into public.customer_contact_methods (tenant_id, customer_id, contact_method_type_code, value)
    values ('57000000-0000-0000-0000-000000000001','57000000-0000-0000-0000-0000000000d1','primary_phone','+201000000098')$$,
  'POSITIVE CONTROL: the employee CAN -- they hold CREATE_CUSTOMER');

select is(
  (select count(*)::int from public.customer_contact_methods where customer_id = '57000000-0000-0000-0000-0000000000d1'),
  1,
  '...and it persisted, so the denial above is not a blanket refusal');

-- =============================================================================================
-- 6-7. THE UNION CASE. `document_links` is written by two RPCs under two different permissions
--      (UPLOAD_DOCUMENT and MANAGE_TENANT_SETTINGS); holding EITHER is exactly what the existing
--      code permits, so the guard requires either -- never both, which would forbid writes ORVION
--      performs today.
-- =============================================================================================
select ok(
  app.has_permission('UPLOAD_DOCUMENT') and not app.has_permission('MANAGE_TENANT_SETTINGS'),
  'the employee holds ONE of the two document_links permissions -- the union is what makes this legal');

reset role;
select set_config('request.jwt.claims','{"sub":"57000000-0000-0000-0000-0000000000a3"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.document_links (tenant_id, document_id, booking_id)
    values ('57000000-0000-0000-0000-000000000001','57000000-0000-0000-0000-0000000000d1','57000000-0000-0000-0000-0000000000b1')$$,
  '42501', null,
  '...while the trainee holds NEITHER and is refused');

-- =============================================================================================
-- 8-9. THE UPDATE EXCLUSION, and why it exists. `approval_requests` INSERT charges
--      CREATE_BOOKING_ITEM; its UPDATE must NOT, because `app.review_finance_approval` is how
--      finance decides -- and finance_manager does not hold CREATE_BOOKING_ITEM.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"57000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select is(
  app.has_permission('CREATE_BOOKING_ITEM'), false,
  'finance holds NO CREATE_BOOKING_ITEM -- so charging it on UPDATE would have broken approvals');

reset role;
select set_config('request.jwt.claims', null, true);
insert into public.approval_requests (id, tenant_id, approval_type_code, approval_status_code, requested_by, related_entity_type, related_entity_id, requested_at)
values ('57000000-0000-0000-0000-0000000000f1','57000000-0000-0000-0000-000000000001','finance_execution_approval','pending','57000000-0000-0000-0000-000000000011','booking','57000000-0000-0000-0000-0000000000b1', now());

select set_config('request.jwt.claims','{"sub":"57000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$update public.approval_requests set approval_status_code = 'approved', reviewed_at = now()
     where id = '57000000-0000-0000-0000-0000000000f1'$$,
  '...and finance CAN still decide it -- FIN-2''s workflow survives this migration');

-- =============================================================================================
-- 10-11. THIS MIGRATION'S NINE ARE STILL GUARDED, and the approval_requests exclusion is structural.
--
--        The map-completeness pin (every trigger sits on a mapped table) moved to
--        `58_write_grants_and_config_capability_test.sql` when `202607056100` added four more
--        tables. One file owns that total; keeping a second copy here would only give the two
--        somewhere to disagree.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and t.tgname like '%\_guard\_write\_capability'
      and c.relname in ('approval_requests','conversation_messages','customer_contact_methods',
                        'customer_identity_signals','customer_identity_merges',
                        'internal_supplier_links','offline_conversions','document_links',
                        'lead_assignments')),
  9,
  'all nine tables this migration mapped still carry the write-capability guard');

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and t.tgname like '%\_guard\_write\_capability'
      and c.relname = 'approval_requests' and (t.tgtype::int & 16) > 0),
  0,
  'approval_requests carries the guard on INSERT only -- the UPDATE exclusion is structural, not a comment');

select finish();
rollback;
