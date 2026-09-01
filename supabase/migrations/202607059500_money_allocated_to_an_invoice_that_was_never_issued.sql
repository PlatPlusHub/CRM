-- ================================================================================================
-- PAY-1 / JE-1 / DEV-1 -- the finance periphery, and the blind spot in PARENT-1's own detector.
--
-- Batch-6 slice: the tables `authenticated` can write that NO TEST HAS EVER BEEN ABOUT. The ranking
-- was derived from the catalog (grants x guard triggers x CHECKs x writing RPCs x test subjectship)
-- and ATTACKED before use: counting BEFORE triggers scores `moddatetime` and `emit_*` as protection,
-- and counting test-file mentions scores `branches`/`users`/`tenants` at 60-76 because EVERY test
-- builds a tenant fixture. Appearance is not subjectship.
--
-- ------------------------------------------------------------------------------------------------
-- PAY-1 (High) -- money allocated against an invoice that was never issued, or that was voided.
--
--   app.record_payment refuses, in this order:
--       'invoice is archived or voided'
--       'only an issued/partially_paid/overdue invoice can be paid (is %)'
--   REPRODUCED as a finance_manager genuinely holding RECORD_PAYMENT, against two real invoices:
--       RPC, draft invoice   -> refused: only an issued/partially_paid/overdue invoice can be paid (is draft)
--       RPC, voided invoice  -> refused: ... (is voided)
--       direct DML, both     -> INSERT 0 2, and 1,000 EGP now sits allocated against a VOIDED invoice
--       direct DML, archived -> INSERT 0 1
--   `enforce_invoice_allocation_ceiling` (FIN-10) already guards this table -- it caps the AMOUNT and
--   never reads the invoice's STATE, which is why the ceiling was green throughout. Consequence:
--   every balance derived from allocations misstates what the customer owes. FIN-6's family.
--
-- ------------------------------------------------------------------------------------------------
-- JE-1 (Medium) -- a journal line posted to a RETIRED chart account.
--
--   app.create_journal_entry refuses 'unknown or inactive chart account code: %'. REPRODUCED: the
--   same finance_manager deactivated accounts 1000 and 1100 (the policy permits that with
--   CREATE_JOURNAL_ENTRY), the RPC refused, and the identical two lines went in by direct DML.
--   Two of the RPC's three line rules were ALREADY on the table door and are NOT re-added here --
--   `journal_entry_lines_debit_xor_credit_check` enforces non-negative and debit-xor-credit, and
--   `enforce_journal_entry_balanced` enforces >= 2 lines, balance and non-zero. Only the ACTIVE
--   account rule was missing. Measured before writing, not assumed.
--
-- ------------------------------------------------------------------------------------------------
-- DEV-1 (Low) -- two rows for one device, and revoking one leaves the other trusted.
--
--   `app.record_trusted_device` is UPDATE-then-INSERT-if-not-found on (auth_user_id,
--   device_identifier), and NOTHING made that pair unique -- LIC-2's check-then-act shape exactly.
--   REPRODUCED THROUGH THE RPC ALONE, no direct DML: two concurrent sessions, the first holding its
--   transaction open, both called app.record_trusted_device('RACE-1') and the table ended with TWO
--   rows. `app.revoke_trusted_device` then revokes one by id, and `app.my_trusted_devices()` shows
--   the same device as revoked AND trusted at once.
--   SEVERITY IS LOW AND THAT WAS MEASURED, NOT ASSUMED: `app.mfa_satisfied()` reads ONLY the JWT
--   `aal` claim and never consults this table, so a trusted device grants no authority in ORVION
--   today. The damage is a security screen that tells the user something false.
--   The invariant is NOT invented here: `record_trusted_device` already treats the pair as a key --
--   it looks the row up by exactly those two columns and re-trusts it in place, so the function's
--   own model is one row per (user, device). The index makes that model true, and the upsert makes
--   the race resolve instead of raising.
--
-- ------------------------------------------------------------------------------------------------
-- AND THE FINDING ABOUT MY OWN GUARD -- PARENT-1's detector could not see PAY-1.
--
-- 202607059400 derived its population from `app.status_transitions`, and `invoices` HAS NO ROWS
-- THERE: canon defines no Invoice State Machine (FIN-7). So `invoices.status_code` is a state that
-- governs behaviour and is not a governed transition, and the detector -- anchored on a catalog of
-- TRANSITIONS rather than of STATE -- was structurally blind to it. That is PAR-3's rule turned on
-- my own work: a guard whose description is broader than its measurement is the finding.
-- Widened here to `app.status_transitions.status_column` UNION every column an
-- `app.enforce_catalog_codes` trigger validates, read out of the TRIGGER ARGUMENTS -- which is the
-- repository's own structural definition of a state vocabulary, and catches `invoices.status_code`.
-- The residual is stated rather than hidden: state carried as a BOOLEAN flag (`is_active`,
-- `is_archived`, `is_current`) still cannot be enumerated this way -- the attempt produced 46 pairs
-- of which most are actor and plan LOOKUPS, and pinning those would be an exemption list wearing an
-- inventory's clothes. JE-1 is exactly that residual class, found by reading rather than by the
-- detector, and it is paid down table by table as this audit reaches each one.
-- ================================================================================================

