-- VOID-1 -- the internal invoice void, built so it never speaks for the tax authority.
--
-- =================================================================================================
-- THE OWNER DECISION, QUOTED RATHER THAN INFERRED (2026-09-04)
--
--   "VOID-1 = IMPLEMENT A REAL ARCHITECTURE NOW. The owner explicitly REJECTS draft-only as the
--    final solution."
--   "INTERNAL ORVION INVOICE LIFECYCLE must be cleanly separated from EXTERNAL EGYPTIAN ETA FISCAL
--    LIFECYCLE."
--   "Do NOT encode speculative universal ETA cancellation windows. Do NOT hard-code historical
--    '7 days', '3 days', '60 days', etc. as universal ORVION rules."
--   "Do not claim that an internal ORVION void automatically means an ETA fiscal cancellation."
--   "Do not claim that an ETA cancellation automatically means an internal void unless the mapping
--    is explicitly defined."
--   "If the existing invoice model is insufficient, extend it coherently rather than creating
--    parallel duplicate invoice concepts."
--
-- NOT ONE DAY-COUNT APPEARS IN THIS MIGRATION. Search it: there is no 3, 7 or 60. Every rule below
-- is derived from ORVION's own schema, its own RPCs or its own canon, and each derivation is stated.
--
-- =================================================================================================
-- THE THREE LIFECYCLES, AND THE FACT THAT TWO OF THEM ALREADY EXISTED
--
-- (a) INTERNAL ORVION INVOICE LIFECYCLE -- `invoices.status_code`, catalog `invoice_status_code`:
--     draft / issued / partially_paid / paid / overdue / voided. FIN-7 (`202607060200`) registered
--     six transitions and attached `app.enforce_status_transition`. `voided` was DELIBERATELY left
--     unreachable there because this decision was open. It is reached here, and only here.
--
-- (b) EXTERNAL ETA FISCAL LIFECYCLE -- and it was already modelled, which the earlier framing of
--     VOID-1 missed: `invoices.external_submission_id` (the authority's own document identifier),
--     `external_submission_status_code` (catalog `tax_submission_status_code`),
--     `external_submitted_at` and `external_response_at`. FOUR columns and a governed catalog,
--     structurally complete and with no writer. This migration adds exactly ONE value to that
--     catalog -- `cancelled` -- because without it a future integration could not RECORD an
--     externally-cancelled document at all, which is the boundary the owner asked to be modelled.
--     ORVION cannot perform an ETA cancellation and this migration builds no mechanism that tries.
--
-- (c) CORRECTION BY CREDIT / DEBIT NOTE -- deliberately NOT built. What is added is the single
--     internal ANCHOR a future workflow needs: `invoices.corrects_invoice_id`. Nothing produces it.
--
-- THE SEPARATION, STATED AS THE RULE THE OWNER RATIFIED:
--   * an internal void is an ORVION bookkeeping act and asserts NOTHING about ETA;
--   * an ETA cancellation is an external fact ORVION can only RECORD, and it does not void anything
--     internally, because no mapping has been defined and inventing one is inventing tax policy;
--   * the two are joined by exactly one refusal -- see step 5.
--
-- =================================================================================================
-- WHERE EACH INTERNAL RULE COMES FROM. Derived, not chosen.
--
-- 1. `draft`, `issued` and `overdue` may be voided; `partially_paid` and `paid` may NOT.
--    DERIVED FROM ORVION'S OWN ARITHMETIC, not from an accounting opinion: `app.customer_balance`
--    computes the receivable as invoices MINUS payments PLUS completed refunds, and it EXCLUDES any
--    invoice with `voided_at is not null`. Void an invoice that carries allocated payment and the
--    invoice leaves the sum while the payment stays in it -- the customer acquires a credit balance
--    backed by no document. The rule is not "voiding a paid invoice is bad practice"; it is that
--    ORVION's own balance function would produce a number that is wrong.
--    Canon 07 states the same posture in its own words: "Any correction after approval must be
--    handled through a new event, adjustment, reversal, or authorized finance action." A refund is
--    already a first-class ORVION entity; a void is not a refund and must not be used as one.
--
-- 2. The precondition is ALLOCATED PAYMENT, not the status word. `status_code` is derived by
--    `app.record_payment` from the amount, so trusting it alone would let a race or a direct table
--    write leave `issued` on an invoice that has money against it. The guard therefore asks
--    `public.payment_allocations` -- the table that actually holds the link -- and PAY-1 already
--    guarantees an allocation cannot exist against an invoice that was never issued.
--
-- 3. `voided` is TERMINAL. `app.status_transitions` gains no row leaving it, so
--    `enforce_status_transition` refuses every exit; the guard below refuses un-voiding explicitly
--    as well, so the failure is a clear message rather than a generic transition refusal.
--
-- 4. The STATUS and the TIMESTAMP must move together. DOC-LC-3 is the standing lesson: two columns
--    representing one fact, movable independently, produce a split state nothing can re-version.
--    `voided_at` may change only in the same statement that sets `status_code = 'voided'`, and it is
--    DERIVED here rather than accepted from the caller -- ATTR-3 / FIN-4 / ATTR-2's class, where a
--    row could name anyone as its actor.
--
-- 5. THE ONE PLACE THE TWO LIFECYCLES TOUCH. An invoice the tax authority has ACCEPTED may not be
--    voided internally. Not because of any window -- none is encoded -- but because ORVION would
--    then hold a document its own books call void while the authority holds it as live, and ORVION
--    has no integration with which to reconcile that. Refusing is the only honest option available
--    to a system that cannot act externally. `submitted`, `pending`, `failed` and `rejected` do NOT
--    block: none of them is an accepted fiscal document.
--
-- 6. Voiding may not touch the external columns. A bookkeeping act must not rewrite what the
--    authority said.
-- =================================================================================================

-- 1. THE PERMISSION. Same mechanism as MANAGE_SUPPLIER_CREDIT / MANAGE_CUSTOMER_CREDIT. Granted to
--    the same three roles that hold CREATE_INVOICE (owner, ceo, finance_manager) -- measured, not
--    assumed -- because voiding is the counterpart of issuing and belongs to the same authority.
--    Plan-gated `finance_lite`, matching CREATE_INVOICE's tier.
insert into public.permissions (key, name, description, required_feature_code, is_system, is_active)
values ('VOID_INVOICE',
        'Void an invoice',
        'Void an ORVION invoice internally. This is a bookkeeping act only: it asserts NOTHING '
        'about the invoice''s status with any tax authority, and ORVION performs no external '
        'cancellation. Refused once payment is allocated (use a refund) and once the document has '
        'been externally accepted. Owner decision VOID-1, 2026-09-04.',
        'finance_lite', true, true)
on conflict (key) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where p.key = 'VOID_INVOICE'
  and r.code in ('owner', 'ceo', 'finance_manager')
on conflict do nothing;

-- 2. THE VOCABULARY. One internal event, and one EXTERNAL state so the boundary is representable.
--    `invoice_voided` is the internal act. `cancelled` on `tax_submission_status_code` is not an act
--    ORVION can perform -- it is a fact ORVION must be able to RECORD when an integration reports
--    it. Adding it now is what stops a future ETA package from having to widen a catalog the
--    invoice model already depends on.
insert into public.catalog_values (catalog_type_code, code, label, description, sort_order, is_system, is_active)
select v.type_code, v.code, v.label, v.descr, v.ord, true, true
from (values
        ('event_type', 'invoice_voided', 'Invoice Voided',
         'An ORVION invoice was voided internally. Carries no external/tax meaning.', 904),
        ('tax_submission_status_code', 'cancelled', 'Cancelled',
         'The external authority reports this document as cancelled. ORVION can only RECORD this; '
         'it performs no external cancellation, and this state does NOT void the ORVION invoice -- '
         'no such mapping is defined (VOID-1, 2026-09-04).', 6)
     ) as v(type_code, code, label, descr, ord)
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = v.type_code
      and cv.code = v.code
      and cv.tenant_id is null
);

