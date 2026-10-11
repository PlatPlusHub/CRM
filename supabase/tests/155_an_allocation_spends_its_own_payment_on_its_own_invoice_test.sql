-- pgTAP: Batch 6 Slice 40 -- payment_allocations. PAY-6, PAY-7, PAY-8, FIN-12, PAY-10 and PAY-11 (SPEC-264).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT BUSINESS PRIVILEGE CONCURRENCY OBSERVABILITY REPLAY=N/A
--
-- An allocation spends its own customer payment, in that payment's currency, on an invoice of the
-- payment's own customer; it never makes the payment settle more than it is, or the invoice receive
-- more than it is worth in the invoice's currency or less than its recorded status says; a currency
-- difference carries its rate (FA-2); once written it stays where it was put -- only its amount is
-- corrected, by RECORD_PAYMENT -- and every amount it is born with or corrected to is an event.
--
-- CONCURRENCY -- pgTAP has one session. Assertions 46-47 prove BEHAVIOURALLY that an allocation
--   write holds the invoice's advisory lock (the key app.record_payment takes) and the payment's,
--   read from pg_locks for this backend; the two-session race, refused only with the lock, is
--   recorded in SPEC-264.
-- REPLAY=N/A -- an allocation carries no token, nonce or single-use value; a repeated allocation is
--   a second row, bounded by both ceilings (assertions 15 and 44).
-- OBSERVABILITY -- assertions 49-54, 61, 63 and 65-66: one event per allocation and per real change of its
--   money, on the RPC, the door and the platform path; none for a no-op or a refused write.
--   A door allocation still leaves the invoice status where it was (PAY-5, not this contract's).
create extension if not exists pgtap with schema extensions;

begin;
select plan(68);

-- ---------------------------------------------------------------------------------------------
-- Fixture: one tenant (owner + employee), two customers, two bookings the employee owns, five
-- invoices, six payments, two rates; a rival tenant with its own payment and rate.
-- ---------------------------------------------------------------------------------------------
insert into auth.users (id,email,email_confirmed_at) values
  ('15500000-0000-0000-0000-0000000000a1','owner@pa155.test',now()),
  ('15500000-0000-0000-0000-0000000000a2','emp@pa155.test',now());
insert into public.tenants (id,name,slug,status) values
  ('15500000-0000-0000-0000-000000000001','PA155 Travel','pa155-travel','active'),
  ('15500000-0000-0000-0000-000000000002','PA155 Rival','pa155-rival','active');
insert into public.subscriptions (tenant_id,subscription_plan_id,subscription_status_code)
select t.id, sp.id, 'active' from public.subscription_plans sp
cross join (values ('15500000-0000-0000-0000-000000000001'::uuid),('15500000-0000-0000-0000-000000000002'::uuid)) t(id)
where sp.plan_code='enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('15500000-0000-0000-0000-00000000000a','15500000-0000-0000-0000-000000000001','Main','pa155-main');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('15500000-0000-0000-0000-0000000000c1','15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('15500000-0000-0000-0000-000000000011','15500000-0000-0000-0000-000000000001','Owner','owner@pa155.test',true,'15500000-0000-0000-0000-0000000000a1'),
  ('15500000-0000-0000-0000-000000000012','15500000-0000-0000-0000-000000000001','Employee','emp@pa155.test',true,'15500000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary) values
  ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-000000000011','15500000-0000-0000-0000-00000000000a','15500000-0000-0000-0000-0000000000c1',true),
  ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-000000000012','15500000-0000-0000-0000-00000000000a','15500000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '15500000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('15500000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('15500000-0000-0000-0000-000000000012'::uuid,'employee')) v(u,rc)
join public.roles r on r.code=v.rc;
insert into public.customers (id,tenant_id,customer_type_code,full_name) values
  ('15500000-0000-0000-0000-0000000000d1','15500000-0000-0000-0000-000000000001','person','C1'),
  ('15500000-0000-0000-0000-0000000000d2','15500000-0000-0000-0000-000000000001','person','C2'),
  ('15500000-0000-0000-0000-0000000000d9','15500000-0000-0000-0000-000000000002','person','Rival');
insert into public.suppliers (id,tenant_id,name,supplier_type_code) values
  ('15500000-0000-0000-0000-0000000000e9','15500000-0000-0000-0000-000000000001','Airline','airline');
insert into public.bookings (id,tenant_id,branch_id,department_id,customer_id,booking_status_code,title,booking_reference,owner_user_id) values
  ('15500000-0000-0000-0000-0000000000b1','15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-00000000000a','15500000-0000-0000-0000-0000000000c1','15500000-0000-0000-0000-0000000000d1','confirmed','B1','PA155-B1','15500000-0000-0000-0000-000000000012'),
  ('15500000-0000-0000-0000-0000000000b2','15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-00000000000a','15500000-0000-0000-0000-0000000000c1','15500000-0000-0000-0000-0000000000d2','confirmed','B2','PA155-B2','15500000-0000-0000-0000-000000000012');
-- IA, IC, ID, IU are C1's; IB is C2's. All on bookings the employee owns, so the employee sees them.
insert into public.invoices (id,tenant_id,customer_id,booking_id,invoice_number,currency_code,total_amount,status_code,invoice_date) values
  ('15500000-0000-0000-0000-0000000000e1','15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000d1','15500000-0000-0000-0000-0000000000b1','PA155-IA','EGP',1000,'draft',current_date),
  ('15500000-0000-0000-0000-0000000000e2','15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000d2','15500000-0000-0000-0000-0000000000b2','PA155-IB','EGP',1000,'draft',current_date),
  ('15500000-0000-0000-0000-0000000000e3','15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000d1','15500000-0000-0000-0000-0000000000b1','PA155-IC','EGP',1000,'draft',current_date),
  ('15500000-0000-0000-0000-0000000000e4','15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000d1','15500000-0000-0000-0000-0000000000b1','PA155-ID','EGP',1000,'draft',current_date),
  ('15500000-0000-0000-0000-0000000000e5','15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000d1','15500000-0000-0000-0000-0000000000b1','PA155-IU','USD',100,'draft',current_date);
insert into public.payments (id,tenant_id,payment_direction_code,customer_id,supplier_id,currency_code,payment_method_code,amount) values
  ('15500000-0000-0000-0000-0000000000f1','15500000-0000-0000-0000-000000000001','customer_payment','15500000-0000-0000-0000-0000000000d1',null,'EGP','cash',600),
  ('15500000-0000-0000-0000-0000000000f2','15500000-0000-0000-0000-000000000001','supplier_payment',null,'15500000-0000-0000-0000-0000000000e9','EGP','cash',500),
  ('15500000-0000-0000-0000-0000000000f3','15500000-0000-0000-0000-000000000001','customer_payment','15500000-0000-0000-0000-0000000000d1',null,'USD','cash',100),
  ('15500000-0000-0000-0000-0000000000f4','15500000-0000-0000-0000-000000000001','customer_payment','15500000-0000-0000-0000-0000000000d2',null,'EGP','cash',1000),
  ('15500000-0000-0000-0000-0000000000f5','15500000-0000-0000-0000-000000000001','customer_payment',null,null,'EGP','cash',100),
  ('15500000-0000-0000-0000-0000000000f6','15500000-0000-0000-0000-000000000001','customer_payment','15500000-0000-0000-0000-0000000000d1',null,'EGP','cash',5000),
  ('15500000-0000-0000-0000-0000000000f9','15500000-0000-0000-0000-000000000002','customer_payment','15500000-0000-0000-0000-0000000000d9',null,'EGP','cash',100);
insert into public.exchange_rates (id,tenant_id,from_currency_code,to_currency_code,rate,effective_at) values
  ('15500000-0000-0000-0000-00000000ee01','15500000-0000-0000-0000-000000000001','USD','EGP',50,now()-interval '1 day'),
  ('15500000-0000-0000-0000-00000000ee02','15500000-0000-0000-0000-000000000001','EGP','USD',0.02,now()-interval '1 day'),
  ('15500000-0000-0000-0000-00000000ee09','15500000-0000-0000-0000-000000000002','USD','EGP',50,now()-interval '1 day');
-- The fixture's payments carry PAY-3's deferred event trigger. Flush it here, session-less, so no
-- later 'set constraints all immediate' fires it under a signed-in caller of another tenant.
set constraints all immediate;
set constraints all deferred;

-- =============================================================================================
-- 1-4. Positive controls: the owner issues four invoices and allocates at the table door.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"15500000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select ok(app.has_permission('RECORD_PAYMENT') and app.has_permission('MERGE_CUSTOMER_IDENTITY'),
  '1. the owner holds RECORD_PAYMENT and MERGE_CUSTOMER_IDENTITY -- every refusal below is the invariant, not the permission');
