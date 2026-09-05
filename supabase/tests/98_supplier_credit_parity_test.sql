-- pgTAP: SUP-4d + CUST-4 + CUST-5 + SUP-4c -- the supplier ceiling reaches parity with the customer
-- one (`202607060600`).
--
-- WHAT MUST BE TRUE, and each of the four is asserted by REPRODUCING the defect it closes rather
-- than by observing that the new code exists:
--   * SUP-4d -- setting a ceiling BELOW an exposure that already stands must alert. The defect is an
--     ABSENCE (no probe on the ceiling), so the only honest proof is the sequence that used to be
--     silent: expose first, set the ceiling second, no write to an exposure table in between;
--   * CUST-4 -- a negative ceiling must be REFUSED, not merely undeclared;
--   * CUST-5 -- the credit-only branch must survive a sibling BEFORE trigger that mutates `new`.
--     Injected here on purpose, because that is precisely the condition `suppliers` does not carry
--     today and the reason the old row-image form was "correct only by accident";
--   * SUP-4c -- exposure in a currency other than the ceiling's must be CONVERTED, and when it
--     cannot be, REPORTED. Silence is the defect.
--
-- Alerts are proven by their EFFECTS (event row + notification + pending email delivery), never by
-- "the function did not throw" (AGENTS.md 6: no vacuous security tests).
create extension if not exists pgtap with schema extensions;

begin;
select plan(18);

insert into auth.users (id, email, email_confirmed_at) values
  ('98000000-0000-0000-0000-0000000000a1','owner@sup98.test',   now()),
  ('98000000-0000-0000-0000-0000000000a2','finance@sup98.test', now()),
  ('98000000-0000-0000-0000-0000000000a3','emp@sup98.test',     now());
