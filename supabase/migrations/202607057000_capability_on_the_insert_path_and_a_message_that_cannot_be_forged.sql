-- SEC-1b / ATTR-4 / CONV-2 / COMP-1 -- the complaints and conversations audit, and the guard that
-- let SEC-1 be declared closed while twelve tables were still open.
--
-- ================================================================================================
-- SEC-1b -- THE CEILING WAS COUNTING THE WRONG TRIGGERS
--
-- `10_grant_model_test` pins three numbers: at most 54 tables insertable by `authenticated`, at most
-- 17 of them with "NO capability trigger ON THE DIRECT WRITE PATH", and at most 3 with no capability
-- enforcement of any kind. The middle detector asks:
--
--     not exists (select 1 from pg_trigger t join pg_proc p on p.oid = t.tgfoid
--                 where t.tgrelid = c.oid and not t.tgisinternal
--                   and pg_get_functiondef(p.oid) ~ '(app\.authorize|app\.has_permission|...)')
--
-- It never asks WHEN the trigger fires. `app.enforce_status_transition` and
-- `app.enforce_archive_authority` both call `app.authorize`, and both are BEFORE **UPDATE** ONLY --
-- so every status-bearing table and every archivable table counted as protected on its INSERT path
-- because it is protected on a different one. Measured live:
--
--     insertable by authenticated ........................... 54
--     no capability trigger, as the detector counts .......... 17
--     no capability trigger THAT FIRES ON INSERT ............. 30
--     credited but UPDATE-only: bookings, complaints, conversations, customer_notes, customers,
--       documents, leads, marketing_campaigns, passengers, quotations, service_requests,
--       suppliers, tasks
--
-- Re-running the third (residue) predicate with the same correction turns **3 into 15**. Three are
-- the canon-34 auth artifacts and remain INTENTIONAL. The other TWELVE are ordinary business tables
-- with no capability check on the direct INSERT path at all.
--
-- REPRODUCED, with the two halves one second apart, same actor, same row:
--
--     trainee holds CREATE_COMPLAINT? f   SEND_MESSAGE? f   CREATE_CUSTOMER? f   CREATE_TASK? f
--     app.create_complaint(...)                     -> REFUSED: permission denied: CREATE_COMPLAINT
--     insert into public.complaints (...)           -> 1 row
--     insert into public.conversations (...)        -> 1 row
--
-- The trainee satisfies the policy through its `current_user_id() = owner_user_id` disjunct: naming
-- YOURSELF as owner is enough. The RPC refuses; the table accepts. This is SEC-1 exactly, in tables
-- the register recorded as closed -- and the reason it was recorded as closed is the detector above.
--
-- ------------------------------------------------------------------------------------------------
-- WHY INSERT ONLY, AND NOT UPDATE
--
-- `202607056000` attaches this guard BEFORE INSERT OR UPDATE. Here it is INSERT only, deliberately:
-- charging CREATE_BOOKING on every UPDATE to `bookings` would break `advance_booking`, since
-- `finance_manager` holds ISSUE_BOOKING and does NOT hold CREATE_BOOKING. That is the same exception
-- `202607056000` already had to make for `approval_requests`, discovered the same way -- by checking
-- before writing rather than after breaking. UPDATE remains governed by the transition, archive and
-- financial guards that already cover it.
--
-- The residual UPDATE axis is NOT closed by this migration and is recorded as **SEC-2**: a
-- descriptive update (retitling a booking, editing a customer's name) still carries no capability
-- check, and cannot be derived -- there is no `update_customer` RPC anywhere to read a permission
-- out of, so choosing one would be inventing business policy rather than reading it.
--
-- Each permission below is READ OUT of the function that already inserts into that table. Nothing
-- is chosen; `create_supplier` charges ASSIGN_SUPPLIER, so `suppliers` charges ASSIGN_SUPPLIER.
-- ================================================================================================

create or replace function app.guard_write_capability()
returns trigger
language plpgsql
set search_path = ''
as $function$
declare
    v_perms text[];
    v_perm  text;
    v_held  text;
begin
    -- Platform/system paths (canon 35 principle 6), as in every other guard here.
    if (select auth.uid()) is null then
        return new;
    end if;

    v_perms := case tg_table_name
                   -- 202607056000: the permission each table's own RPC already charges.
                   when 'approval_requests'         then array['CREATE_BOOKING_ITEM']
                   when 'conversation_messages'     then array['SEND_MESSAGE']
                   when 'customer_contact_methods'  then array['CREATE_CUSTOMER']
                   when 'customer_identity_signals' then array['CREATE_CUSTOMER']
                   when 'customer_identity_merges'  then array['MERGE_CUSTOMER_IDENTITY']
                   when 'internal_supplier_links'   then array['ASSIGN_SUPPLIER']
                   when 'offline_conversions'       then array['MANAGE_MARKETING_CAMPAIGN']
                   when 'document_links'            then array['UPLOAD_DOCUMENT','MANAGE_TENANT_SETTINGS']
                   when 'lead_assignments'          then array['ASSIGN_LEAD','REASSIGN_LEAD']
                   -- 202607056100: no RPC writes these at all, so the permission comes from what
                   -- ORVION charges for the parent object or for the same class of master data.
                   when 'branch_business_hours'     then array['MANAGE_BRANCHES']
                   when 'holidays'                  then array['MANAGE_BRANCHES','MANAGE_TENANT_SETTINGS']
                   when 'financial_accounts'        then array['CREATE_JOURNAL_ENTRY']
                   when 'company_assets'            then array['CREATE_JOURNAL_ENTRY']
                   -- 202607057000 (SEC-1b): the twelve the ceiling's detector was crediting for an
                   -- UPDATE-only trigger. Read out of each table's own creating RPC.
                   when 'bookings'                  then array['CREATE_BOOKING']
                   when 'complaints'                then array['CREATE_COMPLAINT']
                   when 'conversations'             then array['SEND_MESSAGE']
                   when 'customer_notes'            then array['CREATE_CUSTOMER']
                   when 'customers'                 then array['CREATE_CUSTOMER']
                   when 'documents'                 then array['UPLOAD_DOCUMENT']
                   when 'leads'                     then array['CREATE_LEAD']
                   when 'passengers'                then array['CREATE_BOOKING_ITEM']
                   when 'quotations'                then array['CREATE_QUOTATION']
                   when 'service_requests'          then array['CREATE_SERVICE_REQUEST']
                   when 'suppliers'                 then array['ASSIGN_SUPPLIER']
                   when 'tasks'                     then array['CREATE_TASK']
               end;

    if v_perms is null then
        -- Attached to a table with no mapping. Refusing is the only safe reading: returning NEW
        -- would manufacture the exact unguarded path this migration exists to close.
        raise exception 'guard_write_capability has no permission mapping for %', tg_table_name
            using errcode = 'insufficient_privilege';
    end if;

    -- `has_permission` first to find WHICH of the alternatives the caller holds, then `authorize`
    -- on that one -- because authorize is what also composes the MFA step-up, and a bare
    -- has_permission check would silently drop it for the roles canon 28 requires it from.
    foreach v_perm in array v_perms loop
        if app.has_permission(v_perm) then
            v_held := v_perm;
            exit;
        end if;
    end loop;

    if v_held is null then
        raise exception 'permission denied: one of % is required to write %',
                        array_to_string(v_perms, ' or '), tg_table_name
            using errcode = 'insufficient_privilege';
    end if;

    perform app.authorize(v_held);
    return new;
end
$function$;

do $$
declare t text;
begin
    foreach t in array array['bookings','complaints','conversations','customer_notes','customers',
                             'documents','leads','passengers','quotations','service_requests',
                             'suppliers','tasks']
    loop
        execute format('drop trigger if exists %I on public.%I', t || '_guard_write_capability', t);
        execute format(
            'create trigger %I before insert on public.%I
             for each row execute function app.guard_write_capability()',
            t || '_guard_write_capability', t);
    end loop;
end $$;

-- ================================================================================================
-- ATTR-4 -- a conversation message could name any colleague as its sender.
--
-- `app.send_conversation_message` sets `sender_user_id` from the session. Direct DML did not have
-- to. REPRODUCED: an employee inserted a message into their own conversation naming a COLLEAGUE as
-- sender, and the row reads back "Colleague | I never wrote this". This is FIN-4 / ATTR-1 / ATTR-2's
-- shape on the one record that says what an agency told a customer.
--
-- The rule matches what the RPC already does -- `sender_user_id := v_actor` on every insert,
-- whatever the sender_type -- so the guard makes the RPC's behaviour unbypassable rather than
-- introducing a second, different rule. Session-less paths (a future WhatsApp inbound writer) are
-- exempt from the derivation and keep what they set, exactly as `derive_created_by` does.
-- ================================================================================================

create or replace function app.derive_message_sender()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    if tg_op = 'INSERT' then
        new.sender_user_id := app.current_user_id();
    else
        new.sender_user_id := old.sender_user_id;   -- immutable
    end if;
    return new;
end
$fn$;

revoke execute on function app.derive_message_sender() from public;

drop trigger if exists conversation_messages_derive_sender on public.conversation_messages;
create trigger conversation_messages_derive_sender
    before insert or update on public.conversation_messages
    for each row
    execute function app.derive_message_sender();

-- ================================================================================================
-- CONV-2 -- a sent message could be rewritten, or deleted.
--
-- REPRODUCED: `update public.conversation_messages set message_text = '...' where id = <a message
-- the employee sent>` returned UPDATE 1 and the text was replaced. The `for ALL` policy uses one
-- expression for reading and writing, so anyone who can read the conversation can rewrite its
-- history -- and DELETE was open on the same policy.
--
-- What a message record IS decides the rule: it is the evidence of what the agency said to a
-- customer, on the channel canon 10 designates for customer communication. ORVION already treats
-- records of that kind as append-only -- `events` through `app.forbid_mutation`, lead assignment
-- history through `app.forbid_assignment_history_rewrite`, whose comment cites canon 04's "No
-- assignment history may be deleted". This applies the same treatment to the same class of fact.
--
-- NOT frozen, and this is the point of naming columns rather than freezing the row:
-- `external_message_id` and `metadata` are the DELIVERY integration's fields -- a WhatsApp writer
-- learns the provider's message id after the send and must be able to record it. A blanket
-- immutability guard would have looked stricter and broken the integration ORVION is being built
-- for. Same shape as `forbid_assignment_history_rewrite`, which permits exactly `unassigned_at`
-- and `is_current`.
-- ================================================================================================

create or replace function app.forbid_message_rewrite()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if tg_op = 'DELETE' then
        raise exception
            'a conversation message may not be deleted; it is the record of what was said to the customer'
            using errcode = '42501';
    end if;

    if new.conversation_id       is distinct from old.conversation_id
       or new.tenant_id          is distinct from old.tenant_id
       or new.sender_type_code   is distinct from old.sender_type_code
       or new.sender_user_id     is distinct from old.sender_user_id
       or new.message_direction_code is distinct from old.message_direction_code
       or new.message_text       is distinct from old.message_text
       or new.sent_at            is distinct from old.sent_at
       or new.received_at        is distinct from old.received_at then
        raise exception
            'a conversation message is immutable; only external_message_id and metadata may change'
            using errcode = '42501';
    end if;
    return new;
end
$fn$;

revoke execute on function app.forbid_message_rewrite() from public;

drop trigger if exists conversation_messages_forbid_rewrite on public.conversation_messages;
create trigger conversation_messages_forbid_rewrite
    before update or delete on public.conversation_messages
    for each row
    execute function app.forbid_message_rewrite();

-- ================================================================================================
-- COMP-1 -- a complaint could reach `resolved` with no record of how.
--
-- `public.complaints.resolution_notes` is declared in canon 31 ("resolution_notes nullable") and is
-- written by NOTHING in the database -- VOID-1's class, a column that is a contract nobody honours.
-- Meanwhile `app.advance_complaint` already accepts `p_reason` and already puts it in the event.
--
-- The narrowest correct fix: on the transition INTO `resolved`, and only that one, persist the
-- reason as the resolution note. `resolved` is the single transition where "reason" and "resolution"
-- denote the same fact -- a reason given for `new -> acknowledged` is not a resolution, so writing
-- it there would corrupt the column rather than fill it. No signature change, no new parameter, no
-- new vocabulary, and `coalesce` so a caller who supplies nothing does not erase an earlier note.
-- ================================================================================================

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
        -- COMP-1: the reason given for RESOLVING is the resolution note. Only on this transition,
        -- and coalesced so an empty call does not erase what an earlier resolution recorded.
        resolution_notes = case when p_to_status = 'resolved'
                                then coalesce(nullif(btrim(p_reason), ''), resolution_notes)
                                else resolution_notes end,
        closed_at = case when p_to_status = 'closed' then now()
                         when p_to_status = 'in_progress' then null else closed_at end,
        updated_at = now()
    where id = p_complaint_id and tenant_id = v_tenant;

    perform app.record_event(
        v_tenant, v_event, 'complaint', p_complaint_id, v_actor, v_status, p_to_status, p_reason,
        null, 'info');
end;
$function$;
