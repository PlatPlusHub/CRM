-- WP-00 -- Event / audit write-path integrity.
--
-- DISCOVERY (2026-08-26, proven behaviourally as a real `authenticated` employee holding the
-- 13-permission `employee` role, then rolled back):
--
--   An ordinary employee could INSERT directly into public.events, supplying every column. The
--   only barrier was the `audit_insert` policy, whose WITH CHECK is `tenant_id =
--   app.current_tenant_id()` -- tenant membership and nothing else. The employee successfully
--   wrote an event that was: attributed to a DIFFERENT employee (`actor_user_id`), about a lead
--   they could not read, carrying an event_type_code that is not in the registry
--   (`fake_event_code`), and backdated 400 days via an explicit `created_at`.
--
--   public.security_events had the identical policy and the identical hole -- a `login_failure`
--   could be fabricated against a colleague.
--
-- Why this is worse than an ordinary write bypass: both tables carry `forbid_mutation` triggers,
-- so the forged row can never be corrected or deleted by anyone. The append-only guarantee, which
-- exists to protect history, instead makes the forgery permanent. SPEC-143 closed the READ side of
-- the audit trail (an event is readable exactly when its subject is); the WRITE side was never
-- closed, so the spine that Customer 360, Lead 360 and every report are built on was forgeable by
-- any logged-in user.
--
-- MECHANISM -- the smallest coherent one, using the pattern already in the repository.
--
--   `app.record_event` is the ONLY writer of public.events: 50 app functions call it and no other
--   function inserts into the table. So making it the sole *privileged* writer costs nothing.
--   It becomes SECURITY DEFINER (joining app.has_permission / app.plan_allows / app.item_financials
--   / app.enforce_entity_reference, which are already DEFINER) and the direct INSERT grant is
--   revoked. `created_at` then cannot be supplied at all -- it is the column default, server-side.
--
--   Tenant and actor become authoritative rather than caller-supplied, but CONDITIONALLY, because
--   five legitimate SECURITY DEFINER callers run with NO user session and pass a tenant read from a
--   row: app.process_lead_sla (scheduled), app.claim_conversion_deliveries and
--   app.record_conversion_delivery_result (the n8n integration RPCs), app.capture_attribution_click.
--   Unconditionally pinning tenant to app.current_tenant_id() would have broken the n8n contract
--   and the SLA job -- the integration boundary this repository is required to preserve. So:
--
--     * user session present (app.current_tenant_id() is not null):
--         p_tenant_id must equal the session tenant, else raise;
--         actor is FORCED to app.current_user_id(), ignoring whatever the caller passed.
--     * no user session (system / integration path):
--         p_tenant_id is taken as given but must not be null;
--         actor must be null -- a system path may not name a human actor.
--
--   The existing event_type_code and severity_code registry checks are unchanged and now become
--   unbypassable, because the direct-INSERT route that skipped them is gone.
--
-- DELIBERATELY NOT CHANGED (recorded, not silently absorbed):
--   * public.security_events has ZERO legitimate writers -- no function in `app` inserts into it.
--     Revoking INSERT therefore removes only the forgery path and breaks nothing. The table stays
--     write-dead until a governed producer is built; that gap is pre-existing and tracked, and
--     inventing a producer here would be fabricating capability.
--   * The `audit_insert` policies are left in place. With the grant revoked they are inert (a
--     policy cannot admit a write the grant already denies), and removing them would churn the RLS
--     coverage model for no security gain.
--   * `authenticated` keeps EXECUTE on app.record_event -- it must, since 45 of the 50 callers are
--     SECURITY INVOKER and run as the user. A direct call is therefore still possible, but it can
--     now only produce a TRUTHFULLY attributed, server-timestamped, registry-valid event about the
--     caller's own tenant. That is self-incriminating rather than forgery, and is the bounded
--     residual this mechanism accepts.
--   * Three further members of the same failure class were proven in the same sweep and are NOT in
--     this package's boundary, because each is a business table whose write model is the open
--     SEC-1 architectural decision: forging lead_assignments history, stealing first-handler
--     attribution via customers.first_registered_user_id at INSERT, and mutating the
--     offline_conversions Google identity snapshot. They are recorded as evidence for SEC-1.

-- 1. app.record_event -- sole privileged writer of the audit spine.
create or replace function app.record_event(
    p_tenant_id      uuid,
    p_event_type_code text,
    p_entity_type    text,
    p_entity_id      uuid,
    p_actor_user_id  uuid  default null,
    p_previous_state text  default null,
    p_new_state      text  default null,
    p_reason         text  default null,
    p_payload        jsonb default null,
    p_severity_code  text  default 'info'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_event          uuid;
    v_session_tenant uuid := app.current_tenant_id();
    v_tenant         uuid;
    v_actor          uuid;
begin
    -- Tenant and actor authority. A user session may only ever write into its own tenant, as
    -- itself; a system path (no session) supplies the tenant and may not name a human actor.
    if v_session_tenant is not null then
        if p_tenant_id is distinct from v_session_tenant then
            raise exception 'record_event: tenant % is not the caller''s tenant %',
                p_tenant_id, v_session_tenant
                using errcode = 'insufficient_privilege';
        end if;
        v_tenant := v_session_tenant;
        v_actor  := app.current_user_id();
    else
        if p_tenant_id is null then
            raise exception 'record_event: no active tenant and no tenant supplied'
                using errcode = 'insufficient_privilege';
        end if;
        if p_actor_user_id is not null then
            raise exception 'record_event: a system-context event may not name an actor'
                using errcode = 'insufficient_privilege';
        end if;
        v_tenant := p_tenant_id;
        v_actor  := null;
    end if;

    if not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'event_type' and code = p_event_type_code
    ) then
        raise exception 'unknown event_type_code: % (register it in 27_event_catalog.md + the event_type catalog first)', p_event_type_code;
    end if;
    if not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'event_severity_code' and code = p_severity_code
    ) then
        raise exception 'unknown severity_code: %', p_severity_code;
    end if;

    -- created_at is intentionally not in the column list: it is the server-side default, so no
    -- caller -- RPC or direct -- can backdate an event.
    insert into public.events (
        tenant_id, event_type_code, severity_code, actor_user_id, entity_type, entity_id,
        previous_state, new_state, reason, payload
    )
    values (
        v_tenant, p_event_type_code, p_severity_code, v_actor, p_entity_type, p_entity_id,
        p_previous_state, p_new_state, p_reason, p_payload
    )
    returning id into v_event;
    return v_event;
end;
$$;

grant execute on function app.record_event(uuid, text, text, uuid, uuid, text, text, text, jsonb, text) to authenticated;

-- 2. Close the direct-write route. app.record_event is now the only way in.
revoke insert on public.events          from authenticated;
revoke insert on public.security_events from authenticated;
