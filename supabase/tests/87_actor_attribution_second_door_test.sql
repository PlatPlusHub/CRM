-- pgTAP: ATTR-2 (`202607059300`) -- the actor attributions that survived three previous sweeps.
--
-- Every column tested here has EXACTLY ONE producer, and that producer already recorded the
-- authenticated caller. None accepts an actor as a parameter. So the defect was never the RPC: it
-- was that `authenticated` also holds the TABLE grant, and the second door accepted an actor the
-- first door never offered. Each assertion below was first observed FAILING against the schema at
-- migration 181, with a live positive and negative control, before the trigger was written.
--
-- The file is deliberately organised so that no denial can be mistaken for a clean result: for every
-- attack there is a control proving the actor genuinely holds the capability and the row is genuinely
-- reachable. `AGENTS.md §6` forbids the alternative, and has twice caught it in this repository.
--
-- Where RLS or a capability decides the outcome the file runs as `authenticated`: as `postgres` the
-- policies do not apply and every refusal here would silently pass.
create extension if not exists pgtap with schema extensions;

begin;
select plan(29);

insert into auth.users (id, email, email_confirmed_at) values
  ('87000000-0000-0000-0000-0000000000a1','owner@f87.example', now()),
  ('87000000-0000-0000-0000-0000000000a2','emp@f87.example',   now()),
  ('87000000-0000-0000-0000-0000000000a3','fin@f87.example',   now());
