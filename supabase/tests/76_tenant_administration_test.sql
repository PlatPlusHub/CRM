-- pgTAP: ADMIN-1 -- a membership may not claim a different human than the identity it is bound to.
--
-- API-3, the tenant-administration family: create_tenant_user, assign_user_branch, revoke_user_role,
-- create_department. This is the group that CREATES the unlinked memberships IDENT-1 exploited and
-- GRANTS the roles it inherited, so it is the natural continuation of that thread.
--
-- THE DEFECT. `app.create_tenant_user` accepts `p_auth_user_id` from the caller and inserts it
-- without validating it against anything; `users_auth_user_id_fkey` proves the identity EXISTS and
-- nothing about WHOSE it is. Canon 34 is explicit that the Human Identity owns the verified email
-- and the membership owns only what the person may DO, so a linked membership carrying a different
-- email is claiming to be a different human.
--
-- REPRODUCED: Agency A's owner creates 'Alice Smith'/'alice@a.test' bound to BOB'S identity, an
-- existing member of unrelated Agency B. Three harms from one unvalidated argument -- every action
-- Bob takes in Agency A is attributed to Alice; the real Alice can never claim her membership
-- (activate_membership only claims rows with auth_user_id NULL); and Bob gains a tenant he never
-- joined. `my_memberships()` returned BOTH agencies for him.
--
-- The layer was chosen by measurement, and it differs from IDENT-1's on purpose: 49 test files
-- create `auth.users` without `email_confirmed_at` (so IDENT-1 could not be a trigger), but 120
-- linked membership rows carry ZERO divergent emails, and `users.scope_update` lets any MANAGE_USERS
-- holder set `auth_user_id` by direct DML -- so here a function-only check would have left the other
-- door open.
create extension if not exists pgtap with schema extensions;

begin;
select plan(23);

-- Every membership email below MATCHES its bound identity. That is now an invariant, and writing
-- fixtures that respect it is the point: test 65 was modelling ten impossible humans.
insert into auth.users (id, email, email_confirmed_at) values
  ('76000000-0000-0000-0000-0000000000a1','owner@a76.test', now()),
  ('76000000-0000-0000-0000-0000000000b1','bob@b76.test',   now()),
  ('76000000-0000-0000-0000-0000000000c1','alice@a76.test', now());
insert into auth.users (id, email) values
  ('76000000-0000-0000-0000-0000000000e9', null);

insert into public.tenants (id, name, slug, status) values
  ('76000000-0000-0000-0000-00000000000a','Agency A76','agency-a76','active'),
  ('76000000-0000-0000-0000-00000000000b','Agency B76','agency-b76','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise'
  and t.id in ('76000000-0000-0000-0000-00000000000a','76000000-0000-0000-0000-00000000000b');
insert into public.branches (id, tenant_id, name, slug) values
  ('76000000-0000-0000-0000-0000000000aa','76000000-0000-0000-0000-00000000000a','HQ','a76-hq'),
  ('76000000-0000-0000-0000-0000000000ab','76000000-0000-0000-0000-00000000000a','Branch2','a76-b2'),
  ('76000000-0000-0000-0000-0000000000bb','76000000-0000-0000-0000-00000000000b','HQ','b76-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('76000000-0000-0000-0000-0000000000d1','76000000-0000-0000-0000-00000000000a','76000000-0000-0000-0000-0000000000aa','management','Exec'),
  ('76000000-0000-0000-0000-0000000000d2','76000000-0000-0000-0000-00000000000b','76000000-0000-0000-0000-0000000000bb','management','Exec');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('76000000-0000-0000-0000-000000000011','76000000-0000-0000-0000-00000000000a','A Owner','owner@a76.test',true,'76000000-0000-0000-0000-0000000000a1'),
  ('76000000-0000-0000-0000-000000000021','76000000-0000-0000-0000-00000000000b','Bob','bob@b76.test',true,'76000000-0000-0000-0000-0000000000b1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('76000000-0000-0000-0000-00000000000a','76000000-0000-0000-0000-000000000011','76000000-0000-0000-0000-0000000000aa','76000000-0000-0000-0000-0000000000d1',true),
  ('76000000-0000-0000-0000-00000000000b','76000000-0000-0000-0000-000000000021','76000000-0000-0000-0000-0000000000bb','76000000-0000-0000-0000-0000000000d2',true);
insert into public.user_role_assignments (id, tenant_id, user_id, role_id, scope_type)
select '76000000-0000-0000-0000-0000000000f1','76000000-0000-0000-0000-00000000000a','76000000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'owner';
insert into public.user_role_assignments (id, tenant_id, user_id, role_id, scope_type, branch_id)
select '76000000-0000-0000-0000-0000000000f2','76000000-0000-0000-0000-00000000000a','76000000-0000-0000-0000-000000000011', r.id, 'branch','76000000-0000-0000-0000-0000000000aa'
from public.roles r where r.code = 'owner';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '76000000-0000-0000-0000-00000000000b','76000000-0000-0000-0000-000000000021', r.id, 'tenant'
from public.roles r where r.code = 'employee';

-- =============================================================================================
-- 1-2. STRUCTURE.
-- =============================================================================================
select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where t.tgname = 'users_enforce_identity_binding' and not t.tgisinternal
      and (t.tgtype & 2) <> 0 and (t.tgtype & 4) <> 0 and (t.tgtype & 16) <> 0),
  1,
  'the identity-binding trigger exists as BEFORE INSERT OR UPDATE -- UPDATE matters because auth_user_id and email are both editable by a MANAGE_USERS holder');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'enforce_membership_identity_binding'
      and p.prosrc ~ 'auth\.uid\(\)'),
  0,
  'no session-less exemption -- a membership bound to the wrong human is exactly as wrong when a migration does it (SEC-1 Refinement 2)');

