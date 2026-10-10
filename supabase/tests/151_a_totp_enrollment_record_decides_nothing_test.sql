-- ATTACK-CLASSES: AUTH DOOR BUSINESS TENANT=N/A STATE=N/A INPUT=N/A CONCURRENCY=N/A OBSERVABILITY=N/A PRIVILEGE=N/A REPLAY=N/A
-- SPEC-259 / Batch 6 Slice 37. `public.totp_enrollments` is a record that decides nothing, and this
-- file pins that it stays one. AUTH-1 (owner, 2026-09-01) made Supabase Auth the sole factor store:
-- step-up is `app.mfa_satisfied()`, which reads `app.requires_mfa()` and the JWT `aal` claim and
-- nothing else. The table keeps the canon-31 section-9 shape with no secret, its owner-only policy
-- and `authenticated` INSERT/SELECT/UPDATE, and has no writer, reader, trigger or view (IDENT-3,
-- OTP-2). A subject can therefore plant, backdate, duplicate or contradict its own enrollment, and
-- that is harmless only while nothing reads the table. AUTH-1 owes the table's retirement "before
-- any code first references either table"; `75_...` assertion 25 fails when a WRITER appears or the
-- grant moves, and nothing failed when a READER appeared. Assertion 12 is that missing tripwire.
--
-- TENANT=N/A        canon 34 keys the table to the human, not a tenant; the human boundary is
--                   attacked under AUTH (7-9, 11). `58_...` already pins the cross-identity INSERT.
-- STATE=N/A         no lifecycle is consumed: two active rows, or an active row with `revoked_at`,
--                   are accepted and change nothing (4-6); canon 29's one-active cardinality is a
--                   property of a record AUTH-1 retires, and the factor store is Supabase Auth's.
-- INPUT=N/A         no column is read, so no value is consequential beyond the boundary columns.
-- CONCURRENCY=N/A   no read-modify-write path exists to race.
-- OBSERVABILITY=N/A TOTP enrollment and challenge events are Supabase Auth's (AUTH-1, ADMIN-3).
-- PRIVILEGE=N/A     `service_role`'s privileges are granted by the platform image, not by this
--                   repository (PAR-5; `106_...` assertion 10's note).
-- REPLAY=N/A        nothing is redeemed or consumed.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into auth.users (id,email,email_confirmed_at) values
  ('15100000-0000-0000-0000-0000000000a1','owner@totp151.test',now()),
  ('15100000-0000-0000-0000-0000000000a2','victim@totp151.test',now());
insert into public.tenants (id,name,slug,status) values
  ('15100000-0000-0000-0000-000000000001','TOTP151 Travel','totp151-travel','active');
insert into public.subscriptions (tenant_id,subscription_plan_id,subscription_status_code)
select '15100000-0000-0000-0000-000000000001',id,'active'
from public.subscription_plans where plan_code='enterprise';
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('15100000-0000-0000-0000-000000000011','15100000-0000-0000-0000-000000000001','Owner','owner@totp151.test',true,'15100000-0000-0000-0000-0000000000a1');
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '15100000-0000-0000-0000-000000000001','15100000-0000-0000-0000-000000000011',id,'tenant'
from public.roles where code='owner';
-- Another human's active enrollment, so the human-boundary assertions judge a row that exists.
insert into public.totp_enrollments (id,auth_user_id,is_active,enrolled_at) values
  ('15100000-0000-0000-0000-0000000000e2','15100000-0000-0000-0000-0000000000a2',true,'2026-01-01');

create temp table s151 (k text primary key, v text) on commit drop;
grant all on s151 to authenticated;
insert into s151 values ('mfa_def', (select md5(pg_get_functiondef('app.mfa_satisfied()'::regprocedure))));

-- The objects that name the table: functions in `app` and `public`, views, other tables' policies,
-- and triggers on it. Empty while the record decides nothing.
create function pg_temp.totp_mentions() returns text language sql as $$
  select coalesce(string_agg(m, ',' order by m), '') from (
    select 'function:' || n.nspname || '.' || p.proname as m
      from pg_proc p join pg_namespace n on n.oid = p.pronamespace
     where n.nspname in ('app','public') and p.prosrc ~ 'totp_enrollments'
    union all
    select 'view:' || schemaname || '.' || viewname from pg_views where definition ~ 'totp_enrollments'
    union all
    select 'policy:' || p.polrelid::regclass::text || '.' || p.polname from pg_policy p
     where p.polrelid <> 'public.totp_enrollments'::regclass
       and coalesce(pg_get_expr(p.polqual, p.polrelid),'') || coalesce(pg_get_expr(p.polwithcheck, p.polrelid),'') ~ 'totp_enrollments'
    union all
    select 'trigger:' || t.tgname from pg_trigger t
     where t.tgrelid = 'public.totp_enrollments'::regclass and not t.tgisinternal
  ) s $$;

-- ================================================================================================
-- 1-6. BUSINESS: the record does not move step-up in either direction.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"15100000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);

select ok(app.requires_mfa(), 'CONTROL: the owner is a high-risk role whose step-up canon 28 requires');
select ok(not app.mfa_satisfied(), 'CONTROL: at aal1 the owner has not satisfied step-up');

select lives_ok(
  $$insert into public.totp_enrollments (id,auth_user_id,is_active,enrolled_at,created_at)
    values ('15100000-0000-0000-0000-0000000000e1','15100000-0000-0000-0000-0000000000a1',true,'2001-01-01','2001-01-01'),
           ('15100000-0000-0000-0000-0000000000e3','15100000-0000-0000-0000-0000000000a1',true,now(),now())$$,
  'the owner plants two active enrollments of its own, one backdated to 2001 (IDENT-3; `75_...` assertion 25 pins the door)');

select ok(not app.mfa_satisfied(), 'BUSINESS: two planted active enrollments do not satisfy step-up at aal1');

select throws_ok($$select app.authorize('MANAGE_TENANT_SETTINGS')$$, '42501',
  'multi-factor authentication required for this role',
  'BUSINESS: a step-up action is still refused at aal1 for want of MFA, not of permission');

select set_config('request.jwt.claims','{"sub":"15100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
update public.totp_enrollments set is_active = false, revoked_at = now();
select ok(app.mfa_satisfied(), 'BUSINESS: with every own enrollment revoked, aal2 still satisfies step-up: Supabase Auth decides (AUTH-1)');

-- ================================================================================================
-- 7-11. AUTH and DOOR: the human boundary, DELETE and anon.
-- ================================================================================================
select is((select count(*)::int from public.totp_enrollments where auth_user_id = '15100000-0000-0000-0000-0000000000a2'), 0,
  'AUTH: another human''s enrollment is invisible');

select throws_ok(
  $$update public.totp_enrollments set auth_user_id = '15100000-0000-0000-0000-0000000000a2'
     where id = '15100000-0000-0000-0000-0000000000e1'$$,
  '42501', 'new row violates row-level security policy for table "totp_enrollments"',
  'AUTH: an enrollment cannot be handed to another human');

update public.totp_enrollments set is_active = false, enrolled_at = '2001-01-01'
 where id = '15100000-0000-0000-0000-0000000000e2';
reset role;
select is((select is_active::text || '/' || enrolled_at::date::text from public.totp_enrollments
            where id = '15100000-0000-0000-0000-0000000000e2'),
  'true/2026-01-01', 'AUTH: another human''s enrollment cannot be revoked or backdated');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"15100000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok($$delete from public.totp_enrollments where id = '15100000-0000-0000-0000-0000000000e1'$$,
  '42501', 'permission denied for table totp_enrollments', 'DOOR: an enrollment cannot be deleted by its subject');
reset role;

set local role anon;
select throws_ok($$select count(*) from public.totp_enrollments$$,
  '42501', 'permission denied for table totp_enrollments', 'AUTH: anon cannot reach the table at all');
reset role;

-- ================================================================================================
-- 12. The condition that keeps 1-11 benign: nothing reads the table. (75_... pins owner_only's
--     USING and WITH CHECK; a second policy is caught by 7 or 11.)
-- ================================================================================================
select is(pg_temp.totp_mentions(), '',
  'TRIPWIRE: no function, view, other policy or trigger names totp_enrollments; AUTH-1 retires the table before the first one does');

-- ================================================================================================
-- 13-16. Mutation: wire the record into step-up, the realistic regression. The plant then satisfies
--        step-up at aal1 and the tripwire names the reader; after rollback the gate is byte-identical.
-- ================================================================================================
savepoint m1;
create or replace function app.mfa_satisfied() returns boolean language sql stable security definer set search_path = '' as $f$
    select (not app.requires_mfa())
        or coalesce((select auth.jwt() ->> 'aal'), 'aal1') = 'aal2'
        or exists (select 1 from public.totp_enrollments e where e.auth_user_id = (select auth.uid()) and e.is_active);
$f$;
select isnt((select md5(pg_get_functiondef('app.mfa_satisfied()'::regprocedure))), (select v from s151 where k = 'mfa_def'),
  'MUTANT installed: app.mfa_satisfied also accepts an active totp_enrollments row');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"15100000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
update public.totp_enrollments set is_active = true, revoked_at = null where id = '15100000-0000-0000-0000-0000000000e1';
select ok(app.mfa_satisfied(), 'MUTANT: wired as a gate, the backdated plant satisfies step-up at aal1');
reset role;
select is(pg_temp.totp_mentions(), 'function:app.mfa_satisfied', 'MUTANT: the tripwire names the new reader');
rollback to savepoint m1;

select is((select md5(pg_get_functiondef('app.mfa_satisfied()'::regprocedure))), (select v from s151 where k = 'mfa_def'),
  'RESTORED: app.mfa_satisfied is byte-identical to its installed definition');

select * from finish();
rollback;
