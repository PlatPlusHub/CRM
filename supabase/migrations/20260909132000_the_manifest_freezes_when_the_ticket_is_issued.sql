-- PAX-5 -- owner decision, ratified 2026-09-09.
--
-- A passenger manifest becomes immutable at booking-item `issued`. Before issuance, authorized
-- corrections continue through the existing sanctioned path. At issuance and afterwards,
-- `passenger_id` may not be changed by an ordinary booking-item write; a post-issue correction is a
-- deliberate, attributed, audited act requiring its own capability.
--
-- ================================================================================================
-- WHERE `issued` ACTUALLY IS -- READ OUT OF THE STATE MACHINE, NOT INVENTED
--
-- The decision names `issued`; the repository was asked where that state lives before a single line
-- was written, because inventing a status name is the one thing the standing method forbids.
--
--   `booking_item_base_status` = draft · pending · confirmed · in_progress · completed · cancelled
--                                · no_show                    -- NO `issued`.
--   `booking_status`           = draft · pending_approval · confirmed · in_progress · **issued**
--                                · reissue · refunded · void · completed · cancelled
--
-- So issuance is a fact about the BOOKING, and `app.status_transitions` says which states are
-- reachable at or after it:
--
--   in_progress -> issued [ISSUE_BOOKING]      issued -> completed | refunded | reissue | void
--   reissue     -> issued [ISSUE_BOOKING]      refunded -> completed        void -> completed
--
-- THE FROZEN SET IS THEREFORE: issued · reissue · refunded · void · completed.
-- `completed` is included because it is reachable from `issued` and is terminal; it is also already
-- refused for INSERTs by this same trigger, so including it makes the two arms agree rather than
-- introducing a new rule. `booking_items.issued_at` exists but NO function in the database writes
-- it -- measured, not assumed -- so it is not a state signal and is deliberately not used here.
--
-- ================================================================================================
-- THE HOLE THIS CLOSES, AND WHY IT WAS INVISIBLE
--
-- `app.enforce_booking_item_passenger_lifecycle` opens with:
--
--     if tg_op = 'UPDATE' and new.booking_item_id is not distinct from old.booking_item_id
--     then return new; end if;
--
-- -- so a swap of `passenger_id` ON THE SAME ITEM skipped the entire lifecycle guard. PAX-2 had
-- already priced that swap at CREATE_BOOKING_ITEM, which is why it looked covered: it was
-- AUTHORIZED and completely unconstrained by state. Six of ORVION's roles hold
-- CREATE_BOOKING_ITEM, `authenticated` holds UPDATE on `public.booking_item_passengers`, and
-- PostgREST serves that table -- so who flies on an issued ticket could be rewritten by an ordinary
-- employee, through the browser-facing door, at any time.
--
-- ================================================================================================
-- THE ENFORCEMENT LAYER, AND WHY BOTH DOORS COST THE SAME
--
-- Extended into `app.enforce_booking_item_passenger_lifecycle` -- the function that ALREADY owns
-- "what may happen to a manifest row given its parent's state" -- rather than added as a second
-- trigger. One invariant, one owner.
--
-- A post-issue correction must carry a REASON, and a bare table UPDATE has nowhere to put one. So
-- the reason gets a home ON THE ROW, in exactly the shape `app.enforce_archive_authority` already
-- uses for archival: the reason is caller-authored, the actor and instant are SERVER-STAMPED and
-- unforgeable. The result is that the RPC below and the table door produce IDENTICAL evidence, and
-- a bare post-issue swap -- no capability, no reason -- is refused at both. That is ARCH-2's
-- settled position (a second door, proven and left open on purpose because it costs the same
-- capability and records the same facts) applied one table over, rather than a new exception.
--
-- WHAT IS NOT DONE HERE: no historical passenger relationship is rewritten. The correction replaces
-- the CURRENT link and records what it replaced; the event PAX-6 adds in the next migration carries
-- the before/after identities, so the manifest's history is additive.

