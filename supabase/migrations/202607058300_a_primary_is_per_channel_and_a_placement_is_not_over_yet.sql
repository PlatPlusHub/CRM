-- API-3 customer-data family. Three defects, each reproduced before it was fixed, each resolved
-- against a rule this repository had already written down rather than one invented here.
--
-- ================================================================================================
-- CM-1 (Medium) -- "primary" was demoted across ALL channels, not within one.
--
-- `202607052100_duplicate_prevention.sql` states the rule when it creates the index:
-- *"Two primary PHONES for one customer is not a duplicate record but it is the same class of
-- defect"* -- and it encodes that per channel:
-- `customer_contact_methods_one_primary_per_type_idx (tenant_id, customer_id, contact_method_type_code) WHERE is_primary`.
-- One primary PER TYPE. The model agrees elsewhere: `customers` carries `primary_phone` AND
-- `primary_email` as separate columns, and canon 05 speaks only of "one primary phone number".
--
-- `app.add_customer_contact_method` demoted without a type filter. REPRODUCED as an `employee`
-- holding CREATE_CUSTOMER: adding a primary EMAIL silently set the customer's primary PHONE to
-- `is_primary = false`, leaving exactly one primary across all channels where the index permits one
-- per channel. `app.merge_customer_identity` reads `is_primary` when it decides which contact
-- methods survive a merge, so the flag is consumed, not decorative.
--
-- Fixed in the function, because the function's own UPDATE is what is over-broad. Nothing else sets
-- `is_primary = true`; the index already constrains the direct path correctly, per channel.
--
-- ================================================================================================
-- CM-2 (High) -- the canonical form was enforced on `customers` and not on its contact-method sibling,
-- and the migration that built the guard said otherwise.
--
-- `202607052100` also claims: *"`app.add_customer_contact_method` already normalizes ... and already
-- checks for an existing row. THE INDEX IS WHAT MAKES THAT CHECK HOLD UNDER CONCURRENCY AND ON THE
-- DIRECT PATH."* **That sentence is false.** `customer_contact_methods_unique_value_idx` indexes the
-- RAW `value` column, so on the direct path a denormalized string is simply a different string and
-- the index has nothing to collapse.
--
-- REPRODUCED, and the comparison is what makes it a defect rather than an opinion: the RPC stored
-- `mona@example.com`; a direct INSERT of `'  MONA@example.com  '` **succeeded**, leaving TWO rows for
-- one logical address on one customer and one channel. The identical denormalized value applied to
-- `customers.primary_email` was **REFUSED** by `customers_primary_email_normalized_chk`. The same
-- rule, from the same SPEC-126 family that the RPC's own comment cites, was enforced on one table
-- and not on the other.
--
-- Consumer impact, measured: `app.merge_customer_identity` decides which contact methods to delete
-- by comparing `t.value = s.value`. A denormalized twin is invisible to that comparison, which is
-- CUST-1's family of failure -- a comparison that silently matches nothing.
--
-- Enforcement layer: a CHECK, mirroring `customers`, because the invariant is decidable from the
-- single row. It REUSES `app.normalize_email` / `app.normalize_phone` rather than restating their
-- logic -- both are IMMUTABLE (verified), which is what makes them legal in a constraint, and reusing
-- them keeps one definition of the canonical form instead of a third copy. The `is not null` guard is
-- deliberate: both helpers return NULL for a blank input, and `value = NULL` is NULL, which a CHECK
-- treats as satisfied -- so without it a whitespace-only value would pass.
--
-- Every legal writer checked FIRST: `app.add_customer_contact_method` normalizes already;
-- `app.merge_customer_identity` only DELETEs exact duplicates and sets `is_primary = false`, and
-- never writes `value`. Existing rows counted: 0 violations.
--
-- ================================================================================================
-- PLACE-1 (High) -- a scheduled transfer silently stopped recording the registering branch.
--
-- `app.current_placement()` matched `ends_at is null` only. A primary placement carrying a FUTURE
-- `ends_at` -- an employee scheduled to transfer, which canon 03 explicitly provides for
-- ("Temporary transfer to another branch / Permanent transfer to another branch") -- is still the
-- placement the employee is in today, and the function returned NOTHING for it.
--
-- That function has FIVE consumers: `create_customer`, `create_quotation`, `create_complaint`,
-- `create_service_request` and `start_conversation`. Every one of them does
-- `select cp.branch_id, cp.department_id into v_branch, v_dept from app.current_placement() cp`, so
-- an empty result is not an error -- it is a silent NULL.
--
-- REPRODUCED end to end: an `owner` holding MANAGE_USERS set `ends_at = now() + 30 days` through the
-- door RLS already permits (`scope_update`); `app.current_placement()` returned **0 rows**; and the
-- next customer that employee registered was stored with **first_registered_branch_id NULL** --
-- re-creating precisely what `app.create_customer`'s own comment says it had fixed: *"Leaving it null
-- was how canon 03's requirement quietly went unrecorded."* canon 03: *"The system must record which
-- branch first registered a customer."*
--
-- The repository already contains the better answer to the same question: `app.eligible_lead_handlers`
-- (LEAD-3) tests `starts_at <= now() and (ends_at is null or ends_at > now())`. Under that window the
-- same fixture returns 1 row.
--
-- THE FIX IS STRICTLY ADDITIVE, and that is a deliberate choice rather than a cautious one. Widening
-- the window introduces an ambiguity the old predicate could not have: `user_branch_assignments_one_primary_idx`
-- is `UNIQUE (tenant_id, user_id) WHERE (is_primary AND ends_at IS NULL)`, so it guarantees at most
-- one OPEN-ENDED primary placement and cannot guarantee anything about one that is merely still
-- valid -- and it structurally cannot be widened, because a partial-index predicate may not call
-- `now()`. So the ordering resolves it by preferring the open-ended row: whenever today's answer
-- exists it is returned unchanged, and the new branch only fills the case where today returns
-- nothing. `starts_at` is deliberately NOT added -- excluding a not-yet-started placement would
-- change behaviour in a case no evidence showed to be harmful. Recorded as PLACE-2, UNPROVEN.

