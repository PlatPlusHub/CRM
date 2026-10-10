-- pgTAP: Batch 6 slice 36 -- a quotation line stays on its quotation, in its quotation's currency, at
-- its own quantity times its own unit price (SPEC-258: QUO-9, QUO-10).
--
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT BUSINESS CONCURRENCY OBSERVABILITY PRIVILEGE=N/A REPLAY=N/A
--   PRIVILEGE=N/A -- the guard is SECURITY DEFINER and takes nothing from its caller but the row being
--     written; it reads the quotation by the row's own tenant and id.
--   REPLAY=N/A -- adding the same line twice is two lines, each judged on its own; nothing is consumed.
--   CONCURRENCY -- pgTAP has one session. Assertion 31 is a TEXT tripwire, not a behavioural proof: it
--     measures that the guard's source reads the quotation `for update`, the lock
--     `app.add_quotation_item` takes. The two-session reproduction, before and after the repair, is
--     recorded in SPEC-258.
--
-- `app.add_quotation_item` locks the quotation, refuses any status but `draft`, stamps the line with
-- the quotation's currency and writes `quantity * unit_price`; `app.recompute_quotation_total` sums the
-- line totals into the quotation. The table door did none of the middle three:
--   QUO-9:  a line's total and currency were whatever the direct writer stated, and a user DENIED
--           CREATE_QUOTATION moved the quotation's total through the line total.
--   QUO-10: a line was moved off a SENT quotation, which was then accepted at 0.
--
-- THE FIXTURE. One tenant, one branch and department. `emp` is an employee; `den` is an employee
-- carrying an explicit DENY on CREATE_QUOTATION. A rival tenant holds one SENT quotation in SAR.
create extension if not exists pgtap with schema extensions;

begin;
select plan(33);

insert into auth.users (id, email) values
  ('15000000-0000-0000-0000-0000000000a1','emp@q150.test'),
  ('15000000-0000-0000-0000-0000000000a2','den@q150.test');
