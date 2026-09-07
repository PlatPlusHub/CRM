-- ORVION Batch 6 slice 5 -- `booking_items`: the booked service itself had no door.
--
-- Slice 4 closed the MANIFEST (`booking_item_passengers`) and, chasing why the SEC-1 ceilings had
-- never noticed it (MEAS-2), reproduced the identical defect on the PARENT and recorded it as BOOK-3.
-- This migration closes BOOK-3 and the four further defects the parent's own adversarial sweep found.
-- Every one was REPRODUCED behaviourally against the live local stack before a line was written.
--
--   BOOK-3  High.  A bare `booking_items` row -- the booked service itself -- could be INSERTed by an
--                  actor holding NO booking capability at all, and could then be UPDATEd freely:
--                  service type rewritten, currency rewritten, ownership seized, and the row moved to
--                  a different booking. `app.create_booking_item` charges CREATE_BOOKING_ITEM; the
--                  table door charged nothing. Reproduced as a `finance_manager` AND as a `trainee`
--                  (which holds none of the eight booking-item permissions); both rows persisted.
--   BOOK-4  Low.   `app.enforce_booking_item_lifecycle` is SECURITY DEFINER, looked its parent up by
--                  id ALONE, and runs BEFORE the RLS WITH CHECK. A foreign CANCELLED booking answered
--                  "cannot attach a booking item to a cancelled booking"; a foreign ACTIVE one and a
--                  nonexistent one both answered 23503. That difference is a cross-tenant
--                  existence-and-state oracle on `bookings`. PAX-3 exactly, one table up.
--   BOOK-5  High.  `app.guard_booking_item_financials` computed canon-28 scope from `new` on UPDATE,
--                  so the statement under judgement supplied the answer. An ENTER_COST holder who was
--                  NOT assigned the item was refused a plain cost change and ALLOWED the same change
--                  when it also grabbed ownership. Ground truth read as postgres: 100 -> 555.
--   BOOK-6  Med.   `finance_approval_required` -- the flag `advance_booking_item` reads to block
--                  execution -- could be cleared by anyone who could reach the row.
--   BOOK-7  Med.   `currency_code` could be rewritten on a PRICED item with no money permission,
--                  silently reinterpreting the amount. MONEY-1/SUP-4a/CA-2's family.
--
-- A DRAFT THAT WAS REJECTED, recorded because the reason generalises: BOOK-3's own register row said
-- the repair was hard because "finance_manager holds ENTER_COST without CREATE_BOOKING_ITEM". That is
-- FALSE against this database, and it was measured before it was believed -- `finance_manager` holds
-- NEITHER; ENTER_COST, ENTER_SELLING_PRICE, UPDATE_BOOKING_ITEM_STATUS and CREATE_BOOKING_ITEM are
-- held by exactly the same six roles. The real constraint is the opposite one: finance legitimately
-- LOCKS cost, APPROVES, ARCHIVES and ASSIGNS SUPPLIERS on items it does not own, so the UPDATE arm
-- must carry those four or the repair would lock finance out of its own work. Both facts are
-- behaviourally pinned in `105_booking_item_service_door_test.sql`.
--
-- Nothing here invents a permission. Every entry in both arms is read out of an enforcer that already
-- exists: CREATE_BOOKING_ITEM from `create_booking_item`/`request_finance_approval`,
-- UPDATE_BOOKING_ITEM_STATUS from `advance_booking_item`, APPROVE_FINANCE from
-- `review_finance_approval`, ENTER_COST / ENTER_SELLING_PRICE / EDIT_LOCKED_COST from
-- `guard_booking_item_financials`, and ARCHIVE_RECORD from `enforce_archive_authority`. That is
-- SEC-1b's rule verbatim.

-- =============================================================================================
-- BOOK-4. Scope the SECURITY DEFINER parent lookup to the CALLER's tenant.
--
-- The rejected draft was `and b.tenant_id = new.tenant_id`, for the same reason it was rejected in
-- 202607061400: `new.tenant_id` is supplied by the attacker, so it proves nothing.
-- `current_tenant_id()` is derived from the JWT. The `v_tenant is null` arm keeps the platform/system
-- path open, exactly as the `auth.uid() is null` early return does in every other guard here.
--
-- After this a foreign booking is simply NOT FOUND, the function says nothing, and the composite FK
-- refuses all three cases identically.
-- =============================================================================================
create or replace function app.enforce_booking_item_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_status   text;
    v_archived boolean;
    v_tenant   uuid := (select app.current_tenant_id());
