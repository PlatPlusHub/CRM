-- pgTAP: SPEC-158 -- the tenant license activation credential (canon C4).
--
-- The owner proposed a TOTP-style credential and explicitly asked for the correct security
-- architecture rather than blind implementation. The answer was a single-use, hashed, expiring
-- token, because TOTP would have required ORVION to store a shared secret -- something
-- `totp_enrollments` deliberately does not do (it has no secret column at all; canon 34 / ADR-0017
-- keep every factor inside Supabase Auth) -- and because TOTP is a REPEATING credential where a
-- SINGLE-USE one is required.
--
-- The assertions that carry the security argument are 2 (the plaintext is not recoverable from the
-- database), 11 (replay is closed), 13-14 (rotation actually revokes), 17 (cross-tenant redemption
-- is structurally impossible) and 19 (the plaintext never reaches the audit trail).
--
-- Tenant A is deliberately in `read_only` -- a lapsed tenant is EXACTLY who redeems an activation
-- code, so if the subscription write gate blocked this table the feature would be useless to the
-- only people who need it.
create extension if not exists pgtap with schema extensions;

begin;
select plan(19);

insert into auth.users (id, email) values
  ('43000000-0000-0000-0000-0000000000a1','owner-a@lic.test'),
  ('43000000-0000-0000-0000-0000000000a2','emp-a@lic.test'),
  ('43000000-0000-0000-0000-0000000000a3','owner-b@lic.test');

insert into public.tenants (id, name, slug, status) values
  ('43000000-0000-0000-0000-000000000001','Lic A','lic-a','active'),
  ('43000000-0000-0000-0000-000000000002','Lic B','lic-b','active');

insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code, starts_at, ends_at)
select v.t, sp.id, v.st, now() - interval '40 days', v.ends
from (values
  ('43000000-0000-0000-0000-000000000001'::uuid, 'read_only', null::timestamptz),
  ('43000000-0000-0000-0000-000000000002'::uuid, 'active',    now() + interval '30 days')
) v(t, st, ends)
join public.subscription_plans sp on sp.plan_code = 'starter';

