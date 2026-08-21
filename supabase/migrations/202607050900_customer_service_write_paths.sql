-- Migration: customer_service_write_paths
-- Plan reference: SPEC-132. Second delivery of the RPC-1 programme — the customer-service domain.
--
-- Closes seven of the permissions that were enforced nowhere: SEND_MESSAGE, CLOSE_CONVERSATION,
-- ESCALATE_CONVERSATION, CREATE_COMPLAINT, RESOLVE_COMPLAINT, CREATE_SERVICE_REQUEST and
-- RESOLVE_SERVICE_REQUEST. Before this migration `conversations`, `conversation_messages`,
-- `complaints` and `service_requests` had no RPC at all, so a direct table write was the only way
-- to use them: no authorization, no lifecycle rule, no event.
--
-- Every state machine below is transcribed from 26_state_machines.md, not designed here. Where
-- canon and convenience differ, canon wins — three examples worth naming:
--
--   * `closed -> in_progress` (complaint / service request) and `closed -> open` (conversation) are
--     REAL transitions. Canon says these states are "Terminal unless reopened by authorized action",
--     so reopening is modelled and gated on the resolve/close permission rather than forbidden.
--   * The conversation transitions to `pending_customer` / `pending_internal` emit NO event. Canon's
--     Required Events list for conversations names five events and deliberately does not include
--     them; inventing `conversation_pending_*` codes would put this migration ahead of canon 27's
--     event vocabulary, which it has no authority to extend.
--   * `complaint_reopened` / `service_request_reopened` / `conversation_reopened` are emitted on the
--     reopen edge specifically, because canon lists them as required events for exactly that edge.
--
-- The RPCs deliberately do NOT re-validate catalog codes, entity references, tenant-safe foreign
-- keys or normalization: SPEC-126/127/129/130 enforce those on every write path, and repeating them
-- here would create a second place for the same rule to drift.

-- =============================================================================================
-- CONVERSATIONS
-- =============================================================================================

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

    insert into public.conversations (
        tenant_id, channel_code, conversation_status_code,
        customer_id, lead_id, booking_id, booking_item_id, owner_user_id, started_at
    ) values (
        v_tenant, p_channel_code, 'open',
        p_customer_id, p_lead_id, p_booking_id, p_booking_item_id, v_actor, now()
    ) returning id into v_id;

    perform app.record_event(
        v_tenant, 'conversation_started', 'conversation', v_id, v_actor, null, 'open', null,
        jsonb_build_object('channel_code', p_channel_code, 'customer_id', p_customer_id,
                           'lead_id', p_lead_id, 'booking_id', p_booking_id),
        'info');
    return v_id;
end;
$$;
revoke execute on function app.start_conversation(text,uuid,uuid,uuid,uuid) from public;
grant execute on function app.start_conversation(text,uuid,uuid,uuid,uuid) to authenticated;

