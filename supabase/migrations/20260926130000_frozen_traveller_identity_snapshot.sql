-- ================================================================================================
-- SPEC-223 -- PAX-7: the identity a traveller was ticketed under belongs to the manifest, not to the
-- profile it was copied from.
--
-- PAX-5 (`20260909132000`) froze WHO IS ON an issued manifest entry: moving `passenger_id` after the
-- freeze costs CORRECT_PASSENGER_MANIFEST, a fresh reason and a server stamp. But the entry held no
-- identity of its own -- it dereferenced `public.passengers`, a reusable profile any
-- CREATE_BOOKING_ITEM holder may edit. MEASURED in a rolled-back probe: an `employee` refused the swap
-- (`permission denied: CORRECT_PASSENGER_MANIFEST`) then renamed and re-passported the linked
-- passenger with UPDATE 1, and the issued manifest read the new person, with no reason, actor or event.
--
-- OWNER DECISION 2026-09-26 (snapshot, not lock): the profile stays editable for future travel,
-- passport and visa renewal and corrected data; the identity actually ticketed is preserved on the
-- manifest entry and later profile edits must not rewrite it. Locking the profile was rejected because
-- the freeze is permanent once issued, so every repeat traveller's documents would freeze forever.
--
-- WHAT IS FROZEN: the six fields that identify the ticketed person and document -- name components,
-- full name, date of birth, passport number and its issuing country. Validity dates, visas,
-- nationality, passenger type and CRM context are not identity and stay on the profile only.
--
-- WHO OWNS "FROZEN": still only `app.enforce_booking_item_passenger_lifecycle`. It now computes the
-- flag once and uses it for both rules: until the freeze the snapshot is re-derived from the profile
-- on every write (a caller cannot pre-load a different one); afterwards it changes only by a swap or
-- by the same attributed correction PAX-5 already defines. `passengers_sync_manifest_identity` only
-- touches a traveller's entries when an identity field moves; the enforcer decides per entry.
--
-- `app.guard_write_capability` gains one case in its PAX-5 correction condition, for PAX-5's own
-- containment reason: `finance_manager` holds CORRECT_PASSENGER_MANIFEST but not CREATE_BOOKING_ITEM,
-- and without the case could swap a traveller but not correct a ticketed name. Nothing else in the
-- guard changes.
--
-- Deliberately NOT done: no new permission, reason column, event type or RLS change. A post-freeze
-- identity correction is evidenced by the row's stamp and emits no event -- PAX-8, recorded OPEN.
-- ================================================================================================

alter table public.booking_item_passengers
    add column manifest_first_name                    text,
    add column manifest_family_name                   text,
    add column manifest_full_name                     text,
    add column manifest_date_of_birth                 date,
    add column manifest_passport_number               text,
    add column manifest_passport_issuing_country_code text;

-- Backfilled while the PREVIOUS enforcer is still installed: it ignores these columns, so existing
-- rows -- frozen or not -- take their current identity without a correction being demanded.
update public.booking_item_passengers bip
   set manifest_first_name                    = p.first_name,
       manifest_family_name                   = p.family_name,
       manifest_full_name                     = p.full_name,
       manifest_date_of_birth                 = p.date_of_birth,
       manifest_passport_number               = p.passport_number,
       manifest_passport_issuing_country_code = p.passport_issuing_country_code
  from public.passengers p
 where p.id = bip.passenger_id and p.tenant_id = bip.tenant_id;

-- Readable by the client that shows the manifest (the table grants no SELECT, only these columns).
-- The column UPDATE is named explicitly for the correction; the table's existing INSERT and UPDATE
-- grants already reach new columns, which is harmless because the enforcer derives the identity on
-- every INSERT and on every write before the freeze, and governs every change after it.
grant select (manifest_first_name, manifest_family_name, manifest_full_name, manifest_date_of_birth,
              manifest_passport_number, manifest_passport_issuing_country_code),
      update (manifest_first_name, manifest_family_name, manifest_full_name, manifest_date_of_birth,
              manifest_passport_number, manifest_passport_issuing_country_code)
   on public.booking_item_passengers to authenticated;

CREATE OR REPLACE FUNCTION app.enforce_booking_item_passenger_lifecycle()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
    v_item_status     text;
    v_item_archived   boolean;
    v_bk_status       text;
    v_bk_archived     boolean;
    v_tenant          uuid := (select app.current_tenant_id());
    -- Read out of app.status_transitions, not invented: `issued` and every state reachable from it.
    c_frozen constant text[] := array['issued','reissue','refunded','void','completed'];
    v_frozen          boolean;
