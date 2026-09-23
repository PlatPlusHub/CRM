-- SPEC-213 / CONV-6 -- `offline_conversions.source_event_seq` is platform provenance.
--
-- The column is the idempotency key `app.map_outcomes_to_conversions` writes from a real event's
-- global `seq`; the mapper resolves a conflict on it with DO NOTHING, and CONV-1's deferral recovery
-- closes a deferral as mapped when any row holds that key. `authenticated` holds table-level INSERT
-- and UPDATE on this table, so a signed-in session could write the key, and a value written in one
-- tenant made another tenant's conversion be skipped silently and its deferral close as mapped.
--
-- The repair is one BEFORE trigger in the house idiom: a session-less write is the platform path
-- (canon 35 principle 6), the mapper is the only writer of this column and reaches it without a
-- session, and a signed-in session may neither set it on INSERT nor change it on UPDATE. Nothing
-- else about this table, its grants, its policies or the mapper changes.

create or replace function app.forbid_session_provenance_write()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    -- Platform paths carry no session (canon 35 principle 6). app.map_outcomes_to_conversions is
    -- the only writer of this column and reaches it without one.
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'INSERT' then
        if new.source_event_seq is not null then
            raise exception 'offline_conversions.source_event_seq is platform provenance: a signed-in session may not set or change it'
                using errcode = '42501';
        end if;
    elsif new.source_event_seq is distinct from old.source_event_seq then
        raise exception 'offline_conversions.source_event_seq is platform provenance: a signed-in session may not set or change it'
            using errcode = '42501';
    end if;
    return new;
end;
$fn$;

revoke execute on function app.forbid_session_provenance_write() from public;

create trigger offline_conversions_forbid_session_provenance_write
    before insert or update on public.offline_conversions
    for each row execute function app.forbid_session_provenance_write();