insert into public.tenants (id, name, slug, status) values
  ('15000000-0000-0000-0000-000000000001','Q150 Travel','q150-travel','active'),
  ('15000000-0000-0000-0000-000000000002','Q150 Rival','q150-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['15000000-0000-0000-0000-000000000001'::uuid,'15000000-0000-0000-0000-000000000002']) t
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('15000000-0000-0000-0000-00000000000a','15000000-0000-0000-0000-000000000001','Cairo','q150-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('15000000-0000-0000-0000-0000000000c1','15000000-0000-0000-0000-000000000001','15000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('15000000-0000-0000-0000-000000000011','15000000-0000-0000-0000-000000000001','Emp','emp@q150.test',true,'15000000-0000-0000-0000-0000000000a1'),
  ('15000000-0000-0000-0000-000000000021','15000000-0000-0000-0000-000000000001','Den','den@q150.test',true,'15000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '15000000-0000-0000-0000-000000000001', u, '15000000-0000-0000-0000-00000000000a', '15000000-0000-0000-0000-0000000000c1', true
from unnest(array['15000000-0000-0000-0000-000000000011'::uuid,'15000000-0000-0000-0000-000000000021']) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '15000000-0000-0000-0000-000000000001', u, r.id, 'tenant' from public.roles r,
  unnest(array['15000000-0000-0000-0000-000000000011'::uuid,'15000000-0000-0000-0000-000000000021']) u
where r.code = 'employee';
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '15000000-0000-0000-0000-000000000001','15000000-0000-0000-0000-000000000021', p.id, 'deny', 'q150: may read quotations, may not author them'
from public.permissions p where p.key = 'CREATE_QUOTATION';
insert into public.customers (id, tenant_id, customer_type_code, full_name, first_registered_branch_id) values
  ('15000000-0000-0000-0000-0000000000d1','15000000-0000-0000-0000-000000000001','person','Buyer','15000000-0000-0000-0000-00000000000a');
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('15000000-0000-0000-0000-0000000000e1','15000000-0000-0000-0000-000000000002','person','Rival Buyer');
insert into public.quotations (id, tenant_id, customer_id, quotation_status_code, quotation_number, currency_code)
values ('15000000-0000-0000-0000-0000000000f9','15000000-0000-0000-0000-000000000002',
        '15000000-0000-0000-0000-0000000000e1','sent','Q150-RIVAL','SAR');

-- The line ids and quotation ids the assertions name.
create function pg_temp.q(p_number text) returns uuid language sql as
  $$ select id from public.quotations where quotation_number = p_number $$;

select set_config('request.jwt.claims','{"sub":"15000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;

-- =============================================================================================
-- 1-6. THE ACTOR AND THE SANCTIONED PATHS.
-- =============================================================================================
select ok(current_user = 'authenticated'
          and auth.uid() = '15000000-0000-0000-0000-0000000000a1'
          and app.has_permission('CREATE_QUOTATION') and app.has_permission('SEND_QUOTATION'),
  '1. the actor is emp, signed in, holding CREATE_QUOTATION and SEND_QUOTATION, so no refusal below is a permission');

select app.create_quotation(p_customer_id => '15000000-0000-0000-0000-0000000000d1', p_currency_code => 'EGP',
                            p_lead_id => null, p_valid_until => null, p_quotation_number => n)
from unnest(array['Q150-1','Q150-2','Q150-3']) n;

select lives_ok($$select app.add_quotation_item(pg_temp.q('Q150-1'), 'hotel', 1000, 1)$$,
  '2. the RPC adds a 1,000 line to quotation 1');
select lives_ok($$select app.add_quotation_item(pg_temp.q('Q150-2'), 'flight_ticket', 500, 1)$$,
  '3. the RPC adds a 500 line to quotation 2');
select lives_ok($$select app.add_quotation_item(pg_temp.q('Q150-2'), 'visa', 33.3333, 1.5)$$,
  '4. the RPC adds 33.3333 x 1.5, whose product 49.99995 is stored as 50.0000: the guard compares in the column''s own type');
select lives_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('15000000-0000-0000-0000-000000000001', pg_temp.q('Q150-2'), 'transport', 'EGP', 250, 2, 500)$$,
  '5. a direct INSERT whose total is its quantity times its price, in the quotation''s currency, still lands on a draft');
select is((select total_amount::text from public.quotations where id = pg_temp.q('Q150-2')), '1050.0000',
  '6. quotation 2 is the sum of its three lines: 500 + 50 + 500');

-- =============================================================================================
-- 7-15. QUO-9 -- the line's total and currency are its own.
-- =============================================================================================
select throws_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('15000000-0000-0000-0000-000000000001', pg_temp.q('Q150-2'), 'visa', 'EGP', 100, 1, 90000)$$,
  '23514', null,
  '7. QUO-9: a 100 x 1 line stated at 90,000 is refused -- before SPEC-258 it took the quotation from 500 to 90,500');
select throws_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity)
    values ('15000000-0000-0000-0000-000000000001', pg_temp.q('Q150-2'), 'visa', 'EGP', 100, 1)$$,
  '23514', null,
  '8. QUO-9: a 100 x 1 line that omits its total, and so takes the column default 0, is refused');
select throws_ok(
  $$update public.quotation_items set total_amount = 1
     where quotation_id = pg_temp.q('Q150-2') and service_type_code = 'flight_ticket'$$,
  '23514', null,
  '9. QUO-9: a 500 x 1 line''s total rewritten to 1 is refused -- before SPEC-258 the quotation followed it to 1');
select lives_ok(
  $$update public.quotation_items set unit_price = 600, total_amount = 600
     where quotation_id = pg_temp.q('Q150-2') and service_type_code = 'flight_ticket'$$,
  '10. a draft line repriced with its total is still an ordinary edit');
select throws_ok(
  $$update public.quotation_items set unit_price = 700
     where quotation_id = pg_temp.q('Q150-2') and service_type_code = 'flight_ticket'$$,
  '23514', null,
  '11. a price changed without its total is refused: the line is judged as the statement leaves it');
