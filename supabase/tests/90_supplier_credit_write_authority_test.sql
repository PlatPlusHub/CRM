-- pgTAP: PD-24 / SUP-2 -- who may SET a supplier's credit ceiling.
--
-- `86_supplier_credit_visibility_test.sql` pins who may READ it. Its header says SEC-1c closed the
-- write half; SEC-1c closed it against a TRAINEE, who holds neither permission. This file pins the
-- actor neither package examined: `senior_employee`, who holds ASSIGN_SUPPLIER and NOT
-- VIEW_FINANCIAL_DOCUMENTS, and who could therefore write the figure they are refused on read.
--
-- The refusal is proven in the SAME session as the write, in that order, so the write is measured
-- against a caller whose ignorance of the value is established rather than assumed.
--
-- SUPERSEDED IN PART 2026-09-02 by SUP-3 (`202607059700`), and kept because what it proves is still
-- true. SUP-2 charged VIEW_FINANCIAL_DOCUMENTS on the write as the correct FLOOR available when
-- canon named no credit permission; the owner has since ruled that supplier credit management is its
-- own capability, so the charge is now MANAGE_SUPPLIER_CREDIT and the authority model is pinned by
-- `91_supplier_credit_permission_test.sql`. Every refusal below still holds -- `senior_employee`
-- holds neither permission -- so this file continues to guard SUP-2's hole specifically.
create extension if not exists pgtap with schema extensions;

begin;
select plan(18);

insert into auth.users (id, email, email_confirmed_at) values
  ('90000000-0000-0000-0000-0000000000a1','senior@sup90.test', now()),
  ('90000000-0000-0000-0000-0000000000a2','owner@sup90.test',  now());
