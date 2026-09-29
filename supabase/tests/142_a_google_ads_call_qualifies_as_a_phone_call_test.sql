-- pgTAP: PH8-4 -- a qualified Google Ads call is the `qualified_phone_call` conversion, and it reaches
-- delivery only with a recorded consent and something Google can match on.
--
-- ATTACK-CLASSES: BUSINESS REPLAY STATE INPUT PRIVILEGE TENANT DOOR OBSERVABILITY AUTH=N/A CONCURRENCY=N/A
--   AUTH=N/A -- step-up is `app.authorize`'s and unchanged; the refusal below is the permission.
--   CONCURRENCY=N/A -- pgTAP runs one session. The writer holds the customer row lock to commit and
--     `seq` is allocated under it; the two-session proof is recorded in SPEC-240, and assertion 37
--     pins deterministically that the order is `seq`, never a timestamp.
--
-- THE FIXTURE. One tenant; its owner assigns, and an `employee` handler contacts and qualifies every
-- lead through `app.advance_lead` and records consent. A second tenant's owner attacks across the
-- boundary, and a tenant user holding no role attacks the permission.
--   e1 google_ads_form, consented click, local phone -> qualified_lead, claimed WITHOUT a phone
--   e2 google_ads_call, consented click, consent     -> qualified_phone_call, claimed WITH its gclid
--   e3 google_ads_call, no click, denied then granted -> qualified_phone_call, claimed
--   e4 google_ads_call, no click, consent, local phone only -> formed, not claimed (nothing to match)
--   e5 google_ads_call, no click, granted then denied -> formed, not claimed
--   e6 google_ads_call, no click, no consent record   -> formed, not claimed
--   e7 google_ads_form, click consent DENIED, customer consent granted -> not claimed (click path)
--   e8 google_ads_call, click consent DENIED, customer consent -> claimed, its gclid withheld
-- 26-38 add customer merges: consent evidence is never re-pointed, and the reader follows the merge
-- record, so the newest decision of the logical customer governs whichever identity carried it.
create extension if not exists pgtap with schema extensions;

begin;
select plan(38);

insert into auth.users (id,email,email_confirmed_at) values
  ('14200000-0000-0000-0000-0000000000a1','own@ph142.test',now()),
  ('14200000-0000-0000-0000-0000000000a2','emp@ph142.test',now()),
  ('14200000-0000-0000-0000-0000000000a3','none@ph142.test',now()),
  ('14200000-0000-0000-0000-0000000000a4','own@ph142b.test',now());
