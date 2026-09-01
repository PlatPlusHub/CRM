-- ================================================================================================
-- PARENT-1 -- a rule about the parent's state is a rule on every door, not only in the RPC.
--
-- ADR-0024 says every rule an RPC enforces must hold on the table door as well, because
-- `authenticated` holds INSERT on the table and PostgREST serves it beside the function. QUO-2
-- closed one instance of that (`quotation_items` on a SENT quotation). This migration closes the
-- CLASS the care/conversation slice exposed, and the class was derived from the catalog rather than
-- from a list: for every `app.*` function that reads a parent's `app.status_transitions.status_column`
-- and then INSERTs into a DIFFERENT table, ask whether any BEFORE INSERT trigger on that table reads
-- the same parent column. Twelve pairs came back unguarded; reading each function reduced them to
-- FOUR that genuinely REFUSE on the parent's state (the rest merely read it -- `record_lead_interaction`
-- reads `lead_status_code` only to decide the assigned -> contacted transition, and refuses nothing).
-- Static analysis was the lead; the function bodies were the verdict (MEAS-1).
--
-- All four reproduced live, each with the RPC as the positive control and a caller who genuinely
-- holds the capability, so every refusal below is the state rule and not a permission:
--
--   RPC refused                                                          | table door returned
--   ---------------------------------------------------------------------|--------------------
--   only an accepted quotation can produce a booking (status: draft)      | INSERT 0 1
--   cannot request finance approval on a cancelled/... booking item       | INSERT 0 1
--   cannot add a version to an archived document                          | INSERT 0 1
--   conversation is closed; reopen it before sending a message            | INSERT 0 1
--
-- ONE function, not four. The rule is a single rule -- "the parent's state decides" -- with four
-- subjects, and four copies of it would be four places to drift apart; that drift is exactly what
-- TRANS-1 records on the transition lists. The per-table detail lives in one CASE, which is the same
-- shape `app.guard_write_capability` already uses for the same reason.
--
-- Three hazards this file is written around, each of which has already cost this repository a defect:
--   * PL/pgSQL resolves a record field against the ACTUAL record type at execution, so naming
--     `new.quotation_id` anywhere this trigger also serves `document_versions` raises
--     `record "new" has no field`. Every field is read through `to_jsonb(new) ->> '...'`
--     (SPEC-159-A, and again in PP-4).
--   * SECURITY DEFINER, because the parent lookup must not be RLS-filtered: an invisible parent
--     would read as NULL and a NULL-tolerant guard would be no guard at all (BOOK-1). The composite
--     tenant-qualified FK already guarantees the parent row exists, so a NULL here is unreachable --
--     and it FAILS CLOSED rather than returning NEW, because "unreachable" is a claim and the
--     raise is a proof.
--   * An unmapped table raises. Attaching this trigger to a table with no rule must be a loud
--     failure, not a silent pass -- `guard_write_capability` refuses for the identical reason.
--
-- BEFORE INSERT ONLY, deliberately. Each rule governs the CREATION of the child row. A parent may
-- legitimately move on afterwards, and freezing the child's own lifecycle to the parent's later
-- state would BREAK working paths: `review_finance_approval` must still decide a request whose item
-- was cancelled in the meantime, and an integration must still reconcile a message's
-- `external_message_id` after its conversation closed. That is the narrowest enforcement that
-- matches the RPC, which is what ADR-0026 asks for.
--
-- NO session-less exemption, per ADR-0025: these are integrity rules about the state of the
-- business, not authorization rules about the identity of the caller. `guard_quotation_item_parent_editable`
-- is the precedent and carries none either.
--
-- Every message is copied VERBATIM from the RPC that already refuses, so the two doors cannot give a
-- caller two different accounts of the same rule.
-- ================================================================================================

create or replace function app.guard_parent_state_allows_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_new      jsonb := to_jsonb(new);
    v_tenant   uuid  := nullif(v_new ->> 'tenant_id', '')::uuid;
    v_parent   uuid;
    v_status   text;
    v_archived boolean;
    v_item     record;
