-- CONV-11 -- Batch 6 slice 10 (`events`).
--
-- THE RULE. `app.map_outcomes_to_conversions` reads conversion source events past its cursor and
-- moves the cursor to the highest seq it read. A seq is taken when the event is inserted, but the
-- event becomes visible only when its transaction commits, so seqs do not become visible in order.
-- Measured before this migration (two sessions, local stack): session A recorded `lead_qualified`
-- for lead L1 (seq 129) and held its transaction open; session B recorded `lead_qualified` for L2
-- (seq 130) and committed; the mapper ran, mapped L2 and moved the cursor to 130; A committed; the
-- next run mapped nothing. L1's qualification never became a conversion, and nothing recorded
-- that it was lost. The same holds for `booking_created`, `payment_recorded` and `booking_issued`.
--
-- THE REPAIR. Every conversion source event is recorded under the shared form of one advisory lock,
-- held to its commit, and the mapper takes the exclusive form only for the instant it reads its
-- horizon (the highest committed seq). Granted, it proves no source writer is open, so every source
-- seq up to the horizon has ended and any later one is taken after it; the run maps only up to the
-- horizon. Refused, the run maps nothing and the next run retries from the same cursor: a delay,
-- never a loss. The lock is never held while the mapper writes, so it cannot deadlock with a
-- writer's row locks, and a writer waits at most for one read of `max(seq)`.
--
-- NOT CHANGED: every grant, policy, table and index; every other line of both functions, among them
-- `record_event`'s authority, validation and insert, and the mapper's window, deferral, recovery
-- and cursor update. No event type, severity or payload changes.
create or replace function app.record_event(p_tenant_id uuid, p_event_type_code text, p_entity_type text, p_entity_id uuid, p_actor_user_id uuid DEFAULT NULL::uuid, p_previous_state text DEFAULT NULL::text, p_new_state text DEFAULT NULL::text, p_reason text DEFAULT NULL::text, p_payload jsonb DEFAULT NULL::jsonb, p_severity_code text DEFAULT 'info'::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
    v_event          uuid;
    v_session_tenant uuid := app.current_tenant_id();
    v_tenant         uuid;
    v_actor          uuid;
begin
    -- Tenant and actor authority. A user session may only ever write into its own tenant, as
    -- itself; a system path (no session) supplies the tenant and may not name a human actor.
    if v_session_tenant is not null then
        if p_tenant_id is distinct from v_session_tenant then
            raise exception 'record_event: tenant % is not the caller''s tenant %',
                p_tenant_id, v_session_tenant
                using errcode = 'insufficient_privilege';
        end if;
        v_tenant := v_session_tenant;
        v_actor  := app.current_user_id();
    else
        if p_tenant_id is null then
            raise exception 'record_event: no active tenant and no tenant supplied'
                using errcode = 'insufficient_privilege';
        end if;
        if p_actor_user_id is not null then
            raise exception 'record_event: a system-context event may not name an actor'
                using errcode = 'insufficient_privilege';
        end if;
        v_tenant := p_tenant_id;
        v_actor  := null;
    end if;

    if not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'event_type' and code = p_event_type_code
    ) then
        raise exception 'unknown event_type_code: % (register it in 27_event_catalog.md + the event_type catalog first)', p_event_type_code;
    end if;
    if not exists (
        select 1 from public.catalog_values
        where catalog_type_code = 'event_severity_code' and code = p_severity_code
    ) then
        raise exception 'unknown severity_code: %', p_severity_code;
    end if;

    -- CONV-11: a conversion source event takes its seq under the shared form of the mapper's lock
    -- and keeps it to commit, so the mapper never takes its horizon while such a writer is open.
    if p_event_type_code in ('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued') then
        perform pg_advisory_xact_lock_shared(hashtextextended('app.map_outcomes_to_conversions', 0));
    end if;

    -- created_at is intentionally not in the column list: it is the server-side default, so no
    -- caller -- RPC or direct -- can backdate an event.
    insert into public.events (
        tenant_id, event_type_code, severity_code, actor_user_id, entity_type, entity_id,
        previous_state, new_state, reason, payload
    )
    values (
        v_tenant, p_event_type_code, p_severity_code, v_actor, p_entity_type, p_entity_id,
        p_previous_state, p_new_state, p_reason, p_payload
    )
    returning id into v_event;
    return v_event;
