-- Migration: assignment_history_integrity
-- Plan reference: SPEC-140. Makes "who had this lead, and who had it first" a fact the database
-- guarantees rather than one it happens to record.
--
-- WHAT CANON ALREADY REQUIRED, AND WHAT WAS ACTUALLY TRUE. Canon 04 §Lead Assignment History is
-- unambiguous: "Every assignment must remain visible in the lead timeline", the timeline must show
-- "The employee who received it ... The next employee who received it", and "No assignment history
-- may be deleted". Three things stood between that and reality:
--
--   1. `app.assign_lead` refuses any lead not in `new` status with the message "use reassignment" --
--      and no reassignment RPC existed. REASSIGN_LEAD was seeded and granted to four roles and
--      enforced nowhere, so the only way to hand a lead over was a direct UPDATE of
--      `leads.assigned_user_id`, which writes no history at all. The first employee's involvement was
--      simply overwritten.
--   2. `lead_assignments` had no triggers and `authenticated` holds UPDATE on it, so a history row
--      could be rewritten to name a different employee -- worse than deletion, because it leaves a
--      plausible-looking timeline that is false.
--   3. Nothing forced the two to agree. A lead's assignee could change with no corresponding history
--      row and nothing would complain.
--
-- THE ENFORCEMENT CHOICE. The trigger below GUARDS rather than WRITES. A writing trigger was the
-- obvious alternative and is worse: `assigned_by` and `assignment_reason` are known only to the
-- caller, so a trigger would either lose them or need them smuggled through session settings. A
-- guard keeps the RPC as the author of the record -- which is where the context lives -- and makes
-- the unrecorded path fail loudly instead of silently producing a hole.
--
-- This requires history to be written BEFORE the lead row is updated. `app.process_lead_sla` already
-- did it in that order; `app.assign_lead` did not, and is reordered below.

-- ---------------------------------------------------------------------------------------------
-- 1. History rows are testimony: they may be closed, never rewritten.
--
-- `unassigned_at` and `is_current` must stay updatable -- that is how a row is closed when
-- responsibility moves. Everything that identifies WHO had the lead and WHEN is frozen.
-- ---------------------------------------------------------------------------------------------
create or replace function app.forbid_assignment_history_rewrite()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if tg_op = 'DELETE' then
        raise exception 'lead assignment history may not be deleted (canon 04: "No assignment history may be deleted")'
            using errcode = '42501';
    end if;

    if new.lead_id is distinct from old.lead_id
       or new.assigned_user_id is distinct from old.assigned_user_id
       or new.assigned_at is distinct from old.assigned_at
       or new.assigned_by is distinct from old.assigned_by
       or new.tenant_id is distinct from old.tenant_id then
        raise exception 'lead assignment history is immutable; only unassigned_at and is_current may change'
            using errcode = '42501';
    end if;
    return new;
end
$$;

create trigger lead_assignments_immutable
    before update or delete on public.lead_assignments
    for each row execute function app.forbid_assignment_history_rewrite();

-- ---------------------------------------------------------------------------------------------
-- 2. A lead's assignee cannot change without the timeline saying so.
--
-- Fires on any path -- RPC, direct PostgREST write, manual SQL. The check is deliberately narrow:
-- it asks only that a CURRENT history row names the assignee the lead now claims. It does not try to
-- police who did the assigning or why; that is the RPC's job, and duplicating it here would create a
-- second rule to drift.
-- ---------------------------------------------------------------------------------------------
create or replace function app.require_assignment_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if new.assigned_user_id is null then
        return new;   -- an unassigned lead has nothing to record
    end if;
    if tg_op = 'UPDATE' and new.assigned_user_id is not distinct from old.assigned_user_id then
        return new;   -- the assignee did not move
    end if;

    if not exists (
        select 1 from public.lead_assignments la
        where la.lead_id = new.id
          and la.tenant_id = new.tenant_id
          and la.assigned_user_id = new.assigned_user_id
          and la.is_current
    ) then
        raise exception
            'a lead assignee may not change without a current lead_assignments row (canon 04: every assignment must remain visible in the lead timeline); use app.assign_lead or app.reassign_lead'
            using errcode = '23514';
    end if;
    return new;
