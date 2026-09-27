-- ATTACK-CLASSES: TENANT PRIVILEGE DOOR AUTH=N/A STATE=N/A INPUT=N/A BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
-- SPEC-229 / Batch 6 Slice 27. `security_events` is audited and clean: no finding, no repair. This file
-- pins only the long-lived controls that make the security log readable by the right people and
-- rewritable by no one. A tenant-wide reader sees its own tenant's events and neither another
-- tenant's nor a platform-level (`tenant_id` null) event; an ordinary employee of the same tenant sees
-- none (202607052200 restricts this log to tenant-wide readers outright). Each read conjunct is the
-- only refuser of its leak, so each is removed inside a savepoint and the leak is shown, then both are
-- restored byte for byte. The reader who can see an event cannot rewrite or delete it (no grant), and
-- even the table owner cannot (`app.forbid_mutation`), which is the only control left for a role that
-- holds the grants and bypasses RLS, as `service_role` does on Primary (PAR-5).
-- Deliberately NOT pinned here: the forged INSERT (`34_...`), the grant model (`10_...`), the trigger's
-- existence (`02_...`) and the producers' emissions (`43_...`). An `aal1` reader is not pinned in either
-- direction: no policy in the schema charges step-up on a read, so it is not this surface's question.
-- AUTH=N/A: `anon` holds no grant on any public table (`10_...`); reads are permission-gated schema-wide.
-- STATE=N/A: an append-only log has no status and no transition.
-- INPUT=N/A: `authenticated` holds no write; the four producers take their inputs from their own RPCs.
-- BUSINESS=N/A: no function, view, policy or trigger reads `security_events`.
-- CONCURRENCY=N/A: the concurrent double redemption (LIC-2) lives on `tenant_license_activations`.
-- REPLAY=N/A: the single-use token lives on `tenant_license_activations` (`43_...`).
-- OBSERVABILITY=N/A: what is emitted, and that no token plaintext is, is `43_...`'s; auth events are AUTH-1's.
create extension if not exists pgtap with schema extensions;

begin;
select plan(14);

insert into auth.users (id,email,email_confirmed_at) values
  ('13300000-0000-0000-0000-0000000000a1','owner@se133.test',now()),
  ('13300000-0000-0000-0000-0000000000a2','employee@se133.test',now());
insert into public.tenants (id,name,slug,status) values
  ('13300000-0000-0000-0000-000000000001','SE133 Travel','se133-travel','active'),
  ('13300000-0000-0000-0000-000000000002','SE133 Other','se133-other','active');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('13300000-0000-0000-0000-000000000011','13300000-0000-0000-0000-000000000001','Owner','owner@se133.test',true,'13300000-0000-0000-0000-0000000000a1'),
  ('13300000-0000-0000-0000-000000000012','13300000-0000-0000-0000-000000000001','Employee','employee@se133.test',true,'13300000-0000-0000-0000-0000000000a2');
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select '13300000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('13300000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('13300000-0000-0000-0000-000000000012'::uuid,'employee')) v(u,rc)
join public.roles r on r.code = v.rc;
insert into public.security_events (id,tenant_id,user_id,security_event_type_code,payload) values
  ('13300000-0000-0000-0000-00000000e001','13300000-0000-0000-0000-000000000001','13300000-0000-0000-0000-000000000011','license_token_redeemed','{"plan_code":"se133"}'),
  ('13300000-0000-0000-0000-00000000e002','13300000-0000-0000-0000-000000000002',null,'license_token_issued','{"plan_code":"se133"}'),
  ('13300000-0000-0000-0000-00000000e003',null,null,'license_token_revoked','{"plan_code":"se133"}');

create temp table s133 (k text primary key, v text) on commit drop;
insert into s133 values
  ('policy_read', (select md5(coalesce(qual,'')) from pg_policies
                    where schemaname='public' and tablename='security_events' and policyname='audit_read'));

