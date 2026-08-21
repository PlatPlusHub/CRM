-- pgTAP invariants: an approval request has exactly one subject, and its typed accessors cannot
-- disagree with it. Guard for REL-2 (SPEC-135).
--
-- The defect: approval_requests carries a polymorphic subject AND typed FKs, and nothing stopped a
-- row saying related_entity_id = X while booking_item_id = Y. app.review_finance_approval joins on
-- booking_item_id, so it would have approved Y while the audit trail said the request was about X --
-- a silent divergence in a finance path.
create extension if not exists pgtap with schema extensions;

begin;
select plan(5);

insert into public.tenants (id, name, slug, status) values
  ('33330000-0000-0000-0000-000000000001','Approval Co','approval-co','active');
insert into public.branches (id, tenant_id, name, slug) values
  ('33330000-0000-0000-0000-000000000002','33330000-0000-0000-0000-000000000001','B','ap-b');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('33330000-0000-0000-0000-000000000003','33330000-0000-0000-0000-000000000001','33330000-0000-0000-0000-000000000002','finance','F');
insert into public.users (id, tenant_id, full_name, email, is_active) values
  ('33330000-0000-0000-0000-000000000004','33330000-0000-0000-0000-000000000001','U','ap@example.com',true);
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('33330000-0000-0000-0000-0000000000c1','33330000-0000-0000-0000-000000000001','person','C');
insert into public.bookings (id, tenant_id, customer_id, branch_id, department_id, booking_status_code, title, booking_reference) values
  ('33330000-0000-0000-0000-0000000000b1','33330000-0000-0000-0000-000000000001','33330000-0000-0000-0000-0000000000c1',
   '33330000-0000-0000-0000-000000000002','33330000-0000-0000-0000-000000000003','draft','B','AP-REF-1');
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code) values
  ('33330000-0000-0000-0000-0000000000e1','33330000-0000-0000-0000-000000000001','33330000-0000-0000-0000-0000000000b1','flight_ticket','EGP',100,150,'draft'),
  ('33330000-0000-0000-0000-0000000000e2','33330000-0000-0000-0000-000000000001','33330000-0000-0000-0000-0000000000b1','hotel','EGP',200,250,'draft');

-- 1. THE DEFECT: the polymorphic subject names item 1 while the typed accessor names item 2.
select throws_ok(
  $$insert into public.approval_requests (tenant_id, approval_type_code, approval_status_code,
        requested_by, related_entity_type, related_entity_id, booking_item_id, requested_at)
    values ('33330000-0000-0000-0000-000000000001','finance_execution_approval','pending',
            '33330000-0000-0000-0000-000000000004','booking_item',
            '33330000-0000-0000-0000-0000000000e1','33330000-0000-0000-0000-0000000000e2', now())$$,
  '23514', null,
  'a typed accessor naming a DIFFERENT row than the subject is refused');

-- 2. The typed accessor must match the subject TYPE, not merely point at a real row. Note the
--    subject here is a REAL booking, so SPEC-130's entity-reference trigger is satisfied and passes
--    the row through -- it is this migration's CHECK that must catch the type mismatch. (The first
--    draft of this case used a subject that did not exist, and was caught by SPEC-130 with 23503
--    instead: a reminder that a passing negative test proves nothing until you know WHICH guard
--    fired.)
select throws_ok(
  $$insert into public.approval_requests (tenant_id, approval_type_code, approval_status_code,
        requested_by, related_entity_type, related_entity_id, booking_item_id, requested_at)
    values ('33330000-0000-0000-0000-000000000001','finance_execution_approval','pending',
            '33330000-0000-0000-0000-000000000004','booking',
            '33330000-0000-0000-0000-0000000000b1','33330000-0000-0000-0000-0000000000e1', now())$$,
  '23514', null,
  'a typed accessor whose subject TYPE disagrees is refused by the consistency CHECK');

-- 3. An approval is always about something -- canon lists the subject as a core field.
select throws_ok(
  $$insert into public.approval_requests (tenant_id, approval_type_code, approval_status_code,
        requested_by, requested_at)
    values ('33330000-0000-0000-0000-000000000001','discount_approval','pending',
            '33330000-0000-0000-0000-000000000004', now())$$,
  '23502', null,
  'an approval request with no subject at all is refused');

-- 4. The agreeing case -- what request_finance_approval actually writes -- must still work.
select lives_ok(
  $$insert into public.approval_requests (tenant_id, approval_type_code, approval_status_code,
        requested_by, related_entity_type, related_entity_id, booking_item_id, requested_at)
    values ('33330000-0000-0000-0000-000000000001','finance_execution_approval','pending',
            '33330000-0000-0000-0000-000000000004','booking_item',
            '33330000-0000-0000-0000-0000000000e1','33330000-0000-0000-0000-0000000000e1', now())$$,
  'the agreeing representation still succeeds');

-- 5. An approval type with no typed column at all is still valid -- canon supports seven types and
--    only two have one, so the generic path must not have been broken by this constraint.
select lives_ok(
  $$insert into public.approval_requests (tenant_id, approval_type_code, approval_status_code,
        requested_by, related_entity_type, related_entity_id, requested_at)
    values ('33330000-0000-0000-0000-000000000001','discount_approval','pending',
            '33330000-0000-0000-0000-000000000004','booking',
            '33330000-0000-0000-0000-0000000000b1', now())$$,
  'an approval type with no typed accessor works through the polymorphic subject alone');

select * from finish();
rollback;
