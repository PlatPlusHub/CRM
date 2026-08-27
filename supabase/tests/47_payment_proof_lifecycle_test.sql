-- pgTAP: WP-04-B -- the subscription payment-proof lifecycle, and the narrowed document gate.
--
-- The capability was broken in five places at once: no `payment_proof` document type;
-- `subscription_payment` already a link-target type with no branch in `upload_document`;
-- `document_links.subscription_payment_proof_id` with no producer; `status_code` as unconstrained
-- free text; and no review path at all.
--
-- The tenant under test is deliberately READ_ONLY, because that is the only state in which this
-- feature matters: a tenant that has lapsed must still be able to pay its way back. Assertions 8-10
-- are the ones that carry the security argument -- the SAME lapsed tenant that may upload a proof
-- may NOT create an ordinary business document, which is exactly canon 28's Read-Only Subscription
-- Mode ("Upload subscription renewal proof" allowed; "Upload business document" blocked) enforced
-- for the first time.
create extension if not exists pgtap with schema extensions;

begin;
select plan(19);

insert into auth.users (id, email) values
  ('47000000-0000-0000-0000-0000000000a1','owner@pp.test'),
  ('47000000-0000-0000-0000-0000000000a2','emp@pp.test');
insert into public.tenants (id, name, slug, status) values
  ('47000000-0000-0000-0000-000000000001','PP Travel','pp-travel','active');
insert into public.branches (id, tenant_id, name, slug) values
  ('47000000-0000-0000-0000-00000000000a','47000000-0000-0000-0000-000000000001','Cairo','pp-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('47000000-0000-0000-0000-0000000000c1','47000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('47000000-0000-0000-0000-000000000011','47000000-0000-0000-0000-000000000001','PP Owner','owner@pp.test',true,'47000000-0000-0000-0000-0000000000a1'),
  ('47000000-0000-0000-0000-000000000012','47000000-0000-0000-0000-000000000001','PP Employee','emp@pp.test',true,'47000000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('47000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-000000000011','47000000-0000-0000-0000-00000000000a','47000000-0000-0000-0000-0000000000c1',true),
  ('47000000-0000-0000-0000-000000000001','47000000-0000-0000-0000-000000000012','47000000-0000-0000-0000-00000000000a','47000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '47000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('47000000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('47000000-0000-0000-0000-000000000012'::uuid,'employee')) v(u, rc)
join public.roles r on r.code = v.rc;

-- A passenger seeded while the tenant is still writable, so assertion 10 has a real target and
-- cannot pass merely because the fixture was empty.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '47000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'professional';
insert into public.passengers (id, tenant_id, first_name, family_name, full_name, passenger_type_code) values
  ('47000000-0000-0000-0000-0000000000b1','47000000-0000-0000-0000-000000000001','Mona','Adel','Mona Adel','adult');

-- Now lapse the tenant. Everything below happens to a READ_ONLY tenant.
update public.subscriptions set subscription_status_code = 'read_only', read_only_started_at = now()
 where tenant_id = '47000000-0000-0000-0000-000000000001';

-- =============================================================================================
-- 1-3. THE VOCABULARY that was missing, and the free-text status that now has a catalog.
-- =============================================================================================
select is(
  (select count(*)::int from public.catalog_values
    where catalog_type_code = 'document_type' and code = 'payment_proof' and is_active),
  1,
  'payment_proof is a real document type -- a mandatory business concept is no longer filed as "other"');

select ok(app.is_financial_document_type('payment_proof'),
  '...and it is FINANCIAL, so the company''s bank transfer is not readable by frontline staff');

select ok(not app.subscription_allows_write('47000000-0000-0000-0000-000000000001'),
  'CONTROL: the tenant is genuinely restricted -- every assertion below concerns a lapsed tenant');

-- =============================================================================================
-- 4-7. THE UPLOAD. One transaction, four rows, and the link that had no producer.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"47000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select ok(app.has_permission('MANAGE_TENANT_SETTINGS'),
  'CONTROL: the tenant admin holds MANAGE_TENANT_SETTINGS -- the same actor SPEC-158 uses for licensing');

select lives_ok(
  $$select app.upload_subscription_payment_proof('transfer.pdf','pdf', 20480, 'August renewal')$$,
  'a READ_ONLY tenant CAN still upload its renewal proof -- the one capability canon 28 preserves');

reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select p.status_code || ':' || d.document_type_code || ':' || d.is_confidential::text
     from public.subscription_payment_proofs p
     join public.documents d on d.id = p.document_id
    where p.tenant_id = '47000000-0000-0000-0000-000000000001'),
  'pending:payment_proof:true',
  '...creating a pending proof against a confidential payment_proof document');

select is(
  (select count(*)::int from public.document_links dl
     join public.subscription_payment_proofs p on p.id = dl.subscription_payment_proof_id
    where dl.tenant_id = '47000000-0000-0000-0000-000000000001'),
  1,
  '...and document_links.subscription_payment_proof_id finally has a producer');

-- =============================================================================================
-- 8-10. THE NARROWED GATE. The same lapsed tenant, the same session -- and an ORDINARY document is
--       refused. Before this package the exemption was blanket: a suspended tenant could create
--       passports, tickets and invoices freely.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"47000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
set local role authenticated;

select throws_ok(
  $$select app.upload_document('passport','Mona passport','mona.pdf','pdf',
        'passenger','47000000-0000-0000-0000-0000000000b1')$$,
  '42501', null,
  'the SAME lapsed tenant may NOT create an ordinary business document -- the exemption is no longer blanket');

select throws_ok(
  $$insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code, is_confidential)
    values ('47000000-0000-0000-0000-000000000001','contract','Sneaky','active',false)$$,
  '42501', null,
  '...and direct DML is refused too -- the gate is a trigger, not an RPC courtesy');

