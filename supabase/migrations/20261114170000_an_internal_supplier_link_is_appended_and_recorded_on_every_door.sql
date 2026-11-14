-- ISL-1, ISL-2 -- Batch 6 slice 10 (`internal_supplier_links`).
--
-- THE RULE. A link records which branch and department fulfil a booking item for its owning unit.
-- `app.link_internal_supplier` appends one ("history preserved; latest row = current provider")
-- and records `internal_supplier_linked`. `authenticated` holds table-level INSERT and UPDATE, and
-- PostgREST serves both beside the RPC. Measured before this migration (local stack, a
-- `senior_employee` holding ASSIGN_SUPPLIER, at aal1 as that role allows):
--   ISL-1  a link inserted at the table door added no event, where the RPC's added one;
--   ISL-2  an UPDATE moved a link's provider from Alex to Giza, moved it to another booking item
--          and back-dated it to 2019, and none of it was recorded: the history the RPC appends
--          could be rewritten in place.
--
-- THE REPAIR, in existing shapes. One AFTER INSERT trigger is the single producer of the event
-- (SPEC-215's `suppliers_emit_created`), so the RPC loses its own `record_event` call, which would
-- otherwise record every RPC link twice; the RPC hands the trigger its reason through
-- `app.transition_reason`, which the trigger consumes (SPEC-237). The actor and time are
-- `record_event`'s: the session's user, or none on a session-less path. A BEFORE UPDATE OR DELETE
-- trigger on `app.forbid_mutation` makes the table append-only for every writer, the owner included,
-- as `events` is: a new provider is a new row, which is what the RPC always did.
--
-- NOT CHANGED: every grant, policy and constraint; the integrity and capability guards; the event's
-- type, entity, severity and payload keys (the payload values are read from the row the guard
-- derived); and every other line of `app.link_internal_supplier`. A link's caller-supplied
-- `created_at` on INSERT stays a recorded position (SPEC-216's question, as slices 7-9).
create or replace function app.link_internal_supplier(p_booking_item_id uuid, p_provider_branch_id uuid, p_provider_department_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
declare
    v_tenant uuid := app.current_tenant_id();
    v_item record;
    v_req_branch uuid;
    v_req_dept uuid;
    v_link uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('ASSIGN_SUPPLIER');

    select bi.id, bi.base_status_code, bi.is_archived,
           bi.owner_branch_id, bi.owner_department_id,
           b.branch_id as booking_branch_id, b.department_id as booking_department_id,
           b.booking_status_code, b.is_archived as booking_archived
      into v_item
    from public.booking_items bi
    join public.bookings b on b.id = bi.booking_id and b.tenant_id = v_tenant
    where bi.id = p_booking_item_id and bi.tenant_id = v_tenant;
    if not found then
        raise exception 'booking item is not in your tenant';
    end if;
    if v_item.is_archived or v_item.base_status_code in ('cancelled', 'no_show') then
        raise exception 'cannot link a supplier to a % booking item', v_item.base_status_code;
    end if;
    if v_item.booking_archived or v_item.booking_status_code in ('completed', 'cancelled') then
        raise exception 'cannot link a supplier to an item on a % booking', v_item.booking_status_code;
    end if;

    -- Requester = the item's owning org unit (fallback to the booking's branch/department).
    v_req_branch := coalesce(v_item.owner_branch_id, v_item.booking_branch_id);
    v_req_dept   := coalesce(v_item.owner_department_id, v_item.booking_department_id);

    -- Provider org unit must be a department-within-branch in the caller's tenant.
    if not exists (
        select 1 from public.departments d
        where d.id = p_provider_department_id
          and d.branch_id = p_provider_branch_id
          and d.tenant_id = v_tenant
    ) then
        raise exception 'provider department does not belong to provider branch in your tenant';
    end if;

    -- Append a new fulfilment record (history preserved; latest row = current provider). Its event is
    -- recorded by `internal_supplier_links_emit_linked` on every door; this RPC only hands it the
    -- caller's reason (SPEC-237's `app.transition_reason`).
    perform set_config('app.transition_reason', coalesce(p_reason, ''), true);
    insert into public.internal_supplier_links (
        tenant_id, booking_item_id, provider_branch_id, provider_department_id,
        requester_branch_id, requester_department_id
    )
    values (
        v_tenant, p_booking_item_id, p_provider_branch_id, p_provider_department_id,
        v_req_branch, v_req_dept
    )
    returning id into v_link;

    return v_link;
end;
$function$;

create or replace function app.emit_internal_supplier_linked()
returns trigger
language plpgsql
security definer
set search_path to ''
as $fn$
declare
    v_reason text := nullif(current_setting('app.transition_reason', true), '');
begin
    perform app.record_event(
        new.tenant_id, 'internal_supplier_linked', 'booking_item', new.booking_item_id,
        app.current_user_id(), null, null, v_reason,
        jsonb_build_object('link_id', new.id,
                           'provider_branch_id', new.provider_branch_id,
                           'provider_department_id', new.provider_department_id,
                           'requester_branch_id', new.requester_branch_id,
                           'requester_department_id', new.requester_department_id),
        'info');
    -- Consumed: a later link in the same transaction carries only its own reason.
    perform set_config('app.transition_reason', '', true);
    return null;
end;
$fn$;

revoke execute on function app.emit_internal_supplier_linked() from public;

create trigger internal_supplier_links_emit_linked
    after insert on public.internal_supplier_links
    for each row execute function app.emit_internal_supplier_linked();

create trigger internal_supplier_links_append_only
    before update or delete on public.internal_supplier_links
    for each row execute function app.forbid_mutation();
