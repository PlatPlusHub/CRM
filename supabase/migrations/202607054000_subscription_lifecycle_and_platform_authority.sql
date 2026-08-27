-- SPEC-157 -- the subscription lifecycle actually works, and only the Platform Owner drives it.
--
-- OWNER BUSINESS RULES (2026-08-27), accepted as given:
--   * every new tenant gets a 30-day trial with FULL feature access; the trial is tenant-level and
--     not silently restartable;
--   * paid periods are monthly / quarterly / semi-annual / annual / lifetime;
--   * lifetime does not expire through time-based renewal and must NOT be modelled as a far-future
--     date;
--   * the Platform Owner -- not the tenant Owner/CEO -- controls commercial subscription state.
--
-- WHAT THE EVIDENCE SAID BEFORE ANY CODE WAS WRITTEN (full trace in
-- `subscription-licensing-platform-authority-alignment-2026-08-27.md`). Three findings drove this
-- migration, and all three were proven live rather than assumed:
--
--   B1. `app.provision_tenant` created a tenant, an owner user and a role assignment -- and NO
--       subscription row. `app.subscription_allows_write` returns FALSE when no subscription exists
--       (proven: `select app.subscription_allows_write(gen_random_uuid())` --> false). Since WP-03
--       attached the write gate to 42 tables, EVERY freshly provisioned tenant could create branches
--       and users but could not create a customer, lead, booking, quotation, payment or document.
--       Day one of a real agency failed. This was never a policy question -- provisioning simply was
--       never finished.
--
--   B2. `ends_at`, `grace_ends_at` and `read_only_started_at` were DECORATIVE: written by the
--       create-table migration, read by exactly one reporting view, consumed by no logic, and
--       advanced by no scheduled job (`cron.job` held one entry, `lead-sla-processor`). A trial
--       whose `ends_at` passed a year ago kept full write access forever. A 30-day limit would have
--       meant nothing.
--
--   B9. `tenants.status` was unconstrained free text, set to 'trial' by provisioning and read by
--       NOTHING -- a second lifecycle competing with `subscriptions.subscription_status_code`.
--       Canon 35 §8 already names the subscription column as the single authority and expressly
--       flags `tenants.status` as the competing source. It is not deleted (canon 31 lists it as a
--       core field); it is constrained to an ACCOUNT-level vocabulary so the two can never be
--       confused again.
--
-- WHY NO NEW STATE MACHINE: canon 26 already defines all seven states and every legal transition,
-- including "Platform owner suspends tenant" and "Manual reactivation by platform owner". This
-- migration encodes that existing table in one function rather than inventing a second lifecycle.

-- =============================================================================================
-- 1. The two business constants, each with exactly ONE home.
--    Same reasoning as `app.commission_rate_default()` (SPEC-155): changing a business rule should
--    be a one-line migration against a named function, not a hunt through triggers and jobs.
-- =============================================================================================
create or replace function app.trial_period_days()
returns integer language sql immutable set search_path = ''
as $fn$ select 30 $fn$;

revoke execute on function app.trial_period_days() from public;

comment on function app.trial_period_days() is
    'Canonical trial length in days (owner-ratified 2026-08-27). Single source for the rule.';

create or replace function app.grace_period_days()
returns integer language sql immutable set search_path = ''
as $fn$ select 2 $fn$;

revoke execute on function app.grace_period_days() from public;

comment on function app.grace_period_days() is
    'Canonical grace-period length in days. Canon 09: "After subscription expiry, the tenant has a '
    'two-day grace period." Not an invented number.';

-- =============================================================================================
-- 2. Commercial durations. A catalog family, not a hardcoded list -- consistent with every other
--    vocabulary in ORVION, and reachable by a UI through the existing catalog read path.
-- =============================================================================================
insert into public.catalog_types (code, name, ownership_type, description, is_active)
values ('subscription_period', 'Subscription Period', 'system',
        'Commercial duration of a paid subscription period.', true);

insert into public.catalog_values
    (tenant_id, catalog_type_code, code, label, description, sort_order, is_active, is_system)
values
    (null, 'subscription_period', 'monthly',     'Monthly',     'Renews every month.',      1, true, true),
    (null, 'subscription_period', 'quarterly',   'Quarterly',   'Renews every 3 months.',   2, true, true),
    (null, 'subscription_period', 'semi_annual', 'Semi-Annual', 'Renews every 6 months.',   3, true, true),
    (null, 'subscription_period', 'annual',      'Annual',      'Renews every 12 months.',  4, true, true),
    (null, 'subscription_period', 'lifetime',    'Lifetime',
     'Open-ended. Does not expire through time-based renewal.',                             5, true, true);

