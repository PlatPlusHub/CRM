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
select plan(23);

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
  'invoices.voided_by, journal_entries.voided_by, payments.verified_by, tenant_license_activations.consumed_by',
  'CLASS GUARD (ATTR-2): the columns ending `_by` still ACCEPTED from the caller are exactly these four, and no others. This is a PINNED INVENTORY, not an exemption list: it fails when the set changes in EITHER direction, so a new unattributed column fails it and each fix must delete its own line. Four of the original eight were closed by `202607059300`. The four that remain are NOT open work of the same kind, and the distinction matters: `invoices.voided_by` and `journal_entries.voided_by` are VOID-1, an OPEN OWNER DECISION -- voiding is unimplemented, so deriving an attribution for it would dress a missing capability as a solved one; `payments.verified_by` is VERIFY-1, the same shape with no VERIFY_PAYMENT permission in existence; and `tenant_license_activations` is granted to `postgres` and `service_role` ONLY, so no tenant caller can reach it by any door.')
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
        -- Regex, not `like '%new.<col> :=%'`. The `like` form was WHITESPACE-SENSITIVE, and the
        -- migration that closed four of these columns aligned its assignments with padding -- so
        -- the detector would have reported the fix as absent and the author would have "fixed" it
        -- by un-aligning the code. A guard that constrains formatting instead of behaviour is the
        -- MEAS-1 class; this asks for the assignment, at any spacing.
        and p.prosrc ~ ('new\.' || c.column_name || '\s*:='));

-- ================================================================================================
-- ASSERTION 23 -- THE PREDICATE ASSERTION 22 SHOULD ALWAYS HAVE USED.
--
-- Assertion 22 asks the schema rather than a hand-written list, which is why its header says a list
-- is where the next gap hides. It is still a NAME PATTERN: `%_by`. ATTR-2 found two actor columns it
-- cannot see -- `lead_interactions.user_id` (who made the call) and
-- `customers.first_registered_user_id` (who first took the customer on). Both were caller-supplied,
-- both were reproduced, and both are the FOURTH repetition of ASGN-2's lesson: `lead_assignments`
-- carried `created_by`'s meaning under a different name, and no name-shaped sweep could see it.
--
-- This predicate is STRUCTURAL instead of lexical: every FOREIGN KEY TO `public.users` on a table
-- `authenticated` can write directly, that no BEFORE trigger derives. It therefore catches an actor
-- column whatever it is called. The pinned set below is not "remaining work" -- it is a CLASSIFIED
-- inventory, and a new entry appearing in it means somebody must classify it, which is the whole
-- point. The families, all verified this pass:
--   * `*owner_user_id` / `*assigned_user_id` -- ASSIGNMENT TARGETS, not actors. These name somebody
--     OTHER than the caller by design; deriving them from the session would destroy the business
--     fact. Their actor half (`assigned_by`, `created_by`) is already derived.
--   * `*auth_user_id` -- IDENTITY BINDING, governed by `app.enforce_membership_identity_binding`
--     (IDENT-1/ADMIN-1) and by the authentication flows, not by attribution.
--   * `user_branch_assignments.user_id` / `user_role_assignments.user_id` /
--     `user_permission_grants.user_id` -- the SUBJECT of the assignment or grant. Again the actor
--     half (`created_by`, `assigned_by`) is derived already. `user_permission_grants` joined this
--     family with `202607059800` (RBAC-3) and is classified, not outstanding: the row names the
--     person the capability is granted to or denied from, which is precisely a target rather than an
--     actor, and its own `created_by` carries `app.derive_created_by()` exactly as its siblings do.
--   * `customers.last_interaction_user_id` -- DEAD-3: no writer anywhere in the database.
--   * `invoices.voided_by`, `journal_entries.voided_by`, `payments.verified_by` -- see assertion 22.
--   * `user_permission_grants.user_id` (RBAC-3, `202607059800`) -- classified as a SUBJECT column,
--     not an actor one: it names WHOSE capability is being granted, exactly as
--     `user_role_assignments.user_id` names whose role is being assigned, and both are
--     legitimately caller-supplied. The ACTOR on that table is `created_by`, which
--     `app.derive_created_by` derives and which therefore never reaches this list. Classified in
--     MASTER_GAP_REGISTER.md under RBAC-3 before this line was edited, per the rule below.
-- ================================================================================================
select is(
  (select coalesce(string_agg(distinct ac.tbl || '.' || ac.col, ', ' order by ac.tbl || '.' || ac.col), ''))::text,
  'booking_items.operational_owner_user_id, booking_items.owner_user_id, booking_items.sales_owner_user_id, bookings.owner_user_id, complaints.owner_user_id, conversations.owner_user_id, customers.last_interaction_user_id, invoices.voided_by, journal_entries.voided_by, lead_assignments.assigned_user_id, leads.assigned_user_id, leads.owner_user_id, otp_challenges.auth_user_id, payments.verified_by, quotations.owner_user_id, service_requests.owner_user_id, tasks.owner_user_id, totp_enrollments.auth_user_id, trusted_devices.auth_user_id, user_branch_assignments.user_id, user_permission_grants.user_id, user_role_assignments.user_id, users.auth_user_id',
  'CLASS GUARD (ATTR-2, structural): every column that FOREIGN-KEYS to public.users on a table `authenticated` can write directly, and that no BEFORE trigger derives, is exactly this classified set. Unlike assertion 22 this asks no question about the column NAME, so an actor column called anything at all appears here. A new entry is not necessarily a defect -- it is an unclassified column, and it must be classified in MASTER_GAP_REGISTER.md before this line is edited.')
from (
  select c.relname as tbl, a.attname as col
  from pg_constraint k
  join pg_class c on c.oid = k.conrelid
  join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  join pg_class rc on rc.oid = k.confrelid
  join unnest(k.conkey) with ordinality u(attnum, ord) on true
  join pg_attribute a on a.attrelid = c.oid and a.attnum = u.attnum
  where k.contype = 'f' and rc.relname = 'users' and a.attname <> 'tenant_id'
) ac
join (
  select distinct table_name from information_schema.role_table_grants
  where table_schema = 'public' and grantee = 'authenticated'
    and privilege_type in ('INSERT', 'UPDATE')
) w on w.table_name = ac.tbl
where not exists (
    select 1 from pg_trigger t
    join pg_class cl on cl.oid = t.tgrelid
    join pg_namespace n2 on n2.oid = cl.relnamespace and n2.nspname = 'public'
    join pg_proc p on p.oid = t.tgfoid
    where not t.tgisinternal and (t.tgtype::int & 2) = 2 and cl.relname = ac.tbl
      and p.prosrc ~ ('new\.' || ac.col || '\s*:='));

select * from finish();
rollback;