-- ------------------------------------------------------------------------------------------------
-- 1. The capability.
--
--    Seeded to the role bundle that already carries post-issue correction authority: the four roles
--    holding REISSUE_BOOKING (owner, ceo, branch_manager, finance_manager). NOT to the six that hold
--    CREATE_BOOKING_ITEM -- that permission is what an ordinary employee uses to build a manifest
--    before issuance, and granting the post-issue authority to everyone who holds it would leave
--    the freeze with no population it actually restricts. Per-user grants and denies continue to
--    work through the existing capability-grant model; this is only the starting bundle.
-- ------------------------------------------------------------------------------------------------
insert into public.permissions (key, name, description, required_feature_code, capability_group, action_kind, is_system, is_active)
values ('CORRECT_PASSENGER_MANIFEST',
        'Correct a passenger manifest after issuance',
        'Change which passenger is attached to a booking item after the booking has reached issued, '
        'or a state reachable after it (reissue, refunded, void, completed). Before issuance the '
        'manifest is edited under CREATE_BOOKING_ITEM as before; this capability exists only for the '
        'frozen period, and every use of it carries a mandatory reason, the actor, and a '
        'booking_item_passenger_replaced event. Owner decision PAX-5, 2026-09-09.',
        'booking', 'Booking', 'manage', true, true)
on conflict (key) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where p.key = 'CORRECT_PASSENGER_MANIFEST'
  and r.code in (select r2.code
                 from public.role_permissions rp2
                 join public.roles r2 on r2.id = rp2.role_id
                 join public.permissions p2 on p2.id = rp2.permission_id
                 where p2.key = 'REISSUE_BOOKING')
on conflict do nothing;

-- ------------------------------------------------------------------------------------------------
-- 2. The correction's evidence, on the row.
-- ------------------------------------------------------------------------------------------------
alter table public.booking_item_passengers
    add column passenger_correction_reason text,
    add column passenger_corrected_at timestamptz,
    add column passenger_corrected_by uuid;

alter table public.booking_item_passengers
    add constraint booking_item_passengers_corrected_by_fkey
    foreign key (tenant_id, passenger_corrected_by)
    references public.users (tenant_id, id) on delete restrict;

-- The read grant, and why it is NOT inherited. `public.booking_item_passengers` carries COLUMN-LEVEL
-- SELECT grants for `authenticated`, not a table-level one: `selling_amount_override` and
-- `cost_amount_override` are deliberately unreadable (financial privacy), and the rest -- id,
-- tenant_id, booking_item_id, passenger_id, created_at -- are readable. A newly added column inherits
-- the table-level INSERT/UPDATE and NO SELECT, so without this the correction evidence would be
-- writable and invisible: an audit trail nobody in the tenant could read. These three are audit
-- facts, not money, so they join the readable set.
grant select (passenger_correction_reason, passenger_corrected_at, passenger_corrected_by)
    on public.booking_item_passengers to authenticated;

comment on column public.booking_item_passengers.passenger_correction_reason is
    'PAX-5: mandatory, caller-authored reason for a post-issue manifest correction. Required by app.enforce_booking_item_passenger_lifecycle on every door, so the RPC and a direct UPDATE record the same fact.';
comment on column public.booking_item_passengers.passenger_corrected_at is
    'PAX-5: server-stamped instant of the last post-issue correction. Never accepted from the caller.';
comment on column public.booking_item_passengers.passenger_corrected_by is
    'PAX-5: server-stamped actor of the last post-issue correction. Never accepted from the caller.';

-- ------------------------------------------------------------------------------------------------
-- 3. The lifecycle guard learns about issuance. Replaced in full from the live definition so
--    nothing from PAX-3 is lost; only the UPDATE arm is new.
-- ------------------------------------------------------------------------------------------------
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
    -- Read out of app.status_transitions, not invented: `issued` and every state reachable from it.
    c_frozen constant text[] := array['issued','reissue','refunded','void','completed'];
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

    -- ------------------------------------------------------------------------------------------
    -- PAX-5. The UPDATE arm, which did not exist: a swap of `passenger_id` on the SAME item used
    -- to return above without consulting the parent's state at all.
    --
    -- The correction metadata is server-stamped here and NOT on the pre-issue path, so an ordinary
    -- correction before issuance leaves no misleading "corrected after issue" trail.
    -- ------------------------------------------------------------------------------------------
    if tg_op = 'UPDATE' then
        if new.passenger_id is distinct from old.passenger_id
           and (v_bk_archived or v_bk_status = any (c_frozen)) then
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
              and (new.passenger_correction_reason is distinct from old.passenger_correction_reason
                   or new.passenger_corrected_at is distinct from old.passenger_corrected_at
                   or new.passenger_corrected_by is distinct from old.passenger_corrected_by) then
            -- The evidence of a correction is not editable on its own. Without this, the reason a
            -- manifest was changed could be rewritten after the fact, or attribution forged.
            raise exception 'manifest correction evidence is not editable on its own'
                using errcode = 'check_violation';
        end if;

        -- Everything below is about ATTACHING a passenger to a parent. An UPDATE that does not move
        -- the row to a different item is not that, and was always exempt.
        if new.booking_item_id is not distinct from old.booking_item_id then
            return new;
        end if;
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
$fn$;