-- One home for "how long is a period", so no caller re-derives it.
create or replace function app.subscription_period_interval(p_period_code text)
returns interval language sql immutable set search_path = ''
as $fn$
    select case p_period_code
               when 'monthly'     then interval '1 month'
               when 'quarterly'   then interval '3 months'
               when 'semi_annual' then interval '6 months'
               when 'annual'      then interval '1 year'
               else null   -- 'lifetime' and anything unknown have no duration, by design
           end
$fn$;

revoke execute on function app.subscription_period_interval(text) from public;

alter table public.subscriptions
    add column billing_period_code text,
    add column auto_renew boolean not null default false;

comment on column public.subscriptions.billing_period_code is
    'Commercial duration of the current paid period. NULL during trial -- a trial is not a billing '
    'period. FK-equivalent enforcement is by the catalog trigger below.';

comment on column public.subscriptions.auto_renew is
    'Defaults FALSE deliberately: rolling a paid period forward without payment is a commercial '
    'decision the Platform Owner makes per tenant, never a system default.';

-- LIFETIME IS MODELLED, NOT FAKED. The owner explicitly forbade an arbitrarily far future date, and
-- a comment saying so would not stop the next writer. These two constraints make it structurally
-- impossible to express "lifetime" any other way: a lifetime row has no end date and cannot be
-- put on a renewal cycle. Any code that later tries `ends_at = '2999-01-01'` fails at the database.
alter table public.subscriptions
    add constraint subscriptions_lifetime_has_no_end
    check (billing_period_code is distinct from 'lifetime' or ends_at is null);

alter table public.subscriptions
    add constraint subscriptions_lifetime_never_renews
    check (billing_period_code is distinct from 'lifetime' or auto_renew = false);

-- Extend the existing catalog trigger rather than adding a second one: the trigger already carries
-- (column, family) pairs, so the new column joins the mechanism that is already there.
drop trigger subscriptions_enforce_catalog_codes on public.subscriptions;
create trigger subscriptions_enforce_catalog_codes
    before insert or update on public.subscriptions
    for each row execute function app.enforce_catalog_codes(
        'subscription_status_code', 'subscription_status',
        'billing_period_code',      'subscription_period');

-- =============================================================================================
-- 3. The trial is a TENANT-level fact, recorded once.
--
--    WHY NOT ON `subscriptions`: `app.subscription_allows_write` selects
--    `order by s.created_at desc limit 1` -- multiple subscription rows per tenant are expected by
--    design. A trial fact stored there is lost the moment a second row is written, so it could
--    never answer "has this tenant already had its trial?". The owner's own words settle the
--    placement: "The trial is tenant-level, not user-level."
-- =============================================================================================
alter table public.tenants
    add column trial_started_at timestamptz,
    add column trial_ends_at    timestamptz;

alter table public.tenants
    add constraint tenants_trial_dates_paired
    check ((trial_started_at is null) = (trial_ends_at is null));

comment on column public.tenants.trial_started_at is
    'When this tenant''s one trial began. Write-once: see the tenants_enforce_trial_stamp trigger.';
comment on column public.tenants.trial_ends_at is
    'When this tenant''s one trial ended or ends. Write-once. Survives every later subscription row, '
    'which is what makes "already had a trial" answerable.';

-- B9: give `tenants.status` a meaning that cannot be mistaken for the commercial lifecycle.
-- Normalise first so the constraint is correct on ANY database, not just on ones that happen to be
-- empty today. Every one of the 41 test files already uses 'active'; the only other writer was
-- provision_tenant's 'trial' default, replaced below.
update public.tenants set status = 'active' where status not in ('active', 'disabled');

alter table public.tenants
    add constraint tenants_status_vocabulary check (status in ('active', 'disabled'));

comment on column public.tenants.status is
    'ACCOUNT status only: does this tenant account exist and function. It is NOT the commercial '
    'lifecycle -- canon 35 §8 makes subscriptions.subscription_status_code the single authority for '
    'access gating, and this column was previously free text that nothing read.';

