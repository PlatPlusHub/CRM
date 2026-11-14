-- Batch 6 slice 9 (`exchange_rates`). Measured on the local stack before this file (probes ER1-ER3):
--   * a finance_manager, ceo or owner set a rate from a password-only (aal1) session: the table door charged
--     SET_EXCHANGE_RATE through RLS but never the step-up `app.authorize` charges every MFA-bound role;
--   * a rate that a booking item already cited was rewritten (48.5 -> 99), re-dated a year back and had its currency
--     pair flipped in place; `app.exchange_rate_as_of` answered the new value, `set_by` still named the first setter,
--     and nothing was recorded. `exchange_rate_adjustments` (append-only) is the designed correction path.
-- Repair: every session write charges `app.authorize('SET_EXCHANGE_RATE')`; a rate cited by a booking item, a payment,
-- an allocation or an adjustment keeps its rate, pair, instant and tenant for every writer; every set or change of a
-- rate is recorded as the registered `exchange_rate_set` event, at canon 27's severity (critical).

create or replace function app.guard_exchange_rate_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    if tg_op = 'UPDATE'
       and (new.tenant_id, new.from_currency_code, new.to_currency_code, new.rate, new.effective_at)
           is distinct from (old.tenant_id, old.from_currency_code, old.to_currency_code, old.rate, old.effective_at)
       and (exists (select 1 from public.booking_items b
                     where b.tenant_id = old.tenant_id and b.exchange_rate_id = old.id)
            or exists (select 1 from public.payments p
                        where p.tenant_id = old.tenant_id and p.exchange_rate_id = old.id)
            or exists (select 1 from public.payment_allocations a
                        where a.tenant_id = old.tenant_id and a.exchange_rate_id = old.id)
            or exists (select 1 from public.exchange_rate_adjustments x
                        where x.tenant_id = old.tenant_id
                          and (x.original_exchange_rate_id = old.id or x.new_exchange_rate_id = old.id))) then
        raise exception 'exchange rate % is cited by recorded money: set a new rate and record an adjustment', old.id
            using errcode = 'check_violation';
    end if;
    if (select auth.uid()) is null then
        return new;
    end if;
    perform app.authorize('SET_EXCHANGE_RATE');
    return new;
end;
$fn$;

revoke execute on function app.guard_exchange_rate_write() from public;

create trigger exchange_rates_guard_write
    before insert or update on public.exchange_rates
    for each row execute function app.guard_exchange_rate_write();

create or replace function app.emit_exchange_rate_set()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_prev jsonb;
    v_next jsonb;
begin
    v_next := jsonb_build_object('from_currency_code', new.from_currency_code, 'to_currency_code', new.to_currency_code,
        'rate', new.rate, 'effective_at', new.effective_at);
    if tg_op = 'UPDATE' then
        v_prev := jsonb_build_object('from_currency_code', old.from_currency_code, 'to_currency_code', old.to_currency_code,
            'rate', old.rate, 'effective_at', old.effective_at);
        if v_prev = v_next then
            return null;
        end if;
    end if;
    perform app.record_event(
        new.tenant_id, 'exchange_rate_set', 'exchange_rate', new.id,
        null, null, null, null,
        jsonb_build_object('exchange_rate_id', new.id, 'previous', v_prev, 'current', v_next),
        'critical');
    return null;
end;
$fn$;

revoke execute on function app.emit_exchange_rate_set() from public;

create trigger exchange_rates_emit_set
    after insert or update on public.exchange_rates
    for each row execute function app.emit_exchange_rate_set();
