-- Migration: task_write_path
-- Plan reference: SPEC-131. First governed write path for the RPC-1 programme.
--
-- THE GAP. 35 of 72 tables had no RPC write path, so for those entities a direct PostgREST write
-- was the ONLY path — no `app.authorize()`, no state-machine validation, no event emission. That is
-- not "authorization that can be bypassed"; it is no authorization in existence.
--
-- The decisive evidence that this is an implementation gap rather than a design choice: **37 of
-- ORVION's 69 seeded permissions are enforced nowhere**, and the write-side ones map exactly onto
-- the entities missing RPCs — `CREATE_TASK`, `ASSIGN_TASK`, `COMPLETE_TASK`, `SEND_MESSAGE`,
-- `CLOSE_CONVERSATION`, `RESOLVE_COMPLAINT`, `SET_EXCHANGE_RATE` and the rest. The domain already
-- decided these operations require authorization; only the code to enforce it was missing.
-- Equally decisive: `26_state_machines.md` already defines the Task, Complaint, Service Request,
-- Conversation and Marketing Campaign lifecycles in full, so none of this needs a business
-- decision — it is determinable from canon.
--
-- Tasks are first because they are the highest-traffic operational entity in a CRM and because
-- canon specifies their lifecycle completely: 5 states, 10 transitions, 5 required events.
--
-- WHAT THE DATABASE ALREADY GUARANTEES ON EVERY PATH, and therefore what these RPCs do NOT repeat:
-- catalog codes (SPEC-127 trigger), the related-entity reference (SPEC-130 trigger), tenant-safe
-- foreign keys (SPEC-129), and normalization CHECKs (SPEC-126). These RPCs add the three things a
-- constraint cannot express: authorization, lifecycle validity, and the audit event.
--
-- `overdue` is deliberately NOT reachable through `advance_task`. Canon marks it "System-set when
-- due_at passes without completion", so it belongs to a scheduled sweep (the `app.process_lead_sla`
-- pattern), not to an employee action. Modelling it as an employee transition would let staff mark
-- their own work overdue, which is the opposite of what the state means.