-- ------------------------------------------------------------------------------------------------
-- CM-1
-- ------------------------------------------------------------------------------------------------
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

    perform app.record_event(
        v_tenant, 'customer_contact_added', 'customer', p_customer_id,
        (select id from public.users where auth_user_id = (select auth.uid()) and tenant_id = v_tenant),
        null, null, null,
        jsonb_build_object('contact_method_id', v_id,
                           'contact_method_type_code', p_contact_method_type_code),
        'info');
    return v_id;
end;
$fn$;

-- ------------------------------------------------------------------------------------------------
-- CM-2
-- ------------------------------------------------------------------------------------------------
alter table public.customer_contact_methods
    add constraint customer_contact_methods_value_normalized_check
    check (
        case
            when contact_method_type_code = 'email'
                then app.normalize_email(value) is not null
                     and value = app.normalize_email(value)
            when contact_method_type_code in ('primary_phone','secondary_phone','whatsapp')
                then app.normalize_phone(value) is not null
                     and value = app.normalize_phone(value)
            else btrim(value) <> '' and value = btrim(value)
        end
    );

comment on constraint customer_contact_methods_value_normalized_check on public.customer_contact_methods is
    'CM-2: the canonical form is enforced on the TABLE, not only inside app.add_customer_contact_method. 202607052100 claimed customer_contact_methods_unique_value_idx made the duplicate check hold "on the direct path"; it does not, because that index covers the RAW value, so a denormalized string is simply a different string. Reproduced: two rows for one logical email on one customer and channel, while the identical value was refused on customers.primary_email.';

-- ------------------------------------------------------------------------------------------------
-- PLACE-1
-- ------------------------------------------------------------------------------------------------
create or replace function app.current_placement()
returns table(branch_id uuid, department_id uuid)
language sql
stable
security definer
set search_path = ''
as $fn$
    select uba.branch_id, uba.department_id
    from public.user_branch_assignments uba
    where uba.user_id = app.current_user_id()
      and uba.tenant_id = app.current_tenant_id()
      and uba.is_primary
      -- PLACE-1: a placement scheduled to END is still the placement the employee is in today.
      and (uba.ends_at is null or uba.ends_at > now())
    -- Open-ended first, so the answer is unchanged wherever the old predicate had one:
    -- user_branch_assignments_one_primary_idx guarantees at most one row with ends_at IS NULL, and
    -- can guarantee nothing about a merely-still-valid row (a partial index may not call now()).
    order by (uba.ends_at is null) desc, uba.starts_at desc, uba.branch_id
    limit 1
$fn$;

comment on function app.current_placement() is
    'PLACE-1: matches a primary placement that has not ended yet, not only one with ends_at IS NULL. A scheduled transfer (canon 03) used to make this return nothing, and its five consumers -- create_customer, create_quotation, create_complaint, create_service_request, start_conversation -- all read it with SELECT INTO, so an empty result silently became a NULL branch. SECURITY DEFINER is retained and safe: the row is selected by app.current_user_id(), so it cannot return another user''s placement.';
