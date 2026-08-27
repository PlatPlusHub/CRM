-- WP-02 / SPEC-153 -- the five Class A events: a real producer exists, the event was never emitted.
--
-- Re-introspected live before implementing (the previous candidate list was STALE -- it still named
-- customer_created / lead_created / passenger_created, which WP-01 closed). Corrected sweep unions
-- `pg_proc.prosrc` with `pg_get_triggerdef`, because WP-01 emits through trigger ARGUMENTS that never
-- appear as literals in any function body:
--
--   payment_allocation_created      <- app.record_payment writes payment_allocations, announces nothing
--   trusted_device_revoked          <- app.revoke_trusted_device emits nothing at all
--   trusted_device_reverified       <- app.record_trusted_device's UPDATE branch (WP-01's INSERT
--                                      trigger cannot see it)
--   document_superseded             <- app.add_document_version supersedes but only emits
--                                      document_version_created
--   user_branch_transfer_completed  <- app.assign_user_branch emits NOTHING, even though branch and
--                                      department placement is the basis of the whole isolation model
--
-- NOT emitted, deliberately: `user_branch_transfer_started`. `assign_user_branch` is a single
-- synchronous call and canon 26 defines no user-branch-transfer state machine, so firing _started and
-- _completed from one call would fabricate a two-phase process that does not exist (SPEC-153 Class B).
--
-- MECHANISM. Triggers, consistent with WP-01 and for the same reason: SEC-1 is open, so a direct
-- write must not create history-free state. `app.emit_creation_event` is REUSED unchanged for the one
-- genuine creation; it is deliberately NOT renamed, because renaming a function four live triggers
-- depend on buys nothing and risks a migration/compatibility problem for elegance alone. The
-- non-creation cases get their own neutral helper.

-- ---------------------------------------------------------------------------------------------
-- 1. Generic emitter for state CHANGES (as opposed to creations).
--    Records previous/new state from a named column when given one, so the timeline entry says what
--    actually changed rather than merely that something did.
-- ---------------------------------------------------------------------------------------------
create or replace function app.emit_entity_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_new    jsonb := to_jsonb(new);
    v_old    jsonb := to_jsonb(old);
    v_tenant uuid;
    v_prev   text;
    v_next   text;
begin
    -- `trusted_devices` keys on auth_user_id and carries no tenant_id, so the session is the only
    -- source there. Skip rather than raise when nothing resolves: these fire on authentication paths,
    -- and breaking a login to record an event would be a worse outcome than a missing entry.
    v_tenant := coalesce((v_new ->> 'tenant_id')::uuid, app.current_tenant_id());
    if v_tenant is null then
        return new;
    end if;

    if tg_argv[3] is not null then
        v_prev := v_old ->> tg_argv[3];
        v_next := v_new ->> tg_argv[3];
    end if;

    perform app.record_event(
        v_tenant,
        tg_argv[0],                      -- event_type_code
        tg_argv[1],                      -- entity_type
        (v_new ->> 'id')::uuid,
        null,                            -- actor: record_event derives it authoritatively (WP-00)
        v_prev,
        v_next,
        null,
        null,
        coalesce(tg_argv[2], 'info')
    );
    return new;
end;
$fn$;

revoke execute on function app.emit_entity_event() from public;

-- ---------------------------------------------------------------------------------------------
-- 2. `user_branch_transfer_completed` needs its own function: distinguishing a TRANSFER from a
--    first placement requires looking for a prior assignment, which a trigger WHEN clause cannot do.
--    Emitting on first placement would misreport an employee's initial posting as a transfer.
-- ---------------------------------------------------------------------------------------------
create or replace function app.emit_user_branch_transfer()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if exists (
        select 1 from public.user_branch_assignments prior
        where prior.tenant_id = new.tenant_id
          and prior.user_id   = new.user_id
          and prior.id       <> new.id
    ) then
        perform app.record_event(
            new.tenant_id,
            'user_branch_transfer_completed',
            'user',                       -- subject is the employee; `user` is already in the
            new.user_id,                  -- events read-policy dispatch
            null, null, null,
            new.transfer_type_code,
            jsonb_build_object('branch_id', new.branch_id, 'department_id', new.department_id),
            'info'
        );
    end if;
    return new;
end;
$fn$;

revoke execute on function app.emit_user_branch_transfer() from public;

-- ---------------------------------------------------------------------------------------------
-- 3. Attachments.
-- ---------------------------------------------------------------------------------------------
create trigger payment_allocations_emit_created
    after insert on public.payment_allocations
    for each row execute function app.emit_creation_event('payment_allocation_created', 'payment_allocation', 'info');

-- Revocation: only the null -> not-null transition is a revocation.
create trigger trusted_devices_emit_revoked
    after update on public.trusted_devices
    for each row
    when (old.revoked_at is null and new.revoked_at is not null)
    execute function app.emit_entity_event('trusted_device_revoked', 'trusted_device', 'security', 'status_code');

