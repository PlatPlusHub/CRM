-- WP-01 -- creation-event completeness.
--
-- Four registered, ACTIVE `*_created` event types have a real producer and were never emitted, so
-- the business timeline began halfway through the relationship: a customer, lead or passenger
-- simply appeared in the data with no event marking its creation, and Customer 360 / Lead 360 could
-- not answer "when did this start, and who started it?".
--
-- Verified live before implementing (not carried from a previous report):
--   * 26 `*_created` types registered, all active; 10 referenced by NO app function.
--   * Of those 10, exactly four have a producer that actually inserts the entity --
--     customers/create_customer, leads/create_lead, passengers/create_passenger,
--     trusted_devices/record_trusted_device -- and each table has exactly ONE inserting function,
--     so there is no second path to double-emit from.
--   * No existing trigger on any of the four tables emits an event.
--   * The other six (company_asset, exchange_rate_adjustment, financial_account, notification,
--     payment_allocation, subscription) have NO producer at all and are left alone -- inventing one
--     would fabricate capability. They are WP-02's triage.
--
-- MECHANISM -- AFTER INSERT trigger, not a line inside each RPC.
--   SEC-1 is still open, so `authenticated` retains direct INSERT on these tables. An event emitted
--   from inside the RPC would be skipped entirely by a direct write, leaving an entity whose
--   creation is permanently absent from the immutable spine -- exactly the defect this package
--   exists to close. A trigger fires on every write path, so "exactly one event per creation" holds
--   regardless of how the row arrived.
--   It also solves `record_trusted_device` for free: that function is UPSERT-shaped (it UPDATEs an
--   existing device and only INSERTs when none matched), so an in-function `perform record_event`
--   would have fired on every re-login from a known device. An INSERT trigger cannot.
--
-- CONSUMER TRACE (mandatory before touching the spine; all verified by introspection):
--   * `app.map_outcomes_to_conversions` filters on
--     ('lead_qualified','booking_created','payment_recorded','booking_issued'). None of the four
--     new types appears there, so none becomes eligible for Google conversion mapping and the n8n
--     contract is unchanged. Confirmed against the live function body, not assumed.
--   * `app.customer_timeline` / `app.lead_timeline` gain the creation event -- the intended win.
--   * The `events` read policy dispatches `customer`, `lead` and `passenger` to their subject
--     table's own RLS, so each new event is readable exactly when its subject is.
--   * `trusted_device` is NOT in that dispatch and falls to `ELSE false`. Deliberately left alone:
--     the policy's actor exemption already shows the device's own owner their event, and
--     tenant-wide readers (owner/CEO) see it. Adding a dispatch branch would widen SPEC-143's
--     policy for no visibility gain. Canon 27 marks this event `Severity: security`, which is why
--     it is emitted at that severity rather than `info`.
--
-- HISTORICAL BACKFILL -- not required and not performed. Primary holds zero customers, leads,
-- passengers, trusted_devices, events and tenants, so no existing row lacks its creation event.
-- Nothing is reconstructed and no history is fabricated. Should a future import create rows outside
-- these paths, the trigger covers it, because it fires on the INSERT itself rather than on the RPC.

create or replace function app.emit_creation_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_row      jsonb := to_jsonb(new);
    v_tenant   uuid;
    v_severity text := coalesce(tg_argv[2], 'info');
    v_state    text;
begin
    -- Tenant-scoped tables carry it on the row; `trusted_devices` does not (it keys on
    -- auth_user_id), so the session is the only source there.
    v_tenant := coalesce((v_row ->> 'tenant_id')::uuid, app.current_tenant_id());

    -- No resolvable tenant means a platform-level or pre-membership insert. Skip rather than raise:
    -- `record_trusted_device` runs during authentication, and breaking a login to record an event
    -- would trade a missing timeline entry for an unusable system.
    if v_tenant is null then
        return new;
    end if;

    -- Optional 4th argument names a status column, so the event records the state the entity was
    -- born in rather than leaving the timeline's first entry stateless.
    if tg_argv[3] is not null then
        v_state := v_row ->> tg_argv[3];
    end if;

    perform app.record_event(
        v_tenant,
        tg_argv[0],          -- event_type_code
        tg_argv[1],          -- entity_type
        (v_row ->> 'id')::uuid,
        null,                -- actor: record_event derives it authoritatively (WP-00)
        null,                -- previous_state: a creation has none
        v_state,
        null,
        null,
        v_severity
    );
    return new;
end;
$fn$;

revoke execute on function app.emit_creation_event() from public;

create trigger customers_emit_created
    after insert on public.customers
    for each row execute function app.emit_creation_event('customer_created', 'customer', 'info');

create trigger leads_emit_created
    after insert on public.leads
    for each row execute function app.emit_creation_event('lead_created', 'lead', 'info', 'lead_status_code');

create trigger passengers_emit_created
    after insert on public.passengers
    for each row execute function app.emit_creation_event('passenger_created', 'passenger', 'info');

create trigger trusted_devices_emit_created
    after insert on public.trusted_devices
    for each row execute function app.emit_creation_event('trusted_device_created', 'trusted_device', 'security', 'status_code');
