-- Phase-8 Activation Closure: PH8-4 -- a qualified Google Ads call is the `qualified_phone_call`
-- conversion, and it reaches delivery only with a recorded consent and something to match on.
--
-- MEASURED at `6c48fbb`, rolled back:
--   * a `google_ads_call` lead with a consented click, qualified through `app.advance_lead`, became
--     `qualified_lead` -- the phone call counted under the Qualified Lead action;
--   * a `google_ads_call` lead with no click became nothing: the mapper requires a click;
--   * `app.claim_conversion_deliveries` returned `customers.primary_phone` as stored, which the table
--     accepts as `01001234567`, `00201001234567`, `+0100` or `callmemaybe`;
--   * no customer-level consent exists; `customers.marketing_opt_in` is an undated boolean.
--
-- THE SHAPE. The owner's decision (register PH8-4, 2026-09-28): ONE qualification fact. The mapper's
-- `lead_qualified` arm classifies by the lead's first-touch `lead_source_code`, which
-- `leads_forbid_acquisition_lineage_rewrite` already freezes: `google_ads_call` gives
-- `qualified_phone_call` INSTEAD OF `qualified_lead`. `offline_conversions.source_event_seq` stays
-- unique, so one event can never become both. Such a conversion is formed without a click.
--   * E.164: `app.e164_phone` is the single authority. It reuses `app.normalize_phone` and returns a
--     value only when it already IS E.164 -- no country is stored anywhere, so a local number is never
--     given a guessed prefix. The claim returns its result; nothing downstream normalizes.
--   * Consent: `public.customer_consents`, append-only, customer- and purpose-scoped, explicit
--     `granted`/`denied`, with channel, evidence, the server's actor and time. One writer,
--     `app.record_customer_consent`; one reader, `app.customer_consent_status`: the latest record of
--     the LOGICAL customer -- the survivor and every identity merged into it -- by `seq`, none meaning
--     unspecified. A call, a phone number, a lead or a qualification is never consent.
--   * Merge (ADR-0019's documented exclusion): consent evidence is never re-pointed or rewritten, so
--     the merge excludes the table and the reader follows `customer_identity_merges` instead. A newer
--     DENIED on a merged identity therefore still beats an older GRANTED on the survivor.
--   * Delivery: a `qualified_phone_call` is claimable only when it came from a real event, its
--     customer's latest `ad_user_data` consent is `granted`, and it carries an identifier. Click
--     identifiers are returned only under their own click's consent. Every other conversion is
--     claimed exactly as before. A conversion that is not eligible stays in `offline_conversions`.
--
-- NOT CHANGED: every other mapper arm and its click requirement, the lease, the retry ceiling,
-- `app.record_offline_conversion`, `customers`, every existing grant and policy. No telephony, no
-- call duration, no Google wire format: `eventSource`, hashing and the payload stay at the delivery
-- edge.

-- ===========================================================================================
-- 1. The E.164 authority.
-- ===========================================================================================
create function app.e164_phone(p_value text)
returns text
language sql
immutable
set search_path to ''
as $fn$
    select v from (select app.normalize_phone(p_value) as v) n
    where v ~ '^\+[1-9][0-9]{6,14}$'
$fn$;

revoke execute on function app.e164_phone(text) from public;

-- ===========================================================================================
-- 2. The consent record (AUDIT-4, first slice).
-- ===========================================================================================
-- Not subscription-gated, like the audit spine: a customer's withdrawal must be recordable whatever
-- the tenant's billing state. ORDER is `seq`, never time: `created_at` is the recording
-- transaction's start (`now()`), evidence only; `seq` is allocated at INSERT, after the writer holds
-- the customer's row lock until commit, so decisions serialized on that lock take `seq` in the order
-- they were serialized.
create table public.customer_consents (
    id                  uuid primary key default gen_random_uuid(),
    seq                 bigint generated always as identity unique,
    tenant_id           uuid not null references public.tenants (id) on delete restrict,
    customer_id         uuid not null,
    purpose_code        text not null check (purpose_code in ('ad_user_data')),
    consent_status_code text not null check (consent_status_code in ('granted', 'denied')),
    channel_code        text not null,
    evidence            text check (evidence is null or btrim(evidence) <> ''),
    created_by          uuid,
    created_at          timestamptz not null default now(),
    foreign key (tenant_id, customer_id) references public.customers (tenant_id, id) on delete restrict,
    foreign key (tenant_id, created_by) references public.users (tenant_id, id) on delete restrict
);

create index customer_consents_current_idx
    on public.customer_consents (tenant_id, customer_id, purpose_code, seq desc);

alter table public.customer_consents enable row level security;
revoke all on table public.customer_consents from anon, authenticated;
grant select on table public.customer_consents to authenticated;
create policy tenant_isolation on public.customer_consents
    for select to authenticated
    using (tenant_id = (select app.current_tenant_id()));

create trigger customer_consents_append_only
    before update or delete on public.customer_consents
    for each row execute function app.forbid_mutation();
-- The actor is the session's, by the same trigger every attributed table uses.
create trigger customer_consents_derive_created_by
    before insert or update on public.customer_consents
    for each row execute function app.derive_created_by();
create trigger customer_consents_enforce_catalog_codes
    before insert or update on public.customer_consents
    for each row execute function app.enforce_catalog_codes('channel_code', 'channel_code');

-- The writer. The actor and the time are the server's; the caller supplies neither.
create function app.record_customer_consent(
    p_customer_id uuid,
    p_purpose_code text,
    p_consent_status_code text,
    p_channel_code text,
    p_evidence text default null)
returns uuid
language plpgsql
security definer
set search_path to ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid := app.current_user_id();
    v_survivor uuid;
    v_id uuid;
begin
    if v_tenant is null or v_actor is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('CREATE_CUSTOMER');

    -- The lock serializes every decision for this customer, and a merge (which takes it FOR UPDATE),
    -- so `seq`, allocated by the INSERT below, follows that serial order.
    perform 1 from public.customers
     where id = p_customer_id and tenant_id = v_tenant
     for no key update;
    if not found then
        raise exception 'customer is not in your tenant';
    end if;
    -- Read under the lock: a merged identity takes no new decisions, so every later decision for the
    -- logical customer is serialized on the survivor's row.
    select m.target_customer_id into v_survivor
      from public.customer_identity_merges m
     where m.tenant_id = v_tenant and m.source_customer_id = p_customer_id;
    if found then
        raise exception 'customer was merged into % -- record consent for the surviving customer', v_survivor;
    end if;

    insert into public.customer_consents
        (tenant_id, customer_id, purpose_code, consent_status_code, channel_code, evidence)
    values
        (v_tenant, p_customer_id, p_purpose_code, p_consent_status_code, p_channel_code,
         nullif(btrim(p_evidence), ''))
    returning id into v_id;
    return v_id;
end;
$fn$;

revoke execute on function app.record_customer_consent(uuid, text, text, text, text) from public;
grant execute on function app.record_customer_consent(uuid, text, text, text, text) to authenticated;

create function public.record_customer_consent(
    p_customer_id uuid,
    p_purpose_code text,
    p_consent_status_code text,
    p_channel_code text,
    p_evidence text default null)
returns uuid
language sql
set search_path to ''
as $fn$ select app.record_customer_consent(p_customer_id => p_customer_id, p_purpose_code => p_purpose_code, p_consent_status_code => p_consent_status_code, p_channel_code => p_channel_code, p_evidence => p_evidence); $fn$;

revoke execute on function public.record_customer_consent(uuid, text, text, text, text) from public;
grant execute on function public.record_customer_consent(uuid, text, text, text, text) to authenticated;

-- The reader: the latest record, by `seq`, of the logical customer -- the survivor the given id was
-- merged into, and every identity merged into that survivor, however many merges deep -- or NULL:
-- unspecified, never granted. Any member's id gives the same answer.
create function app.customer_consent_status(p_tenant_id uuid, p_customer_id uuid, p_purpose_code text)
returns text
language sql
stable
set search_path to ''
as $fn$
    with recursive up(id) as (
        select p_customer_id
        union
        select m.target_customer_id
          from public.customer_identity_merges m join up on m.source_customer_id = up.id
         where m.tenant_id = p_tenant_id
    ), survivor(id) as (
        select up.id from up
         where not exists (select 1 from public.customer_identity_merges m
                            where m.tenant_id = p_tenant_id and m.source_customer_id = up.id)
    ), members(id) as (
        select id from survivor
        union
        select m.source_customer_id
          from public.customer_identity_merges m join members on m.target_customer_id = members.id
         where m.tenant_id = p_tenant_id
    )
    select c.consent_status_code
      from public.customer_consents c
     where c.tenant_id = p_tenant_id and c.purpose_code = p_purpose_code
       and c.customer_id in (select id from members)
     order by c.seq desc
     limit 1
$fn$;

revoke execute on function app.customer_consent_status(uuid, uuid, text) from public;

-- ===========================================================================================
-- 3. The customer merge excludes consent evidence (ADR-0019's documented route); its body is
--    otherwise unchanged.
-- ===========================================================================================
create or replace function app.merge_customer_identity(p_source_customer_id uuid, p_target_customer_id uuid, p_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
    v_tenant uuid := app.current_tenant_id();
    v_actor uuid;
    v_src_archived boolean;
    v_target_archived boolean;
    r record;
    v_sql text;
begin
    if v_tenant is null then raise exception 'no active tenant for caller'; end if;
    perform app.authorize('MERGE_CUSTOMER_IDENTITY');
    -- Lock both identities before reading lifecycle state. A consistent order prevents opposite
    -- merges from validating stale row versions and archiving both survivors (ADR-0019).
    perform 1 from public.customers
     where tenant_id = v_tenant and id in (p_source_customer_id, p_target_customer_id)
     order by id for update;
    if p_source_customer_id = p_target_customer_id then
        raise exception 'source and target customer must differ';
    end if;
    select is_archived into v_src_archived from public.customers
     where id = p_source_customer_id and tenant_id = v_tenant;
    if not found then raise exception 'source customer is not in your tenant'; end if;
    if v_src_archived then raise exception 'source customer is already archived (merged?)'; end if;
    select is_archived into v_target_archived from public.customers
     where id = p_target_customer_id and tenant_id = v_tenant;
    if not found then raise exception 'target customer is not in your tenant'; end if;
    if v_target_archived then raise exception 'target customer is already archived'; end if;
    select id into v_actor from public.users
     where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    -- Resolve the two uniqueness collisions that are normal when duplicate identities are merged:
    -- the survivor keeps an existing value and its primary designation; a source-only value is
    -- retained but demoted when the target already has a primary of that type.
    delete from public.customer_contact_methods s
     where s.tenant_id=v_tenant and s.customer_id=p_source_customer_id
       and exists (select 1 from public.customer_contact_methods t
                    where t.tenant_id=v_tenant and t.customer_id=p_target_customer_id
                      and t.contact_method_type_code=s.contact_method_type_code and t.value=s.value);
    update public.customer_contact_methods s set is_primary=false
     where s.tenant_id=v_tenant and s.customer_id=p_source_customer_id and s.is_primary
       and exists (select 1 from public.customer_contact_methods t
                    where t.tenant_id=v_tenant and t.customer_id=p_target_customer_id
                      and t.contact_method_type_code=s.contact_method_type_code and t.is_primary);

    for r in
        select cl.relname as tbl,
               max(a.attname) filter (where fa.attname = 'id') as customer_col,
               max(a.attname) filter (where fa.attname = 'tenant_id') as tenant_col
        from pg_constraint c
        join pg_class cl on cl.oid = c.conrelid
        join pg_namespace n on n.oid = cl.relnamespace
        join unnest(c.conkey) with ordinality lk(attnum,ord) on true
        join unnest(c.confkey) with ordinality fk(attnum,ord) on fk.ord=lk.ord
        join pg_attribute a on a.attrelid=c.conrelid and a.attnum=lk.attnum
        join pg_attribute fa on fa.attrelid=c.confrelid and fa.attnum=fk.attnum
        where c.contype='f' and c.confrelid='public.customers'::regclass
          -- ADR-0019's documented exclusions: the merge record itself, and consent evidence, which is
          -- never rewritten -- `app.customer_consent_status` follows the merge record instead (PH8-4).
          and n.nspname='public' and cl.relname not in ('customer_identity_merges', 'customer_consents')
        group by c.oid,cl.relname
    loop
        if r.customer_col is null then
            raise exception 'merge aborted: the foreign key on public.% has no column referencing customers.id', r.tbl;
        end if;
        v_sql := format('update public.%I set %I=$1 where %I=$2',r.tbl,r.customer_col,r.customer_col);
        if r.tenant_col is not null then
            v_sql := v_sql || format(' and %I=$3',r.tenant_col);
            execute v_sql using p_target_customer_id,p_source_customer_id,v_tenant;
        else
            execute v_sql using p_target_customer_id,p_source_customer_id;
        end if;
    end loop;
    insert into public.customer_identity_merges(tenant_id,source_customer_id,target_customer_id,merged_by,reason)
    values(v_tenant,p_source_customer_id,p_target_customer_id,v_actor,p_reason);
    update public.customers set is_archived=true,archived_at=now(),archived_by=v_actor,
      archive_reason=coalesce(p_reason,'merged into '||p_target_customer_id::text),updated_at=now()
      where id=p_source_customer_id;
    perform app.record_event(v_tenant,'customer_identity_merged','customer',p_target_customer_id,v_actor,null,null,p_reason,
      jsonb_build_object('source_customer_id',p_source_customer_id,'target_customer_id',p_target_customer_id),'critical');
    return p_target_customer_id;
end;
$function$;

-- ===========================================================================================
-- 4. The mapper classifies; the claim gates. Both bodies are otherwise unchanged.
-- ===========================================================================================
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

create or replace function app.claim_conversion_deliveries(p_platform_code text, p_batch integer DEFAULT 50)
 RETURNS TABLE(delivery_id uuid, conversion_id uuid, tenant_id uuid, conversion_event_type_code text, conversion_value numeric, currency_code text, conversion_at timestamp with time zone, gclid text, gbraid text, wbraid text, consent_ad_user_data text, consent_ad_personalization text, customer_phone text, customer_email text, attempt_number integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
          and not exists (
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
           nd.attempt_number
    from new_deliveries nd
    join public.offline_conversions oc on oc.id = nd.offline_conversion_id
    left join public.attribution_clicks ac on ac.id = oc.attribution_click_id;
end;
$function$;
