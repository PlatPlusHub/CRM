-- SPEC-233: CONV-7 -- a payment conversion finds its lead through the invoice it paid.
--
-- `app.map_outcomes_to_conversions` turns `payment_recorded` into the `payment_received` offline
-- conversion, the only one of ORVION's Google Ads conversion actions that carries revenue. It found
-- the payment's lead through `payments.booking_id -> bookings.lead_id`. `app.record_payment`, the
-- only producer of `payment_recorded`, pays an INVOICE and never sets `payments.booking_id`, so on
-- the sanctioned path the lead was always NULL and the conversion was dropped without a trace:
-- MEASURED at `3759ef7` -- a booking on a lead with a consented Google Ads click, invoiced, issued
-- and paid in full through the RPCs, emitted `payment_recorded` and produced `booking_created` and
-- `ticket_issued` conversions, and no `payment_received`.
--
-- The event already names the invoice (`payload.invoice_id`, written by `app.record_payment`), and
-- the invoice names its booking. The mapper now follows that, exactly as `booking_created` already
-- follows `payload.lead_id`. `payments.booking_id` still wins where it is set, and it is NOT
-- written here: `app.customer_balance`, `app.booking_item_profit` and `app.supplier_balance` read
-- it, so populating it would change per-booking balances and the negative-balance issuance check.
-- Nothing else in the mapper changes.

create or replace function app.map_outcomes_to_conversions(p_batch integer default 500)
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
    v_cursor bigint;
    v_max_seq bigint;
    v_inserted integer := 0;
begin
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
              and e.event_type_code in
                  ('lead_qualified', 'booking_created', 'payment_recorded', 'booking_issued')
            order by e.seq
            limit p_batch
        ) sub;

        with candidate as (
            select e.seq
            from public.events e
            where e.seq > v_cursor
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
               r.conversion_type, r.conv_value, r.conv_ccy, r.created_at, r.seq,
               cu.id, cu.primary_email, cu.primary_phone
        from resolved r
        join public.leads l on l.id = r.lead_id
        left join public.customers cu
               on cu.id = l.customer_id and cu.tenant_id = r.tenant_id
        where l.attribution_click_id is not null
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
