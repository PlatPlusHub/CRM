-- pgTAP: PARENT-1 (`202607059400`) -- a rule about the parent's state is a rule on every door.
--
-- Four RPCs refuse a write because of the state of the row's PARENT, and until this migration none
-- of those four rules existed on the table door that `authenticated` reaches through PostgREST.
-- All four were reproduced live before any code was written, each with the RPC as the positive
-- control and a caller who genuinely holds the capability, so every refusal here is the state rule
-- and never a missing permission.
--
-- The last assertion is the CLASS, and it is the durable output of this file: it re-derives the
-- population from `app.status_transitions` + `pg_proc` + `pg_trigger` -- no hand-written table list,
-- no exemption list -- and pins the pairs that legitimately have no table-door guard. A new RPC that
-- refuses on a parent's state without a matching trigger appears there and fails this test.
--
-- That detector was ATTACKED before it was trusted, in both directions (AGENTS.md §6):
--   * REMOVE a guard -> the `guarded` set is computed live, so the pair returns to the unguarded
--     list and the string no longer matches. Assertion 22 proves the same thing behaviourally.
--   * ADD an unguarded pair -> a probe function that reads `conversations.conversation_status_code`
--     and inserts into `public.complaints` was created inside a rolled-back transaction: the count
--     went 5 -> 6 and the detector named the probe. It is not pinning a constant.
--   * Its two structural assumptions were MEASURED, not assumed: all 0 `app` functions lack a pinned
--     `search_path` (so `public.` qualification is mandatory, not a style), 0 build an INSERT with
--     dynamic SQL, and 0 write an unqualified `insert into`. Those three counts are what make a
--     source-text predicate sound here rather than merely convenient.
create extension if not exists pgtap with schema extensions;

begin;
select plan(25);

insert into auth.users (id, email) values
  ('88000000-0000-0000-0000-0000000000a1','mgr@f88.example');
