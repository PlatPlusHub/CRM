-- CUST-13, CUST-14 -- Batch 6 slice 11 (`customer_identity_signals`).
--
-- THE RULE. A signal is a phone, WhatsApp number, email or document number by which a customer was
-- identified; `app.find_customer_duplicates` reads them to warn before a second record of the same
-- person is created. `app.create_customer` writes them, normalized (`app.normalize_phone`,
-- `app.normalize_email`), and only ever INSERTs; `app.merge_customer_identity` (SECURITY DEFINER)
-- moves them to the survivor. `authenticated` holds table-level INSERT and UPDATE, and PostgREST
-- serves both. Measured before this migration (local stack, an `employee` holding CREATE_CUSTOMER,
-- at aal1 as that role allows):
--   CUST-13  an UPDATE moved a phone signal from one customer to another and turned an email signal
--            into a passport number, unrecorded: the duplicate check then warned against the wrong
--            customer and no longer warned against the right one;
--   CUST-14  a phone inserted at the door as `+20 100 765 4321` and an email as `Two@CB.test` were
--            stored as typed, so the duplicate check, which compares normalized values, never matched
--            them.
--
-- THE REPAIR, in existing shapes. UPDATE is revoked from `authenticated`, so the grant matches the
-- writers, as `202607056100_write_grants_match_the_writers` did for the tables no invoker writes:
-- no client path updates a signal, and the merge, which does, is SECURITY DEFINER. One BEFORE INSERT
-- OR UPDATE OF the value trigger applies the duplicate reader's own normalization on every door, so a
-- stored signal and a searched value always compare alike; a value that normalizes to nothing is
-- refused by the existing NOT NULL, as the RPC never stores one.
--
-- NOT CHANGED: the INSERT and SELECT grants, the policy, the check, the foreign keys and the
-- capability guard; `app.create_customer`, `app.find_customer_duplicates` and the merge. Correcting a
-- wrong signal stays a product question (a new signal is a new row; nothing deletes one).
revoke update on public.customer_identity_signals from authenticated;

create or replace function app.normalize_identity_signal()
returns trigger
language plpgsql
set search_path to ''
as $fn$
begin
    new.signal_value := case
        when new.signal_type_code in ('phone', 'whatsapp') then app.normalize_phone(new.signal_value)
        when new.signal_type_code = 'email' then app.normalize_email(new.signal_value)
        else new.signal_value end;
    return new;
end;
$fn$;

revoke execute on function app.normalize_identity_signal() from public;

create trigger customer_identity_signals_normalize_value
    before insert or update of signal_value, signal_type_code on public.customer_identity_signals
    for each row execute function app.normalize_identity_signal();
