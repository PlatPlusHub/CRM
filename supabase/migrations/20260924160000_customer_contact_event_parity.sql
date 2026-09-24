-- CM-3: the table door and SECURITY INVOKER RPC must produce the same customer history.
-- The table INSERT is the single authority for customer_contact_added; UPDATE is unchanged.

create or replace function app.add_customer_contact_method(
    p_customer_id uuid,
    p_contact_method_type_code text,
    p_value text,
    p_is_primary boolean default false
)
returns uuid
language plpgsql
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_id uuid;
    v_value text;
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;
    perform app.authorize('CREATE_CUSTOMER');

    if not exists (select 1 from public.customers where id = p_customer_id and tenant_id = v_tenant) then
        raise exception 'customer is not in your tenant'; end if;

    -- Same canonical forms as customers.primary_email / primary_phone (SPEC-126), chosen by the
    -- contact-method family so an email is lowercased and a phone loses presentational formatting.
    -- Since 202607058300 the table enforces this too, so the RPC and the direct path agree.
    v_value := case
        when p_contact_method_type_code in ('email') then app.normalize_email(p_value)
        when p_contact_method_type_code in ('primary_phone','secondary_phone','whatsapp')
             then app.normalize_phone(p_value)
        else nullif(btrim(p_value), '')
    end;
    if v_value is null then raise exception 'contact value is required'; end if;

    -- A customer may legitimately have several contact methods, and even several of one type (two
    -- mobiles). What must not happen is the SAME value recorded twice under the same type, which is
    -- an accidental duplicate rather than a business fact.
    if exists (
        select 1 from public.customer_contact_methods
        where tenant_id = v_tenant and customer_id = p_customer_id
          and contact_method_type_code = p_contact_method_type_code and value = v_value
    ) then
        raise exception 'this % is already recorded for the customer', p_contact_method_type_code
            using errcode = 'unique_violation';
    end if;

    -- CM-1: demote only within the SAME channel. "Primary" is per contact_method_type_code --
    -- that is what customer_contact_methods_one_primary_per_type_idx encodes, and a customer
    -- legitimately has both a primary phone and a primary email.
    if p_is_primary then
        update public.customer_contact_methods
        set is_primary = false, updated_at = now()
        where tenant_id = v_tenant
          and customer_id = p_customer_id
          and contact_method_type_code = p_contact_method_type_code
          and is_primary;
    end if;

    insert into public.customer_contact_methods (
        tenant_id, customer_id, contact_method_type_code, value, is_primary
    ) values (v_tenant, p_customer_id, p_contact_method_type_code, v_value, p_is_primary)
    returning id into v_id;

    return v_id;
end;
$fn$;

create or replace function app.emit_customer_contact_added()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $fn$
begin
    perform app.record_event(
        new.tenant_id, 'customer_contact_added', 'customer', new.customer_id,
        (select id from public.users where auth_user_id = (select auth.uid()) and tenant_id = new.tenant_id),
        null, null, null,
        jsonb_build_object('contact_method_id', new.id,
                           'contact_method_type_code', new.contact_method_type_code),
        'info');
    return new;
end;
$fn$;

revoke execute on function app.emit_customer_contact_added() from public;

create trigger customer_contact_methods_emit_added_event
    after insert on public.customer_contact_methods
    for each row execute function app.emit_customer_contact_added();