-- Re-verification: a device becoming trusted again. Deliberately NOT fired on an ordinary re-login
-- touch of an already-trusted device -- `record_trusted_device` updates last_seen_at every time, and
-- emitting there would spam the append-only spine exactly as an in-RPC creation event would have.
create trigger trusted_devices_emit_reverified
    after update on public.trusted_devices
    for each row
    when ((old.status_code is distinct from 'trusted' and new.status_code = 'trusted')
       or (old.revoked_at is not null and new.revoked_at is null))
    execute function app.emit_entity_event('trusted_device_reverified', 'trusted_device', 'security', 'status_code');

-- Supersession: the FIRST version moves current_version_id from null, which is not a supersession.
create trigger documents_emit_superseded
    after update on public.documents
    for each row
    when (old.current_version_id is not null
      and new.current_version_id is distinct from old.current_version_id)
    execute function app.emit_entity_event('document_superseded', 'document', 'info', 'current_version_id');

create trigger user_branch_assignments_emit_transfer
    after insert on public.user_branch_assignments
    for each row execute function app.emit_user_branch_transfer();

-- ---------------------------------------------------------------------------------------------
-- 4. Event VISIBILITY for the new payment_allocation subject.
--
--    Resolved from live evidence rather than assumed: `app.has_tenant_wide_read()` is
--    `has_permission('VIEW_ALL_BRANCHES')`, which only **ceo** and **owner** hold -- NOT
--    `finance_manager`. `payment_allocation` was absent from the dispatch below, so the new event
--    would have fallen to `ELSE false` and been invisible to Finance, the one role that most needs
--    it. Emitting it without this branch would have produced an event nobody who needs it can read.
--
--    The branch delegates to `payment_allocations`' own RLS -- which already reads
--    `tenant_id = current_tenant_id() AND (VIEW_FINANCIAL_DOCUMENTS OR the related invoice is
--    visible)` -- so this is SPEC-143's existing rule ("an event is readable exactly when its subject
--    is"), not a new boundary. It widens visibility only for `entity_type = 'payment_allocation'`,
--    and only to callers who can already read the allocation row itself, so the event discloses
--    nothing they could not already query. Every other entity_type keeps its current rule verbatim.
-- ---------------------------------------------------------------------------------------------
drop policy audit_read on public.events;

create policy audit_read on public.events
for select to authenticated
using (
    tenant_id = (select app.current_tenant_id())
    and (
        (select app.has_tenant_wide_read())
        or actor_user_id = (select app.current_user_id())
        or case entity_type
            when 'lead'               then exists (select 1 from public.leads x               where x.id = events.entity_id)
            when 'booking'            then exists (select 1 from public.bookings x            where x.id = events.entity_id)
            when 'booking_item'       then exists (select 1 from public.booking_items x       where x.id = events.entity_id)
            when 'quotation'          then exists (select 1 from public.quotations x          where x.id = events.entity_id)
            when 'conversation'       then exists (select 1 from public.conversations x       where x.id = events.entity_id)
            when 'complaint'          then exists (select 1 from public.complaints x          where x.id = events.entity_id)
            when 'service_request'    then exists (select 1 from public.service_requests x    where x.id = events.entity_id)
            when 'task'               then exists (select 1 from public.tasks x               where x.id = events.entity_id)
            when 'invoice'            then exists (select 1 from public.invoices x            where x.id = events.entity_id)
            when 'payment'            then exists (select 1 from public.payments x            where x.id = events.entity_id)
            when 'payment_allocation' then exists (select 1 from public.payment_allocations x where x.id = events.entity_id)
            when 'refund'             then exists (select 1 from public.refunds x             where x.id = events.entity_id)
            when 'receipt'            then exists (select 1 from public.receipts x            where x.id = events.entity_id)
            when 'journal_entry'      then exists (select 1 from public.journal_entries x     where x.id = events.entity_id)
            when 'customer'           then exists (select 1 from public.customers x           where x.id = events.entity_id)
            when 'passenger'          then exists (select 1 from public.passengers x          where x.id = events.entity_id)
            when 'supplier'           then exists (select 1 from public.suppliers x           where x.id = events.entity_id)
            when 'document'           then exists (select 1 from public.documents x           where x.id = events.entity_id)
            when 'marketing_campaign' then exists (select 1 from public.marketing_campaigns x where x.id = events.entity_id)
            when 'attribution_click'  then exists (select 1 from public.attribution_clicks x  where x.id = events.entity_id)
            when 'offline_conversion' then exists (select 1 from public.offline_conversions x where x.id = events.entity_id)
            when 'branch'             then exists (select 1 from public.branches x            where x.id = events.entity_id)
            when 'department'         then exists (select 1 from public.departments x         where x.id = events.entity_id)
            when 'user'               then exists (select 1 from public.users x               where x.id = events.entity_id)
            else false
        end
    )
);
