-- Migration: plan_gating
-- Plan reference: SPEC-146. Makes canon 28's "Plan denial overrides user role permission" true.
--
-- WHERE THIS STOOD. SPEC-141 seeded the plan matrix -- 16 capability switches and 6 numeric ceilings
-- across three plans, straight from canon 28 and canon 17. Nothing read it. A Starter tenant whose
-- plan excludes Booking could create bookings all day, because the only question anyone asked was
-- "does your role permit this?"
--
-- WHERE THE GATE SITS, AND WHY THERE. Canon 35 principle 8 deliberately left this open ("decided at
-- implementation, not here"). The choice is now made: **inside `app.has_permission()`**. That is the
-- single function every RLS policy and every `app.authorize()` already calls, which means one change
-- covers, without exception:
--
--   * every RPC (they all authorize through it);
--   * every direct PostgREST read and write (the policies call it);
--   * every future n8n call (same RPCs, same policies);
--   * a future UI, which cannot construct a path that skips it.
--
-- This is canon 35 principle 4 applied to a second concern: the mechanism evolves in one place. Any
-- other location -- a check per RPC, a wrapper the UI is trusted to call -- would leave the direct
-- path open, which is the failure this whole hardening pass exists to eliminate.
--
-- ROLE PERMISSION REMAINS MEANINGFUL. The plan does not grant anything. It only removes. A user still
-- needs the role permission first; the plan can then take it away. Both must say yes.

-- ---------------------------------------------------------------------------------------------
-- 1. Which feature does a permission depend on?
--
-- An attribute of the permission, so it lives on the permission -- no new table, no new policy, and
-- queryable by anything that can already read `permissions`.
-- ---------------------------------------------------------------------------------------------
alter table public.permissions
    add column if not exists required_feature_code text;

comment on column public.permissions.required_feature_code is
    'Canon 28 Feature Access By Plan: the plan feature this permission depends on. NULL means the permission is not plan-gated. Plan denial overrides role permission.';

alter table public.permissions
    add constraint permissions_required_feature_code_check
    check (required_feature_code is null or required_feature_code in (
        'crm', 'customers', 'booking', 'documents', 'suppliers',
        'finance_lite', 'full_finance', 'basic_reporting', 'advanced_dashboards',
        'api_read_only', 'api_full', 'automation', 'integrations',
        'offline_conversion', 'ai_dashboard', 'multi_branch'
    ));

-- The mapping is taken from canon 28's own feature names matched against each permission's domain.
-- Only unambiguous pairings are made; the reasoning for every omission is recorded in the CR rather
-- than guessed at here.
update public.permissions set required_feature_code = 'booking'
 where key in ('CREATE_BOOKING','CREATE_BOOKING_ITEM','APPROVE_BOOKING','ISSUE_BOOKING',
               'CANCEL_BOOKING','REFUND_BOOKING','REISSUE_BOOKING','UPDATE_BOOKING_ITEM_STATUS',
               'ALLOW_ISSUE_WITH_NEGATIVE_BALANCE','ENTER_COST','ENTER_SELLING_PRICE');

update public.permissions set required_feature_code = 'documents'
 where key in ('UPLOAD_DOCUMENT','ARCHIVE_DOCUMENT','CREATE_DOCUMENT_VERSION','VIEW_TRAVEL_DOCUMENTS');

update public.permissions set required_feature_code = 'suppliers'
 where key in ('ASSIGN_SUPPLIER');

update public.permissions set required_feature_code = 'finance_lite'
 where key in ('CREATE_INVOICE','CREATE_RECEIPT','RECORD_PAYMENT','RECORD_REFUND',
               'APPROVE_FINANCE','SET_EXCHANGE_RATE','VIEW_FINANCIAL_DOCUMENTS');

update public.permissions set required_feature_code = 'full_finance'
 where key in ('CREATE_JOURNAL_ENTRY','EDIT_LOCKED_COST','CREATE_EXCHANGE_RATE_ADJUSTMENT');

update public.permissions set required_feature_code = 'advanced_dashboards'
 where key in ('VIEW_ADVANCED_DASHBOARDS');

update public.permissions set required_feature_code = 'api_read_only'
 where key in ('ACCESS_API_READ_ONLY');

update public.permissions set required_feature_code = 'api_full'
 where key in ('ACCESS_API_FULL');

-- ---------------------------------------------------------------------------------------------
-- 2. Does the tenant's plan currently include a feature?
--
-- FAIL-OPEN ON ABSENCE, and this is a deliberate reading of canon rather than a convenience. Canon
-- says plan *denial* overrides role permission -- a denial requires a plan that denies. A tenant with
-- no subscription row has not been sold anything and therefore has not been denied anything, and the
-- same holds for a feature the matrix does not mention. Fail-closed would instead lock out every
-- tenant the platform has not yet provisioned, which is a worse failure and not what canon says.
--
-- It cannot be abused: SPEC-138 gated `subscriptions` writes behind MANAGE_SUBSCRIPTION, which no
-- role holds, so a tenant cannot delete their own subscription to escape a restriction.
--
-- The terminal states deny everything. `read_only` still allows features -- restricting WRITES for a
-- read-only tenant is subscription-STATE gating, which canon 35 principle 8 keeps as a distinct
-- concern from plan gating and which is not attempted here.
-- ---------------------------------------------------------------------------------------------
create or replace function app.plan_allows(p_feature_code text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select case
        when p_feature_code is null then true
        else coalesce((
            select fe.is_enabled
               and s.subscription_status_code in ('trial', 'active', 'grace_period', 'read_only')
            from public.subscriptions s
            join public.feature_entitlements fe
              on fe.subscription_plan_id = s.subscription_plan_id
             and fe.feature_code = p_feature_code
            where s.tenant_id = app.current_tenant_id()
            order by s.created_at desc
            limit 1
        ), true)
    end
$$;

create or replace function app.plan_limit(p_feature_code text)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
    -- NULL means no ceiling. Canon 17's "Unlimited" and "Custom" are both the absence of a limit,
    -- never a large number a caller might compare against and act on.
    select fe.limit_value
    from public.subscriptions s
    join public.feature_entitlements fe
      on fe.subscription_plan_id = s.subscription_plan_id
     and fe.feature_code = p_feature_code
    where s.tenant_id = app.current_tenant_id()
    order by s.created_at desc
    limit 1
$$;

-- What a UI or an n8n workflow should ask, instead of inferring capability from a failed write.
-- Returns the whole picture in one call: what the plan includes, and what it caps.
create or replace function app.tenant_capabilities()
returns table (feature_code text, is_enabled boolean, limit_value numeric)
language sql
stable
security definer
set search_path = ''
as $$
    select fe.feature_code,
           fe.is_enabled and s.subscription_status_code in ('trial', 'active', 'grace_period', 'read_only'),
           fe.limit_value
    from public.subscriptions s
    join public.feature_entitlements fe on fe.subscription_plan_id = s.subscription_plan_id
    where s.tenant_id = app.current_tenant_id()
    order by fe.feature_code
$$;

revoke execute on function app.plan_allows(text) from public;
revoke execute on function app.plan_limit(text) from public;
revoke execute on function app.tenant_capabilities() from public;
grant execute on function app.plan_allows(text) to authenticated;
grant execute on function app.plan_limit(text) to authenticated;
grant execute on function app.tenant_capabilities() to authenticated;

-- ---------------------------------------------------------------------------------------------
-- 3. Compose the plan gate into the one function everything already calls.
--
-- The role check is unchanged and still comes first -- a plan grants nothing on its own. The `and`
-- is the whole of "plan denial overrides user role permission".
-- ---------------------------------------------------------------------------------------------
create or replace function app.has_permission(p_permission_key text)
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
            on ura.user_id = u.id
           and ura.tenant_id = u.tenant_id
           and ura.is_active
           and (ura.ends_at is null or ura.ends_at > now())
        join public.roles r on r.id = ura.role_id and r.is_active
        join public.role_permissions rp on rp.role_id = ura.role_id
        join public.permissions p on p.id = rp.permission_id
            and p.is_active
            and p.key = p_permission_key
        where u.auth_user_id = (select auth.uid())
          and u.is_active
          and u.tenant_id = app.current_tenant_id()
    )
    and app.plan_allows((select p.required_feature_code from public.permissions p where p.key = p_permission_key));
$$;

-- ---------------------------------------------------------------------------------------------
-- 4. The remaining read permissions that were enforced nowhere.
-- ---------------------------------------------------------------------------------------------

-- Canon 28 marks the trainee "Limited" for the assigned queues, and the seed gave them nothing at
-- all. Granting exactly those two is what "Limited" means for a restricted user: their own work and
-- no queue. Without this, gating the assigned clause below would remove a trainee's access to the
-- records assigned to them, which canon does not say.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.key in ('VIEW_ASSIGNED_LEADS', 'VIEW_ASSIGNED_TASKS')
where r.code = 'trainee'
on conflict do nothing;

-- The `assigned` scope was the one clause in the read model that asked no permission at all. Canon 28
-- names a permission for it on both entities, so it asks for one now.
do $$
declare
    r record;
    v_predicate text;
begin
    for r in
        select * from (values
            ('leads', 'branch_id',       'department_id',       'owner_user_id, assigned_user_id', 'VIEW_DEPARTMENT_QUEUE',      'VIEW_ASSIGNED_LEADS'),
            ('tasks', 'owner_branch_id', 'owner_department_id', 'owner_user_id',                   'VIEW_DEPARTMENT_TASK_QUEUE', 'VIEW_ASSIGNED_TASKS')
        ) as t(tbl, branch_col, dept_col, owner_cols, dept_permission, assigned_permission)
    loop
        v_predicate := format(
            'tenant_id = (select app.current_tenant_id()) and ('
            '  (select app.has_tenant_wide_read())'
            '  or ( (select app.has_permission(%L)) and (select app.current_user_id()) in (%s) )'
            '  or ( %I in (select app.visible_branch_ids())'
            '       and ( (select app.has_permission(''VIEW_BRANCH_DATA''))'
            '             or ( (select app.has_permission(%L))'
            '                  and %I in (select app.visible_department_ids()) ) ) )'
            ')',
            r.assigned_permission, r.owner_cols,
            r.branch_col, r.dept_permission, r.dept_col);

        execute format('drop policy if exists scope_isolation on public.%I', r.tbl);
        execute format(
            'create policy scope_isolation on public.%I for all to authenticated using (%s) with check (%s)',
            r.tbl, v_predicate, v_predicate);
    end loop;
end
$$;

-- Marketing and subscription state are tenant-wide reporting surfaces, and canon 28 gives each its
-- own VIEW_* permission rather than leaving them readable by everyone in the company.
drop policy if exists tenant_isolation on public.marketing_campaigns;
create policy scope_isolation on public.marketing_campaigns for all to authenticated
using (tenant_id = (select app.current_tenant_id())
       and (select app.has_permission('VIEW_MARKETING_DASHBOARD')))
with check (tenant_id = (select app.current_tenant_id())
       and (select app.has_permission('MANAGE_MARKETING_CAMPAIGN')));

drop policy if exists tenant_isolation on public.campaign_daily_metrics;
create policy scope_isolation on public.campaign_daily_metrics for all to authenticated
using (tenant_id = (select app.current_tenant_id())
       and (select app.has_permission('VIEW_MARKETING_DASHBOARD')))
with check (tenant_id = (select app.current_tenant_id())
       and (select app.has_permission('MANAGE_MARKETING_CAMPAIGN')));

-- `subscriptions` write authority was set by SPEC-138 (MANAGE_SUBSCRIPTION); only the read side is
-- narrowed here, from "everyone in the tenant" to the roles canon names.
drop policy if exists scope_read on public.subscriptions;
create policy scope_read on public.subscriptions for select to authenticated
    using (tenant_id = (select app.current_tenant_id())
           and (select app.has_permission('VIEW_SUBSCRIPTION_STATUS')));
