-- pgTAP: Batch 6 slice 59 (nationalities, countries, currencies, and languages with them) -- REF-2.
-- The four reference lists are platform-owned (only migrations write them; test 180 and the slice 59
-- probes pin the grants). The owner's policy of 2026-11-18: a deactivated nationality, country,
-- currency or language stays on every row that already holds it, and that row stays editable; a new
-- create, or a change of that field, refuses it. app.enforce_reference_codes() carries the rule of
-- app.enforce_catalog_codes to the eight tables whose rows are new business. Proven here, after a
-- positive control with every value active: each of the ten guarded columns refuses the deactivated
-- value at create (the tenant through app.provision_tenant as the platform); each existing row keeps
-- it through an edit of another field; each column moves to another active value and refuses the move
-- back; an unknown code is still the foreign key's; and settling business already made in a
-- deactivated currency (a quotation item, an invoice and its payment, a refund) still works, as the
-- migration's Positions record. quotations.currency_code at change is also held by
-- app.guard_quotation_integrity (test 79), so its change is not re-proven here.
-- ATTACK-CLASSES: AUTH TENANT=N/A DOOR STATE INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY=N/A
--   TENANT=N/A -- the reference lists are platform-wide and the guard reads no tenant row; each actor
--     here writes only its own tenant's rows, under the policies other tests pin.
--   CONCURRENCY=N/A -- only migrations deactivate a value; a create meeting a deactivation sees either
--     state, and each state is the rule.
--   REPLAY=N/A -- no token or event is consumed; a repeated create is a new create, refused the same.
--   OBSERVABILITY=N/A -- a refused write leaves no row and no event; the 23514 message names the
--     table, the column, the value and the list.
create extension if not exists pgtap with schema extensions;

begin;
select plan(31);

insert into auth.users (id, email) values
  ('18100000-0000-0000-0000-0000000000a1','owner@c181.test'),
  ('18100000-0000-0000-0000-0000000000a2','employee@c181.test');
insert into public.tenants (id, name, slug, status, default_currency_code) values
  ('18100000-0000-0000-0000-000000000001','Reference Travel','reference-travel-181','active','EUR');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code, starts_at)
