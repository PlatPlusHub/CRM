-- P3 (DELIV-2) -- the notification delivery ledger records an obligation and nothing ever executes,
-- retries or abandons it.
--
-- =================================================================================================
-- THE MEASURED STATE THIS CLOSES
--
-- `public.notification_deliveries` at 197 migrations: id, tenant_id, notification_id, channel_code,
-- delivery_status_code, sent_at, failed_at, error_message, created_at. Two producers
-- (`app.evaluate_customer_credit_threshold`, `app.evaluate_supplier_credit_threshold`) insert
-- `pending` rows on the `email` channel. **Nothing reads the table. Nothing ever moves a row off
-- `pending`.** A row written today stays `pending` for ever, and no surface distinguishes "not yet
-- attempted" from "attempted and lost" from "given up on".
--
-- =================================================================================================
-- THE PRECEDENT IS FOLLOWED, AND WHERE IT IS NOT THE REASON IS STATED
--
-- `app.claim_conversion_deliveries` / `app.record_conversion_delivery_result` (SPEC-123) are the
-- in-house outbox, and `MASTER_INTEGRATION_CATALOG.md §2/§2a` is the n8n contract already written
-- against them. This migration deliberately produces the SAME SHAPE so the workflow layer has one
-- pattern rather than two: `claim_*(target, batch)` returns rows carrying a `delivery_id` plus the
-- payload; `record_*_result(delivery_id, success, response, error)` acknowledges exactly one row;
-- a late acknowledgement RAISES rather than silently succeeding.
--
-- FOUR THINGS ARE COPIED VERBATIM IN INTENT: one row per ATTEMPT (not a counter on a shared row);
-- a lease swept at claim time by the same call that claims; a retry ceiling of **5**, the number
-- SPEC-123 already chose, reused rather than re-derived from an external article; and
-- `for update ... skip locked`, which PostgreSQL 17's own documentation sanctions for exactly this
-- shape -- *"Skipping locked rows provides an inconsistent view of the data, so this is not suitable
-- for general purpose work, but can be used to avoid lock contention with multiple consumers
-- accessing a queue-like table."*
--
-- TWO THINGS DEPART, and each departure is forced by a measured difference rather than preferred:
--
--   1. `claimed_at` EXISTS HERE AND NOT THERE. In SPEC-123 the CLAIMER creates the delivery row, so
--      `pending` and `in flight` are the same state and `created_at` is the lease anchor. Here the
--      PRODUCER creates it -- deliberately, because "the obligation is recorded rather than claimed"
--      is what CUST-3 and SUP-4b built and commented at length -- so `pending` means BOTH "never
--      attempted" and "in flight", and the two must be distinguishable or the lease sweep would
--      fail every obligation that had simply not been picked up yet. One column, and it is the
--      minimum that keeps the producer's semantics intact.
--
--   2. RETRIES WAIT. SPEC-123 has no backoff: a failed conversion is re-claimable on the very next
--      run. That is tolerable against an ad platform's batch API and is NOT tolerable for email --
--      retrying a rejected message immediately damages sender reputation and burns provider rate
--      limits, and current transactional-email practice is unanimous that retries must WIDEN. The
--      schedule is `5 minutes * 2^(attempt-1)` -- 5, 10, 20, 40 -- reaching the ceiling of 5
--      attempts about 75 minutes after the first failure.
--
-- =================================================================================================
-- WHAT IS DELIBERATELY NOT ADDED
--
-- NO `next_attempt_at` COLUMN. It would be a stored copy of a value the claim query can derive from
-- the previous attempt's `failed_at` and its `attempt_number`, and storing it puts the retry
-- schedule in two places -- the writer that computes it and the reader that trusts it. Derived here,
-- the schedule has exactly ONE authority: the constant below. **Stated ceiling:** a derived
-- predicate is not directly indexable, so if this table ever grows past the point where the partial
-- index below stops being enough, materialising the column is the upgrade path.
--
-- NO `attempt_count` COUNTER. One row per attempt is the precedent's model and it keeps every
-- attempt's own `error_message`; a counter on a shared row keeps only the last one.
--
-- NO CLAIM TOKEN, NO WORKER IDENTITY, NO HEARTBEAT. n8n runs one scheduled workflow against this
-- contract. A worker-ownership model would be machinery for a fleet that does not exist, and the
-- transaction-scoped row lock plus the lease already make a crashed run recoverable.
--
-- NO PROVIDER ANYWHERE. No provider name, no API shape, no template, no address rewriting, no
-- suppression list. PostgreSQL owns durable delivery STATE; n8n owns dispatch. MAIL-1 (the provider
-- and its Egyptian PDPC cross-border transfer licence) is an owner decision and this migration is
-- deliberately indifferent to how it is answered.
--
-- NO OPERATOR SURFACE. A `dead_lettered` row is now DISTINGUISHABLE, which is what P3 needs to stop
-- retrying it. Making it VISIBLE to an operator is **DELIV-1**, which owns that gap for this table
-- and for SPEC-123's alike, and it is one `reporting` view rather than anything here.

