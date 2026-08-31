-- pgTAP: SEC-1b / ATTR-4 / CONV-2 / COMP-1 -- the complaints and conversations audit.
--
-- SEC-1b is the one that matters most, because it is a guard failure rather than a code failure.
-- `10_grant_model_test`'s ceiling asked "does this table have a trigger whose body mentions
-- app.authorize?" and never asked WHEN the trigger fires. `enforce_status_transition` and
-- `enforce_archive_authority` both mention it and are BEFORE UPDATE ONLY, so thirteen tables were
-- credited with INSERT-path protection they did not have, and SEC-1 was recorded as closed with
-- twelve business tables still open. A `trainee` -- two permissions in the whole system, neither of
-- them a write -- was proven to insert a complaint and a conversation by direct DML in the same
-- transaction where the RPC refused them.
--
-- §1-6 therefore assert the SAME ACTOR against BOTH DOORS on the SAME table: the RPC refuses, the
-- table refuses, and an employee who legitimately holds the permission is permitted on both. A
-- denial without that third assertion would not distinguish "the guard works" from "nothing works".
create extension if not exists pgtap with schema extensions;

begin;
select plan(25);

insert into auth.users (id, email) values
  ('67000000-0000-0000-0000-0000000000a1','emp@care-pgtap.test'),
  ('67000000-0000-0000-0000-0000000000a2','trainee@care-pgtap.test'),
  ('67000000-0000-0000-0000-0000000000a3','col@care-pgtap.test');