create or replace function app.guard_parent_state_allows_write()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_new      jsonb := to_jsonb(new);
    v_tenant   uuid  := nullif(v_new ->> 'tenant_id', '')::uuid;
    v_parent   uuid;
    v_status   text;
    v_archived boolean;
    v_item     record;
    v_inv      record;
    v_code     text;
begin
    case tg_table_name

    -- app.create_booking: "only an accepted quotation can produce a booking".
    when 'bookings' then
        v_parent := nullif(v_new ->> 'quotation_id', '')::uuid;
        if v_parent is null then
            return new;
        end if;
        select q.quotation_status_code into v_status
        from public.quotations q
        where q.id = v_parent and q.tenant_id = v_tenant;
        if v_status is null then
            raise exception 'quotation is not in your tenant' using errcode = '23514';
        end if;
        if v_status <> 'accepted' then
            raise exception 'only an accepted quotation can produce a booking (status: %)', v_status
                using errcode = '23514';
        end if;

    -- app.request_finance_approval: the item and its booking must both be live.
    when 'approval_requests' then
        v_parent := nullif(v_new ->> 'booking_item_id', '')::uuid;
        if v_parent is null then
            return new;
        end if;
        select bi.base_status_code, bi.is_archived as item_archived,
               b.booking_status_code, b.is_archived as booking_archived
          into v_item
        from public.booking_items bi
        join public.bookings b on b.id = bi.booking_id and b.tenant_id = bi.tenant_id
        where bi.id = v_parent and bi.tenant_id = v_tenant;
        if not found then
            raise exception 'booking item is not in your tenant' using errcode = '23514';
        end if;
        if v_item.item_archived or v_item.base_status_code in ('cancelled', 'no_show') then
            raise exception 'cannot request finance approval on a cancelled/no_show/archived booking item'
                using errcode = '23514';
        end if;
        if v_item.booking_archived or v_item.booking_status_code in ('completed', 'cancelled') then
            raise exception 'cannot request finance approval on a completed/cancelled/archived booking'
                using errcode = '23514';
        end if;

    -- app.add_document_version: "cannot add a version to an archived document".
    when 'document_versions' then
        v_parent := nullif(v_new ->> 'document_id', '')::uuid;
        select d.lifecycle_status_code, d.is_archived into v_status, v_archived
        from public.documents d
        where d.id = v_parent and d.tenant_id = v_tenant;
        if v_status is null then
            raise exception 'document is not in your tenant' using errcode = '23514';
        end if;
        if v_archived or v_status = 'archived' then
            raise exception 'cannot add a version to an archived document' using errcode = '23514';
        end if;

    -- app.send_conversation_message: a closed conversation is a finished engagement.
    when 'conversation_messages' then
        v_parent := nullif(v_new ->> 'conversation_id', '')::uuid;
        select c.conversation_status_code into v_status
        from public.conversations c
        where c.id = v_parent and c.tenant_id = v_tenant;
        if v_status is null then
            raise exception 'conversation not found in your tenant' using errcode = '23514';
        end if;
        if v_status = 'closed' then
            raise exception 'conversation is closed; reopen it before sending a message'
                using errcode = '23514';
        end if;

    -- PAY-1. app.record_payment, both refusals, in its own order and its own words. The payable set
    -- is the RPC's, not a judgement made here: 'paid' is excluded because a fully paid invoice has
    -- nothing left to allocate, and FIN-10's ceiling is the separate, complementary rule about HOW
    -- MUCH -- this one is about WHETHER.
    when 'payment_allocations' then
        v_parent := nullif(v_new ->> 'invoice_id', '')::uuid;
        select i.status_code, i.voided_at, i.is_archived into v_inv
        from public.invoices i
        where i.id = v_parent and i.tenant_id = v_tenant;
        if not found then
            raise exception 'invoice is not in your tenant' using errcode = '23514';
        end if;
        if v_inv.is_archived or v_inv.voided_at is not null then
            raise exception 'invoice is archived or voided' using errcode = '23514';
        end if;
        if v_inv.status_code not in ('issued', 'partially_paid', 'overdue') then
            raise exception 'only an issued/partially_paid/overdue invoice can be paid (is %)',
                v_inv.status_code using errcode = '23514';
        end if;

    -- JE-1. app.create_journal_entry: 'unknown or inactive chart account code: %'. The message
    -- names the CODE rather than the id because that is what the RPC's caller supplies and what a
    -- human recognises; the code is looked up rather than taken from the caller.
    when 'journal_entry_lines' then
        v_parent := nullif(v_new ->> 'chart_account_id', '')::uuid;
        select ca.code, ca.is_active into v_code, v_archived
        from public.chart_of_accounts ca
        where ca.id = v_parent and ca.tenant_id = v_tenant;
        if v_code is null then
            raise exception 'unknown or inactive chart account code: %', v_parent
                using errcode = '23514';
        end if;
        if not v_archived then
            raise exception 'unknown or inactive chart account code: %', v_code
                using errcode = '23514';
        end if;

    else
        raise exception 'app.guard_parent_state_allows_write has no rule for %', tg_table_name
            using errcode = 'insufficient_privilege';
    end case;

    return new;
