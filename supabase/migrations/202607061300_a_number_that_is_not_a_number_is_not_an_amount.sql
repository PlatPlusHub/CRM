-- Batch 6 slice 3 -- `company_assets`, and the class the slice found underneath it.
--
-- The selector chose `company_assets` by measurement (exposure 7, coverage 8, score -1): money on a
-- table with a direct write grant and no RPC anywhere, so the table door IS the door. Most of what
-- the attack found there was a control already working, and that is recorded in
-- `103_company_asset_and_numeric_integrity_surface_test.sql` rather than replaced. Three things gave.
--
-- ---------------------------------------------------------------------------------------------
-- MONEY-1 -- THE ONE THAT MATTERS, AND IT WAS FOUND BY ATTACKING THIS MIGRATION'S OWN FIRST DRAFT.
-- ---------------------------------------------------------------------------------------------
-- The draft repair for `company_assets.purchase_amount` was `check (purchase_amount >= 0)`, copied
-- from the fifteen money columns that already carry that shape. Before trusting it, the constraint
-- itself was attacked -- and it does not hold:
--
--     select 'NaN'::numeric >= 0;   -->  TRUE
--
-- PostgreSQL's `numeric` NaN is defined as GREATER THAN every non-NaN value (documented under
-- "Numeric Types": NaN "is considered to be equal to itself and greater than all non-NaN values",
-- so that numeric can be sorted and indexed at all). Therefore **every `>= 0` and every `> 0` money
-- CHECK in this repository admits NaN** -- `payments`, `refunds`, `invoices`, `journal_entry_lines`,
-- `payment_allocations`, `booking_items`, both credit ceilings, and the six added by slice 1. Not one
-- of the 32 numeric columns on a `public` base table excluded it. `Infinity` is a separate value in
-- PostgreSQL 14+, but every money column here is `numeric(19,4)`, and a typed numeric rejects an
-- infinite value on precision -- measured, not assumed. So NaN was the whole hole.
--
-- REACHED THROUGH THE REAL DOOR, NOT ONLY IN psql. A real employee JWT (`finance_manager`, aal2)
-- POSTing `{"purchase_amount":"NaN"}` to `/rest/v1/company_assets` returns **HTTP 201** and the row
-- comes back with `"purchase_amount":"NaN"`. PostgREST casts the JSON string to `numeric` and the
-- CHECK that was supposed to be the money standard never fires.
--
-- WHY THIS IS AN INTEGRITY DEFECT AND NOT A CURIOSITY. NaN propagates through every aggregate: one
-- row makes `sum`, `avg` and `max` over that column NaN for the whole group. Reproduced end to end on
-- the financial core, not argued from the property:
--
--     insert into public.payments (... amount) values (..., 'NaN');   -- as `authenticated`, accepted
--     select outstanding_balance from reporting.customer_outstanding; -->  NaN
--
-- A tenant's outstanding balance becomes unreadable, and the credit-ceiling comparison built on it
-- (`202607060300`, `202607060600`) inherits the poison -- `NaN > threshold` is TRUE, so the ceiling
-- fires on a number nobody can see. It is tenant-scoped by RLS, so it is self-inflicted rather than a
-- cross-tenant attack; that caps the blast radius, not the severity of the corruption.
--
-- THE REPAIR IS ADDITIVE, DELIBERATELY. Not one existing CHECK is rewritten. Every one of them was
-- earned by a finding (CUST-4, SUP-4d, CDM-2, FIN-*), and editing a control to insert a clause is how
-- a control quietly loses one -- so each table gets a SECOND, separate constraint that says only
-- "a stored number is a number". `is distinct from` is the correct operator and was chosen by
-- behaviour: NULL is distinct from NaN (a null measure stays legal, which canon requires), and NaN is
-- NOT distinct from NaN (numeric NaN equals itself), so the constraint refuses exactly one value.
--
-- THIS RULE CARRIES NO BUSINESS CONTENT, which is why it is applied to all 19 tables at once rather
-- than one slice at a time. "This column holds a number" is not a policy about assets, quotations or
-- balances -- it is the precondition for any policy about them. The three columns that have no
-- non-negative rule at all (`financial_accounts.opening_balance`, `quotations.total_amount`,
-- `quotation_items.total_amount`) get the NaN rule and NOTHING else: whether a bank account may open
-- overdrawn, or a quotation may total below zero, is a business question their own Batch 6 slices
-- will ask. Recorded as MONEY-2 rather than answered here.
--
-- ---------------------------------------------------------------------------------------------
-- CA-1 -- an asset could be bought for a negative amount.
-- ---------------------------------------------------------------------------------------------
-- 15 of the 19 money columns on a base table already carry the non-negative rule; `purchase_amount`
-- carried nothing. A `finance_manager` POSTed `-500000` over HTTP and got 201. Canon 24 calls the
-- entity "company-owned asset" and canon 31 gives it `purchase_amount` -- what was paid for it. A
-- negative purchase price is not a discount, it is a number the column cannot mean, and the rule is
-- the one CUST-4 already ratified for money. Conditional, because canon 31 marks the column nullable.
--
-- ---------------------------------------------------------------------------------------------
-- CA-2 / CDM-3 -- an amount with no currency, on the last two tables that allowed one.
-- ---------------------------------------------------------------------------------------------
-- `202607059900` (SUP-4a) established the rule from canon 30's money standard -- "Currency code
-- should be stored separately" -- in its conditional form: the currency is present exactly when the
-- amount is. Five `public` tables have a nullable `currency_code` beside a numeric amount. THREE
-- carry the pairing (`customers`, `suppliers`, `offline_conversions`); two do not, and one of them is
-- `campaign_daily_metrics`, which THIS PROGRAMME audited eight assertions deep in slice 1 and marked
-- AUDITED. Slice 1 added six non-negative CHECKs to that table and did not ask the currency question.
-- That residue is recorded as CDM-3 and closed here rather than left because the row already reads
-- AUDITED -- a disposition is a claim about what was assessed, and this was not.
--
-- Both were reachable over HTTP: `{"purchase_amount":123456}` with no `currency_code` -> 201.
--
-- NO BACKFILL DECISION IS TAKEN, on the same basis as `202607059900`: Primary holds zero business
-- rows and no fixture sets an amount without a currency, so every constraint below binds forward and
-- assigns nobody's data a currency it did not state.