select throws_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('15000000-0000-0000-0000-000000000001', pg_temp.q('Q150-2'), 'visa', 'USD', 100, 1, 100)$$,
  '23514', null,
  '12. QUO-9: a USD line on an EGP quotation is refused -- before SPEC-258 it was summed into the EGP total');
select throws_ok(
  $$update public.quotation_items set currency_code = 'SAR'
     where quotation_id = pg_temp.q('Q150-2') and service_type_code = 'transport'$$,
  '23514', null,
  '13. QUO-9: an existing line cannot be re-labelled into another currency');
select is(
  (select count(*)::int from public.quotation_items i join public.quotations q on q.id = i.quotation_id
    where q.id = pg_temp.q('Q150-2') and i.currency_code = q.currency_code
      and i.total_amount = (i.quantity * i.unit_price)::numeric(19,4)),
  3,
  '14. every line of quotation 2 is in its quotation''s currency at its own quantity times price');
select is((select total_amount::text from public.quotations where id = pg_temp.q('Q150-2')), '1150.0000',
  '15. and quotation 2 reads 600 + 50 + 500, moved only by the ordinary edit');

-- =============================================================================================
-- 16-20. QUO-9's authority half -- a user DENIED CREATE_QUOTATION.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"15000000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select ok(current_user = 'authenticated'
          and auth.uid() = '15000000-0000-0000-0000-0000000000a2'
          and not app.has_permission('CREATE_QUOTATION')
          and (select count(*) from public.quotation_items where quotation_id = pg_temp.q('Q150-2')) > 0,
  '16. the actor is den, signed in, DENIED CREATE_QUOTATION, and sees quotation 2''s lines');
select throws_ok(
  $$update public.quotation_items set unit_price = 1, total_amount = 1
     where quotation_id = pg_temp.q('Q150-2') and service_type_code = 'flight_ticket'$$,
  '42501', null,
  '17. HELD: den''s price change is charged CREATE_QUOTATION and refused');
select throws_ok(
  $$update public.quotation_items set total_amount = 7
     where quotation_id = pg_temp.q('Q150-2') and service_type_code = 'flight_ticket'$$,
  '23514', null,
  '18. QUO-9: den''s total-only rewrite is refused -- before SPEC-258 it was not charged, and the quotation went to 7');
select throws_ok(
  $$update public.quotation_items set quotation_id = pg_temp.q('Q150-3')
     where quotation_id = pg_temp.q('Q150-2') and service_type_code = 'flight_ticket'$$,
  '23514', null,
  '19. QUO-10: den cannot move a line to another quotation either');
select lives_ok(
  $$update public.quotation_items set description = 'window seat'
     where quotation_id = pg_temp.q('Q150-2') and service_type_code = 'flight_ticket'$$,
  '20. PINNED, NOT ASSERTED AS CORRECT: den edits a draft line''s description. FIN-3 charges a financial row''s money columns on UPDATE and leaves the rest to the authority already held, and the quotation header lets den edit too through SEND_QUOTATION; SPEC-258 changes neither');
reset role;
select set_config('request.jwt.claims','{"sub":"15000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;

-- =============================================================================================
-- 21-26. QUO-10 -- a line stays on the quotation it was added to.
-- =============================================================================================
select throws_ok(
  $$update public.quotation_items set quotation_id = pg_temp.q('Q150-3')
     where quotation_id = pg_temp.q('Q150-2') and service_type_code = 'transport'$$,
  '23514', null,
  '21. QUO-10: a line cannot move between two DRAFT quotations: no sanctioned writer moves a line');
select lives_ok($$select app.advance_quotation(pg_temp.q('Q150-1'), 'sent', 'to the customer')$$,
  '22. quotation 1 is sent through the state machine, carrying its 1,000 line');
select throws_ok(
  $$update public.quotation_items set quotation_id = pg_temp.q('Q150-3')
     where quotation_id = pg_temp.q('Q150-1')$$,
  '23514', null,
  '23. QUO-10: the sent quotation''s line cannot be moved OUT to a draft -- before SPEC-258 this left it empty at 0');
select throws_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('15000000-0000-0000-0000-000000000001', pg_temp.q('Q150-1'), 'visa', 'EGP', 300, 1, 300)$$,
  '23514', null,
  '24. HELD (QUO-2): a line still cannot be added to the sent quotation');
