-- pgTAP: Batch 6 Slice 41 -- receipts. RCPT-1, RCPT-2, RCPT-3 and RCPT-4 (SPEC-268).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT BUSINESS PRIVILEGE CONCURRENCY REPLAY OBSERVABILITY
--
-- A receipt is issued only for a customer payment; its number comes from the tenant's per-year
-- sequence and its issue time from the server, on every door; it is born unsubmitted; once issued
-- its payment, number, issue time and origin never change; its tax-submission fields change only
-- with CREATE_RECEIPT; and every receipt is born with exactly one receipt_issued event.
--
-- CONCURRENCY -- pgTAP has one session. Assertion 4 proves BEHAVIOURALLY that a door insert holds
--   the sequence's advisory lock (the key app.issue_receipt has always taken), read from pg_locks
--   for this backend before any RPC has run; the unique key on (tenant_id, receipt_number) stays.
-- REPLAY -- assertions 13-14: a second receipt for one payment is refused on both doors.
-- OBSERVABILITY -- assertions 5, 10 and 33: one event per receipt, on the RPC and the door, and
--   none for a refused write.
create extension if not exists pgtap with schema extensions;

begin;
select plan(33);

-- ---------------------------------------------------------------------------------------------
-- Fixture: one tenant (owner + employee), one customer, one booking the employee owns, five
-- customer payments (three on that booking) and one supplier payment; a rival tenant with its own
-- customer payment.
-- ---------------------------------------------------------------------------------------------
insert into auth.users (id,email,email_confirmed_at) values
  ('15600000-0000-0000-0000-0000000000a1','owner@rc156.test',now()),
  ('15600000-0000-0000-0000-0000000000a2','emp@rc156.test',now());
insert into public.tenants (id,name,slug,status) values
  ('15600000-0000-0000-0000-000000000001','RC156 Travel','rc156-travel','active'),
  ('15600000-0000-0000-0000-000000000002','RC156 Rival','rc156-rival','active');
