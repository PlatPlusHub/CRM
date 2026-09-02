-- SUP-4a -- a ceiling with no currency is not an amount.
--
-- The owner asked for the supplier credit-limit ENFORCEMENT defect to be resolved, and instructed
-- that if no authoritative exposure definition exists then a NARROWER rule should be implemented if
-- one can be without inventing business semantics. Exhausting the evidence found one, and it is a
-- schema defect rather than a business question.
--
-- THE MEASUREMENT THAT SETTLES IT. Eleven `public` tables carry a money-amount column. Ten of them
-- carry `currency_code` beside it. **`suppliers` is the only one that does not** -- and canon 30's
-- money standard is explicit:
--
--     "Amounts should be stored as numeric, not floating point."   amount numeric(19, 4)
--     "Currency code should be stored separately."                 currency_code text not null
--     "`currency_code` values must reference `currencies.code`"
--
-- So `suppliers.credit_limit_amount` is not an undecided business rule waiting on the owner; it is
-- ORVION's own money standard, unapplied to exactly one column. That is derivable from canon, which
-- is why it is fixed here rather than referred upward.
--
-- WHY THIS IS THE THING BLOCKING ENFORCEMENT, and not a tidy-up. `app.supplier_balance` returns
-- `outstanding_payable` **one row per currency** -- reproduced live as EGP 8,000 and USD 600 for one
-- supplier -- while the ceiling was a single currency-less scalar. "Is 8,000 EGP + 600 USD over
-- 10,000?" was unanswerable, and it was unanswerable because the ceiling did not say what it was
-- denominated in. With the currency present the comparison is well-formed for the currency the limit
-- names, and undefined for no currency at all.
--
-- HOW ORVION ALREADY COMPARES A BALANCE TO A RULE -- copied, not invented. `app.advance_booking`
-- (ADR-0020) is the shipped precedent for constraining an operation on a balance:
--     * it reads the PER-CURRENCY balance function and evaluates `bool_or(outstanding > 0)`,
--       comparing currency to currency and **never converting** -- which is exactly why no exchange
--       rate is introduced here, and why `tenants.default_currency_code` is NOT pressed into service
--       as a base currency (it has a producer and, measured, no consumer at all);
--     * it does not refuse outright -- it requires an override permission and records a `risk` event.
-- That precedent answers the FORM of a ceiling rule. It does not answer whether the supplier ceiling
-- IS such a rule, which operation it constrains, or what may override it -- and canon names no
-- operation, no override permission and no supplier-credit event type. Those three remain owner
-- decisions and are recorded as **SUP-4b**; inventing them is what this migration refuses to do.
--
-- WHAT THIS MIGRATION THEREFORE DOES: it makes the ceiling a well-formed monetary amount, which is
-- the precondition for any enforcement rule the owner later chooses, and it enforces the standard
-- rather than merely documenting it. It does NOT enforce the ceiling.
--
-- NO BACKFILL DECISION IS TAKEN. The column is nullable, and a CHECK requires it exactly when an
-- amount is present, so existing rows are unaffected: Primary holds zero business rows and local
-- fixtures set no limits. Nobody's data is assigned a currency it did not state -- the constraint
-- binds from here forward.

alter table public.suppliers
    add column if not exists credit_limit_currency_code text
        -- ON DELETE RESTRICT per the Referential Action Standard (`verify_database.sql` CHECK 7),
        -- which caught the default NO ACTION on the first run, and which every other currency FK
        -- in the schema already follows.
        references public.currencies(code) on delete restrict;

-- The standard is "currency_code not null" beside an amount. A plain NOT NULL would be wrong here
-- because the AMOUNT itself is nullable (a supplier may have no credit terms at all), so the rule is
-- expressed as the conditional form of the same standard: present exactly when the amount is.
alter table public.suppliers
    drop constraint if exists suppliers_credit_limit_currency_check;
alter table public.suppliers
    add constraint suppliers_credit_limit_currency_check
        check ((credit_limit_amount is null) = (credit_limit_currency_code is null));

comment on column public.suppliers.credit_limit_currency_code is
'The currency the credit ceiling is denominated in (canon 30 money standard: "Currency code should '
'be stored separately", referencing currencies.code). SUP-4a. Comparison against '
'app.supplier_balance is per-currency, never converted -- the shipped precedent in '
'app.advance_booking / ADR-0020. Whether the ceiling REFUSES an operation is SUP-4b, an open owner '
'decision; this column only makes the amount well-formed.';