-- 3. THE CREDIT/DEBIT-NOTE ANCHOR, AND NOTHING MORE.
--    ETA requires a correcting document to reference the ORIGINAL document's identifier. ORVION
--    already stores that identifier (`external_submission_id`). What it could not express is one
--    ORVION invoice standing as the correction of another. This column is that reference and only
--    that: no credit-note type, no workflow, no producer, no automatic effect on any balance.
--    It qualifies under `AGENTS.md §3`'s Fundamental Domain Structure test -- a correcting-document
--    linkage is inevitable in a mature travel ERP regardless of feature order, and adding it now
--    avoids a structural migration on the finance spine later.
--    Composite FK per TENANT-1: a correction and its original are always the same tenant's.
alter table public.invoices
    add column if not exists corrects_invoice_id uuid;

do $DO$
begin
    if not exists (select 1 from pg_constraint where conname = 'invoices_corrects_invoice_fkey') then
        alter table public.invoices
            add constraint invoices_corrects_invoice_fkey
            foreign key (tenant_id, corrects_invoice_id)
            references public.invoices(tenant_id, id) on delete restrict;
    end if;
    if not exists (select 1 from pg_constraint where conname = 'invoices_corrects_not_self_check') then
        alter table public.invoices
            add constraint invoices_corrects_not_self_check
            check (corrects_invoice_id is null or corrects_invoice_id <> id);
    end if;
