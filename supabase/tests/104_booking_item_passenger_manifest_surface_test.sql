-- pgTAP: Batch 6 slice 4 -- booking_item_passengers, the manifest that asked nobody's permission.
--
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT BUSINESS CONCURRENCY REPLAY PRIVILEGE OBSERVABILITY
--
-- All ten classes are live on this surface and none is declared N/A. That is unusual here and it is a
-- property of the table, not of the effort: this row carries an authorization question (who may write
-- it), a tenant question (whose booking is it), two doors (the RPC and the table), a parent lifecycle,
-- a composite foreign key, a unique constraint that is a real cross-row invariant, and a SECURITY
-- DEFINER trigger that used to answer questions about other tenants.
--
-- The three findings this file pins were measured against the live stack BEFORE 202607061400:
--   PAX-1  a finance_manager -- who can SEE booking_items and cannot CREATE_BOOKING_ITEM -- was
--          REFUSED by the RPC (42501) and ALLOWED by a direct INSERT, which persisted.
--   PAX-2  passenger_id could be rewritten on an existing link by an actor who did not create it and
--          held no capability; every trigger on the table returned early for that statement.
--   PAX-3  the SECURITY DEFINER lifecycle trigger looked its parent up by id ALONE and ran BEFORE the
--          RLS WITH CHECK, so a foreign CANCELLED item answered 23514 while a foreign ACTIVE item and
--          a nonexistent id answered 42501 -- a cross-tenant existence-and-state oracle.
--
-- Assertions 17-19 are the oracle proof and they work by pinning the SAME message string three times:
-- indistinguishability is the security property, so the test asserts the strings are equal rather than
-- asserting three codes and hoping. Assertion 20 is its control -- the trigger must still SPEAK when
-- the parent is genuinely the caller's, or 17-19 could be satisfied by a trigger that died.
--
-- Assertions 37-40 are PAR-4 defect injection in both directions: drop the capability trigger and the
-- original PAX-1 insert succeeds again; restore the PRE-REPAIR lifecycle function and the PAX-3 oracle
-- comes back. Each is rolled back and RE-asserted (TEST-3). A guard that cannot be shown to fail has
-- not been shown to work.
--
-- Assertions 11-12 are deliberately NOT a throws_ok, and the reason is the finding itself: the trainee
-- who "proved" this surface safe is refused by RLS VISIBILITY, so their statement matches zero rows and
-- raises nothing. Asserting a throw there would have recorded a capability check that never ran.

create extension if not exists pgtap with schema extensions;

begin;
select plan(41);

-- =============================================================================================
-- FIXTURE. Two tenants, because a cross-tenant assertion whose foreign row does not exist is the
-- vacuous-security-test class (AGENTS.md §6). Assertions 14-15 prove the rival rows are really there.
--
-- Three actors, one variable apart from each other:
--   finance_manager  SEES booking_items (VIEW_FINANCIAL_DOCUMENTS) and holds NO CREATE_BOOKING_ITEM
--   employee         holds CREATE_BOOKING_ITEM -- the legitimate manifest writer
--   trainee          holds neither, and was the actor that made this surface LOOK safe
-- =============================================================================================
insert into auth.users (id, email) values
  ('a4000000-0000-0000-0000-0000000000a1','fin@pax4.test'),
  ('a4000000-0000-0000-0000-0000000000a2','emp@pax4.test'),
  ('a4000000-0000-0000-0000-0000000000a3','trn@pax4.test');