comment on function app.enforce_booking_item_passenger_lifecycle() is
    'PAX-5 (owner decision 2026-09-09): the manifest freezes when the booking reaches issued or a state reachable after it (issued, reissue, refunded, void, completed, or archived). A post-issue passenger swap costs CORRECT_PASSENGER_MANIFEST and a mandatory reason, and the actor and instant are server-stamped -- identical evidence through the RPC and the table door. Before issuance the manifest is edited under CREATE_BOOKING_ITEM exactly as before. Also keeps PAX-3''s caller-tenant lookup.';

-- ------------------------------------------------------------------------------------------------
-- 4. The sanctioned path.
--
--    SECURITY INVOKER (the repository default): every check this needs -- tenant, capability,
--    lifecycle -- is one the trigger performs anyway, and the RLS this function runs under is the
--    same RLS the caller would face at the table. Nothing here requires elevation, so nothing gets
--    it. The function's value is ergonomic and contractual, not privileged: it names the operation,
--    refuses a blank reason before touching anything, and gives clients one call instead of three
--    column assignments.
-- ------------------------------------------------------------------------------------------------
create or replace function app.correct_passenger_manifest(
    p_booking_item_passenger_id uuid,
    p_new_passenger_id uuid,
    p_reason text
)
returns void
language plpgsql
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_link   record;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    if p_reason is null or btrim(p_reason) = '' then
        raise exception 'a manifest correction requires a reason';
    end if;

    select bip.id, bip.passenger_id, bip.booking_item_id
      into v_link
    from public.booking_item_passengers bip
    where bip.id = p_booking_item_passenger_id and bip.tenant_id = v_tenant;
    if not found then
        raise exception 'manifest entry is not in your tenant';
    end if;

    if v_link.passenger_id = p_new_passenger_id then
        raise exception 'the manifest entry already names this passenger';
    end if;
    if not exists (
        select 1 from public.passengers p
        where p.id = p_new_passenger_id and p.tenant_id = v_tenant
    ) then
        raise exception 'passenger is not in your tenant';
    end if;

    -- The capability, the parent's state, the reason's presence and the actor stamp are all
    -- enforced by app.enforce_booking_item_passenger_lifecycle on this very UPDATE, and the
    -- booking_item_passenger_replaced event is emitted by the AFTER trigger PAX-6 installs. This
    -- function deliberately re-implements none of them: one owner per invariant, one producer per
    -- event.
    update public.booking_item_passengers
    set passenger_id = p_new_passenger_id,
        passenger_correction_reason = p_reason
    where id = p_booking_item_passenger_id and tenant_id = v_tenant;
end
$fn$;

comment on function app.correct_passenger_manifest(uuid, uuid, text) is
    'PAX-5 (owner decision 2026-09-09): the sanctioned post-issue manifest correction. SECURITY INVOKER -- it needs no elevation, and app.enforce_booking_item_passenger_lifecycle enforces the capability, the reason and the lifecycle on the UPDATE it performs, so the table door and this RPC cannot diverge.';

revoke all on function app.correct_passenger_manifest(uuid, uuid, text) from public;
grant execute on function app.correct_passenger_manifest(uuid, uuid, text) to authenticated;

create or replace function public.correct_passenger_manifest(
    p_booking_item_passenger_id uuid, p_new_passenger_id uuid, p_reason text)
returns void language sql set search_path = ''
as $fn$ select app.correct_passenger_manifest(p_booking_item_passenger_id, p_new_passenger_id, p_reason) $fn$;
revoke all on function public.correct_passenger_manifest(uuid, uuid, text) from public;
grant execute on function public.correct_passenger_manifest(uuid, uuid, text) to authenticated;
comment on function public.correct_passenger_manifest(uuid, uuid, text) is
    'HTTP surface for the SECURITY INVOKER app.correct_passenger_manifest operation.';

-- ------------------------------------------------------------------------------------------------
-- 5. The object-class door must let the correction authority REACH the enforcer.
--    Replaced in full from the live definition so nothing from SEC-1b / SEC-1c / LIC-3 / PP-4 /
--    CUST-3 / CUST-5 / LEAD-1 is lost; the added region carries its own PAX-5 comment.
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_write_capability()
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
$function$
;
