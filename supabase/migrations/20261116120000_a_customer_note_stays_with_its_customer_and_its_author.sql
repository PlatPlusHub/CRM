-- CUST-15, CUST-16 -- Batch 6 slice 54 (`customer_notes`).
--
-- THE RULE. A customer note is what one person wrote about one customer. `app.add_customer_note`
-- (SECURITY INVOKER) writes it: CREATE_CUSTOMER, the text trimmed and required, the customer in the
-- tenant; `app.derive_created_by` names the author and keeps the name; `app.merge_customer_identity`
-- (SECURITY DEFINER, owned by `postgres`) re-points a merged customer's notes to the survivor. No
-- function rewrites a note's text. `authenticated` holds table-level INSERT and UPDATE (pin,
-- confidential and archive are column updates the product needs), and PostgREST serves both.
-- Measured before this migration (local stack; an `employee` holding CREATE_CUSTOMER, at aal1):
--   CUST-15  the employee rewrote the owner's note, blanked it, moved it to another customer and
--            back-dated its `created_at` to 2019; another employee rewrote the first one's note. Each
--            note still named its original author, and nothing recorded the change;
--   CUST-16  a note of three spaces was accepted at the table door, which the RPC refuses.
--
-- THE REPAIR, in existing shapes. One BEFORE INSERT OR UPDATE trigger in the shape of
-- `app.guard_quotation_integrity` (SECURITY INVOKER so `current_user` names the caller; the definer
-- paths owned by `postgres`, the merge among them, pass through; no separate `auth.uid() is null`
-- exemption, because `service_role` holds no INSERT or UPDATE here and `postgres` is already
-- admitted). The text is trimmed as the RPC trims it, so a blank one is refused by the existing
-- NOT NULL; a note keeps its customer (as a quotation does, 23514); only its author may change its
-- text (42501), so the name on a note is the name of the person who wrote what it says; and
-- `created_at` is kept on UPDATE, as `app.derive_created_by` keeps `created_by`.
--
-- NOT CHANGED: every grant, policy, constraint and foreign key; every other trigger, the archive
-- authority included; `app.add_customer_note` and the merge. Pinning, marking confidential (the
-- policy already limits it to the author) and archiving stay open to whoever could do them before.
-- Positions recorded, not repaired here: `created_at` on INSERT, an archived note inserted at the
-- door, the archive capability, and notes recording no event on any door, the RPC's included.
create or replace function app.guard_customer_note_integrity()
returns trigger
language plpgsql
set search_path to ''
as $fn$
begin
    if current_user = 'postgres' then
        return new;
    end if;

    new.note_text := nullif(btrim(new.note_text), '');

    if tg_op = 'INSERT' then
        return new;
    end if;

    if new.customer_id is distinct from old.customer_id then
        raise exception 'a customer note stays with the customer it was written about; add a new note instead'
            using errcode = '23514';
    end if;

    if new.note_text is distinct from old.note_text
       and old.created_by is distinct from app.current_user_id() then
        raise exception 'only the author of a customer note may change its text; add a new note instead'
            using errcode = '42501';
    end if;

    new.created_at := old.created_at;
    return new;
end;
$fn$;

revoke execute on function app.guard_customer_note_integrity() from public;

create trigger customer_notes_guard_note_integrity
    before insert or update on public.customer_notes
    for each row execute function app.guard_customer_note_integrity();
