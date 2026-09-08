-- ================================================================================================
-- Batch 6 slice 10 -- `invoices`: the financial document that could be rewritten after it was issued
--
-- The slice was chosen by `scripts/batch6_select_target.ps1`, which ranked `invoices` first on
-- EXPOSURE (18) among the 67 surfaces still at NOT-RECORDED. That is a suggestion, not a verdict,
-- and the surface was read before it was attacked: 26 columns, 3 CHECKs, 8 composite FKs, 6 indexes,
-- 10 triggers, one RLS policy, 9 `app.status_transitions` rows, three sanctioned writers
-- (`app.create_invoice`, `app.issue_invoice`, `app.record_payment`) plus `app.void_invoice`.
--
-- MUCH OF IT HELD, AND THAT MATTERS AS MUCH AS WHAT DID NOT. Measured behaviourally, as a real
-- `employee` who owns the booking the invoice hangs off -- so the row is genuinely visible and every
-- refusal below is about capability, not reach:
--
--     update ... set total_amount = 1                 -> 42501  guard_financial_capability
--     update ... set status_code = 'paid'             -> 42501  enforce_status_transition (FIN-7)
--     update ... set external_submission_status_code  -> 42501  guard_financial_capability
--     update ... set is_archived = true               -> 42501  enforce_archive_authority
--     insert  ... into another tenant                 -> RLS with-check
--     update ... set customer_id = <other tenant's>   -> composite FK (TENANT-1)
--     duplicate invoice_number                        -> invoices_tenant_number_key
--     issue an already-issued invoice                 -> app.issue_invoice's own guard
--     two concurrent app.create_invoice calls         -> INV-2026-0001 and INV-2026-0002, the
--                                                        second blocked ~2s on the advisory lock
--
-- THEN THE SAME ACTOR, HOLDING NO FINANCIAL PERMISSION AT ALL, DID THIS:
--
--     update public.invoices set currency_code = 'USD';   -- UPDATE 1
--
-- `app.customer_balance` then reported the debt as 50,000 **USD** where it had been 50,000 EGP. The
-- guarded column `total_amount` never moved. An amount is not a number, it is a PAIR, and
-- `app.guard_financial_capability` named one half of it. Worse, with the invoice already paid in
-- full in EGP, the invoice read USD while its own `payment_allocations` row still read EGP: the
-- document said `paid` in a currency no money had ever arrived in. This is FA-1's shape
-- (`202607061200`, "an account keeps the currency its money arrived in") one table over.
--
-- ------------------------------------------------------------------------------------------------
-- INVOICE-1 .. INVOICE-5, AND WHY THEY ARE ONE DEFECT
-- ------------------------------------------------------------------------------------------------
-- The same actor also re-pointed the invoice to a DIFFERENT customer, rewrote the `invoice_number`
-- of an ISSUED invoice, moved `invoice_date` to 2020, and made the invoice claim -- via
-- `corrects_invoice_id` -- to be a correction of another document. Every one of those succeeded.
--
-- `guard_financial_capability` governs `total_amount`, `status_code` and
-- `external_submission_status_code` and nothing else, and assertion 7 of
-- `68_financial_status_capability_test.sql` pins that as INTENTIONAL: *"the guard is COLUMN-scoped,
-- not a row freeze ... ORVION governs mutation by consequence, not by table."* **That principle is
-- right and is not overturned here.** What was wrong is the CONSEQUENCE SET, and it was wrong by
-- measurement, not by opinion: `currency_code` is read by `app.customer_balance` and
-- `app.customer_exposure_in_limit_currency`; `customer_id` decides whose debt and whose credit
-- ceiling this is; `invoice_number` is the document's identifier in the books. `due_date` -- the
-- column that assertion names -- has no reader in any function, view or policy, so it stays
-- mutable and that assertion stays exactly as written and still passes.
--
-- The correct rule is not "more permissions". Grep says only three statements in the entire
-- repository update this table -- `issue_invoice` (status), `record_payment` (status) and
-- `void_invoice` (status + reason). NOTHING sanctioned has ever changed an invoice's identity,
-- its currency, its customer or its booking after the row existed. The invariant was already true
-- of every path ORVION offers; it simply was not enforced, so the direct door could break it. That
-- is BOOK-1/ADMIN-1/FIN-8/FIN-10/QUO-1's class for the sixth time, and the repair is to state the
-- invariant rather than to invent a policy.
--
--   * IDENTITY AND PROVENANCE ARE FROZEN once the row exists.
--   * `total_amount` MAY still change WHILE THE INVOICE IS A DRAFT. An issued document is a claim
--     that has left the building; canon 07 says corrections after approval go through a new event,
--     adjustment or reversal, `app.guard_invoice_void` already quotes that sentence, and the
--     `corrects_invoice_id` column exists to carry the correcting document. Reproduced: a FULLY
--     PAID invoice's total was raised 50,000 -> 90,000 and its status stayed `paid` while only
--     50,000 was allocated -- and because `record_payment` refuses a `paid` invoice, that gap could
--     never be closed through any sanctioned path. An issued invoice's total was also set to 0,
--     which `app.create_invoice` refuses at birth.
--   * AN INVOICE IS BORN A DRAFT. `app.create_invoice` writes `'draft'` and the transition machine
--     has no producer of any other entry state; direct INSERT could nonetheless raise one already
--     `paid` (with no payment) or already `voided` (with no `void_reason` and no `voided_at`, the
--     exact split state `guard_invoice_void` refuses to produce on UPDATE). LEAD-2's shape.
--
-- THE AUTHORITY QUESTION IS ASKED OF `old`, NOT `new` -- BOOK-5's standing rule, now on its fourth
-- table. "May this column move?" is answered by `old.status_code`, which the attacking statement
-- does not supply. A predicate that read `new.status_code` could be unlocked by setting the status
-- to `draft` in the same statement. It cannot be: nothing in the machine returns to `draft`.
--
-- ------------------------------------------------------------------------------------------------
-- INVOICE-6: THE ARCHIVE ATTRIBUTION THAT WAS ASKED FOR, UNDER A COMMENT SAYING IT WAS NOT
-- ------------------------------------------------------------------------------------------------
-- `202607052800` states in its own header: *"ATTRIBUTION IS STAMPED, NOT ASKED FOR. `archived_at`
-- and `archived_by` are system-generated facts."* The implementation writes
-- `coalesce(new.archived_by, v_actor)`, so a value the caller supplies WINS. Reproduced: a finance
-- manager archived an invoice, recorded a DIFFERENT user as the archiver, and dated the archive to
-- 2001-01-01. IDENT-1's class -- a shipped comment that is false -- and it is not an `invoices`
-- defect at all: this guard serves every archivable table, so the fix belongs in the one function
-- all of them route through, not in a per-table copy. The two RPCs that set `archived_by`
-- explicitly -- `app.merge_customer_identity` and `app.archive_document` -- both resolve it with
-- `select id from public.users where auth_user_id = auth.uid() and tenant_id = v_tenant`, which is
-- what `app.current_user_id()` returns, so stamping unconditionally writes the value they already
-- wrote and changes nothing they do.
--
-- ------------------------------------------------------------------------------------------------
-- INVOICE-7: A TENANT-WIDE DENIAL OF SERVICE THROUGH ONE TEXT COLUMN
-- ------------------------------------------------------------------------------------------------
-- `app.create_invoice` allocates the next number with
-- `max(split_part(invoice_number, '-', 3)::integer)` over `invoice_number like 'INV-<year>-%'`.
-- Setting ONE invoice's number to `INV-2026-abcd` made every subsequent `create_invoice` call in
-- that tenant and year fail with `invalid input syntax for type integer: "abcd"`. Any actor who
-- could see a single invoice could stop the agency raising invoices.
--
-- Freezing `invoice_number` above closes the door the attack came through. It does not make the
-- PARSER total: a `CREATE_INVOICE` holder can still INSERT a malformed number directly, and one
-- day a data import will. The fix is one line and belongs in the scan itself -- match the shape the
-- generator actually produces, so the cast can never see anything else. A CHECK constraint on the
-- column was considered and rejected: it would additionally outlaw the `INV-ALLOC-1` / `INV-V96-3`
-- style numbers that nine existing test fixtures use and that no production path produces, turning
-- a one-line repair into a nine-file rewrite for no behaviour the regex does not already give.
--
-- ------------------------------------------------------------------------------------------------
-- WHAT WAS DELIBERATELY NOT DONE
-- ------------------------------------------------------------------------------------------------
-- No new permission was minted, no grant widened or revoked, no RPC added, no state machine
-- extended, and `app.status_transitions` is untouched -- the machine `202607060200` registered is
-- correct and was re-proven by measurement, not assumed. `due_date` stays mutable. The
-- `external_submission_*` columns keep exactly the authority they have; nothing writes them yet and
-- inventing a tax-authority lifecycle here would be inventing policy (VOID-1's boundary, already
-- decided).
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- 1. INVOICE-1 .. INVOICE-5. Identity is frozen; money moves only while the document is still a draft.
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_invoice_integrity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
    v_new jsonb := to_jsonb(new);
    v_old jsonb;
    v_col text;
