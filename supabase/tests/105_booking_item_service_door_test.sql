-- pgTAP: Batch 6 slice 5 -- booking_items, the booked service that had no door of its own.
--
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT BUSINESS CONCURRENCY REPLAY PRIVILEGE OBSERVABILITY
--
-- Slice 4 closed the manifest and, chasing MEAS-2 (the ceilings CREDITED a conditional guard), found
-- the identical hole on the PARENT and recorded it as BOOK-3. This file pins BOOK-3 and the four
-- further defects the parent's own sweep produced. All five were REPRODUCED against the live stack
-- before 202607061500:
--
--   BOOK-3  a bare booking_item was INSERTable, and freely UPDATEable, by an actor holding NO booking
--           capability at all. Reproduced as a finance_manager AND as a trainee; both persisted.
--   BOOK-4  app.enforce_booking_item_lifecycle is SECURITY DEFINER, looked its parent up by id ALONE
--           and runs BEFORE the RLS WITH CHECK: a foreign CANCELLED booking answered 23514 while a
--           foreign ACTIVE one and a nonexistent one both answered 23503. PAX-3 one table up.
--   BOOK-5  app.guard_booking_item_financials computed canon-28 scope from `new` on UPDATE, so the
--           statement being judged supplied the answer. Reproduced with a DISCRIMINATING PAIR: the
--           plain cost change was refused, the same change carrying an ownership grab took, and the
--           ground truth read as postgres was 100 -> 555 with ownership seized.
--   BOOK-6  finance_approval_required -- the flag advance_booking_item reads to BLOCK execution --
--           could be cleared by anyone who could reach the row.
--   BOOK-7  currency_code could be rewritten on a PRICED item with no money permission.
--
-- ASSERTIONS 2-4 EXIST BECAUSE THE REGISTER WAS WRONG. BOOK-3's own row recorded the repair as hard
-- because "finance_manager holds ENTER_COST without CREATE_BOOKING_ITEM". Measured: it holds NEITHER,
-- and the two permissions are held by exactly the same six roles. The real constraint is the mirror
-- image -- finance LOCKS, APPROVES, ARCHIVES and ASSIGNS SUPPLIERS on items it does not own -- so
-- assertions 28-31 are not decoration; they are the lockout the naive repair would have caused.
--
-- Assertions 17-20 close BOOK-4 the way slice 4 closed PAX-3: by pinning the SAME error three times.
-- Indistinguishability is the security property, so the test asserts the strings are EQUAL rather
-- than asserting three codes and hoping. Assertion 21 is the control that proves the trigger still
-- speaks about the caller's OWN booking, or 17-20 could be satisfied by a function that died.
--
-- Assertion 26 is the anti-tautology control, and it caught a real draft: both money columns are
-- NOT NULL DEFAULT 0, so a currency guard written as `old.cost_amount is not null` would fire on
-- every item that has ever existed. 26 proves the guard does NOT fire on a genuinely unpriced one.
--
-- The BOOK-4 attacks are performed by an actor who HOLDS CREATE_BOOKING_ITEM, and that is deliberate:
-- guard_write_capability now refuses a weaker actor first, so attacking with one would have "proved"
-- the oracle closed while never reaching the function that produced it.

create extension if not exists pgtap with schema extensions;

begin;
select plan(44);

-- =============================================================================================
-- FIXTURE. Two tenants, because a cross-tenant assertion whose foreign row does not exist is the
-- vacuous-security-test class (AGENTS.md §6). Assertion 32 proves the rival rows are really there.
--
-- Four actors in ONE tenant, each one variable apart:
--   fin    finance_manager -- SEES every item, holds APPROVE_FINANCE / EDIT_LOCKED_COST /
--          ARCHIVE_RECORD / ASSIGN_SUPPLIER, and holds NO CREATE_BOOKING_ITEM and NO ENTER_COST
--   emp1   employee -- holds CREATE_BOOKING_ITEM and ENTER_COST, and is NOT assigned item e1
--   emp2   employee -- the same permissions, and IS assigned e1
--   trn    trainee -- holds none of the eight booking-item permissions
-- =============================================================================================
insert into auth.users (id, email) values
  ('b5000000-0000-0000-0000-0000000000a1','fin@bk5.test'),
  ('b5000000-0000-0000-0000-0000000000a2','emp1@bk5.test'),
  ('b5000000-0000-0000-0000-0000000000a3','emp2@bk5.test'),
  ('b5000000-0000-0000-0000-0000000000a4','trn@bk5.test'),
  ('b5000000-0000-0000-0000-0000000000a5','riv@bk5.test');
