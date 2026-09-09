-- BOOK-8 -- owner decision, ratified 2026-09-09.
--
-- A raised finance-approval requirement MAY be withdrawn, but only through an explicit privileged
-- action. CREATE_BOOKING_ITEM -- the authority that RAISED it -- is not sufficient to withdraw it.
--
-- ================================================================================================
-- WHAT WAS THERE, AND THE DISTINCTION THAT MUST NOT BE BLURRED
--
-- BOOK-6 (202607061500) made `guard_booking_item_financials` refuse EVERY lowering of
-- `booking_items.finance_approval_required`, with the message "no governed path lowers it", and its
-- own comment says so explicitly: *"This deliberately does NOT decide whether a finance requirement
-- may EVER be withdrawn. That is a business question, and the answer to it is an RPC someone asks
-- for -- not a silent hole in a table door. Recorded as BOOK-8."* This migration is that RPC.
--
-- `app.review_finance_approval(..., 'cancelled')` is NOT the thing being changed here, and the
-- difference matters. That decision cancels the REQUEST while `finance_approval_required` stays
-- TRUE -- the item ends up MORE blocked, not less, which is why ADR-0020 prices it at
-- CREATE_BOOKING_ITEM (the requester withdrawing their own submission). BOOK-8 is about withdrawing
-- the REQUIREMENT itself, which removes a gate, and that is the act that needs finance's authority.
-- Left untouched, deliberately.
--
-- ================================================================================================
-- WHEN WITHDRAWAL IS STILL OPERATIONALLY VALID
--
-- Refused once the decision has been made or the money has moved past the gate:
--   * `finance_approval_status_code = 'approved'` -- the approval HAPPENED; erasing the requirement
--     it satisfied would rewrite that history.
--   * `cost_locked_at is not null`  -- execution has crossed the financial gate (this is the column
--     `review_finance_approval` stamps on approval and `EDIT_LOCKED_COST` exists to get past).
-- In both cases a later reversal is a NEW auditable action -- a fresh request, or a locked-cost
-- edit -- not a quiet flip of the old flag.
--
-- ================================================================================================
-- BOTH DOORS RECORD THE SAME FACTS
--
-- The evidence lives ON THE ROW (`app.enforce_archive_authority`'s shape, and PAX-5's): the reason
-- is caller-authored and must be FRESH, the actor and instant are server-stamped and unforgeable.
-- So a BARE table-DML lowering -- the thing BOOK-6 refused and BOOK-8 asked about -- is still
-- refused; what is now possible is an ATTRIBUTED withdrawal by a holder of the new capability,
-- through either door, emitting the same event. Nothing is deleted: the withdrawal is recorded
-- beside the requirement it lifted.

-- ------------------------------------------------------------------------------------------------
-- 1. The capability, seeded to the roles that hold APPROVE_FINANCE.
--
--    Derived rather than typed: whoever would otherwise have to SATISFY the requirement is who may
--    decide it does not apply. It stays a SEPARATE key -- not a re-use of APPROVE_FINANCE -- so a
--    per-user grant or deny can move one without the other, which is the whole reason the owner
--    decision asked for its own capability.
-- ------------------------------------------------------------------------------------------------
insert into public.permissions (key, name, description, required_feature_code, capability_group, action_kind, is_system, is_active)
values ('WITHDRAW_FINANCE_APPROVAL',
        'Withdraw a finance approval requirement',
        'Lift a raised finance-approval requirement from a booking item, with a mandatory reason. '
        'Distinct from APPROVE_FINANCE (which SATISFIES the requirement) and from CREATE_BOOKING_ITEM '
        '(which raises it, and is explicitly NOT sufficient to withdraw it). Refused once the '
        'approval has been granted or the cost has been locked -- past that point a reversal is a new '
        'auditable action, not a withdrawal. Owner decision BOOK-8, 2026-09-09.',
        'finance_lite', 'Finance', 'manage', true, true)
on conflict (key) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where p.key = 'WITHDRAW_FINANCE_APPROVAL'
  and r.code in (select r2.code
                 from public.role_permissions rp2
                 join public.roles r2 on r2.id = rp2.role_id
                 join public.permissions p2 on p2.id = rp2.permission_id
                 where p2.key = 'APPROVE_FINANCE')
on conflict do nothing;

-- ------------------------------------------------------------------------------------------------
-- 2. The withdrawal's evidence, and its event vocabulary.
-- ------------------------------------------------------------------------------------------------
alter table public.booking_items
    add column finance_approval_withdrawal_reason text,
    add column finance_approval_withdrawn_at timestamptz,
    add column finance_approval_withdrawn_by uuid;