end;
$function$;

create or replace function app.map_outcomes_to_conversions(p_batch integer DEFAULT 500)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
    v_cursor bigint;
    v_max_seq bigint;
    v_inserted integer := 0;
    v_horizon bigint;
begin
    -- CONV-11: the horizon. Every conversion source event is written under the shared form of this
    -- lock (`app.record_event`), held to its commit, so the exclusive form is granted only when no
    -- such writer is open: every source seq up to the highest committed seq has then ended, and
    -- any later one is taken after it. The lock is held only to read that seq, never while this
    -- run writes, so it cannot deadlock with a writer's row locks; when a writer is open this run
    -- maps nothing and the next run retries from the same cursor.
    if not pg_try_advisory_lock(hashtextextended('app.map_outcomes_to_conversions', 0)) then
        return 0;
    end if;
    begin
        select coalesce(max(seq), 0) into v_horizon from public.events;
    exception when others then
        perform pg_advisory_unlock(hashtextextended('app.map_outcomes_to_conversions', 0));
        raise;
    end;
    perform pg_advisory_unlock(hashtextextended('app.map_outcomes_to_conversions', 0));
    select last_seq into v_cursor
    from public.integration_cursors
    where name = 'outcome_conversion_mapper'
    for update;

    begin
        -- The forward window, exactly as before. Deferred seqs are all BELOW the cursor, so they
        -- cannot influence where the cursor lands.
        select max(sub.seq) into v_max_seq from (
            select e.seq from public.events e
            where e.seq > v_cursor
              and e.seq <= v_horizon
              and e.event_type_code in
                  ('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued')
            order by e.seq
            limit p_batch
        ) sub;

        with candidate as (
            select e.seq
            from public.events e
            where e.seq > v_cursor
              and e.seq <= v_horizon
              and e.event_type_code in
                  ('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued')
            order by e.seq
            limit p_batch
        ),
        -- CONV-1: everything a previous run deferred whose tenant may be written again. Bounded by
        -- the recorded set, which is empty in normal operation and self-limiting otherwise -- unlike
        -- a "re-scan history for events with no conversion row" sweep, whose permanently
        -- unconvertible remainder grows without bound.
        recovered as (
            select f.source_seq as seq
            from public.scheduled_job_findings f
            where f.job_name = 'map_outcomes_to_conversions'
              and f.finding_type_code = 'item_deferred'
              and f.resolved_at is null
              and f.source_seq is not null
              and app.subscription_allows_write(f.tenant_id)
            order by f.source_seq
            limit p_batch
        ),
        due as (
            select seq from candidate
            union
            select seq from recovered
        ),
        batch as (
            select e.seq, e.tenant_id, e.event_type_code, e.entity_type, e.entity_id, e.payload,
                   e.created_at
            from public.events e
            join due d on d.seq = e.seq
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
                        when b.event_type_code = 'payment_recorded'
                        then coalesce(p.booking_id, pinv.booking_id) end
                        as booking_id,
                   case when b.event_type_code = 'payment_recorded' then p.amount end as conv_value,
                   case when b.event_type_code = 'payment_recorded' then p.currency_code end
                        as conv_ccy
            from batch b
            left join public.bookings bk
                   on b.event_type_code = 'booking_issued' and bk.id = b.entity_id
            left join public.payments p
                   on b.event_type_code = 'payment_recorded' and p.id = b.entity_id
            -- CONV-7: the invoice the payment paid, as its own event records it.
            left join public.invoices pinv
                   on b.event_type_code = 'payment_recorded'
                  and pinv.id = (b.payload ->> 'invoice_id')::uuid
                  and pinv.tenant_id = b.tenant_id
            left join public.bookings pbk
                   on pbk.id = coalesce(p.booking_id, pinv.booking_id)
                  and pbk.tenant_id = b.tenant_id
        )
        insert into public.offline_conversions
            (tenant_id, lead_id, booking_id, payment_id, attribution_click_id,
             conversion_event_type_code, conversion_value, currency_code,
             conversion_at, source_event_seq,
             customer_id, customer_email, customer_phone)
        select r.tenant_id, l.id, r.booking_id, r.payment_id, l.attribution_click_id,
               k.conversion_type, r.conv_value, r.conv_ccy, r.created_at, r.seq,
               cu.id, cu.primary_email, cu.primary_phone
        from resolved r
        join public.leads l on l.id = r.lead_id
        -- PH8-4: ONE qualification fact. A lead whose first-touch source is a Google Ads call is
        -- the phone-call conversion INSTEAD OF the lead one -- never both, since one event is one
        -- row -- and it is formed without a click.
        cross join lateral (
            select case when r.conversion_type = 'qualified_lead'
                         and l.lead_source_code = 'google_ads_call'
                        then 'qualified_phone_call'
                        else r.conversion_type end as conversion_type
        ) k
        left join public.customers cu
               on cu.id = l.customer_id and cu.tenant_id = r.tenant_id
        where (l.attribution_click_id is not null or k.conversion_type = 'qualified_phone_call')
          -- SPEC-152 gate awareness. One restricted tenant's row would otherwise abort this whole
          -- set-based INSERT and leave `integration_cursors` un-advanced, stalling the mapper for
          -- every tenant on every subsequent run. What the filter must NOT do is lose the row --
          -- see the deferral recorded below.
          and app.subscription_allows_write(r.tenant_id)
        on conflict (source_event_seq) where source_event_seq is not null do nothing;

        get diagnostics v_inserted = row_count;

        -- CONV-1, the half that was missing: record what the gate filtered out, BEFORE the cursor
        -- moves past it. Restricted only -- an event whose lead carries no attribution click was
        -- never a conversion and is not deferred work.
        perform app.record_job_finding(
                    'map_outcomes_to_conversions', 'item_deferred', d.tenant_id, 'event', null,
                    d.seq, null,
                    'subscription state did not permit writes when this event was first mapped')
        from (
            select e.seq, e.tenant_id
            from public.events e
            where e.seq > v_cursor
              and e.seq <= v_max_seq
              and e.event_type_code in
                  ('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued')
              and not app.subscription_allows_write(e.tenant_id)
        ) d;

        -- Anything now carried into offline_conversions is done, whichever run mapped it.
        update public.scheduled_job_findings f
           set resolved_at = now(),
               resolution_note = 'the conversion was mapped on a later run'
         where f.job_name = 'map_outcomes_to_conversions'
           and f.finding_type_code = 'item_deferred'
           and f.resolved_at is null
           and exists (select 1 from public.offline_conversions oc
                        where oc.source_event_seq = f.source_seq);

        -- A deferral whose tenant is writable again and which STILL produced no conversion was not
        -- deferred work at all -- the lead carries no attribution click, so it was never eligible.
        -- Closed rather than retried forever, which is what would grow this table without bound.
        update public.scheduled_job_findings f
           set resolved_at = now(),
               resolution_note = 'reconsidered while writable; this event maps to no attributed lead'
         where f.job_name = 'map_outcomes_to_conversions'
           and f.finding_type_code = 'item_deferred'
           and f.resolved_at is null
           and app.subscription_allows_write(f.tenant_id)
           and not exists (select 1 from public.offline_conversions oc
                            where oc.source_event_seq = f.source_seq);

        if v_max_seq is not null then
            update public.integration_cursors
            set last_seq = v_max_seq, updated_at = now()
            where name = 'outcome_conversion_mapper';
        end if;

    exception when others then
        -- The cursor is deliberately NOT advanced here: an un-advanced cursor means the batch is
        -- retried, which is the safe failure. What must not happen is the failure being invisible.
        perform app.record_job_finding(
            'map_outcomes_to_conversions', 'item_failed', null, 'integration_cursor', null,
            v_cursor, sqlstate, sqlerrm);
        return 0;
    end;

    return coalesce(v_inserted, 0);
end;
$function$;