select lives_ok($$select app.advance_quotation(pg_temp.q('Q150-1'), 'accepted', 'customer agreed')$$,
  '25. the customer accepts quotation 1');
select is(
  (select string_agg(e.event_type_code || '=' || (e.payload ->> 'total_amount'), ',' order by e.event_type_code)
     from public.events e where e.entity_id = pg_temp.q('Q150-1') and e.event_type_code in ('quotation_sent','quotation_accepted'))
  || ' / ' || (select total_amount::text || ' x' || (select count(*) from public.quotation_items where quotation_id = q.id)
                 from public.quotations q where q.id = pg_temp.q('Q150-1')),
  'quotation_accepted=1000.0000,quotation_sent=1000.0000 / 1000.0000 x1',
  '26. QUO-10: what was sent is what was accepted -- before SPEC-258 the sent event said 1,000 and the acceptance 0');

-- =============================================================================================
-- 27. TENANT -- held by RLS.
-- =============================================================================================
select throws_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('15000000-0000-0000-0000-000000000002', '15000000-0000-0000-0000-0000000000f9', 'visa', 'EGP', 1, 1, 1)$$,
  '42501', null,
  '27. TENANT: emp naming the rival tenant''s SENT quotation is refused by RLS, and the guard reports nothing of that quotation -- before SPEC-258 it answered 23514 "a sent quotation cannot have its lines changed"');

-- =============================================================================================
-- 28-29. THE RULE BINDS EVERY CALLER: no sanctioned platform writer moves or misprices a line.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', '', true);
select throws_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('15000000-0000-0000-0000-000000000001', pg_temp.q('Q150-3'), 'visa', 'EGP', 100, 1, 5)$$,
  '23514', null,
  '28. a session-less writer cannot store a 100 x 1 line at 5');
select throws_ok(
  $$update public.quotation_items set quotation_id = pg_temp.q('Q150-3')
     where quotation_id = pg_temp.q('Q150-2') and service_type_code = 'transport'$$,
  '23514', null,
  '29. nor move a line between quotations');

-- =============================================================================================
-- 30-33. PAR-4: the guard is what refuses, and the lock is in its text.
-- =============================================================================================
savepoint par4;
drop trigger quotation_items_guard_parent_editable on public.quotation_items;
select lives_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('15000000-0000-0000-0000-000000000001', pg_temp.q('Q150-3'), 'visa', 'USD', 100, 1, 90000)$$,
  '30. MUTATION: with the guard''s trigger dropped, a foreign-currency line at 90,000 for 100 x 1 lands -- no constraint was refusing it');
rollback to savepoint par4;

select ok(
  (select p.prosrc ~* 'from\s+public\.quotations\s+q\s+where\s+q\.id\s*=\s*new\.quotation_id[^;]*\sfor\s+update\s*;'
     from pg_proc p where p.oid = 'app.guard_quotation_item_parent_editable()'::regprocedure),
  '31. TRIPWIRE, TEXT ONLY: the guard reads the quotation FOR UPDATE, the lock app.add_quotation_item takes. It proves no ordering; the two-session proof is recorded in SPEC-258');
select throws_ok(
  $$insert into public.quotation_items (tenant_id, quotation_id, service_type_code, currency_code, unit_price, quantity, total_amount)
    values ('15000000-0000-0000-0000-000000000001', pg_temp.q('Q150-3'), 'visa', 'USD', 100, 1, 90000)$$,
  '23514', null,
  '32. ...and once the mutation is rolled back the identical insert is refused again');
select is(
  (select count(*)::int from public.quotation_items where quotation_id = pg_temp.q('Q150-3')),
  0,
  '33. quotation 3 holds no line: every refusal above was a refusal, not a partial write');

select * from finish();
rollback;
