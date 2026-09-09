-- pgTAP: PAX-5 and PAX-6 -- owner decisions, ratified 2026-09-09.
--
-- PAX-5  the manifest freezes when the booking reaches `issued` or a state reachable after it.
--        A post-issue correction costs CORRECT_PASSENGER_MANIFEST, a mandatory reason, and leaves
--        server-stamped attribution.
-- PAX-6  every sanctioned manifest change emits exactly one business event, through EITHER door.
--
-- `issued` is a BOOKING status, not a booking-item one -- read out of app.status_transitions rather
-- than invented (booking_item_base_status has no such value, and booking_items.issued_at has no
-- writer anywhere in the database). Assertion 1 pins that, so a future reader cannot quietly move
-- the freeze to a status the state machine does not have.
--
-- Both doors are attacked. `authenticated` holds INSERT and UPDATE on public.booking_item_passengers
-- and PostgREST serves it, so a rule enforced only inside the RPC would enforce nothing (BOOK-1).
create extension if not exists pgtap with schema extensions;

begin;
select plan(29);

-- =============================================================================================
-- FIXTURE. Two tenants. Three actors chosen for what they DO NOT hold:
--   employee         CREATE_BOOKING_ITEM, no CORRECT_PASSENGER_MANIFEST -- the pre-issue writer
--   finance_manager  CORRECT_PASSENGER_MANIFEST, NO CREATE_BOOKING_ITEM -- the containment case
--   branch_manager   both
-- The finance_manager is the whole reason guard_write_capability had to be widened: without that,
-- the object-class door would refuse the correction before the enforcer that owns PAX-5 ever ran.
-- =============================================================================================
insert into auth.users (id, email) values
  ('a5000000-0000-0000-0000-0000000000a1','emp@pax5.test'),
  ('a5000000-0000-0000-0000-0000000000a2','fin@pax5.test'),
  ('a5000000-0000-0000-0000-0000000000a3','mgr@pax5.test');
