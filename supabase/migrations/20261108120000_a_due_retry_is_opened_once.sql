-- SPEC-298 (Batch 6 Slice 43, ND-1) -- a due retry is opened once, however many dispatchers claim
-- at the same moment.
--
-- =================================================================================================
-- THE MEASURED DEFECT
--
-- `app.claim_notification_deliveries` says "two concurrent dispatchers safe". Its step 3 (the
-- claim) is, by `for update ... skip locked`. Its step 2 (open the due retry) is not: the
-- `not exists` that stops a second retry cannot see another dispatcher's UNCOMMITTED attempt N+1,
-- and nothing made (notification_id, channel_code, attempt_number) unique -- the chain index that
-- serves the retry read was a plain index.
--
-- Measured 2026-11-08 at a21a0ec on the local stack: one `email` delivery at attempt 1, failed six
-- minutes earlier, so its retry was due. Session A ran `begin; claim('email',50); pg_sleep(4);
-- commit;` and session B ran `claim('email',50)` 1.5 s later. The chain ended `1 failed, 2 pending
-- claimed, 2 pending claimed`, and each session's claim returned the notification once: the
-- recipient is sent the same message twice. The sleep only widens the window; any two overlapping
-- calls may interleave this way.
--
-- =================================================================================================
-- THE REPAIR, AND WHY THIS SHAPE
--
-- 1. The attempt number is unique per chain: a UNIQUE CONSTRAINT on (notification_id,
--    channel_code, attempt_number) replaces the plain chain index, which it makes redundant (the
--    retry read still walks the same columns, backwards). A second attempt N on any path -- the
--    claim, a producer, the platform -- is refused 23505. Every producer writes attempt 1 for a
--    notification it has just created, once (read from the catalog), so none can collide.
-- 2. Step 2 names that constraint in `on conflict ... do nothing`. A second dispatcher whose
--    insert meets the first one's uncommitted attempt N+1 WAITS for it; if the first commits, the
--    second inserts nothing and goes on to claim other work; if the first rolls back, the second
--    opens the retry itself. A constraint rather than a bare unique index because the function's
--    own OUT parameters are named `notification_id` and `attempt_number`, so a column-list
--    conflict target would be ambiguous inside PL/pgSQL; `on constraint` is not.
--
-- Everything else in the function is the 202607060900 body unchanged, step 2 aside: the lease, the ceiling,
-- the backoff, the claim, the payload. `create or replace` keeps its owner and its grants
-- (EXECUTE for `orvion_integration` only).
--
-- WHAT IS DELIBERATELY NOT CHANGED, each recorded as a position in the disposition record:
--   * `app.record_notification_delivery_result` accepts a result for a pending row no dispatcher
--     claimed; only `orvion_integration` can call it. Reopening trigger: a second integration
--     identity.
--   * A send that outlives the 30-minute lease is failed and retried, so a slow provider can still
--     receive the message twice. That is the lease trade-off SPEC-123 chose and this table copied.
--   * `notification_deliveries_notification_id_idx` is now covered by the key's leading column. It
--     is left alone: removing it is housekeeping, not this finding.
--
-- Primary: a duplicate (notification_id, channel_code, attempt_number) already stored there would
-- make `add constraint` fail, and the whole migration with it, before anything changes. The
-- readiness gate reads Primary for one before deployment.

alter table public.notification_deliveries
    add constraint notification_deliveries_attempt_key
    unique (notification_id, channel_code, attempt_number);

drop index public.notification_deliveries_chain_idx;

comment on constraint notification_deliveries_attempt_key on public.notification_deliveries is
    'SPEC-298 (ND-1): one row per attempt number per chain, so two dispatchers can never both open attempt N+1. Named by the on-conflict clause of app.claim_notification_deliveries step 2.';

create or replace function app.claim_notification_deliveries(
    p_channel_code text,
    p_batch integer default 50
)
returns table (
    delivery_id            uuid,
    notification_id        uuid,
    tenant_id              uuid,
    attempt_number         integer,
    recipient_user_id      uuid,
    recipient_email        text,
    recipient_name         text,
    notification_type_code text,
    title                  text,
    body                   text,
    related_entity_type    text,
    related_entity_id      uuid
)
language plpgsql
security definer
set search_path = ''
as $$
declare
    -- The lease. Identical to SPEC-123's, and identical for the same reason: it is long enough that
    -- a healthy run never trips it and short enough that a dead run is recovered within one
    -- operator's attention span.
    c_lease        constant interval := interval '30 minutes';
    -- The ceiling. NOT re-derived from external practice -- this is the number SPEC-123 already
    -- chose for this repository's outbox, and two outboxes disagreeing about how many times ORVION
    -- tries before giving up would be a difference with no reason behind it.
    c_max_attempts constant integer  := 5;
    -- The backoff base. 5 * 2^(n-1) => 5, 10, 20, 40 minutes; the fifth attempt falls about 75
    -- minutes after the first failure. Widening rather than immediate, which is the one point on
    -- which transactional-email practice is unanimous and on which SPEC-123's no-backoff model
    -- cannot be copied.
    c_backoff_base constant interval := interval '5 minutes';
    v_row record;
