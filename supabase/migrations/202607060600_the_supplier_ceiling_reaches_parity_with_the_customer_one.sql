-- SUP-4d + CUST-4 + CUST-5 + SUP-4c -- the supplier ceiling reaches parity with the customer one.
--
-- =================================================================================================
-- WHY THESE FOUR TRAVEL TOGETHER
--
-- All four were opened by the CUST-3 implementation (`202607060300`) and all four were deferred with
-- the same sentence: "recorded here rather than fixed inside a customer migration". They are the
-- supplier half of one control. Splitting them across four migrations would touch
-- `app.supplier_exposure_in_limit_currency`, `app.supplier_credit` and
-- `app.evaluate_supplier_credit_threshold` three times each for one coherent outcome.
--
-- NOT ONE OF THEM IS A POLICY QUESTION. Each is measured below against the live catalog, and each
-- fix reuses an authority that already exists. No new permission, no new notification type, no new
-- catalog value, no new table, no second FX authority.
--
-- =================================================================================================
-- WHAT THIS DELIBERATELY DOES NOT DO
--
-- NO BLOCKING. `enforcement => 'warning_only'` is unchanged and no write path gains a refusal. The
-- new ceiling probe is an AFTER trigger returning null, exactly as `customers_probe_credit_ceiling`
-- is, so the write is already committed and cannot be affected.
--
-- NO SECOND FX AUTHORITY. `app.exchange_rate_as_of` -- written GENERIC by CUST-3 precisely so the
-- supplier side could adopt it -- is the only rate source used here. No new rate table, no new
-- as-of rule, no per-supplier override.
--
-- NO RENAMED COLUMNS. `app.supplier_credit` returns `permitted`/`exposure_amount`/
-- `threshold_exceeded` where `app.customer_credit` returns `may_view`/`exposure`/`over_limit`. That
-- asymmetry is cosmetic, it is not a defect, and renaming it would break every existing caller for
-- nothing. Only the genuinely MISSING column is added.
--
-- =================================================================================================
-- 1. CUST-4 -- `suppliers.credit_limit_amount` has no non-negative constraint
--
-- MEASURED at this migration's HEAD (`1df2f06`), live:
--   suppliers: suppliers_credit_limit_currency_check  CHECK ((credit_limit_amount IS NULL) = (credit_limit_currency_code IS NULL))
--   customers: customers_credit_limit_currency_check      -- the same both-or-neither rule, AND
--              customers_credit_limit_non_negative_check  CHECK (credit_limit_amount IS NULL OR credit_limit_amount >= 0)
--
-- A negative ceiling is meaningless in both directions: `exposure > limit` against a negative limit
-- fires on the first EGP of exposure and can never clear. CUST-3 added the constraint for customers
-- because of that; the supplier table never got it. One line, and it is the same line.

alter table public.suppliers
    add constraint suppliers_credit_limit_non_negative_check
    check (credit_limit_amount is null or credit_limit_amount >= 0);

-- =================================================================================================
-- 2. SUP-4c -- non-matching currencies are SILENTLY DROPPED
--
-- MEASURED, live, in `app.supplier_exposure_in_limit_currency`:
--   from public.booking_items bi ... and bi.currency_code = p_currency_code
--   from public.payments p       ... and p.currency_code  = p_currency_code
--
-- A supplier owed EGP 8,000 and USD 600 against an EGP ceiling is measured on the EGP alone, and
-- nothing anywhere says so. The reader returns a number that LOOKS complete.
--
-- THE RATE INSTANT IS NOT INVENTED HERE AND WAS NOT INVENTED FOR CUST-3 EITHER. SUP-4c was
-- reclassified from "BLOCKED -- BUSINESS DECISION" to ENGINEERING on 2026-09-04 on external
-- evidence: credit exposure measured against a limit is converted INTO THE LIMIT'S CURRENCY AT THE
-- CURRENT SPOT RATE (`12 CFR 32.9` determines current credit exposure by mark-to-market; the same
-- rule governs counterparty credit-limit systems). Canon 14's LOCKED rate is the ACCOUNTING instant
-- and belongs to the transaction, not to a control. `credit_limit_currency_code` is already the base
-- currency, so no tenant base currency is needed and none is introduced.
--
-- THE GAP IS STATED, NEVER SWALLOWED -- CUST-3's rule, applied here. A currency carrying real
-- exposure with no usable rate is REPORTED rather than dropped, and the convertible part is still
-- compared. That is the whole difference from the function being replaced: it dropped silently.
--
-- The return type changes (numeric -> TABLE), so this is DROP + CREATE rather than REPLACE, and the
-- two dependants are recreated below in dependency order. Dropping resets the ACL, so the
-- `revoke ... from public` that GRANT-1 requires is restated on every function this migration
-- creates -- the default ACL grants EXECUTE to PUBLIC, which is how `anon` acquired two readers
-- during CUST-3 and was caught by `10_grant_model_test` and `53_api_surface_test` independently.

