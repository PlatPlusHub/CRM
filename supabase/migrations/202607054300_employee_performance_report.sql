-- SPEC-159 -- an employee can see their own results, and only their own.
--
-- OWNER REQUIREMENT (§7-§10): every employee gets a personal operational and financial performance
-- view -- sales, cost, gross profit, commission, company profit attributable to their work, filtered
-- by day / range / month / year / customer / supplier / airline, viewable, filterable, exportable
-- and printable. They must never see another employee's commission or margin, company-wide totals,
-- or branch-wide financials. "Enforced in the database, not by hiding it in the UI."
--
-- ================================================================================================
-- WHAT THE LINEAGE PASS ESTABLISHED BEFORE THIS VIEW WAS WRITTEN (owner directive §9 -- prove the
-- business data lineage first; do not begin by creating a report view).
--
--   * WHOSE SALE IS IT? Commission attaches to `sales_owner_user_id`. Derived, not guessed: canon 31
--     states `commission_rate` reserves the basis for *sales* commission, and `booking_items` carries
--     a dedicated sales ownership triple (`sales_owner_user_id` / `sales_owner_department_id` /
--     `sales_owner_branch_id`) distinct from `owner_*` and `operational_owner_user_id`.
--     Today `app.create_booking_item` sets all three to the creator and NO reassignment path exists,
--     so the fields are structurally distinct and operationally identical. This view keys on the
--     sales field so it stays correct when that changes; whether commission should follow a future
--     reassignment is BLOCKED-4 and does not block this.
--
--   * WHERE IS THE MONEY? `app.item_financials` is the single financial truth. Verified by sweep:
--     no other function, view or report computes `selling_amount - cost_amount`;
--     `app.booking_item_profit` and `reporting.booking_item_profit` both delegate to it. This view
--     delegates too, so a fourth definition cannot drift into existence.
--
--   * WHY A LATERAL CALL AND NOT A PLAIN SELECT. `authenticated` cannot SELECT `cost_amount` or
--     `commission_rate` at all (SPEC-139, re-verified live). A `security_invoker` view naming those
--     columns would fail for every employee. `reporting.booking_item_profit` already solved this
--     with `cross join lateral app.item_financials(bi.id)`; reusing that shape is what keeps
--     SPEC-139 intact instead of weakened.
--
--   * WHAT COUNTS AS A SALE? Archived items and `cancelled` / `no_show` items are excluded --
--     the rule `app.booking_item_profit` already applies. A cancelled sale earns no commission.
--     Reused rather than re-decided.
--
--   * AIRLINE IS NOT A NEW DIMENSION. `airline` is a value of the `supplier_type` catalog, and
--     canon 32 defers airline reference tables to the flight-ticketing feature. So "airline
--     performance" is supplier performance filtered by `supplier_type_code = 'airline'`, which this
--     view exposes. Inventing an airline column would have created a second vocabulary for a
--     concept the catalog already owns.
-- ================================================================================================
--
-- WHY EXACTLY ONE VIEW, when the owner listed leads, quotations, customers and bookings too.
-- The employee can already read their own `leads`, `quotations`, `customers` and `bookings` directly
-- under RLS (`authenticated` holds SELECT on all four, and each carries `owner_user_id`), so
-- counting them needs no new object. The ONLY thing impossible without a new object is the money,
-- because those columns are deliberately unreadable. Building four views to look complete would have
-- added three objects that duplicate what RLS already serves -- and `reporting.sales_activity` and
-- `reporting.lead_performance` already aggregate bookings and leads per owner.
--
-- FILTERING AND EXPORT need no mechanism either. Every filter the owner listed -- today, date range,
-- month, year, customer, supplier, airline -- is a WHERE clause over columns this view exposes, and
-- PostgREST serves the same view as CSV for export/print. No EXPORT permission is invented: canon 25
-- defines none, and creating one that every role would hold is not a control.

create view reporting.my_sales_performance
with (security_invoker = true)
as
select
    bi.id                            as booking_item_id,
    bi.tenant_id,
    bi.sales_owner_user_id,
    bi.booking_id,
    b.booking_reference,
    b.title                          as booking_title,
    b.customer_id,
    c.full_name                      as customer_name,
    bi.supplier_id,
    s.name                           as supplier_name,
    s.supplier_type_code,            -- 'airline' for airline performance; see the header note
    bi.service_type_code,
    bi.base_status_code,
    bi.currency_code,
    bi.created_at                    as sold_at,
    b.travel_start_date,
    b.travel_end_date,
    coalesce(bi.selling_amount, 0)   as selling_amount,
    f.cost_amount,
    f.profit                         as gross_profit,
    f.commission_amount              as employee_commission,
    f.company_profit
from public.booking_items bi
cross join lateral app.item_financials(bi.id) f
-- LEFT joins, deliberately. `booking_items.scope_isolation` admits a row on ownership alone, while
-- `bookings.scope_isolation` is a separate test -- so an item can be the caller's while its parent
-- booking is not visible to them. An inner join would silently drop that item and under-report the
-- employee's own commission, which is a worse failure than a null booking reference.
left join public.bookings  b on b.id = bi.booking_id
left join public.customers c on c.id = b.customer_id
left join public.suppliers s on s.id = bi.supplier_id
where bi.sales_owner_user_id = app.current_user_id()
  and bi.is_archived = false
  and bi.base_status_code not in ('cancelled', 'no_show');

comment on view reporting.my_sales_performance is
    'The signed-in employee''s own sales and earnings, one row per booking item. Scoped in the '
    'database by sales_owner_user_id = app.current_user_id(): a colleague''s rows are ABSENT, not '
    'masked. Money is derived by app.item_financials so there is one financial truth and SPEC-139 '
    'column privacy is untouched. Filter by sold_at / customer_id / supplier_id / '
    'supplier_type_code = ''airline''; export as CSV through the same view.';

-- FILTERED, not merely masked. `app.item_financials` would already null the money for an item the
-- caller does not own, but a masked row still discloses that a colleague made a sale, to which
-- customer, through which supplier, on which date. The owner's rule is that an employee sees "only
-- the employee's authorized results", so the colleague's row does not appear at all.
--
-- Note this makes the view genuinely personal for EVERY role, owner and CEO included: it answers
-- "what did I sell", never "what did the branch sell". Management aggregates are a separate
-- capability with a separate authority, and conflating them here is how a personal view becomes an
-- accidental management report.

grant select on reporting.my_sales_performance to authenticated;