begin
    -- Only the act of ATTACHING an item to a booking is governed. Editing an item already attached
    -- to a closed booking is a different question with different answers (a correction to a
    -- historical record may be legitimate) and is governed by the financial guard, not by this one.
    if tg_op = 'UPDATE' and new.booking_id is not distinct from old.booking_id then
        return new;
    end if;

    select b.booking_status_code, b.is_archived
      into v_status, v_archived
    from public.bookings b
    where b.id = new.booking_id
      and (v_tenant is null or b.tenant_id = v_tenant);

    -- No row: either the foreign key has not been validated yet on a BEFORE trigger, or the booking
    -- belongs to somebody else. Say nothing in BOTH cases and let the FK reject it -- inventing a
    -- second error here is what made this an oracle.
    if not found then
        return new;
    end if;

    if v_archived then
        raise exception 'cannot attach a booking item to an archived booking'
            using errcode = 'check_violation';
    end if;

    if v_status in ('completed', 'cancelled') then
        raise exception 'cannot attach a booking item to a % booking', v_status
            using errcode = 'check_violation';
    end if;

    return new;
end;
$fn$;

-- =============================================================================================
-- BOOK-5, BOOK-6, BOOK-7. The financial guard. Three changes, each commented at its own site;
-- everything else is byte-identical to the form 202607058700 left.
-- =============================================================================================
create or replace function app.guard_booking_item_financials()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_scoped boolean;
begin
    if (select auth.uid()) is null then
        return new;
    end if;

    -- BOOK-5 (202607061500): on UPDATE this reads the PRE-image, and that is the whole repair.
    -- It used to read `new` on both paths, so the statement being judged supplied the answer to the
    -- question: `set owner_user_id = <me>, cost_amount = 555` made `v_scoped` true and the canon-28
    -- scope evaporated. REPRODUCED as an `employee` who holds ENTER_COST and was NOT assigned the
    -- item: the plain cost update was refused, the same update carrying an ownership grab took, and
    -- the ground-truth read as postgres showed 100 -> 555 with ownership seized. That is PAX-3's
    -- draft-1 defect exactly ("the attacker supplies the value it compares"), one table over.
    -- On INSERT there is no pre-image and none is wanted: the creator naming themselves is the
    -- normal act, and it already costs CREATE_BOOKING_ITEM at the table door.
    if tg_op = 'UPDATE' then
        v_scoped := app.is_my_booking_item(old.owner_user_id, old.sales_owner_user_id,
                                           old.operational_owner_user_id)
                    or app.has_tenant_wide_read();
    else
        v_scoped := app.is_my_booking_item(new.owner_user_id, new.sales_owner_user_id,
                                           new.operational_owner_user_id)
                    or app.has_tenant_wide_read();
    end if;

    if tg_op = 'INSERT' then
        if coalesce(new.cost_amount, 0) <> 0 then
            perform app.authorize('ENTER_COST');
            if not v_scoped then
                raise exception 'ENTER_COST is scoped to items assigned to you (canon 28: assigned)'
                    using errcode = 'insufficient_privilege';
            end if;
        end if;
        -- SPEC-155: `commission_rate` removed from this condition. It is system-derived, so there is
        -- no caller value to authorize -- and leaving it here would demand ENTER_SELLING_PRICE for
        -- every bare item, since the derive trigger now sets it on every INSERT.
        if coalesce(new.selling_amount, 0) <> 0 then
            perform app.authorize('ENTER_SELLING_PRICE');
            if not v_scoped then
                raise exception 'ENTER_SELLING_PRICE is scoped to items assigned to you (canon 28: assigned)'
                    using errcode = 'insufficient_privilege';
            end if;
        end if;
        if new.cost_locked_at is not null then
            perform app.authorize('APPROVE_FINANCE');
        end if;
        -- FIN-2: an item may be BORN carrying a request. That is the salesperson opening one, not
        -- finance granting one, so it costs the salesperson's permission and their scope. Any other
        -- starting value is a decision recorded at insert time, which only finance may do.
        if new.finance_approval_status_code is not null then
            if new.finance_approval_status_code = 'pending' then
                perform app.authorize('CREATE_BOOKING_ITEM');
                if not v_scoped then
                    raise exception
                        'a finance approval request is scoped to items assigned to you (canon 28: assigned)'
                        using errcode = 'insufficient_privilege';
                end if;
            else
                perform app.authorize('APPROVE_FINANCE');
            end if;
        end if;
        return new;
    end if;

    -- BOOK-7 (202607061500): a currency change is a change to the MONEY. SUP-4a and CA-2 already
    -- settled that the amount and its currency are one value (canon 30's money standard), so
    -- reinterpreting EGP 100 as USD 100 costs exactly what rewriting the 100 costs -- no more, and
    -- no new permission invented. Only the disjunct is added; the lock and scope logic below is
    -- untouched. REPRODUCED: a finance_manager holding no ENTER_COST changed EGP -> USD on a priced
    -- item and it took.
    --
    -- `coalesce(...) <> 0`, NOT `is not null`, and the draft that used the latter was caught by
    -- re-running the probe: both money columns are NOT NULL DEFAULT 0, so `is not null` is a
    -- tautology and would have charged ENTER_COST for the currency of a bare zero-priced item. The
    -- form used here is the one the INSERT arm above already uses.
    if new.cost_amount is distinct from old.cost_amount
       or (new.currency_code is distinct from old.currency_code
           and coalesce(old.cost_amount, 0) <> 0) then
        if old.cost_locked_at is not null then
            perform app.authorize('EDIT_LOCKED_COST');
        else
            perform app.authorize('ENTER_COST');
            if not v_scoped then
                raise exception 'ENTER_COST is scoped to items assigned to you (canon 28: assigned)'
                    using errcode = 'insufficient_privilege';
            end if;
        end if;
    end if;

    -- SPEC-155: commission_rate dropped here too; the derive trigger guarantees new = old.
    -- BOOK-7's second half, same reasoning as the cost disjunct above.
    if new.selling_amount is distinct from old.selling_amount
       or (new.currency_code is distinct from old.currency_code
           and coalesce(old.selling_amount, 0) <> 0) then
        perform app.authorize('ENTER_SELLING_PRICE');
        if not v_scoped then
            raise exception 'ENTER_SELLING_PRICE is scoped to items assigned to you (canon 28: assigned)'
                using errcode = 'insufficient_privilege';
        end if;
    end if;

    -- Locking a cost is, and stays, an approver-only act. It is not a request anybody can raise.
    if new.cost_locked_at is distinct from old.cost_locked_at then
        perform app.authorize('APPROVE_FINANCE');
    end if;

    -- FIN-2, the heart of it. REQUESTING is not APPROVING.
    if new.finance_approval_status_code is distinct from old.finance_approval_status_code then
        if new.finance_approval_status_code = 'pending' then
            perform app.authorize('CREATE_BOOKING_ITEM');
            if not v_scoped then
                raise exception
                    'a finance approval request is scoped to items assigned to you (canon 28: assigned)'
                    using errcode = 'insufficient_privilege';
            end if;
        else
            perform app.authorize('APPROVE_FINANCE');
        end if;
    end if;

    -- BOOK-6 (202607061500): `finance_approval_required` is the flag `advance_booking_item` reads to
    -- BLOCK execution, and it had no writer of any kind on this door -- REPRODUCED: cleared to false
    -- by an actor holding no booking-item permission, which removes the gate entirely.
    --
    -- The authority is READ OUT OF THE RPC SURFACE, not invented (SEC-1b's rule). Measured across
    -- every function that touches this column: `create_booking_item` sets it at birth,
    -- `request_finance_approval` RAISES it under CREATE_BOOKING_ITEM, `advance_booking_item` only
    -- READS it -- and NOTHING lowers it. So raising it is priced at what the RPC charges, and
    -- LOWERING it is refused, because refusing a transition no governed path produces is what this
    -- codebase already does everywhere (BOOK-1, ADMIN-1, FIN-8, QUO-1) and is the conservative
    -- direction: it removes a reach, it never grants one.
    --
    -- This deliberately does NOT decide whether a finance requirement may EVER be withdrawn. That is
    -- a business question, and the answer to it is an RPC someone asks for -- not a silent hole in a
    -- table door. Recorded as BOOK-8.
    if tg_op = 'UPDATE'
       and new.finance_approval_required is distinct from old.finance_approval_required then
        if new.finance_approval_required then
            perform app.authorize('CREATE_BOOKING_ITEM');
        else
            raise exception
                'finance_approval_required cannot be withdrawn: no governed path lowers it'
                using errcode = 'insufficient_privilege';
        end if;
    end if;

    return new;
end
$fn$;


-- =============================================================================================
-- BOOK-3. The table door itself. `booking_items` joins the tables already priced by the central
-- guard; no second authorization engine, no per-column authority model.
--
-- The UPDATE arm is a FLOOR -- "hold some authority over booked services" -- not a per-column rule.
-- The per-column rules stay exactly where they already live and are untouched: money in
-- `guard_booking_item_financials`, archive in `enforce_archive_authority`, status in
-- `enforce_status_transition`.
--
-- ASSIGN_SUPPLIER is in the UPDATE arm because `finance_manager`, `senior_employee` and the three
-- manager roles hold it and assigning a supplier to an item is a legitimate write; it is the only
-- supplier-assignment permission canon defines, and `internal_supplier_links` is already mapped to it
-- in this same CASE.
--
-- No DELETE arm, and that is measured rather than assumed: `authenticated` holds INSERT and UPDATE on
-- this table and no DELETE grant at all.
-- =============================================================================================
create or replace function app.guard_write_capability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
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
$fn$;


-- 202607061400 (PAX-1) revoked PUBLIC EXECUTE on this function; re-stated here so the property does
-- not depend on the order these two migrations are ever replayed or squashed in.
revoke execute on function app.guard_write_capability() from public;

drop trigger if exists booking_items_guard_write_capability on public.booking_items;
create trigger booking_items_guard_write_capability
    before insert or update on public.booking_items
    for each row
    execute function app.guard_write_capability();
