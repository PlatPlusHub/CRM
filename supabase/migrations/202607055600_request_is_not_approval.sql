-- Phase C -- FIN-2 and TASK-1. Two capabilities that were dead for the roles they exist for.
--
-- Both were found the same way: by walking the journey branches an agency actually spends its day
-- on, over HTTP, as a real employee. Neither was visible to 612 passing pgTAP assertions, because
-- no test had ever asked a frontline employee to *request* an approval or to *start* a task.
--
-- ================================================================================================
-- FIN-2 -- AN EMPLOYEE COULD NOT REQUEST FINANCE APPROVAL, BECAUSE REQUESTING WAS TREATED AS
--          APPROVING. The entire finance-approval workflow was unusable by the only role that
--          needs it.
--
-- The two halves disagreed, and each looked right on its own:
--
--   app.request_finance_approval  ->  perform app.authorize('CREATE_BOOKING_ITEM')
--       Correct. The requester is the salesperson who wants a discount signed off.
--
--   app.guard_booking_item_financials (trigger on booking_items)
--       if new.finance_approval_status_code is distinct from old.finance_approval_status_code
--           then perform app.authorize('APPROVE_FINANCE');
--
-- ...and `request_finance_approval` sets `finance_approval_status_code = 'pending'`. So the RPC
-- charged the salesperson's permission and the trigger immediately charged the approver's. Live
-- result over HTTP, as an employee holding CREATE_BOOKING_ITEM:
--
--     403  permission denied: APPROVE_FINANCE
--
-- Only a holder of APPROVE_FINANCE could open a request -- that is, only the approver could ask
-- themselves for approval. `APPROVE_FINANCE` is held by ceo, finance_manager and owner; the
-- employee and senior_employee who raise discounts hold none of it.
--
-- ROOT CAUSE: the guard treated `finance_approval_status_code` as one privileged column when it
-- carries two different acts.
--
--     null / rejected / cancelled  ->  pending      REQUESTING   (the salesperson's act)
--     pending  ->  approved / rejected / cancelled  DECIDING     (finance's act)
--
-- A control that cannot tell a request from a decision must refuse both, and it did.
--
-- THE FIX keeps the guard's job intact and teaches it the distinction. Requesting now costs exactly
-- what the RPC always said it costs -- CREATE_BOOKING_ITEM, plus the same assignment scope every
-- other financial edit on this table already requires, so an employee still cannot open a request
-- against a colleague's item. Deciding still costs APPROVE_FINANCE. `cost_locked_at` is untouched
-- and remains an approver-only act.
--
-- ================================================================================================
-- TASK-1 -- AN EMPLOYEE COULD CREATE A TASK AND COMPLETE A TASK, BUT NOT START ONE.
--
-- `app.advance_task` maps each transition to a permission:
--
--     open        -> in_progress   'task_assigned'   ASSIGN_TASK      <-- managers only
--     open        -> completed     'task_completed'  COMPLETE_TASK
--     in_progress -> completed     'task_completed'  COMPLETE_TASK
--     overdue     -> in_progress   'task_assigned'   ASSIGN_TASK      <-- managers only
--
-- ASSIGN_TASK is held by branch_manager, department_manager, ceo and owner. COMPLETE_TASK is
-- additionally held by employee and senior_employee. So the frontline could open a follow-up and
-- close it, and could not mark it as being worked on -- which makes `in_progress` unreachable for
-- the people whose work it describes, and quietly turns the task board into a two-state system.
--
-- ROOT CAUSE: starting a task was conflated with assigning one. They are different acts with
-- different actors -- `app.assign_task` already exists and is where ASSIGN_TASK belongs. Moving a
-- task you already hold into `in_progress` is working it, which is what COMPLETE_TASK governs
-- everywhere else in this same table.
--
-- NOT FIXED HERE, AND RECORDED INSTEAD (TASK-2): both start transitions still emit `task_assigned`,
-- so the audit trail will say "assigned" when nothing was assigned. The honest repair is a
-- `task_started` event type, and the event vocabulary is closed and canon-owned (canon 26 owns the
-- state machines, `202607049100` enforces the registry). Adding a code to make a transition read
-- correctly is a vocabulary decision, not a permission bug, so it is registered in
-- MASTER_GAP_REGISTER.md rather than invented here.
-- ================================================================================================

create or replace function app.guard_booking_item_financials()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_scoped boolean;
begin
    if (select auth.uid()) is null then
        return new;
    end if;

    v_scoped := app.is_my_booking_item(new.owner_user_id, new.sales_owner_user_id,
                                       new.operational_owner_user_id)
                or app.has_tenant_wide_read();

    if tg_op = 'INSERT' then
        if coalesce(new.cost_amount, 0) <> 0 then
            perform app.authorize('ENTER_COST');
            if not v_scoped then
                raise exception 'ENTER_COST is scoped to items assigned to you (canon 28: assigned)'
                    using errcode = 'insufficient_privilege';
            end if;
        end if;
        -- SPEC-155: `commission_rate` removed from this condition. It is system-derived, so there is
        -- no caller value to authorize -- and leaving it here would demand ENTER_SELLING_PRICE for
        -- every bare item, since the derive trigger now sets it on every INSERT.
        if coalesce(new.selling_amount, 0) <> 0 then
            perform app.authorize('ENTER_SELLING_PRICE');
            if not v_scoped then
                raise exception 'ENTER_SELLING_PRICE is scoped to items assigned to you (canon 28: assigned)'
                    using errcode = 'insufficient_privilege';
            end if;
        end if;
        if new.cost_locked_at is not null then
            perform app.authorize('APPROVE_FINANCE');
        end if;
        -- FIN-2: an item may be BORN carrying a request. That is the salesperson opening one, not
        -- finance granting one, so it costs the salesperson's permission and their scope. Any other
        -- starting value is a decision recorded at insert time, which only finance may do.
        if new.finance_approval_status_code is not null then
            if new.finance_approval_status_code = 'pending' then
                perform app.authorize('CREATE_BOOKING_ITEM');
                if not v_scoped then
                    raise exception
                        'a finance approval request is scoped to items assigned to you (canon 28: assigned)'
                        using errcode = 'insufficient_privilege';
                end if;
            else
                perform app.authorize('APPROVE_FINANCE');
            end if;
        end if;
        return new;
    end if;

    if new.cost_amount is distinct from old.cost_amount then
        if old.cost_locked_at is not null then
            perform app.authorize('EDIT_LOCKED_COST');
        else
            perform app.authorize('ENTER_COST');
            if not v_scoped then
                raise exception 'ENTER_COST is scoped to items assigned to you (canon 28: assigned)'
                    using errcode = 'insufficient_privilege';
            end if;
        end if;
    end if;

    -- SPEC-155: commission_rate dropped here too; the derive trigger guarantees new = old.
    if new.selling_amount is distinct from old.selling_amount then
        perform app.authorize('ENTER_SELLING_PRICE');
        if not v_scoped then
            raise exception 'ENTER_SELLING_PRICE is scoped to items assigned to you (canon 28: assigned)'
                using errcode = 'insufficient_privilege';
        end if;
    end if;

    -- Locking a cost is, and stays, an approver-only act. It is not a request anybody can raise.
    if new.cost_locked_at is distinct from old.cost_locked_at then
        perform app.authorize('APPROVE_FINANCE');
    end if;

    -- FIN-2, the heart of it. REQUESTING is not APPROVING.
    if new.finance_approval_status_code is distinct from old.finance_approval_status_code then
        if new.finance_approval_status_code = 'pending' then
            perform app.authorize('CREATE_BOOKING_ITEM');
            if not v_scoped then
                raise exception
                    'a finance approval request is scoped to items assigned to you (canon 28: assigned)'
                    using errcode = 'insufficient_privilege';
            end if;
        else
            perform app.authorize('APPROVE_FINANCE');
        end if;
    end if;

    return new;
end
$fn$;

-- ---------------------------------------------------------------------------------------------
-- TASK-1. Only the two `-> in_progress` rows change; every other transition keeps the permission
-- it already had. The event codes are left exactly as they were -- see TASK-2 in the gap register.
-- ---------------------------------------------------------------------------------------------
create or replace function app.advance_task(p_task_id uuid, p_to_status text, p_reason text default null)
returns void
language plpgsql
set search_path = ''
as $fn$
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
        -- TASK-1: the ONLY change in this function is the permission on the two `-> in_progress`
        -- rows, from ASSIGN_TASK to COMPLETE_TASK. Starting a task is WORKING it, not assigning it;
        -- `app.assign_task` is where ASSIGN_TASK belongs. Everything else below -- the tenant
        -- predicates, the error text, the event codes, the completed_at rule -- is byte-for-byte
        -- what was there before, because a permission fix has no business quietly editing anything
        -- else. (My first draft of this migration rewrote the function from a fragment and dropped
        -- `and tenant_id = v_tenant` from the UPDATE. Caught by diffing against the live definition
        -- before it ever ran.)
        ('open',        'in_progress', 'task_assigned',  'COMPLETE_TASK'),
        ('open',        'completed',   'task_completed', 'COMPLETE_TASK'),
        ('open',        'cancelled',   'task_cancelled', 'COMPLETE_TASK'),
        ('in_progress', 'completed',   'task_completed', 'COMPLETE_TASK'),
        ('in_progress', 'cancelled',   'task_cancelled', 'COMPLETE_TASK'),
        ('overdue',     'in_progress', 'task_assigned',  'COMPLETE_TASK'),
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
$fn$;

revoke execute on function app.advance_task(uuid, text, text) from public;
grant  execute on function app.advance_task(uuid, text, text) to authenticated;

-- ================================================================================================
-- TASK-1, THE OTHER HALF -- and the reason this migration nearly shipped a live drift.
--
-- Changing `app.advance_task` above did NOT fix the defect. The employee still got
-- `permission denied: ASSIGN_TASK` over HTTP, because the transition rules live in TWO places:
--
--   1. an inline VALUES list inside `app.advance_task`   -- carries (from, to, EVENT, permission)
--   2. `app.status_transitions`                          -- carries (table, from, to, permission)
--      ...consulted by `app.enforce_status_transition`, the BEFORE UPDATE trigger on every
--      status-bearing table, which is what actually refused the write.
--
-- The trigger is the real boundary: it fires on the RPC path AND on direct DML, so it is the
-- authoritative source and the function's copy is a duplicate. Fixing only the copy left the two
-- disagreeing -- a drift I introduced and then found by diffing all nine `advance_*` functions
-- against the table. That diff is now a permanent test (`54_transition_permission_parity_test.sql`),
-- because a duplicated rule that nothing compares is a rule that will drift again.
--
-- Both rows are corrected here. The function keeps its inline copy because it also carries the
-- EVENT code, which `app.status_transitions` has no column for; de-duplicating properly means
-- giving that table an event column and is recorded as TRANS-1 rather than done in passing.
-- ================================================================================================
update app.status_transitions
   set permission_key = 'COMPLETE_TASK'
 where table_name = 'tasks'
   and to_status = 'in_progress'
   and permission_key = 'ASSIGN_TASK';
