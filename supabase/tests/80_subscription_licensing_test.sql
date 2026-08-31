-- pgTAP: the API-3 subscription/licensing family -- LIC-2 (202607058400), plus the first
-- behavioural coverage of `tenant_capabilities` beyond a name in an inventory.
--
-- WHAT THIS FILE CAN AND CANNOT PIN, STATED RATHER THAN IMPLIED. LIC-2 is a CONCURRENCY defect: two
-- sessions redeeming one single-use code both succeeded. pgTAP runs in ONE session inside ONE
-- transaction, so it structurally cannot stage that interleaving. The defect was reproduced, and the
-- fix proven, with two live psql sessions -- recorded in
-- `reports/history/session-2026-08-30-subscription-licensing-audit.md`. What this file adds is a
-- guard on the MECHANISM that closes it, and that guard is mutation-tested rather than trusted:
-- assertion 15 fails when the compare-and-swap predicate is removed. It measures source text, which
-- VER-1 classifies as a REPOSITORY fact rather than an execution one -- an honest limitation, and
-- the only automatable regression guard available for a race a single session cannot produce.
create extension if not exists pgtap with schema extensions;

begin;
select plan(19);

insert into auth.users (id, email) values
  ('80000000-0000-0000-0000-0000000000a1','own@lic80.example'),
  ('80000000-0000-0000-0000-0000000000a2','emp@lic80.example'),
  ('80000000-0000-0000-0000-0000000000a3','own@lic80rival.example');
insert into public.tenants (id, name, slug, status) values
  ('80000000-0000-0000-0000-000000000001','Lic80 Travel','lic80-travel','active'),
  ('80000000-0000-0000-0000-000000000002','Lic80 Rival','lic80-rival','active');
-- The two tenants are deliberately on DIFFERENT plans, so the isolation assertion below is
-- discriminating rather than incidental: `professional` enables the `documents` feature and
-- `starter` does not, so "which capabilities did I get" has a different answer per tenant.
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '80000000-0000-0000-0000-000000000001', sp.id, 'trial'
from public.subscription_plans sp where sp.plan_code = 'starter';
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '80000000-0000-0000-0000-000000000002', sp.id, 'trial'
from public.subscription_plans sp where sp.plan_code = 'professional';
insert into public.branches (id, tenant_id, name, slug) values
  ('80000000-0000-0000-0000-00000000000a','80000000-0000-0000-0000-000000000001','Main','lic80-main'),
  ('80000000-0000-0000-0000-00000000000b','80000000-0000-0000-0000-000000000002','Main','lic80-rival-main');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('80000000-0000-0000-0000-0000000000c1','80000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('80000000-0000-0000-0000-000000000011','80000000-0000-0000-0000-000000000001','Lic Owner','own@lic80.example',true,'80000000-0000-0000-0000-0000000000a1'),
  ('80000000-0000-0000-0000-000000000021','80000000-0000-0000-0000-000000000001','Lic Employee','emp@lic80.example',true,'80000000-0000-0000-0000-0000000000a2'),
  ('80000000-0000-0000-0000-000000000031','80000000-0000-0000-0000-000000000002','Rival Owner','own@lic80rival.example',true,'80000000-0000-0000-0000-0000000000a3');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '80000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-000000000011', r.id,'tenant' from public.roles r where r.code='owner';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '80000000-0000-0000-0000-000000000001','80000000-0000-0000-0000-000000000021', r.id,'tenant' from public.roles r where r.code='employee';
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '80000000-0000-0000-0000-000000000002','80000000-0000-0000-0000-000000000031', r.id,'tenant' from public.roles r where r.code='owner';
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, is_primary) values
  ('80000000-0000-0000-0000-000000000002','80000000-0000-0000-0000-000000000031','80000000-0000-0000-0000-00000000000b',true);
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '80000000-0000-0000-0000-000000000001', u, '80000000-0000-0000-0000-00000000000a','80000000-0000-0000-0000-0000000000c1', true
from unnest(array['80000000-0000-0000-0000-000000000011'::uuid,'80000000-0000-0000-0000-000000000021']) u;

