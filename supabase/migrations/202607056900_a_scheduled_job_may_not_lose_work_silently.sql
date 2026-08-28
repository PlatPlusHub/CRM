-- SCHED-2 / CONV-1 -- scheduled execution: one item may fail, and nothing may be lost silently.
--
-- ================================================================================================
-- THE AUDIT THAT PRODUCED THIS (directive §7, every background path, traced rather than skimmed)
--
-- ORVION runs three pg_cron jobs and three integration-driven batches. Compared side by side:
--
--   job                            | one item aborts all? | failure persisted? | discoverable after?
--   -------------------------------+----------------------+--------------------+--------------------
--   reconcile_document_storage     | NO  (per-tenant       | YES                | YES
--                                  |      exception block) | (tenant_scan_failed)|
--   process_lead_sla               | YES                  | NO                 | NO
--   process_subscription_lifecycle | YES                  | NO                 | NO
--   map_outcomes_to_conversions    | YES (set-based)      | NO                 | NO
--
-- The exemplar was already in the codebase. `app.reconcile_document_storage` wraps each tenant in
-- `begin ... exception when others then ... end`, records a `tenant_scan_failed` finding, resolves
-- that finding when a later scan of the same tenant succeeds, counts failures into its return
-- value, and nests a second handler in case recording the failure itself fails. Its three siblings
-- have none of that. This migration gives them the same properties.
--
-- ================================================================================================
-- CONV-1 -- THE ONE THAT IS NOT LATENT. REPRODUCED BEFORE IT WAS FIXED.
--
-- `app.map_outcomes_to_conversions` filters restricted tenants OUT of its set-based INSERT and then
-- advances `integration_cursors.last_seq` past their events unconditionally. Two tenants, one lead
-- each, both attributed, both with a `lead_qualified` event; tenant B in `read_only`:
--
--     run 1 (B is read_only)      -> inserted 1     conv-good 1 | conv-lapsed 0
--     B restored to good standing
--     run 2                       -> inserted 0     conv-good 1 | conv-lapsed 0
--     run 3                       -> inserted 0     conv-good 1 | conv-lapsed 0
--
-- The conversion is not deferred. It is DESTROYED. A tenant who paid late permanently loses the
-- acquisition-to-revenue lineage that justifies their ad spend -- and it is the one tenant with a
-- commercial reason to care.
--
-- This contradicts three established positions at once:
--   * the owner's GOOGLE ADS requirement -- "Preserve attribution lineage from acquisition through
--     revenue" -- which this package's sibling `202607056700` was written to protect;
--   * canon 28's promise that a restricted tenant's data remains intact for read and export;
--   * WP-03's own meaning of "a batch caller skips a lapsed tenant". Everywhere else that means
--     DEFER: `process_lead_sla` skips and retries a minute later, `platform_resolve_storage_finding`
--     refuses explicitly and the finding stays open. The mapper is the only place where skip means
--     discard, and that is an accident of it owning a cursor -- not a decision anyone recorded.
--
-- So this is a defect, not a business decision: ORVION already decided what "skip" means.
--
-- ================================================================================================
-- WHY A STORE, AND WHY THIS ONE
--
-- Two candidate fixes for CONV-1 were rejected before this one:
--
--   * "Do not advance the cursor past a skipped event." Correct on loss, but converts one tenant's
--     lapse into head-of-line blocking for EVERY tenant -- and a departed tenant would stall the
--     mapper permanently. That is the trade the original author was avoiding, and they were right.
--   * "Re-scan history for conversion events with no `offline_conversions` row." Needs no storage
--     and uses the `source_event_seq` key that already exists -- but the permanently-unconvertible
--     set (events whose lead carries no attribution click) grows without bound and would starve the
--     backfill's own limit. Correct today, degrading forever.
--
-- What is needed is a durable record of WHICH items were not processed. `document_storage_findings`
-- is exactly that shape for storage, and it appears NOWHERE in canon -- it is engineering-owned
-- platform-operational state, created by WP-04 without a canon amendment, because operational
-- health is not business vocabulary. This table is its generalisation to scheduled jobs, and it is
-- deliberately the SAME shape: upsert on a natural key, `last_seen_at`, `attempt_count`,
-- `resolved_at`, self-healing when a later run succeeds.
--
-- `finding_type_code` is a CHECK constraint rather than a catalog family, unlike its model. The
-- storage findings' codes are a domain vocabulary returned to the executor over HTTP; these two are
-- an internal discriminator that is never rendered, never tenant-extended and never sent anywhere.
-- A catalog entry would add registry surface and a smoke-test pin for no reader.
--
-- NOT built, deliberately: no notification, no event type, no alert routing, no dashboard. §8 asks
-- for enough evidence to answer nine questions; a table and a reader answer all nine. Anything more
-- is the enterprise monitoring platform the directive rules out.
-- ================================================================================================

