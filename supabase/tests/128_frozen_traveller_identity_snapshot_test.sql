-- ATTACK-CLASSES: AUTH DOOR PRIVILEGE STATE BUSINESS TENANT=N/A INPUT=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
-- SPEC-223 / PAX-7. A manifest entry keeps the identity its traveller was ticketed under. Until the
-- PAX-5 freeze the entry's six manifest_* fields are re-derived from the reusable passengers profile
-- on every write; afterwards they change only by a swap or by an attributed correction
-- (CORRECT_PASSENGER_MANIFEST, a fresh reason, a server stamp), and profile edits no longer reach
-- them. Every refusal is pinned to its own message, so a refusal from another authority cannot pass.
-- The mutation disables the profile-propagation trigger and shows the draft entry going stale.
-- OBSERVABILITY=N/A: a post-freeze identity correction emits no event -- PAX-8, recorded OPEN and
-- pinned by the last assertion so this file cannot be read as having fixed it.
create extension if not exists pgtap with schema extensions;

begin;
select plan(43);

insert into auth.users (id, email) values
  ('12800000-0000-0000-0000-0000000000a1','emp@pax7.test'),
  ('12800000-0000-0000-0000-0000000000a2','fin@pax7.test'),
  ('12800000-0000-0000-0000-0000000000a3','mgr@pax7.test');