insert into public.tenants (id, name, slug, status) values
  ('87000000-0000-0000-0000-000000000001','F87 Travel','f87-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '87000000-0000-0000-0000-000000000001', sp.id,'active'
from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('87000000-0000-0000-0000-00000000000a','87000000-0000-0000-0000-000000000001','Main','f87-main');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('87000000-0000-0000-0000-0000000000c1','87000000-0000-0000-0000-000000000001','87000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('87000000-0000-0000-0000-000000000011','87000000-0000-0000-0000-000000000001','Owner','owner@f87.example',true,'87000000-0000-0000-0000-0000000000a1'),
  ('87000000-0000-0000-0000-000000000021','87000000-0000-0000-0000-000000000001','Employee','emp@f87.example',true,'87000000-0000-0000-0000-0000000000a2'),
  ('87000000-0000-0000-0000-000000000031','87000000-0000-0000-0000-000000000001','Finance','fin@f87.example',true,'87000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary)
select '87000000-0000-0000-0000-000000000001',u,'87000000-0000-0000-0000-00000000000a','87000000-0000-0000-0000-0000000000c1',true
from unnest(array['87000000-0000-0000-0000-000000000011'::uuid,'87000000-0000-0000-0000-000000000021'::uuid,
                  '87000000-0000-0000-0000-000000000031'::uuid]) u;
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '87000000-0000-0000-0000-000000000001', v.u, r.id,'tenant' from (values
  ('87000000-0000-0000-0000-000000000011'::uuid,'owner'),
  ('87000000-0000-0000-0000-000000000021'::uuid,'employee'),
  ('87000000-0000-0000-0000-000000000031'::uuid,'finance_manager')) v(u,rc) join public.roles r on r.code=v.rc;

insert into public.customers (id,tenant_id,customer_type_code,full_name) values
  ('87000000-0000-0000-0000-0000000000d1','87000000-0000-0000-0000-000000000001','person','Fixture Customer'),
  ('87000000-0000-0000-0000-0000000000d2','87000000-0000-0000-0000-000000000001','person','Merge Source');
insert into public.bookings (id,tenant_id,branch_id,department_id,customer_id,booking_status_code,title,booking_reference,owner_user_id)
values ('87000000-0000-0000-0000-0000000000b1','87000000-0000-0000-0000-000000000001','87000000-0000-0000-0000-00000000000a',
        '87000000-0000-0000-0000-0000000000c1','87000000-0000-0000-0000-0000000000d1','confirmed','Fixture Booking','F87-REF-1',
        '87000000-0000-0000-0000-000000000021');
insert into public.booking_items (id,tenant_id,booking_id,service_type_code,base_status_code,currency_code,owner_user_id)
values ('87000000-0000-0000-0000-0000000000b2','87000000-0000-0000-0000-000000000001','87000000-0000-0000-0000-0000000000b1',
        'flight_ticket','confirmed','EGP','87000000-0000-0000-0000-000000000021');
-- Unassigned first: `app.require_assignment_history` (canon 04) refuses an assignee with no current
-- `lead_assignments` row, and `leads_owner_matches_assignee_chk` ties owner to assignee.
insert into public.leads (id,tenant_id,branch_id,department_id,lead_source_code,lead_status_code,title)
values ('87000000-0000-0000-0000-0000000000e1','87000000-0000-0000-0000-000000000001','87000000-0000-0000-0000-00000000000a',
        '87000000-0000-0000-0000-0000000000c1','direct_call','new','Fixture Lead');
insert into public.lead_assignments (tenant_id,lead_id,assigned_user_id,is_current)
values ('87000000-0000-0000-0000-000000000001','87000000-0000-0000-0000-0000000000e1','87000000-0000-0000-0000-000000000021',true);
update public.leads set assigned_user_id='87000000-0000-0000-0000-000000000021',
                        owner_user_id='87000000-0000-0000-0000-000000000021',
                        lead_status_code='assigned'
 where id='87000000-0000-0000-0000-0000000000e1';

-- ================================================================================================
-- payments.received_by -- the column the ATTR-2 register row singled out as possibly a LEGITIMATE
-- business fact ("which staff member physically received the cash"). It is not one today, and that
-- was settled by measurement rather than by the suffix: `app.record_payment` and
-- `app.record_supplier_payment` have NO actor parameter and both set `received_by = created_by =
-- v_actor`; no view or function READS the column; canon 31 says only "received_by nullable"; and
-- there is no permission distinguishing receiving from recording. So a direct write naming somebody
-- else is unreachable through every authorized path -- forgery, not a business fact. Should ORVION
-- later want "A received the cash, B recorded it", that is a new capability with a parameter and a
-- permission, and this trigger is amended then; it is not silently assumed now.
-- ================================================================================================
-- aal2: `app.authorize` requires MFA for privileged roles (`app.mfa_satisfied`).
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
set local role authenticated;

select ok(
  (select app.has_permission('RECORD_PAYMENT')),
  'POSITIVE CONTROL: the finance_manager GENUINELY HOLDS RECORD_PAYMENT, so the insert below is authorized rather than merely unblocked');

select lives_ok(
  $$insert into public.payments (id,tenant_id,payment_direction_code,customer_id,booking_id,currency_code,
                                 payment_method_code,amount,received_by,created_by)
    values ('87000000-0000-0000-0000-0000000000f1','87000000-0000-0000-0000-000000000001','customer_payment',
            '87000000-0000-0000-0000-0000000000d1','87000000-0000-0000-0000-0000000000b1','EGP','cash',500,
            '87000000-0000-0000-0000-000000000021','87000000-0000-0000-0000-000000000021')$$,
  'a payment naming SOMEONE ELSE as its receiver still inserts -- the guard derives rather than raises (WP-00)');

select is(
  (select received_by from public.payments where id='87000000-0000-0000-0000-0000000000f1'),
  '87000000-0000-0000-0000-000000000031'::uuid,
  'ATTR-2/A: the FORGED receiver is discarded -- the row records the finance_manager who actually recorded it, not the employee the caller named. Before 202607059300 this stored the employee.');

select is(
  (select created_by from public.payments where id='87000000-0000-0000-0000-0000000000f1'),
  '87000000-0000-0000-0000-000000000031'::uuid,
  'DISCRIMINATING CONTROL: `created_by` in the SAME row from the SAME statement was already correct -- ATTR-1 derived one column and left the other accepted verbatim, which is exactly how this defect stayed invisible');

reset role;
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;

select ok(
  not (select app.has_permission('RECORD_PAYMENT')),
  'POSITIVE CONTROL (inverted): the employee does NOT hold RECORD_PAYMENT -- so what follows tests the column, not the actor');

select is(
  (select count(*) from public.payments where id='87000000-0000-0000-0000-0000000000f1'),
  1::bigint,
  'REACHABILITY CONTROL: the employee can SEE the payment through the RLS booking path -- a denial below could not be mistaken for an invisible row');

select throws_ok(
  $$update public.payments set amount = 999 where id='87000000-0000-0000-0000-0000000000f1'$$,
  '42501', null,
  'NEGATIVE CONTROL: the same employee is refused when changing the AMOUNT -- `guard_financial_capability` is live, and ATTR-2 was an integrity defect, not an authorization one');

select lives_ok(
  $$update public.payments set received_by = '87000000-0000-0000-0000-000000000021'
    where id='87000000-0000-0000-0000-0000000000f1'$$,
  'ATTR-2/B: the same employee CAN run the update -- rewriting the receiver required no capability at all, because that guard watches `amount` and nothing else');

select is(
  (select received_by from public.payments where id='87000000-0000-0000-0000-0000000000f1'),
  '87000000-0000-0000-0000-000000000031'::uuid,
  '...and it changes nothing: attribution is frozen once written. Before 202607059300 this UPDATE returned UPDATE 1 and the value moved.');

-- ================================================================================================
-- lead_interactions.user_id -- INVISIBLE TO ASSERTION 22 of `83_actor_attribution_test.sql`, which
-- asks the schema for columns ending `_by`. This one records who made the call and is named
-- `user_id`. ASGN-2's lesson, for the fourth time.
-- ================================================================================================
select lives_ok(
  $$insert into public.lead_interactions (id,tenant_id,lead_id,interaction_type_code,summary,user_id)
    values ('87000000-0000-0000-0000-00000000009c','87000000-0000-0000-0000-000000000001',
            '87000000-0000-0000-0000-0000000000e1','phone_call','a call the employee never made',
            '87000000-0000-0000-0000-000000000011')$$,
  'POSITIVE CONTROL: the employee IS the assigned handler, so `app.guard_lead_interaction_authority` permits the write');

select is(
  (select user_id from public.lead_interactions where id='87000000-0000-0000-0000-00000000009c'),
  '87000000-0000-0000-0000-000000000021'::uuid,
  'ATTR-2/C: the interaction is attributed to the employee who recorded it, not the owner the caller named. The authority guard asks WHETHER the write is allowed and never WHO is recorded, so a legitimate handler could put a colleague''s name on their own call.');

reset role;
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a3"}',true);
set local role authenticated;

select throws_ok(
  $$insert into public.lead_interactions (tenant_id,lead_id,interaction_type_code,user_id)
    values ('87000000-0000-0000-0000-000000000001','87000000-0000-0000-0000-0000000000e1','note',
            '87000000-0000-0000-0000-000000000011')$$,
  '42501', null,
  'NEGATIVE CONTROL: the finance_manager is not the handler and lacks ASSIGN_LEAD -- authority is untouched by the attribution fix');

-- ================================================================================================
-- customers.first_registered_user_id -- also invisible to assertion 22, and ASGN-2's shape exactly:
-- `app.freeze_first_registration` guarded UPDATE only, so the column LOOKED governed.
-- ================================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;

select lives_ok(
  $$insert into public.customers (id,tenant_id,customer_type_code,full_name,first_registered_user_id,created_by)
    values ('87000000-0000-0000-0000-0000000000d3','87000000-0000-0000-0000-000000000001','person',
            'Forged Registration','87000000-0000-0000-0000-000000000011','87000000-0000-0000-0000-000000000011')$$,
  'an employee creates a customer while naming the owner as its first registrar');

select is(
  (select first_registered_user_id from public.customers where id='87000000-0000-0000-0000-0000000000d3'),
  '87000000-0000-0000-0000-000000000021'::uuid,
  'ATTR-2/D: the row records the employee who actually registered the customer. Before 202607059300 it recorded the owner -- while `created_by`, in the same statement, was corrected to the employee.');

select throws_ok(
  $$update public.customers set first_registered_user_id = '87000000-0000-0000-0000-000000000031'
    where id='87000000-0000-0000-0000-0000000000d3'$$,
  '42501', null,
  'CONTRAST: `app.freeze_first_registration` still RAISES on an attempt to move a written value -- the stronger response, kept rather than replaced');

-- The gap the freeze left: it refuses a change only when the OLD value is non-null, so a row created
-- session-less with NULL could be filled in afterwards by any direct writer.
--
-- `set_config(...,true)` is transaction-local and SURVIVES `reset role`, so dropping back to
-- `postgres` does NOT make a statement session-less -- `auth.uid()` still resolves to whoever the
-- last block impersonated. The claims must be cleared explicitly. This is not a detail: without it
-- the row below would be created WITH an attribution and this assertion would test nothing.
reset role;
select set_config('request.jwt.claims','{}',true);
insert into public.customers (id,tenant_id,customer_type_code,full_name)
values ('87000000-0000-0000-0000-0000000000d4','87000000-0000-0000-0000-000000000001','person','Session-less Customer');
select is(
  (select first_registered_user_id from public.customers where id='87000000-0000-0000-0000-0000000000d4'),
  null::uuid,
  'PRECONDITION: with the claims cleared the insert is genuinely session-less, so the registrar is NULL -- without this the next assertion could pass on a row that already carried an attribution');
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;
update public.customers set first_registered_user_id = '87000000-0000-0000-0000-000000000011'
where id='87000000-0000-0000-0000-0000000000d4';
select is(
  (select first_registered_user_id from public.customers where id='87000000-0000-0000-0000-0000000000d4'),
  '87000000-0000-0000-0000-000000000021'::uuid,
  'ATTR-2/D2: filling a NULL registrar afterwards derives the caller too -- the freeze permitted this because its predicate is `old is not null`');

-- ================================================================================================
-- customer_identity_merges.merged_by -- the audit log of a destructive operation.
-- ================================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;

select throws_ok(
  $$insert into public.customer_identity_merges (tenant_id,source_customer_id,target_customer_id,merged_by)
    values ('87000000-0000-0000-0000-000000000001','87000000-0000-0000-0000-0000000000d2',
            '87000000-0000-0000-0000-0000000000d1','87000000-0000-0000-0000-000000000021')$$,
  '42501', null,
  'NEGATIVE CONTROL: the employee lacks MERGE_CUSTOMER_IDENTITY -- `app.guard_write_capability` still refuses, so this fix changed no authorization');

reset role;
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;

select lives_ok(
  $$insert into public.customer_identity_merges (id,tenant_id,source_customer_id,target_customer_id,merged_by)
    values ('87000000-0000-0000-0000-00000000008e','87000000-0000-0000-0000-000000000001',
            '87000000-0000-0000-0000-0000000000d2','87000000-0000-0000-0000-0000000000d1',
            '87000000-0000-0000-0000-000000000021')$$,
  'POSITIVE CONTROL: the owner holds MERGE_CUSTOMER_IDENTITY and the write proceeds');

select is(
  (select merged_by from public.customer_identity_merges where id='87000000-0000-0000-0000-00000000008e'),
  '87000000-0000-0000-0000-000000000011'::uuid,
  'ATTR-2/E: the merge is attributed to the owner who performed it, not the employee named in the statement');

-- ================================================================================================
-- booking_items.cancelled_by / no_show_recorded_by -- ACTION attributions, so the fix ties the
-- attribution to the ACT. Re-attributing scenario F to the employee would have recorded them as the
-- canceller of an item that was never cancelled: one false statement traded for another.
-- ================================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;

update public.booking_items
   set cancelled_by='87000000-0000-0000-0000-000000000011',
       no_show_recorded_by='87000000-0000-0000-0000-000000000011'
 where id='87000000-0000-0000-0000-0000000000b2';

select is(
  (select cancelled_by from public.booking_items where id='87000000-0000-0000-0000-0000000000b2'),
  null::uuid,
  'ATTR-2/F: an employee who does NOT hold CANCEL_BOOKING stamped a canceller on an item still `confirmed`; the column is now NULL, because the attribution follows the transition. Before 202607059300 this stored the owner.');

select is(
  (select no_show_recorded_by from public.booking_items where id='87000000-0000-0000-0000-0000000000b2'),
  null::uuid,
  'ATTR-2/F2: and the same for `no_show_recorded_by` -- both statuses are terminal in app.status_transitions, so once earned the value is immutable');

-- ================================================================================================
-- CROSS-PATH IMPACT SWEEP (AGENTS.md §5b) -- every RPC that legitimately writes one of these columns
-- must still record the SAME actor it recorded before the triggers existed.
-- ================================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
set local role authenticated;
insert into public.invoices (id,tenant_id,customer_id,invoice_number,invoice_date,currency_code,status_code,total_amount)
values ('87000000-0000-0000-0000-0000000000c9','87000000-0000-0000-0000-000000000001','87000000-0000-0000-0000-0000000000d1',
        'INV-F87-1',now(),'EGP','issued',300);

-- Each RPC is called in its OWN statement and the row found by a deterministic key. Calling the
-- function inside the `where` clause of the assertion makes it a correlated subquery -- Postgres is
-- free to evaluate it per candidate row, which ran the RPC repeatedly and matched nothing.
select app.record_payment('87000000-0000-0000-0000-0000000000c9', 300, 'cash');
select is(
  (select p.received_by from public.payments p
     join public.payment_allocations pa on pa.payment_id = p.id
    where pa.invoice_id = '87000000-0000-0000-0000-0000000000c9'),
  '87000000-0000-0000-0000-000000000031'::uuid,
  'NO REGRESSION: `app.record_payment` still attributes the payment to its caller -- the RPC path was always correct and the trigger derives the same value');

reset role;
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;

select app.record_lead_interaction('87000000-0000-0000-0000-0000000000e1','phone_call','a real call');
select is(
  (select user_id from public.lead_interactions where summary = 'a real call'),
  '87000000-0000-0000-0000-000000000021'::uuid,
  'NO REGRESSION: `app.record_lead_interaction` still attributes the interaction to its caller');

select app.create_customer('person','RPC Customer');
select is(
  (select first_registered_user_id from public.customers where full_name = 'RPC Customer'),
  '87000000-0000-0000-0000-000000000021'::uuid,
  'NO REGRESSION: `app.create_customer` still records its caller as the first registrar');

reset role;
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select app.advance_booking_item('87000000-0000-0000-0000-0000000000b2','cancelled','customer changed plans',
                                null,'customer_cancelled');
reset role;

select is(
  (select cancelled_by from public.booking_items where id='87000000-0000-0000-0000-0000000000b2'),
  '87000000-0000-0000-0000-000000000011'::uuid,
  'NO REGRESSION: a REAL cancellation through `app.advance_booking_item` still records who cancelled it -- the trigger stamps exactly when the item enters `cancelled`, mirroring the RPC');

-- Session-less platform paths keep the attribution they set (canon 35 principle 6). The claims are
-- cleared explicitly, and the attribution written is the EMPLOYEE while the last impersonated actor
-- was the OWNER -- so if the clearing failed and the trigger still fired, this asserts the owner and
-- fails. A session-less test that names the same user the session already held proves nothing.
select set_config('request.jwt.claims','{}',true);
insert into public.payments (id,tenant_id,payment_direction_code,customer_id,currency_code,payment_method_code,amount,received_by)
values ('87000000-0000-0000-0000-0000000000fe','87000000-0000-0000-0000-000000000001','customer_payment',
        '87000000-0000-0000-0000-0000000000d1','EGP','cash',10,'87000000-0000-0000-0000-000000000021');
select is(
  (select received_by from public.payments where id='87000000-0000-0000-0000-0000000000fe'),
  '87000000-0000-0000-0000-000000000021'::uuid,
  'SESSION-LESS: with no auth.uid() the trigger returns NEW untouched, so a platform writer keeps its own attribution rather than having it erased');

-- ================================================================================================
-- PAR-4 -- prove the trigger is the enforcer. Inspection cannot distinguish "the guard held" from
-- "nothing tried to move"; only removing the guard can.
-- ================================================================================================
savepoint mutation;
drop trigger payments_derive_receiver on public.payments;
select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;
update public.payments set received_by = '87000000-0000-0000-0000-000000000021'
where id='87000000-0000-0000-0000-0000000000f1';
reset role;
select is(
  (select received_by from public.payments where id='87000000-0000-0000-0000-0000000000f1'),
  '87000000-0000-0000-0000-000000000021'::uuid,
  'MUTATION: with `payments_derive_receiver` dropped the forged receiver STICKS -- proving that trigger, and nothing incidental, is what the assertions above are testing');
rollback to savepoint mutation;

select set_config('request.jwt.claims','{"sub":"87000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;
update public.payments set received_by = '87000000-0000-0000-0000-000000000021'
where id='87000000-0000-0000-0000-0000000000f1';
reset role;
select is(
  (select received_by from public.payments where id='87000000-0000-0000-0000-0000000000f1'),
  '87000000-0000-0000-0000-000000000031'::uuid,
  'MUTATION RESTORED: the rollback brings the trigger back and the same statement is inert again');

select * from finish();
rollback;
