-- B6-EXIT bundle C: a ledger entry balances in one currency, and a payment row carries value.
--
-- The CRM Action Registry makes `journal_entry_lines`, `payments` and `payment_allocations` B6-EXIT
-- surfaces. Measured at `17ec05a` on the local stack in rolled-back transactions (Workbench
-- data/records/batch6/finance-evidence/repro-17ec05a.sql):
--   * JE-2: `app.create_journal_entry` accepted a 100 USD debit against a 100 EGP credit, and the
--     deferred `app.enforce_journal_entry_balanced` committed it, because both sum debit and credit
--     across currencies. The registry's named exit option is the fail-closed containment: refuse a
--     mixed-currency entry until DC-11 decides the model. It lives in the deferred balance trigger,
--     which already judges both doors (the RPC and the platform's direct DML), so one control covers
--     both. It is a refusal in a replaceable function, NOT a structural CHECK: DC-11's translation
--     model (a transaction-currency amount, a rate and a functional-currency amount per line, IAS 21
--     paragraph 21) replaces this branch with a functional-currency balance and forecloses nothing.
--   * PAY-4: an owner's direct INSERT persisted a `payments` row with amount 0 coded
--     `customer_refund`. Every sanctioned door that writes a payment -- `app.record_payment` and
--     `app.record_supplier_payment` -- refuses an amount that is not greater than zero, and the
--     refund model's own door, `app.record_refund`, writes `refunds`, not `payments`, under the same
--     rule. The entry-shape rule derived from them: a payment row carries value, `amount > 0`, on
--     every door.
--
-- NOT CHANGED: every grant, policy, trigger binding, permission charge and event; the three balance
-- rules (at least two lines, debits equal credits, non-zero total); the RPCs' bodies; the direction
-- column (rewriting a payment's direction is PAY-2's capability charge, already in force);
-- `payments_amount_nonneg_check`, which the new rule implies and which is kept rather than rewritten.
-- Primary carried 0 payments and 0 journal lines when read, so the new CHECK validates on deploy.

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
    v_currencies text[];
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

        select coalesce(sum(l.debit_amount), 0), coalesce(sum(l.credit_amount), 0), count(*),
               array_agg(distinct l.currency_code order by l.currency_code)
          into v_debit, v_credit, v_lines, v_currencies
        from public.journal_entry_lines l
        where l.journal_entry_id = v_entry;

        -- JE-2 containment (B6-EXIT bundle C). The sums below are only meaningful in one currency:
        -- until DC-11 decides the translation model, an entry whose lines carry more than one
        -- currency is refused rather than "balanced" across currencies. Judged first, so the
        -- refusal names the cause and not a misleading total.
        if cardinality(v_currencies) > 1 then
            raise exception 'journal entry % mixes currencies (%): an entry balances in one currency until DC-11 decides the translation model (JE-2)',
                v_entry, array_to_string(v_currencies, ', ') using errcode = '23514';
        end if;

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

alter table public.payments
    add constraint payments_amount_positive_check check (amount > 0);
