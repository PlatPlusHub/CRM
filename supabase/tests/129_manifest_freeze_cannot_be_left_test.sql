-- ATTACK-CLASSES: AUTH DOOR PRIVILEGE STATE BUSINESS TENANT=N/A INPUT=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
-- SPEC-224 / PAX-9. Once a booking's manifest has frozen (PAX-5), nobody changes who is on it except
-- by the attributed correction -- CORRECT_PASSENGER_MANIFEST, a fresh reason, a server stamp -- and
-- that holds for every door the invariant has: an entry inserted, moved in or moved out, and an item
-- moved in or out. Every refusal is pinned to its own message, so a refusal from another authority
-- cannot pass. The finance manager (the correction without CREATE_BOOKING_ITEM) reaches the
-- correction and nothing more. The mutation removes `issued` from app.manifest_is_frozen and shows
-- every operation it owns reopen, then restores it byte-identically.
-- OBSERVABILITY=N/A as an attack class: the correction's event evidence is asserted, but the gap
-- this file closes is authority, not a missing producer.
create extension if not exists pgtap with schema extensions;

begin;
select plan(49);

insert into auth.users (id, email) values
  ('12900000-0000-0000-0000-0000000000a1','emp@pax9.test'),
  ('12900000-0000-0000-0000-0000000000a2','fin@pax9.test'),
  ('12900000-0000-0000-0000-0000000000a3','mgr@pax9.test');
