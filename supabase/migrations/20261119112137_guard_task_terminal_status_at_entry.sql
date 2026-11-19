-- ENTRY-1: task completion and cancellation must use the existing transition path.
create function app.guard_task_terminal_status_at_entry()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    raise exception using
        errcode = '23514',
        message = 'a task cannot be created in a terminal state';
end;
$fn$;

revoke all on function app.guard_task_terminal_status_at_entry() from public;

create trigger tasks_guard_terminal_status_at_entry
before insert on public.tasks
for each row
when (new.task_status_code in ('completed', 'cancelled'))
execute function app.guard_task_terminal_status_at_entry();