-- Every lives_ok below that queues a deferred check also forces it inside its own block, so no later
-- 'set constraints all immediate' is refused by a stale event instead of the mechanism it names.
select lives_ok($q$do $x$ begin
    perform app.issue_invoice('15500000-0000-0000-0000-0000000000e1','go');
    perform app.issue_invoice('15500000-0000-0000-0000-0000000000e2','go');
    perform app.issue_invoice('15500000-0000-0000-0000-0000000000e3','go');
    perform app.issue_invoice('15500000-0000-0000-0000-0000000000e5','go');
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '2. IA, IB, IC and IU are issued; ID stays draft');
select lives_ok($q$do $x$ begin
    insert into public.payment_allocations (id,tenant_id,payment_id,invoice_id,allocated_amount,currency_code,allocated_amount_invoice_currency)
    values ('15500000-0000-0000-0000-00000000aa01','15500000-0000-0000-0000-000000000001',
            '15500000-0000-0000-0000-0000000000f1','15500000-0000-0000-0000-0000000000e1',600,'EGP',5);
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '3. a door allocation of C1''s 600 EGP payment to C1''s EGP invoice passes both commit checks, even naming a converted amount');
select is((select currency_code || '/' || coalesce(allocated_amount_invoice_currency::text,'<null>')
           from public.payment_allocations where id='15500000-0000-0000-0000-00000000aa01'),
  'EGP/<null>', '4. a same-currency allocation carries no converted amount (canon 31): the one it named is discarded, not accepted');

