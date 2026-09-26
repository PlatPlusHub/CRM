-- ================================================================================================
-- SPEC-222 -- CAMP-3: a marketing campaign costs the same step-up through the table as through the
-- functions that write it.
--
-- `app.create_marketing_campaign` and `app.advance_marketing_campaign` charge
-- `app.authorize('MANAGE_MARKETING_CAMPAIGN')`, which is permission AND step-up. The table door was
-- governed only by the `scope_isolation` RLS policy, whose WITH CHECK calls `app.has_permission` --
-- permission only. The capability is held by `owner` and `ceo` alone and `app.requires_mfa` lists
-- both, so every holder is step-up-bound. MEASURED in rolled-back probes: an `owner` at `aal1` was
-- refused 42501 `multi-factor authentication required for this role` by the RPC and, in the same
-- transaction, directly INSERTed a campaign and rewrote an existing campaign's platform, external id
-- and name. An attributed click then reported the rewritten identity, and a squatted external id
-- made the genuine RPC registration fail 23505. USR-2's shape, on a different surface.
--
-- SEC-1b (`202607057000`) credited this table because RLS already charges the permission. That was
-- right about permission and silent about step-up, which USR-2 established later; nothing it decided
-- is reversed here.
--
-- The repair REUSES `app.guard_write_capability`: it already charges the object-class permission
-- through `app.authorize`, already exempts session-less platform paths, and already charges this very
-- permission on the sibling `offline_conversions`. The definition below is the installed one with
-- exactly ONE added INSERT-map arm; the UPDATE extra-permission map deliberately gains nothing, so an
-- UPDATE costs MANAGE_MARKETING_CAMPAIGN -- the only key that can pass this table's RLS WITH CHECK
-- anyway. The only thing a legitimate writer newly pays is the step-up the RPCs already charged.
--
-- Deliberately NOT done: no RLS policy, grant, permission, event producer or status rule changes.
-- Campaign event parity is CAMP-4 and entry into any state is ENTRY-1; both stay separately owned.
-- Status moves already charge `app.authorize` through `app.enforce_status_transition`.
-- ================================================================================================

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
        if new.passenger_id is distinct from old.passenger_id
           and new.passenger_correction_reason is distinct from old.passenger_correction_reason
           and coalesce(btrim(new.passenger_correction_reason), '') <> '' then
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

create trigger marketing_campaigns_guard_write_capability
    before insert or update on public.marketing_campaigns
    for each row execute function app.guard_write_capability();