end
$fn$;

comment on function app.guard_parent_state_allows_write() is
    'PARENT-1 / PAY-1 / JE-1. Enforces on the table door the parent-state rules that '
    'app.create_booking, app.request_finance_approval, app.add_document_version, '
    'app.send_conversation_message, app.record_payment and app.create_journal_entry each already '
    'enforce (ADR-0024). BEFORE INSERT only: the rule governs creation, not the child row''s later '
    'life. Messages are copied verbatim from those functions.';

create trigger payment_allocations_guard_parent_state
    before insert on public.payment_allocations
    for each row execute function app.guard_parent_state_allows_write();

create trigger journal_entry_lines_guard_parent_state
    before insert on public.journal_entry_lines
    for each row execute function app.guard_parent_state_allows_write();

-- ================================================================================================
-- DEV-1. The index states the invariant; the upsert makes the function honour it atomically.
-- `on conflict ... do update` is one statement and takes the row lock itself, so the window two
-- concurrent callers drove through no longer exists -- rather than a compare-and-swap (LIC-2's fix),
-- because that fix guarded a SINGLE-USE resource where losing the race must FAIL, and here the
-- correct outcome for the loser is to re-trust the same row, which is what the RPC always intended.
-- ================================================================================================

create unique index trusted_devices_user_device_key
    on public.trusted_devices (auth_user_id, device_identifier);

create or replace function app.record_trusted_device(p_device_identifier text)
returns uuid
language plpgsql
set search_path = ''
as $fn$
declare
    v_uid uuid := (select auth.uid());
    v_id uuid;
begin
    if v_uid is null then
        raise exception 'not authenticated';
    end if;

    insert into public.trusted_devices (auth_user_id, device_identifier, status_code, verified_at)
    values (v_uid, p_device_identifier, 'trusted', now())
    on conflict (auth_user_id, device_identifier) do update
    set last_seen_at = now(),
        status_code  = 'trusted',
        -- The FIRST verification is the one worth keeping; re-seeing a device is not re-verifying it.
        verified_at  = coalesce(public.trusted_devices.verified_at, now()),
        revoked_at   = null
    returning id into v_id;

    return v_id;
end
$fn$;
