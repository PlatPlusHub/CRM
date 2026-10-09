-- ================================================================================================
-- A subscription transition is judged on the row it replaces (SUB-4, SUB-5).
--
-- Every writer of public.subscriptions.subscription_status_code read the row WITHOUT a lock, judged
-- canon 26 on that read, and then wrote `where id = ...`. Under READ COMMITTED a concurrent writer
-- could commit in between, so the write replaced a state nobody had judged and the event recorded a
-- from-state the row no longer held. Measured on the unrepaired baseline with two live sessions:
--   * SUB-4: a redemption committed read_only -> active while the Platform Owner's suspension waited;
--     the suspension wrote suspended over active (canon 26 has no active -> suspended) and recorded
--     read_only as its from-state. app.platform_activate_subscription reads the same way.
--   * SUB-5: a Platform Owner renewal committed grace_period -> active while the lifecycle job
--     waited; the job wrote read_only over the renewed tenant (canon 26 has no active -> read_only).
--
-- Each writer now locks its row before judging it, so the judgement, the write and the event
-- describe the same state. The lock is FOR NO KEY UPDATE: exactly the lock each writer's UPDATE
-- already took, now taken before the judgement. Writers still serialize against one another, and a
-- payment proof's foreign-key check (FOR KEY SHARE) is not made to wait. One lock order holds
-- everywhere: a tenant's activation codes, then its subscription row -- the order
-- app.redeem_license_token already takes.
-- ================================================================================================
create or replace function app.platform_activate_subscription(
    p_tenant_id uuid,
    p_plan_code text,
    p_billing_period_code text,
    p_auto_renew boolean default false
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_sub     record;
    v_plan_id uuid;
    v_ends    timestamptz;
begin
    select id into v_plan_id
    from public.subscription_plans where plan_code = p_plan_code and is_active;
    if v_plan_id is null then
        raise exception 'unknown or inactive plan_code: %', p_plan_code;
    end if;

    if not exists (select 1 from public.catalog_values
                   where catalog_type_code = 'subscription_period'
                     and code = p_billing_period_code and is_active) then
        raise exception 'unknown subscription_period: %', p_billing_period_code;
    end if;

    -- SUB-4: the row is locked BEFORE canon 26 judges it. A plain read here let a concurrent writer
    -- commit between the judgement and the UPDATE, so the UPDATE replaced a state nobody judged and
    -- the event named a from-state the row no longer held. Under READ COMMITTED, FOR NO KEY UPDATE
    -- waits for that writer and then returns the row it committed, so the judgement, the write and
    -- the event all describe the same state. It is the lock the UPDATE below takes anyway, taken
    -- before the judgement instead of after it. A redemption reaches this function holding its
    -- activation-code row, so the lock order everywhere is: activation codes, then the subscription.
    select id, subscription_status_code into v_sub
    from public.subscriptions
    where tenant_id = p_tenant_id
    order by created_at desc
    limit 1
    for no key update;
    if not found then
        raise exception 'tenant % has no subscription to activate', p_tenant_id;
    end if;

    if v_sub.subscription_status_code <> 'active'
       and not app.subscription_transition_allowed(v_sub.subscription_status_code, 'active') then
        raise exception 'canon 26 does not allow % -> active',
            v_sub.subscription_status_code using errcode = 'check_violation';
    end if;

    -- Lifetime gets no end date at all; the CHECK constraints in §2 make that the only expressible
    -- form, so this is the single place the rule is applied rather than one of several.
    v_ends := case when p_billing_period_code = 'lifetime' then null
                   else now() + app.subscription_period_interval(p_billing_period_code) end;

    update public.subscriptions
       set subscription_plan_id      = v_plan_id,
           subscription_status_code  = 'active',
           billing_period_code       = p_billing_period_code,
           auto_renew                = case when p_billing_period_code = 'lifetime'
                                            then false else p_auto_renew end,
           starts_at                 = now(),
           ends_at                   = v_ends,
           grace_ends_at             = null,
           read_only_started_at      = null
     where id = v_sub.id;

    perform app.record_event(
        p_tenant_id,
        app.subscription_state_event(v_sub.subscription_status_code, 'active'),
        'subscription', v_sub.id, null,
        v_sub.subscription_status_code, 'active', 'platform owner activated subscription',
        jsonb_build_object('plan_code', p_plan_code,
                           'billing_period_code', p_billing_period_code,
                           'auto_renew', p_auto_renew,
                           'ends_at', v_ends));
end;
$fn$;

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
    -- LIC-4: only the Platform Owner restores a suspended or cancelled tenant, so a code issued
    -- before that decision stops being redeemable when it is made. It runs FIRST, before the
    -- subscription row is locked: a redemption holds its activation-code row and then locks the
    -- subscription, so taking the two in the other order here could deadlock against it. A refused
    -- transition below raises, and the revocation rolls back with it.
    if p_new_state in ('suspended', 'cancelled') then
        perform app.platform_revoke_license_tokens(
            p_tenant_id, 'subscription ' || p_new_state || ' by platform owner');
    end if;

    -- SUB-4: canon 26 is judged on the LOCKED row. Measured before this repair with two live
    -- sessions: a redemption committed read_only -> active while this function waited on the row,
    -- and this function, having judged read_only -> suspended, then wrote suspended over active and
    -- recorded read_only as the from-state. FOR NO KEY UPDATE waits and returns the committed row
    -- instead, so an active -> suspended request is refused, as canon 26 requires.
    select id, subscription_status_code, ends_at into v_sub
    from public.subscriptions
    where tenant_id = p_tenant_id
    order by created_at desc
    limit 1
    for no key update;
    if not found then
        raise exception 'tenant % has no subscription', p_tenant_id;
    end if;

    if not app.subscription_transition_allowed(v_sub.subscription_status_code, p_new_state) then
        raise exception 'canon 26 does not allow % -> %',
            v_sub.subscription_status_code, p_new_state using errcode = 'check_violation';
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

create or replace function app.process_subscription_lifecycle()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
    r          record;
    v_cur      record;
    v_from     text;
    v_to       text;
    v_changed  integer := 0;
    v_ends     timestamptz;
begin
    for r in
        select distinct on (s.tenant_id)
               s.id, s.tenant_id, s.subscription_status_code, s.ends_at, s.grace_ends_at,
               s.billing_period_code, s.auto_renew
        from public.subscriptions s
        order by s.tenant_id, s.created_at desc
    loop
        begin
            -- SUB-5: the loop's snapshot is only a candidate list. Each row is re-read under its
            -- lock and judged on THAT. Measured before this repair with two live sessions: a Platform
            -- Owner renewal committed grace_period -> active while this job waited on the row, and the
            -- job, having judged grace_period -> read_only, wrote read_only over the renewed tenant.
            -- Every iterated row is locked, not only the due ones, so the due rules keep one home;
            -- a Platform Owner action on a tenant therefore waits at most for this job to commit.
            -- The job takes no activation-code lock, so it adds no new lock order, and a lock it
            -- cannot take fails this one row into a job finding, never the whole run.
            select subscription_status_code, ends_at, grace_ends_at, billing_period_code, auto_renew
              into v_cur
              from public.subscriptions
             where id = r.id
               for no key update;
            v_from := v_cur.subscription_status_code;
            v_to   := null;
            v_ends := null;

            if v_from = 'trial' and v_cur.ends_at is not null and v_cur.ends_at <= now() then
                -- Canon 26: "trial -> expired : Trial ends without activation".
                v_to := 'expired';

            elsif v_from = 'active' and v_cur.ends_at is not null and v_cur.ends_at <= now() then
                if v_cur.auto_renew
                   and app.subscription_period_interval(v_cur.billing_period_code) is not null then
                    -- Renewal rolls the period forward; the state does not change, so this is
                    -- handled here rather than through the transition validator (active -> active
                    -- is not a canon transition, and correctly so).
                    v_ends := v_cur.ends_at + app.subscription_period_interval(v_cur.billing_period_code);
                    update public.subscriptions set ends_at = v_ends where id = r.id;

                    perform app.record_event(
                        r.tenant_id, 'subscription_activated', 'subscription', r.id, null,
                        'active', 'active', 'automatic renewal',
                        jsonb_build_object('billing_period_code', v_cur.billing_period_code,
                                           'ends_at', v_ends));
                    v_changed := v_changed + 1;
                    perform app.resolve_job_finding(
                        'process_subscription_lifecycle', 'item_failed', r.tenant_id, r.id, null,
                        'a later lifecycle run processed this subscription without error');
                    continue;
                end if;
                -- Canon 26: "active -> grace_period : Payment period ends without renewal".
                v_to := 'grace_period';

            elsif v_from = 'grace_period'
                  and v_cur.grace_ends_at is not null and v_cur.grace_ends_at <= now() then
                -- Canon 26: "grace_period -> read_only : Two-day grace period ends".
                v_to := 'read_only';
            end if;

            -- Not due, or in a state this job does not drive (suspended / cancelled / expired /
            -- read_only are all Platform Owner territory).
            if v_to is not null and app.subscription_transition_allowed(v_from, v_to) then
                update public.subscriptions
                   set subscription_status_code = v_to,
                       grace_ends_at = case
                                           when v_to = 'grace_period'
                                           then coalesce(ends_at, now())
                                                + make_interval(days => app.grace_period_days())
                                           else grace_ends_at
                                       end,
                       read_only_started_at = case when v_to = 'read_only' then now()
                                                   else read_only_started_at end
                 where id = r.id;

                perform app.record_event(
                    r.tenant_id, app.subscription_state_event(v_from, v_to), 'subscription', r.id,
                    null, v_from, v_to, 'automatic lifecycle transition', null);

                v_changed := v_changed + 1;
            end if;

            perform app.resolve_job_finding(
                'process_subscription_lifecycle', 'item_failed', r.tenant_id, r.id, null,
                'a later lifecycle run processed this subscription without error');

        exception when others then
            -- SKIP, NEVER RAISE. One tenant's subscription must not decide every other tenant's.
            perform app.record_job_finding(
                'process_subscription_lifecycle', 'item_failed', r.tenant_id, 'subscription', r.id,
                null, sqlstate, sqlerrm);
        end;
    end loop;

    return v_changed;
end;
$function$;
