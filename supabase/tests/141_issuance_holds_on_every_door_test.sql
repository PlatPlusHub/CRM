-- pgTAP: BOOK-10 -- issuance holds on every door.
--
-- `app.map_outcomes_to_conversions` turns `booking_issued` into `ticket_issued`. Until the BOOK-10
-- migration every rule of issuance lived in `app.advance_booking` alone, while `authenticated` holds
-- UPDATE and INSERT on `bookings` and `app.enforce_status_transition` makes the status door a governed
-- one. A direct issue recorded no `booking_issued` and so never became a conversion, skipped the
-- negative-balance override and its risk record, and issued archived bookings; an INSERT could create
-- a booking born `issued`. Now `bookings_enforce_lifecycle` is the single authority for those rules
-- and the single producer of the issuance events, and the RPC hands it only its reason.
--
-- ATTACK-CLASSES: DOOR BUSINESS STATE PRIVILEGE OBSERVABILITY REPLAY INPUT=N/A TENANT=N/A AUTH=N/A CONCURRENCY=N/A
--   INPUT=N/A -- the only caller-authored value is the status, bounded by the catalog and canon 26.
--   TENANT=N/A -- `app.record_event` takes the tenant from the row, which RLS already confined, and the
--     balance comes from `app.customer_balance`, which is tenant-scoped; conversion provenance is CONV-6's.
--   AUTH=N/A -- ISSUE_BOOKING and step-up on the door are `app.enforce_status_transition`'s and unchanged.
--   CONCURRENCY=N/A -- the trigger reads only its own row and that booking's balance, as the RPC did.
--
-- THE ACTORS. `owner` holds every booking permission. `branch_manager` holds ISSUE_BOOKING with a
-- per-user DENY on ALLOW_ISSUE_WITH_NEGATIVE_BALANCE. `employee` holds CREATE_BOOKING and not
-- ISSUE_BOOKING. Every lead carries a consented first-touch Google Ads click, so every issuance of an
-- attributed booking becomes a conversion. bk1-bk3 are owed 5000 EGP each; bk4-bk7 owe nothing.
create extension if not exists pgtap with schema extensions;

begin;
select plan(27);

insert into auth.users (id,email,email_confirmed_at) values
  ('14100000-0000-0000-0000-0000000000a1','own@p141.test',now()),
  ('14100000-0000-0000-0000-0000000000a2','bm@p141.test',now()),
  ('14100000-0000-0000-0000-0000000000a3','emp@p141.test',now());
