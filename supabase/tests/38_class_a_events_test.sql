-- pgTAP: WP-02 / SPEC-153 -- the five Class A events, and the visibility question they raised.
--
-- Each event has a real producer that emitted nothing. The hard part is not emitting them; it is
-- proving the event lands where the right role can read it and the wrong role cannot -- which for
-- `payment_allocation_created` was a genuine defect waiting to happen: `has_tenant_wide_read()` is
-- `VIEW_ALL_BRANCHES`, held by ceo/owner ONLY, so without a dispatch branch the event would have been
-- invisible to finance_manager, the one role that most needs it.
--
-- Every denial below has a positive control proving the same actor could read something comparable
-- first. A denial whose actor could never have seen anything proves nothing.
create extension if not exists pgtap with schema extensions;

begin;
select plan(21);

insert into auth.users (id, email) values
  ('38000000-0000-0000-0000-0000000000a1','fin@wp2.test'),
  ('38000000-0000-0000-0000-0000000000a2','emp@wp2.test');
insert into public.tenants (id, name, slug, status) values
  ('38000000-0000-0000-0000-000000000001','WP2 Travel','wp2-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '38000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('38000000-0000-0000-0000-00000000000a','38000000-0000-0000-0000-000000000001','Cairo','wp2-cairo'),
  ('38000000-0000-0000-0000-00000000000b','38000000-0000-0000-0000-000000000001','Alex','wp2-alex');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('38000000-0000-0000-0000-0000000000c1','38000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-00000000000a','sales','Cairo Sales'),
  ('38000000-0000-0000-0000-0000000000c2','38000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-00000000000b','sales','Alex Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('38000000-0000-0000-0000-000000000011','38000000-0000-0000-0000-000000000001','Finance','fin@wp2.test',true,'38000000-0000-0000-0000-0000000000a1'),
  ('38000000-0000-0000-0000-000000000012','38000000-0000-0000-0000-000000000001','Employee','emp@wp2.test',true,'38000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('38000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-000000000011','38000000-0000-0000-0000-00000000000a','38000000-0000-0000-0000-0000000000c1',true),
  ('38000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-000000000012','38000000-0000-0000-0000-00000000000a','38000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '38000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-000000000011'::uuid, r.id,'tenant'
from public.roles r where r.code='finance_manager';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '38000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-000000000012'::uuid, r.id,'tenant'
from public.roles r where r.code='employee';

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('38000000-0000-0000-0000-0000000000d1','38000000-0000-0000-0000-000000000001','person','WP2 Customer','+201009991111');

-- =============================================================================================
-- 1-3. payment_allocation_created, through the REAL producer (app.record_payment), as Finance.
-- =============================================================================================
set local role authenticated;
-- `aal2` because app.requires_mfa() covers finance_manager: without it create_invoice raises
-- "multi-factor authentication required for this role". Modelling the real finance session.
select set_config('request.jwt.claims','{"sub":"38000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select lives_ok(
  $$select app.create_invoice('38000000-0000-0000-0000-0000000000d1','EGP', 1000)$$,
  'BASELINE: finance can raise an invoice');

-- An invoice must be issued before it can be paid; a draft invoice is not payable by design.
select lives_ok(
  $$select app.issue_invoice((select id from public.invoices limit 1))$$,
  'BASELINE: finance can issue the invoice');

select lives_ok(
  $$select app.record_payment((select id from public.invoices limit 1), 400, 'cash')$$,
  'BASELINE: finance can record a payment against it');

select is(
  (select count(*)::int from public.events where event_type_code='payment_allocation_created' and tenant_id='38000000-0000-0000-0000-000000000001'),
  1,
  'record_payment now emits exactly ONE payment_allocation_created -- it wrote the allocation but announced nothing before');

-- =============================================================================================
-- 4-7. THE VISIBILITY QUESTION. Finance must see it; an ordinary employee must not. Both halves
--      carry a positive control, because a "cannot see" assertion is worthless if the actor could
--      never see anything.
-- =============================================================================================
select is(
  (select count(*)::int from public.payment_allocations),
  1,
  'CONTROL: finance can read the allocation ROW itself (VIEW_FINANCIAL_DOCUMENTS)');

select is(
  (select count(*)::int from public.events where event_type_code='payment_allocation_created' and tenant_id='38000000-0000-0000-0000-000000000001'),
  1,
  '...and can therefore read its EVENT -- which without the new dispatch branch would have hit ELSE false, since finance_manager does NOT hold VIEW_ALL_BRANCHES');

select set_config('request.jwt.claims','{"sub":"38000000-0000-0000-0000-0000000000a2"}', true);

select isnt(
  (select count(*)::int from public.events where event_type_code='customer_created' and tenant_id='38000000-0000-0000-0000-000000000001'), 0,
  'CONTROL: the ordinary employee CAN read events in general -- so the next denial is about the subject, not an empty fixture');

select is(
  (select count(*)::int from public.events where event_type_code='payment_allocation_created' and tenant_id='38000000-0000-0000-0000-000000000001'),
  0,
  '...but CANNOT read the allocation event -- financial privacy follows the subject row, exactly as SPEC-143 intends');

-- =============================================================================================
-- 8-9. DIRECT DML still emits, and cross-tenant forgery is still impossible.
-- =============================================================================================
reset role;
-- ...and CLEAR the claim with it, which is what `reset role` was always meant to model. `reset role`
-- returns the session to postgres but leaves `request.jwt.claims` set, so `auth.uid()` still
-- resolved to the employee and FIN-3's new financial capability guard correctly refused: an
-- employee holds no RECORD_PAYMENT. The insert below is a SYSTEM path, and now genuinely is one.
-- (Third occurrence of this fixture artifact in the suite, after 31 and 37.)
select set_config('request.jwt.claims', null, true);
select lives_ok(
  $$insert into public.payment_allocations (tenant_id, payment_id, invoice_id, allocated_amount, currency_code)
    select '38000000-0000-0000-0000-000000000001', p.id, i.id, 100, 'EGP'
      from public.payments p, public.invoices i limit 1$$,
  'a DIRECT allocation insert on the SYSTEM path succeeds -- exempt from the capability check, never from the record');

select is(
  (select count(*)::int from public.events where event_type_code='payment_allocation_created' and tenant_id='38000000-0000-0000-0000-000000000001'),
  2,
  '...and ALSO emits its event -- an in-RPC emission would have missed the direct path entirely');

-- =============================================================================================
-- 10-13. trusted_device_revoked / _reverified, and the re-login case that must NOT fire.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"38000000-0000-0000-0000-0000000000a2"}', true);

select lives_ok($$select app.record_trusted_device('wp2-device')$$, 'BASELINE: a device can be trusted');

select is(
  (select count(*)::int from public.events where event_type_code='trusted_device_reverified' and tenant_id='38000000-0000-0000-0000-000000000001'),
  0,
  'an ordinary re-login touch does NOT emit reverified -- record_trusted_device updates last_seen_at every time, and firing there would spam an append-only spine');

select lives_ok(
  $$select app.revoke_trusted_device((select id from public.trusted_devices where device_identifier='wp2-device'))$$,
  'BASELINE: the device can be revoked');

select is(
  (select count(*)::int from public.events where event_type_code='trusted_device_revoked' and tenant_id='38000000-0000-0000-0000-000000000001'),
  1,
  'revoke_trusted_device now emits trusted_device_revoked -- it emitted nothing at all before');

select lives_ok($$select app.record_trusted_device('wp2-device')$$, 'BASELINE: the revoked device can be trusted again');

select is(
  (select count(*)::int from public.events where event_type_code='trusted_device_reverified' and tenant_id='38000000-0000-0000-0000-000000000001'),
  1,
  '...and THAT emits reverified -- a genuine return from revoked, not a routine touch');

-- =============================================================================================
-- 14-17. user_branch_transfer_completed: fires on a TRANSFER, never on first placement, and
--        `_started` is never fabricated (SPEC-153 Class B).
-- =============================================================================================
reset role;
select is(
  (select count(*)::int from public.events where event_type_code='user_branch_transfer_completed' and tenant_id='38000000-0000-0000-0000-000000000001'),
  0,
  'the two FIRST placements in this fixture emitted no transfer event -- an initial posting is not a transfer');

-- A real transfer ends the previous primary placement first; the partial unique index
-- (tenant_id, user_id) WHERE is_primary AND ends_at IS NULL enforces exactly that.
update public.user_branch_assignments set ends_at = now(), is_primary = false
 where tenant_id='38000000-0000-0000-0000-000000000001'
   and user_id='38000000-0000-0000-0000-000000000012' and ends_at is null;

insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary, transfer_type_code)
values ('38000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-000000000012',
        '38000000-0000-0000-0000-00000000000b','38000000-0000-0000-0000-0000000000c2', true, 'permanent');

select is(
  (select count(*)::int from public.events where event_type_code='user_branch_transfer_completed' and tenant_id='38000000-0000-0000-0000-000000000001'),
  1,
  'moving an employee to a second branch DOES emit transfer_completed -- branch placement finally leaves an audit trace');

select is(
  (select entity_type from public.events where event_type_code='user_branch_transfer_completed' and tenant_id='38000000-0000-0000-0000-000000000001'),
  'user',
  '...against the employee as subject, an entity_type the events read policy already dispatches');

select is(
  (select count(*)::int from public.events where event_type_code='user_branch_transfer_started' and tenant_id='38000000-0000-0000-0000-000000000001'),
  0,
  'user_branch_transfer_started is NEVER emitted -- assign_user_branch is one synchronous call and canon defines no two-phase transfer, so firing both would fabricate a lifecycle');

-- =============================================================================================
-- 18. document_superseded: the first version is not a supersession.
-- =============================================================================================
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code, is_confidential, current_version_id)
values ('38000000-0000-0000-0000-0000000000e1','38000000-0000-0000-0000-000000000001','other','Doc','active',false, null);
-- Real version rows: current_version_id carries an FK, so this cannot be faked with random uuids.
insert into public.document_versions (id, tenant_id, document_id, version_number, file_name, file_type_code, storage_path, is_current) values
  ('38000000-0000-0000-0000-0000000000f1','38000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-0000000000e1',1,'v1.pdf','pdf','p/v1.pdf',true),
  ('38000000-0000-0000-0000-0000000000f2','38000000-0000-0000-0000-000000000001','38000000-0000-0000-0000-0000000000e1',2,'v2.pdf','pdf','p/v2.pdf',false);
update public.documents set current_version_id = '38000000-0000-0000-0000-0000000000f1' where id='38000000-0000-0000-0000-0000000000e1';
update public.documents set current_version_id = '38000000-0000-0000-0000-0000000000f2' where id='38000000-0000-0000-0000-0000000000e1';

-- Scoped to THIS fixture's document. Counting `document_superseded` across the whole `events` table
-- made this assertion depend on every other row in the database, and it duly broke the first time
-- something outside the pgTAP suite created a second version -- `scripts/verify_storage_end_to_end.ps1`,
-- whose fixture cannot be torn down because `events` is append-only by design. The code was correct
-- both times; the assertion was measuring the wrong thing. Same correction as `27_event_visibility_test`.
select is(
  (select count(*)::int from public.events
    where event_type_code='document_superseded'
      and entity_id='38000000-0000-0000-0000-0000000000e1'),
  1,
  'only the SECOND version supersedes: null -> v1 is the first version, v1 -> v2 is a supersession');

select finish();
rollback;
