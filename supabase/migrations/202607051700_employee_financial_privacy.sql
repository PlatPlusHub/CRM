-- Migration: employee_financial_privacy
-- Plan reference: SPEC-139. Implements the owner's rule that seeing a booking must not mean seeing
-- another employee's profit or commission.
--
-- WHERE THIS STOOD. `booking_items.cost_amount` and `commission_rate` were readable by anyone who
-- could read the row, and `reporting.booking_item_profit` -- a `security_invoker` view granted to
-- `authenticated` -- served `cost_amount` and `profit` straight out. SPEC-137 narrowed WHICH rows an
-- employee can see, but a department colleague can legitimately see a colleague's booking item, and
-- with it came that item's margin. Canon 31 records `commission_rate` as the path for "future sales
-- commission calculation", so this is one employee's earnings visible to another.
--
-- THE RULE IS ALREADY IN CANON. Canon 28's Finance table scopes VIEW_FINANCIAL_DOCUMENTS as
-- Owner Yes / CEO Yes / Finance Manager Yes / Branch Manager Optional / Department Manager No /
-- Senior Employee and Employee "Assigned related only", with the note "Assigned employee may view
-- financial documents directly related to their lead/booking". That is exactly the owner's
-- requirement, so no new permission is minted: financial visibility is
--
--     holds VIEW_FINANCIAL_DOCUMENTS   (the finance roles, tenant-wide)
--     OR is one of the item's own responsible users   (the "assigned related only" case)
--
-- WHY A COLUMN GRANT RATHER THAN A ROW RULE. Hiding the whole record was ruled out by the owner and
-- would be wrong anyway -- the colleague needs the booking to serve the customer. The visibility
-- rule is per row AND per column, which RLS alone cannot express: a policy decides whether a row is
-- returned, not which of its columns are. Column privileges are the mechanism Postgres provides for
-- the column half, so the sensitive columns are removed from the `authenticated` grant entirely and
-- re-served through `app.item_financials`, a SECURITY DEFINER accessor that applies the rule per
-- item and returns NULL where it does not hold.
--
-- CONSEQUENCE, DELIBERATE: `select *` on `booking_items` as `authenticated` now fails. Postgres
-- checks column privileges on the reference, not on the result, so there is no way to keep `*`
-- working and still withhold a column. A client must name the columns it wants -- which is the
-- correct discipline for a table that holds one employee's earnings next to another's work, and is
-- how the reporting views already read it.

-- ---------------------------------------------------------------------------------------------
-- 1. The gate, and the only path to the numbers it guards.
-- ---------------------------------------------------------------------------------------------
create or replace function app.item_financials(p_booking_item_id uuid)
returns table (cost_amount numeric, commission_rate numeric, profit numeric, permitted boolean)
language sql
stable
security definer
set search_path = ''
as $$
    select case when g.ok then coalesce(bi.cost_amount, 0) end,
           case when g.ok then bi.commission_rate end,
           case when g.ok then coalesce(bi.selling_amount, 0) - coalesce(bi.cost_amount, 0) end,
           g.ok
    from public.booking_items bi
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
$$;
revoke execute on function app.item_financials(uuid) from public;
grant execute on function app.item_financials(uuid) to authenticated;

-- ---------------------------------------------------------------------------------------------
-- 2. Remove the two columns from the authenticated grant.
--
-- A column-level REVOKE has no effect while a table-level SELECT grant stands -- the table grant
-- already covers every column, including ones added later. The only way to withhold a column is to
-- drop the table-level grant and re-grant the permitted columns explicitly, which is what this does.
-- Generated from the catalog so the statement cannot fall out of step with the table.
-- ---------------------------------------------------------------------------------------------
do $$
declare
    v_cols text;
begin
    select string_agg(quote_ident(a.attname), ', ' order by a.attnum) into v_cols
    from pg_attribute a
    where a.attrelid = 'public.booking_items'::regclass
      and a.attnum > 0 and not a.attisdropped
      and a.attname not in ('cost_amount', 'commission_rate');

    execute 'revoke select on public.booking_items from authenticated';
    execute format('grant select (%s) on public.booking_items to authenticated', v_cols);