insert into public.subscriptions (tenant_id,subscription_plan_id,subscription_status_code)
select t.id, sp.id, 'active' from public.subscription_plans sp
cross join (values ('15600000-0000-0000-0000-000000000001'::uuid),('15600000-0000-0000-0000-000000000002'::uuid)) t(id)
where sp.plan_code='enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('15600000-0000-0000-0000-00000000000a','15600000-0000-0000-0000-000000000001','Main','rc156-main');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('15600000-0000-0000-0000-0000000000c1','15600000-0000-0000-0000-000000000001','15600000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('15600000-0000-0000-0000-000000000011','15600000-0000-0000-0000-000000000001','Owner','owner@rc156.test',true,'15600000-0000-0000-0000-0000000000a1'),
  ('15600000-0000-0000-0000-000000000012','15600000-0000-0000-0000-000000000001','Employee','emp@rc156.test',true,'15600000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary) values
  ('15600000-0000-0000-0000-000000000001','15600000-0000-0000-0000-000000000011','15600000-0000-0000-0000-00000000000a','15600000-0000-0000-0000-0000000000c1',true),
  ('15600000-0000-0000-0000-000000000001','15600000-0000-0000-0000-000000000012','15600000-0000-0000-0000-00000000000a','15600000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '15600000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('15600000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('15600000-0000-0000-0000-000000000012'::uuid,'employee')) v(u,rc)
join public.roles r on r.code=v.rc;
insert into public.customers (id,tenant_id,customer_type_code,full_name) values
  ('15600000-0000-0000-0000-0000000000d1','15600000-0000-0000-0000-000000000001','person','C1'),
  ('15600000-0000-0000-0000-0000000000d9','15600000-0000-0000-0000-000000000002','person','Rival');
insert into public.suppliers (id,tenant_id,name,supplier_type_code) values
  ('15600000-0000-0000-0000-0000000000e9','15600000-0000-0000-0000-000000000001','Airline','airline');
insert into public.bookings (id,tenant_id,branch_id,department_id,customer_id,booking_status_code,title,booking_reference,owner_user_id) values
  ('15600000-0000-0000-0000-0000000000b1','15600000-0000-0000-0000-000000000001','15600000-0000-0000-0000-00000000000a','15600000-0000-0000-0000-0000000000c1','15600000-0000-0000-0000-0000000000d1','confirmed','B1','RC156-B1','15600000-0000-0000-0000-000000000012');
-- f1, f2, f5 are on B1, so the employee sees them; f4 is on no booking; f3 is outbound.
insert into public.payments (id,tenant_id,payment_direction_code,customer_id,supplier_id,booking_id,currency_code,payment_method_code,amount) values
  ('15600000-0000-0000-0000-0000000000f1','15600000-0000-0000-0000-000000000001','customer_payment','15600000-0000-0000-0000-0000000000d1',null,'15600000-0000-0000-0000-0000000000b1','EGP','cash',600),
  ('15600000-0000-0000-0000-0000000000f2','15600000-0000-0000-0000-000000000001','customer_payment','15600000-0000-0000-0000-0000000000d1',null,'15600000-0000-0000-0000-0000000000b1','EGP','cash',900),
  ('15600000-0000-0000-0000-0000000000f3','15600000-0000-0000-0000-000000000001','supplier_payment',null,'15600000-0000-0000-0000-0000000000e9',null,'EGP','cash',500),
  ('15600000-0000-0000-0000-0000000000f4','15600000-0000-0000-0000-000000000001','customer_payment','15600000-0000-0000-0000-0000000000d1',null,null,'EGP','cash',100),
  ('15600000-0000-0000-0000-0000000000f5','15600000-0000-0000-0000-000000000001','customer_payment','15600000-0000-0000-0000-0000000000d1',null,'15600000-0000-0000-0000-0000000000b1','EGP','cash',300),
  ('15600000-0000-0000-0000-0000000000f6','15600000-0000-0000-0000-000000000001','customer_payment','15600000-0000-0000-0000-0000000000d1',null,null,'EGP','cash',50),
  ('15600000-0000-0000-0000-0000000000f9','15600000-0000-0000-0000-000000000002','customer_payment','15600000-0000-0000-0000-0000000000d9',null,null,'EGP','cash',100);
-- Flush PAY-3's deferred payment trigger here, session-less (see test 155).
set constraints all immediate;
set constraints all deferred;

-- =============================================================================================
-- 1-5. RCPT-3: a door receipt is numbered, timed and recorded by the server, under the lock.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"15600000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select ok(app.has_permission('CREATE_RECEIPT') and app.has_permission('VIEW_FINANCIAL_DOCUMENTS'),
  '1. the owner holds CREATE_RECEIPT -- every refusal of the owner below is the invariant, not the permission');
select lives_ok($$insert into public.receipts (id,tenant_id,payment_id,receipt_number,issued_at,external_submission_id)
                  values ('15600000-0000-0000-0000-00000000ca04','15600000-0000-0000-0000-000000000001',
                          '15600000-0000-0000-0000-0000000000f4','RCP-' || to_char(now(),'YYYY') || '-X1',
                          now() - interval '400 days','forged')$$,
  '2. the owner inserts a receipt at the table door, naming a malformed number, a date 400 days ago and a submission id');
select is((select receipt_number || '/' || (issued_at = now())::text || '/' || coalesce(external_submission_id,'<null>')
           from public.receipts where id='15600000-0000-0000-0000-00000000ca04'),
  'RCP-' || to_char(now(),'YYYY') || '-0001/true/<null>',
  '3. the number is the sequence''s, the issue time is the server''s and it is born unsubmitted: nothing the caller named is kept');
select ok(exists (
    select 1 from pg_locks l
    cross join (select hashtextextended('15600000-0000-0000-0000-000000000001' || ':RCP:' || to_char(now(),'YYYY'), 0) as k) key
    where l.locktype = 'advisory' and l.pid = pg_backend_pid() and l.granted and l.objsubid = 1
      and l.classid::bigint = ((key.k >> 32) & 4294967295) and l.objid::bigint = (key.k & 4294967295)),
  '4. CONCURRENCY: the door insert holds the receipt sequence''s advisory lock, before any RPC has run');
select is((select count(*)::int from public.events e
           where e.event_type_code = 'receipt_issued' and e.entity_id = '15600000-0000-0000-0000-00000000ca04'
             and e.payload->>'receipt_number' = 'RCP-' || to_char(now(),'YYYY') || '-0001'
             and e.payload->>'payment_id' = '15600000-0000-0000-0000-0000000000f4'
             and (e.payload->>'amount')::numeric = 100),
  1, '5. OBSERVABILITY: the door receipt is born with its receipt_issued event, carrying its number, payment and amount');

-- =============================================================================================
-- 6-10. RCPT-4: the RPC keeps issuing, whatever text a stored number holds.
-- =============================================================================================
select lives_ok($$select app.issue_receipt('15600000-0000-0000-0000-0000000000f1')$$,
  '6. the RPC issues a receipt for f1');
select is((select receipt_number from public.receipts where payment_id='15600000-0000-0000-0000-0000000000f1'),
  'RCP-' || to_char(now(),'YYYY') || '-0002', '7. ...numbered after the door receipt: one sequence for both doors');
reset role;
-- A row written before this migration could carry any text. Write one past the trigger, as such
-- data would have been written; the ALTER is rolled back with the test.
alter table public.receipts disable trigger receipts_guard_issue;
insert into public.receipts (tenant_id,payment_id,receipt_number)
values ('15600000-0000-0000-0000-000000000001','15600000-0000-0000-0000-0000000000f6','RCP-' || to_char(now(),'YYYY') || '-X9');
alter table public.receipts enable trigger receipts_guard_issue;
set local role authenticated;
select lives_ok($$select app.issue_receipt('15600000-0000-0000-0000-0000000000f2')$$,
  '8. with a malformed RCP-<year>-X9 stored, the RPC still issues -- before this contract it raised "invalid input syntax for type integer" for the rest of the year');
select is((select receipt_number from public.receipts where payment_id='15600000-0000-0000-0000-0000000000f2'),
  'RCP-' || to_char(now(),'YYYY') || '-0003', '9. ...and the malformed number neither stops nor bends the sequence');
select is((select count(*)::int from public.events e join public.receipts r on r.id = e.entity_id
           where e.event_type_code = 'receipt_issued' and r.payment_id = '15600000-0000-0000-0000-0000000000f1'),
  1, '10. OBSERVABILITY: an RPC receipt has exactly one receipt_issued event -- the trigger is its one producer');

-- =============================================================================================
-- 11-14. RCPT-2 and REPLAY: only a customer payment, and only once.
-- =============================================================================================
select throws_ok($$select app.issue_receipt('15600000-0000-0000-0000-0000000000f3')$$,
  '23514','a receipt is proof that money was received: payment 15600000-0000-0000-0000-0000000000f3 is a supplier_payment, not a customer payment',
  '11. RCPT-2: the RPC refuses a receipt for an outbound supplier payment');
select throws_ok($$insert into public.receipts (tenant_id,payment_id,receipt_number)
                   values ('15600000-0000-0000-0000-000000000001','15600000-0000-0000-0000-0000000000f3','R')$$,
  '23514','a receipt is proof that money was received: payment 15600000-0000-0000-0000-0000000000f3 is a supplier_payment, not a customer payment',
  '12. ...and so does the table door');
select throws_ok($$select app.issue_receipt('15600000-0000-0000-0000-0000000000f1')$$,
  'P0001','a receipt already exists for this payment', '13. REPLAY: a second RPC receipt for f1 is refused');
select throws_ok($$insert into public.receipts (tenant_id,payment_id,receipt_number)
                   values ('15600000-0000-0000-0000-000000000001','15600000-0000-0000-0000-0000000000f1','R')$$,
  '23505', null, '14. REPLAY: ...and a second door receipt for f1 hits the unique key on (tenant, payment)');

-- =============================================================================================
-- 15-17. RCPT-1 for the capability holder: fixed once issued; the submission record moves.
-- =============================================================================================
select throws_ok($$update public.receipts set receipt_number = 'RCP-2000-0001' where id = '15600000-0000-0000-0000-00000000ca04'$$,
  '23514','receipt 15600000-0000-0000-0000-00000000ca04: its payment, number, issue time and origin are fixed when it is issued',
  '15. even the owner cannot renumber an issued receipt');
select lives_ok($$update public.receipts set external_submission_id = 'ETA-1', external_submitted_at = now()
                  where id = '15600000-0000-0000-0000-00000000ca04'$$,
  '16. the owner records the tax submission on the issued receipt');
select is((select external_submission_id from public.receipts where id = '15600000-0000-0000-0000-00000000ca04'),
  'ETA-1', '17. ...and it is kept');

-- =============================================================================================
-- 18-27. RCPT-1: a reader without CREATE_RECEIPT cannot rewrite a receipt.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"15600000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select ok(not app.has_permission('CREATE_RECEIPT') and not app.has_permission('VIEW_FINANCIAL_DOCUMENTS'),
  '18. the employee holds neither CREATE_RECEIPT nor VIEW_FINANCIAL_DOCUMENTS');
select is((select count(*)::int from public.receipts), 2,
  '19. NON-EMPTY: the employee sees the two receipts whose payments are on their booking');
select throws_ok($$update public.receipts set receipt_number = 'FAKE-0001' where payment_id = '15600000-0000-0000-0000-0000000000f1'$$,
  '23514', null, '20. the employee cannot renumber a receipt');
select throws_ok($$update public.receipts set payment_id = '15600000-0000-0000-0000-0000000000f5' where payment_id = '15600000-0000-0000-0000-0000000000f1'$$,
  '23514', null, '21. ...nor move it onto another payment of the booking');
select throws_ok($$update public.receipts set issued_at = now() - interval '2 years' where payment_id = '15600000-0000-0000-0000-0000000000f1'$$,
  '23514', null, '22. ...nor backdate it');
select throws_ok($$update public.receipts set created_at = now() - interval '2 years' where payment_id = '15600000-0000-0000-0000-0000000000f1'$$,
  '23514', null, '23. ...nor rewrite when it was created');
select throws_ok($$update public.receipts set external_submission_id = 'forged' where payment_id = '15600000-0000-0000-0000-0000000000f1'$$,
  '42501','permission denied: CREATE_RECEIPT', '24. ...nor write its tax-submission id');
select throws_ok($$update public.receipts set external_response_at = now() where payment_id = '15600000-0000-0000-0000-0000000000f1'$$,
  '42501','permission denied: CREATE_RECEIPT', '25. ...nor its tax-submission response time');
select throws_ok($$insert into public.receipts (tenant_id,payment_id,receipt_number)
                   values ('15600000-0000-0000-0000-000000000001','15600000-0000-0000-0000-0000000000f5','R')$$,
  '42501','permission denied: CREATE_RECEIPT', '26. ...nor issue one at the door (the capability guard, held)');
reset role;
select is((select receipt_number || '/' || payment_id::text || '/' || coalesce(external_submission_id,'<null>')
           from public.receipts where payment_id = '15600000-0000-0000-0000-0000000000f1'),
  'RCP-' || to_char(now(),'YYYY') || '-0002/15600000-0000-0000-0000-0000000000f1/<null>',
  '27. f1''s receipt is exactly as issued');

-- =============================================================================================
-- 28-30. The platform path: integrity holds without a session; the capability check keeps canon
--        35 principle 6's exemption.
-- =============================================================================================
select set_config('request.jwt.claims', null, true);
select throws_ok($$update public.receipts set receipt_number = 'RCP-2000-0001' where id = '15600000-0000-0000-0000-00000000ca04'$$,
  '23514','receipt 15600000-0000-0000-0000-00000000ca04: its payment, number, issue time and origin are fixed when it is issued',
  '28. a session-less write cannot renumber a receipt either: integrity, not authorization');
select throws_ok($$insert into public.receipts (tenant_id,payment_id,receipt_number)
                   values ('15600000-0000-0000-0000-000000000001','15600000-0000-0000-0000-0000000000f3','R')$$,
  '23514', null, '29. ...nor issue one for a supplier payment');
select lives_ok($$update public.receipts set external_response_at = now() where id = '15600000-0000-0000-0000-00000000ca04'$$,
  '30. the platform records a tax-submission response without a session (canon 35 principle 6)');

-- =============================================================================================
-- 31-33. TENANT, PRIVILEGE and the evidence count.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"15600000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select throws_ok($$insert into public.receipts (tenant_id,payment_id,receipt_number)
                   values ('15600000-0000-0000-0000-000000000002','15600000-0000-0000-0000-0000000000f9','R')$$,
  '42501', null, '31. TENANT: the owner cannot issue a receipt in the rival tenant');
reset role;
select ok(not has_function_privilege('authenticated','app.guard_receipt_issue()','execute')
      and not has_function_privilege('authenticated','app.emit_receipt_issued()','execute')
      and not has_function_privilege('anon','app.guard_receipt_issue()','execute')
      and not has_function_privilege('anon','app.emit_receipt_issued()','execute'),
  '32. PRIVILEGE: neither SECURITY DEFINER function is callable by an API role');
select is((select count(*)::int from public.events
           where event_type_code = 'receipt_issued' and tenant_id = '15600000-0000-0000-0000-000000000001'),
  4, '33. OBSERVABILITY: four receipts written (the legacy row too: only the guard was off), four events; no refused write left one');

select * from finish();
rollback;
