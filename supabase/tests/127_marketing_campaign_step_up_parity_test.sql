-- ATTACK-CLASSES: AUTH DOOR PRIVILEGE STATE TENANT=N/A INPUT=N/A BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
-- SPEC-222 / CAMP-3. A direct write to `marketing_campaigns` costs MANAGE_MARKETING_CAMPAIGN WITH
-- step-up, exactly as the campaign RPCs charge it. The owner holds the permission, so every aal1
-- refusal below is a step-up refusal and is pinned to its message; UPDATE attacks change only
-- non-status columns, so `app.enforce_status_transition` (which raises the same text) cannot be the
-- authority that refused. The non-holder's refusal is pinned to the guard's own message, which RLS
-- cannot produce. The mutation disables only the new attachment, proves the password-only writes
-- land, re-enables it and proves the guard function is byte-identical throughout.
-- OBSERVABILITY=N/A: campaign event parity is CAMP-4, separately open; assertions 22-23 pin it and
-- ENTRY-1 as still OPEN so this file can never be read as having fixed either.
create extension if not exists pgtap with schema extensions;

begin;
select plan(29);

insert into auth.users (id,email,email_confirmed_at) values
  ('12700000-0000-0000-0000-0000000000a1','owner@camp127.test',now()),
  ('12700000-0000-0000-0000-0000000000a2','employee@camp127.test',now());
insert into public.tenants (id,name,slug,status) values
  ('12700000-0000-0000-0000-000000000001','CAMP127 Travel','camp127-travel','active');
insert into public.subscriptions (tenant_id,subscription_plan_id,subscription_status_code)
select '12700000-0000-0000-0000-000000000001',id,'active'
from public.subscription_plans where plan_code='enterprise';
insert into public.branches (id,tenant_id,name,slug) values
  ('12700000-0000-0000-0000-00000000000a','12700000-0000-0000-0000-000000000001','Main','camp127-main');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('12700000-0000-0000-0000-000000000011','12700000-0000-0000-0000-000000000001','Owner','owner@camp127.test',true,'12700000-0000-0000-0000-0000000000a1'),
  ('12700000-0000-0000-0000-000000000012','12700000-0000-0000-0000-000000000001','Employee','employee@camp127.test',true,'12700000-0000-0000-0000-0000000000a2');
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '12700000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('12700000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('12700000-0000-0000-0000-000000000012'::uuid,'employee')) v(u,rc)
join public.roles r on r.code = v.rc;
-- The campaign under attack, written on the platform path.
insert into public.marketing_campaigns (id,tenant_id,platform_code,campaign_name,external_campaign_id,status_code) values
  ('12700000-0000-0000-0000-0000000000c1','12700000-0000-0000-0000-000000000001','google_ads','Umrah','G-100','active');

create temp table s127 (k text primary key, v text) on commit drop;
grant all on s127 to authenticated;

-- 1. The attachment.
select is(
  (select t.tgtype::int || '/' || t.tgenabled::text || '/' || t.tgfoid::regproc::text
     from pg_trigger t where t.tgrelid = 'public.marketing_campaigns'::regclass
      and t.tgname = 'marketing_campaigns_guard_write_capability'),
  '23/O/app.guard_write_capability',
  'the guard is attached BEFORE INSERT OR UPDATE FOR EACH ROW, enabled, on app.guard_write_capability');

-- ================================================================================================
-- 2-9. Owner at aal1: holds the permission, lacks the step-up.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12700000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);

select ok(app.has_permission('MANAGE_MARKETING_CAMPAIGN'), 'CONTROL: the aal1 owner holds MANAGE_MARKETING_CAMPAIGN');
select ok(not app.mfa_satisfied(), 'CONTROL: the aal1 owner has not satisfied step-up');
select is((select count(*)::int from public.marketing_campaigns where id='12700000-0000-0000-0000-0000000000c1'), 1,
  'CONTROL: the aal1 owner can see the campaign under attack');

select throws_ok(
  $$select app.create_marketing_campaign('Via RPC','google_ads','G-200')$$,
  '42501','multi-factor authentication required for this role',
  'the RPC door refuses the aal1 owner -- the cost the table door must match');

select throws_ok(
  $$insert into public.marketing_campaigns (tenant_id,platform_code,campaign_name,external_campaign_id,status_code)
    values ('12700000-0000-0000-0000-000000000001','google_ads','Squat','G-777','ended')$$,
  '42501','multi-factor authentication required for this role',
  'CAMP-3: the aal1 owner cannot INSERT a campaign through the table');

select throws_ok(
  $$update public.marketing_campaigns set platform_code='meta_ads', external_campaign_id='M-1', campaign_name='Hijacked'
    where id='12700000-0000-0000-0000-0000000000c1'$$,
  '42501','multi-factor authentication required for this role',
  'CAMP-3: the aal1 owner cannot rewrite a campaign''s platform identity through the table');

reset role;
select is(
  (select array[platform_code, external_campaign_id, campaign_name, status_code]
     from public.marketing_campaigns where id='12700000-0000-0000-0000-0000000000c1'),
  array['google_ads','G-100','Umrah','active'],
  '...and the refused rewrite left the campaign exactly as it was');
select is(
  (select count(*)::int from public.marketing_campaigns where tenant_id='12700000-0000-0000-0000-000000000001'), 1,
  '...and the refused INSERT left the tenant with its one campaign');

-- ================================================================================================
-- 10-11. A non-holder is refused by the guard itself, not by RLS.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12700000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select ok(not app.has_permission('MANAGE_MARKETING_CAMPAIGN'), 'CONTROL: the employee does not hold MANAGE_MARKETING_CAMPAIGN');
select throws_ok(
  $$insert into public.marketing_campaigns (tenant_id,platform_code,campaign_name,status_code)
    values ('12700000-0000-0000-0000-000000000001','google_ads','Employee','draft')$$,
  '42501','permission denied: one of MANAGE_MARKETING_CAMPAIGN is required to write marketing_campaigns',
  'a non-holder is refused by the write-capability guard''s own message');

