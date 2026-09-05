-- AUTH-2 -- a role assignment that has not started yet grants its permissions anyway.
--
-- =================================================================================================
-- THE DEFECT, MEASURED RATHER THAN REASONED
--
-- `public.user_role_assignments.starts_at` is `timestamptz NOT NULL DEFAULT now()`. The column exists
-- to say when an assignment comes into force. Twelve functions read the table. Measured live at
-- `1df2f06`, by reading each body rather than grepping for the column name -- the string `starts_at`
-- appears in `app.has_permission` only in its `user_permission_grants` CTE, which is exactly the
-- kind of false positive MEAS-1 warns about:
--
--   HONOURS starts_at                    IGNORES starts_at
--   ------------------------------       ---------------------------------------------
--   app.visible_branch_ids               app.has_permission          <- THE AUTHORISATION AUTHORITY
--   app.visible_department_ids           app.effective_permissions   <- THE EXPLAINABILITY SURFACE
--   app.credit_alert_recipients          app.requires_mfa            <- THE MFA GATE
--   app.lead_responsible_managers
--
-- The sharpest statement is inside ONE function. `app.has_permission` evaluates two grant paths:
--
--   user_permission_grants:  and g.starts_at <= now() and (g.ends_at is null or g.ends_at > now())
--   user_role_assignments:   and ura.is_active        and (ura.ends_at is null or ura.ends_at > now())
--
-- Two grant paths, two different temporal rules, in the same statement, for no stated reason. Both
-- tables carry `starts_at` and `ends_at`; only one of them is asked.
--
-- CONSEQUENCE, and it is reachable. `authenticated` holds INSERT and UPDATE on
-- `user_role_assignments` (measured), gated by RLS `WITH CHECK (tenant_id = current_tenant_id() and
-- has_permission('MANAGE_USERS'))` -- the permission-bearing-RLS mechanism SEC-1's ratified model
-- names. `starts_at` is caller-supplied through that door and no trigger constrains it. So an
-- administrator who schedules "this user becomes finance_manager on the 1st" grants finance_manager
-- IMMEDIATELY. Not at the boundary, not by a race -- from the moment the row is written.
--
-- It is also INTERNALLY INCONSISTENT in a way that would be very hard to diagnose from behaviour:
-- the same future-dated assignment grants the PERMISSION now (`has_permission`) while withholding
-- the SCOPE until it starts (`visible_branch_ids`, `visible_department_ids`). A user would hold
-- CLOSE_LEAD over an empty set of branches, and every explanation surface would agree with the
-- wrong half.
--
-- =================================================================================================
-- WHY THIS IS ENGINEERING AND NOT A POLICY QUESTION
--
-- No invention is required and no rule is chosen. Three things already decide it:
--   1. The column is NOT NULL with DEFAULT now(), so every existing row satisfies `starts_at <= now()`
--      and the corrected predicate changes NOTHING for any assignment created to date. It cannot
--      revoke access anyone currently has.
--   2. The sibling grant path in the same function already applies exactly this predicate to the
--      same pair of columns on `user_permission_grants`.
--   3. Four of the seven readers already apply it, including both scope resolvers. This migration
--      makes the minority agree with the majority; it does not invent a seventh opinion.
--
-- `app.assign_user_role` is deliberately NOT changed. It has no `starts_at` parameter and always
-- takes the DEFAULT, so future-dating is unreachable through the RPC door. Adding the parameter
-- would be a new capability, not a fix, and this migration closes a defect rather than opening a
-- feature. The TABLE door is the one that carries the risk, and the fix belongs where the reading
-- happens rather than in a new write-side constraint -- a `starts_at <= now()` CHECK would forbid
-- legitimate scheduling, which is what the column is FOR.
--
-- =================================================================================================
-- WHAT CHANGES: one predicate, three functions. Nothing else in any body is touched.