-- =============================================================================================
-- 5-13. PAY-6: a reader without RECORD_PAYMENT cannot move an allocation.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"15500000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select ok(not app.has_permission('RECORD_PAYMENT') and not app.has_permission('VIEW_FINANCIAL_DOCUMENTS'),
  '5. the employee holds neither RECORD_PAYMENT nor VIEW_FINANCIAL_DOCUMENTS');
select is((select count(*) from public.payment_allocations)::text || '/' || (select count(*) from public.payments)::text,
  '1/0', '6. NON-EMPTY: the employee sees the allocation (through an invoice on their booking) and no payment');
select throws_ok($$update public.payment_allocations set invoice_id='15500000-0000-0000-0000-0000000000e2'
                   where id='15500000-0000-0000-0000-00000000aa01'$$,
  '23514','payment allocation 15500000-0000-0000-0000-00000000aa01: its payment, invoice, currency, rate and origin are fixed when it is written; only its amount can be corrected',
  '7. the employee cannot move C1''s allocation onto C2''s invoice');
select throws_ok($$update public.payment_allocations set payment_id='15500000-0000-0000-0000-0000000000f2'
                   where id='15500000-0000-0000-0000-00000000aa01'$$,
  '23514','payment allocation 15500000-0000-0000-0000-00000000aa01: its payment, invoice, currency, rate and origin are fixed when it is written; only its amount can be corrected',
  '8. ...nor onto a supplier payment');
select throws_ok($$update public.payment_allocations set currency_code='USD'
                   where id='15500000-0000-0000-0000-00000000aa01'$$,
  '23514','payment allocation 15500000-0000-0000-0000-00000000aa01: its payment, invoice, currency, rate and origin are fixed when it is written; only its amount can be corrected',
  '9. ...nor rewrite its currency');
select throws_ok($$update public.payment_allocations set created_at=now()-interval '1 year'
                   where id='15500000-0000-0000-0000-00000000aa01'$$,
  '23514','payment allocation 15500000-0000-0000-0000-00000000aa01: its payment, invoice, currency, rate and origin are fixed when it is written; only its amount can be corrected',
  '10. ...nor backdate it');
select throws_ok($$update public.payment_allocations set allocated_amount=1
                   where id='15500000-0000-0000-0000-00000000aa01'$$,
  '42501','permission denied: RECORD_PAYMENT',
  '11. HELD: the amount still needs RECORD_PAYMENT (FIN-3''s guard, unchanged)');
select lives_ok($q$do $x$ begin
    update public.payment_allocations
       set invoice_id=invoice_id, payment_id=payment_id, allocated_amount_invoice_currency=5
     where id='15500000-0000-0000-0000-00000000aa01';
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '12. assigning the fixed fields their own values is not a move, and is not refused');
select is((select invoice_id::text || '|' || payment_id::text || '|' || currency_code || '|' || allocated_amount::text
                  || '|' || coalesce(allocated_amount_invoice_currency::text,'<null>')
           from public.payment_allocations where id='15500000-0000-0000-0000-00000000aa01'),
  '15500000-0000-0000-0000-0000000000e1|15500000-0000-0000-0000-0000000000f1|EGP|600.0000|<null>',
  '13. the allocation is unchanged, and the supplied converted amount was discarded, not accepted');

-- =============================================================================================
-- 14-24. PAY-6/7/8 for a RECORD_PAYMENT holder at the door.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"15500000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select throws_ok($$update public.payment_allocations set invoice_id='15500000-0000-0000-0000-0000000000e4'
                   where id='15500000-0000-0000-0000-00000000aa01'$$,
  '23514','payment allocation 15500000-0000-0000-0000-00000000aa01: its payment, invoice, currency, rate and origin are fixed when it is written; only its amount can be corrected',
  '14. STATE: even RECORD_PAYMENT cannot move paid money onto a DRAFT invoice (PAY-1 held on INSERT only)');
select throws_ok($q$do $x$ begin
    insert into public.payment_allocations (tenant_id,payment_id,invoice_id,allocated_amount,currency_code)
    values ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f1','15500000-0000-0000-0000-0000000000e3',1,'EGP');
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','payment 15500000-0000-0000-0000-0000000000f1 is over-allocated: 601.0000 allocated from a payment of 600.0000 (a payment cannot settle more than it is)',
  '15. a 600 payment already spent cannot settle one more piastre of another invoice');
select throws_ok($q$do $x$ begin
    insert into public.payment_allocations (tenant_id,payment_id,invoice_id,allocated_amount,currency_code)
    values ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f2','15500000-0000-0000-0000-0000000000e2',0,'EGP');
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','payment 15500000-0000-0000-0000-0000000000f2 is a supplier_payment and cannot settle a customer invoice',
  '16. money paid OUT to a supplier cannot settle a customer invoice, even at zero');