insert into public.tenants (id, name, slug, status) values
  ('67000000-0000-0000-0000-000000000001','Care Travel','care-pgtap','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '67000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('67000000-0000-0000-0000-00000000000a','67000000-0000-0000-0000-000000000001','Cairo','care-pgtap-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('67000000-0000-0000-0000-0000000000c1','67000000-0000-0000-0000-000000000001','67000000-0000-0000-0000-00000000000a','sales','Care Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('67000000-0000-0000-0000-000000000011','67000000-0000-0000-0000-000000000001','Employee','emp@care-pgtap.test',true,'67000000-0000-0000-0000-0000000000a1'),
  ('67000000-0000-0000-0000-000000000012','67000000-0000-0000-0000-000000000001','Trainee','trainee@care-pgtap.test',true,'67000000-0000-0000-0000-0000000000a2'),
  ('67000000-0000-0000-0000-000000000013','67000000-0000-0000-0000-000000000001','Colleague','col@care-pgtap.test',true,'67000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '67000000-0000-0000-0000-000000000001', u,
       '67000000-0000-0000-0000-00000000000a','67000000-0000-0000-0000-0000000000c1', true
from unnest(array['67000000-0000-0000-0000-000000000011'::uuid,'67000000-0000-0000-0000-000000000012'::uuid,
                  '67000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '67000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('67000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('67000000-0000-0000-0000-000000000012'::uuid,'trainee'),
             ('67000000-0000-0000-0000-000000000013'::uuid,'employee')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('67000000-0000-0000-0000-0000000000d1','67000000-0000-0000-0000-000000000001','person','Care Customer','+201000000670');

-- =============================================================================================
-- 1-6. SEC-1b. The trainee at BOTH doors, then the employee at both, on the same tables.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-0000-0000-0000000000a2"}', true);

select ok(
  not app.has_permission('CREATE_COMPLAINT') and not app.has_permission('SEND_MESSAGE'),
  'the trainee holds neither CREATE_COMPLAINT nor SEND_MESSAGE -- the premise of every refusal below');

select throws_ok(
  $$select app.create_complaint('67000000-0000-0000-0000-0000000000d1','Trainee via RPC','service_quality')$$,
  '42501',
  null,
  'the RPC refuses the trainee -- the intended door, already correct before this migration');

select throws_ok(
  $$insert into public.complaints (tenant_id, customer_id, owner_user_id, owner_branch_id,
        owner_department_id, complaint_category_code, complaint_severity_code,
        complaint_status_code, title)
    values ('67000000-0000-0000-0000-000000000001','67000000-0000-0000-0000-0000000000d1',
            '67000000-0000-0000-0000-000000000012','67000000-0000-0000-0000-00000000000a',
            '67000000-0000-0000-0000-0000000000c1','service_quality','normal','new','Trainee via DML')$$,
  '42501',
  null,
  'SEC-1b: ...and so does DIRECT DML, which accepted this row until 202607057000');

select throws_ok(
  $$insert into public.conversations (tenant_id, customer_id, owner_user_id, owner_branch_id,
        owner_department_id, current_branch_id, current_department_id, channel_code,
        conversation_status_code, started_at)
    values ('67000000-0000-0000-0000-000000000001','67000000-0000-0000-0000-0000000000d1',
            '67000000-0000-0000-0000-000000000012','67000000-0000-0000-0000-00000000000a',
            '67000000-0000-0000-0000-0000000000c1','67000000-0000-0000-0000-00000000000a',
            '67000000-0000-0000-0000-0000000000c1','whatsapp','open', now())$$,
  '42501',
  null,
  '...and the same on conversations -- the trainee named THEMSELVES as owner, which the policy allowed');

-- The positive control that makes the three refusals mean something.
select set_config('request.jwt.claims','{"sub":"67000000-0000-0000-0000-0000000000a1"}', true);

select lives_ok(
  $$select app.create_complaint('67000000-0000-0000-0000-0000000000d1','Employee via RPC','service_quality')$$,
  'POSITIVE CONTROL: the EMPLOYEE, who holds CREATE_COMPLAINT, is permitted through the RPC');

select lives_ok(
  $$insert into public.complaints (tenant_id, customer_id, owner_user_id, owner_branch_id,
        owner_department_id, complaint_category_code, complaint_severity_code,
        complaint_status_code, title)
    values ('67000000-0000-0000-0000-000000000001','67000000-0000-0000-0000-0000000000d1',
            '67000000-0000-0000-0000-000000000011','67000000-0000-0000-0000-00000000000a',
            '67000000-0000-0000-0000-0000000000c1','service_quality','normal','new','Employee via DML')$$,
  '...and through DIRECT DML too -- the guard charges capability, it does not close the door');

-- =============================================================================================
-- 7-9. SEC-1b, the CLASS rather than the two tables this package is named for.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select count(*)::int
     from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relkind = 'r'
      and has_table_privilege('authenticated', c.oid, 'INSERT')
      and not exists (
        select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
         where t.tgrelid = c.oid and not t.tgisinternal and (t.tgtype & 4) <> 0
           and pg_get_functiondef(p.oid) ~
               '(app\.authorize|app\.has_permission|app\.require_lead_handler)')
      and not exists (
        select 1 from pg_policies pp
         where pp.schemaname = 'public' and pp.tablename = c.relname
           and pp.cmd in ('INSERT','ALL')
           and coalesce(pp.with_check,'') ~ 'has_permission\(''(?!VIEW_|SEE_)[A-Z_]+''')),
  3,
  'SEC-1b: measured on the INSERT PATH, exactly 3 tables have no capability enforcement -- was 15');

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and t.tgname like '%\_guard\_write\_capability'
      and c.relname = any (array['bookings','complaints','conversations','customer_notes','customers',
                                 'documents','leads','passengers','quotations','service_requests',
                                 'suppliers','tasks'])
      and (t.tgtype & 4) <> 0),
  12,
  '...and all twelve newly guarded tables carry the guard ON INSERT');

-- SUPERSEDED BY SEC-1c (202607059100). This demanded ZERO on UPDATE, and its stated reason was
-- correct: charging CREATE_BOOKING to ISSUE a booking would break finance, because finance_manager
-- holds ISSUE/CANCEL/REFUND/REISSUE_BOOKING and NOT CREATE_BOOKING. SEC-1b avoided that by
-- attaching on INSERT only -- and thereby left UPDATE with no capability check on all twelve, which
-- SEC-1c reproduced: a trainee holding none of CREATE_CUSTOMER / CREATE_PASSENGER / ASSIGN_SUPPLIER,
-- with the rows proven visible and its own INSERT refused in the same session, rewrote a customer
-- name, a passenger name, and a supplier's credit limit 1000 -> 999999.
-- The fix removes the PREMISE rather than the guard: on UPDATE the charged set is the object-class
-- permission UNION that table's `app.status_transitions.permission_key` values, so finance issues a
-- booking with ISSUE_BOOKING exactly as canon 28 grants it. Both halves are pinned below.
select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and t.tgname like '%\_guard\_write\_capability'
      and c.relname = any (array['bookings','complaints','conversations','customer_notes','customers',
                                 'documents','leads','passengers','quotations','service_requests',
                                 'suppliers','tasks'])
      and (t.tgtype & 16) <> 0),
  12,
  'SEC-1c: all twelve now carry the guard ON UPDATE as well -- the INSERT-only shape was the defect');

-- The guard against the guard. Attaching the UPDATE trigger while leaving a CREATE-only mapping
-- would satisfy the assertion above and silently strip finance of the ability to issue a booking.
-- `app.status_transitions` is the canonical record of which permission may move each object, so
-- assert the guard accepts every one of them: this fails the moment the two drift apart.
select is(
  (select count(*)::int
     from (select distinct st.permission_key
             from app.status_transitions st
            where st.table_name = any (array['bookings','complaints','conversations','documents',
                                             'leads','quotations','service_requests','tasks'])
              and st.permission_key is not null) k
     where not exists (
       select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'app' and p.proname = 'guard_write_capability'
          and p.prosrc like '%' || k.permission_key || '%')),
  0,
  '...and every transition permission canon records for those tables is accepted by the guard -- no role loses a mutation it is granted');

