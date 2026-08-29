-- ADMIN-1 -- a membership may not claim a different human than the identity it is bound to.
--
-- API-3, tenant-administration family. `app.create_tenant_user` accepts `p_auth_user_id` from the
-- caller and inserts it **without validating it against anything**. The only structural check is
-- `users_auth_user_id_fkey`, which proves the identity EXISTS and nothing about WHOSE it is.
--
-- CANON 34 IS EXPLICIT, and this rule is derived from it rather than invented:
--   "A human being has exactly one identity across the entire platform. That identity is
--    `auth.users`... it owns everything that proves *who the person is*: credentials, VERIFIED
--    EMAIL/phone, trusted devices, and MFA enrolment."
--   "A membership is one human's participation in one tenant... it owns everything that describes
--    *what the person may do* inside that tenant."
-- So the verified email belongs to the IDENTITY, and the membership describes permissions, not
-- personhood. A linked membership carrying a different email is claiming to be a different human.
--
-- REPRODUCED on a clean local reset. Agency A's owner (holding MANAGE_USERS, aal2) calls
-- `create_tenant_user('Alice Smith', 'alice@a.test', null, <BOB'S auth uid>)` where Bob is an
-- existing member of an unrelated Agency B:
--
--     membership row      -> full_name 'Alice Smith', email 'alice@a.test'
--     bound identity      -> auth.users.email 'bob@b.test'          EMAIL DIVERGED
--     the real Alice, confirmed, calls activate_membership()
--                         -> 0 memberships. She is PERMANENTLY LOCKED OUT of her own membership,
--                            because activate_membership only claims rows with auth_user_id NULL.
--     Bob calls my_memberships()
--                         -> "Agency A" AND "Agency B". Bob now has access to a tenant he never
--                            joined, and every action he takes there is attributed to "Alice Smith".
--
-- Three distinct harms from one unvalidated argument: silent misattribution of every subsequent
-- action, permanent lockout of the rightful person, and an unconsented cross-tenant access grant.
-- It needs no malice -- one pasted UUID does it, and nothing anywhere reports it afterwards.
--
-- WHY A TRIGGER HERE, WHEN IDENT-1's FIX WENT IN THE FUNCTION. The layer was chosen by measurement
-- both times, and the measurements disagreed -- which is the point of measuring rather than
-- copying the previous package's answer:
--   * IDENT-1: 49 test files create `auth.users` rows and NONE sets `email_confirmed_at`, so a
--     trigger would have broken all 49, and the rule was a precondition of self-claiming anyway.
--   * ADMIN-1: 120 linked membership rows across the whole suite, and **ZERO** carry a divergent
--     email. The invariant already holds everywhere; nothing has to change to satisfy it.
-- And unlike IDENT-1, the alternate paths here are genuinely open: `users.scope_update` lets any
-- MANAGE_USERS holder set `auth_user_id` by direct DML, so a check inside `create_tenant_user` would
-- close one door and leave the other. This is a cross-table integrity invariant -- a CHECK cannot
-- reference `auth.users` -- so it belongs in a trigger.
--
-- NO SESSION-LESS EXEMPTION (SEC-1 Refinement 2). This is integrity, not authorization: a membership
-- bound to the wrong human is exactly as wrong when a migration does it.
--
-- ORDER OF OPERATIONS, deliberately: the identity owns the email, so an address change is made in
-- Supabase Auth FIRST and mirrored onto the membership second. The reverse order is refused, and
-- that is the canon-34 hierarchy expressing itself rather than an accident of implementation.
--
-- CROSS-PATH SWEEP (`AGENTS.md 3 5b`):
--   Q1 -- which paths meet the new rule? `create_tenant_user` (p_auth_user_id), any direct
--     INSERT/UPDATE of `users.auth_user_id` or `users.email` by a MANAGE_USERS holder, and
--     `app.activate_membership`, which satisfies it by construction because it matches on the email
--     it is about to bind. Verified against pg_proc: those are the only writers of `auth_user_id`.
--   Q2 -- which paths CONSUME the shape? `activate_membership` reads `users.email` to find claimable
--     rows; after this trigger a linked row's email is guaranteed to equal its identity's, which
--     makes that match strictly more reliable, not less. No consumer parses or derives from the
--     previous (unconstrained) shape, because there was no shape to rely on.

create or replace function app.enforce_membership_identity_binding()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_identity_email text;
begin
    -- An UNCLAIMED membership names no human yet. That is the whole point of the invite flow
    -- (`create_tenant_user` with a null p_auth_user_id logs `has_auth_link:false`), so it is not a
    -- divergence and must keep working.
    if new.auth_user_id is null then
        return new;
    end if;

    -- Only re-check when the binding or the email actually moves. Editing a phone number or a name
    -- on a linked membership is ordinary work and must not pay for this lookup.
    if tg_op = 'UPDATE'
       and new.auth_user_id is not distinct from old.auth_user_id
       and new.email is not distinct from old.email then
        return new;
    end if;

    select au.email into v_identity_email
    from auth.users au
    where au.id = new.auth_user_id;

    -- No row: users_auth_user_id_fkey has not been validated yet on a BEFORE trigger. Stay silent
    -- and let the foreign key reject it, rather than inventing a second error for one fault.
    if not found then
        return new;
    end if;

    -- An identity with no email is an anonymous sign-in. It proves no mailbox, so it cannot be the
    -- human behind a named membership -- `public.users.email` is NOT NULL, so this is always a
    -- divergence rather than a null-comparison edge case.
    if v_identity_email is null then
        raise exception 'membership % cannot be bound to an identity that has no email address', new.email
            using errcode = 'check_violation';
    end if;

    if lower(new.email) is distinct from lower(v_identity_email) then
        raise exception 'membership email % does not match the bound identity (canon 34: the Human Identity owns the verified email; change it in Supabase Auth first, then mirror it here)', new.email
            using errcode = 'check_violation';
    end if;

    return new;
end;
$fn$;

comment on function app.enforce_membership_identity_binding() is
'ADMIN-1: a linked public.users row must carry the email of the auth.users identity it is bound to (canon 34). Integrity, not authorization -- no session-less exemption.';

create trigger users_enforce_identity_binding
    before insert or update on public.users
    for each row
    execute function app.enforce_membership_identity_binding();

-- SECURITY DEFINER because `authenticated` holds no SELECT on `auth.users`; under INVOKER the lookup
-- would find nothing, fall through the `if not found` branch, and allow every divergence -- the
-- guard would be weakest against exactly the caller it exists to stop. `create function` grants
-- EXECUTE to PUBLIC by default, which `10_grant_model_test.sql` assertion 5 correctly rejects.
revoke execute on function app.enforce_membership_identity_binding() from public;
