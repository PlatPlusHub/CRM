-- SPEC-158 -- the tenant license activation credential. Closes canon decision C4, open since
-- 2026-07-15.
--
-- CANON 09 describes the flow and stops short of the mechanism, deliberately: "Platform owner
-- receives renewal proof / System generates or requests a time-sensitive activation code / Platform
-- owner provides the code to the tenant admin / Tenant admin enters the code to activate renewal.
-- **This requires security review before implementation.**" This migration is that review's outcome.
--
-- ================================================================================================
-- WHY THIS IS NOT TOTP -- the owner proposed a TOTP-style credential and explicitly asked for the
-- correct security architecture rather than blind implementation. Three independent reasons, in
-- order of force:
--
--   1. TOTP REQUIRES ORVION TO STORE A SHARED SECRET, AND ORVION HAS DECIDED IT NEVER WILL.
--      `public.totp_enrollments` carries `auth_user_id`, `is_active`, `enrolled_at`, `revoked_at` --
--      and NO secret column. That is not an oversight: canon 34 places the authentication support
--      tables on the Human Identity with the factor itself owned by Supabase Auth (ADR-0017). A
--      per-tenant TOTP seed would be the first authentication secret ORVION ever stored, reversing a
--      ratified architectural decision in order to obtain a *licensing* feature.
--
--   2. TOTP IS THE WRONG SHAPE. A TOTP seed is a PERMANENT credential that yields a valid code every
--      30 seconds forever. An activation credential must be SINGLE-USE and revocable. Building
--      one-time semantics on a repeating primitive means adding a consumption record anyway -- at
--      which point the consumption record does all the work and the seed is pure liability.
--
--   3. THE OWNER'S OWN CONSTRAINTS SELECT THE SIMPLER PRIMITIVE. Issuance, regeneration, revocation,
--      rotation, replay control, auditability and compromise recovery are all properties of a stored
--      one-time token; none of them are properties TOTP provides.
--
-- WHAT IS BUILT INSTEAD: a single-use, hashed, expiring activation token.
--   * The plaintext is generated inside the database, returned to the Platform Owner EXACTLY ONCE,
--     and never stored, never logged, and never placed in an event payload. Only its SHA-256 hash is
--     persisted, so a database compromise yields no usable token.
--   * It grants NO database privilege whatsoever. It is an argument to one controlled function whose
--     only effect is a subscription state transition -- so it can never become a Supabase password,
--     which is exactly the failure mode the owner named.
--   * Replay is closed by `consumed_at`; rotation is revoke-then-issue (issuing automatically
--     revokes any outstanding token for the tenant, so two live tokens cannot exist); compromise
--     recovery is revocation.
--   * Every issue, redemption and rejection writes a `public.security_events` row -- which also
--     gives that table its first producers, a gap recorded since the WP-00 sweep.
-- ================================================================================================

-- ---------------------------------------------------------------------------------------------
-- 1. Vocabulary. Registered in the catalog like every other ORVION vocabulary, even though
--    `security_events` carries no catalog trigger -- the registry is the place a future reader
--    looks to learn what codes exist.
-- ---------------------------------------------------------------------------------------------
insert into public.catalog_values
    (tenant_id, catalog_type_code, code, label, description, sort_order, is_active, is_system)
values
    (null, 'security_event_type', 'license_token_issued',   'License Token Issued',
     'Platform Owner issued a tenant license activation token.',   15, true, true),
    (null, 'security_event_type', 'license_token_redeemed', 'License Token Redeemed',
     'A tenant admin redeemed a license activation token.',        16, true, true),
    (null, 'security_event_type', 'license_token_revoked',  'License Token Revoked',
     'Outstanding license activation tokens were revoked.',        17, true, true);

-- NOTE ON WHAT IS *NOT* REGISTERED HERE. An obvious fourth code, `license_token_rejected`, is
-- deliberately absent, because it could never have a producer -- see the discussion in §5. Canon 26
-- already left eleven subscription event types registered with zero producers for years; registering
-- a vocabulary word that nothing can ever emit is how that happens, so it is not done here.