-- A trial that can be silently restarted is not a trial. The stamp is set once by provisioning and
-- refuses every later change -- including one from a SECURITY DEFINER path, because the check is in
-- a trigger rather than in the RPC that happens to be the polite way in.
create or replace function app.enforce_trial_stamp_immutable()
returns trigger language plpgsql set search_path = ''
as $fn$
begin
    if old.trial_started_at is not null
       and new.trial_started_at is distinct from old.trial_started_at then
        raise exception 'trial_started_at is set once per tenant and cannot be changed'
            using errcode = 'check_violation';
    end if;

    if old.trial_ends_at is not null
       and new.trial_ends_at is distinct from old.trial_ends_at then
        raise exception 'trial_ends_at is set once per tenant and cannot be changed '
                        '(a trial is not restartable)'
            using errcode = 'check_violation';
    end if;

    return new;
end;
$fn$;

revoke execute on function app.enforce_trial_stamp_immutable() from public;

create trigger tenants_enforce_trial_stamp
    before update on public.tenants
    for each row execute function app.enforce_trial_stamp_immutable();

-- =============================================================================================
-- 4. Canon 26's transition table, encoded once.
--
--    Transcribed EXACTLY from `26_state_machines.md` -- no transition was added for convenience.
--    Note in particular that canon admits `suspended` only from `read_only`, and admits
--    `active -> cancelled` directly. That reading is deliberate: cancellation is commercial
--    termination and is available immediately; suspension is an enforcement action against a tenant
--    that has already lapsed to read-only. Whether the Platform Owner should also be able to
--    suspend an ACTIVE tenant in one step is a canon question, recorded as a finding rather than
--    silently invented here.
-- =============================================================================================
create or replace function app.subscription_transition_allowed(p_from text, p_to text)
returns boolean language sql immutable set search_path = ''
as $fn$
    select (p_from, p_to) in (
        ('trial',        'active'),        -- Subscription activated
        ('trial',        'expired'),       -- Trial ends without activation
        ('active',       'grace_period'),  -- Payment period ends without renewal
        ('grace_period', 'active'),        -- Renewal approved within grace period
        ('grace_period', 'read_only'),     -- Two-day grace period ends
        ('read_only',    'active'),        -- Renewal approved
        ('read_only',    'suspended'),     -- Platform owner suspends tenant
        ('suspended',    'active'),        -- Platform owner restores subscription
        ('active',       'cancelled'),     -- Subscription cancelled
        ('cancelled',    'active'),        -- Manual reactivation by platform owner
        ('expired',      'active')         -- Manual reactivation by platform owner
    )
$fn$;

revoke execute on function app.subscription_transition_allowed(text, text) from public;
grant  execute on function app.subscription_transition_allowed(text, text) to authenticated;

comment on function app.subscription_transition_allowed(text, text) is
    'Canon 26 Subscription State Machine, transcribed. The single home for which subscription '
    'transitions are legal; every writer consults it rather than re-stating the table.';

-- The event that records each arrival state. One mapping, so no caller invents an event code.
create or replace function app.subscription_state_event(p_from text, p_to text)
returns text language sql immutable set search_path = ''
as $fn$
    select case p_to
               when 'grace_period' then 'subscription_entered_grace_period'
               when 'read_only'    then 'subscription_entered_read_only'
               when 'suspended'    then 'subscription_suspended'
               when 'cancelled'    then 'subscription_cancelled'
               when 'expired'      then 'subscription_expired'
               when 'active'       then case
                                            when p_from in ('suspended', 'cancelled', 'expired')
                                            then 'subscription_reactivated'
                                            else 'subscription_activated'
                                        end
           end
$fn$;

revoke execute on function app.subscription_state_event(text, text) from public;

