-- pgTAP: CONV-8 -- a qualified lead and a booking are recorded on every door.
--
-- `app.map_outcomes_to_conversions` turns `lead_qualified` into the `qualified_lead` Google Ads
-- conversion and `booking_created` into `booking_created`. Until the CONV-8 migration each event had
-- one producer, its RPC, while `authenticated` holds UPDATE on `leads` and INSERT on `bookings` and the
-- state machine lets the assigned handler move a contacted lead to `qualified` at the table door. The
-- same business act done there emitted nothing, so it never became a conversion (`137_...` pinned it).
-- Now one AFTER trigger per event is its single producer and the RPCs no longer emit it themselves.
--
-- ATTACK-CLASSES: DOOR BUSINESS STATE OBSERVABILITY PRIVILEGE REPLAY TENANT=N/A AUTH=N/A CONCURRENCY=N/A INPUT=N/A
--   TENANT=N/A -- `app.record_event` takes the tenant from the row, which RLS already confined;
--     conversion provenance across tenants is CONV-6's (`119_...`).
--   AUTH=N/A -- step-up belongs to `app.advance_lead` and is unchanged; the door's own guards are too.
--   CONCURRENCY=N/A -- each emitter is one AFTER ROW call that reads only its own row.
--   INPUT=N/A -- the payload is read from the row the write produced; nothing is parsed.
--
-- THE ACTORS. `owner` holds CREATE_BOOKING and ASSIGN_LEAD. `handler` is an `employee` holding the
-- leads it was assigned; every lead carries a consented first-touch Google Ads click, so each event
-- below that the mapper sees becomes a conversion.
create extension if not exists pgtap with schema extensions;

begin;
select plan(19);

insert into auth.users (id,email,email_confirmed_at) values
  ('13900000-0000-0000-0000-0000000000a1','own@cv139.test',now()),
  ('13900000-0000-0000-0000-0000000000a2','emp@cv139.test',now());
