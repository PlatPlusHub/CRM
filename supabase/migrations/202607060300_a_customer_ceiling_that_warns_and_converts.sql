-- CUST-3 -- the customer receivable ceiling, and the first reader ORVION's rate table ever had.
--
-- =================================================================================================
-- THE OWNER DECISION, QUOTED RATHER THAN INFERRED (2026-09-04)
--
--   "CUST-3 = YES. ORVION WILL offer a customer receivable credit-ceiling capability."
--   "Mirror the already-shipped supplier credit-ceiling pattern where structurally appropriate."
--   "The customer ceiling is nullable and tenant-supplied."
--   "Do NOT invent a numeric default."  "Do NOT make the ceiling blocking by default."
--   "Warning-only enforcement is approved."  "Do not invent collection/dunning behavior."
--   "Preserve currency correctness and existing tenant isolation."
--   "If customer balance is currently per-currency, implement conversion/comparison correctly
--    rather than silently dropping foreign-currency exposure."
--
-- The supplier ceiling (SUP-4b, `202607060100`) is the template. It is followed everywhere it is
-- structurally right, and deliberately NOT followed in one place -- see FX below.
--
-- =================================================================================================
-- WHAT THIS DELIBERATELY DOES NOT DO
--
-- NO DEFAULT CEILING. `customers.credit_limit_amount` is nullable and a NULL ceiling means NO
-- ceiling; such a customer is skipped before any aggregate is computed. No number is invented, and
-- none was asked of the owner: SUP-4b never asked either -- the tenant supplies the value through
-- the existing write path.
--
-- NO BLOCKING. Not one write path gains a refusal. The evaluator inserts rows and raises nothing,
-- and its hooks are AFTER triggers returning null, so the write is already committed and cannot be
-- affected. `enforcement => 'warning_only'` is stated in the event payload, as SUP-4b states it.
--
-- NO DUNNING, NO COLLECTIONS. No schedule, no escalation ladder, no ageing buckets, no letters, no
-- status model. One event when exposure crosses the ceiling, one when it returns below, and an
-- in-system notification to the same finance audience SUP-4b already notifies. That is the whole
-- behaviour.
--
-- NO NEW NOTIFICATION TYPE. `notification_type = 'customer_balance'` has existed in the catalog
-- since the original seed with NO PRODUCER anywhere -- EVT-2's class, exactly as `supplier_balance`
-- was before SUP-4b. This migration is its first producer. Minting a second type for the same
-- concept would be the duplicate-authority mistake this repository keeps finding.
--
-- NO SECOND EXPOSURE DEFINITION. `app.customer_balance` remains the authoritative reader, and its
-- expression is repeated here rather than its AUTHORIZATION: it gates on VIEW_FINANCIAL_DOCUMENTS
-- and raises when there is no session, so calling it from a trigger fired by whoever wrote the row
-- would BLOCK that write -- the outcome the owner forbade. Canon 35 principle 6 and `AGENTS.md §5b`
-- say the same thing: the system path decides eligibility itself and never retreats the gate to
-- make batch work convenient. Same invoice states, same voided/archived exclusions, same payment
-- subtraction, same completed-refund addition.
--
-- =================================================================================================
-- WHERE THIS DEPARTS FROM THE SUPPLIER TEMPLATE, AND WHY THE OWNER REQUIRED IT
--
-- SUP-4b compares a ceiling against exposure IN THE CEILING'S OWN CURRENCY and, in doing so,
-- SILENTLY DROPS exposure held in any other currency (`and bi.currency_code = p_currency_code`).
-- A supplier owed EGP 8,000 and USD 600 against an EGP ceiling is measured on the EGP alone. That
-- gap is SUP-4c, and the owner's CUST-3 instruction forbids repeating it here.
--
-- SUP-4c was resolved as ENGINEERING on 2026-09-04 with the rule stated: credit exposure measured
-- against a limit is converted INTO THE LIMIT'S CURRENCY AT THE CURRENT SPOT RATE -- `12 CFR 32.9`
-- determines current credit exposure by mark-to-market, and counterparty credit-limit systems
-- convert each currency exposure into the credit-limit base currency at the spot rate. Canon 14's
-- LOCKED rate is the ACCOUNTING instant (corrections go through an Exchange Rate Adjustment) and
-- belongs to DC-11; a control and a transaction are different computations, which is why canon's
-- silence here was a separation and not a gap.
--
-- So this migration implements that rule, and `app.exchange_rate_as_of` is written as a GENERIC
-- primitive rather than a customer-specific one precisely so SUP-4c can bring suppliers onto the
-- same authority without a second definition appearing.
--
-- `public.exchange_rates` is fully governed already and has had ZERO readers and ZERO writers since
-- it was created: `SET_EXCHANGE_RATE`-gated INSERT/UPDATE/DELETE policies (held by owner, ceo and
-- finance_manager -- exactly canon 14's Exchange Rate Authority), an `exchange_rates_derive_setter`
-- trigger so `set_by` can never be caller-supplied, the subscription write gate, and DUP-1's
-- `exchange_rates_unique_pair_instant_idx` making "latest rate at or before X" deterministic. This
-- is its first reader. No FX provider, no new rate table, no base-currency architecture and no
-- conversion policy is invented -- every piece already existed and was simply never wired.
--
-- THE FAIL-SAFE IS THE POINT, AND IT IS STATED RATHER THAN SILENT. If a currency carrying real
-- exposure has no usable rate, that exposure is NOT dropped and NOT guessed: the evaluator reports
-- the un-convertible currencies in the event payload and the notification text, and still compares
-- what it could convert. Losing exposure quietly is the defect being fixed; announcing "this figure
-- is incomplete, and here is exactly what is missing" is the fix.
-- =================================================================================================

-- 1. THE PERMISSION. `insert ... on conflict (key) do nothing` with `is_system = true`, the
--    established mechanism (VIEW_DEPARTMENT_RECORDS in `202607051400`, MANAGE_SUPPLIER_CREDIT in
--    `202607059700`). `MANAGE_<noun>` matches the existing family. No second framework.
--
--    THE FEATURE CODE IS DERIVED, NOT PICKED: `required_feature_code` is a PLAN entitlement, and
--    VIEW_FINANCIAL_DOCUMENTS -- the permission governing KNOWING this same figure -- is
--    `finance_lite`, so the write is entitled at the same tier. Putting it on `crm` (where
--    CREATE_CUSTOMER sits) would let a plan grant the write without entitling the read.
insert into public.permissions (key, name, description, required_feature_code, is_system, is_active)
values ('MANAGE_CUSTOMER_CREDIT',
        'Manage customer credit',
        'Set or change a customer''s receivable credit ceiling '
        '(customers.credit_limit_amount / credit_limit_currency_code). Independent of '
        'CREATE_CUSTOMER, which governs customer records themselves, and of '
        'VIEW_FINANCIAL_DOCUMENTS, which governs reading the figure. Owner decision CUST-3, '
        '2026-09-04.',
        'finance_lite', true, true)
on conflict (key) do nothing;

-- 2. THE ROLE GRANTS. The same three that hold MANAGE_SUPPLIER_CREDIT. Measured, not assumed:
--    `finance_manager` does NOT hold CREATE_CUSTOMER (only owner and ceo do), which is why step 6
--    below is REQUIRED rather than cosmetic -- without it a finance manager could not set a ceiling
--    at all. That is SUP-3's defect one table over, and it is closed here in the same change.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where p.key = 'MANAGE_CUSTOMER_CREDIT'
  and r.code in ('owner', 'ceo', 'finance_manager')
on conflict do nothing;

-- 3. THE CEILING ITSELF. Canon 30's money standard and SUP-4a's lesson: an amount is stored beside
--    its currency, and the pair is both-or-neither. `numeric(19,4)` matches `suppliers.credit_limit_
--    amount` and DC-1/R7's money standard -- `numeric(14,2)` was written first and `03_money_currency_
--    precision_test` refused it, because two decimal places truncate a 3-dp currency. The non-negative CHECK is added here because a
--    negative ceiling is meaningless; `suppliers` has no equivalent, which is recorded as CUST-4
--    rather than silently fixed in a migration about customers.
alter table public.customers
    add column if not exists credit_limit_amount numeric(19,4),
    add column if not exists credit_limit_currency_code text;

do $DO$
begin
    if not exists (select 1 from pg_constraint where conname = 'customers_credit_limit_currency_code_fkey') then
        alter table public.customers
            add constraint customers_credit_limit_currency_code_fkey
            foreign key (credit_limit_currency_code) references public.currencies(code) on delete restrict;
    end if;
    if not exists (select 1 from pg_constraint where conname = 'customers_credit_limit_currency_check') then
        alter table public.customers
            add constraint customers_credit_limit_currency_check
            check ((credit_limit_amount is null) = (credit_limit_currency_code is null));
    end if;
    if not exists (select 1 from pg_constraint where conname = 'customers_credit_limit_non_negative_check') then
        alter table public.customers
            add constraint customers_credit_limit_non_negative_check
            check (credit_limit_amount is null or credit_limit_amount >= 0);
    end if;
end
$DO$;

comment on column public.customers.credit_limit_amount is
'CUST-3 (owner decision 2026-09-04): the customer''s receivable ceiling. NULL means NO ceiling and '
'the customer is skipped entirely. Tenant-supplied; ORVION invents no default. WARNING-ONLY -- '
'exceeding it never blocks a write.';

comment on column public.customers.credit_limit_currency_code is
'CUST-3: the currency the ceiling is denominated in. Required exactly when credit_limit_amount is '
'present (canon 30''s money standard, SUP-4a''s lesson). Exposure in other currencies is CONVERTED '
'into this one at the spot rate, never silently dropped.';

-- 4. THE VOCABULARY. `app.record_event` refuses an unregistered code. Canon 27 is the SSOT and is
--    updated in this same commit; this seeds what canon now defines. Guarded by NOT EXISTS rather
--    than ON CONFLICT because `catalog_values`' uniqueness is carried by two PARTIAL indexes, so a
--    bare `on conflict (catalog_type_code, code)` matches no arbiter and fails 42P10 (SUP-4b's note).
insert into public.catalog_values (catalog_type_code, code, label, sort_order, is_system, is_active)
select v.type_code, v.code, v.label, v.ord, true, true
from (values
        ('event_type', 'customer_credit_threshold_exceeded', 'Customer Credit Threshold Exceeded', 902),
        ('event_type', 'customer_credit_threshold_cleared',  'Customer Credit Threshold Cleared',  903)
     ) as v(type_code, code, label, ord)
where not exists (
    select 1 from public.catalog_values cv
    where cv.catalog_type_code = v.type_code
      and cv.code = v.code
      and cv.tenant_id is null
);

-- =================================================================================================
-- 5. THE RATE PRIMITIVE -- generic on purpose, so SUP-4c does not have to mint a second one.
--
--    "Latest rate at or before the instant" is deterministic because DUP-1 made
--    (tenant, from, to, effective_at) unique. A reverse pair is accepted as its inverse: the table
--    carries a single `rate` column with no bid/ask spread, so the model already assumes symmetry --
--    inverting is consistent with it rather than an assumption added here. Returns NULL when no
--    usable rate exists, and NULL is honoured by every caller rather than coerced to a number.
-- =================================================================================================
create or replace function app.exchange_rate_as_of(
    p_tenant_id uuid,
    p_from      text,
    p_to        text,
    p_as_of     timestamptz default now()
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $FN$
    select case
             when p_from is null or p_to is null then null
             when p_from = p_to then 1::numeric
             else coalesce(
                 (select er.rate
                    from public.exchange_rates er
                   where er.tenant_id = p_tenant_id
                     and er.from_currency_code = p_from
                     and er.to_currency_code   = p_to
                     and er.effective_at <= p_as_of
                   order by er.effective_at desc
                   limit 1),
                 (select 1::numeric / er.rate
                    from public.exchange_rates er
                   where er.tenant_id = p_tenant_id
                     and er.from_currency_code = p_to
                     and er.to_currency_code   = p_from
                     and er.effective_at <= p_as_of
                     and er.rate <> 0
                   order by er.effective_at desc
                   limit 1)
             )
           end
$FN$;

revoke all on function app.exchange_rate_as_of(uuid, text, text, timestamptz) from public;

comment on function app.exchange_rate_as_of(uuid, text, text, timestamptz) is
'SUP-4c''s decided rule, as a reusable primitive: the tenant''s latest manual rate at or before an '
'instant, direct or as the inverse of the reverse pair. Returns NULL when no rate exists -- callers '
'must REPORT that, never coerce it. First reader of public.exchange_rates. Not granted to '
'authenticated: it is an internal control helper, not a second read door.';

-- =================================================================================================
-- 6. CUSTOMER EXPOSURE, ON THE SYSTEM PATH, CONVERTED INTO THE CEILING'S CURRENCY.
--
--    Returns BOTH the converted figure and the currencies it could not convert, because reporting
--    the gap is the requirement. `app.customer_balance` stays the authoritative reader; this repeats
--    its EXPRESSION and not its AUTHORIZATION, for the reason stated in the header.
-- =================================================================================================
create or replace function app.customer_exposure_in_limit_currency(
    p_tenant_id     uuid,
    p_customer_id   uuid,
    p_currency_code text
)
returns table (exposure numeric, unconvertible text[])
language sql
stable
security definer
set search_path = ''
as $FN$
    with per_currency as (
        select c.currency_code, sum(c.inv) - sum(c.pay) + sum(c.ref) as outstanding
        from (
            select i.currency_code, i.total_amount as inv, 0::numeric as pay, 0::numeric as ref
            from public.invoices i
            where i.tenant_id = p_tenant_id
              and i.customer_id = p_customer_id
              and i.status_code in ('issued', 'partially_paid', 'paid', 'overdue')
              and i.voided_at is null
              and i.is_archived = false
            union all
            select p.currency_code, 0::numeric, p.amount, 0::numeric
            from public.payments p
            where p.tenant_id = p_tenant_id
              and p.customer_id = p_customer_id
              and p.payment_direction_code = 'customer_payment'
            union all
            select r.currency_code, 0::numeric, 0::numeric, r.amount
            from public.refunds r
            where r.tenant_id = p_tenant_id
              and r.customer_id = p_customer_id
              and r.payment_direction_code = 'customer_refund'
              and r.refund_status_code = 'completed'
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
$FN$;

revoke all on function app.customer_exposure_in_limit_currency(uuid, uuid, text) from public;

comment on function app.customer_exposure_in_limit_currency(uuid, uuid, text) is
'CUST-3: outstanding customer receivable converted INTO the ceiling''s currency at the spot rate '
'(SUP-4c''s decided rule). Repeats app.customer_balance''s EXPRESSION, never its VIEW_FINANCIAL_'
'DOCUMENTS gate, because it runs in a trigger under whoever wrote the row. Returns the currencies '
'it could NOT convert alongside the figure -- exposure is never silently dropped. Deliberately not '
'granted to authenticated: it is not a second read door.';

-- =================================================================================================
-- 7. THE AUDIENCE, STATED ONCE. The owner named Company Owner and Finance Manager for the supplier
--    alert; the customer alert goes to the same finance audience. Rather than copy the query, the
--    definition moves to a shared helper and `app.supplier_credit_alert_recipients` becomes a thin
--    wrapper -- its signature, its callers and `93_supplier_credit_threshold_test.sql` are all
--    unchanged, and there is exactly one place that answers "who hears about credit".
--    Role membership -- not permission holding -- remains the right expression: this is who gets
--    TOLD, not who is ALLOWED. Authorization is untouched by this migration.
-- =================================================================================================
create or replace function app.credit_alert_recipients(p_tenant_id uuid)
returns table (user_id uuid)
language sql
stable
security definer
set search_path = ''
as $FN$
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
$FN$;

revoke all on function app.credit_alert_recipients(uuid) from public;

comment on function app.credit_alert_recipients(uuid) is
'The finance alert audience -- owner + finance_manager, active assignments only. One authority for '
'both the supplier (SUP-4b) and customer (CUST-3) ceilings. Modelled on app.lead_responsible_'
'managers, this repository''s precedent for resolving an escalation audience with no session.';

create or replace function app.supplier_credit_alert_recipients(p_tenant_id uuid)
returns table (user_id uuid)
language sql
stable
security definer
set search_path = ''
as $FN$
    select r.user_id from app.credit_alert_recipients(p_tenant_id) r
$FN$;

revoke all on function app.supplier_credit_alert_recipients(uuid) from public;

comment on function app.supplier_credit_alert_recipients(uuid) is
'SUP-4b''s audience, now delegating to app.credit_alert_recipients so the definition lives in one '
'place (CUST-3, 2026-09-04). Signature and behaviour are unchanged.';

-- =================================================================================================
-- 8. THE EVALUATION. Warning only: this function inserts rows and raises nothing.
--    Idempotency uses the EVENT LEDGER that already exists rather than a new status column -- an
--    alert fires only when the most recent threshold event for the customer is not already
--    `exceeded`, and the `cleared` event exists so a later breach after a payment is announced
--    rather than swallowed. Exactly SUP-4b's mechanism.
-- =================================================================================================
create or replace function app.evaluate_customer_credit_threshold(
    p_tenant_id   uuid,
    p_customer_id uuid
)
returns void
language plpgsql
security definer
set search_path = ''
as $FN$
declare
    v_limit    numeric;
    v_currency text;
    v_name     text;
    v_exposure numeric;
    v_unconv   text[];
    v_last     text;
    v_notif    uuid;
    v_note     text := '';
    r          record;
begin
    if p_tenant_id is null or p_customer_id is null then
        return;
    end if;

    -- A customer with no ceiling has no ceiling. Checked FIRST so the common case costs one indexed
    -- row read and never an aggregate over invoices, payments and refunds.
    select c.credit_limit_amount, c.credit_limit_currency_code, c.full_name
      into v_limit, v_currency, v_name
    from public.customers c
    where c.id = p_customer_id and c.tenant_id = p_tenant_id;

    if v_limit is null or v_currency is null then
        return;
    end if;

    select e.exposure, e.unconvertible
      into v_exposure, v_unconv
    from app.customer_exposure_in_limit_currency(p_tenant_id, p_customer_id, v_currency) e;

    -- THE GAP IS STATED, NEVER SWALLOWED. If a currency carrying real exposure has no usable rate,
    -- the figure below is incomplete and says so in both the event payload and the human text.
    if v_unconv is not null and array_length(v_unconv, 1) > 0 then
        v_note := format(
            ' NOTE: exposure held in %s could not be converted (no exchange rate at or before now), '
            'so this figure is INCOMPLETE and understates the true exposure.',
            array_to_string(v_unconv, ', '));
    end if;

    select e.event_type_code into v_last
    from public.events e
    where e.tenant_id = p_tenant_id
      and e.entity_type = 'customer'
      and e.entity_id = p_customer_id
      and e.event_type_code in ('customer_credit_threshold_exceeded', 'customer_credit_threshold_cleared')
    order by e.seq desc
    limit 1;

    if v_exposure > v_limit then
        if v_last = 'customer_credit_threshold_exceeded' then
            return;
        end if;

        perform app.record_event(
            p_tenant_id, 'customer_credit_threshold_exceeded', 'customer', p_customer_id,
            null, null, null,
            'Customer outstanding receivable rose above its configured credit ceiling',
            jsonb_build_object(
                'customer_id',            p_customer_id,
                'customer_name',          v_name,
                'currency_code',          v_currency,
                'credit_limit',           v_limit,
                'exposure',               v_exposure,
                'over_by',                v_exposure - v_limit,
                'unconvertible_currencies', to_jsonb(v_unconv),
                'enforcement',            'warning_only'
            ),
            'warning'
        );

        for r in select c.user_id from app.credit_alert_recipients(p_tenant_id) c loop
            insert into public.notifications (
                tenant_id, target_user_id, notification_type_code, title, body,
                related_entity_type, related_entity_id
            )
            values (
                p_tenant_id, r.user_id, 'customer_balance',
                'Customer credit threshold exceeded',
                format(
                    'Customer %s has an outstanding receivable of %s %s against a credit ceiling of %s %s (over by %s %s). This is a warning only - no operation has been blocked.%s',
                    coalesce(v_name, '(unnamed)'),
                    to_char(v_exposure, 'FM999999999990.00'), v_currency,
                    to_char(v_limit,    'FM999999999990.00'), v_currency,
                    to_char(v_exposure - v_limit, 'FM999999999990.00'), v_currency,
                    v_note
                ),
                'customer', p_customer_id
            )
            returning id into v_notif;

            -- THE DELIVERY BOUNDARY, RECORDED RATHER THAN CLAIMED -- identical to SUP-4b. ORVION has
            -- no email provider, so the obligation is written to the existing delivery ledger as
            -- `pending` on the `email` channel. Nothing here pretends a mail was sent.
            insert into public.notification_deliveries (
                tenant_id, notification_id, channel_code, delivery_status_code
            )
            values (p_tenant_id, v_notif, 'email', 'pending');
        end loop;

    elsif v_last = 'customer_credit_threshold_exceeded' then
        perform app.record_event(
            p_tenant_id, 'customer_credit_threshold_cleared', 'customer', p_customer_id,
            null, null, null,
            'Customer outstanding receivable returned to or below its credit ceiling',
            jsonb_build_object(
                'customer_id',   p_customer_id,
                'currency_code', v_currency,
                'credit_limit',  v_limit,
                'exposure',      v_exposure,
                'unconvertible_currencies', to_jsonb(v_unconv)
            ),
            'info'
        );
    end if;
end;
$FN$;

revoke all on function app.evaluate_customer_credit_threshold(uuid, uuid) from public;

-- =================================================================================================
-- 9. THE HOOKS. Customer exposure is a function of exactly three tables -- `app.customer_balance`
--    says so: invoices, payments and refunds. AFTER, so the write has already happened and cannot
--    be affected; FOR EACH ROW, because a customer changes per row. Both OLD and NEW customers are
--    evaluated, because re-pointing a row from customer A to B lowers A's exposure and raises B's,
--    and checking only NEW would leave A permanently "exceeded" (SUP-4b's lesson, reused).
-- =================================================================================================
create or replace function app.probe_customer_credit_threshold()
returns trigger
language plpgsql
security definer
set search_path = ''
as $FN$
declare
    v_new uuid := null;
    v_old uuid := null;
    v_ten uuid := null;
begin
    if tg_op in ('INSERT', 'UPDATE') then
        v_new := new.customer_id;
        v_ten := new.tenant_id;
    end if;
    if tg_op in ('UPDATE', 'DELETE') then
        v_old := old.customer_id;
        v_ten := coalesce(v_ten, old.tenant_id);
    end if;

    if v_new is not null then
        perform app.evaluate_customer_credit_threshold(v_ten, v_new);
    end if;
    if v_old is not null and v_old is distinct from v_new then
        perform app.evaluate_customer_credit_threshold(v_ten, v_old);
    end if;

    return null;  -- AFTER trigger: the return value is ignored and the write is untouchable.
end;
$FN$;

revoke all on function app.probe_customer_credit_threshold() from public;

drop trigger if exists invoices_probe_customer_credit on public.invoices;
create trigger invoices_probe_customer_credit
    after insert or update or delete on public.invoices
    for each row execute function app.probe_customer_credit_threshold();

drop trigger if exists payments_probe_customer_credit on public.payments;
create trigger payments_probe_customer_credit
    after insert or update or delete on public.payments
    for each row execute function app.probe_customer_credit_threshold();

drop trigger if exists refunds_probe_customer_credit on public.refunds;
create trigger refunds_probe_customer_credit
    after insert or update or delete on public.refunds
    for each row execute function app.probe_customer_credit_threshold();

-- THE CEILING MOVES TOO, AND THAT IS A FOURTH DOOR SUP-4b DOES NOT HAVE.
-- SUP-4b hooks only the two EXPOSURE tables, reasoning that "exposure is a function of exactly two
-- tables, so those are the only two that can move it". True of exposure -- but the COMPARISON also
-- moves when the CEILING moves. An HTTP probe caught it here: an invoice was raised while the
-- customer had no ceiling, the ceiling was then set BELOW that exposure, and nothing alerted,
-- because no write to invoices/payments/refunds followed. Lowering a ceiling is exactly when a
-- credit control should speak. The supplier side has the same gap and is recorded as SUP-4d rather
-- than fixed here, since this migration is about customers.
--
-- Restricted to statements that actually leave a ceiling in place (`when`), so ordinary customer
-- edits -- a rename, a phone change, an archive -- cost nothing.
create or replace function app.probe_customer_credit_ceiling()
returns trigger
language plpgsql
security definer
set search_path = ''
as $FN$
begin
    perform app.evaluate_customer_credit_threshold(new.tenant_id, new.id);
    return null;
end;
$FN$;

revoke all on function app.probe_customer_credit_ceiling() from public;

drop trigger if exists customers_probe_credit_ceiling on public.customers;
create trigger customers_probe_credit_ceiling
    after insert or update on public.customers
    for each row
    when (new.credit_limit_amount is not null and new.credit_limit_currency_code is not null)
    execute function app.probe_customer_credit_ceiling();

-- =================================================================================================
-- 10. WRITE AUTHORITY ON THE CEILING. Mirrors `app.guard_supplier_credit_authority` exactly: a
--     write that changes the amount OR the currency costs MANAGE_CUSTOMER_CREDIT, because
--     re-denominating a ceiling from EGP to USD changes what the agency is exposed to just as surely
--     as changing the number (SUP-4a's lesson).
-- =================================================================================================
create or replace function app.guard_customer_credit_authority()
returns trigger
language plpgsql
set search_path = ''
as $FN$
begin
    -- Platform/system paths (canon 35 principle 6), identical to every sibling guard.
    if (select auth.uid()) is null then
        return new;
    end if;

    if tg_op = 'INSERT'
       and new.credit_limit_amount is null
       and new.credit_limit_currency_code is null then
        return new;
    end if;

    if tg_op = 'UPDATE'
       and new.credit_limit_amount is not distinct from old.credit_limit_amount
       and new.credit_limit_currency_code is not distinct from old.credit_limit_currency_code then
        return new;
    end if;

    perform app.authorize('MANAGE_CUSTOMER_CREDIT');

    return new;
end;
$FN$;

revoke all on function app.guard_customer_credit_authority() from public;

drop trigger if exists customers_guard_credit_authority on public.customers;
create trigger customers_guard_credit_authority
    before insert or update on public.customers
    for each row execute function app.guard_customer_credit_authority();

-- =================================================================================================
-- 11. THE UI/READ CONTRACT -- the same shape as `app.supplier_credit`, so a client asks one question
--     and gets ceiling, currency, exposure and the over-limit flag in one call. Gated on
--     VIEW_FINANCIAL_DOCUMENTS: an actor holding MANAGE_CUSTOMER_CREDIT and not
--     VIEW_FINANCIAL_DOCUMENTS may SET the ceiling and still cannot READ it. Write authority does
--     not become visibility.
--
--     It additionally returns the un-convertible currencies, so a UI can show "incomplete" rather
--     than presenting a partial number as if it were whole.
-- =================================================================================================
create or replace function app.customer_credit(p_customer_id uuid)
returns table (
    credit_limit_amount        numeric,
    credit_limit_currency_code text,
    may_view                   boolean,
    exposure                   numeric,
    over_limit                 boolean,
    unconvertible_currencies   text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $FN$
declare
    v_tenant uuid := app.current_tenant_id();
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;

    -- The row must be visible to the CALLER, not merely to this DEFINER function.
    if not exists (select 1 from public.customers c
                    where c.id = p_customer_id and c.tenant_id = v_tenant) then
        raise exception 'customer is not in your tenant' using errcode = '42501';
    end if;

    if not app.has_permission('VIEW_FINANCIAL_DOCUMENTS') then
        return query select null::numeric, null::text, false, null::numeric, null::boolean, null::text[];
        return;
    end if;

    return query
    select c.credit_limit_amount,
           c.credit_limit_currency_code,
           true,
           e.exposure,
           case when c.credit_limit_amount is null then null else e.exposure > c.credit_limit_amount end,
           e.unconvertible
    from public.customers c
    left join lateral app.customer_exposure_in_limit_currency(v_tenant, c.id, c.credit_limit_currency_code) e
           on c.credit_limit_currency_code is not null
    where c.id = p_customer_id and c.tenant_id = v_tenant;
end;
$FN$;

-- GRANT-1: the default ACL grants EXECUTE to PUBLIC on every new function, so anon inherits it
-- unless it is revoked. `10_grant_model_test` and `53_api_surface_test` both refused this before
-- the revokes were added -- ORVION has no anonymous flow and no endpoint may be reachable by anon.
revoke all on function app.customer_credit(uuid) from public;
grant execute on function app.customer_credit(uuid) to authenticated;

create or replace function public.customer_credit(p_customer_id uuid)
returns table (
    credit_limit_amount        numeric,
    credit_limit_currency_code text,
    may_view                   boolean,
    exposure                   numeric,
    over_limit                 boolean,
    unconvertible_currencies   text[]
)
language sql
stable
set search_path = ''
as $FN$ select * from app.customer_credit(p_customer_id) $FN$;

revoke all on function public.customer_credit(uuid) from public;
grant execute on function public.customer_credit(uuid) to authenticated;

comment on function public.customer_credit(uuid) is
'CUST-3: the customer receivable ceiling, its currency, current exposure converted into that '
'currency, whether it is exceeded, and any currencies that could not be converted. Warning-only -- '
'nothing in ORVION refuses a write because this is over limit.';

-- =================================================================================================
-- 12. THE TABLE DOOR. `guard_write_capability` decides WHICH permission a write costs, and
--     `customers` currently maps to CREATE_CUSTOMER. Replaced in full from the repository's own
--     latest definition (`202607059900`) so nothing from SEC-1b / SEC-1c / LIC-3 / PP-4 / SUP-3 /
--     SUP-4a is lost; the only change is the customers credit-only branch, which carries its own
--     comment. Test both doors (AGENTS.md 6): `authenticated` holds INSERT/UPDATE on
--     `public.customers`, so PostgREST exposes the table beside every RPC.
-- =================================================================================================
create or replace function app.guard_write_capability()
returns trigger
language plpgsql
set search_path = ''
as $FN$
declare
    v_perms  text[];
    v_extra  text[];
    v_perm   text;
    v_held   text;
    v_strict boolean := false;
    v_relationship_ok boolean := false;
    v_credit_only boolean := false;
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
    -- WHY THIS IS AN `OR` AND NOT A ROW-IMAGE COMPARISON, WHICH IS WHAT SUPPLIERS USES.
    -- The first attempt copied the supplier form -- "the credit pair changed AND nothing else did,
    -- therefore charge MANAGE_SUPPLIER_CREDIT instead". A pgTAP assertion caught it failing on
    -- `customers`, and the cause is real rather than a test artefact: `customers` carries
    -- `customers_derive_first_registration_actor`, which fires BEFORE this guard (alphabetically
    -- `derive_` < `guard_`) and SETS `new.first_registered_user_id` whenever the old value is null --
    -- true for every customer created by a system path with no session. The row image the guard
    -- compares has therefore already been mutated by a SIBLING TRIGGER, so "nothing else changed" is
    -- false, the branch never fires, and a finance manager is refused. `suppliers` escapes this only
    -- because it happens to carry no mutating BEFORE trigger -- an accident, not a design, recorded
    -- as CUST-5.
    --
    -- The correct rule needs no row image at all. `v_perms` is an OR-list, so a write that TOUCHES
    -- the ceiling simply ADDS MANAGE_CUSTOMER_CREDIT to what is sufficient. Authority over the
    -- ceiling itself is not weakened by this: `customers_guard_credit_authority` fires FIRST and
    -- REQUIRES MANAGE_CUSTOMER_CREDIT for any credit change, so an employee holding CREATE_CUSTOMER
    -- is still refused. Two doors, each answering its own question.
    -- THE TABLE TEST IS ITS OWN OUTER `if`, and that is LIC-3 / PP-4's rule restated three lines
    -- below where this guard already states it. A record field reference is resolved against the
    -- ACTUAL record type at execution, so putting `new.credit_limit_amount` in the SAME boolean
    -- expression as `tg_table_name = 'customers'` makes it resolve for `tasks`, `leads` and every
    -- other table this trigger serves -- "record new has no field credit_limit_amount". The suite
    -- caught it across eight files; the nested form evaluates the field only once the table is known.
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

    -- SUP-3, widened by SUP-4a: the ceiling is now the PAIR (amount, currency), so a write that
    -- touches only those two is still a credit-only write. Excluding both from the row image is what
    -- keeps "set a limit of 10,000 EGP" -- which must write both columns -- costing
    -- MANAGE_SUPPLIER_CREDIT rather than silently reverting to ASSIGN_SUPPLIER.
    if tg_op = 'UPDATE' and tg_table_name = 'suppliers' then
        v_credit_only := (new.credit_limit_amount is distinct from old.credit_limit_amount
                          or new.credit_limit_currency_code is distinct from old.credit_limit_currency_code)
                         and (to_jsonb(new) - 'credit_limit_amount' - 'credit_limit_currency_code' - 'updated_at')
                           = (to_jsonb(old) - 'credit_limit_amount' - 'credit_limit_currency_code' - 'updated_at');
        if v_credit_only then
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
$FN$;

revoke all on function app.guard_write_capability() from public;
