-- BOOK-1 -- a closed booking cannot grow new revenue, on any path.
--
-- API-3, booking/passenger family. `app.create_booking_item` refuses to add an item to a booking
-- that is archived, completed or cancelled, and `app.link_passenger_to_booking_item` refuses to
-- attach a passenger to an item on such a booking (or to an item that is itself cancelled, no_show
-- or archived). Both rules lived in exactly one function each.
--
-- REPRODUCED as an ordinary `employee` holding CREATE_BOOKING_ITEM, ENTER_COST and
-- ENTER_SELLING_PRICE -- the same permissions the RPC charges -- against a booking driven to
-- `cancelled` through the legal RPC path:
--
--     RPC  create_booking_item          -> REFUSED 'cannot add items to a cancelled booking'
--     DIRECT INSERT into booking_items  -> SUCCEEDED. selling 5000, cost 3000, on a CANCELLED booking
--                                          gross_profit 2000, and `commission_rate` 0.10 derived
--                                          automatically by booking_items_derive_commission_rate
--     events 'booking_item_created'     -> 0. The direct path emits nothing, so it is also unaudited
--     RPC  link_passenger…              -> REFUSED 'cannot add a passenger to an item on a cancelled booking'
--     DIRECT INSERT into …_passengers   -> SUCCEEDED, overrides 999 / 111
--
-- WHY IT MATTERS BEYOND TIDINESS. The ratified commission rule is
-- `gross_profit = selling - cost` and `employee_commission = max(gross,0) x 10%`, and
-- `commission_rate` is system-derived precisely so a caller cannot choose it. Nothing derives the
-- BOOKING'S state into that calculation, so a cancelled trip that never happened contributed 2,000
-- of gross profit and 200 of commission, while the booking beside it still reads `cancelled`.
--
-- WHY A TRIGGER AND NOT A CHECK: the rule is about ANOTHER ROW IN ANOTHER TABLE -- the parent
-- booking's status. A CHECK constraint cannot reference a second table, and a foreign key cannot
-- carry a predicate. This is the same "the RPC refuses what the table does not" class as FIN-6,
-- FIN-8, FIN-10 and DOC-LC-1; it is not the aggregate-across-rows subclass, so the SEC-1 clause-3
-- filter would NOT have found it, which is worth recording -- that filter is a lead, not a sieve.
--
-- WHY BEFORE ROW AND NOT A DEFERRED CONSTRAINT TRIGGER: unlike FIN-8/FIN-10 this invariant is true
-- at every instant, not only between statements. Creating a booking, adding items and THEN
-- cancelling it is ordinary and legal; only the reverse order is the violation. A deferred trigger
-- would have made the legal order fail at commit.
--
-- DELIBERATELY ASYMMETRIC WITH FIN-10: that one had to guard both sides of its inequality, because
-- an invoice total can shrink beneath its allocations. Here the mirror case -- cancelling a booking
-- that already has items -- is CORRECT BUSINESS BEHAVIOUR and must keep working. So there is no
-- trigger on `bookings`, and that is a decision rather than an omission.
--
-- NO SESSION-LESS EXEMPTION (SEC-1 Refinement 2). `guard_booking_item_financials` exempts
-- `auth.uid() is null` because it is AUTHORIZATION -- who may price an item. This is INTEGRITY: an
-- item attached to a cancelled booking is equally incoherent whether a tenant user or a migration
-- created it. Consumer sweep (`AGENTS.md 3 5b`): `app.create_booking_item` and
-- `app.link_passenger_to_booking_item` are the ONLY functions that insert these tables -- verified
-- against pg_proc, not assumed -- and both already perform this check, so both keep their clearer
-- error message and reach this trigger only on a path that should never have existed.

create or replace function app.enforce_booking_item_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_status   text;
    v_archived boolean;