insert into public.tenants (id, name, slug, status) values
  ('98000000-0000-0000-0000-000000000001','Sup98 Travel','sup98','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id='98000000-0000-0000-0000-000000000001';
insert into public.branches (id, tenant_id, name, slug) values
  ('98000000-0000-0000-0000-00000000000a','98000000-0000-0000-0000-000000000001','HQ','sup98-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('98000000-0000-0000-0000-0000000000c1','98000000-0000-0000-0000-000000000001',
   '98000000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('98000000-0000-0000-0000-000000000011','98000000-0000-0000-0000-000000000001','Owner','owner@sup98.test',true,'98000000-0000-0000-0000-0000000000a1'),
  ('98000000-0000-0000-0000-000000000012','98000000-0000-0000-0000-000000000001','Finance','finance@sup98.test',true,'98000000-0000-0000-0000-0000000000a2'),
  ('98000000-0000-0000-0000-000000000013','98000000-0000-0000-0000-000000000001','Emp','emp@sup98.test',true,'98000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '98000000-0000-0000-0000-000000000001', u,
       '98000000-0000-0000-0000-00000000000a','98000000-0000-0000-0000-0000000000c1', true
from unnest(array['98000000-0000-0000-0000-000000000011'::uuid,
                  '98000000-0000-0000-0000-000000000012'::uuid,
                  '98000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '98000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('98000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('98000000-0000-0000-0000-000000000012'::uuid,'finance_manager'),
             ('98000000-0000-0000-0000-000000000013'::uuid,'employee')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('98000000-0000-0000-0000-0000000000d1','98000000-0000-0000-0000-000000000001','person','Customer');
insert into public.bookings (id, tenant_id, branch_id, department_id, customer_id, booking_status_code, title, booking_reference, owner_user_id) values
  ('98000000-0000-0000-0000-0000000000b1','98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-00000000000a','98000000-0000-0000-0000-0000000000c1','98000000-0000-0000-0000-0000000000d1','confirmed','Trip','BR-SUP98-1','98000000-0000-0000-0000-000000000011');

-- e1 starts with NO ceiling: SUP-4d's reproduction needs exposure to exist BEFORE any ceiling does.
-- e2 carries a ceiling from the start and is the FX subject. e3 is the null control.
insert into public.suppliers (id, tenant_id, name, supplier_type_code, credit_limit_amount, credit_limit_currency_code) values
  ('98000000-0000-0000-0000-0000000000e1','98000000-0000-0000-0000-000000000001','Late Ceiling Air','airline', null, null),
  ('98000000-0000-0000-0000-0000000000e2','98000000-0000-0000-0000-000000000001','FX Air','airline', 1000, 'EGP'),
  ('98000000-0000-0000-0000-0000000000e3','98000000-0000-0000-0000-000000000001','Uncapped Air','airline', null, null);

-- =============================================================================================
-- 1-3. CUST-4. A negative ceiling is meaningless in both directions: `exposure > limit` against a
--      negative limit fires on the first unit of exposure and can NEVER clear. Asserted as
--      BEHAVIOUR (the write is refused) and not merely as a catalog row, then paired with the
--      customer constraint it mirrors so the two tables cannot drift apart again.
-- =============================================================================================
select throws_ok(
  $$insert into public.suppliers (tenant_id, name, supplier_type_code, credit_limit_amount, credit_limit_currency_code)
    values ('98000000-0000-0000-0000-000000000001','Negative Air','airline', -1, 'EGP')$$,
  '23514', null,
  'CUST-4: a NEGATIVE supplier ceiling is REFUSED by a CHECK constraint -- a limit that can never be cleared is not a limit');

select lives_ok(
  $$insert into public.suppliers (id, tenant_id, name, supplier_type_code, credit_limit_amount, credit_limit_currency_code)
    values ('98000000-0000-0000-0000-0000000000e9','98000000-0000-0000-0000-000000000001','Zero Air','airline', 0, 'EGP')$$,
  'CUST-4: ZERO is still a valid ceiling -- the constraint is >= 0, not > 0, so "this supplier gets no credit at all" remains expressible');

select is(
  (select count(*)::int from pg_constraint
    where conname in ('suppliers_credit_limit_non_negative_check','customers_credit_limit_non_negative_check')
      and contype = 'c'),
  2,
  'CUST-4: BOTH credit tables carry the non-negative constraint -- the asymmetry CUST-3 left behind is gone');

-- =============================================================================================
-- 4-8. SUP-4d. THE REPRODUCTION. Exposure is created while the supplier has NO ceiling, so no
--      threshold can be crossed and nothing may alert. The ceiling is then set BELOW that standing
--      exposure with NO write to booking_items or payments in between. Before `202607060600` this
--      sequence was completely silent: SUP-4b hooked only the two exposure tables, so a ceiling
--      that moved under a standing exposure moved unobserved.
-- =============================================================================================
insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code, cost_locked_at) values
  ('98000000-0000-0000-0000-0000000000f1','98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-0000000000b1','98000000-0000-0000-0000-0000000000e1','flight_ticket','EGP',5000,6000,'confirmed', now());

select is(
  (select count(*)::int from public.events
    where entity_id='98000000-0000-0000-0000-0000000000e1'
      and event_type_code like 'supplier_credit_threshold%'),
  0,
  'SUP-4d CONTROL: exposure of 5000 against NO ceiling alerts nothing -- so the alert below is caused by the CEILING moving, not by the exposure');

update public.suppliers
   set credit_limit_amount = 1000, credit_limit_currency_code = 'EGP'
 where id = '98000000-0000-0000-0000-0000000000e1';

select is(
  (select count(*)::int from public.events
    where entity_id='98000000-0000-0000-0000-0000000000e1'
      and event_type_code='supplier_credit_threshold_exceeded'),
  1,
  'SUP-4d: setting a ceiling BELOW a standing exposure ALERTS -- lowering a ceiling is exactly when a credit control should speak');

select is(
  (select (payload->>'enforcement') from public.events
    where entity_id='98000000-0000-0000-0000-0000000000e1'
      and event_type_code='supplier_credit_threshold_exceeded' limit 1),
  'warning_only',
  'SUP-4d: the ceiling probe WARNS -- it is an AFTER trigger returning null and refuses nothing, exactly as the customer probe does');

select is(
  (select count(*)::int from public.notification_deliveries d
    join public.notifications n on n.id=d.notification_id
   where n.related_entity_id='98000000-0000-0000-0000-0000000000e1'
     and d.channel_code='email' and d.delivery_status_code='pending'),
  2,
  'SUP-4d: the email obligation is RECORDED as pending for both finance recipients -- not claimed as sent, because ORVION still has no mail provider');

update public.suppliers set name = 'Late Ceiling Air (renamed)'
 where id = '98000000-0000-0000-0000-0000000000e3';

select is(
  (select count(*)::int from public.events
    where entity_id='98000000-0000-0000-0000-0000000000e3'
      and event_type_code like 'supplier_credit_threshold%'),
  0,
  'SUP-4d: the probe''s WHEN clause holds -- an ordinary edit to a supplier with NO ceiling costs nothing and evaluates nothing');

-- =============================================================================================
-- 9-12. SUP-4c. Exposure in a currency other than the ceiling''s is CONVERTED at the spot rate
--       (12 CFR 32.9 mark-to-market, the rule already ratified for CUST-3), and a currency with no
--       usable rate is REPORTED rather than dropped. The replaced function filtered
--       `bi.currency_code = p_currency_code` and returned a number that LOOKED complete.
-- =============================================================================================
insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at, set_by)
values ('98000000-0000-0000-0000-000000000001','USD','EGP', 50, now() - interval '1 day','98000000-0000-0000-0000-000000000011');

insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code, cost_locked_at) values
  ('98000000-0000-0000-0000-0000000000f2','98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-0000000000b1','98000000-0000-0000-0000-0000000000e2','flight_ticket','USD',30,40,'confirmed', now());

select is(
  (select e.exposure from app.supplier_exposure_in_limit_currency(
      '98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-0000000000e2','EGP') e),
  1500::numeric,
  'SUP-4c: USD 30 against an EGP ceiling is CONVERTED at the spot rate (30 x 50 = 1500 EGP) -- the old function dropped it and reported 0');

select is(
  (select e.unconvertible from app.supplier_exposure_in_limit_currency(
      '98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-0000000000e2','EGP') e),
  '{}'::text[],
  'SUP-4c: with a usable rate nothing is unconvertible -- the gap list is empty rather than absent');

insert into public.booking_items (id, tenant_id, booking_id, supplier_id, service_type_code, currency_code, cost_amount, selling_amount, base_status_code, cost_locked_at) values
  ('98000000-0000-0000-0000-0000000000f3','98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-0000000000b1','98000000-0000-0000-0000-0000000000e2','hotel','GBP',20,25,'confirmed', now());

select is(
  (select e.unconvertible from app.supplier_exposure_in_limit_currency(
      '98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-0000000000e2','EGP') e),
  array['GBP'],
  'SUP-4c: a currency with real exposure and NO rate is NAMED -- the figure is incomplete and says so, instead of silently understating the payable');

select is(
  (select e.exposure from app.supplier_exposure_in_limit_currency(
      '98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-0000000000e2','EGP') e),
  1500::numeric,
  'SUP-4c: the CONVERTIBLE part is still compared -- an unpriceable currency degrades the figure, it does not abandon the control');

-- =============================================================================================
-- 13-14. SUP-4c at the API door. The gated reader must carry the gap list too, or the incomplete
--        figure becomes complete again the moment a human reads it.
-- =============================================================================================
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public' and p.proname='supplier_credit'
      and 'unconvertible_currencies' = any(p.proargnames)),
  1,
  'SUP-4c: public.supplier_credit exposes unconvertible_currencies -- the honesty CUST-3 built for customers now reaches the supplier API');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='app' and p.proname='supplier_exposure_in_limit_currency'
      and has_function_privilege('authenticated', p.oid, 'EXECUTE')),
  0,
  'GRANT-1: the recreated exposure helper is STILL not a second read door -- DROP+CREATE resets the ACL, and the revoke was restated because of it');