insert into public.tenants (id, name, slug, status) values
  ('b5000000-0000-0000-0000-000000000001','Alpha Travel','alpha-bk5','active'),
  ('b5000000-0000-0000-0000-000000000002','Rival Travel','rival-bk5','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['b5000000-0000-0000-0000-000000000001'::uuid,
               'b5000000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code='enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-000000000001','Cairo','bk5-cairo'),
  ('b5000000-0000-0000-0000-00000000000b','b5000000-0000-0000-0000-000000000002','Giza','bk5-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('b5000000-0000-0000-0000-0000000000c1','b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-00000000000a','sales','Sales'),
  ('b5000000-0000-0000-0000-0000000000c2','b5000000-0000-0000-0000-000000000002','b5000000-0000-0000-0000-00000000000b','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('b5000000-0000-0000-0000-000000000011','b5000000-0000-0000-0000-000000000001','Fin','fin@bk5.test',true,'b5000000-0000-0000-0000-0000000000a1'),
  ('b5000000-0000-0000-0000-000000000012','b5000000-0000-0000-0000-000000000001','Emp1','emp1@bk5.test',true,'b5000000-0000-0000-0000-0000000000a2'),
  ('b5000000-0000-0000-0000-000000000013','b5000000-0000-0000-0000-000000000001','Emp2','emp2@bk5.test',true,'b5000000-0000-0000-0000-0000000000a3'),
  ('b5000000-0000-0000-0000-000000000014','b5000000-0000-0000-0000-000000000001','Trn','trn@bk5.test',true,'b5000000-0000-0000-0000-0000000000a4'),
  ('b5000000-0000-0000-0000-000000000015','b5000000-0000-0000-0000-000000000002','Riv','riv@bk5.test',true,'b5000000-0000-0000-0000-0000000000a5');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000011','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1',true),
  ('b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000012','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1',true),
  ('b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000013','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1',true),
  ('b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000000014','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1',true),
  ('b5000000-0000-0000-0000-000000000002','b5000000-0000-0000-0000-000000000015','b5000000-0000-0000-0000-00000000000b','b5000000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('b5000000-0000-0000-0000-000000000001'::uuid,'b5000000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
             ('b5000000-0000-0000-0000-000000000001'::uuid,'b5000000-0000-0000-0000-000000000012'::uuid,'employee'),
             ('b5000000-0000-0000-0000-000000000001'::uuid,'b5000000-0000-0000-0000-000000000013'::uuid,'employee'),
             ('b5000000-0000-0000-0000-000000000001'::uuid,'b5000000-0000-0000-0000-000000000014'::uuid,'trainee'),
             ('b5000000-0000-0000-0000-000000000002'::uuid,'b5000000-0000-0000-0000-000000000015'::uuid,'employee')) v(t,u,rc)
join public.roles r on r.code=v.rc;
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('b5000000-0000-0000-0000-0000000000d1','b5000000-0000-0000-0000-000000000001','person','Alpha Cust','+201006661111'),
  ('b5000000-0000-0000-0000-0000000000d2','b5000000-0000-0000-0000-000000000002','person','Rival Cust','+201006662222');
insert into public.suppliers (id, tenant_id, supplier_type_code, name) values
  ('b5000000-0000-0000-0000-0000000000c9','b5000000-0000-0000-0000-000000000001','airline','Alpha Air');

-- Alpha: one live booking and one cancelled. Rival: one live and one cancelled -- BOOK-4's oracle
-- needs a foreign booking in EACH state or the three-way comparison has nothing to compare.
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, owner_user_id,
    owner_branch_id, owner_department_id, booking_status_code, title, booking_reference) values
  ('b5000000-0000-0000-0000-0000000000f1','b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1','b5000000-0000-0000-0000-0000000000d1','b5000000-0000-0000-0000-000000000013','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1','draft','Alpha live','BK-BK5-1'),
  ('b5000000-0000-0000-0000-0000000000f4','b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1','b5000000-0000-0000-0000-0000000000d1','b5000000-0000-0000-0000-000000000013','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1','draft','Alpha dead','BK-BK5-4'),
  ('b5000000-0000-0000-0000-0000000000f5','b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1','b5000000-0000-0000-0000-0000000000d1','b5000000-0000-0000-0000-000000000013','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1','draft','Alpha second live','BK-BK5-5'),
  ('b5000000-0000-0000-0000-0000000000f2','b5000000-0000-0000-0000-000000000002','b5000000-0000-0000-0000-00000000000b','b5000000-0000-0000-0000-0000000000c2','b5000000-0000-0000-0000-0000000000d2','b5000000-0000-0000-0000-000000000015','b5000000-0000-0000-0000-00000000000b','b5000000-0000-0000-0000-0000000000c2','draft','Rival live','BK-BK5-2'),
  ('b5000000-0000-0000-0000-0000000000f3','b5000000-0000-0000-0000-000000000002','b5000000-0000-0000-0000-00000000000b','b5000000-0000-0000-0000-0000000000c2','b5000000-0000-0000-0000-0000000000d2','b5000000-0000-0000-0000-000000000015','b5000000-0000-0000-0000-00000000000b','b5000000-0000-0000-0000-0000000000c2','draft','Rival dead','BK-BK5-3');

-- e1 is PRICED and assigned to emp2. e2 is genuinely UNPRICED (both money columns at their default
-- 0) and is what assertion 26 uses. e3 is owned by the TRAINEE, which is the only way to give an
-- actor holding no capability VISIBILITY of a row -- without it, assertions 11-12 would be testing
-- RLS instead of authority, which is the vacuous class slice 4 was caught by and documents.
insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
    currency_code, cost_amount, selling_amount, owner_user_id, owner_branch_id, owner_department_id,
    sales_owner_user_id, sales_owner_branch_id, sales_owner_department_id) values
  ('b5000000-0000-0000-0000-0000000000e1','b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-0000000000f1','flight_ticket','draft','EGP',100,150,'b5000000-0000-0000-0000-000000000013','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1','b5000000-0000-0000-0000-000000000013','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1'),
  ('b5000000-0000-0000-0000-0000000000e2','b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-0000000000f1','hotel','draft','EGP',0,0,'b5000000-0000-0000-0000-000000000013','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1','b5000000-0000-0000-0000-000000000013','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1'),
  ('b5000000-0000-0000-0000-0000000000e3','b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-0000000000f1','visa','draft','EGP',0,0,'b5000000-0000-0000-0000-000000000014','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1','b5000000-0000-0000-0000-000000000014','b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1'),
  ('b5000000-0000-0000-0000-0000000000e9','b5000000-0000-0000-0000-000000000002','b5000000-0000-0000-0000-0000000000f2','hotel','draft','EGP',0,0,'b5000000-0000-0000-0000-000000000015','b5000000-0000-0000-0000-00000000000b','b5000000-0000-0000-0000-0000000000c2','b5000000-0000-0000-0000-000000000015','b5000000-0000-0000-0000-00000000000b','b5000000-0000-0000-0000-0000000000c2');

-- The cancelled bookings are cancelled AFTER their items exist, because BOOK-1's own trigger refuses
-- attaching an item to an already-cancelled booking -- on the platform path too.
update public.bookings set booking_status_code = 'cancelled'
 where id in ('b5000000-0000-0000-0000-0000000000f3','b5000000-0000-0000-0000-0000000000f4');

-- =============================================================================================
-- 1-6. CONTROLS. Assertions 2-4 are the ones that corrected the register: they measure the claim
--      BOOK-3 was recorded on, rather than inheriting it.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select cmp_ok((select count(*) from public.booking_items), '>', 0::bigint,
  'CONTROL: the finance manager CAN SEE booking_items. Every refusal below is therefore about AUTHORITY, not visibility -- the distinction PAX-1 turned on');

select ok(not app.has_permission('CREATE_BOOKING_ITEM'),
  'CONTROL: ...and does NOT hold CREATE_BOOKING_ITEM, which app.create_booking_item has always charged');

select ok(not app.has_permission('ENTER_COST'),
  'CORRECTION: ...and does NOT hold ENTER_COST either. BOOK-3''s register row asserted it did, and named that as the reason the repair was hard. Measured, not inherited');

reset role;
select set_config('request.jwt.claims', '', true);
select set_eq(
  $$select r.code::text from public.roles r
     join public.role_permissions rp on rp.role_id = r.id
     join public.permissions p on p.id = rp.permission_id
    where p.key = 'ENTER_COST'$$,
  $$select r.code::text from public.roles r
     join public.role_permissions rp on rp.role_id = r.id
     join public.permissions p on p.id = rp.permission_id
    where p.key = 'CREATE_BOOKING_ITEM'$$,
  'CORRECTION: ENTER_COST and CREATE_BOOKING_ITEM are held by exactly the SAME roles, so the "finance holds one without the other" obstacle never existed. If canon ever separates them this assertion fails and the UPDATE arm must be revisited');

select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select ok(app.has_permission('APPROVE_FINANCE') and app.has_permission('EDIT_LOCKED_COST')
          and app.has_permission('ARCHIVE_RECORD') and app.has_permission('ASSIGN_SUPPLIER'),
  'CONTROL: the REAL constraint -- finance holds four permissions that legitimately mutate an item it does not own. Assertions 28-31 are the lockout a naive repair would have caused');

reset role;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a4","aal":"aal2"}', true);
set local role authenticated;
select ok(not (app.has_permission('CREATE_BOOKING_ITEM') or app.has_permission('ENTER_COST')
               or app.has_permission('ENTER_SELLING_PRICE') or app.has_permission('UPDATE_BOOKING_ITEM_STATUS')
               or app.has_permission('APPROVE_FINANCE') or app.has_permission('EDIT_LOCKED_COST')
               or app.has_permission('ARCHIVE_RECORD') or app.has_permission('ASSIGN_SUPPLIER')),
  'CONTROL: the trainee holds NONE of the eight permissions in either arm -- the actor the floor must refuse outright');

-- =============================================================================================
-- 7-12. BOOK-3 / AUTH + DOOR. The table door is now priced at what the RPC has always charged, and
--       the positive path still works through BOTH doors -- the half that makes a repair a repair.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$insert into public.booking_items (id, tenant_id, booking_id, service_type_code, base_status_code,
      currency_code, owner_user_id, owner_branch_id, owner_department_id)
    values ('b5000000-0000-0000-0000-0000000000ea','b5000000-0000-0000-0000-000000000001',
            'b5000000-0000-0000-0000-0000000000f1','hotel','draft','EGP',
            'b5000000-0000-0000-0000-000000000012','b5000000-0000-0000-0000-00000000000a',
            'b5000000-0000-0000-0000-0000000000c1')$$,
  'POSITIVE CONTROL: an employee holding CREATE_BOOKING_ITEM books a service directly');

