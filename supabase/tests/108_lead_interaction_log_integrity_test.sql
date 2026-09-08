-- pgTAP: Batch 6 slice 8 -- lead_interactions, the contact log that could be moved and rewritten.
--
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT BUSINESS PRIVILEGE OBSERVABILITY REPLAY CONCURRENCY=N/A
--
-- CONCURRENCY=N/A  the table carries no counter, lease, claim or single-use token, and its only
--                  unique constraint is the primary key on a generated uuid. There is no
--                  read-modify-write path for two legitimate actors to combine badly: after
--                  `202607061800` the only write is an INSERT of a fresh row.
--
-- WHAT THIS FILE PINS, and why each assertion exists rather than being decoration:
--
-- 1     is the ACTOR PROOF, and it is assertion 1 rather than a comment because slice 7's first
--       battery silently ran as the table owner and reported every boundary broken.
--
-- 2-6   are the half of the door that was ALREADY CORRECT, asserted rather than assumed. The
--       inherited note (`202607056100` §3) said the RPC "authorizes nothing", so direct DML could
--       not bypass it. That stopped being true when `guard_lead_interaction_authority` was added:
--       both paths now charge assigned-handler-or-ASSIGN_LEAD plus MFA. 2 and 5 prove the two doors
--       agree by refusing the SAME actor on both; 3 is the positive control that keeps 2 honest;
--       4 is the catalog vocabulary; 6 is the anti-forgery derivation. None of them is credited to
--       this slice's repair -- they are here so a future change cannot quietly remove them.
--
-- 7-8   are LI-1 and LI-2, the two REPRODUCED exploits, and they are the reason for the revoke.
--       Both ran at `aal1` as an `employee` holding no ASSIGN_LEAD, with the actor proven first.
--
-- 9-10  are the anti-over-revoke controls, and they are why the repair is `revoke update` and NOT
--       `revoke insert, update`. `app.record_lead_interaction` is SECURITY INVOKER: the INSERT
--       grant IS the sanctioned path, exactly as with `trusted_devices` one slice ago and unlike
--       `otp_challenges` two slices ago. 10 goes further than "it did not throw" and reads the
--       derived state back, because a returned uuid is not evidence the lead moved.
--
-- 11-12 WERE a VERIFIED NON-DEFECT pinned on an INCIDENTAL defence, and the pin fired. Slice 9
--       (`202607061900`, LEAD-1) proved the defence was incidental twice over -- the coherence
--       constraint, and behind it `require_assignment_history` -- and replaced both with an
--       intentional control. The pair now discriminates by MECHANISM: 11 is the seize, refused by
--       `guard_write_capability`; 12 is the transition, refused by `enforce_status_transition`.
--       Both 42501. See the block above assertion 11.
--
-- 13    is the grant posture by MEMBERSHIP, not by count.
--
-- 14    pins LI-3 as a MEASURED FACT rather than a claim: the door enforces the RPC's AUTHORITY and
--       none of its STATE. A qualifying interaction inserted directly leaves the lead reading as
--       never contacted. It is deliberately written to FAIL when LI-3 is repaired -- the tripwire
--       that forces the register row to be closed in the same change.
--
-- 15    is the GROUND TRUTH read as the owner after `reset role`, because an RLS-refused UPDATE can
--       degrade into a silent zero-row no-op that an error-shaped assertion would never notice.
create extension if not exists pgtap with schema extensions;

begin;
select plan(15);

insert into auth.users (id, email) values
  ('08000000-0000-0000-0000-0000000000a1','handlerA@li.test'),
  ('08000000-0000-0000-0000-0000000000a2','handlerB@li.test'),
  ('08000000-0000-0000-0000-0000000000a3','manager@li.test');
