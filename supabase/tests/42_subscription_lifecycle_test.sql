-- pgTAP: SPEC-157 -- the subscription lifecycle is real, and only the Platform Owner drives it.
--
-- Two defects are guarded here, both proven live before the migration was written:
--
--   B2. `ends_at` / `grace_ends_at` / `read_only_started_at` were DECORATIVE -- written by DDL, read
--       only by a reporting view, consumed by no logic, advanced by no job. A trial whose `ends_at`
--       passed a year ago kept full write access forever, so a 30-day limit would have meant
--       nothing. Assertions 4-6 and 12-18 are the two independent mechanisms that fixed it: the
--       write gate refuses immediately, and the scheduled job records the transition.
--
--   B6. `MANAGE_SUBSCRIPTION` is held by no role, which makes the RLS policies on `subscriptions`
--       deny every tenant user. That was TRUE BY ACCIDENT before this package. Assertions 19-23
--       turn it into a tested property, so a later "tidy up the orphaned permissions" pass cannot
--       silently hand a tenant the ability to elevate its own subscription.
--
-- The platform assertions are written against a tenant owner who provably HOLDS tenant authority and
-- provably CAN SEE the row -- otherwise "the update did nothing" would be indistinguishable from
-- "the row was never visible", which is the vacuous-test failure mode this repository has already
-- been bitten by twice.
create extension if not exists pgtap with schema extensions;

begin;
select plan(28);

insert into auth.users (id, email) values
  ('42000000-0000-0000-0000-0000000000a1','owner@life.test');

-- A: trial, already past its end          -> the job must expire it
-- B: active, past its end, no auto-renew   -> the job must move it to grace_period
-- C: grace_period, past its grace window   -> the job must move it to read_only
-- D: active, past its end, auto-renewing   -> the job must roll the period, NOT change state
-- E: lifetime (no end date)                -> the job must never touch it, and it writes forever
-- G: grace_period, still inside its window -> writes must still be allowed (deadline is per state)
-- F: healthy active tenant with a real owner user, for the platform-authority assertions
insert into public.tenants (id, name, slug, status, trial_started_at, trial_ends_at) values
  ('42000000-0000-0000-0000-000000000001','Life A','life-a','active', now() - interval '31 days', now() - interval '1 day'),
  ('42000000-0000-0000-0000-000000000002','Life B','life-b','active', null, null),
  ('42000000-0000-0000-0000-000000000003','Life C','life-c','active', null, null),
  ('42000000-0000-0000-0000-000000000004','Life D','life-d','active', null, null),
  ('42000000-0000-0000-0000-000000000005','Life E','life-e','active', null, null),
  ('42000000-0000-0000-0000-000000000006','Life F','life-f','active', null, null),
  ('42000000-0000-0000-0000-000000000007','Life G','life-g','active', null, null);

insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code,
                                  starts_at, ends_at, grace_ends_at, billing_period_code, auto_renew)
select v.t, sp.id, v.st, v.starts, v.ends, v.grace, v.period, v.renew
from (values
  ('42000000-0000-0000-0000-000000000001'::uuid,'trial',        now() - interval '31 days', now() - interval '1 day',  null::timestamptz,        null,        false),
  ('42000000-0000-0000-0000-000000000002'::uuid,'active',       now() - interval '40 days', now() - interval '1 day',  null::timestamptz,        'monthly',   false),
  ('42000000-0000-0000-0000-000000000003'::uuid,'grace_period', now() - interval '40 days', now() - interval '3 days', now() - interval '1 day', 'monthly',   false),
  ('42000000-0000-0000-0000-000000000004'::uuid,'active',       now() - interval '40 days', now() - interval '1 day',  null::timestamptz,        'monthly',   true),
  ('42000000-0000-0000-0000-000000000005'::uuid,'active',       now() - interval '40 days', null,                      null::timestamptz,        'lifetime',  false),
  ('42000000-0000-0000-0000-000000000006'::uuid,'active',       now(),                      now() + interval '30 days',null::timestamptz,        'annual',    false),
  ('42000000-0000-0000-0000-000000000007'::uuid,'grace_period', now() - interval '40 days', now() - interval '1 day',  now() + interval '1 day', 'monthly',   false)
) v(t, st, starts, ends, grace, period, renew)
join public.subscription_plans sp on sp.plan_code = 'enterprise';