begin
    -- Scalars rather than a RECORD, for the reason app.guard_passenger_financials already documents:
    -- plpgsql binds referenced variables as query parameters, so an unassigned RECORD field raises
    -- 55000 before any guarding condition can short-circuit.
    --
    -- PAX-3: `v_tenant` is the CALLER's tenant, never `new.tenant_id` -- the caller supplies that one
    -- and would simply set it to the tenant being probed. When it is null the caller is the platform
    -- (canon 35 principle 6) and the lookup stays unrestricted, because BOOK-1 grants this trigger no
    -- session-less exemption. For a tenant session the composite foreign key already guarantees that
    -- every COMMITTABLE row has bi.tenant_id = new.tenant_id = v_tenant, so this predicate removes no
    -- enforcement -- only the answer given to a row that was never going to commit.
    select bi.base_status_code, bi.is_archived, b.booking_status_code, b.is_archived
      into v_item_status, v_item_archived, v_bk_status, v_bk_archived
    from public.booking_items bi
    join public.bookings b on b.id = bi.booking_id
    where bi.id = new.booking_item_id
      and (v_tenant is null or bi.tenant_id = v_tenant);

    if not found then
        return new;
    end if;

    -- PAX-7: the ONE definition of "frozen", computed once and used by both the swap rule and the
    -- ticketed-identity rule below.
    v_frozen := v_bk_archived or v_bk_status = any (c_frozen);

    -- ------------------------------------------------------------------------------------------
    -- PAX-5. The UPDATE arm, which did not exist: a swap of `passenger_id` on the SAME item used
    -- to return above without consulting the parent's state at all.
    --
    -- The correction metadata is server-stamped here and NOT on the pre-issue path, so an ordinary
    -- correction before issuance leaves no misleading "corrected after issue" trail.
    -- ------------------------------------------------------------------------------------------
    if tg_op = 'UPDATE' then
        if new.passenger_id is distinct from old.passenger_id
           and v_frozen then
            perform app.authorize('CORRECT_PASSENGER_MANIFEST');

            -- The reason must be FRESH, not merely present. `is distinct from old` is the whole
            -- point: without it the reason left behind by a PREVIOUS correction satisfies the next
            -- one, so the second and every later swap on the same row would be waved through
            -- carrying someone else's explanation. Found by the test, not by inspection.
            if new.passenger_correction_reason is null
               or btrim(new.passenger_correction_reason) = ''
               or new.passenger_correction_reason is not distinct from old.passenger_correction_reason then
                raise exception
                    'a passenger manifest correction after issuance requires its own reason (booking is %)',
                    case when v_bk_archived then 'archived' else v_bk_status end
                    using errcode = 'check_violation';
            end if;

            new.passenger_corrected_at := now();
            new.passenger_corrected_by := (select app.current_user_id());
        elsif new.passenger_id is not distinct from old.passenger_id
              and v_frozen
              and (new.manifest_first_name, new.manifest_family_name, new.manifest_full_name,
                   new.manifest_date_of_birth, new.manifest_passport_number,
                   new.manifest_passport_issuing_country_code)
                  is distinct from
                  (old.manifest_first_name, old.manifest_family_name, old.manifest_full_name,
                   old.manifest_date_of_birth, old.manifest_passport_number,
                   old.manifest_passport_issuing_country_code) then
            -- PAX-7: correcting the TICKETED IDENTITY of the same traveller after the freeze is the
            -- same act as correcting who the traveller is, so it costs exactly what the swap above
            -- costs -- the capability, a fresh reason, and the server stamp -- and nothing new.
            perform app.authorize('CORRECT_PASSENGER_MANIFEST');
            if new.passenger_correction_reason is null
               or btrim(new.passenger_correction_reason) = ''
               or new.passenger_correction_reason is not distinct from old.passenger_correction_reason then
                raise exception
                    'a passenger manifest correction after issuance requires its own reason (booking is %)',
                    case when v_bk_archived then 'archived' else v_bk_status end
                    using errcode = 'check_violation';
            end if;
            if coalesce(btrim(new.manifest_first_name), '') = ''
               or coalesce(btrim(new.manifest_family_name), '') = ''
               or coalesce(btrim(new.manifest_full_name), '') = '' then
                raise exception 'a ticketed identity keeps its name'
                    using errcode = 'check_violation';
            end if;

            new.passenger_corrected_at := now();
            new.passenger_corrected_by := (select app.current_user_id());
        elsif new.passenger_id is not distinct from old.passenger_id
              and (new.passenger_correction_reason is distinct from old.passenger_correction_reason
                   or new.passenger_corrected_at is distinct from old.passenger_corrected_at
                   or new.passenger_corrected_by is distinct from old.passenger_corrected_by) then
            -- The evidence of a correction is not editable on its own. Without this, the reason a
            -- manifest was changed could be rewritten after the fact, or attribution forged.
            raise exception 'manifest correction evidence is not editable on its own'
                using errcode = 'check_violation';
        end if;

        -- PAX-7: until the freeze the ticketed identity IS the profile's, so it is re-derived on every
        -- write and a caller cannot pre-load a different one; a swap always takes the new traveller's.
        -- A frozen row that is merely touched keeps the identity it was ticketed with.
        if new.passenger_id is distinct from old.passenger_id or not v_frozen then
            select p.first_name, p.family_name, p.full_name, p.date_of_birth,
                   p.passport_number, p.passport_issuing_country_code
              into new.manifest_first_name, new.manifest_family_name, new.manifest_full_name,
                   new.manifest_date_of_birth, new.manifest_passport_number,
                   new.manifest_passport_issuing_country_code
            from public.passengers p
            where p.id = new.passenger_id
              and (v_tenant is null or p.tenant_id = v_tenant);
        end if;

        -- Everything below is about ATTACHING a passenger to a parent. An UPDATE that does not move
        -- the row to a different item is not that, and was always exempt.
        if new.booking_item_id is not distinct from old.booking_item_id then
            return new;
        end if;
    end if;

    -- PAX-7: a new manifest entry starts with its traveller's current identity.
    if tg_op = 'INSERT' then
        select p.first_name, p.family_name, p.full_name, p.date_of_birth,
               p.passport_number, p.passport_issuing_country_code
          into new.manifest_first_name, new.manifest_family_name, new.manifest_full_name,
               new.manifest_date_of_birth, new.manifest_passport_number,
               new.manifest_passport_issuing_country_code
        from public.passengers p
        where p.id = new.passenger_id
          and (v_tenant is null or p.tenant_id = v_tenant);
    end if;

    if v_item_archived or v_item_status in ('cancelled', 'no_show') then
        raise exception 'cannot add a passenger to a % booking item',
            case when v_item_archived then 'archived' else v_item_status end
            using errcode = 'check_violation';
    end if;

    if v_bk_archived or v_bk_status in ('completed', 'cancelled') then
        raise exception 'cannot add a passenger to an item on a % booking',
            case when v_bk_archived then 'archived' else v_bk_status end
            using errcode = 'check_violation';
    end if;

    return new;
