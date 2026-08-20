-- Migration: conversion_delivery_lease (resolves PH8-1 — SPEC-123)
-- PH8-1: a delivery claimed but never acked stayed 'pending' forever. Because
-- app.claim_conversion_deliveries excludes any conversion holding a 'pending' or 'sent'
-- delivery, an n8n run interrupted between Claim and Ack (deploy, timeout, credential
-- expiry, rate-limit abort, platform incident) stranded its conversion permanently: never
-- re-claimed, never retried, never acked, never counted as failed, and invisible to the
-- retry ceiling (which counts delivery rows, not outcomes). Silent, unbounded
-- revenue-attribution loss with no operator signal. Reproduced against the live local
-- database before this fix (SPEC-123 Execution Log).
--
-- Fix: the standard outbox lease / visibility timeout. A 'pending' delivery holds a lease
-- that starts at created_at (the row is INSERTed at claim time, so created_at IS the claim
-- instant — no new column is needed). Before claiming, this function terminalizes every
-- pending delivery for the platform whose lease has expired, moving it to 'failed' with an
-- explicit LEASE_EXPIRED marker and emitting the canonical offline_conversion_failed event.
--
-- Why terminalize to 'failed' rather than add an 'expired' status or reclaim in place:
--   * 'failed' is already in the offline_conversion_delivery_status catalog (043100) — no new
--     status vocabulary, no canon change, and no bypass of the guard in test 08.
--   * The existing retry machinery then applies UNCHANGED: the conversion becomes claimable
--     again (the 'pending'/'sent' exclusion no longer matches), the existing retire_failed CTE
--     retires the row to 'retried' when the next attempt is claimed, and the fixed ceiling of
--     5 delivery rows still counts the expired attempt — so a crashed worker CONSUMES an
--     attempt and can never bypass the retry limit.
--   * If the ceiling is already exhausted the expired row simply stays 'failed' — a correct,
--     visible terminal state, rather than a row that looks in-flight forever.
--   * A 'sent' delivery is never touched: only rows currently 'pending' can expire, so a
--     successful delivery can never be turned back into claimable work.
--   * A late "zombie" ack from the crashed run now raises ('delivery % is failed — only
--     pending deliveries can be resolved') instead of marking a reclaimed conversion 'sent'.
--     That is the intended protection; the n8n contract documents it (Integration Catalog §2).
--
-- Concurrency: the expiry UPDATE takes row locks and re-evaluates delivery_status_code =
-- 'pending' under READ COMMITTED, so of two concurrent workers exactly one transitions a given
-- row and only that one sees it in RETURNING — events cannot be double-emitted. Claiming
-- itself is unchanged and still serialized by `for update of oc skip locked` on the
-- offline_conversions row, so two workers can never claim the same conversion.
--
-- Lease duration — derived, not arbitrary (full reasoning: SPEC-123 §Lease derivation):
-- worst-case legitimate run is p_batch (50) rows x ~5 s/row of HTTP + ack ~= 5 min; the n8n
-- workflow is required to set its own `Timeout Workflow` to 10 min (n8n Cloud's own maximum
-- is plan-dependent and must not be relied on); 30 min is 3x that enforced timeout and 6x the
-- realistic worst case, so a still-running worker can never have its rows reclaimed underneath
-- it (which would double-deliver to Google). Recovery latency is at most the lease plus one
-- 15-minute schedule tick (~45 min), far inside Google's offline-conversion ingestion window.
-- INVARIANT to preserve if any of these change: lease > workflow timeout > worst-case run.
-- Kept as a function-local constant rather than a parameter so an orchestrator cannot weaken
-- the safety property from outside (same rationale as the fixed retry ceiling of 5 above it).

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
               failed_at = now(),
               error_message = 'LEASE_EXPIRED: no delivery result recorded within '
                               || c_lease::text || '; attempt terminated by app.claim_conversion_deliveries'
         where d.platform_code = p_platform_code
           and d.delivery_status_code = 'pending'
           and d.created_at < now() - c_lease
        returning d.id, d.tenant_id, d.offline_conversion_id, d.attempt_number
    loop
        perform app.record_event(
            v_expired.tenant_id,
            'offline_conversion_failed',
            'offline_conversion',
            v_expired.offline_conversion_id,
            null,
            'pending',
            'failed',
            'LEASE_EXPIRED: no delivery result recorded within the lease window',
            jsonb_build_object('platform_code', p_platform_code,
                               'attempt_number', v_expired.attempt_number,
                               'delivery_id', v_expired.id,
                               'expired_lease', true,
                               'lease_interval', c_lease::text),
            'warning'
        );
    end loop;

    -- Step 1: claim (unchanged from 202607049200 — the expiry above is what makes a
    -- stranded conversion visible to this query again).
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
        -- previous failed attempt (including a LEASE_EXPIRED one) becomes 'retried' the
        -- moment a new attempt is claimed; error_message is preserved for the audit trail
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
           cu.primary_phone, cu.primary_email,
           nd.attempt_number
    from new_deliveries nd
    join public.offline_conversions oc on oc.id = nd.offline_conversion_id
    left join public.attribution_clicks ac on ac.id = oc.attribution_click_id
    left join public.leads l on l.id = oc.lead_id
    left join public.customers cu on cu.id = l.customer_id;
end;
$$;

-- Partial index for the lease sweep. Added on measured evidence, not assumption: the expiry
-- predicate runs on every claim (every 15 min, forever) against a table that only ever grows
-- (one row per delivery attempt, never deleted). Measured on this database with 200k delivery
-- rows (EXPLAIN ANALYZE, synthetic rows, rolled back — SPEC-123 Verification Notes):
--   without index -> Parallel Seq Scan, 2858 buffers, 57.0 ms   (grows without bound)
--   with index    -> Index Scan,           37 buffers,  0.173 ms
-- The index stays tiny because it is PARTIAL on the in-flight set only: 16 kB against a 22 MB
-- table, since 'pending' rows are bounded by (runs in flight x batch), not by history.
create index if not exists offline_conversion_deliveries_pending_lease_idx
    on public.offline_conversion_deliveries (platform_code, created_at)
    where delivery_status_code = 'pending';

-- Grants are preserved by CREATE OR REPLACE; re-stated explicitly to keep the privilege
-- surface readable in one place and identical to 202607049200.
revoke execute on function app.claim_conversion_deliveries(text, integer) from public, authenticated;
grant execute on function app.claim_conversion_deliveries(text, integer) to orvion_integration;
