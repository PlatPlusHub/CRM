-- pgTAP: Batch 6 slice 49 (RET-3, RET-4) --
-- a document retention period changes only with step-up and a record on every door
-- (`20261111150000`).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE=N/A INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS OBSERVABILITY
--   STATE=N/A -- a policy has no lifecycle beyond its active flag, whose change is charged and recorded here.
--   CONCURRENCY=N/A -- one row per tenant and type, held by the existing unique index.
--   REPLAY=N/A -- no token, nonce or idempotency key on this surface.
create extension if not exists pgtap with schema extensions;

begin;
select plan(15);

insert into auth.users (id, email) values
  ('16400000-0000-0000-0000-0000000000a1','owner@c164.test'),
  ('16400000-0000-0000-0000-0000000000a2','ceo@c164.test'),
  ('16400000-0000-0000-0000-0000000000a3','fm@c164.test'),
  ('16400000-0000-0000-0000-0000000000a9','other@c164.test');
insert into public.tenants (id, name, slug, status) values
  ('16400000-0000-0000-0000-000000000001','Retention Travel','retention-travel-164','active'),
  ('16400000-0000-0000-0000-000000000002','Other Travel','other-travel-164','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, 'active' from public.subscription_plans sp cross join (values ('16400000-0000-0000-0000-000000000001'::uuid), ('16400000-0000-0000-0000-000000000002'::uuid)) t(id) where sp.plan_code = 'enterprise';
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('16400000-0000-0000-0000-000000000011','16400000-0000-0000-0000-000000000001','Owner','owner@c164.test',true,'16400000-0000-0000-0000-0000000000a1'),
  ('16400000-0000-0000-0000-000000000012','16400000-0000-0000-0000-000000000001','CEO','ceo@c164.test',true,'16400000-0000-0000-0000-0000000000a2'),
  ('16400000-0000-0000-0000-000000000013','16400000-0000-0000-0000-000000000001','FM','fm@c164.test',true,'16400000-0000-0000-0000-0000000000a3'),
  ('16400000-0000-0000-0000-000000000019','16400000-0000-0000-0000-000000000002','Other','other@c164.test',true,'16400000-0000-0000-0000-0000000000a9');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.tid, v.uid, r.id, 'tenant'
from (values ('16400000-0000-0000-0000-000000000001'::uuid,'16400000-0000-0000-0000-000000000011'::uuid,'owner'),
             ('16400000-0000-0000-0000-000000000001','16400000-0000-0000-0000-000000000012','ceo'),
             ('16400000-0000-0000-0000-000000000001','16400000-0000-0000-0000-000000000013','finance_manager'),
             ('16400000-0000-0000-0000-000000000002','16400000-0000-0000-0000-000000000019','owner')) v(tid, uid, role_code)
join public.roles r on r.code = v.role_code;
insert into public.documents (id, tenant_id, document_type_code, title, lifecycle_status_code) values
  ('16400000-0000-0000-0000-0000000000d1','16400000-0000-0000-0000-000000000001','visa','V','active');

select is(
  (select count(*)::int from pg_trigger
   where tgrelid = 'public.document_retention_policies'::regclass and not tgisinternal
     and tgname in ('document_retention_policies_guard_write', 'document_retention_policies_emit_change')
     and pg_get_triggerdef(oid) like '%INSERT OR UPDATE%'),
  2,
  'the guard and the emitter both fire on INSERT and UPDATE');

-- The owner at aal1: the legal hold refuses it (control), and now so does the retention period.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a1","aal":"aal1"}', true);
select throws_ok(
  $$select app.set_document_legal_hold('16400000-0000-0000-0000-0000000000d1', true, 'hold')$$,
  '42501', null,
  'control: the legal hold, the lever that overrides retention, refuses a password-only owner');
select throws_ok(
  $$insert into public.document_retention_policies (tenant_id, document_type_code, retention_days, reason)
    values ('16400000-0000-0000-0000-000000000001', 'passport', 1, 'one day')$$,
  '42501', null,
  'RET-3: a 1-day policy at aal1 is refused (measured before the repair: created, and a superseded version became a delete_object claim)');

select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select lives_ok(
  $$insert into public.document_retention_policies (id, tenant_id, document_type_code, retention_days, reason)
    values ('16400000-0000-0000-0000-0000000000e1', '16400000-0000-0000-0000-000000000001', 'visa', 3650, 'ten years')$$,
  'the stepped-up owner still sets a period through the table door');
select is(
  (select count(*)::int from public.events
   where entity_id = '16400000-0000-0000-0000-0000000000e1' and event_type_code = 'document_retention_policy_changed'
     and severity_code = 'critical' and actor_user_id = '16400000-0000-0000-0000-000000000011'
     and payload->'previous' = 'null'::jsonb and (payload->'current'->>'retention_days')::int = 3650
     and new_state = 'active' and reason = 'ten years'),
  1,
  'RET-4: the creation is recorded once, critical, with the actor and the period (measured before the repair: 0 events)');

-- The ceo at aal1 can neither shorten nor deactivate it.
select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select throws_ok(
  $$update public.document_retention_policies set retention_days = 1 where id = '16400000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'RET-3: shortening at aal1 is refused (measured before the repair: shortened to 1 day)');
select throws_ok(
  $$update public.document_retention_policies set is_active = false where id = '16400000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  'RET-3: every column is charged, deactivation included');

select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
select lives_ok(
  $$update public.document_retention_policies set retention_days = 30, reason = 'thirty days' where id = '16400000-0000-0000-0000-0000000000e1'$$,
  'the stepped-up ceo changes the period');
select is(
  (select count(*)::int from public.events
   where entity_id = '16400000-0000-0000-0000-0000000000e1' and event_type_code = 'document_retention_policy_changed'
     and actor_user_id = '16400000-0000-0000-0000-000000000012'
     and (payload->'previous'->>'retention_days')::int = 3650 and (payload->'current'->>'retention_days')::int = 30
     and previous_state = 'active' and reason = 'thirty days'),
  1,
  'RET-4: the change is recorded with the ceo as actor and both periods (measured before the repair: unrecorded, the row still named the owner)');

update public.document_retention_policies set updated_at = now() where id = '16400000-0000-0000-0000-0000000000e1';
select is(
  (select count(*)::int from public.events
   where entity_id = '16400000-0000-0000-0000-0000000000e1' and event_type_code = 'document_retention_policy_changed'),
  2,
  '...and an update that moves no type, period, flag or reason records nothing');

select throws_ok(
  $$update public.document_retention_policies set retention_days = 0 where id = '16400000-0000-0000-0000-0000000000e1'$$,
  '23514', null,
  'a period below one day is refused, unchanged (RET-1, test 97)');

-- Another tenant's owner, stepped up, cannot set this tenant's period.
select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a9","aal":"aal2"}', true);
select throws_ok(
  $$insert into public.document_retention_policies (tenant_id, document_type_code, retention_days)
    values ('16400000-0000-0000-0000-000000000001', 'contract', 1)$$,
  '42501', null,
  'another tenant''s owner is refused, unchanged (RLS)');

-- A finance manager, stepped up, holds no MANAGE_TENANT_SETTINGS.
select set_config('request.jwt.claims', '{"sub":"16400000-0000-0000-0000-0000000000a3","aal":"aal2"}', true);
select throws_ok(
  $$insert into public.document_retention_policies (tenant_id, document_type_code, retention_days)
    values ('16400000-0000-0000-0000-000000000001', 'contract', 1)$$,
  '42501', null,
  'a non-holder is refused, unchanged');

-- No session (migrations, provisioning, the tests' own fixtures): no charge and no record.
reset role;
select set_config('request.jwt.claims', '', true);
select lives_ok(
  $$insert into public.document_retention_policies (id, tenant_id, document_type_code, retention_days)
    values ('16400000-0000-0000-0000-0000000000e2', '16400000-0000-0000-0000-000000000001', 'passport', 365)$$,
  'a session-less write is not charged');
select is(
  (select count(*)::int from public.events where entity_id = '16400000-0000-0000-0000-0000000000e2'),
  0,
  '...and records nothing, as before');

select * from finish();
rollback;
