-- pgTAP: RBAC-1 -- privilege changes are audited and authorized on EVERY path, and CUR-1.
--
-- Before this, `user_role_assignments` carried no triggers at all. `role_assigned` was emitted by
-- `app.assign_user_role` and by nothing else, and `role_removed` -- a registered event type -- had
-- no producer anywhere in the database. So ORVION recorded privilege grants made through one RPC,
-- recorded no grant made by direct DML, and recorded no revocation by any route at all.
--
-- Assertion 7 is the one that keeps the fix honest in the other direction: a trigger that emitted
-- on every UPDATE would fill the security stream with noise until nobody read it. Only a change in
-- EFFECTIVE ACCESS is a privilege change.
--
-- Assertions 8-9 are the MFA half, and they are why the fixture bothers with two different JWTs for
-- the same person. RLS on this table checks `has_permission`; the trigger checks `authorize`, which
-- also composes MFA. Testing the denial with a user who lacks MANAGE_USERS would have proved
-- nothing -- RLS would filter the row out, the UPDATE would touch zero rows, and it would not raise
-- at all. The real gap was an owner who HOLDS the permission and has not stepped up.
--
-- Assertion 8 also failed on its first run for the opposite reason, and the fix was the fixture and
-- not the trigger: it aimed at an assignment that assertion 6 had already expired, so there was no
-- effective-access change left to make and the trigger correctly did nothing. A denial test must
-- attack a LIVE grant or it proves only that dead rows stay dead.
create extension if not exists pgtap with schema extensions;

begin;
select plan(13);

insert into auth.users (id, email) values
  ('51000000-0000-0000-0000-0000000000a1','owner@rc.test'),
  ('51000000-0000-0000-0000-0000000000a2','emp@rc.test');
insert into public.tenants (id, name, slug, status) values
  ('51000000-0000-0000-0000-000000000001','RC Travel','rc-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '51000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('51000000-0000-0000-0000-00000000000a','51000000-0000-0000-0000-000000000001','Cairo','rc-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('51000000-0000-0000-0000-0000000000c1','51000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('51000000-0000-0000-0000-000000000011','51000000-0000-0000-0000-000000000001','RC Owner','owner@rc.test',true,'51000000-0000-0000-0000-0000000000a1'),
  ('51000000-0000-0000-0000-000000000012','51000000-0000-0000-0000-000000000001','RC Emp','emp@rc.test',true,'51000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('51000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000011','51000000-0000-0000-0000-00000000000a','51000000-0000-0000-0000-0000000000c1',true),
  ('51000000-0000-0000-0000-000000000001','51000000-0000-0000-0000-000000000012','51000000-0000-0000-0000-00000000000a','51000000-0000-0000-0000-0000000000c1',true);

-- =============================================================================================
-- 1-2. THE HALF THAT WAS SILENT. This is a plain INSERT -- exactly what every fixture in this suite
--      does, and exactly what an administrator with MANAGE_USERS could always do -- and until now
--      it granted a role and left no trace.
-- =============================================================================================
insert into public.user_role_assignments (id, tenant_id, user_id, role_id, scope_type)
select '51000000-0000-0000-0000-0000000000e1','51000000-0000-0000-0000-000000000001',
       '51000000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'owner';

select is(
  (select count(*)::int from public.events
    where event_type_code = 'role_assigned' and entity_id = '51000000-0000-0000-0000-000000000011'),
  1,
  'a role granted by DIRECT DML is audited -- the path the RPC never covered');

select is(
  (select severity_code from public.events
    where event_type_code = 'role_assigned' and entity_id = '51000000-0000-0000-0000-000000000011'),
  'security',
  '...at security severity, matching what the grant path always claimed to record');

-- =============================================================================================
-- 3. AND EXACTLY ONE EVENT PER GRANT. The RPC's own record_event call was removed when the trigger
--    became the producer; if it had been left in place this would read 2.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select app.assign_user_role('51000000-0000-0000-0000-000000000012','employee');
reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select count(*)::int from public.events
    where event_type_code = 'role_assigned' and entity_id = '51000000-0000-0000-0000-000000000012'),
  1,
  'app.assign_user_role produces exactly ONE role_assigned -- one producer, not two');

-- =============================================================================================
-- 4-6. REVOCATION, by both routes that end a grant.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$select app.revoke_user_role(
      (select id from public.user_role_assignments
        where user_id = '51000000-0000-0000-0000-000000000012' and is_active))$$,
  'app.revoke_user_role exists at all -- granting had a verb and revoking did not');

reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select count(*)::int from public.events
    where event_type_code = 'role_removed' and entity_id = '51000000-0000-0000-0000-000000000012'),
  1,
  '...and revocation is RECORDED -- the spine held every grant and no removal before this');

