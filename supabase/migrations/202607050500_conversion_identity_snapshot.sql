-- Migration: conversion_identity_snapshot
-- Plan reference: SPEC-128. Resolves ATTR-1 — the offline-conversion payload derived customer
-- identity from MUTABLE customer fields, read at claim time on every attempt.
--
-- THE DEFECT. `app.claim_conversion_deliveries` ended with:
--     left join public.leads l     on l.id = oc.lead_id
--     left join public.customers cu on cu.id = l.customer_id
--     ... select cu.primary_phone, cu.primary_email
-- so the identity sent to Google was whatever the customer record happened to say at the moment of
-- the claim — not what was true when the conversion occurred. Three consequences, all real:
--   1. A customer who corrects their email after the conversion silently changes the identity of a
--      historical business event.
--   2. A retry after a failed attempt can send DIFFERENT user data than the first attempt, for the
--      same transactionId — the one thing an at-least-once delivery pipeline must never do.
--   3. `offline_conversions` carried no `customer_id` at all, so the conversion could not even name
--      the customer it belonged to; identity was reachable only by traversing an optional lead.
--
-- WHY IT HAD TO BE FIXED BEFORE THE FIRST WORKFLOW, NOT AFTER. This is the one defect in the
-- Phase-8 chain whose window closes permanently: a snapshot cannot be backfilled. Once a real
-- conversion has been delivered against a since-edited customer, the identity that was actually
-- sent is unrecoverable from the database. Cost to fix at 0 rows: this migration. Cost to fix
-- after go-live: impossible for the affected rows.
--
-- THE FIX. Snapshot the identity onto the conversion at CREATION time, in every creation path, and
-- have the claim read the snapshot. The stored values are already canonical because SPEC-126
-- normalizes and constrains `customers.primary_email` / `primary_phone` at their single write path,
-- so the snapshot inherits that canonical form; the CHECKs below re-assert it so a future writer
-- cannot introduce a non-canonical identity through this table either.
--
-- CONTRACT PRESERVED. `claim_conversion_deliveries` keeps its exact RETURNS TABLE signature —
-- `customer_phone` / `customer_email` still appear in the same positions. The n8n `§2` contract does
-- not move; only the SOURCE of those two values changes, from mutable to immutable. That was a
-- deliberate design constraint, not a coincidence: the workflow must be built against the final
-- data contract, and this keeps that contract stable while making it historically true.

-- ---------------------------------------------------------------------------------------------
-- 1. The snapshot columns.
-- ---------------------------------------------------------------------------------------------
alter table public.offline_conversions
    add column customer_id uuid,
    add column customer_email text,
    add column customer_phone text;

comment on column public.offline_conversions.customer_id is
    'The customer this conversion belongs to, resolved at conversion-creation time. Nullable: a lead may not yet be linked to a customer when an early-funnel conversion (qualified_lead) fires.';
comment on column public.offline_conversions.customer_email is
    'HISTORICAL SNAPSHOT of the customer email at conversion-creation time. Never re-read from customers -- see SPEC-128 / ATTR-1. Deliberately denormalized: this is the identity that was true when the business event occurred, and it must survive later customer edits.';
comment on column public.offline_conversions.customer_phone is
    'HISTORICAL SNAPSHOT of the customer phone at conversion-creation time. See customer_email.';

alter table public.offline_conversions
    add constraint offline_conversions_customer_id_fkey
    foreign key (customer_id) references public.customers (id)
    on delete restrict on update no action;

create index offline_conversions_customer_id_idx
    on public.offline_conversions (customer_id);

-- The snapshot must be canonical for the same reason the source is (SPEC-126): an identity that
-- differs only by casing or formatting is a different identity to Google's matcher.
alter table public.offline_conversions
    add constraint offline_conversions_customer_email_normalized_chk
    check (
        customer_email is null
        or (customer_email = lower(btrim(customer_email))
            and customer_email !~ '[[:space:]]'
            and position('@' in customer_email) > 1)
    );

