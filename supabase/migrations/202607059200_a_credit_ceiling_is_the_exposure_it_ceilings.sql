-- PD-24 / SUP-1 -- a credit ceiling is the exposure it ceilings, and is read by whoever may read that.
--
-- FOUND: `suppliers.credit_limit_amount` -- how much a travel agency may owe a supplier before it
-- stops booking -- is readable by EVERY authenticated user of the tenant. `suppliers` carries one
-- policy, `tenant_isolation FOR ALL`, whose qual is `tenant_id = current_tenant_id()` and nothing
-- else, and PostgREST serves the table, so a trainee reads the agency's commercial exposure ceiling
-- with one GET. (Its UPDATE half was closed by SEC-1c in `202607059100`; this is the READ half.)
--
-- DERIVED, NOT ASSUMED. The owner's instruction was explicit: do not put it behind
-- VIEW_FINANCIAL_DOCUMENTS merely because it looks financial. Two pieces of existing ORVION
-- evidence answer both halves of the question without inventing anything.
--
--   WHICH PERMISSION -- `app.supplier_balance` is ORVION's own reader for a supplier's financial
--   position, and it already raises 42501 unless the caller holds **VIEW_FINANCIAL_DOCUMENTS**:
--       if not app.has_permission('VIEW_FINANCIAL_DOCUMENTS') then
--           raise exception 'permission denied: VIEW_FINANCIAL_DOCUMENTS is required to read supplier balances'
--   The credit limit is the CEILING on precisely that balance. Guarding the amount owed while
--   publishing the maximum that may be owed protects one half of one fact. Same object, same
--   permission -- a shipped decision, not a new one.
--
--   WHICH MECHANISM -- ORVION already withholds finance-sensitive COLUMNS from `authenticated`
--   while leaving the row readable. Measured live: `booking_items` grants `authenticated` SELECT on
--   every column EXCEPT **`cost_amount`** and **`commission_rate`**, which are served instead by the
--   gated `app.item_financials`. `booking_item_passengers` follows the same shape. That is the
--   identical problem -- a sensitive column on an otherwise readable table -- already solved here,
--   so this migration copies it rather than inventing a view, a second table, or a new policy style.
--
-- WHY NOT RLS: row security cannot express a column. Splitting the column into its own table would
-- be a schema change with FK, RLS, grant and consumer consequences, to protect one numeric that has
-- exactly one writer. The column grant is the smaller change that closes the same hole.
--
-- WHY A READER IS INCLUDED: revoking alone would make the field write-only and REMOVE a capability
-- from finance, which is the regression class SEC-1c's own fix was checked against. `app.supplier_credit`
-- mirrors `app.item_financials` exactly -- SECURITY DEFINER, returning a `permitted` flag rather than
-- raising, so a caller can render "hidden" without handling an exception.
--
-- NOT CHANGED: `app.create_supplier` still accepts the limit and still writes it; the write path and
-- its ASSIGN_SUPPLIER charge are untouched. No role gains or loses a permission. No RLS policy moves.

-- HOW THE REVOKE HAS TO BE WRITTEN, learned by getting it wrong first. A column-level
-- `revoke select (credit_limit_amount)` against a role that holds TABLE-level SELECT is a no-op:
-- the table grant already covers every column, present and future, and PostgreSQL does not subtract
-- a column from it. The first draft did exactly that, and assertions 1 and 5 of
-- `86_supplier_credit_visibility_test.sql` failed while the migration reported success -- a silent
-- non-fix that only a behavioural assertion could catch. `booking_items` is right for this reason:
-- it holds NO table-level SELECT at all, only per-column grants.
--
-- The column list is DERIVED from `information_schema`, not typed out. A hardcoded list would be a
-- new place to drift the moment a column is added to `suppliers`, and the safe default for a NEW
-- column is to be readable like every other one -- the sensitive column is the named exception.
revoke select on public.suppliers from authenticated;
revoke select on public.suppliers from anon;

do $grant$
declare
    v_cols text;
begin
    select string_agg(quote_ident(column_name), ', ' order by ordinal_position)
      into v_cols
      from information_schema.columns
     where table_schema = 'public' and table_name = 'suppliers'
       and column_name <> 'credit_limit_amount';

    execute format('grant select (%s) on public.suppliers to authenticated', v_cols);
end
$grant$;

create or replace function app.supplier_credit(p_supplier_id uuid)
returns table (credit_limit_amount numeric, permitted boolean)
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    -- The row must be visible to the CALLER, not merely to this DEFINER function. Without this a
    -- SECURITY DEFINER reader would happily return another tenant's ceiling to anyone who guessed an
    -- id -- the failure mode DEFINER functions exist to create.
    if not exists (select 1 from public.suppliers s
                    where s.id = p_supplier_id and s.tenant_id = v_tenant) then
        raise exception 'supplier is not in your tenant' using errcode = '42501';
    end if;

    -- Mirrors `app.item_financials`: report the refusal rather than raising, so a UI can render the
    -- field as withheld. The refusal is still total -- no amount is returned.
    if not app.has_permission('VIEW_FINANCIAL_DOCUMENTS') then
        return query select null::numeric, false;
        return;
    end if;

    return query
    select s.credit_limit_amount, true
    from public.suppliers s
    where s.id = p_supplier_id and s.tenant_id = v_tenant;
end;
$fn$;

revoke execute on function app.supplier_credit(uuid) from public;
grant execute on function app.supplier_credit(uuid) to authenticated;

create or replace function public.supplier_credit(p_supplier_id uuid)
returns table (credit_limit_amount numeric, permitted boolean)
language sql
stable
security invoker
set search_path = ''
as $fn$ select * from app.supplier_credit(p_supplier_id) $fn$;

revoke execute on function public.supplier_credit(uuid) from public;
grant execute on function public.supplier_credit(uuid) to authenticated;
