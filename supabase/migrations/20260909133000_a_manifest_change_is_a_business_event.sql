-- PAX-6 -- owner decision, ratified 2026-09-09.
--
-- Passenger-manifest changes ARE business events. Canon 27 gains three types:
--
--     booking_item_passenger_linked
--     booking_item_passenger_replaced
--     booking_item_passenger_removed
--
-- ================================================================================================
-- AUTHORIZATION AND OBSERVABILITY ARE SEPARATE REQUIREMENTS
--
-- PAX-2 priced the manifest door and PAX-5 froze it after issuance -- and neither made a single
-- manifest change VISIBLE. Measured before this migration: `app.link_passenger_to_booking_item`
-- calls `app.record_event` nowhere, and the row that decides who flies could be created, swapped and
-- removed with zero events on either door. An authorized change is not thereby an audited one.
--
-- ================================================================================================
-- ONE PRODUCER, AND WHY IT IS THE TRIGGER RATHER THAN THE RPCs
--
-- `public.booking_item_passengers` is a SANCTIONED direct-DML surface: `authenticated` holds INSERT
-- and UPDATE on it and PostgREST serves it, and PAX-2/PAX-5 deliberately kept that door open at the
-- correct price rather than closing it. So the event cannot live in the RPCs -- it would be absent
-- from exactly the door the owner decision says must not bypass the invariant.
--
-- An AFTER trigger is therefore the ONLY producer:
--   * INSERT                      -> booking_item_passenger_linked
--   * UPDATE, passenger_id moved  -> booking_item_passenger_replaced
--   * DELETE                      -> booking_item_passenger_removed
--
-- DUPLICATE EMISSION IS PREVENTED STRUCTURALLY, not by convention: neither
-- `app.link_passenger_to_booking_item` nor `app.correct_passenger_manifest` emits any of the three,
-- and both reach the table through ordinary DML, so the trigger fires exactly once per change.
-- Assertion in 114 pins that -- a future RPC that emits one of these itself fails a test.
--
-- An UPDATE that touches financial overrides, or a correction's own metadata, is NOT a manifest
-- change and produces nothing. `booking_item_id` moving is treated as a replacement too, because
-- from the item's point of view a traveller left it.
--
-- DELETE is covered although `authenticated` holds no DELETE here (measured) -- exactly the
-- defensive reason `quotation_items_recompute_total` covers DELETE. A platform path that removes a
-- traveller must not be the one change that leaves no trace.
--
-- ================================================================================================
-- WHAT THE EVENT CARRIES
--
-- `app.record_event` supplies the tenant, the actor (from the session; null and unforgeable on a
-- platform path) and the occurrence time (`events.created_at`, a server default no caller can
-- backdate). This trigger supplies the booking item, the previous and new passenger identities where
-- each applies, and the correction reason when there is one. Severity is `warning` for a replacement
-- or removal -- a traveller changing after the fact is something an operator should see -- and
-- `info` for the ordinary act of building a manifest.

-- ------------------------------------------------------------------------------------------------
-- 1. The vocabulary. NOT EXISTS rather than ON CONFLICT: catalog_values' uniqueness is carried by
--    two PARTIAL indexes, so a bare ON CONFLICT matches no arbiter and fails 42P10.
-- ------------------------------------------------------------------------------------------------
insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_system, is_active)
select v.type_code, v.code, v.label, v.ord, true, true
from (values
        ('event_type', 'booking_item_passenger_linked',   'Booking Item Passenger Linked',   910),
        ('event_type', 'booking_item_passenger_replaced', 'Booking Item Passenger Replaced', 911),
        ('event_type', 'booking_item_passenger_removed',  'Booking Item Passenger Removed',  912)
     ) as v(type_code, code, label, ord)
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = v.type_code
      and cv.code = v.code
      and cv.tenant_id is null
);

-- ------------------------------------------------------------------------------------------------
-- 2. The producer.
--
--    SECURITY DEFINER for one reason: `app.record_event` inserts into `public.events`, and the
--    manifest's writers must not need a write grant on the event ledger to be audited. Its
--    search_path is pinned and every object is schema-qualified. It takes NO session-less exemption:
--    a platform path's manifest change is exactly as much a business fact as a user's.
-- ------------------------------------------------------------------------------------------------
create or replace function app.record_manifest_change_event()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_row     record  := coalesce(new, old);
    v_type    text;
    v_prev    uuid;
    v_next    uuid;
    v_severity text;
begin
    if tg_op = 'INSERT' then
        v_type := 'booking_item_passenger_linked';
        v_prev := null;
        v_next := new.passenger_id;
        v_severity := 'info';
    elsif tg_op = 'DELETE' then
        v_type := 'booking_item_passenger_removed';
        v_prev := old.passenger_id;
        v_next := null;
        v_severity := 'warning';
    else
        -- Only a change of TRAVELLER, or of the item a traveller is attached to, is a manifest
        -- change. Editing a financial override is not, and must not fill the ledger with noise.
        if new.passenger_id is not distinct from old.passenger_id
           and new.booking_item_id is not distinct from old.booking_item_id then
            return null;
        end if;
        v_type := 'booking_item_passenger_replaced';
        v_prev := old.passenger_id;
        v_next := new.passenger_id;
        v_severity := 'warning';
    end if;

    perform app.record_event(
        v_row.tenant_id,
        v_type,
        'booking_item',
        v_row.booking_item_id,
        -- The actor is DERIVED by app.record_event from the session. It is passed as null here on
        -- purpose: record_event refuses a named actor on a session-less path, and supplying one on a
        -- user path would let this trigger assert an identity it did not verify.
        null,
        case when v_prev is null then null else v_prev::text end,
        case when v_next is null then null else v_next::text end,
        case when tg_op = 'UPDATE' then new.passenger_correction_reason else null end,
        jsonb_build_object(
            'booking_item_passenger_id', v_row.id,
            'booking_item_id',           v_row.booking_item_id,
            'previous_passenger_id',     v_prev,
            'new_passenger_id',          v_next,
            'previous_booking_item_id',  case when tg_op = 'UPDATE' then old.booking_item_id else null end),
        v_severity);

    return null;
end
$fn$;

comment on function app.record_manifest_change_event() is
    'PAX-6 (owner decision 2026-09-09): the SOLE producer of booking_item_passenger_linked / _replaced / _removed. An AFTER trigger rather than RPC code, because public.booking_item_passengers is a sanctioned direct-DML surface (authenticated holds INSERT and UPDATE, PostgREST serves it) and an event emitted only by the RPCs would be absent from exactly the door PAX-6 says must not bypass it. No RPC emits these types, so no duplicate is possible. SECURITY DEFINER so a manifest writer needs no grant on public.events.';

revoke all on function app.record_manifest_change_event() from public;

create trigger booking_item_passengers_record_manifest_event
    after insert or update or delete on public.booking_item_passengers
    for each row execute function app.record_manifest_change_event();