-- =================================================================================================
-- 1. THE TERMINAL STATE. `enforce_catalog_codes` validates `delivery_status_code` against this
--    catalog, so the value must exist before any code can write it.
--
--    SPEC-123 has no equivalent: a conversion that has failed five times is simply never selected
--    again, which is indistinguishable from one that is still waiting. Current practice on
--    transactional email is explicit that a send must never be silently dropped, and the register
--    already carries that complaint as DELIV-1. `dead_lettered` is the smallest thing that makes
--    "we gave up" a fact rather than an absence.

insert into public.catalog_values (tenant_id, catalog_type_code, code, label, description, sort_order, is_system)
values (null, 'notification_delivery_status', 'dead_lettered', 'Dead-lettered',
        'The delivery exhausted its retry ceiling and will not be attempted again. Terminal; requires operator action.',
        5, true);

-- =================================================================================================
-- 2. THE THREE COLUMNS, AND WHAT EACH IS FOR
--
--    `attempt_number`  -- which attempt this row IS. Defaults to 1 so both existing producers keep
--                         working unchanged; neither needs to know this migration happened.
--    `claimed_at`      -- when a dispatcher took this row. NULL = never attempted. Non-null and
--                         still `pending` = in flight, and it is the lease anchor.
--    `response_payload`-- the provider's own record of the send (its message id, typically). The
--                         only durable link between an ORVION row and the provider's console, which
--                         is what an operator needs when asked "did this actually go out?".
--                         SPEC-123 carries the same column for the same reason.

alter table public.notification_deliveries
    add column attempt_number   integer not null default 1,
    add column claimed_at       timestamptz,
    add column response_payload jsonb;

alter table public.notification_deliveries
    add constraint notification_deliveries_attempt_number_positive
    check (attempt_number >= 1);

-- The claim query's access path, and it is the one authoritative guidance on queue tables insists
-- on: a composite index over exactly the columns used to FIND work. Partial, because every row this
-- index exists to find is `pending` and the terminal states are dead weight in it.
create index notification_deliveries_claimable_idx
    on public.notification_deliveries (channel_code, claimed_at, created_at)
    where delivery_status_code = 'pending';

-- The retry path reads the newest attempt per (notification, channel).
create index notification_deliveries_chain_idx
    on public.notification_deliveries (notification_id, channel_code, attempt_number desc);

comment on column public.notification_deliveries.attempt_number is
    'P3: one ROW per attempt, not a counter. Attempt N+1 is a new row, so every attempt keeps its own error_message.';
comment on column public.notification_deliveries.claimed_at is
    'P3: NULL = never attempted. Non-null while pending = in flight, and the anchor for the lease sweep in app.claim_notification_deliveries.';