insert into public.tenants (id, name, slug, status) values
  ('a5000000-0000-0000-0000-000000000001','Alpha Travel','alpha-pax5','active'),
  ('a5000000-0000-0000-0000-000000000002','Rival Travel','rival-pax5','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['a5000000-0000-0000-0000-000000000001'::uuid,
               'a5000000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('a5000000-0000-0000-0000-00000000000a','a5000000-0000-0000-0000-000000000001','Cairo','pax5-cairo'),
  ('a5000000-0000-0000-0000-00000000000b','a5000000-0000-0000-0000-000000000002','Giza','pax5-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('a5000000-0000-0000-0000-0000000000c1','a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-00000000000a','sales','Sales'),
  ('a5000000-0000-0000-0000-0000000000c2','a5000000-0000-0000-0000-000000000002','a5000000-0000-0000-0000-00000000000b','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000001','Emp','emp@pax5.test',true,'a5000000-0000-0000-0000-0000000000a1'),
  ('a5000000-0000-0000-0000-000000000012','a5000000-0000-0000-0000-000000000001','Fin','fin@pax5.test',true,'a5000000-0000-0000-0000-0000000000a2'),
  ('a5000000-0000-0000-0000-000000000013','a5000000-0000-0000-0000-000000000001','Mgr','mgr@pax5.test',true,'a5000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select 'a5000000-0000-0000-0000-000000000001', u, 'a5000000-0000-0000-0000-00000000000a','a5000000-0000-0000-0000-0000000000c1', true
from unnest(array['a5000000-0000-0000-0000-000000000011'::uuid,
                  'a5000000-0000-0000-0000-000000000012'::uuid,
                  'a5000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'a5000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('a5000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('a5000000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('a5000000-0000-0000-0000-000000000013'::uuid,'branch_manager')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('a5000000-0000-0000-0000-0000000000d1','a5000000-0000-0000-0000-000000000001','person','Alpha Cust'),
  ('a5000000-0000-0000-0000-0000000000d2','a5000000-0000-0000-0000-000000000002','person','Rival Cust');

-- One DRAFT booking (pre-issue) and one ISSUED booking, in Alpha; one draft in Rival.
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
    owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('a5000000-0000-0000-0000-0000000000f1','a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-00000000000a','a5000000-0000-0000-0000-0000000000c1','a5000000-0000-0000-0000-0000000000d1','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-00000000000a','a5000000-0000-0000-0000-0000000000c1','draft','Alpha draft','BK-PAX5-1'),
  ('a5000000-0000-0000-0000-0000000000f2','a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-00000000000a','a5000000-0000-0000-0000-0000000000c1','a5000000-0000-0000-0000-0000000000d1','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-00000000000a','a5000000-0000-0000-0000-0000000000c1','issued','Alpha issued','BK-PAX5-2'),
  ('a5000000-0000-0000-0000-0000000000f3','a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-00000000000a','a5000000-0000-0000-0000-0000000000c1','a5000000-0000-0000-0000-0000000000d1','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-00000000000a','a5000000-0000-0000-0000-0000000000c1','void','Alpha void','BK-PAX5-3'),
  ('a5000000-0000-0000-0000-0000000000f9','a5000000-0000-0000-0000-000000000002','a5000000-0000-0000-0000-00000000000b','a5000000-0000-0000-0000-0000000000c2','a5000000-0000-0000-0000-0000000000d2',null,'a5000000-0000-0000-0000-00000000000b','a5000000-0000-0000-0000-0000000000c2','issued','Rival issued','BK-PAX5-9');

insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code, is_archived,
    owner_user_id, sales_owner_user_id, operational_owner_user_id, owner_branch_id, owner_department_id, currency_code) values
  ('a5000000-0000-0000-0000-0000000000e1','a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-0000000000f1','flight_ticket','draft',false,'a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-00000000000a','a5000000-0000-0000-0000-0000000000c1','EGP'),
  ('a5000000-0000-0000-0000-0000000000e2','a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-0000000000f2','flight_ticket','confirmed',false,'a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-00000000000a','a5000000-0000-0000-0000-0000000000c1','EGP'),
  ('a5000000-0000-0000-0000-0000000000e3','a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-0000000000f3','flight_ticket','confirmed',false,'a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-000000000011','a5000000-0000-0000-0000-00000000000a','a5000000-0000-0000-0000-0000000000c1','EGP'),
  ('a5000000-0000-0000-0000-0000000000e9','a5000000-0000-0000-0000-000000000002','a5000000-0000-0000-0000-0000000000f9','flight_ticket','confirmed',false,null,null,null,'a5000000-0000-0000-0000-00000000000b','a5000000-0000-0000-0000-0000000000c2','EGP');

insert into public.passengers (id, tenant_id, first_name, family_name, full_name, passenger_type_code) values
  ('a5000000-0000-0000-0000-00000000aaa1','a5000000-0000-0000-0000-000000000001','Ahmed','Original','Ahmed Original','adult'),
  ('a5000000-0000-0000-0000-00000000aaa2','a5000000-0000-0000-0000-000000000001','Mona','Replacement','Mona Replacement','adult'),
  ('a5000000-0000-0000-0000-00000000aaa3','a5000000-0000-0000-0000-000000000001','Sara','Third','Sara Third','adult'),
  ('a5000000-0000-0000-0000-00000000aaa9','a5000000-0000-0000-0000-000000000002','Rival','Traveller','Rival Traveller','adult');

insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id) values
  ('a5000000-0000-0000-0000-0000000000b1','a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-0000000000e1','a5000000-0000-0000-0000-00000000aaa1'),
  ('a5000000-0000-0000-0000-0000000000b2','a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-0000000000e2','a5000000-0000-0000-0000-00000000aaa1'),
  ('a5000000-0000-0000-0000-0000000000b3','a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-0000000000e3','a5000000-0000-0000-0000-00000000aaa1'),
  ('a5000000-0000-0000-0000-0000000000b9','a5000000-0000-0000-0000-000000000002','a5000000-0000-0000-0000-0000000000e9','a5000000-0000-0000-0000-00000000aaa9');

-- =============================================================================================
-- 1-5. THE VOCABULARY AND THE BUNDLE -- where `issued` lives, and who may correct after it.
-- =============================================================================================
select is(
  (select string_agg(distinct to_status, ',' order by to_status)
     from app.status_transitions
    where table_name = 'bookings' and from_status = 'issued'),
  'completed,refunded,reissue,void',
  'THE FROZEN SET IS READ, NOT INVENTED: `issued` is a BOOKING status and the states reachable from it are exactly completed/refunded/reissue/void. booking_item_base_status has no `issued` value at all.');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname in ('app','public') and p.prokind = 'f'
      and pg_get_functiondef(p.oid) ~ 'set[^;]*issued_at'),
  0,
  '...and booking_items.issued_at is NOT the signal: no function in the database writes that column, so a freeze hung on it would never engage');

select is(
  (select string_agg(r.code, ',' order by r.code)
     from public.role_permissions rp
     join public.roles r on r.id = rp.role_id
     join public.permissions p on p.id = rp.permission_id
    where p.key = 'CORRECT_PASSENGER_MANIFEST'),
  'branch_manager,ceo,finance_manager,owner',
  'the capability is seeded to the REISSUE_BOOKING bundle -- the closest existing post-issue correction authority');

select isnt(
  (select string_agg(r.code, ',' order by r.code) from public.role_permissions rp
     join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id
    where p.key = 'CORRECT_PASSENGER_MANIFEST'),
  (select string_agg(r.code, ',' order by r.code) from public.role_permissions rp
     join public.roles r on r.id = rp.role_id join public.permissions p on p.id = rp.permission_id
    where p.key = 'CREATE_BOOKING_ITEM'),
  'AND IT IS NOT CREATE_BOOKING_ITEM''S BUNDLE: if it were, the freeze would restrict nobody -- an employee building a manifest holds that one');

select is(
  (select string_agg(code, ',' order by code) from public.catalog_values
    where catalog_type_code = 'event_type' and code like 'booking_item_passenger%'),
  'booking_item_passenger_linked,booking_item_passenger_removed,booking_item_passenger_replaced',
  'PAX-6: the three manifest event types are registered. Test 104 assertion 41 asserted this vocabulary''s ABSENCE and has been updated in the same change, which is exactly the demand it was written to make.');

-- =============================================================================================
-- 6-10. BEFORE ISSUANCE: nothing got harder, and every change is now visible.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"a5000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('CREATE_BOOKING_ITEM') and not app.has_permission('CORRECT_PASSENGER_MANIFEST'),
  'POSITIVE/NEGATIVE CONTROL: the employee genuinely holds CREATE_BOOKING_ITEM and genuinely lacks CORRECT_PASSENGER_MANIFEST');

select lives_ok(
  $q$update public.booking_item_passengers set passenger_id = 'a5000000-0000-0000-0000-00000000aaa2'
      where id = 'a5000000-0000-0000-0000-0000000000b1'$q$,
  'THE ONE THAT MATTERS: before issuance an ordinary employee still corrects the manifest -- PAX-5 must not make normal pre-departure work harder');

select is(
  (select passenger_id::text || '/' || coalesce(passenger_corrected_by::text,'unstamped')
     from public.booking_item_passengers where id = 'a5000000-0000-0000-0000-0000000000b1'),
  'a5000000-0000-0000-0000-00000000aaa2/unstamped',
  '...the swap really happened (not a no-op), and it left NO post-issue correction trail -- an ordinary pre-issue edit must not look like a correction after the fact');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'booking_item_passenger_replaced'
      and entity_id = 'a5000000-0000-0000-0000-0000000000e1'
      and previous_state = 'a5000000-0000-0000-0000-00000000aaa1'
      and new_state = 'a5000000-0000-0000-0000-00000000aaa2'),
  1,
  'PAX-6 ON THE TABLE DOOR: the swap emitted exactly one booking_item_passenger_replaced carrying both identities -- measured at 0 before this change, through either door');