select throws_ok($q$do $x$ begin
    insert into public.payment_allocations (tenant_id,payment_id,invoice_id,allocated_amount,currency_code,exchange_rate_id)
    values ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f1','15500000-0000-0000-0000-0000000000e1',0,'USD',
            '15500000-0000-0000-0000-00000000ee01');
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','payment 15500000-0000-0000-0000-0000000000f1 is in EGP and an allocation of it claims another currency',
  '17. an allocation is in its payment''s currency (canon 31), even with a valid rate to the invoice');
select throws_ok($q$do $x$ begin
    insert into public.payment_allocations (tenant_id,payment_id,invoice_id,allocated_amount,currency_code)
    values ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f4','15500000-0000-0000-0000-0000000000e1',1,'EGP');
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','payment 15500000-0000-0000-0000-0000000000f4 settles an invoice of a customer other than the payment''s own',
  '18. C2''s payment cannot settle C1''s invoice: app.customer_balance credits the payment to C2');
select throws_ok($q$do $x$ begin
    insert into public.payment_allocations (tenant_id,payment_id,invoice_id,allocated_amount,currency_code)
    values ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f5','15500000-0000-0000-0000-0000000000e1',1,'EGP');
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','payment 15500000-0000-0000-0000-0000000000f5 settles an invoice of a customer other than the payment''s own',
  '19. ...nor can a payment no customer''s balance counts');
select throws_ok($$insert into public.payment_allocations (tenant_id,payment_id,invoice_id,allocated_amount,currency_code)
    values ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f3','15500000-0000-0000-0000-0000000000e1',100,'USD')$$,
  '23514','cross-currency allocation refused: a USD allocation to a EGP invoice requires an explicit exchange_rate_id (FA-2)',
  '20. PAY-8: 100 USD is never silently 100 EGP');
select throws_ok($$insert into public.payment_allocations (tenant_id,payment_id,invoice_id,allocated_amount,currency_code,exchange_rate_id)
    values ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f3','15500000-0000-0000-0000-0000000000e1',1,'USD',
            '15500000-0000-0000-0000-00000000ee02')$$,
  '23514','exchange rate converts EGP -> USD, but this allocation converts USD -> EGP',
  '21. INPUT: the rate must be the conversion this allocation performs');
select throws_ok($$insert into public.payment_allocations (tenant_id,payment_id,invoice_id,allocated_amount,currency_code,exchange_rate_id)
    values ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f1','15500000-0000-0000-0000-0000000000e1',0,'EGP',
            '15500000-0000-0000-0000-00000000ee01')$$,
  '23514','allocation currency EGP already matches the invoice currency: no conversion applies, so no exchange rate may be attached',
  '22. INPUT: a rate on a same-currency allocation is a contradiction, not extra care');
select throws_ok($$insert into public.payment_allocations (tenant_id,payment_id,invoice_id,allocated_amount,currency_code,exchange_rate_id)
    values ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f3','15500000-0000-0000-0000-0000000000e1',1,'USD',
            '15500000-0000-0000-0000-00000000ee09')$$,
  '23514','exchange rate is not in your tenant',
  '23. TENANT: another tenant''s rate is no evidence here');
select throws_ok($$insert into public.payment_allocations (tenant_id,payment_id,invoice_id,allocated_amount,currency_code)
    values ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f9','15500000-0000-0000-0000-0000000000e1',1,'EGP')$$,
  '23503', null,
  '24. TENANT: another tenant''s payment is refused by the tenant-qualified foreign key');

-- =============================================================================================
-- 25-29. PAY-7 from the payment's side: the payment cannot shrink or change beneath its allocations.
-- =============================================================================================
select throws_ok($q$do $x$ begin
    update public.payments set amount=500 where id='15500000-0000-0000-0000-0000000000f1';
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','payment 15500000-0000-0000-0000-0000000000f1 is over-allocated: 600.0000 allocated from a payment of 500.0000 (a payment cannot settle more than it is)',
  '25. a payment cannot shrink beneath what it already settled');
select throws_ok($q$do $x$ begin
    update public.payments set payment_direction_code='supplier_payment', customer_id=null,
           supplier_id='15500000-0000-0000-0000-0000000000e9' where id='15500000-0000-0000-0000-0000000000f1';
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','payment 15500000-0000-0000-0000-0000000000f1 is a supplier_payment and cannot settle a customer invoice',
  '26. ...nor become a supplier payment');
select throws_ok($q$do $x$ begin
    update public.payments set currency_code='USD' where id='15500000-0000-0000-0000-0000000000f1';
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','payment 15500000-0000-0000-0000-0000000000f1 is in USD and an allocation of it claims another currency',
  '27. ...nor change currency');
select throws_ok($q$do $x$ begin
    update public.payments set customer_id='15500000-0000-0000-0000-0000000000d2' where id='15500000-0000-0000-0000-0000000000f1';
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','payment 15500000-0000-0000-0000-0000000000f1 settles an invoice of a customer other than the payment''s own',
  '28. ...nor move to another customer');
