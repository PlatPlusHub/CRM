-- TRANS-2 + SEC-1's last table -- the lead's handler rule now applies on the direct path too.
--
-- ================================================================================================
-- A CORRECTION FIRST, BECAUSE IT IS THE REASON THIS MIGRATION EXISTS
--
-- `202607056100` recorded that `app.record_lead_interaction` "authorizes nothing", and left
-- `lead_interactions` under SEC-1 as an undecided business question. That was WRONG, and the error
-- was in my detector, not in ORVION: I searched for `app.authorize('PERM')` and this function does
-- not use it. It enforces its rule inline instead:
--
--     if not (v_actor is not null and v_actor = v_assigned) and not app.has_permission('ASSIGN_LEAD')
--     then raise 'permission denied: not the assigned handler and lacks ASSIGN_LEAD'; end if;
--     if not app.mfa_satisfied() then raise 'multi-factor authentication required'; end if;
--
-- `app.advance_lead` (non-closure transitions) and `app.convert_lead` state the SAME rule verbatim.
-- So the lead pipeline does have a documented capability rule -- it is just assignment-based rather
-- than permission-based, which is why a permission-shaped search could not see it.
--
-- That changes the finding completely. `lead_interactions` is not "no bypass, only an open
-- question"; it is the SEC-1 pattern exactly: the RPC charges a rule and direct DML charges nothing.
--
-- ================================================================================================
-- TRANS-2: EIGHT LEAD TRANSITIONS WERE ENFORCED FOR SEQUENCE AND NOT FOR AUTHORITY
--
-- `app.status_transitions` is the direct-DML half of ORVION's transition authority, read by
-- `app.enforce_status_transition`. Its only authorization column is `permission_key`, and it applies
-- it `if v_permission is not null`. Eight `leads` rows carry NULL:
--
--     assigned->contacted   contacted->qualified    qualified->quotation_sent   qualified->won
--     quotation_sent->negotiation   quotation_sent->won   negotiation->won   won->converted
--
-- They are null because the rule those transitions actually carry -- "the assigned handler, or
-- ASSIGN_LEAD, plus MFA" -- has no column that can express it. The effect was that direct DML could
-- walk a COLLEAGUE'S lead all the way from `contacted` to `won` and on to `converted` with no
-- capability check of any kind, while every RPC that performs those same moves refuses anyone who is
-- not the handler. Reachable: `leads.scope_isolation` lets a user update any lead they can see, and
-- an employee with VIEW_DEPARTMENT_QUEUE can see their whole department's pipeline.
--
-- The three other lead-status writers are unaffected: `app.assign_lead` performs `new->assigned`,
-- which already carries ASSIGN_LEAD in the table; `app.process_lead_sla` is SECURITY DEFINER and
-- session-less, so it returns at the platform-path check; and `advance_lead`'s closure transitions
-- already carry CLOSE_LEAD and keep it -- the fallback below runs ONLY where `permission_key` is
-- null, so no path becomes stricter than the RPC that walks it.
--
-- AND THE CLASS, NOT THE INSTANCE: a null `permission_key` used to mean "allow". It now means
-- "apply this table's named fallback rule", and a table with neither a permission nor a fallback
-- FAILS CLOSED. Only `leads` has nulls today, so the new else-branch is unreachable now -- which is
-- the point: it makes the next unguarded transition a loud error instead of a silent hole.
-- ================================================================================================

-- The rule, in one place, exactly as the three lead RPCs state it.
create or replace function app.require_lead_handler(p_assigned_user_id uuid)
returns void
language plpgsql
set search_path = ''
as $fn$
declare
    v_actor uuid := app.current_user_id();
begin
    if not (v_actor is not null and v_actor = p_assigned_user_id)
       and not app.has_permission('ASSIGN_LEAD') then
        raise exception 'permission denied: not the assigned handler and lacks ASSIGN_LEAD'
            using errcode = '42501';
    end if;
    if not app.mfa_satisfied() then
        raise exception 'multi-factor authentication required for this role'
            using errcode = '42501';
    end if;
end
$fn$;

-- `authenticated` needs EXECUTE because `app.guard_lead_interaction_authority` is SECURITY INVOKER,
-- exactly like `app.authorize` and `app.has_permission`, which every other invoker guard calls. The
-- function only raises or returns void -- it decides nothing and reveals nothing a caller could not
-- already determine by attempting the write.
revoke execute on function app.require_lead_handler(uuid) from public;
grant  execute on function app.require_lead_handler(uuid) to authenticated;

create or replace function app.enforce_status_transition()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_column text := tg_argv[0];
    v_old text;
    v_new text;
    v_permission text;
    v_found boolean;
begin
    -- Platform paths (service_role, migrations, seeds) are outside per-table enforcement -- canon 35
    -- principle 6. A tenant user cannot reach a row without a resolved identity, so this cannot be
    -- used to escape the guard.
    if (select auth.uid()) is null then
        return new;
    end if;

    v_old := to_jsonb(old) ->> v_column;
    v_new := to_jsonb(new) ->> v_column;

    if v_new is not distinct from v_old then
        return new;
    end if;

    select st.permission_key, true
      into v_permission, v_found
    from app.status_transitions st
    where st.table_name = tg_table_name
      and st.from_status = v_old
      and st.to_status = v_new;

    if not coalesce(v_found, false) then
        raise exception
            '% is not a permitted transition for %.% (canon 26 state machine); use the app.advance_* RPC',
            coalesce(v_old, '(null)') || ' -> ' || coalesce(v_new, '(null)'), tg_table_name, v_column
            using errcode = '23514';
    end if;

    if v_permission is not null then
        perform app.authorize(v_permission);
    elsif tg_table_name = 'leads' then
        -- TRANS-2. `permission_key` cannot express "the assigned handler", so these rows are null --
        -- and null used to mean no check at all. The rule is not invented here: it is copied from
        -- app.advance_lead, app.convert_lead and app.record_lead_interaction, which all state it.
        -- `to_jsonb` rather than `new.assigned_user_id` because plpgsql binds every NEW field named
        -- in a generic trigger regardless of which branch runs (the SPEC-159-A hazard).
        perform app.require_lead_handler((to_jsonb(new) ->> 'assigned_user_id')::uuid);
    else
        -- Fail closed. A transition with no permission and no named fallback is an unguarded write
        -- path, and returning NEW here is exactly how the eight leads rows stayed invisible.
        raise exception
            'transition %.% % -> % has no permission_key and no fallback authority rule',
            tg_table_name, v_column, v_old, v_new
            using errcode = '42501';
    end if;

    return new;
end
$fn$;

-- ------------------------------------------------------------------------------------------------
-- SEC-1's last table: `lead_interactions` charges what `app.record_lead_interaction` charges.
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_lead_interaction_authority()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_assigned uuid;
begin
    if (select auth.uid()) is null then
        return new;
    end if;

    select l.assigned_user_id into v_assigned
    from public.leads l
    where l.id = new.lead_id and l.tenant_id = new.tenant_id;

    -- No parent means the RLS policy will refuse this row anyway; refusing here keeps the guard from
    -- silently passing a write it could not evaluate.
    if not found then
        raise exception 'lead is not in your tenant' using errcode = '42501';
    end if;

    perform app.require_lead_handler(v_assigned);
    return new;
end
$fn$;

revoke execute on function app.guard_lead_interaction_authority() from public;

create trigger lead_interactions_guard_handler_authority
    before insert or update on public.lead_interactions
    for each row execute function app.guard_lead_interaction_authority();
