-- SPEC-260 (Batch 6 Slice 38): a subscription payment proof is born `pending` and unreviewed, for
-- every caller and through either door. Only `app.platform_review_payment_proof` decides it.
--
-- Canon 28: "Tenant users may upload proof but cannot approve their own subscription renewal." The
-- sole sanctioned writer, `app.upload_subscription_payment_proof` (WP-04-B, SECURITY INVOKER),
-- writes `pending` with no review time; the platform review, session-less and SECURITY DEFINER,
-- decides only a `pending` proof and records no tenant reviewer (SPP-3, FX-4).
--
-- SPP-5, measured at `e26733a` on the local stack in rolled-back transactions, by a tenant `owner`
-- proven to hold MANAGE_TENANT_SETTINGS, on a lapsed tenant:
--   * the RPC's own proof was born with `reviewed_by` = its uploader. FX-4's trigger
--     (`202607058900`) copied `app.derive_created_by` and stamps the session user on INSERT, so every
--     uploaded proof named the tenant owner as its reviewer before any review, and the platform's
--     session-less approval left that name in place. FX-4 and SPP-3 record the column as NULL after
--     every review; since that trigger, no proof the RPC wrote has had a NULL reviewer. Primary holds
--     no proof, so no stored row carries the false name.
--   * a direct INSERT created a proof born `approved`, uploaded 40 days ago, reviewed 39 days ago,
--     with review notes "transfer confirmed by platform"; another was born `rejected`. Neither
--     passed through the platform review, which then refuses either as already decided.
--
-- THE REPAIR replaces only the body of `app.derive_proof_reviewer()`, already the BEFORE INSERT OR
-- UPDATE trigger `subscription_payment_proofs_derive_reviewer`. On INSERT, for every caller, a status
-- other than `pending` or a review time is refused (23514), and the reviewer is derived as NULL. The
-- UPDATE arm is unchanged. Security mode, owner, configuration, ACL and trigger are unchanged, and no
-- table, column, grant, policy, constraint, permission, event or catalog value is touched.
create or replace function app.derive_proof_reviewer()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    -- A proof is born pending and unreviewed, whoever writes it: only the platform review decides
    -- it, and no review has happened yet, so there is no reviewer to record.
    if tg_op = 'INSERT' then
        if new.status_code is distinct from 'pending' or new.reviewed_at is not null then
            raise exception 'a payment proof is created pending and unreviewed; only app.platform_review_payment_proof decides it'
                using errcode = '23514';
        end if;
        new.reviewed_by := null;
        return new;
    end if;

    -- The platform review path is session-less by design and records no ORVION actor. This is the
    -- branch that keeps that true.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- On UPDATE the reviewer is stamped the first time and frozen thereafter, so a second
    -- review cannot silently overwrite who performed the first.
    new.reviewed_by := coalesce(old.reviewed_by, app.current_user_id());
    return new;
end
$fn$;