select is((select service_type_code from public.booking_items
            where id='b5000000-0000-0000-0000-0000000000ea'), 'hotel',
  '...and the row PERSISTED -- so every refusal below is a refusal and not a closed table');

select lives_ok(
  $$select app.create_booking_item('b5000000-0000-0000-0000-0000000000f1','hotel','EGP')$$,
  'POSITIVE CONTROL: the RPC door is undamaged -- guard_write_capability passes for a caller who already satisfied app.authorize');

reset role;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a4","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code,
      currency_code, owner_user_id, owner_branch_id, owner_department_id)
    values ('b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-0000000000f1','hotel',
            'draft','EGP','b5000000-0000-0000-0000-000000000014',
            'b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1')$$,
  '42501', null,
  'BOOK-3 / AUTH: the trainee -- holding none of the eight -- is REFUSED. Before 202607061500 this succeeded and the booked service persisted');

select throws_ok(
  $$update public.booking_items set service_type_code = 'hotel'
     where id = 'b5000000-0000-0000-0000-0000000000e3'$$,
  '42501', null,
  'BOOK-3 / DOOR, the UPDATE half: and on a row the trainee OWNS, so this is authority and not RLS. Rewriting what was booked was previously free');

select throws_ok(
  $$update public.booking_items set booking_id = 'b5000000-0000-0000-0000-0000000000f5'
     where id = 'b5000000-0000-0000-0000-0000000000e3'$$,
  '42501', null,
  'BOOK-3 / STATE: the same floor stops a row-hop -- moving a booked service onto a different LIVE booking of the same tenant, which no RPC offers at all. f5 is live on purpose: against a cancelled one the lifecycle trigger would refuse first and this would be testing BOOK-1');

