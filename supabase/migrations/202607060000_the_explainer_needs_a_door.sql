-- RBAC-4 -- the explainer the dashboard was built for could not be reached from the dashboard.
--
-- FOUND while reconstructing the tests for `202607059800` (RBAC-3), which was recovered from Primary
-- on 2026-09-03 after being applied there and never committed. That migration created
-- `app.effective_permissions` for a stated purpose -- "'Why does this user hold this?' must be
-- answerable without reading SQL, both for the dashboard and for an audit" -- and granted EXECUTE to
-- `authenticated`. It never created the `public` wrapper, and PostgREST serves only `public`.
--
-- MEASURED, not inferred:
--     app.effective_permissions      public.effective_permissions   <- ABSENT
--     app.tenant_capabilities        public.tenant_capabilities     <- present
--     app.supplier_credit            public.supplier_credit         <- present
-- Both of its nearest siblings -- the other two gated readers a client legitimately calls -- carry a
-- wrapper. This one does not, so the single capability RBAC-3 exists to enable is unreachable from
-- any browser, and `MASTER_API_CONTRACT.md` would have listed it nowhere. The omission is consistent
-- with a package that was never committed, never tested and never had its contract regenerated.
--
-- WHY THIS IS NOT THE `has_permission` DECISION BEING REOPENED. `app.has_permission` is deliberately
-- NOT reachable, and `verify_api_end_to_end.ps1` asserts so ("has_permission is NOT reachable -- no
-- permission-probing oracle"). That assertion stays true and is not touched. The two are different
-- objects:
--   * `has_permission(key)` takes an ARBITRARY key and answers yes/no about the caller -- a probe
--     primitive, whose exposure would let a client enumerate the authorization model one guess at a
--     time.
--   * `effective_permissions(user)` is CURATED and SELF-GATING: it returns the catalog rows with the
--     four decision inputs, and its own WHERE clause already restricts it -- a caller may itemise
--     THEMSELVES freely, and itemising anyone else costs MANAGE_PERMISSIONS. A user learning their
--     own capabilities is what lets a UI render, and `tenant_capabilities()` -- the plan half of the
--     same question -- is already exposed on exactly that reasoning.
--
-- The wrapper follows API-1's model exactly: it adds REACHABILITY and zero authority. SECURITY
-- INVOKER (never DEFINER -- the `app` function is already DEFINER and owns the decision), search_path
-- pinned, EXECUTE revoked from PUBLIC and granted to `authenticated` only.

create or replace function public.effective_permissions(p_user_id uuid default null)
returns table (
    permission_key   text,
    capability_group text,
    action_kind      text,
    from_role        boolean,
    user_grant       boolean,
    user_deny        boolean,
    plan_allows      boolean,
    effective        boolean
)
language sql
stable
security invoker
set search_path = ''
as $FN$ select * from app.effective_permissions(p_user_id) $FN$;

revoke all on function public.effective_permissions(uuid) from public;
grant execute on function public.effective_permissions(uuid) to authenticated;

comment on function public.effective_permissions(uuid) is
'RBAC-4: the reachable door for app.effective_permissions -- the administration dashboard''s '
'"why does this user hold this?" surface. Adds reachability and NO authority: the app function is '
'SECURITY DEFINER and self-gates (own permissions freely; another user''s costs MANAGE_PERMISSIONS). '
'Distinct from app.has_permission, which stays unreachable on purpose (no permission-probing oracle).';