begin
    -- Platform/system paths (canon 35 principle 6), as in every sibling guard on this table.
    -- Migrations, seeds and `service_role` carry no resolved identity; a tenant user always does.
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'INSERT' then
        if new.status_code is distinct from 'draft' then
            raise exception
                'an invoice is raised as a draft and issued by app.issue_invoice; it cannot be created already % (canon 26 state machine)',
                new.status_code
                using errcode = '23514';
        end if;
        return new;
    end if;

    v_old := to_jsonb(old);

    -- WHAT the document IS. None of these is written by any sanctioned path after the INSERT, and
    -- each of them changes which financial record this row is rather than what it says.
    foreach v_col in array array['invoice_number', 'customer_id', 'booking_id', 'booking_item_id',
                                 'currency_code', 'invoice_date', 'corrects_invoice_id'] loop
        if (v_new ->> v_col) is distinct from (v_old ->> v_col) then
            raise exception
                'invoice %.% is fixed when the invoice is created and cannot be changed afterwards; correct the document with a new one (corrects_invoice_id)',
                old.invoice_number, v_col
                using errcode = '23514';
        end if;
    end loop;

    -- WHAT the document SAYS. `old`, never `new`: the authority question is about the state the row
    -- was already in, which the attacking statement cannot supply (BOOK-5).
    if new.total_amount is distinct from old.total_amount and old.status_code is distinct from 'draft' then
        raise exception
            'invoice % is % and its total can no longer change; issue a correcting document instead (canon 07: corrections after approval go through a new event, adjustment or reversal)',
            old.invoice_number, old.status_code
            using errcode = '23514';
    end if;

    return new;
