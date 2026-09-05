-- pgTAP: AUTH-2 -- a role assignment that has not started yet grants NOTHING (`202607060700`).
--
-- THE DEFECT THIS PINS. `public.user_role_assignments.starts_at` is `NOT NULL DEFAULT now()` and
-- exists to say when an assignment comes into force. `app.has_permission` -- the authorisation
-- authority -- did not read it, while the `user_permission_grants` path in the SAME statement did.
-- `app.effective_permissions` and `app.requires_mfa` shared the omission; `app.visible_branch_ids`,
-- `app.visible_department_ids`, `app.credit_alert_recipients` and `app.lead_responsible_managers`
-- did not. So a future-dated assignment granted the PERMISSION immediately while withholding the
-- SCOPE until it started, and every explanation surface agreed with the wrong half.
--
-- WHAT MUST BE TRUE:
--   * a future-dated assignment grants nothing, through the authority AND through the explainer;
--   * it is a TIME test and not a blanket denial -- the same row, backdated, grants everything;
--   * permission and scope agree at both instants, which is the property that was broken;
--   * the two grant paths inside `has_permission` apply the SAME temporal rule.
--
-- Each assertion below FAILED before `202607060700` unless marked CONTROL or REGRESSION GUARD.
create extension if not exists pgtap with schema extensions;

begin;
select plan(11);

insert into auth.users (id, email, email_confirmed_at) values
  ('99000000-0000-0000-0000-0000000000a1','now@auth99.test',    now()),
  ('99000000-0000-0000-0000-0000000000a2','future@auth99.test', now());
insert into public.tenants (id, name, slug, status) values
  ('99000000-0000-0000-0000-000000000001','Auth99 Travel','auth99','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code='enterprise' and t.id='99000000-0000-0000-0000-000000000001';
insert into public.branches (id, tenant_id, name, slug) values
  ('99000000-0000-0000-0000-00000000000a','99000000-0000-0000-0000-000000000001','HQ','auth99-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('99000000-0000-0000-0000-0000000000c1','99000000-0000-0000-0000-000000000001',
   '99000000-0000-0000-0000-00000000000a','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('99000000-0000-0000-0000-000000000011','99000000-0000-0000-0000-000000000001','Now User','now@auth99.test',true,'99000000-0000-0000-0000-0000000000a1'),
  ('99000000-0000-0000-0000-000000000012','99000000-0000-0000-0000-000000000001','Future User','future@auth99.test',true,'99000000-0000-0000-0000-0000000000a2');
-- ONLY the control user is placed in the branch. The subject deliberately is NOT: `visible_branch_ids`
-- is a UNION of three sources -- tenant-wide read, `user_branch_assignments`, and the branch named on
-- a `user_role_assignments` row -- and assertion 7 measures the THIRD. A placement row for the
-- subject would satisfy the second and the assertion would pass no matter what the role assignment
-- said, which is the shape of a test that proves nothing.
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
values ('99000000-0000-0000-0000-000000000001','99000000-0000-0000-0000-000000000011',
        '99000000-0000-0000-0000-00000000000a','99000000-0000-0000-0000-0000000000c1', true);

-- The CONTROL assignment starts NOW (the column default), which is every assignment ORVION has ever
-- created: `app.assign_user_role` takes no `starts_at` argument, so future-dating is reachable only
-- through the TABLE door -- which `authenticated` holds, gated by MANAGE_USERS in RLS `WITH CHECK`.
insert into public.user_role_assignments (id, tenant_id, user_id, role_id, scope_type, branch_id)
select '99000000-0000-0000-0000-0000000000b1','99000000-0000-0000-0000-000000000001',
       '99000000-0000-0000-0000-000000000011', r.id, 'branch','99000000-0000-0000-0000-00000000000a'
from public.roles r where r.code='finance_manager';

-- The SUBJECT. Same role, same scope, same branch -- and it does not start for a week. An
-- administrator writing this row means "on the 1st", and before `202607060700` it meant "now".
insert into public.user_role_assignments (id, tenant_id, user_id, role_id, scope_type, branch_id, starts_at)
select '99000000-0000-0000-0000-0000000000b2','99000000-0000-0000-0000-000000000001',
       '99000000-0000-0000-0000-000000000012', r.id, 'branch','99000000-0000-0000-0000-00000000000a',
       now() + interval '7 days'
from public.roles r where r.code='finance_manager';

-- =============================================================================================
-- 1. CONTROL. The fixture is capable of granting the permission at all -- without this, every
--    "false" below would pass for a user who simply has no roles.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"99000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select is(
  app.has_permission('MANAGE_SUPPLIER_CREDIT'), true,
  'CONTROL: an assignment that has ALREADY started grants its permissions -- the fixture works, so the denials below mean something');

reset role;

-- =============================================================================================
-- 2-6. THE FUTURE-DATED ASSIGNMENT GRANTS NOTHING, and the authority and the explainer say the
--      same thing. Assertion 6 is the one that would have caught this class on its own.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"99000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select is(
  app.has_permission('MANAGE_SUPPLIER_CREDIT'), false,
  'AUTH-2: a role assignment that has not STARTED grants nothing -- scheduling a promotion no longer performs it');