end
$$;

create trigger leads_require_assignment_history
    after insert or update of assigned_user_id on public.leads
    for each row execute function app.require_assignment_history();

-- ---------------------------------------------------------------------------------------------
-- 3. Reorder app.assign_lead so the timeline is written first.
--
-- Identical behaviour otherwise; only the two statements are swapped, so the guard in (2) sees the
-- history row that this same call is creating.
-- ---------------------------------------------------------------------------------------------
create or replace function app.assign_lead(
    p_lead_id uuid,
    p_assignee_user_id uuid,
    p_reason text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_branch uuid;
    v_department uuid;
    v_status text;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('ASSIGN_LEAD');

    select branch_id, department_id, lead_status_code
      into v_branch, v_department, v_status
    from public.leads
    where id = p_lead_id and tenant_id = v_tenant;
    if not found then
        raise exception 'lead is not in your tenant';
    end if;
    if v_status <> 'new' then
        raise exception 'lead is not in new status (use app.reassign_lead): %', v_status;
    end if;

    if not exists (
        select 1 from public.users
        where id = p_assignee_user_id and tenant_id = v_tenant and is_active
    ) then
        raise exception 'assignee is not an active user in your tenant';
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    insert into public.lead_assignments (
        tenant_id, lead_id, assigned_user_id, assigned_by, assignment_reason, is_current
    )
    values (v_tenant, p_lead_id, p_assignee_user_id, v_actor, p_reason, true);

    update public.leads
    set assigned_user_id = p_assignee_user_id,
        lead_status_code = 'assigned',
        owner_user_id = p_assignee_user_id,
        owner_branch_id = v_branch,
        owner_department_id = v_department
    where id = p_lead_id;

    perform app.record_event(
        v_tenant, 'lead_assigned', 'lead', p_lead_id, v_actor, 'new', 'assigned', p_reason,
        jsonb_build_object('assigned_user_id', p_assignee_user_id)
    );

    return p_lead_id;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- 4. The reassignment path app.assign_lead has been pointing at since it was written.
--
-- Closes the outgoing responsibility rather than erasing it, which is the whole point: canon 04
-- requires the timeline to show the employee who received it, the handover, and the next employee.
-- Terminal leads are excluded -- reassigning a lost or converted lead would record responsibility
-- for work that cannot happen.
-- ---------------------------------------------------------------------------------------------
create or replace function app.reassign_lead(
    p_lead_id uuid,
    p_assignee_user_id uuid,
    p_reason text default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_branch uuid;
    v_department uuid;
    v_status text;
    v_previous uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('REASSIGN_LEAD');

    select branch_id, department_id, lead_status_code, assigned_user_id
      into v_branch, v_department, v_status, v_previous
    from public.leads
    where id = p_lead_id and tenant_id = v_tenant;
    if not found then
        raise exception 'lead is not in your tenant';
    end if;
    if v_status in ('won', 'converted', 'lost', 'spam', 'duplicate') then
        raise exception 'a lead in terminal status % cannot be reassigned', v_status;
    end if;
    if v_previous is null then
        raise exception 'lead has no current assignee (use app.assign_lead)';
    end if;
    if p_assignee_user_id = v_previous then
        raise exception 'lead is already assigned to that employee';
    end if;

    if not exists (
        select 1 from public.users
        where id = p_assignee_user_id and tenant_id = v_tenant and is_active
    ) then
        raise exception 'assignee is not an active user in your tenant';
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    update public.lead_assignments
    set is_current = false, unassigned_at = now()
    where lead_id = p_lead_id and tenant_id = v_tenant and is_current;

    insert into public.lead_assignments (
        tenant_id, lead_id, assigned_user_id, assigned_by, assignment_reason, is_current
    )
    values (v_tenant, p_lead_id, p_assignee_user_id, v_actor, p_reason, true);

    update public.leads
    set assigned_user_id = p_assignee_user_id,
        owner_user_id = p_assignee_user_id,
        owner_branch_id = v_branch,
        owner_department_id = v_department
    where id = p_lead_id;

    perform app.record_event(
        v_tenant, 'lead_reassigned', 'lead', p_lead_id, v_actor, v_status, v_status, p_reason,
        jsonb_build_object('from_user_id', v_previous, 'to_user_id', p_assignee_user_id)
    );

    return p_lead_id;
end;
$$;
revoke execute on function app.reassign_lead(uuid, uuid, text) from public;
grant execute on function app.reassign_lead(uuid, uuid, text) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- 5. The originating employee.
--
-- Canon 03 requires "which branch first registered a customer" and the schema carries
-- `first_registered_branch_id` for it. The owner's directive of 2026-08-24 §8 extends that to the
-- employee, and requires it be preserved permanently and never derived from the current assignee.
-- The symmetric column is added rather than a new mechanism invented, and frozen by trigger --
-- "permanently preserve" is not a property a nullable column has on its own.
-- ---------------------------------------------------------------------------------------------
alter table public.customers
    add column if not exists first_registered_user_id uuid;

alter table public.customers
    add constraint customers_first_registered_user_id_fkey
    foreign key (tenant_id, first_registered_user_id)
    references public.users (tenant_id, id) on delete restrict;

create or replace function app.freeze_first_registration()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    if old.first_registered_user_id is not null
       and new.first_registered_user_id is distinct from old.first_registered_user_id then
        raise exception 'first_registered_user_id records who first took this customer on and cannot be changed'
            using errcode = '42501';
    end if;
    if old.first_registered_branch_id is not null
       and new.first_registered_branch_id is distinct from old.first_registered_branch_id then
        raise exception 'first_registered_branch_id records where this customer was first registered and cannot be changed'
            using errcode = '42501';
    end if;
    return new;
end
$$;

create trigger customers_freeze_first_registration
    before update on public.customers
    for each row execute function app.freeze_first_registration();

-- `app.lead_origin` answers the owner's question directly and without a stored duplicate: the
-- earliest row in the timeline IS the first employee, and (1) and (2) above are what make that
-- derivation trustworthy. Storing it as well would create a second source of truth that could
-- disagree with the history it summarises.
create or replace function app.lead_origin(p_lead_id uuid)
returns table (
    first_user_id uuid,
    first_assigned_at timestamptz,
    current_user_id uuid,
    assignment_count integer
)
language sql
stable
security invoker
set search_path = ''
as $$
    select
        -- array_agg rather than min/max: Postgres defines no ordering aggregate for uuid, so
        -- `max(assigned_user_id)` does not exist. Ordering by the timestamp and taking the first
        -- element is also the more honest expression of the question -- "who was first" is a
        -- chronological fact, not an arithmetic one.
        (array_agg(la.assigned_user_id order by la.assigned_at))[1],
        min(la.assigned_at),
        (array_agg(la.assigned_user_id) filter (where la.is_current))[1],
        count(*)::int
    from public.lead_assignments la
    where la.lead_id = p_lead_id
      and la.tenant_id = app.current_tenant_id()
$$;
revoke execute on function app.lead_origin(uuid) from public;
grant execute on function app.lead_origin(uuid) to authenticated;

-- Trigger functions are invoked by their triggers, never called directly, so they need no
-- EXECUTE grant -- but they still inherit PUBLIC EXECUTE at creation and the SPEC-124 grant
-- model does not permit that. Caught by test 05/10 rather than by review.
revoke execute on function app.forbid_assignment_history_rewrite() from public;
revoke execute on function app.require_assignment_history() from public;
revoke execute on function app.freeze_first_registration() from public;
