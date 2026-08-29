-- pgTAP: IDENT-1 -- an unverified email is not proof of identity.
--
-- API-3, the canon-34 Human Identity family: activate_membership, my_memberships,
-- record_trusted_device, my_trusted_devices, revoke_trusted_device. SEC-1's inventory classified
-- `otp_challenges`, `totp_enrollments` and `trusted_devices` as the only writable tables with no
-- governing capability trigger -- INTENTIONAL, because they are owned by `auth.uid()` rather than by
-- a tenant permission. That classification was asserted STRUCTURALLY and never tested BEHAVIOURALLY:
-- before this file the family's entire coverage was a name-existence list in
-- `53_api_surface_test.sql`, which is the CUST-2 shape exactly (a guard that checks an endpoint
-- EXISTS cannot see what it does).
--
-- THE DEFECT. `app.activate_membership()` claims a pre-provisioned membership by matching
-- `auth.users.email` to `public.users.email`, justified in its own comment as "the caller's
-- auth.users row exists only after Supabase verified this email, so the match is an authorization
-- proof". `supabase/config.toml` sets `enable_confirmations = false`, so the row exists at signup
-- with `email_confirmed_at` NULL -- and that column appeared NOWHERE in the repository.
--
-- REPRODUCED: an attacker signing up as `ceo@victim.test` claimed the pre-provisioned CEO
-- membership and then held APPROVE_FINANCE, VIEW_FINANCIAL_DOCUMENTS and MANAGE_USERS.
--
-- The fix is in the FUNCTION, not a trigger, and assertions 10-11 are why: the alternate paths were
-- measured closed before the layer was chosen.
create extension if not exists pgtap with schema extensions;

begin;
select plan(24);

-- Two identities for the SAME email: one confirmed, one not. Everything else about them is
-- identical, so the only variable in assertions 5/8 is `email_confirmed_at` itself.
insert into auth.users (id, email, email_confirmed_at) values
  ('75000000-0000-0000-0000-0000000000c1','claimant@ident.test', now()),
  ('75000000-0000-0000-0000-0000000000c2','other@ident.test',    now());
insert into auth.users (id, email, email_confirmed_at, banned_until, deleted_at) values
  ('75000000-0000-0000-0000-0000000000b1','banned@ident.test',  now(), now() + interval '1 day', null),
  ('75000000-0000-0000-0000-0000000000d1','deleted@ident.test', now(), null, now());

insert into public.tenants (id, name, slug, status) values
  ('75000000-0000-0000-0000-000000000001','Ident Travel','ident-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '75000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('75000000-0000-0000-0000-00000000000a','75000000-0000-0000-0000-000000000001','HQ','ident-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('75000000-0000-0000-0000-0000000000e1','75000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-00000000000a','management','Exec');

-- The pre-provisioned, unclaimed CEO membership -- exactly what create_tenant_user leaves behind
-- when p_auth_user_id is null (it records has_auth_link:false, so this is an intended flow).
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('75000000-0000-0000-0000-000000000011','75000000-0000-0000-0000-000000000001','The CEO','claimant@ident.test',true, null),
  ('75000000-0000-0000-0000-000000000012','75000000-0000-0000-0000-000000000001','Colleague','other@ident.test',true,'75000000-0000-0000-0000-0000000000c2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('75000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000011','75000000-0000-0000-0000-00000000000a','75000000-0000-0000-0000-0000000000e1',true),
  ('75000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000012','75000000-0000-0000-0000-00000000000a','75000000-0000-0000-0000-0000000000e1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '75000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('75000000-0000-0000-0000-000000000011'::uuid,'ceo'),
             ('75000000-0000-0000-0000-000000000012'::uuid,'employee')) v(u, rc)
join public.roles r on r.code = v.rc;

-- =============================================================================================
-- 1-4. STRUCTURE, and the boundary SEC-1 called INTENTIONAL -- now checked rather than assumed.
-- =============================================================================================
select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'activate_membership' and p.prosecdef),
  1,
  'app.activate_membership is SECURITY DEFINER -- it must bypass RLS to link an identity that has no membership yet, which is exactly why its own preconditions have to be airtight');

select is(
  (select count(*)::int from pg_policies
    where schemaname = 'public'
      and tablename in ('trusted_devices','otp_challenges','totp_enrollments')
      and qual = '(auth_user_id = ( SELECT auth.uid() AS uid))'
      and with_check = '(auth_user_id = ( SELECT auth.uid() AS uid))'),
  3,
  'all three canon-34 identity tables carry owner_only on BOTH using and with_check -- SEC-1''s INTENTIONAL classification, verified rather than quoted');

select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname in ('trusted_devices','otp_challenges','totp_enrollments')
      and c.relrowsecurity),
  3,
  'and ROW SECURITY IS ACTUALLY ENABLED on all three -- PAR-3''s lesson: pg_policies lists a policy whether or not it can ever fire');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'activate_membership'
      and p.prosrc ~ 'email_confirmed_at'),
  1,
  'the claim reads email_confirmed_at -- before IDENT-1 that column appeared nowhere in the entire repository');

