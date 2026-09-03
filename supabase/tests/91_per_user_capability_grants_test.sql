-- pgTAP: RBAC-3 / ADR-0027 -- capability grants are per-USER, not only per-role.
--
-- WHY THIS FILE EXISTS AT ALL. `202607059800` was applied to Primary on 2026-09-02 and never
-- committed; it was recovered from Primary's migration ledger on 2026-09-03, byte-identical. The
-- database returns SQL, not tests, so this file is the reconstructed behavioural half.
--
-- WHAT MUST BE TRUE, and each of these is a distinct owner requirement rather than one feature:
--   * a role grant still works exactly as before  (the refactor expanded no privilege);
--   * a capability can be granted to ONE USER without inventing a role;
--   * a capability can be DENIED to one user even though their role grants it;
--   * DENY beats GRANT, unconditionally -- the AWS IAM / Azure rule, adopted rather than invented;
--   * the PLAN gate still overrides BOTH, so a tenant administrator can never grant past a
--     commercial entitlement -- the one thing a per-user grant must not be able to do;
--   * only MANAGE_PERMISSIONS may write a grant;
--   * `app.effective_permissions` explains a decision and never DISAGREES with it.
--
-- The last one is the load-bearing assertion: an explainer that can drift from the decision it
-- claims to explain is worse than no explainer, because an administrator would trust it.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into auth.users (id, email, email_confirmed_at) values
  ('91000000-0000-0000-0000-0000000000a1','owner@rbac91.test', now()),
  ('91000000-0000-0000-0000-0000000000a2','emp@rbac91.test',   now());
