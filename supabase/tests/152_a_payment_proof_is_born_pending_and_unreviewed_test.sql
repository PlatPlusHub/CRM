-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT BUSINESS CONCURRENCY=N/A OBSERVABILITY=N/A PRIVILEGE=N/A REPLAY=N/A
-- SPEC-260 / Batch 6 Slice 38. A subscription payment proof is born `pending` and unreviewed, for
-- every caller and through either door; only `app.platform_review_payment_proof` decides it (canon
-- 28: tenant users "cannot approve their own subscription renewal"). SPP-5, measured at `e26733a`:
-- FX-4's `app.derive_proof_reviewer` stamped the uploader as reviewer on INSERT, so every proof the
-- RPC wrote named the tenant owner as its reviewer, before and after the platform's approval; and a
-- direct INSERT by the owner created a proof born `approved` or `rejected`, backdated, with forged
-- review notes. Assertions 3, 8 and 13 are the reviewer; 4-6 and 11 the birth state; 15-16 prove
-- that the named trigger is what refuses (PAR-4).
--
-- CONCURRENCY=N/A   this file has one session. The only read-modify-write is the platform review,
--                   whose two-session race is SPP-6 (SPEC-261): proven by
--                   `scripts/verify_subscription_concurrency.py` and pinned by `153_...`.
-- OBSERVABILITY=N/A a direct-door pending proof emits no upload event and no document link. It can
--                   only delay its own uploader's renewal: the platform reviews a proof by its id.
-- PRIVILEGE=N/A     REVIEW_SUBSCRIPTION_PAYMENT is held by no role and cannot be granted (SPEC-227,
--                   `131_...`), so no tenant caller reaches the UPDATE door (assertion 10).
-- REPLAY=N/A        a second review of a decided proof is refused by the review itself (`47_...`
--                   assertion 16), unchanged.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

insert into auth.users (id, email) values
  ('15200000-0000-0000-0000-0000000000a1','owner@pp152.test'),
  ('15200000-0000-0000-0000-0000000000a2','emp@pp152.test');
insert into public.tenants (id, name, slug, status) values
  ('15200000-0000-0000-0000-000000000001','PP152 Travel','pp152-travel','active'),
  ('15200000-0000-0000-0000-000000000002','PP152 Rival','pp152-rival','active');