select is((select p.amount::text || '/' || p.currency_code || '/' || p.payment_direction_code || '/' ||
                  (select sum(allocated_amount) from public.payment_allocations where payment_id=p.id)::text
           from public.payments p where p.id='15500000-0000-0000-0000-0000000000f1'),
  '600.0000/EGP/customer_payment/600.0000', '29. NON-MUTATION: the payment and its allocations are unchanged after every refusal');

-- =============================================================================================
-- 30-43. The legitimate work still works, and is counted in the invoice's currency.
-- =============================================================================================
select lives_ok($q$do $x$ begin
    insert into public.payment_allocations (id,tenant_id,payment_id,invoice_id,allocated_amount,currency_code,exchange_rate_id)
    values ('15500000-0000-0000-0000-00000000aa02','15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f3',
            '15500000-0000-0000-0000-0000000000e1',8,'USD','15500000-0000-0000-0000-00000000ee01');
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '30. FA-2 permits a cross-currency allocation with its rate: 8 USD to C1''s EGP invoice');
select is((select allocated_amount::text || '/' || allocated_amount_invoice_currency::text
           from public.payment_allocations where id='15500000-0000-0000-0000-00000000aa02'),
  '8.0000/400.0000', '31. the invoice-currency amount is derived from the rate: 8 USD at 50 is 400 EGP');
select throws_ok($$select app.record_payment('15500000-0000-0000-0000-0000000000e1',0.0001,'cash')$$,
  'P0001','payment 0.0001 exceeds invoice outstanding 0.0000 (total 1000.0000, already allocated 1000.0000)',
  '32. app.record_payment reads the invoice in its own currency: 600 EGP + 8 USD fill it (face value would leave 392)');
select lives_ok($q$do $x$ begin
    insert into public.payment_allocations (id,tenant_id,payment_id,invoice_id,allocated_amount,currency_code,exchange_rate_id)
    values ('15500000-0000-0000-0000-00000000aa03','15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f6',
            '15500000-0000-0000-0000-0000000000e5',5000,'EGP','15500000-0000-0000-0000-00000000ee02');
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '33. 5000 EGP settles a 100 USD invoice in full -- the ceiling counts USD, where face value would refuse 5000 > 100');
select is((select allocated_amount::text || '/' || allocated_amount_invoice_currency::text
           from public.payment_allocations where id='15500000-0000-0000-0000-00000000aa03'),
  '5000.0000/100.0000', '34. ...as 100 USD');
select lives_ok($q$do $x$ begin
    update public.payment_allocations set allocated_amount=0 where id='15500000-0000-0000-0000-00000000aa02';
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '35. RECORD_PAYMENT still corrects an amount');
select is((select allocated_amount::text || '/' || allocated_amount_invoice_currency::text
           from public.payment_allocations where id='15500000-0000-0000-0000-00000000aa02'),
  '0.0000/0.0000', '36. ...and the invoice-currency amount follows it');
select lives_ok($q$do $x$ begin
    update public.payment_allocations set allocated_amount=0 where id='15500000-0000-0000-0000-00000000aa01';
    insert into public.payment_allocations (id,tenant_id,payment_id,invoice_id,allocated_amount,currency_code)
    values ('15500000-0000-0000-0000-00000000aa04','15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f1',
            '15500000-0000-0000-0000-0000000000e3',600,'EGP');
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '37. the correction a misplaced allocation needs, where no recorded status rests on it: zero it, allocate again');
select is((select (select sum(coalesce(allocated_amount_invoice_currency,allocated_amount)) from public.payment_allocations
                    where invoice_id='15500000-0000-0000-0000-0000000000e1')::text || '/' ||
                  (select sum(allocated_amount) from public.payment_allocations
                    where invoice_id='15500000-0000-0000-0000-0000000000e3')::text),
  '0.0000/600.0000', '38. ...moving C1''s 600 from IA to IC, both rows kept as history');
select lives_ok($q$do $x$ begin
    update public.payments set amount=650 where id='15500000-0000-0000-0000-0000000000f1';
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '39. a payment can still grow above what it settled');
select lives_ok($q$do $x$ begin
    perform app.record_payment('15500000-0000-0000-0000-0000000000e2',300,'cash');
    perform app.record_payment('15500000-0000-0000-0000-0000000000e2',700,'cash');
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '40. app.record_payment still takes a partial and then the balance');
select is((select status_code || '/' || (select sum(allocated_amount) from public.payment_allocations pa where pa.invoice_id=i.id)::text
           from public.invoices i where i.id='15500000-0000-0000-0000-0000000000e2'),
  'paid/1000.0000', '41. ...and derives paid, exactly as before');