-- =============================================================================================
-- 13-16. BOOK-5 / PRIVILEGE. The scope check used to read the attacker's own post-image. 13 and 14
--        are a DISCRIMINATING PAIR one variable apart, and 15 is the property: after the repair the
--        two are INDISTINGUISHABLE. 16 proves the guard did not simply die.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$update public.booking_items set cost_amount = 555
     where id = 'b5000000-0000-0000-0000-0000000000e1'$$,
  '42501', 'ENTER_COST is scoped to items assigned to you (canon 28: assigned)',
  'CONTROL: emp1 holds ENTER_COST but is not assigned e1, so the plain cost change is refused by SCOPE. This always worked');

select throws_ok(
  $$update public.booking_items
       set owner_user_id = 'b5000000-0000-0000-0000-000000000012',
           sales_owner_user_id = 'b5000000-0000-0000-0000-000000000012',
           cost_amount = 555
     where id = 'b5000000-0000-0000-0000-0000000000e1'$$,
  '42501', 'ENTER_COST is scoped to items assigned to you (canon 28: assigned)',
  'BOOK-5: the SAME change carrying an ownership grab is now refused IDENTICALLY. Before 202607061500 this took, and the ground truth read as postgres was 100 -> 555 with ownership seized');

-- 13 and 14 already pin the SAME literal string, so indistinguishability is proven by those two
-- calls and a third assertion restating it would be a tautology (AGENTS.md §6). BOOK-9 has now
-- closed the residual this assertion deliberately carried: CREATE_BOOKING_ITEM is not authority
-- to move a booked service away from the colleague holding it.
select throws_ok(
  $$update public.booking_items set owner_user_id = 'b5000000-0000-0000-0000-000000000012'
     where id = 'b5000000-0000-0000-0000-0000000000e2'$$,
  '42501', null,
  'BOOK-9 CLOSED: an ownership grab WITHOUT money is refused for a CREATE_BOOKING_ITEM holder; moving responsibility now costs REASSIGN_BOOKING_ITEM independently');