insert into public.tenants (id, name, slug, status) values
  ('12900000-0000-0000-0000-000000000001','PAX9 Travel','pax9-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '12900000-0000-0000-0000-000000000001', id, 'active'
from public.subscription_plans where plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('12900000-0000-0000-0000-00000000000a','12900000-0000-0000-0000-000000000001','Cairo','pax9-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('12900000-0000-0000-0000-0000000000c1','12900000-0000-0000-0000-000000000001','12900000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('12900000-0000-0000-0000-000000000011','12900000-0000-0000-0000-000000000001','Emp','emp@pax9.test',true,'12900000-0000-0000-0000-0000000000a1'),
  ('12900000-0000-0000-0000-000000000012','12900000-0000-0000-0000-000000000001','Fin','fin@pax9.test',true,'12900000-0000-0000-0000-0000000000a2'),
  ('12900000-0000-0000-0000-000000000013','12900000-0000-0000-0000-000000000001','Mgr','mgr@pax9.test',true,'12900000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '12900000-0000-0000-0000-000000000001', u, '12900000-0000-0000-0000-00000000000a','12900000-0000-0000-0000-0000000000c1', true
from unnest(array['12900000-0000-0000-0000-000000000011'::uuid,
                  '12900000-0000-0000-0000-000000000012'::uuid,
                  '12900000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '12900000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('12900000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('12900000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('12900000-0000-0000-0000-000000000013'::uuid,'branch_manager')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('12900000-0000-0000-0000-0000000000d1','12900000-0000-0000-0000-000000000001','person','PAX9 Cust');
-- f1 and f5 stay draft; f2 is built draft, gets its travellers, and is then issued -- the only order
-- in which a frozen manifest can now be built on any path.
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
    owner_branch_id, owner_department_id, booking_status_code, title, booking_reference)
select v.id, '12900000-0000-0000-0000-000000000001','12900000-0000-0000-0000-00000000000a','12900000-0000-0000-0000-0000000000c1',
       '12900000-0000-0000-0000-0000000000d1','12900000-0000-0000-0000-000000000011','12900000-0000-0000-0000-00000000000a',
       '12900000-0000-0000-0000-0000000000c1','draft', v.t, v.r
from (values ('12900000-0000-0000-0000-0000000000f1'::uuid,'PAX9 draft','BK-PAX9-1'),
             ('12900000-0000-0000-0000-0000000000f2'::uuid,'PAX9 issued','BK-PAX9-2'),
             ('12900000-0000-0000-0000-0000000000f5'::uuid,'PAX9 second draft','BK-PAX9-5')) v(id,t,r);
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code, is_archived,
    owner_user_id, sales_owner_user_id, operational_owner_user_id, owner_branch_id, owner_department_id, currency_code)
select v.id, '12900000-0000-0000-0000-000000000001', v.bk, 'flight_ticket', 'draft', false,
       '12900000-0000-0000-0000-000000000011','12900000-0000-0000-0000-000000000011','12900000-0000-0000-0000-000000000011',
       '12900000-0000-0000-0000-00000000000a','12900000-0000-0000-0000-0000000000c1','EGP'
from (values ('12900000-0000-0000-0000-0000000000e1'::uuid,'12900000-0000-0000-0000-0000000000f1'::uuid),
             ('12900000-0000-0000-0000-0000000000e2'::uuid,'12900000-0000-0000-0000-0000000000f2'::uuid),
             ('12900000-0000-0000-0000-0000000000e5'::uuid,'12900000-0000-0000-0000-0000000000f1'::uuid),
             ('12900000-0000-0000-0000-0000000000e6'::uuid,'12900000-0000-0000-0000-0000000000f5'::uuid),
             ('12900000-0000-0000-0000-0000000000e7'::uuid,'12900000-0000-0000-0000-0000000000f5'::uuid),
             ('12900000-0000-0000-0000-0000000000e8'::uuid,'12900000-0000-0000-0000-0000000000f5'::uuid)) v(id,bk);
insert into public.passengers (id, tenant_id, first_name, family_name, full_name, passenger_type_code)
select v.id, '12900000-0000-0000-0000-000000000001', v.f, v.l, v.f||' '||v.l, 'adult'
from (values ('12900000-0000-0000-0000-00000000aaa1'::uuid,'Ahmed','One'),
             ('12900000-0000-0000-0000-00000000aaa2'::uuid,'Mona','Two'),
             ('12900000-0000-0000-0000-00000000aaa3'::uuid,'Sara','Three'),
             ('12900000-0000-0000-0000-00000000aaa4'::uuid,'Dina','Four'),
             ('12900000-0000-0000-0000-00000000aaa5'::uuid,'Eman','Five'),
             ('12900000-0000-0000-0000-00000000aaa6'::uuid,'Farid','Six'),
             ('12900000-0000-0000-0000-00000000aaa7'::uuid,'Gamal','Seven'),
             ('12900000-0000-0000-0000-00000000aaa8'::uuid,'Hoda','Eight')) v(id,f,l);
insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id)
select v.id, '12900000-0000-0000-0000-000000000001', v.i, v.p
from (values ('12900000-0000-0000-0000-0000000000b1'::uuid,'12900000-0000-0000-0000-0000000000e1'::uuid,'12900000-0000-0000-0000-00000000aaa1'::uuid),
             ('12900000-0000-0000-0000-0000000000b2'::uuid,'12900000-0000-0000-0000-0000000000e2'::uuid,'12900000-0000-0000-0000-00000000aaa1'::uuid),
             ('12900000-0000-0000-0000-0000000000b3'::uuid,'12900000-0000-0000-0000-0000000000e2'::uuid,'12900000-0000-0000-0000-00000000aaa3'::uuid),
             ('12900000-0000-0000-0000-0000000000b6'::uuid,'12900000-0000-0000-0000-0000000000e6'::uuid,'12900000-0000-0000-0000-00000000aaa2'::uuid),
             ('12900000-0000-0000-0000-0000000000b7'::uuid,'12900000-0000-0000-0000-0000000000e7'::uuid,'12900000-0000-0000-0000-00000000aaa4'::uuid)) v(id,i,p);
update public.bookings set booking_status_code = 'issued' where id = '12900000-0000-0000-0000-0000000000f2';

create temp table s129 (k text primary key, v text) on commit drop;
grant all on s129 to authenticated;

-- ================================================================================================
-- 1-4. The helper and the population.
-- ================================================================================================
select is(array[(select provolatile::text from pg_proc where oid = 'app.manifest_is_frozen(text,boolean)'::regprocedure),
                (select prosecdef::text from pg_proc where oid = 'app.manifest_is_frozen(text,boolean)'::regprocedure),
                has_function_privilege('authenticated','app.manifest_is_frozen(text,boolean)','EXECUTE')::text,
                has_function_privilege('anon','app.manifest_is_frozen(text,boolean)','EXECUTE')::text],
  array['i','false','false','false'],
  'app.manifest_is_frozen is an internal IMMUTABLE predicate nobody but its owner can execute');
select is(array[app.manifest_is_frozen('issued', false), app.manifest_is_frozen('reissue', false),
                app.manifest_is_frozen('refunded', false), app.manifest_is_frozen('void', false),
                app.manifest_is_frozen('completed', false), app.manifest_is_frozen('draft', true),
                app.manifest_is_frozen('draft', false), app.manifest_is_frozen('confirmed', false),
                app.manifest_is_frozen('in_progress', false)],
  array[true,true,true,true,true,true,false,false,false],
  '...and it encodes exactly PAX-5''s freeze: an archived booking, or issued and every state reachable from it');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
insert into s129 values ('fin', app.has_permission('CORRECT_PASSENGER_MANIFEST')::text||'/'||app.has_permission('CREATE_BOOKING_ITEM')::text);
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
insert into s129 values ('mgr', app.has_permission('CORRECT_PASSENGER_MANIFEST')::text||'/'||app.has_permission('CREATE_BOOKING_ITEM')::text);
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select is(array[app.has_permission('CORRECT_PASSENGER_MANIFEST')::text||'/'||app.has_permission('CREATE_BOOKING_ITEM')::text,
                (select count(*)::text from public.booking_item_passengers
                  where booking_item_id = '12900000-0000-0000-0000-0000000000e2')],
  array['false/true','2'],
  'CONTROL: the employee builds manifests (CREATE_BOOKING_ITEM), cannot correct them, and sees the issued item''s two entries');
reset role;
select is(array[(select v from s129 where k='fin'), (select v from s129 where k='mgr')], array['true/false','true/true'],
  'CONTROL: the finance manager holds the correction and not CREATE_BOOKING_ITEM; the branch manager holds both');

-- ================================================================================================
-- 5-12. OUT: an item never leaves; an entry leaves only by the correction.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok($$update public.booking_items set booking_id = '12900000-0000-0000-0000-0000000000f1'
                    where id = '12900000-0000-0000-0000-0000000000e2'$$,
  '23514', 'a booking item cannot leave a booking whose passenger manifest has frozen',
  'PAX-9: the employee cannot carry the issued booking''s item out');
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok($$update public.booking_items set booking_id = '12900000-0000-0000-0000-0000000000f1'
                    where id = '12900000-0000-0000-0000-0000000000e2'$$,
  '23514', 'a booking item cannot leave a booking whose passenger manifest has frozen',
  '...nor can a correction holder: an item carries no reason to authorize it with');
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e5'
                    where id = '12900000-0000-0000-0000-0000000000b3'$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  'PAX-9: the employee cannot move an entry off the frozen manifest');
select throws_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e5',
                    passenger_correction_reason = 'employee says so' where id = '12900000-0000-0000-0000-0000000000b3'$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  '...not even by manufacturing correction evidence');
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select throws_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e5'
                    where id = '12900000-0000-0000-0000-0000000000b3'$$,
  '23514', 'joining or leaving a frozen passenger manifest requires its own reason',
  'the finance manager reaches the correction, which still demands a reason');
