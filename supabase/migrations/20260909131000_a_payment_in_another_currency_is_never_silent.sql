-- FA-2 -- owner decision, ratified 2026-09-09.
--
-- A financial account MAY receive a payment denominated in another currency, but NEVER SILENTLY.
-- Cross-currency posting requires explicit conversion evidence; same-currency posting is unchanged.
--
-- ================================================================================================
-- WHAT WAS ACTUALLY THERE (measured before anything was designed)
--
-- `public.payments` carries `currency_code` and `financial_account_id`, and NOTHING related the two.
-- An EGP payment could be posted into a USD bank account and the row would simply assert that a USD
-- account received 5,000 -- of something. FA-1 froze an account's denomination under the payments
-- already sitting in it; FA-2 is the other half, and asks which payments may arrive at all.
--
-- ORVION ALREADY HAS AN FX MODEL, AND THIS MIGRATION INVENTS NO SECOND ONE:
--   * `public.exchange_rates` -- (tenant_id, from_currency_code, to_currency_code, rate,
--     effective_at, set_by), unique per (tenant, pair, instant), `rate > 0`, NaN refused.
--   * `app.exchange_rate_as_of(tenant, from, to, as_of)` -- the reader, including the inverse-rate
--     fallback.
--   * `public.booking_items.exchange_rate_id` -- the existing precedent for "WHICH rate this row was
--     converted at", as a composite `(tenant_id, exchange_rate_id)` foreign key.
--
-- So the conversion evidence FA-2 requires is a REFERENCE to that model, in exactly the shape
-- `booking_items` already uses. The rate row itself already preserves the positive rate, the
-- conversion instant (`effective_at`) and the source (`set_by`), and the FK is ON DELETE RESTRICT,
-- so the historical conversion fact cannot be deleted out from under a posted payment.
--
-- ================================================================================================
-- THE INVARIANT
--
--   financial_account_id IS NULL      -> nothing is being posted into an account. No conversion
--                                        exists, so none may be claimed.
--   payment currency = account currency -> ordinary posting. No rate may be attached (a rate on a
--                                        same-currency posting is a contradiction, not extra care).
--   payment currency <> account currency -> `exchange_rate_id` is MANDATORY, must belong to this
--                                        tenant, must be exactly the (payment currency ->
--                                        account currency) pair, and its rate must be positive and
--                                        FINITE.
--
-- WHAT IS PRESERVED ON THE ROW, and every one of these is DERIVED BY THE SERVER, never accepted from
-- the caller (SUP-1's "derived, not accepted" shape -- whatever the caller sends is discarded):
--   * original amount + original currency  -- `amount`, `currency_code`, untouched.
--   * financial-account currency           -- `account_currency_code`, snapshotted at posting.
--   * the rate, its instant and its source -- reachable through `exchange_rate_id`.
--   * the account-currency value           -- `account_amount`.
--
-- ================================================================================================
-- WHY A TRIGGER AND NOT A CHECK CONSTRAINT
--
-- PostgreSQL CHECK constraints may reference only the row being written; this rule is a statement
-- about TWO other tables (`financial_accounts` for the account's denomination, `exchange_rates` for
-- the rate). SECURITY DEFINER for BOOK-1's reason: under INVOKER the guard's reads of those two
-- tables would be RLS-filtered, leaving it blindest against exactly the caller it must stop. NO
-- session-less exemption -- this is INTEGRITY, not authorization (SUP-1's distinction), and a
-- silently mis-denominated payment written by a platform path is exactly as wrong as one written by
-- a user.
--
-- Tenant isolation and financial authorization are untouched: the payments RLS policy and
-- `payments_guard_financial_capability` both still run, and this guard adds no door of its own.

-- ------------------------------------------------------------------------------------------------
-- 1. THE INFINITE-RATE QUESTION, MEASURED RATHER THAN ASSUMED -- AND DELIBERATELY NOT GUARDED AGAIN.
--
--    `exchange_rates_rate_positive_check` is `rate > 0`, which is TRUE for 'Infinity', and
--    `exchange_rates_no_nan_check` does not exclude it either -- so on inspection an infinite rate
--    looked storable. A CHECK constraint for it was drafted, and then the assumption was tested:
--    `public.exchange_rates.rate` is `numeric(18,8)`, a CONSTRAINED numeric, and PostgreSQL refuses
--    'Infinity' in one with **22003 numeric field overflow** before any CHECK is evaluated.
--
--    The constraint was therefore REMOVED rather than shipped. It would have been a second
--    enforcement mechanism for an invariant the column type already owns, unreachable by any write,
--    and permanently untestable -- exactly the redundancy this repository refuses to add. The fact
--    is pinned by an assertion in 113_cross_currency_payment_evidence_test.sql instead, so a future
--    widening of the column type to bare `numeric` fails a test that explains why it matters.
-- ------------------------------------------------------------------------------------------------

-- ------------------------------------------------------------------------------------------------
-- 2. The conversion evidence columns.
-- ------------------------------------------------------------------------------------------------
alter table public.payments
    add column exchange_rate_id uuid,
    add column account_currency_code text,
    add column account_amount numeric(18,4);

alter table public.payments
    add constraint payments_exchange_rate_id_fkey
    foreign key (tenant_id, exchange_rate_id)
    references public.exchange_rates (tenant_id, id) on delete restrict;

alter table public.payments
    add constraint payments_account_currency_code_fkey
    foreign key (account_currency_code) references public.currencies (code) on delete restrict;

alter table public.payments
    add constraint payments_account_amount_no_nan_check
    check (account_amount is distinct from 'NaN'::numeric);

alter table public.payments
    add constraint payments_account_amount_nonneg_check
    check (account_amount is null or account_amount >= 0);

create index if not exists payments_exchange_rate_id_idx
    on public.payments (tenant_id, exchange_rate_id)
    where exchange_rate_id is not null;

comment on column public.payments.exchange_rate_id is
    'FA-2: the exchange_rates row this payment was converted at. MANDATORY when the payment currency differs from the financial account''s currency, and REFUSED when they match. ON DELETE RESTRICT, so the historical conversion fact survives.';
comment on column public.payments.account_currency_code is
    'FA-2: the financial account''s currency at posting time. Server-derived, never accepted from the caller.';
comment on column public.payments.account_amount is
    'FA-2: this payment expressed in the financial account''s currency. Server-derived (amount, or amount * rate); equals amount on a same-currency posting.';

-- ------------------------------------------------------------------------------------------------
-- 3. The guard.
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_payment_currency_conversion()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_account_currency text;
    v_rate             numeric;
    v_from             text;
    v_to               text;
begin
    -- ------------------------------------------------------------------------------------------
    -- A. Historical conversion facts survive financial finalisation.
    --    `verified_at` is the point at which a payment has been checked by someone with the
    --    authority to check it. After that, the money, its denomination and the conversion that
    --    produced the account-currency figure are history and are not re-writable in place. A
    --    correction after verification is a new record, not an edit of the old one.
    -- ------------------------------------------------------------------------------------------
    if tg_op = 'UPDATE' and old.verified_at is not null then
        if new.amount               is distinct from old.amount
        or new.currency_code        is distinct from old.currency_code
        or new.financial_account_id is distinct from old.financial_account_id
        or new.exchange_rate_id     is distinct from old.exchange_rate_id
        or new.account_amount       is distinct from old.account_amount
        or new.account_currency_code is distinct from old.account_currency_code then
            raise exception
                'a verified payment''s amount, currency, account and conversion are historical facts and cannot be rewritten'
                using errcode = '23514';
        end if;
        return new;
    end if;

    -- ------------------------------------------------------------------------------------------
    -- B. No account, no conversion. A payment not posted into a financial account has no second
    --    currency to be reconciled with, so claiming a conversion here would be evidence of
    --    something that did not happen.
    -- ------------------------------------------------------------------------------------------
    if new.financial_account_id is null then
        if new.exchange_rate_id is not null then
            raise exception
                'a payment with no financial account cannot carry an exchange rate: there is no account currency to convert into'
                using errcode = '23514';
        end if;
        new.account_currency_code := null;
        new.account_amount        := null;
        return new;
    end if;

    -- The composite foreign key already guarantees this row exists in this tenant; the lookup is
    -- for its DENOMINATION, which no key can supply.
    select fa.currency_code into v_account_currency
    from public.financial_accounts fa
    where fa.id = new.financial_account_id
      and fa.tenant_id = new.tenant_id;

    if not found then
        -- The FK is the authority on existence; do not duplicate it here (SUP-1's shape).
        return new;
    end if;

    -- Derived, not accepted: whatever the caller sent for these two is discarded.
    new.account_currency_code := v_account_currency;

    -- ------------------------------------------------------------------------------------------
    -- C. Same currency -- the ordinary path, deliberately unchanged in cost and behaviour.
    -- ------------------------------------------------------------------------------------------
    if new.currency_code = v_account_currency then
        if new.exchange_rate_id is not null then
            raise exception
                'payment currency % already matches the account currency: no conversion applies, so no exchange rate may be attached',
                new.currency_code
                using errcode = '23514';
        end if;
        new.account_amount := new.amount;
        return new;
    end if;

    -- ------------------------------------------------------------------------------------------
    -- D. Cross currency -- permitted, but only with evidence.
    -- ------------------------------------------------------------------------------------------
    if new.exchange_rate_id is null then
        raise exception
            'cross-currency posting refused: a % payment into a % account requires an explicit exchange_rate_id (FA-2)',
            new.currency_code, v_account_currency
            using errcode = '23514';
    end if;

    select er.rate, er.from_currency_code, er.to_currency_code
      into v_rate, v_from, v_to
    from public.exchange_rates er
    where er.id = new.exchange_rate_id
      and er.tenant_id = new.tenant_id;

    if not found then
        raise exception 'exchange rate is not in your tenant'
            using errcode = '23514';
    end if;

    -- The rate must be the conversion this posting actually performs, not merely A rate. Without
    -- this a caller could attach any rate row they liked -- including one for an unrelated pair --
    -- and the row would carry evidence that explains nothing.
    if v_from is distinct from new.currency_code or v_to is distinct from v_account_currency then
        raise exception
            'exchange rate converts % -> %, but this posting converts % -> %',
            v_from, v_to, new.currency_code, v_account_currency
            using errcode = '23514';
    end if;

    -- Re-verified here rather than trusted from the constraints, because a guard that relies on
    -- another object having been correct is the class this repository keeps finding.
    if v_rate is null or v_rate <= 0 or v_rate = 'NaN'::numeric or v_rate >= 'Infinity'::numeric then
        raise exception 'exchange rate must be positive and finite (got %)', v_rate
            using errcode = '23514';
    end if;

    new.account_amount := new.amount * v_rate;
    return new;
end
$fn$;

comment on function app.guard_payment_currency_conversion() is
    'FA-2 (owner decision 2026-09-09): a financial account may receive a foreign-currency payment, but never silently. Same-currency posting is unchanged; cross-currency posting must name an exchange_rates row for exactly that pair, in this tenant, with a positive finite rate, and the account-currency value is derived from it rather than accepted. SECURITY DEFINER because under INVOKER its reads of financial_accounts and exchange_rates would be RLS-filtered (BOOK-1). No session-less exemption: integrity, not authorization.';

revoke all on function app.guard_payment_currency_conversion() from public;

create trigger payments_guard_currency_conversion
    before insert or update on public.payments
    for each row execute function app.guard_payment_currency_conversion();