select lives_ok(
  $q$update public.booking_item_passengers set selling_amount_override = 500
      where id = 'a5000000-0000-0000-0000-0000000000b1'$q$,
  'NO NOISE: editing a financial override is not a manifest change');

-- =============================================================================================
-- 11-16. AT AND AFTER ISSUANCE: the freeze.
-- =============================================================================================
select is(
  (select string_agg(event_type_code, ',' order by event_type_code) from public.events
    where event_type_code like 'booking_item_passenger%'
      and entity_id = 'a5000000-0000-0000-0000-0000000000e1'),
  'booking_item_passenger_linked,booking_item_passenger_replaced',
  '...and it produced NO event: this item''s ledger holds exactly two -- the link created in the fixture and the swap from assertion 9 -- and the override edit added nothing');

select throws_ok(
  $q$update public.booking_item_passengers set passenger_id = 'a5000000-0000-0000-0000-00000000aaa2'
      where id = 'a5000000-0000-0000-0000-0000000000b2'$q$,
  '42501', NULL,
  'THE REPRODUCTION, CLOSED: the same employee cannot rewrite who flies on an ISSUED booking through the table door -- this succeeded before PAX-5, because the lifecycle guard returned early for a same-item update');

select throws_ok(
  $q$select app.correct_passenger_manifest('a5000000-0000-0000-0000-0000000000b2','a5000000-0000-0000-0000-00000000aaa2','typo in the name')$q$,
  '42501', NULL,
  '...and the RPC refuses the same actor identically: the sanctioned path is not a way around the capability');

