-- pgTAP: Batch 6 slice 31 -- `customer_identity_merges` is written only by the merge.
--
-- ATTACK-CLASSES: DOOR BUSINESS STATE REPLAY INPUT PRIVILEGE AUTH TENANT OBSERVABILITY CONCURRENCY=N/A
--   CONCURRENCY=N/A -- pgTAP runs one session. The merge locks both identities in id order and a
--     consent decision locks its identity, so the record checks below are read under those locks;
--     the two-session proofs (A->B with B->A and with A->C, and a merge against a decision on either
--     identity, both orders) are recorded in the Change Request.
--
-- The merge record decides which identities are one logical customer: `app.customer_consent_status`
-- follows it and `app.record_customer_consent` refuses an identity it names as merged.
--   MRG-1: a MERGE_CUSTOMER_IDENTITY holder wrote and rewrote it at the table door, so a customer
--          whose own decision was DENIED read another's GRANTED and its call went to Google.
--   MRG-2: the merge refused a second merge of an identity by its archive flag, which the customers
--          door can reverse, so one identity could be merged twice, or two merged into each other.
--
-- THE FIXTURE. One tenant: its owner holds MERGE_CUSTOMER_IDENTITY at aal2, its `employee` handler
-- qualifies a Google Ads call lead of A and records consent. A has DENIED and B has GRANTED. C, with
-- a note, is merged into D through the merge; E is unrelated. A second tenant's owner attacks across
-- the boundary.
create extension if not exists pgtap with schema extensions;

begin;
select plan(23);

insert into auth.users (id,email,email_confirmed_at) values
  ('14400000-0000-0000-0000-0000000000a1','own@m144.test',now()),
  ('14400000-0000-0000-0000-0000000000a2','emp@m144.test',now()),
  ('14400000-0000-0000-0000-0000000000a4','own@m144b.test',now());