select lives_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e5',
                   passenger_correction_reason = 'finance: traveller moved to the re-planned trip'
                   where id = '12900000-0000-0000-0000-0000000000b3'$$,
  'the finance manager moves an entry off the frozen manifest with a fresh reason');
reset role;
select is((select array[right(booking_item_id::text, 2), (passenger_corrected_by = '12900000-0000-0000-0000-000000000012')::text,
                        (passenger_corrected_at is not null)::text, passenger_correction_reason]
             from public.booking_item_passengers where id = '12900000-0000-0000-0000-0000000000b3'),
  array['e5','true','true','finance: traveller moved to the re-planned trip'],
  '...stamped by the server with the finance manager');
select is((select reason from public.events where event_type_code = 'booking_item_passenger_replaced'
             and payload->>'booking_item_passenger_id' = '12900000-0000-0000-0000-0000000000b3' order by seq desc limit 1),
  'finance: traveller moved to the re-planned trip', '...and its replaced event carries the reason');

-- ================================================================================================
-- 13-17. IN BY MOVE: an entry joins the frozen manifest only by the correction.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e2'
                    where id = '12900000-0000-0000-0000-0000000000b6'$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  'PAX-9: the employee cannot move an entry onto the frozen manifest');
select throws_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e2',
                    passenger_correction_reason = 'employee says so' where id = '12900000-0000-0000-0000-0000000000b6'$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  '...not even with manufactured evidence');
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e2'
                    where id = '12900000-0000-0000-0000-0000000000b6'$$,
  '23514', 'joining or leaving a frozen passenger manifest requires its own reason',
  'a correction holder moving an entry on needs a reason');