alter table public.booking_items
    add constraint booking_items_finance_withdrawn_by_fkey
    foreign key (tenant_id, finance_approval_withdrawn_by)
    references public.users (tenant_id, id) on delete restrict;

comment on column public.booking_items.finance_approval_withdrawal_reason is
    'BOOK-8: mandatory, caller-authored reason for lifting a finance-approval requirement. Must be FRESH on each withdrawal -- a reason left by a previous one does not satisfy the next.';
comment on column public.booking_items.finance_approval_withdrawn_at is
    'BOOK-8: server-stamped instant of the withdrawal. Never accepted from the caller.';
comment on column public.booking_items.finance_approval_withdrawn_by is
    'BOOK-8: server-stamped actor of the withdrawal. Never accepted from the caller.';

insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_system, is_active)
select v.type_code, v.code, v.label, v.ord, true, true
from (values
        ('event_type', 'finance_approval_requirement_withdrawn', 'Finance Approval Requirement Withdrawn', 920)
     ) as v(type_code, code, label, ord)
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = v.type_code and cv.code = v.code and cv.tenant_id is null
);

-- ------------------------------------------------------------------------------------------------
-- 3. The event producer.
--
--    An AFTER trigger, for PAX-6's reason: `public.booking_items` is a sanctioned direct-DML surface,
--    so an event emitted only by the RPC would be missing from exactly the door that must not bypass
--    the invariant. The RPC below emits nothing itself, so there is exactly one producer and no
--    double-count is possible.
-- ------------------------------------------------------------------------------------------------
create or replace function app.record_finance_requirement_withdrawal_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if old.finance_approval_required and not new.finance_approval_required then
        perform app.record_event(
            new.tenant_id, 'finance_approval_requirement_withdrawn', 'booking_item', new.id,
            null, 'required', 'withdrawn', new.finance_approval_withdrawal_reason,
            jsonb_build_object(
                'finance_approval_status_code', new.finance_approval_status_code,
                'cost_locked_at',               new.cost_locked_at,
                'withdrawn_by',                 new.finance_approval_withdrawn_by),
            'critical');
    end if;
    return null;
end
$fn$;

comment on function app.record_finance_requirement_withdrawal_event() is
    'BOOK-8: the sole producer of finance_approval_requirement_withdrawn. AFTER trigger rather than RPC code, because public.booking_items is a sanctioned direct-DML surface and an event emitted only by the RPC would be absent from the other door. Severity critical: removing a financial gate is not routine.';

revoke all on function app.record_finance_requirement_withdrawal_event() from public;

create trigger booking_items_record_finance_withdrawal
    after update on public.booking_items
    for each row execute function app.record_finance_requirement_withdrawal_event();

-- ------------------------------------------------------------------------------------------------
-- 4. The sanctioned path.
--
--    SECURITY INVOKER: every rule is enforced by the trigger on the UPDATE it performs, so this
--    function needs no elevation and cannot diverge from the table door.
-- ------------------------------------------------------------------------------------------------
create or replace function app.withdraw_finance_approval(
    p_booking_item_id uuid,
    p_reason text
)
returns void
language plpgsql
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_item   record;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    if p_reason is null or btrim(p_reason) = '' then
        raise exception 'withdrawing a finance approval requirement requires a reason';
    end if;

    select bi.id, bi.finance_approval_required, bi.finance_approval_status_code, bi.cost_locked_at
      into v_item
    from public.booking_items bi
    where bi.id = p_booking_item_id and bi.tenant_id = v_tenant
    for update;
    if not found then
        raise exception 'booking item is not in your tenant';
    end if;
    if not v_item.finance_approval_required then
        raise exception 'this booking item carries no finance approval requirement to withdraw';
    end if;

    -- Any request still awaiting a decision is closed in the same transaction: leaving a `pending`
    -- approval_request behind a withdrawn requirement would ask a finance reviewer to decide
    -- something that no longer applies.
    update public.approval_requests
    set approval_status_code = 'cancelled',
        reviewed_by = app.current_user_id(),
        reviewed_at = now()
    where tenant_id = v_tenant
      and booking_item_id = p_booking_item_id
      and approval_type_code = 'finance_execution_approval'
      and approval_status_code = 'pending';

    -- The capability, the operational window, the reason's freshness and the actor stamp are all
    -- enforced by app.guard_booking_item_financials on this UPDATE, and the event is emitted by the
    -- AFTER trigger above. One owner per invariant, one producer per event.
    update public.booking_items
    set finance_approval_required = false,
        finance_approval_withdrawal_reason = p_reason,
        updated_at = now()
    where id = p_booking_item_id and tenant_id = v_tenant;
