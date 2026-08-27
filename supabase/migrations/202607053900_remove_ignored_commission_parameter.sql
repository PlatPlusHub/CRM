-- SPEC-156 -- remove the `p_commission_rate` parameter that SPEC-155 rendered inert.
--
-- SPEC-155 made `commission_rate` system-derived: a BEFORE trigger overwrites the column on every
-- write path, so whatever `app.create_booking_item` passed through was discarded microseconds later.
-- The parameter therefore became a LIE in the API contract -- a caller (a future UI, an n8n node, an
-- integration) could pass 0.90, receive no error, and see no effect. A silently ignored input is
-- worse than a rejected one: a rejected input teaches the caller the rule, an ignored input teaches
-- the caller a false rule.
--
-- WHY A SEPARATE MIGRATION rather than a tail-end edit inside SPEC-155: removing a parameter changes
-- the function's identity (its signature), which is an integration-contract change. It deserves its
-- own reviewable unit and its own line in the ledger, so a future reader diffing an integration
-- failure against the migration history finds one obvious cause rather than a footnote.
--
-- WHY `drop function` FIRST and not `create or replace`: PostgreSQL identifies a function by name AND
-- argument list, so `create or replace` with eight parameters would leave the nine-parameter version
-- in place as a second overload. Both would then be callable, the old one would still accept a
-- commission rate, and a positional call could resolve to either -- exactly the ambiguity this
-- migration exists to remove. The drop is the point, not housekeeping.
--
-- CALLER SAFETY, verified before writing this migration rather than assumed: the only callers in the
-- repository are `39_employee_day_one_workflow_test.sql` and `41_commission_derivation_test.sql`,
-- both of which pass the first three arguments positionally and never reach the removed parameter.
-- PostgREST invokes RPCs by NAMED argument, so a caller that never named `p_commission_rate` is
-- unaffected, and one that did named it will now fail loudly -- which is the intended outcome.

drop function if exists app.create_booking_item(uuid, text, text, numeric, numeric, numeric, uuid, text, boolean);

create function app.create_booking_item(
    p_booking_id uuid,
    p_service_type_code text,
    p_currency_code text,
    p_cost_amount numeric default 0,
    p_selling_amount numeric default 0,
    p_supplier_id uuid default null,
    p_sub_status_code text default null,
    p_finance_approval_required boolean default false
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_bk record;
    v_sub_catalog text;
    v_item uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('CREATE_BOOKING_ITEM');

    select id, branch_id, department_id, booking_status_code, is_archived
      into v_bk
    from public.bookings
    where id = p_booking_id and tenant_id = v_tenant;
    if not found then
        raise exception 'booking is not in your tenant';
    end if;
    if v_bk.is_archived or v_bk.booking_status_code in ('completed', 'cancelled') then
        raise exception 'cannot add items to a % booking',
            case when v_bk.is_archived then 'archived' else v_bk.booking_status_code end;
    end if;

    if not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'service_type' and code = p_service_type_code
    ) then
        raise exception 'unknown service_type_code: %', p_service_type_code;
    end if;

    if not exists (select 1 from public.currencies where code = p_currency_code) then
        raise exception 'unknown currency_code: %', p_currency_code;
    end if;

    if p_supplier_id is not null and not exists (
        select 1 from public.suppliers where id = p_supplier_id and tenant_id = v_tenant
    ) then
        raise exception 'supplier is not in your tenant';
    end if;

    -- Service-specific sub-status: only ticket/visa/hotel define a sub-status catalog (13).
    if p_sub_status_code is not null then
        v_sub_catalog := case p_service_type_code
            when 'flight_ticket' then 'ticket_sub_status'
            when 'visa'          then 'visa_sub_status'
            when 'hotel'         then 'hotel_sub_status'
            else null
        end;
        if v_sub_catalog is null then
            raise exception 'service_type % does not support a sub_status', p_service_type_code;
        end if;
        if not exists (
            select 1 from public.catalog_values
            where catalog_type_code = v_sub_catalog and code = p_sub_status_code
        ) then
            raise exception 'unknown % value: %', v_sub_catalog, p_sub_status_code;
        end if;
    end if;

    if p_cost_amount < 0 or p_selling_amount < 0 then
        raise exception 'cost and selling amounts must be non-negative';
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    -- `commission_rate` is deliberately absent from this INSERT. It is not omitted as a default --
    -- `app.derive_commission_rate` (SPEC-155) sets it on every INSERT and UPDATE, so naming it here
    -- would only re-create the illusion that this function decides it.
    insert into public.booking_items (
        tenant_id, booking_id, service_type_code, base_status_code, sub_status_code, supplier_id,
        operational_owner_user_id, owner_user_id, owner_department_id, owner_branch_id,
        sales_owner_user_id, sales_owner_department_id, sales_owner_branch_id,
        currency_code, cost_amount, selling_amount,
        finance_approval_required, created_by
    )
    values (
        v_tenant, p_booking_id, p_service_type_code, 'draft', p_sub_status_code, p_supplier_id,
        v_actor, v_actor, v_bk.department_id, v_bk.branch_id,
        v_actor, v_bk.department_id, v_bk.branch_id,
        p_currency_code, p_cost_amount, p_selling_amount,
        p_finance_approval_required, v_actor
    )
    returning id into v_item;

    perform app.record_event(
        v_tenant, 'booking_item_created', 'booking_item', v_item, v_actor, null, 'draft', null,
        jsonb_build_object('booking_id', p_booking_id, 'service_type_code', p_service_type_code,
                           'currency_code', p_currency_code)
    );

    return v_item;
end;
$fn$;

revoke execute on function app.create_booking_item(uuid, text, text, numeric, numeric, uuid, text, boolean) from public;
grant  execute on function app.create_booking_item(uuid, text, text, numeric, numeric, uuid, text, boolean) to authenticated;

comment on function app.create_booking_item(uuid, text, text, numeric, numeric, uuid, text, boolean) is
    'Creates a booking item. Commission rate is NOT a parameter: it is system-derived by '
    'app.derive_commission_rate (SPEC-155) and cannot be influenced by the caller on any path.';