select lives_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e2',
                   passenger_correction_reason = 'manager: traveller added to the ticketed service'
                   where id = '12900000-0000-0000-0000-0000000000b6'$$,
  '...and with one, the entry joins the frozen manifest');
reset role;
select is((select array[right(booking_item_id::text, 2), (passenger_corrected_by = '12900000-0000-0000-0000-000000000013')::text]
             from public.booking_item_passengers where id = '12900000-0000-0000-0000-0000000000b6'),
  array['e2','true'], '...stamped by the server with the branch manager');

-- ================================================================================================
-- 18-25. IN BY INSERT: a new traveller joins the frozen manifest only by the correction; before the
-- freeze an insertion is ordinary manifest-building.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok($$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id)
                    values ('12900000-0000-0000-0000-0000000000b8','12900000-0000-0000-0000-000000000001',
                            '12900000-0000-0000-0000-0000000000e2','12900000-0000-0000-0000-00000000aaa5')$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  'PAX-9: the employee cannot add a traveller to the frozen manifest');
select throws_ok($$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id, passenger_correction_reason)
                    values ('12900000-0000-0000-0000-0000000000b8','12900000-0000-0000-0000-000000000001',
                            '12900000-0000-0000-0000-0000000000e2','12900000-0000-0000-0000-00000000aaa5','employee says so')$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  '...not even with manufactured evidence');
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select throws_ok($$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id)
                    values ('12900000-0000-0000-0000-0000000000b8','12900000-0000-0000-0000-000000000001',
                            '12900000-0000-0000-0000-0000000000e2','12900000-0000-0000-0000-00000000aaa5')$$,
  '23514', 'joining or leaving a frozen passenger manifest requires its own reason',
  'the finance manager adding a traveller after issue needs a reason');
select lives_ok($$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id, passenger_correction_reason)
                   values ('12900000-0000-0000-0000-0000000000b8','12900000-0000-0000-0000-000000000001',
                           '12900000-0000-0000-0000-0000000000e2','12900000-0000-0000-0000-00000000aaa5',
                           'finance: late traveller ticketed')$$,
  '...and with one, the traveller joins the frozen manifest');
reset role;
select is((select array[event_type_code, coalesce(reason, 'NULL'),
                        (actor_user_id = '12900000-0000-0000-0000-000000000012')::text,
                        entity_type, entity_id::text]
             from public.events where payload->>'booking_item_passenger_id' = '12900000-0000-0000-0000-0000000000b8'),
  array['booking_item_passenger_linked','finance: late traveller ticketed','true','booking_item','12900000-0000-0000-0000-0000000000e2'],
  'the post-issue linked event carries the correction reason, the server-derived actor and the entry''s linkage');
select is((select (passenger_corrected_by = '12900000-0000-0000-0000-000000000012' and passenger_corrected_at is not null)::text
             from public.booking_item_passengers where id = '12900000-0000-0000-0000-0000000000b8'),
  'true', '...and the entry itself is stamped by the server');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id)
                   values ('12900000-0000-0000-0000-0000000000b9','12900000-0000-0000-0000-000000000001',
                           '12900000-0000-0000-0000-0000000000e5','12900000-0000-0000-0000-00000000aaa6')$$,
  'before the freeze the employee still builds the manifest under CREATE_BOOKING_ITEM');