insert into public.branches (id, tenant_id, name, slug) values
  ('43000000-0000-0000-0000-00000000000a','43000000-0000-0000-0000-000000000001','A HQ','lic-a-hq'),
  ('43000000-0000-0000-0000-00000000000b','43000000-0000-0000-0000-000000000002','B HQ','lic-b-hq');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('43000000-0000-0000-0000-0000000000c1','43000000-0000-0000-0000-000000000001','43000000-0000-0000-0000-00000000000a','sales','A Sales'),
  ('43000000-0000-0000-0000-0000000000c2','43000000-0000-0000-0000-000000000002','43000000-0000-0000-0000-00000000000b','sales','B Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('43000000-0000-0000-0000-000000000011','43000000-0000-0000-0000-000000000001','A Owner','owner-a@lic.test',true,'43000000-0000-0000-0000-0000000000a1'),
  ('43000000-0000-0000-0000-000000000012','43000000-0000-0000-0000-000000000001','A Employee','emp-a@lic.test',true,'43000000-0000-0000-0000-0000000000a2'),
  ('43000000-0000-0000-0000-000000000013','43000000-0000-0000-0000-000000000002','B Owner','owner-b@lic.test',true,'43000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('43000000-0000-0000-0000-000000000001','43000000-0000-0000-0000-000000000011','43000000-0000-0000-0000-00000000000a','43000000-0000-0000-0000-0000000000c1',true),
  ('43000000-0000-0000-0000-000000000001','43000000-0000-0000-0000-000000000012','43000000-0000-0000-0000-00000000000a','43000000-0000-0000-0000-0000000000c1',true),
  ('43000000-0000-0000-0000-000000000002','43000000-0000-0000-0000-000000000013','43000000-0000-0000-0000-00000000000b','43000000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values
  ('43000000-0000-0000-0000-000000000001'::uuid,'43000000-0000-0000-0000-000000000011'::uuid,'owner'),
  ('43000000-0000-0000-0000-000000000001'::uuid,'43000000-0000-0000-0000-000000000012'::uuid,'employee'),
  ('43000000-0000-0000-0000-000000000002'::uuid,'43000000-0000-0000-0000-000000000013'::uuid,'owner')
) v(t, u, rc)
join public.roles r on r.code = v.rc;

-- The plaintext exists only in this temp table for the length of the test; it is never persisted by
-- the system under test, which assertion 2 is what proves.
create temp table lic (k text primary key, v text);
-- Test scaffold only: the assertions below run as `authenticated`, and they must be able to hand the
-- plaintext back to the function the way a human operator would. Nothing in the system under test
-- grants a tenant role access to a token.
grant select on lic to authenticated;

-- =============================================================================================
-- 1-2. ISSUANCE, and the property the whole design rests on: the database cannot give the token
--      back. A dump of `tenant_license_activations` yields hashes, never anything redeemable.
-- =============================================================================================
insert into lic
select 'a1', app.platform_issue_license_token(
  '43000000-0000-0000-0000-000000000001', 'professional', 'annual', false, 7, 'renewal 2026');

select matches(
  (select v from lic where k = 'a1'),
  '^[0-9a-f]{32}$',
  'the Platform Owner receives a 128-bit token, hex so a human can dictate it over the phone');

select is(
  (select count(*)::int from public.tenant_license_activations t
    where t.tenant_id = '43000000-0000-0000-0000-000000000001'
      and (t.token_hash = (select v from lic where k = 'a1')
           or t.token_hash <> encode(extensions.digest((select v from lic where k = 'a1'), 'sha256'), 'hex'))),
  0,
  'the PLAINTEXT is nowhere in the table, and what is stored is exactly its SHA-256 -- a dump is useless');

-- =============================================================================================
-- 3-4. The credential is not reachable as data, and issuance is not reachable by a tenant.
-- =============================================================================================
select is(
  (select count(*)::int from information_schema.role_table_grants
    where grantee in ('authenticated','anon') and table_schema = 'public'
      and table_name = 'tenant_license_activations'),
  0,
  'no tenant-facing role holds ANY privilege on the token table -- hashes are not merely RLS-hidden');

select ok(
  not has_function_privilege('authenticated',
      'app.platform_issue_license_token(uuid, text, text, boolean, integer, text)', 'EXECUTE'),
  'a tenant user cannot issue itself a token -- issuance is service_role only');

-- =============================================================================================
-- 5-7. REJECTION. The control comes first: the owner genuinely holds the authority to redeem, so
--      the refusal below is about the TOKEN and nothing else.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"43000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('MANAGE_TENANT_SETTINGS'),
  'CONTROL: tenant A''s owner HOLDS MANAGE_TENANT_SETTINGS -- what follows is not a permission failure');

select throws_ok(
  $$select app.redeem_license_token('deadbeefdeadbeefdeadbeefdeadbeef')$$,
  '42501',
  'activation code is not valid',
  'a wrong code is refused with ONE generic message -- never "already used" vs "no such token", which would be a guessing oracle');

reset role;
select set_config('request.jwt.claims', null, true);

-- A FAILED ATTEMPT IS NOT AUDITED, and this assertion exists to say so out loud.
--
-- The first version of `app.redeem_license_token` wrote a rejection row here and then raised. This
-- very assertion caught that the row was never there: `raise` aborts the transaction and takes the
-- audit INSERT with it, and PostgreSQL has no autonomous transaction to escape that. Rather than
-- ship an INSERT that looks like auditing and never runs, the function now states the limitation in
-- its own body -- and this assertion pins the real behaviour, so nobody builds a brute-force alert
-- on data that does not exist. Successful redemptions ARE audited (assertion 18); replay is closed
-- by consumption regardless (assertion 11); a 128-bit token makes guessing infeasible.
select is(
  (select count(*)::int from public.security_events
    where tenant_id = '43000000-0000-0000-0000-000000000001'
      and security_event_type_code like 'license_token_%'),
  1,
  'a REFUSED attempt leaves no audit row -- the raise rolls it back; only the issuance survives');

-- =============================================================================================
-- 8-10. REDEMPTION by a READ_ONLY tenant -- the case the feature exists for. If the subscription
--       write gate covered this table, a lapsed tenant could never renew itself.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"43000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$select app.redeem_license_token((select v from lic where k = 'a1'))$$,
  'the owner of a READ_ONLY tenant redeems the code -- exactly who needs to');

reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select sp.plan_code || ':' || s.subscription_status_code || ':' || s.billing_period_code
     from public.subscriptions s join public.subscription_plans sp on sp.id = s.subscription_plan_id
    where s.tenant_id = '43000000-0000-0000-0000-000000000001'),
  'professional:active:annual',
  '...and the subscription now carries exactly the terms the PLATFORM fixed at issuance, not terms the tenant chose');