insert into public.branches (id, tenant_id, name, slug) values
  ('15200000-0000-0000-0000-00000000000a','15200000-0000-0000-0000-000000000001','Cairo','pp152-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('15200000-0000-0000-0000-0000000000c1','15200000-0000-0000-0000-000000000001','15200000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('15200000-0000-0000-0000-000000000011','15200000-0000-0000-0000-000000000001','PP152 Owner','owner@pp152.test',true,'15200000-0000-0000-0000-0000000000a1'),
  ('15200000-0000-0000-0000-000000000012','15200000-0000-0000-0000-000000000001','PP152 Employee','emp@pp152.test',true,'15200000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('15200000-0000-0000-0000-000000000001','15200000-0000-0000-0000-000000000011','15200000-0000-0000-0000-00000000000a','15200000-0000-0000-0000-0000000000c1',true),
  ('15200000-0000-0000-0000-000000000001','15200000-0000-0000-0000-000000000012','15200000-0000-0000-0000-00000000000a','15200000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '15200000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('15200000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('15200000-0000-0000-0000-000000000012'::uuid,'employee')) v(u, rc)
join public.roles r on r.code = v.rc;
insert into public.subscriptions (id, tenant_id, subscription_plan_id, subscription_status_code)
select v.id, v.t, sp.id, 'active'
from (values ('15200000-0000-0000-0000-0000000000b1'::uuid,'15200000-0000-0000-0000-000000000001'::uuid),
             ('15200000-0000-0000-0000-0000000000b2'::uuid,'15200000-0000-0000-0000-000000000002'::uuid)) v(id, t)
cross join public.subscription_plans sp where sp.plan_code = 'professional';
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code, is_confidential) values
  ('15200000-0000-0000-0000-0000000000d2','15200000-0000-0000-0000-000000000002','payment_proof','Rival proof','active',true);

-- The tenant lapses: proof upload is the one way back, so everything below concerns a READ_ONLY tenant.
update public.subscriptions set subscription_status_code = 'read_only', read_only_started_at = now()
 where id = '15200000-0000-0000-0000-0000000000b1';

create temp table s152 (k text primary key, v uuid) on commit drop;
grant all on s152 to authenticated;

select set_config('request.jwt.claims','{"sub":"15200000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

-- 1. The actor is live and is the tenant's highest authority, and still not a reviewer.
select ok(
  app.current_user_id() = '15200000-0000-0000-0000-000000000011'
  and app.has_permission('MANAGE_TENANT_SETTINGS')
  and app.has_permission('VIEW_SUBSCRIPTION_STATUS')
  and not app.has_permission('REVIEW_SUBSCRIPTION_PAYMENT'),
  'CONTROL: the owner is a live session holding MANAGE_TENANT_SETTINGS and not REVIEW_SUBSCRIPTION_PAYMENT');

-- 2-3. The sanctioned door.
select lives_ok(
  $$insert into s152 select 'rpc', app.upload_subscription_payment_proof('transfer.pdf','pdf',20480,'October renewal')$$,
  'a lapsed tenant uploads its renewal proof through the RPC');

select is(
  (select p.status_code || ':' || (p.uploaded_by = '15200000-0000-0000-0000-000000000011')::text
          || ':' || coalesce(p.reviewed_by::text, 'no reviewer') || ':' || coalesce(p.reviewed_at::text, 'no review')
     from public.subscription_payment_proofs p where p.id = (select v from s152 where k = 'rpc')),
  'pending:true:no reviewer:no review',
  'SPP-5: the uploaded proof is pending, attributed to its uploader, and names NO reviewer');

-- 4-6. The table door cannot create a decided proof.
select throws_ok(
  $$insert into public.subscription_payment_proofs
        (tenant_id, subscription_id, document_id, status_code, uploaded_at, reviewed_at, review_notes)
    select tenant_id, subscription_id, document_id, 'approved', now() - interval '40 days',
           now() - interval '39 days', 'transfer confirmed by platform'
      from public.subscription_payment_proofs where id = (select v from s152 where k = 'rpc')$$,
  '23514', 'a payment proof is created pending and unreviewed; only app.platform_review_payment_proof decides it',
  'SPP-5: the owner cannot create a proof born approved, backdated, with forged review notes');

select throws_ok(
  $$insert into public.subscription_payment_proofs (tenant_id, subscription_id, document_id, status_code)
    select tenant_id, subscription_id, document_id, 'rejected'
      from public.subscription_payment_proofs where id = (select v from s152 where k = 'rpc')$$,
  '23514', 'a payment proof is created pending and unreviewed; only app.platform_review_payment_proof decides it',
  '...nor one born rejected');

select throws_ok(
  $$insert into public.subscription_payment_proofs (tenant_id, subscription_id, document_id, status_code, reviewed_at)
    select tenant_id, subscription_id, document_id, 'pending', now()
      from public.subscription_payment_proofs where id = (select v from s152 where k = 'rpc')$$,
  '23514', 'a payment proof is created pending and unreviewed; only app.platform_review_payment_proof decides it',
  '...nor a pending one that claims a review time');

-- 7-8. A pending proof at the table door stays an ordinary write, and the attributions are derived.
select lives_ok(
  $$with x as (
      insert into public.subscription_payment_proofs
          (tenant_id, subscription_id, document_id, status_code, uploaded_by, reviewed_by)
      select tenant_id, subscription_id, document_id, 'pending',
             '15200000-0000-0000-0000-000000000012', '15200000-0000-0000-0000-000000000012'
        from public.subscription_payment_proofs where id = (select v from s152 where k = 'rpc')
      returning id)
    insert into s152 select 'direct', id from x$$,
  'a pending proof written at the table door is still accepted');

select is(
  (select p.uploaded_by::text || ':' || coalesce(p.reviewed_by::text, 'no reviewer')
     from public.subscription_payment_proofs p where p.id = (select v from s152 where k = 'direct')),
  '15200000-0000-0000-0000-000000000011:no reviewer',
  '...with the uploader derived from the session and the stated reviewer discarded');

-- 9. Another tenant's proof is refused by RLS.
select throws_ok(
  $$insert into public.subscription_payment_proofs (tenant_id, subscription_id, document_id, status_code)
    values ('15200000-0000-0000-0000-000000000002','15200000-0000-0000-0000-0000000000b2',
            '15200000-0000-0000-0000-0000000000d2','pending')$$,
  '42501', 'new row violates row-level security policy for table "subscription_payment_proofs"',
  'TENANT: a proof filed under another tenant is refused by RLS');

-- 10. The owner cannot decide its own proof through the UPDATE door.
update public.subscription_payment_proofs set status_code = 'approved', reviewed_at = now()
 where id = (select v from s152 where k = 'rpc');

reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select status_code || ':' || coalesce(reviewed_at::text, 'no review')
     from public.subscription_payment_proofs where id = (select v from s152 where k = 'rpc')),
  'pending:no review',
  'AUTH: the owner''s attempt to approve its own proof changed nothing');

-- 11. Session-less writers are bound too.
select throws_ok(
  $$insert into public.subscription_payment_proofs (tenant_id, subscription_id, document_id, status_code)
    select tenant_id, subscription_id, document_id, 'approved'
      from public.subscription_payment_proofs where id = (select v from s152 where k = 'rpc')$$,
  '23514', 'a payment proof is created pending and unreviewed; only app.platform_review_payment_proof decides it',
  'SPP-5: a session-less writer cannot create a decided proof either');

-- 12-13. The platform decides, and records no tenant reviewer.
select lives_ok(
  $$select app.platform_review_payment_proof((select v from s152 where k = 'rpc'),
        true, 'transfer confirmed', 'professional', 'annual')$$,
  'the Platform Owner approves the proof and reactivates the subscription');

select is(
  (select p.status_code || ':' || coalesce(p.reviewed_by::text, 'no reviewer') || ':'
          || (p.reviewed_at is not null)::text || ':' || s.subscription_status_code
     from public.subscription_payment_proofs p
     join public.subscriptions s on s.id = p.subscription_id
    where p.id = (select v from s152 where k = 'rpc')),
  'approved:no reviewer:true:active',
  'SPP-5: the approved proof names no tenant reviewer -- the platform decided it (SPP-3)');

-- 14. No refused write left a row.
select is(
  (select count(*)::int from public.subscription_payment_proofs
    where tenant_id in ('15200000-0000-0000-0000-000000000001','15200000-0000-0000-0000-000000000002')),
  2,
  'only the two accepted proofs exist');

-- 15-16. PAR-4: the named trigger is what refuses.
savepoint par4;
drop trigger subscription_payment_proofs_derive_reviewer on public.subscription_payment_proofs;
select lives_ok(
  $$insert into public.subscription_payment_proofs (tenant_id, subscription_id, document_id, status_code)
    select tenant_id, subscription_id, document_id, 'approved'
      from public.subscription_payment_proofs where id = (select v from s152 where k = 'rpc')$$,
  'PAR-4: without subscription_payment_proofs_derive_reviewer a proof is born approved');
rollback to savepoint par4;

select throws_ok(
  $$insert into public.subscription_payment_proofs (tenant_id, subscription_id, document_id, status_code)
    select tenant_id, subscription_id, document_id, 'approved'
      from public.subscription_payment_proofs where id = (select v from s152 where k = 'rpc')$$,
  '23514', 'a payment proof is created pending and unreviewed; only app.platform_review_payment_proof decides it',
  '...and with it restored the identical insert is refused again');

select finish();
rollback;
