-- SPEC-257 (Batch 6 Slice 35): a service request begins `requested`, unresolved and unarchived,
-- owned and filed by whoever opens it, and every move of its life is recorded once -- through the
-- table door exactly as through `app.create_service_request` and `app.advance_service_request`.
--
-- `authenticated` holds table-level INSERT and UPDATE on `public.service_requests`, and both RPCs are
-- SECURITY INVOKER through that same grant, so PostgREST serves the table beside them. Measured at
-- `3af104b` on the local stack in rolled-back transactions, by an `employee` proven first to hold
-- CREATE_SERVICE_REQUEST and RESOLVE_SERVICE_REQUEST and not ARCHIVE_RECORD:
--   * ENTRY-1: a direct INSERT created a request `closed` with `resolved_at` 2020-01-01. The RPC
--     writes only `requested` (canon 26's first state) and stamps `resolved_at` only on `resolved`.
--   * ARCH-2: a direct INSERT created a request already archived, naming a colleague as
--     `archived_by` with a forged reason. No RPC creates a service request archived; archiving is
--     the UPDATE `app.enforce_archive_authority` charges ARCHIVE_RECORD for.
--   * SR-1: a direct INSERT naming a colleague in another branch as owner persisted, and that
--     colleague then read the row through owner-based RLS. The RPC derives the owner and the filing
--     branch and department from the caller's session and placement.
--   * SR-1: none of those rows emitted `service_request_created`; the RPC emits one.
--   * SR-1: after a legitimate RPC creation, a direct UPDATE moved the owner to a colleague in another
--     branch, or the filing scope to another branch, and that branch then read the request; a
--     same-department colleague took a request over the same way. No RPC moves a service request's
--     owner or filing scope, and canon 28 defines no reassignment act or permission for one.
--   * SR-2: a legal direct UPDATE walked a request `requested -> in_progress -> resolved -> closed`
--     with no transition event and `resolved_at` forged to 2001-01-01; a later UPDATE rewrote
--     `resolved_at` alone. Canon 26 requires every transition's event. `app.advance_service_request`
--     reopened `closed -> in_progress` with a null reason and severity `info`, where canon 26 and 27
--     require a reason and canon 27 makes `service_request_reopened` a warning. The table accepted a
--     blank title, which the RPC refuses.
--
-- THE SHAPE is SPEC-220's conversation guard (`20260924170000`), deliberately: SECURITY INVOKER,
-- the entry state binds every caller, and only a signed-in caller's owner and filing scope are
-- derived, so session-less platform writes keep their nullable owner. Its UPDATE arm is SPEC-216's
-- document rule (`20260924140000`): what no sanctioned writer ever changes, a signed-in caller cannot
-- change at the table either, and what the sanctioned writer stamps, the server stamps. Session-less
-- platform writes keep their latitude (canon 35 principle 6), which is where a historical import
-- would carry an earlier resolution time. Each event has one AFTER producer and its RPC loses its own
-- `record_event`, so no act is recorded twice; the transition reason reaches the producer through
-- SPEC-237's transaction-local `app.transition_reason` (`20260928160000`), which it consumes.
--
-- NOT CHANGED: every grant, policy, other trigger, permission charge and state transition, and the
-- reason and payload each event already carried.
create or replace function app.guard_service_request_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_actor uuid;
    v_branch uuid;
    v_dept uuid;
begin
    if nullif(btrim(new.title), '') is null then
        raise exception 'a service request needs a title' using errcode = '23514';
    end if;

    if tg_op = 'UPDATE' then
        if (select auth.uid()) is null then
            return new;
        end if;
        if (new.owner_user_id, new.owner_branch_id, new.owner_department_id)
           is distinct from (old.owner_user_id, old.owner_branch_id, old.owner_department_id) then
            raise exception 'a service request keeps the owner and filing scope it was created with; no act reassigns it'
                using errcode = '23514';
        end if;
        if old.service_request_status_code = 'closed' and new.service_request_status_code = 'in_progress'
           and nullif(btrim(current_setting('app.transition_reason', true)), '') is null then
            raise exception 'a closed service request is reopened with a reason (canon 26, 27); use app.advance_service_request with p_reason'
                using errcode = '23514';
        end if;
        new.resolved_at := case
            when new.service_request_status_code = 'resolved'
                 and old.service_request_status_code is distinct from 'resolved' then now()
            else old.resolved_at end;
        return new;
    end if;

    if new.service_request_status_code is distinct from 'requested' or new.resolved_at is not null then
        raise exception 'a service request is created requested and unresolved (canon 26); advance it with app.advance_service_request'
            using errcode = '23514';
    end if;
    if new.is_archived or new.archived_at is not null or new.archived_by is not null
       or new.archive_reason is not null then
        raise exception 'a service request is created unarchived; archiving is an update that requires ARCHIVE_RECORD'
            using errcode = '23514';
    end if;

    if (select auth.uid()) is null then
        return new;
    end if;

    v_actor := app.current_user_id();
    select cp.branch_id, cp.department_id into v_branch, v_dept from app.current_placement() cp;
    if v_actor is null or v_branch is null then
        raise exception 'a service request creator needs an active user and a primary branch assignment'
            using errcode = '42501';
    end if;

    new.owner_user_id := v_actor;
    new.owner_branch_id := v_branch;
    new.owner_department_id := v_dept;
    return new;
end;
$$;
revoke execute on function app.guard_service_request_integrity() from public;

create trigger service_requests_guard_integrity
before insert or update on public.service_requests
for each row execute function app.guard_service_request_integrity();

create or replace function app.emit_service_request_created()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    perform app.record_event(
        new.tenant_id, 'service_request_created', 'service_request', new.id,
        case when (select auth.uid()) is null then null else app.current_user_id() end,
        null, 'requested', null,
        jsonb_build_object('customer_id', new.customer_id,
                           'service_request_type_code', new.service_request_type_code),
        'info');
    return new;
end;
$$;
revoke execute on function app.emit_service_request_created() from public;

create trigger service_requests_emit_created
after insert on public.service_requests
for each row execute function app.emit_service_request_created();

-- Canon 26's events, keyed by the state entered; entering `in_progress` from `closed` is the reopen.
create or replace function app.emit_service_request_transition()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_reason text := nullif(current_setting('app.transition_reason', true), '');
    v_reopen boolean := old.service_request_status_code = 'closed'
                        and new.service_request_status_code = 'in_progress';
    v_event text;
begin
    -- Consumed: a later transition in the same transaction carries only its own reason.
    perform set_config('app.transition_reason', '', true);
    v_event := case
        when v_reopen then 'service_request_reopened'
        else case new.service_request_status_code
            when 'in_progress' then 'service_request_in_progress'
            when 'awaiting_customer' then 'service_request_awaiting_customer'
            when 'awaiting_supplier' then 'service_request_awaiting_supplier'
            when 'resolved' then 'service_request_resolved'
            when 'closed' then 'service_request_closed'
        end
    end;
    if v_event is null then
        return null;
    end if;
    perform app.record_event(
        new.tenant_id, v_event, 'service_request', new.id,
        case when (select auth.uid()) is null then null else app.current_user_id() end,
        old.service_request_status_code, new.service_request_status_code, v_reason, null,
        case when v_reopen then 'warning' else 'info' end);
    return null;
end;
$$;
revoke execute on function app.emit_service_request_transition() from public;

create trigger service_requests_emit_transition
after update of service_request_status_code on public.service_requests
for each row
when (new.service_request_status_code is distinct from old.service_request_status_code)
execute function app.emit_service_request_transition();

-- The complete current SECURITY INVOKER RPC (`202607051500`), removing only its event call.
create or replace function app.create_service_request(
    p_customer_id uuid,
    p_title text,
    p_service_request_type_code text,
    p_service_request_severity_code text default 'normal',
    p_description text default null,
    p_booking_id uuid default null,
    p_booking_item_id uuid default null
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
    v_title text := nullif(btrim(p_title), '');
    v_branch uuid;
    v_dept uuid;
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;
    perform app.authorize('CREATE_SERVICE_REQUEST');
    if v_title is null then raise exception 'title is required'; end if;

    if not exists (select 1 from public.customers where id = p_customer_id and tenant_id = v_tenant) then
        raise exception 'customer is not in your tenant'; end if;
    if p_booking_id is not null and not exists (
        select 1 from public.bookings where id = p_booking_id and tenant_id = v_tenant) then
        raise exception 'booking is not in your tenant'; end if;
    if p_booking_item_id is not null and not exists (
        select 1 from public.booking_items where id = p_booking_item_id and tenant_id = v_tenant) then
        raise exception 'booking item is not in your tenant'; end if;

    select id into v_actor from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    select cp.branch_id, cp.department_id into v_branch, v_dept from app.current_placement() cp;
    if v_branch is null then
        raise exception 'you have no primary branch assignment; a service request must be filed under a branch';
    end if;

    insert into public.service_requests (
        tenant_id, customer_id, booking_id, booking_item_id,
        owner_user_id, owner_branch_id, owner_department_id,
        service_request_type_code, service_request_severity_code, service_request_status_code,
        title, description, created_by
    ) values (
        v_tenant, p_customer_id, p_booking_id, p_booking_item_id,
        v_actor, v_branch, v_dept,
        p_service_request_type_code, p_service_request_severity_code, 'requested',
        v_title, nullif(btrim(p_description), ''), v_actor
    ) returning id into v_id;

    return v_id;
end;
$$;

-- The complete current SECURITY INVOKER RPC (`202607050900`): its event call is replaced by handing
-- the caller's reason to `service_requests_emit_transition`, and the actor it looked up only for that
-- call goes with it.
create or replace function app.advance_service_request(
    p_service_request_id uuid,
    p_to_status text,
    p_reason text default null
)
returns void
language plpgsql
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_status text;
    v_event text;
    v_perm text;
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;

    select service_request_status_code into v_status
    from public.service_requests where id = p_service_request_id and tenant_id = v_tenant;
    if v_status is null then raise exception 'service request not found in your tenant'; end if;

    -- 26_state_machines.md, Service Request State Machine.
    select t.ev, t.perm into v_event, v_perm
    from (values
        ('requested',         'in_progress',       'service_request_in_progress',       'RESOLVE_SERVICE_REQUEST'),
        ('in_progress',       'awaiting_customer', 'service_request_awaiting_customer', 'RESOLVE_SERVICE_REQUEST'),
        ('in_progress',       'awaiting_supplier', 'service_request_awaiting_supplier', 'RESOLVE_SERVICE_REQUEST'),
        ('awaiting_customer', 'in_progress',       'service_request_in_progress',       'RESOLVE_SERVICE_REQUEST'),
        ('awaiting_supplier', 'in_progress',       'service_request_in_progress',       'RESOLVE_SERVICE_REQUEST'),
        ('in_progress',       'resolved',          'service_request_resolved',          'RESOLVE_SERVICE_REQUEST'),
        ('resolved',          'closed',            'service_request_closed',            'RESOLVE_SERVICE_REQUEST'),
        ('closed',            'in_progress',       'service_request_reopened',          'RESOLVE_SERVICE_REQUEST')
    ) as t(frm, to_s, ev, perm)
    where t.frm = v_status and t.to_s = p_to_status;

    if v_event is null then
        raise exception 'invalid service request transition % -> %', v_status, p_to_status; end if;
    perform app.authorize(v_perm);

    perform set_config('app.transition_reason', coalesce(p_reason, ''), true);

    update public.service_requests
    set service_request_status_code = p_to_status,
        resolved_at = case when p_to_status = 'resolved' then now() else resolved_at end,
        updated_at = now()
    where id = p_service_request_id and tenant_id = v_tenant;
end;
$$;