create or replace function app.send_conversation_message(
    p_conversation_id uuid,
    p_message_direction_code text,
    p_sender_type_code text,
    p_body text default null
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
    v_status text;
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;
    perform app.authorize('SEND_MESSAGE');

    select conversation_status_code into v_status
    from public.conversations where id = p_conversation_id and tenant_id = v_tenant;
    if v_status is null then raise exception 'conversation not found in your tenant'; end if;
    if v_status = 'closed' then
        raise exception 'conversation is closed; reopen it before sending a message'; end if;

    select id into v_actor from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    insert into public.conversation_messages (
        tenant_id, conversation_id, sender_type_code, message_direction_code, message_text,
        sender_user_id, sent_at, received_at
    ) values (
        v_tenant, p_conversation_id, p_sender_type_code, p_message_direction_code,
        nullif(btrim(p_body), ''), v_actor,
        case when p_message_direction_code = 'inbound' then null else now() end,
        case when p_message_direction_code = 'inbound' then now() else null end
    ) returning id into v_id;

    update public.conversations set updated_at = now()
    where id = p_conversation_id and tenant_id = v_tenant;

    perform app.record_event(
        v_tenant,
        case when p_message_direction_code = 'inbound'
             then 'conversation_message_received' else 'conversation_message_sent' end,
        'conversation', p_conversation_id, v_actor, null, null, null,
        jsonb_build_object('message_id', v_id, 'direction', p_message_direction_code),
        'info');
    return v_id;
end;
$$;
revoke execute on function app.send_conversation_message(uuid,text,text,text) from public;
grant execute on function app.send_conversation_message(uuid,text,text,text) to authenticated;

create or replace function app.advance_conversation(
    p_conversation_id uuid,
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
    v_matched boolean := false;
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;

    select conversation_status_code into v_status
    from public.conversations where id = p_conversation_id and tenant_id = v_tenant;
    if v_status is null then raise exception 'conversation not found in your tenant'; end if;

    -- 26_state_machines.md, Conversation State Machine. ev is null where canon requires no event.
    select true, t.ev, t.perm into v_matched, v_event, v_perm
    from (values
        ('open',             'assigned',         'conversation_assigned',  'SEND_MESSAGE'),
        ('assigned',         'pending_customer',  null,                    'SEND_MESSAGE'),
        ('assigned',         'pending_internal',  null,                    'SEND_MESSAGE'),
        ('pending_customer', 'assigned',         'conversation_assigned',  'SEND_MESSAGE'),
        ('pending_internal', 'assigned',         'conversation_assigned',  'SEND_MESSAGE'),
        ('assigned',         'escalated',        'conversation_escalated', 'ESCALATE_CONVERSATION'),
        ('escalated',        'assigned',         'conversation_assigned',  'ESCALATE_CONVERSATION'),
        ('assigned',         'closed',           'conversation_closed',    'CLOSE_CONVERSATION'),
        ('pending_customer', 'closed',           'conversation_closed',    'CLOSE_CONVERSATION'),
        ('escalated',        'closed',           'conversation_closed',    'CLOSE_CONVERSATION'),
        ('closed',           'open',             'conversation_reopened',  'CLOSE_CONVERSATION')
    ) as t(frm, to_s, ev, perm)
    where t.frm = v_status and t.to_s = p_to_status;

    if not v_matched then
        raise exception 'invalid conversation transition % -> %', v_status, p_to_status; end if;
    perform app.authorize(v_perm);

    select id into v_actor from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    update public.conversations
    set conversation_status_code = p_to_status,
        closed_at = case when p_to_status = 'closed' then now()
                         when p_to_status = 'open' then null else closed_at end,
        updated_at = now()
    where id = p_conversation_id and tenant_id = v_tenant;

    if v_event is not null then
        perform app.record_event(
            v_tenant, v_event, 'conversation', p_conversation_id, v_actor,
            v_status, p_to_status, p_reason, null, 'info');
    end if;
end;
$$;
revoke execute on function app.advance_conversation(uuid,text,text) from public;
grant execute on function app.advance_conversation(uuid,text,text) to authenticated;

-- =============================================================================================
-- COMPLAINTS
-- =============================================================================================

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

    insert into public.complaints (
        tenant_id, customer_id, booking_id, booking_item_id,
        complaint_category_code, complaint_severity_code, complaint_status_code,
        title, description, created_by
    ) values (
        v_tenant, p_customer_id, p_booking_id, p_booking_item_id,
        p_complaint_category_code, p_complaint_severity_code, 'new',
        v_title, nullif(btrim(p_description), ''), v_actor
    ) returning id into v_id;

    perform app.record_event(
        v_tenant, 'complaint_created', 'complaint', v_id, v_actor, null, 'new', null,
        jsonb_build_object('customer_id', p_customer_id,
                           'complaint_category_code', p_complaint_category_code,
                           'complaint_severity_code', p_complaint_severity_code),
        'info');
    return v_id;
end;
$$;
revoke execute on function app.create_complaint(uuid,text,text,text,text,uuid,uuid) from public;
grant execute on function app.create_complaint(uuid,text,text,text,text,uuid,uuid) to authenticated;

create or replace function app.advance_complaint(
    p_complaint_id uuid,
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

    select id into v_actor from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    update public.complaints
    set complaint_status_code = p_to_status,
        resolved_at = case when p_to_status = 'resolved' then now() else resolved_at end,
        closed_at = case when p_to_status = 'closed' then now()
                         when p_to_status = 'in_progress' then null else closed_at end,
        updated_at = now()
    where id = p_complaint_id and tenant_id = v_tenant;

    perform app.record_event(
        v_tenant, v_event, 'complaint', p_complaint_id, v_actor, v_status, p_to_status, p_reason,
        null, 'info');
end;
$$;
revoke execute on function app.advance_complaint(uuid,text,text) from public;
grant execute on function app.advance_complaint(uuid,text,text) to authenticated;

-- =============================================================================================
-- SERVICE REQUESTS
-- =============================================================================================

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

    insert into public.service_requests (
        tenant_id, customer_id, booking_id, booking_item_id,
        service_request_type_code, service_request_severity_code, service_request_status_code,
        title, description, created_by
    ) values (
        v_tenant, p_customer_id, p_booking_id, p_booking_item_id,
        p_service_request_type_code, p_service_request_severity_code, 'requested',
        v_title, nullif(btrim(p_description), ''), v_actor
    ) returning id into v_id;

    perform app.record_event(
        v_tenant, 'service_request_created', 'service_request', v_id, v_actor, null, 'requested', null,
        jsonb_build_object('customer_id', p_customer_id,
                           'service_request_type_code', p_service_request_type_code),
        'info');
    return v_id;
end;
$$;
revoke execute on function app.create_service_request(uuid,text,text,text,text,uuid,uuid) from public;
grant execute on function app.create_service_request(uuid,text,text,text,text,uuid,uuid) to authenticated;

create or replace function app.advance_service_request(
    p_service_request_id uuid,
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

    select id into v_actor from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    update public.service_requests
    set service_request_status_code = p_to_status,
        resolved_at = case when p_to_status = 'resolved' then now() else resolved_at end,
        updated_at = now()
    where id = p_service_request_id and tenant_id = v_tenant;

    perform app.record_event(
        v_tenant, v_event, 'service_request', p_service_request_id, v_actor,
        v_status, p_to_status, p_reason, null, 'info');
end;
$$;
revoke execute on function app.advance_service_request(uuid,text,text) from public;
grant execute on function app.advance_service_request(uuid,text,text) to authenticated;
