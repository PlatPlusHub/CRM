-- pgTAP: Batch 6 slice 48 -- `customer_consents` audited and recorded, not repaired.
--
-- ATTACK-CLASSES: AUTH STATE BUSINESS DOOR TENANT PRIVILEGE INPUT CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
--   DOOR, TENANT, PRIVILEGE, INPUT -- attacked again in this slice and held; their assertions live in `142_...`
--     (no table door, the server's actor and time, another tenant refused, CREATE_CUSTOMER required, only granted
--     or denied) and `144_...` (a merged identity takes no decision, a newer DENIED on a merged identity governs),
--     so they are not repeated here.
--   OBSERVABILITY=N/A -- the record is its own audit trail: append-only, with the server's actor and time (142);
--     a decision emits no event by SPEC-240's design.
--   CONCURRENCY=N/A -- pgTAP runs one session; SPEC-244 recorded the two-session proofs of a merge against a
--     decision on either identity, both orders.
--   REPLAY=N/A -- every decision is a new record by design; no token, nonce or idempotency key.
--
-- What this file adds is what the slice measured and no test held:
--   AUTH: the one writer charges step-up exactly where `app.requires_mfa` does -- an owner at aal1 is refused, at
--     aal2 records -- and an employee, whose role is not MFA-bound, records at aal1. That is SPEC-240's choice of
--     CREATE_CUSTOMER as the authority, recorded as a position: whoever captures a customer captures its decision.
--   STATE: an archived customer that was never merged still takes a withdrawal (only the merge record refuses).
--   BUSINESS: a tenant whose writes the subscription gate refuses still records a GRANT, not only a withdrawal: the
--     decision is the customer's own fact, and refusing it would leave the record false. Position; test 35 states
--     the exemption's reason for withdrawals.
-- Not pinned: `service_role` TRUNCATE empties the table (no trigger refuses TRUNCATE on any append-only table).
--   It fails closed (no record reads as unspecified, never granted) and is DC-15's service_role blast radius;
--   `service_role` grants differ by environment (PAR-5), so a local pin would measure the platform.
create extension if not exists pgtap with schema extensions;

begin;
select plan(9);

insert into auth.users (id, email) values
  ('16300000-0000-0000-0000-0000000000a1','owner@c163.test'),
  ('16300000-0000-0000-0000-0000000000a2','emp@c163.test'),
  ('16300000-0000-0000-0000-0000000000a3','lapsed@c163.test');
insert into public.tenants (id, name, slug, status) values
  ('16300000-0000-0000-0000-000000000001','Consent Travel','consent-travel-163','active'),
  ('16300000-0000-0000-0000-000000000002','Lapsed Travel','lapsed-travel-163','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code, created_at)
select t, sp.id, 'active', now() - interval '2 days' from public.subscription_plans sp,
  (values ('16300000-0000-0000-0000-000000000001'::uuid), ('16300000-0000-0000-0000-000000000002'::uuid)) v(t)
where sp.plan_code = 'enterprise';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('16300000-0000-0000-0000-000000000011','16300000-0000-0000-0000-000000000001','Owner','owner@c163.test',true,'16300000-0000-0000-0000-0000000000a1'),
  ('16300000-0000-0000-0000-000000000012','16300000-0000-0000-0000-000000000001','Handler','emp@c163.test',true,'16300000-0000-0000-0000-0000000000a2'),
  ('16300000-0000-0000-0000-000000000021','16300000-0000-0000-0000-000000000002','Lapsed handler','lapsed@c163.test',true,'16300000-0000-0000-0000-0000000000a3');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('16300000-0000-0000-0000-000000000001'::uuid,'16300000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('16300000-0000-0000-0000-000000000001','16300000-0000-0000-0000-000000000012','employee'),
             ('16300000-0000-0000-0000-000000000002','16300000-0000-0000-0000-000000000021','employee')) v(t,u,rc)
join public.roles r on r.code = v.rc;
-- d1 A and d2 B in the active tenant, B archived without a merge; d3 G in the tenant whose billing then ends.
insert into public.customers (id, tenant_id, customer_type_code, full_name) values
  ('16300000-0000-0000-0000-0000000000d1','16300000-0000-0000-0000-000000000001','person','A'),
  ('16300000-0000-0000-0000-0000000000d2','16300000-0000-0000-0000-000000000001','person','B'),
  ('16300000-0000-0000-0000-0000000000d3','16300000-0000-0000-0000-000000000002','person','G');
update public.customers set is_archived = true, archived_at = now(), archived_by = '16300000-0000-0000-0000-000000000011',
       archive_reason = 'left' where id = '16300000-0000-0000-0000-0000000000d2';
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code, starts_at, ends_at, created_at)
select '16300000-0000-0000-0000-000000000002', id, 'active', now() - interval '2 days', now() - interval '1 day', now() - interval '1 day'
from public.subscription_plans where plan_code = 'enterprise';

