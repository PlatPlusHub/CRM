-- pgTAP: FX-1 / FX-2 (`202607058800`) and FX-3 / FX-4 (`202607058900`) -- the first bounded slice of
-- the Batch-6 table-by-table audit: the accounting core and the actor-attribution class.
--
-- ASSERTION 22 IS THE ONE THAT MATTERS IN A YEAR. It asks the SCHEMA, not a hand-written list,
-- whether any actor column is accepted from the caller instead of derived. That is not a stylistic
-- preference -- it is how this package's own findings were nearly missed. A sweep using the list
-- ('created_by','set_by','uploaded_by','recorded_by','issued_by') reported ONE gap and looked
-- finished; adding `assigned_by` produced FX-3, and widening again to `reviewed_by` produced FX-4.
-- A detector's blind spot is indistinguishable from a clean result, so the detector became the test.
-- It is written with NO exemption list, deliberately: an exemption list is where the next gap hides.
--
-- Where RLS decides the outcome the file switches to `authenticated`: as `postgres` the policies do
-- not apply and every refusal below would silently pass.
create extension if not exists pgtap with schema extensions;

begin;
select plan(22);

insert into auth.users (id, email) values
  ('83000000-0000-0000-0000-0000000000a1','own@f83.example'),
  ('83000000-0000-0000-0000-0000000000a2','emp@f83.example'),
  ('83000000-0000-0000-0000-0000000000a3','fin@f83.example');
insert into public.tenants (id, name, slug, status) values
  ('83000000-0000-0000-0000-000000000001','F83 Travel','f83-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '83000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('83000000-0000-0000-0000-00000000000a','83000000-0000-0000-0000-000000000001','Main','f83-main');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('83000000-0000-0000-0000-000000000011','83000000-0000-0000-0000-000000000001','Owner','own@f83.example',true,'83000000-0000-0000-0000-0000000000a1'),
  ('83000000-0000-0000-0000-000000000021','83000000-0000-0000-0000-000000000001','Employee','emp@f83.example',true,'83000000-0000-0000-0000-0000000000a2'),
  ('83000000-0000-0000-0000-000000000031','83000000-0000-0000-0000-000000000001','Finance','fin@f83.example',true,'83000000-0000-0000-0000-0000000000a3');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '83000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('83000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('83000000-0000-0000-0000-000000000021'::uuid,'employee'),
             ('83000000-0000-0000-0000-000000000031'::uuid,'finance_manager')) v(u,code)
join public.roles r on r.code = v.code;
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, is_primary)
select '83000000-0000-0000-0000-000000000001', u, '83000000-0000-0000-0000-00000000000a', true
from unnest(array['83000000-0000-0000-0000-000000000011'::uuid,'83000000-0000-0000-0000-000000000021',
                  '83000000-0000-0000-0000-000000000031']) u;

-- ================================================================================================
-- FX-1 / FX-2 -- exchange_rates. The caller genuinely holds SET_EXCHANGE_RATE throughout, so every
-- refusal below is the integrity rule and never the permission.
-- ================================================================================================
select set_config('request.jwt.claims','{"sub":"83000000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
set local role authenticated;

select ok(app.has_permission('SET_EXCHANGE_RATE'),
  'POSITIVE CONTROL: the finance_manager genuinely holds SET_EXCHANGE_RATE');

select lives_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('83000000-0000-0000-0000-000000000001','USD','EGP', 48.5, '2026-08-31T09:00:00Z')$$,
  'POSITIVE CONTROL: a legitimate positive rate still inserts -- the guards do not block real work');

select throws_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('83000000-0000-0000-0000-000000000001','USD','EGP', -48.5, '2026-08-31T10:00:00Z')$$,
  '23514', null,
  'FX-1: a NEGATIVE exchange rate is refused -- before 202607058800 this returned INSERT 0 1');

select throws_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('83000000-0000-0000-0000-000000000001','USD','EGP', 0, '2026-08-31T11:00:00Z')$$,
  '23514', null,
  'FX-1b: and so is a ZERO rate -- strictly > 0, because a zero rate values every foreign amount at nothing');