-- ---------------------------------------------------------------------------------------------
-- 1. company_assets -- the slice's own surface.
-- ---------------------------------------------------------------------------------------------
alter table public.company_assets
    add constraint company_assets_purchase_amount_non_negative
        check (purchase_amount is null or purchase_amount >= 0),
    -- The biconditional, not two one-way implications: a currency with no amount is as meaningless as
    -- an amount with no currency, and `customers`/`suppliers` are written the same way.
    add constraint company_assets_purchase_currency_pairing
        check ((purchase_amount is null) = (currency_code is null));

-- ---------------------------------------------------------------------------------------------
-- 2. campaign_daily_metrics -- CDM-3, slice 1's residue.
-- ---------------------------------------------------------------------------------------------
-- Two money columns share one currency, so the rule is "the currency is present exactly when ANY
-- money is". `coalesce` is the two-column form of the same biconditional `customers` uses; the four
-- COUNT measures are deliberately outside it -- impressions are not denominated in anything.
alter table public.campaign_daily_metrics
    add constraint campaign_daily_metrics_amount_currency_pairing
        check ((coalesce(spend_amount, revenue_amount) is null) = (currency_code is null));

-- ---------------------------------------------------------------------------------------------
-- 3. MONEY-1 -- every numeric column on every public base table, in one pass.
-- ---------------------------------------------------------------------------------------------
-- Written out per table rather than generated by a DO loop over the catalog: a loop would silently
-- cover whatever it happened to match, and the point of this constraint set is that the list is
-- reviewable and that `103_...` can assert the count. 19 tables, 32 columns -- the complete set of
-- `numeric` columns on `public` base tables as of migration 202607061300.
alter table public.booking_item_passengers add constraint booking_item_passengers_no_nan_check
    check (cost_amount_override is distinct from 'NaN'::numeric
       and selling_amount_override is distinct from 'NaN'::numeric);