-- =================================================================================================
-- The two guards must now treat the ceiling as the PAIR it has become. Without this, setting a limit
-- -- which necessarily writes both columns in one statement -- would stop being a credit-only write
-- and would start demanding ASSIGN_SUPPLIER, silently undoing the owner's SUP-3 rule for any actor
-- who holds MANAGE_SUPPLIER_CREDIT without supplier administration. The row-image comparison was
-- built to fail in exactly this safe direction, and this is the deliberate follow-up it expects.
-- =================================================================================================
create or replace function app.guard_supplier_credit_authority()
returns trigger
language plpgsql
set search_path = ''
as $FN$
begin
    -- Platform/system paths (canon 35 principle 6), identical to every sibling guard.
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'INSERT'
       and new.credit_limit_amount is null
       and new.credit_limit_currency_code is null then
        return new;
    end if;

    -- SUP-4a: the currency is part of the ceiling. Re-denominating a limit from EGP to USD changes
    -- what the agency may owe just as surely as changing the number, so it costs the same permission.
    if tg_op = 'UPDATE'
       and new.credit_limit_amount is not distinct from old.credit_limit_amount
       and new.credit_limit_currency_code is not distinct from old.credit_limit_currency_code then
        return new;
    end if;

    perform app.authorize('MANAGE_SUPPLIER_CREDIT');

    return new;
end;
$FN$;

revoke all on function app.guard_supplier_credit_authority() from public;

create or replace function app.guard_write_capability()
returns trigger
language plpgsql
set search_path = ''
as $FN$
declare
    v_perms  text[];
    v_extra  text[];
    v_perm   text;
    v_held   text;
    v_strict boolean := false;
    v_relationship_ok boolean := false;
    v_credit_only boolean := false;