-- =================================================================================================
-- 3. THE CLAIM. One call performs the whole housekeeping cycle, exactly as SPEC-123 does, so a
--    dispatcher needs no separate maintenance schedule and cannot forget to run one.
--
--      step 0  expire leases      -- in flight past the lease -> failed
--      step 1  dead-letter        -- chains at the ceiling -> terminal, stop retrying
--      step 2  open retries       -- failed chains whose backoff has elapsed -> a new pending row
--      step 3  claim              -- unclaimed pending rows -> stamped and returned
--
--    Steps 0-2 are what make step 3's simple predicate correct. Ordering matters: a lease that
--    expires in step 0 becomes a failure that step 1 or step 2 then judges in the same call.

create function app.claim_notification_deliveries(
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
                   or other.delivery_status_code in ('pending', 'sent', 'dead_lettered')));

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

-- GRANT-1's class. The default ACL grants EXECUTE to PUBLIC on every new function.
revoke execute on function app.claim_notification_deliveries(text, integer) from public;
-- `orvion_integration` is the n8n identity and it holds NO table grants at all -- measured. It
-- reaches this database only through the RPC contract, and that property is preserved here rather
-- than weakened: this is a second RPC for it, not a first table.
grant execute on function app.claim_notification_deliveries(text, integer) to orvion_integration;

-- =================================================================================================
-- 4. THE ACKNOWLEDGEMENT. Deliberately a near-copy of `app.record_conversion_delivery_result`,
--    including the behaviour `MASTER_INTEGRATION_CATALOG.md §2a` item 6 documents as intentional:
--    a LATE ACK RAISES. A run that resumes after its lease expired must not be able to mark as
--    `sent` a row another run has already retried, and the exception is what stops it. The workflow
--    treats that as an expected non-fatal outcome for that row.

create function app.record_notification_delivery_result(
    p_delivery_id uuid,
    p_success     boolean,
    p_response    jsonb default null,
    p_error       text  default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
    v_d record;
begin
    if p_success is null then
        raise exception 'p_success is required -- an unknown outcome must not be recorded as either';
    end if;

    select * into v_d
    from public.notification_deliveries
    where id = p_delivery_id
    for update;

    if not found then
        raise exception 'unknown delivery id: %', p_delivery_id;
    end if;

    if v_d.delivery_status_code <> 'pending' then
        raise exception 'delivery % is % -- only pending deliveries can be resolved',
            p_delivery_id, v_d.delivery_status_code;
    end if;

    update public.notification_deliveries
    set delivery_status_code = case when p_success then 'sent' else 'failed' end,
        sent_at          = case when p_success then now() else sent_at end,
        failed_at        = case when p_success then failed_at else now() end,
        response_payload = p_response,
        error_message    = p_error
    where id = p_delivery_id;

    perform app.record_event(
        v_d.tenant_id,
        case when p_success then 'notification_delivery_sent' else 'notification_delivery_failed' end,
        'notification', v_d.notification_id, null,
        'pending', case when p_success then 'sent' else 'failed' end, p_error,
        jsonb_build_object('delivery_id', p_delivery_id,
                           'channel_code', v_d.channel_code,
                           'attempt_number', v_d.attempt_number),
        case when p_success then 'info' else 'warning' end);
end;
$$;

revoke execute on function app.record_notification_delivery_result(uuid, boolean, jsonb, text) from public;
grant execute on function app.record_notification_delivery_result(uuid, boolean, jsonb, text) to orvion_integration;

-- =================================================================================================
-- 5. THE THREE EVENT TYPES. `app.record_event` REFUSES an unregistered code, so a missing catalog
--    row would make every path above fail closed at runtime rather than silently skip its audit.

insert into public.catalog_values (tenant_id, catalog_type_code, code, label, description, sort_order, is_system)
values
 (null, 'event_type', 'notification_delivery_sent', 'Notification delivered',
  'A notification was successfully dispatched on a channel by the delivery worker.', 0, true),
 (null, 'event_type', 'notification_delivery_failed', 'Notification delivery failed',
  'A delivery attempt failed, or its lease expired before a result was recorded. Retried until the ceiling.', 0, true),
 (null, 'event_type', 'notification_delivery_dead_lettered', 'Notification delivery abandoned',
  'A delivery exhausted its retry ceiling and will not be attempted again. Terminal; requires operator action.', 0, true);