alter table public.offline_conversions
    add constraint offline_conversions_customer_phone_normalized_chk
    check (
        customer_phone is null
        or (customer_phone !~ '[[:space:]().-]' and customer_phone <> '')
    );

-- ---------------------------------------------------------------------------------------------
-- 2. Creation path 1 of 2 — the event-driven mapper.
--    Body preserved verbatim from 202607049300 except for the customer join and the three new
--    snapshot columns. The join is LEFT because `leads.customer_id` is legitimately null for a
--    lead that has not been converted yet; such a conversion is delivered on its click ID alone,
--    which is valid and is the correct behaviour rather than a reason to withhold the conversion.
-- ---------------------------------------------------------------------------------------------
create or replace function app.map_outcomes_to_conversions(p_batch integer default 500)
returns integer
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_cursor bigint;
    v_max_seq bigint;
    v_inserted integer := 0;
begin
    select last_seq into v_cursor
    from public.integration_cursors
    where name = 'outcome_conversion_mapper'
    for update;

    select max(sub.seq) into v_max_seq from (
        select e.seq from public.events e
        where e.seq > v_cursor
          and e.event_type_code in
              ('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued')
        order by e.seq
        limit p_batch
    ) sub;
    if v_max_seq is null then
        return 0;   -- nothing new
    end if;

    with batch as (
        select e.seq, e.tenant_id, e.event_type_code, e.entity_type, e.entity_id, e.payload,
               e.created_at
        from public.events e
        where e.seq > v_cursor
          and e.event_type_code in
              ('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued')
        order by e.seq
        limit p_batch
    ),
    resolved as (
        select b.seq, b.tenant_id, b.created_at,
               case b.event_type_code
                   when 'lead_qualified'   then 'qualified_lead'
                   when 'booking_created'  then 'booking_created'
                   when 'payment_recorded' then 'payment_received'
                   when 'booking_issued'   then 'ticket_issued'
               end as conversion_type,
               coalesce(
                   case when b.event_type_code = 'lead_qualified' then b.entity_id end,
                   case when b.event_type_code = 'booking_created'
                        then (b.payload ->> 'lead_id')::uuid end,
                   case when b.event_type_code = 'booking_issued' then bk.lead_id end,
                   case when b.event_type_code = 'payment_recorded' then pbk.lead_id end
               ) as lead_id,
               case when b.event_type_code = 'payment_recorded' then p.id end as payment_id,
               case when b.event_type_code in ('booking_created', 'booking_issued')
                    then b.entity_id
                    when b.event_type_code = 'payment_recorded' then p.booking_id end as booking_id,
               case when b.event_type_code = 'payment_recorded' then p.amount end as conv_value,
               case when b.event_type_code = 'payment_recorded' then p.currency_code end as conv_ccy
        from batch b
        left join public.bookings bk
               on b.event_type_code = 'booking_issued' and bk.id = b.entity_id
        left join public.payments p
               on b.event_type_code = 'payment_recorded' and p.id = b.entity_id
        left join public.bookings pbk
               on p.booking_id = pbk.id
    )
    insert into public.offline_conversions
        (tenant_id, lead_id, booking_id, payment_id, attribution_click_id,
         conversion_event_type_code, conversion_value, currency_code,
         conversion_at, source_event_seq,
         customer_id, customer_email, customer_phone)
    select r.tenant_id, l.id, r.booking_id, r.payment_id, l.attribution_click_id,
           r.conversion_type, r.conv_value, r.conv_ccy, r.created_at, r.seq,
           cu.id, cu.primary_email, cu.primary_phone
    from resolved r
    join public.leads l on l.id = r.lead_id
    left join public.customers cu
           on cu.id = l.customer_id and cu.tenant_id = r.tenant_id
    where l.attribution_click_id is not null
    on conflict (source_event_seq) where source_event_seq is not null do nothing;

    get diagnostics v_inserted = row_count;

    update public.integration_cursors
    set last_seq = v_max_seq, updated_at = now()
    where name = 'outcome_conversion_mapper';

    return v_inserted;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- 3. Creation path 2 of 2 — the manual RPC.
