-- Migration: canonical_input_and_catalog_governance
-- Plan reference: SPEC-126. Closes four catalog-governance defects and one customer-identity
-- normalization defect, all of which were reproduced behaviorally against the local database on
-- 2026-08-21 before being fixed (evidence in changes/SPEC-126-*.md).
--
-- WHY THIS EXISTS. ORVION's controlled vocabulary and its customer identity anchor were both
-- enforceable only by convention. Proven, not assumed:
--   * 'whatsapp', 'WHATSAPP' and ' whatsapp ' could all coexist as separate lead_source values.
--   * 'Direct Call' could coexist with the canonical 'direct_call'.
--   * A catalog value could be created under a catalog family that does not exist.
--   * Tenant B could NOT create a catalog code that Tenant A had already created -- the uniqueness
--     was global on (catalog_type_code, code) although the table is tenant-scoped, which both
--     breaks tenant extension and leaks the existence of another tenant's private value through
--     the unique-violation error.
--   * Customer identity matching is exact string equality, so 'Ahmed@Gmail.com' and
--     'ahmed@gmail.com' are two customers, and create_customer's in-tenant primary-phone
--     uniqueness guard is defeated by a single space.
--
-- SAFETY. All 569 existing catalog values and all 67 catalog types already satisfy the code format
-- (verified: 0 violations), and all 18 currencies already match ISO 4217 shape, so every CHECK
-- below is additive with no data migration. app.create_customer is the ONLY write path into
-- customers.primary_email / primary_phone and into customer_identity_signals.signal_value
-- (verified across all 91 migrations), so the normalization contract has exactly one enforcement
-- point plus the CHECK backstop.
--
-- DELIBERATELY NOT DONE HERE:
--   * Phone numbers are normalized for FORMATTING ONLY (whitespace, hyphens, parentheses, dots
--     removed). No country code is inferred and no E.164 conversion is performed, because choosing
--     a default country code is an open owner decision (finding PH8-3). This migration therefore
--     makes phone matching reliable without pre-empting that decision.
--   * nationalities.code is left unconstrained: its vocabulary (ISO 3166-1 alpha-2 with demonym
--     names, versus a separate demonym code set) is an open decision recorded as REF-1.

-- =============================================================================================
-- PART 1 — Controlled-vocabulary governance
-- =============================================================================================

-- 1a. Canonical code shape. This single rule is what makes 'WHATSAPP', ' whatsapp ' and
--     'Direct Call' impossible; it is the lowercase snake_case convention every seeded value
--     already follows, promoted from convention to constraint.
alter table public.catalog_types
    add constraint catalog_types_code_format_chk
    check (code ~ '^[a-z0-9_]+$');

alter table public.catalog_values
    add constraint catalog_values_code_format_chk
    check (code ~ '^[a-z0-9_]+$');