insert into public.tenants (id,name,slug,status) values
  ('14100000-0000-0000-0000-000000000001','P141 Travel','p141-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '14100000-0000-0000-0000-000000000001', sp.id, 'active' from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('14100000-0000-0000-0000-00000000000a','14100000-0000-0000-0000-000000000001','Cairo','p141-cairo');
insert into public.departments (id,tenant_id,branch_id,department_type_code,name) values
  ('14100000-0000-0000-0000-0000000000c1','14100000-0000-0000-0000-000000000001','14100000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('14100000-0000-0000-0000-000000000011','14100000-0000-0000-0000-000000000001','Owner','own@p141.test',true,'14100000-0000-0000-0000-0000000000a1'),
  ('14100000-0000-0000-0000-000000000012','14100000-0000-0000-0000-000000000001','Manager','bm@p141.test',true,'14100000-0000-0000-0000-0000000000a2'),
  ('14100000-0000-0000-0000-000000000013','14100000-0000-0000-0000-000000000001','Employee','emp@p141.test',true,'14100000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id,user_id,branch_id,department_id,is_primary)
select '14100000-0000-0000-0000-000000000001', u, '14100000-0000-0000-0000-00000000000a','14100000-0000-0000-0000-0000000000c1', true
from unnest(array['14100000-0000-0000-0000-000000000011'::uuid,'14100000-0000-0000-0000-000000000012','14100000-0000-0000-0000-000000000013']) u;
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '14100000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('14100000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('14100000-0000-0000-0000-000000000012','branch_manager'),
             ('14100000-0000-0000-0000-000000000013','employee')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.user_permission_grants (tenant_id,user_id,permission_id,effect)
select '14100000-0000-0000-0000-000000000001','14100000-0000-0000-0000-000000000012', p.id, 'deny'
from public.permissions p where p.key = 'ALLOW_ISSUE_WITH_NEGATIVE_BALANCE';
insert into public.customers (id,tenant_id,customer_type_code,full_name,primary_phone,primary_email) values
  ('14100000-0000-0000-0000-0000000000d1','14100000-0000-0000-0000-000000000001','person','Buyer','+201000000141','buyer@p141.test'),
  ('14100000-0000-0000-0000-0000000000d2','14100000-0000-0000-0000-000000000001','person','Other',null,null);
insert into public.leads (id,tenant_id,branch_id,department_id,customer_id,lead_source_code,title,lead_status_code)
select ('14100000-0000-0000-0000-0000000000e'||n)::uuid, '14100000-0000-0000-0000-000000000001',
       '14100000-0000-0000-0000-00000000000a','14100000-0000-0000-0000-0000000000c1',
       '14100000-0000-0000-0000-0000000000d1','google_ads_form','L'||n,'new'
from generate_series(1,7) n;
select app.capture_attribution_click('14100000-0000-0000-0000-000000000001','google_ads','GCLID-141-'||n,
         null,null,null,null,null,null,null,null,null,null,'granted','granted',
         null, ('14100000-0000-0000-0000-0000000000e'||n)::uuid)
from generate_series(1,7) n;

create temp table s141 (k text primary key, v text) on commit drop;
grant select, insert on s141 to authenticated;
-- One line per booking and event type: count / actor / previous state / reason / payload.
create function pg_temp.i141(p_booking uuid, p_type text) returns text language sql as $$
  select count(e.id)::text || '/' || coalesce(max(e.actor_user_id::text), '-') || '/'
         || coalesce(max(e.previous_state), '-') || '/' || coalesce(max(e.reason), '-') || '/' || coalesce(max(e.payload::text), '-')
  from public.events e where e.entity_id = p_booking and e.event_type_code = p_type
$$;
grant execute on function pg_temp.i141(uuid, text) to authenticated;

-- 1. The door is a legal one.
select ok(has_table_privilege('authenticated','public.bookings','UPDATE') and has_table_privilege('authenticated','public.bookings','INSERT')
          and exists (select 1 from app.status_transitions where table_name = 'bookings' and from_status = 'in_progress'
                      and to_status = 'issued' and permission_key = 'ISSUE_BOOKING'),
  'PREMISE: authenticated holds UPDATE and INSERT on bookings, and canon 26''s in_progress -> issued edge is published to the table door under ISSUE_BOOKING -- a governed, legal door');

-- The owner works L1-L7 to a booking each, invoices bk1-bk3 without collecting, and takes all seven
-- to `in_progress`, the state issuance leaves from.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select app.assign_lead(('14100000-0000-0000-0000-0000000000e'||n)::uuid, '14100000-0000-0000-0000-000000000011', 'fixture') from generate_series(1,7) n;
select app.record_lead_interaction(('14100000-0000-0000-0000-0000000000e'||n)::uuid, 'phone_call') from generate_series(1,7) n;
insert into s141 select 'bk'||n, app.create_booking(p_customer_id=>'14100000-0000-0000-0000-0000000000d1',
                                                  p_lead_id=>('14100000-0000-0000-0000-0000000000e'||n)::uuid, p_title=>'Trip '||n)::text
from generate_series(1,7) n;
insert into s141 select 'inv'||n, app.create_invoice('14100000-0000-0000-0000-0000000000d1','EGP',5000,(select v from s141 where k='bk'||n)::uuid)::text
from generate_series(1,3) n;
select app.issue_invoice((select v from s141 where k='inv'||n)::uuid) from generate_series(1,3) n;
select app.advance_booking((select v from s141 where k='bk'||n)::uuid, s) from generate_series(1,7) n,
       unnest(array['pending_approval','confirmed','in_progress']) s;

-- =============================================================================================
-- 2-3. The RPC still issues exactly once.
-- =============================================================================================

select app.advance_booking((select v from s141 where k='bk1')::uuid, 'issued', 'tickets out');
select is(pg_temp.i141((select v from s141 where k='bk1')::uuid, 'booking_issued'),
  '1/14100000-0000-0000-0000-000000000011/in_progress/tickets out/{"lead_id": "14100000-0000-0000-0000-0000000000e1", "customer_id": "14100000-0000-0000-0000-0000000000d1", "booking_reference": "'
    || (select booking_reference from public.bookings where id = (select v from s141 where k='bk1')::uuid) || '"}',
  'DOOR: app.advance_booking records exactly ONE booking_issued, with the caller, the state it left, its reason and the RPC''s payload keys');
select is(pg_temp.i141((select v from s141 where k='bk1')::uuid, 'booking_item_risk_flag_created'),
  '1/14100000-0000-0000-0000-000000000011/-/tickets out/{"customer_id": "14100000-0000-0000-0000-0000000000d1", "permission_used": "ALLOW_ISSUE_WITH_NEGATIVE_BALANCE", "customer_balance_snapshot": [{"currency_code": "EGP", "outstanding_balance": 5000.0000}]}',
  'BUSINESS: issuing before collection records exactly ONE risk flag, with the permission used, the balance snapshot and the reason (ADR-0020, canon 27)');

-- =============================================================================================
-- 4-6. BOOK-10: the table door.
-- =============================================================================================
update public.bookings set booking_status_code = 'issued' where id = (select v from s141 where k='bk4')::uuid;
select is(pg_temp.i141((select v from s141 where k='bk4')::uuid, 'booking_issued') || ' | risk ' || pg_temp.i141((select v from s141 where k='bk4')::uuid, 'booking_item_risk_flag_created'),
  '1/14100000-0000-0000-0000-000000000011/in_progress/-/{"lead_id": "14100000-0000-0000-0000-0000000000e4", "customer_id": "14100000-0000-0000-0000-0000000000d1", "booking_reference": "'
    || (select booking_reference from public.bookings where id = (select v from s141 where k='bk4')::uuid) || '"} | risk 0/-/-/-/-',
  'DOOR: an owner''s direct issue records exactly ONE booking_issued with the RPC''s keys and no reason -- the RPC''s earlier reason was consumed, not inherited -- and no risk flag when nothing is owed');

update public.bookings set booking_status_code = 'issued' where id = (select v from s141 where k='bk2')::uuid;
select is(pg_temp.i141((select v from s141 where k='bk2')::uuid, 'booking_issued') || ' | risk ' || pg_temp.i141((select v from s141 where k='bk2')::uuid, 'booking_item_risk_flag_created'),
  '1/14100000-0000-0000-0000-000000000011/in_progress/-/{"lead_id": "14100000-0000-0000-0000-0000000000e2", "customer_id": "14100000-0000-0000-0000-0000000000d1", "booking_reference": "'
    || (select booking_reference from public.bookings where id = (select v from s141 where k='bk2')::uuid) || '"} | risk 1/14100000-0000-0000-0000-000000000011/-/-/{"customer_id": "14100000-0000-0000-0000-0000000000d1", "permission_used": "ALLOW_ISSUE_WITH_NEGATIVE_BALANCE", "customer_balance_snapshot": [{"currency_code": "EGP", "outstanding_balance": 5000.0000}]}',
  'BUSINESS: a direct issue before collection by an override holder records one booking_issued AND one risk flag with the snapshot -- the canon-28 risk record the door used to lose');

select set_config('request.jwt.claims','{"sub":"14100000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select ok(app.has_permission('ISSUE_BOOKING') and not app.has_permission('ALLOW_ISSUE_WITH_NEGATIVE_BALANCE'),
  'PREMISE: the branch manager holds ISSUE_BOOKING and is DENIED the negative-balance override, so any refusal below is the override''s');

-- =============================================================================================
-- 7-11. Issuance refused on the RPC is refused on the door.
-- =============================================================================================
select throws_ok($$select app.advance_booking((select v from s141 where k='bk3')::uuid, 'issued', 'try')$$,
  '42501', 'permission denied: ALLOW_ISSUE_WITH_NEGATIVE_BALANCE',
  'PRIVILEGE: the RPC refuses a denied manager issuing a booking the customer still owes on');
select throws_ok($$update public.bookings set booking_status_code = 'issued' where id = (select v from s141 where k='bk3')::uuid$$,
  '42501', 'permission denied: ALLOW_ISSUE_WITH_NEGATIVE_BALANCE',
  'PRIVILEGE: BOOK-10 -- the same issue by direct UPDATE is refused by the same control with the same message');
select throws_ok($$update public.bookings set customer_id = '14100000-0000-0000-0000-0000000000d2', booking_status_code = 'issued'
                   where id = (select v from s141 where k='bk3')::uuid$$,
  '42501', 'permission denied: ALLOW_ISSUE_WITH_NEGATIVE_BALANCE',
  'PRIVILEGE: rebinding the booking to a customer who owes nothing in the same statement does not escape -- the balance judged is the booking''s as it stood, which is what the RPC reads');
select is((select booking_status_code || '/' || (select count(*) from public.events e where e.entity_id = b.id
                                                  and e.event_type_code in ('booking_issued','booking_item_risk_flag_created'))
           from public.bookings b where b.id = (select v from s141 where k='bk3')::uuid),
  'in_progress/0', 'STATE: after all three refusals the owed booking is still in_progress with no issuance event');

update public.bookings set booking_status_code = 'issued' where id = (select v from s141 where k='bk5')::uuid;
select is(pg_temp.i141((select v from s141 where k='bk5')::uuid, 'booking_issued') || ' | risk ' || pg_temp.i141((select v from s141 where k='bk5')::uuid, 'booking_item_risk_flag_created'),
  '1/14100000-0000-0000-0000-000000000012/in_progress/-/{"lead_id": "14100000-0000-0000-0000-0000000000e5", "customer_id": "14100000-0000-0000-0000-0000000000d1", "booking_reference": "'
    || (select booking_reference from public.bookings where id = (select v from s141 where k='bk5')::uuid) || '"} | risk 0/-/-/-/-',
  'BUSINESS: the denied manager still issues a booking nothing is owed on -- the override is demanded only when the customer owes');

-- =============================================================================================
-- 12-16. Archived bookings and entry state.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"14100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
update public.bookings set is_archived = true, archive_reason = 'duplicate trip' where id = (select v from s141 where k='bk6')::uuid;
select throws_ok($$select app.advance_booking((select v from s141 where k='bk6')::uuid, 'issued')$$,
  'P0001', 'booking is archived', 'STATE: the RPC still refuses to issue an archived booking');
select throws_ok($$update public.bookings set booking_status_code = 'issued' where id = (select v from s141 where k='bk6')::uuid$$,
  'P0001', 'booking is archived', 'STATE: BOOK-10 -- so does the table door, with the same message');
select throws_ok($$update public.bookings set booking_status_code = 'cancelled' where id = (select v from s141 where k='bk6')::uuid$$,
  'P0001', 'booking is archived', 'STATE: the rule is the RPC''s for every transition, moved whole -- the door cannot cancel an archived booking either');

select set_config('request.jwt.claims','{"sub":"14100000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok($$insert into public.bookings (tenant_id,branch_id,department_id,customer_id,lead_id,title,booking_reference,booking_status_code,owner_user_id)
                   values ('14100000-0000-0000-0000-000000000001','14100000-0000-0000-0000-00000000000a','14100000-0000-0000-0000-0000000000c1',
                           '14100000-0000-0000-0000-0000000000d1','14100000-0000-0000-0000-0000000000e7','Born issued','BK-141-BORN','issued',
                           '14100000-0000-0000-0000-000000000013')$$,
  '23514', 'a booking is created at ''draft'' (canon 26); it was created as ''issued'' -- use app.advance_booking to move it',
  'STATE: ENTRY-1 -- an employee without ISSUE_BOOKING can no longer create a booking born issued');
select lives_ok($$insert into public.bookings (tenant_id,branch_id,department_id,customer_id,title,booking_reference,booking_status_code,owner_user_id)
                  values ('14100000-0000-0000-0000-000000000001','14100000-0000-0000-0000-00000000000a','14100000-0000-0000-0000-0000000000c1',
                          '14100000-0000-0000-0000-0000000000d1','Born draft','BK-141-DRAFT','draft','14100000-0000-0000-0000-000000000013')$$,
  'DOOR: the same employee still creates a booking at draft -- the entry rule constrains the state, not the door');

-- =============================================================================================
-- 17-18. The edge, not the state: remaining in `issued` is not issuance; re-entering it is.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"14100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
update public.bookings set title = 'Trip 1 renamed' where id = (select v from s141 where k='bk1')::uuid;
update public.bookings set booking_status_code = 'issued' where id = (select v from s141 where k='bk1')::uuid;
select is((select count(*)::int from public.events e where e.entity_id = (select v from s141 where k='bk1')::uuid
           and e.event_type_code in ('booking_issued','booking_item_risk_flag_created')),
  2, 'REPLAY: an unrelated edit and a no-op status write on an issued booking record nothing more');

select app.advance_booking((select v from s141 where k='bk1')::uuid, 'reissue', 'date change');
select app.advance_booking((select v from s141 where k='bk1')::uuid, 'issued', 'reissued');
select is((select string_agg(e.event_type_code || ':' || coalesce(e.previous_state,'-') || '>' || e.new_state || ':' || coalesce(e.reason,'-'), ', ' order by e.seq)
           from public.events e where e.entity_id = (select v from s141 where k='bk1')::uuid
           and e.event_type_code in ('booking_issued','booking_item_risk_flag_created','booking_reissue_started')),
  'booking_issued:in_progress>issued:tickets out, booking_item_risk_flag_created:->issued:tickets out, booking_reissue_started:issued>reissue:date change, booking_issued:reissue>issued:reissued, booking_item_risk_flag_created:->issued:reissued',
  'STATE: canon 26''s reissue -> issued is issuance again -- one more booking_issued and, still owed, one more risk flag, each with its own reason; the RPC still records booking_reissue_started itself');

-- =============================================================================================
-- 19-20. The platform path: recorded, and exempt from the override (authorization, ADR-0025).
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','',true);
select lives_ok($$update public.bookings set booking_status_code = 'issued' where id = (select v from s141 where k='bk3')::uuid$$,
  'DOOR: the platform path issues the owed booking the manager could not -- it has no session to authorize');
select is(pg_temp.i141((select v from s141 where k='bk3')::uuid, 'booking_issued') || ' | risk ' || pg_temp.i141((select v from s141 where k='bk3')::uuid, 'booking_item_risk_flag_created'),
  '1/-/in_progress/-/{"lead_id": "14100000-0000-0000-0000-0000000000e3", "customer_id": "14100000-0000-0000-0000-0000000000d1", "booking_reference": "'
    || (select booking_reference from public.bookings where id = (select v from s141 where k='bk3')::uuid) || '"} | risk 0/-/-/-/-',
  'DOOR: a session-less issue records ONE booking_issued with no actor; the override and its risk record are authorization and do not apply');

-- =============================================================================================
-- 21-23. The pipeline: one ticket_issued per issuance event, on every door, and never twice.
-- =============================================================================================
select app.map_outcomes_to_conversions(5000);
select is((select string_agg(k || ':' || n, ',' order by k) from (
             select s.k, count(oc.id) as n from s141 s
             join public.offline_conversions oc on oc.booking_id = s.v::uuid and oc.conversion_event_type_code = 'ticket_issued'
             group by s.k) t),
  'bk1:2,bk2:1,bk3:1,bk4:1,bk5:1',
  'OBSERVABILITY: the real mapper makes exactly one ticket_issued per issuance -- RPC (bk1, and its reissue), owner door (bk2, bk4), manager door (bk5) and platform (bk3); none for the refused or archived booking');
select is((select count(*)::int from public.offline_conversions oc
           join public.events e on e.seq = oc.source_event_seq
           where oc.conversion_event_type_code = 'ticket_issued' and oc.tenant_id = '14100000-0000-0000-0000-000000000001'
             and (e.event_type_code <> 'booking_issued' or e.entity_id <> oc.booking_id)),
  0, 'OBSERVABILITY: every ticket_issued is keyed to its own booking_issued event');
select is(app.map_outcomes_to_conversions(5000), 0, 'REPLAY: a second mapper run adds nothing');

-- =============================================================================================
-- 24. The authority's own shape.
-- =============================================================================================
select is((select p.prosecdef::text || '/' || array_to_string(p.proconfig, ',') || '/' || coalesce(p.proacl::text, '-')
                  || '/' || t.tgtype::text || '/' || (t.tgconstraint <> 0)::text || '/' || t.tgenabled::text
           from pg_proc p join pg_trigger t on t.tgfoid = p.oid
           where p.oid = 'app.enforce_booking_lifecycle'::regproc and t.tgrelid = 'public.bookings'::regclass),
  'false/search_path=""/{postgres=X/postgres}/21/false/O',
  'PRIVILEGE: the authority is SECURITY INVOKER (the override is judged on the balance the caller can read, as in the RPC), pins search_path, grants EXECUTE to no one, and is one AFTER INSERT OR UPDATE ROW trigger');

-- =============================================================================================
-- 25-27. Mutation, in-file: without the trigger the door is silent again and the rules fall.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14100000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
savepoint no_authority;
reset role;
drop trigger bookings_enforce_lifecycle on public.bookings;
set local role authenticated;
update public.bookings set booking_status_code = 'issued' where id = (select v from s141 where k='bk7')::uuid;
select is(pg_temp.i141((select v from s141 where k='bk7')::uuid, 'booking_issued'), '0/-/-/-/-',
  'MUTATION: with the trigger dropped a direct issue records no booking_issued -- BOOK-10 as it was');
reset role;
select set_config('request.jwt.claims','',true);
select is(app.map_outcomes_to_conversions(5000), 0, 'MUTATION: ...and so no ticket_issued ever exists for it');
rollback to savepoint no_authority;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"14100000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
update public.bookings set booking_status_code = 'issued' where id = (select v from s141 where k='bk7')::uuid;
select is(pg_temp.i141((select v from s141 where k='bk7')::uuid, 'booking_issued'),
  '1/14100000-0000-0000-0000-000000000012/in_progress/-/{"lead_id": "14100000-0000-0000-0000-0000000000e7", "customer_id": "14100000-0000-0000-0000-0000000000d1", "booking_reference": "'
    || (select booking_reference from public.bookings where id = (select v from s141 where k='bk7')::uuid) || '"}',
  'MUTATION: restored, the same direct issue is recorded once');

select * from finish();
rollback;
