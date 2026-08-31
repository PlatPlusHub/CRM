-- API-3 subscription/licensing family.
--
-- ================================================================================================
-- LIC-2 (High) -- the single-use activation code could be redeemed TWICE, concurrently.
--
-- `app.redeem_license_token` reads the token row, checks `consumed_at is null`, and then updates
-- `consumed_at` with `where id = v_row.id` -- a check-then-act with no guard on the act. Under READ
-- COMMITTED two concurrent redemptions of the SAME code both read `consumed_at` NULL; the second
-- UPDATE blocks on the first's row lock, and when it unblocks PostgreSQL re-evaluates only the WHERE
-- clause, which is `id = ...` and still matches. So the second redemption proceeds.
--
-- WHAT MAKES THIS A DEFECT RATHER THAN A THEORETICAL RACE is that the repository states the opposite
-- in two places. The function's own comment: *"replay is closed by `consumed_at` regardless of
-- auditing"*. And `43_license_activation_test.sql` assertion 11: *"the SAME code cannot be used
-- twice -- replay is closed by consumption, not by hoping."* Both are true SEQUENTIALLY and false
-- CONCURRENTLY, which is LESSON 4 exactly -- a shipped claim that does not hold.
--
-- REPRODUCED with two real psql sessions against a committed fixture, not by inspection:
--   session A: begin; redeem(token); pg_sleep(6); commit;
--   session B (2s later, while A is still open): begin; redeem(token); commit;
-- Both returned success. Measured afterwards:
--   public.security_events 'license_token_redeemed' = 2   <-- for ONE single-use token
--   tenant_license_activations rows = 1, consumed_at set = 1
--   subscription: trial/starter -> active/professional, activated twice
-- The audit spine therefore records two redemptions of a credential the row says was consumed once:
-- the evidence is not merely incomplete, it is internally inconsistent. With two different actors
-- the last writer also wins `consumed_by`, so the row names one redeemer and the events name two.
--
-- ENFORCEMENT LAYER -- and this family is the rare case where the FUNCTION is the complete answer.
-- Measured rather than assumed: `authenticated` holds **no grant at all** on
-- `public.tenant_license_activations` (only `service_role`), and its RLS policy is `platform_only`,
-- so there is no second door for a tenant user -- unlike BOOK-1, ASGN-1 or CM-2, where the table was
-- reachable and the fix had to live below the RPC. Copying that pattern here would add a trigger
-- guarding a door nobody can open. The three functions that touch the table are
-- `platform_issue_license_token` (insert), `platform_revoke_license_tokens` (revoke) and this one.
--
-- The fix is a compare-and-swap: claim the row and the act of claiming it IS the check. `not found`
-- then means somebody else consumed it between the read and the write, and it raises the SAME
-- generic message as every other failure mode -- deliberately, because distinguishing "you lost the
-- race" from "no such token" would reintroduce exactly the probing oracle the original design
-- avoided. No lock is taken and no dependency is added.
--
-- NOT CHANGED, deliberately: **LIC-1** (a refused redemption is not audited) is untouched and
-- remains BLOCKED BY EXTERNAL DEPENDENCY. This migration does not make it better or worse -- the new
-- refusal path raises like every other, so it too goes unaudited, for the same documented reason.

