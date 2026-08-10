-- pgTAP invariant: every from/to status literal a transition-owning app.* function can write is a
-- registered catalog_values row in that function's governing catalog family. Extends the SPEC-120
-- event-vocabulary guard (07) to the status side of the same `values(...) as t(...)` mapping tables
-- ADR-0006 deliberately leaves without mandatory database enforcement. Design: SPEC-121.
--
-- The map below is the single authoritative inventory of transition-owning RPCs (verified live
-- against pg_proc/migration text, not assumed) -- reproduced from SPEC-121 §1. It is not trusted to
-- stay exhaustive on its own: the completeness assertion below independently discovers every
-- app.* function shaped like a transition RPC (a `values(...) as t(...)` block whose alias list
-- names both a from-state column (frm|f) and a to-state column (to_s|s) -- the actual, consistent
-- authoring convention across all 5 current transition RPCs) and fails if any such function is
-- missing from the map, so a future transition RPC written by the same convention cannot silently
-- evade this guard.
create extension if not exists pgtap with schema extensions;

begin;
select plan(2);

create temporary table _transition_rpc_map (proname text primary key, catalog_type_code text) on commit drop;
insert into _transition_rpc_map (proname, catalog_type_code) values
    ('advance_lead',         'lead_status'),
    ('advance_booking_item', 'booking_item_base_status'),
    ('advance_booking',      'booking_status'),
    ('advance_refund',       'refund_status_code'),
    ('advance_quotation',    'quotation_status_code');

create temporary table _transition_literal_scan (proname text, side text, literal text) on commit drop;

do $$
declare
    v_func record;
    v_src text;
    v_map_match text[];
    v_values_block text;
    v_cols text;
    v_col_list text[];
    v_frm_idx int;
    v_to_idx int;
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

        -- Alias-aware: locate the values(...) as t(<col-list>) block(s) and resolve column
        -- positions from the alias list itself, not a fixed position (order differs across
        -- functions: t(frm, to_s, ev) vs t(f, s, perm, evt)). The outer pattern captures
        -- immediately after `values\s*` with no literal `(` token, so the first tuple's own
        -- opening parenthesis is never consumed -- the exact bug caught and fixed in test 07.
        for v_map_match in
            select regexp_matches(v_src, 'values\s*(.*)\)\s*as\s+t\s*\(([^)]*)\)', 'g')
        loop
            v_values_block := v_map_match[1];
            v_cols := v_map_match[2];
            v_col_list := regexp_split_to_array(trim(v_cols), '\s*,\s*');
            v_frm_idx := null;
            v_to_idx := null;
            for i in 1..coalesce(array_length(v_col_list, 1), 0) loop
                if lower(trim(v_col_list[i])) in ('frm', 'f') then
                    v_frm_idx := i;
                end if;
                if lower(trim(v_col_list[i])) in ('to_s', 's') then
                    v_to_idx := i;
                end if;
            end loop;
            continue when v_frm_idx is null or v_to_idx is null;

            for v_tuple_match in
                select regexp_matches(v_values_block, '\(([^()]*)\)', 'g')
            loop
                v_tuple_items := regexp_split_to_array(v_tuple_match[1], '\s*,\s*');
                if coalesce(array_length(v_tuple_items, 1), 0) >= greatest(v_frm_idx, v_to_idx) then
                    v_lit := regexp_replace(trim(v_tuple_items[v_frm_idx]), '^''|''$', '', 'g');
                    if v_lit ~ '^[a-z][a-z0-9_]*$' then
                        insert into _transition_literal_scan values (v_func.proname, 'from', v_lit);
                    end if;
                    v_lit := regexp_replace(trim(v_tuple_items[v_to_idx]), '^''|''$', '', 'g');
                    if v_lit ~ '^[a-z][a-z0-9_]*$' then
                        insert into _transition_literal_scan values (v_func.proname, 'to', v_lit);
                    end if;
                end if;
            end loop;
        end loop;
    end loop;
end $$;

select is(
  (select count(*)::int
     from (select distinct proname from _transition_literal_scan) d
    where not exists (select 1 from _transition_rpc_map m where m.proname = d.proname)),
  0,
  'Every transition-shaped app.* function (values(...) as t(frm|f, to_s|s, ...)) is covered by the transition-RPC map');

select is(
  (select count(*)::int
     from _transition_literal_scan s
     join _transition_rpc_map m on m.proname = s.proname
    where not exists (
      select 1 from public.catalog_values cv
      where cv.catalog_type_code = m.catalog_type_code and cv.code = s.literal
    )),
  0,
  'Every from/to status literal in a mapped transition RPC has a registered catalog_values row in its governing family');

select * from finish();
rollback;