-- 1. THE AUTHORISATION AUTHORITY.
create or replace function app.has_permission(p_permission_key text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    with me as (
        select u.id, u.tenant_id
        from public.users u
        where u.auth_user_id = (select auth.uid())
          and u.is_active
          and u.tenant_id = app.current_tenant_id()
    ),
    perm as (
        select p.id, p.required_feature_code
        from public.permissions p
        where p.key = p_permission_key and p.is_active
    ),
    override as (
        select g.effect
        from public.user_permission_grants g
        join me on me.id = g.user_id and me.tenant_id = g.tenant_id
        join perm on perm.id = g.permission_id
        where g.is_active
          and g.starts_at <= now()
          and (g.ends_at is null or g.ends_at > now())
    )
    select
        -- An active deny ends the question. Checked first and independently of every grant path.
        not exists (select 1 from override where effect = 'deny')
        and (
            exists (select 1 from override where effect = 'grant')
            or exists (
                select 1
                from me
                join public.user_role_assignments ura
                    on ura.user_id = me.id
                   and ura.tenant_id = me.tenant_id
                   and ura.is_active
                   -- AUTH-2 (202607060700): an assignment that has not started grants nothing. The
                   -- same predicate the `override` CTE eight lines above already applies to
                   -- `user_permission_grants`, and the same one `app.visible_branch_ids` and
                   -- `app.visible_department_ids` apply to THIS table.
                   and ura.starts_at <= now()
                   and (ura.ends_at is null or ura.ends_at > now())
                join public.roles r on r.id = ura.role_id and r.is_active
                join public.role_permissions rp on rp.role_id = ura.role_id
                join perm on perm.id = rp.permission_id
            )
        )
        and app.plan_allows((select required_feature_code from perm));
$$;

-- 2. THE EXPLAINABILITY SURFACE. `effective_permissions` restates the precedence rule in the order
-- `has_permission` applies it, and `92_capability_grant_model_test` already proves the two agree for
-- every permission and every actor. It must therefore move in the SAME statement as the authority
-- above, or that suite fails -- which is exactly what it is for. `99_role_assignment_temporal_test`
-- adds the same lockstep assertion for the future-dated actor specifically.
create or replace function app.effective_permissions(p_user_id uuid default null)
returns table (
    permission_key text, capability_group text, action_kind text,
    from_role boolean, user_grant boolean, user_deny boolean,
    plan_allows boolean, effective boolean
)
language sql
stable
security definer
set search_path = ''
as $$
    with target as (
        select coalesce(p_user_id, app.current_user_id()) as uid,
               app.current_tenant_id() as tid
    ),
    rows as (
        select p.key as k,
               p.capability_group as g,
               p.action_kind as a,
               exists (select 1
                         from public.user_role_assignments ura
                         join public.roles r on r.id = ura.role_id and r.is_active
                         join public.role_permissions rp
                              on rp.role_id = ura.role_id and rp.permission_id = p.id
                        where ura.user_id = (select uid from target)
                          and ura.tenant_id = (select tid from target)
                          -- AUTH-2 (202607060700): moved in lockstep with `app.has_permission`.
                          and ura.is_active and ura.starts_at <= now()
                          and (ura.ends_at is null or ura.ends_at > now())) as fr,
               exists (select 1 from public.user_permission_grants ug
                        where ug.user_id = (select uid from target)
                          and ug.tenant_id = (select tid from target)
                          and ug.permission_id = p.id and ug.effect = 'grant' and ug.is_active
                          and ug.starts_at <= now() and (ug.ends_at is null or ug.ends_at > now())) as ugr,
               exists (select 1 from public.user_permission_grants ud
                        where ud.user_id = (select uid from target)
                          and ud.tenant_id = (select tid from target)
                          and ud.permission_id = p.id and ud.effect = 'deny' and ud.is_active
                          and ud.starts_at <= now() and (ud.ends_at is null or ud.ends_at > now())) as udn,
               app.plan_allows(p.required_feature_code) as pa
        from public.permissions p
        where p.is_active
          -- A caller may itemise their OWN permissions freely; itemising someone else's is reading
          -- the tenant's access matrix, which is what MANAGE_PERMISSIONS governs.
          and ((select uid from target) = app.current_user_id()
               or app.has_permission('MANAGE_PERMISSIONS'))
    )
    -- The precedence rule is restated here in exactly the order `has_permission` applies it, and
    -- assertion 11 of the new test proves the two agree for EVERY permission and every actor -- so a
    -- future edit to one that is not made to the other fails a test rather than misleading a reader.
    select k, g, a, fr, ugr, udn, pa,
           (not udn) and (ugr or fr) and pa
    from rows
$$;

-- 3. THE MFA GATE. Same table, same omission. A future-dated `owner` assignment currently makes MFA
-- required today; corrected, the requirement arrives with the role. This moves the gate in the
-- LESS restrictive direction for future-dated rows and is stated plainly rather than buried: no row
-- that exists today is affected, because `starts_at` defaults to `now()` and every current row
-- therefore already satisfies the predicate.
create or replace function app.requires_mfa()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select exists (
        select 1
        from public.users u
        join public.user_role_assignments ura
            on ura.user_id = u.id and ura.tenant_id = u.tenant_id and ura.is_active
           -- AUTH-2 (202607060700).
           and ura.starts_at <= now()
           and (ura.ends_at is null or ura.ends_at > now())
        join public.roles r on r.id = ura.role_id and r.is_active
        where u.auth_user_id = (select auth.uid())
          and u.is_active
          and u.tenant_id = app.current_tenant_id()
          and r.code in ('owner', 'ceo', 'finance_manager', 'system_administrator')
    );
$$;

-- GRANT-1's class. `create or replace` PRESERVES the existing ACL, so these three keep the grants
-- they already carried (`authenticated` on all three) and PUBLIC gains nothing. The revoke is
-- restated anyway because it costs nothing and because every function in this repository that
-- forgot it was caught only by a test.
revoke execute on function app.has_permission(text) from public;
revoke execute on function app.effective_permissions(uuid) from public;
revoke execute on function app.requires_mfa() from public;
grant execute on function app.has_permission(text) to authenticated;
grant execute on function app.effective_permissions(uuid) to authenticated;
grant execute on function app.requires_mfa() to authenticated;
