-- Phase-8 Activation Closure: PH8-9 -- a Google Data Manager ingestion acknowledgement is not a
-- delivery. ORVION keeps the provider's request identity, keeps the delivery out of every re-claim
-- while Google processes it, and marks it `sent` only on Google's terminal SUCCESS.
--
-- MEASURED at `67007fb` (local stack):
--   * `app.record_conversion_delivery_result(id, true, ...)` set `delivery_status_code = 'sent'` on
--     the call that acknowledges ingestion -- a boolean that meant "Google accepted the request";
--   * `app.claim_conversion_deliveries` excludes a conversion holding a `pending` or `sent` delivery
--     for ever, so a conversion Google later reports FAILED was lost as permanently as `validateOnly`
--     (register PH8-9; `MASTER_INTEGRATION_CATALOG.md` section 2a correction 11).
--
-- THE SHAPE. One table, one more state, no second ledger.
--   * `ingested` sits between `pending` (claimed, under the 30-minute pre-send lease) and the terminal
--     result. It carries Google's `requestId` (unique: one request names one delivery, the v1
--     one-event-per-request design), is never re-claimed and is never swept by the pre-send lease.
--   * Google answers `requestStatus:retrieve` from about 30 minutes to 24 hours after ingestion.
--     `app.conversion_status_checks_due` lists an ingested delivery 30 minutes after ingestion and
--     then at most hourly -- never more often than Google's documented back-off (x1.3, capped at
--     60 minutes) after the first check.
--   * `app.record_conversion_provider_status` judges Google's answer for THAT delivery and THAT
--     request only. PROCESSING and REQUEST_STATUS_UNKNOWN stay `ingested`; SUCCESS is the only path
--     to `sent` and emits `offline_conversion_sent` once (a repeated SUCCESS is a no-op); FAILED and
--     PARTIAL_SUCCESS -- which a one-event request cannot legitimately return -- become `failed`
--     and re-claimable, exactly like an ingestion failure.
--   * A delivery still `ingested` 26 hours after ingestion -- two hours past Google's documented
--     maximum -- is failed with `PROVIDER_DEADLINE` by the same claim call that sweeps the lease.
--   * `app.record_conversion_ingestion` replaces the boolean: exactly one of Google's `requestId`
--     (`pending` -> `ingested`) or an error (`pending` -> `failed`: an HTTP error, a material
--     `fieldWarnings` entry, or a `validateOnly` run).
--   * A table CHECK makes `sent` impossible without a recorded SUCCESS, on every door.
--   * Retries re-send the same Google `transactionId`, now returned by the claim: the conversion's
--     id, except that a `ticket_issued` formed from a `booking_issued` event carries that event's
--     booking -- so a reissue of the same booking is Google's adjustment of one acquisition, not a
--     second one (owner direction, register PH8-9, 2026-09-29). The booking is read from the
--     append-only source event, never from the conversion's own updatable `booking_id`.
--
-- NOT CHANGED: the mapper, consent and identity rules, the lease, the retry ceiling of 5, every
-- other function, grant and policy. No Google wire format beyond the request id and status: the
-- payload, hashing, OAuth and polling transport stay at the delivery edge.

-- ===========================================================================================
-- 1. The state.
-- ===========================================================================================
insert into public.catalog_values (tenant_id, catalog_type_code, code, label, description, sort_order, is_system)
values (null, 'offline_conversion_delivery_status', 'ingested', 'Ingested',
        'The provider accepted the request and returned its request identity, and is still processing it. Not sent, not re-claimable; resolved only by a terminal provider status or its deadline.',
        5, true);

-- ===========================================================================================
-- 2. The provider's request, on the delivery it belongs to.
-- ===========================================================================================
alter table public.offline_conversion_deliveries
    add column provider_request_id     text,
    add column ingested_at             timestamptz,
    add column provider_status_code    text,
    add column provider_status_payload jsonb,
    add column provider_checked_at     timestamptz;

alter table public.offline_conversion_deliveries
    add constraint offline_conversion_deliveries_provider_request_shape
        check ((provider_request_id is null) = (ingested_at is null)
               and (provider_request_id is null
                    or (length(provider_request_id) between 1 and 256
                        and provider_request_id !~ '[[:space:]]'))),
    add constraint offline_conversion_deliveries_ingested_has_request
        check (delivery_status_code <> 'ingested' or provider_request_id is not null),
    add constraint offline_conversion_deliveries_provider_status_vocabulary
        check (provider_status_code is null
               or (provider_request_id is not null
                   and provider_status_code in ('REQUEST_STATUS_UNKNOWN', 'PROCESSING', 'SUCCESS',
                                                'PARTIAL_SUCCESS', 'FAILED'))),
    add constraint offline_conversion_deliveries_sent_on_provider_success
        check (delivery_status_code <> 'sent' or provider_status_code is not distinct from 'SUCCESS');