select throws_ok(
  $q$update public.booking_item_passengers set passenger_id = 'a5000000-0000-0000-0000-00000000aaa2'
      where id = 'a5000000-0000-0000-0000-0000000000b3'$q$,
  '42501', NULL,
  'STATE BOUNDARY: `void` -- reachable only from `issued` -- is frozen too, so the freeze covers the states after issuance and not just the instant of it');

select is(
  (select passenger_id::text from public.booking_item_passengers where id = 'a5000000-0000-0000-0000-0000000000b2'),
  'a5000000-0000-0000-0000-00000000aaa1',
  'GROUND TRUTH after the refusals: the issued manifest still names the original traveller');

select is(
  (select count(*)::int from information_schema.role_table_grants
    where table_schema = 'public' and table_name = 'booking_item_passengers'
      and grantee = 'authenticated' and privilege_type = 'DELETE'),
  0,
  'NO TWO-STEP BYPASS: `authenticated` holds no DELETE here, so a frozen link cannot be removed and re-added to achieve the swap the freeze refuses');

-- =============================================================================================
-- 17-23. THE SANCTIONED CORRECTION.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"a5000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('CORRECT_PASSENGER_MANIFEST') and not app.has_permission('CREATE_BOOKING_ITEM'),
  'THE CONTAINMENT CASE, PROVEN TO EXIST: finance_manager holds CORRECT_PASSENGER_MANIFEST and NOT CREATE_BOOKING_ITEM -- so the object-class door had to be widened or this holder could never reach the enforcer');

select throws_ok(
  $q$select app.correct_passenger_manifest('a5000000-0000-0000-0000-0000000000b2','a5000000-0000-0000-0000-00000000aaa2','   ')$q$,
  'P0001', NULL,
  'a blank reason is refused before anything is touched: the reason is mandatory, not merely a column that exists');

select throws_ok(
  $q$update public.booking_item_passengers set passenger_id = 'a5000000-0000-0000-0000-00000000aaa2'
      where id = 'a5000000-0000-0000-0000-0000000000b2'$q$,
  '23514', NULL,
  'AND THE TABLE DOOR DEMANDS IT TOO: a capability holder swapping without a reason is refused, so the two doors record the same facts (ARCH-2''s settled position, one table over)');

select lives_ok(
  $q$select app.correct_passenger_manifest('a5000000-0000-0000-0000-0000000000b2','a5000000-0000-0000-0000-00000000aaa2','passport name mismatch found at check-in')$q$,
  'THE SANCTIONED PATH WORKS: capability plus reason corrects an issued manifest');

select is(
  (select passenger_id::text || '|' || passenger_correction_reason || '|' || passenger_corrected_by::text
     from public.booking_item_passengers where id = 'a5000000-0000-0000-0000-0000000000b2'),
  'a5000000-0000-0000-0000-00000000aaa2|passport name mismatch found at check-in|a5000000-0000-0000-0000-000000000012',
  '...and the row carries the new traveller, the reason, and the SERVER-STAMPED actor');