begin
    -- Platform/system paths (canon 35 principle 6), as in every other guard here.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- 202607058500 (LIC-3 / PP-4): `documents` is resolved in its OWN statement, not inside the
    -- shared CASE below. A record field reference is resolved against the ACTUAL record type at
    -- execution, so naming `new.document_type_code` inside an expression this trigger also evaluates
    -- for `customers`, `leads` and twenty other tables fails on every one of them.
    if tg_table_name = 'documents' then
        if new.document_type_code = 'payment_proof' then
            v_perms := array['MANAGE_TENANT_SETTINGS'];
            v_strict := true;
        else
            v_perms := array['UPLOAD_DOCUMENT'];
        end if;
    else
    v_perms := case tg_table_name
                   when 'approval_requests'         then array['CREATE_BOOKING_ITEM']
                   when 'conversation_messages'     then array['SEND_MESSAGE']
                   when 'customer_contact_methods'  then array['CREATE_CUSTOMER']
                   when 'customer_identity_signals' then array['CREATE_CUSTOMER']
                   when 'customer_identity_merges'  then array['MERGE_CUSTOMER_IDENTITY']
                   when 'internal_supplier_links'   then array['ASSIGN_SUPPLIER']
                   when 'offline_conversions'       then array['MANAGE_MARKETING_CAMPAIGN']
                   when 'document_links'            then array['UPLOAD_DOCUMENT','MANAGE_TENANT_SETTINGS']
                   when 'lead_assignments'          then array['ASSIGN_LEAD','REASSIGN_LEAD']
                   when 'branch_business_hours'     then array['MANAGE_BRANCHES']
                   when 'holidays'                  then array['MANAGE_BRANCHES','MANAGE_TENANT_SETTINGS']
                   when 'financial_accounts'        then array['CREATE_JOURNAL_ENTRY']
                   when 'company_assets'            then array['CREATE_JOURNAL_ENTRY']
                   when 'bookings'                  then array['CREATE_BOOKING']
                   when 'complaints'                then array['CREATE_COMPLAINT']
                   when 'conversations'             then array['SEND_MESSAGE']
                   when 'customer_notes'            then array['CREATE_CUSTOMER']
                   when 'customers'                 then array['CREATE_CUSTOMER']
                   when 'leads'                     then array['CREATE_LEAD']
                   when 'passengers'                then array['CREATE_BOOKING_ITEM']
                   when 'quotations'                then array['CREATE_QUOTATION']
                   when 'service_requests'          then array['CREATE_SERVICE_REQUEST']
                   when 'suppliers'                 then array['ASSIGN_SUPPLIER']
                   when 'tasks'                     then array['CREATE_TASK']
               end;
    end if;

    -- 202607059100 (SEC-1c): on UPDATE the object-class permission is joined by the permissions canon
    -- already says may MUTATE this object.
    if tg_op = 'UPDATE' and not v_strict then
        v_extra := case tg_table_name
                       when 'approval_requests'  then array['APPROVE_FINANCE','REVIEW_APPROVAL_REQUEST','REVIEW_SUBSCRIPTION_PAYMENT']
                       when 'bookings'           then array['APPROVE_BOOKING','CANCEL_BOOKING','ISSUE_BOOKING','REFUND_BOOKING','REISSUE_BOOKING']
                       when 'complaints'         then array['RESOLVE_COMPLAINT']
                       when 'conversations'      then array['CLOSE_CONVERSATION','ESCALATE_CONVERSATION']
                       when 'customers'          then array['MERGE_CUSTOMER_IDENTITY']
                       when 'documents'          then array['ARCHIVE_DOCUMENT','CREATE_DOCUMENT_VERSION']
                       when 'leads'              then array['ASSIGN_LEAD','CLOSE_LEAD','REASSIGN_LEAD']
                       when 'quotations'         then array['ACCEPT_QUOTATION','SEND_QUOTATION']
                       when 'service_requests'   then array['RESOLVE_SERVICE_REQUEST']
                       when 'tasks'              then array['ASSIGN_TASK','COMPLETE_TASK']
                       else null
                   end;
        if v_extra is not null then
            v_perms := v_perms || v_extra;
        end if;
    end if;

    -- SUP-3, widened by SUP-4a: the ceiling is now the PAIR (amount, currency), so a write that
    -- touches only those two is still a credit-only write. Excluding both from the row image is what
    -- keeps "set a limit of 10,000 EGP" -- which must write both columns -- costing
    -- MANAGE_SUPPLIER_CREDIT rather than silently reverting to ASSIGN_SUPPLIER.
    if tg_op = 'UPDATE' and tg_table_name = 'suppliers' then
        v_credit_only := (new.credit_limit_amount is distinct from old.credit_limit_amount
                          or new.credit_limit_currency_code is distinct from old.credit_limit_currency_code)
                         and (to_jsonb(new) - 'credit_limit_amount' - 'credit_limit_currency_code' - 'updated_at')
                           = (to_jsonb(old) - 'credit_limit_amount' - 'credit_limit_currency_code' - 'updated_at');
        if v_credit_only then
            v_perms := array['MANAGE_SUPPLIER_CREDIT'];
        end if;
    end if;

    -- The handler rule, evaluated ONLY inside its own table branch so `new.assigned_user_id` is
    -- never named while this trigger is serving `suppliers` or `customers`.
    if tg_op = 'UPDATE' and tg_table_name = 'leads' then
        v_relationship_ok := (select app.current_user_id()) is not null
                             and (select app.current_user_id()) in (new.assigned_user_id, new.owner_user_id);
    end if;

    if v_relationship_ok then
        return new;
    end if;

    if v_perms is null then
        raise exception 'guard_write_capability has no permission mapping for %', tg_table_name
            using errcode = 'insufficient_privilege';
    end if;

    foreach v_perm in array v_perms loop
        if app.has_permission(v_perm) then
            v_held := v_perm;
            exit;
        end if;
    end loop;

    if v_held is null then
        raise exception 'permission denied: one of % is required to write %',
                        array_to_string(v_perms, ' or '), tg_table_name
            using errcode = 'insufficient_privilege';
    end if;

    perform app.authorize(v_held);
    return new;
end;
$FN$;

revoke all on function app.guard_write_capability() from public;

-- =================================================================================================
-- `app.create_supplier` gains the currency alongside the amount. The parameter is added at the END
-- and defaults to NULL, so every existing caller -- the two HTTP suites, test 19, and any future n8n
-- client -- keeps working unchanged; only a caller that actually sets a limit must now say in what.
-- =================================================================================================
create or replace function app.create_supplier(
    p_name text,
    p_supplier_type_code text,
    p_phone text default null,
    p_email text default null,
    p_payment_term_code text default null,
    p_credit_limit_amount numeric default null,
    p_credit_limit_currency_code text default null
)
returns uuid
language plpgsql
set search_path = ''
as $FN$
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
    -- SUP-4a: refuse the ill-formed amount explicitly rather than letting the CHECK report it, so the
    -- caller is told which of the two it omitted.
    if (p_credit_limit_amount is null) <> (p_credit_limit_currency_code is null) then
        raise exception 'a credit limit needs both an amount and a currency (canon 30 money standard)'
            using errcode = 'check_violation';
    end if;

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
        tenant_id, supplier_type_code, name, phone, email, payment_term_code,
        credit_limit_amount, credit_limit_currency_code
    ) values (
        v_tenant, p_supplier_type_code, v_name, v_phone, v_email, p_payment_term_code,
        p_credit_limit_amount, p_credit_limit_currency_code
    ) returning id into v_id;

    perform app.record_event(
        v_tenant, 'supplier_created', 'supplier', v_id,
        (select id from public.users where auth_user_id = (select auth.uid()) and tenant_id = v_tenant),
        null, null, null,
        jsonb_build_object('supplier_type_code', p_supplier_type_code, 'name', v_name),
        'info');
    return v_id;
