-- SPEC-154 (discovered) -- app.create_booking could not create a booking on the DIRECT path.
--
-- THE DEFECT, reproduced live before fixing:
--
--   select app.create_booking(p_customer_id => '...', p_title => '...',
--                             p_branch_id => '...', p_department_id => '...');
--   ERROR:  record "v_quote" is not assigned yet          -- SQLSTATE 55000
--
-- A walk-in customer booked directly -- no lead, no quotation -- is an entirely ordinary travel-agency
-- action, and it was IMPOSSIBLE for every role, not merely for employees. It surfaced only when
-- SPEC-154 finally let an ordinary employee reach the booking step; no existing test exercised the
-- direct path without a quotation, so the bug sat latent behind a permission wall.
--
-- ROOT CAUSE -- a plpgsql evaluation-order trap, not a logic error:
--
--   v_customer := coalesce(p_customer_id,
--                          case when p_quotation_id is not null then v_quote.customer_id end);
--
-- plpgsql does not evaluate this as lazily-branching SQL. It rewrites the statement into a query and
-- passes every referenced plpgsql variable as a BOUND PARAMETER, which means `v_quote.customer_id` is
-- resolved *before* the CASE can short-circuit. When no quotation was supplied, `v_quote` was never
-- assigned by a SELECT INTO, and reading a field off an unassigned RECORD raises 55000. The guard
-- `when p_quotation_id is not null` reads as if it protects the reference; it cannot.
--
-- The same trap sat in a second place, still latent because the first raised earlier:
--
--   if p_quotation_id is not null and v_customer <> v_quote.customer_id then
--
-- An `IF a and b` in plpgsql is likewise one SQL expression, so `b` is not short-circuited either.
-- Both are fixed here; fixing only the reported one would have moved the error rather than removed it.
--
-- THE FIX -- carry the quotation's customer in a SCALAR. A scalar `uuid` is simply NULL when unset,
-- so no branch can trip over it, and both call sites express exactly what they meant. Nothing else
-- about the function changes: the same validations, the same ownership stamping, the same event.

create or replace function app.create_booking(
    p_customer_id uuid default null,
    p_lead_id uuid default null,
    p_title text default null,
    p_branch_id uuid default null,
    p_department_id uuid default null,
    p_travel_start_date date default null,
    p_travel_end_date date default null,
    p_destination_country_code text default null,
    p_destination_city text default null,
    p_booking_reference text default null,
    p_quotation_id uuid default null
)
returns uuid
language plpgsql
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_customer uuid;
    v_branch uuid;
    v_department uuid;
    v_title text;
    v_ref text;
    v_booking uuid;
    v_rc record;
    v_quote record;
    -- Scalar mirror of v_quote.customer_id. NULL when no quotation was supplied, which is what makes
    -- the two references below safe; see this migration's header.
    v_quote_customer uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('CREATE_BOOKING');

    -- ADDITIVE (quotation workflow): an accepted quotation may anchor the booking.
    if p_quotation_id is not null then
        select * into v_quote from public.quotations
        where id = p_quotation_id and tenant_id = v_tenant;
        if not found then
            raise exception 'quotation is not in your tenant';
        end if;
        if v_quote.quotation_status_code <> 'accepted' then
            raise exception 'only an accepted quotation can produce a booking (status: %)',
                v_quote.quotation_status_code;
        end if;
        v_quote_customer := v_quote.customer_id;
    end if;

    if p_lead_id is not null then
        -- Consume the handoff contract (single source of booking-eligibility). Do not re-derive.
        select * into v_rc from app.lead_booking_readiness(p_lead_id);
        if not v_rc.is_ready then
            raise exception 'lead is not booking-ready: %', v_rc.reason_code;
        end if;
        v_customer   := v_rc.customer_id;
        v_branch     := coalesce(p_branch_id, v_rc.branch_id);
        v_department := coalesce(p_department_id, v_rc.department_id);
        v_title      := coalesce(p_title, v_rc.title);
    else
        -- ADDITIVE: the quotation can supply the customer on the direct path.
        v_customer   := coalesce(p_customer_id, v_quote_customer);
        v_branch     := p_branch_id;
        v_department := p_department_id;
        v_title      := p_title;
        if v_customer is null then
            raise exception 'a customer is required to create a booking';
        end if;
    end if;

    -- ADDITIVE: whichever path resolved the customer, it must match the quotation's customer.
    if p_quotation_id is not null and v_customer <> v_quote_customer then
        raise exception 'customer does not match the quotation customer';
    end if;

    if v_branch is null or v_department is null then
        raise exception 'branch and department are required';
    end if;
    if v_title is null then
        raise exception 'a booking title is required';
    end if;

    -- Customer, and department-within-branch-within-tenant, must all be in the caller's tenant.
    if not exists (
        select 1 from public.customers where id = v_customer and tenant_id = v_tenant
    ) then
        raise exception 'customer is not in your tenant';
    end if;
    if not exists (
        select 1 from public.departments d
        where d.id = v_department and d.branch_id = v_branch and d.tenant_id = v_tenant
    ) then
        raise exception 'department does not belong to branch in your tenant';
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    -- Human-readable reference (no uniqueness constraint in the schema; make it practically unique).
    v_ref := coalesce(
        p_booking_reference,
        'BK-' || to_char(now(), 'YYYYMMDD') || '-' || upper(left(replace(gen_random_uuid()::text, '-', ''), 8))
    );

    insert into public.bookings (
        tenant_id, branch_id, department_id, owner_user_id, owner_department_id, owner_branch_id,
        lead_id, quotation_id, customer_id, booking_status_code, title, booking_reference,
        travel_start_date, travel_end_date, destination_country_code, destination_city, created_by
    )
    values (
        v_tenant, v_branch, v_department, v_actor, v_department, v_branch,
        p_lead_id, p_quotation_id, v_customer, 'draft', v_title, v_ref,
        p_travel_start_date, p_travel_end_date, p_destination_country_code, p_destination_city, v_actor
    )
    returning id into v_booking;

    perform app.record_event(
        v_tenant, 'booking_created', 'booking', v_booking, v_actor, null, 'draft', null,
        jsonb_build_object('lead_id', p_lead_id, 'customer_id', v_customer,
                           'booking_reference', v_ref, 'quotation_id', p_quotation_id)
    );

    return v_booking;
end;
$fn$;

revoke execute on function app.create_booking(uuid, uuid, text, uuid, uuid, date, date, text, text, text, uuid) from public;
grant  execute on function app.create_booking(uuid, uuid, text, uuid, uuid, date, date, text, text, text, uuid) to authenticated;
