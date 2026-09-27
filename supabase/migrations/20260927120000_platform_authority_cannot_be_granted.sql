-- ================================================================================================
-- SPEC-227 -- SUB-3: platform authority over a tenant's subscription cannot be granted to a tenant
-- user.
--
-- SPEC-157 (`202607054000`, B6) put the subscription lifecycle outside every tenant: `subscriptions`
-- is written only when `app.has_permission('MANAGE_SUBSCRIPTION')` holds, a payment proof is decided
-- only when `app.has_permission('REVIEW_SUBSCRIPTION_PAYMENT')` holds, and NO role holds either, so
-- both gates deny every tenant user. Canon 28 says so twice: "Tenant users may upload proof but
-- cannot approve their own subscription renewal", and "`subscriptions` writes need
-- `MANAGE_SUBSCRIPTION`, which no role holds". Platform authority lives in SECURITY DEFINER
-- functions granted to `service_role` alone. `42_subscription_lifecycle_test.sql` assertion 20 pins
-- the mechanism: no ROLE holds MANAGE_SUBSCRIPTION.
--
-- RBAC-3 (`202607059800`) then added a second path from a user to a permission,
-- `public.user_permission_grants`, written by any holder of MANAGE_PERMISSIONS (`owner`, `ceo`),
-- with no restriction on WHICH permission is granted. MEASURED in rolled-back probes: an `owner` at
-- `aal2` on a `read_only` starter tenant (write gate false, its own subscription UPDATE filtered to
-- 0 rows) inserted a grant of MANAGE_SUBSCRIPTION to itself, then rewrote its subscription to
-- `active` / `enterprise` / `lifetime`, which turned the write gate true and the plan's features on,
-- and inserted a second subscription row. With REVIEW_SUBSCRIPTION_PAYMENT granted the same way, it
-- marked its own pending payment proof `approved`, after which `app.platform_review_payment_proof`
-- refused the Platform Owner (`only a pending proof can be reviewed`). The canon-31 rule "the plan
-- gate always last, so a tenant administrator can never grant past a commercial entitlement" was
-- defeated by granting the plan itself.
--
-- THE REPAIR restores SPEC-157's own mechanism at the one door that reopened it. "No role holds
-- these two permissions" becomes "no tenant principal holds them": a BEFORE INSERT OR UPDATE trigger
-- on `user_permission_grants` refuses any row whose effect is `grant` for either permission, on every
-- path, session-less included. There is no legitimate grant of either: a tenant user holding them IS
-- the defect (SPEC-157: "it would have let each tenant elevate its own subscription, the exact
-- opposite of the requirement"). A `deny` of either is harmless and stays legal, as does every other
-- grant.
--
-- Deliberately NOT done: no RLS policy, grant, permission, role, event producer or existing function
-- changes. `app.has_permission` stays the single decision point and is not taught a second rule.
-- Revoking `authenticated`'s writes on `subscriptions` was rejected: it would leave the grant live
-- and reported by `app.effective_permissions`, and it would not reach the `approval_requests`
-- `subscription_approval` arm. USR-3 (no step-up at this table door) is a different invariant and
-- stays separately owned.
-- ================================================================================================

-- A grant of either permission that already exists would stay live under a trigger that judges only
-- new writes. None may exist; if one does, the deployment stops rather than deciding its fate here.
do $$
begin
    if exists (
        select 1
        from public.user_permission_grants g
        join public.permissions p on p.id = g.permission_id
        where g.effect = 'grant'
          and p.key in ('MANAGE_SUBSCRIPTION', 'REVIEW_SUBSCRIPTION_PAYMENT')
    ) then
        raise exception 'SUB-3: a grant of platform subscription authority already exists; resolve it before deploying';
    end if;
end $$;

create or replace function app.guard_platform_permission_grant()
 returns trigger
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare
    v_key text;
begin
    if new.effect <> 'grant' then
        return new;
    end if;

    select p.key into v_key from public.permissions p where p.id = new.permission_id;

    if v_key in ('MANAGE_SUBSCRIPTION', 'REVIEW_SUBSCRIPTION_PAYMENT') then
        raise exception 'permission denied: % is platform authority and cannot be granted to a tenant user', v_key
            using errcode = '42501';
    end if;

    return new;
end
$function$;

revoke all on function app.guard_platform_permission_grant() from public;

comment on function app.guard_platform_permission_grant() is
'SUB-3 (SPEC-227): no tenant principal may hold MANAGE_SUBSCRIPTION or REVIEW_SUBSCRIPTION_PAYMENT. '
'SPEC-157 keeps both held by no role; this refuses the per-user grant path on every write path.';

create trigger user_permission_grants_guard_platform_authority
    before insert or update on public.user_permission_grants
    for each row execute function app.guard_platform_permission_grant();
