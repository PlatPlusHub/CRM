-- SUP-4b -- the credit ceiling gets its behaviour, and the behaviour is WARN.
--
-- =================================================================================================
-- THE OWNER DECISION, QUOTED RATHER THAN INFERRED (2026-09-04)
--
--   "Finance Manager CAN override the supplier credit ceiling."
--   "EXCEEDING the limit MUST NOT block operations."
--   "No new entry/addition/action should be prevented merely because the ceiling has been exceeded."
--   "When exposure exceeds the threshold: send an email notification to the Company Owner; send an
--    email notification to the Finance Manager."
--   "The intended behavior is WARNING/ALERT, NOT REFUSAL/BLOCKING."
--
-- SUP-4b asked three questions: does the ceiling REFUSE or WARN, at which operation, and with what
-- override. All three are now answered: WARN; at the moment exposure crosses; and there is nothing
-- to override because nothing is refused. `CREDIT LIMIT ENFORCED = NO` is therefore no longer the
-- state -- but note precisely what replaced it: the ceiling is OBSERVED, not ENFORCED. Not one
-- write path gains a new refusal in this migration, and that is the requirement, not a shortcut.
--
-- =================================================================================================
-- WHAT THIS DELIBERATELY DOES NOT DO
--
-- NO FX. `public.exchange_rates` exists as a table and **no function in the database reads it** --
-- measured, not assumed. The owner's "100,000 EGP or equivalent" is therefore implemented exactly as
-- far as the existing finance model reaches: the ceiling is compared against exposure IN THE
-- CURRENCY THE CEILING IS DENOMINATED IN, which is ADR-0020/ADR-0021's shipped per-currency rule and
-- SUP-4b's already-recorded DERIVED semantics. A ceiling in EGP is measured against EGP exposure; a
-- ceiling in USD against USD exposure. What is NOT implemented is collapsing multi-currency exposure
-- into one comparable number -- that needs a base currency and a rate source, which is a business
-- decision with no canonical home. It is isolated as **SUP-4c**, not guessed at here.
--
-- NO NEW CONFIGURATION LAYER. `suppliers.credit_limit_amount` + `credit_limit_currency_code` IS the
-- threshold, per supplier, already write-gated by MANAGE_SUPPLIER_CREDIT (SUP-3). "100,000 EGP" is a
-- VALUE the owner configures through that existing path, not a constant belonging in code. No global
-- default column is invented; a NULL ceiling still means no ceiling, and such a supplier is skipped
-- before any aggregate is computed.
--
-- NO NEW NOTIFICATION TYPE. `notification_type = 'supplier_balance'` has existed in the catalog
-- since the original seed with **no producer anywhere** -- EVT-2's class exactly. This migration is
-- its first producer. Minting a second type for the same concept would be the duplicate-authority
-- mistake this repository keeps finding.
--
-- NO NEW STATUS SYSTEM. The owner asked for a simple warning and explicitly not a colour/status
-- model. Idempotency therefore uses the EVENT LEDGER that already exists rather than a new column:
-- an alert fires only when the most recent threshold event for the supplier is not already
-- `exceeded`. That is why the `cleared` event exists -- without it the first breach would silence
-- the supplier permanently, and a later breach after a payment would never be announced.
--
-- NO CUSTOMER RULE. The owner's wording mentioned "dues at a customer or supplier". `public.
-- customers` carries **zero** credit columns (measured) -- a customer threshold would be a NEW
-- business rule with no schema, no canon and no ceiling to compare against. Isolated as **CUST-3**.
-- =================================================================================================

-- 1. THE VOCABULARY. `app.record_event` refuses an unregistered code and says so: "register it in
--    27_event_catalog.md + the event_type catalog first". Canon 27 is the SSOT and was updated in
--    this same commit; this seeds what canon now defines.
--    Guarded by NOT EXISTS rather than ON CONFLICT on purpose: `catalog_values`' uniqueness is
--    carried by two PARTIAL indexes (`... where tenant_id is null` for system rows and a
--    tenant-qualified one for tenant rows), so a bare `on conflict (catalog_type_code, code)` matches
--    no arbiter and fails 42P10. The original 2026-07 seed predates that split, which is why copying
--    its idiom would have been wrong here.
insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_system, is_active)
select v.type_code, v.code, v.label, v.ord, true, true
from (values
        ('event_type', 'supplier_credit_threshold_exceeded', 'Supplier Credit Threshold Exceeded', 900),
        ('event_type', 'supplier_credit_threshold_cleared',  'Supplier Credit Threshold Cleared',  901)
     ) as v(type_code, code, label, ord)
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = v.type_code
      and cv.code = v.code
      and cv.tenant_id is null
);

-- =================================================================================================
-- 2. EXPOSURE, ON THE SYSTEM PATH.
--
--    `app.supplier_balance` is the authoritative exposure definition and MUST NOT be duplicated --
--    but it gates on VIEW_FINANCIAL_DOCUMENTS, and this runs inside a trigger fired by whoever
--    happened to write the row. A salesperson locking a cost does not hold that permission, so
--    calling the gated reader here would raise and BLOCK the write -- the exact outcome the owner
--    forbade. Canon 35 principle 6 and AGENTS.md 5b both say the same thing: the system path
--    decides eligibility itself and never retreats the gate to make batch work convenient.
--
--    So this function repeats the EXPRESSION and not the AUTHORIZATION: same locked-cost rule, same
--    cancelled/no_show and archived exclusions, same supplier_payment subtraction. It is deliberately
--    NOT granted to authenticated -- it is an internal system helper, not a second read door, and a
--    second read door is how SUP-1's confidentiality would leak back open.
-- =================================================================================================
create or replace function app.supplier_exposure_in_limit_currency(
    p_tenant_id uuid,
    p_supplier_id uuid,
    p_currency_code text
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
    select coalesce(sum(c.cost) - sum(c.paid), 0)
    from (
        select bi.cost_amount as cost, 0::numeric as paid
        from public.booking_items bi
        where bi.tenant_id = p_tenant_id
          and bi.supplier_id = p_supplier_id
          and bi.currency_code = p_currency_code
          and bi.cost_locked_at is not null
          and bi.is_archived = false
          and bi.base_status_code not in ('cancelled', 'no_show')
          and bi.cost_amount is not null
        union all
        select 0::numeric, p.amount
        from public.payments p
        where p.tenant_id = p_tenant_id
          and p.supplier_id = p_supplier_id
          and p.currency_code = p_currency_code
          and p.payment_direction_code = 'supplier_payment'
    ) c;
$$;

revoke all on function app.supplier_exposure_in_limit_currency(uuid, uuid, text) from public;

comment on function app.supplier_exposure_in_limit_currency(uuid, uuid, text) is
'SUP-4b system path. Repeats app.supplier_balance''s EXPRESSION for one currency without its '
'VIEW_FINANCIAL_DOCUMENTS gate, because it runs in a trigger under whoever wrote the row. '
'Deliberately not granted to authenticated: it is not a second read door.';

-- =================================================================================================
-- 3. THE RECIPIENTS. The owner named two roles: Company Owner and Finance Manager. Modelled on
--    `app.lead_responsible_managers`, which is this repository's precedent for resolving an
--    escalation audience with no session. Role membership -- not permission holding -- is the right
--    expression here: this is who gets TOLD, not who is ALLOWED. Authorization is unchanged by this
--    migration and is not routed through this function.
-- =================================================================================================
create or replace function app.supplier_credit_alert_recipients(p_tenant_id uuid)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
    select distinct ura.user_id
    from public.user_role_assignments ura
    join public.roles r on r.id = ura.role_id
    join public.users u on u.id = ura.user_id and u.tenant_id = ura.tenant_id
    where ura.tenant_id = p_tenant_id
      and ura.is_active
      and r.is_active
      and u.is_active
      and r.code in ('owner', 'finance_manager')
      and ura.starts_at <= now()
      and (ura.ends_at is null or ura.ends_at > now());
$$;

revoke all on function app.supplier_credit_alert_recipients(uuid) from public;

-- =================================================================================================
-- 4. THE EVALUATION. Warning only: this function inserts rows and raises nothing.
-- =================================================================================================
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
    v_last      text;
    v_notif     uuid;
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

    v_exposure := app.supplier_exposure_in_limit_currency(p_tenant_id, p_supplier_id, v_currency);

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
                    'Supplier %s has an outstanding payable of %s %s against a credit ceiling of %s %s (over by %s %s). This is a warning only - no operation has been blocked.',
                    coalesce(v_name, '(unnamed)'),
                    to_char(v_exposure, 'FM999999999990.00'), v_currency,
                    to_char(v_limit,    'FM999999999990.00'), v_currency,
                    to_char(v_exposure - v_limit, 'FM999999999990.00'), v_currency
                ),
                'supplier', p_supplier_id
            )
            returning id into v_notif;

            -- THE DELIVERY BOUNDARY, RECORDED RATHER THAN CLAIMED. The owner asked for email.
            -- Canon 10 lists in-system as the MVP channel and "Email business alerts" as a FUTURE
            -- one, and this repository has NO email provider -- measured: no SMTP, SendGrid, Resend,
            -- Postmark, Mailgun or SES reference exists anywhere in migrations or scripts. So the
            -- obligation is written to the existing delivery ledger as `pending` on the `email`
            -- channel, which makes it auditable and queryable by whatever eventually dispatches it.
            -- `pending` is the truth: nothing in ORVION sends mail today, and this migration does
            -- not pretend otherwise.
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
                'exposure',      v_exposure
            ),
            'info'
        );
    end if;
end;
$$;

revoke all on function app.evaluate_supplier_credit_threshold(uuid, uuid) from public;

-- =================================================================================================
-- 5. THE HOOKS. Exposure is a function of exactly two tables -- `app.supplier_balance` says so --
--    so those are the only two that can move it. AFTER, so the write has already happened and
--    cannot be affected by anything here; FOR EACH ROW, because a supplier changes per row.
--    Both OLD and NEW suppliers are evaluated: moving an item from supplier A to supplier B lowers
--    A's exposure and raises B's, and only checking NEW would leave A permanently "exceeded".
-- =================================================================================================
create or replace function app.probe_supplier_credit_threshold()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_new uuid := null;
    v_old uuid := null;
    v_ten uuid := null;
begin
    if tg_op in ('INSERT', 'UPDATE') then
        v_new := new.supplier_id;
        v_ten := new.tenant_id;
    end if;
    if tg_op in ('UPDATE', 'DELETE') then
        v_old := old.supplier_id;
        v_ten := coalesce(v_ten, old.tenant_id);
    end if;

    if v_new is not null then
        perform app.evaluate_supplier_credit_threshold(v_ten, v_new);
    end if;
    if v_old is not null and v_old is distinct from v_new then
        perform app.evaluate_supplier_credit_threshold(v_ten, v_old);
    end if;

    return null;  -- AFTER trigger: the return value is ignored and the write is untouchable.
end;
$$;

revoke all on function app.probe_supplier_credit_threshold() from public;

drop trigger if exists booking_items_probe_supplier_credit on public.booking_items;
create trigger booking_items_probe_supplier_credit
    after insert or update or delete on public.booking_items
    for each row execute function app.probe_supplier_credit_threshold();

drop trigger if exists payments_probe_supplier_credit on public.payments;
create trigger payments_probe_supplier_credit
    after insert or update or delete on public.payments
    for each row execute function app.probe_supplier_credit_threshold();

-- =================================================================================================
-- 6. THE UI CONTRACT -- "a simple visual red warning is desirable if feasible".
--
--    There is no ORVION frontend, and none is fabricated here. What exists is `supplier_credit`,
--    already the gated reader for the ceiling and already reachable over HTTP through its `public`
--    wrapper. Extending it is the smallest honest answer: the client that already asks "what is this
--    supplier's ceiling?" now also learns "and is it exceeded?" in the same call, and can render that
--    one boolean red. ONE boolean -- not a colour vocabulary, not a status catalog.
--
--    The VIEW_FINANCIAL_DOCUMENTS gate is unchanged, including its empty-set-is-authorization
--    behaviour: an actor who may not read the ceiling learns nothing new about the exposure either.
--    Return type changes require DROP; the public wrapper is recreated identically.
-- =================================================================================================
drop function if exists public.supplier_credit(uuid);
drop function if exists app.supplier_credit(uuid);

create or replace function app.supplier_credit(p_supplier_id uuid)
returns table (
    credit_limit_amount        numeric,
    credit_limit_currency_code text,
    permitted                  boolean,
    exposure_amount            numeric,
    threshold_exceeded         boolean
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
        return query select null::numeric, null::text, false, null::numeric, null::boolean;
        return;
    end if;

    return query
    select s.credit_limit_amount,
           s.credit_limit_currency_code,
           true,
           case when s.credit_limit_currency_code is null then null
                else app.supplier_exposure_in_limit_currency(v_tenant, s.id, s.credit_limit_currency_code)
           end,
           case when s.credit_limit_amount is null or s.credit_limit_currency_code is null then null
                else app.supplier_exposure_in_limit_currency(v_tenant, s.id, s.credit_limit_currency_code)
                     > s.credit_limit_amount
           end
    from public.suppliers s
    where s.id = p_supplier_id and s.tenant_id = v_tenant;
end;
$$;

revoke all on function app.supplier_credit(uuid) from public;
grant execute on function app.supplier_credit(uuid) to authenticated;

create or replace function public.supplier_credit(p_supplier_id uuid)
returns table (
    credit_limit_amount        numeric,
    credit_limit_currency_code text,
    permitted                  boolean,
    exposure_amount            numeric,
    threshold_exceeded         boolean
)
language sql
stable
set search_path = ''
as $$ select * from app.supplier_credit(p_supplier_id) $$;

revoke all on function public.supplier_credit(uuid) from public;
grant execute on function public.supplier_credit(uuid) to authenticated;

comment on function public.supplier_credit(uuid) is
'SUP-1/SUP-4b. The supplier credit ceiling and, since 2026-09-04, the exposure measured against it '
'and whether it is exceeded. threshold_exceeded is a WARNING flag: nothing is refused on it. '
'Gated on VIEW_FINANCIAL_DOCUMENTS; an actor without it receives permitted=false and nulls.';