insert into public.tenants (id, name, slug, status) values
  ('12800000-0000-0000-0000-000000000001','PAX7 Travel','pax7-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '12800000-0000-0000-0000-000000000001', id, 'active'
from public.subscription_plans where plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('12800000-0000-0000-0000-00000000000a','12800000-0000-0000-0000-000000000001','Cairo','pax7-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('12800000-0000-0000-0000-0000000000c1','12800000-0000-0000-0000-000000000001','12800000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('12800000-0000-0000-0000-000000000011','12800000-0000-0000-0000-000000000001','Emp','emp@pax7.test',true,'12800000-0000-0000-0000-0000000000a1'),
  ('12800000-0000-0000-0000-000000000012','12800000-0000-0000-0000-000000000001','Fin','fin@pax7.test',true,'12800000-0000-0000-0000-0000000000a2'),
  ('12800000-0000-0000-0000-000000000013','12800000-0000-0000-0000-000000000001','Mgr','mgr@pax7.test',true,'12800000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '12800000-0000-0000-0000-000000000001', u, '12800000-0000-0000-0000-00000000000a','12800000-0000-0000-0000-0000000000c1', true
from unnest(array['12800000-0000-0000-0000-000000000011'::uuid,
                  '12800000-0000-0000-0000-000000000012'::uuid,
                  '12800000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '12800000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('12800000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('12800000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('12800000-0000-0000-0000-000000000013'::uuid,'branch_manager')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('12800000-0000-0000-0000-0000000000d1','12800000-0000-0000-0000-000000000001','person','PAX7 Cust');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
    owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('12800000-0000-0000-0000-0000000000f1','12800000-0000-0000-0000-000000000001','12800000-0000-0000-0000-00000000000a','12800000-0000-0000-0000-0000000000c1','12800000-0000-0000-0000-0000000000d1','12800000-0000-0000-0000-000000000011','12800000-0000-0000-0000-00000000000a','12800000-0000-0000-0000-0000000000c1','draft','PAX7 draft','BK-PAX7-1'),
  ('12800000-0000-0000-0000-0000000000f2','12800000-0000-0000-0000-000000000001','12800000-0000-0000-0000-00000000000a','12800000-0000-0000-0000-0000000000c1','12800000-0000-0000-0000-0000000000d1','12800000-0000-0000-0000-000000000011','12800000-0000-0000-0000-00000000000a','12800000-0000-0000-0000-0000000000c1','issued','PAX7 issued','BK-PAX7-2');
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code, is_archived,
    owner_user_id, sales_owner_user_id, operational_owner_user_id, owner_branch_id, owner_department_id, currency_code) values
  ('12800000-0000-0000-0000-0000000000e1','12800000-0000-0000-0000-000000000001','12800000-0000-0000-0000-0000000000f1','flight_ticket','draft',false,'12800000-0000-0000-0000-000000000011','12800000-0000-0000-0000-000000000011','12800000-0000-0000-0000-000000000011','12800000-0000-0000-0000-00000000000a','12800000-0000-0000-0000-0000000000c1','EGP'),
  ('12800000-0000-0000-0000-0000000000e2','12800000-0000-0000-0000-000000000001','12800000-0000-0000-0000-0000000000f2','flight_ticket','confirmed',false,'12800000-0000-0000-0000-000000000011','12800000-0000-0000-0000-000000000011','12800000-0000-0000-0000-000000000011','12800000-0000-0000-0000-00000000000a','12800000-0000-0000-0000-0000000000c1','EGP');
insert into public.passengers (id, tenant_id, first_name, family_name, full_name, passenger_type_code,
    date_of_birth, passport_number, passport_issuing_country_code) values
  ('12800000-0000-0000-0000-00000000aaa1','12800000-0000-0000-0000-000000000001','Ahmed','Original','Ahmed Original','adult','1980-01-01','A1000001','EG'),
  ('12800000-0000-0000-0000-00000000aaa2','12800000-0000-0000-0000-000000000001','Mona','Second','Mona Second','adult','1985-02-02','B2000002','EG'),
  ('12800000-0000-0000-0000-00000000aaa3','12800000-0000-0000-0000-000000000001','Sara','Third','Sara Third','adult','1990-03-03','C3000003','SA');
-- b1 on the draft booking, b2 and b3 on the issued one: the same traveller (A) sits on a draft AND an
-- issued entry, which is exactly the population the rule has to split.
insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id) values
  ('12800000-0000-0000-0000-0000000000b1','12800000-0000-0000-0000-000000000001','12800000-0000-0000-0000-0000000000e1','12800000-0000-0000-0000-00000000aaa1'),
  ('12800000-0000-0000-0000-0000000000b2','12800000-0000-0000-0000-000000000001','12800000-0000-0000-0000-0000000000e2','12800000-0000-0000-0000-00000000aaa1'),
  ('12800000-0000-0000-0000-0000000000b3','12800000-0000-0000-0000-000000000001','12800000-0000-0000-0000-0000000000e2','12800000-0000-0000-0000-00000000aaa3');

create temp table s128 (k text primary key, v text) on commit drop;
grant all on s128 to authenticated;
create function pg_temp.ident(p uuid) returns text language sql as
  $f$ select concat_ws('|', manifest_first_name, manifest_family_name, manifest_full_name,
                       manifest_date_of_birth::text, manifest_passport_number,
                       manifest_passport_issuing_country_code)
        from public.booking_item_passengers where id = p $f$;
create function pg_temp.prof(p uuid) returns text language sql as
  $f$ select concat_ws('|', first_name, family_name, full_name, date_of_birth::text, passport_number,
                       passport_issuing_country_code)
        from public.passengers where id = p $f$;

-- ================================================================================================
-- 1-5. The surface and the population.
-- ================================================================================================
select is((select count(*)::int from information_schema.columns
            where table_schema='public' and table_name='booking_item_passengers' and column_name like 'manifest\_%'),
  6, 'the manifest entry carries six ticketed-identity fields');
select is(array[has_column_privilege('authenticated','public.booking_item_passengers','manifest_passport_number','SELECT'),
                has_column_privilege('authenticated','public.booking_item_passengers','manifest_passport_number','UPDATE')],
  array[true,true], 'authenticated may read the ticketed identity (column SELECT) and correct it (UPDATE)');
select is((select t.tgtype::int || '/' || t.tgenabled::text || '/' || t.tgfoid::regproc::text
             from pg_trigger t where t.tgname = 'passengers_sync_manifest_identity'
              and t.tgrelid = 'public.passengers'::regclass),
  '17/O/app.sync_manifest_identity', 'profile edits propagate through one AFTER UPDATE row trigger, enabled');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12800000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select is(array[app.has_permission('CREATE_BOOKING_ITEM'), app.has_permission('CORRECT_PASSENGER_MANIFEST'),
                (select count(*) = 2 from public.booking_item_passengers where id in
                   ('12800000-0000-0000-0000-0000000000b1','12800000-0000-0000-0000-0000000000b2'))],
  array[true,false,true], 'CONTROL: the employee holds CREATE_BOOKING_ITEM, not CORRECT_PASSENGER_MANIFEST, and sees both entries');
select set_config('request.jwt.claims','{"sub":"12800000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
insert into s128 values ('mgr', (app.has_permission('CREATE_BOOKING_ITEM') and app.has_permission('CORRECT_PASSENGER_MANIFEST'))::text);
select set_config('request.jwt.claims','{"sub":"12800000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
insert into s128 values ('fin', (not app.has_permission('CREATE_BOOKING_ITEM') and app.has_permission('CORRECT_PASSENGER_MANIFEST'))::text);
reset role;
select is(array[(select v from s128 where k='mgr'), (select v from s128 where k='fin')], array['true','true'],
  'CONTROL: the branch manager holds both; the finance manager holds CORRECT_PASSENGER_MANIFEST and not CREATE_BOOKING_ITEM');

-- ================================================================================================
-- 6-11. Before the freeze the entry IS the profile.
-- ================================================================================================
select is(array[pg_temp.ident('12800000-0000-0000-0000-0000000000b1'), pg_temp.ident('12800000-0000-0000-0000-0000000000b2')],
  array['Ahmed|Original|Ahmed Original|1980-01-01|A1000001|EG','Ahmed|Original|Ahmed Original|1980-01-01|A1000001|EG'],
  'a new entry takes its traveller''s identity, on a draft booking and on an issued one alike');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12800000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($$update public.booking_item_passengers set manifest_full_name = 'Fake Person'
                   where id = '12800000-0000-0000-0000-0000000000b1'$$,
  'an unfrozen entry accepts the statement...');
select is(pg_temp.ident('12800000-0000-0000-0000-0000000000b1'), pg_temp.prof('12800000-0000-0000-0000-00000000aaa1'),
  '...but its identity is re-derived: a caller cannot pre-load a different one before the freeze');
select lives_ok($$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id,
                     manifest_full_name, manifest_passport_number)
                   values ('12800000-0000-0000-0000-0000000000b4','12800000-0000-0000-0000-000000000001',
                     '12800000-0000-0000-0000-0000000000e1','12800000-0000-0000-0000-00000000aaa3','Forged Name','F0000000')$$,
  'the table''s INSERT grant accepts an entry that supplies its own identity...');
select is(pg_temp.ident('12800000-0000-0000-0000-0000000000b4'), pg_temp.prof('12800000-0000-0000-0000-00000000aaa3'),
  '...but the entry is born with its traveller''s identity, not the supplied one');

select lives_ok($$update public.passengers set first_name = 'Ahmed', family_name = 'Corrected', full_name = 'Ahmed Corrected',
                   date_of_birth = '1980-01-02', passport_number = 'A1000009'
                   where id = '12800000-0000-0000-0000-00000000aaa1'$$,
  'the employee corrects the profile before issue');
select is(pg_temp.ident('12800000-0000-0000-0000-0000000000b1'), 'Ahmed|Corrected|Ahmed Corrected|1980-01-02|A1000009|EG',
  'PAX-7: the draft entry follows the pre-issue correction');
select is(pg_temp.ident('12800000-0000-0000-0000-0000000000b2'), 'Ahmed|Original|Ahmed Original|1980-01-01|A1000001|EG',
  'PAX-7: the SAME traveller''s issued entry keeps the identity it was ticketed under');

-- ================================================================================================
-- 12-18. MUTATION: without the propagation trigger the draft entry goes stale.
-- ================================================================================================
reset role;
insert into s128 select 'enf', md5(pg_get_functiondef('app.enforce_booking_item_passenger_lifecycle()'::regprocedure));
insert into s128 select 'grd', md5(pg_get_functiondef('app.guard_write_capability()'::regprocedure));
alter table public.passengers disable trigger passengers_sync_manifest_identity;
select is((select tgenabled::text from pg_trigger where tgname = 'passengers_sync_manifest_identity'), 'D',
  'MUTANT INSTALLED: the propagation trigger is disabled');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12800000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($$update public.passengers set full_name = 'Ahmed Mutant' where id = '12800000-0000-0000-0000-00000000aaa1'$$,
  'MUTANT: the profile edit still lands');
select is((select manifest_full_name from public.booking_item_passengers where id = '12800000-0000-0000-0000-0000000000b1'),
  'Ahmed Corrected', 'MUTANT: ...but the draft entry no longer follows it -- the trigger is load-bearing');
reset role;
alter table public.passengers enable trigger passengers_sync_manifest_identity;
select is((select tgenabled::text from pg_trigger where tgname = 'passengers_sync_manifest_identity'), 'O',
  'RESTORED: the propagation trigger is enabled again');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12800000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($$update public.passengers set full_name = 'Ahmed Restored' where id = '12800000-0000-0000-0000-00000000aaa1'$$,
  'RESTORED: the next profile edit lands');
select is((select manifest_full_name from public.booking_item_passengers where id = '12800000-0000-0000-0000-0000000000b1'),
  'Ahmed Restored', 'RESTORED: ...and reaches the draft entry again');
reset role;
select is(array[md5(pg_get_functiondef('app.enforce_booking_item_passenger_lifecycle()'::regprocedure)),
                md5(pg_get_functiondef('app.guard_write_capability()'::regprocedure))],
  array[(select v from s128 where k='enf'), (select v from s128 where k='grd')],
  'the enforcer and the guard are byte-identical before and after the mutation');

-- ================================================================================================
-- 19-25. The freeze. The profile stays editable; the frozen entry does not follow; the employee
-- cannot reach the frozen identity by any door.
-- ================================================================================================
select set_config('request.jwt.claims', '', true);
update public.bookings set booking_status_code = 'issued' where id = '12800000-0000-0000-0000-0000000000f1';

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12800000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok($$update public.passengers set full_name = 'Ahmed Renewed', passport_number = 'A2000002',
                   passport_issuing_country_code = 'SA' where id = '12800000-0000-0000-0000-00000000aaa1'$$,
  'after issue the employee still renews the traveller''s profile');
select is(array[pg_temp.prof('12800000-0000-0000-0000-00000000aaa1'), pg_temp.ident('12800000-0000-0000-0000-0000000000b1')],
  array['Ahmed|Corrected|Ahmed Renewed|1980-01-02|A2000002|SA','Ahmed|Corrected|Ahmed Restored|1980-01-02|A1000009|EG'],
  'PAX-7: the profile changed and the now-frozen entry kept the identity it was frozen with');

select throws_ok($$update public.booking_item_passengers set manifest_full_name = 'Mona Replacement'
                    where id = '12800000-0000-0000-0000-0000000000b2'$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  'the employee cannot rewrite a frozen ticketed identity');
select throws_ok($$update public.booking_item_passengers set manifest_passport_number = null
                    where id = '12800000-0000-0000-0000-0000000000b2'$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  '...nor clear part of it');
select throws_ok($$update public.booking_item_passengers set manifest_full_name = 'Mona Replacement',
                    passenger_correction_reason = 'typo' where id = '12800000-0000-0000-0000-0000000000b2'$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  '...nor rewrite it by supplying a reason');
select throws_ok($$update public.booking_item_passengers set passenger_id = '12800000-0000-0000-0000-00000000aaa2',
                    passenger_correction_reason = 'swap' where id = '12800000-0000-0000-0000-0000000000b2'$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  'PAX-5 unchanged: the employee still cannot swap the traveller');
reset role;
select is(pg_temp.ident('12800000-0000-0000-0000-0000000000b2'), 'Ahmed|Original|Ahmed Original|1980-01-01|A1000001|EG',
  '...and after every refusal the issued entry still names the person it was ticketed for');

-- ================================================================================================
-- 26-33. The attributed correction: the capability, a fresh reason, a kept name, a server stamp.
-- ================================================================================================
insert into s128 select 'ev', count(*)::text from public.events where entity_id = '12800000-0000-0000-0000-0000000000e2';
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12800000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok($$update public.booking_item_passengers set manifest_full_name = 'Ahmed O. Original'
                    where id = '12800000-0000-0000-0000-0000000000b2'$$,
  '23514', 'a passenger manifest correction after issuance requires its own reason (booking is issued)',
  'a correction holder still needs a reason');
select throws_ok($$update public.booking_item_passengers set manifest_full_name = '',
                    passenger_correction_reason = 'blank it' where id = '12800000-0000-0000-0000-0000000000b2'$$,
  '23514', 'a ticketed identity keeps its name',
  '...and cannot blank the ticketed name');
select lives_ok($$update public.booking_item_passengers set manifest_full_name = 'Ahmed O. Original',
                   passenger_correction_reason = 'ticket reissued with middle initial'
                   where id = '12800000-0000-0000-0000-0000000000b2'$$,
  'a correction holder corrects the ticketed identity with a fresh reason');
reset role;
select is((select array[manifest_full_name, (passenger_corrected_by = '12800000-0000-0000-0000-000000000013')::text,
                        (passenger_corrected_at is not null)::text]
             from public.booking_item_passengers where id = '12800000-0000-0000-0000-0000000000b2'),
  array['Ahmed O. Original','true','true'], '...which lands, stamped by the server with the corrector');
select is(pg_temp.prof('12800000-0000-0000-0000-00000000aaa1'), 'Ahmed|Corrected|Ahmed Renewed|1980-01-02|A2000002|SA',
  '...and leaves the reusable profile untouched');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12800000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select throws_ok($$update public.booking_item_passengers set manifest_passport_number = 'X1'
                    where id = '12800000-0000-0000-0000-0000000000b2'$$,
  '23514', 'a passenger manifest correction after issuance requires its own reason (booking is issued)',
  'a second correction cannot ride on the first one''s reason');
select throws_ok($$update public.booking_item_passengers set passenger_correction_reason = 'rewritten'
                    where id = '12800000-0000-0000-0000-0000000000b2'$$,
  '23514', 'manifest correction evidence is not editable on its own',
  'PAX-5 unchanged: the correction evidence is still not editable on its own');
select set_config('request.jwt.claims','{"sub":"12800000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select lives_ok($$update public.booking_item_passengers set manifest_full_name = 'Sara T. Third',
                   passenger_correction_reason = 'finance: name as on reissued ticket'
                   where id = '12800000-0000-0000-0000-0000000000b3'$$,
  'the finance manager (correction authority, no CREATE_BOOKING_ITEM) corrects a ticketed identity too');

-- ================================================================================================
-- 34-37. Swaps take the new traveller's identity, whatever the statement supplies.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"12800000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select lives_ok($$update public.booking_item_passengers set passenger_id = '12800000-0000-0000-0000-00000000aaa2',
                   manifest_full_name = 'Invented Name', passenger_correction_reason = 'wrong traveller ticketed'
                   where id = '12800000-0000-0000-0000-0000000000b2'$$,
  'a reasoned swap by a correction holder lands');
select is(pg_temp.ident('12800000-0000-0000-0000-0000000000b2'), 'Mona|Second|Mona Second|1985-02-02|B2000002|EG',
  '...with the new traveller''s identity, not the one the statement supplied');
select lives_ok($$select app.correct_passenger_manifest('12800000-0000-0000-0000-0000000000b3',
                   '12800000-0000-0000-0000-00000000aaa1', 'rpc: traveller corrected')$$,
  'the correction RPC swaps a frozen entry');
select is(pg_temp.ident('12800000-0000-0000-0000-0000000000b3'), 'Ahmed|Corrected|Ahmed Renewed|1980-01-02|A2000002|SA',
  '...and the entry takes the incoming traveller''s current identity');

-- ================================================================================================
-- 38-40. The platform path.
-- ================================================================================================
reset role;
select set_config('request.jwt.claims', '', true);
select throws_ok($$update public.booking_item_passengers set manifest_full_name = 'Platform Edit',
                    passenger_correction_reason = 'platform' where id = '12800000-0000-0000-0000-0000000000b3'$$,
  '42501', 'permission denied: CORRECT_PASSENGER_MANIFEST',
  'a session-less identity correction is refused, as a session-less swap already is (BOOK-1)');
select lives_ok($$update public.passengers set full_name = 'Ahmed Platform' where id = '12800000-0000-0000-0000-00000000aaa1'$$,
  'a session-less profile edit lands');
select is(pg_temp.ident('12800000-0000-0000-0000-0000000000b3'), 'Ahmed|Corrected|Ahmed Renewed|1980-01-02|A2000002|SA',
  '...and does not reach the frozen entry either');

-- ================================================================================================
-- 41. OBSERVED AND STILL OPEN -- PAX-8. A repair of PAX-8 is expected to update this assertion.
-- ================================================================================================
-- The two swaps above each add a `booking_item_passenger_replaced`, so those are excluded; before the
-- first correction the item carried no event of that type.
select is((select count(*)::text from public.events where entity_id = '12800000-0000-0000-0000-0000000000e2'
             and event_type_code <> 'booking_item_passenger_replaced'),
  (select v from s128 where k = 'ev'),
  'PAX-8 STILL OPEN: the two post-freeze identity corrections added no event to the item');

select finish();
rollback;