-- ---------------------------------------------------------------------------------------------
-- create_task
-- ---------------------------------------------------------------------------------------------
create or replace function app.create_task(
    p_title text,
    p_task_type_code text,
    p_owner_user_id uuid default null,
    p_owner_department_id uuid default null,
    p_owner_branch_id uuid default null,
    p_priority_code text default 'normal',
    p_description text default null,
    p_due_at timestamptz default null,
    p_related_entity_type text default null,
    p_related_entity_id uuid default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_id uuid;
    v_owner uuid;
    v_dept uuid;
    v_branch uuid;
    v_title text := nullif(btrim(p_title), '');
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('CREATE_TASK');

    if v_title is null then
        raise exception 'title is required';
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    -- An unassigned task defaults to the caller, which is what "I need to do this" means in
    -- practice; the columns are NOT NULL, so a task always has an accountable owner.
    v_owner := coalesce(p_owner_user_id, v_actor);
    if v_owner is null then
        raise exception 'owner_user_id is required when the caller is not a tenant user';
    end if;
    if not exists (select 1 from public.users where id = v_owner and tenant_id = v_tenant) then
        raise exception 'owner user is not in your tenant';
    end if;

    select coalesce(p_owner_branch_id, uba.branch_id), coalesce(p_owner_department_id, uba.department_id)
      into v_branch, v_dept
    from public.user_branch_assignments uba
    where uba.user_id = v_owner and uba.tenant_id = v_tenant and uba.is_primary and uba.ends_at is null
    limit 1;

    v_branch := coalesce(v_branch, p_owner_branch_id);
    v_dept   := coalesce(v_dept, p_owner_department_id);

    if v_branch is null or v_dept is null then
        raise exception 'owner branch and department are required (the owner has no primary branch assignment to default from)';
    end if;
    if not exists (select 1 from public.branches where id = v_branch and tenant_id = v_tenant) then
        raise exception 'branch is not in your tenant';
    end if;
    if not exists (select 1 from public.departments where id = v_dept and tenant_id = v_tenant) then
        raise exception 'department is not in your tenant';
    end if;

    -- task_type_code / priority_code / the related-entity pair are validated by the SPEC-127 and
    -- SPEC-130 triggers on this table; repeating those checks here would create a second place for
    -- the same rule to drift.
    insert into public.tasks (
        tenant_id, owner_user_id, owner_department_id, owner_branch_id,
        task_type_code, task_status_code, priority_code, title, description, due_at,
        related_entity_type, related_entity_id, created_by
    ) values (
        v_tenant, v_owner, v_dept, v_branch,
        p_task_type_code, 'open', p_priority_code, v_title, nullif(btrim(p_description), ''), p_due_at,
        p_related_entity_type, p_related_entity_id, v_actor
    )
    returning id into v_id;

    perform app.record_event(
        v_tenant, 'task_created', 'task', v_id, v_actor, null, 'open', null,
        jsonb_build_object('task_type_code', p_task_type_code,
                           'owner_user_id', v_owner,
                           'due_at', p_due_at,
                           'related_entity_type', p_related_entity_type,
                           'related_entity_id', p_related_entity_id),
        'info');
    return v_id;
end;
$$;

revoke execute on function app.create_task(text,text,uuid,uuid,uuid,text,text,timestamptz,text,uuid) from public;
grant execute on function app.create_task(text,text,uuid,uuid,uuid,text,text,timestamptz,text,uuid) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- assign_task
-- ---------------------------------------------------------------------------------------------
create or replace function app.assign_task(
    p_task_id uuid,
    p_owner_user_id uuid,
    p_owner_department_id uuid default null,
    p_owner_branch_id uuid default null,
    p_reason text default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_prev uuid;
    v_status text;
    v_branch uuid;
    v_dept uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('ASSIGN_TASK');

    select owner_user_id, task_status_code into v_prev, v_status
    from public.tasks where id = p_task_id and tenant_id = v_tenant;
    if v_prev is null then
        raise exception 'task not found in your tenant';
    end if;
    if v_status in ('completed', 'cancelled') then
        raise exception 'task is % and cannot be reassigned', v_status;
    end if;
    if not exists (select 1 from public.users where id = p_owner_user_id and tenant_id = v_tenant) then
        raise exception 'owner user is not in your tenant';
    end if;

    select coalesce(p_owner_branch_id, uba.branch_id), coalesce(p_owner_department_id, uba.department_id)
      into v_branch, v_dept
    from public.user_branch_assignments uba
    where uba.user_id = p_owner_user_id and uba.tenant_id = v_tenant and uba.is_primary and uba.ends_at is null
    limit 1;

    select id into v_actor from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    update public.tasks
    set owner_user_id = p_owner_user_id,
        owner_branch_id = coalesce(v_branch, owner_branch_id),
        owner_department_id = coalesce(v_dept, owner_department_id),
        updated_at = now()
    where id = p_task_id and tenant_id = v_tenant;

    perform app.record_event(
        v_tenant, 'task_assigned', 'task', p_task_id, v_actor, null, null, p_reason,
        jsonb_build_object('previous_owner_user_id', v_prev, 'new_owner_user_id', p_owner_user_id),
        'info');
end;
$$;

revoke execute on function app.assign_task(uuid,uuid,uuid,uuid,text) from public;
grant execute on function app.assign_task(uuid,uuid,uuid,uuid,text) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- advance_task — the canonical Task state machine (26_state_machines.md), employee-reachable
-- transitions only. Authored in the same `values(...) as t(frm, to_s, ev, perm)` shape as
-- advance_lead / advance_booking, so the SPEC-121 status-vocabulary guard discovers it
-- automatically and its completeness assertion covers it.
-- ---------------------------------------------------------------------------------------------
create or replace function app.advance_task(
    p_task_id uuid,
    p_to_status text,
    p_reason text default null
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_status text;
    v_event text;
    v_perm text;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    select task_status_code into v_status
    from public.tasks where id = p_task_id and tenant_id = v_tenant;
    if v_status is null then
        raise exception 'task not found in your tenant';
    end if;

    select t.ev, t.perm into v_event, v_perm
    from (values
        ('open',        'in_progress', 'task_assigned',  'ASSIGN_TASK'),
        ('open',        'completed',   'task_completed', 'COMPLETE_TASK'),
        ('open',        'cancelled',   'task_cancelled', 'COMPLETE_TASK'),
        ('in_progress', 'completed',   'task_completed', 'COMPLETE_TASK'),
        ('in_progress', 'cancelled',   'task_cancelled', 'COMPLETE_TASK'),
        ('overdue',     'in_progress', 'task_assigned',  'ASSIGN_TASK'),
        ('overdue',     'completed',   'task_completed', 'COMPLETE_TASK'),
        ('overdue',     'cancelled',   'task_cancelled', 'COMPLETE_TASK')
    ) as t(frm, to_s, ev, perm)
    where t.frm = v_status and t.to_s = p_to_status;

    if v_event is null then
        raise exception 'invalid task transition % -> %', v_status, p_to_status;
    end if;
    perform app.authorize(v_perm);

    select id into v_actor from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    update public.tasks
    set task_status_code = p_to_status,
        completed_at = case when p_to_status = 'completed' then now() else completed_at end,
        updated_at = now()
    where id = p_task_id and tenant_id = v_tenant;

    perform app.record_event(
        v_tenant, v_event, 'task', p_task_id, v_actor, v_status, p_to_status, p_reason, null, 'info');
end;
$$;

revoke execute on function app.advance_task(uuid,text,text) from public;
grant execute on function app.advance_task(uuid,text,text) to authenticated;