end
$DO$;

comment on column public.invoices.corrects_invoice_id is
'VOID-1 (2026-09-04): the internal anchor for a FUTURE credit/debit-note workflow -- the invoice '
'this one corrects. Nothing writes it today and it has no effect on any balance; it exists so a '
'later ETA correction package can reference the original deterministically without restructuring '
'the invoice model. A credit note is NOT a void and this column does not make one.';

comment on column public.invoices.external_submission_status_code is
'The EXTERNAL (tax authority) document lifecycle, deliberately separate from `status_code`, which '
'is ORVION''s INTERNAL lifecycle. VOID-1: an internal void asserts nothing here, and a `cancelled` '
'recorded here does NOT void the ORVION invoice -- no mapping between the two is defined, and '
'inventing one would be inventing tax policy. The only link is a refusal: an invoice already '
'`accepted` externally cannot be voided internally, because ORVION cannot reconcile the difference.';

-- 4. THE TRANSITIONS. `voided` becomes reachable from the three states that carry no allocated
--    money, and from nowhere else. No row LEAVES `voided`: it is terminal, and
--    `app.enforce_status_transition` (FIN-7) refuses every exit for free.
--    `partially_paid` and `paid` are absent on purpose -- see derivation 1 in the header.
insert into app.status_transitions (table_name, status_column, from_status, to_status, permission_key)
select v.tbl, v.col, v.frm, v.tos, v.perm
from (values
        ('invoices', 'status_code', 'draft',   'voided', 'VOID_INVOICE'),
        ('invoices', 'status_code', 'issued',  'voided', 'VOID_INVOICE'),
        ('invoices', 'status_code', 'overdue', 'voided', 'VOID_INVOICE')
     ) as v(tbl, col, frm, tos, perm)
where not exists (
    select 1 from app.status_transitions st
    where st.table_name = v.tbl and st.status_column = v.col
      and st.from_status = v.frm and st.to_status = v.tos
);

-- =================================================================================================
-- 5. THE GUARD. Every rule above, enforced on EVERY door.
--
--    `authenticated` holds INSERT/SELECT/UPDATE on `public.invoices`, so PostgREST serves the table
--    beside the RPC and an RPC-only rule is a half-fix (BOOK-1, ADMIN-1, FIN-8, FIN-10, QUO-1).
--    This is a BEFORE trigger, so it refuses rather than merely observing.
-- =================================================================================================
create or replace function app.guard_invoice_void()
returns trigger
language plpgsql
set search_path = ''
as $FN$
declare
    v_voiding   boolean;
    v_allocated numeric;
