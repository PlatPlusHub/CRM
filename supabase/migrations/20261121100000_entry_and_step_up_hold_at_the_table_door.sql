-- B6-EXIT bundle A: three entry and step-up holes at the table door, each reproduced at 73b02a1 in
-- rolled-back transactions on the local stack, each closed by reusing a mechanism already in force.
--   * ARCH-2: an employee without ARCHIVE_RECORD inserted archived leads, quotations and booking
--     items, and an active row naming a forged archived_by; an aal2 finance user inserted an
--     archived invoice with archived_by forged and archived_at backdated a year. SPEC-319 already
--     made app.enforce_archive_authority judge INSERT; these four attachments still fired on UPDATE
--     only. They are re-attached BEFORE INSERT OR UPDATE on the unchanged function.
--   * STEPUP-1: an aal1 owner inserted campaign_daily_metrics (spend 0, revenue 5,000,000) while the
--     same session was refused the parent campaign update for missing MFA; an aal1 finance_manager
--     inserted an exchange_rate_adjustment that then blocked an aal2 correction of the cited rate.
--     Both tables gain the arm of app.guard_write_capability that CAMP-3 and BRANCH-1 use, priced at
--     the permission each table's RLS write check already demands, so app.authorize adds only the
--     role's MFA requirement. No RPC writes either table.
--   * ENTRY-1 (booking_items): the employee refused by app.advance_booking_item for a finance-gated
--     item inserted that item already in_progress with no approval, and a completed item with
--     completed_at backdated 400 days; neither emitted a lifecycle event. app.create_booking_item,
--     the only inserter, writes 'draft' and no lifecycle stamp. A signed-in caller is now held to
--     the same entry, SPEC-239's bookings rule; session-less platform paths stay exempt, as
--     app.enforce_status_transition already exempts them from the whole graph.
-- NOT CHANGED: every grant, policy, permission, RLS check, event producer and RPC; the permission
-- mapping of every other table; CAMP-2, JE-2 and the other STEPUP-1 candidates.

create or replace trigger leads_enforce_archive_authority
before insert or update on public.leads
for each row execute function app.enforce_archive_authority();

create or replace trigger quotations_enforce_archive_authority
before insert or update on public.quotations
for each row execute function app.enforce_archive_authority();

create or replace trigger booking_items_enforce_archive_authority
before insert or update on public.booking_items
for each row execute function app.enforce_archive_authority();

create or replace trigger invoices_enforce_archive_authority
before insert or update on public.invoices
for each row execute function app.enforce_archive_authority();