end
$$;

-- ---------------------------------------------------------------------------------------------
-- 3. Rework the two read primitives that used to serve the numbers ungated.
--
-- `booking_item_profit` stays SECURITY INVOKER on purpose: that is what keeps SPEC-137's row scope
-- the single authority over WHICH items appear. It simply no longer touches the withheld columns --
-- it joins to the gated accessor instead. Making it DEFINER would have been the easy fix and the
-- wrong one, because it would have had to re-implement the scope model and become a second place
-- for it to drift.
-- ---------------------------------------------------------------------------------------------
create or replace function app.booking_item_profit(
    p_booking_id uuid default null,
    p_booking_item_id uuid default null
)
returns table (
    booking_item_id uuid,
    booking_id uuid,
    currency_code text,
    selling_amount numeric,
    cost_amount numeric,
    profit numeric,
    cost_locked boolean
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    return query
    select
        bi.id,
        bi.booking_id,
        bi.currency_code,
        coalesce(bi.selling_amount, 0) as selling_amount,
        f.cost_amount,
        f.profit,
        (bi.cost_locked_at is not null) as cost_locked
    from public.booking_items bi
    cross join lateral app.item_financials(bi.id) f
    where bi.tenant_id = v_tenant
      and bi.is_archived = false
      and bi.base_status_code not in ('cancelled', 'no_show')
      and (p_booking_id is null or bi.booking_id = p_booking_id)
      and (p_booking_item_id is null or bi.id = p_booking_item_id)
    order by bi.booking_id, bi.id;
end;
$$;

-- Supplier payables are wholesale cost data: what ORVION pays its suppliers, aggregated. Canon 28
-- defines no operational permission for it, and there is no "my own work" reading of a supplier-wide
-- total, so this one is simply finance-only. SECURITY DEFINER because it must read the withheld
-- column; the explicit tenant filter it already carried is what keeps that safe, and the gate is
-- checked before any row is produced.
create or replace function app.supplier_balance(
    p_supplier_id uuid,
    p_booking_id uuid default null
)
returns table (
    currency_code text,
    cost_amount numeric,
    paid_amount numeric,
    outstanding_payable numeric
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    if not app.has_permission('VIEW_FINANCIAL_DOCUMENTS') then
        raise exception 'permission denied: VIEW_FINANCIAL_DOCUMENTS is required to read supplier balances'
            using errcode = '42501';
    end if;

    perform 1 from public.suppliers
    where id = p_supplier_id and tenant_id = v_tenant;
    if not found then
        raise exception 'supplier is not in your tenant';
    end if;

    return query
    with contrib as (
        select bi.currency_code, bi.cost_amount as cost, 0::numeric as paid
        from public.booking_items bi
        where bi.tenant_id = v_tenant
          and bi.supplier_id = p_supplier_id
          and bi.cost_locked_at is not null
          and bi.is_archived = false
          and bi.base_status_code not in ('cancelled', 'no_show')
          and bi.cost_amount is not null
          and (p_booking_id is null or bi.booking_id = p_booking_id)
        union all
        select p.currency_code, 0::numeric, p.amount
        from public.payments p
        where p.tenant_id = v_tenant
          and p.supplier_id = p_supplier_id
          and p.payment_direction_code = 'supplier_payment'
          and (p_booking_id is null or p.booking_id = p_booking_id)
    )
    select
        c.currency_code,
        sum(c.cost) as cost_amount,
        sum(c.paid) as paid_amount,
        sum(c.cost) - sum(c.paid) as outstanding_payable
    from contrib c
    group by c.currency_code
    order by c.currency_code;
end;
$$;
revoke execute on function app.supplier_balance(uuid, uuid) from public;
grant execute on function app.supplier_balance(uuid, uuid) to authenticated;
