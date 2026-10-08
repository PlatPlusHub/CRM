-- pgTAP: Batch 6 slice 34 -- an activation code carries the platform owner's current decision.
--
-- ATTACK-CLASSES: BUSINESS STATE TENANT OBSERVABILITY CONCURRENCY DOOR=N/A PRIVILEGE=N/A AUTH=N/A INPUT=N/A REPLAY=N/A
--   DOOR=N/A -- no signed-in role holds any privilege on `tenant_license_activations` and its policy is
--     `platform_only`; `43_...` assertions 3-4 pin that.
--   PRIVILEGE=N/A, AUTH=N/A -- who may redeem (the tenant owner at aal2, not an employee) is `43_...`'s
--     contract; this file asks WHICH codes may still be redeemed.
--   INPUT=N/A -- the code's shape and the generic refusal are `43_...`'s.
--   REPLAY=N/A -- a consumed code is refused (`43_...` assertion 11); LIC-2's concurrent replay is
--     `80_...`'s.
--   CONCURRENCY -- pgTAP has one session, so this file pins the schema rule that makes concurrent
--     issuance safe (assertion 14); the two-session reproduction is recorded in SPEC-247.
--
-- Canon 26 gives `suspended -> active` and `cancelled -> active` to the Platform Owner. SPEC-158 says
-- issuing a code means two live codes for one tenant cannot exist.
--   LIC-4: a code issued before the Platform Owner suspended or cancelled a tenant still redeemed,
--          and the tenant reactivated itself.
--   LIC-5: two concurrent issuances for one tenant both left a live code.
--
-- THE FIXTURE. Tenant A starts `read_only`, the state the code exists to renew from; its `owner`
-- redeems at aal2. Tenant B holds a live code of its own and has nothing else in this file.
create extension if not exists pgtap with schema extensions;

begin;
select plan(15);

insert into auth.users (id, email) values
  ('14700000-0000-0000-0000-0000000000a1','owner@l147.test');