insert into public.tenants (id, name, slug, status) values
  ('08000000-0000-0000-0000-000000000001','LI Travel','li-travel','active'),
  ('08000000-0000-0000-0000-000000000002','LI Rival','li-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active'
from unnest(array['08000000-0000-0000-0000-000000000001'::uuid,'08000000-0000-0000-0000-000000000002'::uuid]) t
cross join public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('08000000-0000-0000-0000-00000000000a','08000000-0000-0000-0000-000000000001','Cairo','li-cairo'),
  ('08000000-0000-0000-0000-00000000000b','08000000-0000-0000-0000-000000000002','Rival','li-rival-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('08000000-0000-0000-0000-0000000000c1','08000000-0000-0000-0000-000000000001','08000000-0000-0000-0000-00000000000a','sales','Sales'),
  ('08000000-0000-0000-0000-0000000000c2','08000000-0000-0000-0000-000000000002','08000000-0000-0000-0000-00000000000b','sales','Rival Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('08000000-0000-0000-0000-000000000011','08000000-0000-0000-0000-000000000001','Handler A','handlerA@li.test',true,'08000000-0000-0000-0000-0000000000a1'),
  ('08000000-0000-0000-0000-000000000012','08000000-0000-0000-0000-000000000001','Handler B','handlerB@li.test',true,'08000000-0000-0000-0000-0000000000a2'),
  ('08000000-0000-0000-0000-000000000013','08000000-0000-0000-0000-000000000001','Manager','manager@li.test',true,'08000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '08000000-0000-0000-0000-000000000001', u,'08000000-0000-0000-0000-00000000000a','08000000-0000-0000-0000-0000000000c1',true
from unnest(array['08000000-0000-0000-0000-000000000011'::uuid,'08000000-0000-0000-0000-000000000012'::uuid,'08000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '08000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('08000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('08000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('08000000-0000-0000-0000-000000000013'::uuid,'branch_manager')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('08000000-0000-0000-0000-0000000000d1','08000000-0000-0000-0000-000000000001','person','LI Customer','+201000000008'),
  ('08000000-0000-0000-0000-0000000000d2','08000000-0000-0000-0000-000000000002','person','Rival Customer','+201000000010');
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code, title, lead_status_code) values
  ('08000000-0000-0000-0000-0000000000e1','08000000-0000-0000-0000-000000000001','08000000-0000-0000-0000-00000000000a','08000000-0000-0000-0000-0000000000c1','08000000-0000-0000-0000-0000000000d1','direct_call','Lead A','new'),
  ('08000000-0000-0000-0000-0000000000e2','08000000-0000-0000-0000-000000000001','08000000-0000-0000-0000-00000000000a','08000000-0000-0000-0000-0000000000c1','08000000-0000-0000-0000-0000000000d1','direct_call','Lead B','new'),
  ('08000000-0000-0000-0000-0000000000e3','08000000-0000-0000-0000-000000000002','08000000-0000-0000-0000-00000000000b','08000000-0000-0000-0000-0000000000c2','08000000-0000-0000-0000-0000000000d2','direct_call','Rival Lead','new');

-- Assigned through the sanctioned RPC: SPEC-148's coherence trigger refuses a direct
-- `assigned_user_id` write, which is correct and which the first draft of this fixture tripped over.
select set_config('request.jwt.claims','{"sub":"08000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;
select app.assign_lead('08000000-0000-0000-0000-0000000000e1','08000000-0000-0000-0000-000000000011','slice8 fixture');
select app.assign_lead('08000000-0000-0000-0000-0000000000e2','08000000-0000-0000-0000-000000000012','slice8 fixture');
reset role;

-- Handler B logs a genuine interaction on B's OWN lead through the sanctioned path. This row is the
-- object of LI-1: it belongs to B, and assertion 6 proves A can no longer take it.
select set_config('request.jwt.claims','{"sub":"08000000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
set local role authenticated;
select app.record_lead_interaction('08000000-0000-0000-0000-0000000000e2','note','B private note', null);
reset role;

-- ================================================================================================
-- Everything below runs as HANDLER A: an `employee`, at aal1, holding no ASSIGN_LEAD.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"08000000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
set local role authenticated;

select ok(
  current_user = 'authenticated'
  and app.current_user_id() = '08000000-0000-0000-0000-000000000011'
  and not app.has_permission('ASSIGN_LEAD'),
  'ACTOR PROOF, and it is assertion 1 on purpose: slice 7''s first battery silently ran as the table OWNER because `set local role` outside a transaction is a no-op, and every boundary looked broken. current_user, the resolved ORVION identity and the ABSENCE of ASSIGN_LEAD are all established before a single attack runs -- without the third, every refusal below could be a permission the actor simply held');

select throws_ok(
  $$insert into public.lead_interactions (tenant_id, lead_id, interaction_type_code, summary)
    values ('08000000-0000-0000-0000-000000000001','08000000-0000-0000-0000-0000000000e2','note','A on B lead')$$,
  '42501', null,
  'AUTH: the direct table door refuses an interaction on a COLLEAGUE''s lead -- guard_lead_interaction_authority charges what the RPC charges, which is the half of the inherited question that turned out already answered');

select lives_ok(
  $$insert into public.lead_interactions (tenant_id, lead_id, interaction_type_code, summary)
    values ('08000000-0000-0000-0000-000000000001','08000000-0000-0000-0000-0000000000e1','note','A own note')$$,
  'POSITIVE CONTROL: the assigned handler still writes their own lead by direct DML -- without this, assertion 2 would pass just as well if the table were unreachable to everyone');

select throws_ok(
  $$insert into public.lead_interactions (tenant_id, lead_id, interaction_type_code, summary)
    values ('08000000-0000-0000-0000-000000000001','08000000-0000-0000-0000-0000000000e1','TELEPATHY','bad code')$$,
  '23514', null,
  'INPUT: an invented interaction_type_code is refused by enforce_catalog_codes -- the `lead_interaction_type` family is enforced here, unlike `trusted_device_status` which TD-1 found seeded and enforced by nothing');

select throws_ok(
  $$select app.record_lead_interaction('08000000-0000-0000-0000-0000000000e2','note','via RPC')$$,
  '42501', null,
  'DOOR: the SAME actor is refused by the RPC on the SAME lead. Asserting both doors against one actor is what makes "the door enforces what the RPC charges" a measurement rather than a reading of two code paths');

select is(
  (select user_id from public.lead_interactions where summary = 'A own note'),
  '08000000-0000-0000-0000-000000000011'::uuid,
  'PRIVILEGE: authorship is DERIVED, not accepted -- and this is re-asserted rather than assumed, so the revoke below cannot be credited for a control app.derive_interaction_actor already provided');

select throws_ok(
  $$update public.lead_interactions set lead_id = '08000000-0000-0000-0000-0000000000e1'
     where lead_id = '08000000-0000-0000-0000-0000000000e2'$$,
  '42501', null,
  'LI-1 CLOSED (BUSINESS/STATE): re-parenting a colleague''s interaction onto my own lead. REPRODUCED before 202607061800 -- RLS permitted the row because its USING clause tests the tenant and the parent''s existence, never who handles it, and then guard_lead_interaction_authority asked who handles the lead the row was moving TO and never asked about the one it was moving FROM. BOOK-5''s shape on a second table: `set lead_id = <my lead>` supplies the answer to "is this lead mine?"');

select throws_ok(
  $$update public.lead_interactions set interaction_at = '2001-01-01', summary = 'rewritten after the fact'
     where summary = 'A own note'$$,
  '42501', null,
  'LI-2 CLOSED (REPLAY/OBSERVABILITY): backdating and rewriting my own contact log after the fact. REPRODUCED before the repair. A contact log that can be edited is not evidence of contact');

select lives_ok(
  $$select app.record_lead_interaction('08000000-0000-0000-0000-0000000000e1','phone_call','rpc call')$$,
  'ANTI-OVER-REVOKE: the sanctioned RPC still works after the revoke. app.record_lead_interaction is SECURITY INVOKER, so the INSERT grant IS its path -- this is why the repair is `revoke update` and not the `revoke insert, update` that closed OTP-1');

select is(
  (select lead_status_code from public.leads where id = '08000000-0000-0000-0000-0000000000e1'),
  'contacted',
  '...and the RPC still maintains the lead END TO END -- a returned uuid is not evidence that the qualifying interaction advanced the lead, so the derived state is read back');

-- 2026-09-08, slice 9 (LEAD-1): THIS PIN FIRED, WHICH IS THE ONLY REASON IT EXISTED. It used to
-- assert 23514 and name `leads_owner_matches_assignee_chk`, because that constraint was what refused
-- the seize. Slice 9 re-ran the same attack with the PAIR of columns the constraint actually couples
-- (`owner_user_id` as well as `assigned_user_id`), found the constraint satisfied and the refusal
-- coming from `app.require_assignment_history` -- an INTEGRITY control, equally incidental -- and
-- replaced both with an intentional one in `202607061900`: moving a lead's assignment costs
-- ASSIGN_LEAD or REASSIGN_LEAD, and the handler shortcut is decided from OLD. So the code is now
-- 42501 and the pair below discriminates by MECHANISM rather than by errcode: the seize is refused by
-- `guard_write_capability`, the transition by `enforce_status_transition`. That the guard stands
-- alone -- with the constraint and the history trigger both removed -- is proven by mutation in
-- `109_lead_authority_and_lifecycle_test.sql` 15-18, not here.
select throws_ok(
  $$update public.leads set assigned_user_id = '08000000-0000-0000-0000-000000000011',
        owner_user_id = '08000000-0000-0000-0000-000000000011'
      where id = '08000000-0000-0000-0000-0000000000e2'$$,
  '42501', null,
  'LEAD-1 (was a VERIFIED NON-DEFECT here, now CLOSED): seizing a colleague''s lead is refused by the AUTHORIZATION model -- app.guard_write_capability charges ASSIGN_LEAD or REASSIGN_LEAD for moving an assignment, instead of letting the attacker''s own NEW image answer "are you the handler?"');

select throws_ok(
  $$update public.leads set lead_status_code = 'contacted' where id = '08000000-0000-0000-0000-0000000000e2'$$,
  '42501', null,
  '...and the DISCRIMINATING PAIR: the transition without the seize is refused by a DIFFERENT guard -- app.enforce_status_transition''s handler fallback, which now resolves the handler from OLD (LEAD-1b). Without this, assertion 11 would pass equally well if leads transitions were simply unreachable');

select is(
  (select string_agg(privilege_type, ',' order by privilege_type)
     from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'lead_interactions' and grantee = 'authenticated'),
  'INSERT,SELECT',
  'the grant posture NAMED rather than counted: INSERT is kept because a SECURITY INVOKER RPC needs it, SELECT because reading a lead''s history is not authority over it, and UPDATE is gone because NO function in this database updates this table -- the same rule 75_... assertion 25 makes executable for the canon-34 family');

select is(
  (select count(*)::int from public.events
    where entity_type = 'lead' and entity_id = '08000000-0000-0000-0000-0000000000e1'
      and event_type_code = 'lead_contacted'),
  1,
  'LI-3, PINNED AS A MEASURED FACT AND DELIBERATELY LEFT OPEN: exactly ONE lead_contacted event exists on this lead, and the RPC emitted it. The direct-DML `note` inserts above emitted nothing, and a direct-DML QUALIFYING interaction emits nothing either -- the door enforces the RPC''s AUTHORITY and none of its STATE. This assertion FAILS if LI-3 is ever repaired, which is intentional: it forces the register row to be closed in the same change rather than drifting');

reset role;

select is(
  (select lead_id from public.lead_interactions where summary = 'B private note'),
  '08000000-0000-0000-0000-0000000000e2'::uuid,
  'GROUND TRUTH read as the owner after reset role: B''s interaction is still on B''s lead. An RLS-refused UPDATE can degrade into a silent zero-row no-op, so LI-1 is confirmed against the table itself rather than against the error the attacker happened to see');

select * from finish();
rollback;