reset role;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;
select lives_ok(
  $$update public.booking_items set cost_amount = 555
     where id = 'b5000000-0000-0000-0000-0000000000e1'$$,
  'CONTROL: emp2, who IS assigned e1, still prices it. The scope check reads the PRE-image, not "nobody"');

-- =============================================================================================
-- 17-21. BOOK-4 / OBSERVABILITY. The cross-tenant existence-and-state oracle. Attacked by an actor
--        who HOLDS CREATE_BOOKING_ITEM, because the new floor would otherwise refuse first and the
--        oracle would never be reached -- the exact mistake slice 4 documents for PAX-3.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code,
      currency_code, owner_user_id, owner_branch_id, owner_department_id)
    values ('b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-0000000000f3','hotel',
            'draft','EGP','b5000000-0000-0000-0000-000000000012',
            'b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1')$$,
  '23503', null,
  'BOOK-4: a foreign CANCELLED booking. Before 202607061500 this answered "cannot attach a booking item to a cancelled booking" -- disclosing both that it exists and what state it is in');

select throws_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code,
      currency_code, owner_user_id, owner_branch_id, owner_department_id)
    values ('b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-0000000000f2','hotel',
            'draft','EGP','b5000000-0000-0000-0000-000000000012',
            'b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1')$$,
  '23503', null,
  'BOOK-4: a foreign ACTIVE booking answers the same');

select throws_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code,
      currency_code, owner_user_id, owner_branch_id, owner_department_id)
    values ('b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-000000009999','hotel',
            'draft','EGP','b5000000-0000-0000-0000-000000000012',
            'b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1')$$,
  '23503', null,
  'BOOK-4: and a booking that does not exist at all answers the same. Three cases, one answer');

