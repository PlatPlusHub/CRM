-- B6-EXIT bundle B: RFD-3 a refund's life, CHAT-2 a conversation's life and PAY-5 / FIN-11 an
-- invoice's settlement are produced by the table, so the table door and the RPC door record the same
-- acts once each. Each table-door case below recorded nothing (or settled nothing) at 7c5975a.
create extension if not exists pgtap with schema extensions;

begin;
select plan(36);

insert into auth.users (id, email) values
    ('18400000-0000-0000-0000-0000000000a1', 'owner@door184.test'),
    ('18400000-0000-0000-0000-0000000000a2', 'finance@door184.test'),
    ('18400000-0000-0000-0000-0000000000a3', 'emp@door184.test');
insert into public.tenants (id, name, slug, status)
values ('18400000-0000-0000-0000-000000000001', 'Door 184 Travel', 'door-184', 'active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '18400000-0000-0000-0000-000000000001', id, 'active'
from public.subscription_plans where plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug)
values ('18400000-0000-0000-0000-00000000000a', '18400000-0000-0000-0000-000000000001', 'HQ', 'door-184-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name)
values ('18400000-0000-0000-0000-00000000000b', '18400000-0000-0000-0000-000000000001',
        '18400000-0000-0000-0000-00000000000a', 'sales', 'Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
    ('18400000-0000-0000-0000-000000000011', '18400000-0000-0000-0000-000000000001', 'Owner', 'owner@door184.test', true, '18400000-0000-0000-0000-0000000000a1'),
    ('18400000-0000-0000-0000-000000000012', '18400000-0000-0000-0000-000000000001', 'Finance', 'finance@door184.test', true, '18400000-0000-0000-0000-0000000000a2'),
    ('18400000-0000-0000-0000-000000000013', '18400000-0000-0000-0000-000000000001', 'Emp', 'emp@door184.test', true, '18400000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select tenant_id, id, '18400000-0000-0000-0000-00000000000a', '18400000-0000-0000-0000-00000000000b', true
from public.users where tenant_id = '18400000-0000-0000-0000-000000000001';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '18400000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('18400000-0000-0000-0000-000000000011'::uuid, 'owner'),
             ('18400000-0000-0000-0000-000000000012'::uuid, 'finance_manager'),
             ('18400000-0000-0000-0000-000000000013'::uuid, 'employee')) v(u, rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name)
values ('18400000-0000-0000-0000-0000000000d1', '18400000-0000-0000-0000-000000000001', 'person', 'Buyer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id)
values ('18400000-0000-0000-0000-0000000000b1', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-00000000000a',
        '18400000-0000-0000-0000-00000000000b', '18400000-0000-0000-0000-0000000000d1', 'draft', 'Trip', 'BR-DOOR184-1',
        '18400000-0000-0000-0000-000000000013');
-- Four issued invoices of 5000 (session-less fixture, test 111 pattern): e1 RPC, e2 one full door
-- allocation, e3 two partial door allocations, e4 an allocation lowered then raised.
insert into public.invoices (id, tenant_id, customer_id, booking_id, invoice_number, invoice_date, currency_code, total_amount, status_code)
select ('18400000-0000-0000-0000-0000000000e' || n)::uuid, '18400000-0000-0000-0000-000000000001',
       '18400000-0000-0000-0000-0000000000d1', '18400000-0000-0000-0000-0000000000b1', 'INV-184-' || n,
       current_date, 'EGP', 5000, 'issued'
from generate_series(1, 4) n;
insert into public.conversations (id, tenant_id, customer_id, channel_code, conversation_status_code, owner_user_id,
    owner_branch_id, owner_department_id, current_branch_id, current_department_id, external_conversation_id)
select ('18400000-0000-0000-0000-0000000000c' || n)::uuid, '18400000-0000-0000-0000-000000000001',
       '18400000-0000-0000-0000-0000000000d1', 'whatsapp', 'open', '18400000-0000-0000-0000-000000000013',
       '18400000-0000-0000-0000-00000000000a', '18400000-0000-0000-0000-00000000000b',
       '18400000-0000-0000-0000-00000000000a', '18400000-0000-0000-0000-00000000000b', 'door-184-cv-' || n
from generate_series(1, 2) n;
create temporary table r (k text primary key, v uuid);
grant all on r to authenticated;

-- ===== RFD-3: finance at aal2, the table door beside the RPC door.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18400000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select lives_ok($$insert into public.refunds (id, tenant_id, payment_direction_code, customer_id, booking_id, refund_reason_code, currency_code, amount, refund_status_code)
                  values ('18400000-0000-0000-0000-0000000000f1', '18400000-0000-0000-0000-000000000001', 'customer_refund',
                          '18400000-0000-0000-0000-0000000000d1', '18400000-0000-0000-0000-0000000000b1', 'customer_cancelled', 'EGP', 100, 'requested')$$,
                'RFD-3: a refund is requested at the table door');
select lives_ok($$update public.refunds set refund_status_code = 'approved' where id = '18400000-0000-0000-0000-0000000000f1'$$,
                'RFD-3: the table door approves it');
select lives_ok($$update public.refunds set refund_status_code = 'completed' where id = '18400000-0000-0000-0000-0000000000f1'$$,
                'RFD-3: the table door completes it');
insert into r values ('rf_rpc', app.record_refund('18400000-0000-0000-0000-0000000000d1', 100, 'EGP', 'customer_cancelled',
                                                  '18400000-0000-0000-0000-0000000000b1', null));
select app.advance_refund((select v from r where k = 'rf_rpc'), 'approved', 'ok');
select app.advance_refund((select v from r where k = 'rf_rpc'), 'completed', 'paid out');
reset role;

select results_eq(
    $$select event_type_code, severity_code, previous_state, new_state, reason, actor_user_id, payload->>'amount'
      from public.events where entity_id = '18400000-0000-0000-0000-0000000000f1' order by seq$$,
    $$values ('refund_requested', 'info', null::text, 'requested', 'customer_cancelled', '18400000-0000-0000-0000-000000000012'::uuid, '100.0000'),
             ('refund_approved', 'info', 'requested', 'approved', null, '18400000-0000-0000-0000-000000000012'::uuid, '100.0000'),
             ('refund_completed', 'warning', 'approved', 'completed', null, '18400000-0000-0000-0000-000000000012'::uuid, '100.0000')$$,
    'RFD-3: the table door records the request, the approval and the completion once each, under the caller');
select results_eq(
    $$select event_type_code, severity_code, previous_state, new_state, reason
      from public.events where entity_id = (select v from r where k = 'rf_rpc') order by seq$$,
    $$values ('refund_requested', 'info', null::text, 'requested', 'customer_cancelled'),
             ('refund_approved', 'info', 'requested', 'approved', 'ok'),
             ('refund_completed', 'warning', 'approved', 'completed', 'paid out')$$,
    'RFD-3: the RPC door records the same three acts once each, with its reasons');
select is((select count(*)::int from public.refunds
           where tenant_id = '18400000-0000-0000-0000-000000000001' and completed_at is not null), 2,
          'RFD-3: completed_at is server-stamped on both doors');

-- ===== CHAT-2: the employee at the table door (c1) and the RPC door (c2).
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18400000-0000-0000-0000-0000000000a3"}', true);
select lives_ok($$update public.conversations set conversation_status_code = 'assigned' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                'CHAT-2: the table door assigns');
select lives_ok($$update public.conversations set conversation_status_code = 'closed', closed_at = '2001-01-01' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                'CHAT-2: the table door closes, offering a forged closed_at');
select ok((select closed_at > now() - interval '1 minute' from public.conversations where id = '18400000-0000-0000-0000-0000000000c1'),
          'CHAT-2: closing stamps closed_at from the server, not the forged value');
update public.conversations set closed_at = '2001-01-01' where id = '18400000-0000-0000-0000-0000000000c1';
select ok((select closed_at > now() - interval '1 minute' from public.conversations where id = '18400000-0000-0000-0000-0000000000c1'),
          'CHAT-2: a later update cannot rewrite closed_at');
select throws_ok($$update public.conversations set conversation_status_code = 'open' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                 '23514', 'a closed conversation is reopened with a reason (canon 26, 27); use app.advance_conversation with p_reason',
                 'CHAT-2: the table door cannot reopen without a reason');
select lives_ok($$select set_config('app.transition_reason', 'customer replied', true);
                  update public.conversations set conversation_status_code = 'open' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                'CHAT-2: a reopen carrying a reason is accepted');
select is((select closed_at from public.conversations where id = '18400000-0000-0000-0000-0000000000c1'), null,
          'CHAT-2: reopening clears closed_at');
select lives_ok($$update public.conversations set conversation_status_code = 'assigned' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                'CHAT-2: the table door reassigns after the reopen');
select throws_ok($$update public.conversations set conversation_status_code = 'escalated' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                 '42501', 'permission denied: ESCALATE_CONVERSATION',
                 'CHAT-2: the employee still cannot escalate at the table');
select lives_ok($$select app.advance_conversation('18400000-0000-0000-0000-0000000000c2', 'assigned', 'picked');
                  select app.advance_conversation('18400000-0000-0000-0000-0000000000c2', 'closed', 'done')$$,
                'CHAT-2: the RPC door assigns and closes');
select throws_ok($$select app.advance_conversation('18400000-0000-0000-0000-0000000000c2', 'open', null)$$,
                 '23514', 'a closed conversation is reopened with a reason (canon 26, 27); use app.advance_conversation with p_reason',
                 'CHAT-2: the RPC door cannot reopen without a reason either');
select lives_ok($$select app.advance_conversation('18400000-0000-0000-0000-0000000000c2', 'open', 'customer replied')$$,
                'CHAT-2: the RPC door reopens with a reason');
select set_config('request.jwt.claims', '{"sub":"18400000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select lives_ok($$update public.conversations set conversation_status_code = 'escalated' where id = '18400000-0000-0000-0000-0000000000c1'$$,
                'CHAT-2: the owner escalates at the table');
reset role;

select results_eq(
    $$select event_type_code, severity_code, previous_state, new_state, reason, actor_user_id
      from public.events where entity_id = '18400000-0000-0000-0000-0000000000c1' and event_type_code <> 'conversation_started' order by seq$$,
    $$values ('conversation_assigned', 'info', 'open', 'assigned', null::text, '18400000-0000-0000-0000-000000000013'::uuid),
             ('conversation_closed', 'info', 'assigned', 'closed', null, '18400000-0000-0000-0000-000000000013'::uuid),
             ('conversation_reopened', 'warning', 'closed', 'open', 'customer replied', '18400000-0000-0000-0000-000000000013'::uuid),
             ('conversation_assigned', 'info', 'open', 'assigned', null, '18400000-0000-0000-0000-000000000013'::uuid),
             ('conversation_escalated', 'warning', 'assigned', 'escalated', null, '18400000-0000-0000-0000-000000000011'::uuid)$$,
    'CHAT-2: every table-door move is recorded once, reopen and escalation as warnings, the reason consumed by its own move');
select results_eq(
    $$select event_type_code, severity_code, reason
      from public.events where entity_id = '18400000-0000-0000-0000-0000000000c2' and event_type_code <> 'conversation_started' order by seq$$,
    $$values ('conversation_assigned', 'info', 'picked'), ('conversation_closed', 'info', 'done'),
             ('conversation_reopened', 'warning', 'customer replied')$$,
    'CHAT-2: the RPC door records the same moves once each, with its reasons');

-- ===== PAY-5 / FIN-11: the owner at aal2.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18400000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
insert into r values ('pay_rpc', app.record_payment('18400000-0000-0000-0000-0000000000e1', 5000, 'cash', now(), 'R-184'));
select lives_ok($$insert into public.payments (id, tenant_id, payment_direction_code, customer_id, currency_code, payment_method_code, amount, paid_at) values
                    ('18400000-0000-0000-0000-000000000133', '18400000-0000-0000-0000-000000000001', 'customer_payment', '18400000-0000-0000-0000-0000000000d1', 'EGP', 'bank_transfer', 1000, now());
                  insert into public.payment_allocations (id, tenant_id, payment_id, invoice_id, allocated_amount, currency_code) values
                    ('18400000-0000-0000-0000-000000000233', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-000000000133', '18400000-0000-0000-0000-0000000000e4', 0, 'EGP')$$,
                'PAY-5: a zero allocation is written at the table door');
select is((select status_code from public.invoices where id = '18400000-0000-0000-0000-0000000000e4'), 'issued',
          'PAY-5: a zero allocation settles nothing, so the invoice stays issued');
select lives_ok($$insert into public.payments (id, tenant_id, payment_direction_code, customer_id, currency_code, payment_method_code, amount, paid_at) values
                    ('18400000-0000-0000-0000-000000000102', '18400000-0000-0000-0000-000000000001', 'customer_payment', '18400000-0000-0000-0000-0000000000d1', 'EGP', 'bank_transfer', 5000, now()),
                    ('18400000-0000-0000-0000-000000000131', '18400000-0000-0000-0000-000000000001', 'customer_payment', '18400000-0000-0000-0000-0000000000d1', 'EGP', 'bank_transfer', 2000, now()),
                    ('18400000-0000-0000-0000-000000000132', '18400000-0000-0000-0000-000000000001', 'customer_payment', '18400000-0000-0000-0000-0000000000d1', 'EGP', 'bank_transfer', 3000, now()),
                    ('18400000-0000-0000-0000-000000000104', '18400000-0000-0000-0000-000000000001', 'customer_payment', '18400000-0000-0000-0000-0000000000d1', 'EGP', 'bank_transfer', 5000, now());
                  insert into public.payment_allocations (id, tenant_id, payment_id, invoice_id, allocated_amount, currency_code) values
                    ('18400000-0000-0000-0000-000000000202', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-000000000102', '18400000-0000-0000-0000-0000000000e2', 5000, 'EGP'),
                    ('18400000-0000-0000-0000-000000000231', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-000000000131', '18400000-0000-0000-0000-0000000000e3', 2000, 'EGP');
                  insert into public.payment_allocations (id, tenant_id, payment_id, invoice_id, allocated_amount, currency_code) values
                    ('18400000-0000-0000-0000-000000000232', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-000000000132', '18400000-0000-0000-0000-0000000000e3', 3000, 'EGP'),
                    ('18400000-0000-0000-0000-000000000204', '18400000-0000-0000-0000-000000000001', '18400000-0000-0000-0000-000000000104', '18400000-0000-0000-0000-0000000000e4', 3000, 'EGP')$$,
                'PAY-5: payments and allocations are written at the table door');
select is((select status_code from public.invoices where id = '18400000-0000-0000-0000-0000000000e4'), 'partially_paid',
          'PAY-5: a partial door allocation settles the invoice partially_paid');
select lives_ok($$update public.payment_allocations set allocated_amount = 1000 where id = '18400000-0000-0000-0000-000000000204'$$,
                'PAY-5: a door allocation is lowered');
select is((select status_code from public.invoices where id = '18400000-0000-0000-0000-0000000000e4'), 'partially_paid',
          'PAY-5: a lowered allocation never walks the settlement back');
select lives_ok($$update public.payment_allocations set allocated_amount = 5000 where id = '18400000-0000-0000-0000-000000000204'$$,
                'PAY-5: the door allocation is raised to the full total');
set constraints payments_emit_recorded immediate;
reset role;

select results_eq(
    $$select invoice_number, status_code from public.invoices where tenant_id = '18400000-0000-0000-0000-000000000001' order by 1$$,
    $$values ('INV-184-1', 'paid'), ('INV-184-2', 'paid'), ('INV-184-3', 'paid'), ('INV-184-4', 'paid')$$,
    'PAY-5: every invoice covered by its allocations is paid, on either door');
select results_eq(
    $$select i.invoice_number, e.event_type_code, e.previous_state, e.new_state, e.actor_user_id, (e.payload->>'allocated_total')::numeric
      from public.events e join public.invoices i on i.id = e.entity_id
      where i.tenant_id = '18400000-0000-0000-0000-000000000001' order by i.invoice_number, e.seq$$,
    $$values ('INV-184-1', 'invoice_paid', 'issued', 'paid', '18400000-0000-0000-0000-000000000011'::uuid, 5000::numeric),
             ('INV-184-2', 'invoice_paid', 'issued', 'paid', '18400000-0000-0000-0000-000000000011'::uuid, 5000),
             ('INV-184-3', 'invoice_partially_paid', 'issued', 'partially_paid', '18400000-0000-0000-0000-000000000011'::uuid, 2000),
             ('INV-184-3', 'invoice_paid', 'partially_paid', 'paid', '18400000-0000-0000-0000-000000000011'::uuid, 5000),
             ('INV-184-4', 'invoice_partially_paid', 'issued', 'partially_paid', '18400000-0000-0000-0000-000000000011'::uuid, 3000),
             ('INV-184-4', 'invoice_paid', 'partially_paid', 'paid', '18400000-0000-0000-0000-000000000011'::uuid, 5000)$$,
    'PAY-5: each settlement is recorded once on either door, and a lowering records none');
select is((select payload->>'payment_id' from public.events
           where entity_id = '18400000-0000-0000-0000-0000000000e2' and event_type_code = 'invoice_paid'),
          '18400000-0000-0000-0000-000000000102', 'PAY-5: the settlement names the payment that caused it');
select ok((select max(seq) filter (where event_type_code = 'payment_allocation_created')
                < max(seq) filter (where event_type_code = 'invoice_paid')
           from public.events where entity_id in ('18400000-0000-0000-0000-000000000202', '18400000-0000-0000-0000-0000000000e2')),
          'PAY-5: the allocation is recorded before the settlement it causes');
select results_eq(
    $$select entity_id, payload->>'invoice_new_status' from public.events
      where event_type_code = 'payment_recorded' and entity_id in ((select v from r where k = 'pay_rpc'), '18400000-0000-0000-0000-000000000102')
      order by payload->>'invoice_id'$$,
    $$values ((select v from r where k = 'pay_rpc'), 'paid'), ('18400000-0000-0000-0000-000000000102'::uuid, 'paid')$$,
    'PAY-5: payment_recorded reports the settled invoice status on both doors');

-- ===== Shape: invoker producers on the tables, and no RPC emits what its table now produces.
select is((select count(*)::int from pg_proc where pronamespace = 'app'::regnamespace and not prosecdef
           and proname in ('emit_refund_requested', 'emit_refund_transition', 'guard_conversation_transition',
                           'emit_conversation_transition', 'derive_invoice_payment_status')), 5,
          'the guard and the four producers are SECURITY INVOKER');
select results_eq(
    $$select tgname::text collate "default", (tgtype & 2) = 2 from pg_trigger
      where tgname in ('refunds_emit_requested', 'refunds_emit_transition', 'conversations_guard_transition',
                       'conversations_emit_transition', 'payment_allocations_settle_invoice') order by 1$$,
    $$values ('conversations_emit_transition', false), ('conversations_guard_transition', true),
             ('payment_allocations_settle_invoice', false), ('refunds_emit_requested', false), ('refunds_emit_transition', false)$$,
    'the conversation guard fires BEFORE, the four producers AFTER');
select is((select count(*)::int from pg_proc where pronamespace = 'app'::regnamespace
           and proname in ('record_refund', 'advance_refund', 'advance_conversation', 'record_payment')
           and pg_get_functiondef(oid) ~ 'record_event'), 0,
          'no restated RPC records the events its table now produces');

select * from finish();
rollback;