-- =============================================================================================
-- 5-7. THE ONE THAT MATTERS: a VERIFIED invitee must still be able to onboard. A fix that closed
--      the takeover by breaking onboarding would be worse than the defect.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"75000000-0000-0000-0000-0000000000c1"}', true);
set local role authenticated;

select is(
  (select count(*)::int from app.activate_membership()),
  1,
  'THE ONE THAT MATTERS: a CONFIRMED invitee still claims their pre-provisioned membership');

select is(
  (select u.auth_user_id from public.users u where u.id = '75000000-0000-0000-0000-000000000011'),
  '75000000-0000-0000-0000-0000000000c1'::uuid,
  '...and the row really was linked -- a returned set is not evidence that the UPDATE ran');

select is(
  (select count(*)::int from app.activate_membership()),
  1,
  'IDEMPOTENT: calling it again returns the same single membership and claims nothing new');

-- =============================================================================================
-- 8-9. THE REPRODUCTION. Same email, same tenant, same everything -- only the confirmation differs,
--      which is what makes this pair a load-bearing test of the check itself rather than of the
--      attacker's luck.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','', true);
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('75000000-0000-0000-0000-000000000013','75000000-0000-0000-0000-000000000001','The CFO','cfo@ident.test',true, null);
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('75000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000013','75000000-0000-0000-0000-00000000000a','75000000-0000-0000-0000-0000000000e1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '75000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000013', r.id, 'tenant'
from public.roles r where r.code = 'finance_manager';
-- The attacker signs up with the CFO's email. enable_confirmations = false, so this row exists and
-- email_confirmed_at is NULL: nobody has proven they can read that mailbox.
insert into auth.users (id, email, email_confirmed_at) values
  ('75000000-0000-0000-0000-0000000000a9','cfo@ident.test', null);

select set_config('request.jwt.claims','{"sub":"75000000-0000-0000-0000-0000000000a9"}', true);
set local role authenticated;

select throws_ok(
  $q$select * from app.activate_membership()$q$,
  '42501', null,
  'REPRODUCTION CLOSED: an UNCONFIRMED identity claiming the CFO membership is refused -- it previously succeeded and yielded APPROVE_FINANCE, VIEW_FINANCIAL_DOCUMENTS and MANAGE_USERS');

reset role;
select is(
  (select u.auth_user_id from public.users u where u.id = '75000000-0000-0000-0000-000000000013'),
  null,
  'NON-MUTATION: the CFO membership is still unclaimed after the refusal');

-- =============================================================================================
-- 10-11. THE ALTERNATE PATHS, measured rather than assumed -- this is WHY the fix is in the
--        function and not in a trigger on public.users.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"75000000-0000-0000-0000-0000000000a9"}', true);
set local role authenticated;

select is(
  (select count(*)::int from public.users),
  0,
  'the unclaimed attacker sees NO users at all -- current_tenant_id() is null, so RLS hides every row and a direct UPDATE has nothing to hit');

-- The email deliberately MATCHES the attacker's own identity. ADMIN-1's binding trigger is a BEFORE
-- trigger, so it answers before RLS's WITH CHECK does; using a mismatched address here would prove
-- only that the binding rule works and would say nothing about RLS. Making the row otherwise valid
-- leaves RLS as the only thing that can refuse it, which is what this assertion claims to show.
select throws_ok(
  $q$insert into public.users (tenant_id, full_name, email, is_active, auth_user_id)
     values ('75000000-0000-0000-0000-000000000001','Self','cfo@ident.test',true,'75000000-0000-0000-0000-0000000000a9')$q$,
  '42501', null,
  'and cannot self-provision a membership either -- the row is otherwise VALID (its email matches its own identity), so RLS is what refuses it, and the RPC is the only reachable claim path');

-- =============================================================================================
-- 12-13. A banned or deleted identity may not claim. A JWT issued before the ban stays valid until
--        it expires, so GoTrue refusing new sessions does not stop an existing token.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','', true);
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('75000000-0000-0000-0000-000000000014','75000000-0000-0000-0000-000000000001','Banned','banned@ident.test',true,null),
  ('75000000-0000-0000-0000-000000000015','75000000-0000-0000-0000-000000000001','Deleted','deleted@ident.test',true,null);

select set_config('request.jwt.claims','{"sub":"75000000-0000-0000-0000-0000000000b1"}', true);
set local role authenticated;
select throws_ok(
  $q$select * from app.activate_membership()$q$,
  '42501', null,
  'a BANNED identity may not claim -- its email is confirmed, so this proves the ban check fires independently');

reset role;
select set_config('request.jwt.claims','{"sub":"75000000-0000-0000-0000-0000000000d1"}', true);
set local role authenticated;
select throws_ok(
  $q$select * from app.activate_membership()$q$,
  '42501', null,
  'and a soft-DELETED identity may not claim either');

