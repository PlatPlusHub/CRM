-- SPEC-155 -- commission is a SYSTEM-DERIVED business rule, not an employee-editable input.
--
-- OWNER RULE (ratified 2026-08-27, closing BLOCKED-3):
--
--     gross_profit      = selling_amount - cost_amount
--     employee_commission = max(gross_profit, 0) * 10%
--     company_profit      = gross_profit - employee_commission
--
-- There is NO employee decision in setting a commission percentage. SPEC-154-A granted
-- ENTER_SELLING_PRICE per canon, and the guard bundles `commission_rate` into that permission, so an
-- employee could set the basis of their OWN compensation. That is the manipulation this migration
-- removes.
--
-- RECONCILED WITH THE EXISTING MODEL BEFORE IMPLEMENTING (the rule was not applied blindly):
--   * `app.item_financials` already defines `profit` as `selling_amount - cost_amount` -- gross
--     profit, exactly as the owner rule states. No competing accounting definition exists.
--   * Canon 31 says `commission_rate` "reserves a lightweight path for future sales commission
--     calculation without creating a payroll model" -- canon reserves the column and defines NO
--     model, so this rule fills a canon gap rather than contradicting canon.
--   * Only three functions referenced `commission_rate` (`create_booking_item`, `item_financials`,
--     `guard_booking_item_financials`); no view, no report and no integration consumed it. The blast
--     radius is therefore small and fully enumerated.
--
-- MECHANISM -- overwrite, do not merely forbid. A permission check would still leave the value
-- caller-supplied and would fail open the moment some future path forgot to check. A BEFORE trigger
-- that OVERWRITES the column makes the caller's value irrelevant on every path at once -- RPC,
-- direct PostgREST DML, batch, and any future writer. The employee cannot manipulate their
-- compensation because the system does not read what they sent.
--
-- TRIGGER ORDER IS LOAD-BEARING. PostgreSQL fires BEFORE triggers in alphabetical order by name.
-- This trigger is named `booking_items_derive_commission_rate` so that "d" sorts ahead of the
-- existing "..._enforce_*" and "..._guard_financials" triggers, guaranteeing the system value is in
-- place before the financial guard evaluates the row. A name sorting after the guard would have made
-- the guard judge the caller's value instead of the system's.
--
-- WHY commission_rate LEAVES THE GUARD'S CONDITION -- this is not a weakening. The guard's job is to
-- stop a CALLER setting a financial value they are not entitled to set. Once the column is
-- system-overwritten, there is no caller value left to authorize: on UPDATE the forced value always
-- equals the previous forced value, and on INSERT it is always the system constant. Keeping it in
-- the condition would additionally have BROKEN item creation -- forcing a non-null rate on every
-- INSERT would have made `new.commission_rate is not null` true for every bare item, demanding
-- ENTER_SELLING_PRICE from a user who holds only CREATE_BOOKING_ITEM. `selling_amount` and
-- `cost_amount` remain fully guarded and scope-checked exactly as SPEC-145/SPEC-154-A left them.

-- ---------------------------------------------------------------------------------------------
-- 1. One home for the rate. Changing the business rule is a one-line migration against this
--    function rather than a hunt through triggers, reports and call sites.
--
--    NOT per-tenant: the owner stated a single flat 10% with no per-agency qualification, and
--    inventing tenant-configurable compensation would be inventing business policy. If agencies
--    ever differ, that is a business decision and this function is the one place it lands.
-- ---------------------------------------------------------------------------------------------
-- `set search_path` even though the body touches no schema object and could not be hijacked: the
-- repository invariant (`05_function_search_path_test.sql`) is absolute precisely so that no future
-- reader has to re-derive whether a given function is the safe exception. It caught this omission
-- within one test run.
create or replace function app.commission_rate_default()
returns numeric
language sql
immutable
set search_path = ''
as $fn$
    select 0.10::numeric
$fn$;

revoke execute on function app.commission_rate_default() from public;
grant  execute on function app.commission_rate_default() to authenticated;

comment on function app.commission_rate_default() is
    'Canonical employee commission rate: 10% of gross profit (owner-ratified 2026-08-27). Single '
    'source for the rule; commission_rate on booking_items is overwritten with this value and is '
    'never a caller input.';

