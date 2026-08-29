-- pgTAP: CUST-1 -- the merge that merged nothing.
--
-- `app.merge_customer_identity` archived the source, wrote its audit row, emitted a CRITICAL
-- `customer_identity_merged` event and returned the target id -- while re-pointing NOT ONE referrer.
-- Reproduced as an `owner`: a customer note sat on the source before the merge and was still there
-- afterwards, now behind an archived customer.
--
-- ROOT CAUSE, and it is a REGRESSION FROM AN EARLIER FIX: the re-pointing loop took the local column
-- as `conkey[1]`, the FIRST column of the foreign key. Correct when written, because the FKs were
-- single-column. **TENANT-1 (SPEC-128) made every tenant-scoped FK composite** -- `(tenant_id,
-- customer_id)` -- so `conkey[1]` silently became `tenant_id` on all sixteen referrers and the
-- generated UPDATE matched zero rows.
--
-- WHY NOTHING CAUGHT IT: the only tests naming this function checked that its EVENT CODE is
-- registered and that its ENDPOINT exists. A guard on the name of an emitted event cannot notice
-- that the function did nothing else. Assertion 5 is the behavioural test that was missing.
create extension if not exists pgtap with schema extensions;

begin;
select plan(19);

insert into auth.users (id, email) values
  ('71000000-0000-0000-0000-0000000000a1','owner@merge.test'),
  ('71000000-0000-0000-0000-0000000000a2','emp@merge.test'),
  ('71000000-0000-0000-0000-0000000000a3','rival@merge.test');