end;
$$;

comment on function app.guard_invoice_integrity() is
    'INV-1..INVOICE-5 (slice 10). An invoice''s identity -- number, customer, booking, currency, date, the document it corrects -- is fixed at creation, and its total stops moving once it is no longer a draft. Entry state is `draft`. The state question is asked of OLD (BOOK-5).';

revoke execute on function app.guard_invoice_integrity() from public;

create trigger invoices_guard_integrity
    before insert or update on public.invoices
    for each row execute function app.guard_invoice_integrity();

comment on trigger invoices_guard_integrity on public.invoices is
    'Fires after invoices_guard_financial_capability and before invoices_guard_void (BEFORE row triggers run in name order), so a statement that touches both a guarded amount and a frozen column is refused for the permission first.';

-- ------------------------------------------------------------------------------------------------
-- 2. INVOICE-6. The attribution its own migration header already claimed. Every archivable table.
-- ------------------------------------------------------------------------------------------------
create or replace function app.enforce_archive_authority()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_permission text;
    v_actor uuid;
begin
    -- Platform paths are outside per-table enforcement (canon 35 principle 6), as in SPEC-145/149.
    if (select auth.uid()) is null then
        return new;
    end if;
    if new.is_archived is not distinct from old.is_archived then
        return new;
    end if;

    v_permission := case when tg_table_name = 'documents' then 'ARCHIVE_DOCUMENT' else 'ARCHIVE_RECORD' end;
    perform app.authorize(v_permission);

    -- Restoring is the same authority as archiving: a control that let anyone un-archive would make
    -- the archive itself meaningless.
    v_actor := app.current_user_id();
    if new.is_archived then
        -- INVOICE-6 (202607062000): STAMPED, not coalesced. `202607052800`'s own header said these were
        -- system-generated facts; `coalesce(new.archived_by, v_actor)` let the caller's value win,
        -- and a finance manager archived an invoice as a DIFFERENT user, dated 2001-01-01. The
        -- three RPCs that set `archived_by` explicitly derive it from the session exactly as
        -- `app.current_user_id()` does, so they write the same value they always wrote.
        new.archived_at := now();
        new.archived_by := v_actor;
    else
        new.archived_at := null;
        new.archived_by := null;
    end if;

    return new;