insert into public.tenants (id,name,slug,status) values
  ('13900000-0000-0000-0000-000000000001','CV139 Travel','cv139-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '13900000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('13900000-0000-0000-0000-00000000000a','13900000-0000-0000-0000-000000000001','Cairo','cv139-cairo');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('13900000-0000-0000-0000-0000000000c1','13900000-0000-0000-0000-000000000001','13900000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('13900000-0000-0000-0000-000000000011','13900000-0000-0000-0000-000000000001','Owner','own@cv139.test',true,'13900000-0000-0000-0000-0000000000a1'),
  ('13900000-0000-0000-0000-000000000012','13900000-0000-0000-0000-000000000001','Handler','emp@cv139.test',true,'13900000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary)
select '13900000-0000-0000-0000-000000000001', u, '13900000-0000-0000-0000-00000000000a','13900000-0000-0000-0000-0000000000c1', true
from unnest(array['13900000-0000-0000-0000-000000000011'::uuid,'13900000-0000-0000-0000-000000000012'::uuid]) u;
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '13900000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('13900000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('13900000-0000-0000-0000-000000000012','employee')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id,tenant_id,customer_type_code,full_name,primary_phone,primary_email) values
  ('13900000-0000-0000-0000-0000000000d1','13900000-0000-0000-0000-000000000001','person','Buyer','+201000000139','buyer@cv139.test');
insert into public.leads (id,tenant_id,branch_id,department_id,customer_id,lead_source_code,title,lead_status_code)
select ('13900000-0000-0000-0000-0000000000e'||n)::uuid, '13900000-0000-0000-0000-000000000001',
       '13900000-0000-0000-0000-00000000000a','13900000-0000-0000-0000-0000000000c1',
       '13900000-0000-0000-0000-0000000000d1','google_ads_form','L'||n,'new'
from generate_series(1,7) n;
select app.capture_attribution_click('13900000-0000-0000-0000-000000000001','google_ads','GCLID-139-'||n,
         null,null,null,null,null,null,null,null,null,null,'granted','granted',
         null, ('13900000-0000-0000-0000-0000000000e'||n)::uuid)
from generate_series(1,7) n;

-- One line per lead: lead_qualified count / actor / previous / new / reason.
create function pg_temp.q139(p_lead uuid) returns text language sql as $$
  select count(e.id)::text || '/' || coalesce(max(e.actor_user_id::text), '-') || '/' || coalesce(max(e.previous_state), '-')
         || '/' || coalesce(max(e.new_state), '-') || '/' || coalesce(max(e.reason), '-')
  from public.events e where e.entity_id = p_lead and e.event_type_code = 'lead_qualified'
$$;
-- One line per booking reference: booking_created count / actor / new state / payload.
create function pg_temp.b139(p_ref text) returns text language sql as $$
  select count(e.id)::text || '/' || coalesce(max(e.actor_user_id::text), '-') || '/' || coalesce(max(e.new_state), '-')
         || '/' || coalesce(max((e.payload - 'customer_id')::text), '-')
  from public.bookings b
  left join public.events e on e.entity_id = b.id and e.event_type_code = 'booking_created'
  where b.tenant_id = '13900000-0000-0000-0000-000000000001' and b.booking_reference = p_ref
$$;
grant execute on function pg_temp.q139(uuid) to authenticated;
grant execute on function pg_temp.b139(text) to authenticated;

-- Written as `postgres`, with no session: the platform path, recorded with a null actor (15).
insert into public.bookings (tenant_id,branch_id,department_id,customer_id,booking_status_code,title,booking_reference)
values ('13900000-0000-0000-0000-000000000001','13900000-0000-0000-0000-00000000000a','13900000-0000-0000-0000-0000000000c1',
        '13900000-0000-0000-0000-0000000000d1','draft','Platform booking','CV139-SYS');

-- The owner hands every lead to the handler; the handler contacts L1-L6. L7 stays assigned.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select app.assign_lead(('13900000-0000-0000-0000-0000000000e'||n)::uuid, '13900000-0000-0000-0000-000000000012', 'fixture')
from generate_series(1,7) n;
select app.record_lead_interaction(('13900000-0000-0000-0000-0000000000e'||n)::uuid, 'phone_call') from generate_series(1,6) n;
reset role;

-- =============================================================================================
-- 1-4. The lead: the RPC and the table door each record exactly one lead_qualified.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"13900000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;

select ok(has_table_privilege('authenticated','public.leads','UPDATE') and has_table_privilege('authenticated','public.bookings','INSERT'),
  'PREMISE: authenticated holds UPDATE on leads and INSERT on bookings -- the table door is a designed door');

select app.advance_lead('13900000-0000-0000-0000-0000000000e1', 'qualified', 'budget confirmed');
select is(pg_temp.q139('13900000-0000-0000-0000-0000000000e1'),
  '1/13900000-0000-0000-0000-000000000012/contacted/qualified/budget confirmed',
  'DOOR: the RPC path records exactly ONE lead_qualified, with the caller, the transition and the caller''s reason -- the RPC no longer emits it itself, so it is not recorded twice');

select lives_ok($$update public.leads set lead_status_code = 'qualified' where id = '13900000-0000-0000-0000-0000000000e2'$$,
  'POSITIVE CONTROL: the assigned handler still qualifies a contacted lead at the table door -- it is recorded, not closed');
select is(pg_temp.q139('13900000-0000-0000-0000-0000000000e2'),
  '1/13900000-0000-0000-0000-000000000012/contacted/qualified/-',
  'CONV-8: a lead qualified at the table door records lead_qualified naming the handler -- and the RPC''s reason, set earlier in this transaction, did not leak onto it');

-- =============================================================================================
-- 5-8. What is not recorded, and what the state machine still refuses.
-- =============================================================================================
update public.leads set title = 'L2 edited' where id = '13900000-0000-0000-0000-0000000000e2';
select is(pg_temp.q139('13900000-0000-0000-0000-0000000000e2'),
  '1/13900000-0000-0000-0000-000000000012/contacted/qualified/-',
  'STATE: an edit of a qualified lead records no second lead_qualified -- the event is the entry into qualified, not every write to a qualified row');

select app.advance_lead('13900000-0000-0000-0000-0000000000e1', 'quotation_sent', 'sent the Cairo quote');
select is((select count(*)::text || '/' || max(e.reason) from public.events e
            where e.entity_id = '13900000-0000-0000-0000-0000000000e1' and e.event_type_code = 'lead_quotation_sent')
          || '|' || pg_temp.q139('13900000-0000-0000-0000-0000000000e1'),
  '1/sent the Cairo quote|1/13900000-0000-0000-0000-000000000012/contacted/qualified/budget confirmed',
  'STATE: every other app.advance_lead event is still the RPC''s own, exactly once, and leaving qualified records no lead_qualified');

select throws_ok($$update public.leads set lead_status_code = 'qualified' where id = '13900000-0000-0000-0000-0000000000e7'$$,
  '23514', 'assigned -> qualified is not a permitted transition for leads.lead_status_code (canon 26 state machine); use the app.advance_* RPC',
  'STATE: the table door still refuses assigned -> qualified -- the state machine, not the emitter, decides what is a qualification');
select is(pg_temp.q139('13900000-0000-0000-0000-0000000000e7'), '0/-/-/-/-',
  '...and the refused transition leaves no lead_qualified behind');

-- =============================================================================================
-- 9-12. The booking: the RPC and the table door each record exactly one booking_created.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"13900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;
select app.create_booking(p_customer_id=>'13900000-0000-0000-0000-0000000000d1', p_lead_id=>'13900000-0000-0000-0000-0000000000e3',
                          p_title=>'Cairo trip', p_booking_reference=>'CV139-RPC');
select is(pg_temp.b139('CV139-RPC'),
  '1/13900000-0000-0000-0000-000000000011/draft/{"lead_id": "13900000-0000-0000-0000-0000000000e3", "quotation_id": null, "booking_reference": "CV139-RPC"}',
  'DOOR: the RPC path records exactly ONE booking_created, with the caller and the RPC''s own payload keys -- not recorded twice');
select is((select e.payload ->> 'customer_id' from public.events e join public.bookings b on b.id = e.entity_id
            where b.booking_reference = 'CV139-RPC' and e.event_type_code = 'booking_created'),
  '13900000-0000-0000-0000-0000000000d1',
  'INPUT: the payload''s customer is the one the RPC resolved, read back from the row');
reset role;

select set_config('request.jwt.claims','{"sub":"13900000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
select lives_ok($$insert into public.bookings (tenant_id,branch_id,department_id,customer_id,lead_id,booking_status_code,title,booking_reference)
                  values ('13900000-0000-0000-0000-000000000001','13900000-0000-0000-0000-00000000000a','13900000-0000-0000-0000-0000000000c1',
                          '13900000-0000-0000-0000-0000000000d1','13900000-0000-0000-0000-0000000000e4','draft','Door booking','CV139-DOOR')$$,
  'POSITIVE CONTROL: an employee still creates a booking at the table door');
select is(pg_temp.b139('CV139-DOOR'),
  '1/13900000-0000-0000-0000-000000000012/draft/{"lead_id": "13900000-0000-0000-0000-0000000000e4", "quotation_id": null, "booking_reference": "CV139-DOOR"}',
  'CONV-8: a booking created at the table door records booking_created naming its creator and its lead -- before the CONV-8 migration this row had zero events');
reset role;
select set_config('request.jwt.claims','',true);

-- =============================================================================================
-- 13-15. The pipeline, the emitters' privileges, and the platform path.
-- =============================================================================================
create temp table run1 on commit drop as select app.map_outcomes_to_conversions(100000) as n;
select is((select array_agg(l.title || ':' || oc.conversion_event_type_code || '@' || (oc.source_event_seq = e.seq)::text order by l.title)
             from public.offline_conversions oc
             join public.leads l on l.id = oc.lead_id
             join public.events e on e.seq = oc.source_event_seq
            where oc.tenant_id = '13900000-0000-0000-0000-000000000001'),
  array['L1:qualified_lead@true','L2 edited:qualified_lead@true','L3:booking_created@true','L4:booking_created@true'],
  'BUSINESS: both doors now reach the Google Ads pipeline -- one conversion per recorded act, each keyed to its own event');

select ok(
  (select bool_and(prosecdef) from pg_proc where oid in ('app.emit_lead_qualified'::regproc, 'app.emit_booking_created'::regproc))
  and not has_function_privilege('public', 'app.emit_lead_qualified()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'app.emit_lead_qualified()', 'EXECUTE')
  and not has_function_privilege('public', 'app.emit_booking_created()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'app.emit_booking_created()', 'EXECUTE')
  and (select count(*) = 1 from pg_trigger t
        where t.tgrelid = 'public.bookings'::regclass and not t.tgisinternal and t.tgfoid = 'app.emit_booking_created'::regproc
          and (t.tgtype & 1) = 1 and (t.tgtype & 2) = 0 and (t.tgtype & 4) <> 0 and (t.tgtype & 8) = 0 and (t.tgtype & 16) = 0)
  and (select count(*) = 1 from pg_trigger t
        where t.tgrelid = 'public.leads'::regclass and not t.tgisinternal and t.tgfoid = 'app.emit_lead_qualified'::regproc
          and (t.tgtype & 1) = 1 and (t.tgtype & 2) = 0 and (t.tgtype & 4) = 0 and (t.tgtype & 8) = 0 and (t.tgtype & 16) <> 0),
  'PRIVILEGE: both emitters are SECURITY DEFINER, executable by neither PUBLIC nor authenticated, and fire AFTER ROW on INSERT (bookings) and UPDATE (leads) only, exactly once each');

select is(pg_temp.b139('CV139-SYS'),
  '1/-/draft/{"lead_id": null, "quotation_id": null, "booking_reference": "CV139-SYS"}',
  'the session-less platform path is recorded too, with a null actor');

-- =============================================================================================
-- 16-18. LOAD-BEARING: remove the emitters and both doors are silent again; restore them and they record.
-- TEST-3: the in-savepoint assertion is re-asserted after the rollback so it is counted.
-- =============================================================================================
savepoint m139;
drop trigger leads_emit_qualified on public.leads;
drop trigger bookings_emit_created on public.bookings;
select set_config('request.jwt.claims','{"sub":"13900000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
update public.leads set lead_status_code = 'qualified' where id = '13900000-0000-0000-0000-0000000000e5';
insert into public.bookings (tenant_id,branch_id,department_id,customer_id,lead_id,booking_status_code,title,booking_reference)
values ('13900000-0000-0000-0000-000000000001','13900000-0000-0000-0000-00000000000a','13900000-0000-0000-0000-0000000000c1',
        '13900000-0000-0000-0000-0000000000d1','13900000-0000-0000-0000-0000000000e6','draft','Mutant booking','CV139-MUT');
reset role;
select set_config('request.jwt.claims','',true);
create temp table mrun on commit drop as select app.map_outcomes_to_conversions(100000) as n;
select is(pg_temp.q139('13900000-0000-0000-0000-0000000000e5') || '|' || pg_temp.b139('CV139-MUT') || '|' || (select n from mrun),
  '0/-/-/-/-|0/-/-/-|0',
  'MUTATION: with both emitters dropped, the door qualification and the door booking are silent again and produce no conversion -- so these triggers are what close CONV-8');
rollback to savepoint m139;

select set_config('request.jwt.claims','{"sub":"13900000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
set local role authenticated;
update public.leads set lead_status_code = 'qualified' where id = '13900000-0000-0000-0000-0000000000e5';
insert into public.bookings (tenant_id,branch_id,department_id,customer_id,lead_id,booking_status_code,title,booking_reference)
values ('13900000-0000-0000-0000-000000000001','13900000-0000-0000-0000-00000000000a','13900000-0000-0000-0000-0000000000c1',
        '13900000-0000-0000-0000-0000000000d1','13900000-0000-0000-0000-0000000000e6','draft','Mutant booking','CV139-MUT');
reset role;
select set_config('request.jwt.claims','',true);
create temp table rrun on commit drop as select app.map_outcomes_to_conversions(100000) as n;
select is(pg_temp.q139('13900000-0000-0000-0000-0000000000e5') || '|' || pg_temp.b139('CV139-MUT') || '|' || (select n from rrun),
  '1/13900000-0000-0000-0000-000000000012/contacted/qualified/-|1/13900000-0000-0000-0000-000000000012/draft/{"lead_id": "13900000-0000-0000-0000-0000000000e6", "quotation_id": null, "booking_reference": "CV139-MUT"}|2',
  'RESTORED: with the mutation rolled back the identical writes are recorded again and become two conversions');

create temp table run3 on commit drop as select app.map_outcomes_to_conversions(100000) as n;
select is(array[(select n from run3), (select count(*)::int from public.offline_conversions where tenant_id = '13900000-0000-0000-0000-000000000001')],
  array[0, 6],
  'REPLAY: a further mapper run adds nothing; six conversions, one per recorded act (the platform booking has no lead)');

-- =============================================================================================
-- 19. COMPLETENESS.
-- =============================================================================================
select is((select count(*)::int from public.bookings b
            where b.tenant_id = '13900000-0000-0000-0000-000000000001'
              and (select count(*) from public.events e where e.entity_id = b.id and e.event_type_code = 'booking_created') <> 1)
        + (select count(*)::int from public.leads l
            where l.tenant_id = '13900000-0000-0000-0000-000000000001'
              and l.lead_status_code in ('qualified','quotation_sent')
              and (select count(*) from public.events e where e.entity_id = l.id and e.event_type_code = 'lead_qualified') <> 1),
  0,
  'COMPLETENESS: every booking in the tenant carries exactly one booking_created, and every lead that entered qualified exactly one lead_qualified');

select * from finish();
rollback;