--    Body preserved verbatim from 202607049200 except for identity resolution. The customer is
--    derived from the supplied lead and re-checked against the caller's tenant, so a cross-tenant
--    lead can never contribute an identity even if the lead guard above were ever relaxed.
-- ---------------------------------------------------------------------------------------------
create or replace function app.record_offline_conversion(
    p_conversion_event_type_code text,
    p_lead_id uuid default null,
    p_booking_id uuid default null,
    p_booking_item_id uuid default null,
    p_payment_id uuid default null,
    p_attribution_click_id uuid default null,
    p_marketing_campaign_id uuid default null,
    p_conversion_value numeric default null,
    p_currency_code text default null,
    p_conversion_at timestamptz default now()
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_id uuid;
    v_customer_id uuid;
    v_customer_email text;
    v_customer_phone text;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('MANAGE_MARKETING_CAMPAIGN');

    if not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'offline_conversion_event_type'
          and code = p_conversion_event_type_code
    ) then
        raise exception 'unknown conversion_event_type_code: %', p_conversion_event_type_code;
    end if;
    if p_conversion_value is not null and p_conversion_value < 0 then
        raise exception 'conversion_value must be non-negative';
    end if;
    if p_conversion_value is not null and p_currency_code is null then
        raise exception 'currency_code is required when conversion_value is set';
    end if;
    if p_attribution_click_id is not null and not exists (
        select 1 from public.attribution_clicks
        where id = p_attribution_click_id and tenant_id = v_tenant
    ) then
        raise exception 'attribution click is not in your tenant';
    end if;
    if p_lead_id is not null and not exists (
        select 1 from public.leads where id = p_lead_id and tenant_id = v_tenant
    ) then
        raise exception 'lead is not in your tenant';
    end if;

    -- Historical identity snapshot (SPEC-128 / ATTR-1), taken once, here, at creation.
    if p_lead_id is not null then
        select cu.id, cu.primary_email, cu.primary_phone
          into v_customer_id, v_customer_email, v_customer_phone
        from public.leads l
        join public.customers cu on cu.id = l.customer_id and cu.tenant_id = v_tenant
        where l.id = p_lead_id and l.tenant_id = v_tenant;
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    insert into public.offline_conversions (
        tenant_id, lead_id, booking_id, booking_item_id, payment_id,
        attribution_click_id, marketing_campaign_id,
        conversion_event_type_code, conversion_value, currency_code, conversion_at,
        customer_id, customer_email, customer_phone
    ) values (
        v_tenant, p_lead_id, p_booking_id, p_booking_item_id, p_payment_id,
        p_attribution_click_id, p_marketing_campaign_id,
        p_conversion_event_type_code, p_conversion_value, p_currency_code, p_conversion_at,
        v_customer_id, v_customer_email, v_customer_phone
    )
    returning id into v_id;

    perform app.record_event(
        v_tenant, 'offline_conversion_created', 'offline_conversion', v_id, v_actor,
        null, 'created', null,
        jsonb_build_object('conversion_event_type_code', p_conversion_event_type_code,
                           'conversion_value', p_conversion_value,
                           'currency_code', p_currency_code,
                           'lead_id', p_lead_id),
        'info'
    );
    return v_id;
end;
$$;

