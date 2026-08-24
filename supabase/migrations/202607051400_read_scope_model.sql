-- Migration: read_scope_model
-- Plan reference: SPEC-137. Resolves AUDIT-3 by replacing the tenant-only read model with the
-- branch / department / assigned scope model canon 28 defines.
--
-- WHERE THIS STOOD. All 76 RLS policies resolved to `tenant_id` and nothing else, while canon 28
-- defines five scope types, assigns one to every permission, and states that a "Sales employee sees
-- assigned leads only by default". Fourteen VIEW_* permissions were seeded, granted to roles, and
-- enforced nowhere: a trainee could read every lead, booking, quotation, conversation, complaint and
-- invoice in the tenant.
--
-- THE MODEL. A row in a scope-bearing table is readable when ANY of:
--   * the caller has tenant-wide read (VIEW_ALL_BRANCHES -- owner, ceo);
--   * the caller is one of the row's responsible users            -> the `assigned` scope;
--   * the row's branch is one the caller works in, AND either the caller holds VIEW_BRANCH_DATA
--     (branch managers see every department in their branch) or the row's department is one the
--     caller belongs to AND they hold that entity's department-read
--     permission                                                  -> `branch` / `department` scopes.
--
-- Department visibility is what makes business continuity work: when the assigned employee is
-- absent, a colleague in the same department can still see the work needed to serve the customer.
-- Canon 28 requires it to be permission-gated ("Department queue visibility requires explicit
-- permission"); the owner requires it to be available by default. Both hold here -- the mechanism is
-- a permission, and that permission is granted to `employee` and `senior_employee` at the bottom of
-- this migration. `trainee` does not receive it and therefore sees only its own records.
--
-- WHAT IS NOT BRANCH-SCOPED, AND WHY. `customers` stays tenant-visible. Canon 05 (Customer Scope /
-- Customer Cross-Branch Awareness) requires that a customer dealing with two branches is NOT
-- duplicated, and that a limited cross-branch summary -- last interaction date, branch, and employee
-- -- stays visible; those are exactly `last_interaction_at` / `last_interaction_branch_id` /
-- `last_interaction_user_id`. Canon then draws the line at "Detailed event content from another
-- branch is not shown by default", which is what this migration enforces: the customer row is
-- visible, every activity record about them is branch-scoped. Branch-scoping the master row would
-- defeat the uniqueness rule it exists to serve.
--
-- CANON 35 PRINCIPLE 4. Policies must not inline `auth.uid()` logic; they call resolution
-- primitives, so the mechanism evolves in one place. The primitives below are SECURITY DEFINER and
-- live in the non-API `app` schema. They are called as `(select app.f())` scalar subqueries so
-- Postgres hoists them to an InitPlan and evaluates them once per query rather than once per row --
-- the pattern migration 202607048500 established for the tenant resolver.

-- =============================================================================================
-- 1. Constrain the inputs the model now depends on.
--
-- `scope_type` becomes security-critical the moment it decides read authority, and it was free text
-- with no CHECK -- `app.assign_user_role` passes its parameter straight through. A typo ('Branch',
-- 'tenant ') would silently change a user's authority. This is the `scope_type` half of CAT-6,
-- resolved here with cause rather than deferred: canon 28 names the scope vocabulary, so the values
-- are not invented. 'assigned' is deliberately excluded -- it describes a permission's reach over
-- records, not a scope a role assignment can be granted at.
-- =============================================================================================
alter table public.user_role_assignments
    add constraint user_role_assignments_scope_type_check
    check (scope_type in ('tenant', 'branch', 'department', 'platform'));

-- A branch-scoped assignment without a branch, or a department-scoped one without a department,
-- resolves to no authority at all -- silently, which is the dangerous failure. Reject it at write.
alter table public.user_role_assignments
    add constraint user_role_assignments_scope_qualifier_check
    check (
        (scope_type = 'branch' and branch_id is not null)
        or (scope_type = 'department' and department_id is not null)
        or (scope_type in ('tenant', 'platform') and branch_id is null and department_id is null)
    );

-- `app.create_task` resolves an owner's placement with `where is_primary and ends_at is null limit 1`.
-- Nothing stopped a user having two such rows, which makes that lookup -- and therefore the branch a
-- record is filed under -- non-deterministic. One current primary placement per user.
create unique index if not exists user_branch_assignments_one_current_primary_idx
    on public.user_branch_assignments (tenant_id, user_id)
    where is_primary and ends_at is null;

-- =============================================================================================
-- 2. Resolution primitives (canon 35 principle 4).
-- =============================================================================================

-- The caller's ORVION user id inside the active tenant. Every other primitive builds on this, and
-- it is the `assigned` scope's whole implementation.
create or replace function app.current_user_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
    select u.id
    from public.users u
    where u.auth_user_id = (select auth.uid())
      and u.is_active
      and u.tenant_id = app.current_tenant_id()
    limit 1
$$;

-- Tenant-wide read is the `tenant` scope: canon 28 grants VIEW_ALL_BRANCHES to owner and ceo, and
-- notes "CEO sees all branches". Expressed as a permission rather than a role list so a tenant can
-- extend it through RBAC without a migration.
create or replace function app.has_tenant_wide_read()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
    select app.has_permission('VIEW_ALL_BRANCHES')
$$;

-- The branches the caller may read. Two independent sources, deliberately unioned:
--   * where they WORK  -- a current `user_branch_assignments` row (the org placement record);
--   * where they GOVERN -- a branch- or department-scoped role assignment (the RBAC record).
-- A branch manager is normally both, but the two are not the same fact and neither implies the
-- other: an auditor may govern a branch they do not work in.
create or replace function app.visible_branch_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
    select b.id
    from public.branches b
    where b.tenant_id = app.current_tenant_id()
      and app.has_tenant_wide_read()
    union
    select uba.branch_id
    from public.user_branch_assignments uba
    where uba.user_id = app.current_user_id()
      and uba.tenant_id = app.current_tenant_id()
      and uba.starts_at <= now()
      and (uba.ends_at is null or uba.ends_at > now())
    union
    select ura.branch_id
    from public.user_role_assignments ura
    where ura.user_id = app.current_user_id()
      and ura.tenant_id = app.current_tenant_id()
      and ura.is_active
      and ura.branch_id is not null
      and ura.starts_at <= now()
      and (ura.ends_at is null or ura.ends_at > now())
$$;

-- The departments the caller belongs to or governs. Same two sources, same reasoning.
create or replace function app.visible_department_ids()
returns setof uuid
language sql
stable
security definer
set search_path = ''
as $$
    select uba.department_id
    from public.user_branch_assignments uba
    where uba.user_id = app.current_user_id()
      and uba.tenant_id = app.current_tenant_id()
      and uba.department_id is not null
      and uba.starts_at <= now()
      and (uba.ends_at is null or uba.ends_at > now())
    union
    select ura.department_id
    from public.user_role_assignments ura
    where ura.user_id = app.current_user_id()
      and ura.tenant_id = app.current_tenant_id()
      and ura.is_active
      and ura.department_id is not null
      and ura.starts_at <= now()
      and (ura.ends_at is null or ura.ends_at > now())
$$;

revoke execute on function app.current_user_id() from public;
revoke execute on function app.has_tenant_wide_read() from public;
revoke execute on function app.visible_branch_ids() from public;
revoke execute on function app.visible_department_ids() from public;
grant execute on function app.current_user_id() to authenticated;
grant execute on function app.has_tenant_wide_read() to authenticated;
grant execute on function app.visible_branch_ids() to authenticated;
grant execute on function app.visible_department_ids() to authenticated;

-- =============================================================================================
-- 3. Scope-bearing tables.
--
-- `leads` and `bookings` each carry TWO placements: `branch_id`/`department_id` (NOT NULL) and
-- `owner_branch_id`/`owner_department_id` (nullable). Both are canonical (31_schema_draft). Isolation
-- uses the NOT NULL pair -- a mandatory column cannot produce the invisible-row failure a nullable
-- one can. The nullable triple records responsibility, and feeds the `assigned` axis instead.
--
-- The predicate is applied to USING and WITH CHECK alike: the owner's directive is that Branch A
-- staff may not "see or operate on" Branch B's data, and a read-only restriction would leave the
-- write path open. Every write RPC is SECURITY INVOKER (67 of 82 app functions are), so these
-- policies govern the RPC path too -- which is why step 4 repairs the four RPCs that did not
-- populate the ownership triple.
-- =============================================================================================
-- Department visibility is gated by a PERMISSION, not by membership alone. Membership-only was the
-- first cut and test 21 rejected it: a trainee placed in Cairo Sales inherited every Cairo Sales
-- lead, because being in the department was the whole test. Canon 28 is explicit -- "Department
-- queue visibility requires explicit permission" -- and that permission is exactly what makes the
-- trainee boundary real rather than incidental.
--
-- Canon names a VIEW_* permission for five of these entities, so those five become genuinely
-- enforced here for the first time. It names none for bookings, booking items or quotations;
-- VIEW_DEPARTMENT_RECORDS is minted below for those rather than stretching VIEW_DEPARTMENT_QUEUE
-- (a leads concept) to cover a booking.
insert into public.permissions (key, name, description, is_system, is_active)
values ('VIEW_DEPARTMENT_RECORDS',
        'View department records',
        'Read booking, booking item and quotation records belonging to the holder''s own department. '
        'The department-scope read gate for the entities canon 28 does not name a VIEW_* permission for.',
        true, true)
on conflict (key) do nothing;

do $$
declare
    r record;
    v_predicate text;
begin
    for r in
        select * from (values
            -- table,            branch column,       department column,     responsible-user columns,                                        department-read permission
            ('leads',            'branch_id',         'department_id',       array['owner_user_id','assigned_user_id'],                        'VIEW_DEPARTMENT_QUEUE'),
            ('bookings',         'branch_id',         'department_id',       array['owner_user_id'],                                           'VIEW_DEPARTMENT_RECORDS'),
            ('booking_items',    'owner_branch_id',   'owner_department_id', array['owner_user_id','sales_owner_user_id','operational_owner_user_id'], 'VIEW_DEPARTMENT_RECORDS'),
            ('tasks',            'owner_branch_id',   'owner_department_id', array['owner_user_id'],                                           'VIEW_DEPARTMENT_TASK_QUEUE'),
            ('conversations',    'owner_branch_id',   'owner_department_id', array['owner_user_id'],                                           'VIEW_CONVERSATION'),
            ('complaints',       'owner_branch_id',   'owner_department_id', array['owner_user_id'],                                           'VIEW_COMPLAINT'),
            ('service_requests', 'owner_branch_id',   'owner_department_id', array['owner_user_id'],                                           'VIEW_SERVICE_REQUEST'),
            ('quotations',       'owner_branch_id',   'owner_department_id', array['owner_user_id'],                                           'VIEW_DEPARTMENT_RECORDS')
        ) as t(tbl, branch_col, dept_col, owner_cols, dept_permission)
    loop
        v_predicate := format(
            'tenant_id = (select app.current_tenant_id()) and ('
            '  (select app.has_tenant_wide_read())'
            '  or (select app.current_user_id()) in (%s)'
            '  or ( %I in (select app.visible_branch_ids())'
            '       and ( (select app.has_permission(''VIEW_BRANCH_DATA''))'
            '             or ( (select app.has_permission(%L))'
            '                  and %I in (select app.visible_department_ids()) ) ) )'
            ')',
            (select string_agg(quote_ident(c), ', ') from unnest(r.owner_cols) as c),
            r.branch_col, r.dept_permission, r.dept_col);

        execute format('drop policy if exists tenant_isolation on public.%I', r.tbl);
        execute format('drop policy if exists scope_isolation on public.%I', r.tbl);
        execute format(
            'create policy scope_isolation on public.%I for all to authenticated using (%s) with check (%s)',
            r.tbl, v_predicate, v_predicate);
    end loop;
end
$$;

-- A booking item is part of its booking: whoever may see the booking may see what was booked. This
-- also covers items whose own (nullable) triple is unset, which would otherwise be invisible to
-- everyone -- a fail-closed gap rather than a leak, but a gap all the same. RLS applies to
-- `bookings` inside this subquery, so the item inherits exactly the booking's scope.
drop policy if exists scope_isolation on public.booking_items;
create policy scope_isolation on public.booking_items for all to authenticated
using (
    tenant_id = (select app.current_tenant_id()) and (
        (select app.has_tenant_wide_read())
        or (select app.current_user_id()) in (owner_user_id, sales_owner_user_id, operational_owner_user_id)
        or exists (select 1 from public.bookings b where b.id = booking_items.booking_id)
        or ( owner_branch_id in (select app.visible_branch_ids())
             and ( (select app.has_permission('VIEW_BRANCH_DATA'))
                   or ( (select app.has_permission('VIEW_DEPARTMENT_RECORDS'))
                        and owner_department_id in (select app.visible_department_ids()) ) ) )
    )
)
with check (
    tenant_id = (select app.current_tenant_id()) and (
        (select app.has_tenant_wide_read())
        or (select app.current_user_id()) in (owner_user_id, sales_owner_user_id, operational_owner_user_id)
        or exists (select 1 from public.bookings b where b.id = booking_items.booking_id)
        or ( owner_branch_id in (select app.visible_branch_ids())
             and ( (select app.has_permission('VIEW_BRANCH_DATA'))
                   or ( (select app.has_permission('VIEW_DEPARTMENT_RECORDS'))
                        and owner_department_id in (select app.visible_department_ids()) ) ) )
    )
);

-- =============================================================================================
-- 4. Derived children: scoped through their parent, never independently.
--
-- Each child carries no scope columns of its own, and inventing some would create a second source
-- of truth that could disagree with the parent. `exists` against the parent is enough: RLS on the
-- parent applies inside the subquery, so the child inherits the parent's scope automatically and
-- stays correct when the parent's rule changes. No recursion risk -- none of these parents'
-- policies reference their children.
-- =============================================================================================
do $$
declare
    r record;
    v_predicate text;
begin
    for r in
        select * from (values
            ('conversation_messages',   'conversations', 'conversation_id'),
            ('quotation_items',         'quotations',    'quotation_id'),
            ('booking_item_passengers', 'booking_items', 'booking_item_id'),
            ('lead_interactions',       'leads',         'lead_id'),
            ('lead_assignments',        'leads',         'lead_id')
        ) as t(tbl, parent, fk)
    loop
        v_predicate := format(
            'tenant_id = (select app.current_tenant_id()) '
            'and exists (select 1 from public.%I p where p.id = public.%I.%I)',
            r.parent, r.tbl, r.fk);
        execute format('drop policy if exists tenant_isolation on public.%I', r.tbl);
        execute format('drop policy if exists scope_isolation on public.%I', r.tbl);
        execute format(
            'create policy scope_isolation on public.%I for all to authenticated using (%s) with check (%s)',
            r.tbl, v_predicate, v_predicate);
    end loop;
end
$$;

-- =============================================================================================
-- 5. Financial records.
--
-- Canon 28 scopes VIEW_FINANCIAL_DOCUMENTS as tenant/branch/assigned and notes: "Assigned employee
-- may view financial documents directly related to their lead/booking." That is exactly two
-- clauses -- the permission (finance roles, tenant-wide) or a visible related booking/item (the
-- assigned employee's own work). The `exists` clauses inherit the scope built above, so an employee
-- sees the invoice for their own booking and nothing else.
-- =============================================================================================
drop policy if exists tenant_isolation on public.invoices;
create policy scope_isolation on public.invoices for all to authenticated
using (
    tenant_id = (select app.current_tenant_id()) and (
        (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS'))
        or (booking_id is not null and exists (select 1 from public.bookings b where b.id = invoices.booking_id))
        or (booking_item_id is not null and exists (select 1 from public.booking_items bi where bi.id = invoices.booking_item_id))
    )
)
with check (
    tenant_id = (select app.current_tenant_id()) and (
        (select app.has_permission('VIEW_FINANCIAL_DOCUMENTS'))
        or (booking_id is not null and exists (select 1 from public.bookings b where b.id = invoices.booking_id))
        or (booking_item_id is not null and exists (select 1 from public.booking_items bi where bi.id = invoices.booking_item_id))
    )
);

do $$
declare
    r record;
    v_predicate text;
begin
    for r in
        select * from (values
            ('payments', 'tenant_id = (select app.current_tenant_id()) and ('
                       || ' (select app.has_permission(''VIEW_FINANCIAL_DOCUMENTS''))'
                       || ' or (booking_id is not null and exists (select 1 from public.bookings b where b.id = public.payments.booking_id))'
                       || ' or (booking_item_id is not null and exists (select 1 from public.booking_items bi where bi.id = public.payments.booking_item_id)))'),
            ('refunds',  'tenant_id = (select app.current_tenant_id()) and ('
                       || ' (select app.has_permission(''VIEW_FINANCIAL_DOCUMENTS''))'
                       || ' or (booking_id is not null and exists (select 1 from public.bookings b where b.id = public.refunds.booking_id))'
                       || ' or (booking_item_id is not null and exists (select 1 from public.booking_items bi where bi.id = public.refunds.booking_item_id)))'),
            ('receipts', 'tenant_id = (select app.current_tenant_id()) and ('
                       || ' (select app.has_permission(''VIEW_FINANCIAL_DOCUMENTS''))'
                       || ' or exists (select 1 from public.payments p where p.id = public.receipts.payment_id))'),
            ('payment_allocations', 'tenant_id = (select app.current_tenant_id()) and ('
                       || ' (select app.has_permission(''VIEW_FINANCIAL_DOCUMENTS''))'
                       || ' or exists (select 1 from public.invoices i where i.id = public.payment_allocations.invoice_id))')
        ) as t(tbl, predicate)
    loop
        execute format('drop policy if exists tenant_isolation on public.%I', r.tbl);
        execute format('drop policy if exists scope_isolation on public.%I', r.tbl);
        execute format(
            'create policy scope_isolation on public.%I for all to authenticated using (%s) with check (%s)',
            r.tbl, r.predicate, r.predicate);
    end loop;
end
$$;

-- =============================================================================================
-- 6. Notifications are personal, not tenant-wide.
--
-- `notifications.target_user_id` names one recipient, yet the tenant-only policy let every employee
-- read every other employee's notifications -- an unintended disclosure of who is being told what,
-- and of the records they concern. There is no management-override clause here on purpose: a
-- notification is addressed correspondence, and the underlying records remain readable on their own
-- terms through the scope model above.
-- =============================================================================================
drop policy if exists tenant_isolation on public.notifications;
create policy scope_isolation on public.notifications for all to authenticated
using (tenant_id = (select app.current_tenant_id()) and target_user_id = (select app.current_user_id()))
with check (tenant_id = (select app.current_tenant_id()) and target_user_id = (select app.current_user_id()));

drop policy if exists tenant_isolation on public.notification_deliveries;
create policy scope_isolation on public.notification_deliveries for all to authenticated
using (tenant_id = (select app.current_tenant_id())
       and exists (select 1 from public.notifications n where n.id = public.notification_deliveries.notification_id))
with check (tenant_id = (select app.current_tenant_id())
       and exists (select 1 from public.notifications n where n.id = public.notification_deliveries.notification_id));

-- A confidential customer note is confidential from colleagues, which is the only reading of the
-- flag that means anything. Non-confidential notes follow the customer record (tenant-visible per
-- canon 05); confidential ones are visible to their author and to tenant-wide readers.
drop policy if exists tenant_isolation on public.customer_notes;
create policy scope_isolation on public.customer_notes for all to authenticated
using (
    tenant_id = (select app.current_tenant_id())
    and (not is_confidential
         or created_by = (select app.current_user_id())
         or (select app.has_tenant_wide_read()))
)
with check (
    tenant_id = (select app.current_tenant_id())
    and (not is_confidential
         or created_by = (select app.current_user_id())
         or (select app.has_tenant_wide_read()))
);

-- =============================================================================================
-- 7. Align role_permissions with the model.
-- =============================================================================================

-- Department visibility for the ranks that do the operational work. Canon 28 marks Employee "No" for
-- the department queues; the owner's directive of 2026-08-24 requires that a colleague in the same
-- department can continue serving a customer when the assigned employee is absent, and that
-- assignment must not mean sole visibility. The mechanism stays permission-gated exactly as canon
-- requires -- this changes the default grant, not the design -- and `trainee` is deliberately
-- excluded, which is what keeps the restricted-user boundary real.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.key in (
    'VIEW_DEPARTMENT_QUEUE', 'VIEW_DEPARTMENT_TASK_QUEUE', 'VIEW_DEPARTMENT_RECORDS',
    'VIEW_COMPLAINT', 'VIEW_CONVERSATION', 'VIEW_SERVICE_REQUEST')
where r.code in ('employee', 'senior_employee')
on conflict do nothing;

-- Canon 28: "Branch Manager sees all departments inside their branch" (VIEW_BRANCH_DATA, "Own
-- branch"). Only owner and ceo held it, which would have left a branch manager able to see just
-- their own department. Department managers are deliberately NOT granted it -- canon confines them
-- to "their department inside their branch", which the department clause already provides.
insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on p.key = 'VIEW_BRANCH_DATA'
where r.code = 'branch_manager'
on conflict do nothing;
