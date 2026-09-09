-- pgTAP: BOOK-8 and BOOK-9 -- owner decisions, ratified 2026-09-09.
--
-- BOOK-8  a raised finance-approval requirement may be withdrawn, but only by WITHDRAW_FINANCE_APPROVAL,
--         with a fresh reason, and only while withdrawal is still operationally valid.
-- BOOK-9  moving a booked service away from the colleague holding it costs REASSIGN_BOOKING_ITEM.
--
-- Both are attacked on the TABLE door as well as the RPC: `authenticated` holds INSERT and UPDATE on
-- public.booking_items and PostgREST serves it (BOOK-1), and both of these decisions are precisely
-- about what a direct UPDATE may do.
create extension if not exists pgtap with schema extensions;

begin;
select plan(26);

-- =============================================================================================
-- FIXTURE. Actors chosen for what they do NOT hold:
--   employee         CREATE_BOOKING_ITEM only -- raised the requirement, owns nothing else
--   finance_manager  APPROVE_FINANCE + WITHDRAW_FINANCE_APPROVAL, no CREATE_BOOKING_ITEM
--   department_manager CREATE_BOOKING_ITEM + REASSIGN_BOOKING_ITEM, no finance authority
-- =============================================================================================
insert into auth.users (id, email) values
  ('b8000000-0000-0000-0000-0000000000a1','emp@bk89.test'),
  ('b8000000-0000-0000-0000-0000000000a2','fin@bk89.test'),
  ('b8000000-0000-0000-0000-0000000000a3','dpt@bk89.test');
