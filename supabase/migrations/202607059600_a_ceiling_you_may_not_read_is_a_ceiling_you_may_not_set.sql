-- PD-24 / SUP-2 -- a ceiling you may not READ is a ceiling you may not SET.
--
-- FOUND, and reproduced live before a line of this was written. `suppliers.credit_limit_amount` is
-- withheld from `authenticated` by column grant (SUP-1, `202607059200`) and served only by the gated
-- `app.supplier_credit`, which requires VIEW_FINANCIAL_DOCUMENTS. Its WRITE, on both doors, requires
-- only ASSIGN_SUPPLIER. Those are different role sets, measured rather than assumed:
--
--     ASSIGN_SUPPLIER          -> branch_manager, ceo, department_manager, owner, senior_employee
--     VIEW_FINANCIAL_DOCUMENTS -> ceo, finance_manager, owner
--
-- so **branch_manager, department_manager and senior_employee could set the ceiling they are
-- forbidden to know.** Reproduced as `senior_employee`, with the refusal proven first in the same
-- session: reading the column raised 42501 and `supplier_credit` returned `permitted=false` with no
-- amount, and then `update public.suppliers set credit_limit_amount = 999999` returned UPDATE 1 and
-- `app.create_supplier(..., 500000)` minted a supplier at half a million. Both verified by reading
-- the values back WITH rights afterwards -- not by "it did not throw".
--
-- WHY IT SURVIVED TWO PACKAGES THAT BOTH LOOKED AT THIS EXACT COLUMN. Each recorded the other as
-- the half it did not do:
--   * `86_supplier_credit_visibility_test.sql` opens "SEC-1c closed the WRITE half (a trainee
--     rewrote `credit_limit_amount` 1000 -> 999999). This file pins the READ half."
--   * `202607059200` (SUP-1) closes with "NOT CHANGED: `app.create_supplier` still accepts the limit
--     and still writes it; the write path and its ASSIGN_SUPPLIER charge are untouched."
-- Both statements are true. SEC-1c closed the write half **against a trainee**, who holds neither
-- permission; the middle of the role ladder was never the subject of either proof. This is the
-- standing rule in `AGENTS.md 6` -- a green guard proves only the property it actually measures --
-- and the property measured was "the weakest actor is refused", not "the authority is sufficient".
--
-- DERIVED, NOT CHOSEN. The permission is not a preference and no permission is minted here. An actor
-- who may SET a value KNOWS it: they supplied it. So a read gate on VIEW_FINANCIAL_DOCUMENTS whose
-- write costs less than VIEW_FINANCIAL_DOCUMENTS withholds nothing from the actors in the gap -- they
-- learn the ceiling by writing it. The floor is therefore forced by SUP-1's own guarantee rather than
-- by a new policy: the write must require AT LEAST what the read requires. That is exactly
-- VIEW_FINANCIAL_DOCUMENTS, the permission `app.supplier_balance` and `app.supplier_credit` already
-- charge for the same fact. Canon 28 assigns the field no authority of its own (canon 25 lists
-- `credit_limit` only as a payment TERM; canon 31 lists the column), which is why SUP-1 had to derive
-- the read permission too -- this derives the write from the identical source.
--
-- WHAT IS DELIBERATELY *NOT* DECIDED HERE. Requiring this on top of the table's existing
-- ASSIGN_SUPPLIER leaves {owner, ceo} able to set a ceiling; `finance_manager` holds
-- VIEW_FINANCIAL_DOCUMENTS but not ASSIGN_SUPPLIER and so still cannot write `suppliers` at all --
-- which is pre-existing behaviour from `guard_write_capability`, not introduced here. Whether the
-- role most obviously responsible for supplier credit terms SHOULD hold ASSIGN_SUPPLIER, or whether
-- supplier credit deserves a canon-28 permission of its own, is a business rule and is recorded as
-- **SUP-3** in `MASTER_GAP_REGISTER.md` rather than answered by this migration. Closing a proven hole
-- does not wait on that question, and guessing at it would be the invention this audit forbids.
--
-- THE SHAPE IS COPIED, NOT INVENTED. `app.guard_passenger_financials` (SPEC-159-A) already solves the
-- identical problem one table over -- a financial column on a table whose ordinary writes cost an
-- operational permission -- and its structure is followed exactly: exempt the session-less path, do
-- nothing when the financial field is not in play, then charge the financial permission. What is NOT
-- copied is its scope check: `booking_items` has an assigned owner to be scoped against and canon 28
-- reads "assigned" for ENTER_COST; a supplier is tenant master data with no assignee, and canon 28
-- gives VIEW_FINANCIAL_DOCUMENTS a tenant/branch scope. Inventing a scope here would be minting.
--
-- NOT CHANGED: no role gains or loses a permission; no RLS policy moves; no grant changes; the column
-- grant and `app.supplier_credit` are untouched; a supplier with NO ceiling is still ordinary
-- operational work costing only ASSIGN_SUPPLIER, exactly as a passenger with no price still costs
-- only CREATE_BOOKING_ITEM. `app.create_supplier` keeps its signature -- the parameter is still
-- accepted and still written, it is now simply authorized. Dropping the parameter would repeat
-- SPEC-156's integration-contract change for no gain, since the RPC is not the only door anyway.