create table if not exists public.scheduled_job_findings (
    id                uuid primary key default gen_random_uuid(),
    job_name          text        not null,
    finding_type_code text        not null
        check (finding_type_code in ('item_failed', 'item_deferred')),
    tenant_id         uuid        references public.tenants (id) on delete restrict,
    entity_type       text,
    entity_id         uuid,
    source_seq        bigint,
    sqlstate          text,
    message           text,
    first_seen_at     timestamptz not null default now(),
    last_seen_at      timestamptz not null default now(),
    attempt_count     integer     not null default 1,
    resolved_at       timestamptz,
    resolution_note   text
);

comment on table public.scheduled_job_findings is
    'Platform-operational record of work a scheduled job could not complete. item_failed: the '
    'iteration raised and was isolated so the rest of the batch survived. item_deferred: the item '
    'was intentionally not processed yet (today, a restricted subscription) and MUST be retried '
    'when the reason clears. Engineering-owned, like public.document_storage_findings, which this '
    'mirrors; not business vocabulary and not in canon. Platform-only: RLS denies every tenant role.';

-- The natural key. Mirrors document_storage_findings' coalesce(storage_path,'') idiom: the upsert
-- must collapse repeated observations of the SAME item into one row with a rising attempt_count,
-- rather than growing a row per cron tick.
create unique index if not exists scheduled_job_findings_identity_idx
    on public.scheduled_job_findings (
        job_name,
        finding_type_code,
        coalesce(tenant_id,  '00000000-0000-0000-0000-000000000000'::uuid),
        coalesce(entity_id,  '00000000-0000-0000-0000-000000000000'::uuid),
        coalesce(source_seq, -1)
    );

create index if not exists scheduled_job_findings_open_idx
    on public.scheduled_job_findings (job_name, finding_type_code, resolved_at)
    where resolved_at is null;

alter table public.scheduled_job_findings enable row level security;

-- SPEC-158's shape, as used by integration_cursors and document_storage_findings: state the intent
-- where a reader looks, rather than leaving RLS enabled with no policy and letting the next engineer
-- "fix" the omission.
drop policy if exists platform_only on public.scheduled_job_findings;
create policy platform_only on public.scheduled_job_findings
    for all to authenticated using (false) with check (false);

revoke all on public.scheduled_job_findings from anon, authenticated;

-- Deliberately NO subscription write gate on this table. A restricted tenant is precisely the case
-- these rows exist to record; a gate here would make the deferral unrecordable for exactly the
-- tenant being deferred.