select '18100000-0000-0000-0000-000000000001', sp.id, 'active', now() - interval '2 days'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('18100000-0000-0000-0000-0000000000b1','18100000-0000-0000-0000-000000000001','Giza','giza-181');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('18100000-0000-0000-0000-0000000000c1','18100000-0000-0000-0000-000000000001','18100000-0000-0000-0000-0000000000b1','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('18100000-0000-0000-0000-000000000011','18100000-0000-0000-0000-000000000001','Owner','owner@c181.test',true,'18100000-0000-0000-0000-0000000000a1'),
  ('18100000-0000-0000-0000-000000000012','18100000-0000-0000-0000-000000000001','Employee','employee@c181.test',true,'18100000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('18100000-0000-0000-0000-000000000001','18100000-0000-0000-0000-000000000012','18100000-0000-0000-0000-0000000000b1','18100000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '18100000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values
  ('18100000-0000-0000-0000-000000000011'::uuid, 'owner'),
  ('18100000-0000-0000-0000-000000000012', 'employee')) v(u, c)
join public.roles r on r.code = v.c;

-- =============================================================================================
-- 1-3. THE GUARD: a definer function with an empty search_path that no API role may call, on eight tables.
-- =============================================================================================
select is(
  (select prosecdef::text || '/' || array_to_string(proconfig, ',')
     from pg_proc where oid = 'app.enforce_reference_codes()'::regprocedure),
  'true/search_path=""',
  'app.enforce_reference_codes is SECURITY DEFINER with an empty search_path');
select is(
  (select string_agg(r || '=' || has_function_privilege(r, 'app.enforce_reference_codes()', 'EXECUTE'), ',' order by r)
     from unnest(array['anon','authenticated','orvion_integration','service_role']) r),
  'anon=false,authenticated=false,orvion_integration=false,service_role=false',
  'no API role may call the guard directly');
select is(
  (select count(*) filter (where pg_get_triggerdef(t.oid) ~ ('^CREATE TRIGGER ' || c.relname
            || '_enforce_reference_codes BEFORE INSERT OR UPDATE ON public\.' || c.relname
            || ' FOR EACH ROW EXECUTE FUNCTION app\.enforce_reference_codes\('))::text || '|'
       || string_agg(c.relname || '(' || substring(pg_get_triggerdef(t.oid) from 'enforce_reference_codes\((.*)\)$') || ')', ';' order by c.relname)
     from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and t.tgfoid = 'app.enforce_reference_codes()'::regprocedure),
  '8|booking_items(''currency_code'', ''currencies'');bookings(''destination_country_code'', ''countries'');'
    || 'customers(''preferred_language_code'', ''languages'', ''credit_limit_currency_code'', ''currencies'');'
    || 'financial_accounts(''currency_code'', ''currencies'');'
    || 'passengers(''nationality_code'', ''nationalities'', ''passport_issuing_country_code'', ''countries'');'
    || 'quotations(''currency_code'', ''currencies'');suppliers(''credit_limit_currency_code'', ''currencies'');'
    || 'tenants(''default_currency_code'', ''currencies'')',
  'the guard is BEFORE INSERT OR UPDATE FOR EACH ROW on exactly the eight tables, with these (column, list) pairs');

-- =============================================================================================
-- 4. POSITIVE CONTROL: with every value active, each create succeeds (these rows are the existing ones below).
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select set_config('t181.p', app.create_passenger('T181', 'One', p_nationality_code => 'FR', p_passport_issuing_country_code => 'FR')::text, true);
select set_config('t181.c', app.create_customer('person', 'T181 Customer', p_primary_phone => '+20100000181', p_preferred_language_code => 'fr')::text, true);
select set_config('t181.b', app.create_booking(p_customer_id => current_setting('t181.c')::uuid, p_title => 'T181 trip',
  p_branch_id => '18100000-0000-0000-0000-0000000000b1', p_department_id => '18100000-0000-0000-0000-0000000000c1',
  p_destination_country_code => 'FR')::text, true);
select set_config('t181.q', app.create_quotation(current_setting('t181.c')::uuid, 'EUR')::text, true);
select set_config('t181.i', app.create_booking_item(current_setting('t181.b')::uuid, 'umrah', 'EUR')::text, true);
select set_config('t181.j', app.create_booking_item(current_setting('t181.b')::uuid, 'umrah', 'EUR', 0, 1000)::text, true);
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select set_config('t181.s', app.create_supplier('T181 Air', 'airline', p_credit_limit_amount => 1000, p_credit_limit_currency_code => 'EUR')::text, true);
insert into public.customers (id, tenant_id, customer_type_code, full_name, credit_limit_amount, credit_limit_currency_code)
values ('18100000-0000-0000-0000-0000000000d2', '18100000-0000-0000-0000-000000000001', 'person', 'T181 Credit', 1000, 'EUR');
insert into public.financial_accounts (id, tenant_id, financial_account_type_code, name, currency_code)
values ('18100000-0000-0000-0000-0000000000d3', '18100000-0000-0000-0000-000000000001', 'cash', 'T181 Cash', 'EUR');
reset role;
select set_config('request.jwt.claims', '', true);
select count(*) from app.provision_tenant('T181 New', 't181-new', 'new@c181.test', 'New', p_default_currency_code => 'EUR');

select is(
  (select p.nationality_code || p.passport_issuing_country_code from public.passengers p where p.id = current_setting('t181.p')::uuid)
    || ' ' || (select preferred_language_code from public.customers where id = current_setting('t181.c')::uuid)
    || ' ' || (select destination_country_code from public.bookings where id = current_setting('t181.b')::uuid)
    || ' ' || (select currency_code from public.quotations where id = current_setting('t181.q')::uuid)
    || ' ' || (select string_agg(currency_code, '') from public.booking_items where booking_id = current_setting('t181.b')::uuid)
    || ' ' || (select credit_limit_currency_code from public.suppliers where id = current_setting('t181.s')::uuid)
    || ' ' || (select credit_limit_currency_code from public.customers where id = '18100000-0000-0000-0000-0000000000d2')
    || ' ' || (select currency_code from public.financial_accounts where id = '18100000-0000-0000-0000-0000000000d3')
    || ' ' || (select string_agg(default_currency_code, '' order by slug) from public.tenants where slug in ('reference-travel-181', 't181-new')),
  'FRFR fr FR EUR EUREUR EUR EUR EUR EUREUR',
  'positive control: with every value active, an employee, the owner and the platform create on all ten columns');

update public.nationalities set is_active = false where code = 'FR';
update public.countries set is_active = false where code = 'FR';
update public.currencies set is_active = false where code = 'EUR';
update public.languages set is_active = false where code = 'fr';

-- =============================================================================================
-- 5-14. A NEW CREATE refuses each deactivated value.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select throws_ok($$select app.create_passenger('T181', 'Two', p_nationality_code => 'FR')$$, '23514',
  'passengers .nationality_code : "FR" is not an active value of reference table "nationalities"',
  'a new passenger is refused a deactivated nationality');
select throws_ok($$select app.create_passenger('T181', 'Two', p_passport_issuing_country_code => 'FR')$$, '23514',
  'passengers .passport_issuing_country_code : "FR" is not an active value of reference table "countries"',
  'a new passenger is refused a deactivated passport country');
select throws_ok(format($$select app.create_booking(p_customer_id => %L, p_title => 'T181 trip two',
  p_branch_id => '18100000-0000-0000-0000-0000000000b1', p_department_id => '18100000-0000-0000-0000-0000000000c1',
  p_destination_country_code => 'FR')$$, current_setting('t181.c')), '23514',
  'bookings .destination_country_code : "FR" is not an active value of reference table "countries"',
  'a new booking is refused a deactivated destination country');
select throws_ok($$select app.create_customer('person', 'T181 French', p_primary_phone => '+20100000182', p_preferred_language_code => 'fr')$$, '23514',
  'customers .preferred_language_code : "fr" is not an active value of reference table "languages"',
  'a new customer is refused a deactivated language');
select throws_ok(format($$select app.create_quotation(%L, 'EUR')$$, current_setting('t181.c')), '23514',
  'quotations .currency_code : "EUR" is not an active value of reference table "currencies"',
  'a new quotation is refused a deactivated currency');
select throws_ok(format($$select app.create_booking_item(%L, 'umrah', 'EUR')$$, current_setting('t181.b')), '23514',
  'booking_items .currency_code : "EUR" is not an active value of reference table "currencies"',
  'a new booking item is refused a deactivated currency');
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select throws_ok($$insert into public.customers (tenant_id, customer_type_code, full_name, credit_limit_amount, credit_limit_currency_code)
  values ('18100000-0000-0000-0000-000000000001', 'person', 'T181 Credit Two', 1000, 'EUR')$$, '23514',
  'customers .credit_limit_currency_code : "EUR" is not an active value of reference table "currencies"',
  'a new customer is refused a deactivated credit currency');
select throws_ok($$select app.create_supplier('T181 Sea', 'airline', p_credit_limit_amount => 1000, p_credit_limit_currency_code => 'EUR')$$, '23514',
  'suppliers .credit_limit_currency_code : "EUR" is not an active value of reference table "currencies"',
  'a new supplier is refused a deactivated credit currency');
select throws_ok($$insert into public.financial_accounts (tenant_id, financial_account_type_code, name, currency_code)
  values ('18100000-0000-0000-0000-000000000001', 'cash', 'T181 Cash Two', 'EUR')$$, '23514',
  'financial_accounts .currency_code : "EUR" is not an active value of reference table "currencies"',
  'a new financial account is refused a deactivated currency');
reset role;
select set_config('request.jwt.claims', '', true);
select throws_ok($$select app.provision_tenant('T181 Newer', 't181-newer', 'newer@c181.test', 'Newer', p_default_currency_code => 'EUR')$$, '23514',
  'tenants .default_currency_code : "EUR" is not an active value of reference table "currencies"',
  'the platform cannot provision a new tenant in a deactivated currency');

-- =============================================================================================
-- 15-16. KEEP: every existing row holding a since-deactivated value keeps it through an edit of another field.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
update public.passengers set first_name = 'T181 Kept' where id = current_setting('t181.p')::uuid;
update public.customers set full_name = 'T181 Customer Kept' where id = current_setting('t181.c')::uuid;
update public.bookings set title = 'T181 trip kept' where id = current_setting('t181.b')::uuid;
update public.quotations set valid_until = now() + interval '9 days' where id = current_setting('t181.q')::uuid;
update public.booking_items set cost_amount = 100 where id = current_setting('t181.i')::uuid;
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
update public.suppliers set name = 'T181 Air Kept' where id = current_setting('t181.s')::uuid;
update public.customers set full_name = 'T181 Credit Kept' where id = '18100000-0000-0000-0000-0000000000d2';
update public.financial_accounts set name = 'T181 Cash Kept' where id = '18100000-0000-0000-0000-0000000000d3';
update public.tenants set name = 'Reference Travel Kept' where id = '18100000-0000-0000-0000-000000000001';
reset role;
select set_config('request.jwt.claims', '', true);

select is(
  (select first_name || ':' || nationality_code || passport_issuing_country_code from public.passengers where id = current_setting('t181.p')::uuid)
    || ' ' || (select full_name || ':' || preferred_language_code from public.customers where id = current_setting('t181.c')::uuid)
    || ' ' || (select title || ':' || destination_country_code from public.bookings where id = current_setting('t181.b')::uuid)
    || ' ' || (select (valid_until > now() + interval '8 days')::text || ':' || currency_code from public.quotations where id = current_setting('t181.q')::uuid)
    || ' ' || (select cost_amount::int || ':' || currency_code from public.booking_items where id = current_setting('t181.i')::uuid),
  'T181 Kept:FRFR T181 Customer Kept:fr T181 trip kept:FR true:EUR 100:EUR',
  'an employee edits a passenger, a customer, a booking, a quotation and a booking item that keep their deactivated values');
select is(
  (select name || ':' || credit_limit_currency_code from public.suppliers where id = current_setting('t181.s')::uuid)
    || ' ' || (select full_name || ':' || credit_limit_currency_code from public.customers where id = '18100000-0000-0000-0000-0000000000d2')
    || ' ' || (select name || ':' || currency_code from public.financial_accounts where id = '18100000-0000-0000-0000-0000000000d3')
    || ' ' || (select name || ':' || default_currency_code from public.tenants where id = '18100000-0000-0000-0000-000000000001'),
  'T181 Air Kept:EUR T181 Credit Kept:EUR T181 Cash Kept:EUR Reference Travel Kept:EUR',
  'the owner edits a supplier, a customer''s credit, a financial account and the tenant that keep the deactivated currency');

-- =============================================================================================
-- 17-19. POSITIONS: settling business already made in a deactivated currency still works (not guarded).
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select set_config('t181.qi', app.add_quotation_item(current_setting('t181.q')::uuid, 'umrah', 2500)::text, true);
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select set_config('t181.v', app.create_invoice(current_setting('t181.c')::uuid, 'EUR', 1000,
  current_setting('t181.b')::uuid, current_setting('t181.j')::uuid)::text, true);
select set_config('t181.vi', app.issue_invoice(current_setting('t181.v')::uuid)::text, true);
select set_config('t181.y', app.record_payment(current_setting('t181.v')::uuid, 400, 'cash')::text, true);
select set_config('t181.r', app.record_refund(current_setting('t181.c')::uuid, 10, 'EUR', 'other')::text, true);
reset role;
select set_config('request.jwt.claims', '', true);

select is((select currency_code from public.quotation_items where id = current_setting('t181.qi')::uuid), 'EUR',
  'an item is added to an existing quotation in the deactivated currency');
select is((select currency_code from public.payments where id = current_setting('t181.y')::uuid), 'EUR',
  'an existing booking item is invoiced, the invoice issued and paid in the deactivated currency');
select is((select count(*)::int from public.refunds where id = current_setting('t181.r')::uuid), 1,
  'a refund is recorded in the deactivated currency');

-- =============================================================================================
-- 20-21. A CHANGE to another active value is allowed.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
update public.passengers set nationality_code = 'EG', passport_issuing_country_code = 'EG' where id = current_setting('t181.p')::uuid;
update public.customers set preferred_language_code = 'en' where id = current_setting('t181.c')::uuid;
update public.bookings set destination_country_code = 'EG' where id = current_setting('t181.b')::uuid;
update public.booking_items set currency_code = 'EGP' where id = current_setting('t181.i')::uuid;
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
update public.suppliers set credit_limit_currency_code = 'EGP' where id = current_setting('t181.s')::uuid;
update public.customers set credit_limit_currency_code = 'EGP' where id = '18100000-0000-0000-0000-0000000000d2';
update public.financial_accounts set currency_code = 'EGP' where id = '18100000-0000-0000-0000-0000000000d3';
update public.tenants set default_currency_code = 'EGP' where id = '18100000-0000-0000-0000-000000000001';
reset role;
select set_config('request.jwt.claims', '', true);

select is(
  (select nationality_code || passport_issuing_country_code from public.passengers where id = current_setting('t181.p')::uuid)
    || ' ' || (select preferred_language_code from public.customers where id = current_setting('t181.c')::uuid)
    || ' ' || (select destination_country_code from public.bookings where id = current_setting('t181.b')::uuid)
    || ' ' || (select currency_code from public.booking_items where id = current_setting('t181.i')::uuid),
  'EGEG en EG EGP',
  'an employee moves a passenger, a customer, a booking and a booking item to other active values');
select is(
  (select credit_limit_currency_code from public.suppliers where id = current_setting('t181.s')::uuid)
    || ' ' || (select credit_limit_currency_code from public.customers where id = '18100000-0000-0000-0000-0000000000d2')
    || ' ' || (select currency_code from public.financial_accounts where id = '18100000-0000-0000-0000-0000000000d3')
    || ' ' || (select default_currency_code from public.tenants where id = '18100000-0000-0000-0000-000000000001'),
  'EGP EGP EGP EGP',
  'the owner moves a supplier, a customer''s credit, a financial account and the tenant to another active currency');

-- =============================================================================================
-- 22-30. A CHANGE back to the deactivated value is refused, on each of the nine columns.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select throws_ok(format($$update public.passengers set nationality_code = 'FR' where id = %L$$, current_setting('t181.p')), '23514',
  'passengers .nationality_code : "FR" is not an active value of reference table "nationalities"',
  'a passenger cannot be changed to a deactivated nationality');
select throws_ok(format($$update public.passengers set passport_issuing_country_code = 'FR' where id = %L$$, current_setting('t181.p')), '23514',
  'passengers .passport_issuing_country_code : "FR" is not an active value of reference table "countries"',
  'a passenger cannot be changed to a deactivated passport country');
select throws_ok(format($$update public.customers set preferred_language_code = 'fr' where id = %L$$, current_setting('t181.c')), '23514',
  'customers .preferred_language_code : "fr" is not an active value of reference table "languages"',
  'a customer cannot be changed to a deactivated language');
select throws_ok(format($$update public.bookings set destination_country_code = 'FR' where id = %L$$, current_setting('t181.b')), '23514',
  'bookings .destination_country_code : "FR" is not an active value of reference table "countries"',
  'a booking cannot be changed to a deactivated destination country');
select throws_ok(format($$update public.booking_items set currency_code = 'EUR' where id = %L$$, current_setting('t181.i')), '23514',
  'booking_items .currency_code : "EUR" is not an active value of reference table "currencies"',
  'a booking item cannot be changed to a deactivated currency');
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select throws_ok(format($$update public.suppliers set credit_limit_currency_code = 'EUR' where id = %L$$, current_setting('t181.s')), '23514',
  'suppliers .credit_limit_currency_code : "EUR" is not an active value of reference table "currencies"',
  'a supplier cannot be changed to a deactivated credit currency');
select throws_ok($$update public.customers set credit_limit_currency_code = 'EUR' where id = '18100000-0000-0000-0000-0000000000d2'$$, '23514',
  'customers .credit_limit_currency_code : "EUR" is not an active value of reference table "currencies"',
  'a customer cannot be changed to a deactivated credit currency');
select throws_ok($$update public.financial_accounts set currency_code = 'EUR' where id = '18100000-0000-0000-0000-0000000000d3'$$, '23514',
  'financial_accounts .currency_code : "EUR" is not an active value of reference table "currencies"',
  'a financial account cannot be changed to a deactivated currency');
select throws_ok($$update public.tenants set default_currency_code = 'EUR' where id = '18100000-0000-0000-0000-000000000001'$$, '23514',
  'tenants .default_currency_code : "EUR" is not an active value of reference table "currencies"',
  'the tenant cannot be changed to a deactivated default currency');

-- =============================================================================================
-- 31. AN UNKNOWN code is still the foreign key's.
-- =============================================================================================
select set_config('request.jwt.claims', '{"sub":"18100000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select throws_ok(format($$update public.passengers set nationality_code = 'ZZ' where id = %L$$, current_setting('t181.p')), '23503',
  'insert or update on table "passengers" violates foreign key constraint "passengers_nationality_code_fkey"',
  'an unknown nationality is refused by the foreign key, which names it');
reset role;

select * from finish();
rollback;