-- =============================================================================================
-- 3-6. THE AUTHORIZED PATHS MUST ALL STILL WORK. A fix that closed this by breaking user
--      provisioning would be worse than the defect it closed.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"76000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('MANAGE_USERS') and app.has_permission('MANAGE_DEPARTMENTS'),
  'POSITIVE CONTROL: the owner holds both administration permissions -- so every refusal below is the rule, not the permission');

select isnt(
  (select app.create_tenant_user('Invitee','invitee@a76.test', null, null)),
  null,
  'THE ONE THAT MATTERS: the INVITE flow still works -- an unlinked membership names no human yet, which is exactly what IDENT-1''s claim path consumes');

select isnt(
  (select app.create_tenant_user('Real Alice','alice@a76.test', null, '76000000-0000-0000-0000-0000000000c1')),
  null,
  '...and a membership linked to the CORRECT identity is still created directly');

-- Reads auth.users, which `authenticated` holds no SELECT on -- that is precisely why the trigger
-- enforcing this invariant has to be SECURITY DEFINER. Checked from the platform role.
reset role;
select is(
  (select count(*)::int from public.users u join auth.users au on au.id = u.auth_user_id
    where u.tenant_id = '76000000-0000-0000-0000-00000000000a'
      and lower(u.email) is distinct from lower(au.email)),
  0,
  'and no linked membership in this tenant diverges from its identity -- the invariant holds after the legal writes');