select lives_ok($q$do $x$ begin
    perform app.merge_customer_identity('15500000-0000-0000-0000-0000000000d2','15500000-0000-0000-0000-0000000000d1','duplicate identity');
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '42. merging C2 into C1 re-points C2''s paid invoice and its payments together and commits');
select is((select count(*)::int from public.payment_allocations pa
             join public.payments p on p.id=pa.payment_id join public.invoices i on i.id=pa.invoice_id
            where pa.tenant_id='15500000-0000-0000-0000-000000000001' and p.customer_id is distinct from i.customer_id),
  0, '43. ...leaving no allocation whose payment and invoice name different customers');

-- =============================================================================================
-- 44-45. No session-less exemption: integrity, not authorization.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{}',true);
select throws_ok($q$do $x$ begin
    insert into public.payment_allocations (tenant_id,payment_id,invoice_id,allocated_amount,currency_code)
    values ('15500000-0000-0000-0000-000000000001','15500000-0000-0000-0000-0000000000f1','15500000-0000-0000-0000-0000000000e1',51,'EGP');
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','payment 15500000-0000-0000-0000-0000000000f1 is over-allocated: 651.0000 allocated from a payment of 650.0000 (a payment cannot settle more than it is)',
  '44. a platform write cannot over-spend a payment either');
select throws_ok($$update public.payment_allocations set invoice_id='15500000-0000-0000-0000-0000000000e1'
                   where id='15500000-0000-0000-0000-00000000aa04'$$,
  '23514','payment allocation 15500000-0000-0000-0000-00000000aa04: its payment, invoice, currency, rate and origin are fixed when it is written; only its amount can be corrected',
  '45. ...nor move an allocation');

-- =============================================================================================
-- 46-48. FIN-12: an allocation write holds the invoice's lock (app.record_payment's key) and the
--        payment's, until commit; and the mechanism is installed as designed.
-- =============================================================================================
select ok(exists(select 1 from pg_locks l
                  where l.locktype='advisory' and l.pid=pg_backend_pid() and l.granted and l.objsubid=1
                    and l.classid=((hashtextextended('15500000-0000-0000-0000-0000000000e3',0) >> 32) & 4294967295)::oid
                    and l.objid=(hashtextextended('15500000-0000-0000-0000-0000000000e3',0) & 4294967295)::oid),
  '46. CONCURRENCY: allocating to IC took IC''s advisory lock, the key app.record_payment serialises on');
select ok(exists(select 1 from pg_locks l
                  where l.locktype='advisory' and l.pid=pg_backend_pid() and l.granted and l.objsubid=1
                    and l.classid=((hashtextextended('15500000-0000-0000-0000-0000000000f1',0) >> 32) & 4294967295)::oid
                    and l.objid=(hashtextextended('15500000-0000-0000-0000-0000000000f1',0) & 4294967295)::oid),
  '47. CONCURRENCY: ...and the payment''s, so two transactions cannot each spend its remainder');
select is((select string_agg(t.tgname || ':' || t.tgdeferrable::text || ':' || t.tginitdeferred::text || ':' || p.prosecdef::text
                             || ':' || coalesce(array_to_string(p.proconfig, ','), ''), ' | ' order by t.tgname)
           from pg_trigger t join pg_proc p on p.oid=t.tgfoid
           where t.tgname in ('payment_allocations_guard_link','payment_allocations_within_payment_amount','payments_amount_covers_allocations')
             and not t.tgisinternal and t.tgenabled='O'),
  'payment_allocations_guard_link:false:false:true:search_path="" | payment_allocations_within_payment_amount:true:true:true:search_path="" | payments_amount_covers_allocations:true:true:true:search_path=""',
  '48. the guard is immediate, both coherence checks run at commit, all SECURITY DEFINER with an empty search_path');

-- =============================================================================================
-- 49-54. PAY-10: every allocation and every real change of its money is an event, attributed and
--        timed by app.record_event, on the door and the RPC alike; nothing else is.
-- =============================================================================================
select is((select count(*)::text || '|' || string_agg(e.severity_code || ':' || (e.actor_user_id = '15500000-0000-0000-0000-000000000011')::text
                  || ':' || (e.payload ->> 'payment_id') || ':' || (e.payload ->> 'invoice_id') || ':' || (e.payload ->> 'currency_code')
                  || ':' || (e.payload ->> 'exchange_rate_id') || ':' || (e.payload ->> 'allocated_amount')
                  || ':' || (e.payload ->> 'allocated_amount_invoice_currency'), ',')
           from public.events e where e.entity_id='15500000-0000-0000-0000-00000000aa03' and e.event_type_code='payment_allocation_created'),
  '1|info:true:15500000-0000-0000-0000-0000000000f6:15500000-0000-0000-0000-0000000000e5:EGP:15500000-0000-0000-0000-00000000ee02:5000.0000:100.0000',
  '49. a door allocation is born with one event carrying its payment, invoice, currency, rate and both amounts (canon 27), by its actor');
select is((select count(distinct e.entity_id)::text || '|' || string_agg((e.payload ->> 'allocated_amount') || ':'
                  || (e.actor_user_id = '15500000-0000-0000-0000-000000000011')::text, ',' order by e.seq)
           from public.events e where e.event_type_code='payment_allocation_created'
            and e.payload ->> 'invoice_id' = '15500000-0000-0000-0000-0000000000e2'),
  '2|300.0000:true,700.0000:true', '50. ...and app.record_payment''s allocations exactly once each, through the same producer');
