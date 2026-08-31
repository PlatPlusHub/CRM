-- API-3 lead-routing family. Four defects, all reproduced before being fixed, all on the same
-- table: `public.lead_assignments`, which `authenticated` holds INSERT and UPDATE on and which
-- PostgREST therefore serves beside the RPCs.
--
-- ================================================================================================
-- LEAD-6 -- round-robin assigned by PROXIMITY where canon says ELIGIBILITY.
--
-- canon 04: "The default routing method is round-robin assignment among ELIGIBLE EMPLOYEES."
-- LEAD-3 (202607056800) already answered what "eligible" means, by reading ORVION's own permission
-- matrix rather than the word: a candidate must hold CLOSE_LEAD, the permission ORVION charges for
-- bringing a lead to an outcome. That answer was applied to `app.process_lead_sla` and to nothing
-- else. `app.assign_lead_round_robin` still selected on PLACEMENT alone -- active user with a
-- current `user_branch_assignments` row -- which is the precise definition LEAD-3 rejected:
-- "The pool was never 'eligible employees' at all. It was everyone PLACED in the branch."
--
-- That migration's "NOT CHANGED, deliberately" list names the round-robin ORDERING and it names
-- `app.reassign_lead` (the human path, where a supervisor names the assignee -- LEAD-5). It does
-- not name this pool, and the reasoning it gives for sparing `reassign_lead` does not reach here:
-- round-robin is the path where NO human chooses, which is the side of the line LEAD-3 governs.
--
-- REPRODUCED on a clean database: a branch/department holding one branch_manager (CLOSE_LEAD) and
-- one trainee (no CLOSE_LEAD). `app.eligible_lead_handlers` returned ONE candidate, the manager.
-- Round-robin's own predicate returned TWO. With the manager already holding a lead, round-robin's
-- "never assigned first" ordering selected the TRAINEE -- and the trainee, calling
-- `app.advance_lead(..., 'lost', ...)` on the lead they now owned, was refused
-- `permission denied: CLOSE_LEAD`. The lead was routed to someone who cannot close it.
--
-- Fixed by CALLING the existing authority rather than restating it. The predicate is not inlined
-- here, and that is a measured decision, not a stylistic one: `user_role_assignments` carries a
-- `scope_read` RLS policy, so the permission join evaluated inside this INVOKER function would be
-- ROW-FILTERED to what the caller may see and would silently exclude eligible colleagues. The
-- resolution has to run as DEFINER, and `app.eligible_lead_handlers` already is one.
--
-- Calling it requires granting EXECUTE to `authenticated`, and granting it AS IT STOOD would have
-- opened a cross-tenant enumeration oracle: it is SECURITY DEFINER and takes `p_tenant_id` as an
-- argument, so any authenticated user could have listed the staff of any tenant. The grant is
-- therefore paired with a tenant guard inside the function -- a session may only ask about its own
-- tenant; the session-less SLA path, which must pass a tenant explicitly, is unaffected.
--
-- The ordering is untouched (least-recently-assigned, nulls first, `u.id` as tie-break): LEAD-3
-- declined to change it and nothing found here contradicts that. Adopting the shared pool also
-- corrects a divergence that was never separately filed: round-robin tested `uba.ends_at is null`,
-- so it counted a placement that has not STARTED yet and skipped one that is current but carries a
-- future end date. `eligible_lead_handlers` tests the actual window.
--
-- ================================================================================================
-- ASGN-1 (High) -- "one lead has one current handler" lived in one function.
--
-- `leads.assigned_user_id` is singular and SPEC-151 constrains `owner_user_id` equal to it, so the
-- domain rule is exactly one current assignment per lead. Nothing enforced it: `lead_assignments`
-- carried no unique index, and `app.require_assignment_history` -- the trigger that closed the
-- direct-UPDATE hole on `leads` -- asks whether A current row exists for the new assignee, never
-- whether only one does.
--
-- REPRODUCED as a branch_manager over the real `authenticated` role, holding ASSIGN_LEAD and
-- REASSIGN_LEAD, with the lead visible, immediately after a legal `app.assign_lead` that left
-- exactly one current row: a direct INSERT produced TWO current rows for one lead, left
-- `leads.assigned_user_id` pointing at the first, and emitted NO event -- the timeline and the
-- authoritative column disagreed, and nothing recorded that anything had happened.
--
-- Closed with a partial unique index rather than a trigger, because the invariant is a statement
-- about a SET of rows that PostgreSQL can enforce declaratively, and a declarative constraint
-- cannot be reached around by any door. Precedent and shape: `document_versions_one_current_idx`.
-- Every legal writer was checked against it FIRST rather than after: `app.assign_lead` inserts only
-- when the lead is `new` and moves it to `assigned`, so it cannot fire twice; `app.reassign_lead`
-- and `app.process_lead_sla` both close the previous row before inserting the next.
--
-- ================================================================================================
-- ASGN-2 (High) -- `assigned_by` was a caller-supplied column.
--
-- ATTR-1 (202607056400) made `created_by` derived on twenty tables because a caller-supplied
-- attribution column lets one employee's action be recorded as another's. `lead_assignments`
-- carries its own attribution column under a different name and was not among the twenty.
-- `app.forbid_assignment_history_rewrite` freezes `assigned_by` on UPDATE, so the column looked
-- governed; nothing constrained it on INSERT.
--
-- REPRODUCED in the same transaction as ASGN-1: the manager's direct INSERT recorded
-- `assigned_by = Employee A`. The audit trail named a subordinate as the author of the manager's
-- own act. The composite FK is satisfied by any user in the tenant -- ADMIN-1's lesson exactly: a
-- foreign key proves an identity EXISTS, never WHOSE it is.
--
-- Fixed with ATTR-1's own idiom, deliberately unchanged: derive on INSERT from the session, and
-- leave session-less platform paths alone -- `app.process_lead_sla` passes `assigned_by => null`
-- on purpose, because no human performed that assignment.
--
-- ================================================================================================
-- ASGN-3 (Medium) -- the terminal-status rule was enforced in the RPC only.
--
-- `app.reassign_lead` refuses a lead in `won/converted/lost/spam/duplicate`. REPRODUCED: with a
-- lead legally advanced to `lost`, the RPC refused ("a lead in terminal status lost cannot be
-- reassigned") and a direct INSERT by the SAME actor in the SAME transaction SUCCEEDED -- a closed
-- lead acquired a new handler, unaudited. This is BOOK-1's shape one domain over.
--
-- Enforced with a BEFORE INSERT trigger carrying the RPC's list verbatim, SECURITY DEFINER with a
-- mandatory REVOKE for BOOK-1's reason: under INVOKER the guard's own read of the parent lead would
-- be RLS-filtered, leaving it blindest against precisely the caller it must stop. No session-less
-- exemption: this is integrity, not authorization, and a closed lead may not acquire a handler
-- whoever is asking.
-- ================================================================================================

-- ------------------------------------------------------------------------------------------------
-- LEAD-6
-- ------------------------------------------------------------------------------------------------
create or replace function app.eligible_lead_handlers(
    p_tenant_id       uuid,
    p_branch_id       uuid,
    p_department_id   uuid,
    p_exclude_user_id uuid default null
)
returns setof uuid
language plpgsql
stable
security definer
set search_path = ''
as $fn$
begin
    -- This function is SECURITY DEFINER and takes the tenant as an argument, so exposing it to
    -- `authenticated` without this check would let any signed-in user enumerate any tenant's staff.
    -- A session may only ask about its own tenant. `auth.uid() is null` is the session-less
    -- platform path (canon 35 principle 6) -- `app.process_lead_sla` iterates tenants and must
    -- keep passing them explicitly.
    if (select auth.uid()) is not null and p_tenant_id is distinct from app.current_tenant_id() then
        raise exception 'eligible_lead_handlers may only be asked about your own tenant'
            using errcode = '42501';
    end if;

    return query
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
end
$fn$;

grant execute on function app.eligible_lead_handlers(uuid, uuid, uuid, uuid) to authenticated;

create or replace function app.assign_lead_round_robin(p_lead_id uuid, p_reason text default null)
returns uuid
language plpgsql
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_branch uuid;
    v_department uuid;
    v_status text;
    v_chosen uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('ASSIGN_LEAD');

    select branch_id, department_id, lead_status_code
      into v_branch, v_department, v_status
    from public.leads
    where id = p_lead_id and tenant_id = v_tenant;
    if not found then
        raise exception 'lead is not in your tenant';
    end if;
    if v_status <> 'new' then
        raise exception 'lead is not in new status (use reassignment): %', v_status;
    end if;

    -- LEAD-6: the pool is app.eligible_lead_handlers -- canon 04's "eligible employees", resolved
    -- once, in the DEFINER function that LEAD-3 built for it. Round-robin order is unchanged:
    -- least-recently-assigned (never-assigned first), tie-broken deterministically by user id.
    select e.user_id
      into v_chosen
    from app.eligible_lead_handlers(v_tenant, v_branch, v_department) as e(user_id)
    left join lateral (
        select max(la.assigned_at) as last_at
        from public.lead_assignments la
        where la.assigned_user_id = e.user_id and la.tenant_id = v_tenant
    ) x on true
    order by x.last_at asc nulls first, e.user_id asc
    limit 1;

    if v_chosen is null then
        raise exception 'no eligible employee for round-robin';
    end if;

    return app.assign_lead(p_lead_id, v_chosen, coalesce(p_reason, 'round-robin assignment'));
end;
$fn$;

-- ------------------------------------------------------------------------------------------------
-- ASGN-1
-- ------------------------------------------------------------------------------------------------
create unique index lead_assignments_one_current_idx
    on public.lead_assignments (lead_id)
    where is_current;

comment on index public.lead_assignments_one_current_idx is
    'ASGN-1: exactly one current assignment per lead. leads.assigned_user_id is singular and SPEC-151 constrains owner_user_id equal to it; before this index a direct INSERT produced two current rows, desynchronised the authoritative column and emitted no event.';

-- ------------------------------------------------------------------------------------------------
-- ASGN-2
-- ------------------------------------------------------------------------------------------------
create or replace function app.derive_assignment_actor()
returns trigger
language plpgsql
set search_path = ''
as $fn$
begin
    -- Session-less platform paths keep the attribution they set: app.process_lead_sla writes
    -- assigned_by => null deliberately, because no human performed that assignment.
    if (select auth.uid()) is null then
        return new;
    end if;
    new.assigned_by := app.current_user_id();
    return new;
end
$fn$;

comment on function app.derive_assignment_actor() is
    'ASGN-2: lead_assignments.assigned_by is derived from the session on INSERT, never accepted from the caller. ATTR-1 did this for created_by on twenty tables; this column carries the same fact under a different name and was not among them. UPDATE is already frozen by app.forbid_assignment_history_rewrite.';

-- A newly created function inherits PostgreSQL's default EXECUTE-to-PUBLIC. `10_grant_model_test`
-- caught this omission on the first draft of this migration, exactly as it caught BOOK-1's -- an
-- existing guard catching a real regression introduced by a security fix.
revoke all on function app.derive_assignment_actor() from public;

create trigger lead_assignments_derive_actor
    before insert on public.lead_assignments
    for each row execute function app.derive_assignment_actor();

-- ------------------------------------------------------------------------------------------------
-- ASGN-3
-- ------------------------------------------------------------------------------------------------
create or replace function app.guard_lead_assignment_target()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    v_status text;
begin
    select lead_status_code into v_status
    from public.leads
    where id = new.lead_id and tenant_id = new.tenant_id;

    if v_status is null then
        return new;   -- the composite FK is the authority on existence; do not duplicate it here
    end if;

    if v_status in ('won', 'converted', 'lost', 'spam', 'duplicate') then
        raise exception 'a lead in terminal status % cannot acquire a new handler', v_status
            using errcode = '23514';
    end if;

    return new;
end
$fn$;

comment on function app.guard_lead_assignment_target() is
    'ASGN-3: app.reassign_lead refuses a terminal lead; the table door did not. SECURITY DEFINER because under INVOKER this read of the parent lead would be RLS-filtered and the guard would be weakest against the caller it must stop (BOOK-1). No session-less exemption: integrity, not authorization.';

-- BOOK-1's mandatory REVOKE: a SECURITY DEFINER function must not be callable by clients.
revoke all on function app.guard_lead_assignment_target() from public;

create trigger lead_assignments_guard_target
    before insert on public.lead_assignments
    for each row execute function app.guard_lead_assignment_target();