-- 1b. A catalog value must belong to a registered catalog family (finding CAT-1). catalog_types.code
--     is UNIQUE, so this single-column reference is mechanically possible -- ADR-0006's rationale
--     (a single column cannot reference catalog_values' COMPOSITE key) never applied to this link.
--     Referential actions follow ADR-0007's restrict/no-action default.
alter table public.catalog_values
    add constraint catalog_values_catalog_type_code_fkey
    foreign key (catalog_type_code) references public.catalog_types (code)
    on delete restrict on update no action;

-- 1c. Tenant-scoped uniqueness (finding CAT-2). The old constraint made a tenant-extendable catalog
--     effectively single-tenant. Split into two partial unique indexes:
--       * global/system values (tenant_id is null) stay unique per family, as before;
--       * a tenant's own values are unique within that tenant only.
alter table public.catalog_values drop constraint catalog_values_type_code_key;

create unique index catalog_values_global_code_key
    on public.catalog_values (catalog_type_code, code)
    where tenant_id is null;

create unique index catalog_values_tenant_code_key
    on public.catalog_values (tenant_id, catalog_type_code, code)
    where tenant_id is not null;

-- 1d. Reference-data code shape. These tables are platform-managed (authenticated holds SELECT
--     only), so the risk is a malformed seed rather than employee input -- but a seed is exactly
--     where 'Egypt' / 'egypt' / 'EG' variants would enter and become permanent foreign-key targets.
alter table public.countries
    add constraint countries_code_format_chk check (code ~ '^[A-Z]{2}$');

alter table public.currencies
    add constraint currencies_code_format_chk check (code ~ '^[A-Z]{3}$');

alter table public.languages
    add constraint languages_code_format_chk check (code ~ '^[a-z]{2}$');

-- =============================================================================================
-- PART 2 — Canonical input normalization for customer identity
-- =============================================================================================

-- 2a. One authority for each normalization rule, reused by the RPCs below. Both are IMMUTABLE so
--     they are safe in any expression context, and both are null-preserving: absent data stays
--     absent rather than becoming an empty string.
create or replace function app.normalize_email(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$ select nullif(lower(btrim(p_value)), '') $$;

create or replace function app.normalize_phone(p_value text)
returns text
language sql
immutable
set search_path = ''
as $$ select nullif(regexp_replace(btrim(p_value), '[[:space:]().-]', '', 'g'), '') $$;

-- PostgreSQL grants EXECUTE to PUBLIC on every new function by default. SPEC-124 established that
-- no app-schema function may be PUBLIC-executable, and test 10 enforces it -- so the revoke must be
-- part of creating a function here, not an afterthought. (This exact regression was caught by
-- test 10 when this migration was first run, which is the guard working as intended.)
revoke execute on function app.normalize_email(text) from public;
revoke execute on function app.normalize_phone(text) from public;
grant execute on function app.normalize_email(text) to authenticated;
grant execute on function app.normalize_phone(text) to authenticated;

-- 2b. The backstop. Even if a future write path forgets to normalize, the database refuses the row.
--     The rules are stated inline rather than by calling the helpers so the constraint carries no
--     function dependency; test 11 asserts the two definitions agree.
alter table public.customers
    add constraint customers_primary_email_normalized_chk
    check (
        primary_email is null
        or (primary_email = lower(btrim(primary_email))
            and primary_email !~ '[[:space:]]'
            and position('@' in primary_email) > 1)
    );

alter table public.customers
    add constraint customers_primary_phone_normalized_chk
    check (
        primary_phone is null
        or (primary_phone !~ '[[:space:]().-]' and primary_phone <> '')
    );

alter table public.customer_identity_signals
    add constraint customer_identity_signals_value_normalized_chk
    check (signal_value = btrim(signal_value) and signal_value <> '');

-- =============================================================================================
-- PART 3 — Apply normalization at the single write path
-- =============================================================================================

-- Body preserved verbatim from 202607044800 except for the normalization of phone/email/name
-- inputs at entry, which is what makes the duplicate guard and duplicate detection actually work.
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

    insert into public.customers (
        tenant_id, customer_type_code, first_name, family_name, full_name, company_name,
        primary_phone, primary_email, preferred_language_code, preferred_contact_method_code,
        marketing_opt_in, first_registered_branch_id, created_by
    )
    values (
        v_tenant, p_customer_type_code, v_first_name, v_family_name, v_full_name, v_company_name,
        v_phone, v_email, p_preferred_language_code, p_preferred_contact_method_code,
        p_marketing_opt_in, p_branch_id, v_actor
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

-- Matching must normalize its inputs the same way, or a correctly-stored customer would still be
-- missed when an employee types the number or address in a different but equivalent form.
create or replace function app.find_customer_duplicates(
    p_phone text default null,
    p_email text default null,
    p_whatsapp text default null,
    p_passport_number text default null,
    p_document_number text default null
)
returns table (customer_id uuid, full_name text, matched_signal_type text, matched_value text)
language sql
stable
security invoker
set search_path = ''
as $$
    with n as (
        select app.normalize_phone(p_phone)       as phone,
               app.normalize_email(p_email)       as email,
               app.normalize_phone(p_whatsapp)    as whatsapp,
               nullif(btrim(p_passport_number),'') as passport_number,
               nullif(btrim(p_document_number),'') as document_number
    )
    -- direct profile fields
    select c.id, c.full_name, 'phone'::text, c.primary_phone
    from public.customers c, n
    where c.is_archived = false and n.phone is not null and c.primary_phone = n.phone
    union
    select c.id, c.full_name, 'email'::text, c.primary_email
    from public.customers c, n
    where c.is_archived = false and n.email is not null and c.primary_email = n.email
    union
    -- recorded identity signals
    select c.id, c.full_name, s.signal_type_code, s.signal_value
    from public.customer_identity_signals s
    join public.customers c on c.id = s.customer_id and c.is_archived = false
    cross join n
    where (s.signal_type_code in ('phone','whatsapp') and s.signal_value = n.phone)
       or (s.signal_type_code in ('phone','whatsapp') and s.signal_value = n.whatsapp)
       or (s.signal_type_code = 'email' and s.signal_value = n.email)
       or (s.signal_type_code = 'passport_number' and s.signal_value = n.passport_number)
       or (s.signal_type_code = 'official_document_number' and s.signal_value = n.document_number);
$$;