insert into public.tenants (id, name, slug, status) values
  ('a4000000-0000-0000-0000-000000000001','Alpha Travel','alpha-pax4','active'),
  ('a4000000-0000-0000-0000-000000000002','Rival Travel','rival-pax4','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['a4000000-0000-0000-0000-000000000001'::uuid,
               'a4000000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-000000000001','Cairo','pax4-cairo'),
  ('a4000000-0000-0000-0000-00000000000b','a4000000-0000-0000-0000-000000000002','Giza','pax4-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('a4000000-0000-0000-0000-0000000000c1','a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-00000000000a','sales','Sales'),
  ('a4000000-0000-0000-0000-0000000000c2','a4000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-00000000000b','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('a4000000-0000-0000-0000-000000000011','a4000000-0000-0000-0000-000000000001','Fin','fin@pax4.test',true,'a4000000-0000-0000-0000-0000000000a1'),
  ('a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-000000000001','Emp','emp@pax4.test',true,'a4000000-0000-0000-0000-0000000000a2'),
  ('a4000000-0000-0000-0000-000000000013','a4000000-0000-0000-0000-000000000001','Trn','trn@pax4.test',true,'a4000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000011','a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-0000000000c1',true),
  ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-0000000000c1',true),
  ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-000000000013','a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (id, tenant_id, user_id, role_id, scope_type)
select v.i, 'a4000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('a4000000-0000-0000-0000-0000000000e1'::uuid,'a4000000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
             ('a4000000-0000-0000-0000-0000000000e2'::uuid,'a4000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('a4000000-0000-0000-0000-0000000000e3'::uuid,'a4000000-0000-0000-0000-000000000013'::uuid,'trainee')) v(i,u,rc)
join public.roles r on r.code=v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('a4000000-0000-0000-0000-0000000000d1','a4000000-0000-0000-0000-000000000001','person','Alpha Cust','+201005551111'),
  ('a4000000-0000-0000-0000-0000000000d2','a4000000-0000-0000-0000-000000000002','person','Rival Cust','+201005552222');

-- Alpha carries a live booking and a CANCELLED one; Rival carries a live booking. The cancelled
-- Alpha booking is what assertion 22 attacks, and it must stay distinguishable from the tenant case.
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
    owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('a4000000-0000-0000-0000-0000000000f1','a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-0000000000c1','a4000000-0000-0000-0000-0000000000d1','a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-0000000000c1','draft','Alpha bk','BK-PAX4-1'),
  ('a4000000-0000-0000-0000-0000000000f3','a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-0000000000c1','a4000000-0000-0000-0000-0000000000d1','a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-0000000000c1','draft','Alpha dead bk','BK-PAX4-3'),
  ('a4000000-0000-0000-0000-0000000000f2','a4000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-00000000000b','a4000000-0000-0000-0000-0000000000c2','a4000000-0000-0000-0000-0000000000d2',null,'a4000000-0000-0000-0000-00000000000b','a4000000-0000-0000-0000-0000000000c2','draft','Rival bk','BK-PAX4-2');

--   e1  Alpha, draft            -- the legitimate target
--   e9  Alpha, cancelled        -- STATE
--   e8  Alpha, archived         -- STATE
--   e7  Alpha, draft, on the CANCELLED booking -- STATE, parent's parent
--   e2  Rival, draft            -- TENANT: the "does it exist" half of the oracle
--   e3  Rival, cancelled        -- TENANT: the "what state is it in" half of the oracle
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code, is_archived,
    owner_user_id, sales_owner_user_id, operational_owner_user_id, owner_branch_id, owner_department_id, currency_code) values
  ('a4000000-0000-0000-0000-0000000000e1','a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000f1','flight_ticket','draft',false,'a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-0000000000c1','EGP'),
  ('a4000000-0000-0000-0000-0000000000e9','a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000f1','flight_ticket','cancelled',false,'a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-0000000000c1','EGP'),
  ('a4000000-0000-0000-0000-0000000000e8','a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000f1','flight_ticket','draft',true,'a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-0000000000c1','EGP'),
  ('a4000000-0000-0000-0000-0000000000e7','a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000f3','flight_ticket','draft',false,'a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-000000000012','a4000000-0000-0000-0000-00000000000a','a4000000-0000-0000-0000-0000000000c1','EGP'),
  ('a4000000-0000-0000-0000-0000000000e2','a4000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-0000000000f2','flight_ticket','draft',false,null,null,null,'a4000000-0000-0000-0000-00000000000b','a4000000-0000-0000-0000-0000000000c2','EGP'),
  ('a4000000-0000-0000-0000-0000000000e3','a4000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-0000000000f2','flight_ticket','cancelled',false,null,null,null,'a4000000-0000-0000-0000-00000000000b','a4000000-0000-0000-0000-0000000000c2','EGP');

-- f3 is cancelled AFTER e7 is attached to it, because BOOK-1's own item trigger refuses to attach an
-- item to an already-cancelled booking -- on the platform path too. That refusal is correct and is
-- itself evidence: the fixture cannot be built the naive way, which is why it is built this way.
update public.bookings set booking_status_code = 'cancelled'
 where id = 'a4000000-0000-0000-0000-0000000000f3';

insert into public.passengers (id, tenant_id, first_name, family_name, full_name, passenger_type_code) values
  ('a4000000-0000-0000-0000-0000000000b1','a4000000-0000-0000-0000-000000000001','Nour','Hassan','Nour Hassan','adult'),
  ('a4000000-0000-0000-0000-0000000000b2','a4000000-0000-0000-0000-000000000001','Omar','Hassan','Omar Hassan','adult'),
  ('a4000000-0000-0000-0000-0000000000b4','a4000000-0000-0000-0000-000000000001','Laila','Hassan','Laila Hassan','adult'),
  ('a4000000-0000-0000-0000-0000000000b5','a4000000-0000-0000-0000-000000000001','Yara','Hassan','Yara Hassan','adult'),
  ('a4000000-0000-0000-0000-0000000000b6','a4000000-0000-0000-0000-000000000001','Tarek','Hassan','Tarek Hassan','adult'),
  ('a4000000-0000-0000-0000-0000000000b9','a4000000-0000-0000-0000-000000000002','Rival','Traveller','Rival Traveller','adult');

-- =============================================================================================
-- 1-5. CONTROLS. Every refusal below differs from a permit in exactly ONE variable, and assertion 3
--      is the one that made PAX-1 real: the finance manager is refused despite SEEING the parent, so
--      the denial is about AUTHORITY. The trainee's refusal was only ever about VISIBILITY, which is
--      precisely why a low-privilege attacker called this surface safe.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('VIEW_FINANCIAL_DOCUMENTS'),
  'CONTROL: the finance manager holds VIEW_FINANCIAL_DOCUMENTS');

select ok(not app.has_permission('CREATE_BOOKING_ITEM'),
  'CONTROL: ...and does NOT hold CREATE_BOOKING_ITEM -- the capability the RPC has always charged');

select cmp_ok((select count(*) from public.booking_items), '>', 0::bigint,
  'CONTROL: ...and CAN SEE booking_items. This is what separates PAX-1 from the trainee''s RLS refusal: the denial below is authority, not visibility');

select is(app.current_tenant_id(), 'a4000000-0000-0000-0000-000000000001'::uuid,
  'CONTROL: and resolves to its own tenant, so the cross-tenant assertions are not vacuous');

reset role;
select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;
select ok(app.has_permission('CREATE_BOOKING_ITEM'),
  'CONTROL: the employee DOES hold it -- one variable apart, and the positive path below must survive');

-- =============================================================================================
-- 6-9. PAX-1. The table door is now priced at what the RPC has always charged -- and the positive
--      path still works through BOTH doors, which is the half that makes the repair a repair.
-- =============================================================================================
select lives_ok(
  $$insert into public.booking_item_passengers (id, tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-0000000000aa','a4000000-0000-0000-0000-000000000001',
            'a4000000-0000-0000-0000-0000000000e1','a4000000-0000-0000-0000-0000000000b1')$$,
  'POSITIVE CONTROL: an employee holding CREATE_BOOKING_ITEM writes the manifest directly');

select is((select passenger_id from public.booking_item_passengers
            where id='a4000000-0000-0000-0000-0000000000aa'),
  'a4000000-0000-0000-0000-0000000000b1'::uuid,
  '...and the row PERSISTED -- so every refusal below is a refusal and not a closed table');

select lives_ok(
  $$select app.link_passenger_to_booking_item(
      'a4000000-0000-0000-0000-0000000000e1','a4000000-0000-0000-0000-0000000000b2')$$,
  'POSITIVE CONTROL: the RPC door is undamaged -- guard_write_capability passes for a caller who already satisfied app.authorize');

reset role;
select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000e1',
            'a4000000-0000-0000-0000-0000000000b5')$$,
  '42501', null,
  'PAX-1 / DOOR: the direct table INSERT is now REFUSED for the actor the RPC already refused. Before 202607061400 this succeeded and the row persisted');