-- =============================================================================================
-- 5. The dates become load-bearing.
--
--    The scheduled job (§7) is the primary mechanism, exactly as canon 26 describes. This check is
--    DEFENCE IN DEPTH: without it, a job that is late, disabled, or has not yet run its first pass
--    hands the tenant free write time past its own expiry -- which is precisely the B2 defect, just
--    with a smaller window. The deadline differs per state, which is why this is a CASE and not one
--    `ends_at > now()` predicate: a tenant in `grace_period` is there BECAUSE `ends_at` has already
--    passed, so testing `ends_at` would deny the grace period its entire purpose.
--
--    `ends_at is null` remains writable. That is not a loophole -- it is how lifetime is expressed
--    (§2), and how every existing test fixture is written.
-- =============================================================================================
create or replace function app.subscription_allows_write(p_tenant_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
    select coalesce((
        select case s.subscription_status_code
                   when 'trial'        then s.ends_at is null or s.ends_at > now()
                   when 'active'       then s.ends_at is null or s.ends_at > now()
                   when 'grace_period' then s.grace_ends_at is null or s.grace_ends_at > now()
                   else false
               end
        from public.subscriptions s
        where s.tenant_id = p_tenant_id
        order by s.created_at desc
        limit 1
    ), false)
$fn$;

revoke execute on function app.subscription_allows_write(uuid) from public;
grant  execute on function app.subscription_allows_write(uuid) to authenticated;

-- =============================================================================================
-- 6. Provisioning creates the trial. This is the B1 fix.
--
--    "Full feature access during trial" resolves to the ENTERPRISE plan without inventing anything:
--    `feature_entitlements` is keyed by plan, and enterprise is the only plan whose rows are ALL
--    enabled (proven live: enterprise 22/22, professional 18/22, starter 9/22). Inventing a fourth
--    "trial plan" would have created a second entitlement surface for one rule.
-- =============================================================================================
create or replace function app.provision_tenant(
    p_tenant_name text,
    p_tenant_slug text,
    p_owner_email text,
    p_owner_full_name text,
    p_owner_auth_user_id uuid default null,
    p_default_currency_code text default null,
    p_tenant_status text default 'active'
)
returns table(tenant_id uuid, owner_user_id uuid)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_tenant_id  uuid;
    v_user_id    uuid;
    v_owner_role_id uuid;
    v_plan_id    uuid;
    v_trial_ends timestamptz := now() + make_interval(days => app.trial_period_days());
begin
    select id into v_owner_role_id from public.roles where code = 'owner' and is_active;
    if v_owner_role_id is null then
        raise exception 'owner role is not seeded; cannot provision tenant';
    end if;

    -- Resolved before the tenant is written, so a misconfigured catalog fails the whole
    -- provisioning rather than leaving a tenant that can never write (which was the B1 defect).
    select id into v_plan_id from public.subscription_plans where plan_code = 'enterprise' and is_active;
    if v_plan_id is null then
        raise exception 'enterprise plan is not seeded; cannot start a full-feature trial';
    end if;

    insert into public.tenants (name, slug, primary_email, default_currency_code, status,
                                trial_started_at, trial_ends_at)
    values (p_tenant_name, p_tenant_slug, p_owner_email, p_default_currency_code, p_tenant_status,
            now(), v_trial_ends)
    returning id into v_tenant_id;

    -- The subscription row is what makes the tenant able to work. Same transaction as the tenant,
    -- so the two can never disagree.
    insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code,
                                      starts_at, ends_at)
    values (v_tenant_id, v_plan_id, 'trial', now(), v_trial_ends);

    insert into public.users (tenant_id, auth_user_id, full_name, email, is_active)
    values (v_tenant_id, p_owner_auth_user_id, p_owner_full_name, p_owner_email, true)
    returning id into v_user_id;

    -- Owner authority is tenant-scoped (scope_type='tenant'); assigned_by is null (platform action,
    -- no tenant-user assigner).
    insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type, is_active)
    values (v_tenant_id, v_user_id, v_owner_role_id, 'tenant', true);

    -- Session-less caller (service_role, no auth.uid()): WP-00 requires actor NULL on that path.
    perform app.record_event(
        v_tenant_id, 'subscription_created', 'subscription', v_tenant_id, null,
        null, 'trial', 'tenant provisioned with a full-feature trial',
        jsonb_build_object('plan_code', 'enterprise',
                           'trial_days', app.trial_period_days(),
                           'trial_ends_at', v_trial_ends)
    );

    return query select v_tenant_id, v_user_id;
end;
$fn$;

-- Unchanged and deliberate: the platform surface, never the tenant.
revoke execute on function app.provision_tenant(text, text, text, text, uuid, text, text) from public;
revoke execute on function app.provision_tenant(text, text, text, text, uuid, text, text) from authenticated;
grant  execute on function app.provision_tenant(text, text, text, text, uuid, text, text) to service_role;