select set_config('request.jwt.claims','{"sub":"76000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

-- =============================================================================================
-- 7-10. THE REPRODUCTION, on every path that can set the binding.
-- =============================================================================================
select throws_ok(
  $q$select app.create_tenant_user('Alice Smith','fake-alice@a76.test', null, '76000000-0000-0000-0000-0000000000b1')$q$,
  '23514', null,
  'REPRODUCTION CLOSED: the RPC refuses to bind a membership to BOB''S identity under a different email -- it previously succeeded, locking the real person out and granting Bob a tenant he never joined');

select throws_ok(
  $q$update public.users set auth_user_id = '76000000-0000-0000-0000-0000000000b1'
      where id = '76000000-0000-0000-0000-000000000011'$q$,
  '23514', null,
  'and DIRECT DML re-binding an existing membership to a foreign identity is refused too -- users.scope_update grants this to any MANAGE_USERS holder, which is why a check inside the RPC alone would have been a half-fix');

select throws_ok(
  $q$update public.users set email = 'someone-else@a76.test'
      where id = '76000000-0000-0000-0000-000000000011'$q$,
  '23514', null,
  'and the OTHER direction is refused -- editing the membership email away from its identity, which a trigger watching only auth_user_id would have missed');

select throws_ok(
  $q$select app.create_tenant_user('Ghost','ghost@a76.test', null, '76000000-0000-0000-0000-0000000000e9')$q$,
  '23514', null,
  'an ANONYMOUS identity (auth.users.email is null) cannot back a named membership -- it proves no mailbox at all');

-- =============================================================================================
-- 11-12. NON-MUTATION, and the harm that motivated the fix: the rightful person can still claim.
-- =============================================================================================
reset role;
select is(
  (select u.auth_user_id from public.users u where u.id = '76000000-0000-0000-0000-000000000011'),
  '76000000-0000-0000-0000-0000000000a1'::uuid,
  'NON-MUTATION: the owner''s own binding is untouched after four refusals');

select set_config('request.jwt.claims','{"sub":"76000000-0000-0000-0000-0000000000c1"}', true);
set local role authenticated;
select is(
  (select count(*)::int from app.activate_membership()),
  1,
  'and the REAL Alice still claims her membership -- the permanent lockout ADMIN-1 caused is gone');

-- =============================================================================================
-- 13-14. LOAD-BEARING (PAR-4): is the NAMED trigger what refuses, or something else?
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"76000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

savepoint before_enforcer_mutation;
reset role;
drop trigger users_enforce_identity_binding on public.users;
set local role authenticated;

select lives_ok(
  $q$select app.create_tenant_user('Alice Smith','fake-alice@a76.test', null, '76000000-0000-0000-0000-0000000000b1')$q$,
  'MUTATION: with the binding trigger dropped, the SAME call succeeds again -- so that trigger is what refuses it, not the FK and not RLS');

rollback to savepoint before_enforcer_mutation;

select throws_ok(
  $q$select app.create_tenant_user('Alice Smith','fake-alice@a76.test', null, '76000000-0000-0000-0000-0000000000b1')$q$,
  '23514', null,
  'RESTORED: and with the trigger back the identical call is refused again');

-- =============================================================================================
-- 15-17. TENANT LOCKOUT. Zero owners is structurally unreachable -- but only because
--        `emit_role_change` is an AFTER trigger that re-checks MANAGE_USERS once the granting row
--        is already inactive. That protection is REAL and ACCIDENTAL, so it is pinned here: a
--        future refactor moving that trigger to BEFORE, or dropping its authorize() call, would
--        make a tenant permanently unadministrable with nothing else noticing.
-- =============================================================================================
select lives_ok(
  $q$select app.revoke_user_role('76000000-0000-0000-0000-0000000000f2')$q$,
  'an owner CAN revoke one of their two owner grants -- the other still confers MANAGE_USERS, so this is not a blanket refusal');

select throws_ok(
  $q$select app.revoke_user_role('76000000-0000-0000-0000-0000000000f1')$q$,
  '42501', null,
  'but revoking the LAST grant that confers MANAGE_USERS is refused -- zero-owner is unreachable, which is why a tenant cannot be locked out of its own administration');

reset role;
select cmp_ok(
  (select count(*)::int from public.user_role_assignments ura
     join public.role_permissions rp on rp.role_id = ura.role_id
     join public.permissions p on p.id = rp.permission_id
    where ura.tenant_id = '76000000-0000-0000-0000-00000000000a' and ura.is_active and p.key = 'MANAGE_USERS'),
  '>=', 1,
  'and the tenant still has at least one live MANAGE_USERS holder after both attempts');

-- =============================================================================================
-- 18-20. The remaining two capabilities, and their set-level constraints.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"76000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select isnt(
  (select app.create_department('76000000-0000-0000-0000-0000000000aa','sales','Sales Floor')),
  null,
  'create_department still creates a department on a branch in the caller''s tenant');

select throws_ok(
  $q$select app.create_department('76000000-0000-0000-0000-0000000000aa','sales','Sales Floor')$q$,
  '23505', null,
  'and a DUPLICATE active department name in the same branch is refused -- departments_unique_name_per_branch_idx, which is partial on is_active so a reactivated name is still governed');

select throws_ok(
  $q$select app.assign_user_branch('76000000-0000-0000-0000-000000000021','76000000-0000-0000-0000-0000000000aa', null, false, null)$q$,
  null, null,
  'assign_user_branch refuses a user from ANOTHER tenant -- cross-tenant isolation on the administration path, proven rather than assumed');

-- =============================================================================================
-- 21-22. assign_user_branch's set-level invariant and its audit trail. `one_primary_idx` is a rule
--        about a SET of rows (at most one live primary per user), which is the SEC-1 clause-3 shape
--        -- and unlike FIN-8/FIN-10 it was already expressed correctly, as a partial unique index.
--        Recorded here because "already correct" is a finding too, and an untested constraint is
--        one refactor away from being dropped silently.
-- =============================================================================================
select throws_ok(
  $q$select app.assign_user_branch('76000000-0000-0000-0000-000000000011','76000000-0000-0000-0000-0000000000ab', null, true, null)$q$,
  '23505', null,
  'a SECOND live primary branch assignment is refused -- one_primary_idx is partial on (is_primary and ends_at is null), so ending the first would legitimately free the slot');

select lives_ok(
  $q$select app.assign_user_branch('76000000-0000-0000-0000-000000000011','76000000-0000-0000-0000-0000000000ab', null, false, 'permanent')$q$,
  'POSITIVE CONTROL: a NON-primary second assignment is accepted -- working at two branches is ordinary, so the refusal above is the primary rule and not a blanket one');

reset role;
select cmp_ok(
  (select count(*)::int from public.events
    where tenant_id = '76000000-0000-0000-0000-00000000000a'
      and event_type_code = 'user_branch_transfer_completed'),
  '>=', 1,
  'and the transfer reached the audit spine -- assign_user_branch emits nothing itself, so this proves user_branch_assignments_emit_transfer is what records it');

select finish();
rollback;