select is((select string_agg(e.event_type_code || ':' || e.severity_code || ':' || coalesce(e.payload ->> 'previous_allocated_amount','-')
                  || '>' || (e.payload ->> 'allocated_amount') || ':' || coalesce(e.payload ->> 'previous_allocated_amount_invoice_currency','-')
                  || '>' || (e.payload ->> 'allocated_amount_invoice_currency') || ':'
                  || (e.actor_user_id = '15500000-0000-0000-0000-000000000011')::text, ' | ' order by e.seq)
           from public.events e where e.entity_id='15500000-0000-0000-0000-00000000aa02'),
  'payment_allocation_created:info:->8.0000:->400.0000:true | payment_allocation_amount_changed:warning:8.0000>0.0000:400.0000>0.0000:true',
  '51. assertion 35''s correction is recorded with the amounts before and after, in both currencies, by its actor');
select is((select string_agg(e.event_type_code || ':' || (e.payload ->> 'invoice_id') || ':' || coalesce(e.payload ->> 'previous_allocated_amount','-')
                  || '>' || (e.payload ->> 'allocated_amount'), ' | ' order by e.seq)
           from public.events e where e.entity_id in ('15500000-0000-0000-0000-00000000aa01','15500000-0000-0000-0000-00000000aa04')),
  'payment_allocation_created:15500000-0000-0000-0000-0000000000e1:->600.0000 | payment_allocation_amount_changed:15500000-0000-0000-0000-0000000000e1:600.0000>0.0000 | payment_allocation_created:15500000-0000-0000-0000-0000000000e3:->600.0000',
  '52. assertion 37''s move of C1''s 600 from IA to IC reads back from the events alone');
select is((select count(*)::int from public.events e where e.entity_id='15500000-0000-0000-0000-00000000aa01'), 2,
  '53. assertion 12''s UPDATE, which changed no money, recorded nothing');
select is((select count(*)::int from public.events e
            where e.tenant_id='15500000-0000-0000-0000-000000000001' and e.entity_type='payment_allocation'), 8,
  '54. six allocations and two corrections are eight events: the writes refused at 15-28 and 44-45 left none');

-- =============================================================================================
-- 55-61. PAY-11: an allocation write cannot leave an invoice's recorded status claiming more than
--        is allocated to it -- canon 26 has no way back out of paid or partially_paid.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"15500000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select throws_ok($q$do $x$ begin
    update public.payment_allocations set allocated_amount=0
     where invoice_id='15500000-0000-0000-0000-0000000000e2' and allocated_amount=700;
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','invoice 15500000-0000-0000-0000-0000000000e2 is paid and its allocations would total 300.0000 of 1000.0000: an allocation that settled it cannot be reduced (canon 26: no transition leaves paid)',
  '55. zeroing an allocation that settled a paid invoice is refused: it would strand the invoice paid on 300');
select throws_ok($q$do $x$ begin
    update public.payment_allocations set allocated_amount=699.9999
     where invoice_id='15500000-0000-0000-0000-0000000000e2' and allocated_amount=700;
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','invoice 15500000-0000-0000-0000-0000000000e2 is paid and its allocations would total 999.9999 of 1000.0000: an allocation that settled it cannot be reduced (canon 26: no transition leaves paid)',
  '56. ...and so is the smallest reduction the money column can hold');select is((select status_code || '/' || (select sum(allocated_amount) from public.payment_allocations pa where pa.invoice_id=i.id)::text
           from public.invoices i where i.id='15500000-0000-0000-0000-0000000000e2'),
  'paid/1000.0000', '57. NON-MUTATION: IB is still paid on its full 1000');
select lives_ok($q$do $x$ begin
    perform app.issue_invoice('15500000-0000-0000-0000-0000000000e4','go');
    perform app.record_payment('15500000-0000-0000-0000-0000000000e4',400,'cash');
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
    update public.payment_allocations set allocated_amount=100 where invoice_id='15500000-0000-0000-0000-0000000000e4';
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '58. a partially_paid invoice''s allocation can be reduced while it stays partially paid (400 -> 100)');
select throws_ok($q$do $x$ begin
    update public.payment_allocations set allocated_amount=0 where invoice_id='15500000-0000-0000-0000-0000000000e4';
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','invoice 15500000-0000-0000-0000-0000000000e4 is partially_paid and its allocations would total 0: an allocation that settled it cannot be removed (canon 26: no transition returns it to issued)',
  '59. ...but not removed');
