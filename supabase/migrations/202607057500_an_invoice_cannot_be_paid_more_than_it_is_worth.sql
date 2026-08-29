-- FIN-10 -- the second instance of FIN-8's class, found by looking for it rather than tripping over
-- it: a SET-LEVEL business invariant enforced in exactly one function.
--
-- `app.record_payment` will not allocate more to an invoice than the invoice is worth. It even takes
-- `pg_advisory_xact_lock` on the invoice first -- so the author knew this was a statement about a SET
-- of rows and that concurrency could break it. Nothing enforced it on any other path.
--
-- REPRODUCED as a `finance_manager` (aal2), holding RECORD_PAYMENT -- the same permission the RPC
-- charges, so this is not a privilege escalation but a door with no invariant behind it:
--
--     invoice total 1000, issued
--     RPC pays 400                  -> allocated 400,  status partially_paid
--     RPC tries 900 more            -> ERROR 'payment 900 exceeds invoice outstanding 600.0000'
--     DIRECT DML: payment 900 + allocation 900
--                                   -> SUCCEEDED.  invoice_total=1000  ALLOCATED=1300
--                                      status still 'partially_paid'
--
-- An invoice worth 1,000 carrying 1,300 of allocations, still reporting itself unpaid.
-- `reporting.customer_outstanding` derives `paid_amount` and `outstanding_balance` from this data,
-- so the customer's balance is wrong in the direction that matters commercially -- the agency
-- believes it is owed money it has over-collected, or the reverse, depending on which figure is read.
--
-- WHY NO CHECK CONSTRAINT COULD HAVE DONE THIS, and it is the same structural reason as FIN-8:
-- `payment_allocations` already has `CHECK (allocated_amount >= 0)` -- a per-row rule. "The SUM of
-- allocations for an invoice must not exceed that invoice's total" spans rows in two tables and a
-- CHECK cannot express it.
--
-- THE RULE IS COPIED, NOT CHOSEN. `record_payment` computes
--     v_remaining := invoices.total_amount - coalesce(sum(payment_allocations.allocated_amount), 0)
-- and refuses when the new amount exceeds it. The trigger below asserts the same inequality on the
-- resulting state. Nothing about what a valid allocation is changes here; only where it is enforced.
--
-- DEFERRED, for the same reason as FIN-8: `record_payment` inserts the payment, then the allocation,
-- then updates the invoice status. `deferrable initially deferred` checks at COMMIT, which is the
-- only moment the invariant must hold.
--
-- BOTH SIDES OF THE INEQUALITY ARE GUARDED. Allocations can exceed the total by growing, or by the
-- total SHRINKING beneath them -- `invoices.total_amount` is writable by a CREATE_INVOICE holder
-- (guarded for capability by FIN-3, not for this invariant). A trigger on `payment_allocations`
-- alone would leave the second route open, which is precisely the half-fix DOC-LC-1 and FIN-8 both
-- had to avoid.
--
-- NO SESSION-LESS EXEMPTION, consistent with FIN-8 and for the same reason: this is data integrity,
-- not authorization. Canon 35 principle 6 exempts platform paths from per-table AUTHORIZATION; an
-- over-allocated invoice created by a migration is exactly as wrong as one created by a tenant user.
--
-- NOT ADDRESSED HERE, and recorded rather than assumed away: direct-DML allocation also leaves
-- `invoices.status_code` unchanged (the RPC advances it to `partially_paid`/`paid`) and emits no
-- event. That is **FIN-11** -- the same shape as FIN-9 one table over, and it needs the same decision
-- about where side effects belong rather than a second producer bolted on here.

create or replace function app.enforce_invoice_allocation_ceiling()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_invoice uuid;
    v_total numeric;
    v_allocated numeric;
begin
    -- DELETE carries no NEW. On `invoices` the row IS the invoice; on `payment_allocations` it is
    -- the invoice the row points at.
    v_invoice := case tg_table_name
                   when 'invoices'            then coalesce((to_jsonb(new) ->> 'id')::uuid,
                                                            (to_jsonb(old) ->> 'id')::uuid)
                   when 'payment_allocations' then coalesce((to_jsonb(new) ->> 'invoice_id')::uuid,
                                                            (to_jsonb(old) ->> 'invoice_id')::uuid)
                 end;
    if v_invoice is null then
        return null;
    end if;

    -- The invoice may have been removed in this same transaction; there is then nothing to exceed.
    select i.total_amount into v_total
    from public.invoices i where i.id = v_invoice;
    if not found then
        return null;
    end if;

    select coalesce(sum(pa.allocated_amount), 0) into v_allocated
    from public.payment_allocations pa
    where pa.invoice_id = v_invoice;

    if v_allocated > v_total then
        raise exception
            'invoice % is over-allocated: % allocated against a total of % (an invoice cannot be paid more than it is worth)',
            v_invoice, v_allocated, v_total using errcode = '23514';
    end if;

    return null;
end;
$fn$;

-- SECURITY DEFINER with a pinned search_path so the trigger sums EVERY allocation for the invoice,
-- including rows an RLS policy would scope away from the caller. It reads and never writes, and a
-- trigger function needs no EXECUTE grant.
revoke execute on function app.enforce_invoice_allocation_ceiling() from public;

create constraint trigger payment_allocations_within_invoice_total
    after insert or update or delete on public.payment_allocations
    deferrable initially deferred
    for each row execute function app.enforce_invoice_allocation_ceiling();

-- The second route: lowering the invoice total beneath what is already allocated.
create constraint trigger invoices_total_covers_allocations
    after update on public.invoices
    deferrable initially deferred
    for each row execute function app.enforce_invoice_allocation_ceiling();
