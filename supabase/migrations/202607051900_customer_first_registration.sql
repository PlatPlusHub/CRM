-- Migration: customer_first_registration
-- Plan reference: SPEC-140 (step 5, writer half). Makes `app.create_customer` record who and where a
-- customer was first taken on.
--
-- TWO THINGS WERE MISSING, ONE OF THEM CANONICAL. Canon 03 states "The system must record which
-- branch first registered a customer", and the column existed -- but `create_customer` filled it from
-- an optional parameter defaulting to NULL, so the fact canon requires was recorded only when a
-- caller happened to supply it. The owner's directive of 2026-08-24 §8 adds the employee: the first
-- person who actually took the customer on, preserved permanently and never derived from whoever
-- currently handles them.
--
-- Both now come from the same place the rest of the system resolves placement from -- the caller's
-- primary branch assignment (`app.current_placement`, SPEC-137) -- with an explicit branch parameter
-- still winning when one is passed. The freeze trigger added in 202607051800 is what makes
-- "permanently" true rather than merely intended.

create or replace function app.create_customer(
    p_customer_type_code text,
    p_full_name text,
    p_first_name text default null,
    p_family_name text default null,
    p_company_name text default null,
    p_primary_phone text default null,
    p_primary_email text default null,
    p_whatsapp text default null,
    p_preferred_language_code text default null,
    p_preferred_contact_method_code text default null,
    p_marketing_opt_in boolean default false,
    p_branch_id uuid default null,
    p_allow_duplicate boolean default false
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_customer uuid;
    v_dupe uuid;
    v_branch uuid;
    v_phone text := app.normalize_phone(p_primary_phone);
    v_email text := app.normalize_email(p_primary_email);
    v_whatsapp text := app.normalize_phone(p_whatsapp);
    v_full_name text := nullif(btrim(p_full_name), '');
    v_first_name text := nullif(btrim(p_first_name), '');
    v_family_name text := nullif(btrim(p_family_name), '');
    v_company_name text := nullif(btrim(p_company_name), '');
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('CREATE_CUSTOMER');

    if not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'customer_type' and code = p_customer_type_code
    ) then
        raise exception 'unknown customer_type_code: %', p_customer_type_code;
    end if;

    if p_preferred_contact_method_code is not null and not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'contact_method_type' and code = p_preferred_contact_method_code
    ) then
        raise exception 'unknown preferred_contact_method_code: %', p_preferred_contact_method_code;
    end if;

    if p_branch_id is not null and not exists (
        select 1 from public.branches where id = p_branch_id and tenant_id = v_tenant
    ) then
        raise exception 'branch is not in your tenant';
    end if;

    -- Primary-phone uniqueness (05): unique in-tenant unless an approved exception is requested.
    -- Compares NORMALIZED values, so '+20 123', '+20-123' and '+20123' are correctly one number.
    if v_phone is not null and not p_allow_duplicate then
        select id into v_dupe from public.customers
        where tenant_id = v_tenant and is_archived = false and primary_phone = v_phone
        limit 1;
        if v_dupe is not null then
            raise exception 'duplicate primary phone for customer %; pass p_allow_duplicate to override', v_dupe
                using errcode = 'unique_violation';
        end if;
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    -- An explicit branch still wins; otherwise the customer is registered where the employee taking
    -- them on actually works. Leaving it null was how canon 03's requirement quietly went unrecorded.
    v_branch := coalesce(p_branch_id, (select cp.branch_id from app.current_placement() cp));

    insert into public.customers (
        tenant_id, customer_type_code, first_name, family_name, full_name, company_name,
        primary_phone, primary_email, preferred_language_code, preferred_contact_method_code,
        marketing_opt_in, first_registered_branch_id, first_registered_user_id, created_by
    )
    values (
        v_tenant, p_customer_type_code, v_first_name, v_family_name, v_full_name, v_company_name,
        v_phone, v_email, p_preferred_language_code, p_preferred_contact_method_code,
        p_marketing_opt_in, v_branch, v_actor, v_actor
    )
    returning id into v_customer;

    -- Seed identity signals (only for provided values) so duplicate detection has data to match on.
    insert into public.customer_identity_signals (tenant_id, customer_id, signal_type_code, signal_value)
    select v_tenant, v_customer, t.st, t.sv
    from (values
        ('phone',    v_phone),
        ('whatsapp', v_whatsapp),
        ('email',    v_email)
    ) as t(st, sv)
    where t.sv is not null;

    return v_customer;
end;
$$;
