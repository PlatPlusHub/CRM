-- SPEC-154-A -- the financial guard becomes SCOPE-aware, so canon's "assigned" scope on
-- ENTER_COST / ENTER_SELLING_PRICE is enforced rather than merely written down.
--
-- THE GAP (recorded by SPEC-154, proven by `29_financial_write_authority_test.sql` assertion 6).
-- `app.guard_booking_item_financials` asked only "does this ROLE hold ENTER_COST?" and never "is
-- this item the caller's?". Canon 28 gives the ordinary employee ENTER_COST / ENTER_SELLING_PRICE
-- as **"Assigned only"**, so granting the permission against a role-only guard would have let an
-- employee price a COLLEAGUE's booking item -- exceeding canon rather than implementing it. SPEC-154
-- therefore withheld both permissions and recorded this package. This closes it in the right order:
-- fix the enforcement first, then grant.
--
-- WHAT "ASSIGNED" MEANS -- discovered, not invented. `booking_items` carries three ownership
-- columns (`owner_user_id`, `sales_owner_user_id`, `operational_owner_user_id`) and the table's own
-- SPEC-137 RLS policy already defines "this row is mine" as the caller matching ANY of the three.
-- That is ORVION's existing assignment concept, so this guard reuses it verbatim. Introducing a
-- second, narrower definition here would have created two competing answers to one question.
--
-- WHY IT APPLIES TO EVERY ROLE, not just `employee`. Canon 28's Employee column says "Assigned only"
-- while Senior Employee says "Yes" -- but `employee` and `senior_employee` hold an IDENTICAL scope
-- permission set (both have VIEW_DEPARTMENT_QUEUE and VIEW_DEPARTMENT_RECORDS; neither has
-- VIEW_BRANCH_DATA), so no permission-based discriminator between them exists. Canon settles it from
-- the other direction: the **Scope column of both permission rows reads `assigned`** for the whole
-- row, not per-role. Assignment is therefore the row-level rule, and the per-role wording is
-- emphasis. Encoding it uniformly needs no role names in the guard, which keeps the model
-- permission-driven exactly as canon 28 requires.
--
-- The single exemption is `app.has_tenant_wide_read()` (VIEW_ALL_BRANCHES -- owner and CEO only),
-- whose scope is tenant-wide everywhere else in the model. Without it the tenant owner could not
-- price an item they do not personally own, which no reading of canon supports.
--
-- WHAT IS NOT CHANGED -- deliberately. This migration only ADDS a condition; every existing
-- authority check stays exactly as written:
--   * EDIT_LOCKED_COST still governs a cost after the lock (canon scope: tenant) -- NO assignment
--     requirement, because a locked cost is finance's to edit precisely when it is not theirs.
--   * APPROVE_FINANCE still governs the lock itself and the approval status (canon scope: tenant).
--   * The zero-value reasoning is untouched: `cost_amount`/`selling_amount` are NOT NULL DEFAULT 0,
--     so only a NON-ZERO value counts as "entering" one.
--   * The `auth.uid() is null` service_role/migration exemption is untouched (canon 35 principle 6).
-- Nothing here weakens the guard; a caller who could not write before still cannot.

create or replace function app.is_my_booking_item(
    p_owner_user_id uuid,
    p_sales_owner_user_id uuid,
    p_operational_owner_user_id uuid
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $fn$
    -- Mirrors the ownership disjunction in booking_items' own RLS policy. `coalesce(... , false)`
    -- because any of the three columns may be NULL, and `uuid = NULL` is NULL rather than false --
    -- an unguarded three-way OR would return NULL and read as "not mine" only by accident.
    select coalesce((select app.current_user_id()) = p_owner_user_id, false)
        or coalesce((select app.current_user_id()) = p_sales_owner_user_id, false)
        or coalesce((select app.current_user_id()) = p_operational_owner_user_id, false)
$fn$;

revoke execute on function app.is_my_booking_item(uuid, uuid, uuid) from public;
grant  execute on function app.is_my_booking_item(uuid, uuid, uuid) to authenticated;

create or replace function app.guard_booking_item_financials()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_scoped boolean;
begin
    -- No authenticated end user means this is not an employee acting -- it is `service_role` or a
    -- migration, both of which canon 35 principle 6 places outside per-table enforcement. The
    -- exemption cannot be abused by a tenant user: without a resolved identity they fail
    -- `tenant_id = app.current_tenant_id()` on every policy and cannot reach a row at all.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- SPEC-154-A: canon's `assigned` scope for ENTER_COST / ENTER_SELLING_PRICE. Owner/CEO keep
    -- tenant-wide reach; everyone else must be an owner of the item they are pricing.
    v_scoped := app.is_my_booking_item(new.owner_user_id, new.sales_owner_user_id,
                                       new.operational_owner_user_id)
                or app.has_tenant_wide_read();

    if tg_op = 'INSERT' then
        -- `cost_amount` and `selling_amount` are NOT NULL DEFAULT 0, so "is not null" is never false
        -- and would demand a finance permission for an item carrying no financial value at all.
        -- Entering a cost means entering a NON-ZERO one; zero is the absence of a figure. Creating a
        -- bare item stays governed by CREATE_BOOKING_ITEM alone, which is what canon 28 says it is.
        if coalesce(new.cost_amount, 0) <> 0 then
            perform app.authorize('ENTER_COST');
            if not v_scoped then
                raise exception 'ENTER_COST is scoped to items assigned to you (canon 28: assigned)'
                    using errcode = 'insufficient_privilege';
            end if;
        end if;
        if coalesce(new.selling_amount, 0) <> 0 or new.commission_rate is not null then
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

    -- Cost after locking is a different act from cost before it. Canon 28 gives the first to the
    -- operational roles and the second to finance alone, which is the entire purpose of the lock: it
    -- moves the cost out of operations' reach. EDIT_LOCKED_COST carries canon scope `tenant`, so it
    -- is deliberately NOT assignment-scoped -- finance edits precisely the items that are not theirs.
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

    if new.selling_amount is distinct from old.selling_amount
       or new.commission_rate is distinct from old.commission_rate then
        perform app.authorize('ENTER_SELLING_PRICE');
        if not v_scoped then
            raise exception 'ENTER_SELLING_PRICE is scoped to items assigned to you (canon 28: assigned)'
                using errcode = 'insufficient_privilege';
        end if;
    end if;

    -- Setting or clearing the lock, and moving the finance approval status, are both finance acts.
    -- Clearing the lock matters most: without this, any operational user could unlock a cost and
    -- then edit it under ENTER_COST, making EDIT_LOCKED_COST unreachable in practice. Canon scope is
    -- `tenant`, so no assignment requirement here either.
    if new.cost_locked_at is distinct from old.cost_locked_at
       or new.finance_approval_status_code is distinct from old.finance_approval_status_code then
        perform app.authorize('APPROVE_FINANCE');
    end if;

    return new;
end
$fn$;

-- Now that the enforcement can honour canon's scope, the two permissions SPEC-154 withheld can be
-- granted as canon 28 requires. Order matters: guard first, grant second.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.code = 'employee'
  and p.key in ('ENTER_COST', 'ENTER_SELLING_PRICE')
  and not exists (
      select 1 from public.role_permissions rp
      where rp.role_id = r.id and rp.permission_id = p.id
  );