end;
$FN$;

-- The 6-argument overload is DROPPED rather than left beside the new one. SPEC-156's lesson: a stale
-- overload that silently ignores what a caller passes is a misleading contract, and PostgREST would
-- otherwise have two candidates to resolve between.
drop function if exists app.create_supplier(text, text, text, text, text, numeric);

revoke all on function app.create_supplier(text, text, text, text, text, numeric, text) from public;
grant execute on function app.create_supplier(text, text, text, text, text, numeric, text) to authenticated;

-- The gated reader reports the currency too, and BOTH functions have to be dropped first: a
-- `create or replace` cannot widen a `RETURNS TABLE`, and the `public` wrapper depends on the `app`
-- one. Dropping in dependency order and recreating both is the only correct move here.
drop function if exists public.supplier_credit(uuid);
drop function if exists app.supplier_credit(uuid);

-- The gated reader reports the currency too: a ceiling amount without its denomination is exactly the
-- ill-formed value this migration exists to end, and a reader that returned one would reintroduce it
-- at the API.
create or replace function app.supplier_credit(p_supplier_id uuid)
returns table(credit_limit_amount numeric, credit_limit_currency_code text, permitted boolean)
language plpgsql
stable
security definer
set search_path = ''
as $FN$
declare
    v_tenant uuid := app.current_tenant_id();
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    -- The row must be visible to the CALLER, not merely to this DEFINER function.
    if not exists (select 1 from public.suppliers s
                    where s.id = p_supplier_id and s.tenant_id = v_tenant) then
        raise exception 'supplier is not in your tenant' using errcode = '42501';
    end if;

    if not app.has_permission('VIEW_FINANCIAL_DOCUMENTS') then
        return query select null::numeric, null::text, false;
        return;
    end if;

    return query
    select s.credit_limit_amount, s.credit_limit_currency_code, true
    from public.suppliers s
    where s.id = p_supplier_id and s.tenant_id = v_tenant;
end;
$FN$;

revoke all on function app.supplier_credit(uuid) from public;
grant execute on function app.supplier_credit(uuid) to authenticated;

-- The `public` wrappers move with them (API-1's model: the wrapper adds reachability and zero
-- authority, never SECURITY DEFINER, search_path pinned).
create function public.supplier_credit(p_supplier_id uuid)
returns table(credit_limit_amount numeric, credit_limit_currency_code text, permitted boolean)
language sql
stable
set search_path = ''
as $FN$ select * from app.supplier_credit(p_supplier_id) $FN$;

-- A freshly CREATEd function gets PostgreSQL's default EXECUTE to PUBLIC -- the replaced ones had
-- been revoked years ago and the drop took that with them. `10_grant_model_test` assertions 5 and 7
-- caught exactly this, which is what those class guards exist for.
revoke all on function public.supplier_credit(uuid) from public;
grant execute on function public.supplier_credit(uuid) to authenticated;

drop function if exists public.create_supplier(text, text, text, text, text, numeric);

create function public.create_supplier(
    p_name text,
    p_supplier_type_code text,
    p_phone text default null,
    p_email text default null,
    p_payment_term_code text default null,
    p_credit_limit_amount numeric default null,
    p_credit_limit_currency_code text default null
)
returns uuid
language sql
set search_path = ''
as $FN$ select app.create_supplier(p_name => p_name, p_supplier_type_code => p_supplier_type_code,
                                   p_phone => p_phone, p_email => p_email,
                                   p_payment_term_code => p_payment_term_code,
                                   p_credit_limit_amount => p_credit_limit_amount,
                                   p_credit_limit_currency_code => p_credit_limit_currency_code); $FN$;

revoke all on function public.create_supplier(text, text, text, text, text, numeric, text) from public;
grant execute on function public.create_supplier(text, text, text, text, text, numeric, text) to authenticated;