end
$fn$;

comment on function app.withdraw_finance_approval(uuid, text) is
    'BOOK-8 (owner decision 2026-09-09): the sanctioned withdrawal of a raised finance-approval requirement. Charges WITHDRAW_FINANCE_APPROVAL through app.guard_booking_item_financials, requires a fresh reason, closes any pending request, and is refused once the approval was granted or the cost was locked. SECURITY INVOKER -- it needs no elevation.';

revoke all on function app.withdraw_finance_approval(uuid, text) from public;
grant execute on function app.withdraw_finance_approval(uuid, text) to authenticated;

create or replace function public.withdraw_finance_approval(p_booking_item_id uuid, p_reason text)
returns void language sql set search_path = ''
as $fn$ select app.withdraw_finance_approval(p_booking_item_id, p_reason) $fn$;
revoke all on function public.withdraw_finance_approval(uuid, text) from public;
grant execute on function public.withdraw_finance_approval(uuid, text) to authenticated;
comment on function public.withdraw_finance_approval(uuid, text) is
    'HTTP surface for the SECURITY INVOKER app.withdraw_finance_approval operation.';

-- ------------------------------------------------------------------------------------------------
-- 5. The financial guard learns that withdrawal has a governed path now.
--    Replaced in full from the live definition so nothing from BOOK-5 / BOOK-6 / BOOK-7 / FIN-2 /
--    SPEC-155 is lost; only the finance_approval_required arm changed.
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_booking_item_financials()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
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
    -- BOOK-8 (2026-09-09, owner decision). BOOK-6's refusal above this line used to be
    -- unconditional -- "no governed path lowers it" -- and said in its own comment that whether a
    -- requirement may EVER be withdrawn was a business question awaiting an RPC. The owner answered
    -- it: withdrawal is permitted, but only as an explicit, attributed, privileged act.
    --
    -- RAISING is unchanged and still costs CREATE_BOOKING_ITEM. LOWERING now requires ALL of:
    --   * WITHDRAW_FINANCE_APPROVAL -- NOT CREATE_BOOKING_ITEM, which is what raised it;
    --   * a FRESH reason on the same row -- `is distinct from old` matters, or the reason from a
    --     previous withdrawal would silently satisfy the next one;
    --   * the approval not already granted, and the cost not already locked -- past either of those
    --     the history stands and a reversal is a new action, not a withdrawal.
    -- The actor and instant are server-stamped here, so neither door can forge attribution and both
    -- record identical evidence. A BARE lowering is still refused, exactly as BOOK-6 left it.
    if tg_op = 'UPDATE'
       and new.finance_approval_required is distinct from old.finance_approval_required then
        if new.finance_approval_required then
            perform app.authorize('CREATE_BOOKING_ITEM');
        else
            perform app.authorize('WITHDRAW_FINANCE_APPROVAL');

            if old.finance_approval_status_code = 'approved' then
                raise exception
                    'the finance approval was already granted: withdrawing the requirement now would rewrite that decision'
                    using errcode = 'check_violation';
            end if;
            if old.cost_locked_at is not null then
                raise exception
                    'the cost is locked: execution has crossed the financial gate, so a reversal is a new auditable action rather than a withdrawal'
                    using errcode = 'check_violation';
            end if;
            if new.finance_approval_withdrawal_reason is null
               or btrim(new.finance_approval_withdrawal_reason) = ''
               or new.finance_approval_withdrawal_reason is not distinct from old.finance_approval_withdrawal_reason then
                raise exception
                    'withdrawing a finance approval requirement requires its own reason'
                    using errcode = 'check_violation';
            end if;

            new.finance_approval_withdrawn_at := now();
            new.finance_approval_withdrawn_by := (select app.current_user_id());
        end if;
    elsif tg_op = 'UPDATE'
          and (new.finance_approval_withdrawal_reason is distinct from old.finance_approval_withdrawal_reason
               or new.finance_approval_withdrawn_at is distinct from old.finance_approval_withdrawn_at
               or new.finance_approval_withdrawn_by is distinct from old.finance_approval_withdrawn_by) then
        -- The evidence of a withdrawal is not editable on its own: the reason a financial gate was
        -- removed cannot be rewritten afterwards, and attribution cannot be forged.
        raise exception 'finance approval withdrawal evidence is not editable on its own'
            using errcode = 'check_violation';
    end if;

    return new;
end
$function$
;