drop function if exists public.supplier_credit(uuid);
drop function if exists app.supplier_credit(uuid);
drop function if exists app.supplier_exposure_in_limit_currency(uuid, uuid, text);

create function app.supplier_exposure_in_limit_currency(
    p_tenant_id   uuid,
    p_supplier_id uuid,
    p_currency_code text
)
returns table (exposure numeric, unconvertible text[])
language sql
stable
security definer
set search_path = ''
as $$
    -- Structurally identical to `app.customer_exposure_in_limit_currency`: aggregate PER CURRENCY
    -- first, price each currency into the limit currency second, and report what could not be
    -- priced. Same shape, different ledger -- payables (booking_items cost, less supplier payments)
    -- rather than receivables. The row filters are UNCHANGED from the function this replaces except
    -- that the `currency_code = p_currency_code` restriction is gone: same locked-cost rule, same
    -- archived exclusion, same cancelled/no_show exclusion, same supplier_payment direction.
    with per_currency as (
        select c.currency_code, sum(c.cost) - sum(c.paid) as outstanding
        from (
            select bi.currency_code, bi.cost_amount as cost, 0::numeric as paid
            from public.booking_items bi
            where bi.tenant_id = p_tenant_id
              and bi.supplier_id = p_supplier_id
              and bi.cost_locked_at is not null
              and bi.is_archived = false
              and bi.base_status_code not in ('cancelled', 'no_show')
              and bi.cost_amount is not null
            union all
            select p.currency_code, 0::numeric, p.amount
            from public.payments p
            where p.tenant_id = p_tenant_id
              and p.supplier_id = p_supplier_id
              and p.payment_direction_code = 'supplier_payment'
        ) c
        group by c.currency_code
    ),
    priced as (
        select pc.currency_code,
               pc.outstanding,
               app.exchange_rate_as_of(p_tenant_id, pc.currency_code, p_currency_code) as rate
        from per_currency pc
        where pc.outstanding <> 0
    )
    select
        coalesce(sum(pr.outstanding * pr.rate) filter (where pr.rate is not null), 0)::numeric,
        coalesce(array_agg(distinct pr.currency_code) filter (where pr.rate is null), '{}'::text[])
    from priced pr
$$;

revoke execute on function app.supplier_exposure_in_limit_currency(uuid, uuid, text) from public;

-- The gated reader. `unconvertible_currencies` is ADDED -- the one genuinely missing column, and the
-- one that stops this function reporting an incomplete figure as if it were complete. Everything
-- else about the signature is preserved so existing callers keep working.