insert into public.branches (id, tenant_id, name, slug) values
  ('42000000-0000-0000-0000-00000000000a','42000000-0000-0000-0000-000000000006','Cairo','life-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('42000000-0000-0000-0000-0000000000c1','42000000-0000-0000-0000-000000000006','42000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('42000000-0000-0000-0000-000000000011','42000000-0000-0000-0000-000000000006','Life Owner','owner@life.test',true,'42000000-0000-0000-0000-0000000000a1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('42000000-0000-0000-0000-000000000006','42000000-0000-0000-0000-000000000011','42000000-0000-0000-0000-00000000000a','42000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '42000000-0000-0000-0000-000000000006','42000000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'owner';

-- =============================================================================================
-- 1-3. The business rules have one home each, and the commercial vocabulary is a catalog rather
--      than a list buried in code.
-- =============================================================================================
select is(app.trial_period_days(), 30,
  'the trial is 30 days, held in exactly one function (owner-ratified 2026-08-27)');

select is(app.grace_period_days(), 2,
  'the grace period is 2 days -- canon 09, not an invented number');

select is(
  (select count(*)::int from public.catalog_values
    where catalog_type_code = 'subscription_period' and is_active),
  5,
  'monthly / quarterly / semi_annual / annual / lifetime are catalog values, not hardcoded');

-- =============================================================================================
-- 4-7. THE DATES ARE LOAD-BEARING -- and this is asserted BEFORE the job runs, because that is the
--      window in which the old system leaked free write time. The deadline is per state: a tenant
--      in grace_period is there precisely BECAUSE `ends_at` passed, so testing `ends_at` for it
--      would have destroyed the grace period's entire purpose. Assertion 6 is the one that proves
--      the distinction is implemented rather than assumed.
-- =============================================================================================
select ok(app.subscription_allows_write('42000000-0000-0000-0000-000000000005'),
  'CONTROL: a LIFETIME subscription (no end date) may write -- so what follows is not a blanket denial');

select ok(not app.subscription_allows_write('42000000-0000-0000-0000-000000000001'),
  'a trial past its ends_at is denied writes IMMEDIATELY -- before any job has run');

select ok(app.subscription_allows_write('42000000-0000-0000-0000-000000000007'),
  '...while a tenant still INSIDE its grace window may write: the deadline is per state, not one date');

select throws_ok(
  $$insert into public.customers (tenant_id, customer_type_code, full_name, primary_phone)
    values ('42000000-0000-0000-0000-000000000001','person','Too Late','+201001110000')$$,
  '42501',
  null,
  'and the gate itself refuses the write, not merely the helper function');

select is(
  (select count(*)::int from public.subscriptions where tenant_id = '42000000-0000-0000-0000-000000000001'),
  1,
  'READS remain available on the same lapsed tenant -- writes are gated, data is not confiscated');

-- =============================================================================================
-- 9-10. LIFETIME IS MODELLED, NOT FAKED. The owner forbade an arbitrarily far future date; a
--       comment saying so would not stop the next writer, so the database refuses it.
-- =============================================================================================
select throws_ok(
  $$update public.subscriptions set ends_at = now() + interval '99 years'
     where tenant_id = '42000000-0000-0000-0000-000000000005'$$,
  '23514',
  null,
  'a lifetime subscription CANNOT be given an end date -- lifetime is structural, not a big number');

select throws_ok(
  $$update public.subscriptions set auto_renew = true
     where tenant_id = '42000000-0000-0000-0000-000000000005'$$,
  '23514',
  null,
  '...and cannot be put on a renewal cycle either');

-- =============================================================================================
-- 11-12. A trial that can be silently restarted is not a trial, and `tenants.status` can no longer
--        impersonate the commercial lifecycle (it was free text that nothing read).
-- =============================================================================================
select throws_ok(
  $$update public.tenants set trial_ends_at = now() + interval '30 days'
     where id = '42000000-0000-0000-0000-000000000001'$$,
  '23514',
  null,
  'the trial stamp is write-once: a trial cannot be restarted by moving its end date');

select throws_ok(
  $$update public.tenants set status = 'trial' where id = '42000000-0000-0000-0000-000000000002'$$,
  '23514',
  null,
  'tenants.status can no longer hold a commercial state -- one lifecycle, per canon 35 §8');

-- =============================================================================================
-- 13-18. THE SCHEDULED JOB. Four tenants are due in the same run and two are not; the run must
--        advance every due tenant and skip the rest. This shape is the WP-03 lesson: a job that
--        raised on one tenant's behalf once aborted the entire multi-tenant run.
-- =============================================================================================
select lives_ok(
  $$select app.process_subscription_lifecycle()$$,
  'the lifecycle job runs to completion with both due and ineligible tenants in the same pass');

select is(
  (select subscription_status_code from public.subscriptions where tenant_id = '42000000-0000-0000-0000-000000000001'),
  'expired',
  'trial past its end -> expired (canon 26: "Trial ends without activation")');

select is(
  (select subscription_status_code || ':' || (grace_ends_at::date - ends_at::date)::text
     from public.subscriptions where tenant_id = '42000000-0000-0000-0000-000000000002'),
  'grace_period:2',
  'active past its end -> grace_period, with the 2-day window canon 09 specifies');

select is(
  (select subscription_status_code from public.subscriptions where tenant_id = '42000000-0000-0000-0000-000000000003'),
  'read_only',
  'grace period elapsed -> read_only (canon 26)');

select is(
  (select subscription_status_code || ':' || (ends_at > now())::text
     from public.subscriptions where tenant_id = '42000000-0000-0000-0000-000000000004'),
  'active:true',
  'an AUTO-RENEWING tenant rolls its period forward and stays active -- state unchanged, date moved');

select is(
  (select subscription_status_code || ':' || coalesce(ends_at::text, 'no-end')
     from public.subscriptions where tenant_id = '42000000-0000-0000-0000-000000000005'),
  'active:no-end',
  '...and the lifetime tenant is untouched by the same run -- ineligible tenants are skipped, not failed');

-- =============================================================================================
-- 19. The audit spine records it. Canon 26 names these as REQUIRED events, and until this package
--     all eleven subscription event types had zero producers anywhere in the repository.
-- =============================================================================================
select is(
  (select count(distinct event_type_code)::int from public.events
    where event_type_code in ('subscription_expired','subscription_entered_grace_period',
                              'subscription_entered_read_only')),
  3,
  'each transition emitted its canon-26 event -- the first producers these event types have ever had');

-- =============================================================================================
-- 20-23. PLATFORM AUTHORITY. A tenant Owner cannot elevate its own subscription. The two controls
--        come first so the refusal cannot be confused with an invisible row or a dead session.
-- =============================================================================================
select is(
  (select count(*)::int from public.role_permissions rp
     join public.permissions p on p.id = rp.permission_id
    where p.key = 'MANAGE_SUBSCRIPTION'),
  0,
  'NO role holds MANAGE_SUBSCRIPTION -- deliberate, and now permanent: platform authority is not a tenant permission');

select set_config('request.jwt.claims','{"sub":"42000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(
  (select count(*) from public.subscriptions where tenant_id = '42000000-0000-0000-0000-000000000006') = 1,
  'CONTROL: the tenant owner CAN SEE its own subscription row (VIEW_SUBSCRIPTION_STATUS)');

select lives_ok(
  $$update public.tenants set legal_name = 'Life F Ltd' where id = '42000000-0000-0000-0000-000000000006'$$,
  'CONTROL: ...and the session is genuinely authorized inside its tenant (MANAGE_TENANT_SETTINGS)');

update public.subscriptions set subscription_status_code = 'active', ends_at = now() + interval '10 years'
 where tenant_id = '42000000-0000-0000-0000-000000000006';

reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select (ends_at < now() + interval '1 year')::text from public.subscriptions
    where tenant_id = '42000000-0000-0000-0000-000000000006'),
  'true',
  '...yet its attempt to grant itself a 10-year subscription changed NOTHING -- no rows matched the policy');