-- The other route to the same end: the grant runs out rather than being switched off. SPEC-148
-- proved both routes revoke access; both must therefore be audited, or the cheaper one is a
-- silent way to strip a colleague.
insert into public.user_role_assignments (id, tenant_id, user_id, role_id, scope_type)
select '51000000-0000-0000-0000-0000000000e3','51000000-0000-0000-0000-000000000001',
       '51000000-0000-0000-0000-000000000012', r.id, 'tenant'
from public.roles r where r.code = 'employee';

update public.user_role_assignments set ends_at = now() - interval '1 day'
 where id = '51000000-0000-0000-0000-0000000000e3';

select is(
  (select count(*)::int from public.events
    where event_type_code = 'role_removed' and entity_id = '51000000-0000-0000-0000-000000000012'),
  2,
  'EXPIRING a grant is audited too, not only switching is_active off');

-- =============================================================================================
-- 7. THE NOISE CONTROL. A column change that does not change effective access must record nothing,
--    or the security stream becomes unreadable and therefore unread.
-- =============================================================================================
update public.user_role_assignments set scope_type = 'tenant'
 where id = '51000000-0000-0000-0000-0000000000e1';

select is(
  (select count(*)::int from public.events
    where entity_id = '51000000-0000-0000-0000-000000000011'
      and event_type_code in ('role_assigned','role_removed')),
  1,
  'an UPDATE that changes no effective access emits nothing -- still just the original grant');

-- =============================================================================================
-- 8-9. MFA PARITY. Granting through the RPC always cost a step-up; changing the same rows by DML
--      cost only the permission, so the cheaper route was the destructive one. A FRESH LIVE grant,
--      because a denial aimed at an already-dead row proves nothing. Denial first, then the
--      positive control that proves the denial is about MFA and not about the fixture.
-- =============================================================================================
insert into public.user_role_assignments (id, tenant_id, user_id, role_id, scope_type)
select '51000000-0000-0000-0000-0000000000e4','51000000-0000-0000-0000-000000000001',
       '51000000-0000-0000-0000-000000000012', r.id, 'tenant'
from public.roles r where r.code = 'senior_employee';

select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select throws_ok(
  $$update public.user_role_assignments set is_active = false
     where id = '51000000-0000-0000-0000-0000000000e4'$$,
  '42501', null,
  'an OWNER who has not stepped up cannot revoke by direct DML -- RLS let the row through, the trigger did not');

reset role;
select set_config('request.jwt.claims','{"sub":"51000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$update public.user_role_assignments set is_active = false
     where id = '51000000-0000-0000-0000-0000000000e4'$$,
  'POSITIVE CONTROL: the same owner, stepped up, performs the same UPDATE');

-- =============================================================================================
-- 10-11. THE SYSTEM PATH stays open and stays audited. Provisioning writes these rows before any
--        session exists; if the trigger charged it a permission, a new tenant could not be born.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select lives_ok(
  $$insert into public.user_role_assignments (id, tenant_id, user_id, role_id, scope_type)
    select '51000000-0000-0000-0000-0000000000e5','51000000-0000-0000-0000-000000000001',
           '51000000-0000-0000-0000-000000000012'::uuid, r.id,'tenant'
    from public.roles r where r.code = 'branch_manager'$$,
  'a SESSION-LESS grant is permitted -- the exemption provisioning depends on');

select is(
  (select count(*)::int from public.events
    where event_type_code = 'role_assigned'
      and entity_id = '51000000-0000-0000-0000-000000000012'
      and actor_user_id is null
      and payload ->> 'assignment_id' = '51000000-0000-0000-0000-0000000000e5'),
  1,
  '...and is still AUDITED, with no actor invented for it -- exempt from the check, never from the record');

-- =============================================================================================
-- 12-13. CUR-1. integration_cursors granted authenticated SELECT/INSERT/UPDATE while its RLS
--        denied all three. Behaviour was already fail-closed; the two layers now agree.
-- =============================================================================================
select is(
  (select count(*)::int
     from (values ('SELECT'),('INSERT'),('UPDATE'),('DELETE')) as p(priv)
    where has_table_privilege('authenticated', 'public.integration_cursors'::regclass, p.priv)),
  0,
  'authenticated holds NO privilege on integration_cursors -- the grants matched nothing RLS allowed');

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public' and tablename = 'integration_cursors'
      and qual = 'false' and with_check = 'false'),
  1,
  '...and an EXPLICIT deny-all states that intent, instead of leaving it as an absence to interpret');

select finish();
rollback;