-- =============================================================================================
-- 10-13. PAX-2. The silent passenger swap. Nour Hassan flies; the manifest afterwards said Laila
--        Hassan; every trigger returned early. The swap is not FORBIDDEN -- canon does not say a
--        manifest may never be corrected (PAX-5, open) -- it is now PRICED.
-- =============================================================================================
select throws_ok(
  $$update public.booking_item_passengers set passenger_id = 'a4000000-0000-0000-0000-0000000000b4'
     where id = 'a4000000-0000-0000-0000-0000000000aa'$$,
  '42501', null,
  'PAX-2: the finance manager can no longer SWAP the traveller on a link they did not create. Before 202607061400 this was ALLOWED and recorded nothing');

reset role;
select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;
-- The trainee is the actor that made this surface LOOK safe, and asserting a THROW here would have
-- been the vacuous-security-test class (AGENTS.md §6): the trainee sees zero booking_items, so the
-- read-scope policy hides the row, the UPDATE matches NOTHING, and no trigger ever runs. It does not
-- raise -- it silently changes nothing. That is a visibility refusal, not an authority one, and
-- writing it as a throw would have recorded a capability check that never fired.
select lives_ok(
  $$update public.booking_item_passengers set passenger_id = 'a4000000-0000-0000-0000-0000000000b4'
     where id = 'a4000000-0000-0000-0000-0000000000aa'$$,
  'PAX-2 / TENANT: a trainee''s swap does NOT raise -- RLS hides the row, so the statement matches zero rows and no trigger is reached');