create or replace function app.redeem_license_token(p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor  uuid := app.current_user_id();
    v_row    record;
    v_reason text;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('MANAGE_TENANT_SETTINGS');

    -- Scoped to the caller's own tenant, so a token issued for another agency is invisible here
    -- rather than merely refused.
    select * into v_row
    from public.tenant_license_activations
    where tenant_id = v_tenant
      and token_hash = encode(extensions.digest(coalesce(p_token, ''), 'sha256'), 'hex');

    if not found then
        v_reason := 'no matching token';
    elsif v_row.revoked_at is not null then
        v_reason := 'token revoked';
    elsif v_row.consumed_at is not null then
        v_reason := 'token already used';
    elsif v_row.expires_at <= now() then
        v_reason := 'token expired';
    end if;

    if v_reason is not null then
        -- ----------------------------------------------------------------------------------------
        -- A FAILED ATTEMPT IS NOT AUDITED, AND THAT IS STATED HERE RATHER THAN FAKED.
        --
        -- The first version of this function wrote a `license_token_rejected` row here and then
        -- raised. Its own test caught that the row was never there: `raise` aborts the transaction,
        -- and the audit INSERT is rolled back with everything else. PostgreSQL has no autonomous
        -- transaction, so an audit row written in the same transaction as its own refusal CANNOT
        -- survive -- the only escapes are an out-of-transaction hop (dblink self-connection, pg_net,
        -- an edge function) or abandoning `raise` in favour of a status return.
        --
        -- Neither is taken: dblink would require a stored connection secret, and a redemption RPC
        -- that returns "false" instead of raising invites a client to treat failure as success.
        -- Shipping the INSERT anyway would have been the worst of the three -- code that LOOKS like
        -- it audits, tested by nobody, that a future engineer builds a brute-force alert on.
        --
        -- The residual risk is small and bounded: a token is 128 bits of CSPRNG output, so guessing
        -- is infeasible; replay is closed by the compare-and-swap below; and every SUCCESSFUL
        -- redemption is audited, because that path commits. What is lost is visibility of a probing
        -- campaign against a leaked code. Recorded as LIC-1, classified BLOCKED BY EXTERNAL
        -- DEPENDENCY (an out-of-transaction audit hop), and pinned by an assertion in
        -- `43_license_activation_test.sql` so nobody assumes otherwise.
        --
        -- One generic message for every failure mode: telling a caller "already used" versus "no
        -- matching token" turns this function into an oracle for probing valid tokens.
        -- ----------------------------------------------------------------------------------------
        raise exception 'activation code is not valid' using errcode = '42501';
    end if;

    -- LIC-2: CLAIM the row, and let the claim BE the check. The pre-check above is now only for the
    -- error taxonomy; this is what actually makes the code single-use. Under READ COMMITTED a
    -- concurrent redeemer's UPDATE re-evaluates this predicate against the committed row and matches
    -- nothing, so exactly one caller can ever proceed past here.
    update public.tenant_license_activations
       set consumed_at = now(), consumed_by = v_actor
     where id = v_row.id
       and consumed_at is null;

    if not found then
        -- Someone consumed it between the read and the write. Same generic message as every other
        -- failure mode, deliberately: "you lost the race" would be as much of an oracle as
        -- "already used".
        raise exception 'activation code is not valid' using errcode = '42501';
    end if;

    -- Reuses the SPEC-157 platform path rather than repeating the activation logic, so the canon-26
    -- transition check, the end-date derivation and the lifetime rule all have exactly one home.
    -- The nested call is permitted because this function is SECURITY DEFINER and therefore runs as
    -- the owner -- the tenant user never holds execute on the platform function itself.
    perform app.platform_activate_subscription(
        v_tenant, v_row.plan_code, v_row.billing_period_code, v_row.auto_renew);

    insert into public.security_events (tenant_id, user_id, security_event_type_code, payload)
    values (v_tenant, v_actor, 'license_token_redeemed',
            jsonb_build_object('plan_code', v_row.plan_code,
                               'billing_period_code', v_row.billing_period_code));
end;
$fn$;

comment on function app.redeem_license_token(text) is
    'LIC-2 (202607058400): the consuming UPDATE carries `and consumed_at is null` and raises when it matches no row, so the code is single-use under CONCURRENCY and not only in sequence. Reproduced before the fix with two live sessions: both redemptions succeeded and public.security_events recorded TWO redemptions of one token. The function is the complete enforcement layer here because `authenticated` holds no grant on tenant_license_activations and its RLS is platform_only -- there is no second door. LIC-1 (a refused redemption is not audited) is unchanged and still BLOCKED.';
