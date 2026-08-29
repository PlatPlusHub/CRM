-- IDENT-1 -- an unverified email is not proof of identity, and it was the only proof required.
--
-- API-3, canon-34 Human Identity family. `app.activate_membership()` is how a pre-provisioned
-- membership is CLAIMED: `app.create_tenant_user` may insert a `public.users` row with
-- `auth_user_id` NULL (it records `has_auth_link: false` in its own event, so the unlinked case is a
-- first-class, intended flow), and the invitee later links their Supabase identity to it.
--
-- The whole authorization for that claim was a string comparison between `auth.users.email` and
-- `public.users.email`, justified in the function's own comment:
--
--     "The caller's auth.users row exists only after Supabase verified this email, so the match is
--      an authorization proof."
--
-- THAT SENTENCE IS FALSE AGAINST THIS REPOSITORY'S OWN CONFIGURATION. `supabase/config.toml` sets
-- `enable_confirmations = false`, so a GoTrue signup creates the `auth.users` row IMMEDIATELY with
-- `email_confirmed_at` NULL. Nothing has proven the signer-up can read that mailbox. And
-- `email_confirmed_at` appears NOWHERE in any migration, test or script -- the assumption was never
-- checked anywhere.
--
-- REPRODUCED on a clean local reset. A tenant pre-provisions its CEO (`ceo@victim.test`, unlinked,
-- active, `ceo` role). An attacker signs up with the same email string; their `auth.users` row has
-- `email_confirmed_at` NULL. They then call `activate_membership()`:
--
--     activate_membership()  -> returned the CEO membership, claimed
--     users.auth_user_id     -> now the ATTACKER'S uid
--     current_tenant_id()    -> the victim tenant
--     APPROVE_FINANCE        -> true
--     VIEW_FINANCIAL_DOCUMENTS -> true
--     MANAGE_USERS           -> true
--
-- Full takeover of a pre-provisioned executive account, from a signup form.
--
-- WHY THE FIX IS IN THIS FUNCTION AND NOT IN A TRIGGER. The reflex would be a trigger on
-- `public.users` requiring any `auth_user_id` to reference a confirmed identity. That is the wrong
-- layer, for two measured reasons:
--   (1) The alternate paths are ALREADY CLOSED, verified rather than assumed. Before claiming, the
--       attacker has no membership, so `app.current_tenant_id()` is null and `users`' RLS hides
--       every row: a direct `UPDATE public.users SET auth_user_id = <self>` affected **0 rows**, and
--       a direct INSERT of a self-provisioned membership was refused **42501**. This RPC is the only
--       reachable path, so this is where the rule belongs.
--   (2) Q2, the consumer question: **49 test files create `auth.users` rows and not one sets
--       `email_confirmed_at`.** A trigger would break all 49, and would also impose an email-
--       confirmation requirement on the ADMIN provisioning path (`create_tenant_user` with a
--       supplied `p_auth_user_id`), which rests on a different trust basis -- an authenticated
--       administrator vouching for a colleague, not a stranger claiming a mailbox.
-- The rule is a PRECONDITION OF SELF-CLAIMING, not an invariant of the column. It goes where the
-- self-claiming happens.
--
-- `banned_until` and `deleted_at` are checked in the same breath, and not speculatively: a JWT
-- issued before a ban stays valid until it expires, so GoTrue refusing new sessions does not stop an
-- already-issued token from calling this. A banned or soft-deleted identity claiming a fresh
-- membership would defeat the ban entirely.
--
-- `email_confirmed_at` deliberately, NOT the generated `confirmed_at` -- the latter is
-- `least(email_confirmed_at, phone_confirmed_at)`, so a phone-confirmed identity would satisfy it
-- while never having proven ownership of the EMAIL this claim matches on.

create or replace function app.activate_membership()
returns table(membership_id uuid, tenant_id uuid, tenant_name text, is_active boolean)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_uid       uuid := (select auth.uid());
    v_email     text;
    v_confirmed timestamptz;
    v_banned    timestamptz;
    v_deleted   timestamptz;
begin
    if v_uid is null then
        raise exception 'not authenticated';
    end if;

    select u.email, u.email_confirmed_at, u.banned_until, u.deleted_at
      into v_email, v_confirmed, v_banned, v_deleted
    from auth.users u
    where u.id = v_uid;

    if v_email is null then
        raise exception 'no verified email for caller';
    end if;

    -- IDENT-1. The claim matches on the email, so the email is what must be proven.
    if v_confirmed is null then
        raise exception 'email address is not verified: a tenant membership cannot be claimed by an identity that has not proven it owns this mailbox'
            using errcode = 'insufficient_privilege';
    end if;

    if v_deleted is not null or (v_banned is not null and v_banned > now()) then
        raise exception 'this identity may not claim a membership'
            using errcode = 'insufficient_privilege';
    end if;

    -- Claim every unlinked, active membership for the caller's VERIFIED email.
    -- The original comment here claimed this was "bounded to one row per tenant by
    -- users_tenant_email_key". It is not, and that is IDENT-4: this match is case-INSENSITIVE while
    -- that constraint is case-SENSITIVE. `202607057900` adds the case-insensitive unique index that
    -- makes the claim true; until that index exists, two case-variant rows in one tenant lock the
    -- user out permanently with a raw 23505.
    update public.users u
    set auth_user_id = v_uid
    where lower(u.email) = lower(v_email)
      and u.auth_user_id is null
      and u.is_active;

    -- Return the caller's memberships (same shape as app.my_memberships()); idempotent.
    return query
    select u.id, u.tenant_id, t.name, u.is_active
    from public.users u
    join public.tenants t on t.id = u.tenant_id
    where u.auth_user_id = v_uid
    order by t.name;
end;
$fn$;

comment on function app.activate_membership() is
'IDENT-1: claims pre-provisioned memberships for the caller''s VERIFIED email. An unconfirmed, banned or deleted identity may not claim.';

revoke execute on function app.activate_membership() from public;
grant execute on function app.activate_membership() to authenticated;