-- Read back as postgres, NOT through the trainee's session: the trainee cannot see the row either, so
-- asking them what it now contains would return NULL whether the swap landed or not -- an assertion
-- that passes for the wrong reason. Ground truth is read where RLS does not apply.
reset role;
select set_config('request.jwt.claims', '', true);
select is((select passenger_id from public.booking_item_passengers
            where id='a4000000-0000-0000-0000-0000000000aa'),
  'a4000000-0000-0000-0000-0000000000b1'::uuid,
  '...and the traveller is UNCHANGED, read as postgres. This is why PAX-1 went unfound: attacking only with a low-privilege role proves visibility, never authority -- assertion 9 is the actor that mattered');

reset role;
select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$update public.booking_item_passengers set passenger_id = 'a4000000-0000-0000-0000-0000000000b4'
     where id = 'a4000000-0000-0000-0000-0000000000aa'$$,
  'BUSINESS: an actor who HOLDS CREATE_BOOKING_ITEM may still correct the manifest. No business prohibition was invented -- canon does not define one (PAX-5)');

select is((select passenger_id from public.booking_item_passengers
            where id='a4000000-0000-0000-0000-0000000000aa'),
  'a4000000-0000-0000-0000-0000000000b4'::uuid,
  '...and the correction really took effect, so assertion 10 is a denial and not a no-op UPDATE');

-- =============================================================================================
-- 14-20. PAX-3, THE CROSS-TENANT ORACLE. The security property is INDISTINGUISHABILITY, so these
--        assertions pin the same message THREE times rather than pinning three codes. Assertion 20
--        is the control that proves the trigger still speaks about the caller's OWN bookings.
--
--        The attacker here is the EMPLOYEE, deliberately: BEFORE ROW triggers fire in name order, so
--        `..._enforce_lifecycle` runs BEFORE `..._guard_write_capability`. A capability-less actor is
--        stopped by the capability guard and never reaches the oracle; only an actor who PASSES it
--        tests the oracle at all. Attacking with the weaker role would have proved nothing.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','', true);
select is((select count(*)::int from public.booking_items
            where id in ('a4000000-0000-0000-0000-0000000000e2','a4000000-0000-0000-0000-0000000000e3')),
  2,
  'CONTROL: both rival booking items genuinely EXIST -- read as postgres, before RLS applies');