-- ================================================================================================
-- 12-20. Owner at aal2: every legitimate door still opens; status authority is unchanged.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"12700000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);

select lives_ok(
  $$insert into public.marketing_campaigns (tenant_id,platform_code,campaign_name,external_campaign_id,status_code)
    values ('12700000-0000-0000-0000-000000000001','google_ads','Direct','G-300','draft')$$,
  'the aal2 owner can still INSERT a campaign through the table');
select lives_ok(
  $$update public.marketing_campaigns set campaign_name='Umrah Ramadan' where id='12700000-0000-0000-0000-0000000000c1'$$,
  'the aal2 owner can still edit a campaign through the table');
select is((select campaign_name from public.marketing_campaigns where id='12700000-0000-0000-0000-0000000000c1'),
  'Umrah Ramadan', '...and the edit landed');

select lives_ok(
  $$insert into s127 values ('rpc', app.create_marketing_campaign('Via RPC','google_ads','G-400')::text)$$,
  'the aal2 owner can still create a campaign through the RPC');
select lives_ok(
  $$select app.advance_marketing_campaign((select v::uuid from s127 where k='rpc'),'active','go live')$$,
  'the aal2 owner can still advance a campaign through the RPC');
select is((select status_code from public.marketing_campaigns where id=(select v::uuid from s127 where k='rpc')),
  'active', '...and the RPC advance landed');

select throws_ok(
  $$update public.marketing_campaigns set status_code='draft' where id='12700000-0000-0000-0000-0000000000c1'$$,
  '23514', null,
  'status authority unchanged: a transition canon 26 does not define is still refused by the state machine');
select lives_ok(
  $$update public.marketing_campaigns set status_code='paused' where id='12700000-0000-0000-0000-0000000000c1'$$,
  'status authority unchanged: a defined transition by the aal2 holder still lands');

select set_config('request.jwt.claims','{"sub":"12700000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
select throws_ok(
  $$update public.marketing_campaigns set status_code='active' where id='12700000-0000-0000-0000-0000000000c1'$$,
  '42501','multi-factor authentication required for this role',
  'status authority unchanged: a defined transition still costs step-up at aal1');

-- ================================================================================================
-- 21. The platform path is outside per-table enforcement.
-- ================================================================================================
reset role;
select set_config('request.jwt.claims','',true);
select lives_ok(
  $$insert into public.marketing_campaigns (tenant_id,platform_code,campaign_name,status_code)
    values ('12700000-0000-0000-0000-000000000001','google_ads','Platform','draft')$$,
  'a session-less (platform) INSERT still lands');

-- ================================================================================================
-- 22-23. OBSERVED AND STILL OPEN -- pinned so this file cannot be read as having fixed them.
-- A repair of ENTRY-1 or CAMP-4 is expected to update these two assertions.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12700000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok(
  $$insert into public.marketing_campaigns (id,tenant_id,platform_code,campaign_name,status_code)
    values ('12700000-0000-0000-0000-0000000000c2','12700000-0000-0000-0000-000000000001','google_ads','Born ended','ended')$$,
  'ENTRY-1 STILL OPEN: an aal2 holder can INSERT a campaign born in a late state');
reset role;
select is((select count(*)::int from public.events where entity_id='12700000-0000-0000-0000-0000000000c2'), 0,
  'CAMP-4 STILL OPEN: a direct campaign INSERT records no event');

-- ================================================================================================
-- 24-29. MUTATION: remove only the new attachment, prove it was load-bearing, restore it.
-- ================================================================================================
insert into s127 select 'md5', md5(pg_get_functiondef('app.guard_write_capability()'::regprocedure));
alter table public.marketing_campaigns disable trigger marketing_campaigns_guard_write_capability;
select is((select tgenabled::text from pg_trigger where tgname='marketing_campaigns_guard_write_capability'), 'D',
  'MUTANT INSTALLED: the new attachment is disabled');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12700000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
select lives_ok(
  $$insert into public.marketing_campaigns (tenant_id,platform_code,campaign_name,external_campaign_id,status_code)
    values ('12700000-0000-0000-0000-000000000001','google_ads','Squat','G-777','ended')$$,
  'MUTANT: without the attachment the aal1 owner''s INSERT lands -- the attachment is load-bearing');
select lives_ok(
  $$update public.marketing_campaigns set platform_code='meta_ads', external_campaign_id='M-1', campaign_name='Hijacked'
    where id='12700000-0000-0000-0000-0000000000c1'$$,
  'MUTANT: without the attachment the aal1 owner''s identity rewrite lands');

reset role;
alter table public.marketing_campaigns enable trigger marketing_campaigns_guard_write_capability;
select is((select tgenabled::text from pg_trigger where tgname='marketing_campaigns_guard_write_capability'), 'O',
  'RESTORED: the attachment is enabled again');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"12700000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
select throws_ok(
  $$insert into public.marketing_campaigns (tenant_id,platform_code,campaign_name,external_campaign_id,status_code)
    values ('12700000-0000-0000-0000-000000000001','google_ads','Squat again','G-778','ended')$$,
  '42501','multi-factor authentication required for this role',
  'RESTORED: the same aal1 INSERT is refused again');

reset role;
select is(md5(pg_get_functiondef('app.guard_write_capability()'::regprocedure)), (select v from s127 where k='md5'),
  'the guard function is byte-identical before and after the mutation');

select finish();
rollback;
