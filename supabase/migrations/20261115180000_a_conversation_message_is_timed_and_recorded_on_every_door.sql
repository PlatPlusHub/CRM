-- CHAT-3, CHAT-4 -- Batch 6 slice 11 (`conversation_messages`).
--
-- THE RULE. A message is sent or received inside a conversation. `app.send_conversation_message`
-- stamps its time from the clock (`sent_at` for outbound, `received_at` for inbound), stores a blank
-- text as none, moves the conversation's `updated_at` and records `conversation_message_sent` or
-- `conversation_message_received`. `authenticated` holds table-level INSERT beside the RPC, and
-- PostgREST serves it. Measured before this migration (local stack, an `employee` holding
-- SEND_MESSAGE, at aal1 as that role allows):
--   CHAT-3  a message inserted at the table door added no event and left its conversation's
--           `updated_at` where it was, where the RPC's did both: a conversation could change with
--           no record and without rising in any list ordered by activity;
--   CHAT-4  the same door accepted `sent_at` 2019 and `received_at` 2099 on one outbound message,
--           and kept a text of three spaces, where the RPC derives both times and stores none.
--
-- THE REPAIR, in existing shapes. The signed-in INSERT arm of `app.derive_message_sender`, which
-- already derives the sender (ATTR-4, `202607057000`), now also derives the two times and the blank text exactly
-- as the RPC does; a session-less insert (a provider integration replaying a message it received
-- earlier) keeps its own times, as it keeps its own sender. One AFTER INSERT trigger is the single
-- producer of the event and of the conversation's move (SPEC-215's shape, slice 10's
-- `internal_supplier_links_emit_linked`), so the RPC loses its own `update` and `record_event`,
-- which would otherwise record every RPC message twice. The actor is `app.current_user_id()`: the
-- session's user, or none on a session-less path.
--
-- NOT CHANGED: every grant, policy and constraint; the sender, parent-state, rewrite and
-- capability guards; the event's types, entity, severity and payload keys; and every other line of
-- `app.send_conversation_message`. A message's caller-supplied `created_at` on INSERT stays a
-- recorded position (SPEC-216's question, as slices 7-10), and `external_message_id` and `metadata`
-- stay writable after the insert by design (`app.forbid_message_rewrite`).
create or replace function app.derive_message_sender()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    if tg_op = 'INSERT' then
        new.sender_user_id := app.current_user_id();
        -- The RPC's derivation, on every signed-in door (CHAT-4).
        new.message_text := nullif(btrim(new.message_text), '');
        new.sent_at := case when new.message_direction_code = 'inbound' then null else now() end;
        new.received_at := case when new.message_direction_code = 'inbound' then now() else null end;
    else
        new.sender_user_id := old.sender_user_id;   -- immutable
    end if;
    return new;
end
$function$;

create or replace function app.send_conversation_message(p_conversation_id uuid, p_message_direction_code text, p_sender_type_code text, p_body text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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

    -- Its event and the conversation's move are recorded by `conversation_messages_emit_recorded`
    -- on every door (CHAT-3).
    insert into public.conversation_messages (
        tenant_id, conversation_id, sender_type_code, message_direction_code, message_text,
        sender_user_id, sent_at, received_at
    ) values (
        v_tenant, p_conversation_id, p_sender_type_code, p_message_direction_code,
        nullif(btrim(p_body), ''), v_actor,
        case when p_message_direction_code = 'inbound' then null else now() end,
        case when p_message_direction_code = 'inbound' then now() else null end
    ) returning id into v_id;

    return v_id;
end;
$function$;

create or replace function app.emit_conversation_message()
returns trigger
language plpgsql
security definer
set search_path to ''
as $fn$
begin
    update public.conversations set updated_at = now()
    where id = new.conversation_id and tenant_id = new.tenant_id;

    perform app.record_event(
        new.tenant_id,
        case when new.message_direction_code = 'inbound'
             then 'conversation_message_received' else 'conversation_message_sent' end,
        'conversation', new.conversation_id, app.current_user_id(), null, null, null,
        jsonb_build_object('message_id', new.id, 'direction', new.message_direction_code),
        'info');
    return null;
end;
$fn$;

revoke execute on function app.emit_conversation_message() from public;

create trigger conversation_messages_emit_recorded
    after insert on public.conversation_messages
    for each row execute function app.emit_conversation_message();
