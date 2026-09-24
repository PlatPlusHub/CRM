-- SPEC-217 / RFD-1, RFD-2, ENTRY-1 (refunds) -- Batch 6 Slice 17.
-- A refund's table door must charge the same authority as app.advance_refund,
-- begin in the state app.record_refund uses, and derive completion evidence.
-- Existing RLS, catalog, subscription, financial amount, and status-transition
-- controls remain attached. System writes with no auth identity keep their
-- existing exemption; tenant users still have to satisfy RLS.

create or replace function app.guard_refund_integrity()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $fn$
begin
    if (select auth.uid()) is null then
        return new;
    end if;

    if new.amount <= 0 then
        raise exception 'refund amount must be greater than zero'
            using errcode = '23514';
    end if;

    if tg_op = 'INSERT' then
        if new.refund_status_code is distinct from 'requested'
           or new.completed_at is not null then
            raise exception 'a refund starts requested without a completion time'
                using errcode = '23514';
        end if;
        return new;
    end if;

    perform app.authorize('RECORD_REFUND');

    if new.refund_status_code = 'completed'
       and old.refund_status_code is distinct from 'completed' then
        new.completed_at := now();
    else
        new.completed_at := old.completed_at;
    end if;

    return new;
end;
$fn$;

revoke execute on function app.guard_refund_integrity() from public;

create trigger refunds_guard_integrity
    before insert or update on public.refunds
    for each row execute function app.guard_refund_integrity();