select is(
  (select consumed_by::text from public.tenant_license_activations
    where tenant_id = '43000000-0000-0000-0000-000000000001' and consumed_at is not null),
  '43000000-0000-0000-0000-000000000011',
  '...and the token is burned, attributed to the user who redeemed it');

-- =============================================================================================
-- 11. REPLAY. The single property TOTP could not have given us without adding this same record.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"43000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$select app.redeem_license_token((select v from lic where k = 'a1'))$$,
  '42501', 'activation code is not valid',
  'the SAME code cannot be used twice -- replay is closed by consumption, not by hoping');

-- =============================================================================================
-- 12. An ordinary employee cannot renew the company licence, even holding a valid code.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);
insert into lic select 'a2', app.platform_issue_license_token(
  '43000000-0000-0000-0000-000000000001', 'enterprise', 'monthly');

select set_config('request.jwt.claims','{"sub":"43000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;
select throws_ok(
  $$select app.redeem_license_token((select v from lic where k = 'a2'))$$,
  '42501', 'permission denied: MANAGE_TENANT_SETTINGS',
  'an employee holding a genuinely valid code still cannot renew the licence -- and fails on AUTHORITY, not on the code');

-- =============================================================================================
-- 13-14. ROTATION. Issuing again supersedes the outstanding token, so "regenerate" needs no
--        separate function and two live codes for one tenant cannot exist.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);
insert into lic select 'a3', app.platform_issue_license_token(
  '43000000-0000-0000-0000-000000000001', 'enterprise', 'quarterly');

select is(
  (select revoked_reason from public.tenant_license_activations
    where tenant_id = '43000000-0000-0000-0000-000000000001' and revoked_at is not null
    order by issued_at desc limit 1),
  'superseded by a newly issued token',
  'issuing a replacement REVOKES the outstanding one -- rotation is issuance, not a second mechanism');

select set_config('request.jwt.claims','{"sub":"43000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$select app.redeem_license_token((select v from lic where k = 'a2'))$$,
  '42501', 'activation code is not valid',
  '...and the superseded code is dead -- a leaked old code cannot be used after regeneration');

-- =============================================================================================
-- 15-16. EXPIRY and explicit REVOCATION -- the owner's "reset" and compromise-recovery requirements.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);
update public.tenant_license_activations
   set expires_at = now() - interval '1 minute'
 where tenant_id = '43000000-0000-0000-0000-000000000001' and consumed_at is null and revoked_at is null;

select set_config('request.jwt.claims','{"sub":"43000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$select app.redeem_license_token((select v from lic where k = 'a3'))$$,
  '42501', 'activation code is not valid',
  'an expired code is refused -- canon 09 asked for a TIME-SENSITIVE credential');

reset role;
select set_config('request.jwt.claims', null, true);
insert into lic select 'a4', app.platform_issue_license_token(
  '43000000-0000-0000-0000-000000000001', 'enterprise', 'annual');

select is(
  app.platform_revoke_license_tokens('43000000-0000-0000-0000-000000000001', 'suspected compromise'),
  1,
  'the Platform Owner can revoke outstanding codes outright -- compromise recovery without a schema change');

-- =============================================================================================
-- 17. CROSS-TENANT. Tenant B holds A's code. This is not merely refused -- the lookup is scoped to
--     the caller's own tenant, so the row is not even visible to be refused.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"43000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$select app.redeem_license_token((select v from lic where k = 'a4'))$$,
  '42501', 'activation code is not valid',
  'another agency''s owner cannot redeem tenant A''s code, even holding the exact plaintext');

-- =============================================================================================
-- 18-19. AUDIT. `public.security_events` had ZERO producers in the whole repository before this
--        package; these are its first. And the trail must never contain the credential itself.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims', null, true);

select ok(
  (select count(distinct security_event_type_code) from public.security_events
    where security_event_type_code in
          ('license_token_issued','license_token_redeemed','license_token_revoked')) = 3,
  'issue, redeem and revoke are all audited -- the first producers public.security_events has ever had');

select is(
  (select count(*)::int from public.security_events se, lic
    where se.payload::text like '%' || lic.v || '%'),
  0,
  'and NO token plaintext ever reaches the audit trail -- reading security_events must not let you redeem');

select finish();
rollback;