create or replace function app.guard_supplier_credit_authority()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    -- Platform/system paths (canon 35 principle 6), identical to every sibling guard. Migrations,
    -- seeds, `provision_tenant` and the pgTAP fixtures that build a world as `postgres` have no
    -- `auth.uid()` and are not the subject of a tenant permission check.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- The ceiling is not in play. Creating or editing a supplier with no credit terms is ordinary
    -- master-data work and must keep costing exactly ASSIGN_SUPPLIER and nothing more.
    if tg_op = 'INSERT' and new.credit_limit_amount is null then
        return new;
    end if;

    -- `is not distinct from` rather than `=`: NULL is a real value for this column and CLEARING a
    -- ceiling is a change to the ceiling. `=` would have let an unprivileged actor erase the limit
    -- silently, which is the more dangerous direction of the two.
    if tg_op = 'UPDATE'
       and new.credit_limit_amount is not distinct from old.credit_limit_amount then
        return new;
    end if;

    -- `authorize`, not `has_permission`: it is what composes the MFA step-up, and every role holding
    -- VIEW_FINANCIAL_DOCUMENTS is in `app.requires_mfa`'s set, so a bare permission check would
    -- quietly drop a factor canon 28 requires from exactly these roles.
    perform app.authorize('VIEW_FINANCIAL_DOCUMENTS');

    return new;
end;
$$;

-- PostgreSQL grants EXECUTE to PUBLIC on every new function. `10_grant_model_test.sql` assertion 5
-- refuses that for any ORVION function and caught this one on its first run -- the class guard doing
-- exactly its job, which is why the revoke is here rather than a habit.
revoke all on function app.guard_supplier_credit_authority() from public;

comment on function app.guard_supplier_credit_authority() is
'SUP-2: writing suppliers.credit_limit_amount costs VIEW_FINANCIAL_DOCUMENTS -- the permission that '
'already governs READING it (SUP-1, app.supplier_credit). An actor who may set a value knows it, so '
'a read gate whose write costs less withholds nothing. Ordinary supplier writes are untouched.';

-- Fires BEFORE `suppliers_guard_write_capability` (PostgreSQL orders BEFORE row triggers by name,
-- and 'c' < 'w'). That ordering is not load-bearing -- both raise 42501 -- but it is stated because a
-- future reader comparing error TEXT between two guards on one table should know which speaks first.
create trigger suppliers_guard_credit_authority
    before insert or update on public.suppliers
    for each row execute function app.guard_supplier_credit_authority();