insert into public.tenants (id,name,slug,status) values
  ('14400000-0000-0000-0000-000000000001','M144 Travel','m144-travel','active'),
  ('14400000-0000-0000-0000-000000000002','M144 Other','m144-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['14400000-0000-0000-0000-000000000001'::uuid,'14400000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('14400000-0000-0000-0000-00000000000a','14400000-0000-0000-0000-000000000001','Cairo','m144-cairo');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('14400000-0000-0000-0000-0000000000c1','14400000-0000-0000-0000-000000000001','14400000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('14400000-0000-0000-0000-000000000011','14400000-0000-0000-0000-000000000001','Owner','own@m144.test',true,'14400000-0000-0000-0000-0000000000a1'),
  ('14400000-0000-0000-0000-000000000012','14400000-0000-0000-0000-000000000001','Handler','emp@m144.test',true,'14400000-0000-0000-0000-0000000000a2'),
  ('14400000-0000-0000-0000-000000000021','14400000-0000-0000-0000-000000000002','Other owner','own@m144b.test',true,'14400000-0000-0000-0000-0000000000a4');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary)
select '14400000-0000-0000-0000-000000000001', u, '14400000-0000-0000-0000-00000000000a','14400000-0000-0000-0000-0000000000c1', true
from unnest(array['14400000-0000-0000-0000-000000000011'::uuid,'14400000-0000-0000-0000-000000000012'::uuid]) u;
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('14400000-0000-0000-0000-000000000001'::uuid,'14400000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('14400000-0000-0000-0000-000000000001','14400000-0000-0000-0000-000000000012','employee'),
             ('14400000-0000-0000-0000-000000000002','14400000-0000-0000-0000-000000000021','owner')) v(t,u,rc)
join public.roles r on r.code = v.rc;

-- d1 A, d2 B, d3 C, d4 D, d5 E.
insert into public.customers (id,tenant_id,customer_type_code,full_name,primary_phone)
select ('14400000-0000-0000-0000-0000000000d'||n)::uuid, '14400000-0000-0000-0000-000000000001', 'person', 'C'||n,
       '+2010000144'||(10 + n)
from generate_series(1,5) n;
insert into public.customer_notes (tenant_id,customer_id,note_text)
values ('14400000-0000-0000-0000-000000000001','14400000-0000-0000-0000-0000000000d3','history on C');
insert into public.leads (id,tenant_id,branch_id,department_id,customer_id,lead_source_code,title,lead_status_code)
values ('14400000-0000-0000-0000-0000000000e1','14400000-0000-0000-0000-000000000001','14400000-0000-0000-0000-00000000000a',
        '14400000-0000-0000-0000-0000000000c1','14400000-0000-0000-0000-0000000000d1','google_ads_call','L1','new');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select app.assign_lead('14400000-0000-0000-0000-0000000000e1', '14400000-0000-0000-0000-000000000012', 'fixture');
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select app.record_lead_interaction('14400000-0000-0000-0000-0000000000e1', 'phone_call');
select app.advance_lead('14400000-0000-0000-0000-0000000000e1', 'qualified', 'qualified');
select app.record_customer_consent('14400000-0000-0000-0000-0000000000d1', 'ad_user_data', 'denied', 'phone', 'do not share');
select app.record_customer_consent('14400000-0000-0000-0000-0000000000d2', 'ad_user_data', 'granted', 'phone', null);
select app.record_customer_consent('14400000-0000-0000-0000-0000000000d3', 'ad_user_data', 'denied', 'phone', null);
reset role;
select set_config('request.jwt.claims','',true);
select app.map_outcomes_to_conversions(100000);

create function pg_temp.st(p_n int) returns text language sql as $$
  select coalesce(app.customer_consent_status('14400000-0000-0000-0000-000000000001',
                  ('14400000-0000-0000-0000-0000000000d'||p_n)::uuid, 'ad_user_data'), 'null')
$$;
create function pg_temp.claimed() returns text language sql as $$
  select coalesce(string_agg(c.conversion_event_type_code || ':' || coalesce(c.customer_phone, '-'), ','), '')
    from app.claim_conversion_deliveries('google_ads', 500) c
   where c.tenant_id = '14400000-0000-0000-0000-000000000001'
$$;

-- =============================================================================================
-- 1-7. MRG-1, CREATION: a merge record exists only where a merge happened.
-- =============================================================================================
select ok(has_table_privilege('authenticated','public.customer_identity_merges','SELECT')
          and not has_table_privilege('authenticated','public.customer_identity_merges','INSERT')
          and not has_table_privilege('authenticated','public.customer_identity_merges','UPDATE')
          and not has_table_privilege('authenticated','public.customer_identity_merges','DELETE'),
  'DOOR: a signed-in user may read the merge record and holds no table door into it -- the merge is its one writer');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select ok(app.has_permission('MERGE_CUSTOMER_IDENTITY'),
  'PREMISE: the owner holds MERGE_CUSTOMER_IDENTITY at aal2, so a refusal below is the missing door, not a missing permission');

select throws_ok(
  $$insert into public.customer_identity_merges (tenant_id,source_customer_id,target_customer_id,reason)
    values ('14400000-0000-0000-0000-000000000001','14400000-0000-0000-0000-0000000000d1','14400000-0000-0000-0000-0000000000d2','forged')$$,
  '42501', 'permission denied for table customer_identity_merges',
  'MRG-1: the owner cannot record A as merged into B without merging them');
reset role;
select set_config('request.jwt.claims','',true);

select is(pg_temp.st(1) || ',' || pg_temp.st(2) || ',' ||
          (select count(*)::text from public.customer_identity_merges where tenant_id = '14400000-0000-0000-0000-000000000001'),
  'denied,granted,0',
  'BUSINESS: A''s own DENIED still governs A, and B''s GRANTED stays B''s -- no record joins them');

select is(pg_temp.claimed(), '',
  'BUSINESS: A''s qualified call does not go to Google on B''s consent');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select lives_ok($$select app.record_customer_consent('14400000-0000-0000-0000-0000000000d1', 'ad_user_data', 'denied', 'phone', 'withdrew again')$$,
  'STATE: A, never merged, still records a withdrawal');
select app.record_customer_consent('14400000-0000-0000-0000-0000000000d1', 'ad_user_data', 'granted', 'phone', 'agreed later');
reset role;
select set_config('request.jwt.claims','',true);
select is(pg_temp.claimed(), 'qualified_phone_call:+201000014411',
  'POSITIVE CONTROL: once A itself grants, the same call is claimed -- the claim above was empty for A''s decision, not for want of a path');

-- =============================================================================================
-- 8-17. MRG-1, REWRITE: the record of a merge that happened stays the record of that merge, and the
-- merge itself is unchanged.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($$select app.merge_customer_identity('14400000-0000-0000-0000-0000000000d3','14400000-0000-0000-0000-0000000000d4','genuine')$$,
  'POSITIVE CONTROL: the owner merges C into D through the merge');
reset role;
select set_config('request.jwt.claims','',true);

select is(
  (select c.is_archived::text from public.customers c where c.id = '14400000-0000-0000-0000-0000000000d3')
  || '/' || (select count(*)::text from public.customer_notes where customer_id = '14400000-0000-0000-0000-0000000000d4')
  || '/' || (select string_agg(m.target_customer_id::text || ':' || m.merged_by::text || ':' || m.reason || ':' || (m.created_at = now())::text, ',')
               from public.customer_identity_merges m where m.source_customer_id = '14400000-0000-0000-0000-0000000000d3')
  || '/' || (select string_agg(e.severity_code || ':' || (e.payload ->> 'source_customer_id'), ',')
               from public.events e
              where e.tenant_id = '14400000-0000-0000-0000-000000000001' and e.event_type_code = 'customer_identity_merged'),
  'true/1/14400000-0000-0000-0000-0000000000d4:14400000-0000-0000-0000-000000000011:genuine:true/critical:14400000-0000-0000-0000-0000000000d3',
  'the merge is complete: the source is archived, its history is on the survivor, one record attributed to the owner at the server''s time, one critical event');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok(
  $$update public.customer_identity_merges
       set source_customer_id = '14400000-0000-0000-0000-0000000000d1', target_customer_id = '14400000-0000-0000-0000-0000000000d2',
           reason = 'rewritten', created_at = '2001-01-01'
     where source_customer_id = '14400000-0000-0000-0000-0000000000d3'$$,
  '42501', 'permission denied for table customer_identity_merges',
  'MRG-1: the owner cannot move a recorded merge onto other identities, re-reason it or backdate it');
reset role;
select set_config('request.jwt.claims','',true);

select is(
  (select string_agg(m.source_customer_id::text || '>' || m.target_customer_id::text || ':' || m.reason || ':' || (m.created_at = now())::text, ',')
     from public.customer_identity_merges m where m.tenant_id = '14400000-0000-0000-0000-000000000001')
  || '/' || pg_temp.st(1) || ',' || pg_temp.st(3) || ',' || pg_temp.st(4),
  '14400000-0000-0000-0000-0000000000d3>14400000-0000-0000-0000-0000000000d4:genuine:true/granted,denied,denied',
  'BUSINESS: the record still says C merged into D, D answers to C''s DENIED, and A answers to its own decision');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select throws_ok($$select app.merge_customer_identity('14400000-0000-0000-0000-0000000000d1','14400000-0000-0000-0000-0000000000d2','employee')$$,
  '42501', 'permission denied: MERGE_CUSTOMER_IDENTITY',
  'PRIVILEGE: a user without MERGE_CUSTOMER_IDENTITY cannot merge');
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
select throws_ok($$select app.merge_customer_identity('14400000-0000-0000-0000-0000000000d1','14400000-0000-0000-0000-0000000000d2','aal1')$$,
  null, 'multi-factor authentication required for this role',
  'AUTH: the owner without step-up cannot merge');
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a4","aal":"aal2"}',true);
select is((select count(*)::int from public.customer_identity_merges), 0,
  'TENANT: another tenant''s owner reads none of this tenant''s merge records');
select throws_ok($$select public.merge_customer_identity('14400000-0000-0000-0000-0000000000d1','14400000-0000-0000-0000-0000000000d2','cross')$$,
  'P0001', 'source customer is not in your tenant',
  'TENANT: another tenant''s owner cannot merge this tenant''s customers, through the HTTP endpoint either');
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok($$select app.merge_customer_identity('14400000-0000-0000-0000-0000000000d3','14400000-0000-0000-0000-0000000000d4','again')$$,
  'P0001', 'source customer is already archived (merged?)',
  'REPLAY: merging an archived source again is refused by its archive, before the record is consulted');
select throws_ok($$select app.merge_customer_identity('14400000-0000-0000-0000-0000000000d4','14400000-0000-0000-0000-0000000000d4','self')$$,
  'P0001', 'source and target customer must differ',
  'INPUT: an identity cannot be merged into itself');
reset role;
select set_config('request.jwt.claims','',true);

-- =============================================================================================
-- 18-23. MRG-2: the record, not the archive flag, says an identity was merged away. The owner
-- holds ARCHIVE_RECORD, so the customers door lets it un-archive C; C stays merged.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($$update public.customers set is_archived = false, archive_reason = null
                   where id = '14400000-0000-0000-0000-0000000000d3'$$,
  'PREMISE: the owner un-archives the merged C at the customers door');
select throws_ok($$select app.merge_customer_identity('14400000-0000-0000-0000-0000000000d3','14400000-0000-0000-0000-0000000000d5','fork')$$,
  'P0001', 'source customer was already merged into 14400000-0000-0000-0000-0000000000d4',
  'MRG-2: the un-archived C is not merged a second time, into E');
select throws_ok($$select app.merge_customer_identity('14400000-0000-0000-0000-0000000000d4','14400000-0000-0000-0000-0000000000d3','cycle')$$,
  'P0001', 'target customer was merged into 14400000-0000-0000-0000-0000000000d4',
  'MRG-2: the survivor D is not merged back into C, which would leave neither a survivor');
reset role;
select set_config('request.jwt.claims','',true);

select is(
  (select count(*)::text from public.customer_identity_merges where tenant_id = '14400000-0000-0000-0000-000000000001')
  || '/' || (select count(*)::text from public.events
              where tenant_id = '14400000-0000-0000-0000-000000000001' and event_type_code = 'customer_identity_merged')
  || '/' || (select count(*)::text from public.customers where id = '14400000-0000-0000-0000-0000000000d4' and not is_archived),
  '1/1/1',
  'OBSERVABILITY: one merge, one record, one event, and D still survives');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14400000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select lives_ok($$select app.record_customer_consent('14400000-0000-0000-0000-0000000000d4', 'ad_user_data', 'granted', 'phone', 'agreed')$$,
  'STATE: the logical customer still takes a decision, on its survivor');
select throws_ok($$select app.record_customer_consent('14400000-0000-0000-0000-0000000000d3', 'ad_user_data', 'denied', 'phone', null)$$,
  'P0001', 'customer was merged into 14400000-0000-0000-0000-0000000000d4 -- record consent for the surviving customer',
  'STATE: the un-archived C still takes none -- the merge and the consent writer read the same record');
reset role;
select set_config('request.jwt.claims','',true);

select * from finish();
rollback;
