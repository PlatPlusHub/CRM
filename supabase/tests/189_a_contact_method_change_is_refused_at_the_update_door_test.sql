-- pgTAP: Batch 6 exit -- a contact method change is refused at the UPDATE door for every rule its INSERT door keeps.
--
-- EC-6: every sensitive path needs a targeted negative test. Swept at `2f8c19a` (CRM SPEC-332), the only
--   member-writable table door with no test aimed at it is UPDATE on public.customer_contact_methods: authenticated
--   holds UPDATE, the tenant_isolation policy covers it, and seven controls stand on it (the RLS
--   WITH CHECK, the tenant-bound customer key, the value_normalized check, the one-primary-per-type index, the
--   enforce_catalog_codes trigger, the guard_write_capability trigger and the subscription write gate), yet every
--   existing contact test (124 and the customer door tests) writes through INSERT only.
--   Assertions 1-2 are the positive control: an employee changes a value and its verification. Assertions 3-12
--   attack the same door as that employee and as a trainee: a move to another tenant, a move to another tenant's
--   customer, a value that is not normalized (email and phone), a second primary, and a type code that is unknown,
--   inactive in its own tenant or active only in another tenant; a trainee without CREATE_CUSTOMER is refused and
--   the row stays as it was. Assertions 13-14 prove another tenant neither sees nor changes the row. Assertion 15
--   proves a lapsed subscription refuses the change. No migration: each control already holds (PROVEN on the local
--   stack before this test was written); this test pins them so a later change cannot drop one unseen.
-- ATTACK-CLASSES: AUTH TENANT DOOR INPUT PRIVILEGE BUSINESS STATE CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
create extension if not exists pgtap with schema extensions;

begin;
select plan(15);

insert into auth.users (id, email, email_confirmed_at) values
  ('c1890000-0000-0000-0000-0000000000a1','employee@a189.test', now()),
  ('c1890000-0000-0000-0000-0000000000a2','trainee@a189.test', now()),
  ('c1890000-0000-0000-0000-0000000000b1','employee@b189.test', now());
