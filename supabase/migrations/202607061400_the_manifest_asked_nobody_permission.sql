-- PAX-1, PAX-2, PAX-3 -- the relationship that decided who was travelling asked nobody's permission.
--
-- Batch 6 slice 4, `booking_item_passengers`, chosen by `scripts/batch6_select_target.ps1`
-- (score -2; exposure 10, coverage 12 -- the highest-ranked NOT-RECORDED surface).
--
-- This table is not "a join table". It is the manifest: the row that says WHICH PERSON is on WHICH
-- booked service. SPEC-159-A already gave its two MONEY columns a real guard
-- (`app.guard_passenger_financials`). What this migration found is that the guard is CONDITIONAL --
-- it returns NEW immediately when both override amounts are null -- and nothing else on the table
-- door asked for a capability at all. So the financial half of the row was governed and the
-- OPERATIONAL half, which is the half the table exists for, was not.
--
-- =============================================================================================
-- PAX-1 -- REPRODUCED, as a real `finance_manager` holding aal2, against the live local stack.
-- =============================================================================================
--   identity                                    current_user=authenticated, tenant=Alpha
--   app.has_permission('CREATE_BOOKING_ITEM')   f
--   app.has_permission('VIEW_FINANCIAL_DOCUMENTS')  t   -- so booking_items are VISIBLE: 2 rows
--   RPC   app.link_passenger_to_booking_item()  REFUSED 42501 permission denied: CREATE_BOOKING_ITEM
--   DIRECT insert into booking_item_passengers  ALLOWED  -- and the row persisted (1)
--
-- The RPC is priced at CREATE_BOOKING_ITEM and `passengers` itself is mapped to CREATE_BOOKING_ITEM
-- inside `app.guard_write_capability`. So CREATING the traveller was gated and ATTACHING them to a
-- booked service was free. `MASTER_API_CONTRACT.md` states the RPC's permission as
-- CREATE_BOOKING_ITEM, which was true of the RPC and untrue of the surface.
--
-- WHY THE TRAINEE DID NOT FIND THIS. A `trainee` was refused the same INSERT -- but by RLS, not by a
-- capability: the read-scope policy on this table requires the parent booking_item to be VISIBLE,
-- and a trainee can see 0 booking_items. That refusal is real and is kept as a control below, but it
-- is visibility, not authority, and it says nothing about an actor who can see the parent. The
-- finance_manager is exactly that actor. A test that had only ever attacked with a low-privilege
-- role would have called this surface safe.
--
-- =============================================================================================
-- PAX-2 -- the same door, one verb over: a passenger could be SWAPPED for another.
-- =============================================================================================
--   employee links passenger b1 legitimately                       ALLOWED
--   update ... set passenger_id = b4  (a DIFFERENT Alpha traveller) ALLOWED, no capability asked
--   ...performed by the finance_manager who did not create the link ALLOWED
--   events emitted by the link and by the swap                      0
--
-- `app.enforce_booking_item_passenger_lifecycle` returns early when `booking_item_id` is unchanged,
-- and `app.guard_passenger_financials` returns early when the amounts are unchanged. A statement
-- that changes ONLY `passenger_id` therefore passes every trigger on the table. Nour Hassan flies;
-- the manifest afterwards says Laila Hassan; nothing recorded that anyone changed it.
--
-- The REPAIR for PAX-1 closes PAX-2, which is why there is one repair and not two: mapping this
-- table in `app.guard_write_capability` and attaching the trigger for INSERT **or UPDATE** makes
-- both verbs cost CREATE_BOOKING_ITEM -- the price the RPC has always charged.
--
-- NOT DONE, DELIBERATELY: no rule is added that FREEZES the passenger after issuance/ticketing.
-- Whether a manifest may be corrected after a ticket is issued is a business question and canon does
-- not answer it (`MASTER_EXECUTION_PLAN.md` 10 / directive 12: if canon does not define it, do not
-- invent it). Recorded as PAX-5, open, owner. This migration only restores the price of the door.
--
-- =============================================================================================
-- PAX-3 -- a SECURITY DEFINER trigger answered a question about another tenant's booking.
-- =============================================================================================
-- `app.enforce_booking_item_passenger_lifecycle` is SECURITY DEFINER (correctly -- BOOK-1 needs it
-- to see a parent the caller may not read) and looked its parent up by `bi.id` ALONE. BEFORE ROW
-- triggers run BEFORE the RLS WITH CHECK in PostgreSQL's ExecInsert, so it ran, and spoke, on rows
-- RLS was about to refuse. Measured, same actor, same statement, three parents:
--
--   foreign booking_item, ACTIVE       -> 42501 new row violates row-level security policy   (opaque)
--   booking_item UUID that does not exist -> 42501 new row violates row-level security policy (opaque)
--   foreign booking_item, CANCELLED    -> 23514 cannot add a passenger to a cancelled booking item
--
-- The third answer is a cross-tenant oracle: given a booking_item id, a stranger learns whether it
-- exists AND whether it (or its booking) is cancelled / no_show / archived / completed. It needs a
-- foreign UUID to be known, so it is Low -- but it is a tenant-boundary leak through a definer
-- function, which is the SECDEF-1 class, and the fix costs one predicate.
--
-- THE REPAIR WAS ATTACKED BEFORE IT WAS TRUSTED (the MONEY-1 discipline from slice 3).
--   Draft 1: `and bi.tenant_id = new.tenant_id`. REJECTED, and the reason matters -- an attacker
--   supplies `new.tenant_id`. Set it to the FOREIGN tenant and the predicate matches again, the
--   trigger speaks again, and RLS is still the thing that refuses afterwards. The draft repairs the
--   case the tester happens to write and not the case the attacker would.
--   Draft 2, kept: scope to `app.current_tenant_id()` -- the caller's tenant, which the caller
--   cannot choose. Proven not to weaken BOOK-1: the composite foreign key
--   `(tenant_id, booking_item_id) references booking_items(tenant_id, id)` means every row that can
--   ever COMMIT has `bi.tenant_id = new.tenant_id`, and RLS means every row an authenticated caller
--   can commit has `new.tenant_id = app.current_tenant_id()`. So the narrowed lookup refuses exactly
--   the same set of committable rows and declines to comment on the rest.
--   The platform path keeps the UNRESTRICTED lookup (`v_tenant is null`), because BOOK-1's header
--   says in terms that this trigger has NO session-less exemption: an item on a cancelled booking is
--   equally incoherent whether a migration or a user created it. The scope narrows for tenant
--   sessions; the CHECK never stops running.
--
-- =============================================================================================
-- MEASURED AND DELIBERATELY NOT REPAIRED HERE
-- =============================================================================================
-- PAX-4 (open, engineering): `booking_item_passengers` is not alone. Measured against the live
-- catalog: of the tables `authenticated` may INSERT, **20 have no trigger that calls app.authorize
-- or app.has_permission at all** -- `branches`, `catalog_values`, `chart_of_accounts`,
-- `departments`, `exchange_rates`, `journal_entries`, `journal_entry_lines`, `lead_interactions`,
-- `subscriptions`, `tenants`, `users`, `user_branch_assignments`, `user_permission_grants`,
-- `otp_challenges`, `totp_enrollments`, `trusted_devices`, `campaign_daily_metrics`,
-- `document_retention_policies`, `exchange_rate_adjustments`, `subscription_payment_proofs`. Some
-- are certainly correct (`otp_challenges` is a pre-authentication surface; a capability check there
-- would be a category error). The rest need a per-table answer that canon must supply, one surface
-- at a time, which is what Batch 6 is for. Registered with the count rather than repaired in bulk:
-- inventing twenty table-to-permission mappings in one migration would be exactly the "add business
-- rules Canon does not define" this programme forbids.
--
-- `created_at` remains rewritable by `authenticated` on this table -- `update ... set
-- created_at = '1999-01-01'` was ALLOWED and stored. NOT fixed here, and the number is the reason:
-- **51 of 51** public base tables that grant UPDATE to `authenticated` also grant it on `created_at`.
-- That is a uniform schema-wide shape, not this table's defect, and it is the same class slice 3
-- left open after measuring the CHECK side of it. A one-table revoke would make the schema less
-- consistent, not safer.
--
-- Re-pricing a passenger on an ALREADY-ATTACHED row whose item has since been cancelled stays
-- ALLOWED (measured: 999999 stored against a `cancelled` item). That is not an omission. BOOK-1's
-- own header rules on it: "Editing an item already attached to a closed booking is a different
-- question with different answers (a correction to a historical record may be legitimate)". The
-- passenger trigger mirrors the item trigger deliberately, and this migration keeps the mirror.
--
-- =============================================================================================
-- CONSUMER SWEEP (AGENTS.md 5b) -- run against pg_proc and pg_class, not assumed.
-- =============================================================================================
-- Functions naming this table or its override columns: `app.link_passenger_to_booking_item`, its
-- `public` wrapper, and `app.guard_passenger_financials`. Views/matviews selecting from it: NONE.
-- Reporting views: NONE. So the override amounts are stored and currently consumed by nothing --
-- which BOUNDS the financial blast radius of everything above, and is stated here so no later
-- reader infers a pricing impact this slice did not prove.
-- `app.guard_write_capability` gains one CASE arm and one more trigger; it is already the enforcer
-- on 24 tables and the whole suite re-runs against it below.