insert into public.tenants (id, name, slug, status) values
  ('90000000-0000-0000-0000-000000000001','Sup90 Travel','sup90','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id='90000000-0000-0000-0000-000000000001';
insert into public.branches (id, tenant_id, name, slug) values
  ('90000000-0000-0000-0000-00000000000a','90000000-0000-0000-0000-000000000001','HQ','sup90-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('90000000-0000-0000-0000-0000000000c1','90000000-0000-0000-0000-000000000001',
   '90000000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('90000000-0000-0000-0000-000000000011','90000000-0000-0000-0000-000000000001','Senior','senior@sup90.test',true,'90000000-0000-0000-0000-0000000000a1'),
  ('90000000-0000-0000-0000-000000000012','90000000-0000-0000-0000-000000000001','Owner','owner@sup90.test', true,'90000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '90000000-0000-0000-0000-000000000001', u,
       '90000000-0000-0000-0000-00000000000a','90000000-0000-0000-0000-0000000000c1', true
from unnest(array['90000000-0000-0000-0000-000000000011'::uuid,
                  '90000000-0000-0000-0000-000000000012'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '90000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('90000000-0000-0000-0000-000000000011'::uuid,'senior_employee'),
             ('90000000-0000-0000-0000-000000000012'::uuid,'owner')) v(u,rc)
join public.roles r on r.code = v.rc;

-- Built as `postgres`, i.e. with no `auth.uid()`. Assertion 14 turns that into a claim rather than
-- leaving it as a convenience: the session-less path must stay open or every migration and seed that
-- ever writes a supplier breaks.
insert into public.suppliers (id, tenant_id, name, supplier_type_code, credit_limit_amount, credit_limit_currency_code) values
  ('90000000-0000-0000-0000-0000000000e1','90000000-0000-0000-0000-000000000001','Nile Air','airline', 1000, 'EGP');

-- =============================================================================================
-- 1. STRUCTURE. The guard covers BOTH write operations -- an INSERT-only trigger would leave
--    `update` open, which is the exact one-sided shape SEC-1c existed to clean up.
-- =============================================================================================
select is(
  (select count(*)::int from pg_trigger t
     join pg_class c on c.oid = t.tgrelid
     join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
    where not t.tgisinternal and c.relname = 'suppliers'
      and t.tgname = 'suppliers_guard_credit_authority'
      and t.tgtype & 4 = 4 and t.tgtype & 16 = 16),
  1,
  'SUP-2: suppliers carries a credit-authority guard on INSERT and UPDATE');

-- =============================================================================================
-- 2-5. THE PREMISE. The measured role-set gap, and the actor's ignorance of the value, proven
--      before the write is attempted rather than asserted about them afterwards.
-- =============================================================================================
select is(
  (select count(*)::int from public.roles r
    where exists (select 1 from public.role_permissions rp join public.permissions p on p.id=rp.permission_id
                   where rp.role_id=r.id and p.key='ASSIGN_SUPPLIER')
      and not exists (select 1 from public.role_permissions rp join public.permissions p on p.id=rp.permission_id
                   where rp.role_id=r.id and p.key='VIEW_FINANCIAL_DOCUMENTS')),
  3,
  'the gap is real and COUNTED: exactly 3 roles hold ASSIGN_SUPPLIER without VIEW_FINANCIAL_DOCUMENTS -- if this number moves, the premise of this file has changed and it should be re-read, not re-numbered');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select is(
  app.has_permission('ASSIGN_SUPPLIER'), true,
  'CONTROL: the senior employee genuinely HOLDS ASSIGN_SUPPLIER -- so every refusal below is the new guard, not a missing capability');

select is(
  app.has_permission('VIEW_FINANCIAL_DOCUMENTS'), false,
  'CONTROL: ...and does NOT hold VIEW_FINANCIAL_DOCUMENTS');

select throws_ok(
  $$select credit_limit_amount from public.suppliers where id = '90000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'CONTROL: ...and is refused the READ of the ceiling -- established in this same session, so the write below is a write by someone who does not know the value');

-- =============================================================================================
-- 6. POSITIVE CONTROL. The guard withholds a FIELD, not the table. Without this, a fix that
--    simply froze `suppliers` for three roles would pass every negative assertion in this file.
-- =============================================================================================
select lives_ok(
  $$update public.suppliers set phone = '+20 100 000 0000'
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  'POSITIVE CONTROL: the senior employee still edits an ordinary supplier field');

select is(
  (select phone from public.suppliers where id = '90000000-0000-0000-0000-0000000000e1'),
  '+20 100 000 0000',
  '...and that write actually LANDED -- "it did not throw" is not evidence a row changed');

-- =============================================================================================
-- 7-9. THE REPRODUCER, on both doors. Each of these succeeded before 202607059600.
-- =============================================================================================
select throws_ok(
  $$update public.suppliers set credit_limit_amount = 999999
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'SUP-2: setting the ceiling by direct DML is refused -- this returned UPDATE 1 before this migration');

select throws_ok(
  $$update public.suppliers set credit_limit_amount = null
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  '...and CLEARING it is refused too -- `is not distinct from` is what makes erasure a change rather than a no-op');

select throws_ok(
  $$select app.create_supplier('Delta Air','airline', null, null, null, 500000, 'EGP')$$,
  '42501', null,
  '...nor through the RPC, which still accepts the parameter and now authorizes it');

-- =============================================================================================
-- 10. ...while a supplier with NO ceiling stays ordinary work. A fix that broke this would have
--     charged a finance permission for creating master data.
-- =============================================================================================
select lives_ok(
  $$select app.create_supplier('Sinai Hotels','hotel')$$,
  'a supplier with NO credit terms is still creatable on ASSIGN_SUPPLIER alone');

-- =============================================================================================
-- 11-12. PAR-4 DEFECT INJECTION. Drop the named guard, prove the write succeeds, restore, prove
--        it is refused again -- so assertion 7 is pinned to THIS trigger and not to a coincidence.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

savepoint before_mutation;
drop trigger suppliers_guard_credit_authority on public.suppliers;

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

-- PORTED 2026-09-03 from the RECOVER-1 reconstruction, during the git-divergence reconciliation.
-- Two sessions built this file's mutation independently and solved the two-enforcer problem two
-- different ways; the other one asserted the COMPLEMENTARY fact, and it is kept rather than lost.
-- The pair below isolates THIS trigger by making the write non-credit-only. This assertion proves
-- the other half: with the dedicated trigger gone, a CREDIT-ONLY write is still refused. Together
-- they establish that the two guards are INDEPENDENT enforcers, not one mechanism counted twice --
-- which is the distinction that decides whether a single-trigger mutation measures anything at all.
select throws_ok(
  $$update public.suppliers set credit_limit_amount = 999999
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'MUTATION CONTROL: with the dedicated trigger dropped a CREDIT-ONLY write is STILL refused -- guard_write_capability''s credit branch is a second, independent enforcer (SUP-3)');

-- 202607059700 (SUP-3): this mutation pair names `credit_limit_amount` AND `phone`, and the second
-- column is load-bearing. SUP-3 gave `guard_write_capability` a credit-only branch that charges
-- MANAGE_SUPPLIER_CREDIT, so on a credit-ONLY write there are now TWO guards demanding a permission
-- this actor lacks -- dropping one leaves the other, the `lives_ok` fails, and the paired `throws_ok`
-- would still pass on the survivor while measuring nothing. That is the same defect this file's own
-- header describes in test 85, arriving here the moment a second enforcement point appeared.
-- Adding an ordinary column makes the write NOT credit-only, so `guard_write_capability` charges
-- ASSIGN_SUPPLIER (which this actor HOLDS) and `guard_supplier_credit_authority` is the sole refuser
-- -- which is exactly what this pair must isolate.
select lives_ok(
  $$update public.suppliers set credit_limit_amount = 999999, phone = '+20 100 000 5555'
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  'MUTATION: with the guard dropped the senior employee CAN set the ceiling -- the refusal above is this trigger');

reset role;
select set_config('request.jwt.claims', null, true);
rollback to savepoint before_mutation;

-- Re-established deliberately: after a rollback an unset session measures "never attempted" rather
-- than "denied", the confusion already met in tests 70, 72 and 85.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);

select throws_ok(
  $$update public.suppliers set credit_limit_amount = 999999, phone = '+20 100 000 5555'
     where id = '90000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  '...and with it restored the refusal returns -- the pair is what makes assertion 7 load-bearing');

-- =============================================================================================
-- 13. THE OWNER CAN. A guard that stopped everyone would be a capability regression, which is the
--     failure mode SUP-1's own fix was checked against.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"90000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select is(
  (select credit_limit_amount from public.supplier_credit('90000000-0000-0000-0000-0000000000e1')),
  1000::numeric,
  'POSITIVE CONTROL: the owner holds both permissions and reads the REAL ceiling');

-- =============================================================================================
-- 14. THE SESSION-LESS PATH stays open. Migrations, seeds and `provision_tenant` write suppliers
--     with no `auth.uid()`; charging them a tenant permission would break every one of them.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select lives_ok(
  $$insert into public.suppliers (tenant_id, name, supplier_type_code, credit_limit_amount, credit_limit_currency_code)
    values ('90000000-0000-0000-0000-000000000001','Seeded Air','airline', 7500, 'EGP')$$,
  'the session-less platform path still writes a ceiling -- canon 35 principle 6, as in every sibling guard');

-- =============================================================================================
-- 16-17. SUP-4a -- CANON 30's MONEY STANDARD, as a class rather than as one column.
--        Canon 30: "Currency code should be stored separately", `currency_code text not null`,
--        referencing `currencies.code`. Eleven public tables carry a money-amount column and
--        `suppliers` was the ONLY one without a currency companion -- which is precisely why the
--        ceiling could not be compared to `app.supplier_balance`'s per-currency payable. The
--        assertion is written over `information_schema` with no exemption list, so the next
--        money column added without a currency fails here rather than being discovered by a
--        defect years later.
-- =============================================================================================
reset role;
select is(
  (select coalesce(string_agg(distinct t.table_name, ', ' order by t.table_name), '')
     from information_schema.columns t
    where t.table_schema = 'public'
      and (t.column_name ~ '_amount$' or t.column_name = 'amount')
      -- a per-currency companion column satisfies the standard however it is named on that table
      and not exists (
        select 1 from information_schema.columns c2
         where c2.table_schema = 'public' and c2.table_name = t.table_name
           and c2.column_name ~ 'currency_code$')),
  '',
  'CANON 30 (SUP-4a): every table with a money amount carries a currency code -- no exemption list, so a new one cannot slip in');

select is(
  (select count(*)::int from pg_constraint c
     where c.conrelid = 'public.suppliers'::regclass
       and c.conname = 'suppliers_credit_limit_currency_check'),
  1,
  '...and the ceiling''s two halves are bound together: an amount without its currency, or a currency without its amount, is refused');

select * from finish();
rollback;
