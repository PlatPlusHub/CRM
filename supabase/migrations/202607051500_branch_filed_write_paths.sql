-- Migration: branch_filed_write_paths
-- Plan reference: SPEC-137 (step 4). Repairs the four RPCs that did not file their records under a
-- branch, which the read-scope model in 202607051400 makes a functional requirement rather than a
-- tidiness one.
--
-- WHY THIS IS NOT COSMETIC. `app.create_quotation` and `app.start_conversation` set only
-- `owner_user_id`; `app.create_complaint` and `app.create_service_request` set none of the ownership
-- triple. Under the tenant-only model those rows were still readable by everyone in the tenant, so
-- the omission was invisible. Under a branch-scoped predicate a null branch matches nothing, and
-- because all four RPCs are SECURITY INVOKER (67 of the 82 app functions are) the new WITH CHECK
-- rejects the insert outright. Left unrepaired, these four RPCs would simply stop working.
--
-- `app.create_task` already resolved placement from the owner's primary branch assignment. Rather
-- than copy that lookup a fifth time, it is lifted into `app.current_placement()` here; the
-- uniqueness index added in 202607051400 is what makes its `limit 1` deterministic.

create or replace function app.current_placement()
returns table (branch_id uuid, department_id uuid)
language sql
stable
security definer
set search_path = ''
as $$
    select uba.branch_id, uba.department_id
    from public.user_branch_assignments uba
    where uba.user_id = app.current_user_id()
      and uba.tenant_id = app.current_tenant_id()
      and uba.is_primary
      and uba.ends_at is null
    limit 1
$$;
revoke execute on function app.current_placement() from public;
grant execute on function app.current_placement() to authenticated;

-- ---------------------------------------------------------------------------------------------
create or replace function app.create_quotation(
    p_customer_id uuid,
    p_currency_code text,
    p_lead_id uuid default null,
    p_valid_until timestamptz default null,
    p_quotation_number text default null
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
    v_number text;
    v_branch uuid;
    v_dept uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('CREATE_QUOTATION');

    if not exists (select 1 from public.customers where id = p_customer_id and tenant_id = v_tenant) then
        raise exception 'customer is not in your tenant';
    end if;
    if not exists (select 1 from public.currencies where code = p_currency_code) then
        raise exception 'unknown currency_code: %', p_currency_code;
    end if;
    if p_lead_id is not null and not exists (
        select 1 from public.leads where id = p_lead_id and tenant_id = v_tenant
    ) then
        raise exception 'lead is not in your tenant';
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    select cp.branch_id, cp.department_id into v_branch, v_dept from app.current_placement() cp;
    if v_branch is null then
        raise exception 'you have no primary branch assignment; a quotation must be filed under a branch';
    end if;

    v_number := coalesce(
        p_quotation_number,
        'QT-' || to_char(now(), 'YYYYMMDD') || '-' || upper(left(replace(gen_random_uuid()::text, '-', ''), 8))
    );

    insert into public.quotations (
        tenant_id, lead_id, customer_id, owner_user_id, owner_branch_id, owner_department_id,
        quotation_status_code, quotation_number, currency_code, valid_until, created_by
    ) values (
        v_tenant, p_lead_id, p_customer_id, v_actor, v_branch, v_dept,
        'draft', v_number, p_currency_code, p_valid_until, v_actor
    )
    returning id into v_id;

    perform app.record_event(
        v_tenant, 'quotation_created', 'quotation', v_id, v_actor,
        null, 'draft', null,
        jsonb_build_object('quotation_number', v_number, 'customer_id', p_customer_id, 'lead_id', p_lead_id),
        'info'
    );
    return v_id;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- `current_*` mirrors `owner_*` at creation: a conversation starts where it is opened, and
-- escalation (app.advance_conversation) is what moves it.
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

    perform app.record_event(
        v_tenant, 'conversation_started', 'conversation', v_id, v_actor, null, 'open', null,
        jsonb_build_object('channel_code', p_channel_code, 'customer_id', p_customer_id,
                           'lead_id', p_lead_id, 'booking_id', p_booking_id),
        'info');
    return v_id;
end;
$$;

-- ---------------------------------------------------------------------------------------------
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

    perform app.record_event(
        v_tenant, 'complaint_created', 'complaint', v_id, v_actor, null, 'new', null,
        jsonb_build_object('customer_id', p_customer_id,
                           'complaint_category_code', p_complaint_category_code,
                           'complaint_severity_code', p_complaint_severity_code),
        'info');
    return v_id;
end;
$$;

-- ---------------------------------------------------------------------------------------------
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

    perform app.record_event(
        v_tenant, 'service_request_created', 'service_request', v_id, v_actor, null, 'requested', null,
        jsonb_build_object('customer_id', p_customer_id,
                           'service_request_type_code', p_service_request_type_code),
        'info');
    return v_id;
end;
$$;
