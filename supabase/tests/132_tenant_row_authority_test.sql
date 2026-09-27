-- ATTACK-CLASSES: AUTH TENANT DOOR PRIVILEGE STATE=N/A INPUT=N/A BUSINESS=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
-- SPEC-228 / Batch 6 Slice 26. `tenants` is audited and clean: no finding, no repair. This file pins
-- only the long-lived controls that keep the tenant row the root of isolation, each by its own
-- message: a signed-in owner sees only its own tenant, cannot create a tenant (provisioning is
-- `app.provision_tenant`, `service_role` only), cannot move its tenant's id, cannot change another
-- tenant's row and cannot delete one; `anon` has no grant at all. The creation refusal has exactly
-- one refuser, the tenant conjunct of `scope_insert`, so that conjunct is removed inside a savepoint
-- and the same creation is shown to land, then restored byte for byte.
-- Deliberately NOT pinned, in either direction: an `aal1` owner's edit of the tenant row (the
-- `tenants` member of STEPUP-1, recorded UNPROVEN with no material consequence, so it is neither a
-- desired invariant nor an OPEN defect), a lapsed tenant's edit of its own row, the global slug and a
-- caller-supplied `created_at` (SPEC-216's schema-wide question). The employee's refused rename is
-- `22_...`'s; the write-once trial stamp and the account-level `status` vocabulary are `42_...`'s.
-- STATE=N/A: `tenants.status` has no reader and no transition; the commercial lifecycle is `subscriptions`.
-- INPUT=N/A: status vocabulary and trial stamp are pinned in `42_...`; nothing reads slug, contact or currency.
-- BUSINESS=N/A: no function, view or policy reads a tenant column except `name` for display.
-- CONCURRENCY=N/A: no counter, allocator or lock lives on this surface.
-- REPLAY=N/A: no token, idempotency key or one-time value lives on this surface.
-- OBSERVABILITY=N/A: canon 27 defines no tenant-settings event, so there is no record to compare.
create extension if not exists pgtap with schema extensions;

begin;
select plan(13);

insert into auth.users (id,email,email_confirmed_at) values
  ('13200000-0000-0000-0000-0000000000a1','owner@tn132.test',now()),
  ('13200000-0000-0000-0000-0000000000b1','owner@tn132b.test',now());
insert into public.tenants (id,name,slug,status) values
  ('13200000-0000-0000-0000-000000000001','TN132 Travel','tn132-travel','active'),
  ('13200000-0000-0000-0000-000000000002','TN132 Other','tn132-other','active');
insert into public.users (id,tenant_id,full_name,email,is_active,auth_user_id) values
  ('13200000-0000-0000-0000-000000000011','13200000-0000-0000-0000-000000000001','Owner','owner@tn132.test',true,'13200000-0000-0000-0000-0000000000a1'),
  ('13200000-0000-0000-0000-000000000021','13200000-0000-0000-0000-000000000002','Owner B','owner@tn132b.test',true,'13200000-0000-0000-0000-0000000000b1');
insert into public.user_role_assignments (tenant_id,user_id,role_id,scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('13200000-0000-0000-0000-000000000001'::uuid,'13200000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('13200000-0000-0000-0000-000000000002'::uuid,'13200000-0000-0000-0000-000000000021'::uuid,'owner')) v(t,u,rc)
join public.roles r on r.code = v.rc;

create temp table s132 (k text primary key, v text) on commit drop;
insert into s132 values
  ('policy_insert', (select md5(coalesce(with_check,'')) from pg_policies
                      where schemaname='public' and tablename='tenants' and policyname='scope_insert'));

-- ================================================================================================
-- 1-3. The population: the owner at aal2 holds MANAGE_TENANT_SETTINGS, sees exactly its own tenant,
--      and can edit it, so every refusal below is the control and not a dead session.
-- ================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13200000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select ok(app.has_permission('MANAGE_TENANT_SETTINGS'), 'CONTROL: the owner holds MANAGE_TENANT_SETTINGS');
select is((select array_agg(id::text) from public.tenants), array['13200000-0000-0000-0000-000000000001'],
  'TENANT: the owner sees exactly its own tenant row');
select lives_ok(
  $$update public.tenants set legal_name='TN132 Travel LLC' where id='13200000-0000-0000-0000-000000000001'$$,
  'CONTROL: the owner edits its own tenant row');

-- ================================================================================================
-- 4-7. The door refuses what only provisioning may do, and the tenant boundary holds.
-- ================================================================================================
select throws_ok(
  $$insert into public.tenants (name,slug,status) values ('Spawned','tn132-spawn','active')$$,
  '42501','new row violates row-level security policy for table "tenants"',
  'DOOR: a signed-in owner cannot create a tenant; provisioning is platform-only');
select throws_ok(
  $$update public.tenants set id='13200000-0000-0000-0000-0000000000ff'
    where id='13200000-0000-0000-0000-000000000001'$$,
  '42501','new row violates row-level security policy for table "tenants"',
  'TENANT: the owner cannot move its tenant row to another id');
select throws_ok(
  $$delete from public.tenants where id='13200000-0000-0000-0000-000000000001'$$,
  '42501','permission denied for table tenants',
  'PRIVILEGE: no authenticated DELETE grant exists on tenants');
update public.tenants set name='Seized' where id='13200000-0000-0000-0000-000000000002';
reset role;
select is((select name from public.tenants where id='13200000-0000-0000-0000-000000000002'), 'TN132 Other',
  'TENANT: the owner''s UPDATE of another tenant''s row changed nothing');

-- ================================================================================================
-- 8. AUTH: anon holds no grant on tenants.
-- ================================================================================================
set local role anon;
select set_config('request.jwt.claims','{"role":"anon"}',true);
select throws_ok(
  $$select count(*) from public.tenants$$,
  '42501','permission denied for table tenants',
  'AUTH: anon cannot read the tenant directory');
reset role;

-- ================================================================================================
-- 9. Nothing was created or moved.
-- ================================================================================================
select is(
  (select array[count(*) filter (where slug='tn132-spawn'),
                count(*) filter (where id in ('13200000-0000-0000-0000-000000000001','13200000-0000-0000-0000-000000000002'))]::int[]
     from public.tenants),
  array[0,2],
  'no tenant was created and neither tenant row moved');

-- ================================================================================================
-- 10-13. Mutation: the tenant conjunct of `scope_insert` is the only refuser of tenant creation.
--        Remove it inside a savepoint, prove the installed expression changed, prove the creation
--        lands, then roll back and prove the original expression is back byte for byte.
-- ================================================================================================
savepoint m1;
alter policy scope_insert on public.tenants
  with check ((select app.has_permission('MANAGE_TENANT_SETTINGS')));
select isnt((select md5(with_check) from pg_policies where schemaname='public' and tablename='tenants' and policyname='scope_insert'),
  (select v from s132 where k='policy_insert'), 'MUTANT installed: scope_insert without the tenant conjunct');
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"13200000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok(
  $$insert into public.tenants (name,slug,status) values ('Spawned','tn132-spawn','active')$$,
  'MUTANT: the owner creates a tenant, so the tenant conjunct is what refused it');
reset role;
rollback to savepoint m1;

select is((select md5(coalesce(with_check,'')) from pg_policies where schemaname='public' and tablename='tenants' and policyname='scope_insert'),
  (select v from s132 where k='policy_insert'), 'RESTORED: scope_insert is byte-identical to its installed expression');
select is((select count(*)::int from public.tenants where slug='tn132-spawn'), 0,
  'RESTORED: no mutant write survived the rollback');

select * from finish();
rollback;