end
$function$;

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
        -- PAX-7 (SPEC-223): correcting the TICKETED IDENTITY of the same traveller is the same
        -- attributed correction as moving the traveller, so it is offered on the same two facts.
        if (new.passenger_id is distinct from old.passenger_id
            or (new.manifest_first_name, new.manifest_family_name, new.manifest_full_name,
                new.manifest_date_of_birth, new.manifest_passport_number,
                new.manifest_passport_issuing_country_code)
               is distinct from
               (old.manifest_first_name, old.manifest_family_name, old.manifest_full_name,
                old.manifest_date_of_birth, old.manifest_passport_number,
                old.manifest_passport_issuing_country_code))
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

-- SECURITY DEFINER so an entry the editor cannot see is still re-derived; every trigger on the entry
-- still runs under the editor's session, so nothing here grants authority.
create or replace function app.sync_manifest_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    update public.booking_item_passengers
       set passenger_id = passenger_id
     where passenger_id = new.id
       and tenant_id = new.tenant_id;
    return null;
end
$fn$;
revoke execute on function app.sync_manifest_identity() from public;

create trigger passengers_sync_manifest_identity
    after update of first_name, family_name, full_name, date_of_birth, passport_number,
                    passport_issuing_country_code
    on public.passengers
    for each row
    when ((old.first_name, old.family_name, old.full_name, old.date_of_birth, old.passport_number,
           old.passport_issuing_country_code)
          is distinct from
          (new.first_name, new.family_name, new.full_name, new.date_of_birth, new.passport_number,
           new.passport_issuing_country_code))
    execute function app.sync_manifest_identity();