select is((select base_status_code from public.booking_items where id='a4000000-0000-0000-0000-0000000000e3'),
  'cancelled',
  'CONTROL: ...and the rival item really is CANCELLED -- the exact state the oracle used to disclose');

select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-0000000000e3',
            'a4000000-0000-0000-0000-0000000000b1')$$,
  '42501', 'new row violates row-level security policy for table "booking_item_passengers"',
  'PAX-3: a foreign CANCELLED item is now OPAQUE. Before 202607061400 this answered 23514 "cannot add a passenger to a cancelled booking item"');

select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-0000000000e2',
            'a4000000-0000-0000-0000-0000000000b1')$$,
  '42501', 'new row violates row-level security policy for table "booking_item_passengers"',
  'PAX-3: a foreign ACTIVE item gives the IDENTICAL message -- state is no longer distinguishable');

select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-000000009999',
            'a4000000-0000-0000-0000-0000000000b1')$$,
  '42501', 'new row violates row-level security policy for table "booking_item_passengers"',
  'PAX-3: and so does an id that does not EXIST -- so existence is no longer distinguishable either. Three identical strings ARE the oracle proof');

select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000e9',
            'a4000000-0000-0000-0000-0000000000b1')$$,
  '23514', 'cannot add a passenger to a cancelled booking item',
  'CONTROL: the trigger still SPEAKS about the caller''s OWN cancelled item. The repair narrowed the audience, not the rule -- without this the three assertions above could be satisfied by a dead trigger');

-- =============================================================================================
-- 21-24. STATE. The parent lifecycle, on every door BOOK-1 named. Each of these is the caller's own
--        tenant, so a 23514 here is correct and is not the leak assertion 16 closed.
-- =============================================================================================
select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000e8',
            'a4000000-0000-0000-0000-0000000000b1')$$,
  '23514', 'cannot add a passenger to a archived booking item',
  'STATE: an ARCHIVED item refuses a new passenger');

select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000e7',
            'a4000000-0000-0000-0000-0000000000b1')$$,
  '23514', 'cannot add a passenger to an item on a cancelled booking',
  'STATE: so does a live item whose BOOKING is cancelled -- the grandparent is checked too');

select throws_ok(
  $$update public.booking_item_passengers set booking_item_id = 'a4000000-0000-0000-0000-0000000000e9'
     where id = 'a4000000-0000-0000-0000-0000000000aa'$$,
  '23514', 'cannot add a passenger to a cancelled booking item',
  'STATE on the UPDATE door: a passenger cannot be MOVED onto a cancelled item either');

reset role;
select set_config('request.jwt.claims','', true);
select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000e9',
            'a4000000-0000-0000-0000-0000000000b4')$$,
  '23514', 'cannot add a passenger to a cancelled booking item',
  'STATE / PLATFORM: the session-less path is refused too. PAX-3 narrowed the lookup for TENANT sessions only -- BOOK-1 grants this trigger no session-less exemption, and the CHECK never stops running');

-- =============================================================================================
-- 25-28. TENANT ISOLATION as relationships, not as one predicate: plant, row-hop, and the identity
--        substitution that would put a rival's traveller on this tenant's manifest.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-0000000000e2',
            'a4000000-0000-0000-0000-0000000000b9')$$,
  '42501', null,
  'TENANT write: a manifest row cannot be PLANTED in another agency even with that agency''s own item and traveller');

select throws_ok(
  $$update public.booking_item_passengers set tenant_id = 'a4000000-0000-0000-0000-000000000002'
     where id = 'a4000000-0000-0000-0000-0000000000aa'$$,
  '42501', null,
  'TENANT row-hop: a link you DO own cannot be walked into a tenant you do not. Measured: RLS''s WITH CHECK refuses it FIRST (42501); the composite FK behind it never gets the chance, and both would refuse');