-- =============================================================================================
-- 14-18. THE TRUSTED DEVICE CAPABILITY, which had no behavioural test at all.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"75000000-0000-0000-0000-0000000000c1"}', true);
set local role authenticated;

select isnt(
  (select app.record_trusted_device('device-alpha')),
  null,
  'record_trusted_device registers a device for the caller');

select is(
  (select count(*)::int from app.my_trusted_devices() where device_identifier = 'device-alpha'),
  1,
  '...and my_trusted_devices returns it -- the write is observable through the read path');

select is(
  (select app.record_trusted_device('device-alpha')),
  (select id from app.my_trusted_devices() where device_identifier = 'device-alpha'),
  'IDEMPOTENT: recording the same identifier returns the SAME row rather than a duplicate -- there is no unique constraint, so this is the function''s update-then-insert doing the work');

select is(
  (select count(*)::int from public.trusted_devices),
  1,
  'and exactly one device row exists in total -- the idempotency assertion above could otherwise pass while duplicating rows');

-- Cross-user isolation, the property SEC-1 rested its INTENTIONAL classification on.
reset role;
select set_config('request.jwt.claims','{"sub":"75000000-0000-0000-0000-0000000000c2"}', true);
set local role authenticated;

select is(
  (select count(*)::int from app.my_trusted_devices()),
  0,
  'a DIFFERENT authenticated user sees none of the first user''s devices -- owner_only RLS, proven behaviourally rather than read off pg_policies');

-- =============================================================================================
-- 19-20. Revocation, and that it does not become a probe for other people's device ids.
-- =============================================================================================
select throws_ok(
  format($q$select app.revoke_trusted_device(%L)$q$,
         (select id from public.trusted_devices limit 1)),
  null, null,
  'and cannot revoke a device belonging to someone else -- it reports "device not found", the same answer a genuinely absent id gets, so this is not an existence oracle');

reset role;
select set_config('request.jwt.claims','{"sub":"75000000-0000-0000-0000-0000000000c1"}', true);
set local role authenticated;

select lives_ok(
  format($q$select app.revoke_trusted_device(%L)$q$,
         (select id from app.my_trusted_devices() where device_identifier = 'device-alpha')),
  'POSITIVE CONTROL: the owner CAN revoke their own device -- so the refusal above is ownership, not a guard that blocks everyone');

-- =============================================================================================
-- 21. The audit spine. `trusted_devices` has no tenant_id, so this records what the platform-level
--     emitters actually produce rather than asserting what they ought to.
-- =============================================================================================
reset role;
select cmp_ok(
  (select count(*)::int from public.events where entity_type = 'trusted_device'),
  '>=', 1,
  'the device lifecycle reaches the audit spine -- trusted_devices carries three emit triggers and this proves at least one of them fires');

-- =============================================================================================
-- 22-24. IDENT-4: the claim matched case-INSENSITIVELY while uniqueness was case-SENSITIVE, so the
--        function's own comment ("bounded to one row per tenant") was false. A tenant holding both
--        `ceo@x` and `CEO@x` locked that human out permanently with a raw 23505 on
--        users_tenant_auth_key -- fails closed, but unrecoverable without an administrator.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','', true);

select is(
  (select count(*)::int from pg_indexes
    where schemaname = 'public' and indexname = 'users_tenant_email_lower_key'
      and indexdef ~ 'lower'),
  1,
  'the case-INSENSITIVE unique index exists -- this is what actually bounds the claim to one row per tenant, which users_tenant_email_key never did');

select throws_ok(
  $q$insert into public.users (tenant_id, full_name, email, is_active, auth_user_id)
     values ('75000000-0000-0000-0000-000000000001','Case Twin','CLAIMANT@ident.test',true,null)$q$,
  '23505', null,
  'REPRODUCTION CLOSED: a case-variant duplicate of an existing member is refused AT PROVISIONING TIME -- previously it was accepted, and the invitee then hit an unrecoverable 23505 when they tried to claim');

-- The fix must not break case-insensitive onboarding, which is the reason the match is lower() in
-- the first place: someone who signs up as MiXeD@case still owns the mailbox the invite was sent to.
insert into auth.users (id, email, email_confirmed_at) values
  ('75000000-0000-0000-0000-0000000000c3','MIXED@ident.test', now());
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('75000000-0000-0000-0000-000000000016','75000000-0000-0000-0000-000000000001','Mixed Case','mixed@ident.test',true,null);
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('75000000-0000-0000-0000-000000000001','75000000-0000-0000-0000-000000000016','75000000-0000-0000-0000-00000000000a','75000000-0000-0000-0000-0000000000e1',true);

select set_config('request.jwt.claims','{"sub":"75000000-0000-0000-0000-0000000000c3"}', true);
set local role authenticated;

select is(
  (select count(*)::int from app.activate_membership()),
  1,
  'THE ONE THAT MATTERS for IDENT-4: an identity confirmed as MIXED@ident.test still claims the membership stored as mixed@ident.test -- case-insensitive onboarding is intact, which is the whole reason the match uses lower()');

select finish();
rollback;