create or replace function app.record_job_finding(
    p_job         text,
    p_type        text,
    p_tenant_id   uuid    default null,
    p_entity_type text    default null,
    p_entity_id   uuid    default null,
    p_source_seq  bigint  default null,
    p_sqlstate    text    default null,
    p_message     text    default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
begin
    insert into public.scheduled_job_findings
        (job_name, finding_type_code, tenant_id, entity_type, entity_id, source_seq,
         sqlstate, message)
    values (p_job, p_type, p_tenant_id, p_entity_type, p_entity_id, p_source_seq,
            p_sqlstate, left(coalesce(p_message, ''), 2000))
    on conflict (job_name, finding_type_code,
                 coalesce(tenant_id,  '00000000-0000-0000-0000-000000000000'::uuid),
                 coalesce(entity_id,  '00000000-0000-0000-0000-000000000000'::uuid),
                 coalesce(source_seq, -1))
    do update set last_seen_at    = now(),
                  attempt_count   = public.scheduled_job_findings.attempt_count + 1,
                  sqlstate        = excluded.sqlstate,
                  message         = excluded.message,
                  -- Re-observation REOPENS, exactly as re-detection does for a storage finding: an
                  -- item that failed again was not actually resolved, whatever a later pass wrote.
                  resolved_at     = null,
                  resolution_note = null;
exception when others then
    -- Recording the failure failed too. There is nothing left to do but let the caller continue;
    -- the caller's own counter still reports the loss, so it is visible rather than silent.
    null;
end
$fn$;

revoke execute on function app.record_job_finding(text, text, uuid, text, uuid, bigint, text, text) from public;

create or replace function app.resolve_job_finding(
    p_job         text,
    p_type        text,
    p_tenant_id   uuid   default null,
    p_entity_id   uuid   default null,
    p_source_seq  bigint default null,
    p_note        text   default 'a later run processed this item successfully'
)
returns void
language sql
security definer
set search_path = ''
as $fn$
    update public.scheduled_job_findings
       set resolved_at = now(), resolution_note = p_note
     where job_name          = p_job
       and finding_type_code = p_type
       and resolved_at is null
       and coalesce(tenant_id,  '00000000-0000-0000-0000-000000000000'::uuid)
             = coalesce(p_tenant_id, '00000000-0000-0000-0000-000000000000'::uuid)
       and coalesce(entity_id,  '00000000-0000-0000-0000-000000000000'::uuid)
             = coalesce(p_entity_id, '00000000-0000-0000-0000-000000000000'::uuid)
       and coalesce(source_seq, -1) = coalesce(p_source_seq, -1);
$fn$;

revoke execute on function app.resolve_job_finding(text, text, uuid, uuid, bigint, text) from public;

-- ================================================================================================
-- THE READER. `app.storage_action_backlog()`'s counterpart, and deliberately its shape: the whole
-- point of that function is that the monitor and the worker share ONE definition of outstanding
-- work. Here the definition is simply "unresolved", so there is nothing to diverge from.
-- ================================================================================================

create or replace function app.scheduled_job_health()
returns table(
    job_name           text,
    finding_type_code  text,
    open_items         bigint,
    tenants_affected   bigint,
    oldest_open_age    interval,
    last_seen_at       timestamptz,
    max_attempts       integer
)
language sql
stable
security definer
set search_path = ''
as $fn$
    select f.job_name,
           f.finding_type_code,
           count(*)                            as open_items,
           count(distinct f.tenant_id)         as tenants_affected,
           now() - min(f.first_seen_at)        as oldest_open_age,
           max(f.last_seen_at)                 as last_seen_at,
           max(f.attempt_count)                as max_attempts
    from public.scheduled_job_findings f
    where f.resolved_at is null
    group by f.job_name, f.finding_type_code
    order by f.job_name, f.finding_type_code;
$fn$;

revoke execute on function app.scheduled_job_health() from public;
grant  execute on function app.scheduled_job_health() to service_role;

create or replace function public.scheduled_job_health()
returns table(
    job_name           text,
    finding_type_code  text,
    open_items         bigint,
    tenants_affected   bigint,
    oldest_open_age    interval,
    last_seen_at       timestamptz,
    max_attempts       integer
)
language sql
security invoker
set search_path = ''
as $fn$ select * from app.scheduled_job_health(); $fn$;

revoke execute on function public.scheduled_job_health() from public, anon, authenticated;
grant  execute on function public.scheduled_job_health() to service_role;

comment on function public.scheduled_job_health() is
    'Platform operations surface: what scheduled work is outstanding, for how long, over how many '
    'tenants, and how many times it has been attempted. service_role only -- operational state is '
    'not a tenant surface, on the same reasoning as public.storage_action_backlog().';

-- ================================================================================================
-- SCHED-2a -- PER-ITEM ISOLATION FOR process_lead_sla.
--
-- The subscription gate is pre-checked at the top of each iteration (SPEC-152), which handles ONE
-- known raise source. It is a guard shaped to the first instance: any other raise inside the loop
-- body -- a constraint, an FK, a future trigger -- still aborts every tenant's SLA processing, and
-- pg_cron records only "failed" with no indication of which lead. No such raise is reachable today
-- (every write in the body was traced), so this is LATENT; the fix is the isolation property
-- itself rather than an enumeration of today's raise sources, because enumerating them is exactly
-- how this class keeps returning.
-- ================================================================================================

create or replace function app.process_lead_sla(
    p_warn_after     interval default '00:15:00'::interval,
    p_reassign_after interval default '00:30:00'::interval
)
returns table(lead_id uuid, action text)
language plpgsql
security definer
set search_path = ''
as $function$
declare
    r record;
    v_cur_id uuid;
    v_cur_user uuid;
    v_cur_at timestamptz;
    v_warned boolean;
    v_elapsed interval;
    v_next uuid;
    m record;
    v_acted boolean;
begin
    for r in
        select l.id, l.tenant_id, l.branch_id, l.department_id
        from public.leads l
        where l.lead_status_code = 'assigned'
    loop
        -- SPEC-152 gate awareness. Without this the first restricted tenant raises and the entire
        -- multi-tenant run rolls back -- see that migration's header. Kept as a pre-check because a
        -- gated tenant is a DEFERRAL, not a failure: the next minute's pass retries it.
        if not app.subscription_allows_write(r.tenant_id) then
            continue;
        end if;

        v_acted := false;

        begin
            select la.id, la.assigned_user_id, la.assigned_at
              into v_cur_id, v_cur_user, v_cur_at
            from public.lead_assignments la
            where la.lead_id = r.id and la.is_current
            order by la.assigned_at desc
            limit 1;

            if v_cur_id is not null then
                v_elapsed := now() - v_cur_at;
                v_warned := exists (
                    select 1 from public.events e
                    where e.entity_type = 'lead' and e.entity_id = r.id
                      and e.event_type_code = 'lead_sla_warning'
                      and e.created_at >= v_cur_at
                );

                if v_elapsed >= p_reassign_after and v_warned then
                    -- LEAD-3: candidates are those who may WORK a lead, not merely those placed here.
                    select h.user_id into v_next
                    from app.eligible_lead_handlers(
                             r.tenant_id, r.branch_id, r.department_id, v_cur_user) as h(user_id)
                    left join lateral (
                        select max(la2.assigned_at) as last_at
                        from public.lead_assignments la2
                        where la2.assigned_user_id = h.user_id and la2.tenant_id = r.tenant_id
                    ) x on true
                    order by x.last_at asc nulls first, h.user_id asc
                    limit 1;

                    if v_next is not null then
                        update public.lead_assignments
                        set is_current = false, unassigned_at = now()
                        where id = v_cur_id;

                        insert into public.lead_assignments (
                            tenant_id, lead_id, assigned_user_id, assigned_by, assignment_reason,
                            is_current
                        )
                        values (r.tenant_id, r.id, v_next, null, 'SLA auto-reassignment', true);

                        update public.leads
                        set assigned_user_id = v_next, owner_user_id = v_next
                        where id = r.id;

                        perform app.record_event(
                            r.tenant_id, 'lead_reassigned', 'lead', r.id, null, 'assigned',
                            'assigned', 'SLA auto-reassignment (no qualifying interaction)',
                            jsonb_build_object('from_user_id', v_cur_user, 'to_user_id', v_next),
                            'warning'
                        );

                        insert into public.notifications (
                            tenant_id, target_user_id, notification_type_code, title, body,
                            related_entity_type, related_entity_id
                        )
                        values (
                            r.tenant_id, v_next, 'lead_reassigned', 'Lead reassigned to you',
                            'An SLA-overdue lead was reassigned to you.', 'lead', r.id
                        );

                        -- canon 10: "After another 15 minutes without response: Notify reassigned
                        -- employee. NOTIFY MANAGER. Record reassignment event." `v_next` is excluded
                        -- because they have just been told directly above. The OUTGOING assignee is
                        -- not excluded -- so a manager who was also the assignee still receives the
                        -- team notification. Canon requires no separate notice to a departing
                        -- assignee who is not a manager, and one is not invented here.
                        for m in select app.lead_responsible_managers(
                                            r.tenant_id, r.branch_id, r.department_id, v_next)
                                            as user_id
                        loop
                            insert into public.notifications (
                                tenant_id, target_user_id, notification_type_code, title, body,
                                related_entity_type, related_entity_id
                            )
                            values (
                                r.tenant_id, m.user_id, 'lead_reassigned',
                                'Lead reassigned in your team',
                                'An SLA-overdue lead was reassigned to another employee.',
                                'lead', r.id
                            );
                        end loop;

                        lead_id := r.id; action := 'reassigned'; v_acted := true; return next;
                    else
                        -- Nobody in this branch and department may work a lead. The lead STAYS --
                        -- parking it with someone who cannot act on it is worse than leaving it with
                        -- someone who has not. LEAD-4: this is now DURABLE, not merely returned.
                        perform app.record_job_finding(
                            'process_lead_sla', 'item_deferred', r.tenant_id, 'lead', r.id, null,
                            null,
                            'SLA reassignment is due but no active user in this branch and '
                            'department holds CLOSE_LEAD');
                        lead_id := r.id; action := 'reassignment_blocked'; v_acted := true;
                        return next;
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
                        'A lead assigned to you has had no qualifying interaction within the SLA '
                        'window.', 'lead', r.id
                    );

                    -- canon 04 / canon 10: notify the employee's manager. This is the line that
                    -- never fired, because it used to test only
                    -- `user_role_assignments.branch_id/department_id` -- NULL for every assignment
                    -- `app.assign_user_role` creates by default.
                    for m in select app.lead_responsible_managers(
                                        r.tenant_id, r.branch_id, r.department_id, v_cur_user)
                                        as user_id
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

                    lead_id := r.id; action := 'warned'; v_acted := true; return next;
                end if;
            end if;

            -- This lead was handled without raising. Any standing failure for it is now stale.
            -- Deferrals are NOT resolved here: a `reassignment_blocked` lead is re-recorded above on
            -- every due pass, which reopens it, and a lead that becomes handleable resolves through
            -- the reassignment branch instead.
            perform app.resolve_job_finding(
                'process_lead_sla', 'item_failed', r.tenant_id, r.id, null,
                'a later SLA pass processed this lead without error');
            if v_acted and action <> 'reassignment_blocked' then
                perform app.resolve_job_finding(
                    'process_lead_sla', 'item_deferred', r.tenant_id, r.id, null,
                    'the lead was reassigned or warned on a later pass');
            end if;

        exception when others then
            -- SKIP, NEVER RAISE. One lead's failure must not deny every other tenant its SLA
            -- automation for as long as that lead exists. This is reconcile_document_storage's
            -- established pattern, applied to the job that runs every sixty seconds.
            perform app.record_job_finding(
                'process_lead_sla', 'item_failed', r.tenant_id, 'lead', r.id, null,
                sqlstate, sqlerrm);
        end;
    end loop;
