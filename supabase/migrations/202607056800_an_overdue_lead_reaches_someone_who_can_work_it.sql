-- LEAD-3 -- resolved, and a defect found underneath it.
--
-- ================================================================================================
-- THE QUESTION AS IT WAS FILED, AND WHY THE FILING WAS THE WRONG SHAPE
--
-- LEAD-3 was recorded on 2026-08-29 as an owner decision: "the SLA reassignment pool includes
-- MANAGERS -- canon 04 says 'reassign to another eligible employee' and defines neither 'eligible'
-- nor whether a manager qualifies."
--
-- Asking the permission matrix instead of asking the word answers it, and answers something bigger.
-- `role_permissions`, live:
--
--     CLOSE_LEAD / CREATE_LEAD / CREATE_QUOTATION / VIEW_DEPARTMENT_QUEUE
--       -> branch_manager, ceo, department_manager, employee, owner, senior_employee
--
-- All four lead-working permissions resolve to the IDENTICAL role set, and managers are in it.
-- So by ORVION's own definition of what it takes to work a lead, a branch or department manager IS
-- an eligible handler -- which also matches how a small Egyptian agency actually runs, where the
-- branch manager sells alongside the team. LEAD-3's stated question is therefore RESOLVED from
-- existing evidence, and the answer is that the current behaviour is correct: managers stay.
--
-- ================================================================================================
-- THE DEFECT THAT WAS UNDERNEATH IT (reproduced before it was fixed)
--
-- The pool was never "eligible employees" at all. It was "everyone PLACED in the branch and
-- department", with no reference to what any of them may do. Live reproduction, one branch, one
-- department, the handler plus a trainee plus a finance manager:
--
--     pass 1  -> warned
--     pass 2  -> reassigned
--     WHO NOW HOLDS THE LEAD:
--         full_name | role    | can_close_lead | can_quote
--         Trainee   | trainee | f              | f
--
-- `trainee` holds exactly two permissions in the whole system -- VIEW_ASSIGNED_LEADS and
-- VIEW_ASSIGNED_TASKS. An SLA-overdue lead, the one case where ORVION intervenes precisely because
-- revenue is at risk, was handed to the one role that cannot quote it, cannot close it and cannot
-- book it. `finance_manager` and `system_administrator` are in the same position and were equally
-- eligible. The rescue mechanism could park the lead somewhere it can never leave.
--
-- This is not the same shape as the question LEAD-3 asked. It is the SEC-1 shape once more: a
-- capability decision taken by proximity (who is placed here) instead of by authority (who may do
-- this), in the one place where the system acts with no human in the loop to notice.
--
-- ================================================================================================
-- THE RULE, DERIVED RATHER THAN INVENTED
--
-- canon 04: "Reassign the lead to another ELIGIBLE EMPLOYEE." Eligibility is read out of ORVION's
-- own permission matrix -- a candidate must hold the permission ORVION already charges for bringing
-- a lead to an outcome. CLOSE_LEAD is that permission: canon 04's SLA exists to get the lead to an
-- outcome, and CLOSE_LEAD is what ORVION charges to record one. The choice narrows nothing that the
-- other three candidate permissions would not narrow identically -- all four resolve to the same six
-- roles today -- so it is a reading of the matrix rather than a preference between readings.
--
-- The permission is resolved the way `app.has_permission` resolves it (active assignment, active
-- role, active permission), for an ARBITRARY user, because this runs with no session. CLOSE_LEAD
-- carries no `required_feature_code`, so there is no plan gate to mirror; `app.process_lead_sla`
-- already applies the subscription gate for the tenant as a whole.
--
-- WHEN NOBODY IS ELIGIBLE the lead now STAYS with its current assignee instead of moving to someone
-- who cannot act on it -- and the pass reports `reassignment_blocked` rather than returning silently.
-- The employee and both managers have already been warned by the earlier pass, so a human has been
-- told; what would otherwise be lost is the fact that the automation tried and could not act.
-- Recorded as LEAD-4: nothing yet CONSUMES that signal on a scheduled run, which is SCHED-1's shape
-- and is deliberately not solved by inventing a notification type here.
--
-- NOT CHANGED, deliberately:
--   * The round-robin ordering (least-recently-assigned, then `u.id` as a deterministic tie-break).
--     LEAD-3 also asked whether the tie should break on open-lead count instead. The primary key of
--     the ordering is already operational; the tie-break only decides between people who have never
--     held a lead, and changing it is an optimisation, not a defect.
--   * The 15/30 windows, the warning path, the manager escalation, the event vocabulary, the
--     subscription-gate skip, and the immutability of assignment history.
--   * `app.reassign_lead`, the HUMAN path. It charges REASSIGN_LEAD and a manager names the
--     assignee deliberately; this migration governs the path where NO human chose. Widening an
--     automatic-path fix into a restriction on a supervisor's explicit instruction would be an
--     unrequested policy change. Recorded as LEAD-5 rather than silently applied.
-- ================================================================================================