select is(
  (select set_by from public.exchange_rates where effective_at = '2026-08-31T09:00:00Z'),
  '83000000-0000-0000-0000-000000000031'::uuid,
  'FX-2b: `set_by` was omitted by the caller and DERIVED from the session -- before the fix it stayed NULL');

select lives_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at, set_by)
    values ('83000000-0000-0000-0000-000000000001','USD','EGP', 49.0, '2026-08-31T12:00:00Z',
            '83000000-0000-0000-0000-000000000021')$$,
  'a rate naming SOMEONE ELSE as its setter still inserts -- the guard derives rather than raises');

select is(
  (select set_by from public.exchange_rates where effective_at = '2026-08-31T12:00:00Z'),
  '83000000-0000-0000-0000-000000000031'::uuid,
  'FX-2: ...and the FORGED setter is discarded: the row records the finance_manager who actually set it, not the employee the caller named');

select lives_ok(
  $$update public.exchange_rates set set_by = '83000000-0000-0000-0000-000000000021'
    where effective_at = '2026-08-31T09:00:00Z'$$,
  'an UPDATE attempting to rewrite the setter is accepted...');

select is(
  (select set_by from public.exchange_rates where effective_at = '2026-08-31T09:00:00Z'),
  '83000000-0000-0000-0000-000000000031'::uuid,
  '...and changes nothing: attribution is frozen once written');

reset role;
select set_config('request.jwt.claims','{"sub":"83000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;
select throws_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('83000000-0000-0000-0000-000000000001','USD','EGP', 99, '2026-08-31T13:00:00Z')$$,
  '42501', null,
  'NEGATIVE CONTROL: an ordinary employee still cannot set a rate at all -- SPEC-138 authorization is untouched, and these were integrity defects, not authorization ones');

-- ================================================================================================
-- FX-3 -- the RBAC grant trail. The RPC already derived the actor; the table did not.
-- ================================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"83000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
set local role authenticated;

select ok(app.has_permission('MANAGE_USERS'),
  'POSITIVE CONTROL: the owner genuinely holds MANAGE_USERS, so the grants below are authorized work');

select lives_ok(
  $$select app.assign_user_role('83000000-0000-0000-0000-000000000021'::uuid,'branch_manager','tenant',null,null)$$,
  'POSITIVE CONTROL: the RPC path grants a role');

select is(
  (select assigned_by from public.user_role_assignments
    where user_id = '83000000-0000-0000-0000-000000000021'
      and role_id = (select id from public.roles where code='branch_manager')),
  '83000000-0000-0000-0000-000000000011'::uuid,
  '...attributing it to the OWNER who called it -- this is the behaviour the table door had to match');

select lives_ok(
  $$insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type, assigned_by)
    select '83000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000021', id,'tenant',
           '83000000-0000-0000-0000-000000000021' from public.roles where code='finance_manager'$$,
  'a direct INSERT naming the PROMOTED USER as the granter still inserts...');

select is(
  (select assigned_by from public.user_role_assignments
    where user_id = '83000000-0000-0000-0000-000000000021'
      and role_id = (select id from public.roles where code='finance_manager')),
  '83000000-0000-0000-0000-000000000011'::uuid,
  'FX-3: ...and the forged granter is discarded -- before 202607058900 the privilege trail said the manager had promoted themselves');

select lives_ok(
  $$insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
    select '83000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000021', id,'tenant'
    from public.roles where code='senior_employee'$$,
  'a direct INSERT omitting the granter entirely still inserts...');

select is(
  (select assigned_by from public.user_role_assignments
    where user_id = '83000000-0000-0000-0000-000000000021'
      and role_id = (select id from public.roles where code='senior_employee')),
  '83000000-0000-0000-0000-000000000011'::uuid,
  'FX-3b: ...and is attributed to the caller -- before the fix a role grant could name nobody at all');

reset role;
select set_config('request.jwt.claims','{"sub":"83000000-0000-0000-0000-0000000000a2"}',true);
set local role authenticated;
select throws_ok(
  $$insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
    select '83000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000021', id,'tenant'
    from public.roles where code='owner'$$,
  '42501', null,
  'NEGATIVE CONTROL: an ordinary employee still cannot grant themselves any role -- SPEC-138''s MANAGE_USERS gate is what stops that, and it is unchanged');