select is(
  (select ep.from_role from app.effective_permissions() ep where ep.permission_key='MANAGE_SUPPLIER_CREDIT'),
  false,
  'AUTH-2: the EXPLAINER agrees -- `from_role` is false, so an administrator auditing the matrix is not shown a grant the future has not delivered');

select is(
  (select ep.effective from app.effective_permissions() ep where ep.permission_key='MANAGE_SUPPLIER_CREDIT'),
  false,
  'AUTH-2: ...and the explainer''s bottom line is false too');

select is(
  app.requires_mfa(), false,
  'AUTH-2: the MFA gate reads the same table and had the same omission -- a future-dated finance_manager does not make MFA required today');

select is(
  (select count(*)::int from app.effective_permissions() ep
    where ep.effective is distinct from app.has_permission(ep.permission_key)),
  0,
  'AUTH-2 LOCKSTEP: the explainer and the authority agree on EVERY permission for this actor -- an edit to one that is not made to the other fails here');

reset role;

-- =============================================================================================
-- 7. THE PROPERTY THAT WAS ACTUALLY BROKEN. `visible_branch_ids` already honoured `starts_at`, so
--    before the fix this user held MANAGE_SUPPLIER_CREDIT over an EMPTY set of branches --
--    permission without scope, and no surface that could show the contradiction.
-- =============================================================================================
select is(
  (select count(*)::int from app.visible_branch_ids() b
    where b = '99000000-0000-0000-0000-00000000000a'),
  0,
  'AUTH-2: the branch scope is withheld until the assignment starts -- this always held, and permission now AGREES with it instead of contradicting it');

-- =============================================================================================
-- 8-10. IT IS A TIME TEST, NOT A DENIAL. The same row, backdated, grants everything. Without this
--       the fix would be indistinguishable from breaking role grants outright.
-- =============================================================================================
update public.user_role_assignments
   set starts_at = now() - interval '1 day'
 where id = '99000000-0000-0000-0000-0000000000b2';

set local role authenticated;

select is(
  app.has_permission('MANAGE_SUPPLIER_CREDIT'), true,
  'AUTH-2: once `starts_at` has passed the SAME row grants the permission -- the predicate tests time, it does not deny role grants');

select is(
  app.requires_mfa(), true,
  'AUTH-2: ...and the MFA requirement arrives WITH the role rather than before it');

reset role;

select is(
  (select count(*)::int from app.visible_branch_ids() b
    where b = '99000000-0000-0000-0000-00000000000a'),
  1,
  'AUTH-2: ...and the scope arrives at the same instant -- permission and scope are now one event, not two');

-- =============================================================================================
-- 11. REGRESSION GUARD on the path that was ALREADY correct. `user_permission_grants` has always
--     applied `starts_at <= now()`; this pins it so a future "simplification" cannot quietly bring
--     the two grant paths back into disagreement from the other direction.
-- =============================================================================================
insert into public.user_permission_grants (tenant_id, user_id, permission_id, effect, reason, starts_at)
select '99000000-0000-0000-0000-000000000001','99000000-0000-0000-0000-000000000012', p.id, 'grant',
       'AUTH-2 test: the sibling grant path must apply the same temporal rule', now() + interval '7 days'
from public.permissions p where p.key = 'MANAGE_MARKETING_CAMPAIGN';

set local role authenticated;

select is(
  app.has_permission('MANAGE_MARKETING_CAMPAIGN'), false,
  'REGRESSION GUARD: a future-dated USER GRANT also grants nothing -- both grant paths inside has_permission apply the same rule');

reset role;
select set_config('request.jwt.claims', null, true);

select * from finish();
rollback;