select is(
  (select count(*)::int from public.subscription_payment_proofs
    where tenant_id = '47000000-0000-0000-0000-000000000001'),
  1,
  '...while READS of what the tenant already has remain available -- data is gated, not confiscated');

-- =============================================================================================
-- 11-12. THE TENANT CANNOT APPROVE ITSELF. Canon 28: "Tenant users may upload proof but cannot
--        approve their own subscription renewal." The control proves the row is visible first, so
--        the refusal is about authority rather than an invisible row.
-- =============================================================================================
select ok(
  (select count(*) from public.subscription_payment_proofs
    where tenant_id = '47000000-0000-0000-0000-000000000001') = 1,
  'CONTROL: the tenant admin CAN SEE its own proof');

update public.subscription_payment_proofs set status_code = 'approved'
 where tenant_id = '47000000-0000-0000-0000-000000000001';

reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select status_code from public.subscription_payment_proofs
    where tenant_id = '47000000-0000-0000-0000-000000000001'),
  'pending',
  '...yet its attempt to approve itself changed NOTHING -- REVIEW_SUBSCRIPTION_PAYMENT is held by no role');

-- =============================================================================================
-- 13-15. THE PLATFORM REVIEW, and approval that reactivates in the same transaction.
-- =============================================================================================
select ok(
  not has_function_privilege('authenticated',
      'app.platform_review_payment_proof(uuid, boolean, text, text, text, boolean)', 'EXECUTE'),
  'no tenant user may execute the review function at all -- service_role only, per canon 28');

select lives_ok(
  $$select app.platform_review_payment_proof(
      (select id from public.subscription_payment_proofs
        where tenant_id = '47000000-0000-0000-0000-000000000001'),
      true, 'transfer confirmed', 'professional', 'annual')$$,
  'the Platform Owner approves the proof AND activates the renewal in one transaction');

select is(
  (select p.status_code || ':' || s.subscription_status_code || ':' || s.billing_period_code
     from public.subscription_payment_proofs p
     join public.subscriptions s on s.id = p.subscription_id
    where p.tenant_id = '47000000-0000-0000-0000-000000000001'),
  'approved:active:annual',
  '...the proof is approved and the tenant is trading again, on the terms the PLATFORM chose');

-- =============================================================================================
-- 16. REVIEW IS NOT REPLAYABLE. Canon 26 admits a decision only from `pending`, so a second
--     approval cannot silently re-activate a subscription a second time.
-- =============================================================================================
select throws_ok(
  $$select app.platform_review_payment_proof(
      (select id from public.subscription_payment_proofs
        where tenant_id = '47000000-0000-0000-0000-000000000001'),
      true, 'again')$$,
  '23514', null,
  'reviewing an already-approved proof is refused -- approval cannot be replayed');

-- =============================================================================================
-- 17-19. SPP-1 / SPP-2 -- the sibling audit, applied to this table by a FAILING ASSERTION in
--        `48_document_storage_test.sql` rather than by inspection. `subscriptions` gates reads on
--        VIEW_SUBSCRIPTION_STATUS and inserts on MANAGE_SUBSCRIPTION; this table gated NEITHER, so
--        any tenant user could read the agency's whole payment history and FORGE a pending proof by
--        direct DML. Both policies now say what the parent says.
--
--        The employee is a real, live session throughout -- assertion 17 proves it -- so the two
--        refusals below are about authority and not about an empty fixture or a dead JWT.
-- =============================================================================================
-- The ids are captured as postgres FIRST. Without this the forgery attempt below reads
-- `subscriptions`, which SPP-1 has just made invisible to the employee -- so the INSERT ... SELECT
-- would read zero rows, insert nothing, and throw nothing. That is exactly the vacuous-test failure
-- AGENTS.md §6 exists to prevent, and the first version of this block was guilty of it: it "passed"
-- the forgery attempt by doing nothing at all. Handing the employee concrete ids makes the INSERT a
-- real single-row attempt that the policy must refuse on its own merits.
reset role;
select set_config('request.jwt.claims', null, true);
create temp table pp_ids as
select s.id as subscription_id, d.id as document_id
from public.subscriptions s
cross join public.documents d
where s.tenant_id = '47000000-0000-0000-0000-000000000001'
  and d.tenant_id = '47000000-0000-0000-0000-000000000001'
limit 1;
grant select on pp_ids to authenticated;

select set_config('request.jwt.claims','{"sub":"47000000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;

select ok(
  app.current_user_id() = '47000000-0000-0000-0000-000000000012'
  and not app.has_permission('VIEW_SUBSCRIPTION_STATUS'),
  'CONTROL: the employee is a live session and genuinely lacks VIEW_SUBSCRIPTION_STATUS');

select is(
  (select count(*)::int from public.subscription_payment_proofs),
  0,
  'SPP-1: an ordinary employee can no longer read the agency''s payment history -- parity with subscriptions');

select throws_ok(
  $$insert into public.subscription_payment_proofs
        (tenant_id, subscription_id, document_id, status_code)
    select '47000000-0000-0000-0000-000000000001', subscription_id, document_id, 'pending'
      from pp_ids$$,
  '42501', null,
  'SPP-2: ...and can no longer FORGE a pending proof by direct DML, which needed no permission at all');

select finish();
rollback;