insert into public.tenants (id,name,slug,status) values
  ('14200000-0000-0000-0000-000000000001','PH142 Travel','ph142-travel','active'),
  ('14200000-0000-0000-0000-000000000002','PH142 Other','ph142-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['14200000-0000-0000-0000-000000000001'::uuid,'14200000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('14200000-0000-0000-0000-00000000000a','14200000-0000-0000-0000-000000000001','Cairo','ph142-cairo');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('14200000-0000-0000-0000-0000000000c1','14200000-0000-0000-0000-000000000001','14200000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('14200000-0000-0000-0000-000000000011','14200000-0000-0000-0000-000000000001','Owner','own@ph142.test',true,'14200000-0000-0000-0000-0000000000a1'),
  ('14200000-0000-0000-0000-000000000012','14200000-0000-0000-0000-000000000001','Handler','emp@ph142.test',true,'14200000-0000-0000-0000-0000000000a2'),
  ('14200000-0000-0000-0000-000000000013','14200000-0000-0000-0000-000000000001','No role','none@ph142.test',true,'14200000-0000-0000-0000-0000000000a3'),
  ('14200000-0000-0000-0000-000000000021','14200000-0000-0000-0000-000000000002','Other owner','own@ph142b.test',true,'14200000-0000-0000-0000-0000000000a4');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary)
select '14200000-0000-0000-0000-000000000001', u, '14200000-0000-0000-0000-00000000000a','14200000-0000-0000-0000-0000000000c1', true
from unnest(array['14200000-0000-0000-0000-000000000011'::uuid,'14200000-0000-0000-0000-000000000012'::uuid]) u;
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('14200000-0000-0000-0000-000000000001'::uuid,'14200000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('14200000-0000-0000-0000-000000000001','14200000-0000-0000-0000-000000000012','employee'),
             ('14200000-0000-0000-0000-000000000002','14200000-0000-0000-0000-000000000021','owner')) v(t,u,rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id,tenant_id,customer_type_code,full_name,primary_phone,primary_email)
select ('14200000-0000-0000-0000-0000000000d'||n)::uuid, '14200000-0000-0000-0000-000000000001', 'person', 'C'||n,
       case n when 1 then '01000001421' when 4 then '01000001424' else '+2010000014'||(20 + n) end,
       case n when 1 then 'buyer@ph142.test' end
from generate_series(1,8) n;
insert into public.leads (id,tenant_id,branch_id,department_id,customer_id,lead_source_code,title,lead_status_code)
select ('14200000-0000-0000-0000-0000000000e'||n)::uuid, '14200000-0000-0000-0000-000000000001',
       '14200000-0000-0000-0000-00000000000a','14200000-0000-0000-0000-0000000000c1',
       ('14200000-0000-0000-0000-0000000000d'||n)::uuid,
       case when n in (1,7) then 'google_ads_form' else 'google_ads_call' end, 'L'||n, 'new'
from generate_series(1,8) n;
select app.capture_attribution_click('14200000-0000-0000-0000-000000000001','google_ads','GCLID-142-'||n,
         null,null,null,null,null,null,null,null,null,null,
         case when n in (7,8) then 'denied' else 'granted' end, 'granted',
         null, ('14200000-0000-0000-0000-0000000000e'||n)::uuid)
from unnest(array[1,2,7,8]) n;

-- The claim, reduced to one ordered line per claimed row of this tenant.
create function pg_temp.claimed() returns text language sql as $$
  select coalesce(string_agg(l.title || ':' || c.conversion_event_type_code || ':' || coalesce(c.gclid, '-')
                  || ':' || c.consent_ad_user_data || ':' || coalesce(c.consent_ad_personalization, '-')
                  || ':' || coalesce(c.customer_phone, '-') || ':' || coalesce(c.customer_email, '-'),
                  ',' order by l.title), '')
  from app.claim_conversion_deliveries('google_ads', 500) c
  join public.offline_conversions oc on oc.id = c.conversion_id
  join public.leads l on l.id = oc.lead_id
  where c.tenant_id = '14200000-0000-0000-0000-000000000001'
$$;

select app.map_outcomes_to_conversions(100000);
select set_config('t142.cursor', (select last_seq::text from public.integration_cursors
                                   where name = 'outcome_conversion_mapper'), true);

-- =============================================================================================
-- 1-8. THE CONSENT AUTHORITY.
-- =============================================================================================
select ok(has_table_privilege('authenticated','public.customer_consents','SELECT')
          and not has_table_privilege('authenticated','public.customer_consents','INSERT')
          and not has_table_privilege('authenticated','public.customer_consents','UPDATE')
          and not has_table_privilege('authenticated','public.customer_consents','DELETE'),
  'PREMISE: authenticated may read the consent record and has no table door into it -- the RPC is its one writer');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select app.record_customer_consent(('14200000-0000-0000-0000-0000000000d'||n)::uuid, 'ad_user_data', 'granted',
                                   'phone', 'agreed on the call')
from unnest(array[2,4,5,7,8]) n;
select app.record_customer_consent('14200000-0000-0000-0000-0000000000d3', 'ad_user_data', 'denied', 'phone', null);
select app.record_customer_consent('14200000-0000-0000-0000-0000000000d3', 'ad_user_data', 'granted', 'email', 'written reply');
select app.record_customer_consent('14200000-0000-0000-0000-0000000000d5', 'ad_user_data', 'denied', 'whatsapp', 'withdrew');

select is((select count(*)::text || '/' || count(distinct created_by)::text || '/' || max(created_by::text)
                  || '/' || bool_and(created_at = now())::text
             from public.customer_consents where tenant_id = '14200000-0000-0000-0000-000000000001'),
  '8/1/14200000-0000-0000-0000-000000000012/true',
  'the RPC records every decision with the server''s actor and the server''s time -- the caller supplies neither');

select throws_ok(
  $$insert into public.customer_consents (tenant_id, customer_id, purpose_code, consent_status_code, channel_code, created_by, created_at)
    values ('14200000-0000-0000-0000-000000000001','14200000-0000-0000-0000-0000000000d6','ad_user_data','granted','phone',
            '14200000-0000-0000-0000-000000000011', now() - interval '1 year')$$,
  '42501', 'permission denied for table customer_consents',
  'DOOR: a session cannot write a consent record with a forged actor or time at the table');

select throws_ok(
  $$select app.record_customer_consent('14200000-0000-0000-0000-0000000000d6', 'ad_user_data', 'unspecified', 'phone')$$,
  '23514', null,
  'INPUT: "unspecified" cannot be recorded -- it is the absence of a record, never a stored decision');

select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok(
  $$select app.record_customer_consent('14200000-0000-0000-0000-0000000000d6', 'ad_user_data', 'granted', 'phone')$$,
  '42501', 'permission denied: CREATE_CUSTOMER',
  'PRIVILEGE: a tenant user without CREATE_CUSTOMER cannot record consent');

select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a4","aal":"aal2"}',true);
select throws_ok(
  $$select public.record_customer_consent('14200000-0000-0000-0000-0000000000d6', 'ad_user_data', 'granted', 'phone')$$,
  'P0001', 'customer is not in your tenant',
  'TENANT: another tenant''s owner cannot record consent for this tenant''s customer, through the HTTP endpoint either');
select is((select count(*)::int from public.customer_consents), 0,
  'TENANT: another tenant sees none of this tenant''s consent records');
reset role;
select set_config('request.jwt.claims','',true);

select throws_like(
  $$update public.customer_consents set consent_status_code = 'granted' where customer_id = '14200000-0000-0000-0000-0000000000d5'$$,
  'append-only table: UPDATE is not permitted on customer_consents',
  'STATE: not even the platform can rewrite a recorded decision -- a change of mind is a new record');

select is((select string_agg(coalesce(app.customer_consent_status('14200000-0000-0000-0000-000000000001', ('14200000-0000-0000-0000-0000000000d'||n)::uuid, 'ad_user_data'), 'null'), ',' order by n)
             from generate_series(1,8) n),
  'null,granted,granted,granted,denied,null,granted,granted',
  'the current decision is the latest record: denied-then-granted is granted, granted-then-denied is denied, and no record is NULL -- unspecified, never granted');

-- =============================================================================================
-- 9-12. THE ONE QUALIFICATION FACT.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select app.assign_lead(('14200000-0000-0000-0000-0000000000e'||n)::uuid, '14200000-0000-0000-0000-000000000012', 'fixture') from generate_series(1,8) n;
select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
-- Every lead, form leads included, has a phone call logged: a mutable interaction is not the source.
select app.record_lead_interaction(('14200000-0000-0000-0000-0000000000e'||n)::uuid, 'phone_call') from generate_series(1,8) n;
select app.advance_lead(('14200000-0000-0000-0000-0000000000e'||n)::uuid, 'qualified', 'qualified') from generate_series(1,7) n;
select lives_ok($$update public.leads set lead_status_code = 'qualified' where id = '14200000-0000-0000-0000-0000000000e8'$$,
  'POSITIVE CONTROL: the handler still qualifies a call lead at the table door');
reset role;
select set_config('request.jwt.claims','',true);

select app.map_outcomes_to_conversions(500);

select is((select string_agg(l.title || '=' || coalesce(oc.conversion_event_type_code, 'none') || '/' || (oc.attribution_click_id is not null)::text, ',' order by l.title)
             from public.leads l left join public.offline_conversions oc on oc.lead_id = l.id
            where l.tenant_id = '14200000-0000-0000-0000-000000000001'),
  'L1=qualified_lead/true,L2=qualified_phone_call/true,L3=qualified_phone_call/false,L4=qualified_phone_call/false,L5=qualified_phone_call/false,L6=qualified_phone_call/false,L7=qualified_lead/true,L8=qualified_phone_call/true',
  'BUSINESS: each qualification is ONE conversion -- a first-touch Google Ads call is qualified_phone_call INSTEAD OF qualified_lead, with or without a click; every other source stays qualified_lead');

select is((select count(*)::int from public.offline_conversions oc
             join public.events e on e.seq = oc.source_event_seq
            where oc.tenant_id = '14200000-0000-0000-0000-000000000001'
              and e.event_type_code = 'lead_qualified' and e.entity_id = oc.lead_id), 8,
  'each conversion is keyed to its own lead_qualified event');

update public.integration_cursors set last_seq = current_setting('t142.cursor')::bigint
 where name = 'outcome_conversion_mapper';
select is(app.map_outcomes_to_conversions(500), 0,
  'REPLAY: with the shared cursor rewound over every qualification, re-mapping adds nothing -- one event is one conversion, of one type');

select throws_ok(
  $$update public.leads set lead_source_code = 'google_ads_form' where id = '14200000-0000-0000-0000-0000000000e3'$$,
  '42501', null,
  'STATE: the acquisition source the classification reads is first-touch -- no write can turn a call lead into a form lead, or back');

-- =============================================================================================
-- 13-19. DELIVERY: ONE CONSENT AUTHORITY PER PATH, AND THE PHONE ONLY AS E.164.
-- =============================================================================================
select is(pg_temp.claimed(),
  'L1:qualified_lead:GCLID-142-1:granted:granted:-:buyer@ph142.test,'
  || 'L2:qualified_phone_call:GCLID-142-2:granted:-:+201000001422:-,'
  || 'L3:qualified_phone_call:-:granted:-:+201000001423:-,'
  || 'L8:qualified_phone_call:-:granted:-:+201000001428:-',
  'the claim takes the form lead on its click''s consent, and each phone-call conversion on its customer''s latest granted consent -- keeping a genuine gclid, needing none, and withholding one whose own click consent was denied; a phone leaves only as E.164, so the form lead''s local number does not leave at all');

select is((select string_agg(l.title || '=' || oc.customer_phone || '/' || (select count(*) from public.offline_conversion_deliveries d where d.offline_conversion_id = oc.id)::text, ',' order by l.title)
             from public.offline_conversions oc join public.leads l on l.id = oc.lead_id
            where l.title in ('L4','L5','L6','L7')),
  'L4=01000001424/0,L5=+201000001425/0,L6=+201000001426/0,L7=+201000001427/0',
  'OBSERVABILITY: a conversion that is not eligible is not lost -- it stays recorded with its snapshot and no delivery (L4 has nothing to match on, L5 was withdrawn, L6 never consented, L7 is on the click path with a denied click)');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select isnt(app.record_offline_conversion('qualified_phone_call', '14200000-0000-0000-0000-0000000000e6'), null,
  'POSITIVE CONTROL: the manual door still records a conversion');
select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select app.record_customer_consent('14200000-0000-0000-0000-0000000000d6', 'ad_user_data', 'granted', 'phone', 'agreed on a later call');
reset role;
select set_config('request.jwt.claims','',true);
select is(pg_temp.claimed(),
  'L6:qualified_phone_call:-:granted:-:+201000001426:-',
  'BUSINESS: once L6''s customer consents, its mapped conversion is claimed -- and the hand-recorded qualified_phone_call for the same lead is not: only the qualification event is the fact');

select is((select count(*)::int from app.claim_conversion_deliveries('google_ads', 500) c
            where c.tenant_id = '14200000-0000-0000-0000-000000000001'), 0,
  'REPLAY: nothing is claimed twice');

-- A withdrawal is owed to the customer, not to the subscription: it is recordable while billing
-- restricts the tenant's business writes.
update public.subscriptions set subscription_status_code = 'read_only'
 where tenant_id = '14200000-0000-0000-0000-000000000001';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select throws_ok($$select app.add_customer_note('14200000-0000-0000-0000-0000000000d2', 'note')$$, null, null,
  'PREMISE: the tenant is billing-restricted -- an ordinary customer write is refused');
select lives_ok($$select app.record_customer_consent('14200000-0000-0000-0000-0000000000d2', 'ad_user_data', 'denied', 'phone', 'withdrew')$$,
  'STATE: the customer''s withdrawal is still recorded -- consent is not gated by billing');
reset role;
select set_config('request.jwt.claims','',true);
select is(app.customer_consent_status('14200000-0000-0000-0000-000000000001', '14200000-0000-0000-0000-0000000000d2', 'ad_user_data'),
  'denied', '...and it is the current decision');

select is(
  (select string_agg(coalesce(app.e164_phone(v), 'null'), ',' order by o)
     from unnest(array['+20 100 123 4567','+1 (800) 555-0100','(010) 0123-4567','01001234567','00201001234567',
                       '+0100','+201001234567x12','callmemaybe','+12345','+1234567890123456',null]) with ordinality u(v, o)),
  '+201001234567,+18005550100,null,null,null,null,null,null,null,null,null',
  'INPUT: the E.164 authority returns a number only when it already carries its country -- a local, 00-prefixed, malformed, too-short or too-long value is never given a guessed prefix');

select is(
  (select string_agg(p.oid::regprocedure::text || ' ' || p.prosecdef::text || ' ' || coalesce(array_to_string(p.proconfig, ','), '-')
                     || ' ' || coalesce(p.proacl::text, '-'), ' | ' order by p.oid::regprocedure::text)
     from pg_proc p where p.oid in ('app.e164_phone(text)'::regprocedure, 'app.customer_consent_status(uuid,uuid,text)'::regprocedure,
                                    'app.record_customer_consent(uuid,text,text,text,text)'::regprocedure)),
  'app.customer_consent_status(uuid,uuid,text) false search_path="" {postgres=X/postgres} | '
  || 'app.e164_phone(text) false search_path="" {postgres=X/postgres} | '
  || 'app.record_customer_consent(uuid,text,text,text,text) true search_path="" {postgres=X/postgres,authenticated=X/postgres}',
  'PRIVILEGE: the reader and the E.164 authority are platform-internal; only the writer is callable, and it pins its search_path');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = 'record_customer_consent'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')
      and not has_function_privilege('anon', p.oid, 'EXECUTE')), 1,
  'the writer has its one HTTP endpoint, for signed-in callers only');