select is(
  (select previous_state || ' -> ' || new_state || ' : ' || reason
     from public.events
    where event_type_code = 'booking_item_passenger_replaced'
      and entity_id = 'a5000000-0000-0000-0000-0000000000e2'),
  'a5000000-0000-0000-0000-00000000aaa1 -> a5000000-0000-0000-0000-00000000aaa2 : passport name mismatch found at check-in',
  'PAX-6: the correction emitted ONE event carrying the previous passenger, the new passenger and the reason');

select throws_ok(
  $q$update public.booking_item_passengers set passenger_correction_reason = 'a nicer reason'
      where id = 'a5000000-0000-0000-0000-0000000000b2'$q$,
  '23514', NULL,
  'THE EVIDENCE IS NOT EDITABLE ON ITS OWN: the reason a manifest was corrected cannot be rewritten after the fact, and attribution cannot be forged');

-- =============================================================================================
-- 24-25. TENANT BOUNDARY, and ONE PRODUCER.
-- =============================================================================================
select throws_ok(
  $q$select app.correct_passenger_manifest('a5000000-0000-0000-0000-0000000000b9','a5000000-0000-0000-0000-00000000aaa2','borrowing another agency''s manifest')$q$,
  'P0001', NULL,
  'TENANT BOUNDARY: the correction RPC cannot reach another tenant''s manifest entry');

reset role;
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.prokind = 'f'
      and p.proname <> 'record_manifest_change_event'
      and pg_get_functiondef(p.oid) ~ 'record_event\([^;]*booking_item_passenger_'),
  0,
  'ONE PRODUCER: app.record_manifest_change_event is the only emitter of these three types, so the RPC and the table door cannot double-count a single change');

-- =============================================================================================
-- 26-28. LOAD-BEARING (PAR-4 defect injection), both enforcers.
-- =============================================================================================
savepoint before_enforcer_mutation;
drop trigger booking_item_passengers_enforce_lifecycle on public.booking_item_passengers;
select set_config('request.jwt.claims','{"sub":"a5000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $q$update public.booking_item_passengers set passenger_id = 'a5000000-0000-0000-0000-00000000aaa3'
      where id = 'a5000000-0000-0000-0000-0000000000b2'$q$,
  'MUTATION: with the lifecycle trigger dropped the employee''s post-issue swap SUCCEEDS again -- so that trigger is what enforces PAX-5, and nothing else was doing it');

rollback to savepoint before_enforcer_mutation;
-- set_config(..., true) is transaction-local, so the rollback reverted the claims too. Re-establish
-- the SAME actor, or the restore assertion would be testing a different caller than the mutation did.
select set_config('request.jwt.claims','{"sub":"a5000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $q$update public.booking_item_passengers set passenger_id = 'a5000000-0000-0000-0000-00000000aaa3'
      where id = 'a5000000-0000-0000-0000-0000000000b2'$q$,
  '42501', NULL,
  'RESTORED: with the trigger back the identical swap is refused again');

reset role;
savepoint before_event_mutation;
drop trigger booking_item_passengers_record_manifest_event on public.booking_item_passengers;
insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
values ('a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-0000000000e1','a5000000-0000-0000-0000-00000000aaa3');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'booking_item_passenger_linked'
      and entity_id = 'a5000000-0000-0000-0000-0000000000e1'
      and new_state = 'a5000000-0000-0000-0000-00000000aaa3'),
  0,
  'MUTATION: with the event trigger dropped, linking a NEW traveller produces no event at all -- which is PAX-6 exactly, so that trigger is what closes it');

rollback to savepoint before_event_mutation;

insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
values ('a5000000-0000-0000-0000-000000000001','a5000000-0000-0000-0000-0000000000e1','a5000000-0000-0000-0000-00000000aaa3');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'booking_item_passenger_linked'
      and entity_id = 'a5000000-0000-0000-0000-0000000000e1'
      and new_state = 'a5000000-0000-0000-0000-00000000aaa3'),
  1,
  'RESTORED: with the trigger back the identical link emits exactly one booking_item_passenger_linked');

select finish();
rollback;