-- 17-19 already pin the SAME SQLSTATE three times, so restating their equality would be a tautology.
-- 20 spends the slot on the door 17-19 do NOT cover: the trigger also fires on UPDATE, so the oracle
-- had a second entrance through a row-hop, and it has to be shown closed there too.
select throws_ok(
  $$update public.booking_items set booking_id = 'b5000000-0000-0000-0000-0000000000f3'
     where id = 'b5000000-0000-0000-0000-0000000000ea'$$,
  '23503', null,
  'BOOK-4 / DOOR: the oracle''s OTHER entrance. The lifecycle trigger fires on UPDATE too when booking_id changes, so re-parenting onto a foreign CANCELLED booking used to disclose it the same way -- and now answers 23503 like every other foreign id');

select throws_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code,
      currency_code, owner_user_id, owner_branch_id, owner_department_id)
    values ('b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-0000000000f4','hotel',
            'draft','EGP','b5000000-0000-0000-0000-000000000012',
            'b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1')$$,
  '23514', 'cannot attach a booking item to a cancelled booking',
  'CONTROL: the trigger still SPEAKS about the caller''s OWN cancelled booking. Without this, 17-20 would be satisfied by a function that had simply stopped working');

-- =============================================================================================
-- 22-24. BOOK-6 / BUSINESS. The execution gate. Raising the flag costs what request_finance_approval
--        charges; LOWERING it is refused because no governed path lowers it at all.
-- =============================================================================================
select lives_ok(
  $$update public.booking_items set finance_approval_required = true
     where id = 'b5000000-0000-0000-0000-0000000000e2'$$,
  'CONTROL: an employee holding CREATE_BOOKING_ITEM may RAISE the finance gate -- exactly what app.request_finance_approval charges');

select throws_ok(
  $$update public.booking_items set finance_approval_required = false
     where id = 'b5000000-0000-0000-0000-0000000000e2'$$,
  '42501', 'permission denied: WITHDRAW_FINANCE_APPROVAL',
  'BOOK-8 CLOSED: CREATE_BOOKING_ITEM may raise the gate but may not withdraw it; lowering now charges its independent authority');

reset role;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$update public.booking_items set finance_approval_required = false
     where id = 'b5000000-0000-0000-0000-0000000000e2'$$,
  '23514', 'withdrawing a finance approval requirement requires its own reason',
  'BOOK-8 CLOSED: APPROVE_FINANCE derives withdrawal authority, but the table door still refuses an unattributed lowering without a fresh reason');

-- =============================================================================================
-- 25-27. BOOK-7 / INPUT. A currency change is a change to the money (canon 30, via SUP-4a and CA-2).
--        26 is the anti-tautology control and it caught a real draft.
-- =============================================================================================
select throws_ok(
  $$update public.booking_items set currency_code = 'USD'
     where id = 'b5000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'BOOK-7: the finance manager -- holding no ENTER_COST -- can no longer reinterpret EGP 100 as USD 100 on a PRICED item without touching the amount');

reset role;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;
select lives_ok(
  $$update public.booking_items set currency_code = 'USD'
     where id = 'b5000000-0000-0000-0000-0000000000e3'$$,
  'ANTI-TAUTOLOGY CONTROL: on a genuinely UNPRICED item the money guard stays silent. Both money columns are NOT NULL DEFAULT 0, so a draft written as "old.cost_amount is not null" would have fired here -- and on every item that has ever existed');

select lives_ok(
  $$update public.booking_items set currency_code = 'USD'
     where id = 'b5000000-0000-0000-0000-0000000000e1'$$,
  'CONTROL: emp2, assigned to e1 and holding ENTER_COST, may still redenominate it. The guard prices the act, it does not forbid it');

-- =============================================================================================
-- 28-31. THE LOCKOUT THAT DIDN'T HAPPEN. Finance does real work on items it does not own, and the
--        naive BOOK-3 repair would have refused all four of these.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$update public.booking_items set cost_locked_at = now()
     where id = 'b5000000-0000-0000-0000-0000000000e1'$$,
  'NO LOCKOUT: finance still LOCKS the cost of an item it does not own (APPROVE_FINANCE)');

select lives_ok(
  $$update public.booking_items set finance_approval_status_code = 'approved'
     where id = 'b5000000-0000-0000-0000-0000000000e1'$$,
  'NO LOCKOUT: finance still APPROVES (APPROVE_FINANCE)');

select lives_ok(
  $$update public.booking_items set is_archived = true, archive_reason = 'slice5'
     where id = 'b5000000-0000-0000-0000-0000000000e2'$$,
  'NO LOCKOUT: finance still ARCHIVES (ARCHIVE_RECORD)');

