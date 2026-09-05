-- LEAD-5 -- the minute-ly SLA job can overlap itself, and the warning branch has nothing to stop it.
--
-- =================================================================================================
-- The whole of this migration is ONE GUARD placed at the top of `app.process_lead_sla`. The body
-- below is otherwise the function as it stands at `1df2f06`, reproduced verbatim from
-- `pg_get_functiondef` rather than retyped, so the diff is exactly the block marked LEAD-5.
--
-- The evidence, the branch-by-branch measurement of what actually breaks, why TRY rather than plain
-- `pg_advisory_xact_lock`, and why the key is the job and not the tenant are all stated inside that
-- block, next to the code they justify, rather than here where a reader of the function would never
-- find them.
--
-- NOT CHANGED, DELIBERATELY: the SLA windows (15 minutes to warn, 30 to reassign) remain the
-- function's DEFAULTS and no configurability is introduced; the clock remains wall-clock from
-- `assigned_at`; the skip-never-raise error handling, the deferral semantics and every notification
-- remain as they were. This closes a concurrency defect and nothing else.

CREATE OR REPLACE FUNCTION app.process_lead_sla(p_warn_after interval DEFAULT '00:15:00'::interval, p_reassign_after interval DEFAULT '00:30:00'::interval)
 RETURNS TABLE(lead_id uuid, action text)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
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
    -- LEAD-5 (202607060800): ONE SLA PASS AT A TIME.
    --
    -- MEASURED: `cron.job` schedules `select app.process_lead_sla()` at `* * * * *`. pg_cron starts
    -- each run on schedule and does NOT wait for the previous one to finish, so any pass that
    -- exceeds sixty seconds runs CONCURRENTLY with its successor. The loop is over every `assigned`
    -- lead in every tenant and does real work per lead, so that is a matter of scale, not of luck.
    --
    -- WHAT ACTUALLY BREAKS, measured per branch rather than asserted for both:
    --   REASSIGNMENT is already protected, and by a constraint rather than by timing.
    --   `lead_assignments_one_current_idx` is UNIQUE on (lead_id) WHERE is_current, so a second
    --   concurrent reassignment of the same lead cannot commit. It fails, and the surrounding
    --   handler records `item_failed` -- degraded and noisy, but never two current assignments.
    --
    --   THE WARNING BRANCH HAS NO SUCH CONSTRAINT. It reads `v_warned` from `events`, then inserts
    --   a `lead_sla_warning` event and one notification per responsible manager. Two passes that
    --   read before either writes BOTH see `v_warned = false` and both write: a duplicate event in
    --   the ledger that the SLA's own idempotency depends on, and duplicate notifications to every
    --   manager. Nothing in the schema forbids it.
    --
    -- THE SMALLEST FIX THAT CLOSES IT IS THE ONE THIS REPOSITORY ALREADY USES. `record_payment`,
    -- `issue_receipt` and `create_invoice` each take `pg_advisory_xact_lock(hashtextextended(...))`
    -- for exactly this class of read-then-write. This is that idiom with the TRY variant, because
    -- the correct behaviour for a scheduled job differs from the correct behaviour for a user
    -- request: a caller who cannot get the lock should WAIT, but a minute-ly job that cannot get the
    -- lock should GIVE UP and let the run already in progress finish. Blocking would queue passes
    -- behind a slow one and make the pile-up worse than the duplicate it prevents.
    --
    -- The lock is transaction-scoped, so it is released on commit or rollback with no unlock path to
    -- forget. It is keyed on the function name and NOT on the tenant: the job's own loop is what
    -- must not overlap, and a per-tenant key would still let two passes interleave inside it.
    --
    -- A skipped pass loses nothing. Every lead is re-examined from durable state on the next minute:
    -- `v_elapsed` is derived from `assigned_at` and `v_warned` from the event ledger, so nothing is
    -- carried in memory between passes and a missed pass is indistinguishable from a slow one.
    if not pg_try_advisory_xact_lock(hashtextextended('app.process_lead_sla', 0)) then
        return;
    end if;

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


-- GRANT-1's class, restated. `create or replace` preserves the existing ACL (`service_role`), so
-- this changes nothing and exists so the property is asserted rather than assumed.
revoke execute on function app.process_lead_sla(interval, interval) from public;
grant execute on function app.process_lead_sla(interval, interval) to service_role;