-- =============================================================================================
-- 10-14. ATTR-4 and CONV-2, on a real conversation started through the real RPC.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"67000000-0000-0000-0000-0000000000a1"}', true);

create temp table care_ids as
select app.start_conversation('whatsapp','67000000-0000-0000-0000-0000000000d1') as conv;
insert into public.conversation_messages (tenant_id, conversation_id, sender_type_code,
    message_direction_code, message_text, sender_user_id, sent_at)
select '67000000-0000-0000-0000-000000000001', c.conv, 'user','outbound','Forged by direct DML',
       '67000000-0000-0000-0000-000000000013', now()
from care_ids c;

select is(
  (select m.sender_user_id from public.conversation_messages m
    where m.message_text = 'Forged by direct DML'),
  '67000000-0000-0000-0000-000000000011'::uuid,
  'ATTR-4: a message naming a COLLEAGUE as sender is recorded against the ACTUAL sender instead');

select is(
  (select count(*)::int from public.conversation_messages m
    where m.message_text = 'Forged by direct DML'
      and m.sender_user_id = '67000000-0000-0000-0000-000000000013'),
  0,
  '...asserted on the ROW, because "no exception raised" would pass even if the forgery had stuck');

select throws_ok(
  $$update public.conversation_messages set message_text = 'rewritten'
     where message_text = 'Forged by direct DML'$$,
  '42501',
  null,
  'CONV-2: the text of a sent message cannot be rewritten -- it is what the agency told the customer');

select throws_ok(
  $$delete from public.conversation_messages where message_text = 'Forged by direct DML'$$,
  '42501',
  null,
  '...nor deleted, on the same reasoning the audit spine and assignment history already use');

select lives_ok(
  $$update public.conversation_messages
       set external_message_id = 'wamid.TEST', metadata = '{"provider":"whatsapp"}'::jsonb
     where message_text = 'Forged by direct DML'$$,
  'NEGATIVE CONTROL: external_message_id and metadata STILL change -- a blanket freeze would have broken the delivery integration');

-- =============================================================================================
-- 15-18. The conversation lifecycle's authority split, which is the part canon actually separates.
-- =============================================================================================
select lives_ok(
  $$select app.advance_conversation((select conv from care_ids), 'assigned', 'picked up')$$,
  'the employee takes the conversation: open -> assigned');

select throws_ok(
  $$select app.advance_conversation((select conv from care_ids), 'escalated', 'needs a manager')$$,
  '42501',
  null,
  'an EMPLOYEE cannot escalate -- ESCALATE_CONVERSATION is held by managers, ceo and owner only');

select lives_ok(
  $$select app.advance_conversation((select conv from care_ids), 'closed', 'resolved on the call')$$,
  '...but CAN close it, because CLOSE_CONVERSATION is a front-line permission -- the two are separate');

select throws_ok(
  $$select app.send_conversation_message((select conv from care_ids),'outbound','user','after close')$$,
  null,
  'conversation is closed; reopen it before sending a message',
  'a closed conversation refuses new messages, by message rather than by silence');

-- =============================================================================================
-- 19-21. COMP-1: a complaint could reach `resolved` with no record of how.
-- =============================================================================================
create temp table care_comp as
select id from public.complaints
where tenant_id = '67000000-0000-0000-0000-000000000001' and title = 'Employee via RPC';

select throws_ok(
  $$select app.advance_complaint((select id from care_comp), 'resolved', 'straight to resolved')$$,
  null,
  'invalid complaint transition new -> resolved',
  'a complaint cannot jump from new straight to resolved -- the state machine is real');

select lives_ok(
  $$select app.advance_complaint((select id from care_comp), 'acknowledged')$$,
  'new -> acknowledged');

select lives_ok(
  $$select app.advance_complaint((select id from care_comp), 'in_progress')$$,
  'acknowledged -> in_progress');

select lives_ok(
  $$select app.advance_complaint((select id from care_comp), 'resolved',
                                 'Refunded the baggage fee and apologised in writing')$$,
  'in_progress -> resolved');

select is(
  (select resolution_notes from public.complaints where id = (select id from care_comp)),
  'Refunded the baggage fee and apologised in writing',
  'COMP-1: the reason given for RESOLVING is persisted as the resolution note -- the column was written by nothing');

select is(
  (select resolution_notes from public.complaints
    where tenant_id = '67000000-0000-0000-0000-000000000001' and title = 'Employee via DML'),
  null,
  'NEGATIVE CONTROL: a complaint that was never resolved has no resolution note -- the write is scoped to that one transition');

select finish();
rollback;