insert into public.tenants (id, name, slug, status) values
  ('c1890000-0000-0000-0000-000000000001','A189 Travel','a189-travel','active'),
  ('c1890000-0000-0000-0000-000000000002','B189 Travel','b189-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active'
  from (values ('c1890000-0000-0000-0000-000000000001'::uuid), ('c1890000-0000-0000-0000-000000000002'::uuid)) t(id)
 cross join public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('c1890000-0000-0000-0000-00000000000a','c1890000-0000-0000-0000-000000000001','Main A','a189-main'),
  ('c1890000-0000-0000-0000-00000000000b','c1890000-0000-0000-0000-000000000002','Main B','b189-main');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('c1890000-0000-0000-0000-0000000000da','c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-00000000000a','sales','Sales'),
  ('c1890000-0000-0000-0000-0000000000db','c1890000-0000-0000-0000-000000000002','c1890000-0000-0000-0000-00000000000b','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('c1890000-0000-0000-0000-000000000011','c1890000-0000-0000-0000-000000000001','Employee A','employee@a189.test',true,'c1890000-0000-0000-0000-0000000000a1'),
  ('c1890000-0000-0000-0000-000000000012','c1890000-0000-0000-0000-000000000001','Trainee A','trainee@a189.test',true,'c1890000-0000-0000-0000-0000000000a2'),
  ('c1890000-0000-0000-0000-000000000021','c1890000-0000-0000-0000-000000000002','Employee B','employee@b189.test',true,'c1890000-0000-0000-0000-0000000000b1');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-000000000011','c1890000-0000-0000-0000-00000000000a','c1890000-0000-0000-0000-0000000000da',true),
  ('c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-000000000012','c1890000-0000-0000-0000-00000000000a','c1890000-0000-0000-0000-0000000000da',true),
  ('c1890000-0000-0000-0000-000000000002','c1890000-0000-0000-0000-000000000021','c1890000-0000-0000-0000-00000000000b','c1890000-0000-0000-0000-0000000000db',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
  from (values ('c1890000-0000-0000-0000-000000000001'::uuid,'c1890000-0000-0000-0000-000000000011'::uuid,'employee'),
               ('c1890000-0000-0000-0000-000000000001'::uuid,'c1890000-0000-0000-0000-000000000012'::uuid,'trainee'),
               ('c1890000-0000-0000-0000-000000000002'::uuid,'c1890000-0000-0000-0000-000000000021'::uuid,'employee')) v(t, u, code)
  join public.roles r on r.code = v.code;
insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('c1890000-0000-0000-0000-0000000000c1','c1890000-0000-0000-0000-000000000001','person','A189 Customer','+201000018901'),
  ('c1890000-0000-0000-0000-0000000000c2','c1890000-0000-0000-0000-000000000002','person','B189 Customer','+201000018902');
insert into public.catalog_values (tenant_id, catalog_type_code, code, label, is_active) values
  ('c1890000-0000-0000-0000-000000000001','contact_method_type','a189_retired','A189 retired channel',false),
  ('c1890000-0000-0000-0000-000000000002','contact_method_type','b189_only','B189 own channel',true);
insert into public.customer_contact_methods (id, tenant_id, customer_id, contact_method_type_code, value, is_primary) values
  ('c1890000-0000-0000-0000-0000000000e1','c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-0000000000c1','primary_phone','+201000018911',true),
  ('c1890000-0000-0000-0000-0000000000e2','c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-0000000000c1','primary_phone','+201000018912',false),
  ('c1890000-0000-0000-0000-0000000000e3','c1890000-0000-0000-0000-000000000001','c1890000-0000-0000-0000-0000000000c1','email','a189@example.com',false);

-- The employee of tenant A works through the authenticated door.
select set_config('request.jwt.claims', '{"sub":"c1890000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

-- 1-2. Positive control: an employee changes a contact value and its verification, and the change is kept.
select lives_ok(
  $$update public.customer_contact_methods set value = '+201000018921', is_verified = true
     where id = 'c1890000-0000-0000-0000-0000000000e2'$$,
  'an employee changes a contact value and its verification through the UPDATE door (positive control)'
);
select is(
  (select value || ' ' || is_verified::text from public.customer_contact_methods where id = 'c1890000-0000-0000-0000-0000000000e2'),
  '+201000018921 true',
  'the changed value and verification are kept'
);

-- 3. TENANT: a contact method cannot be moved into another tenant.
select throws_ok(
  $$update public.customer_contact_methods set tenant_id = 'c1890000-0000-0000-0000-000000000002'
     where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
  '42501', 'new row violates row-level security policy for table "customer_contact_methods"',
  'TENANT: a contact method cannot be moved into another tenant'
);

-- 4. TENANT: a contact method cannot be moved onto another tenant's customer.
select throws_ok(
  $$update public.customer_contact_methods set customer_id = 'c1890000-0000-0000-0000-0000000000c2'
     where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
  '23503', null,
  'TENANT: a contact method cannot be moved onto another tenant''s customer'
);

-- 5-6. INPUT: a changed value must stay in normal form.
select throws_ok(
  $$update public.customer_contact_methods set value = 'A189@Example.COM'
     where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
  '23514', null,
  'INPUT: an email changed to a value that is not normalized is refused'
);
select throws_ok(
  $$update public.customer_contact_methods set value = '+20 100 001 8931'
     where id = 'c1890000-0000-0000-0000-0000000000e2'$$,
  '23514', null,
  'INPUT: a phone changed to a value that is not normalized is refused'
);

-- 7. BUSINESS: a change cannot make a second primary of the same type.
select throws_ok(
  $$update public.customer_contact_methods set is_primary = true
     where id = 'c1890000-0000-0000-0000-0000000000e2'$$,
  '23505', null,
  'BUSINESS: a change that makes a second primary phone for the customer is refused'
);

-- 8-10. INPUT and TENANT: a changed type code must be active in the row's own tenant catalog.
select throws_matching(
  $$update public.customer_contact_methods set contact_method_type_code = 'telegram'
     where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
  '"telegram" is not an active value of catalog family "contact_method_type"',
  'INPUT: a type code the catalog does not hold is refused'
);
select throws_matching(
  $$update public.customer_contact_methods set contact_method_type_code = 'a189_retired'
     where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
  '"a189_retired" is not an active value of catalog family "contact_method_type"',
  'INPUT: a type code that is inactive in the own tenant catalog is refused'
);
select throws_matching(
  $$update public.customer_contact_methods set contact_method_type_code = 'b189_only'
     where id = 'c1890000-0000-0000-0000-0000000000e3'$$,
  '"b189_only" is not an active value of catalog family "contact_method_type"',
  'TENANT: a type code active only in another tenant catalog is refused'
);

-- 11-12. AUTH and PRIVILEGE: a trainee without CREATE_CUSTOMER cannot change a contact, and the row stays.
select set_config('request.jwt.claims', '{"sub":"c1890000-0000-0000-0000-0000000000a2"}', true);
select throws_ok(
  $$update public.customer_contact_methods set value = '+201000018941'
     where id = 'c1890000-0000-0000-0000-0000000000e2'$$,
  '42501', 'permission denied: one of CREATE_CUSTOMER is required to write customer_contact_methods',
  'PRIVILEGE: a trainee without CREATE_CUSTOMER cannot change a contact method'
);
reset role;
select is(
  (select value from public.customer_contact_methods where id = 'c1890000-0000-0000-0000-0000000000e2'),
  '+201000018921',
  'AUTH: the refused trainee change left the contact value as it was'
);

-- 13-14. TENANT: another tenant's employee neither sees nor changes the row.
select set_config('request.jwt.claims', '{"sub":"c1890000-0000-0000-0000-0000000000b1"}', true);
set local role authenticated;
select is(
  (select count(*)::int from public.customer_contact_methods where tenant_id = 'c1890000-0000-0000-0000-000000000001'),
  0,
  'TENANT: another tenant''s employee sees no contact method of tenant A'
);
update public.customer_contact_methods set value = '+201000018951' where id = 'c1890000-0000-0000-0000-0000000000e2';
reset role;
select is(
  (select value from public.customer_contact_methods where id = 'c1890000-0000-0000-0000-0000000000e2'),
  '+201000018921',
  'TENANT: another tenant''s employee changes no contact method of tenant A'
);

-- 15. STATE: a lapsed subscription refuses the change and keeps reads.
update public.subscriptions set subscription_status_code = 'expired' where tenant_id = 'c1890000-0000-0000-0000-000000000001';
select set_config('request.jwt.claims', '{"sub":"c1890000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;
select throws_ok(
  $$update public.customer_contact_methods set value = '+201000018961'
     where id = 'c1890000-0000-0000-0000-0000000000e2'$$,
  '42501', 'subscription state "expired" does not permit writes on public.customer_contact_methods (reads remain available so the tenant can inspect and export its own data)',
  'STATE: a lapsed subscription refuses a contact method change'
);
reset role;

select * from finish();
rollback;