create function app.supplier_credit(p_supplier_id uuid)
returns table (
    credit_limit_amount      numeric,
    credit_limit_currency_code text,
    permitted                boolean,
    exposure_amount          numeric,
    threshold_exceeded       boolean,
    unconvertible_currencies text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    -- The row must be visible to the CALLER, not merely to this DEFINER function.
    if not exists (select 1 from public.suppliers s
                    where s.id = p_supplier_id and s.tenant_id = v_tenant) then
        raise exception 'supplier is not in your tenant' using errcode = '42501';
    end if;

    if not app.has_permission('VIEW_FINANCIAL_DOCUMENTS') then
        return query select null::numeric, null::text, false, null::numeric, null::boolean,
                            null::text[];
        return;
    end if;

    -- The null-ceiling cases return NULL exactly as the replaced function did. The lateral is
    -- guarded rather than filtered afterwards: with a NULL limit currency `app.exchange_rate_as_of`
    -- returns NULL for every rate, so an unguarded call would report exposure 0 and name every
    -- currency the supplier holds as "unconvertible" -- an incomplete-figure warning about a
    -- supplier that has no ceiling to be incomplete about.
    return query
    select s.credit_limit_amount,
           s.credit_limit_currency_code,
           true,
           e.exposure,
           case when s.credit_limit_amount is null then null
                else e.exposure > s.credit_limit_amount
           end,
           e.unconvertible
    from public.suppliers s
    left join lateral app.supplier_exposure_in_limit_currency(
                         v_tenant, s.id, s.credit_limit_currency_code) e
           on s.credit_limit_currency_code is not null
    where s.id = p_supplier_id and s.tenant_id = v_tenant;
end;
$$;

revoke execute on function app.supplier_credit(uuid) from public;
grant execute on function app.supplier_credit(uuid) to authenticated;

create function public.supplier_credit(p_supplier_id uuid)
returns table (
    credit_limit_amount      numeric,
    credit_limit_currency_code text,
    permitted                boolean,
    exposure_amount          numeric,
    threshold_exceeded       boolean,
    unconvertible_currencies text[]
)
language sql
stable
set search_path = ''
as $$ select * from app.supplier_credit(p_supplier_id) $$;

revoke execute on function public.supplier_credit(uuid) from public;
grant execute on function public.supplier_credit(uuid) to authenticated, service_role;

-- =================================================================================================
-- 3. SUP-4d -- the supplier ceiling never re-evaluates when the CEILING moves
--
-- MEASURED, live: `customers` carries `customers_probe_credit_ceiling`; `suppliers` carries no
-- equivalent. SUP-4b hooked only the two EXPOSURE tables, reasoning that exposure is a function of
-- exactly those two. True of exposure -- but the COMPARISON also moves when the CEILING moves, and
-- lowering a ceiling is exactly when a credit control should speak. Reproduced on the customer side
-- over HTTP before CUST-3 closed it there: an invoice was raised with no ceiling set, the ceiling
-- was then set BELOW that exposure, and nothing alerted because no write to an exposure table
-- followed. The reader said over-limit; the event ledger said nothing had happened.
--
-- The `when` clause is CUST-3's: a supplier with no ceiling cannot cross one, so ordinary supplier
-- edits cost nothing. The evaluator's own first act is the same null check, so this is an
-- optimisation rather than the guard.

create function app.probe_supplier_credit_ceiling()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
    perform app.evaluate_supplier_credit_threshold(new.tenant_id, new.id);
    return null;
end;
$$;

revoke execute on function app.probe_supplier_credit_ceiling() from public;

create trigger suppliers_probe_credit_ceiling
    after insert or update on public.suppliers
    for each row
    when (new.credit_limit_amount is not null and new.credit_limit_currency_code is not null)
    execute function app.probe_supplier_credit_ceiling();

-- =================================================================================================
-- 4. The evaluator consumes the new shape, and states the gap
--
-- Two changes only: the exposure call now returns a row rather than a scalar, and an incomplete
-- figure says so -- in the event payload (`unconvertible_currencies`) and in the human notification
-- text. Word for word the treatment `app.evaluate_customer_credit_threshold` already gives it. The
-- idempotency ledger, the two event types, the audience, the notification type, the delivery-ledger
-- row and `enforcement => 'warning_only'` are all untouched.

create or replace function app.evaluate_supplier_credit_threshold(
    p_tenant_id uuid,
    p_supplier_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_limit     numeric;
    v_currency  text;
    v_name      text;
    v_exposure  numeric;
    v_unconv    text[];
    v_last      text;
    v_notif     uuid;
    v_note      text := '';
    r           record;
begin
    if p_tenant_id is null or p_supplier_id is null then
        return;
    end if;

    -- A supplier with no ceiling has no ceiling. Checked FIRST so the common case costs one indexed
    -- row read and never an aggregate over booking_items and payments.
    select s.credit_limit_amount, s.credit_limit_currency_code, s.name
      into v_limit, v_currency, v_name
    from public.suppliers s
    where s.id = p_supplier_id and s.tenant_id = p_tenant_id;

    if v_limit is null or v_currency is null then
        return;
    end if;

    select e.exposure, e.unconvertible
      into v_exposure, v_unconv
    from app.supplier_exposure_in_limit_currency(p_tenant_id, p_supplier_id, v_currency) e;

    -- THE GAP IS STATED, NEVER SWALLOWED. If a currency carrying real exposure has no usable rate,
    -- the figure below is incomplete and says so in both the event payload and the human text.
    if v_unconv is not null and array_length(v_unconv, 1) > 0 then
        v_note := format(
            ' NOTE: exposure held in %s could not be converted (no exchange rate at or before now), '
            'so this figure is INCOMPLETE and understates the true exposure.',
            array_to_string(v_unconv, ', '));
    end if;

    -- The idempotency ledger IS the event trail (no new column, no status vocabulary). Only the most
    -- recent of the two threshold events matters: it is the supplier's current alert state.
    select e.event_type_code into v_last
    from public.events e
    where e.tenant_id = p_tenant_id
      and e.entity_type = 'supplier'
      and e.entity_id = p_supplier_id
      and e.event_type_code in ('supplier_credit_threshold_exceeded', 'supplier_credit_threshold_cleared')
    order by e.seq desc
    limit 1;

    if v_exposure > v_limit then
        -- Already announced: say nothing. This is what stops an alert per write, and per read.
        if v_last = 'supplier_credit_threshold_exceeded' then
            return;
        end if;

        perform app.record_event(
            p_tenant_id, 'supplier_credit_threshold_exceeded', 'supplier', p_supplier_id,
            null, null, null,
            'Supplier outstanding payable rose above its configured credit ceiling',
            jsonb_build_object(
                'supplier_id',   p_supplier_id,
                'supplier_name', v_name,
                'currency_code', v_currency,
                'credit_limit',  v_limit,
                'exposure',      v_exposure,
                'over_by',       v_exposure - v_limit,
                'unconvertible_currencies', to_jsonb(v_unconv),
                'enforcement',   'warning_only'
            ),
            'warning'
        );

        for r in select app.supplier_credit_alert_recipients(p_tenant_id) as user_id loop
            insert into public.notifications (
                tenant_id, target_user_id, notification_type_code, title, body,
                related_entity_type, related_entity_id
            )
            values (
                p_tenant_id, r.user_id, 'supplier_balance',
                'Supplier credit threshold exceeded',
                format(
                    'Supplier %s has an outstanding payable of %s %s against a credit ceiling of %s %s (over by %s %s). This is a warning only - no operation has been blocked.%s',
                    coalesce(v_name, '(unnamed)'),
                    to_char(v_exposure, 'FM999999999990.00'), v_currency,
                    to_char(v_limit,    'FM999999999990.00'), v_currency,
                    to_char(v_exposure - v_limit, 'FM999999999990.00'), v_currency,
                    v_note
                ),
                'supplier', p_supplier_id
            )
            returning id into v_notif;

            -- THE DELIVERY BOUNDARY, RECORDED RATHER THAN CLAIMED -- unchanged from SUP-4b. ORVION
            -- has no email provider, so the obligation is written to the existing delivery ledger as
            -- `pending` on the `email` channel. Nothing here pretends a mail was sent.
            insert into public.notification_deliveries (
                tenant_id, notification_id, channel_code, delivery_status_code
            )
            values (p_tenant_id, v_notif, 'email', 'pending');
        end loop;

    elsif v_last = 'supplier_credit_threshold_exceeded' then
        -- Back within the ceiling. Recorded so the NEXT breach is announced rather than swallowed.
        perform app.record_event(
            p_tenant_id, 'supplier_credit_threshold_cleared', 'supplier', p_supplier_id,
            null, null, null,
            'Supplier outstanding payable returned to or below its credit ceiling',
            jsonb_build_object(
                'supplier_id',   p_supplier_id,
                'currency_code', v_currency,
                'credit_limit',  v_limit,
                'exposure',      v_exposure,
                'unconvertible_currencies', to_jsonb(v_unconv)
            ),
            'info'
        );
    end if;
end;
$$;

-- =================================================================================================
-- 5. CUST-5 -- the supplier credit-only branch is correct only by accident
--
-- MEASURED, live, in `app.guard_write_capability`:
--   v_credit_only := (credit pair changed)
--                    and (to_jsonb(new) - 'credit_limit_amount' - 'credit_limit_currency_code' - 'updated_at')
--                      = (to_jsonb(old) - 'credit_limit_amount' - 'credit_limit_currency_code' - 'updated_at');
--
-- The row-image comparison is true today only because `suppliers` happens to carry no BEFORE trigger
-- that mutates `new`. Measured BEFORE set on `suppliers`: enforce_archive_authority,
-- enforce_catalog_codes, enforce_subscription_write_gate, guard_credit_authority,
-- guard_write_capability, moddatetime -- none writes a column the comparison reads, and
-- `moddatetime` sorts AFTER it. That is an accident, not a design. On `customers` the identical form
-- ALREADY FAILED: `customers_derive_first_registration_actor` sorts before the guard and sets
-- `new.first_registered_user_id`, so "nothing else changed" was false and a finance manager was
-- refused. The day anyone adds a `derive_*` trigger to `suppliers`, SUP-3's authority silently stops
-- applying, in the direction that REFUSES the right actor.
--
-- THE FIX IS TO DELETE THE ROW IMAGE AND NOTHING ELSE. The predicate becomes "this UPDATE TOUCHES
-- the credit pair" and the assignment it guards is untouched: `v_perms := array['MANAGE_SUPPLIER_
-- CREDIT']`, still a REPLACEMENT. One conjunct removed; not one character of the consequence.
--
-- THE CUSTOMER BRANCH'S OR-LIST FORM WAS TRIED FIRST AND IS WRONG HERE, and the suite is what said
-- so. Appending MANAGE_SUPPLIER_CREDIT to `v_perms` instead of replacing it makes this guard stop
-- being an ENFORCER of the credit permission and start merely offering an extra way to pass: an
-- actor holding ASSIGN_SUPPLIER and NOT MANAGE_SUPPLIER_CREDIT would satisfy it on a credit write.
-- `90_supplier_credit_write_authority_test` assertion 12 exists precisely to forbid that -- it drops
-- `suppliers_guard_credit_authority` and requires the write to be REFUSED ANYWAY, which is the
-- definition of two INDEPENDENT enforcers rather than one mechanism counted twice. The OR-list form
-- failed it. Defence in depth is not a redundancy to be optimised away, and the test caught the
-- attempt.
--
-- WHAT CHANGES IN PRODUCTION: NOTHING, and that is checkable rather than hopeful.
-- `suppliers_guard_credit_authority` fires FIRST (`guard_credit_authority` < `guard_write_capability`
-- alphabetically, both BEFORE INSERT OR UPDATE) and unconditionally
-- `perform app.authorize('MANAGE_SUPPLIER_CREDIT')` for ANY write touching either credit column. So
-- MANAGE_SUPPLIER_CREDIT is already mandatory for every credit write, and the only writes whose
-- treatment here changes are MIXED ones (ceiling AND some other column), which previously fell
-- through to ASSIGN_SUPPLIER and now demand MANAGE_SUPPLIER_CREDIT. Every actor who could perform
-- such a write already had to hold MANAGE_SUPPLIER_CREDIT to get past the first trigger. The change
-- is therefore visible ONLY when one of the two guards is artificially removed -- which is exactly
-- the mutation test, and exactly where a defence-in-depth property should be visible.
--
-- It is also a TIGHTENING rather than a widening, in the one direction it moves: an actor holding
-- ASSIGN_SUPPLIER without MANAGE_SUPPLIER_CREDIT previously satisfied THIS guard on a mixed write
-- and now does not. Measured role holders at this HEAD:
--   MANAGE_SUPPLIER_CREDIT = {ceo, finance_manager, owner}
--   ASSIGN_SUPPLIER        = {branch_manager, ceo, department_manager, finance_manager, owner, senior_employee}
--
-- NO INSERT ARM. The customer branch has one because CUST-3 needed `finance_manager` -- who does NOT
-- hold CREATE_CUSTOMER -- to create a customer carrying a ceiling. No equivalent case exists here:
-- MANAGE_SUPPLIER_CREDIT is a strict SUBSET of ASSIGN_SUPPLIER, so every role that may set a supplier
-- ceiling may already create a supplier. Adding an INSERT arm for symmetry alone would let a
-- user-granted MANAGE_SUPPLIER_CREDIT create suppliers, which is a capability nothing asked for.
-- SUP-3 was about UPDATE; this stays about UPDATE.
--
-- THE TABLE TEST STAYS ITS OWN OUTER `if` -- LIC-3 / PP-4's rule, which this guard already states
-- twice. A record field reference resolves against the ACTUAL record type at execution, so naming
-- `new.credit_limit_amount` in the same boolean expression as `tg_table_name = 'suppliers'` makes it
-- resolve for `tasks`, `leads` and every other table this trigger serves.

create or replace function app.guard_write_capability()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_perms  text[];
    v_extra  text[];
    v_perm   text;
    v_held   text;
    v_strict boolean := false;
    v_relationship_ok boolean := false;
begin
    -- Platform/system paths (canon 35 principle 6), as in every other guard here.
    if (select auth.uid()) is null then
        return new;
    end if;

    -- 202607058500 (LIC-3 / PP-4): `documents` is resolved in its OWN statement, not inside the
    -- shared CASE below. A record field reference is resolved against the ACTUAL record type at
    -- execution, so naming `new.document_type_code` inside an expression this trigger also evaluates
    -- for `customers`, `leads` and twenty other tables fails on every one of them.
    if tg_table_name = 'documents' then
        if new.document_type_code = 'payment_proof' then
            v_perms := array['MANAGE_TENANT_SETTINGS'];
            v_strict := true;
        else
            v_perms := array['UPLOAD_DOCUMENT'];
        end if;
    else
    v_perms := case tg_table_name
                   when 'approval_requests'         then array['CREATE_BOOKING_ITEM']
                   when 'conversation_messages'     then array['SEND_MESSAGE']
                   when 'customer_contact_methods'  then array['CREATE_CUSTOMER']
                   when 'customer_identity_signals' then array['CREATE_CUSTOMER']
                   when 'customer_identity_merges'  then array['MERGE_CUSTOMER_IDENTITY']
                   when 'internal_supplier_links'   then array['ASSIGN_SUPPLIER']
                   when 'offline_conversions'       then array['MANAGE_MARKETING_CAMPAIGN']
                   when 'document_links'            then array['UPLOAD_DOCUMENT','MANAGE_TENANT_SETTINGS']
                   when 'lead_assignments'          then array['ASSIGN_LEAD','REASSIGN_LEAD']
                   when 'branch_business_hours'     then array['MANAGE_BRANCHES']
                   when 'holidays'                  then array['MANAGE_BRANCHES','MANAGE_TENANT_SETTINGS']
                   when 'financial_accounts'        then array['CREATE_JOURNAL_ENTRY']
                   when 'company_assets'            then array['CREATE_JOURNAL_ENTRY']
                   when 'bookings'                  then array['CREATE_BOOKING']
                   when 'complaints'                then array['CREATE_COMPLAINT']
                   when 'conversations'             then array['SEND_MESSAGE']
                   when 'customer_notes'            then array['CREATE_CUSTOMER']
                   when 'customers'                 then array['CREATE_CUSTOMER']
                   when 'leads'                     then array['CREATE_LEAD']
                   when 'passengers'                then array['CREATE_BOOKING_ITEM']
                   when 'quotations'                then array['CREATE_QUOTATION']
                   when 'service_requests'          then array['CREATE_SERVICE_REQUEST']
                   when 'suppliers'                 then array['ASSIGN_SUPPLIER']
                   when 'tasks'                     then array['CREATE_TASK']
               end;
    end if;

    -- 202607059100 (SEC-1c): on UPDATE the object-class permission is joined by the permissions canon
    -- already says may MUTATE this object.
    if tg_op = 'UPDATE' and not v_strict then
        v_extra := case tg_table_name
                       when 'approval_requests'  then array['APPROVE_FINANCE','REVIEW_APPROVAL_REQUEST','REVIEW_SUBSCRIPTION_PAYMENT']
                       when 'bookings'           then array['APPROVE_BOOKING','CANCEL_BOOKING','ISSUE_BOOKING','REFUND_BOOKING','REISSUE_BOOKING']
                       when 'complaints'         then array['RESOLVE_COMPLAINT']
                       when 'conversations'      then array['CLOSE_CONVERSATION','ESCALATE_CONVERSATION']
                       when 'customers'          then array['MERGE_CUSTOMER_IDENTITY']
                       when 'documents'          then array['ARCHIVE_DOCUMENT','CREATE_DOCUMENT_VERSION']
                       when 'leads'              then array['ASSIGN_LEAD','CLOSE_LEAD','REASSIGN_LEAD']
                       when 'quotations'         then array['ACCEPT_QUOTATION','SEND_QUOTATION']
                       when 'service_requests'   then array['RESOLVE_SERVICE_REQUEST']
                       when 'tasks'              then array['ASSIGN_TASK','COMPLETE_TASK']
                       else null
                   end;
        if v_extra is not null then
            v_perms := v_perms || v_extra;
        end if;
    end if;

    -- CUST-3 (2026-09-04): the customer ceiling. REQUIRED, not cosmetic -- `finance_manager` does NOT
    -- hold CREATE_CUSTOMER (measured: only owner, ceo, branch_manager, department_manager,
    -- senior_employee and employee do), so without this a finance manager could not set a ceiling at
    -- all. That is SUP-3's defect one table over.
    --
    -- THIS BRANCH APPENDS; THE SUPPLIER BRANCH BELOW REPLACES, AND THE DIFFERENCE IS DELIBERATE.
    -- MANAGE_CUSTOMER_CREDIT is NOT a subset of CREATE_CUSTOMER (`finance_manager` holds the first
    -- and not the second), so replacing here would refuse an employee legitimately creating a
    -- customer that happens to carry a ceiling. On `suppliers` the containment runs the other way and
    -- replacing costs nothing -- see CUST-5's block in `202607060600`. The CONSEQUENCE of appending
    -- is that this guard is not a second enforcer of MANAGE_CUSTOMER_CREDIT the way the supplier
    -- branch is; `customers_guard_credit_authority` is the sole enforcer on this table. Recorded as
    -- CUST-6 rather than changed inside a supplier migration.
    if tg_table_name = 'customers' then
        if (tg_op = 'UPDATE'
            and (new.credit_limit_amount is distinct from old.credit_limit_amount
                 or new.credit_limit_currency_code is distinct from old.credit_limit_currency_code))
           or (tg_op = 'INSERT'
               and (new.credit_limit_amount is not null or new.credit_limit_currency_code is not null))
        then
            -- `array[...]`, not a bare literal: `text[] || 'x'` makes PostgreSQL parse the untyped
            -- literal AS an array and fail with 22P02, which is what the suite caught first.
            v_perms := v_perms || array['MANAGE_CUSTOMER_CREDIT'];
        end if;
    end if;

    -- CUST-5 (202607060600): SUP-3's authority, widened by SUP-4a to the PAIR (amount, currency),
    -- expressed WITHOUT a row image. The ONLY change from the replaced form is that the
    -- "and nothing else changed" conjunct is GONE; the assignment it guards is untouched.
    if tg_op = 'UPDATE' and tg_table_name = 'suppliers' then
        if new.credit_limit_amount is distinct from old.credit_limit_amount
           or new.credit_limit_currency_code is distinct from old.credit_limit_currency_code
        then
            v_perms := array['MANAGE_SUPPLIER_CREDIT'];
        end if;
    end if;

    -- The handler rule, evaluated ONLY inside its own table branch so `new.assigned_user_id` is
    -- never named while this trigger is serving `suppliers` or `customers`.
    if tg_op = 'UPDATE' and tg_table_name = 'leads' then
        v_relationship_ok := (select app.current_user_id()) is not null
                             and (select app.current_user_id()) in (new.assigned_user_id, new.owner_user_id);
    end if;

    if v_relationship_ok then
        return new;
    end if;

    if v_perms is null then
        raise exception 'guard_write_capability has no permission mapping for %', tg_table_name
            using errcode = 'insufficient_privilege';
    end if;

    foreach v_perm in array v_perms loop
        if app.has_permission(v_perm) then
            v_held := v_perm;
            exit;
        end if;
    end loop;

    if v_held is null then
        raise exception 'permission denied: one of % is required to write %',
                        array_to_string(v_perms, ' or '), tg_table_name
            using errcode = 'insufficient_privilege';
    end if;

    perform app.authorize(v_held);
    return new;
end;
$$;

revoke execute on function app.guard_write_capability() from public;

comment on constraint suppliers_credit_limit_non_negative_check on public.suppliers is
    'CUST-4: a negative ceiling can never be cleared -- exposure > limit fires on the first unit of exposure. Mirrors customers_credit_limit_non_negative_check.';