insert into public.tenants (id, name, slug, status) values
  ('88000000-0000-0000-0000-000000000001','F88 Travel','f88-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '88000000-0000-0000-0000-000000000001', sp.id,'active'
from public.subscription_plans sp where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('88000000-0000-0000-0000-00000000000a','88000000-0000-0000-0000-000000000001','Main','f88-main');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('88000000-0000-0000-0000-0000000000c1','88000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('88000000-0000-0000-0000-000000000011','88000000-0000-0000-0000-000000000001','Manager','mgr@f88.example',true,'88000000-0000-0000-0000-0000000000a1');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '88000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-000000000011', r.id,'tenant'
from public.roles r where r.code='branch_manager';
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
values ('88000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-000000000011',
        '88000000-0000-0000-0000-00000000000a','88000000-0000-0000-0000-0000000000c1', true);
insert into public.customers (id, tenant_id, customer_type_code, full_name, first_registered_branch_id)
values ('88000000-0000-0000-0000-0000000000cc','88000000-0000-0000-0000-000000000001','person',
        'F88 Customer','88000000-0000-0000-0000-00000000000a');
insert into public.quotations (id, tenant_id, customer_id, quotation_status_code, quotation_number,
                               currency_code, owner_user_id, owner_branch_id, owner_department_id)
values ('88000000-0000-0000-0000-0000000000f1','88000000-0000-0000-0000-000000000001',
        '88000000-0000-0000-0000-0000000000cc','draft','F88-0001','EGP',
        '88000000-0000-0000-0000-000000000011','88000000-0000-0000-0000-00000000000a','88000000-0000-0000-0000-0000000000c1');

select set_config('request.jwt.claims','{"sub":"88000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;

-- 1
select ok(
  app.has_permission('CREATE_BOOKING') and app.has_permission('CREATE_BOOKING_ITEM')
  and app.has_permission('CREATE_DOCUMENT_VERSION') and app.has_permission('UPLOAD_DOCUMENT')
  and app.has_permission('SEND_MESSAGE') and app.has_permission('CLOSE_CONVERSATION')
  and app.has_permission('SEND_QUOTATION') and app.has_permission('ACCEPT_QUOTATION'),
  'POSITIVE CONTROL: the caller genuinely holds every capability exercised below, so each refusal that follows is the parent-state rule and not a permission');

-- ================================================================================================
-- bookings <- quotations: app.create_booking, "only an accepted quotation can produce a booking".
-- ================================================================================================
-- 2
select throws_ok(
  $$select app.create_booking(
      p_customer_id   => '88000000-0000-0000-0000-0000000000cc',
      p_title         => 'Trip from a quotation nobody accepted',
      p_branch_id     => '88000000-0000-0000-0000-00000000000a',
      p_department_id => '88000000-0000-0000-0000-0000000000c1',
      p_quotation_id  => '88000000-0000-0000-0000-0000000000f1')$$,
  'P0001', 'only an accepted quotation can produce a booking (status: draft)',
  'POSITIVE CONTROL: the RPC refuses a booking anchored to a DRAFT quotation -- this is the authority the table door had to match');

-- 3
select throws_ok(
  $$insert into public.bookings (tenant_id, branch_id, department_id, customer_id, quotation_id,
        booking_status_code, title, booking_reference, owner_user_id, owner_branch_id, owner_department_id)
    values ('88000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-00000000000a','88000000-0000-0000-0000-0000000000c1',
            '88000000-0000-0000-0000-0000000000cc','88000000-0000-0000-0000-0000000000f1','draft',
            'Trip from a quotation nobody accepted','F88-BK-X','88000000-0000-0000-0000-000000000011',
            '88000000-0000-0000-0000-00000000000a','88000000-0000-0000-0000-0000000000c1')$$,
  '23514', 'only an accepted quotation can produce a booking (status: draft)',
  'PARENT-1: the TABLE now refuses it too, with the RPC''s own words -- before 202607059400 this returned INSERT 0 1 and the booking cited an offer the customer never accepted');

-- A quotation needs at least one line before it can be sent -- app.advance_quotation says so, and
-- that refusal is a fixture requirement here, not the rule under test.
select app.add_quotation_item('88000000-0000-0000-0000-0000000000f1','hotel',1000,1);

-- 4, 5
select lives_ok($$select app.advance_quotation('88000000-0000-0000-0000-0000000000f1','sent','send it')$$,
  'the quotation is sent through the machine');
select lives_ok($$select app.advance_quotation('88000000-0000-0000-0000-0000000000f1','accepted','customer accepted')$$,
  'and the customer accepts it');

-- 6
select lives_ok(
  $$insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, quotation_id,
        booking_status_code, title, booking_reference, owner_user_id, owner_branch_id, owner_department_id)
    values ('88000000-0000-0000-0000-0000000000b1','88000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-00000000000a','88000000-0000-0000-0000-0000000000c1',
            '88000000-0000-0000-0000-0000000000cc','88000000-0000-0000-0000-0000000000f1','draft',
            'F88 Trip','F88-BK-1','88000000-0000-0000-0000-000000000011',
            '88000000-0000-0000-0000-00000000000a','88000000-0000-0000-0000-0000000000c1')$$,
  'NEGATIVE CONTROL: the identical direct INSERT succeeds once the quotation is ACCEPTED -- the guard tests the parent''s state, it does not close the door');

-- 7
select lives_ok(
  $$insert into public.bookings (tenant_id, branch_id, department_id, customer_id,
        booking_status_code, title, booking_reference, owner_user_id, owner_branch_id, owner_department_id)
    values ('88000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-00000000000a','88000000-0000-0000-0000-0000000000c1',
            '88000000-0000-0000-0000-0000000000cc','draft','F88 Walk-in','F88-BK-2',
            '88000000-0000-0000-0000-000000000011','88000000-0000-0000-0000-00000000000a','88000000-0000-0000-0000-0000000000c1')$$,
  'NEGATIVE CONTROL: a walk-in booking with NO quotation is unaffected -- the rule is conditional on the reference existing, exactly as app.create_booking''s own `if p_quotation_id is not null` is');

-- ================================================================================================
-- approval_requests <- booking_items: app.request_finance_approval.
-- ================================================================================================
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
                                  currency_code, owner_user_id, owner_branch_id, owner_department_id,
                                  sales_owner_user_id, sales_owner_branch_id, sales_owner_department_id)
values ('88000000-0000-0000-0000-0000000000e1','88000000-0000-0000-0000-000000000001','88000000-0000-0000-0000-0000000000b1',
        'hotel','draft','EGP','88000000-0000-0000-0000-000000000011','88000000-0000-0000-0000-00000000000a','88000000-0000-0000-0000-0000000000c1',
        '88000000-0000-0000-0000-000000000011','88000000-0000-0000-0000-00000000000a','88000000-0000-0000-0000-0000000000c1');

-- 8
select is(
  (select base_status_code from public.booking_items
    where id = '88000000-0000-0000-0000-0000000000e1'
      and tenant_id = '88000000-0000-0000-0000-000000000001')::text,
  'draft',
  'POSITIVE CONTROL: the booking item exists and is LIVE, so the refusal below is about its later state and not about a missing row');

-- 9
select lives_ok(
  $$insert into public.approval_requests (tenant_id, approval_type_code, approval_status_code,
        related_entity_type, related_entity_id, booking_item_id, reason)
    values ('88000000-0000-0000-0000-000000000001','finance_execution_approval','pending','booking_item',
            '88000000-0000-0000-0000-0000000000e1','88000000-0000-0000-0000-0000000000e1','a live item')$$,
  'NEGATIVE CONTROL: a direct approval request against a LIVE booking item still works');

-- 10
select lives_ok(
  $$select app.advance_booking_item('88000000-0000-0000-0000-0000000000e1','cancelled','customer cancelled', null, 'customer_cancelled')$$,
  'the item is cancelled through the machine');

-- 11
select throws_ok(
  $$select app.request_finance_approval('88000000-0000-0000-0000-0000000000e1','cost above ceiling')$$,
  'P0001', 'cannot request finance approval on a cancelled/no_show/archived booking item',
  'POSITIVE CONTROL: the RPC refuses a finance approval on a CANCELLED item');

-- 12
select throws_ok(
  $$insert into public.approval_requests (tenant_id, approval_type_code, approval_status_code,
        related_entity_type, related_entity_id, booking_item_id, reason)
    values ('88000000-0000-0000-0000-000000000001','finance_execution_approval','pending','booking_item',
            '88000000-0000-0000-0000-0000000000e1','88000000-0000-0000-0000-0000000000e1','forged request')$$,
  '23514', 'cannot request finance approval on a cancelled/no_show/archived booking item',
  'PARENT-1: and so does the TABLE -- before 202607059400 a pending finance approval could be opened against an item that no longer exists commercially');

-- ================================================================================================
-- document_versions <- documents: app.add_document_version, "cannot add a version to an archived document".
-- ================================================================================================
select app.upload_document(
  p_document_type_code => 'other', p_title => 'F88 Voucher',
  p_file_name => 'v1.pdf', p_file_type_code => 'pdf',
  p_link_target_type => 'booking', p_link_target_id => '88000000-0000-0000-0000-0000000000b1',
  p_file_size => 1000);

-- 13
select lives_ok(
  $$insert into public.document_versions (tenant_id, document_id, version_number, file_name, file_type_code, file_size, storage_path, is_current)
    select '88000000-0000-0000-0000-000000000001', d.id, 0, 'v2.pdf','pdf',2000,'derived-anyway', false
    from public.documents d
    where d.title = 'F88 Voucher' and d.tenant_id = '88000000-0000-0000-0000-000000000001'$$,
  'NEGATIVE CONTROL: a direct version INSERT works while the document is ACTIVE (version_number and storage_path are derived by DOC-1''s trigger, not taken from the caller)');

-- 14
select lives_ok(
  $$select app.archive_document(
      (select d.id from public.documents d
        where d.title = 'F88 Voucher' and d.tenant_id = '88000000-0000-0000-0000-000000000001'),
      'superseded')$$,
  'the document is archived through its own RPC');

-- 15
select throws_ok(
  $$select app.add_document_version(
      (select d.id from public.documents d
        where d.title = 'F88 Voucher' and d.tenant_id = '88000000-0000-0000-0000-000000000001'),
      'v3.pdf','pdf',3000)$$,
  'P0001', 'cannot add a version to an archived document',
  'POSITIVE CONTROL: the RPC refuses a version on an ARCHIVED document');

-- 16
select throws_ok(
  $$insert into public.document_versions (tenant_id, document_id, version_number, file_name, file_type_code, file_size, storage_path, is_current)
    select '88000000-0000-0000-0000-000000000001', d.id, 0, 'v3.pdf','pdf',3000,'derived-anyway', false
    from public.documents d
    where d.title = 'F88 Voucher' and d.tenant_id = '88000000-0000-0000-0000-000000000001'$$,
  '23514', 'cannot add a version to an archived document',
  'PARENT-1: and so does the TABLE -- an archived document is out of use, and a new version of it is a change to a record that was closed');

-- ================================================================================================
-- conversation_messages <- conversations: app.send_conversation_message.
-- ================================================================================================
select app.start_conversation('whatsapp','88000000-0000-0000-0000-0000000000cc');

-- 17
select lives_ok(
  $$insert into public.conversation_messages (tenant_id, conversation_id, sender_type_code, message_direction_code, message_text, sent_at)
    select '88000000-0000-0000-0000-000000000001', c.id, 'user','outbound','while open', now()
    from public.conversations c
    where c.tenant_id = '88000000-0000-0000-0000-000000000001'
      and c.customer_id = '88000000-0000-0000-0000-0000000000cc'$$,
  'NEGATIVE CONTROL: a direct message INSERT works while the conversation is OPEN');

-- 18, 19
select lives_ok(
  $$select app.advance_conversation(
      (select c.id from public.conversations c
        where c.tenant_id = '88000000-0000-0000-0000-000000000001'
          and c.customer_id = '88000000-0000-0000-0000-0000000000cc'),'assigned','picked up')$$,
  'the conversation is picked up');
select lives_ok(
  $$select app.advance_conversation(
      (select c.id from public.conversations c
        where c.tenant_id = '88000000-0000-0000-0000-000000000001'
          and c.customer_id = '88000000-0000-0000-0000-0000000000cc'),'closed','done')$$,
  'and closed through the machine');

-- 20
select throws_ok(
  $$select app.send_conversation_message(
      (select c.id from public.conversations c
        where c.tenant_id = '88000000-0000-0000-0000-000000000001'
          and c.customer_id = '88000000-0000-0000-0000-0000000000cc'),'outbound','user','after closure')$$,
  'P0001', 'conversation is closed; reopen it before sending a message',
  'POSITIVE CONTROL: the RPC refuses a message on a CLOSED conversation');

-- 21
select throws_ok(
  $$insert into public.conversation_messages (tenant_id, conversation_id, sender_type_code, message_direction_code, message_text, sent_at)
    select '88000000-0000-0000-0000-000000000001', c.id, 'user','outbound','AFTER CLOSURE', now()
    from public.conversations c
    where c.tenant_id = '88000000-0000-0000-0000-000000000001'
      and c.customer_id = '88000000-0000-0000-0000-0000000000cc'$$,
  '23514', 'conversation is closed; reopen it before sending a message',
  'PARENT-1: and so does the TABLE -- before 202607059400 a message landed on a finished engagement and the parent''s updated_at did not even move');

-- ================================================================================================
-- Mutation (PAR-4), placed third-from-last so its count survives the rollback (TEST-3).
-- ================================================================================================
-- `authenticated` does not own the table, so the defect injection needs the session role back. The
-- JWT claims stay set, so `guard_write_capability` still charges SEND_MESSAGE exactly as before --
-- only the ownership needed for DROP TRIGGER changes.
reset role;
savepoint m1;
drop trigger conversation_messages_guard_parent_state on public.conversation_messages;
-- 22
select lives_ok(
  $$insert into public.conversation_messages (tenant_id, conversation_id, sender_type_code, message_direction_code, message_text, sent_at)
    select '88000000-0000-0000-0000-000000000001', c.id, 'user','outbound','MUTATION', now()
    from public.conversations c
    where c.tenant_id = '88000000-0000-0000-0000-000000000001'
      and c.customer_id = '88000000-0000-0000-0000-0000000000cc'$$,
  'MUTATION: with the trigger dropped the message lands on the closed conversation again -- proving that trigger, and not RLS or a permission, is the enforcer');
rollback to savepoint m1;

-- 23
select throws_ok(
  $$insert into public.conversation_messages (tenant_id, conversation_id, sender_type_code, message_direction_code, message_text, sent_at)
    select '88000000-0000-0000-0000-000000000001', c.id, 'user','outbound','AFTER ROLLBACK', now()
    from public.conversations c
    where c.tenant_id = '88000000-0000-0000-0000-000000000001'
      and c.customer_id = '88000000-0000-0000-0000-0000000000cc'$$,
  '23514', 'conversation is closed; reopen it before sending a message',
  '...and once the mutation is rolled back the guard is BACK: the identical insert is refused again');

select app.advance_conversation(
  (select c.id from public.conversations c
    where c.tenant_id = '88000000-0000-0000-0000-000000000001'
      and c.customer_id = '88000000-0000-0000-0000-0000000000cc'),'open','reopened');

-- 24
select lives_ok(
  $$insert into public.conversation_messages (tenant_id, conversation_id, sender_type_code, message_direction_code, message_text, sent_at)
    select '88000000-0000-0000-0000-000000000001', c.id, 'user','outbound','after reopening', now()
    from public.conversations c
    where c.tenant_id = '88000000-0000-0000-0000-000000000001'
      and c.customer_id = '88000000-0000-0000-0000-0000000000cc'$$,
  'NEGATIVE CONTROL: reopen the conversation through the machine and the same message is accepted -- the rule is about the parent''s state, not a permanent freeze');

-- ================================================================================================
-- THE CLASS. Derived from the catalog every time it runs: for each app function that reads a
-- parent's registered status column and INSERTs into a different table, is there a BEFORE INSERT
-- trigger on that table reading the same column? The five below are verified NOT to be defects --
-- each was read, not assumed:
--   process_lead_sla -> notifications          system path; `authenticated` holds no INSERT on
--                                              notifications at all (SEC-1 residue revoked it)
--   record_lead_interaction -> lead_interactions  reads lead_status_code ONLY to decide the
--                                              assigned -> contacted transition; refuses nothing
--   upload_document / upload_subscription_payment_proof -> document_links, subscription_payment_proofs
--                                              these CREATE the document in the same transaction,
--                                              so there is no prior parent state to refuse on
-- A sixth entry means a new RPC enforces a parent-state rule the table door does not.
-- ================================================================================================
reset role;
-- 25
select is(
  (with parents as (select distinct table_name, status_column from app.status_transitions),
   fns as (select p.proname, p.prosrc from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'app' and p.prokind = 'f' and p.prorettype <> 'trigger'::regtype),
   reads as (select f.proname, pa.table_name as parent, pa.status_column
             from fns f join parents pa
               on f.prosrc ~ ('public\.' || pa.table_name || '\M')
              and f.prosrc ~ ('\m' || pa.status_column || '\M')),
   writes as (select f.proname, m[1] as child
              from fns f, regexp_matches(f.prosrc, 'insert\s+into\s+public\.(\w+)', 'g') m),
   pairs as (select distinct r.proname, r.parent, w.child
             from reads r join writes w on w.proname = r.proname where w.child <> r.parent),
   guarded as (select distinct c.relname as child, pa.table_name as parent
               from pg_trigger t
               join pg_class c on c.oid = t.tgrelid
               join pg_namespace n on n.oid = c.relnamespace
               join pg_proc p on p.oid = t.tgfoid, parents pa
               where not t.tgisinternal and n.nspname = 'public'
                 and (t.tgtype::int & 2) = 2 and (t.tgtype::int & 4) = 4
                 and p.prosrc ~ ('public\.' || pa.table_name || '\M')
                 and p.prosrc ~ ('\m' || pa.status_column || '\M'))
   select coalesce(string_agg(distinct pr.proname || ' -> ' || pr.child || ' (' || pr.parent || ')', ', '
                     order by pr.proname || ' -> ' || pr.child || ' (' || pr.parent || ')'), '')
   from pairs pr left join guarded g on g.child = pr.child and g.parent = pr.parent
   where g.child is null)::text,
  'process_lead_sla -> notifications (leads), record_lead_interaction -> lead_interactions (leads), upload_document -> document_links (documents), upload_subscription_payment_proof -> document_links (documents), upload_subscription_payment_proof -> subscription_payment_proofs (documents)',
  'CLASS GUARD (PARENT-1): the only app functions that read a registered parent status and write another table WITHOUT a matching table-door guard are the five verified non-defects. Fails in BOTH directions -- a new unguarded pair fails it, and so does removing one of the four guards this migration added.');

select * from finish();
rollback;