alter table public.booking_items add constraint booking_items_no_nan_check
    check (commission_rate is distinct from 'NaN'::numeric
       and cost_amount is distinct from 'NaN'::numeric
       and selling_amount is distinct from 'NaN'::numeric);
alter table public.campaign_daily_metrics add constraint campaign_daily_metrics_no_nan_check
    check (bookings_count is distinct from 'NaN'::numeric
       and clicks is distinct from 'NaN'::numeric
       and impressions is distinct from 'NaN'::numeric
       and leads_count is distinct from 'NaN'::numeric
       and revenue_amount is distinct from 'NaN'::numeric
       and spend_amount is distinct from 'NaN'::numeric);
alter table public.company_assets add constraint company_assets_no_nan_check
    check (purchase_amount is distinct from 'NaN'::numeric);
alter table public.customers add constraint customers_no_nan_check
    check (credit_limit_amount is distinct from 'NaN'::numeric);
alter table public.exchange_rates add constraint exchange_rates_no_nan_check
    check (rate is distinct from 'NaN'::numeric);
alter table public.feature_entitlements add constraint feature_entitlements_no_nan_check
    check (limit_value is distinct from 'NaN'::numeric);
alter table public.financial_accounts add constraint financial_accounts_no_nan_check
    check (opening_balance is distinct from 'NaN'::numeric);
alter table public.invoices add constraint invoices_no_nan_check
    check (total_amount is distinct from 'NaN'::numeric);
alter table public.journal_entry_lines add constraint journal_entry_lines_no_nan_check
    check (credit_amount is distinct from 'NaN'::numeric
       and debit_amount is distinct from 'NaN'::numeric);
alter table public.leads add constraint leads_no_nan_check
    check (expected_value is distinct from 'NaN'::numeric);
alter table public.offline_conversions add constraint offline_conversions_no_nan_check
    check (conversion_value is distinct from 'NaN'::numeric);
alter table public.payment_allocations add constraint payment_allocations_no_nan_check
    check (allocated_amount is distinct from 'NaN'::numeric
       and allocated_amount_invoice_currency is distinct from 'NaN'::numeric);
alter table public.payments add constraint payments_no_nan_check
    check (amount is distinct from 'NaN'::numeric);
alter table public.quotation_items add constraint quotation_items_no_nan_check
    check (quantity is distinct from 'NaN'::numeric
       and total_amount is distinct from 'NaN'::numeric
       and unit_price is distinct from 'NaN'::numeric);
alter table public.quotations add constraint quotations_no_nan_check
    check (total_amount is distinct from 'NaN'::numeric);
alter table public.refunds add constraint refunds_no_nan_check
    check (amount is distinct from 'NaN'::numeric);
alter table public.suppliers add constraint suppliers_no_nan_check
    check (credit_limit_amount is distinct from 'NaN'::numeric);
alter table public.usage_counters add constraint usage_counters_no_nan_check
    check (limit_value is distinct from 'NaN'::numeric
       and used_value is distinct from 'NaN'::numeric);

comment on constraint company_assets_purchase_currency_pairing on public.company_assets is
    'Canon 30 money standard in the conditional form ratified by 202607059900 (SUP-4a): the currency '
    'is present exactly when the amount is. An amount with no currency is not an amount.';
comment on constraint payments_no_nan_check on public.payments is
    'MONEY-1: numeric NaN satisfies >= 0 in PostgreSQL, so the non-negative CHECK admitted it and one '
    'row turned reporting.customer_outstanding.outstanding_balance into NaN. Every numeric column on '
    'a public base table carries this companion constraint; 103_... asserts the set is complete.';