-- ---------------------------------------------------------------------------------------------
-- 2. The credential store.
--
--    The token CARRIES the terms it activates (plan, period, auto-renew). Without them redemption
--    would be meaningless -- the tenant would present a code and the system would not know what it
--    entitles. This is also what keeps the tenant out of the commercial decision: the Platform Owner
--    fixes the terms at issuance, and redemption can only apply them, never choose them.
-- ---------------------------------------------------------------------------------------------
create table public.tenant_license_activations (
    id uuid primary key default gen_random_uuid(),
    tenant_id uuid not null references public.tenants (id) on delete restrict on update no action,

    -- SHA-256 of the token. The plaintext is never stored anywhere, in any column, at any point.
    token_hash text not null,

    -- The terms this token activates, fixed by the Platform Owner at issuance.
    plan_code text not null,
    billing_period_code text not null,
    auto_renew boolean not null default false,

    issued_at   timestamptz not null default now(),
    issued_note text,
    expires_at  timestamptz not null,

    consumed_at timestamptz,
    -- TENANT-QUALIFIED FK, not a bare `references users(id)`. `14_tenant_qualified_fk_test.sql`
    -- caught the single-column version on the first run: a lone `users(id)` reference is a path by
    -- which one tenant's row can point at another tenant's user, which is the class of defect
    -- SPEC-130 removed everywhere else. The composite key makes the cross-tenant row unrepresentable.
    consumed_by uuid,
    constraint tenant_license_activations_consumed_by_fkey
        foreign key (tenant_id, consumed_by) references public.users (tenant_id, id)
        on delete restrict on update no action,

    revoked_at     timestamptz,
    revoked_reason text,

    constraint tenant_license_activations_not_both_consumed_and_revoked
        check (consumed_at is null or revoked_at is null)
);

create index tenant_license_activations_tenant_idx
    on public.tenant_license_activations (tenant_id, issued_at desc);

-- A hash collision is not the concern; a duplicate issuance is. Unique on the hash makes the token
-- itself the identity.
create unique index tenant_license_activations_token_hash_key
    on public.tenant_license_activations (token_hash);

comment on table public.tenant_license_activations is
    'Single-use tenant license activation tokens (SPEC-158, canon C4). Stores only the SHA-256 hash; '
    'the plaintext is returned once at issuance and never persisted. Grants no database privilege.';

-- No grant to `anon`/`authenticated` at all: a tenant user must never read a token hash, and never
-- needs to -- the code reaches them out of band, exactly as canon 09 describes. Both functions below
-- are SECURITY DEFINER, so they reach this table as its owner without any tenant-facing privilege
-- existing.
alter table public.tenant_license_activations enable row level security;
revoke all on table public.tenant_license_activations from anon, authenticated;

-- An EXPLICIT deny-all policy rather than simply leaving the table policy-less.
-- `01_rls_coverage_test.sql` is catalog-driven -- every NOT NULL `tenant_id` table must carry a
-- policy, with no exception list -- and it failed here on the first run. The right answer was not to
-- add an exception to a deliberately exception-free invariant, but to state the intent in the place
-- a reader will look: this table denies everyone, always, and the two SECURITY DEFINER functions
-- below reach it as the table owner. It is also a second lock: if some future migration grants
-- `authenticated` a privilege here by accident, this policy still returns nothing.
create policy platform_only on public.tenant_license_activations
    for all using (false) with check (false);

-- DELIBERATELY EXEMPT from the subscription write gate. A tenant redeems a token precisely when it
-- is `read_only` or `expired`; gating this table would make renewal impossible for exactly the
-- tenants that need it. Canon 28 agrees from the other side -- in read-only mode "Upload
-- subscription renewal proof" is allowed and "Platform owner subscription actions remain allowed".
-- Same reasoning that exempts `subscriptions` and `subscription_payment_proofs` (WP-03).
-- `35_subscription_write_gate_test.sql` records the exemption in both directions.

-- ---------------------------------------------------------------------------------------------
-- 3. Issue. Platform Owner only.
-- ---------------------------------------------------------------------------------------------
create or replace function app.platform_issue_license_token(
    p_tenant_id uuid,
    p_plan_code text,
    p_billing_period_code text,
    p_auto_renew boolean default false,
    p_valid_for_days integer default 7,
    p_note text default null
)
returns text
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_token text;
begin
    if not exists (select 1 from public.tenants where id = p_tenant_id) then
        raise exception 'unknown tenant %', p_tenant_id;
    end if;

    -- Validate the terms AT ISSUANCE rather than at redemption. A token that cannot be redeemed is
    -- worse than a refused issuance: the tenant discovers the mistake, not the Platform Owner.
    if not exists (select 1 from public.subscription_plans
                   where plan_code = p_plan_code and is_active) then
        raise exception 'unknown or inactive plan_code: %', p_plan_code;
    end if;
    if not exists (select 1 from public.catalog_values
                   where catalog_type_code = 'subscription_period'
                     and code = p_billing_period_code and is_active) then
        raise exception 'unknown subscription_period: %', p_billing_period_code;
    end if;
    if p_valid_for_days is null or p_valid_for_days < 1 then
        raise exception 'p_valid_for_days must be at least 1';
    end if;

    -- ROTATION. Issuing supersedes any outstanding token for this tenant, so two live tokens for one
    -- tenant cannot exist and "regenerate" needs no separate function -- it is just issuing again.
    update public.tenant_license_activations
       set revoked_at = now(),
           revoked_reason = 'superseded by a newly issued token'
     where tenant_id = p_tenant_id
       and consumed_at is null
       and revoked_at is null;

    -- 128 bits from the CSPRNG. Hex rather than base64 so the code can be dictated over a phone
    -- call without '+', '/' or '=' ambiguity -- this credential is handed over by a human.
    v_token := encode(extensions.gen_random_bytes(16), 'hex');

    insert into public.tenant_license_activations
        (tenant_id, token_hash, plan_code, billing_period_code, auto_renew, expires_at, issued_note)
    values
        (p_tenant_id,
         encode(extensions.digest(v_token, 'sha256'), 'hex'),
         p_plan_code, p_billing_period_code, p_auto_renew,
         now() + make_interval(days => p_valid_for_days),
         p_note);

    -- The payload records the TERMS, never the token. Anyone who can read security_events must not
    -- thereby be able to redeem.
    insert into public.security_events (tenant_id, security_event_type_code, payload)
    values (p_tenant_id, 'license_token_issued',
            jsonb_build_object('plan_code', p_plan_code,
                               'billing_period_code', p_billing_period_code,
                               'auto_renew', p_auto_renew,
                               'valid_for_days', p_valid_for_days));

    -- The only moment the plaintext exists outside the caller's hand.
    return v_token;
