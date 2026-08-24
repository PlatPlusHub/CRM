-- Migration: duplicate_prevention
-- Plan reference: SPEC-142. Puts a database constraint behind every duplicate rule the system
-- already believed it had, and adds the ones the integration layer will depend on.
--
-- WHAT WAS ACTUALLY PROTECTING THESE. In every case below the rule existed only inside an RPC as a
-- check-then-insert: `select ... if found then raise ... else insert`. That has two holes, and they
-- are different holes:
--
--   * A direct PostgREST write skips the RPC entirely, so the rule simply does not run.
--   * Two concurrent RPC calls both run the SELECT before either runs the INSERT, both find nothing,
--     and both insert. No amount of care inside the function closes this -- only a unique index does.
--     The owner's directive asks for exactly this case by name ("race/concurrent duplicate where
--     applicable"), and it is the one a busy branch actually hits: two employees answering the same
--     WhatsApp enquiry at the same moment.
--
-- The RPC checks are all LEFT IN PLACE. They produce a clear, actionable error before the write is
-- attempted; the index is the guarantee underneath. That is not duplication of a rule -- it is a
-- validation and a constraint doing their separate jobs.
--
-- WHAT IS DELIBERATELY NOT CONSTRAINED. `passengers.passport_number` looks like an obvious unique
-- key and is not one: the same traveller can legitimately appear under two customers (a corporate
-- account and their own personal account both booking the same person), and a unique index would
-- block a real booking rather than a mistake. Detection is the right tool there and already exists --
-- `app.find_customer_duplicates` matches on passport. The owner's directive draws this line
-- explicitly: "Do not create over-restrictive UNIQUE constraints that block legitimate business
-- activity."

-- ---------------------------------------------------------------------------------------------
-- 1. Customer primary phone -- canon 05, with its exception made explicit.
--
-- Canon 05: "The primary phone number is a major identity signal and must be unique inside the
-- company unless an approved exception exists." Both halves matter. A plain unique index would
-- enforce the rule and forbid the exception; `app.create_customer`'s `p_allow_duplicate` allowed the
-- exception and enforced nothing.
--
-- The flag makes the exception a recorded fact rather than an invisible one. Before this, an
-- "approved exception" left no trace at all -- you could not tell a deliberate duplicate from an
-- accident after the fact. Rows carrying it are excluded from the index; everything else is unique.
-- ---------------------------------------------------------------------------------------------
alter table public.customers
    add column if not exists duplicate_phone_approved boolean not null default false;

comment on column public.customers.duplicate_phone_approved is
    'Canon 05 permits a duplicate primary phone when an approved exception exists. This records that the exception was taken, so a deliberate duplicate is distinguishable from an accident.';

create unique index customers_unique_primary_phone_idx
    on public.customers (tenant_id, primary_phone)
    where primary_phone is not null
      and not is_archived
      and not duplicate_phone_approved;

-- ---------------------------------------------------------------------------------------------
-- 2. Contact methods -- the same value twice on the same customer is always an accident.
--
-- `app.add_customer_contact_method` already normalizes (so 'Ahmed@Gmail.com' and 'ahmed@gmail.com'
-- are one value) and already checks for an existing row. The index is what makes that check hold
-- under concurrency and on the direct path.
-- ---------------------------------------------------------------------------------------------
create unique index customer_contact_methods_unique_value_idx
    on public.customer_contact_methods (tenant_id, customer_id, contact_method_type_code, value);

-- "Primary" is a singular word. Two primary phones for one customer is not a duplicate record but it
-- is the same class of defect: an ambiguous answer to a question the system will be asked.
create unique index customer_contact_methods_one_primary_per_type_idx
    on public.customer_contact_methods (tenant_id, customer_id, contact_method_type_code)
    where is_primary;

-- ---------------------------------------------------------------------------------------------
-- 3. Organization and master data.
--
-- Two departments called "Sales" in one branch, or two suppliers called "Egypt Air", are the
-- duplicates an employee creates by not finding the existing one first. Archived rows are excluded
-- so a name can be retired and reused.
-- ---------------------------------------------------------------------------------------------
create unique index departments_unique_name_per_branch_idx
    on public.departments (tenant_id, branch_id, name)
    where is_active;

create unique index suppliers_unique_name_idx
    on public.suppliers (tenant_id, name)
    where not is_archived;

-- ---------------------------------------------------------------------------------------------
-- 4. Integration idempotency. These three are not CRM hygiene -- they are what stops an external
--    system's retry from becoming a second record, and n8n's delivery contract is at-least-once.
-- ---------------------------------------------------------------------------------------------

-- A Google Ads campaign synced twice must be one campaign, not two.
create unique index marketing_campaigns_unique_external_idx
    on public.marketing_campaigns (tenant_id, platform_code, external_campaign_id)
    where external_campaign_id is not null;

-- A click identifier names ONE click. `app.capture_attribution_click` inserts unconditionally, so a
-- replayed tag fire or webhook retry created a second click row -- and because
-- `app.map_outcomes_to_conversions` joins leads to their attribution click, a duplicated click is a
-- path to a duplicated conversion being reported to Google. Each identifier gets its own partial
-- index because a click carries exactly one of the three.
create unique index attribution_clicks_unique_gclid_idx
    on public.attribution_clicks (tenant_id, gclid) where gclid is not null;
create unique index attribution_clicks_unique_gbraid_idx
    on public.attribution_clicks (tenant_id, gbraid) where gbraid is not null;
create unique index attribution_clicks_unique_wbraid_idx
    on public.attribution_clicks (tenant_id, wbraid) where wbraid is not null;

-- A WhatsApp thread replayed by the provider must resolve to the existing conversation, not open a
-- second one alongside it.
create unique index conversations_unique_external_idx
    on public.conversations (tenant_id, channel_code, external_conversation_id)
    where external_conversation_id is not null;

-- ---------------------------------------------------------------------------------------------
-- 5. Exchange rates -- ambiguity here is a financial defect, not a tidiness one.
--
-- Rate lookup is "the latest rate for this pair at or before this moment". Two rows for the same
-- pair at the same instant make that question have two answers, and whichever the planner returns
-- first silently decides what a booking cost. Nothing prevented it.
-- ---------------------------------------------------------------------------------------------
create unique index exchange_rates_unique_pair_instant_idx
    on public.exchange_rates (tenant_id, from_currency_code, to_currency_code, effective_at);

-- ---------------------------------------------------------------------------------------------
-- 6. Teach app.create_customer to record the exception it was already permitting.
--
-- Only two lines change: the declaration and the insert. Without this, `p_allow_duplicate => true`
-- would now be rejected by the index it is supposed to be exempt from -- the flag is what carries
-- the exemption.
-- ---------------------------------------------------------------------------------------------
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

    -- Primary-phone uniqueness (05). This check survives for the error message; the partial unique
    -- index added by SPEC-142 is what makes it true under concurrency and on the direct path.
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
        marketing_opt_in, first_registered_branch_id, first_registered_user_id, created_by,
        duplicate_phone_approved
    )
    values (
        v_tenant, p_customer_type_code, v_first_name, v_family_name, v_full_name, v_company_name,
        v_phone, v_email, p_preferred_language_code, p_preferred_contact_method_code,
        p_marketing_opt_in, v_branch, v_actor, v_actor,
        p_allow_duplicate and v_phone is not null
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