-- ---------------------------------------------------------------------------------------------
-- 2. Overwrite the column on every write path.
-- ---------------------------------------------------------------------------------------------
create or replace function app.derive_commission_rate()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    -- Unconditional: whatever the caller sent is discarded. That is the entire security property --
    -- an employee cannot influence the basis of their own commission because nothing they supply
    -- survives this line.
    new.commission_rate := app.commission_rate_default();
    return new;
end;
$fn$;

revoke execute on function app.derive_commission_rate() from public;

create trigger booking_items_derive_commission_rate
    before insert or update on public.booking_items
    for each row execute function app.derive_commission_rate();

-- Existing rows adopt the canonical rate. Primary holds zero business rows today, so this is a
-- no-op there; it is written anyway so the migration is correct on any database that does have rows.
update public.booking_items
   set commission_rate = app.commission_rate_default()
 where commission_rate is distinct from app.commission_rate_default();

-- ---------------------------------------------------------------------------------------------
-- 3. The guard stops authorizing a value the caller can no longer set. cost_amount and
--    selling_amount keep every check SPEC-145 and SPEC-154-A gave them, scope included.
-- ---------------------------------------------------------------------------------------------
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

    v_scoped := app.is_my_booking_item(new.owner_user_id, new.sales_owner_user_id,
                                       new.operational_owner_user_id)
                or app.has_tenant_wide_read();

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
        if new.cost_locked_at is not null or new.finance_approval_status_code is not null then
            perform app.authorize('APPROVE_FINANCE');
        end if;
        return new;
    end if;

    if new.cost_amount is distinct from old.cost_amount then
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
    if new.selling_amount is distinct from old.selling_amount then
        perform app.authorize('ENTER_SELLING_PRICE');
        if not v_scoped then
            raise exception 'ENTER_SELLING_PRICE is scoped to items assigned to you (canon 28: assigned)'
                using errcode = 'insufficient_privilege';
        end if;
    end if;

    if new.cost_locked_at is distinct from old.cost_locked_at
       or new.finance_approval_status_code is distinct from old.finance_approval_status_code then
        perform app.authorize('APPROVE_FINANCE');
    end if;

    return new;
end
$fn$;

-- ---------------------------------------------------------------------------------------------
-- 4. Derive the amounts where the financial model already lives, so no consumer recomputes them
--    and no second definition can drift. `permitted` continues to gate every figure: SPEC-139
--    financial privacy is unchanged, and commission/company profit are exactly as protected as cost.
--
--    `greatest(gross, 0)` implements the owner's `max(selling - cost, 0)`: a loss-making item pays
--    no commission, and the company absorbs the whole loss (company_profit = gross, commission = 0)
--    rather than the employee being charged for it.
-- ---------------------------------------------------------------------------------------------
drop function if exists app.item_financials(uuid);

create function app.item_financials(p_booking_item_id uuid)
returns table(
    cost_amount numeric,
    commission_rate numeric,
    profit numeric,
    commission_amount numeric,
    company_profit numeric,
    permitted boolean
)
language sql
stable
security definer
set search_path = ''
as $fn$
    select case when g.ok then coalesce(bi.cost_amount, 0) end,
           case when g.ok then bi.commission_rate end,
           case when g.ok then v.gross end,
           case when g.ok then round(greatest(v.gross, 0) * coalesce(bi.commission_rate, 0), 2) end,
           case when g.ok then v.gross - round(greatest(v.gross, 0) * coalesce(bi.commission_rate, 0), 2) end,
           g.ok
    from public.booking_items bi
    cross join lateral (
        select coalesce(bi.selling_amount, 0) - coalesce(bi.cost_amount, 0) as gross
    ) v
    cross join lateral (
        -- coalesce is load-bearing, not defensive tidying. `x in (a, b, c)` returns NULL rather
        -- than false when x matches none of them and any is NULL, which is the normal case here --
        -- most items have no operational owner. The masking still worked (`case when null` yields
        -- null), but `permitted` came back NULL, so a consumer could not distinguish "you may not
        -- see this" from "unknown". A flag that is sometimes NULL is not a flag.
        select coalesce(
                   app.has_permission('VIEW_FINANCIAL_DOCUMENTS')
                   or coalesce(app.current_user_id() in
                       (bi.owner_user_id, bi.sales_owner_user_id, bi.operational_owner_user_id), false),
                   false) as ok
    ) g
    where bi.id = p_booking_item_id
      and bi.tenant_id = app.current_tenant_id()
$fn$;

revoke execute on function app.item_financials(uuid) from public;
grant  execute on function app.item_financials(uuid) to authenticated;