select lives_ok(
  $$update public.booking_items set supplier_id = 'b5000000-0000-0000-0000-0000000000c9'
     where id = 'b5000000-0000-0000-0000-0000000000e3'$$,
  'NO LOCKOUT: and still ASSIGNS A SUPPLIER to an item it does not own (ASSIGN_SUPPLIER). This is the arm entry that would be easiest to leave out, and leaving it out would break supplier assignment for every role that is not also a booking creator');

-- =============================================================================================
-- 32-35. TENANT. Isolation on read and on write, in both directions.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a5","aal":"aal2"}', true);
set local role authenticated;

select is((select count(*)::int from public.booking_items
            where id='b5000000-0000-0000-0000-0000000000e1'), 0,
  'TENANT: the rival employee cannot SEE Alpha''s booked service');

select is((select count(*)::int from public.booking_items
            where id='b5000000-0000-0000-0000-0000000000e9'), 1,
  'TENANT: ...and CAN see its own, so assertion 32 is a refusal and not an empty table');

reset role;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$update public.booking_items set tenant_id = 'b5000000-0000-0000-0000-000000000002'
     where id = 'b5000000-0000-0000-0000-0000000000ea'$$,
  '42501', 'new row violates row-level security policy for table "booking_items"',
  'TENANT: a row cannot be walked into another tenant. The RLS WITH CHECK refuses the post-image');

select throws_ok(
  $$update public.booking_items set booking_id = 'b5000000-0000-0000-0000-0000000000f2'
     where id = 'b5000000-0000-0000-0000-0000000000ea'$$,
  '23503', null,
  'TENANT: and cannot be re-parented onto a FOREIGN booking -- TENANT-1''s composite FK, which is also what makes BOOK-4''s three answers identical');

-- =============================================================================================
-- 36-38. PRIVILEGE + REPLAY + CONCURRENCY.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', '', true);

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app'
      and p.proname in ('guard_write_capability','enforce_booking_item_lifecycle')
      and (p.proacl is null or array_to_string(p.proacl, ',') like '%=X/%' and array_to_string(p.proacl, ',') like '%public%')),
  0,
  'PRIVILEGE: neither SECURITY DEFINER guard is executable by PUBLIC. A caller who could call them directly could pass an arbitrary trigger record');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app'
      and p.proname in ('guard_write_capability','guard_booking_item_financials','enforce_booking_item_lifecycle')
      and not (coalesce(array_to_string(p.proconfig, ','), '') like '%search_path=%')),
  0,
  'PRIVILEGE / SECDEF-1: all three guards on this surface pin search_path, so none of them can be redirected by a caller-set path');

select is(
  (select count(*)::int from pg_trigger t join pg_proc p on p.oid = t.tgfoid
    where t.tgrelid = 'public.booking_items'::regclass and not t.tgisinternal
      and p.proname = 'guard_write_capability'
      and (t.tgtype & 4) <> 0 and (t.tgtype & 16) <> 0),
  1,
  'DOOR: the capability trigger fires on INSERT *and* UPDATE. A trigger that covered only one verb is PAX-2''s defect, and it is the single most repeated shape in this register');

-- =============================================================================================
-- 39-40. REPLAY and CONCURRENCY, stated rather than performed, because both reduce to registered
--        design items and claiming otherwise would be claiming an attack that was not run.
-- =============================================================================================
-- The two constraints that DO exist are identity only: PRIMARY KEY (id) and UNIQUE (tenant_id, id),
-- the second being TENANT-1's composite-FK support key rather than a business rule. So the assertion
-- is about columns, not counts: nothing about WHAT was booked is unique.
select is(
  (select count(*)::int from pg_constraint c, unnest(c.conkey) k
    where c.conrelid = 'public.booking_items'::regclass and c.contype in ('u','p')
      and (select attname from pg_attribute
            where attrelid = c.conrelid and attnum = k) not in ('id','tenant_id')),
  0,
  'REPLAY: no uniqueness on booking_items covers any BUSINESS column -- only id and TENANT-1''s (tenant_id, id) support key -- so a replayed create makes a second distinct service. That is DC-2 (write-idempotency keys, DESIGN-READY), not a slice-5 defect, and it is pinned here so a future constraint cannot arrive unnoticed');