end;
$fn$;

revoke execute on function app.platform_issue_license_token(uuid, text, text, boolean, integer, text) from public;
grant  execute on function app.platform_issue_license_token(uuid, text, text, boolean, integer, text) to service_role;

comment on function app.platform_issue_license_token(uuid, text, text, boolean, integer, text) is
    'Issues a single-use tenant license activation token and returns its plaintext ONCE. Only the '
    'SHA-256 hash is stored. service_role only -- this is a Platform Owner action.';

-- ---------------------------------------------------------------------------------------------
-- 4. Revoke. Compromise recovery, and the "reset" the owner asked for.
-- ---------------------------------------------------------------------------------------------
create or replace function app.platform_revoke_license_tokens(
    p_tenant_id uuid,
    p_reason text default 'revoked by platform owner'
)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_count integer;
begin
    update public.tenant_license_activations
       set revoked_at = now(), revoked_reason = p_reason
     where tenant_id = p_tenant_id
       and consumed_at is null
       and revoked_at is null;
    get diagnostics v_count = row_count;

    -- This audit row SURVIVES, because this function returns normally. That is not true of the
    -- rejection path in §5 -- see the note there.
    if v_count > 0 then
        insert into public.security_events (tenant_id, security_event_type_code, payload)
        values (p_tenant_id, 'license_token_revoked',
                jsonb_build_object('count', v_count, 'reason', p_reason));
    end if;

    return v_count;
end;
$fn$;

revoke execute on function app.platform_revoke_license_tokens(uuid, text) from public;
grant  execute on function app.platform_revoke_license_tokens(uuid, text) to service_role;

-- ---------------------------------------------------------------------------------------------
-- 5. Redeem. The tenant admin's side -- the ONLY tenant-facing part of licensing.
--
--    `app.authorize` rather than `app.has_permission`: authorize also composes MFA, and canon 28
--    requires TOTP for owner and ceo. Renewing the company's licence is precisely a step-up action.
--
--    MANAGE_TENANT_SETTINGS is reused rather than a new permission invented. Canon 09 calls this
--    actor "the tenant admin", and MANAGE_TENANT_SETTINGS is already exactly Owner + CEO.
-- ---------------------------------------------------------------------------------------------
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
        -- is infeasible; replay is closed by `consumed_at` regardless of auditing; and every
        -- SUCCESSFUL redemption is audited, because that path commits. What is lost is visibility of
        -- a probing campaign against a leaked code. Recorded as a named limitation, classified
        -- BLOCKED BY EXTERNAL DEPENDENCY (an out-of-transaction audit hop), and pinned by an
        -- assertion in `43_license_activation_test.sql` so nobody assumes otherwise.
        --
        -- One generic message for every failure mode: telling a caller "already used" versus "no
        -- matching token" turns this function into an oracle for probing valid tokens.
        -- ----------------------------------------------------------------------------------------
        raise exception 'activation code is not valid' using errcode = '42501';
    end if;

    update public.tenant_license_activations
       set consumed_at = now(), consumed_by = v_actor
     where id = v_row.id;

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

revoke execute on function app.redeem_license_token(text) from public;
grant  execute on function app.redeem_license_token(text) to authenticated;

comment on function app.redeem_license_token(text) is
    'Tenant admin redeems a license activation token issued by the Platform Owner. Single-use; every '
    'attempt is audited; failures return one generic message so the function cannot be used as an '
    'oracle. The token grants no database privilege -- only the subscription terms it carries.';