begin
    -- Platform/system paths (canon 35 principle 6), as in every sibling guard.
    if (select auth.uid()) is null then
        return new;
    end if;

    v_voiding := new.status_code = 'voided' and old.status_code is distinct from 'voided';

    -- UN-VOIDING IS REFUSED EXPLICITLY. `enforce_status_transition` would refuse it anyway (no row
    -- leaves `voided`), but a caller deserves the real reason rather than a generic one.
    if old.status_code = 'voided' and new.status_code is distinct from 'voided' then
        raise exception 'a voided invoice is terminal and cannot be un-voided; issue a correcting document instead'
            using errcode = '23514';
    end if;

    -- DOC-LC-3'S LESSON, APPLIED BEFORE IT CAN HAPPEN: the status and the timestamp are two
    -- representations of one fact and may not move apart. Moving `voided_at` without moving the
    -- status is exactly the split state that made `documents` unre-versionable.
    if not v_voiding and (new.voided_at is distinct from old.voided_at
                          or new.voided_by is distinct from old.voided_by) then
        raise exception 'voided_at/voided_by may only change in the statement that sets status_code to voided'
            using errcode = '23514';
    end if;

    if not v_voiding then
        return new;
    end if;

    -- ------------------------------------------------------------------------------------------
    -- DERIVATION 1 + 2: allocated money, asked of the table that actually holds it.
    -- ------------------------------------------------------------------------------------------
    select coalesce(sum(pa.allocated_amount), 0) into v_allocated
    from public.payment_allocations pa
    where pa.tenant_id = new.tenant_id and pa.invoice_id = new.id;

    if v_allocated > 0 then
        raise exception
            'invoice % carries % allocated in payment and cannot be voided; correct it with a refund or a credit note, not a void (canon 07: corrections after approval go through a new event, adjustment or reversal)',
            new.invoice_number, v_allocated
            using errcode = '23514';
    end if;

    -- ------------------------------------------------------------------------------------------
    -- DERIVATION 5: the ONE place the internal and external lifecycles touch, and it is a refusal.
    -- No day-count, no window, no jurisdiction rule -- only "ORVION will not hold a document its own
    -- books call void while the authority holds it as live".
    -- ------------------------------------------------------------------------------------------
    if old.external_submission_status_code = 'accepted' then
        raise exception
            'invoice % was ACCEPTED by the external tax authority (submission %) and cannot be voided internally; ORVION performs no external cancellation, so an internal void here would make the two records disagree. Correct it with a credit/debit note once that capability exists',
            new.invoice_number, coalesce(new.external_submission_id, '(no id recorded)')
            using errcode = '23514';
    end if;

    -- ------------------------------------------------------------------------------------------
    -- DERIVATION 6: a bookkeeping act must not rewrite what the authority said.
    -- ------------------------------------------------------------------------------------------
    if new.external_submission_status_code is distinct from old.external_submission_status_code
       or new.external_submission_id is distinct from old.external_submission_id
       or new.external_submitted_at is distinct from old.external_submitted_at
       or new.external_response_at is distinct from old.external_response_at then
        raise exception 'voiding an invoice may not change its external submission state -- the internal void asserts nothing about the tax authority'
            using errcode = '23514';
    end if;

    -- A reason is REQUIRED. Canon 26 already demands one for archiving; a void is the stronger act.
    if new.void_reason is null or btrim(new.void_reason) = '' then
        raise exception 'void_reason is required when voiding an invoice'
            using errcode = '23514';
    end if;

    -- DERIVED, never caller-supplied (ATTR-3 / FIN-4 / ATTR-2's class).
    new.voided_at := now();
    new.voided_by := app.current_user_id();

    return new;
end;
$FN$;

revoke all on function app.guard_invoice_void() from public;

drop trigger if exists invoices_guard_void on public.invoices;
create trigger invoices_guard_void
    before update on public.invoices
    for each row execute function app.guard_invoice_void();

-- =================================================================================================
-- 6. THE RPC. The named door, so a client does not have to know the column protocol. It adds no
--    rule the table door lacks -- every refusal above applies to both -- and it exists so the act
--    is auditable as one intention rather than inferred from a column diff.
-- =================================================================================================
create or replace function app.void_invoice(p_invoice_id uuid, p_reason text)
returns uuid
language plpgsql
security definer
set search_path = ''
as $FN$
declare
    v_tenant uuid := app.current_tenant_id();
    v_inv    record;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    perform app.authorize('VOID_INVOICE');

    select id, status_code, invoice_number, voided_at, is_archived
      into v_inv
    from public.invoices
    where id = p_invoice_id and tenant_id = v_tenant;
    if not found then
        raise exception 'invoice is not in your tenant';
    end if;
    if v_inv.is_archived then
        raise exception 'invoice is archived';
    end if;
    if v_inv.voided_at is not null then
        raise exception 'invoice % is already voided', v_inv.invoice_number;
    end if;

    -- The UPDATE carries only the two columns a caller may set. `voided_at`, `voided_by` and every
    -- refusal are the guard's, so this path and the table door cannot diverge.
    update public.invoices
       set status_code = 'voided',
           void_reason = p_reason
     where id = p_invoice_id and tenant_id = v_tenant;

    perform app.record_event(
        v_tenant, 'invoice_voided', 'invoice', p_invoice_id,
        null, null, null,
        'Invoice voided internally. This asserts nothing about any external tax authority.',
        jsonb_build_object(
            'invoice_id',     p_invoice_id,
            'invoice_number', v_inv.invoice_number,
            'from_status',    v_inv.status_code,
            'reason',         p_reason,
            'external_effect', 'none'
        ),
        'warning'
    );

    return p_invoice_id;
end;
$FN$;

revoke all on function app.void_invoice(uuid, text) from public;
grant execute on function app.void_invoice(uuid, text) to authenticated;

create or replace function public.void_invoice(p_invoice_id uuid, p_reason text)
returns uuid
language sql
set search_path = ''
as $FN$ select app.void_invoice(p_invoice_id, p_reason) $FN$;

revoke all on function public.void_invoice(uuid, text) from public;
grant execute on function public.void_invoice(uuid, text) to authenticated;

comment on function public.void_invoice(uuid, text) is
'VOID-1: void an ORVION invoice internally, with a required reason. Refused once payment is '
'allocated (use a refund) and once the document has been externally accepted. Performs NO external '
'cancellation and asserts nothing about any tax authority.';

-- =================================================================================================
-- 7. `journal_entries` -- RECORDED AS CLOSED-BY-DESIGN, AND DELIBERATELY NOT GIVEN A WRITER.
--
--    `journal_entries` carries the same three columns (`voided_at`, `voided_by`, `void_reason`) with
--    ZERO readers anywhere and no catalog state behind them -- measured. They are NOT dropped here:
--    dropping is a destructive migration, DEAD-1's precedent keeps inevitable structure, and
--    VERIFY-1's precedent is to keep such columns and record them as closed-by-design so no future
--    implementer reads them as an unbuilt feature.
--
--    The reason they must never get a writer is canon 07's own correction rule -- "Any correction
--    after approval must be handled through a new event, adjustment, reversal, or authorized
--    finance action" -- which for a POSTED double-entry record means a compensating REVERSAL entry,
--    never mutation of the original. Voiding a posted entry would destroy the audit trail the
--    entry exists to be.
-- =================================================================================================
comment on column public.journal_entries.voided_at is
'CLOSED BY DESIGN (VOID-1, 2026-09-04) -- kept, and deliberately never given a writer. A POSTED '
'journal entry is corrected by a compensating REVERSAL entry, never by mutation: canon 07 requires '
'corrections after approval to go through a new event, adjustment or reversal. Do not read this '
'column as an unbuilt feature, and do not wire it to the invoice void, which is a different act on '
'a different object.';
