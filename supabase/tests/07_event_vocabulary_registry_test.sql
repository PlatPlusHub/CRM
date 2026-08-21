-- pgTAP invariant: every event_type literal an app.* function can emit to app.record_event must be
-- a registered event_type catalog value. Discovery-to-guard (audit 2026-08-10): two RPCs
-- (app.merge_customer_identity, app.advance_refund) emitted event codes with no matching catalog
-- row -- app.record_event's own guard (202607049100) rejected them at call time, but nothing
-- caught the mismatch before runtime. Catalog-driven, introspects pg_proc source directly (no
-- hardcoded function/event list), so it holds automatically as new event-emitting RPCs are added.
--
-- Covers both emission shapes actually used in this codebase:
--   (a) a literal passed directly as record_event's 2nd argument, e.g.
--       perform app.record_event(v_tenant, 'booking_created', ...);
--   (b) a literal resolved via a `from (values (...), ...) as t(..., ev|evt, ...)` transition-
--       mapping table into a variable later passed to record_event, e.g. advance_refund/
--       advance_booking/advance_lead/quotation_workflow's per-transition event lookups. The alias
--       list is read to find the column literally named 'ev' or 'evt', so the check is correct
--       regardless of that column's position within the tuple (it varies across functions).
create extension if not exists pgtap with schema extensions;

begin;
select plan(1);

create temporary table _event_literal_scan (proname text, literal text) on commit drop;

do $$
declare
    v_func record;
    v_src text;
    v_call_match text[];
    v_map_match text[];
    v_values_block text;
    v_cols text;
    v_col_list text[];
    v_ev_idx int;
    v_tuple_match text[];
    v_tuple_items text[];
    v_lit text;
    i int;
begin
    for v_func in
        select p.proname, pg_get_functiondef(p.oid) as def
        from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
        where n.nspname = 'app'
    loop
        v_src := v_func.def;

        -- (a) direct literal: record_event(<first arg>, 'literal', ...)
        for v_call_match in
            select regexp_matches(v_src, 'record_event\(\s*[^,()]+\s*,\s*''([a-z][a-z0-9_]*)''', 'g')
        loop
            insert into _event_literal_scan values (v_func.proname, v_call_match[1]);
        end loop;

        -- (b) values(...) as t(..., ev|evt, ...) transition-mapping tables.
        for v_map_match in
            select regexp_matches(v_src, 'values\s*(.*)\)\s*as\s+t\s*\(([^)]*)\)', 'g')
        loop
            v_values_block := v_map_match[1];
            v_cols := v_map_match[2];
            v_col_list := regexp_split_to_array(trim(v_cols), '\s*,\s*');
            v_ev_idx := null;
            for i in 1..coalesce(array_length(v_col_list, 1), 0) loop
                if lower(trim(v_col_list[i])) in ('ev', 'evt') then
                    v_ev_idx := i;
                end if;
            end loop;
            continue when v_ev_idx is null;

            for v_tuple_match in
                select regexp_matches(v_values_block, '\(([^()]*)\)', 'g')
            loop
                v_tuple_items := regexp_split_to_array(v_tuple_match[1], '\s*,\s*');
                if coalesce(array_length(v_tuple_items, 1), 0) >= v_ev_idx then
                    v_lit := regexp_replace(trim(v_tuple_items[v_ev_idx]), '^''|''$', '', 'g');
                    -- PRECISION FIX (2026-08-21, SPEC-132): an UNQUOTED `null` in the event column
                    -- is the SQL keyword, meaning "this transition emits no event" -- it is not an
                    -- event literal and must not be required to exist in the catalog. That shape is
                    -- real and canonical: app.advance_conversation's pending_customer /
                    -- pending_internal transitions emit nothing, because 26_state_machines.md's
                    -- Required Events list for conversations deliberately does not name an event for
                    -- them. Without this exclusion the guard demanded a catalog value literally
                    -- called "null". Nothing is masked: `null` is a reserved keyword and could never
                    -- be a legitimate event code, and a QUOTED 'null' would still be scanned.
                    continue when trim(v_tuple_items[v_ev_idx]) ~* '^null$';
                    if v_lit ~ '^[a-z][a-z0-9_]*$' then
                        insert into _event_literal_scan values (v_func.proname, v_lit);
                    end if;
                end if;
            end loop;
        end loop;
    end loop;
end $$;

select is(
  (select count(*)::int
     from _event_literal_scan s
    where not exists (
      select 1 from public.catalog_values cv
      where cv.catalog_type_code = 'event_type' and cv.code = s.literal
    )),
  0,
  'Every event_type literal an app.* function can emit has a registered event_type catalog value');

select * from finish();
rollback;
