-- SLA-1 -- the manager escalation canon makes MANDATORY has never fired.
--
-- ================================================================================================
-- THE CANONICAL REQUIREMENT, QUOTED RATHER THAN INFERRED
--
-- canon 04 § SLA Escalation Rule:
--     "If a lead is not responded to within 15 minutes: Notify the assigned employee. NOTIFY THE
--      EMPLOYEE'S MANAGER. Record an escalation event."
--     "If another 15 minutes pass without response: Reassign the lead ... Record the reassignment
--      event. Preserve the original assignee in lead history."
--
-- canon 10 § Lead Notifications:
--     "After 15 minutes without response: Notify assigned employee. NOTIFY MANAGER."
--     "After another 15 minutes without response: Notify reassigned employee. NOTIFY MANAGER.
--      Record reassignment event."
--
-- canon 10 also lists "Manager escalation" among the notifications users CANNOT MUTE. This is not a
-- preference; it is mandatory operational behaviour. The 15/30-minute windows already match
-- `app.process_lead_sla`'s defaults, so nothing about the timing is invented here either.
--
-- ================================================================================================
-- WHAT ACTUALLY HAPPENED, REPRODUCED BEFORE IT WAS FIXED
--
-- Standard configuration: an employee, a branch_manager and a department_manager, all PLACED in the
-- branch/department through `user_branch_assignments`, all holding TENANT-scoped roles -- which is
-- exactly what `app.assign_user_role` produces (`p_scope_type` defaults to 'tenant', leaving
-- `branch_id` and `department_id` NULL). A lead assigned to the employee, then one SLA pass:
--
--     1-Emp         1 notification (lead_sla_warning)
--     2-BranchMgr   0
--     3-DeptMgr     0
--
-- with a positive control in the same transaction proving the managers CAN see the lead (RLS
-- returns it), so this is a notification failure and not an unreachable row.
--
-- ROOT CAUSE: the manager lookup asked
--
--     and (ura.branch_id = r.branch_id or ura.department_id = r.department_id)
--
-- of `user_role_assignments` ALONE. ORVION's authoritative definition of which branches and
-- departments a user governs is `app.visible_branch_ids()` / `app.visible_department_ids()`, and
-- each is a UNION of sources: tenant-wide read, the user's `user_branch_assignments` PLACEMENT, and
-- scoped `user_role_assignments`. The SLA lookup used only the third -- the one that is NULL for
-- every role assignment ORVION's own RPC creates by default. Two definitions of one concept, and
-- the narrower one sat in the place that mattered.
--
-- SECOND INSTANCE, SAME DEFECT: the reassignment branch notified only the NEW assignee. Canon 10
-- requires the manager to be notified there too, and that branch had no manager notification at all.
--
-- ================================================================================================
-- WHAT IS AND IS NOT CHANGED
--
-- CHANGED: how a responsible manager is IDENTIFIED, and the addition of the manager notification
-- canon requires on reassignment.
--
-- NOT CHANGED, deliberately:
--   * WHICH ROLES escalate. Still branch_manager and department_manager. Widening to holders of
--     tenant-wide read (ceo/owner) would be new policy, not a defect fix -- and neither role is in
--     canon's escalation path.
--   * The 15/30-minute windows, the warn-before-reassign ordering, the qualifying-interaction
--     definition, the round-robin choice of the next assignee, the subscription gate skip, the
--     event vocabulary, and the immutability of assignment history. All existing, all correct.
--   * The assigned employee is still excluded from the manager list: they receive their own
--     notification, and a manager who is also the assignee must not be told twice.
--
-- The scope rule is extracted into ONE function used by BOTH paths, because a second copy of a
-- predicate is what produced this defect in the first place.
-- ================================================================================================

create or replace function app.lead_responsible_managers(
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
    -- Mirrors app.visible_branch_ids() / app.visible_department_ids() for an ARBITRARY user, because
    -- those read the session and this runs with none. The tenant-wide-read source is deliberately
    -- absent: it resolves to ceo/owner, who are not in canon's escalation path and are excluded by
    -- the role filter below in any case.
    select distinct ura.user_id
    from public.user_role_assignments ura
    join public.roles r on r.id = ura.role_id
    where ura.tenant_id = p_tenant_id
      and ura.is_active
      and r.is_active
      and r.code in ('branch_manager', 'department_manager')
      and ura.starts_at <= now()
      and (ura.ends_at is null or ura.ends_at > now())
      and ura.user_id is distinct from p_exclude_user_id
      and (
            -- scoped role assignment (the source the old predicate used, kept)
            ura.branch_id     = p_branch_id
         or ura.department_id = p_department_id
            -- ...or the manager is PLACED in the branch/department, which is the source
            -- `assign_user_role` actually populates and the one that makes the lead visible to them.
         or exists (
                select 1
                from public.user_branch_assignments uba
                where uba.user_id = ura.user_id
                  and uba.tenant_id = p_tenant_id
                  and uba.starts_at <= now()
                  and (uba.ends_at is null or uba.ends_at > now())
                  and (uba.branch_id = p_branch_id or uba.department_id = p_department_id)
            )
      );
$fn$;

revoke execute on function app.lead_responsible_managers(uuid, uuid, uuid, uuid) from public;

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
