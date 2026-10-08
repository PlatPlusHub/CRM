-- Batch 6 slice 34 -- `tenant_license_activations`: an activation code carries the platform owner's
-- current decision.
--
-- ================================================================================================
-- WHY
--
-- SPEC-158 built the canon-09 activation code: the Platform Owner issues a single-use code carrying
-- plan, period and auto-renew, and the tenant admin redeems it, which runs the platform activation
-- path. It promised two things this slice measured false.
--
-- LIC-4. Canon 26 gives `suspended -> active` ("Platform owner restores subscription") and
--   `cancelled -> active` ("Manual reactivation by platform owner") to the Platform Owner, yet
--   suspending or cancelling a tenant left its outstanding code live, and redemption reaches
--   `active` from either state. A code issued while a tenant was `read_only` was redeemed after the
--   Platform Owner suspended it: `suspended -> active`, on the plan the old code carried. The same
--   held after cancellation. The tenant undid the Platform Owner's later decision.
--   Suspending or cancelling now revokes the tenant's outstanding codes, through
--   `app.platform_revoke_license_tokens`, so the revocation is audited in its one home. Codes are
--   revoked before the subscription row is written, the same order redemption takes its locks
--   (code, then subscription). A fresh code issued after the suspension is the Platform Owner's new
--   decision and still restores the tenant. `expired`, `read_only` and `grace_period` keep their
--   codes: renewing from them is what the code exists for.
--
-- LIC-5. Issuance revokes the tenant's outstanding code and then inserts the new one, which SPEC-158
--   states means "two live tokens for one tenant cannot exist". True in sequence, false
--   concurrently: two issuances for one tenant each saw nothing to revoke, both committed, and both
--   codes redeemed. A partial unique index makes the claim the schema's: a second concurrent
--   issuance now waits for the first and is refused, and the sequential rotation is unchanged.
-- ================================================================================================

create unique index tenant_license_activations_one_live_per_tenant
    on public.tenant_license_activations (tenant_id)
    where consumed_at is null and revoked_at is null;

create or replace function app.platform_transition_subscription(
    p_tenant_id uuid,
    p_new_state text,
    p_reason text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_sub record;
begin
    select id, subscription_status_code, ends_at into v_sub
    from public.subscriptions
    where tenant_id = p_tenant_id
    order by created_at desc
    limit 1;
    if not found then
        raise exception 'tenant % has no subscription', p_tenant_id;
    end if;

    if not app.subscription_transition_allowed(v_sub.subscription_status_code, p_new_state) then
        raise exception 'canon 26 does not allow % -> %',
            v_sub.subscription_status_code, p_new_state using errcode = 'check_violation';
    end if;

    -- LIC-4: only the Platform Owner restores a suspended or cancelled tenant, so a code issued
    -- before that decision stops being redeemable when it is made.
    if p_new_state in ('suspended', 'cancelled') then
        perform app.platform_revoke_license_tokens(
            p_tenant_id, 'subscription ' || p_new_state || ' by platform owner');
    end if;

    update public.subscriptions
       set subscription_status_code = p_new_state,
           grace_ends_at = case
                               when p_new_state = 'grace_period'
                               then coalesce(ends_at, now())
                                    + make_interval(days => app.grace_period_days())
                               else grace_ends_at
                           end,
           read_only_started_at = case when p_new_state = 'read_only' then now()
                                       else read_only_started_at end
     where id = v_sub.id;

    perform app.record_event(
        p_tenant_id,
        app.subscription_state_event(v_sub.subscription_status_code, p_new_state),
        'subscription', v_sub.id, null,
        v_sub.subscription_status_code, p_new_state,
        coalesce(p_reason, 'platform owner transition'), null);
end;
$fn$;