begin
    -- Only the act of ATTACHING an item to a booking is governed. Editing an item already attached
    -- to a closed booking is a different question with different answers (a correction to a
    -- historical record may be legitimate) and is governed by the financial guard, not by this one.
    if tg_op = 'UPDATE' and new.booking_id is not distinct from old.booking_id then
        return new;
    end if;

    select b.booking_status_code, b.is_archived
      into v_status, v_archived
    from public.bookings b
    where b.id = new.booking_id;

    -- No row: the foreign key has not been validated yet on a BEFORE trigger. Say nothing and let
    -- the FK reject it, rather than inventing a second error for the same fault.
    if not found then
        return new;
    end if;

    if v_archived then
        raise exception 'cannot attach a booking item to an archived booking'
            using errcode = 'check_violation';
    end if;

    if v_status in ('completed', 'cancelled') then
        raise exception 'cannot attach a booking item to a % booking', v_status
            using errcode = 'check_violation';
    end if;

    return new;
end;
$fn$;

comment on function app.enforce_booking_item_lifecycle() is
'BOOK-1: mirrors app.create_booking_item''s parent-state refusal on every write path. Integrity, not authorization -- no session-less exemption.';

create trigger booking_items_enforce_lifecycle
    before insert or update on public.booking_items
    for each row
    execute function app.enforce_booking_item_lifecycle();

create or replace function app.enforce_booking_item_passenger_lifecycle()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_item_status     text;
    v_item_archived   boolean;
    v_bk_status       text;
    v_bk_archived     boolean;
begin
    if tg_op = 'UPDATE' and new.booking_item_id is not distinct from old.booking_item_id then
        return new;
    end if;

    -- Scalars rather than a RECORD, for the reason app.guard_passenger_financials already documents:
    -- plpgsql binds referenced variables as query parameters, so an unassigned RECORD field raises
    -- 55000 before any guarding condition can short-circuit.
    select bi.base_status_code, bi.is_archived, b.booking_status_code, b.is_archived
      into v_item_status, v_item_archived, v_bk_status, v_bk_archived
    from public.booking_items bi
    join public.bookings b on b.id = bi.booking_id
    where bi.id = new.booking_item_id;

    if not found then
        return new;
    end if;

    if v_item_archived or v_item_status in ('cancelled', 'no_show') then
        raise exception 'cannot add a passenger to a % booking item',
            case when v_item_archived then 'archived' else v_item_status end
            using errcode = 'check_violation';
    end if;

    if v_bk_archived or v_bk_status in ('completed', 'cancelled') then
        raise exception 'cannot add a passenger to an item on a % booking',
            case when v_bk_archived then 'archived' else v_bk_status end
            using errcode = 'check_violation';
    end if;

    return new;
end;
$fn$;

comment on function app.enforce_booking_item_passenger_lifecycle() is
'BOOK-1: mirrors app.link_passenger_to_booking_item''s parent-state refusals on every write path.';

create trigger booking_item_passengers_enforce_lifecycle
    before insert or update on public.booking_item_passengers
    for each row
    execute function app.enforce_booking_item_passenger_lifecycle();

-- WHY SECURITY DEFINER, AND THEREFORE WHY THIS REVOKE IS NOT OPTIONAL.
-- The check reads the PARENT's state, and `booking_items` and `bookings` both carry RLS. Under
-- SECURITY INVOKER the trigger's own SELECT would be filtered by the caller's row scope, so a user
-- who cannot SEE the parent would get `not found`, fall through the `if not found then return new`
-- branch, and be ALLOWED -- the guard would be weakest against exactly the caller it most needs to
-- stop. DEFINER makes it read the true parent state. `create function` grants EXECUTE to PUBLIC by
-- default, so a DEFINER function left public is a privilege hole; `10_grant_model_test.sql`
-- assertion 5 caught precisely that on the first run of this migration, which is what the guard is
-- for.
revoke execute on function app.enforce_booking_item_lifecycle() from public;
revoke execute on function app.enforce_booking_item_passenger_lifecycle() from public;
