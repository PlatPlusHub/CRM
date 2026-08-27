-- RBAC-1 and CUR-1 -- two findings from the whole-system post-WP-04 discovery sweep.
--
-- ================================================================================================
-- RBAC-1 -- ORVION AUDITS EVERY PRIVILEGE GRANT MADE THROUGH ITS RPC, AND NOTHING ELSE.
--
-- FOUND BY: sweeping the event registry for codes with no producer anywhere in the database --
-- `pg_get_functiondef` across schema `app` plus every trigger definition. 43 registered event types
-- have no producer. Most are unbuilt features (auth events live in Supabase Auth; notifications
-- have no producer yet) and are recorded as EVT-2. `role_removed` is not one of those. It is an
-- ASYMMETRY, and asymmetric audit is a defect rather than a missing feature.
--
-- What the sweep then showed, live:
--
--   GRANT     app.assign_user_role -> app.authorize('MANAGE_USERS')  [permission AND MFA]
--                                  -> record_event('role_assigned', severity 'security')
--   REVOKE    no RPC exists at all.
--
-- And `user_role_assignments` carries NO TRIGGERS WHATSOEVER (verified live: `pg_trigger` returns
-- zero non-internal rows for it). So the RPC is not a boundary, it is a convenience. The real
-- privilege surface is the table, and its RLS is:
--
--   scope_insert / scope_update / scope_delete -> app.has_permission('MANAGE_USERS')
--
-- `has_permission`, not `authorize`. Three consequences, none of them theoretical:
--
--   1. NO REVOCATION IS EVER RECORDED. Every grant in ORVION's history is in the audit spine and
--      not one removal is. An administrator -- or anyone who reaches an administrator's session --
--      can strip a colleague's roles, including the Owner's, and leave the spine looking untouched.
--      For an event class whose severity is literally 'security', that is the wrong half to record.
--
--   2. DIRECT DML GRANTS ARE UNAUDITED TOO. This is the half I did not expect and the sweep found:
--      because the emission lives in the RPC rather than on the table, `insert into
--      public.user_role_assignments ...` grants a role and emits nothing. The audit spine's
--      coverage of grants was never complete either -- it covered one path.
--
--   3. THE DESTRUCTIVE PATH IS THE CHEAPER ONE. Granting through the RPC costs MFA, because
--      `app.authorize` composes it. Revoking -- or granting by direct DML -- costs only the
--      permission. A control where the safe route is harder than the dangerous one inverts the
--      incentive it exists to create.
--
-- THE FIX IS ON THE TABLE, NOT IN THE RPC. This is the WP-00 shape the programme has applied
-- everywhere else: a rule that lives in one caller protects one path, and the defect is always in
-- the sibling path. One trigger closes RPC, direct DML, INSERT, UPDATE and DELETE at once, and
-- becomes the SINGLE producer of both events -- so `app.assign_user_role` below LOSES its own
-- `record_event` call rather than gaining a second one beside the trigger's.
-- ================================================================================================

create or replace function app.emit_role_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $fn$
declare
    -- SCALARS, NOT A RECORD. plpgsql binds every referenced variable as a query parameter before
    -- the statement runs, so reading a field of an unassigned RECORD raises 55000 before any guard
    -- can short-circuit -- the failure mode SPEC-159-A hit. Branching on tg_op into scalars is the
    -- shape that survives all three operations.
    v_tenant   uuid;
    v_user     uuid;
    v_role_id  uuid;
    v_assign   uuid;
    v_scope    text;
    v_branch   uuid;
    v_dept     uuid;
    v_role     text;
    v_actor    uuid;
    v_was_live boolean;
    v_now_live boolean;
