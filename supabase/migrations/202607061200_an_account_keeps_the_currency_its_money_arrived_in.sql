-- =====================================================================================================
-- BATCH 6 SLICE 2 -- `financial_accounts`, selected by measurement, plus one cross-cutting finding
-- the same adversarial pass produced.
--
-- SELECTION. `scripts/batch6_select_target.ps1` ranks every surface still at NOT-RECORDED by
-- exposure minus coverage. `financial_accounts` came first: a numeric(19,4) money column, two direct
-- write grants to `authenticated`, no RPC anywhere, and only two pgTAP files naming it of which one
-- carries a negative assertion. Slice 1's rule ("the tables no test names") could not have chosen a
-- third slice; this one can choose a seventy-fifth.
--
-- WHAT THE ATTACK PASS PROVED CORRECT, recorded because a control found strong is worth as much as a
-- control found weak, and pinning it stops the next session re-deriving it:
--   * NO function writes this table -- measured against `pg_proc.prosrc`. The table door is the only
--     door, so RLS plus the capability trigger are the complete layer (SEC-2's ratified reading).
--   * The capability is NOT in RLS: `tenant_isolation` names only the tenant, and
--     `app.guard_write_capability` charges `CREATE_JOURNAL_ENTRY` on INSERT **and** UPDATE. Both
--     halves matter and neither is redundant -- the test injects the trigger's absence to prove it.
--   * The tenant boundary holds in both directions, including the row-hop (an owner moving their own
--     account into another tenant by UPDATE), which RLS `WITH CHECK` refuses.
--
-- FA-1 (Medium) -- AN ACCOUNT COULD BE RE-DENOMINATED AFTER MONEY HAD MOVED THROUGH IT.
-- Canon 31: "Bank and cash accounts." A bank account's currency and its kind are its identity, not a
-- preference. `public.payments` carries `FOREIGN KEY (tenant_id, financial_account_id)` into this
-- table and its own NOT NULL `currency_code`, so payments are routed INTO an account -- and nothing
-- stopped a holder of `CREATE_JOURNAL_ENTRY` from later switching that account's `currency_code`
-- from EGP to USD, or its type from bank to cash. Every payment already recorded against it silently
-- changes meaning, with no event and nothing to notice: `updated_at` moves and says only that
-- something did.
--
-- THE RULE IS CONDITIONAL, DELIBERATELY, AND THE CONDITION IS THE WHOLE POINT. An unused account is
-- a typo someone may fix; a used account is history someone must not rewrite. So the freeze binds
-- exactly when a payment references the account, and not before. Freezing outright would have forced
-- a tenant to abandon a mistyped account, which is a cost canon does not ask anyone to pay.
--
-- SECURITY DEFINER is REQUIRED here rather than tidy: the trigger must see the payments that make the
-- account "used" even when the caller cannot. A `SECURITY INVOKER` check would be evaluated under the
-- caller's RLS, so a finance user who cannot see a branch's payments would find the account
-- un-frozen -- the guard would be strongest for the people with the least to hide. `search_path = ''`
-- with every reference schema-qualified, per PostgreSQL's own SECURITY DEFINER guidance: with an
-- empty path `pg_temp` is not searched at all, which is stronger than the documented "pg_temp last".
--
-- WHAT THIS DELIBERATELY DOES NOT DECIDE -- FA-2, recorded and NOT fixed. Nothing requires
-- `payments.currency_code` to equal the account's `currency_code`: an EGP payment can be recorded
-- into a USD account today, and this migration leaves that exactly as it was. Whether a bank account
-- may receive a foreign-currency payment (and at which rate it would be converted) is a business
-- rule canon does not state, and inventing one because an attack surfaced the ambiguity is the thing
-- the standing method forbids. Freezing the denomination does not answer it and is not a step
-- towards answering it in either direction.
--
-- SECDEF-1 (Low) -- TWO RLS-BYPASSING HELPERS ANSWERED QUESTIONS ABOUT ANY TENANT.
-- Found by applying PostgreSQL's own SECURITY DEFINER guidance to ORVION rather than by grep. No
-- ORVION table sets `FORCE ROW LEVEL SECURITY` and every table is owned by the same role that owns
-- the functions, so **all 83 SECURITY DEFINER functions run with RLS entirely bypassed** -- which is
-- correct and load-bearing for the system paths, and is exactly why a caller-supplied `p_tenant_id`
-- inside one is a cross-tenant door by construction. Four such functions are executable by
-- `authenticated`. Two already refuse a foreign tenant and their guard clauses are the pattern:
-- `app.record_event` ("tenant % is not the caller's tenant %") and `app.eligible_lead_handlers`,
-- whose own comment says exposing it without the check "would let any signed-in user enumerate any
-- tenant's staff". Two did not:
--   * `app.document_retention_days(p_tenant_id, p_document_type_code)` -- reads any tenant's
--     retention configuration.
--   * `app.subscription_allows_write(p_tenant_id)` -- reports whether any tenant's subscription is
--     in good standing, which is commercial intelligence about a competitor agency.
-- Neither is reachable over HTTP today (neither has a `public` wrapper, so PostgREST cannot see
-- them), and that is a mitigation, not the fix.
--
-- REVOKED RATHER THAN GUARDED, on measurement. The obvious repair was to copy the tenant check into
-- both. Measured first, and the grant turned out to be unnecessary in the first place: NO policy, no
-- CHECK constraint, no view and no index references either function, `app.document_retention_days`
-- has **zero callers anywhere**, and every caller of `app.subscription_allows_write` is itself
-- SECURITY DEFINER and therefore executes as the owner without consulting `authenticated`'s grant.
-- Removing a door is smaller and more complete than adding a lock to it, and it is the answer
-- `202607056100` already established for this class. **Ceiling, stated:** if a later package needs
-- either function exposed to `authenticated`, it must first carry `eligible_lead_handlers`' refusal
-- clause -- and `102_...` asserts that as a class over the whole set, so a new one fails closed.
-- =====================================================================================================

-- -----------------------------------------------------------------------------------------------
-- FA-1: an account keeps the currency and the kind its money arrived in.
-- -----------------------------------------------------------------------------------------------
create or replace function app.forbid_used_account_redenomination()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_column text;
begin
    if new.currency_code is not distinct from old.currency_code
       and new.financial_account_type_code is not distinct from old.financial_account_type_code then
        return new;
    end if;

    -- Tenant-qualified even though RLS is bypassed here, because it is bypassed here: the composite
    -- FK guarantees a payment's account is in its own tenant, and this predicate says so out loud
    -- rather than relying on the reader to remember it.
    if exists (
        select 1
        from public.payments p
        where p.tenant_id            = old.tenant_id
          and p.financial_account_id = old.id
    ) then
        v_column := case
            when new.currency_code is distinct from old.currency_code then 'currency_code'
            else 'financial_account_type_code'
        end;
        raise exception
            'financial_accounts.% is fixed once money has moved through the account: '
            'payments are already recorded against account %',
            v_column, old.id
            using errcode = '42501';
    end if;

    return new;
end
$$;

comment on function app.forbid_used_account_redenomination() is
    'FA-1. Canon 31 calls these "bank and cash accounts": an account''s currency and kind are its '
    'identity, and changing either after payments have been routed through it re-denominates history '
    'silently. CONDITIONAL by design -- an unused account is a typo someone may fix. SECURITY '
    'DEFINER is required, not tidy: the trigger must see payments the caller cannot, or the freeze '
    'would be weakest for the callers with the narrowest visibility.';

-- GRANT-1: pg_default_acl grants EXECUTE to PUBLIC on every new function, and
-- 10_grant_model_test.sql refuses that for any ORVION function. Caught by that guard on this
-- migration's first run, which is the guard doing exactly what SPEC-124 built it for.
revoke execute on function app.forbid_used_account_redenomination() from public;

drop trigger if exists financial_accounts_forbid_redenomination on public.financial_accounts;
create trigger financial_accounts_forbid_redenomination
    before update on public.financial_accounts
    for each row execute function app.forbid_used_account_redenomination();

-- -----------------------------------------------------------------------------------------------
-- SECDEF-1: close the two RLS-bypassing helpers that answered questions about any tenant.
-- -----------------------------------------------------------------------------------------------
revoke execute on function app.document_retention_days(uuid, text) from authenticated;
revoke execute on function app.subscription_allows_write(uuid)     from authenticated;

comment on function app.document_retention_days(uuid, text) is
    'SECDEF-1. SECURITY DEFINER, so it runs with RLS bypassed, and it takes the tenant as an '
    'argument -- which made it a cross-tenant read of any tenant''s retention configuration for any '
    'signed-in user. EXECUTE revoked from `authenticated` rather than guarded, because the grant was '
    'never needed: this function has no callers at all, and its intended system callers would run as '
    'owner. Re-exposing it to `authenticated` requires app.eligible_lead_handlers'' refusal clause '
    'first; test 102 asserts that as a class.';

comment on function app.subscription_allows_write(uuid) is
    'The subscription write gate''s authority (canon 26/28), and SECURITY DEFINER so it can read '
    '`public.subscriptions` from inside trigger paths. SECDEF-1: EXECUTE revoked from '
    '`authenticated` -- it takes the tenant as an argument and runs with RLS bypassed, so a signed-in '
    'user could ask whether ANY agency''s subscription was in good standing. Every real caller is '
    'itself SECURITY DEFINER and executes as the owner, so nothing needed the grant; verified '
    'against pg_policies, pg_constraint, pg_views and pg_indexes before revoking.';
