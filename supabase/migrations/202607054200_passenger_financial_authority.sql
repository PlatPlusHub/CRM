-- SPEC-159-A -- the second financial write path had no financial authority and no privacy.
--
-- FOUND BY THE SPEC-159 LINEAGE PASS, not by a failing test. Before building an employee earnings
-- report it was necessary to prove there is ONE financial truth (owner directive §8). There was not.
--
-- `booking_item_passengers` carries `cost_amount_override` and `selling_amount_override` -- the
-- per-passenger fare and cost. Three defects, each proven live:
--
--   1. PRIVACY HOLE (SPEC-139 was applied to one table and not its sibling).
--        has_column_privilege('authenticated','booking_items','cost_amount','SELECT')                = false
--        has_column_privilege('authenticated','booking_item_passengers','cost_amount_override', ...) = TRUE
--      `booking_items` had its table-level SELECT removed and a column list granted; this table kept
--      a plain table-level SELECT, so every column including the two financial ones was readable.
--      RLS makes that reachable rather than theoretical: `booking_item_passengers.scope_isolation`
--      admits any row whose PARENT booking item is visible, and `booking_items.scope_isolation`
--      grants department/branch visibility of a colleague's items. So one employee could read a
--      colleague's per-passenger cost -- exactly the SEC-4 threat SPEC-139 exists to prevent.
--
--   2. AUTHORITY BYPASS (SPEC-145 and SPEC-154-A were applied to one table and not its sibling).
--      `app.link_passenger_to_booking_item` authorizes only `CREATE_BOOKING_ITEM` and then writes
--      both financial columns. It never asks for `ENTER_COST` or `ENTER_SELLING_PRICE`, and never
--      checks that the parent item is the caller's. `guard_booking_item_financials` protects
--      `booking_items` and does not fire here. An employee could therefore attach cost and selling
--      figures to ANY booking item they can see, including a colleague's -- the precise thing
--      SPEC-154-A made impossible one table over.
--
--   3. DIRECT DML. `authenticated` holds INSERT and UPDATE on this table, so neither defect needed
--      the RPC at all.
--
-- WHY THE COLUMNS ARE KEPT RATHER THAN DROPPED. Nothing reads them today -- no function, view or
-- report -- so the lazy reading is "dead columns, delete them". Per-passenger pricing is not
-- speculative in a travel agency (two passengers on one booking routinely carry different fares),
-- canon 06 and canon 24 model the passenger as a first-class entity, and AGENTS.md §3 keeps an
-- inevitable domain structure even with no current consumer. Deleting them would trade a five-minute
-- fix for a future structural migration. They are secured instead, and their lack of a reader is
-- recorded as a separate finding rather than resolved by amputation.

-- ---------------------------------------------------------------------------------------------
-- 1. Privacy: mirror SPEC-139 exactly. A table-level SELECT grant covers every column including
--    ones added later, which is why the fix is a column list and not a policy.
-- ---------------------------------------------------------------------------------------------
revoke select on public.booking_item_passengers from authenticated;

grant select (id, tenant_id, booking_item_id, passenger_id, created_at)
    on public.booking_item_passengers to authenticated;

comment on column public.booking_item_passengers.cost_amount_override is
    'Per-passenger cost. NOT readable by `authenticated` (SPEC-159-A, mirroring SPEC-139 on '
    'booking_items.cost_amount); reachable only through a SECURITY DEFINER accessor.';
comment on column public.booking_item_passengers.selling_amount_override is
    'Per-passenger selling price. Writing it requires ENTER_SELLING_PRICE and the parent item must '
    'be assigned to the caller (SPEC-159-A, mirroring SPEC-145/SPEC-154-A on booking_items).';

-- ---------------------------------------------------------------------------------------------
-- 2. Authority: the same rule the parent table already enforces, on the same permissions, with the
--    same scope test. Deliberately a TRIGGER and not a check inside the RPC -- the RPC is one of
--    two write paths and the direct-DML path is the one that was actually unguarded.
--
--    A raising trigger is correct HERE (owner directive §16): this table is written only by
--    `app.link_passenger_to_booking_item` and by direct DML, both single-tenant interactive paths.
--    No scheduled job, batch, or multi-tenant system path touches it -- verified against the
--    catalog before writing this -- so there is no WP-03-shaped risk of one tenant's refusal
--    aborting another tenant's run.
-- ---------------------------------------------------------------------------------------------
create or replace function app.guard_passenger_financials()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
    v_owner  uuid;
    v_sales  uuid;
    v_ops    uuid;
    v_scoped boolean;
begin
    -- service_role / migration path (canon 35 principle 6), identical to the parent guard.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- Nothing financial in play: linking a passenger with no price is ordinary operational work and
    -- must keep needing only CREATE_BOOKING_ITEM. Same reasoning that keeps a BARE booking item
    -- creatable without ENTER_SELLING_PRICE (SPEC-155).
    if new.cost_amount_override is null and new.selling_amount_override is null then
        return new;
    end if;

    if tg_op = 'UPDATE'
       and new.cost_amount_override is not distinct from old.cost_amount_override
       and new.selling_amount_override is not distinct from old.selling_amount_override then
        return new;
    end if;

    -- SCALARS, not a RECORD. plpgsql binds referenced variables as query parameters, so an
    -- unassigned RECORD field raises 55000 before any guarding condition can short-circuit -- the
    -- exact trap that broke `create_booking` on the direct path. This runs BEFORE the foreign key on
    -- `booking_item_id` is validated, so a bogus parent really can produce no row here; three
    -- scalars are simply NULL in that case, `is_my_booking_item` returns false, and the FK then
    -- rejects the row on its own.
    select bi.owner_user_id, bi.sales_owner_user_id, bi.operational_owner_user_id
      into v_owner, v_sales, v_ops
    from public.booking_items bi
    where bi.id = new.booking_item_id;

    v_scoped := app.is_my_booking_item(v_owner, v_sales, v_ops) or app.has_tenant_wide_read();

    if (tg_op = 'INSERT' and new.cost_amount_override is not null)
       or (tg_op = 'UPDATE' and new.cost_amount_override is distinct from old.cost_amount_override) then
        perform app.authorize('ENTER_COST');
        if not v_scoped then
            raise exception 'ENTER_COST is scoped to items assigned to you (canon 28: assigned)'
                using errcode = 'insufficient_privilege';
        end if;
    end if;

    if (tg_op = 'INSERT' and new.selling_amount_override is not null)
       or (tg_op = 'UPDATE' and new.selling_amount_override is distinct from old.selling_amount_override) then
        perform app.authorize('ENTER_SELLING_PRICE');
        if not v_scoped then
            raise exception 'ENTER_SELLING_PRICE is scoped to items assigned to you (canon 28: assigned)'
                using errcode = 'insufficient_privilege';
        end if;
    end if;

    return new;
end;
$fn$;

revoke execute on function app.guard_passenger_financials() from public;

-- "g" sorts after the existing "..._enforce_subscription_write_gate", so the subscription gate still
-- decides first and this guard judges a row the subscription already permits -- the same relative
-- ordering `booking_items` uses.
create trigger booking_item_passengers_guard_financials
    before insert or update on public.booking_item_passengers
    for each row execute function app.guard_passenger_financials();