end;
$function$;

-- ================================================================================================
-- SCHED-2b -- PER-TENANT ISOLATION FOR process_subscription_lifecycle.
--
-- This one had no isolation of any kind. A single tenant whose transition raised would roll back
-- every other tenant's trial expiry, grace entry and read-only transition for that day -- and the
-- next day's run would meet the same row and do it again. Subscription state is what gates every
-- write in the system, so a stalled lifecycle silently keeps lapsed tenants writable and paying
-- tenants un-renewed.
-- ================================================================================================

create or replace function app.process_subscription_lifecycle()
returns integer
language plpgsql
security definer
set search_path = ''
as $function$
declare
    r          record;
    v_from     text;
    v_to       text;
    v_changed  integer := 0;
    v_ends     timestamptz;
begin
    for r in
        select distinct on (s.tenant_id)
               s.id, s.tenant_id, s.subscription_status_code, s.ends_at, s.grace_ends_at,
               s.billing_period_code, s.auto_renew
        from public.subscriptions s
        order by s.tenant_id, s.created_at desc
    loop
        begin
            v_from := r.subscription_status_code;
            v_to   := null;
            v_ends := null;

            if v_from = 'trial' and r.ends_at is not null and r.ends_at <= now() then
                -- Canon 26: "trial -> expired : Trial ends without activation".
                v_to := 'expired';

            elsif v_from = 'active' and r.ends_at is not null and r.ends_at <= now() then
                if r.auto_renew
                   and app.subscription_period_interval(r.billing_period_code) is not null then
                    -- Renewal rolls the period forward; the state does not change, so this is
                    -- handled here rather than through the transition validator (active -> active
                    -- is not a canon transition, and correctly so).
                    v_ends := r.ends_at + app.subscription_period_interval(r.billing_period_code);
                    update public.subscriptions set ends_at = v_ends where id = r.id;

                    perform app.record_event(
                        r.tenant_id, 'subscription_activated', 'subscription', r.id, null,
                        'active', 'active', 'automatic renewal',
                        jsonb_build_object('billing_period_code', r.billing_period_code,
                                           'ends_at', v_ends));
                    v_changed := v_changed + 1;
                    perform app.resolve_job_finding(
                        'process_subscription_lifecycle', 'item_failed', r.tenant_id, r.id, null,
                        'a later lifecycle run processed this subscription without error');
                    continue;
                end if;
                -- Canon 26: "active -> grace_period : Payment period ends without renewal".
                v_to := 'grace_period';

            elsif v_from = 'grace_period'
                  and r.grace_ends_at is not null and r.grace_ends_at <= now() then
                -- Canon 26: "grace_period -> read_only : Two-day grace period ends".
                v_to := 'read_only';
            end if;

            -- Not due, or in a state this job does not drive (suspended / cancelled / expired /
            -- read_only are all Platform Owner territory).
            if v_to is not null and app.subscription_transition_allowed(v_from, v_to) then
                update public.subscriptions
                   set subscription_status_code = v_to,
                       grace_ends_at = case
                                           when v_to = 'grace_period'
                                           then coalesce(ends_at, now())
                                                + make_interval(days => app.grace_period_days())
                                           else grace_ends_at
                                       end,
                       read_only_started_at = case when v_to = 'read_only' then now()
                                                   else read_only_started_at end
                 where id = r.id;

                perform app.record_event(
                    r.tenant_id, app.subscription_state_event(v_from, v_to), 'subscription', r.id,
                    null, v_from, v_to, 'automatic lifecycle transition', null);

                v_changed := v_changed + 1;
            end if;

            perform app.resolve_job_finding(
                'process_subscription_lifecycle', 'item_failed', r.tenant_id, r.id, null,
                'a later lifecycle run processed this subscription without error');

        exception when others then
            -- SKIP, NEVER RAISE. One tenant's subscription must not decide every other tenant's.
            perform app.record_job_finding(
                'process_subscription_lifecycle', 'item_failed', r.tenant_id, 'subscription', r.id,
                null, sqlstate, sqlerrm);
        end;
    end loop;

    return v_changed;
end;
$function$;

-- ================================================================================================
-- CONV-1 -- map_outcomes_to_conversions: a skipped tenant is DEFERRED, not discarded.
--
-- The cursor still advances (so no tenant's lapse blocks any other tenant's mapping), but every
-- event the gate filtered out is now recorded as `item_deferred` BEFORE the cursor moves past it,
-- and each run reconsiders the deferrals whose tenant can be written again. The conversion is
-- recovered on the first run after the tenant returns to good standing.
--
-- Recovery is safe to repeat because `offline_conversions.source_event_seq` is unique and the
-- INSERT carries `on conflict do nothing` -- the idempotency key this fix leans on already existed.
--
-- The whole body is wrapped so a raise cannot leave the mapper dead and silent; on a raise the
-- cursor is not advanced, so the batch is retried rather than lost.
-- ================================================================================================

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
                        when b.event_type_code = 'payment_recorded' then p.booking_id end
                        as booking_id,
                   case when b.event_type_code = 'payment_recorded' then p.amount end as conv_value,
                   case when b.event_type_code = 'payment_recorded' then p.currency_code end
                        as conv_ccy
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