insert into public.tenants (id, name, slug, status) values
  ('14700000-0000-0000-0000-000000000001','L147 Travel','l147-travel','active'),
  ('14700000-0000-0000-0000-000000000002','L147 Rival','l147-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select v.t, sp.id, v.st from public.subscription_plans sp,
  (values ('14700000-0000-0000-0000-000000000001'::uuid, 'read_only'),
          ('14700000-0000-0000-0000-000000000002'::uuid, 'active')) v(t, st)
where sp.plan_code = 'starter';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('14700000-0000-0000-0000-000000000011','14700000-0000-0000-0000-000000000001','Owner','owner@l147.test',true,'14700000-0000-0000-0000-0000000000a1');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '14700000-0000-0000-0000-000000000001', '14700000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'owner';

-- The plaintext lives only in this temp table, handed back the way a human operator would.
create temp table code (k text primary key, v text);
grant select on code to authenticated;

create function pg_temp.live(p_tenant uuid) returns integer language sql as $$
  select count(*)::int from public.tenant_license_activations
  where tenant_id = p_tenant and consumed_at is null and revoked_at is null $$;
create function pg_temp.status(p_tenant uuid) returns text language sql as $$
  select subscription_status_code from public.subscriptions where tenant_id = p_tenant $$;

-- =============================================================================================
-- 1-3. THE POSITIVE CONTROL. A live code renews a read_only tenant, and after it is consumed the
--      Platform Owner can issue the next one: a consumed code is not a live one.
-- =============================================================================================
insert into code select 'first', app.platform_issue_license_token(
  '14700000-0000-0000-0000-000000000001', 'professional', 'annual', false, 7, 'renewal');

select set_config('request.jwt.claims','{"sub":"14700000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select lives_ok(
  $$select app.redeem_license_token((select v from code where k = 'first'))$$,
  '1. the owner redeems a live code at aal2 (positive control)');
reset role;
select set_config('request.jwt.claims', null, true);

select is(pg_temp.status('14700000-0000-0000-0000-000000000001'), 'active',
  '2. the code renewed the tenant: read_only -> active');

select lives_ok(
  $$insert into code select 'stale', app.platform_issue_license_token(
      '14700000-0000-0000-0000-000000000001', 'enterprise', 'annual', false, 7, 'next term')$$,
  '3. a consumed code does not block the next issuance');

insert into code select 'rival', app.platform_issue_license_token(
  '14700000-0000-0000-0000-000000000002', 'professional', 'monthly', false, 7, 'rival renewal');

-- =============================================================================================
-- 4-9. SUSPENSION. Grace and read_only keep the code -- renewing from them is what it is for. The
--      Platform Owner's suspension revokes it, audited, and the tenant cannot undo the suspension.
-- =============================================================================================
select app.platform_transition_subscription('14700000-0000-0000-0000-000000000001', 'grace_period');
select app.platform_transition_subscription('14700000-0000-0000-0000-000000000001', 'read_only');
select is(pg_temp.live('14700000-0000-0000-0000-000000000001'), 1,
  '4. grace_period and read_only leave the outstanding code live');

select app.platform_transition_subscription('14700000-0000-0000-0000-000000000001', 'suspended');
select is(pg_temp.live('14700000-0000-0000-0000-000000000001'), 0,
  '5. LIC-4: suspending the tenant revokes its outstanding code');

select is(
  (select count(*)::int from public.security_events
   where tenant_id = '14700000-0000-0000-0000-000000000001'
     and security_event_type_code = 'license_token_revoked'
     and payload ->> 'reason' = 'subscription suspended by platform owner'
     and (payload ->> 'count')::int = 1),
  1, '6. the revocation is audited once, naming the suspension');

select set_config('request.jwt.claims','{"sub":"14700000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$select app.redeem_license_token((select v from code where k = 'stale'))$$,
  '42501', 'activation code is not valid',
  '7. LIC-4: the code issued before the suspension is refused with the generic message');
reset role;
select set_config('request.jwt.claims', null, true);

select is(pg_temp.status('14700000-0000-0000-0000-000000000001'), 'suspended',
  '8. the tenant stays suspended');

select is(pg_temp.live('14700000-0000-0000-0000-000000000002'), 1,
  '9. another tenant''s code is untouched by this suspension');

-- =============================================================================================
-- 10-11. A code issued AFTER the suspension is the Platform Owner's new decision, and restores.
-- =============================================================================================
insert into code select 'fresh', app.platform_issue_license_token(
  '14700000-0000-0000-0000-000000000001', 'professional', 'monthly', false, 7, 'restore');

select set_config('request.jwt.claims','{"sub":"14700000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select lives_ok(
  $$select app.redeem_license_token((select v from code where k = 'fresh'))$$,
  '10. a code issued after the suspension still redeems (control for 7)');
reset role;
select set_config('request.jwt.claims', null, true);

select is(pg_temp.status('14700000-0000-0000-0000-000000000001'), 'active',
  '11. the Platform Owner''s fresh code restored the tenant: suspended -> active');

-- =============================================================================================
-- 12-13. CANCELLATION revokes the same way.
-- =============================================================================================
insert into code select 'precancel', app.platform_issue_license_token(
  '14700000-0000-0000-0000-000000000001', 'enterprise', 'annual', false, 7, 'before cancel');
select app.platform_transition_subscription('14700000-0000-0000-0000-000000000001', 'cancelled');

select set_config('request.jwt.claims','{"sub":"14700000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $$select app.redeem_license_token((select v from code where k = 'precancel'))$$,
  '42501', 'activation code is not valid',
  '12. LIC-4: the code issued before the cancellation is refused');
reset role;
select set_config('request.jwt.claims', null, true);

select is(pg_temp.status('14700000-0000-0000-0000-000000000001'), 'cancelled',
  '13. the tenant stays cancelled');

-- =============================================================================================
-- 14-15. LIC-5. One live code per tenant is the schema's rule, so the second of two concurrent
--        issuances is refused; rotation in sequence is unchanged.
-- =============================================================================================
insert into code select 'live', app.platform_issue_license_token(
  '14700000-0000-0000-0000-000000000001', 'starter', 'monthly', false, 7, 'live');

select throws_ok(
  $$insert into public.tenant_license_activations
      (tenant_id, token_hash, plan_code, billing_period_code, expires_at)
    values ('14700000-0000-0000-0000-000000000001', repeat('0', 64), 'starter', 'monthly',
            now() + interval '1 day')$$,
  '23505', null,
  '14. LIC-5: a second live code for one tenant is refused by the schema');

insert into code select 'rotated', app.platform_issue_license_token(
  '14700000-0000-0000-0000-000000000001', 'starter', 'monthly', false, 7, 'rotated');
select ok(
  pg_temp.live('14700000-0000-0000-0000-000000000001') = 1
  and exists (select 1 from public.tenant_license_activations
              where tenant_id = '14700000-0000-0000-0000-000000000001'
                and consumed_at is null and revoked_at is null
                and token_hash = encode(extensions.digest((select v from code where k = 'rotated'), 'sha256'), 'hex')),
  '15. rotation in sequence is unchanged: the newest code is the one live code');

select * from finish();
rollback;
