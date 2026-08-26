-- WP-03 post-package discovery -- fixing two CROSS-TENANT ABORT defects that SPEC-152 introduced.
--
-- SPEC-152 attached `app.enforce_subscription_write_gate` to 42 tenant-scoped tables. The gate
-- raises `insufficient_privilege` when a tenant's subscription does not permit writes. That is
-- correct for a user-facing write, which is one tenant's own action -- but WRONG for a batch or
-- set-based system path that spans tenants, because an unhandled exception aborts the WHOLE
-- statement or function, not just the offending row. One lapsed tenant then denies service to every
-- other tenant. Neither defect is visible by reading the gate; both were found by asking which
-- SECURITY DEFINER functions write a gated table.
--
-- DEFECT 1 -- app.process_lead_sla.
--   It loops `for r in select l.id, l.tenant_id ... from public.leads l where lead_status_code =
--   'assigned'` with NO tenant filter (it is SECURITY DEFINER, so RLS does not scope it), and inside
--   the loop writes `lead_assignments`, `leads` and `notifications` -- all gated. The first
--   restricted tenant reached raises, the exception is unhandled, and the entire SLA run rolls back.
--   Every tenant's SLA warnings and auto-reassignments stop because one unrelated tenant lapsed.
--
-- DEFECT 2 -- app.map_outcomes_to_conversions (the n8n outbox mapper).
--   Its `insert into public.offline_conversions ... select` is a single set-based statement over a
--   batch of events that spans tenants. A BEFORE trigger fires per row, so one restricted tenant's
--   row aborts the whole INSERT -- and because the abort happens before
--   `update public.integration_cursors`, the cursor never advances. The conversion pipeline then
--   stalls PERMANENTLY for all tenants, re-reading the same poisoned batch on every run. This
--   breaks the Phase-8 integration contract (`MASTER_INTEGRATION_CATALOG.md §2`) rather than merely
--   delaying it.
--
-- FIX -- skip, do not raise. Both paths now consult `app.subscription_allows_write` themselves and
-- exclude non-writable tenants BEFORE the gate can fire. The gate is unchanged and remains the
-- backstop; this only stops system paths from walking into it on another tenant's behalf. The
-- business reading is also the right one: a lapsed tenant receives no SLA automation and generates
-- no new ad conversions, while every other tenant is unaffected.
--
-- Deliberate consequence, recorded rather than hidden: conversions whose source events occur while a
-- tenant is restricted are skipped, and the cursor advances past them, so they are not created
-- retroactively on reactivation. Preferred over stalling the shared pipeline. A tenant in
-- `grace_period` is writable, so an ordinary billing lapse does not lose conversions.

-- ---------------------------------------------------------------------------------------------
-- 1. process_lead_sla -- skip tenants that cannot be written to.
-- ---------------------------------------------------------------------------------------------
create or replace function app.process_lead_sla(
    p_warn_after     interval default '00:15:00'::interval,
    p_reassign_after interval default '00:30:00'::interval
)
returns table(lead_id uuid, action text)
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    r record;
    v_cur_id uuid;
    v_cur_user uuid;
    v_cur_at timestamptz;
    v_warned boolean;
    v_elapsed interval;
    v_next uuid;
    m record;
