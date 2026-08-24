-- Migration: rbac_write_authority
-- Plan reference: SPEC-138. Closes the privilege-escalation path that made every other
-- authorization control in ORVION advisory.
--
-- THE DEFECT. `authenticated` holds INSERT and UPDATE on `user_role_assignments`, and that table's
-- only policy was `tenant_id = app.current_tenant_id()`. So this statement, runnable by any
-- employee, satisfied the policy and made the caller an owner:
--
--     insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
--     values (<my tenant>, <my user id>, (select id from public.roles where code='owner'), 'tenant');
--
-- Everything downstream -- app.has_permission, app.authorize, and the entire SPEC-137 read-scope
-- model -- resolves through that table. The same shape applied to `user_branch_assignments` (grant
-- yourself any branch), `users`, `branches`, `departments`, `tenants`, `subscriptions` and
-- `catalog_values`.
--
-- WHY THE RPCs DID NOT ALREADY PREVENT IT. They did, on their own path: `app.assign_user_role`
-- calls `app.authorize('MANAGE_USERS')`, `app.create_branch` calls `authorize('MANAGE_BRANCHES')`,
-- and so on. But those RPCs are SECURITY INVOKER and PostgREST exposes the tables directly, so the
-- check was only ever reached by a caller who chose to go through the front door. The permission
-- each table requires below is taken from its own RPC's authorize() call rather than picked
-- independently, so the table and the RPC cannot drift apart.
--
-- SELECT IS DELIBERATELY UNCHANGED. Reading your own memberships, your branch, or your tenant's
-- catalog is not the risk and is needed by ordinary screens. Only the write commands gain the
-- requirement.
--
-- NOT IN SCOPE, having been checked: `trusted_devices`, `totp_enrollments` and `otp_challenges` are
-- already `owner_only`, and `app.mfa_satisfied()` reads the `aal` claim from the JWT rather than
-- those tables -- a self-inserted row grants nothing.

do $$
declare
    r record;
    v_read text;
    v_write text;
begin
    for r in
        select * from (values
            -- table,                    permission required to write,  the row's tenant column
            ('user_role_assignments',   'MANAGE_USERS',           'tenant_id'),
            ('user_branch_assignments', 'MANAGE_USERS',           'tenant_id'),
            ('users',                   'MANAGE_USERS',           'tenant_id'),
            ('branches',                'MANAGE_BRANCHES',        'tenant_id'),
            ('departments',             'MANAGE_DEPARTMENTS',     'tenant_id'),
            ('subscriptions',           'MANAGE_SUBSCRIPTION',    'tenant_id'),
            ('tenants',                 'MANAGE_TENANT_SETTINGS', 'id')
        ) as t(tbl, permission, tenant_col)
    loop
        v_read  := format('%I = (select app.current_tenant_id())', r.tenant_col);
        v_write := format('%s and (select app.has_permission(%L))', v_read, r.permission);

        execute format('drop policy if exists tenant_isolation on public.%I', r.tbl);
        execute format('drop policy if exists tenant_self on public.%I', r.tbl);

        execute format('create policy scope_read on public.%I for select to authenticated using (%s)', r.tbl, v_read);
        execute format('create policy scope_insert on public.%I for insert to authenticated with check (%s)', r.tbl, v_write);
        execute format('create policy scope_update on public.%I for update to authenticated using (%s) with check (%s)', r.tbl, v_write, v_write);
        execute format('create policy scope_delete on public.%I for delete to authenticated using (%s)', r.tbl, v_write);
    end loop;
end
$$;

-- `catalog_values` keeps its own read policy: canon 35 principle 5 makes it the one deliberate
-- exception, readable when the row is global (`tenant_id is null`) or the caller's own. Only its
-- three write policies are replaced. Extending a tenant's controlled vocabulary is a settings-level
-- act, so it takes the same permission as any other tenant configuration change.
drop policy if exists catalog_tenant_insert on public.catalog_values;
drop policy if exists catalog_tenant_update on public.catalog_values;
drop policy if exists catalog_tenant_delete on public.catalog_values;

create policy catalog_tenant_insert on public.catalog_values for insert to authenticated
    with check (tenant_id = (select app.current_tenant_id())
                and (select app.has_permission('MANAGE_TENANT_SETTINGS')));
create policy catalog_tenant_update on public.catalog_values for update to authenticated
    using (tenant_id = (select app.current_tenant_id())
           and (select app.has_permission('MANAGE_TENANT_SETTINGS')))
    with check (tenant_id = (select app.current_tenant_id())
                and (select app.has_permission('MANAGE_TENANT_SETTINGS')));
create policy catalog_tenant_delete on public.catalog_values for delete to authenticated
    using (tenant_id = (select app.current_tenant_id())
           and (select app.has_permission('MANAGE_TENANT_SETTINGS')));