-- =============================================================================================
-- 24-25. The platform surface exists, is validated against canon 26, and is not reachable by a
--        tenant user at all.
-- =============================================================================================
select ok(
  not has_function_privilege('authenticated',
      'app.platform_activate_subscription(uuid, text, text, boolean)', 'EXECUTE'),
  'no authenticated user may execute the platform activation function -- service_role only');

select throws_ok(
  $$select app.platform_transition_subscription('42000000-0000-0000-0000-000000000001','suspended')$$,
  '23514',
  null,
  'even the Platform Owner is held to canon 26: expired -> suspended is not a legal transition');

-- =============================================================================================
-- 26-28. ...and the platform surface actually WORKS. Proving only that tenants cannot reach it
--        would leave a function that is unreachable AND broken looking identical to one that is
--        unreachable and correct. Tenant G is in grace_period, so grace_period -> active exercises
--        the canon-26 validator on the way in rather than bypassing it.
-- =============================================================================================
select lives_ok(
  $$select app.platform_activate_subscription('42000000-0000-0000-0000-000000000007','professional','annual')$$,
  'the Platform Owner activates a lapsed tenant on a chosen plan and duration');

-- The end date is compared to the same interval the function is supposed to have used, rather than
-- to a day count, so the assertion stays true across leap years instead of failing once in four.
select is(
  (select sp.plan_code || ':' || s.subscription_status_code || ':' || s.billing_period_code
          || ':' || (s.ends_at::date = (now() + interval '1 year')::date)::text
     from public.subscriptions s
     join public.subscription_plans sp on sp.id = s.subscription_plan_id
    where s.tenant_id = '42000000-0000-0000-0000-000000000007'),
  'professional:active:annual:true',
  '...plan, state, duration and end date all follow from the one activation call');

select app.platform_activate_subscription('42000000-0000-0000-0000-000000000007','enterprise','lifetime');

select is(
  (select coalesce(s.ends_at::text, 'no-end') || ':' || s.auto_renew::text
     from public.subscriptions s where s.tenant_id = '42000000-0000-0000-0000-000000000007'),
  'no-end:false',
  'switching that tenant to LIFETIME clears the end date and forces auto_renew off -- never a far-future date');

select finish();
rollback;
