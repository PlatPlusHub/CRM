-- pgTAP: Batch 6 slice 13 -- `offline_conversions.source_event_seq` is platform provenance.
--
-- ATTACK-CLASSES: DOOR TENANT PRIVILEGE STATE REPLAY BUSINESS OBSERVABILITY AUTH=N/A INPUT=N/A CONCURRENCY=N/A
--
-- The column is the idempotency key `app.map_outcomes_to_conversions` writes from a real event's
-- global `seq`, and the mapper resolves a conflict on it with DO NOTHING. Before this contract a
-- signed-in session holding MANAGE_MARKETING_CAMPAIGN could set it through the table door, so a
-- value written in one tenant was enough for another tenant's conversion to be skipped silently and
-- for its CONV-1 deferral to be closed as mapped. The rule tested here: a signed-in session may not
-- set or change the column; the session-less mapper still writes it.
--
-- AUTH is N/A: the refusal does not depend on permission or MFA, and the actor below holds both, so
-- no refusal in this file can come from `guard_write_capability` (64 and 78 own those). INPUT is N/A:
-- no value of the column is acceptable from a session. CONCURRENCY is N/A: the guard reads only the
-- session and the row's own OLD/NEW, never another row, so no interleaving can change its decision;
-- the orderings that matter to the mapper are exercised sequentially below.
create extension if not exists pgtap with schema extensions;

begin;
select plan(16);