reset role;
select is((select array[e.event_type_code, coalesce(e.reason, 'NULL'), (b.passenger_corrected_at is null and b.passenger_corrected_by is null)::text]
             from public.events e join public.booking_item_passengers b on b.id = '12900000-0000-0000-0000-0000000000b9'
            where e.payload->>'booking_item_passenger_id' = '12900000-0000-0000-0000-0000000000b9'),
  array['booking_item_passenger_linked','NULL','true'],
  '...recorded as an ordinary linked event with no reason and no correction stamp');

-- ================================================================================================
-- 26-31. No correction evidence at birth; no relocation door for the finance manager.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok($$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id,
                      passenger_correction_reason, passenger_corrected_by, passenger_corrected_at)
                    values ('12900000-0000-0000-0000-0000000000ba','12900000-0000-0000-0000-000000000001',
                            '12900000-0000-0000-0000-0000000000e8','12900000-0000-0000-0000-00000000aaa3',
                            'approved by the manager','12900000-0000-0000-0000-000000000013','2020-01-01')$$,
  '23514', 'manifest correction evidence is not editable on its own',
  'a "corrected by the manager" record cannot be forged at birth');
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select throws_ok($$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id, passenger_correction_reason)
                    values ('12900000-0000-0000-0000-0000000000ba','12900000-0000-0000-0000-000000000001',
                            '12900000-0000-0000-0000-0000000000e8','12900000-0000-0000-0000-00000000aaa3','finance')$$,
  '23514', 'manifest correction evidence is not editable on its own',
  'a finance manager''s reason buys no pre-issue insertion');
select throws_ok($$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id)
                    values ('12900000-0000-0000-0000-0000000000ba','12900000-0000-0000-0000-000000000001',
                            '12900000-0000-0000-0000-0000000000e8','12900000-0000-0000-0000-00000000aaa3')$$,
  '42501', 'permission denied: one of CREATE_BOOKING_ITEM is required to write booking_item_passengers',
  '...and without one the object-class authority refuses it');
select throws_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e8',
                    passenger_correction_reason = 'finance relocation' where id = '12900000-0000-0000-0000-0000000000b7'$$,
  '23514', 'manifest correction evidence is not editable on its own',
  'a finance manager''s reason buys no move between unfrozen items');
select throws_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e8'
                    where id = '12900000-0000-0000-0000-0000000000b7'$$,
  '42501', 'permission denied: one of CREATE_BOOKING_ITEM is required to write booking_item_passengers',
  '...and without one the object-class authority refuses it');
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e8'
                   where id = '12900000-0000-0000-0000-0000000000b7'$$,
  'the employee still moves an entry between unfrozen items');

-- ================================================================================================
-- 32-34. IN BY ITEM: a traveller-carrying item cannot join; an empty one can.
-- ================================================================================================
select throws_ok($$update public.booking_items set booking_id = '12900000-0000-0000-0000-0000000000f2'
                    where id = '12900000-0000-0000-0000-0000000000e8'$$,
  '23514', 'a booking item carrying passengers cannot join a booking whose passenger manifest has frozen',
  'PAX-9: an item carrying a traveller cannot join the issued booking');
select lives_ok($$update public.booking_items set booking_id = '12900000-0000-0000-0000-0000000000f2'
                   where id = '12900000-0000-0000-0000-0000000000e7'$$,
  'an EMPTY item may still join an issued booking (a post-issue service addition, as create_booking_item allows)');
select lives_ok($$update public.booking_items set booking_id = '12900000-0000-0000-0000-0000000000f5'
                   where id = '12900000-0000-0000-0000-0000000000e5'$$,
  'a draft item still moves between draft bookings');

-- ================================================================================================
-- 35-37. PAX-5 and PAX-7 unchanged.
-- ================================================================================================
select throws_ok($$update public.booking_item_passengers set passenger_id = '12900000-0000-0000-0000-00000000aaa7',
                    passenger_correction_reason = 'swap' where id = '12900000-0000-0000-0000-0000000000b2'$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  'PAX-5 unchanged: the employee cannot swap the traveller on the frozen manifest');
select lives_ok($$update public.passengers set full_name = 'Ahmed Renamed' where id = '12900000-0000-0000-0000-00000000aaa1'$$,
  'PAX-7 unchanged: the profile stays editable after issue...');
