-- SPEC-299 (Batch 6 Slice 44, AR-1, AR-2, AR-3) -- a decided approval request is final,
-- and an item has at most one pending finance request, on every door.
--
-- =================================================================================================
-- THE MEASURED DEFECTS (2026-11-09 at a4fc1e1 on the local stack, two live sessions; session A
-- acts, sleeps 4 s, commits; session B acts 1.5 s later)
--
-- AR-1 `app.review_finance_approval` reads the request without a lock and updates it `where id =`
--      with no status predicate, so the `pending` check it made can be stale by the time it writes.
--      A approves, B rejects: both succeed; the request ends `rejected`, the item `rejected`, and
--      `cost_locked_at` stays set from the approval. A withdraws (committed), B approves: B waits
--      on the request row, then overwrites `cancelled` with `approved` and locks the cost of an
--      item whose finance requirement was withdrawn.
-- AR-2 `app.request_finance_approval` refuses a second pending request with a plain `exists`, and
--      nothing makes "one pending finance request per item" a rule. Two overlapping requests both
--      insert: two pending requests for one item.
-- AR-3 The table door (`scope_update`, open by design to the reviewer the type names) had no
--      transition rule. A finance manager turned a `rejected` request `approved` by plain SQL, and
--      approved a pending request on a CANCELLED booking that the RPC refuses.
--
-- =================================================================================================
-- THE REPAIR, AND WHY THIS SHAPE
--
-- 1. `app.guard_approval_request_decision`, BEFORE UPDATE OF approval_status_code: the status may
--    only leave `pending`, and only for `approved`, `rejected` or `cancelled` -- the three values
--    the two writers (`app.review_finance_approval`, `app.withdraw_finance_approval`) assign. A
--    decided request is final. Because the trigger sees the row version current at write time,
--    it also closes AR-1: a second reviewer queued behind the first finds OLD already decided and
--    is refused 23514, whatever its earlier read said. An approval of a booking-item request obeys
--    the RPC's parent-state rule (item not archived, cancelled or no_show; booking not archived,
--    completed or cancelled) on every door.
-- 2. A partial UNIQUE index: one `pending` `finance_execution_approval` per booking item. A
--    second pending request on any path waits for the first and is refused 23505.
--
-- Authority is NOT moved: RLS `scope_update` already names the permission per request type, and
-- `app.status_transitions` keys one permission per transition, which cannot express that (a
-- `cancelled` comes from the requester's RPC decision and from WITHDRAW_FINANCE_APPROVAL alike).
-- The guard is validity only, so it is not registered there.
--
-- Like `app.enforce_status_transition`, the guard steps aside when there is no end user
-- (`auth.uid()` is null): migrations, seeds and the platform's own maintenance.
--
-- NOT CHANGED: every grant, policy, both RPC bodies, `app.status_transitions`, the item guards.
-- Hosted rows at the time of writing: 0 approval requests on Primary (read-only, ledger 254), so
-- the index meets no duplicate.
-- =================================================================================================

create or replace function app.guard_approval_request_decision()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
    v_parent record;
begin
    if (select auth.uid()) is null then
        return new;
    end if;
    if new.approval_status_code is not distinct from old.approval_status_code then
        return new;
    end if;
    if old.approval_status_code <> 'pending'
       or new.approval_status_code not in ('approved', 'rejected', 'cancelled') then
        raise exception
            '% -> % is not a permitted transition for approval_requests: a decided request is final',
            old.approval_status_code, coalesce(new.approval_status_code, '(null)')
            using errcode = '23514';
    end if;
    if new.approval_status_code = 'approved' and new.booking_item_id is not null then
        select bi.is_archived as item_archived, bi.base_status_code,
               b.is_archived as booking_archived, b.booking_status_code
          into v_parent
        from public.booking_items bi
        join public.bookings b on b.id = bi.booking_id
        where bi.id = new.booking_item_id;
        if v_parent.item_archived
           or v_parent.base_status_code in ('cancelled', 'no_show')
           or v_parent.booking_archived
           or v_parent.booking_status_code in ('completed', 'cancelled') then
            raise exception 'cannot approve a request for a terminal/archived booking item or booking'
                using errcode = '23514';
        end if;
    end if;
    return new;
end;
$$;

revoke execute on function app.guard_approval_request_decision() from public;

drop trigger if exists approval_requests_guard_decision on public.approval_requests;
create trigger approval_requests_guard_decision
    before update of approval_status_code on public.approval_requests
    for each row execute function app.guard_approval_request_decision();

create unique index if not exists approval_requests_one_pending_finance_per_item
    on public.approval_requests (booking_item_id)
    where approval_type_code = 'finance_execution_approval' and approval_status_code = 'pending';
