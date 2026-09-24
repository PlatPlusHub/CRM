-- SPEC-214 / QUO-5, QUO-6, QUO-7, QUO-8 -- Batch 6 slice 14, `quotations`.
--
-- THE RULE. The table door may not give a quotation a state or a commercial term that its own
-- lifecycle RPCs cannot give it. `app.create_quotation` creates a quotation as a `draft` with no
-- items and a total of 0; `app.advance_quotation` refuses to send a quotation with no items;
-- nothing ever changes a quotation's customer or currency; and the total is maintained by
-- `app.recompute_quotation_total` from the items. `authenticated` holds table-level INSERT and
-- UPDATE here, and before this migration the door enforced the transition AUTHORITY
-- (`enforce_status_transition`) and none of that STATE:
--   * QUO-5 -- a quotation could be born `accepted` or `sent` (ENTRY-1's class): a user holding
--     explicit denies on SEND_QUOTATION and ACCEPT_QUOTATION inserted one born `accepted`, with no
--     items and no event, and `app.create_booking` produced a booking from it.
--   * QUO-6 -- a SENT or ACCEPTED quotation's customer and currency were rewritable: a booking was
--     produced for a customer the offer was never sent to, and an accepted EGP quotation was
--     re-denominated to SAR while its lines stayed EGP.
--   * QUO-7 -- the header total could be asserted independently of the lines (QUO-1's header
--     half): 1 against 10,000 of lines, recorded in the `quotation_sent` event's payload.
--   * QUO-8 -- an empty draft could be sent directly, which the RPC refuses.
--
-- THE SHAPE is `app.guard_invoice_integrity`'s (INVOICE-2/4/5), deliberately: SECURITY INVOKER so
-- `current_user` names the caller, the definer paths owned by `postgres` pass through --
-- `app.recompute_quotation_total` (which is what keeps the total true) and
-- `app.merge_customer_identity` (which must re-point every customer referrer). Unlike most guards
-- here it carries NO separate `auth.uid() is null` exemption, and that is measured, not forgotten:
-- `service_role` holds no INSERT or UPDATE on this table, so the only session-less writer is
-- `postgres`, which the first line already admits -- the clause could never decide anything, and a
-- later session-less writer is refused until someone decides it should not be. The item count is
-- read as the caller, which is exactly what `app.advance_quotation` does: item visibility is the
-- parent's.
--
-- NOT CHANGED: every grant, policy, index and constraint; every other trigger; every RPC.
-- `valid_until`, the lead, the owner fields and the archive fields stay writable exactly as before.
create or replace function app.guard_quotation_integrity()
returns trigger
language plpgsql
set search_path to ''
as $$
begin
    if current_user = 'postgres' then
        return new;
    end if;

    if tg_op = 'INSERT' then
        if new.quotation_status_code is distinct from 'draft' then
            raise exception
                'a quotation is created as a draft (canon 26); it cannot be created already % -- use app.advance_quotation',
                new.quotation_status_code using errcode = '23514';
        end if;
        if new.total_amount is distinct from 0 then
            raise exception
                'a quotation''s total is the sum of its items and a new quotation has none; it cannot be created at %',
                new.total_amount using errcode = '23514';
        end if;
        return new;
    end if;

    if new.customer_id is distinct from old.customer_id
       or new.currency_code is distinct from old.currency_code then
        raise exception
            'quotation % keeps the customer and currency it was created with; create a new quotation instead',
            old.quotation_number using errcode = '23514';
    end if;

    if new.total_amount is distinct from old.total_amount then
        raise exception
            'quotation % total is the sum of its items and is maintained by them; change the items instead',
            old.quotation_number using errcode = '23514';
    end if;

    if new.quotation_status_code = 'sent'
       and old.quotation_status_code is distinct from 'sent'
       and not exists (select 1 from public.quotation_items qi
                        where qi.quotation_id = new.id and qi.tenant_id = new.tenant_id) then
        raise exception 'a quotation needs at least one item before it can be sent'
            using errcode = '23514';
    end if;

    return new;
end;
$$;

revoke execute on function app.guard_quotation_integrity() from public;

create trigger quotations_guard_integrity
    before insert or update on public.quotations
    for each row execute function app.guard_quotation_integrity();