begin
    if tg_op = 'DELETE' then
        v_tenant := old.tenant_id; v_user := old.user_id; v_role_id := old.role_id;
        v_assign := old.id; v_scope := old.scope_type;
        v_branch := old.branch_id; v_dept := old.department_id;
        v_was_live := old.is_active and (old.ends_at is null or old.ends_at > now());
        v_now_live := false;
    elsif tg_op = 'INSERT' then
        v_tenant := new.tenant_id; v_user := new.user_id; v_role_id := new.role_id;
        v_assign := new.id; v_scope := new.scope_type;
        v_branch := new.branch_id; v_dept := new.department_id;
        v_was_live := false;
        v_now_live := new.is_active and (new.ends_at is null or new.ends_at > now());
    else
        v_tenant := new.tenant_id; v_user := new.user_id; v_role_id := new.role_id;
        v_assign := new.id; v_scope := new.scope_type;
        v_branch := new.branch_id; v_dept := new.department_id;
        v_was_live := old.is_active and (old.ends_at is null or old.ends_at > now());
        v_now_live := new.is_active and (new.ends_at is null or new.ends_at > now());
    end if;

    -- EFFECTIVE ACCESS is what is audited, not column churn. Correcting a typo in `scope_type`
    -- is not a privilege change and must not look like one in the spine; flipping `is_active`,
    -- or setting `ends_at` into the past, is. Both columns are read because either one alone
    -- can end a grant -- SPEC-148 proved the resolution primitives honour both.
    if v_was_live = v_now_live then
        return case when tg_op = 'DELETE' then old else new end;
    end if;

    -- Platform paths (provisioning, migrations, service_role) carry no session and are outside
    -- per-table enforcement, exactly as in SPEC-145/149 and `app.enforce_archive_authority`. They
    -- are still AUDITED -- the exemption is from the permission check, never from the record.
    if (select auth.uid()) is not null then
        -- `authorize`, not `has_permission`: this is what removes consequence 3. Changing who holds
        -- a role now costs the same step-up through direct DML as it does through the RPC.
        perform app.authorize('MANAGE_USERS');
        v_actor := app.current_user_id();
    end if;

    select r.code into v_role from public.roles r where r.id = v_role_id;

    perform app.record_event(
        v_tenant,
        case when v_now_live then 'role_assigned' else 'role_removed' end,
        'user', v_user, v_actor,
        case when v_now_live then null else v_role end,
        case when v_now_live then v_role else null end,
        tg_op,
        jsonb_build_object('role_code', v_role, 'scope_type', v_scope,
                           'branch_id', v_branch, 'department_id', v_dept,
                           'assignment_id', v_assign),
        'security');

    return case when tg_op = 'DELETE' then old else new end;
end;
$fn$;

revoke execute on function app.emit_role_change() from public;

-- AFTER, so the event describes what actually happened rather than what was attempted. A raise
-- from `app.authorize` inside an AFTER trigger still aborts the whole statement, so the permission
-- check loses nothing by being here -- and keeping authority and audit in one function means they
-- can never drift apart, which is how this defect arose in the first place.
create trigger user_role_assignments_emit_role_change
    after insert or update or delete on public.user_role_assignments
    for each row execute function app.emit_role_change();

-- ---------------------------------------------------------------------------------------------
-- The RPC loses its own emission. There is now exactly ONE producer of role_assigned/role_removed,
-- and it sits on the table where every path must pass. Leaving the call here would have produced
-- two events for one grant -- the usual cost of "add the new rule and keep the old one".
--
-- Everything else about this function is unchanged and deliberately so: the role-exists check, the
-- target-user-is-in-my-tenant check and the `assigned_by` stamp are all things the trigger cannot
-- do, because a trigger sees a row and not an intent.
-- ---------------------------------------------------------------------------------------------
create or replace function app.assign_user_role(
    p_user_id uuid,
    p_role_code text,
    p_scope_type text default 'tenant',
    p_branch_id uuid default null,
    p_department_id uuid default null
)
returns uuid
language plpgsql
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_role uuid;
    v_actor uuid;
    v_assignment uuid;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('MANAGE_USERS');

    select id into v_role from public.roles where code = p_role_code and is_active;
    if v_role is null then
        raise exception 'unknown or inactive role: %', p_role_code;
    end if;

    if not exists (
        select 1 from public.users where id = p_user_id and tenant_id = v_tenant
    ) then
        raise exception 'target user is not in your tenant';
    end if;

    select id into v_actor
    from public.users
    where auth_user_id = (select auth.uid()) and tenant_id = v_tenant;

    insert into public.user_role_assignments (
        tenant_id, user_id, role_id, scope_type, branch_id, department_id, is_active, assigned_by
    )
    values (
        v_tenant, p_user_id, v_role, p_scope_type, p_branch_id, p_department_id, true, v_actor
    )
    returning id into v_assignment;

    -- `role_assigned` is emitted by user_role_assignments_emit_role_change, not from here.

    return v_assignment;