-- A token for THIS tenant, and one for the rival, both issued through the platform path.
create temp table tok as
  select app.platform_issue_license_token('80000000-0000-0000-0000-000000000001','professional','monthly',true,30,'test') as t,
         app.platform_issue_license_token('80000000-0000-0000-0000-000000000002','professional','monthly',true,30,'rival') as rival_t;

select set_config('request.jwt.claims','{"sub":"80000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);

-- ================================================================================================
-- tenant_capabilities
-- ================================================================================================
select ok(app.has_permission('MANAGE_TENANT_SETTINGS'),
  'POSITIVE CONTROL: the owner genuinely holds MANAGE_TENANT_SETTINGS, so a later refusal is about the rule under test');

select cmp_ok(
  (select count(*)::int from app.tenant_capabilities()), '>', 0,
  'tenant_capabilities returns this tenant''s plan entitlements');

select is(
  (select is_enabled from app.tenant_capabilities() where feature_code = 'documents'),
  false,
  'TENANT ISOLATION, discriminating: this STARTER tenant is told the documents feature is DISABLED');

select set_config('request.jwt.claims','{"sub":"80000000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select is(
  (select is_enabled from app.tenant_capabilities() where feature_code = 'documents'),
  true,
  '...while a caller in the RIVAL tenant, on PROFESSIONAL, gets the opposite answer -- so the function resolves the CALLER''s tenant and does not return a global set');
select set_config('request.jwt.claims','{"sub":"80000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);

-- The employee is deliberately used here: capability discovery is NOT permission-gated, and that is
-- a deliberate reading rather than an oversight. canon 09 lists what plan limits cover and says
-- nothing about who may see them; canon 28 scopes VIEW_SUBSCRIPTION_STATUS to subscription STATUS,
-- not to feature capability; the function exposes no price, billing date or payment data; and it has
-- NO internal consumer, so it cannot create an authorization inconsistency anywhere else.
select set_config('request.jwt.claims','{"sub":"80000000-0000-0000-0000-0000000000a2"}',true);
select cmp_ok(
  (select count(*)::int from app.tenant_capabilities()), '>', 0,
  'an ordinary employee CAN read capabilities -- INTENTIONAL: this is client capability discovery, and it exposes no commercial subscription data');

set local role authenticated;
select is(
  (select count(*)::int from public.subscriptions),
  0,
  '...while the SUBSCRIPTION row itself stays behind VIEW_SUBSCRIPTION_STATUS for that same employee -- RLS FILTERS rather than raising, so this asserts an empty set and not an exception');
reset role;

-- ================================================================================================
-- upload_subscription_payment_proof
-- ================================================================================================
select throws_ok(
  $$select app.upload_subscription_payment_proof('proof.pdf','pdf',1024,'bank transfer')$$,
  '42501', null,
  'an employee without MANAGE_TENANT_SETTINGS cannot upload a payment proof');

-- PP-4: and neither can they plant one through the TABLE, which is the door the RPC does not own.
-- Reproduced before 202607058500: an employee holding UPLOAD_DOCUMENT inserted a confidential
-- payment_proof document directly -- audit pollution a Platform Owner reviewing renewals could be
-- misled by, which is SPP-2's shape one table over.
select throws_ok(
  $$insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code, is_confidential)
    values ('80000000-0000-0000-0000-000000000001','payment_proof','Forged proof','active',true)$$,
  '42501', null,
  'PP-4: an employee cannot plant a payment_proof document by direct DML either -- the table now charges the same permission the RPC does');

-- NEGATIVE CONTROL, and it is sited on the PROFESSIONAL tenant deliberately. On starter an
-- ordinary document is refused for a reason that is NOT this migration -- UPLOAD_DOCUMENT is gated
-- on the documents entitlement starter does not buy, and that is the plan model working exactly as
-- intended. Which is the whole point of LIC-3: only the payment proof is exempt, because paying for
-- the plan cannot be a plan feature. The first draft of this assertion ran on starter and failed
-- for that reason -- a fixture error, recorded rather than mistaken for a finding.
select set_config('request.jwt.claims','{"sub":"80000000-0000-0000-0000-0000000000a3","aal":"aal2"}',true);
select lives_ok(
  $$insert into public.documents (tenant_id, document_type_code, title, lifecycle_status_code)
    values ('80000000-0000-0000-0000-000000000002','other','An ordinary document','active')$$,
  'NEGATIVE CONTROL: on a plan that DOES include documents, an ordinary document still inserts -- 202607058500 scoped its change to payment proofs and did not tighten the documents module generally');
select set_config('request.jwt.claims','{"sub":"80000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);

select set_config('request.jwt.claims','{"sub":"80000000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);

create temp table proof as
  select app.upload_subscription_payment_proof('proof.pdf','pdf',1024,'bank transfer') as id;

select is(
  (select status_code from public.subscription_payment_proofs where id = (select id from proof)),
  'pending',
  'LIC-3: the owner of a STARTER tenant CAN file a payment proof, and it opens in canon 26 status "pending" -- before 202607058500 this refused, because UPLOAD_DOCUMENT is gated on the documents entitlement that starter does not have, so the only way back from read_only was shut on the entry-level plan');

select is(
  (select count(*)::int from public.document_links where subscription_payment_proof_id = (select id from proof)),
  1,
  '...and the document_links row that had no producer before WP-04-B is written');

select throws_ok(
  $$select app.upload_subscription_payment_proof('proof.exe','exe',1024,null)$$,
  null, 'a payment proof must be a pdf or an image (pdf, jpg, jpeg, png)',
  'a non-document file type is refused');

-- ================================================================================================
-- redeem_license_token -- the sequential contract, which is what one session can prove
-- ================================================================================================
select lives_ok(
  $$select app.redeem_license_token((select t from tok))$$,
  'POSITIVE CONTROL: a valid activation code redeems');

select is(
  (select subscription_status_code from public.subscriptions where tenant_id = '80000000-0000-0000-0000-000000000001'),
  'active',
  '...and the subscription is activated by the platform path');

select is(
  (select count(*)::int from public.security_events
    where tenant_id = '80000000-0000-0000-0000-000000000001'
      and security_event_type_code = 'license_token_redeemed'),
  1,
  '...recording EXACTLY ONE redemption -- the count LIC-2 made two under concurrency');

select throws_ok(
  $$select app.redeem_license_token((select rival_t from tok))$$,
  '42501', 'activation code is not valid',
  'a token issued for ANOTHER tenant is refused with the same generic message -- never an oracle');

-- ================================================================================================
-- LIC-2 mechanism guard, mutation-tested. See the header for what this can and cannot prove.
-- ================================================================================================
select ok(
  pg_get_functiondef('app.redeem_license_token(text)'::regprocedure) like '%and consumed_at is null%',
  'LIC-2: the consuming UPDATE carries its compare-and-swap predicate, which is what makes the code single-use under concurrency');

savepoint m1;
create or replace function app.redeem_license_token(p_token text)
returns void language plpgsql security definer set search_path = '' as $mut$
begin
    update public.tenant_license_activations set consumed_at = now() where id = id;
end $mut$;
select ok(
  pg_get_functiondef('app.redeem_license_token(text)'::regprocedure) not like '%and consumed_at is null%',
  'MUTATION: with the compare-and-swap predicate removed the guard above FAILS -- proving assertion 15 detects its absence rather than passing on the function''s mere existence');
rollback to savepoint m1;

-- The closing half of the PAR-4 pattern, and it is not decoration: pgTAP's assertion counter lives
-- in a temp table, so `rollback to savepoint` UNDOES the count of anything asserted inside the
-- mutated region. With the mutation assertion last, `finish()` reported "planned 18 but ran 17"
-- while every `ok` line was still emitted -- a warning the harness printed and the suite's PASS
-- masked. Re-asserting after the rollback both restores the count and proves the thing the pattern
-- exists to prove: that the enforcer is back.
select ok(
  pg_get_functiondef('app.redeem_license_token(text)'::regprocedure) like '%and consumed_at is null%',
  '...and the compare-and-swap predicate is restored once the mutation is rolled back');

select finish();
rollback;