end
$$;

-- ------------------------------------------------------------------------------------------------
-- 3. INVOICE-7. The sequence scan reads only the shape the generator produces, so the cast is total.
-- ------------------------------------------------------------------------------------------------
create or replace function app.create_invoice(
    p_customer_id uuid,
    p_currency_code text,
    p_total_amount numeric,
    p_booking_id uuid default null,
    p_booking_item_id uuid default null,
    p_invoice_date date default current_date,
    p_due_date date default null
)
returns uuid
language plpgsql
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_year text := to_char(coalesce(p_invoice_date, current_date), 'YYYY');
    v_seq integer;
    v_number text;
    v_invoice_id uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    if p_total_amount is null or p_total_amount <= 0 then
        raise exception 'invoice total_amount must be greater than zero';
    end if;

    -- Referenced entities must be in the caller's tenant (RLS with-check covers the insert; these give a
    -- clear error rather than a policy violation, and validate the optional booking links).
    perform 1 from public.customers where id = p_customer_id and tenant_id = v_tenant;
    if not found then
        raise exception 'customer is not in your tenant';
    end if;
    if p_booking_id is not null then
        perform 1 from public.bookings where id = p_booking_id and tenant_id = v_tenant;
        if not found then
            raise exception 'booking is not in your tenant';
        end if;
    end if;
    if p_booking_item_id is not null then
        perform 1 from public.booking_items where id = p_booking_item_id and tenant_id = v_tenant;
        if not found then
            raise exception 'booking item is not in your tenant';
        end if;
    end if;

    perform app.authorize('CREATE_INVOICE');

    -- Serialise number allocation per (tenant, year); gaps are acceptable, collisions are not.
    perform pg_advisory_xact_lock(hashtextextended(v_tenant::text || ':' || v_year, 0));

    -- INVOICE-7 (202607062000): `~` and not `like`. `like 'INV-<year>-%'` admitted anything after the
    -- second dash, and `split_part(...)::integer` then raised 22P02 on it -- so ONE row reading
    -- `INV-2026-abcd` stopped this tenant raising any further invoice for the year. The pattern
    -- below is exactly the shape the next statement generates, which makes the cast total.
    select coalesce(max(split_part(i.invoice_number, '-', 3)::integer), 0) + 1
      into v_seq
    from public.invoices i
    where i.tenant_id = v_tenant
      and i.invoice_number ~ ('^INV-' || v_year || '-[0-9]+$');
    v_number := 'INV-' || v_year || '-' || lpad(v_seq::text, 4, '0');

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    insert into public.invoices (
        tenant_id, customer_id, booking_id, booking_item_id,
        invoice_number, invoice_date, due_date, currency_code,
        total_amount, status_code, created_by
    ) values (
        v_tenant, p_customer_id, p_booking_id, p_booking_item_id,
        v_number, coalesce(p_invoice_date, current_date), p_due_date, p_currency_code,
        p_total_amount, 'draft', v_actor
    ) returning id into v_invoice_id;

    perform app.record_event(
        v_tenant, 'invoice_created', 'invoice', v_invoice_id, v_actor,
        null, 'draft', null,
        jsonb_build_object('invoice_number', v_number, 'customer_id', p_customer_id,
                           'booking_id', p_booking_id, 'currency_code', p_currency_code,
                           'total_amount', p_total_amount),
        'info'
    );

    return v_invoice_id;
end;
$$;