create function pg_temp.st(p_tenant text, p_customer text) returns text language sql as $$
  select coalesce(app.customer_consent_status(p_tenant::uuid, p_customer::uuid, 'ad_user_data'), 'null')
$$;

-- =============================================================================================
-- 1-4. AUTH: step-up is charged where the role is MFA-bound, and only there.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"16300000-0000-0000-0000-0000000000a1","aal":"aal1"}',true);
select throws_ok(
  $$select app.record_customer_consent('16300000-0000-0000-0000-0000000000d1','ad_user_data','denied','phone','asked to stop')$$,
  '42501', 'multi-factor authentication required for this role',
  'AUTH: an owner without step-up cannot record a consent decision');
select set_config('request.jwt.claims','{"sub":"16300000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select lives_ok(
  $$select app.record_customer_consent('16300000-0000-0000-0000-0000000000d1','ad_user_data','denied','phone','asked to stop')$$,
  'POSITIVE CONTROL: the same owner with step-up records it');
select set_config('request.jwt.claims','{"sub":"16300000-0000-0000-0000-0000000000a2","aal":"aal1"}',true);
select lives_ok(
  $$select app.record_customer_consent('16300000-0000-0000-0000-0000000000d1','ad_user_data','granted','phone','agreed on the call')$$,
  'AUTH (position, SPEC-240): an employee, whose role is not MFA-bound, records a decision at aal1');
reset role;
select set_config('request.jwt.claims','',true);
select is(
  pg_temp.st('16300000-0000-0000-0000-000000000001','16300000-0000-0000-0000-0000000000d1') || '/' ||
  (select c.created_by::text from public.customer_consents c
    where c.customer_id = '16300000-0000-0000-0000-0000000000d1' order by c.seq desc limit 1),
  'granted/16300000-0000-0000-0000-000000000012',
  'BUSINESS: the employee''s later GRANT is the current decision, attributed to the employee');

-- =============================================================================================
-- 5-6. STATE: an archive is not a merge.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"16300000-0000-0000-0000-0000000000a2","aal":"aal1"}',true);
select lives_ok(
  $$select app.record_customer_consent('16300000-0000-0000-0000-0000000000d2','ad_user_data','denied','email',null)$$,
  'STATE: an archived customer that was never merged still takes a withdrawal');
reset role;
select set_config('request.jwt.claims','',true);
select is(pg_temp.st('16300000-0000-0000-0000-000000000001','16300000-0000-0000-0000-0000000000d2'), 'denied',
  '...and it is the current decision');

-- =============================================================================================
-- 7-9. BUSINESS: billing never decides the customer's consent, in either direction.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"16300000-0000-0000-0000-0000000000a3","aal":"aal1"}',true);
select throws_ok(
  $$update public.customers set full_name = 'G2' where id = '16300000-0000-0000-0000-0000000000d3'$$,
  '42501', null,
  'PREMISE: the tenant''s billing has ended -- an ordinary customer write is refused');
select lives_ok(
  $$select app.record_customer_consent('16300000-0000-0000-0000-0000000000d3','ad_user_data','granted','phone',null)$$,
  'BUSINESS (position): the customer''s GRANT is recorded whatever the tenant''s billing state');
reset role;
select set_config('request.jwt.claims','',true);
select is(pg_temp.st('16300000-0000-0000-0000-000000000002','16300000-0000-0000-0000-0000000000d3'), 'granted',
  '...and it is the current decision');

select * from finish();
rollback;