reset role;

-- The session-less path, which is not an exemption of convenience: `app.provision_tenant` inserts
-- the founding owner's assignment as service_role with no session, and WP-00 requires the actor to
-- be NULL there rather than invented.
select set_config('request.jwt.claims', null, true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '83000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000031', id,'tenant'
from public.roles where code='department_manager';
select is(
  (select assigned_by from public.user_role_assignments
    where user_id = '83000000-0000-0000-0000-000000000031'
      and role_id = (select id from public.roles where code='department_manager')),
  null,
  'SESSION-LESS: a write with no session keeps a NULL granter rather than inventing one -- the provisioning path depends on this');

-- ================================================================================================
-- Mutation. Deliberately NOT last: pgTAP's counter lives in a temp table, so an assertion inside a
-- rolled-back savepoint is not counted (TEST-3).
-- ================================================================================================
savepoint m1;
alter table public.exchange_rates drop constraint exchange_rates_rate_positive_check;
select lives_ok(
  $$insert into public.exchange_rates (tenant_id, from_currency_code, to_currency_code, rate, effective_at)
    values ('83000000-0000-0000-0000-000000000001','USD','EGP', -1, '2026-08-31T14:00:00Z')$$,
  'MUTATION: with the CHECK dropped a negative rate inserts again -- proving that constraint is the enforcer');
rollback to savepoint m1;

savepoint m2;
drop trigger user_role_assignments_derive_actor on public.user_role_assignments;
select set_config('request.jwt.claims','{"sub":"83000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type, assigned_by)
select '83000000-0000-0000-0000-000000000001','83000000-0000-0000-0000-000000000031', id,'tenant',
       '83000000-0000-0000-0000-000000000021' from public.roles where code='senior_employee';
select is(
  (select assigned_by from public.user_role_assignments
    where user_id = '83000000-0000-0000-0000-000000000031'
      and role_id = (select id from public.roles where code='senior_employee')),
  '83000000-0000-0000-0000-000000000021'::uuid,
  'MUTATION: with the trigger dropped the forged granter sticks -- proving that trigger is the enforcer');
rollback to savepoint m2;

-- ================================================================================================
-- The class guard. This is the assertion FX-3 would have needed to be found the first time.
-- ================================================================================================
select is(
  (select coalesce(string_agg(c.table_name || '.' || c.column_name, ', ' order by c.table_name, c.column_name), ''))::text,
  'booking_items.cancelled_by, booking_items.no_show_recorded_by, customer_identity_merges.merged_by, invoices.voided_by, journal_entries.voided_by, payments.received_by, payments.verified_by, tenant_license_activations.consumed_by',
  'CLASS GUARD (ATTR-2): the actor columns still ACCEPTED from the caller are exactly these eight, and no others. The predicate asks the SCHEMA for every column ending `_by` -- it no longer takes a hand-written list, because a list is how FX-3 and FX-4 were nearly missed: the first sweep enumerated five names, found one gap and looked finished. This is a PINNED INVENTORY, not an exemption list: it fails when the set changes in EITHER direction, so a new unattributed column fails it and each fix must delete its own line. Every entry is an open finding in MASTER_GAP_REGISTER.md under ATTR-2.')
from information_schema.columns c
join information_schema.tables tb
  on tb.table_schema = c.table_schema and tb.table_name = c.table_name and tb.table_type = 'BASE TABLE'
where c.table_schema = 'public'
  and c.column_name like '%\_by'
  and not exists (
      select 1 from pg_trigger t
      join pg_class cl on cl.oid = t.tgrelid
      join pg_namespace n on n.oid = cl.relnamespace
      join pg_proc p on p.oid = t.tgfoid
      where not t.tgisinternal and n.nspname = 'public'
        and cl.relname = c.table_name
        and (t.tgtype::int & 2) = 2
        and p.prosrc like '%new.' || c.column_name || ' :=%');

select * from finish();
rollback;