select ok(
  (select pg_get_functiondef(p.oid) from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname='app' and p.proname='guard_booking_item_financials') like '%old.owner_user_id%',
  'CONCURRENCY: the scope decision is taken from the row version this statement locked (the pre-image), not from a value the statement supplies. Two concurrent writers are serialised by that row lock; the lost-update question itself is DC-3');

-- =============================================================================================
-- 41-43. PAR-4 DEFECT INJECTION, in both directions, each rolled back and RE-asserted (TEST-3).
--        A guard that cannot be shown to fail has not been shown to work.
-- =============================================================================================
savepoint before_door_mutation;
drop trigger booking_items_guard_write_capability on public.booking_items;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a4","aal":"aal2"}', true);
set local role authenticated;
select lives_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code,
      currency_code, owner_user_id, owner_branch_id, owner_department_id)
    values ('b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-0000000000f1','hotel',
            'draft','EGP','b5000000-0000-0000-0000-000000000014',
            'b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1')$$,
  'MUTATION: with the capability trigger dropped, the trainee books a service again. Assertion 10 fails without it, so 10 is testing the trigger and not the weather');

reset role;
rollback to savepoint before_door_mutation;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a4","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$insert into public.booking_items (tenant_id, booking_id, service_type_code, base_status_code,
      currency_code, owner_user_id, owner_branch_id, owner_department_id)
    values ('b5000000-0000-0000-0000-000000000001','b5000000-0000-0000-0000-0000000000f1','hotel',
            'draft','EGP','b5000000-0000-0000-0000-000000000014',
            'b5000000-0000-0000-0000-00000000000a','b5000000-0000-0000-0000-0000000000c1')$$,
  '42501', null,
  'TEST-3: and refused again after the rollback, so this file leaves the schema byte-identical to the migration (PAR-2)');

reset role;
savepoint before_scope_mutation;
-- The PRE-repair scope computation, restored verbatim: `new` on both paths.
create or replace function app.guard_booking_item_financials()
returns trigger language plpgsql set search_path = ''
as $fn$
declare
    v_scoped boolean;
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    v_scoped := app.is_my_booking_item(new.owner_user_id, new.sales_owner_user_id,
                                       new.operational_owner_user_id)
                or app.has_tenant_wide_read();
    if tg_op = 'INSERT' then
        return new;
    end if;
    if new.cost_amount is distinct from old.cost_amount then
        perform app.authorize('ENTER_COST');
        if not v_scoped then
            raise exception 'ENTER_COST is scoped to items assigned to you (canon 28: assigned)'
                using errcode = 'insufficient_privilege';
        end if;
    end if;
    return new;
end
$fn$;
-- BOOK-9 is a second, independent enforcer on the same adversarial statement. Remove it inside
-- this savepoint so the mutation continues to isolate BOOK-5's PRE-image scope guard; rollback
-- restores both the function and this trigger before the identical negative control below.
drop trigger booking_items_guard_reassignment on public.booking_items;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;
select lives_ok(
  $$update public.booking_items
       set owner_user_id = 'b5000000-0000-0000-0000-000000000012',
           sales_owner_user_id = 'b5000000-0000-0000-0000-000000000012',
           cost_amount = 777
     where id = 'b5000000-0000-0000-0000-0000000000e3'$$,
  'MUTATION: with the pre-repair `new`-image scope restored, the ownership grab defeats canon 28 again -- assertion 14 comes back to life. Reading the PRE-image is the entire repair');

reset role;
rollback to savepoint before_scope_mutation;
select set_config('request.jwt.claims','{"sub":"b5000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$update public.booking_items
       set owner_user_id = 'b5000000-0000-0000-0000-000000000012',
           sales_owner_user_id = 'b5000000-0000-0000-0000-000000000012',
           cost_amount = 777
     where id = 'b5000000-0000-0000-0000-0000000000e3'$$,
  '42501', 'ENTER_COST is scoped to items assigned to you (canon 28: assigned)',
  'TEST-3: and refused again after the rollback. Both mutations are restored, so this file leaves the schema byte-identical to the migration (PAR-2)');

reset role;
select * from finish();
rollback;