begin
    if p_channel_code is null then
        raise exception 'p_channel_code is required';
    end if;
    if p_batch is null or p_batch < 1 then
        raise exception 'p_batch must be at least 1';
    end if;

    -- ---------------------------------------------------------------------------------------------
    -- STEP 0 -- expire leases. A run that died between claim and acknowledgement leaves a row
    -- `pending` with `claimed_at` set and no result. Without this it is stranded for ever, which is
    -- PH8-1's defect on the conversion side, avoided here rather than repeated.
    for v_row in
        update public.notification_deliveries d
        set delivery_status_code = 'failed',
            failed_at = now(),
            error_message = 'LEASE_EXPIRED: no delivery result recorded within ' || c_lease::text
                            || '; attempt terminated by app.claim_notification_deliveries'
        where d.channel_code = p_channel_code
          and d.delivery_status_code = 'pending'
          and d.claimed_at is not null
          and d.claimed_at < now() - c_lease
        returning d.id, d.tenant_id, d.notification_id, d.attempt_number
    loop
        perform app.record_event(
            v_row.tenant_id, 'notification_delivery_failed', 'notification', v_row.notification_id,
            null, 'pending', 'failed',
            'LEASE_EXPIRED: no delivery result recorded within the lease window',
            jsonb_build_object('delivery_id', v_row.id, 'channel_code', p_channel_code,
                               'attempt_number', v_row.attempt_number, 'expired_lease', true,
                               'lease_interval', c_lease::text),
            'warning');
    end loop;

    -- ---------------------------------------------------------------------------------------------
    -- STEP 1 -- dead-letter the exhausted. A chain is exhausted when its newest attempt has FAILED
    -- and that attempt is the ceiling. Marked terminal so step 2 stops re-opening it and so the row
    -- states that ORVION gave up, rather than leaving an operator to infer it from a count.
    for v_row in
        update public.notification_deliveries d
        set delivery_status_code = 'dead_lettered'
        where d.channel_code = p_channel_code
          and d.delivery_status_code = 'failed'
          and d.attempt_number >= c_max_attempts
          and not exists (
                select 1 from public.notification_deliveries later
                where later.notification_id = d.notification_id
                  and later.channel_code = d.channel_code
                  and later.attempt_number > d.attempt_number)
        returning d.id, d.tenant_id, d.notification_id, d.attempt_number, d.error_message
    loop
        perform app.record_event(
            v_row.tenant_id, 'notification_delivery_dead_lettered', 'notification',
            v_row.notification_id, null, 'failed', 'dead_lettered',
            'Delivery abandoned after exhausting its retry ceiling',
            jsonb_build_object('delivery_id', v_row.id, 'channel_code', p_channel_code,
                               'attempts', v_row.attempt_number,
                               'last_error', v_row.error_message),
            'warning');
    end loop;

    -- ---------------------------------------------------------------------------------------------
    -- STEP 2 -- open the retries that are due. A new ROW at attempt N+1, never a mutation of the
    -- failed one: the failure and its own error message stay on the record.
    --
    -- SPEC-298 (ND-1): the `not exists` below cannot see another dispatcher's uncommitted attempt
    -- N+1, so the unique key decides: the insert waits on that key and skips it once taken.
    --
    -- `not exists (pending or sent or dead_lettered)` is the whole eligibility rule and it is
    -- deliberately expressed over the chain rather than over this row: it stops a second retry being
    -- opened while one is in flight, stops retrying something already delivered, and stops reviving
    -- something step 1 has just abandoned.
    insert into public.notification_deliveries
        (tenant_id, notification_id, channel_code, delivery_status_code, attempt_number)
    select d.tenant_id, d.notification_id, d.channel_code, 'pending', d.attempt_number + 1
    from public.notification_deliveries d
    where d.channel_code = p_channel_code
      and d.delivery_status_code = 'failed'
      and d.attempt_number < c_max_attempts
      and d.failed_at is not null
      -- The backoff, DERIVED rather than stored. This expression is the single authority for the
      -- retry schedule in the whole system.
      and d.failed_at + (c_backoff_base * (2 ^ (d.attempt_number - 1))) <= now()
      and not exists (
            select 1 from public.notification_deliveries other
            where other.notification_id = d.notification_id
              and other.channel_code = d.channel_code
              and (other.attempt_number > d.attempt_number
                   or other.delivery_status_code in ('pending', 'sent', 'dead_lettered')))
    on conflict on constraint notification_deliveries_attempt_key do nothing;

    -- ---------------------------------------------------------------------------------------------
    -- STEP 3 -- claim. `for update ... skip locked` is what makes two concurrent dispatchers safe:
    -- the second call skips rows the first has locked instead of blocking behind them or handing
    -- back the same work twice.
    --
    -- The ORDER BY sits INSIDE the locking sub-select, which is the form PostgreSQL's own Caution
    -- note about `ORDER BY` with a locking clause at READ COMMITTED recommends.
    --
    -- `claimed_at is null` -- not `< now() - lease` -- because step 0 has already converted every
    -- expired lease into a failure, so anything still pending and claimed is genuinely in flight.
    return query
    with claimed as (
        update public.notification_deliveries d
        set claimed_at = now()
        where d.id in (
            select c.id
            from public.notification_deliveries c
            where c.channel_code = p_channel_code
              and c.delivery_status_code = 'pending'
              and c.claimed_at is null
            order by c.created_at, c.id
            limit p_batch
            for update skip locked
        )
        returning d.id, d.notification_id, d.tenant_id, d.attempt_number
    )
    select c.id, c.notification_id, c.tenant_id, c.attempt_number,
           n.target_user_id, u.email, u.full_name,
           n.notification_type_code, n.title, n.body,
           n.related_entity_type, n.related_entity_id
    from claimed c
    join public.notifications n on n.id = c.notification_id
    join public.users u on u.id = n.target_user_id;
end;
$$;

-- `create or replace` kept the ACL; restated so the grant model is visible in this file too.
revoke execute on function app.claim_notification_deliveries(text, integer) from public;
grant execute on function app.claim_notification_deliveries(text, integer) to orvion_integration;
