-- Migration: a quotation that left the building is not a draft
-- Batch 6, table-by-table audit — care/conversation slice (QUO-2, QUO-3).
--
-- WHAT THIS SLICE MEASURED FIRST. `complaints`, `service_requests`, `conversations`,
-- `conversation_messages` and `quotation_items` were swept for their real write surface. Four of the
-- five came back clean and are recorded as such rather than left unstated:
--   * `complaints` and `service_requests` each carry SEVEN triggers — catalog codes, status
--     transition, archive authority, subscription gate, created_by derivation and the capability
--     guard. NOT A DEFECT.
--   * `conversation_messages` derives its sender (`derive_message_sender`) and forbids rewriting a
--     sent message (`forbid_message_rewrite`). NOT A DEFECT.
--   * `conversations` has neither `is_archived` nor an actor column, so the two guards it lacks
--     relative to its siblings are guards it has nothing to apply to. NOT A DEFECT — checked, not
--     assumed from the trigger count.
-- `quotation_items` is the one that failed, and it failed twice.
--
-- ---------------------------------------------------------------------------------------------
-- QUO-2 — a quotation already SENT to the customer could still be edited.
--
-- `app.add_quotation_item` refuses it: "items can only be added to a draft quotation (status: sent)".
-- `guard_financial_capability` charges CREATE_QUOTATION for a change to `unit_price`/`quantity` and
-- never looks at the parent's status. REPRODUCED in one transaction, as a caller who legitimately
-- holds CREATE_QUOTATION and SEND_QUOTATION, against a quotation legally advanced draft -> sent:
--   RPC add          -> refused, "items can only be added to a draft quotation"
--   direct INSERT    -> SUCCEEDED: a new 7,777 line appeared on a quotation the customer already has
--   direct UPDATE    -> SUCCEEDED: an existing line went from 10,000 to 1
-- An offer that has left the building is a record of what was offered. This is BOOK-1's shape in the
-- pre-sale domain, and ASGN-3's exactly: the RPC knew the rule and the table did not.
--
-- THE UPDATE HALF IS DERIVED, AND THAT IS STATED. Only the INSERT rule exists in an RPC, because
-- there is NO `update_quotation_item` function at all — direct DML is the only way to reprice a line.
-- The rule is extended to UPDATE because the REASON `add_quotation_item` gives ("a draft quotation")
-- is a statement about the parent's editability, not about the verb; and because leaving UPDATE open
-- would close the door the RPC guards while leaving the one it does not guard wide open, which is
-- the worse half of the same defect.
--
-- ---------------------------------------------------------------------------------------------
-- QUO-3 — a negative price and a zero quantity were both storable.
--
-- `app.add_quotation_item` refuses both: "unit_price must be >= 0 and quantity > 0".
-- `quotation_items` carried NO CHECK constraints at all. REPRODUCED, same transaction, same caller:
-- `unit_price = -5000` stored, `quantity = 0` stored. `quotation_items.total_amount` feeds
-- `quotations.total_amount` through `recompute_quotation_total`, so a negative line silently reduces
-- the quoted total.
--
-- `>= 0` for price and `> 0` for quantity, copied from the RPC rather than chosen here: a zero-price
-- line is a real thing (an included transfer, a waived fee); a zero-quantity line is not a line.
--
-- ---------------------------------------------------------------------------------------------
-- ENFORCEMENT LAYER, from the measured surface (ADR-0025), and the two halves land differently:
--   * QUO-3 is decidable from the row alone, so a CHECK is the narrowest layer and no door can
--     reach around it.
--   * QUO-2 is a statement about ANOTHER table (the parent's status), which a CHECK cannot express,
--     so it is a trigger. No session-less exemption: this is integrity, not authorization, and a
--     sent quotation is fixed whoever is asking. Verified there is nothing to exempt —
--     `recompute_quotation_total` writes `quotations`, not `quotation_items`, and no system path
--     inserts a line.
--   * `authenticated` holds INSERT/SELECT/UPDATE and no DELETE on this table, so the trigger covers
--     insert and update and deliberately does not invent a delete branch.
--
-- NOT DONE HERE, AND NOT BY OVERSIGHT: canon 28 records CREATE_QUOTATION as "Assigned only" for
-- `employee`, and NOTHING enforces that on either door — `app.add_quotation_item` checks the tenant
-- and the draft status, never the owner. Reproduced: one employee repriced a colleague's quotation
-- line from 10,000 to 1. That is not a two-door gap (both doors agree) but a canon-vs-implementation
-- one, and its answer is not derivable: canon's own scope column for this permission reads
-- "assigned/department", the 2026-08-24 directive granted department continuity deliberately, and
-- choosing between them decides who may work on whose quotation. Recorded as QUO-4, OWNER DECISION.

alter table public.quotation_items
    add constraint quotation_items_unit_price_nonneg_check check (unit_price >= 0);

alter table public.quotation_items
    add constraint quotation_items_quantity_positive_check check (quantity > 0);

comment on constraint quotation_items_unit_price_nonneg_check on public.quotation_items is
    'QUO-3: app.add_quotation_item refuses "unit_price must be >= 0 and quantity > 0"; the table had no CHECK constraints at all and stored -5000 by direct DML. total_amount feeds quotations.total_amount through recompute_quotation_total, so a negative line silently reduces the quoted total.';

create or replace function app.guard_quotation_item_parent_editable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_status text;
begin
    select q.quotation_status_code into v_status
    from public.quotations q
    where q.id = new.quotation_id and q.tenant_id = new.tenant_id;

    if v_status is null then
        return new;   -- the FK is the authority on existence; do not duplicate it here
    end if;

    if v_status <> 'draft' then
        raise exception
            'a % quotation cannot have its lines changed: only a draft quotation is editable', v_status
            using errcode = '23514';
    end if;

    return new;
end
$fn$;

comment on function app.guard_quotation_item_parent_editable() is
    'QUO-2: app.add_quotation_item refuses an item on a non-draft quotation and the table door did not -- a line could be added to, or repriced on, a quotation the customer already had. SECURITY DEFINER because under INVOKER this read of the parent would be RLS-filtered and the guard would be weakest against the caller it must stop (BOOK-1). No session-less exemption: integrity, not authorization.';

-- BOOK-1's mandatory REVOKE: a SECURITY DEFINER function must not be callable by clients.
revoke all on function app.guard_quotation_item_parent_editable() from public;

create trigger quotation_items_guard_parent_editable
    before insert or update on public.quotation_items
    for each row execute function app.guard_quotation_item_parent_editable();