insert into public.tenants (id, name, slug, status) values
  ('71000000-0000-0000-0000-000000000001','Merge Travel','merge-travel','active'),
  ('71000000-0000-0000-0000-000000000002','Rival Merge','merge-rival','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.tenants t cross join public.subscription_plans sp
where sp.plan_code = 'enterprise' and t.id in ('71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000002');
insert into public.branches (id, tenant_id, name, slug) values
  ('71000000-0000-0000-0000-00000000000a','71000000-0000-0000-0000-000000000001','Cairo','merge-cairo'),
  ('71000000-0000-0000-0000-00000000000b','71000000-0000-0000-0000-000000000002','Giza','merge-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('71000000-0000-0000-0000-0000000000c1','71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-00000000000a','sales','Sales'),
  ('71000000-0000-0000-0000-0000000000c2','71000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-00000000000b','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('71000000-0000-0000-0000-000000000011','71000000-0000-0000-0000-000000000001','Own','owner@merge.test',true,'71000000-0000-0000-0000-0000000000a1'),
  ('71000000-0000-0000-0000-000000000012','71000000-0000-0000-0000-000000000001','Emp','emp@merge.test',true,'71000000-0000-0000-0000-0000000000a2'),
  ('71000000-0000-0000-0000-000000000013','71000000-0000-0000-0000-000000000002','Rival','rival@merge.test',true,'71000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000011','71000000-0000-0000-0000-00000000000a','71000000-0000-0000-0000-0000000000c1',true),
  ('71000000-0000-0000-0000-000000000001','71000000-0000-0000-0000-000000000012','71000000-0000-0000-0000-00000000000a','71000000-0000-0000-0000-0000000000c1',true),
  ('71000000-0000-0000-0000-000000000002','71000000-0000-0000-0000-000000000013','71000000-0000-0000-0000-00000000000b','71000000-0000-0000-0000-0000000000c2',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant' from (values
  ('71000000-0000-0000-0000-000000000001'::uuid,'71000000-0000-0000-0000-000000000011'::uuid,'owner'),
  ('71000000-0000-0000-0000-000000000001'::uuid,'71000000-0000-0000-0000-000000000012'::uuid,'employee'),
  ('71000000-0000-0000-0000-000000000002'::uuid,'71000000-0000-0000-0000-000000000013'::uuid,'owner')) v(t,u,rc)
join public.roles r on r.code = v.rc;

-- =============================================================================================
-- 1-3. THE ROOT CAUSE, pinned. Both halves: the condition that broke it, and the code that fell for it.
-- =============================================================================================
select cmp_ok(
  (select count(*)::int from pg_constraint c
    where c.contype = 'f' and c.confrelid = 'public.customers'::regclass
      and array_length(c.conkey, 1) > 1),
  '>=', 10,
  'TENANT-1 made the customer FKs COMPOSITE -- this is the precondition that turned conkey[1] into tenant_id');

select is(
  (select count(*)::int from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'merge_customer_identity'
      and p.prosrc ~ 'conkey\[1\]'),
  0,
  'the function no longer reads conkey[1] -- the local column is paired with customers.id by ordinal position');

select isnt(
  (select position('has no column referencing customers.id' in p.prosrc)
     from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'app' and p.proname = 'merge_customer_identity'),
  0,
  '...and it FAILS CLOSED on a referrer it cannot resolve -- silently skipping one is the defect being fixed');

-- =============================================================================================
-- 4-5. AUTHORIZATION, both directions.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;
select ok(app.has_permission('MERGE_CUSTOMER_IDENTITY'),
  'POSITIVE CONTROL: the owner holds MERGE_CUSTOMER_IDENTITY');

select lives_ok(
  $q$select app.create_customer('person','Ahmed Dup',null,null,null,'+201000000001','dup@merge.test')$q$,
  'the source customer exists -- the fixture is real');
select lives_ok(
  $q$select app.create_customer('person','Ahmed Real',null,null,null,'+201000000002','real@merge.test')$q$,
  'and so does the target');

-- Referrers on the SOURCE: a note, plus contact methods that will collide on merge.
insert into public.customer_notes (tenant_id, customer_id, note_text)
select '71000000-0000-0000-0000-000000000001', c.id, 'source note'
from public.customers c where c.tenant_id = '71000000-0000-0000-0000-000000000001' and c.full_name = 'Ahmed Dup';

select lives_ok(
  $q$select app.add_customer_contact_method(
      (select id from public.customers where tenant_id='71000000-0000-0000-0000-000000000001' and full_name='Ahmed Dup'),
      'email','source-only@merge.test', true)$q$,
  'the source has a PRIMARY email');
select lives_ok(
  $q$select app.add_customer_contact_method(
      (select id from public.customers where tenant_id='71000000-0000-0000-0000-000000000001' and full_name='Ahmed Real'),
      'email','target-primary@merge.test', true)$q$,
  '...and so does the target -- the one_primary_per_type collision the fix must survive');
select lives_ok(
  $q$select app.add_customer_contact_method(
      (select id from public.customers where tenant_id='71000000-0000-0000-0000-000000000001' and full_name='Ahmed Dup'),
      'whatsapp','+20111222333', false)$q$,
  'the source has a whatsapp number');
select lives_ok(
  $q$select app.add_customer_contact_method(
      (select id from public.customers where tenant_id='71000000-0000-0000-0000-000000000001' and full_name='Ahmed Real'),
      'whatsapp','+20111222333', false)$q$,
  '...and the target has THE SAME ONE -- the unique_value collision, which is WHY they are duplicates');

-- =============================================================================================
-- 10-14. THE MERGE ITSELF.
-- =============================================================================================
select lives_ok(
  $q$select app.merge_customer_identity(
      (select id from public.customers where tenant_id='71000000-0000-0000-0000-000000000001' and full_name='Ahmed Dup'),
      (select id from public.customers where tenant_id='71000000-0000-0000-0000-000000000001' and full_name='Ahmed Real'),
      'duplicate record')$q$,
  'the merge completes -- and does NOT raise a unique violation on the ordinary duplicate-customer case');

select is(
  (select count(*)::int from public.customer_notes cn
    join public.customers c on c.id = cn.customer_id
   where c.tenant_id = '71000000-0000-0000-0000-000000000001' and c.full_name = 'Ahmed Real'),
  1,
  'THE REPRODUCTION, CLOSED: the source''s note is now on the TARGET -- before the fix it stayed put and this assertion is the one that was missing');

select is(
  (select count(*)::int from public.customer_notes cn
    join public.customers c on c.id = cn.customer_id
   where c.tenant_id = '71000000-0000-0000-0000-000000000001' and c.full_name = 'Ahmed Dup'),
  0,
  '...and nothing is left pointing at the archived source');

select is(
  (select string_agg(m.contact_method_type_code || ':' || m.value || case when m.is_primary then '*' else '' end, ' | ' order by m.contact_method_type_code, m.value)
     from public.customer_contact_methods m
     join public.customers c on c.id = m.customer_id
    where c.tenant_id = '71000000-0000-0000-0000-000000000001' and c.full_name = 'Ahmed Real'),
  'email:source-only@merge.test | email:target-primary@merge.test* | whatsapp:+20111222333',
  'COLLISIONS RESOLVED WITHOUT LOSS: the shared whatsapp is de-duplicated, the source email is KEPT but DEMOTED, and the target''s primary survives because the target is the identity that survives');

select is(
  (select count(*)::int from public.customer_contact_methods m
     join public.customers c on c.id = m.customer_id
    where c.tenant_id = '71000000-0000-0000-0000-000000000001' and c.full_name = 'Ahmed Real' and m.is_primary
      and m.contact_method_type_code = 'email'),
  1,
  '...exactly ONE primary email, which is what the unique index requires and what would have raised before');

-- =============================================================================================
-- 15-16. SIDE EFFECTS -- unchanged by this package, and proven still present.
-- =============================================================================================
select is(
  (select is_archived::text from public.customers
    where tenant_id = '71000000-0000-0000-0000-000000000001' and full_name = 'Ahmed Dup'),
  'true',
  'the source is archived, not deleted -- history is preserved');

select is(
  (select count(*)::int from public.events
    where tenant_id = '71000000-0000-0000-0000-000000000001' and event_type_code = 'customer_identity_merged'),
  1,
  'and the critical customer_identity_merged event fired exactly once -- now backed by a merge that actually happened');

-- =============================================================================================
-- 17-18. REFUSALS. Cross-tenant, and the employee.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
set local role authenticated;
select throws_ok(
  $q$select app.merge_customer_identity(
      (select id from public.customers where tenant_id='71000000-0000-0000-0000-000000000001' and full_name='Ahmed Real'),
      (select id from public.customers where tenant_id='71000000-0000-0000-0000-000000000001' and full_name='Ahmed Dup'),
      'cross tenant')$q$,
  null, null,
  'TENANT ISOLATION: the rival agency''s owner -- who holds MERGE_CUSTOMER_IDENTITY in their OWN tenant -- cannot merge another agency''s customers');

reset role;
select set_config('request.jwt.claims','{"sub":"71000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;
select throws_ok(
  $q$select app.merge_customer_identity(
      '71000000-0000-0000-0000-0000000000f1'::uuid,'71000000-0000-0000-0000-0000000000f2'::uuid,'x')$q$,
  '42501', null,
  'and an ordinary employee is refused outright -- identity merge is an owner/ceo capability');

select finish();
rollback;