select throws_ok(
  $$update public.booking_item_passengers set passenger_id = 'a4000000-0000-0000-0000-0000000000b9'
     where id = 'a4000000-0000-0000-0000-0000000000aa'$$,
  '23503', null,
  'TENANT substitution: a RIVAL tenant''s traveller cannot be swapped onto this tenant''s manifest -- the composite FK (tenant_id, passenger_id) is what makes the swap tenant-safe');

select is((select count(*)::int from public.booking_item_passengers
            where booking_item_id = 'a4000000-0000-0000-0000-0000000000e3'),
  0,
  'TENANT: and nothing this file attempted ever landed on a rival item');

-- =============================================================================================
-- 29-33. THE DOORS AND THE PRIVILEGES. PostgREST serves the TABLE beside the RPC (BOOK-1/ADMIN-1),
--        which is the whole reason PAX-1 existed, so the grants themselves are assertions.
-- =============================================================================================
select throws_ok(
  $$delete from public.booking_item_passengers where id = 'a4000000-0000-0000-0000-0000000000aa'$$,
  '42501', null,
  'DOOR: DELETE is refused at the GRANT -- which is why 202607061400 added no DELETE arm. A trigger guarding a door that does not exist is decoration');

select ok(
  has_table_privilege('authenticated','public.booking_item_passengers','INSERT')
  and has_table_privilege('authenticated','public.booking_item_passengers','UPDATE')
  and not has_table_privilege('authenticated','public.booking_item_passengers','DELETE'),
  'DOOR: the reachable verb set is exactly {INSERT, UPDATE} -- pinned, so a future GRANT DELETE cannot arrive without failing here');

reset role;
set local role anon;
select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000e1',
            'a4000000-0000-0000-0000-0000000000b5')$$,
  '42501', null,
  'DOOR: the unauthenticated boundary holds at the grant, before any policy or trigger is consulted');

reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname in ('app','public','reporting')
      and p.prosrc like '%booking_item_passengers%'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  1,
  'PRIVILEGE: exactly ONE function naming this table is executable by authenticated -- app.link_passenger_to_booking_item. A second definer door cannot appear without failing here');

select ok(not has_function_privilege('public','app.guard_write_capability()','EXECUTE'),
  'PRIVILEGE: the guard itself is not executable by public -- 202607061400 revokes it, per Supabase''s own SECURITY DEFINER guidance');

-- =============================================================================================
-- 34-36. INPUT, REPLAY and the CONCURRENCY basis. The unique constraint is a REAL cross-row
--        invariant here (unlike slice 3, where the absence of one is what made CONCURRENCY moot),
--        so it is asserted as behaviour and then pinned as structure.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000e1',
            'a4000000-0000-0000-0000-0000000000b2')$$,
  '23505', null,
  'REPLAY: the same traveller cannot be linked to the same item twice -- a replayed link is refused by the unique constraint, not by the RPC''s friendly message');

select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id,
                                                selling_amount_override)
    values ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000e1',
            'a4000000-0000-0000-0000-0000000000b6', -1)$$,
  '23514', null,
  'INPUT: a negative per-passenger override is refused at the table door, not only inside the RPC (SPEC-159-A''s constraint, re-attacked here)');

select is(
  (select count(*)::int from pg_constraint
    where conrelid='public.booking_item_passengers'::regclass and contype='u'),
  1,
  'CONCURRENCY basis: the surface has exactly ONE cross-row invariant -- (booking_item_id, passenger_id). Two concurrent linkers of the same traveller are serialised by the unique index, which cannot be raced by construction. Add a second invariant and this fails, which is the point');

-- =============================================================================================
-- 37-40. PAR-4 DEFECT INJECTION, in BOTH directions. "It did not throw" is not evidence that
--        anything was enforced -- so each enforcer is removed, the ORIGINAL attack is shown to
--        succeed again, and the guard is restored and re-asserted (TEST-3).
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', '', true);
savepoint before_capability_mutation;
drop trigger booking_item_passengers_guard_write_capability on public.booking_item_passengers;