CREATE OR REPLACE FUNCTION app.guard_write_capability()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
    v_perms  text[];
    v_extra  text[];
    v_perm   text;
    v_held   text;
    v_strict boolean := false;
    v_relationship_ok boolean := false;
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
                   when 'booking_item_passengers'   then array['CREATE_BOOKING_ITEM']
                   when 'booking_items'             then array['CREATE_BOOKING_ITEM']
                   when 'conversation_messages'     then array['SEND_MESSAGE']
                   when 'customer_contact_methods'  then array['CREATE_CUSTOMER']
                   when 'customer_identity_signals' then array['CREATE_CUSTOMER']
                   when 'customer_identity_merges'  then array['MERGE_CUSTOMER_IDENTITY']
                   when 'internal_supplier_links'   then array['ASSIGN_SUPPLIER']
                   when 'offline_conversions'       then array['MANAGE_MARKETING_CAMPAIGN']
                   when 'marketing_campaigns'       then array['MANAGE_MARKETING_CAMPAIGN']
                   when 'campaign_daily_metrics'    then array['MANAGE_MARKETING_CAMPAIGN']
                   when 'exchange_rate_adjustments' then array['CREATE_EXCHANGE_RATE_ADJUSTMENT']
                   when 'document_links'            then array['UPLOAD_DOCUMENT','MANAGE_TENANT_SETTINGS']
                   when 'lead_assignments'          then array['ASSIGN_LEAD','REASSIGN_LEAD']
                   when 'branches'                  then array['MANAGE_BRANCHES']
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
                       -- PAX-5 (2026-09-09): the post-issue manifest authority APPENDS, exactly as
                       -- CUST-3's block below explains for MANAGE_CUSTOMER_CREDIT and NOT as the
                       -- supplier branch REPLACES. Measured containment: CORRECT_PASSENGER_MANIFEST
                       -- goes to owner/ceo/branch_manager/finance_manager and CREATE_BOOKING_ITEM to
                       -- owner/ceo/branch_manager/department_manager/employee/senior_employee, so
                       -- `finance_manager` holds the first and NOT the second. Without this line the
                       -- object-class door would refuse a finance manager's correction before
                       -- app.enforce_booking_item_passenger_lifecycle -- the enforcer that actually
                       -- owns PAX-5 -- ever ran, and a per-user grant of the capability would be
                       -- silently void. Appending widens only WHO REACHES THE ENFORCER; the freeze
                       -- itself still demands CORRECT_PASSENGER_MANIFEST specifically.
                       when 'booking_items'      then array['UPDATE_BOOKING_ITEM_STATUS','ENTER_COST','ENTER_SELLING_PRICE','APPROVE_FINANCE','EDIT_LOCKED_COST','ARCHIVE_RECORD','ASSIGN_SUPPLIER']
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

    -- CUST-3 (2026-09-04): the customer ceiling. REQUIRED, not cosmetic -- `finance_manager` does NOT
    -- hold CREATE_CUSTOMER (measured: only owner, ceo, branch_manager, department_manager,
    -- senior_employee and employee do), so without this a finance manager could not set a ceiling at
    -- all. That is SUP-3's defect one table over.
    --
    -- THIS BRANCH APPENDS; THE SUPPLIER BRANCH BELOW REPLACES, AND THE DIFFERENCE IS DELIBERATE.
    -- MANAGE_CUSTOMER_CREDIT is NOT a subset of CREATE_CUSTOMER (`finance_manager` holds the first
    -- and not the second), so replacing here would refuse an employee legitimately creating a
    -- customer that happens to carry a ceiling. On `suppliers` the containment runs the other way and
    -- replacing costs nothing -- see CUST-5's block in `202607060600`. The CONSEQUENCE of appending
    -- is that this guard is not a second enforcer of MANAGE_CUSTOMER_CREDIT the way the supplier
    -- branch is; `customers_guard_credit_authority` is the sole enforcer on this table. Recorded as
    -- CUST-6 rather than changed inside a supplier migration.
    if tg_table_name = 'customers' then
        if (tg_op = 'UPDATE'
            and (new.credit_limit_amount is distinct from old.credit_limit_amount
                 or new.credit_limit_currency_code is distinct from old.credit_limit_currency_code))
           or (tg_op = 'INSERT'
               and (new.credit_limit_amount is not null or new.credit_limit_currency_code is not null))
        then
            -- `array[...]`, not a bare literal: `text[] || 'x'` makes PostgreSQL parse the untyped
            -- literal AS an array and fail with 22P02, which is what the suite caught first.
            v_perms := v_perms || array['MANAGE_CUSTOMER_CREDIT'];
        end if;
    end if;

    -- PAX-5 (2026-09-09). SCOPED TO THE ACT, NOT TO THE TABLE, and the first draft was wrong in a way
    -- the suite caught. Measured containment: CORRECT_PASSENGER_MANIFEST goes to
    -- owner/ceo/branch_manager/finance_manager, CREATE_BOOKING_ITEM to those three plus
    -- department_manager/employee/senior_employee -- so `finance_manager` holds the first and NOT the
    -- second, and without SOME widening a per-user grant of the correction capability would be
    -- silently void: the object-class door would refuse before
    -- app.enforce_booking_item_passenger_lifecycle -- the enforcer that owns PAX-5 -- ever ran.
    --
    -- THE FIRST DRAFT WIDENED THE WHOLE TABLE and broke PAX-2: test 104 assertions 10 and 12 failed,
    -- because a finance_manager could then swap the traveller on a DRAFT link they did not create,
    -- which is the exact reproduction 202607061400 closed. The rule is not "this table costs the
    -- correction capability"; it is "an ATTRIBUTED CORRECTION may be made by a correction holder".
    --
    -- So the alternative is offered ONLY when the statement is actually a correction: the traveller
    -- moves AND the statement authors a fresh reason for it -- the same two facts the lifecycle guard
    -- demands in the frozen period. A bare swap still costs CREATE_BOOKING_ITEM and nothing else, so
    -- PAX-2 is untouched. This APPENDS rather than REPLACES, for CUST-3's reason exactly: the two
    -- populations are not nested, and replacing would refuse an employee's ordinary attributed edit.
    if tg_op = 'UPDATE' and tg_table_name = 'booking_item_passengers' then
        -- PAX-7 (SPEC-223): correcting the TICKETED IDENTITY of the same traveller is the same
        -- attributed correction as moving the traveller, so it is offered on the same two facts.
        -- PAX-9 (SPEC-224): so is moving an entry ONTO or OFF a frozen manifest. Only a frozen
        -- endpoint qualifies: between unfrozen items a reason buys nothing here, and the object-class
        -- authority stays the only door.
        if (new.passenger_id is distinct from old.passenger_id
            or (new.manifest_first_name, new.manifest_family_name, new.manifest_full_name,
                new.manifest_date_of_birth, new.manifest_passport_number,
                new.manifest_passport_issuing_country_code)
               is distinct from
               (old.manifest_first_name, old.manifest_family_name, old.manifest_full_name,
                old.manifest_date_of_birth, old.manifest_passport_number,
                old.manifest_passport_issuing_country_code)
            or (new.booking_item_id is distinct from old.booking_item_id
                and exists (select 1
                              from public.booking_items bi
                              join public.bookings b on b.id = bi.booking_id
                             where bi.id in (old.booking_item_id, new.booking_item_id)
                               and bi.tenant_id = (select app.current_tenant_id())
                               and app.manifest_is_frozen(b.booking_status_code, b.is_archived))))
           and new.passenger_correction_reason is distinct from old.passenger_correction_reason
           and coalesce(btrim(new.passenger_correction_reason), '') <> '' then
            v_perms := v_perms || array['CORRECT_PASSENGER_MANIFEST'];
        end if;
    end if;
    -- PAX-9 (SPEC-224): adding a traveller to a FROZEN manifest is an attributed correction too, and
    -- is offered on the same facts; before the freeze an insertion stays CREATE_BOOKING_ITEM work.
    if tg_op = 'INSERT' and tg_table_name = 'booking_item_passengers' then
        if coalesce(btrim(new.passenger_correction_reason), '') <> ''
           and exists (select 1
                         from public.booking_items bi
                         join public.bookings b on b.id = bi.booking_id
                        where bi.id = new.booking_item_id
                          and bi.tenant_id = (select app.current_tenant_id())
                          and app.manifest_is_frozen(b.booking_status_code, b.is_archived)) then
            v_perms := v_perms || array['CORRECT_PASSENGER_MANIFEST'];
        end if;
    end if;
    -- CUST-5 (202607060600): SUP-3's authority, widened by SUP-4a to the PAIR (amount, currency),
    -- expressed WITHOUT a row image. The ONLY change from the replaced form is that the
    -- "and nothing else changed" conjunct is GONE; the assignment it guards is untouched.
    if tg_op = 'UPDATE' and tg_table_name = 'suppliers' then
        if new.credit_limit_amount is distinct from old.credit_limit_amount
           or new.credit_limit_currency_code is distinct from old.credit_limit_currency_code
        then
            v_perms := array['MANAGE_SUPPLIER_CREDIT'];
        end if;
    end if;

    -- LEAD-1 (202607061900). The handler rule, evaluated ONLY inside its own table branch so
    -- `new.assigned_user_id` is never named while this trigger is serving `suppliers` or `customers`.
    -- TWO CHANGES FROM THE FORM THIS REPLACES, both from BOOK-5's standing question:
    --   * MOVING THE ASSIGNMENT is authority, not content, and it costs what the two RPCs that do it
    --     charge. REPLACES the permission set (the `suppliers` shape): every role holding either key
    --     also holds CREATE_LEAD, so nothing legitimate loses a door.
    --   * THE SHORTCUT READS `old`. Reading `new` let the attacking statement supply the answer to
    --     "are you the handler?" and skip the entire check for every column in the statement.
    if tg_op = 'UPDATE' and tg_table_name = 'leads' then
        if new.assigned_user_id is distinct from old.assigned_user_id
           or new.owner_user_id is distinct from old.owner_user_id then
            v_perms := array['ASSIGN_LEAD','REASSIGN_LEAD'];
        else
            v_relationship_ok := (select app.current_user_id()) is not null
                                 and (select app.current_user_id())
                                     in (old.assigned_user_id, old.owner_user_id);
        end if;
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
$function$;

create trigger campaign_daily_metrics_guard_write_capability
    before insert or update on public.campaign_daily_metrics
    for each row execute function app.guard_write_capability();

create trigger exchange_rate_adjustments_guard_write_capability
    before insert or update on public.exchange_rate_adjustments
    for each row execute function app.guard_write_capability();

create function app.guard_booking_item_entry_state()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    raise exception using
        errcode = '23514',
        message = 'a booking item is created at ''draft'' with no lifecycle stamp (canon 26); '
                  'use app.advance_booking_item to move it';
end;
$fn$;

revoke all on function app.guard_booking_item_entry_state() from public;

create trigger booking_items_guard_entry_state
before insert on public.booking_items
for each row
when (new.base_status_code is distinct from 'draft'
      or new.completed_at is not null
      or new.cancelled_at is not null
      or new.cancelled_by is not null
      or new.no_show_at is not null
      or new.no_show_recorded_by is not null)
execute function app.guard_booking_item_entry_state();
