-- pgTAP: SPEC-299 (Batch 6 Slice 44, AR-1, AR-2, AR-3) -- a decided approval request is
-- final, and an item has at most one pending finance request (`20261109120000`).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY REPLAY PRIVILEGE BUSINESS OBSERVABILITY=N/A
--   OBSERVABILITY=N/A -- the guard refuses; it records nothing, and the RPCs' events are pinned by
--     their own tests.
--   CONCURRENCY -- two overlapping reviews or requests need two live sessions, which pgTAP does not
--     have. The races are proven by the Batch 6 two-session probe, with and without the repair;
--     here the rule they rest on is pinned on every door: a queued second reviewer meets OLD
--     already decided, which is exactly the direct UPDATE below.
create extension if not exists pgtap with schema extensions;

begin;
select plan(14);

insert into auth.users (id, email) values
  ('15900000-0000-0000-0000-0000000000a1','emp@c159.test'),
  ('15900000-0000-0000-0000-0000000000a2','fin@c159.test');
insert into public.tenants (id, name, slug, status) values
  ('15900000-0000-0000-0000-000000000001','Approvals Travel','approvals-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '15900000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('15900000-0000-0000-0000-00000000000a','15900000-0000-0000-0000-000000000001','Main','main-159');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('15900000-0000-0000-0000-0000000000c1','15900000-0000-0000-0000-000000000001','15900000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('15900000-0000-0000-0000-000000000011','15900000-0000-0000-0000-000000000001','Employee','emp@c159.test',true,'15900000-0000-0000-0000-0000000000a1'),
  ('15900000-0000-0000-0000-000000000012','15900000-0000-0000-0000-000000000001','Finance','fin@c159.test',true,'15900000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '15900000-0000-0000-0000-000000000001', u, '15900000-0000-0000-0000-00000000000a', '15900000-0000-0000-0000-0000000000c1', true
from unnest(array['15900000-0000-0000-0000-000000000011'::uuid,'15900000-0000-0000-0000-000000000012']) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '15900000-0000-0000-0000-000000000001', v.uid, r.id, 'tenant'
from (values ('15900000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('15900000-0000-0000-0000-000000000012'::uuid,'finance_manager')) v(uid, role_code)
join public.roles r on r.code = v.role_code;
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('15900000-0000-0000-0000-0000000000d1','15900000-0000-0000-0000-000000000001','person','Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
                             owner_branch_id, owner_department_id, booking_status_code, title, booking_reference)
select b.id, '15900000-0000-0000-0000-000000000001', '15900000-0000-0000-0000-00000000000a', '15900000-0000-0000-0000-0000000000c1',
       '15900000-0000-0000-0000-0000000000d1', '15900000-0000-0000-0000-000000000011',
       '15900000-0000-0000-0000-00000000000a', '15900000-0000-0000-0000-0000000000c1', 'draft', 'Booking', b.ref
from (values ('15900000-0000-0000-0000-0000000000f1'::uuid,'BK-159-1'), ('15900000-0000-0000-0000-0000000000f2'::uuid,'BK-159-2')) b(id, ref);
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
                                  owner_user_id, owner_branch_id, owner_department_id,
                                  currency_code, cost_amount, selling_amount)
select i.id, '15900000-0000-0000-0000-000000000001', i.booking, 'hotel', 'draft',
       '15900000-0000-0000-0000-000000000011', '15900000-0000-0000-0000-00000000000a', '15900000-0000-0000-0000-0000000000c1',
       'EGP', 3000, 5000
from (values ('15900000-0000-0000-0000-0000000000e1'::uuid,'15900000-0000-0000-0000-0000000000f1'::uuid),
             ('15900000-0000-0000-0000-0000000000e2'::uuid,'15900000-0000-0000-0000-0000000000f1'::uuid),
             ('15900000-0000-0000-0000-0000000000e3'::uuid,'15900000-0000-0000-0000-0000000000f1'::uuid),
             ('15900000-0000-0000-0000-0000000000e4'::uuid,'15900000-0000-0000-0000-0000000000f2'::uuid)) i(id, booking);

select is(
  (select count(*)::int from pg_indexes
   where schemaname = 'public' and indexname = 'approval_requests_one_pending_finance_per_item'
     and indexdef like '%UNIQUE%' and indexdef like '%pending%'),
  1,
  'AR-2: one pending finance request per booking item is a unique rule, not an RPC check');

-- The employee requests finance approval on items 1-4 through the RPC.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"15900000-0000-0000-0000-0000000000a1"}', true);
select lives_ok(
  $$select app.request_finance_approval(i, 'needs sign-off') from unnest(array[
      '15900000-0000-0000-0000-0000000000e1'::uuid, '15900000-0000-0000-0000-0000000000e2',
      '15900000-0000-0000-0000-0000000000e3', '15900000-0000-0000-0000-0000000000e4']) i$$,
  'the requester opens one pending finance request on each of four items');

select throws_ok(
  $$insert into public.approval_requests (tenant_id, approval_type_code, approval_status_code, related_entity_type,
                                          related_entity_id, booking_item_id, reason)
    values ('15900000-0000-0000-0000-000000000001', 'finance_execution_approval', 'pending', 'booking_item',
            '15900000-0000-0000-0000-0000000000e1', '15900000-0000-0000-0000-0000000000e1', 'again')$$,
  '23505', null,
  'AR-2: a second pending finance request for the same item is refused on the table door too -- an overlapping RPC call meets the same key');

-- The finance manager decides.
select set_config('request.jwt.claims', '{"sub":"15900000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select lives_ok(
  $$select app.review_finance_approval((select id from public.approval_requests where booking_item_id = '15900000-0000-0000-0000-0000000000e1'), 'approved', 'ok')$$,
  'the reviewer approves item 1 through the RPC');

select throws_ok(
  $$update public.approval_requests set approval_status_code = 'rejected'
    where booking_item_id = '15900000-0000-0000-0000-0000000000e1'$$,
  '23514', null,
  'AR-1: approved -> rejected is refused -- the write a second reviewer queued behind the first makes, after its stale pending check');

select is(
  (select bi.cost_locked_at is not null and bi.finance_approval_status_code = 'approved' and ar.approval_status_code = 'approved'
   from public.booking_items bi join public.approval_requests ar on ar.booking_item_id = bi.id
   where bi.id = '15900000-0000-0000-0000-0000000000e1'),
  true,
  '...so the request and the item agree: approved, with the cost locked');

select throws_ok(
  $$update public.approval_requests set approval_status_code = 'pending'
    where booking_item_id = '15900000-0000-0000-0000-0000000000e1'$$,
  '23514', null,
  'a decided request cannot be reopened either');

select lives_ok(
  $$update public.approval_requests set payload = '{"note":"filed"}'::jsonb
    where booking_item_id = '15900000-0000-0000-0000-0000000000e1'$$,
  'an edit that does not move the status is unaffected -- the guard fires on decisions only');

select lives_ok(
  $$select app.review_finance_approval((select id from public.approval_requests where booking_item_id = '15900000-0000-0000-0000-0000000000e2'), 'rejected', 'over budget')$$,
  'the reviewer rejects item 2 through the RPC');

select throws_ok(
  $$update public.approval_requests set approval_status_code = 'approved'
    where booking_item_id = '15900000-0000-0000-0000-0000000000e2'$$,
  '23514', null,
  'AR-3: rejected -> approved by plain SQL is refused (measured before the repair: accepted, item left rejected)');

select lives_ok(
  $$select app.withdraw_finance_approval('15900000-0000-0000-0000-0000000000e3', 'not needed')$$,
  'the reviewer withdraws item 3''s finance requirement; its pending request is cancelled');

select throws_ok(
  $$update public.approval_requests set approval_status_code = 'approved'
    where booking_item_id = '15900000-0000-0000-0000-0000000000e3'$$,
  '23514', null,
  'AR-1: an approval cannot land on a withdrawn request (measured before the repair: a queued approval overwrote it and locked the cost)');

-- Booking 2 is cancelled; its item's request is still pending.
reset role;
select set_config('request.jwt.claims', '', true);
update public.bookings set booking_status_code = 'cancelled' where id = '15900000-0000-0000-0000-0000000000f2';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"15900000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select throws_ok(
  $$update public.approval_requests set approval_status_code = 'approved'
    where booking_item_id = '15900000-0000-0000-0000-0000000000e4'$$,
  '23514', null,
  'AR-3: the RPC''s parent-state rule holds on the table door -- no approval for a cancelled booking');

select lives_ok(
  $$update public.approval_requests set approval_status_code = 'rejected'
    where booking_item_id = '15900000-0000-0000-0000-0000000000e4'$$,
  '...while rejecting it stays possible: the rule refuses approval, not closure');

select * from finish();
rollback;
