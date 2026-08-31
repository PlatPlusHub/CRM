-- pgTAP: QUO-2 / QUO-3 (`202607059000`) -- the care/conversation slice of the Batch-6 table-by-table
-- audit. The other four tables in that slice came back clean and are recorded in the migration
-- header; `quotation_items` failed twice.
--
-- Assertion 16 PINS AN OPEN OWNER DECISION rather than asserting correctness: QUO-4. It records that
-- one employee can reprice a colleague's DRAFT quotation line, because canon 28 says "Assigned only"
-- for `employee` and nothing enforces that on EITHER door. It is labelled a pin, not a rule.
create extension if not exists pgtap with schema extensions;

begin;
select plan(17);

insert into auth.users (id, email) values
  ('84000000-0000-0000-0000-0000000000a1','mgr@f84.example'),
  ('84000000-0000-0000-0000-0000000000a2','other@f84.example');
insert into public.tenants (id, name, slug, status) values
  ('84000000-0000-0000-0000-000000000001','F84 Travel','f84-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '84000000-0000-0000-0000-000000000001', sp.id,'active'
from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('84000000-0000-0000-0000-00000000000a','84000000-0000-0000-0000-000000000001','Main','f84-main');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('84000000-0000-0000-0000-0000000000c1','84000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('84000000-0000-0000-0000-000000000011','84000000-0000-0000-0000-000000000001','Manager','mgr@f84.example',true,'84000000-0000-0000-0000-0000000000a1'),
  ('84000000-0000-0000-0000-000000000021','84000000-0000-0000-0000-000000000001','Other Seller','other@f84.example',true,'84000000-0000-0000-0000-0000000000a2');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '84000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000011', r.id,'tenant' from public.roles r where r.code='branch_manager';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '84000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-000000000021', r.id,'tenant' from public.roles r where r.code='employee';
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '84000000-0000-0000-0000-000000000001', u,'84000000-0000-0000-0000-00000000000a','84000000-0000-0000-0000-0000000000c1', true
from unnest(array['84000000-0000-0000-0000-000000000011'::uuid,'84000000-0000-0000-0000-000000000021']) u;
insert into public.customers (id, tenant_id, customer_type_code, full_name, first_registered_branch_id)
values ('84000000-0000-0000-0000-0000000000cc','84000000-0000-0000-0000-000000000001','person','F84 Customer','84000000-0000-0000-0000-00000000000a');
insert into public.quotations (id, tenant_id, customer_id, quotation_status_code, quotation_number,
                               currency_code, owner_user_id, owner_branch_id, owner_department_id)
values ('84000000-0000-0000-0000-0000000000f1','84000000-0000-0000-0000-000000000001',
        '84000000-0000-0000-0000-0000000000cc','draft','F84-0001','EGP',
        '84000000-0000-0000-0000-000000000011','84000000-0000-0000-0000-00000000000a','84000000-0000-0000-0000-0000000000c1');

select set_config('request.jwt.claims','{"sub":"84000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;

select ok(app.has_permission('CREATE_QUOTATION') and app.has_permission('SEND_QUOTATION'),
  'POSITIVE CONTROL: the caller genuinely holds CREATE_QUOTATION and SEND_QUOTATION, so every refusal below is the integrity rule and not the permission');

select lives_ok(
  $$select app.add_quotation_item('84000000-0000-0000-0000-0000000000f1','hotel',10000,1)$$,
  'POSITIVE CONTROL: the RPC adds a line to a DRAFT quotation');

select lives_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('84000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-0000000000f1','hotel','EGP', 250, 2, 500)$$,
  'POSITIVE CONTROL: and a direct INSERT on a DRAFT still works -- the new guards do not block legitimate editing');

-- ================================================================================================
-- QUO-3 -- the value rules the RPC enforced and the table did not.
-- ================================================================================================
select throws_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('84000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-0000000000f1','hotel','EGP', -5000, 1, -5000)$$,
  '23514', null,
  'QUO-3: a NEGATIVE unit_price is refused -- before 202607059000 the table had no CHECK constraints at all and stored it, and total_amount feeds quotations.total_amount');

select throws_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('84000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-0000000000f1','hotel','EGP', 100, 0, 0)$$,
  '23514', null,
  'QUO-3b: and so is a ZERO quantity -- a zero-quantity line is not a line');

select lives_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('84000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-0000000000f1','hotel','EGP', 0, 1, 0)$$,
  'NEGATIVE CONTROL: a ZERO unit_price is still allowed -- an included transfer or a waived fee is a real line, which is why the rule is >= 0 and not > 0 (copied from the RPC, not chosen here)');