begin
    for r in
        select l.id, l.tenant_id, l.branch_id, l.department_id
        from public.leads l
        where l.lead_status_code = 'assigned'
    loop
        -- SPEC-152 gate awareness. Without this the first restricted tenant raises and the entire
        -- multi-tenant run rolls back -- see this migration's header.
        if not app.subscription_allows_write(r.tenant_id) then
            continue;
        end if;

        select la.id, la.assigned_user_id, la.assigned_at
          into v_cur_id, v_cur_user, v_cur_at
        from public.lead_assignments la
        where la.lead_id = r.id and la.is_current
        order by la.assigned_at desc
        limit 1;
        if v_cur_id is null then
            continue;
        end if;

        v_elapsed := now() - v_cur_at;
        v_warned := exists (
            select 1 from public.events e
            where e.entity_type = 'lead' and e.entity_id = r.id
              and e.event_type_code = 'lead_sla_warning'
              and e.created_at >= v_cur_at
        );

        if v_elapsed >= p_reassign_after and v_warned then
            select u.id into v_next
            from public.users u
            join public.user_branch_assignments uba
                on uba.user_id = u.id
               and uba.tenant_id = r.tenant_id
               and uba.branch_id = r.branch_id
               and uba.department_id = r.department_id
               and uba.ends_at is null
            left join lateral (
                select max(la2.assigned_at) as last_at
                from public.lead_assignments la2
                where la2.assigned_user_id = u.id and la2.tenant_id = r.tenant_id
            ) x on true
            where u.is_active and u.id <> v_cur_user
            order by x.last_at asc nulls first, u.id asc
            limit 1;

            if v_next is not null then
                update public.lead_assignments
                set is_current = false, unassigned_at = now()
                where id = v_cur_id;

                insert into public.lead_assignments (
                    tenant_id, lead_id, assigned_user_id, assigned_by, assignment_reason, is_current
                )
                values (r.tenant_id, r.id, v_next, null, 'SLA auto-reassignment', true);

                update public.leads
                set assigned_user_id = v_next, owner_user_id = v_next
                where id = r.id;

                perform app.record_event(
                    r.tenant_id, 'lead_reassigned', 'lead', r.id, null, 'assigned', 'assigned',
                    'SLA auto-reassignment (no qualifying interaction)',
                    jsonb_build_object('from_user_id', v_cur_user, 'to_user_id', v_next), 'warning'
                );

                insert into public.notifications (
                    tenant_id, target_user_id, notification_type_code, title, body,
                    related_entity_type, related_entity_id
                )
                values (
                    r.tenant_id, v_next, 'lead_reassigned', 'Lead reassigned to you',
                    'An SLA-overdue lead was reassigned to you.', 'lead', r.id
                );

                lead_id := r.id; action := 'reassigned'; return next;
            end if;

        elsif v_elapsed >= p_warn_after and not v_warned then
            perform app.record_event(
                r.tenant_id, 'lead_sla_warning', 'lead', r.id, null, null, null,
                'No qualifying interaction within SLA window',
                jsonb_build_object('assigned_user_id', v_cur_user), 'warning'
            );

            insert into public.notifications (
                tenant_id, target_user_id, notification_type_code, title, body,
                related_entity_type, related_entity_id
            )
            values (
                r.tenant_id, v_cur_user, 'lead_sla_warning', 'Lead SLA warning',
                'A lead assigned to you has had no qualifying interaction within the SLA window.',
                'lead', r.id
            );

            for m in
                select distinct ura.user_id
                from public.user_role_assignments ura
                join public.roles rr on rr.id = ura.role_id
                where ura.tenant_id = r.tenant_id and ura.is_active
                  and rr.code in ('branch_manager', 'department_manager')
                  and (ura.branch_id = r.branch_id or ura.department_id = r.department_id)
                  and ura.user_id <> v_cur_user
            loop
                insert into public.notifications (
                    tenant_id, target_user_id, notification_type_code, title, body,
                    related_entity_type, related_entity_id
                )
                values (
                    r.tenant_id, m.user_id, 'lead_sla_warning', 'Team lead SLA warning',
                    'A lead in your team has breached its SLA window.', 'lead', r.id
                );
            end loop;

            lead_id := r.id; action := 'warned'; return next;
        end if;
    end loop;
end;
$fn$;

-- `create or replace` preserves the existing ACL; both lines are stated explicitly so the intended
-- caller is visible in the migration rather than inherited silently. This job is scheduled, so its
-- caller is `service_role`, not `orvion_integration`.
revoke execute on function app.process_lead_sla(interval, interval) from public;
grant  execute on function app.process_lead_sla(interval, interval) to service_role;

-- ---------------------------------------------------------------------------------------------
-- 2. map_outcomes_to_conversions -- exclude non-writable tenants from the set-based INSERT so the
--    statement cannot abort and the cursor still advances.
-- ---------------------------------------------------------------------------------------------
create or replace function app.map_outcomes_to_conversions(p_batch integer default 500)
returns integer
language plpgsql
security definer
set search_path = ''
as $fn$
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
      -- SPEC-152 gate awareness. One restricted tenant's row would otherwise abort this whole
      -- set-based INSERT and leave `integration_cursors` un-advanced, stalling the mapper for every
      -- tenant on every subsequent run.
      and app.subscription_allows_write(r.tenant_id)
    on conflict (source_event_seq) where source_event_seq is not null do nothing;

    get diagnostics v_inserted = row_count;

    update public.integration_cursors
    set last_seq = v_max_seq, updated_at = now()
    where name = 'outcome_conversion_mapper';

    return v_inserted;
end;
$fn$;

revoke execute on function app.map_outcomes_to_conversions(integer) from public;
grant  execute on function app.map_outcomes_to_conversions(integer) to orvion_integration;
