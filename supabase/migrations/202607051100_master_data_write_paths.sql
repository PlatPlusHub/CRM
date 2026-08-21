-- Migration: master_data_write_paths
-- Plan reference: SPEC-134. Resolves RPC-2 and closes the remaining employee-facing master-data
-- write paths: customer contact methods, customer notes, suppliers and marketing campaigns.
--
-- RPC-2 ASKED WHICH PERMISSION GOVERNS FOUR ENTITIES THAT HAVE NONE OF THEIR OWN. The answer was
-- determined from canon and from ORVION's own established pattern, not invented, and not resolved by
-- minting permission keys to make a count reach zero. Each is justified separately:
--
--   customer_contact_methods -> CREATE_CUSTOMER
--   customer_notes           -> CREATE_CUSTOMER
--     Both are sub-records of the Customer aggregate: `customer_id` is NOT NULL on each, so neither
--     can exist independently; neither has a state machine in 26_state_machines.md; and 28_permissions
--     _matrix.md's CRM table -- which is granular enough to separate SEND_QUOTATION from
--     ACCEPT_QUOTATION -- lists only CREATE_CUSTOMER and MERGE_CUSTOMER_IDENTITY for the customer
--     domain. Decisively, ORVION already governs sub-records by their capability rather than by their
--     table: `app.create_passenger` is authorized by CREATE_BOOKING_ITEM, and `app.create_customer`
--     already writes `customer_identity_signals` under CREATE_CUSTOMER. This is that same pattern,
--     not a convenience borrow.
--
--   suppliers -> ASSIGN_SUPPLIER
--     A Supplier is a first-class entity (24_entity_registry.md: "an external or internal service
--     provider", responsible for booking-item links, payables/receivables and statement tracking) --
--     NOT a sub-record. But 28_permissions_matrix.md defines exactly one supplier permission,
--     ASSIGN_SUPPLIER, at branch/department scope, granted to the same roles who would add a supplier
--     in practice (Senior Employee upward). ORVION names capabilities, not tables, so "work with
--     suppliers" is that capability. The permission's NAME reads narrower than its scope; that is a
--     naming observation, not evidence of a second permission. Splitting create from assign would be
--     a 28-amendment and is recorded as an owner option in the register rather than assumed here.
--
--   marketing_campaigns -> MANAGE_MARKETING_CAMPAIGN
--     Already defined in 28's Marketing Permissions at tenant scope, with the note "Marketing
--     campaigns are tenant-scoped (no branch/department ownership fields exist)". MANAGE covers
--     create and update. It is already enforced elsewhere (`app.record_offline_conversion`), so this
--     is simply its second correct use.
--
-- CONTACT DATA IS NORMALIZED HERE TOO. `customer_contact_methods.value` and `suppliers.phone/email`
-- hold the same class of identity data SPEC-126 canonicalized on `customers`, and were left
-- un-normalized only because they had no write path. Normalizing them at their new single write path
-- closes that gap: a contact method typed as ' Ahmed@Gmail.COM ' is stored as 'ahmed@gmail.com', so
-- duplicate detection and any future matching see one comparable form rather than two.

-- =============================================================================================
-- Customer sub-records
-- =============================================================================================

create or replace function app.add_customer_contact_method(
    p_customer_id uuid,
    p_contact_method_type_code text,
    p_value text,
    p_is_primary boolean default false
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
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

    if p_is_primary then
        update public.customer_contact_methods
        set is_primary = false, updated_at = now()
        where tenant_id = v_tenant and customer_id = p_customer_id and is_primary;
    end if;

    insert into public.customer_contact_methods (
        tenant_id, customer_id, contact_method_type_code, value, is_primary
    ) values (v_tenant, p_customer_id, p_contact_method_type_code, v_value, p_is_primary)
    returning id into v_id;

    perform app.record_event(
        v_tenant, 'customer_contact_added', 'customer', p_customer_id,
        (select id from public.users where auth_user_id = (select auth.uid()) and tenant_id = v_tenant),
        null, null, null,
        jsonb_build_object('contact_method_id', v_id,
                           'contact_method_type_code', p_contact_method_type_code),
        'info');
    return v_id;
end;
$$;
revoke execute on function app.add_customer_contact_method(uuid,text,text,boolean) from public;
grant execute on function app.add_customer_contact_method(uuid,text,text,boolean) to authenticated;

create or replace function app.add_customer_note(
    p_customer_id uuid,
    p_note_text text,
    p_is_pinned boolean default false,
    p_is_confidential boolean default false
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
    v_text text := nullif(btrim(p_note_text), '');
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;
    perform app.authorize('CREATE_CUSTOMER');
    if v_text is null then raise exception 'note_text is required'; end if;
    if not exists (select 1 from public.customers where id = p_customer_id and tenant_id = v_tenant) then
        raise exception 'customer is not in your tenant'; end if;

    select id into v_actor from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    -- Deliberately NO duplicate guard: two employees legitimately recording the same short note
    -- ("called, no answer") on different days is a business fact, not an accidental duplicate.
    insert into public.customer_notes (
        tenant_id, customer_id, note_text, is_pinned, is_confidential, created_by
    ) values (v_tenant, p_customer_id, v_text, p_is_pinned, p_is_confidential, v_actor)
    returning id into v_id;

    return v_id;
end;
$$;
revoke execute on function app.add_customer_note(uuid,text,boolean,boolean) from public;
grant execute on function app.add_customer_note(uuid,text,boolean,boolean) to authenticated;

-- =============================================================================================
-- Suppliers
-- =============================================================================================

create or replace function app.create_supplier(
    p_name text,
    p_supplier_type_code text,
    p_phone text default null,
    p_email text default null,
    p_payment_term_code text default null,
    p_credit_limit_amount numeric default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_id uuid;
    v_name text := nullif(btrim(p_name), '');
    v_phone text := app.normalize_phone(p_phone);
    v_email text := app.normalize_email(p_email);
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;
    perform app.authorize('ASSIGN_SUPPLIER');
    if v_name is null then raise exception 'name is required'; end if;
    if p_credit_limit_amount is not null and p_credit_limit_amount < 0 then
        raise exception 'credit_limit_amount must be non-negative'; end if;

    -- Supplier names are the operational key an employee searches by, so the same supplier entered
    -- twice under one tenant is an accidental duplicate that would split payables across two
    -- records. Case-insensitive, because 'Egyptair' and 'EgyptAir' are the same airline.
    if exists (
        select 1 from public.suppliers
        where tenant_id = v_tenant and not is_archived and lower(name) = lower(v_name)
    ) then
        raise exception 'a supplier named "%" already exists in this tenant', v_name
            using errcode = 'unique_violation';
    end if;

    insert into public.suppliers (
        tenant_id, supplier_type_code, name, phone, email, payment_term_code, credit_limit_amount
    ) values (
        v_tenant, p_supplier_type_code, v_name, v_phone, v_email, p_payment_term_code, p_credit_limit_amount
    ) returning id into v_id;

    perform app.record_event(
        v_tenant, 'supplier_created', 'supplier', v_id,
        (select id from public.users where auth_user_id = (select auth.uid()) and tenant_id = v_tenant),
        null, null, null,
        jsonb_build_object('supplier_type_code', p_supplier_type_code, 'name', v_name),
        'info');
    return v_id;
end;
$$;
revoke execute on function app.create_supplier(text,text,text,text,text,numeric) from public;
grant execute on function app.create_supplier(text,text,text,text,text,numeric) to authenticated;

-- =============================================================================================
-- Marketing campaigns
-- =============================================================================================

create or replace function app.create_marketing_campaign(
    p_campaign_name text,
    p_platform_code text,
    p_external_campaign_id text default null,
    p_started_at timestamptz default null
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_id uuid;
    v_name text := nullif(btrim(p_campaign_name), '');
    v_ext text := nullif(btrim(p_external_campaign_id), '');
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;
    perform app.authorize('MANAGE_MARKETING_CAMPAIGN');
    if v_name is null then raise exception 'campaign_name is required'; end if;

    -- The external campaign id is the platform's own identifier. Recording one platform campaign
    -- twice would split its attribution and its daily metrics across two ORVION rows, so it is
    -- unique per tenant and platform where supplied. The NAME is deliberately not unique: an agency
    -- may legitimately run "Umrah Ramadan" on Google and on Meta.
    if v_ext is not null and exists (
        select 1 from public.marketing_campaigns
        where tenant_id = v_tenant and platform_code = p_platform_code and external_campaign_id = v_ext
    ) then
        raise exception 'campaign % is already recorded for platform %', v_ext, p_platform_code
            using errcode = 'unique_violation';
    end if;

    insert into public.marketing_campaigns (
        tenant_id, platform_code, campaign_name, external_campaign_id, status_code, started_at
    ) values (v_tenant, p_platform_code, v_name, v_ext, 'draft', p_started_at)
    returning id into v_id;

    perform app.record_event(
        v_tenant, 'marketing_campaign_created', 'marketing_campaign', v_id,
        (select id from public.users where auth_user_id = (select auth.uid()) and tenant_id = v_tenant),
        null, 'draft', null,
        jsonb_build_object('platform_code', p_platform_code, 'campaign_name', v_name,
                           'external_campaign_id', v_ext),
        'info');
    return v_id;
end;
$$;
revoke execute on function app.create_marketing_campaign(text,text,text,timestamptz) from public;
grant execute on function app.create_marketing_campaign(text,text,text,timestamptz) to authenticated;

create or replace function app.advance_marketing_campaign(
    p_campaign_id uuid,
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

    select status_code into v_status
    from public.marketing_campaigns where id = p_campaign_id and tenant_id = v_tenant;
    if v_status is null then raise exception 'campaign not found in your tenant'; end if;

    -- 26_state_machines.md, Marketing Campaign State Machine.
    select t.ev, t.perm into v_event, v_perm
    from (values
        ('draft',  'active',   'marketing_campaign_activated', 'MANAGE_MARKETING_CAMPAIGN'),
        ('active', 'paused',   'marketing_campaign_paused',    'MANAGE_MARKETING_CAMPAIGN'),
        ('paused', 'active',   'marketing_campaign_activated', 'MANAGE_MARKETING_CAMPAIGN'),
        ('active', 'ended',    'marketing_campaign_ended',     'MANAGE_MARKETING_CAMPAIGN'),
        ('paused', 'ended',    'marketing_campaign_ended',     'MANAGE_MARKETING_CAMPAIGN'),
        ('ended',  'archived', 'marketing_campaign_archived',  'MANAGE_MARKETING_CAMPAIGN')
    ) as t(frm, to_s, ev, perm)
    where t.frm = v_status and t.to_s = p_to_status;

    if v_event is null then
        raise exception 'invalid marketing campaign transition % -> %', v_status, p_to_status; end if;
    perform app.authorize(v_perm);

    select id into v_actor from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    update public.marketing_campaigns
    set status_code = p_to_status,
        ended_at = case when p_to_status = 'ended' then now() else ended_at end,
        started_at = case when p_to_status = 'active' and started_at is null then now() else started_at end,
        updated_at = now()
    where id = p_campaign_id and tenant_id = v_tenant;

    perform app.record_event(
        v_tenant, v_event, 'marketing_campaign', p_campaign_id, v_actor,
        v_status, p_to_status, p_reason, null, 'info');
end;
$$;
revoke execute on function app.advance_marketing_campaign(uuid,text,text) from public;
grant execute on function app.advance_marketing_campaign(uuid,text,text) to authenticated;