-- Two tenants on DIFFERENT plans. The starter tenant is not decoration: it is the only way to prove
-- the plan gate still outranks a direct user grant.
insert into public.tenants (id, name, slug, status) values
  ('91000000-0000-0000-0000-000000000001','Ent Travel','rbac91-ent','active'),
  ('91000000-0000-0000-0000-000000000002','Starter Travel','rbac91-str','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '91000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '91000000-0000-0000-0000-000000000002', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'starter';
insert into public.branches (id, tenant_id, name, slug) values
  ('91000000-0000-0000-0000-00000000000a','91000000-0000-0000-0000-000000000001','HQ','rbac91-hq'),
  ('91000000-0000-0000-0000-00000000000b','91000000-0000-0000-0000-000000000002','HQ2','rbac91-hq2');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('91000000-0000-0000-0000-0000000000c1','91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-00000000000a','management','Exec'),
  ('91000000-0000-0000-0000-0000000000c2','91000000-0000-0000-0000-000000000002','91000000-0000-0000-0000-00000000000b','management','Exec2');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('91000000-0000-0000-0000-000000000011','91000000-0000-0000-0000-000000000001','Owner','owner@rbac91.test',true,'91000000-0000-0000-0000-0000000000a1'),
  ('91000000-0000-0000-0000-000000000012','91000000-0000-0000-0000-000000000001','Emp','emp@rbac91.test',true,'91000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '91000000-0000-0000-0000-000000000001', u,
       '91000000-0000-0000-0000-00000000000a','91000000-0000-0000-0000-0000000000c1', true
from unnest(array['91000000-0000-0000-0000-000000000011'::uuid,
                  '91000000-0000-0000-0000-000000000012'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '91000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('91000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('91000000-0000-0000-0000-000000000012'::uuid,'employee')) v(u,rc)
join public.roles r on r.code = v.rc;

-- =============================================================================================
-- 1-3. THE REFACTOR EXPANDED NO PRIVILEGE. With the grant table EMPTY, `has_permission` must return
--      exactly what the role-only model returned. This is the assertion that makes the whole change
--      safe to have shipped, and it is deliberately first.
-- =============================================================================================
-- Scoped to THIS file's tenant, not global. The global form failed Pass B (the second, un-reset run)
-- because `verify_role_journeys.ps1` leaves a real grant row behind by design -- an order-dependent
-- premise, which is precisely the TEST-2 class the second pass exists to catch, caught here in this
-- file's own first assertion.
select is(
  (select count(*)::int from public.user_permission_grants
    where tenant_id = '91000000-0000-0000-0000-000000000001'), 0,
  'PREMISE: this tenant has no per-user grant yet -- so every result below is the role-only answer');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a2"}', true);

select is(
  app.has_permission('CREATE_LEAD'), true,
  'ROLE GRANT UNCHANGED: employee still holds CREATE_LEAD through its role, with the grant table empty');

select is(
  app.has_permission('CREATE_JOURNAL_ENTRY'), false,
  '...and still does NOT hold CREATE_JOURNAL_ENTRY -- the baseline the direct grant below will move');

-- =============================================================================================
-- 4-6. WHO MAY WRITE A GRANT. The capability matrix is the most sensitive table in the system: an
--      actor who can edit it can give themselves everything.
-- =============================================================================================
select is(
  app.has_permission('MANAGE_PERMISSIONS'), false,
  'CONTROL: the employee does NOT hold MANAGE_PERMISSIONS -- the premise of the refusal below');

select throws_ok(
  $$insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect)
    select '91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000012', p.id, 'grant'
    from public.permissions p where p.key = 'CREATE_JOURNAL_ENTRY'$$,
  '42501', null,
  'RBAC-3: an employee CANNOT grant themselves a capability -- the RLS policy scope_insert charges MANAGE_PERMISSIONS');

reset role;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select is(
  app.has_permission('MANAGE_PERMISSIONS'), true,
  'POSITIVE CONTROL: the owner DOES hold MANAGE_PERMISSIONS -- so the write below tests the policy, not the role');

-- =============================================================================================
-- 7-9. THE DIRECT USER GRANT. The owner's requirement: open one capability to one person without
--      inventing an artificial role for them.
-- =============================================================================================
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000012', p.id, 'grant',
       'covering finance while the manager is on hajj leave'
from public.permissions p where p.key = 'CREATE_JOURNAL_ENTRY';

select is(
  (select count(*)::int from public.user_permission_grants where effect = 'grant'), 1,
  '...and the grant row EXISTS -- "did not throw" is not evidence that a write occurred');

-- The actor is DERIVED, never accepted: `app.derive_created_by` is attached exactly as it is on the
-- sibling identity tables (ATTR-2's class).
select is(
  (select created_by from public.user_permission_grants where effect = 'grant'),
  '91000000-0000-0000-0000-000000000011'::uuid,
  '...with created_by DERIVED from the session -- an access-grant audit row must not accept its own author');

reset role;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select is(
  app.has_permission('CREATE_JOURNAL_ENTRY'), true,
  'RBAC-3: the employee NOW holds CREATE_JOURNAL_ENTRY -- granted to the person, with no role invented and no role edited');

-- =============================================================================================
-- 10-11. THE DENY, AND ITS PRECEDENCE. This is the requirement a role-only model cannot express at
--        all: "this user must never have this", even though their role grants it.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000012', p.id, 'deny',
       'under investigation'
from public.permissions p where p.key = 'CREATE_LEAD';

reset role;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select is(
  app.has_permission('CREATE_LEAD'), false,
  'DENY OVERRIDES ROLE: the employee''s role still grants CREATE_LEAD and the answer is now NO -- the AWS IAM / Azure rule, adopted rather than invented');

-- A deny and a grant on the SAME capability is not a contradiction to be resolved by ordering; deny
-- must win regardless of which row was written first.
reset role;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '91000000-0000-0000-0000-000000000001','91000000-0000-0000-0000-000000000012', p.id, 'deny',
       'and denied as well'
from public.permissions p where p.key = 'CREATE_JOURNAL_ENTRY';

reset role;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select is(
  app.has_permission('CREATE_JOURNAL_ENTRY'), false,
  'DENY OVERRIDES A DIRECT GRANT TOO: grant and deny coexist on one capability and deny wins -- precedence is a rule, not an accident of insert order');

-- =============================================================================================
-- 12. THE COMMERCIAL BOUNDARY. The single most important property of the whole model: a tenant
--     administrator must NEVER be able to grant a capability the subscription does not entitle.
--     `EDIT_LOCKED_COST` requires the `full_finance` feature, which starter does not carry.
-- =============================================================================================
reset role;
-- The claims MUST be cleared before building the second tenant's fixture. Left set, the session is
-- still tenant 1's owner, so `app.derive_created_by` stamps a tenant-1 actor onto a tenant-2 row and
-- `user_branch_assignments_created_by_fkey` refuses it -- which is TENANT-1's composite FK doing
-- precisely its job, and is how the first draft of this fixture failed.
select set_config('request.jwt.claims', null, true);

insert into auth.users (id, email, email_confirmed_at) values
  ('91000000-0000-0000-0000-0000000000a3','so@rbac91.test', now());
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('91000000-0000-0000-0000-000000000021','91000000-0000-0000-0000-000000000002','Starter Owner','so@rbac91.test',true,'91000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('91000000-0000-0000-0000-000000000002','91000000-0000-0000-0000-000000000021','91000000-0000-0000-0000-00000000000b','91000000-0000-0000-0000-0000000000c2', true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '91000000-0000-0000-0000-000000000002','91000000-0000-0000-0000-000000000021', r.id, 'tenant'
from public.roles r where r.code = 'owner';

-- Granted DIRECTLY, by the strongest possible path, as postgres -- bypassing even the RLS policy, so
-- the assertion cannot be satisfied merely because the write was refused.
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason)
select '91000000-0000-0000-0000-000000000002','91000000-0000-0000-0000-000000000021', p.id, 'grant',
       'tenant admin tries to buy themselves a feature'
from public.permissions p where p.key = 'EDIT_LOCKED_COST';

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);

select is(
  app.has_permission('EDIT_LOCKED_COST'), false,
  'PLAN GATE OUTRANKS THE DIRECT GRANT: a starter tenant''s own owner holds an explicit user grant and STILL cannot use a full_finance capability -- the commercial boundary canon 28 requires');

-- =============================================================================================
-- 13-14. EXPLAINABILITY. `app.effective_permissions` must ITEMISE the decision, and must never
--        contradict it. Assertion 14 compares the explainer against the decider for EVERY active
--        permission, so an edit to one that is not made to the other fails here rather than
--        misleading an administrator reading the dashboard.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"91000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select is(
  (select (from_role, user_grant, user_deny, effective)::text
     from app.effective_permissions()
    where permission_key = 'CREATE_LEAD'),
  '(t,f,t,f)',
  'EXPLAINER: CREATE_LEAD reads "role grants it, no user grant, an explicit user DENY, therefore NO" -- the four inputs an administrator needs to see, not just the verdict');

select is(
  (select count(*)::int from app.effective_permissions() ep
    where ep.effective is distinct from app.has_permission(ep.permission_key)),
  0,
  'EXPLAINER NEVER DISAGREES WITH THE DECIDER: across every active permission, effective_permissions() and has_permission() return the same answer -- an explainer that can drift is worse than none');

-- =============================================================================================
-- 15-16. STRUCTURE the dashboard depends on, and the tenant boundary.
-- =============================================================================================
reset role;

select is(
  (select count(*)::int from public.permissions where action_kind = 'view' and key not like 'VIEW\_%'),
  0,
  'action_kind is DERIVED from canon 28''s naming convention, not hand-maintained -- nothing is marked `view` that is not a VIEW_* permission');

-- TENANT-1's rule on the newest table: a composite FK is the only thing that stops one tenant's
-- grant row naming another tenant's user.
select is(
  (select count(*)::int
     from pg_constraint
    where conrelid = 'public.user_permission_grants'::regclass
      and contype = 'f' and array_length(conkey, 1) = 2),
  2,
  'TENANT-1: both FKs to public.users are COMPOSITE (tenant_id, user_id) -- a single-column FK would let one tenant grant a capability to another tenant''s user');

select * from finish();
rollback;
