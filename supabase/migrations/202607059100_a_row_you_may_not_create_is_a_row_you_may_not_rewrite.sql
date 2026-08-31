-- SEC-1c -- a row you may not create is a row you may not rewrite.
--
-- FOUND, by asking why `suppliers.credit_limit_amount` is readable by everyone (PD-24). `suppliers`
-- carries ONE policy (`tenant_isolation FOR ALL`, tenant only) and ONE capability trigger, and that
-- trigger is `BEFORE INSERT` and nothing else.
--
-- PROVED on a clean reset at 179 migrations, as a `trainee`, with controls in both directions:
--     has_permission CREATE_CUSTOMER=f CREATE_PASSENGER=f MANAGE_SUPPLIERS=f VIEW_FINANCIAL_DOCUMENTS=f
--     rows visible first: customers=1 passengers=1 suppliers=1 (credit 1000)   <- not vacuous
--     INSERT customers                     -> REFUSED  "one of CREATE_CUSTOMER is required"
--     UPDATE customers.full_name           -> UPDATE 1
--     UPDATE passengers.full_name          -> UPDATE 1
--     UPDATE suppliers.credit_limit_amount -> UPDATE 1   1000 -> 999999
-- The refused INSERT in the SAME session on the SAME table is what makes this non-vacuous: it proves
-- the actor is genuinely unprivileged, so the difference is INSERT vs UPDATE and not the fixture.
--
-- ROOT CAUSE, and it is a class rather than three tables. `app.guard_write_capability` is attached
-- `BEFORE INSERT` only on THIRTEEN tables: approval_requests, bookings, complaints, conversations,
-- customer_notes, customers, documents, leads, passengers, quotations, service_requests, suppliers,
-- tasks. Measured against RLS, those thirteen split three ways:
--   * FOUR   (customers, passengers, suppliers, customer_notes) -- UPDATE `WITH CHECK` is tenant
--            isolation and nothing else. Completely ungoverned. These are the reproduced ones.
--   * EIGHT  (bookings, complaints, conversations, documents, leads, quotations, service_requests,
--            tasks) -- `WITH CHECK` does call `has_permission`, but every permission it names is a
--            **VIEW_*** one plus ownership. That is RLS-1 exactly ("a read permission confers write
--            authority"), which was MERGED INTO SEC-1: read scope is not write capability.
--   * ONE    (approval_requests) -- the only one already gated on genuine write permissions
--            (APPROVE_FINANCE / REVIEW_APPROVAL_REQUEST / REVIEW_SUBSCRIPTION_PAYMENT).
--
-- This is the exact MIRROR of SEC-1b. SEC-1b found the ceiling crediting tables for an UPDATE-only
-- trigger and opened twelve of them on the INSERT path. Nobody then asked the inverse question about
-- the tables SEC-1b itself had just attached. The guard written to close one direction was attached
-- in one direction.
--
-- WHICH PERMISSION UPDATE CHARGES -- DERIVED, NOT CHOSEN. Canon 28 defines NO general edit
-- permission: repository-wide the only mutation-shaped permissions canon names beyond CREATE_* are
-- `EDIT_LOCKED_COST` and `UPDATE_BOOKING_ITEM_STATUS`, both narrow and field/state-specific. Canon's
-- model is one permission per object class plus narrow permissions for specifically sensitive
-- mutations. So UPDATE cannot demand an EDIT_* that canon never defined, and inventing one would be
-- inventing business policy.
--
-- Two existing pieces of evidence settle it instead:
--   1. TWELVE tables ALREADY carry this guard as INSERT **OR UPDATE** with the same object-class
--      permission for both (branch_business_hours, company_assets, conversation_messages,
--      customer_contact_methods, customer_identity_merges, customer_identity_signals, document_links,
--      financial_accounts, holidays, internal_supplier_links, lead_assignments, offline_conversions).
--      The rule already exists in this repository; thirteen tables were simply missed.
--   2. `app.status_transitions.permission_key` already records, per table, WHICH permission may
--      legally change that object's state -- canon-encoded data, not a judgement.
--
-- Hence: **UPDATE set = the object-class permission UNION that table's transition permissions**, and
-- the guard's `v_perms` is already a `text[]` evaluated as "any of", so no new mechanism is needed.
--
-- WHY THE UNION AND NOT JUST THE CREATE PERMISSION -- this was checked against real role holdings
-- before it was written, because the owner's step 10 is "verify no unrelated capability was removed":
--     finance_manager holds ISSUE/CANCEL/REFUND/REISSUE_BOOKING but NOT CREATE_BOOKING
--         -> `advance_booking` would have broken under a CREATE-only rule.
--     finance_manager holds ARCHIVE_DOCUMENT + CREATE_DOCUMENT_VERSION but is not a general uploader
--         -> `archive_document` / `add_document_version` would have broken.
--     finance_manager holds APPROVE_FINANCE + REVIEW_APPROVAL_REQUEST but NOT CREATE_BOOKING_ITEM
--         -> `review_finance_approval` (FIN-2's fix) would have broken.
-- A blanket "same permission as INSERT" was therefore rejected on evidence, not on taste.
--
-- WHAT THIS DELIBERATELY DOES NOT DO. It does not touch the twelve tables that already fire on both.
-- It does not add a permission to any role. It does not change any RLS policy -- the trigger is an
-- AND with RLS, so this can only ever refuse more, never permit more. It does not govern WHICH FIELD
-- changed: status changes remain governed by `app.status_transitions` + `enforce_status_transition`,
-- and the narrow field permissions (EDIT_LOCKED_COST) remain where they are. This closes exactly the
-- proven hole -- "may this actor mutate this object class at all" -- and nothing wider (owner
-- directive: no silent scope expansion).
--
-- `payment_proof` documents keep their STRICT `MANAGE_TENANT_SETTINGS` on both paths, preserving
-- PP-4; widening them to the ordinary document set would reopen it.
--
-- No session-less exemption is added or removed: the existing `auth.uid() is null` early return is
-- unchanged, so `process_lead_sla` and the other platform paths behave exactly as before.

create or replace function app.guard_write_capability()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_perms  text[];
    v_extra  text[];
    v_perm   text;
    v_held   text;
    -- Set ONLY inside the `documents` branch below. It exists because the UPDATE widening must not
    -- apply to payment proofs (PP-4), and the obvious way to write that -- naming
    -- `new.document_type_code` in the widening condition -- is the very trap the comment above
    -- describes: PL/pgSQL resolves a record field against the ACTUAL record type at execution, so
    -- that expression raises `record "new" has no field "document_type_code"` on `suppliers`,
    -- `customers` and every other table this trigger serves. It was written that way in this
    -- migration's first draft and the reproducer caught it immediately. A boolean carries the fact
    -- out of the branch where the field genuinely exists.
    v_strict boolean := false;
    -- `leads` carries an authority that is a RELATIONSHIP rather than a permission, and it is
    -- ORVION's own, copied verbatim rather than invented. `app.record_lead_interaction` reads:
    --     if not (v_actor = v_assigned) and not app.has_permission('ASSIGN_LEAD') then raise 42501
    -- i.e. THE ASSIGNED HANDLER, OR ASSIGN_LEAD. A trainee assigned a lead may log a call on it and
    -- holds none of CREATE_LEAD / ASSIGN_LEAD / CLOSE_LEAD / REASSIGN_LEAD -- so a permission-only
    -- UPDATE rule silently removed the handler rule. Caught by `verify_lifecycle_branches.ps1`
    -- ("a trainee CAN log an interaction on the lead they are ASSIGNED"), which is the assertion
    -- this migration's first draft broke: pgTAP was entirely green, and only the HTTP layer failed.
    -- That is the standing argument for running both doors, not a formality.
    -- Note this does NOT reopen SEC-1c: the reproduced trainee was assigned nothing, so the escape
    -- does not apply to them. It admits exactly the actor the RPC already admits, and no other.
    v_relationship_ok boolean := false;
begin
    -- Platform/system paths (canon 35 principle 6), as in every other guard here.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- 202607058500 (LIC-3 / PP-4): `documents` is resolved in its OWN statement, not inside the
    -- shared CASE below. A record field reference is resolved against the ACTUAL record type at
    -- execution, so naming `new.document_type_code` inside an expression this trigger also evaluates
    -- for `customers`, `leads` and twenty other tables fails on every one of them -- a CASE branch
    -- being untaken does not make the field reference disappear.
    if tg_table_name = 'documents' then
        if new.document_type_code = 'payment_proof' then
            -- Strict on both paths (PP-4): a billing artefact, not a use of the documents module.
            v_perms := array['MANAGE_TENANT_SETTINGS'];
            v_strict := true;
        else
            v_perms := array['UPLOAD_DOCUMENT'];
        end if;
    else
    v_perms := case tg_table_name
                   -- 202607056000: the permission each table's own RPC already charges.
                   when 'approval_requests'         then array['CREATE_BOOKING_ITEM']
                   when 'conversation_messages'     then array['SEND_MESSAGE']
                   when 'customer_contact_methods'  then array['CREATE_CUSTOMER']
                   when 'customer_identity_signals' then array['CREATE_CUSTOMER']
                   when 'customer_identity_merges'  then array['MERGE_CUSTOMER_IDENTITY']
                   when 'internal_supplier_links'   then array['ASSIGN_SUPPLIER']
                   when 'offline_conversions'       then array['MANAGE_MARKETING_CAMPAIGN']
                   when 'document_links'            then array['UPLOAD_DOCUMENT','MANAGE_TENANT_SETTINGS']
                   when 'lead_assignments'          then array['ASSIGN_LEAD','REASSIGN_LEAD']
                   -- 202607056100: no RPC writes these at all, so the permission comes from what
                   -- ORVION charges for the parent object or for the same class of master data.
                   when 'branch_business_hours'     then array['MANAGE_BRANCHES']
                   when 'holidays'                  then array['MANAGE_BRANCHES','MANAGE_TENANT_SETTINGS']
                   when 'financial_accounts'        then array['CREATE_JOURNAL_ENTRY']
                   when 'company_assets'            then array['CREATE_JOURNAL_ENTRY']
                   -- 202607057000 (SEC-1b): the twelve the ceiling's detector was crediting for an
                   -- UPDATE-only trigger. Read out of each table's own creating RPC.
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

    -- 202607059100 (SEC-1c): on UPDATE, the object-class permission is joined by the permissions
    -- that canon already says may MUTATE this object -- its `app.status_transitions.permission_key`
    -- values, plus the permission any non-transition mutating RPC charges. Creating and changing are
    -- different authorities in canon 28 (CREATE_LEAD vs CLOSE_LEAD, UPLOAD_DOCUMENT vs
    -- ARCHIVE_DOCUMENT), and a rule that recognised only the first would strip authority the
    -- permission matrix grants. `payment_proof` is excluded from widening on purpose (PP-4).
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
        -- Attached to a table with no mapping. Refusing is the only safe reading: returning NEW
        -- would manufacture the exact unguarded path this migration exists to close.
        raise exception 'guard_write_capability has no permission mapping for %', tg_table_name
            using errcode = 'insufficient_privilege';
    end if;

    -- `has_permission` first to find WHICH of the alternatives the caller holds, then `authorize`
    -- on that one -- because authorize is what also composes the MFA step-up, and a bare
    -- has_permission check would silently drop it for the roles canon 28 requires it from.
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
end
$fn$;

-- The thirteen INSERT-only attachments become INSERT OR UPDATE. The other twelve tables carrying
-- this guard already fire on both and are deliberately untouched.
drop trigger if exists approval_requests_guard_write_capability on public.approval_requests;
create trigger approval_requests_guard_write_capability
    before insert or update on public.approval_requests
    for each row execute function app.guard_write_capability();

drop trigger if exists bookings_guard_write_capability on public.bookings;
create trigger bookings_guard_write_capability
    before insert or update on public.bookings
    for each row execute function app.guard_write_capability();

drop trigger if exists complaints_guard_write_capability on public.complaints;
create trigger complaints_guard_write_capability
    before insert or update on public.complaints
    for each row execute function app.guard_write_capability();

drop trigger if exists conversations_guard_write_capability on public.conversations;
create trigger conversations_guard_write_capability
    before insert or update on public.conversations
    for each row execute function app.guard_write_capability();

drop trigger if exists customer_notes_guard_write_capability on public.customer_notes;
create trigger customer_notes_guard_write_capability
    before insert or update on public.customer_notes
    for each row execute function app.guard_write_capability();

drop trigger if exists customers_guard_write_capability on public.customers;
create trigger customers_guard_write_capability
    before insert or update on public.customers
    for each row execute function app.guard_write_capability();

drop trigger if exists documents_guard_write_capability on public.documents;
create trigger documents_guard_write_capability
    before insert or update on public.documents
    for each row execute function app.guard_write_capability();

drop trigger if exists leads_guard_write_capability on public.leads;
create trigger leads_guard_write_capability
    before insert or update on public.leads
    for each row execute function app.guard_write_capability();

drop trigger if exists passengers_guard_write_capability on public.passengers;
create trigger passengers_guard_write_capability
    before insert or update on public.passengers
    for each row execute function app.guard_write_capability();

drop trigger if exists quotations_guard_write_capability on public.quotations;
create trigger quotations_guard_write_capability
    before insert or update on public.quotations
    for each row execute function app.guard_write_capability();

drop trigger if exists service_requests_guard_write_capability on public.service_requests;
create trigger service_requests_guard_write_capability
    before insert or update on public.service_requests
    for each row execute function app.guard_write_capability();

drop trigger if exists suppliers_guard_write_capability on public.suppliers;
create trigger suppliers_guard_write_capability
    before insert or update on public.suppliers
    for each row execute function app.guard_write_capability();

drop trigger if exists tasks_guard_write_capability on public.tasks;
create trigger tasks_guard_write_capability
    before insert or update on public.tasks
    for each row execute function app.guard_write_capability();

revoke execute on function app.guard_write_capability() from public;