-- ================================================================================================
-- 1-4. The population: the owner is a tenant-wide reader and sees exactly its own tenant's event; the
--      employee is a live member of the same tenant and sees none.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13300000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select ok(app.has_tenant_wide_read(), 'CONTROL: the owner is a tenant-wide reader');
select is((select array_agg(id::text order by id) from public.security_events where id::text like '13300000-%'),
  array['13300000-0000-0000-0000-00000000e001'],
  'TENANT: the owner sees its own tenant''s event, and neither another tenant''s nor a platform event');
select set_config('request.jwt.claims','{"sub":"13300000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select is(app.current_tenant_id(), '13300000-0000-0000-0000-000000000001'::uuid,
  'CONTROL: the employee is a live member of the same tenant');
select is((select count(*)::int from public.security_events where id::text like '13300000-%'), 0,
  'PRIVILEGE: an ordinary employee cannot browse the tenant''s security log');

-- ================================================================================================
-- 5-9. No door rewrites the log: not the reader who can see the event, and not the table owner.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"13300000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok(
  $$update public.security_events set payload='{}' where id='13300000-0000-0000-0000-00000000e001'$$,
  '42501','permission denied for table security_events',
  'DOOR: the reader who can see an event cannot rewrite it');
select throws_ok(
  $$delete from public.security_events where id='13300000-0000-0000-0000-00000000e001'$$,
  '42501','permission denied for table security_events',
  'DOOR: the reader who can see an event cannot delete it');
reset role;
select throws_ok(
  $$update public.security_events set payload='{}' where id='13300000-0000-0000-0000-00000000e001'$$,
  'P0001','append-only table: UPDATE is not permitted on security_events',
  'DOOR: even a role holding the grant and bypassing RLS cannot rewrite an event');
select throws_ok(
  $$delete from public.security_events where id='13300000-0000-0000-0000-00000000e001'$$,
  'P0001','append-only table: DELETE is not permitted on security_events',
  'DOOR: even a role holding the grant and bypassing RLS cannot delete an event');
select is(
  (select array[count(*)::int, count(*) filter (where payload = '{"plan_code":"se133"}')::int]
     from public.security_events where id::text like '13300000-%'),
  array[3,3],
  'all three events survive unchanged');

-- ================================================================================================
-- 10-14. Mutation: each read conjunct is the only refuser of its leak. Remove one inside a savepoint,
--        prove the installed expression changed and the leak appears, roll back; then the other; then
--        prove the original expression is back byte for byte.
-- ================================================================================================
savepoint m1;
alter policy audit_read on public.security_events using (tenant_id = (select app.current_tenant_id()));
select isnt((select md5(qual) from pg_policies where schemaname='public' and tablename='security_events' and policyname='audit_read'),
  (select v from s133 where k='policy_read'), 'MUTANT installed: audit_read without the tenant-wide-reader conjunct');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13300000-0000-0000-0000-0000000000a2","aal":"aal2"}',true);
select is((select count(*)::int from public.security_events where id::text like '13300000-%'), 1,
  'MUTANT: the employee reads the security log, so the tenant-wide-reader conjunct is what refused it');
reset role;
rollback to savepoint m1;

savepoint m2;
alter policy audit_read on public.security_events using ((select app.has_tenant_wide_read()));
select isnt((select md5(qual) from pg_policies where schemaname='public' and tablename='security_events' and policyname='audit_read'),
  (select v from s133 where k='policy_read'), 'MUTANT installed: audit_read without the tenant conjunct');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13300000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select is((select count(*)::int from public.security_events where id::text like '13300000-%'), 3,
  'MUTANT: the owner reads another tenant''s and the platform''s events, so the tenant conjunct is what refused them');
reset role;
rollback to savepoint m2;

select is((select md5(coalesce(qual,'')) from pg_policies where schemaname='public' and tablename='security_events' and policyname='audit_read'),
  (select v from s133 where k='policy_read'), 'RESTORED: audit_read is byte-identical to its installed expression');

select * from finish();
rollback;