end;
$fn$;

-- ---------------------------------------------------------------------------------------------
-- The verb that was missing. Granting had an RPC and revoking did not, which is why revocation was
-- only ever reachable through raw DML in the first place.
--
-- It ENDS the assignment rather than deleting it: `24_assignment_history_test.sql` establishes that
-- assignment history is evidence, and a hard DELETE would erase the record of a privilege that was
-- genuinely held during a period someone may later need to reconstruct.
--
-- No `p_reason`, deliberately -- `app.assign_user_role` has none either, and there is no column to
-- hold one. Inventing an asymmetric parameter that the trigger could not see anyway would be
-- decoration. If role changes should carry reasons, that is one schema change covering both verbs.
-- ---------------------------------------------------------------------------------------------
create or replace function app.revoke_user_role(p_assignment_id uuid)
returns void
language plpgsql
set search_path = ''
as $fn$
declare
    v_tenant uuid := app.current_tenant_id();
    v_found  boolean;
begin
    if v_tenant is null then
        raise exception 'no active tenant for caller';
    end if;
    perform app.authorize('MANAGE_USERS');

    select true into v_found
    from public.user_role_assignments
    where id = p_assignment_id and tenant_id = v_tenant;
    if v_found is not true then
        raise exception 'role assignment is not in your tenant';
    end if;

    update public.user_role_assignments
       set is_active = false,
           ends_at = coalesce(ends_at, now())
     where id = p_assignment_id
       and tenant_id = v_tenant
       and is_active;
end;
$fn$;

revoke execute on function app.revoke_user_role(uuid) from public;
grant  execute on function app.revoke_user_role(uuid) to authenticated;

comment on function app.revoke_user_role(uuid) is
    'Ends a role assignment. Requires MANAGE_USERS with step-up, and is audited as role_removed by '
    'the table trigger -- as is the same change made by direct DML (RBAC-1).';

-- ================================================================================================
-- CUR-1 -- `public.integration_cursors` grants `authenticated` SELECT, INSERT and UPDATE while its
-- RLS denies all three.
--
-- FOUND BY: the same sweep, looking for tables with RLS enabled and zero policies. It is the only
-- one, and it is invisible to `01_rls_coverage_test.sql` because that guard is driven by NOT NULL
-- `tenant_id` and this table has no tenant column at all -- it is the global n8n outbox cursor.
--
-- The BEHAVIOUR is already correct and fail-closed: RLS with no policy denies every non-owner role,
-- so an authenticated user can neither read nor advance the cursor, and
-- `app.map_outcomes_to_conversions` reaches it as SECURITY DEFINER. Nothing is exposed.
--
-- What is wrong is that the privilege layer and the policy layer state OPPOSITE intentions about
-- the same table. That is a misleading contract, and misleading contracts are how the next engineer
-- reasons their way into a real defect -- reading the GRANT, concluding an authenticated client may
-- advance the cursor, and "fixing" the missing policy to match. The grants are also live exposure
-- waiting on one `alter table ... disable row level security`.
--
-- Both layers are made to say the same thing: nobody but the platform touches this.
-- ================================================================================================
revoke all on table public.integration_cursors from anon, authenticated;

-- The intent, stated where a reader looks, rather than left as an absence to be interpreted. Same
-- shape as `tenant_license_activations.platform_only` (SPEC-158) -- and a second lock, so a future
-- accidental grant still returns nothing.
create policy platform_only on public.integration_cursors
    for all to authenticated using (false) with check (false);

comment on table public.integration_cursors is
    'Global outbox cursors for the n8n integration path. Platform-only: no tenant dimension, no '
    'tenant-facing privilege, and an explicit deny-all policy behind the absent grant (CUR-1).';