-- =============================================================================================
-- 15-18. CUST-5. THE INJECTION THAT MATTERS. The old branch decided "credit-only" by comparing full
--        row images, which held only because `suppliers` happens to carry no BEFORE trigger that
--        mutates `new`. A `derive_*` trigger is added here -- sorting BEFORE `guard_write_capability`
--        exactly as `customers_derive_first_registration_actor` does on the table where this ALREADY
--        FAILED -- and the credit-only write must still be authorised by MANAGE_SUPPLIER_CREDIT
--        alone. Under the replaced form this write was REFUSED.
--
--        The actor holds MANAGE_SUPPLIER_CREDIT through a USER GRANT and holds no supplier role
--        permission at all: `employee` carries neither ASSIGN_SUPPLIER nor MANAGE_SUPPLIER_CREDIT
--        (measured). That is the only actor shape that can tell the two forms apart, because
--        MANAGE_SUPPLIER_CREDIT is a strict subset of ASSIGN_SUPPLIER at ROLE level.
-- =============================================================================================
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '98000000-0000-0000-0000-000000000001','98000000-0000-0000-0000-000000000013', p.id, 'grant',
       'CUST-5 test: the only actor shape that distinguishes the row-image form from the OR-list form'
from public.permissions p where p.key = 'MANAGE_SUPPLIER_CREDIT';

create function app.derive_sup98_probe() returns trigger
language plpgsql set search_path = '' as $$
begin
    -- Mutates `new` in a column the replaced row-image comparison did NOT exclude, which is the
    -- whole failure mode: the guard would compare a row a sibling had already changed. `phone` is
    -- chosen because no other trigger on `suppliers` reads or writes it, so the injection tests the
    -- guard and nothing else.
    new.phone := coalesce(new.phone, '') || '.';
    return new;
end;
$$;

-- `derive_` sorts before `guard_` -- the same alphabetical accident that made this fail on customers.
create trigger suppliers_derive_sup98_probe
    before insert or update on public.suppliers
    for each row execute function app.derive_sup98_probe();

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"98000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);

select is(
  (select app.has_permission('ASSIGN_SUPPLIER')),
  false,
  'CUST-5 CONTROL: the actor does NOT hold ASSIGN_SUPPLIER -- without this the next assertion would pass for the wrong reason');

select is(
  (select app.has_permission('MANAGE_SUPPLIER_CREDIT')),
  true,
  'CUST-5 CONTROL: the actor holds MANAGE_SUPPLIER_CREDIT through a user grant -- role bundles alone cannot produce this shape');

select lives_ok(
  $$update public.suppliers set credit_limit_amount = 2000
     where id = '98000000-0000-0000-0000-0000000000e2'$$,
  'CUST-5: a credit-only write survives a sibling BEFORE trigger that mutates `new` -- the OR-list needs no row image, and the row-image form would have REFUSED this exact write');

reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select credit_limit_amount from public.suppliers where id='98000000-0000-0000-0000-0000000000e2'),
  2000::numeric,
  'CUST-5: ...and the write LANDED -- lives_ok alone would pass if the statement had matched no rows');

drop trigger suppliers_derive_sup98_probe on public.suppliers;
drop function app.derive_sup98_probe();

select * from finish();
rollback;