begin
    case tg_table_name

    -- app.create_booking: "only an accepted quotation can produce a booking".
    -- The quotation is OPTIONAL -- a walk-in booking has none -- so the rule is conditional on the
    -- reference being present, exactly as the function's own `if p_quotation_id is not null` is.
    when 'bookings' then
        v_parent := nullif(v_new ->> 'quotation_id', '')::uuid;
        if v_parent is null then
            return new;
        end if;
        select q.quotation_status_code into v_status
        from public.quotations q
        where q.id = v_parent and q.tenant_id = v_tenant;
        if v_status is null then
            raise exception 'quotation is not in your tenant' using errcode = '23514';
        end if;
        if v_status <> 'accepted' then
            raise exception 'only an accepted quotation can produce a booking (status: %)', v_status
                using errcode = '23514';
        end if;

    -- app.request_finance_approval: the item and its booking must both be live. Both halves are
    -- carried, because the function raises separately for each and a caller is entitled to the same
    -- distinction on either door.
    when 'approval_requests' then
        v_parent := nullif(v_new ->> 'booking_item_id', '')::uuid;
        if v_parent is null then
            return new;
        end if;
        select bi.base_status_code, bi.is_archived as item_archived,
               b.booking_status_code, b.is_archived as booking_archived
          into v_item
        from public.booking_items bi
        join public.bookings b on b.id = bi.booking_id and b.tenant_id = bi.tenant_id
        where bi.id = v_parent and bi.tenant_id = v_tenant;
        if not found then
            raise exception 'booking item is not in your tenant' using errcode = '23514';
        end if;
        if v_item.item_archived or v_item.base_status_code in ('cancelled', 'no_show') then
            raise exception 'cannot request finance approval on a cancelled/no_show/archived booking item'
                using errcode = '23514';
        end if;
        if v_item.booking_archived or v_item.booking_status_code in ('completed', 'cancelled') then
            raise exception 'cannot request finance approval on a completed/cancelled/archived booking'
                using errcode = '23514';
        end if;

    -- app.add_document_version: "cannot add a version to an archived document". Both the boolean and
    -- the lifecycle code are tested because the RPC tests both, and DOC-LC-1 made them independent.
    when 'document_versions' then
        v_parent := nullif(v_new ->> 'document_id', '')::uuid;
        select d.lifecycle_status_code, d.is_archived into v_status, v_archived
        from public.documents d
        where d.id = v_parent and d.tenant_id = v_tenant;
        if v_status is null then
            raise exception 'document is not in your tenant' using errcode = '23514';
        end if;
        if v_archived or v_status = 'archived' then
            raise exception 'cannot add a version to an archived document' using errcode = '23514';
        end if;

    -- app.send_conversation_message: a closed conversation is the record of a finished engagement.
    -- Appending to it changes what the file says was said, and the parent's `updated_at` does not
    -- even move to show that anything happened.
    when 'conversation_messages' then
        v_parent := nullif(v_new ->> 'conversation_id', '')::uuid;
        select c.conversation_status_code into v_status
        from public.conversations c
        where c.id = v_parent and c.tenant_id = v_tenant;
        if v_status is null then
            raise exception 'conversation not found in your tenant' using errcode = '23514';
        end if;
        if v_status = 'closed' then
            raise exception 'conversation is closed; reopen it before sending a message'
                using errcode = '23514';
        end if;

    else
        raise exception 'app.guard_parent_state_allows_write has no rule for %', tg_table_name
            using errcode = 'insufficient_privilege';
    end case;

    return new;
end
$fn$;

revoke all on function app.guard_parent_state_allows_write() from public;

comment on function app.guard_parent_state_allows_write() is
    'PARENT-1. Enforces on the table door the parent-state rules that app.create_booking, '
    'app.request_finance_approval, app.add_document_version and app.send_conversation_message each '
    'already enforce (ADR-0024). BEFORE INSERT only: the rule governs creation, not the child row''s '
    'later life. Messages are copied verbatim from those functions.';

create trigger bookings_guard_parent_state
    before insert on public.bookings
    for each row execute function app.guard_parent_state_allows_write();

create trigger approval_requests_guard_parent_state
    before insert on public.approval_requests
    for each row execute function app.guard_parent_state_allows_write();

create trigger document_versions_guard_parent_state
    before insert on public.document_versions
    for each row execute function app.guard_parent_state_allows_write();

create trigger conversation_messages_guard_parent_state
    before insert on public.conversation_messages
    for each row execute function app.guard_parent_state_allows_write();
