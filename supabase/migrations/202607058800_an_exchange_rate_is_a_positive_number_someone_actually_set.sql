-- Migration: an exchange rate is a positive number, set by someone who actually set it
-- Batch 6, table-by-table audit — first bounded slice: the accounting core (FX-1, FX-2).
--
-- HOW THIS SLICE WAS CHOSEN, because "audit the remaining tables" is not a package. The 54 tables
-- `authenticated` can write were ranked by guard coverage and test coverage, and the ranking was
-- then ATTACKED rather than trusted (MEAS-1): a first pass keyed on `guard_write_capability` scored
-- the finance tables as unguarded, which is false — FIN-3 gave them dedicated triggers under other
-- names. Corrected, the sweep produced three clean results and one outlier:
--
--   * identity/organization (`users`, `user_role_assignments`, `user_branch_assignments`,
--     `branches`, `departments`) — SPEC-138 gives every one of them per-command policies requiring
--     the canon-named MANAGE_* permission on INSERT, UPDATE and DELETE alike. NOT A DEFECT.
--   * the accounting core's AUTHORIZATION — `exchange_rates`, `exchange_rate_adjustments`,
--     `chart_of_accounts`, `journal_entries`, `journal_entry_lines` each require the exact canon-28
--     permission (SET_EXCHANGE_RATE / CREATE_EXCHANGE_RATE_ADJUSTMENT / CREATE_JOURNAL_ENTRY), and
--     journal entries must balance. NOT A DEFECT.
--   * every FK into `exchange_rates` is tenant-qualified (`(tenant_id, id)`), so TENANT-1's
--     cross-tenant class is closed here. NOT A DEFECT.
--   * `otp_challenges` and `totp_enrollments` are owner-scoped by RLS (`auth_user_id = auth.uid()`)
--     and have NO READER — no function, no view, no authorization path consults either. Recorded,
--     deliberately not "fixed": inventing a consumer to justify a guard is the non-goal this audit
--     names explicitly.
--
-- The outlier: of every actor column in the schema, `exchange_rates.set_by` is the ONLY one with no
-- derivation. Twenty tables carry `app.derive_created_by`; `subscription_payment_proofs` carries
-- `derive_proof_uploader` (which my first detector missed, and which is why the detector was
-- rebuilt before its result was believed). `exchange_rates` carries neither — and no CHECK on the
-- number itself.
--
-- WHAT WAS REPRODUCED, as a finance_manager who genuinely holds SET_EXCHANGE_RATE:
--   FX-1   `rate = -48.5`  INSERT 0 1
--   FX-1b  `rate = 0`      INSERT 0 1
--   FX-2   `set_by` set to an EMPLOYEE who did not set the rate   INSERT 0 1
--   FX-2b  `set_by` omitted entirely                             INSERT 0 1
-- NEGATIVE CONTROL: an ordinary employee attempting the same insert is refused 42501. Authorization
-- is intact and was never the problem — these are INTEGRITY defects, which is what decides the layer
-- below and denies them the session-less exemption an authorization rule would earn (ADR-0025).
--
-- SEVERITY IS LOW, AND THE REASON IS MEASURED, NOT ASSUMED: `exchange_rates` has **no reader**. No
-- function and no view in `app`, `public` or `reporting` references it; `booking_items` and
-- `payment_allocations` carry `exchange_rate_id` FK columns that nothing converts with yet. A wrong
-- rate therefore misstates history and changes no number today. It is fixed for SUP-1's reason: the
-- history is the point of the record, and a future consumer would inherit the corruption silently.
--
-- ENFORCEMENT LAYER, from the measured surface (ADR-0025). There is **no RPC** for exchange rates —
-- the table is the ONLY door — so ADR-0024's two-door question has one answer here, and the rule
-- must live on the table:
--   * FX-1 is a statement about the row itself and about nothing else, so a CHECK is the narrowest
--     layer that can express it. No trigger is needed and none is added.
--   * FX-2 is attribution, which is a statement about the SESSION, so it needs a trigger.

-- ---------------------------------------------------------------------------------------------
-- 1. FX-1. An exchange rate is a positive multiplier.
--
--    Strictly `> 0`, not `>= 0`, and the difference is deliberate. CONV-4 allows a conversion VALUE
--    of zero because a free conversion is a real thing; a zero RATE is not a rate — it would value
--    every foreign amount at nothing — and a negative one inverts the sign of money. Canon 07 says
--    only "Manual exchange rates" and sets no bound, so this is the arithmetic floor, not a business
--    policy: no rule about which rates are reasonable is invented here.
-- ---------------------------------------------------------------------------------------------
alter table public.exchange_rates
    add constraint exchange_rates_rate_positive_check check (rate > 0);

-- ---------------------------------------------------------------------------------------------
-- 2. FX-2. The setter is derived, never accepted.
--
--    A dedicated trigger rather than a generalisation of `app.derive_created_by`: that function is
--    attached to twenty tables, and widening it to take a column argument to serve one table is
--    exactly the CUST-1 shape — a structurally reasonable change that silently alters twenty
--    consumers. The semantics below are copied from it verbatim, including the session-less
--    exemption, so the two cannot drift in meaning even though they are separate objects.
--
--    Session-less writes keep whatever attribution they set (canon 35 principle 6). That is the
--    same guarantee the other twenty tables give, and it is the reason `set_by` is NOT made NOT
--    NULL: there is no system writer today, and a NOT NULL would be a stronger claim than the
--    evidence supports while breaking the first one that appears.
--
--    On UPDATE the column is frozen to its old value. Verified before relying on it: no `app.*` or
--    `public.*` function writes `exchange_rates` at all, so nothing legitimate is being blocked.
-- ---------------------------------------------------------------------------------------------
create or replace function app.derive_exchange_rate_setter()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'INSERT' then
        new.set_by := app.current_user_id();
    else
        new.set_by := old.set_by;
    end if;

    return new;
end
$fn$;
revoke all on function app.derive_exchange_rate_setter() from public;

create trigger exchange_rates_derive_setter
    before insert or update on public.exchange_rates
    for each row execute function app.derive_exchange_rate_setter();
