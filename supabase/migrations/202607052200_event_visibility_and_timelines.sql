-- Migration: event_visibility_and_timelines
-- Plan reference: SPEC-143. Scopes the audit trail to match the records it describes, and provides
-- the Customer 360 / Lead 360 timeline primitives.
--
-- THE DEFECT. SPEC-137 scoped every operational table by branch, department and assignment. The
-- `events` table was left on its original tenant-only policy -- so an employee in Cairo could not
-- read an Alexandria booking, but could read the entire event stream describing it: every status
-- change, every reassignment, every reason, and every `payload` those RPCs wrote. The audit trail
-- was a complete bypass of the read model, and the more thoroughly the entities were scoped the
-- more the events stood out as the way around it.
--
-- THE FIX IS UNIFORM, WHICH IS WHY IT IS TRUSTWORTHY. Every one of the 22 `entity_type` values the
-- RPCs actually emit corresponds to a real table that already carries RLS. So the policy needs no
-- judgement about which events are sensitive: an event is readable exactly when its SUBJECT is
-- readable, dispatched by `entity_type`. RLS applies inside each `exists`, so each event inherits
-- its subject's scope automatically -- and keeps inheriting it when that table's policy changes,
-- rather than drifting into a second, stale copy of the rule.
--
-- Events remain append-only (migration 043300's trigger) and immutable. This changes who may READ
-- them and nothing else.
--
-- ONE DELIBERATE ADDITION beyond subject visibility: an actor can always read their own actions.
-- Without it an employee loses sight of what they themselves did the moment a record moves to
-- another branch, which is the opposite of an audit trail.

do $$
declare
    v_dispatch text;
    v_predicate text;
    r record;
begin
    -- entity_type -> the table that owns that record. Every value the RPCs emit is covered; anything
    -- unrecognised falls through to tenant-wide readers only, so a new entity type added later is
    -- private by default rather than public by default.
    select string_agg(
               format('when %L then exists (select 1 from public.%I x where x.id = public.events.entity_id)',
                      t.et, t.tbl), ' ')
      into v_dispatch
    from (values
        ('lead','leads'), ('booking','bookings'), ('booking_item','booking_items'),
        ('quotation','quotations'), ('conversation','conversations'), ('complaint','complaints'),
        ('service_request','service_requests'), ('task','tasks'),
        ('invoice','invoices'), ('payment','payments'), ('refund','refunds'), ('receipt','receipts'),
        ('journal_entry','journal_entries'),
        ('customer','customers'), ('passenger','passengers'), ('supplier','suppliers'),
        ('document','documents'), ('marketing_campaign','marketing_campaigns'),
        ('attribution_click','attribution_clicks'), ('offline_conversion','offline_conversions'),
        ('branch','branches'), ('department','departments'), ('user','users')
    ) as t(et, tbl);

    v_predicate := format(
        'tenant_id = (select app.current_tenant_id()) and ('
        '  (select app.has_tenant_wide_read())'
        '  or actor_user_id = (select app.current_user_id())'
        '  or (case entity_type %s else false end)'
        ')', v_dispatch);

    execute 'drop policy if exists audit_read on public.events';
    execute format('create policy audit_read on public.events for select to authenticated using (%s)', v_predicate);
end
$$;

-- `security_events` is deliberately NOT given the same treatment. It records authentication,
-- permission changes and risk flags -- the material a tenant administrator investigates, and the
-- material an ordinary employee has no business browsing. It is restricted to tenant-wide readers
-- outright rather than dispatched by subject, because "who can see this security event" is not the
-- same question as "who can see the record it concerns".
drop policy if exists audit_read on public.security_events;
create policy audit_read on public.security_events for select to authenticated
using (tenant_id = (select app.current_tenant_id()) and (select app.has_tenant_wide_read()));

-- ---------------------------------------------------------------------------------------------
-- Customer 360 and Lead 360.
--
-- The owner's requirement is that "Show me everything that ever happened with this customer, in
-- chronological order" be answerable deterministically. Two properties make it so, and both already
-- existed: `events` carries `(entity_type, entity_id)` with a matching index, and `seq` gives a
-- total order that does not degrade when two events share a timestamp -- ordering by `created_at`
-- alone would leave same-instant events in an arbitrary order, which is exactly the case a
-- multi-step RPC produces.
--
-- These are SECURITY INVOKER, so the policy above filters them. A user assembling a customer
-- timeline sees the parts of it they are entitled to and no more -- the timeline is not a second
-- read path around the scope model.
-- ---------------------------------------------------------------------------------------------
create or replace function app.customer_timeline(p_customer_id uuid)
returns table (
    seq bigint,
    occurred_at timestamptz,
    event_type_code text,
    entity_type text,
    entity_id uuid,
    actor_user_id uuid,
    previous_state text,
    new_state text,
    reason text,
    payload jsonb
)
language sql
stable
security invoker
set search_path = ''
as $$
    with subject as (
        select 'customer'::text as et, c.id as eid from public.customers c where c.id = p_customer_id
        union all select 'lead', l.id from public.leads l where l.customer_id = p_customer_id
        union all select 'booking', b.id from public.bookings b where b.customer_id = p_customer_id
        union all select 'booking_item', bi.id from public.booking_items bi
                    join public.bookings b on b.id = bi.booking_id where b.customer_id = p_customer_id
        union all select 'quotation', q.id from public.quotations q where q.customer_id = p_customer_id
        union all select 'invoice', i.id from public.invoices i where i.customer_id = p_customer_id
        union all select 'payment', pm.id from public.payments pm where pm.customer_id = p_customer_id
        union all select 'refund', rf.id from public.refunds rf where rf.customer_id = p_customer_id
        union all select 'conversation', cv.id from public.conversations cv where cv.customer_id = p_customer_id
        union all select 'complaint', cp.id from public.complaints cp where cp.customer_id = p_customer_id
        union all select 'service_request', sr.id from public.service_requests sr where sr.customer_id = p_customer_id
        union all select 'passenger', pg.id from public.passengers pg where pg.customer_id = p_customer_id
    )
    select e.seq, e.created_at, e.event_type_code, e.entity_type, e.entity_id, e.actor_user_id,
           e.previous_state, e.new_state, e.reason, e.payload
    from public.events e
    join subject s on s.et = e.entity_type and s.eid = e.entity_id
    where e.tenant_id = app.current_tenant_id()
    order by e.seq
$$;
revoke execute on function app.customer_timeline(uuid) from public;
grant execute on function app.customer_timeline(uuid) to authenticated;

create or replace function app.lead_timeline(p_lead_id uuid)
returns table (
    seq bigint,
    occurred_at timestamptz,
    event_type_code text,
    entity_type text,
    entity_id uuid,
    actor_user_id uuid,
    previous_state text,
    new_state text,
    reason text,
    payload jsonb
)
language sql
stable
security invoker
set search_path = ''
as $$
    with subject as (
        select 'lead'::text as et, l.id as eid from public.leads l where l.id = p_lead_id
        union all select 'quotation', q.id from public.quotations q where q.lead_id = p_lead_id
        union all select 'conversation', cv.id from public.conversations cv where cv.lead_id = p_lead_id
        union all select 'attribution_click', ac.id from public.attribution_clicks ac where ac.lead_id = p_lead_id
        union all select 'offline_conversion', oc.id from public.offline_conversions oc where oc.lead_id = p_lead_id
    )
    select e.seq, e.created_at, e.event_type_code, e.entity_type, e.entity_id, e.actor_user_id,
           e.previous_state, e.new_state, e.reason, e.payload
    from public.events e
    join subject s on s.et = e.entity_type and s.eid = e.entity_id
    where e.tenant_id = app.current_tenant_id()
    order by e.seq
$$;
revoke execute on function app.lead_timeline(uuid) from public;
grant execute on function app.lead_timeline(uuid) to authenticated;