insert into public.tenants (id, name, slug, status) values
  ('b8000000-0000-0000-0000-000000000001','Alpha Travel','alpha-bk89','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select 'b8000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('b8000000-0000-0000-0000-00000000000a','b8000000-0000-0000-0000-000000000001','Cairo','bk89-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('b8000000-0000-0000-0000-0000000000c1','b8000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('b8000000-0000-0000-0000-000000000011','b8000000-0000-0000-0000-000000000001','Emp','emp@bk89.test',true,'b8000000-0000-0000-0000-0000000000a1'),
  ('b8000000-0000-0000-0000-000000000012','b8000000-0000-0000-0000-000000000001','Fin','fin@bk89.test',true,'b8000000-0000-0000-0000-0000000000a2'),
  ('b8000000-0000-0000-0000-000000000013','b8000000-0000-0000-0000-000000000001','Dpt','dpt@bk89.test',true,'b8000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select 'b8000000-0000-0000-0000-000000000001', u, 'b8000000-0000-0000-0000-00000000000a','b8000000-0000-0000-0000-0000000000c1', true
from unnest(array['b8000000-0000-0000-0000-000000000011'::uuid,
                  'b8000000-0000-0000-0000-000000000012'::uuid,
                  'b8000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'b8000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('b8000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('b8000000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('b8000000-0000-0000-0000-000000000013'::uuid,'department_manager')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('b8000000-0000-0000-0000-0000000000d1','b8000000-0000-0000-0000-000000000001','person','Alpha Cust');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
    owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('b8000000-0000-0000-0000-0000000000f1','b8000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-00000000000a','b8000000-0000-0000-0000-0000000000c1','b8000000-0000-0000-0000-0000000000d1','b8000000-0000-0000-0000-000000000011','b8000000-0000-0000-0000-00000000000a','b8000000-0000-0000-0000-0000000000c1','draft','Alpha bk','BK-BK89-1');

-- e1 carries a raised, still-pending requirement; e2 is already APPROVED with a locked cost;
-- e3 is the reassignment target, owned by the employee.
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code, is_archived,
    owner_user_id, sales_owner_user_id, operational_owner_user_id, owner_branch_id, owner_department_id,
    currency_code, finance_approval_required, finance_approval_status_code, cost_locked_at) values
  ('b8000000-0000-0000-0000-0000000000e1','b8000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-0000000000f1','flight_ticket','draft',false,'b8000000-0000-0000-0000-000000000011','b8000000-0000-0000-0000-000000000011','b8000000-0000-0000-0000-000000000011','b8000000-0000-0000-0000-00000000000a','b8000000-0000-0000-0000-0000000000c1','EGP',true,'pending',null),
  ('b8000000-0000-0000-0000-0000000000e2','b8000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-0000000000f1','flight_ticket','draft',false,'b8000000-0000-0000-0000-000000000011','b8000000-0000-0000-0000-000000000011','b8000000-0000-0000-0000-000000000011','b8000000-0000-0000-0000-00000000000a','b8000000-0000-0000-0000-0000000000c1','EGP',true,'approved',now()),
  ('b8000000-0000-0000-0000-0000000000e3','b8000000-0000-0000-0000-000000000001','b8000000-0000-0000-0000-0000000000f1','flight_ticket','draft',false,'b8000000-0000-0000-0000-000000000011','b8000000-0000-0000-0000-000000000011','b8000000-0000-0000-0000-000000000011','b8000000-0000-0000-0000-00000000000a','b8000000-0000-0000-0000-0000000000c1','EGP',false,null,null);

-- The still-pending request is deliberate: BOOK-8 promises to close the live request in the same
-- transaction as the requirement, so the test must exercise that promise rather than pass because
-- no request existed.
insert into public.approval_requests (
    id, tenant_id, approval_type_code, approval_status_code, requested_by,
    related_entity_type, related_entity_id, booking_item_id, reason
) values (
    'b8000000-0000-0000-0000-0000000000d8',
    'b8000000-0000-0000-0000-000000000001',
    'finance_execution_approval', 'pending', 'b8000000-0000-0000-0000-000000000011',
    'booking_item', 'b8000000-0000-0000-0000-0000000000e1',
    'b8000000-0000-0000-0000-0000000000e1', 'manager approval required'
);

-- =============================================================================================
-- 1-4. THE TWO CAPABILITIES AND THEIR BUNDLES.
-- =============================================================================================
select is(
  (select string_agg(r.code, ',' order by r.code) from public.role_permissions rp
     join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id
    where p.key = 'WITHDRAW_FINANCE_APPROVAL'),
  (select string_agg(r.code, ',' order by r.code) from public.role_permissions rp
     join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id
    where p.key = 'APPROVE_FINANCE'),
  'BOOK-8''s bundle is DERIVED, not chosen: whoever would otherwise have to SATISFY the requirement is who may decide it does not apply');

select is(
  (select string_agg(r.code, ',' order by r.code) from public.role_permissions rp
     join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id
    where p.key = 'REASSIGN_BOOKING_ITEM'),
  (select string_agg(r.code, ',' order by r.code) from public.role_permissions rp
     join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id
    where p.key = 'REASSIGN_LEAD'),
  'BOOK-9''s bundle is the REASSIGN_LEAD population exactly -- the booking-item counterpart of the authority canon 28 already gives leads');

select isnt(
  (select string_agg(r.code, ',' order by r.code) from public.role_permissions rp
     join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id
    where p.key = 'REASSIGN_BOOKING_ITEM'),
  (select string_agg(r.code, ',' order by r.code) from public.role_permissions rp
     join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id
    where p.key = 'CREATE_BOOKING_ITEM'),
  'AND IT IS NOT CREATE_BOOKING_ITEM''S: employee and senior_employee are exactly the population this capability exists to exclude');

select is(
  (select string_agg(code, ',' order by code) from public.catalog_values
    where catalog_type_code = 'event_type'
      and code in ('finance_approval_requirement_withdrawn','booking_item_reassigned')),
  'booking_item_reassigned,finance_approval_requirement_withdrawn',
  'both audit vocabularies are registered');

-- =============================================================================================
-- 5-9. BOOK-8 ON THE TABLE DOOR: who may NOT withdraw.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"b8000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('CREATE_BOOKING_ITEM') and not app.has_permission('WITHDRAW_FINANCE_APPROVAL'),
  'POSITIVE/NEGATIVE CONTROL: the employee holds the authority that RAISED the requirement and not the one that withdraws it');

select throws_ok(
  $q$update public.booking_items set finance_approval_required = false
      where id = 'b8000000-0000-0000-0000-0000000000e1'$q$,
  '42501', NULL,
  'THE DECISION, ENFORCED: CREATE_BOOKING_ITEM is NOT sufficient to withdraw a finance requirement -- BOOK-6 refused this outright, and BOOK-8 keeps refusing it for this actor');

select throws_ok(
  $q$select app.withdraw_finance_approval('b8000000-0000-0000-0000-0000000000e1','changed my mind')$q$,
  '42501', NULL,
  '...and the sanctioned RPC refuses the same actor identically');

select is(
  (select finance_approval_required::text from public.booking_items where id = 'b8000000-0000-0000-0000-0000000000e1'),
  'true',
  'GROUND TRUTH: the requirement is still standing after both refusals');

select lives_ok(
  $q$update public.booking_items set finance_approval_required = true
      where id = 'b8000000-0000-0000-0000-0000000000e3'$q$,
  'RAISING IS UNCHANGED: the employee can still raise a requirement under CREATE_BOOKING_ITEM -- BOOK-8 changed the lowering arm only');

-- =============================================================================================
-- 10-16. BOOK-8, THE SANCTIONED WITHDRAWAL AND ITS LIMITS.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"b8000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('WITHDRAW_FINANCE_APPROVAL') and app.has_permission('APPROVE_FINANCE'),
  'POSITIVE CONTROL: the finance manager genuinely holds the withdrawal capability');

select throws_ok(
  $q$update public.booking_items set finance_approval_required = false
      where id = 'b8000000-0000-0000-0000-0000000000e1'$q$,
  '23514', NULL,
  'A BARE LOWERING IS STILL REFUSED, even for a capability holder: without a reason there is no evidence, and BOOK-6''s door stays shut to an unattributed flip');

select throws_ok(
  $q$select app.withdraw_finance_approval('b8000000-0000-0000-0000-0000000000e2','re-scoped below the threshold')$q$,
  '23514', NULL,
  'HISTORY IS NOT REWRITTEN: the requirement on an item whose approval was GRANTED and whose cost is LOCKED cannot be withdrawn -- past that gate a reversal is a new auditable action');

select lives_ok(
  $q$select app.withdraw_finance_approval('b8000000-0000-0000-0000-0000000000e1','item re-scoped below the approval threshold')$q$,
  'THE SANCTIONED WITHDRAWAL WORKS: capability plus fresh reason lifts a still-pending requirement');

reset role;
select is(
  (select finance_approval_required::text || '|' || finance_approval_withdrawal_reason || '|' || finance_approval_withdrawn_by::text
     from public.booking_items where id = 'b8000000-0000-0000-0000-0000000000e1'),
  'false|item re-scoped below the approval threshold|b8000000-0000-0000-0000-000000000012',
  '...and the row records the reason and the SERVER-STAMPED actor beside the requirement it lifted');

select is(
  (select approval_status_code || '|' || reviewed_by::text from public.approval_requests
    where booking_item_id = 'b8000000-0000-0000-0000-0000000000e1'),
  'cancelled|b8000000-0000-0000-0000-000000000012',
  'the pending request is closed in the same transaction and its reviewer is server-derived -- no orphaned finance task survives the withdrawal');

select is(
  (select previous_state || ' -> ' || new_state || ' [' || severity_code || ']'
     from public.events where event_type_code = 'finance_approval_requirement_withdrawn'
      and entity_id = 'b8000000-0000-0000-0000-0000000000e1'),
  'required -> withdrawn [critical]',
  'PAX-6''s discipline applied here too: the withdrawal emitted exactly one CRITICAL event -- removing a financial gate is not routine');

-- =============================================================================================
-- 17-22. BOOK-9.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"b8000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('CREATE_BOOKING_ITEM') and not app.has_permission('REASSIGN_BOOKING_ITEM'),
  'POSITIVE/NEGATIVE CONTROL: the employee can edit booking items but genuinely lacks the independent reassignment authority');

select throws_ok(
  $q$update public.booking_items set owner_user_id = 'b8000000-0000-0000-0000-000000000013'
      where id = 'b8000000-0000-0000-0000-0000000000e3'$q$,
  '42501', NULL,
  'THE REPRODUCTION, CLOSED: an employee holding CREATE_BOOKING_ITEM can no longer hand a colleague''s booked service to someone else. 105 assertion 15 asserted this SUCCEEDED and flips with this change');

select throws_ok(
  $q$update public.booking_items set owner_user_id = null
      where id = 'b8000000-0000-0000-0000-0000000000e3'$q$,
  '42501', NULL,
  'NO TWO-STEP BYPASS: clearing an occupied owner slot costs the same authority, so "owner -> null, then null -> me" is not a free path around it');

select lives_ok(
  $q$update public.booking_items set sub_status_code = null
      where id = 'b8000000-0000-0000-0000-0000000000e3'$q$,
  'ORDINARY WORK IS UNTOUCHED: an edit that moves no owner stays under CREATE_BOOKING_ITEM (TASK-1''s shape -- the guard fires only when ownership actually moves)');

reset role;
select set_config('request.jwt.claims','{"sub":"b8000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $q$select app.reassign_booking_item('b8000000-0000-0000-0000-0000000000e3','staff transfer to Giza branch','b8000000-0000-0000-0000-000000000013')$q$,
  'THE SANCTIONED PATH: a department manager holding REASSIGN_BOOKING_ITEM moves the item with a reason');

reset role;
select is(
  (select owner_user_id::text || '|' || sales_owner_user_id::text || '|' || reassignment_reason || '|' || reassigned_by::text
     from public.booking_items where id = 'b8000000-0000-0000-0000-0000000000e3'),
  'b8000000-0000-0000-0000-000000000013|b8000000-0000-0000-0000-000000000011|staff transfer to Giza branch|b8000000-0000-0000-0000-000000000013',
  '...only the named owner moved -- the sales owner the caller did not name is untouched -- and the reason and actor are recorded');

-- =============================================================================================
-- 23-24. THE AUDIT, AND WHAT REASSIGNMENT DOES NOT REWRITE.
-- =============================================================================================
select is(
  (select (payload ->> 'previous_owner_user_id') || ' -> ' || (payload ->> 'new_owner_user_id') || ' : ' || reason
     from public.events where event_type_code = 'booking_item_reassigned'
      and entity_id = 'b8000000-0000-0000-0000-0000000000e3'),
  'b8000000-0000-0000-0000-000000000011 -> b8000000-0000-0000-0000-000000000013 : staff transfer to Giza branch',
  'THE AUDIT: one booking_item_reassigned carrying the old owner, the new owner, the actor (via record_event) and the reason -- ORVION has no commission ledger, so this event is what keeps "who held it when" answerable');

select is(
  (select count(*)::int from information_schema.tables
    where table_schema = 'public' and table_name ~ 'commission'),
  0,
  'STATED ACCURATELY RATHER THAN ASSUMED: there is no commission LEDGER table for a reassignment to corrupt. commission_rate is set from the tenant-wide default by app.derive_commission_rate and does not depend on who owns the item');

-- =============================================================================================
-- 25-26. LOAD-BEARING (PAR-4 defect injection), one per decision.
-- =============================================================================================
savepoint before_enforcer_mutation;
drop trigger booking_items_guard_reassignment on public.booking_items;
select set_config('request.jwt.claims','{"sub":"b8000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $q$update public.booking_items set owner_user_id = 'b8000000-0000-0000-0000-000000000011'
      where id = 'b8000000-0000-0000-0000-0000000000e3'$q$,
  'MUTATION: with the reassignment guard dropped the employee takes the item back again -- so that trigger is what closes BOOK-9, and nothing else was doing it');

rollback to savepoint before_enforcer_mutation;
select set_config('request.jwt.claims','{"sub":"b8000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $q$update public.booking_items set owner_user_id = 'b8000000-0000-0000-0000-000000000011'
      where id = 'b8000000-0000-0000-0000-0000000000e3'$q$,
  '42501', NULL,
  'RESTORED: with the trigger back the identical grab is refused again');

select finish();
rollback;
