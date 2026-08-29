-- QUO-1 -- the third instance of the same class, and the first that is a DERIVED VALUE rather than
-- a refusal. Found by asking which functions compute an aggregate and write a table, after FIN-8 and
-- FIN-10 established that a set-level rule living in one function is a class rather than an accident.
--
-- `app.add_quotation_item` recomputes the parent's headline price after every insert:
--     update public.quotations set total_amount = (select coalesce(sum(total_amount), 0) ...)
-- so `quotations.total_amount` is DEFINED as the sum of its items. It is maintained on that one path
-- and on no other, while `quotation_items` is directly writable by any CREATE_QUOTATION holder
-- (branch_manager, ceo, department_manager, employee, owner, senior_employee -- six roles).
--
-- REPRODUCED as an ordinary `employee`:
--
--     RPC adds a 1000 item      -> quotation.total = 1000   items_sum = 1000   (agree)
--     DIRECT DML adds a 5000 item
--                               -> quotation.total = 1000   items_sum = 6000
--     DIRECT DML edits the first item down to 1
--                               -> quotation.total = 1000   items_sum = 5001
--
-- The header the customer is quoted and the lines it is built from disagree, by whatever amount the
-- employee chooses, in either direction. A quotation is a PRICE OFFERED TO A CUSTOMER: an underquote
-- the agency may have to honour, or an overquote that loses the sale, and `advance_quotation` reads
-- `total_amount` when the quotation is sent and accepted -- so the wrong number is the one that
-- travels into the booking.
--
-- WHY THIS IS NOT A NEW BUSINESS RULE. `quotations` has no discount, adjustment or override column;
-- the only two writers of `total_amount` are `add_quotation_item` (which recomputes it from the
-- items) and `advance_quotation` (which reads it). The total is already DEFINED as the sum. This
-- migration does not decide what a quotation costs -- it makes the existing definition true on every
-- path instead of one.
--
-- WHY RECOMPUTE RATHER THAN REFUSE, which is the one place this differs from FIN-8 and FIN-10.
-- Those two guard INVARIANTS -- statements that must hold, where the only correct response to a
-- violation is to reject the write. This is a DERIVED VALUE: there is no "user intent" for the
-- header that could conflict with the lines, because the header has no independent source. Refusing
-- a direct item write would be refusing something legitimate (adding a line) to protect a number the
-- database can simply keep correct. Recomputing is therefore both safer and smaller.
--
-- SAFE AGAINST THE GUARDS ALREADY ON `quotations`, checked rather than assumed:
--   * `quotations_guard_write_capability` is BEFORE INSERT ONLY (SEC-1b) -- an UPDATE does not reach it.
--   * `quotations_enforce_status_transition` returns early when the status column is unchanged.
--   * `quotations_enforce_archive_authority` returns early unless `is_archived` changes.
--   * `quotations_enforce_subscription_write_gate` does fire -- and correctly: a lapsed tenant that
--     cannot write the ITEM cannot reach this trigger at all, so the two agree by construction.
--
-- NO SESSION-LESS EXEMPTION, consistent with FIN-8 and FIN-10: a derived total left stale by a
-- platform path is exactly as wrong as one left stale by a tenant user.

create or replace function app.recompute_quotation_total()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_quotation uuid;
    v_tenant uuid;
begin
    -- DELETE carries no NEW. An UPDATE that MOVES an item between quotations would leave the old
    -- parent stale, so both sides are recomputed when they differ.
    v_quotation := coalesce((to_jsonb(new) ->> 'quotation_id')::uuid, (to_jsonb(old) ->> 'quotation_id')::uuid);
    v_tenant    := coalesce((to_jsonb(new) ->> 'tenant_id')::uuid,    (to_jsonb(old) ->> 'tenant_id')::uuid);

    if v_quotation is not null then
        update public.quotations q
           set total_amount = (select coalesce(sum(qi.total_amount), 0)
                                 from public.quotation_items qi
                                where qi.quotation_id = v_quotation),
               updated_at = now()
         where q.id = v_quotation and q.tenant_id = v_tenant
           and q.total_amount is distinct from (select coalesce(sum(qi.total_amount), 0)
                                                  from public.quotation_items qi
                                                 where qi.quotation_id = v_quotation);
    end if;

    -- The row's parent changed: the PREVIOUS parent is now stale too.
    if tg_op = 'UPDATE'
       and (to_jsonb(old) ->> 'quotation_id') is distinct from (to_jsonb(new) ->> 'quotation_id') then
        update public.quotations q
           set total_amount = (select coalesce(sum(qi.total_amount), 0)
                                 from public.quotation_items qi
                                where qi.quotation_id = (to_jsonb(old) ->> 'quotation_id')::uuid),
               updated_at = now()
         where q.id = (to_jsonb(old) ->> 'quotation_id')::uuid
           and q.tenant_id = (to_jsonb(old) ->> 'tenant_id')::uuid;
    end if;

    return null;
end;
$fn$;

-- SECURITY DEFINER so the SUM sees every line of the quotation regardless of the caller's row scope.
-- The UPDATE is bounded to the item's own `(tenant_id, quotation_id)`, and the FK on
-- `quotation_items` is composite `(tenant_id, quotation_id) -> quotations(tenant_id, id)`, so the
-- parent is necessarily in the same tenant -- the definer rights cannot reach another agency's row.
revoke execute on function app.recompute_quotation_total() from public;

create trigger quotation_items_recompute_total
    after insert or update or delete on public.quotation_items
    for each row execute function app.recompute_quotation_total();
