-- pgTAP: PD-24 / SUP-3 -- supplier credit management is its OWN permission (owner decision 2026-09-02).
--
-- SUP-2 (`90_...`) proved the ceiling's write cost less than its read and charged the READ permission
-- as an interim floor. The owner has since ruled that supplier credit management must be its own
-- independently grantable capability, and that `finance_manager` must hold it. This file pins the
-- resulting model, whose whole point is ORTHOGONALITY:
--
--     MANAGE_SUPPLIER_CREDIT   -> may set the ceiling, and NOTHING else about a supplier
--     ASSIGN_SUPPLIER          -> may administer the supplier, and NOT its ceiling
--     VIEW_FINANCIAL_DOCUMENTS -> may READ the ceiling; grants no write authority
--
-- Each of the three is proven not to imply either of the others, in BOTH directions. The grant and
-- revoke assertions run against a role that does NOT hold the permission by default, because the
-- owner's requirement is that any capability be independently grantable and revocable per actor --
-- an assertion that only ever reads the seeded grants would never test that at all.
create extension if not exists pgtap with schema extensions;

begin;
select plan(26);

insert into auth.users (id, email, email_confirmed_at) values
  ('91000000-0000-0000-0000-0000000000a1','fin@sup91.test',    now()),
  ('91000000-0000-0000-0000-0000000000a2','senior@sup91.test', now()),
  ('91000000-0000-0000-0000-0000000000a3','owner@sup91.test',  now());