-- =============================================================================================
-- 26-37. A CUSTOMER MERGE NEVER HIDES A DECISION. Consent evidence is excluded from the merge's
-- re-pointing (ADR-0019's documented route) and never rewritten; the reader follows the merge record
-- to the logical customer. The tenant is writable again; its handler records, in this order:
--   S1 granted (T1 has nothing) | T2 granted, then S2 denied | S3 granted, then T3 denied |
--   X2 granted, then X1 denied (X3 has nothing). The owner then merges S1->T1, S2->T2, S3->T3,
--   X1->X2 and X2->X3. L9 is a Google Ads call lead of S2, qualified before the merge.
-- =============================================================================================
update public.subscriptions set subscription_status_code = 'active'
 where tenant_id = '14200000-0000-0000-0000-000000000001';
insert into public.customers (id,tenant_id,customer_type_code,full_name,primary_phone)
select ('14200000-0000-0000-0000-0000000000f'||n)::uuid, '14200000-0000-0000-0000-000000000001', 'person', 'M'||n,
       '+2010000014'||(40 + n)
from generate_series(1,9) n;
insert into public.leads (id,tenant_id,branch_id,department_id,customer_id,lead_source_code,title,lead_status_code)
values ('14200000-0000-0000-0000-0000000000e9','14200000-0000-0000-0000-000000000001','14200000-0000-0000-0000-00000000000a',
        '14200000-0000-0000-0000-0000000000c1','14200000-0000-0000-0000-0000000000f3','google_ads_call','L9','new');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select app.assign_lead('14200000-0000-0000-0000-0000000000e9', '14200000-0000-0000-0000-000000000012', 'fixture');
select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select app.record_lead_interaction('14200000-0000-0000-0000-0000000000e9', 'phone_call');
select app.advance_lead('14200000-0000-0000-0000-0000000000e9', 'qualified', 'qualified');
select app.record_customer_consent('14200000-0000-0000-0000-0000000000f1', 'ad_user_data', 'granted', 'phone', null);
select app.record_customer_consent('14200000-0000-0000-0000-0000000000f4', 'ad_user_data', 'granted', 'phone', null);
select app.record_customer_consent('14200000-0000-0000-0000-0000000000f3', 'ad_user_data', 'denied', 'phone', null);
select app.record_customer_consent('14200000-0000-0000-0000-0000000000f5', 'ad_user_data', 'granted', 'phone', null);
select app.record_customer_consent('14200000-0000-0000-0000-0000000000f6', 'ad_user_data', 'denied', 'phone', null);
select app.record_customer_consent('14200000-0000-0000-0000-0000000000f8', 'ad_user_data', 'granted', 'phone', null);
select app.record_customer_consent('14200000-0000-0000-0000-0000000000f7', 'ad_user_data', 'denied', 'phone', null);
reset role;
select set_config('request.jwt.claims','',true);
select app.map_outcomes_to_conversions(500);
select set_config('t142.history', (select md5(string_agg(c.id::text || c.customer_id::text || c.consent_status_code
                                                         || coalesce(c.created_by::text, '-') || c.seq::text, ',' order by c.seq))
                                     from public.customer_consents c
                                    where c.tenant_id = '14200000-0000-0000-0000-000000000001'), true);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($$
  select app.merge_customer_identity('14200000-0000-0000-0000-0000000000f1', '14200000-0000-0000-0000-0000000000f2', 'duplicate');
  select app.merge_customer_identity('14200000-0000-0000-0000-0000000000f3', '14200000-0000-0000-0000-0000000000f4', 'duplicate');
  select app.merge_customer_identity('14200000-0000-0000-0000-0000000000f5', '14200000-0000-0000-0000-0000000000f6', 'duplicate');
  select app.merge_customer_identity('14200000-0000-0000-0000-0000000000f7', '14200000-0000-0000-0000-0000000000f8', 'duplicate');
  select app.merge_customer_identity('14200000-0000-0000-0000-0000000000f8', '14200000-0000-0000-0000-0000000000f9', 'duplicate')$$,
  'POSITIVE CONTROL: customers holding consent records merge -- consent evidence is excluded from re-pointing, so the append-only record never aborts a merge');
reset role;
select set_config('request.jwt.claims','',true);

create function pg_temp.st(p_n int) returns text language sql as $$
  select coalesce(app.customer_consent_status('14200000-0000-0000-0000-000000000001',
                  ('14200000-0000-0000-0000-0000000000f'||p_n)::uuid, 'ad_user_data'), 'null')
$$;

select is(pg_temp.st(2) || ',' || pg_temp.st(1), 'granted,granted',
  'MERGE 1: a source GRANTED merged into a target with no record -- the logical customer is granted, read from either id');
select is(pg_temp.st(4) || ',' || pg_temp.st(3), 'denied,denied',
  'MERGE 2: a source''s NEWER DENIED merged into a target''s OLDER GRANTED -- denied: the survivor''s own history is not the whole truth');
select is(pg_temp.st(6) || ',' || pg_temp.st(5), 'denied,denied',
  'MERGE 3: a source''s OLDER GRANTED merged into a target''s NEWER DENIED -- denied: the older grant does not resurface');
select is(pg_temp.st(9) || ',' || pg_temp.st(8) || ',' || pg_temp.st(7), 'denied,denied,denied',
  'MERGE 4: X1 into X2, then X2 into X3 -- the newest decision two merges deep governs, from any of the three ids');
select is((select md5(string_agg(c.id::text || c.customer_id::text || c.consent_status_code
                                 || coalesce(c.created_by::text, '-') || c.seq::text, ',' order by c.seq))
             from public.customer_consents c where c.tenant_id = '14200000-0000-0000-0000-000000000001'),
  current_setting('t142.history'),
  'HISTORY: after five merges every record is still there, unchanged -- same customer it was given for, same actor, same order');
select is(pg_temp.claimed(), '',
  'DELIVERY: L9''s conversion now belongs to the survivor T2, whose own record says granted -- and it is not claimed, because the merged newer DENIED governs');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14200000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select throws_ok($$select app.record_customer_consent('14200000-0000-0000-0000-0000000000f3', 'ad_user_data', 'granted', 'phone')$$,
  'P0001', 'customer was merged into 14200000-0000-0000-0000-0000000000f4 -- record consent for the surviving customer',
  'STATE: a merged identity takes no new decision -- every later decision for the logical customer is serialized on the survivor');
select app.record_customer_consent('14200000-0000-0000-0000-0000000000f4', 'ad_user_data', 'granted', 'email', 'confirmed after the merge');
reset role;
select set_config('request.jwt.claims','',true);
select is(pg_temp.st(4) || ',' || pg_temp.st(3), 'granted,granted',
  'POST-MERGE: a new decision on the survivor is the newest for the whole logical customer');
select is(pg_temp.claimed(), 'L9:qualified_phone_call:-:granted:-:+201000001443:-',
  '...and it reaches delivery: L9 is claimed on the survivor''s new grant');

select is(app.customer_consent_status('14200000-0000-0000-0000-000000000002', '14200000-0000-0000-0000-0000000000f4', 'ad_user_data'),
  null, 'TENANT: read under another tenant, the same customer id has no consent at all');

-- Order is `seq`, never time. A decision serialized later can carry an EARLIER `created_at` (its
-- transaction began first -- measured in the SPEC-240 two-session proof); written here directly, as
-- the platform, so the outcome is deterministic.
insert into public.customer_consents (tenant_id, customer_id, purpose_code, consent_status_code, channel_code, created_at)
values ('14200000-0000-0000-0000-000000000001','14200000-0000-0000-0000-0000000000d6','ad_user_data','granted','phone', now() + interval '1 hour');
insert into public.customer_consents (tenant_id, customer_id, purpose_code, consent_status_code, channel_code, created_at)
values ('14200000-0000-0000-0000-000000000001','14200000-0000-0000-0000-0000000000d6','ad_user_data','denied','phone', now() - interval '1 hour');
select is(app.customer_consent_status('14200000-0000-0000-0000-000000000001', '14200000-0000-0000-0000-0000000000d6', 'ad_user_data')
          || '/' || (select (d.seq > g.seq and d.created_at < g.created_at)::text
                       from public.customer_consents d, public.customer_consents g
                      where d.customer_id = '14200000-0000-0000-0000-0000000000d6' and d.created_at < now() - interval '30 minutes'
                        and g.customer_id = '14200000-0000-0000-0000-0000000000d6' and g.created_at > now() + interval '30 minutes'),
  'denied/true',
  'ORDER: the later-serialized DENIED wins although its created_at is two hours EARLIER -- the authority is seq, not a timestamp');

select throws_ok(
  $$insert into public.customer_consents (tenant_id, customer_id, purpose_code, consent_status_code, channel_code)
    values ('14200000-0000-0000-0000-000000000001', '14200000-0000-0000-0000-0000000000d1', 'ad_user_data', 'granted', 'phone'),
           ('14200000-0000-0000-0000-000000000002', '14200000-0000-0000-0000-0000000000d1', 'ad_user_data', 'granted', 'phone')$$,
  '23503', null,
  'INTEGRITY: even the platform cannot record consent for a customer of another tenant -- the record keeps its tenant-qualified foreign key to customers; only the merge''s re-pointing is excluded');

select * from finish();
rollback;