select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select lives_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000e1',
            'a4000000-0000-0000-0000-0000000000b5')$$,
  'MUTATION: with booking_item_passengers_guard_write_capability dropped, the ORIGINAL PAX-1 insert succeeds again. THAT trigger is what refuses it -- not RLS, not the harness, not the financial guard beside it');

reset role;
rollback to savepoint before_capability_mutation;
select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000001','a4000000-0000-0000-0000-0000000000e1',
            'a4000000-0000-0000-0000-0000000000b5')$$,
  '42501', null,
  'TEST-3: and refused again after the rollback -- an injection assertion that is never re-asserted is never counted');

-- The PAX-3 half. Restoring the PRE-REPAIR body (parent looked up by id ALONE) must bring the oracle
-- back; if it does not, the tenant predicate was never what closed it and assertions 16-18 were luck.
reset role;
select set_config('request.jwt.claims', '', true);
savepoint before_oracle_mutation;
create or replace function app.enforce_booking_item_passenger_lifecycle()
returns trigger language plpgsql security definer set search_path = '' as $fn$
declare
    v_item_status text; v_item_archived boolean; v_bk_status text; v_bk_archived boolean;
begin
    if tg_op = 'UPDATE' and new.booking_item_id is not distinct from old.booking_item_id then
        return new;
    end if;
    select bi.base_status_code, bi.is_archived, b.booking_status_code, b.is_archived
      into v_item_status, v_item_archived, v_bk_status, v_bk_archived
    from public.booking_items bi join public.bookings b on b.id = bi.booking_id
    where bi.id = new.booking_item_id;
    if not found then return new; end if;
    if v_item_archived or v_item_status in ('cancelled','no_show') then
        raise exception 'cannot add a passenger to a % booking item',
            case when v_item_archived then 'archived' else v_item_status end
            using errcode = 'check_violation';
    end if;
    if v_bk_archived or v_bk_status in ('completed','cancelled') then
        raise exception 'cannot add a passenger to an item on a % booking',
            case when v_bk_archived then 'archived' else v_bk_status end
            using errcode = 'check_violation';
    end if;
    return new;
end;
$fn$;

select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-0000000000e3',
            'a4000000-0000-0000-0000-0000000000b1')$$,
  '23514', 'cannot add a passenger to a cancelled booking item',
  'MUTATION: with the pre-repair body restored, the foreign CANCELLED item DISCLOSES its state again -- 23514 where the repaired function gives the RLS message. The tenant predicate is what closed the oracle');

reset role;
rollback to savepoint before_oracle_mutation;
select set_config('request.jwt.claims','{"sub":"a4000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.booking_item_passengers (tenant_id, booking_item_id, passenger_id)
    values ('a4000000-0000-0000-0000-000000000002','a4000000-0000-0000-0000-0000000000e3',
            'a4000000-0000-0000-0000-0000000000b1')$$,
  '42501', 'new row violates row-level security policy for table "booking_item_passengers"',
  'TEST-3: and opaque again after the rollback. Both mutations are restored, so this file leaves the schema byte-identical to the migration (PAR-2)');

-- =============================================================================================
-- 41. OBSERVABILITY. PAX-6, pinned as an ABSENCE rather than repaired. A manifest change -- the row
--     that decides WHO FLIES -- emits no business event through either door, because canon 27
--     registers no event vocabulary for it at all (passenger_created exists; nothing for the LINK).
--     Minting one here would be inventing canon, which this programme forbids (OWNER-1 / EVT-2).
--     Pinned so a producer cannot arrive without a test, and so the gap cannot be forgotten.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.catalog_values
    where catalog_type_code = 'event_type'
      and (code ilike '%passenger%link%' or code ilike '%passenger%swap%'
           or code ilike '%manifest%' or code ilike '%passenger_removed%')),
  0,
  'OBSERVABILITY / PAX-6: canon registers NO event type for a manifest change, so neither door can record one. Registered as open rather than invented -- add the vocabulary and this assertion fails, demanding the producer and its test together');

select * from finish();
rollback;