-- =============================================================================================
-- 7. State advances by itself. This is the other half of the B2 fix.
--
--    SHAPE IS LOAD-BEARING -- this is the lesson WP-03 taught at cost. `process_lead_sla` once
--    raised inside a multi-tenant loop and aborted the entire run for every tenant because ONE
--    tenant was ineligible. This function therefore decides eligibility per tenant and CONTINUES;
--    it never raises on a tenant's behalf. One tenant's bad state cannot stall another's transition.
-- =============================================================================================
create or replace function app.process_subscription_lifecycle()
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    r          record;
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
        v_from := r.subscription_status_code;
        v_to   := null;
        v_ends := null;

        if v_from = 'trial' and r.ends_at is not null and r.ends_at <= now() then
            -- Canon 26: "trial -> expired : Trial ends without activation".
            v_to := 'expired';

        elsif v_from = 'active' and r.ends_at is not null and r.ends_at <= now() then
            if r.auto_renew and app.subscription_period_interval(r.billing_period_code) is not null then
                -- Renewal rolls the period forward; the state does not change, so this is handled
                -- here rather than through the transition validator (active -> active is not a
                -- canon transition, and correctly so).
                v_ends := r.ends_at + app.subscription_period_interval(r.billing_period_code);
                update public.subscriptions set ends_at = v_ends where id = r.id;

                perform app.record_event(
                    r.tenant_id, 'subscription_activated', 'subscription', r.id, null,
                    'active', 'active', 'automatic renewal',
                    jsonb_build_object('billing_period_code', r.billing_period_code,
                                       'ends_at', v_ends));
                v_changed := v_changed + 1;
                continue;
            end if;
            -- Canon 26: "active -> grace_period : Payment period ends without renewal".
            v_to := 'grace_period';

        elsif v_from = 'grace_period' and r.grace_ends_at is not null and r.grace_ends_at <= now() then
            -- Canon 26: "grace_period -> read_only : Two-day grace period ends".
            v_to := 'read_only';
        end if;

        -- Not due, or in a state this job does not drive (suspended / cancelled / expired /
        -- read_only are all Platform Owner territory). Skip -- never raise on another tenant's
        -- behalf.
        if v_to is null then
            continue;
        end if;

        if not app.subscription_transition_allowed(v_from, v_to) then
            continue;
        end if;

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
            r.tenant_id, app.subscription_state_event(v_from, v_to), 'subscription', r.id, null,
            v_from, v_to, 'automatic lifecycle transition', null);

        v_changed := v_changed + 1;
    end loop;

    return v_changed;
end;
$fn$;

revoke execute on function app.process_subscription_lifecycle() from public;

comment on function app.process_subscription_lifecycle() is
    'Advances subscription state per canon 26. Per-tenant, skip-never-raise: one ineligible tenant '
    'must never abort another tenant''s transition (the WP-03 cross-path defect).';

-- Daily is the right cadence: every deadline in this machine is measured in days, and the write
-- gate (§5) already denies writes the instant a deadline passes, so the job records history rather
-- than being the thing that protects the boundary.
select cron.schedule('subscription-lifecycle', '10 0 * * *',
                     'select app.process_subscription_lifecycle()');

-- =============================================================================================
-- 8. The Platform Owner surface.
--
--    WHY THIS IS NOT A PERMISSION AND NOT A ROLE -- a structural proof, not a preference:
--    `app.has_permission` resolves the caller through `public.users` joined on
--    `u.tenant_id = app.current_tenant_id()`. Every holder of every role is, by construction, inside
--    exactly one tenant. A Platform Owner is therefore INEXPRESSIBLE as a tenant role, and granting
--    `MANAGE_SUBSCRIPTION` to `owner` or `ceo` would not create platform authority -- it would let
--    each tenant elevate its own subscription, which is the opposite of the requirement.
--
--    So platform authority lives where `app.provision_tenant` already put it: SECURITY DEFINER
--    functions granted to `service_role` and nothing else. `MANAGE_SUBSCRIPTION` and
--    `REVIEW_SUBSCRIPTION_PAYMENT` stay held by NO role -- which makes the RLS policies on
--    `subscriptions` deny every tenant user. That is now a deliberate, tested property rather than
--    an accident of omission that a future "tidy up the orphaned permissions" pass could undo.
--
--    `system_administrator` is NOT promoted here. Canon 28 calls it "Platform-level OR tenant
--    technical administrator depending on scope"; the ambiguity resolves to the tenant half,
--    because the platform half cannot live in a tenant role at all.
-- =============================================================================================
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

    select id, subscription_status_code into v_sub
    from public.subscriptions
    where tenant_id = p_tenant_id
    order by created_at desc
    limit 1;
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

revoke execute on function app.platform_activate_subscription(uuid, text, text, boolean) from public;
grant  execute on function app.platform_activate_subscription(uuid, text, text, boolean) to service_role;

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

revoke execute on function app.platform_transition_subscription(uuid, text, text) from public;
grant  execute on function app.platform_transition_subscription(uuid, text, text) to service_role;

comment on function app.platform_transition_subscription(uuid, text, text) is
    'Platform Owner subscription state change, validated against canon 26. service_role only: a '
    'tenant role cannot express platform authority (app.has_permission is tenant-bound by '
    'construction), so this authority deliberately lives outside the RBAC model.';