reset role;
select is((select manifest_full_name from public.booking_item_passengers where id = '12900000-0000-0000-0000-0000000000b2'),
  'Ahmed One', '...and the frozen entry keeps the identity it was ticketed under');

-- ================================================================================================
-- 38-41. The platform path gets no exemption (BOOK-1).
-- ================================================================================================
select set_config('request.jwt.claims', '', true);
select throws_ok($$update public.booking_items set booking_id = '12900000-0000-0000-0000-0000000000f1'
                    where id = '12900000-0000-0000-0000-0000000000e2'$$,
  '23514', 'a booking item cannot leave a booking whose passenger manifest has frozen',
  'a session-less caller cannot carry the issued booking''s item out');
select throws_ok($$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id)
                    values ('12900000-0000-0000-0000-0000000000bb','12900000-0000-0000-0000-000000000001',
                            '12900000-0000-0000-0000-0000000000e2','12900000-0000-0000-0000-00000000aaa7')$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  '...nor add a traveller to the frozen manifest');
select throws_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e1'
                    where id = '12900000-0000-0000-0000-0000000000b2'$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  '...nor move an entry off it');
select is((select string_agg(p.first_name, ',' order by p.first_name)
             from public.booking_item_passengers b
             join public.booking_items bi on bi.id = b.booking_item_id
             join public.passengers p on p.id = b.passenger_id
            where bi.booking_id = '12900000-0000-0000-0000-0000000000f2'),
  'Ahmed,Eman,Mona',
  'after every refusal the issued booking holds exactly its original traveller plus the two attributed corrections');

-- ================================================================================================
-- 42-49. MUTATION: without `issued` in the one predicate, every operation it owns reopens.
-- ================================================================================================
insert into s129 select 'def', pg_get_functiondef('app.manifest_is_frozen(text,boolean)'::regprocedure);
create or replace function app.manifest_is_frozen(p_booking_status text, p_booking_archived boolean)
returns boolean language sql immutable set search_path = '' as
$fn$ select p_booking_archived or p_booking_status = any (array['reissue','refunded','void','completed']) $fn$;
select is(array[(position('''issued''' in pg_get_functiondef('app.manifest_is_frozen(text,boolean)'::regprocedure)) = 0),
                app.manifest_is_frozen('issued', false)],
  array[true,false], 'MUTANT INSTALLED: the predicate no longer names or answers issued');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id)
                   values ('12900000-0000-0000-0000-0000000000bc','12900000-0000-0000-0000-000000000001',
                           '12900000-0000-0000-0000-0000000000e2','12900000-0000-0000-0000-00000000aaa7')$$,
  'MUTANT: the employee adds a traveller to the issued item');
select lives_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e1'
                   where id = '12900000-0000-0000-0000-0000000000b6'$$,
  'MUTANT: ...moves an entry off it');
select lives_ok($$update public.booking_item_passengers set booking_item_id = '12900000-0000-0000-0000-0000000000e2'
                   where id = '12900000-0000-0000-0000-0000000000b6'$$,
  'MUTANT: ...moves it back on');
select lives_ok($$update public.booking_item_passengers set passenger_id = '12900000-0000-0000-0000-00000000aaa8'
                   where id = '12900000-0000-0000-0000-0000000000b2'$$,
  'MUTANT: ...swaps its traveller');
select lives_ok($$update public.booking_items set booking_id = '12900000-0000-0000-0000-0000000000f2'
                   where id = '12900000-0000-0000-0000-0000000000e8'$$,
  'MUTANT: ...brings a traveller-carrying item in');
select lives_ok($$update public.booking_items set booking_id = '12900000-0000-0000-0000-0000000000f1'
                   where id = '12900000-0000-0000-0000-0000000000e2'$$,
  'MUTANT: ...and carries the issued item out');
reset role;
do $$ begin execute (select v from s129 where k = 'def'); end $$;
select is(pg_get_functiondef('app.manifest_is_frozen(text,boolean)'::regprocedure), (select v from s129 where k = 'def'),
  'RESTORED: the predicate is byte-identical to the installed one');

select finish();
rollback;