select is((select string_agg(i.invoice_number || ':' || i.status_code || ':'
                  || coalesce((select sum(coalesce(pa.allocated_amount_invoice_currency, pa.allocated_amount))
                                 from public.payment_allocations pa where pa.invoice_id=i.id)::text, '-'), ' | ' order by i.invoice_number)
           from public.invoices i where i.id in ('15500000-0000-0000-0000-0000000000e1','15500000-0000-0000-0000-0000000000e2','15500000-0000-0000-0000-0000000000e4')),
  'PA155-IA:issued:0.0000 | PA155-IB:paid:1000.0000 | PA155-ID:partially_paid:100.0000',
  '60. the floor refuses and moves no status: the door''s IA stays issued (PAY-5), IB paid, ID partially_paid');
select is((select string_agg(e.event_type_code || ':' || e.severity_code || ':' || coalesce(e.payload ->> 'previous_allocated_amount','-')
                  || '>' || (e.payload ->> 'allocated_amount'), ' | ' order by e.seq)
           from public.events e where e.entity_type='payment_allocation'
            and e.payload ->> 'invoice_id' = '15500000-0000-0000-0000-0000000000e4'),
  'payment_allocation_created:info:->400.0000 | payment_allocation_amount_changed:warning:400.0000>100.0000',
  '61. ID''s allocation history is its birth and the one reduction that committed');

-- =============================================================================================
-- 62-65. The platform path is recorded and bounded too, and an untouched amount stays as it was written.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{}',true);
select lives_ok($q$do $x$ begin
    update public.payment_allocations set allocated_amount=500 where id='15500000-0000-0000-0000-00000000aa04';
    execute 'set constraints all immediate'; execute 'set constraints all deferred';
  end $x$$q$,
  '62. a session-less correction on an issued invoice passes every check');
select is((select e.event_type_code || ':' || (e.payload ->> 'previous_allocated_amount') || '>' || (e.payload ->> 'allocated_amount')
                  || ':' || coalesce(e.actor_user_id::text, '<system>')
           from public.events e where e.entity_id='15500000-0000-0000-0000-00000000aa04' order by e.seq desc limit 1),
  'payment_allocation_amount_changed:600.0000>500.0000:<system>',
  '63. ...and is recorded as a system change, not skipped (no session-less exemption)');
select throws_ok($q$do $x$ begin
    update public.payment_allocations set allocated_amount=0
     where invoice_id='15500000-0000-0000-0000-0000000000e2' and allocated_amount=700;
    execute 'set constraints all immediate';
  end $x$$q$,
  '23514','invoice 15500000-0000-0000-0000-0000000000e2 is paid and its allocations would total 300.0000 of 1000.0000: an allocation that settled it cannot be reduced (canon 26: no transition leaves paid)',
  '64. ...and the platform cannot strand a paid invoice either: integrity, not authorization');update public.exchange_rates set rate=0.03 where id='15500000-0000-0000-0000-00000000ee02';
update public.payment_allocations set allocated_amount=allocated_amount where id='15500000-0000-0000-0000-00000000aa03';
select is((select pa.allocated_amount_invoice_currency::text || '/' ||
                  (select count(*) from public.events e where e.entity_id=pa.id)::text
           from public.payment_allocations pa where pa.id='15500000-0000-0000-0000-00000000aa03'),
  '100.0000/1', '65. after its rate row is edited, touching an allocation without changing its amount changes no money and records nothing');

-- =============================================================================================
-- 66-68. Who reads the history, and the mechanism as installed.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"15500000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select is((select count(*) filter (where pa.id is null)::text || '/' || count(*)::text
           from public.events e left join public.payment_allocations pa on pa.id=e.entity_id
           where e.entity_type='payment_allocation'),
  '0/11', '66. the employee reads the history of exactly the allocations they can read (audit_read''s existing branch)');
reset role;
select is((select string_agg(t.tgname || ':' || p.proname || ':' || (pg_get_triggerdef(t.oid) like '% WHEN %')::text || ':'
                             || p.prosecdef::text || ':' || coalesce(array_to_string(p.proconfig, ','), ''), ' | ' order by t.tgname)
           from pg_trigger t join pg_proc p on p.oid=t.tgfoid
           where t.tgrelid='public.payment_allocations'::regclass and t.tgname like 'payment_allocations_emit_%'
             and not t.tgisinternal and t.tgenabled='O')
         || ' | ' || (select count(*) from public.catalog_values
                       where catalog_type_code='event_type' and code='payment_allocation_amount_changed' and tenant_id is null)::text,
  'payment_allocations_emit_amount_changed:emit_payment_allocation_event:true:true:search_path="" | payment_allocations_emit_created:emit_payment_allocation_event:false:true:search_path="" | 1',
  '67. one producer for both events, the change event conditional on money, SECURITY DEFINER with an empty search_path; the code is registered');
select is(has_table_privilege('anon','public.payment_allocations','DELETE')::text || '/'
          || has_table_privilege('authenticated','public.payment_allocations','DELETE')::text || '/'
          || has_table_privilege('service_role','public.payment_allocations','DELETE')::text || '/'
          || exists(select 1 from pg_trigger where tgname='events_append_only' and tgrelid='public.events'::regclass)::text,
  'false/false/false/true', '68. no API role can delete an allocation, and its events are append-only');
select finish();
rollback;