create or replace function app.eligible_lead_handlers(
    p_tenant_id       uuid,
    p_branch_id       uuid,
    p_department_id   uuid,
    p_exclude_user_id uuid default null
)
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $fn$
    select u.id
    from public.users u
    join public.user_branch_assignments uba
        on uba.user_id      = u.id
       and uba.tenant_id    = p_tenant_id
       and uba.branch_id    = p_branch_id
       and uba.department_id = p_department_id
       and uba.starts_at   <= now()
       and (uba.ends_at is null or uba.ends_at > now())
    where u.tenant_id = p_tenant_id
      and u.is_active
      and u.id is distinct from p_exclude_user_id
      -- Eligibility is authority, not proximity. Resolved exactly as app.has_permission resolves it.
      and exists (
            select 1
            from public.user_role_assignments ura
            join public.roles r  on r.id = ura.role_id and r.is_active
            join public.role_permissions rp on rp.role_id = ura.role_id
            join public.permissions p on p.id = rp.permission_id
                                     and p.is_active
                                     and p.key = 'CLOSE_LEAD'
            where ura.user_id  = u.id
              and ura.tenant_id = p_tenant_id
              and ura.is_active
              and ura.starts_at <= now()
              and (ura.ends_at is null or ura.ends_at > now())
      );
$fn$;

comment on function app.eligible_lead_handlers(uuid, uuid, uuid, uuid) is
    'Candidates for automatic SLA reassignment: active users placed in the lead''s branch AND '
    'department who hold CLOSE_LEAD through an active role assignment. canon 04 says "another '
    'eligible employee"; eligibility is read out of ORVION''s permission matrix rather than out of '
    'placement, so a trainee or a finance manager sitting in the same room is not a candidate.';

revoke execute on function app.eligible_lead_handlers(uuid, uuid, uuid, uuid) from public;

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
begin
    for r in
        select l.id, l.tenant_id, l.branch_id, l.department_id
        from public.leads l
        where l.lead_status_code = 'assigned'
    loop
        -- SPEC-152 gate awareness. Without this the first restricted tenant raises and the entire
        -- multi-tenant run rolls back -- see that migration's header.
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

                -- canon 10: "After another 15 minutes without response: Notify reassigned employee.
                -- NOTIFY MANAGER. Record reassignment event." The manager half was absent.
                -- `v_next` is excluded because they have just been told directly above. The OUTGOING
                -- assignee is not excluded -- so a manager who was also the assignee still receives
                -- the team notification. Canon requires no separate notice to a departing assignee
                -- who is not a manager, and one is not invented here.
                for m in select app.lead_responsible_managers(
                                    r.tenant_id, r.branch_id, r.department_id, v_next) as user_id
                loop
                    insert into public.notifications (
                        tenant_id, target_user_id, notification_type_code, title, body,
                        related_entity_type, related_entity_id
                    )
                    values (
                        r.tenant_id, m.user_id, 'lead_reassigned', 'Lead reassigned in your team',
                        'An SLA-overdue lead was reassigned to another employee.', 'lead', r.id
                    );
                end loop;

                lead_id := r.id; action := 'reassigned'; return next;
            else
                -- Nobody in this branch and department may work a lead. The lead STAYS -- parking it
                -- with someone who cannot act on it is worse than leaving it with someone who has
                -- not. Reported rather than passed over in silence; the employee and the managers
                -- were already warned on the earlier pass. See LEAD-4.
                lead_id := r.id; action := 'reassignment_blocked'; return next;
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

            -- canon 04 / canon 10: notify the employee's manager. This is the line that never fired,
            -- because it used to test only `user_role_assignments.branch_id/department_id` -- NULL
            -- for every assignment `app.assign_user_role` creates by default.
            for m in select app.lead_responsible_managers(
                                r.tenant_id, r.branch_id, r.department_id, v_cur_user) as user_id
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
$function$;
