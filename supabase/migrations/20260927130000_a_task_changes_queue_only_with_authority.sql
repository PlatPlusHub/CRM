-- SPEC-230 / Batch 6 Slice 28 -- TASK-4: a task changes QUEUE only with authority.
--
-- TASK-1 (202607058600) made a change of hands cost ASSIGN_TASK at the table door, and measured one
-- column: `owner_user_id`. A task's accountable owner is a TRIPLE, `owner_user_id`,
-- `owner_department_id`, `owner_branch_id`, and the other two are what the read model supervises by:
-- `tasks.scope_isolation` shows a task to the department queue (VIEW_DEPARTMENT_TASK_QUEUE over
-- `owner_department_id`) and to the branch (VIEW_BRANCH_DATA over `owner_branch_id`). The only RPC
-- that moves them after creation, `app.assign_task`, charges ASSIGN_TASK.
--
-- REPRODUCED on a clean local reset at `3b4b5e4`, in a rolled-back transaction: an `employee`
-- (CREATE_TASK and COMPLETE_TASK, not ASSIGN_TASK) was refused `permission denied: ASSIGN_TASK` by
-- `app.assign_task` naming itself in another branch and department, and then moved the same kind of
-- task there by a direct UPDATE. Their department manager's view of it went from 1 row to 0 and the
-- other branch's manager gained it, with no event. RLS WITH CHECK still passed because the employee
-- remains the owner (VIEW_ASSIGNED_TASKS); it keeps a colleague's task in place, not one's own.
--
-- The repair widens TASK-1's own condition to the triple and changes nothing else: same function,
-- same trigger, same session-less exemption (authorization, canon 35 principle 6). Legal writers of
-- the two placement columns were enumerated first: `app.create_task` (INSERT only, so this BEFORE
-- UPDATE trigger never fires for it) and `app.assign_task`, which already authorizes ASSIGN_TASK, so
-- the trigger stays idempotent for it. No test or HTTP suite moves a placement without ASSIGN_TASK.
-- Editing, re-prioritising, starting and completing a task the caller owns stay under CREATE_TASK /
-- COMPLETE_TASK.

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
    -- TASK-4: the hands are the owner, its department and its branch, which is exactly the set
    -- `app.assign_task` moves and the queue `scope_isolation` supervises by.
    if (new.owner_user_id, new.owner_department_id, new.owner_branch_id)
       is distinct from (old.owner_user_id, old.owner_department_id, old.owner_branch_id) then
        perform app.authorize('ASSIGN_TASK');
    end if;

    return new;
end
$fn$;

comment on function app.guard_task_reassignment() is
    'TASK-1 / TASK-4: app.assign_task charges ASSIGN_TASK; the table door charged only CREATE_TASK. Fires when the owner, its department or its branch actually changes, so ordinary task work stays under CREATE_TASK and COMPLETE_TASK.';

revoke all on function app.guard_task_reassignment() from public;
