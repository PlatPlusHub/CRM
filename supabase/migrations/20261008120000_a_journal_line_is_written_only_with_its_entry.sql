-- Batch 6 slice 32 -- `journal_entry_lines`: a journal line is written only with its entry, and a
-- posted line never changes.
--
-- ================================================================================================
-- WHY
--
-- Canon 07: any correction after approval goes through a new event, adjustment, reversal or
-- authorized finance action. The register's closure of `journal_entries`' void columns applies it to
-- the ledger: a POSTED double-entry record is corrected by a compensating reversal, never by
-- mutation. A journal entry has no draft state; `app.create_journal_entry` writes the entry and all
-- its lines in one call, emits `journal_entry_created` with the total, and is the only function that
-- writes a line. Nothing updates one.
--
-- JE-3. `authenticated` held INSERT and UPDATE on the lines, guarded only by RLS charging
--   CREATE_JOURNAL_ENTRY through `app.has_permission`, so a finance manager, at aal1 as well as aal2:
--   rewrote a posted 1000/1000 entry to 7000/7000 in USD on other accounts, backdated, while its
--   event still said 1000; moved a posted line onto a RETIRED account (JE-1 guards INSERT only);
--   appended a balanced pair of lines to a posted entry, which PostgREST accepts as one request; and
--   did all of it at aal1, where the RPC refuses for want of step-up. The RPC is SECURITY INVOKER,
--   which is the only reason the line grant existed. It now runs as definer, as
--   `app.merge_customer_identity` does, keeping its `app.authorize` (permission and MFA), its tenant
--   from the session and its empty search_path; the line grants are revoked. SELECT stays.
--
-- JE-4. `app.enforce_journal_entry_balanced` judged only the entry a line moved TO, so moving lines
--   out of an entry left it with none and committed -- for every writer, the platform included,
--   which FIN-8 deliberately does not exempt. It now judges both entries, and locks each before
--   counting so that two transactions emptying one entry from two sides cannot both pass.
-- ================================================================================================

revoke insert, update on public.journal_entry_lines from authenticated;

alter function app.create_journal_entry(text, date, text, jsonb, uuid) security definer;

create or replace function app.enforce_journal_entry_balanced()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
    v_entries uuid[];
    v_entry uuid;
    v_debit numeric;
    v_credit numeric;
    v_lines int;
begin
    -- DELETE carries no NEW; the affected entry is the one the removed row pointed at. A line that
    -- moved between entries affects both (JE-4).
    -- Sorted, so two transactions moving lines between the same two entries lock them in one order.
    select array_agg(distinct x order by x) into v_entries
      from unnest(case tg_table_name
                    when 'journal_entries'      then array[coalesce((to_jsonb(new) ->> 'id')::uuid,
                                                                    (to_jsonb(old) ->> 'id')::uuid)]
                    when 'journal_entry_lines'  then array[(to_jsonb(new) ->> 'journal_entry_id')::uuid,
                                                           (to_jsonb(old) ->> 'journal_entry_id')::uuid]
                  end) x
     where x is not null;
    if v_entries is null then
        return null;
    end if;

    foreach v_entry in array v_entries
    loop
        -- The entry may have been deleted in this same transaction (lines first, then the entry,
        -- because the FK is ON DELETE RESTRICT). Removing a whole entry is legitimate; there is
        -- nothing left to balance, so skip rather than refuse. The lock serializes two transactions
        -- that change one entry's lines, so each counts the other's committed lines (JE-4).
        perform 1 from public.journal_entries je where je.id = v_entry for no key update;
        continue when not found;

        select coalesce(sum(l.debit_amount), 0), coalesce(sum(l.credit_amount), 0), count(*)
          into v_debit, v_credit, v_lines
        from public.journal_entry_lines l
        where l.journal_entry_id = v_entry;

        -- The three rules below are COPIED from app.create_journal_entry, not chosen here.
        if v_lines < 2 then
            raise exception 'journal entry % has % line(s): a double-entry record requires at least two',
                v_entry, v_lines using errcode = '23514';
        end if;
        if v_debit <> v_credit then
            raise exception 'journal entry % is not balanced: debits % <> credits %',
                v_entry, v_debit, v_credit using errcode = '23514';
        end if;
        if v_debit = 0 then
            raise exception 'journal entry % totals zero', v_entry using errcode = '23514';
        end if;
    end loop;

    return null;
end;
$function$;