-- ---------------------------------------------------------------------------------------------
-- PAX-3: the lifecycle trigger stops commenting on other tenants' bookings.
-- ---------------------------------------------------------------------------------------------
create or replace function app.enforce_booking_item_passenger_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_item_status     text;
    v_item_archived   boolean;
    v_bk_status       text;
    v_bk_archived     boolean;
    v_tenant          uuid := (select app.current_tenant_id());
begin
    if tg_op = 'UPDATE' and new.booking_item_id is not distinct from old.booking_item_id then
        return new;
    end if;

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
end;
$fn$;

comment on function app.enforce_booking_item_passenger_lifecycle() is
'BOOK-1: mirrors app.link_passenger_to_booking_item''s parent-state refusals on every write path. PAX-3: the parent lookup is scoped to the CALLER''s tenant so the refusal cannot report another tenant''s booking state; unrestricted on the platform path, where BOOK-1 allows no exemption.';

-- ---------------------------------------------------------------------------------------------
-- PAX-1 / PAX-2: the table door is priced at what the RPC has always charged.
-- ---------------------------------------------------------------------------------------------
create or replace function app.guard_write_capability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
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
$$;

revoke execute on function app.guard_write_capability() from public;

-- INSERT **OR UPDATE**, and no DELETE arm. The two verbs are the two `authenticated` actually holds:
--   has_table_privilege('authenticated','booking_item_passengers', ...) -> INSERT t, UPDATE t,
--   SELECT f, DELETE f. DELETE is refused at the GRANT, proven by the error PostgreSQL itself gives
--   ("permission denied for table ... HINT: GRANT DELETE ..."), so a DELETE arm here would guard a
--   door that does not exist -- the SECDEF-1 preference for removing doors over locking absent ones.
create trigger booking_item_passengers_guard_write_capability
    before insert or update on public.booking_item_passengers
    for each row
    execute function app.guard_write_capability();
