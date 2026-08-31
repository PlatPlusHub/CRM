-- API-3, final family: assign_task, financial_documents, link_internal_supplier.
--
-- ================================================================================================
-- TASK-1 (High) -- an ordinary employee could reassign a task, and unaudited.
--
-- `app.assign_task` charges **ASSIGN_TASK** (branch_manager, ceo, department_manager, owner).
-- `public.tasks` is served by PostgREST with INSERT/SELECT/UPDATE to `authenticated`, and its
-- capability guard charges **CREATE_TASK** -- which `employee` and `senior_employee` also hold. The
-- two permissions are NOT the same role set, which is what makes this a real privilege gap rather
-- than the theoretical one ASSIGN_LEAD/REASSIGN_LEAD turned out to be.
--
-- REPRODUCED as an ordinary `employee`, in one transaction: `app.assign_task` refused with
-- **`permission denied: ASSIGN_TASK`**, and `update public.tasks set owner_user_id = <manager>`
-- returned **UPDATE 1**. The task changed hands, and `task_assigned` events for it numbered **0** --
-- the event comes from the RPC, so the table door is unaudited as well as unauthorized.
--
-- Enforcement layer: a BEFORE UPDATE trigger charging ASSIGN_TASK *only when the owner actually
-- changes*. Chosen over widening `guard_write_capability`'s mapping because that guard fires on
-- every write to the table and cannot see WHICH column moved -- charging ASSIGN_TASK for every task
-- edit would stop an `employee` completing their own task, which `CREATE_TASK` legitimately allows.
-- The session-less path is exempt: this is AUTHORIZATION, and canon 35 principle 6 exempts platform
-- paths from authorization (LESSON 6's distinction -- integrity, below, gets no such exemption).
-- Legal writers of `tasks.owner_user_id` were enumerated first: `app.create_task` (INSERT only, so
-- this UPDATE trigger never fires for it) and `app.assign_task`, which already authorizes
-- ASSIGN_TASK, so the trigger is idempotent for it.
--
-- ================================================================================================
-- TASK-2 (Medium) -- assign_task carried a THIRD, narrower definition of "current placement".
--
-- PLACE-1 (202607058300) widened `app.current_placement()` to `(ends_at is null or ends_at > now())`
-- because a SCHEDULED transfer is still today's placement. `app.eligible_lead_handlers` already used
-- the full window. `app.assign_task` resolves the placement of an ARBITRARY user -- so neither helper
-- fits -- and inlines `uba.ends_at is null`, the narrowest of the three.
--
-- REPRODUCED with a wrong value, not merely a divergence: a CAIRO task assigned to staff whose
-- primary placement is GIZA with a transfer scheduled 30 days out. Expected `owner_branch_id` Giza;
-- actual **Cairo** -- the previous owner's branch, silently retained, because the lookup matched no
-- row. Measured beside it: that user's placement under the full window resolves to Giza; under
-- `assign_task`'s window it resolves to nothing.
--
-- Fixed with the SAME strictly-additive shape PLACE-1 used -- open-ended row preferred, so every
-- answer the old predicate produced is unchanged and only the empty case is filled.
--
-- ALSO CORRECTED, and flagged because it was NOT separately reproduced: the old statement computed
-- `coalesce(p_owner_branch_id, uba.branch_id)` INSIDE the SELECT, so when the owner had no matching
-- placement row the whole SELECT returned nothing and the caller's EXPLICIT `p_owner_branch_id` was
-- discarded with it. The coalesce now happens outside the lookup, which is evidently what the
-- parameter is for. This changes behaviour only in the no-placement case.
--
-- ================================================================================================
-- SUP-1 (Low) -- three of link_internal_supplier's rules were absent from the table door.
--
-- REPRODUCED, each as an `ASSIGN_SUPPLIER` holder whose RPC call had just been refused:
--   * provider pair -- RPC: "provider department does not belong to provider branch in your tenant";
--     direct INSERT of the same mismatched pair: **INSERT 0 1**.
--   * requester -- derived by the RPC from the item, accepted verbatim by the table (a link naming
--     Giza as requester for a Cairo item).
--   * lifecycle -- RPC: "cannot link a supplier to a cancelled booking item"; direct INSERT on the
--     same legally-cancelled item: **INSERT 0 1**.
--
-- SEVERITY IS LOW AND THE REASON IS MEASURED, NOT ASSUMED: `public.internal_supplier_links` has NO
-- consumer. Nothing reads it except `app.link_internal_supplier` itself and
-- `app.guard_write_capability` -- no view, no reporting surface, no other function. So a corrupt
-- fulfilment record misstates history and changes no behaviour today. It is fixed because the
-- history is the point of an append-only fulfilment log, and because a future consumer would inherit
-- the corruption silently.
--
-- Enforcement layer: one BEFORE INSERT OR UPDATE trigger carrying the RPC's rules verbatim
-- (BOOK-1's pattern), SECURITY DEFINER with a mandatory REVOKE for BOOK-1's reason -- under INVOKER
-- its reads of the parent item and booking would be RLS-filtered, leaving the guard blindest against
-- exactly the caller it must stop. **No session-less exemption**: this is integrity, not
-- authorization. A CHECK constraint cannot express any of the three -- each is a statement about
-- ANOTHER table (departments, booking_items, bookings).

-- ------------------------------------------------------------------------------------------------
-- TASK-1
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_task_reassignment()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    -- Platform/system paths (canon 35 principle 6). This is authorization, so the exemption is the
    -- same one every other capability guard here takes.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- Only a change of hands costs ASSIGN_TASK. Completing, re-prioritising or editing a task the
    -- caller already owns stays under CREATE_TASK, which is what `employee` legitimately holds.
    if new.owner_user_id is distinct from old.owner_user_id then
        perform app.authorize('ASSIGN_TASK');
    end if;

    return new;
end
$fn$;

comment on function app.guard_task_reassignment() is
    'TASK-1: app.assign_task charges ASSIGN_TASK; public.tasks charged only CREATE_TASK, which employee and senior_employee also hold. Reproduced: the RPC refused an employee and their direct UPDATE moved the owner anyway, emitting no task_assigned event. Fires only when owner_user_id actually changes, so ordinary task work stays under CREATE_TASK.';

revoke all on function app.guard_task_reassignment() from public;

create trigger tasks_guard_reassignment
    before update on public.tasks
    for each row execute function app.guard_task_reassignment();

-- ------------------------------------------------------------------------------------------------
-- TASK-2
-- ------------------------------------------------------------------------------------------------
create or replace function app.assign_task(
    p_task_id uuid,
    p_owner_user_id uuid,
    p_owner_department_id uuid default null,
    p_owner_branch_id uuid default null,
    p_reason text default null
)
returns void
language plpgsql
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_prev uuid;
    v_status text;
    v_pl_branch uuid;
    v_pl_dept uuid;
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

    -- TASK-2: a placement SCHEDULED to end is still today's placement (PLACE-1). Strictly additive:
    -- the open-ended row is preferred, so every answer the old predicate gave is unchanged.
    select uba.branch_id, uba.department_id
      into v_pl_branch, v_pl_dept
    from public.user_branch_assignments uba
    where uba.user_id = p_owner_user_id
      and uba.tenant_id = v_tenant
      and uba.is_primary
      and (uba.ends_at is null or uba.ends_at > now())
    order by (uba.ends_at is null) desc, uba.starts_at desc, uba.branch_id
    limit 1;

    -- The coalesce is OUTSIDE the lookup on purpose: inside it, an owner with no matching placement
    -- made the whole SELECT return nothing and discarded the caller's explicit parameter with it.
    v_branch := coalesce(p_owner_branch_id, v_pl_branch);
    v_dept   := coalesce(p_owner_department_id, v_pl_dept);

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
$fn$;

-- ------------------------------------------------------------------------------------------------
-- SUP-1
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_internal_supplier_link()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_item record;
begin
    -- Provider org unit must be a department WITHIN the named branch, in this tenant. The composite
    -- FKs prove each id exists in the tenant; neither proves the department is in that branch.
    if not exists (
        select 1 from public.departments d
        where d.id = new.provider_department_id
          and d.branch_id = new.provider_branch_id
          and d.tenant_id = new.tenant_id
    ) then
        raise exception 'provider department does not belong to provider branch in your tenant'
            using errcode = '23514';
    end if;

    select bi.base_status_code, bi.is_archived,
           bi.owner_branch_id, bi.owner_department_id,
           b.branch_id as booking_branch_id, b.department_id as booking_department_id,
           b.booking_status_code, b.is_archived as booking_archived
      into v_item
    from public.booking_items bi
    join public.bookings b on b.id = bi.booking_id and b.tenant_id = new.tenant_id
    where bi.id = new.booking_item_id and bi.tenant_id = new.tenant_id;

    if not found then
        return new;   -- the composite FK is the authority on existence; do not duplicate it here
    end if;

    if v_item.is_archived or v_item.base_status_code in ('cancelled', 'no_show') then
        raise exception 'cannot link a supplier to a % booking item', v_item.base_status_code
            using errcode = '23514';
    end if;
    if v_item.booking_archived or v_item.booking_status_code in ('completed', 'cancelled') then
        raise exception 'cannot link a supplier to an item on a % booking', v_item.booking_status_code
            using errcode = '23514';
    end if;

    -- Derived, not accepted: the requester IS the item's owning org unit. Whatever the caller sent
    -- is discarded, which is the security property (SPEC-155's shape).
    new.requester_branch_id     := coalesce(v_item.owner_branch_id, v_item.booking_branch_id);
    new.requester_department_id := coalesce(v_item.owner_department_id, v_item.booking_department_id);

    return new;
end
$fn$;

comment on function app.guard_internal_supplier_link() is
    'SUP-1: app.link_internal_supplier validates the provider pair, derives the requester and refuses cancelled items; the table door enforced none of the three and all three were reproduced by direct DML. SECURITY DEFINER because under INVOKER the parent reads would be RLS-filtered (BOOK-1). No session-less exemption: integrity, not authorization.';

revoke all on function app.guard_internal_supplier_link() from public;

create trigger internal_supplier_links_guard_integrity
    before insert or update on public.internal_supplier_links
    for each row execute function app.guard_internal_supplier_link();
