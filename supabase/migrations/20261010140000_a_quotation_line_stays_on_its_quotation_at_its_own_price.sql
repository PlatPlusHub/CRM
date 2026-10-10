-- SPEC-258 (Batch 6 Slice 36): a quotation line stays on the quotation it was added to, in that
-- quotation's currency, at its own quantity times its own unit price -- through the table door
-- exactly as through `app.add_quotation_item`, and while the quotation is being sent.
--
-- `authenticated` holds table-level INSERT and UPDATE on `public.quotation_items`, so PostgREST serves
-- the table beside the RPC. `app.add_quotation_item` locks the quotation `for update`, refuses any
-- status but `draft`, stamps the line with the quotation's currency and writes `quantity *
-- unit_price` as the line total; `app.recompute_quotation_total` then sums the line totals into the
-- quotation's total. Measured at `44c09d8` on the local stack, by an `employee` proven first to hold
-- CREATE_QUOTATION and SEND_QUOTATION:
--   * QUO-9: a direct INSERT of a 100 x 1 line with `total_amount` 90000 took the quotation from 500
--     to 90,500, and a direct UPDATE of a 500 x 1 line's total to 1 took it to 1. A USD line was
--     inserted on an EGP quotation and summed into its EGP total, and an existing line was re-labelled
--     SAR. A second employee carrying an explicit DENY on CREATE_QUOTATION, refused a price change and
--     refused the RPC, still set a line's total to 7 and the quotation followed: the capability charge
--     reads `unit_price` and `quantity` only, and the total moved without either.
--   * QUO-10: after the quotation was sent through `app.advance_quotation`, a direct UPDATE of its only
--     line's `quotation_id` moved the line to a draft. The sent quotation was left with no lines and a
--     total of 0 against a `quotation_sent` event of 1,000, and was then accepted at 0. The editable-
--     parent guard judged only the line's NEW quotation. The denied employee moved a line the same way.
--   * QUO-10: in two concurrent sessions, a direct INSERT that read the quotation as `draft` while
--     `app.advance_quotation` was sending it waited on the send's lock and then committed a second
--     line onto the sent quotation (1,300 against a `quotation_sent` event of 1,000). The RPC, run the
--     same way, waited, re-read the quotation as `sent` and refused.
--   * The guard runs before RLS's WITH CHECK and as its definer, so an employee naming another
--     tenant's SENT quotation was told "a sent quotation cannot have its lines changed" where RLS
--     would have refused. It now reads only the caller's own tenant, and RLS is the refuser.
--
-- THE SHAPE is the existing guard's, deliberately: one BEFORE INSERT OR UPDATE trigger on the line,
-- SECURITY DEFINER with an empty `search_path`, binding every caller. It reads the quotation under the
-- RPC's own lock, so a line and a send are ordered rather than interleaved. It refuses, as SPEC-214's
-- `app.guard_quotation_integrity` refuses a hand-written quotation total (QUO-7), rather than
-- rewriting what the caller stated. The line total is compared in the column's own type, so it is
-- rounded exactly as the RPC's stored product is.
--
-- NOT CHANGED: the trigger, its name and timing, the function's owner, security and ACL (its comment
-- is restated to name what it now holds); every grant,
-- policy, constraint, permission charge and state transition; `app.add_quotation_item`,
-- `app.advance_quotation` and `app.recompute_quotation_total`.
create or replace function app.guard_quotation_item_parent_editable()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_status   text;
    v_currency text;
    v_total    public.quotation_items.total_amount%type;
begin
    if tg_op = 'UPDATE' and new.quotation_id is distinct from old.quotation_id then
        raise exception
            'a quotation line stays on the quotation it was added to; add a new line to the other quotation instead'
            using errcode = '23514';
    end if;

    -- A signed-in caller naming another tenant's quotation is refused by RLS after this trigger; the
    -- guard neither locks that row nor reports its state or currency.
    select q.quotation_status_code, q.currency_code into v_status, v_currency
    from public.quotations q
    where q.id = new.quotation_id and q.tenant_id = new.tenant_id
      and ((select auth.uid()) is null or q.tenant_id = (select app.current_tenant_id()))
    for update;

    if v_status is null then
        return new;   -- the FK is the authority on existence; do not duplicate it here
    end if;

    if v_status <> 'draft' then
        raise exception
            'a % quotation cannot have its lines changed: only a draft quotation is editable', v_status
            using errcode = '23514';
    end if;

    if new.currency_code is distinct from v_currency then
        raise exception
            'a quotation in % is priced in %; this line names %', v_currency, v_currency, new.currency_code
            using errcode = '23514';
    end if;

    v_total := new.quantity * new.unit_price;
    if new.total_amount is distinct from v_total then
        raise exception
            'a quotation line''s total is its quantity times its unit price (%); it cannot be %',
            v_total, new.total_amount
            using errcode = '23514';
    end if;

    return new;
end
$$;

comment on function app.guard_quotation_item_parent_editable() is
    'QUO-2, QUO-9, QUO-10: a quotation line stays on the quotation it was added to, which must be a draft read under the lock app.add_quotation_item takes, in that quotation''s currency, at its own quantity times its unit price in the column''s type. SECURITY DEFINER because under INVOKER this read of the parent would be RLS-filtered and the guard would be weakest against the caller it must stop (BOOK-1); for a signed-in caller it reads only that caller''s tenant, so RLS refuses a foreign quotation. No session-less exemption: integrity, not authorization.';