insert into public.tenants (id, name, slug, status) values
  ('91000000-0000-0000-0000-000000000001','Sup91 Travel','sup91','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id='91000000-0000-0000-0000-000000000001';
insert into public.branches (id, tenant_id, name, slug) values
  ('91000000-0000-0000-0000-00000000000a','91000000-0000-0000-0000-000000000001','HQ','sup91-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('91000000-0000-0000-0000-0000000000c1','91000000-0000-0000-0000-000000000001',
   '91000000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('91000000-0000-0000-0000-000000000011','91000000-0000-0000-0000-000000000001','Fin','fin@sup91.test',true,'91000000-0000-0000-0000-0000000000a1'),
  ('91000000-0000-0000-0000-000000000012','91000000-0000-0000-0000-000000000001','Senior','senior@sup91.test',true,'91000000-0000-0000-0000-0000000000a2'),
  ('91000000-0000-0000-0000-000000000013','91000000-0000-0000-0000-000000000001','Owner','owner@sup91.test',true,'91000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '91000000-0000-0000-0000-000000000001', u,
       '91000000-0000-0000-0000-00000000000a','91000000-0000-0000-0000-0000000000c1', true
from unnest(array['91000000-0000-0000-0000-000000000011'::uuid,'91000000-0000-0000-0000-000000000012'::uuid,
                  '91000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '91000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('91000000-0000-0000-0000-000000000011'::uuid,'finance_manager'),
             ('91000000-0000-0000-0000-000000000012'::uuid,'senior_employee'),
             ('91000000-0000-0000-0000-000000000013'::uuid,'owner')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.suppliers (id, tenant_id, name, supplier_type_code, credit_limit_amount, phone) values
  ('91000000-0000-0000-0000-0000000000e1','91000000-0000-0000-0000-000000000001','Nile Air','airline', 1000, '+20 100 000 0001');

-- =============================================================================================
-- 1-3. THE PERMISSION ITSELF.
-- =============================================================================================
select is(
  (select count(*)::int from public.permissions
    where key='MANAGE_SUPPLIER_CREDIT' and is_system and is_active),
  1,
  'SUP-3: MANAGE_SUPPLIER_CREDIT exists as an active system permission');

select is(
  (select required_feature_code from public.permissions where key='MANAGE_SUPPLIER_CREDIT'),
  (select required_feature_code from public.permissions where key='VIEW_FINANCIAL_DOCUMENTS'),
  '...entitled at the SAME plan tier as the permission that governs READING the figure -- a plan that grants the write without the read would be SUP-2 one level up');

select is(
  (select string_agg(r.code, ',' order by r.code)
     from public.roles r
     join public.role_permissions rp on rp.role_id=r.id
     join public.permissions p on p.id=rp.permission_id
    where p.key='MANAGE_SUPPLIER_CREDIT'),
  'ceo,finance_manager,owner',
  '...granted to exactly ceo/finance_manager/owner -- the owner rule adds finance_manager and keeps owner+ceo, and does NOT restore the three roles SUP-2 removed');

-- =============================================================================================
-- 4-9. FINANCE MANAGER: holds the new permission and NOT ASSIGN_SUPPLIER. This is owner rule 1,
--      and it is also the orthogonality proof in one direction.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select is(app.has_permission('MANAGE_SUPPLIER_CREDIT'), true,
  'CONTROL: finance_manager holds MANAGE_SUPPLIER_CREDIT');
select is(app.has_permission('ASSIGN_SUPPLIER'), false,
  'CONTROL: ...and does NOT hold ASSIGN_SUPPLIER -- so the write below cannot be riding on supplier administration');

select lives_ok(
  $$update public.suppliers set credit_limit_amount = 5000
     where id = '91000000-0000-0000-0000-0000000000e1'$$,
  'OWNER RULE 1: finance_manager CAN set a supplier credit limit');

select is(
  (select credit_limit_amount from public.supplier_credit('91000000-0000-0000-0000-0000000000e1')),
  5000::numeric,
  '...and the value actually CHANGED -- read back through the gated reader, not inferred from the absence of an error');

-- The counterexample that proves the credit-only relaxation is doing the work: same actor, same
-- table, same column -- only the presence of a SECOND changed column differs.
select throws_ok(
  $$update public.suppliers set credit_limit_amount = 6000, phone = '+20 100 000 0002'
     where id = '91000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'ORTHOGONAL: the same write PLUS an ordinary column is refused -- credit authority is not supplier authority');

select throws_ok(
  $$update public.suppliers set phone = '+20 100 000 0003'
     where id = '91000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  '...and an ordinary supplier edit alone is refused too -- MANAGE_SUPPLIER_CREDIT grants nothing beyond the ceiling');

-- =============================================================================================
-- 10-13. SENIOR EMPLOYEE: holds ASSIGN_SUPPLIER and NOT the new permission. The other direction,
--        and the proof that SUP-2's hole stays closed under the new model.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select is(app.has_permission('ASSIGN_SUPPLIER'), true,
  'CONTROL: senior_employee holds ASSIGN_SUPPLIER');
select is(app.has_permission('MANAGE_SUPPLIER_CREDIT'), false,
  'CONTROL: ...and not MANAGE_SUPPLIER_CREDIT');

select throws_ok(
  $$update public.suppliers set credit_limit_amount = 999999
     where id = '91000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'ORTHOGONAL + SUP-2 STAYS CLOSED: ASSIGN_SUPPLIER does not imply credit management');

select lives_ok(
  $$update public.suppliers set phone = '+20 100 000 0004'
     where id = '91000000-0000-0000-0000-0000000000e1'$$,
  'REGRESSION: ordinary supplier administration still works on ASSIGN_SUPPLIER alone');

-- =============================================================================================
-- 14-18. INDEPENDENT GRANT AND REVOKE. The owner's stated architecture is that any capability can
--        be granted or revoked for an individual actor. Asserting only the seeded grants would
--        never test that, so the permission is granted to a role that does not have it and taken
--        away again -- with the actor's behaviour measured after each.
-- =============================================================================================
reset role;
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id from public.roles r cross join public.permissions p
where r.code='senior_employee' and p.key='MANAGE_SUPPLIER_CREDIT';

select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select is(app.has_permission('MANAGE_SUPPLIER_CREDIT'), true,
  'MUTATION (grant): the permission is now genuinely held -- verified before the behaviour is measured');

select lives_ok(
  $$update public.suppliers set credit_limit_amount = 4321
     where id = '91000000-0000-0000-0000-0000000000e1'$$,
  'GRANT: ...and the same actor whose write was refused above now succeeds');

-- The owner's visibility requirement, tested on the one actor that can express it: senior_employee
-- holds MANAGE_SUPPLIER_CREDIT and NOT VIEW_FINANCIAL_DOCUMENTS. No seeded role has that shape.
select is(app.has_permission('VIEW_FINANCIAL_DOCUMENTS'), false,
  'VISIBILITY IS SEPARATE: this actor holds the write permission and NOT the financial-view permission');

select throws_ok(
  $$select credit_limit_amount from public.suppliers where id = '91000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  '...and STILL cannot read the ceiling -- write authority did not become visibility');

select is(
  (select permitted from public.supplier_credit('91000000-0000-0000-0000-0000000000e1')),
  false,
  '...nor through the gated reader -- MANAGE_SUPPLIER_CREDIT bought no financial visibility at all');

reset role;
delete from public.role_permissions rp
using public.roles r, public.permissions p
where rp.role_id=r.id and rp.permission_id=p.id
  and r.code='senior_employee' and p.key='MANAGE_SUPPLIER_CREDIT';

select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select is(app.has_permission('MANAGE_SUPPLIER_CREDIT'), false,
  'MUTATION (revoke): the permission is genuinely gone -- verified before the behaviour is measured');

select throws_ok(
  $$update public.suppliers set credit_limit_amount = 7777
     where id = '91000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'REVOKE: ...and the capability goes with it -- independently revocable, which is the whole point of the fine-grained model');

-- =============================================================================================
-- 19-21. THE RPC DOOR. `create_supplier` still accepts the parameter and now authorizes it.
-- =============================================================================================
select throws_ok(
  $$select app.create_supplier('Ceiling Co','hotel', null, null, null, 500000)$$,
  '42501', null,
  'the RPC door is charged the same permission -- creating a supplier WITH credit terms needs it');

select lives_ok(
  $$select app.create_supplier('No Terms Co','hotel')$$,
  '...while a supplier with NO credit terms is still ordinary work on ASSIGN_SUPPLIER alone');

-- =============================================================================================
-- 22-23. PAR-4 DEFECT INJECTION on `guard_supplier_credit_authority`.
--        The mutation is chosen so that this trigger is the ONLY refuser: an ASSIGN_SUPPLIER holder
--        changing the ceiling AND another column passes `guard_write_capability` (the write is not
--        credit-only, so ASSIGN_SUPPLIER is what it charges) and is stopped solely here. Using a
--        credit-ONLY write would have been the test-85 mistake -- both guards would demand the same
--        permission and dropping one would prove nothing.
-- =============================================================================================
reset role;
select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid=t.tgrelid
    where not t.tgisinternal and c.relname='suppliers' and t.tgname='suppliers_guard_credit_authority'),
  1,
  'CONTROL: the guard is present before the mutation -- the harness is measuring a real object');

savepoint before_mutation;
drop trigger suppliers_guard_credit_authority on public.suppliers;

select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$update public.suppliers set credit_limit_amount = 888888, phone = '+20 100 000 0009'
     where id = '91000000-0000-0000-0000-0000000000e1'$$,
  'MUTATION: with the credit guard dropped, an ASSIGN_SUPPLIER holder CAN move the ceiling -- so the refusals above are this trigger');

reset role;
rollback to savepoint before_mutation;

-- Re-established after the rollback: an unset session measures "never attempted" rather than
-- "denied", the confusion already met in tests 70, 72, 85 and 90.
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$update public.suppliers set credit_limit_amount = 888888, phone = '+20 100 000 0009'
     where id = '91000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  '...and with it restored the refusal returns -- the pair is what makes the assertions above load-bearing');

-- =============================================================================================
-- 24. THE OWNER retains authority. A change that narrowed the ceiling to finance alone would be a
--     capability regression, and the owner directed that none be removed silently.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$update public.suppliers set credit_limit_amount = 33000
     where id = '91000000-0000-0000-0000-0000000000e1'$$,
  'the owner still sets a ceiling -- holding both ASSIGN_SUPPLIER and MANAGE_SUPPLIER_CREDIT');

select * from finish();
rollback;
