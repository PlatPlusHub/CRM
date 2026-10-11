-- SPEC-262 (Batch 6 Slice 39): a complaint begins `new`, unresolved, unclosed and unarchived, owned
-- and filed by whoever opens it, and every move of its life is recorded once -- through the table
-- door exactly as through `app.create_complaint` and `app.advance_complaint`.
--
-- `authenticated` holds table-level INSERT and UPDATE on `public.complaints`, and both RPCs are
-- SECURITY INVOKER through that same grant, so PostgREST serves the table beside them. Measured at
-- `88bc20a` on the local stack in rolled-back transactions, by an `employee` proven first to hold
-- CREATE_COMPLAINT and RESOLVE_COMPLAINT and not ARCHIVE_RECORD:
--   * ENTRY-1: a direct INSERT created a complaint `closed`, with `resolved_at` 2020-01-01, `closed_at`
--     2020-01-02 and a forged `resolution_notes`. The RPC writes only `new` (canon 26's first state)
--     and writes none of the three.
--   * ARCH-2: a direct INSERT created a complaint already archived, naming a colleague as
--     `archived_by` with a forged reason. No RPC creates a complaint archived; archiving is the
--     UPDATE `app.enforce_archive_authority` charges ARCHIVE_RECORD for.
--   * COMP-2: a direct INSERT naming a colleague in another branch as owner, or filed under another
--     branch, persisted, and that colleague then read both rows. The RPC derives the owner and the
--     filing branch and department from the caller's session and placement; an employee with no
--     primary branch, whom the RPC refuses, created one directly. None of those rows emitted
--     `complaint_created`; the RPC emits one, at `info` where canon 27 makes it a warning.
--   * COMP-2: after a legitimate RPC creation, a direct UPDATE moved the owner to a colleague in
--     another branch. No RPC moves a complaint's owner or filing scope, and canon 28 defines no
--     reassignment act or permission for one. The table accepted a blank title, which the RPC refuses.
--   * COMP-3: a legal direct UPDATE walked a complaint `new -> acknowledged -> in_progress -> resolved
--     -> closed` with no transition event, `resolved_at` forged to 2001-01-01, `closed_at` to
--     2001-02-02 and its resolution note forged; a later UPDATE rewrote `resolved_at` and the
--     resolution note alone. A direct reopen kept the stale `closed_at`. Canon 26 requires every
--     transition's event. `app.advance_complaint` reopened `closed -> in_progress` with a null reason
--     and severity `info`, where canon 26 and 27 require a reason and canon 27 makes
--     `complaint_reopened` a warning.
--
-- THE SHAPE is SPEC-257's service-request guard (`20261010120000`), deliberately: SECURITY INVOKER,
-- the entry state binds every caller, and only a signed-in caller's owner and filing scope are
-- derived, so session-less platform writes keep their nullable owner. Its UPDATE arm is SPEC-216's
-- document rule: what no sanctioned writer ever changes, a signed-in caller cannot change at the
-- table either, and what the sanctioned writer stamps, the server stamps -- here `resolved_at`,
-- `closed_at` and COMP-1's resolution note, which `app.advance_complaint` takes from the reason given
-- for resolving. Session-less platform writes keep their latitude (canon 35 principle 6). Each event
-- has one AFTER producer and its RPC loses its own `record_event`, so no act is recorded twice; the
-- transition reason reaches the guard and the producer through SPEC-237's transaction-local
-- `app.transition_reason` (`20260928160000`), which the producer consumes.
--
-- NOT CHANGED: every grant, policy, other trigger, permission charge and state transition, and the
-- reason and payload each event already carried.
create or replace function app.guard_complaint_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_actor uuid;
    v_branch uuid;
    v_dept uuid;
    v_reason text;
    v_entered boolean;
begin
    if nullif(btrim(new.title), '') is null then
        raise exception 'a complaint needs a title' using errcode = '23514';
    end if;

    if tg_op = 'UPDATE' then
        if (select auth.uid()) is null then
            return new;
        end if;
        if (new.owner_user_id, new.owner_branch_id, new.owner_department_id)
           is distinct from (old.owner_user_id, old.owner_branch_id, old.owner_department_id) then
            raise exception 'a complaint keeps the owner and filing scope it was created with; no act reassigns it'
                using errcode = '23514';
        end if;
        v_reason := nullif(btrim(current_setting('app.transition_reason', true)), '');
        if old.complaint_status_code = 'closed' and new.complaint_status_code = 'in_progress'
           and v_reason is null then
            raise exception 'a closed complaint is reopened with a reason (canon 26, 27); use app.advance_complaint with p_reason'
                using errcode = '23514';
        end if;
        v_entered := new.complaint_status_code is distinct from old.complaint_status_code;
        new.resolved_at := case
            when v_entered and new.complaint_status_code = 'resolved' then now()
            else old.resolved_at end;
        new.resolution_notes := case
            when v_entered and new.complaint_status_code = 'resolved' then coalesce(v_reason, old.resolution_notes)
            else old.resolution_notes end;
        new.closed_at := case
            when v_entered and new.complaint_status_code = 'closed' then now()
            when v_entered and new.complaint_status_code = 'in_progress' then null
            else old.closed_at end;
        return new;
    end if;

    if new.complaint_status_code is distinct from 'new' or new.resolved_at is not null
       or new.closed_at is not null or new.resolution_notes is not null then
        raise exception 'a complaint is created new, unresolved and unclosed (canon 26); advance it with app.advance_complaint'
            using errcode = '23514';
    end if;
    if new.is_archived or new.archived_at is not null or new.archived_by is not null
       or new.archive_reason is not null then
        raise exception 'a complaint is created unarchived; archiving is an update that requires ARCHIVE_RECORD'
            using errcode = '23514';
    end if;

    if (select auth.uid()) is null then
        return new;
    end if;

    v_actor := app.current_user_id();
    select cp.branch_id, cp.department_id into v_branch, v_dept from app.current_placement() cp;
    if v_actor is null or v_branch is null then
        raise exception 'a complaint creator needs an active user and a primary branch assignment'
            using errcode = '42501';
    end if;

    new.owner_user_id := v_actor;
    new.owner_branch_id := v_branch;
    new.owner_department_id := v_dept;
    return new;
end;
$$;
revoke execute on function app.guard_complaint_integrity() from public;

create trigger complaints_guard_integrity
before insert or update on public.complaints
for each row execute function app.guard_complaint_integrity();

create or replace function app.emit_complaint_created()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    perform app.record_event(
        new.tenant_id, 'complaint_created', 'complaint', new.id,
        case when (select auth.uid()) is null then null else app.current_user_id() end,
        null, 'new', null,
        jsonb_build_object('customer_id', new.customer_id,
                           'complaint_category_code', new.complaint_category_code,
                           'complaint_severity_code', new.complaint_severity_code),
        'warning');
    return new;
end;
$$;
revoke execute on function app.emit_complaint_created() from public;

create trigger complaints_emit_created
after insert on public.complaints
for each row execute function app.emit_complaint_created();

-- Canon 26's events, keyed by the state entered; entering `in_progress` from `closed` is the reopen.
create or replace function app.emit_complaint_transition()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_reason text := nullif(current_setting('app.transition_reason', true), '');
    v_reopen boolean := old.complaint_status_code = 'closed'
                        and new.complaint_status_code = 'in_progress';
    v_event text;
begin
    -- Consumed: a later transition in the same transaction carries only its own reason.
    perform set_config('app.transition_reason', '', true);
    v_event := case
        when v_reopen then 'complaint_reopened'
        else case new.complaint_status_code
            when 'acknowledged' then 'complaint_acknowledged'
            when 'in_progress' then 'complaint_in_progress'
            when 'awaiting_customer' then 'complaint_awaiting_customer'
            when 'awaiting_supplier' then 'complaint_awaiting_supplier'
            when 'resolved' then 'complaint_resolved'
            when 'closed' then 'complaint_closed'
        end
    end;
    if v_event is null then
        return null;
    end if;
    perform app.record_event(
        new.tenant_id, v_event, 'complaint', new.id,
        case when (select auth.uid()) is null then null else app.current_user_id() end,
        old.complaint_status_code, new.complaint_status_code, v_reason, null,
        case when v_reopen then 'warning' else 'info' end);
    return null;
end;
$$;
revoke execute on function app.emit_complaint_transition() from public;

create trigger complaints_emit_transition
after update of complaint_status_code on public.complaints
for each row
when (new.complaint_status_code is distinct from old.complaint_status_code)
execute function app.emit_complaint_transition();

-- The complete current SECURITY INVOKER RPC (`202607051500`), removing only its event call.
create or replace function app.create_complaint(
    p_customer_id uuid,
    p_title text,
    p_complaint_category_code text,
    p_complaint_severity_code text default 'normal',
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
    perform app.authorize('CREATE_COMPLAINT');
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
        raise exception 'you have no primary branch assignment; a complaint must be filed under a branch';
    end if;

    insert into public.complaints (
        tenant_id, customer_id, booking_id, booking_item_id,
        owner_user_id, owner_branch_id, owner_department_id,
        complaint_category_code, complaint_severity_code, complaint_status_code,
        title, description, created_by
    ) values (
        v_tenant, p_customer_id, p_booking_id, p_booking_item_id,
        v_actor, v_branch, v_dept,
        p_complaint_category_code, p_complaint_severity_code, 'new',
        v_title, nullif(btrim(p_description), ''), v_actor
    ) returning id into v_id;

    return v_id;
end;
$$;

-- The complete current SECURITY INVOKER RPC (`202607057000`): its event call is replaced by handing
-- the caller's reason to the guard and to `complaints_emit_transition`, and the actor it looked up
-- only for that call goes with it.
create or replace function app.advance_complaint(
    p_complaint_id uuid,
    p_to_status text,
    p_reason text default null
)
returns void
language plpgsql
set search_path = ''
as $function$
declare
    v_tenant uuid := app.current_tenant_id();
    v_status text;
    v_event text;
    v_perm text;
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;

    select complaint_status_code into v_status
    from public.complaints where id = p_complaint_id and tenant_id = v_tenant;
    if v_status is null then raise exception 'complaint not found in your tenant'; end if;

    -- 26_state_machines.md, Complaint State Machine.
    select t.ev, t.perm into v_event, v_perm
    from (values
        ('new',               'acknowledged',      'complaint_acknowledged',      'RESOLVE_COMPLAINT'),
        ('acknowledged',      'in_progress',       'complaint_in_progress',       'RESOLVE_COMPLAINT'),
        ('in_progress',       'awaiting_customer', 'complaint_awaiting_customer', 'RESOLVE_COMPLAINT'),
        ('in_progress',       'awaiting_supplier', 'complaint_awaiting_supplier', 'RESOLVE_COMPLAINT'),
        ('awaiting_customer', 'in_progress',       'complaint_in_progress',       'RESOLVE_COMPLAINT'),
        ('awaiting_supplier', 'in_progress',       'complaint_in_progress',       'RESOLVE_COMPLAINT'),
        ('in_progress',       'resolved',          'complaint_resolved',          'RESOLVE_COMPLAINT'),
        ('resolved',          'closed',            'complaint_closed',            'RESOLVE_COMPLAINT'),
        ('closed',            'in_progress',       'complaint_reopened',          'RESOLVE_COMPLAINT')
    ) as t(frm, to_s, ev, perm)
    where t.frm = v_status and t.to_s = p_to_status;

    if v_event is null then
        raise exception 'invalid complaint transition % -> %', v_status, p_to_status; end if;
    perform app.authorize(v_perm);

    perform set_config('app.transition_reason', coalesce(p_reason, ''), true);

    update public.complaints
    set complaint_status_code = p_to_status,
        resolved_at = case when p_to_status = 'resolved' then now() else resolved_at end,
        -- COMP-1: the reason given for RESOLVING is the resolution note. Only on this transition,
        -- and coalesced so an empty call does not erase what an earlier resolution recorded.
        resolution_notes = case when p_to_status = 'resolved'
                                then coalesce(nullif(btrim(p_reason), ''), resolution_notes)
                                else resolution_notes end,
        closed_at = case when p_to_status = 'closed' then now()
                         when p_to_status = 'in_progress' then null else closed_at end,
        updated_at = now()
    where id = p_complaint_id and tenant_id = v_tenant;
end;
$function$;