-- ================================================================================================
-- QUO-2 -- an offer that has left the building.
-- ================================================================================================
select lives_ok(
  $$select app.advance_quotation('84000000-0000-0000-0000-0000000000f1','sent','send it')$$,
  'the quotation is advanced draft -> sent through the state machine, legally');

select throws_ok(
  $$select app.add_quotation_item('84000000-0000-0000-0000-0000000000f1','hotel',7777,1)$$,
  'P0001', null,
  'POSITIVE CONTROL: the RPC refuses a line on a SENT quotation -- this is the authority the table door had to match');

select throws_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('84000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-0000000000f1','hotel','EGP', 7777, 1, 7777)$$,
  '23514', null,
  'QUO-2: the TABLE now refuses it too -- before 202607059000 a 7,777 line appeared on a quotation the customer already had');

select throws_ok(
  $$update public.quotation_items set unit_price = 1, total_amount = 1
    where quotation_id = '84000000-0000-0000-0000-0000000000f1' and unit_price = 10000$$,
  '23514', null,
  'QUO-2b: and repricing an existing line on a SENT quotation is refused -- the half with NO RPC at all, where direct DML was the only path and 10,000 became 1');

select is(
  (select count(*)::int from public.quotation_items
    where quotation_id = '84000000-0000-0000-0000-0000000000f1' and unit_price = 10000),
  1,
  '...and the original line is untouched, so the refusal was a refusal and not a silent partial write');

-- A quotation can legally return to draft, and then it is editable again.
select lives_ok(
  $$select app.advance_quotation('84000000-0000-0000-0000-0000000000f1','rejected','customer declined')$$,
  'the customer rejects it');
select lives_ok(
  $$select app.advance_quotation('84000000-0000-0000-0000-0000000000f1','draft','revising')$$,
  'and it returns to draft through the machine');
select lives_ok(
  $$update public.quotation_items set unit_price = 9000, total_amount = 9000
    where quotation_id = '84000000-0000-0000-0000-0000000000f1' and unit_price = 10000$$,
  'NEGATIVE CONTROL: editing works again once it is a draft -- the rule is about the parent''s state, not a permanent freeze');

-- ================================================================================================
-- QUO-4 -- PINNED, NOT ASSERTED AS CORRECT. Placed BEFORE the mutation so it acts on a draft.
-- ================================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"84000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;
select lives_ok(
  $$update public.quotation_items set unit_price = 1, total_amount = 1
    where quotation_id = '84000000-0000-0000-0000-0000000000f1' and unit_price = 9000$$,
  'PINNED, NOT ASSERTED AS CORRECT (QUO-4): a DIFFERENT employee reprices a colleague''s DRAFT quotation line. Canon 28 records CREATE_QUOTATION as "Assigned only" for employee, and NOTHING enforces that on either door -- app.add_quotation_item checks the tenant and the draft status, never the owner. Not a two-door gap: both doors agree. Canon''s own scope column reads "assigned/department" and the 2026-08-24 directive granted department continuity deliberately, so choosing between them is an OWNER DECISION. This assertion exists so the boundary cannot move silently.');
reset role;
select set_config('request.jwt.claims','{"sub":"84000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);

-- ================================================================================================
-- Mutation, then PAR-4's closing move.
--
-- Two traps are avoided here deliberately, and both bit the first draft of this file.
--   TEST-3: an assertion inside a rolled-back savepoint is UN-COUNTED, so the mutation must never
--           be the last assertion -- there must be a real one after it.
--   The rollback also restores the PARENT to draft, so the closing assertion has to put the
--           quotation back into a non-draft state itself. The first version tested an
--           `insert ... select` filtered on `<> 'draft'`, which matched zero rows and "passed" by
--           inserting nothing -- the vacuous-test class AGENTS.md §6 forbids.
-- ================================================================================================
savepoint m1;
drop trigger quotation_items_guard_parent_editable on public.quotation_items;
update public.quotations set quotation_status_code = 'sent' where id = '84000000-0000-0000-0000-0000000000f1';
select lives_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('84000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-0000000000f1','hotel','EGP', 4242, 1, 4242)$$,
  'MUTATION: with the parent-editable trigger dropped a line lands on a SENT quotation again -- proving that trigger is the enforcer');
rollback to savepoint m1;

update public.quotations set quotation_status_code = 'sent' where id = '84000000-0000-0000-0000-0000000000f1';
select throws_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('84000000-0000-0000-0000-000000000001','84000000-0000-0000-0000-0000000000f1','hotel','EGP', 4242, 1, 4242)$$,
  '23514', null,
  '...and once the mutation is rolled back the guard is BACK: the identical insert against the identical SENT parent is refused again');

select * from finish();
rollback;
