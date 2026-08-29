-- FIN-8 -- the double-entry invariant lived in ONE function, and the ledger had another door.
--
-- REPRODUCED FIRST, as a `finance_manager` (aal2), with the positive control that makes it
-- conclusive -- the RPC refusing in the very transaction the direct write succeeded:
--
--     RPC, balanced 1000/1000        -> 76565004-...  (a real entry: the fixture is not empty)
--     RPC, unbalanced 1000/1         -> ERROR 'journal entry is not balanced: debits 1000 <> credits 1'
--     DIRECT DML, one line, 1,000,000 debit and no credit at all
--                                    -> SUCCEEDED. debits=1000000  credits=0  lines=1
--     events emitted for that entry  -> 0
--
-- This is the GENERAL LEDGER. "Debits equal credits" is not a validation rule, it is the definition
-- of double-entry bookkeeping; an entry that does not balance is not a weaker entry, it is a corrupt
-- one. `app.create_journal_entry` enforced it correctly -- at least two lines, each line exactly one
-- of debit/credit, totals equal, total > 0 -- and enforced it NOWHERE ELSE. `authenticated` holds
-- INSERT and UPDATE on both tables, and the RLS policies charge CREATE_JOURNAL_ENTRY, which is the
-- same permission the RPC charges. So this was never a privilege escalation: it is a holder of the
-- right permission reaching the right table through a door with no invariant behind it.
--
-- WHAT THE DATABASE ALREADY ENFORCED, and why it was not enough: `journal_entry_lines` carries
-- `journal_entry_lines_debit_xor_credit_check`, which is a PER-ROW constraint -- it proves each line
-- is either a debit or a credit, and can say nothing about whether the ENTRY balances, because that
-- is a statement about a SET of rows. A CHECK constraint cannot express it. This is the gap.
--
-- WHY A DEFERRED CONSTRAINT TRIGGER. The invariant is only ever true between statements: the entry
-- row is inserted first and is momentarily an entry with zero lines; each line lands one at a time
-- and every intermediate state is unbalanced. An immediate trigger would refuse
-- `app.create_journal_entry` on its own first line. `deferrable initially deferred` moves the check
-- to COMMIT, which is exactly when the invariant must hold and the only moment it is meaningful.
--
-- CONSEQUENCE, STATED PLAINLY: creating a journal entry through the PostgREST TABLE endpoints
-- becomes impossible, because each HTTP request is its own transaction and no single request can
-- insert an entry and two balanced lines. That is not a capability being removed -- there was never
-- a way to build a VALID entry that way, only an invalid one. `app.create_journal_entry` is and
-- remains the door, which is what a ledger should have.
--
-- NO SESSION-LESS EXEMPTION, DELIBERATELY, and this differs from the authorization guards beside it.
-- `app.enforce_status_transition` and `app.enforce_archive_authority` exempt `auth.uid() is null`
-- under canon 35 principle 6 -- platform paths sit outside per-table AUTHORIZATION. This is not an
-- authorization rule. It is a data-integrity invariant, in the same class as the `debit_xor_credit`
-- CHECK one column over, which the platform does not escape either. A ledger corrupted by a
-- migration is exactly as corrupt as one corrupted by a tenant user.
--
-- RELATED, RECORDED NOT FIXED: a transaction-capable direct-DML client can still create a VALID
-- balanced entry with no `journal_entry_created` event, because the event is emitted by the RPC and
-- not by the table. An event trigger would double-emit for every RPC-created entry, so the honest
-- answer is not a second producer -- see **FIN-9** in MASTER_GAP_REGISTER.md.

create or replace function app.enforce_journal_entry_balanced()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_entry uuid;
    v_debit numeric;
    v_credit numeric;
    v_lines int;
begin
    -- DELETE carries no NEW; the affected entry is the one the removed row pointed at.
    v_entry := case tg_table_name
                 when 'journal_entries'      then coalesce((to_jsonb(new) ->> 'id')::uuid,
                                                           (to_jsonb(old) ->> 'id')::uuid)
                 when 'journal_entry_lines'  then coalesce((to_jsonb(new) ->> 'journal_entry_id')::uuid,
                                                           (to_jsonb(old) ->> 'journal_entry_id')::uuid)
               end;
    if v_entry is null then
        return null;
    end if;

    -- The entry may have been deleted in this same transaction (lines first, then the entry, because
    -- the FK is ON DELETE RESTRICT). Removing a whole entry is legitimate; there is nothing left to
    -- balance, so skip rather than refuse.
    if not exists (select 1 from public.journal_entries je where je.id = v_entry) then
        return null;
    end if;

    select coalesce(sum(l.debit_amount), 0), coalesce(sum(l.credit_amount), 0), count(*)
      into v_debit, v_credit, v_lines
    from public.journal_entry_lines l
    where l.journal_entry_id = v_entry;

    -- The three rules below are COPIED from app.create_journal_entry, not chosen here. Nothing about
    -- what a valid entry is changes in this migration; only where the rule is enforced.
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

    return null;
end;
$fn$;

-- SECURITY DEFINER with `search_path = ''` because the trigger must see EVERY line of the entry to
-- sum it, including under an RLS policy that would otherwise scope the read. It reads and never
-- writes, and it is not executable by anyone: a trigger function needs no EXECUTE grant.
revoke execute on function app.enforce_journal_entry_balanced() from public;

-- Both tables, because the two failure modes are different: an entry inserted with no lines at all
-- is invisible to a trigger on the lines, and lines that unbalance an existing entry are invisible
-- to a trigger on the entry.
create constraint trigger journal_entries_must_balance
    after insert or update on public.journal_entries
    deferrable initially deferred
    for each row execute function app.enforce_journal_entry_balanced();

create constraint trigger journal_entry_lines_must_balance
    after insert or update or delete on public.journal_entry_lines
    deferrable initially deferred
    for each row execute function app.enforce_journal_entry_balanced();