-- =================================================================================================
-- FIXTURE. Tenant A holds the signed-in actor (owner, aal2). Tenant B holds two attributed leads
-- whose outcomes the mapper converts.
-- =================================================================================================
insert into auth.users (id, email) values ('11900000-0000-0000-0000-0000000000a1','owner@pa.test');
insert into public.tenants (id, name, slug, status) values
  ('11900000-0000-0000-0000-000000000001','PA Travel','pa-travel','active'),
  ('11900000-0000-0000-0000-000000000002','PB Travel','pb-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active' from public.subscription_plans sp,
  unnest(array['11900000-0000-0000-0000-000000000001'::uuid,'11900000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('11900000-0000-0000-0000-00000000000a','11900000-0000-0000-0000-000000000001','A','pa-branch'),
  ('11900000-0000-0000-0000-00000000000b','11900000-0000-0000-0000-000000000002','B','pb-branch');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('11900000-0000-0000-0000-0000000000c1','11900000-0000-0000-0000-000000000001','11900000-0000-0000-0000-00000000000a','sales','AS'),
  ('11900000-0000-0000-0000-0000000000c2','11900000-0000-0000-0000-000000000002','11900000-0000-0000-0000-00000000000b','sales','BS');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('11900000-0000-0000-0000-000000000011','11900000-0000-0000-0000-000000000001','PA Owner','owner@pa.test',true,'11900000-0000-0000-0000-0000000000a1');
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '11900000-0000-0000-0000-000000000001','11900000-0000-0000-0000-000000000011', r.id, 'tenant'
from public.roles r where r.code = 'owner';
insert into public.leads (id, tenant_id, branch_id, department_id, lead_source_code, title, lead_status_code) values
  ('11900000-0000-0000-0000-0000000000e1','11900000-0000-0000-0000-000000000001','11900000-0000-0000-0000-00000000000a','11900000-0000-0000-0000-0000000000c1','google_ads_call','LA','new'),
  ('11900000-0000-0000-0000-0000000000e2','11900000-0000-0000-0000-000000000002','11900000-0000-0000-0000-00000000000b','11900000-0000-0000-0000-0000000000c2','google_ads_call','LB1','new'),
  ('11900000-0000-0000-0000-0000000000e3','11900000-0000-0000-0000-000000000002','11900000-0000-0000-0000-00000000000b','11900000-0000-0000-0000-0000000000c2','google_ads_call','LB2','new');
select app.capture_attribution_click(p_tenant_id => t, p_attribution_source_code => 'google_ads',
                                     p_gclid => g, p_lead_id => l)
from (values ('11900000-0000-0000-0000-000000000001'::uuid,'PA-1','11900000-0000-0000-0000-0000000000e1'::uuid),
             ('11900000-0000-0000-0000-000000000002'::uuid,'PB-1','11900000-0000-0000-0000-0000000000e2'::uuid),
             ('11900000-0000-0000-0000-000000000002'::uuid,'PB-2','11900000-0000-0000-0000-0000000000e3'::uuid)) v(t,g,l);

-- The mapper starts from wherever the shared cursor stands; bring it current so every assertion
-- below is about events this file creates.
select app.map_outcomes_to_conversions(100000);

-- A session-less outcome in tenant B, recorded BEFORE the signed-in actor acts.
select set_config('t119.event_b1', app.record_event('11900000-0000-0000-0000-000000000002','lead_qualified','lead',
                        '11900000-0000-0000-0000-0000000000e2',null,null,null,'119',null)::text, true);
-- A separate statement: the row inserted above is not visible to the statement that inserted it.
select set_config('t119.seq_b1',
  (select seq::text from public.events where id = current_setting('t119.event_b1')::uuid), true);

-- =================================================================================================
-- 1-3. THE SIGNED-IN DOORS THAT MUST STAY OPEN.
-- =================================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);

select isnt(app.record_offline_conversion('qualified_lead'), null,
  'POSITIVE CONTROL: the manual RPC still records a conversion');

select lives_ok(
  $$insert into public.offline_conversions (id, tenant_id, conversion_event_type_code)
    values ('11900000-0000-0000-0000-0000000000f1','11900000-0000-0000-0000-000000000001','qualified_lead')$$,
  'POSITIVE CONTROL: the table door still admits a conversion that leaves the column NULL');

select lives_ok(
  $$update public.offline_conversions set conversion_value = 100, currency_code = 'EGP'
     where id = '11900000-0000-0000-0000-0000000000f1'$$,
  'POSITIVE CONTROL: an update that does not move the column is unaffected (64 pins this door)');

-- =================================================================================================
-- 4-6. A SIGNED-IN SESSION MAY NOT SET THE COLUMN -- on INSERT, or by UPDATE from NULL.
-- =================================================================================================
select throws_ok(
  $$insert into public.offline_conversions (tenant_id, conversion_event_type_code, source_event_seq)
    values ('11900000-0000-0000-0000-000000000001','qualified_lead', (select max(seq) from public.events) + 1)$$,
  '42501', 'offline_conversions.source_event_seq is platform provenance: a signed-in session may not set or change it',
  'INSERT supplying a not-yet-used value is refused by the provenance guard');

select throws_ok(
  $$insert into public.offline_conversions (tenant_id, conversion_event_type_code, source_event_seq)
    values ('11900000-0000-0000-0000-000000000001','qualified_lead', current_setting('t119.seq_b1')::bigint)$$,
  '42501', 'offline_conversions.source_event_seq is platform provenance: a signed-in session may not set or change it',
  'INSERT supplying another tenant''s existing event value is refused by the same guard');

select throws_ok(
  $$update public.offline_conversions set source_event_seq = current_setting('t119.seq_b1')::bigint
     where id = '11900000-0000-0000-0000-0000000000f1'$$,
  '42501', 'offline_conversions.source_event_seq is platform provenance: a signed-in session may not set or change it',
  'UPDATE from NULL to a value is refused');

-- The refusals above are this guard's and no other control's: with only the trigger removed, the
-- same actor's same INSERT succeeds. Rolled back, so nothing below sees the removal.
savepoint without_guard;
reset role;
drop trigger offline_conversions_forbid_session_provenance_write on public.offline_conversions;
set local role authenticated;
select lives_ok(
  $$insert into public.offline_conversions (tenant_id, conversion_event_type_code, source_event_seq)
    values ('11900000-0000-0000-0000-000000000001','qualified_lead', (select max(seq) from public.events) + 1)$$,
  'MUTATION: without offline_conversions_forbid_session_provenance_write the same INSERT succeeds -- nothing else on this door refuses it');
rollback to savepoint without_guard;

-- =================================================================================================
-- 8-9. THE SESSION-LESS MAPPER STILL WRITES IT, ONCE.
-- =================================================================================================
reset role;
select set_config('request.jwt.claims', '', true);
select app.map_outcomes_to_conversions(500);

select is(
  (select tenant_id from public.offline_conversions
    where source_event_seq = current_setting('t119.seq_b1')::bigint),
  '11900000-0000-0000-0000-000000000002'::uuid,
  'the mapper converts tenant B''s outcome and tenant B holds its provenance');

select app.map_outcomes_to_conversions(500);
select is(
  (select count(*)::int from public.offline_conversions
    where lead_id = '11900000-0000-0000-0000-0000000000e2'),
  1,
  'a second mapper run adds nothing -- the key still deduplicates');

-- =================================================================================================
-- 10-11. A VALUE THE MAPPER WROTE MAY NOT BE REPLACED OR REMOVED BY A SESSION.
-- =================================================================================================
select app.record_event('11900000-0000-0000-0000-000000000001','lead_qualified','lead',
                        '11900000-0000-0000-0000-0000000000e1',null,null,null,'119',null);
select app.map_outcomes_to_conversions(500);

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);

select throws_ok(
  $$update public.offline_conversions set source_event_seq = source_event_seq + 1000000
     where lead_id = '11900000-0000-0000-0000-0000000000e1'$$,
  '42501', 'offline_conversions.source_event_seq is platform provenance: a signed-in session may not set or change it',
  'UPDATE replacing a mapper-written value is refused');

select throws_ok(
  $$update public.offline_conversions set source_event_seq = null
     where lead_id = '11900000-0000-0000-0000-0000000000e1'$$,
  '42501', 'offline_conversions.source_event_seq is platform provenance: a signed-in session may not set or change it',
  'UPDATE clearing a mapper-written value is refused');

-- =================================================================================================
-- 12-16. CONV-1 DEFERRAL STAYS TRUTHFUL. Tenant B lapses, an outcome is deferred, a session tries to
-- write the deferred value, B recovers, and the deferral closes only because B's row now exists.
-- =================================================================================================
reset role;
select set_config('request.jwt.claims', '', true);
update public.subscriptions set subscription_status_code = 'read_only'
 where tenant_id = '11900000-0000-0000-0000-000000000002';
select set_config('t119.event_b2', app.record_event('11900000-0000-0000-0000-000000000002','lead_qualified','lead',
                        '11900000-0000-0000-0000-0000000000e3',null,null,null,'119',null)::text, true);
-- A separate statement: the row inserted above is not visible to the statement that inserted it.
select set_config('t119.seq_b2',
  (select seq::text from public.events where id = current_setting('t119.event_b2')::uuid), true);
select app.map_outcomes_to_conversions(500);

select is(
  (select count(*)::int from public.scheduled_job_findings
    where job_name = 'map_outcomes_to_conversions' and finding_type_code = 'item_deferred'
      and source_seq = current_setting('t119.seq_b2')::bigint and resolved_at is null),
  1,
  'POSITIVE CONTROL: the lapsed tenant''s outcome is deferred, not converted');

set local role authenticated;
select set_config('request.jwt.claims','{"sub":"11900000-0000-0000-0000-0000000000a1","aal":"aal2"}',true);
select throws_ok(
  $$insert into public.offline_conversions (tenant_id, conversion_event_type_code, source_event_seq)
    values ('11900000-0000-0000-0000-000000000001','qualified_lead', current_setting('t119.seq_b2')::bigint)$$,
  '42501', 'offline_conversions.source_event_seq is platform provenance: a signed-in session may not set or change it',
  'INSERT supplying a deferred event''s value is refused');

reset role;
select set_config('request.jwt.claims', '', true);
update public.subscriptions set subscription_status_code = 'active'
 where tenant_id = '11900000-0000-0000-0000-000000000002';
select app.map_outcomes_to_conversions(500);

select is(
  (select tenant_id from public.offline_conversions
    where source_event_seq = current_setting('t119.seq_b2')::bigint),
  '11900000-0000-0000-0000-000000000002'::uuid,
  'the deferred outcome is converted for tenant B once B can be written again');

select is(
  (select resolution_note from public.scheduled_job_findings
    where job_name = 'map_outcomes_to_conversions' and finding_type_code = 'item_deferred'
      and source_seq = current_setting('t119.seq_b2')::bigint),
  'the conversion was mapped on a later run',
  '...and the deferral closes as mapped because it WAS mapped');

select is(
  (select count(*)::int from public.offline_conversions
    where source_event_seq is not null
      and tenant_id = '11900000-0000-0000-0000-000000000001'
      and lead_id is distinct from '11900000-0000-0000-0000-0000000000e1'),
  0,
  'tenant A holds no provenance except the one the mapper wrote for its own outcome');

select finish();
rollback;
