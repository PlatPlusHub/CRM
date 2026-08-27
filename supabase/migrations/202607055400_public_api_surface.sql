-- API-1 (first slice) -- ORVION gains its first HTTP-reachable endpoints.
--
-- ================================================================================================
-- THE DISCOVERY. Every one of ORVION's 136 `app.*` functions is unreachable over HTTP.
--
-- Proven live against Primary, not inferred from configuration:
--
--   POST /rest/v1/rpc/document_bucket
--     -> 404 PGRST202 "Searched for the function public.document_bucket ... no matches were found
--        in the schema cache."
--   POST /rest/v1/rpc/document_bucket   (header: Content-Profile: app)
--     -> 406 PGRST106 "Invalid schema: app. Only the following schemas are exposed: public,
--        graphql_public"
--   POST /rest/v1/tenants
--     -> 401 42501 "permission denied for table tenants"
--
-- The third call is the control: the API itself works and the table is visible to PostgREST, so the
-- two 404s are specifically "that schema is not exposed" and not "the API is down". And
-- `public` currently contains exactly ONE function -- `moddatetime`, from an extension. ORVION has
-- zero endpoints.
--
-- WHY NO TEST CAUGHT THIS. Every RPC test in the suite calls `app.something(...)` as a database
-- session. That is a real and necessary proof of the function's logic, and it is not a proof that
-- any client can reach it. The suite has been green for the whole programme while the entire API
-- surface was unreachable, because SQL and HTTP are different doors and only one was ever tried.
--
-- WHY THE FIX IS WRAPPERS AND NOT "EXPOSE THE app SCHEMA". Exposing `app` to PostgREST is one
-- setting, and it would publish all 136 functions at once -- including every internal helper that
-- MUST be executable by `authenticated` because RLS policies call it: `app.has_permission`,
-- `app.current_tenant_id`, `app.visible_branch_ids`, `app.item_financials`. Those are not
-- vulnerabilities, but publishing them hands any authenticated caller a permission-probing oracle
-- and turns every internal refactor into a breaking API change. A deliberate, named, minimal
-- surface in `public` is the smaller attack surface AND the stable contract.
--
-- WHY THE WRAPPERS ARE `security invoker`, AND WHY THAT IS THE WHOLE SAFETY PROPERTY.
-- A `security definer` wrapper would run as its owner, so PostgreSQL would check EXECUTE on the
-- inner `app.*` function against the OWNER rather than the caller -- turning every wrapper into a
-- privilege-escalation bridge that hands any caller the private schema's authority. With
-- `security invoker` (the default, stated explicitly here so it can never be lost in an edit) the
-- caller's own role is what the inner EXECUTE grant is checked against, so the wrappers add
-- reachability and precisely zero authority. This is NOT a second authorization system: it is the
-- same one, with a door in front of it. `52_public_api_and_executor_contract_test.sql` pins it for every current
-- and future wrapper.
--
-- SCOPE. This migration adds only the two endpoints WP-04-E actually needs, because the executor
-- cannot function without them. The remaining client-facing surface is a specified package
-- (API-1 in MASTER_EXECUTION_PLAN.md) rather than 130 wrappers written speculatively today.
-- ================================================================================================

-- ================================================================================================
-- GRANT-1 -- and this one had to be found before the first endpoint shipped, not after the 130th.
--
-- `revoke execute ... from public` does NOT make a public-schema function private here. Live
-- evidence, `pg_default_acl`:
--
--     grantor=postgres  schema=public  objtype=f
--     {postgres=X/postgres, anon=X/postgres, authenticated=X/postgres, service_role=X/postgres}
--
-- Supabase ships `alter default privileges in schema public grant execute on functions to anon,
-- authenticated`. Those are EXPLICIT per-role grants, so revoking from the PUBLIC pseudo-role
-- removes something that was never there and leaves `anon=X` untouched. The first version of this
-- migration did exactly that, and `52_public_api_and_executor_contract_test.sql` failed on its
-- first run with both endpoints executable by `anon`.
--
-- This is SPEC-124's defect class -- the hosted default ACL granting more than ORVION intends --
-- recurring for FUNCTIONS after SPEC-124 fixed it for TABLES. It was invisible until ORVION created
-- its first `public` function, which is this migration.
--
-- It was not exploitable in the moment: the wrappers are `security invoker`, so a caller still has
-- to pass the inner `app.*` EXECUTE check, which `anon` fails. But relying on that is relying on the
-- second lock while the first stands open -- and one `security definer` slip in any future wrapper
-- would turn it into a real breach. It also leaks existence: a 403 from inside the function tells an
-- anonymous caller the endpoint is real.
--
-- FIXED AT THE CLASS, not on two functions. The default itself is changed, so every wrapper API-1
-- adds is private on creation and must be granted deliberately -- which is the same "explicit grants
-- only" model `10_grant_model_test.sql` already enforces for tables.
-- ================================================================================================
alter default privileges in schema public revoke execute on functions from anon, authenticated;

create or replace function public.claim_storage_actions(p_limit integer default 50)
returns table (
    finding_id      uuid,
    tenant_id       uuid,
    storage_path    text,
    action_code     text,
    attempt_count   integer
)
language sql
security invoker
stable
set search_path = ''
as $fn$
    select * from app.claim_storage_actions(p_limit);
$fn$;

-- anon/authenticated are revoked EXPLICITLY as well as by the default-privileges change above.
-- The default only governs functions created after it; these two were created in this same
-- migration, and being explicit here means the grant state is readable without knowing the order.
revoke execute on function public.claim_storage_actions(integer) from public, anon, authenticated;
grant  execute on function public.claim_storage_actions(integer) to service_role;

comment on function public.claim_storage_actions(integer) is
    'HTTP endpoint for app.claim_storage_actions. SECURITY INVOKER, so the caller''s own EXECUTE '
    'grant on the app function is what authorizes it -- the wrapper adds reachability, never '
    'authority (API-1 / WP-04-E).';

create or replace function public.resolve_storage_finding(
    p_finding_id uuid,
    p_resolution_code text,
    p_note text default null
)
returns text
language sql
security invoker
volatile
set search_path = ''
as $fn$
    select app.platform_resolve_storage_finding(p_finding_id, p_resolution_code, p_note);
$fn$;

revoke execute on function public.resolve_storage_finding(uuid, text, text) from public, anon, authenticated;
grant  execute on function public.resolve_storage_finding(uuid, text, text) to service_role;

comment on function public.resolve_storage_finding(uuid, text, text) is
    'HTTP endpoint for app.platform_resolve_storage_finding. SECURITY INVOKER (API-1 / WP-04-E).';