create unique index offline_conversion_deliveries_provider_request_id_key
    on public.offline_conversion_deliveries (provider_request_id)
    where provider_request_id is not null;

-- ===========================================================================================
-- 3. The claim: an ingested delivery is not re-claimable, a stale one meets its deadline, and
--    every row carries its stable Google transaction identity. The OUT list grows, so the
--    function is re-created.
-- ===========================================================================================
drop function app.claim_conversion_deliveries(text, integer);

create function app.claim_conversion_deliveries(p_platform_code text, p_batch integer default 50)
returns table(delivery_id uuid, conversion_id uuid, tenant_id uuid, conversion_event_type_code text,
              conversion_value numeric, currency_code text, conversion_at timestamp with time zone,
              gclid text, gbraid text, wbraid text, consent_ad_user_data text,
              consent_ad_personalization text, customer_phone text, customer_email text,
              attempt_number integer, transaction_id uuid)
language plpgsql
security definer
set search_path to ''
as $function$
declare
    c_lease constant interval := interval '30 minutes';
    -- PH8-9: Google reports a terminal status within 24 hours of ingestion; two hours more, then
    -- the attempt is failed and the conversion re-sent under the same transaction identity.
    c_provider_deadline constant interval := interval '26 hours';
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

    -- Step 0b (PH8-9): an ingested delivery Google never resolved meets its deadline.
    for v_expired in
        update public.offline_conversion_deliveries d
        set delivery_status_code = 'failed',
            failed_at = now(),
            error_message = 'PROVIDER_DEADLINE: no terminal provider status within '
                            || c_provider_deadline::text
                            || ' of ingestion; attempt terminated by app.claim_conversion_deliveries'
        where d.platform_code = p_platform_code
          and d.delivery_status_code = 'ingested'
          and d.ingested_at < now() - c_provider_deadline
        returning d.id, d.tenant_id, d.offline_conversion_id, d.attempt_number, d.provider_request_id
    loop
        perform app.record_event(
            v_expired.tenant_id, 'offline_conversion_failed', 'offline_conversion',
            v_expired.offline_conversion_id, null,
            'ingested',
            'failed',
            'PROVIDER_DEADLINE: no terminal provider status within the deadline',
            jsonb_build_object('delivery_id', v_expired.id,
                               'attempt_number', v_expired.attempt_number,
                               'provider_request_id', v_expired.provider_request_id,
                               'provider_deadline', true,
                               'deadline_interval', c_provider_deadline::text),
            'warning'
        );
    end loop;

    -- Step 1: claim.
    return query
    with claimable as (
        select oc.id, oc.tenant_id
        from public.offline_conversions oc
        left join public.attribution_clicks ac
          on ac.id = oc.attribution_click_id
        -- PH8-4: each path answers to its own consent authority. A phone-call conversion answers to
        -- its customer's recorded consent, must come from a real event, and must carry something
        -- to match on; every other conversion answers to its click's consent, as before.
        where case when oc.conversion_event_type_code = 'qualified_phone_call'
                   then oc.source_event_seq is not null
                    and app.customer_consent_status(oc.tenant_id, oc.customer_id, 'ad_user_data')
                        = 'granted'
                    and (app.e164_phone(oc.customer_phone) is not null
                         or oc.customer_email is not null
                         or (ac.consent_ad_user_data = 'granted'
                             and coalesce(ac.gclid, ac.gbraid, ac.wbraid) is not null))
                   else ac.consent_ad_user_data = 'granted' end
          -- PH8-9: an ingested delivery is Google's to resolve, never ORVION's to re-send.
          and not exists (
                select 1 from public.offline_conversion_deliveries d
                where d.offline_conversion_id = oc.id
                  and d.platform_code = p_platform_code
                  and d.delivery_status_code in ('pending', 'ingested', 'sent')
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
           -- A click's identifiers and consent travel only under that click's own consent.
           case when ac.consent_ad_user_data = 'granted' then ac.gclid end,
           case when ac.consent_ad_user_data = 'granted' then ac.gbraid end,
           case when ac.consent_ad_user_data = 'granted' then ac.wbraid end,
           case when oc.conversion_event_type_code = 'qualified_phone_call' then 'granted'
                else ac.consent_ad_user_data end,
           case when oc.conversion_event_type_code = 'qualified_phone_call' then null
                else ac.consent_ad_personalization end,
           -- SPEC-128: the historical snapshot taken at conversion creation. Deliberately NOT a
           -- join to customers -- that is the defect this migration exists to remove. PH8-4: the
           -- phone leaves only as E.164, from the one authority, or not at all.
           app.e164_phone(oc.customer_phone), oc.customer_email,
           nd.attempt_number,
           -- PH8-9: the Google transactionId, identical on every retry. A reissue of the same
           -- booking is the same acquisition, so a mapped `ticket_issued` carries the booking of
           -- its append-only source event; every other conversion carries its own id.
           coalesce(case when oc.conversion_event_type_code = 'ticket_issued' then se.entity_id end,
                    oc.id)
    from new_deliveries nd
    join public.offline_conversions oc on oc.id = nd.offline_conversion_id
    left join public.attribution_clicks ac on ac.id = oc.attribution_click_id
    left join public.events se
           on se.seq = oc.source_event_seq
          and se.tenant_id = oc.tenant_id
          and se.event_type_code = 'booking_issued';
end;
$function$;

revoke execute on function app.claim_conversion_deliveries(text, integer) from public, authenticated;
grant execute on function app.claim_conversion_deliveries(text, integer) to orvion_integration;

-- ===========================================================================================
-- 4. Ingestion: Google's `requestId`, or the reason there is none. Replaces the boolean.
-- ===========================================================================================
drop function app.record_conversion_delivery_result(uuid, boolean, jsonb, text);

create function app.record_conversion_ingestion(
    p_delivery_id uuid,
    p_request_id  text,
    p_error       text  default null,
    p_response    jsonb default null
)
returns text
language plpgsql
security definer
set search_path to ''
as $function$
declare
    v_d record;
begin
    if (p_request_id is null) = (p_error is null) then
        raise exception 'record_conversion_ingestion: exactly one of p_request_id (the provider accepted the request) or p_error (it did not, or ORVION refuses the response) is required'
            using errcode = 'invalid_parameter_value';
    end if;
    if p_error is not null and btrim(p_error) = '' then
        raise exception 'record_conversion_ingestion: p_error must say why'
            using errcode = 'invalid_parameter_value';
    end if;

    select * into v_d
    from public.offline_conversion_deliveries
    where id = p_delivery_id
    for update;
    if not found then
        raise exception 'unknown delivery id: %', p_delivery_id;
    end if;
    -- A late call after the lease expired finds `failed` or `retried` and is refused, so a run that
    -- lost its lease can never attach a request to a delivery another run has taken over.
    if v_d.delivery_status_code <> 'pending' then
        raise exception 'delivery % is % -- only a pending delivery can record its ingestion',
            p_delivery_id, v_d.delivery_status_code;
    end if;

    if p_request_id is not null then
        -- The request id's shape and its uniqueness are the table's: one request, one delivery.
        update public.offline_conversion_deliveries
        set delivery_status_code = 'ingested',
            provider_request_id = p_request_id,
            ingested_at = now(),
            response_payload = p_response
        where id = p_delivery_id;
        return 'ingested';
    end if;

    update public.offline_conversion_deliveries
    set delivery_status_code = 'failed',
        failed_at = now(),
        response_payload = p_response,
        error_message = p_error
    where id = p_delivery_id;

    perform app.record_event(
        v_d.tenant_id, 'offline_conversion_failed', 'offline_conversion',
        v_d.offline_conversion_id, null,
        'pending', 'failed', p_error,
        jsonb_build_object('platform_code', v_d.platform_code,
                           'attempt_number', v_d.attempt_number,
                           'delivery_id', p_delivery_id),
        'warning'
    );
    return 'failed';
end;
$function$;

revoke execute on function app.record_conversion_ingestion(uuid, text, text, jsonb) from public, authenticated;
grant execute on function app.record_conversion_ingestion(uuid, text, text, jsonb) to orvion_integration;

-- ===========================================================================================
-- 5. Which ingested deliveries are due for `requestStatus:retrieve`.
-- ===========================================================================================
create function app.conversion_status_checks_due(p_platform_code text, p_batch integer default 50)
returns table(delivery_id uuid, provider_request_id text, conversion_id uuid, tenant_id uuid,
              attempt_number integer, ingested_at timestamp with time zone,
              provider_checked_at timestamp with time zone)
language sql
stable
security definer
set search_path to ''
as $function$
    -- First check 30 minutes after ingestion (Google's documented wait), then at most hourly
    -- (Google's back-off cap). Read-only: a run that dies after reading leaves the row due.
    select d.id, d.provider_request_id, d.offline_conversion_id, d.tenant_id, d.attempt_number,
           d.ingested_at, d.provider_checked_at
    from public.offline_conversion_deliveries d
    where d.platform_code = p_platform_code
      and d.delivery_status_code = 'ingested'
      and d.ingested_at <= now() - interval '30 minutes'
      and (d.provider_checked_at is null or d.provider_checked_at <= now() - interval '60 minutes')
    order by coalesce(d.provider_checked_at, d.ingested_at), d.id
    limit p_batch
$function$;

revoke execute on function app.conversion_status_checks_due(text, integer) from public, authenticated;
grant execute on function app.conversion_status_checks_due(text, integer) to orvion_integration;

-- ===========================================================================================
-- 6. Google's answer for one request. SUCCESS is the only door to `sent`.
-- ===========================================================================================
create function app.record_conversion_provider_status(
    p_delivery_id    uuid,
    p_request_id     text,
    p_request_status text,
    p_response       jsonb default null
)
returns text
language plpgsql
security definer
set search_path to ''
as $function$
declare
    v_d record;
begin
    if p_request_status is null
       or p_request_status not in ('REQUEST_STATUS_UNKNOWN', 'PROCESSING', 'SUCCESS',
                                   'PARTIAL_SUCCESS', 'FAILED') then
        raise exception 'record_conversion_provider_status: unknown provider request status %',
            p_request_status
            using errcode = 'invalid_parameter_value';
    end if;

    select * into v_d
    from public.offline_conversion_deliveries
    where id = p_delivery_id
    for update;
    if not found then
        raise exception 'unknown delivery id: %', p_delivery_id;
    end if;
    -- The answer belongs to one request of one delivery. A status for another delivery's request,
    -- or for an earlier attempt's, never touches this one.
    if v_d.provider_request_id is distinct from p_request_id then
        raise exception 'request % is not the provider request of delivery %',
            p_request_id, p_delivery_id
            using errcode = 'invalid_parameter_value';
    end if;
    -- A repeated SUCCESS for the request that made it `sent` changes nothing and records nothing.
    if v_d.delivery_status_code = 'sent' and p_request_status = 'SUCCESS' then
        return 'sent';
    end if;
    if v_d.delivery_status_code <> 'ingested' then
        raise exception 'delivery % is % -- only an ingested delivery can record a provider status',
            p_delivery_id, v_d.delivery_status_code;
    end if;

    case p_request_status
        when 'PROCESSING', 'REQUEST_STATUS_UNKNOWN' then
            -- Not terminal. UNKNOWN fails closed: never sent, resolved by a later status or by the
            -- deadline.
            update public.offline_conversion_deliveries
            set provider_status_code = p_request_status,
                provider_status_payload = p_response,
                provider_checked_at = now()
            where id = p_delivery_id;
            return 'ingested';

        when 'SUCCESS' then
            update public.offline_conversion_deliveries
            set delivery_status_code = 'sent',
                sent_at = now(),
                provider_status_code = 'SUCCESS',
                provider_status_payload = p_response,
                provider_checked_at = now()
            where id = p_delivery_id;

            perform app.record_event(
                v_d.tenant_id, 'offline_conversion_sent', 'offline_conversion',
                v_d.offline_conversion_id, null,
                'ingested', 'sent', null,
                jsonb_build_object('platform_code', v_d.platform_code,
                                   'attempt_number', v_d.attempt_number,
                                   'delivery_id', p_delivery_id,
                                   'provider_request_id', p_request_id),
                'info'
            );
            return 'sent';

        else
            -- FAILED, or PARTIAL_SUCCESS, which a one-event request cannot legitimately return:
            -- not sent, and re-claimable under the same transaction identity.
            update public.offline_conversion_deliveries
            set delivery_status_code = 'failed',
                failed_at = now(),
                provider_status_code = p_request_status,
                provider_status_payload = p_response,
                provider_checked_at = now(),
                error_message = 'PROVIDER_' || p_request_status || ': the provider reported '
                                || p_request_status || ' for request ' || p_request_id
            where id = p_delivery_id;

            perform app.record_event(
                v_d.tenant_id, 'offline_conversion_failed', 'offline_conversion',
                v_d.offline_conversion_id, null,
                'ingested', 'failed', 'PROVIDER_' || p_request_status,
                jsonb_build_object('platform_code', v_d.platform_code,
                                   'attempt_number', v_d.attempt_number,
                                   'delivery_id', p_delivery_id,
                                   'provider_request_id', p_request_id,
                                   'provider_status', p_request_status),
                'warning'
            );
            return 'failed';
    end case;
end;
$function$;

revoke execute on function app.record_conversion_provider_status(uuid, text, text, jsonb) from public, authenticated;
grant execute on function app.record_conversion_provider_status(uuid, text, text, jsonb) to orvion_integration;
