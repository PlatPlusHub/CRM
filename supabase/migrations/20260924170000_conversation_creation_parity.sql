-- SPEC-220: conversation creation has one initial state, owner and start event on both doors.
create or replace function app.guard_conversation_creation()
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
    if new.conversation_status_code is distinct from 'open' or new.closed_at is not null then
        raise exception 'conversation must begin open and not closed' using errcode = '23514';
    end if;

    if (select auth.uid()) is null then
        return new;
    end if;

    v_actor := app.current_user_id();
    select cp.branch_id, cp.department_id into v_branch, v_dept from app.current_placement() cp;
    if v_actor is null or v_branch is null then
        raise exception 'conversation creator needs an active user and primary branch assignment'
            using errcode = '42501';
    end if;

    new.owner_user_id := v_actor;
    new.owner_branch_id := v_branch;
    new.owner_department_id := v_dept;
    new.current_branch_id := v_branch;
    new.current_department_id := v_dept;
    return new;
end;
$$;
revoke execute on function app.guard_conversation_creation() from public;

create trigger conversations_guard_creation
before insert on public.conversations
for each row execute function app.guard_conversation_creation();

create or replace function app.emit_conversation_started()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
    perform app.record_event(
        new.tenant_id, 'conversation_started', 'conversation', new.id,
        case when (select auth.uid()) is null then null else app.current_user_id() end,
        null, 'open', null,
        jsonb_build_object('channel_code', new.channel_code, 'customer_id', new.customer_id,
                           'lead_id', new.lead_id, 'booking_id', new.booking_id),
        'info');
    return new;
end;
$$;
revoke execute on function app.emit_conversation_started() from public;

create trigger conversations_emit_started
after insert on public.conversations
for each row execute function app.emit_conversation_started();

-- Preserve the complete current SECURITY INVOKER RPC, removing only its duplicate event call.
create or replace function app.start_conversation(
    p_channel_code text,
    p_customer_id uuid default null,
    p_lead_id uuid default null,
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
    v_branch uuid;
    v_dept uuid;
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;
    perform app.authorize('SEND_MESSAGE');

    if p_customer_id is not null and not exists (
        select 1 from public.customers where id = p_customer_id and tenant_id = v_tenant) then
        raise exception 'customer is not in your tenant'; end if;
    if p_lead_id is not null and not exists (
        select 1 from public.leads where id = p_lead_id and tenant_id = v_tenant) then
        raise exception 'lead is not in your tenant'; end if;
    if p_booking_id is not null and not exists (
        select 1 from public.bookings where id = p_booking_id and tenant_id = v_tenant) then
        raise exception 'booking is not in your tenant'; end if;

    select id into v_actor from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    select cp.branch_id, cp.department_id into v_branch, v_dept from app.current_placement() cp;
    if v_branch is null then
        raise exception 'you have no primary branch assignment; a conversation must be filed under a branch';
    end if;

    insert into public.conversations (
        tenant_id, channel_code, conversation_status_code,
        customer_id, lead_id, booking_id, booking_item_id,
        owner_user_id, owner_branch_id, owner_department_id,
        current_branch_id, current_department_id, started_at
    ) values (
        v_tenant, p_channel_code, 'open',
        p_customer_id, p_lead_id, p_booking_id, p_booking_item_id,
        v_actor, v_branch, v_dept, v_branch, v_dept, now()
    ) returning id into v_id;

    return v_id;
end;
$$;