-- ---------------------------------------------------------------------------------------------
-- 4. Delivery — read the snapshot, never the live customer.
--    Body preserved verbatim from 202607050100 (the SPEC-123 lease) except for the final
--    projection: the two joins to leads/customers are removed and the identity now comes from the
--    conversion row itself. The RETURNS TABLE signature is byte-for-byte unchanged.
-- ---------------------------------------------------------------------------------------------
create or replace function app.claim_conversion_deliveries(
    p_platform_code text,
    p_batch integer default 50
)
returns table (
    delivery_id uuid,
    conversion_id uuid,
    tenant_id uuid,
    conversion_event_type_code text,
    conversion_value numeric,
    currency_code text,
    conversion_at timestamptz,
    gclid text,
    gbraid text,
    wbraid text,
    consent_ad_user_data text,
    consent_ad_personalization text,
    customer_phone text,
    customer_email text,
    attempt_number integer
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    c_lease constant interval := interval '30 minutes';
    v_expired record;
begin
    -- Step 0: expire stale leases before claiming (PH8-1).
    for v_expired in
        update public.offline_conversion_deliveries d
        set delivery_status_code = 'failed',
            error_message = 'LEASE_EXPIRED: no delivery result recorded within '
                            || c_lease::text || '; attempt terminated by app.claim_conversion_deliveries'
        where d.platform_code = p_platform_code
          and d.delivery_status_code = 'pending'
          and d.created_at < now() - c_lease
        returning d.id, d.tenant_id, d.offline_conversion_id, d.attempt_number
    loop
        perform app.record_event(
            v_expired.tenant_id, 'offline_conversion_failed', 'offline_conversion',
            v_expired.offline_conversion_id, null,
            'pending',
            'failed',
            'LEASE_EXPIRED: no delivery result recorded within the lease window',
            jsonb_build_object('delivery_id', v_expired.id,
                               'attempt_number', v_expired.attempt_number,
                               'expired_lease', true,
                               'lease_interval', c_lease::text),
            'warning'
        );
    end loop;

    -- Step 1: claim.
    return query
    with claimable as (
        select oc.id, oc.tenant_id
        from public.offline_conversions oc
        join public.attribution_clicks ac
          on ac.id = oc.attribution_click_id
         and ac.consent_ad_user_data = 'granted'
        where not exists (
                select 1 from public.offline_conversion_deliveries d
                where d.offline_conversion_id = oc.id
                  and d.platform_code = p_platform_code
                  and d.delivery_status_code in ('pending', 'sent')
              )
          and (select count(*) from public.offline_conversion_deliveries d2
               where d2.offline_conversion_id = oc.id
                 and d2.platform_code = p_platform_code) < 5
        order by oc.conversion_at
        limit p_batch
        for update of oc skip locked
    ),
    retire_failed as (
        update public.offline_conversion_deliveries d
        set delivery_status_code = 'retried'
        from claimable c
        where d.offline_conversion_id = c.id
          and d.platform_code = p_platform_code
          and d.delivery_status_code = 'failed'
    ),
    new_deliveries as (
        insert into public.offline_conversion_deliveries
            (tenant_id, offline_conversion_id, platform_code, delivery_status_code, attempt_number)
        select c.tenant_id, c.id, p_platform_code, 'pending',
               coalesce((select max(d.attempt_number)
                         from public.offline_conversion_deliveries d
                         where d.offline_conversion_id = c.id
                           and d.platform_code = p_platform_code), 0) + 1
        from claimable c
        returning offline_conversion_deliveries.id,
                  offline_conversion_deliveries.offline_conversion_id,
                  offline_conversion_deliveries.tenant_id,
                  offline_conversion_deliveries.attempt_number
    )
    select nd.id, oc.id, oc.tenant_id,
           oc.conversion_event_type_code, oc.conversion_value, oc.currency_code, oc.conversion_at,
           ac.gclid, ac.gbraid, ac.wbraid, ac.consent_ad_user_data, ac.consent_ad_personalization,
           -- SPEC-128: the historical snapshot taken at conversion creation. Deliberately NOT a
           -- join to customers -- that is the defect this migration exists to remove.
           oc.customer_phone, oc.customer_email,
           nd.attempt_number
    from new_deliveries nd
    join public.offline_conversions oc on oc.id = nd.offline_conversion_id
    left join public.attribution_clicks ac on ac.id = oc.attribution_click_id;
end;
$$;
