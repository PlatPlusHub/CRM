-- REF-2 -- Batch 6 slice 59 (`nationalities`, `countries`, `currencies`, and `languages` with them).
--
-- THE RULE (the owner's policy of 2026-11-18; no CRM or ORVION spec defined it before). A
-- deactivated nationality, country, currency or language stays on every row that already holds it,
-- and that row stays editable; a new create, or a change of that field, refuses it. This is the rule
-- `app.enforce_catalog_codes` already applies to the catalog families, carried to the four
-- reference tables, which are written only by migrations (`postgres`).
-- Measured before this migration (local stack, `probe-02.log`): with the value deactivated, every
-- member-chosen column below accepted it at create (a passenger, a booking, a customer's language
-- and credit currency, a supplier, a quotation, a booking item, a financial account, and a tenant
-- provisioned by the platform) and at a change of that field (all but `quotations.currency_code`,
-- which `app.guard_quotation_integrity` already keeps); the foreign keys check existence only.
--
-- THE REPAIR, in the existing shape. `app.enforce_reference_codes()` is `app.enforce_catalog_codes`
-- with (column, reference table) pairs: it skips a null, skips on UPDATE a column the statement did
-- not change (what lets a row holding a since-deactivated code keep being edited), and refuses a
-- value whose reference row is not active (23514 `check_violation`, as the catalog guard). It is
-- attached BEFORE INSERT OR UPDATE to the eight tables whose rows are new business:
--   passengers          nationality_code (nationalities), passport_issuing_country_code (countries)
--   bookings            destination_country_code (countries)
--   customers           preferred_language_code (languages), credit_limit_currency_code (currencies)
--   suppliers           credit_limit_currency_code (currencies)
--   quotations          currency_code (currencies)
--   booking_items       currency_code (currencies)
--   financial_accounts  currency_code (currencies)
--   tenants             default_currency_code (currencies)
--
-- NOT CHANGED: every grant, policy, constraint, foreign key and existing trigger; the reference
-- tables and their rows; every function body.
-- Positions recorded, not repaired here: the settlement of business already made keeps its
-- currency, so `invoices`, `payments`, `payment_allocations`, `refunds`, `journal_entry_lines` and
-- `quotation_items` (each carries the currency of the quotation, booking item, invoice or payment it
-- settles; `probe-02.log` EX1-EX3) are not guarded; `exchange_rates` records a historical fact;
-- `offline_conversions`, `campaign_daily_metrics` and `company_assets` record what a source
-- reported or what was bought; `booking_item_passengers.manifest_passport_issuing_country_code` is
-- a snapshot with no foreign key.

create or replace function app.enforce_reference_codes()
returns trigger
language plpgsql
security definer
set search_path to ''
as $function$
declare
    i int;
    v_column text;
    v_table text;
    v_value text;
    v_active boolean;
    v_new jsonb := to_jsonb(new);
    v_old jsonb := case when tg_op = 'UPDATE' then to_jsonb(old) else null end;
begin
    -- TG_ARGV holds (column, reference table) pairs.
    i := 0;
    while i < tg_nargs loop
        v_column := tg_argv[i];
        v_table := tg_argv[i + 1];
        i := i + 2;

        v_value := v_new ->> v_column;
        continue when v_value is null;

        -- On UPDATE, only re-validate a column the statement actually changed: a row that holds a
        -- since-deactivated code keeps it and stays editable.
        continue when tg_op = 'UPDATE' and v_old ->> v_column is not distinct from v_value;

        execute format('select r.is_active from public.%I r where r.code = $1', v_table)
            into v_active
            using v_value;

        -- An unknown code is left to the foreign key, which names it; only an inactive one is refused here.
        if v_active is false then
            raise exception
                '% .% : "%" is not an active value of reference table "%"',
                tg_table_name, v_column, v_value, v_table
                using errcode = 'check_violation';
        end if;
    end loop;

    return new;
end;
$function$;

revoke execute on function app.enforce_reference_codes() from public;

create trigger passengers_enforce_reference_codes
    before insert or update on public.passengers
    for each row execute function app.enforce_reference_codes(
        'nationality_code', 'nationalities', 'passport_issuing_country_code', 'countries');

create trigger bookings_enforce_reference_codes
    before insert or update on public.bookings
    for each row execute function app.enforce_reference_codes(
        'destination_country_code', 'countries');

create trigger customers_enforce_reference_codes
    before insert or update on public.customers
    for each row execute function app.enforce_reference_codes(
        'preferred_language_code', 'languages', 'credit_limit_currency_code', 'currencies');

create trigger suppliers_enforce_reference_codes
    before insert or update on public.suppliers
    for each row execute function app.enforce_reference_codes(
        'credit_limit_currency_code', 'currencies');

create trigger quotations_enforce_reference_codes
    before insert or update on public.quotations
    for each row execute function app.enforce_reference_codes(
        'currency_code', 'currencies');

create trigger booking_items_enforce_reference_codes
    before insert or update on public.booking_items
    for each row execute function app.enforce_reference_codes(
        'currency_code', 'currencies');

create trigger financial_accounts_enforce_reference_codes
    before insert or update on public.financial_accounts
    for each row execute function app.enforce_reference_codes(
        'currency_code', 'currencies');

create trigger tenants_enforce_reference_codes
    before insert or update on public.tenants
    for each row execute function app.enforce_reference_codes(
        'default_currency_code', 'currencies');
