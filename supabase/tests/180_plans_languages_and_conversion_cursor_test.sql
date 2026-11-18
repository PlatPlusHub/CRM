-- pgTAP: Batch 6 slice 58 (subscription_plans, integration_cursors, languages) --
-- the plan list and the language list are platform-owned reference data: every member of every tenant
-- reads all of both, no member writes either (an owner at aal2 is refused by the missing grant), and anon
-- and orvion_integration hold no privilege on them. integration_cursors is the conversion mapper's
-- position: no member reads or writes it, and its one writer, app.map_outcomes_to_conversions (EXECUTE to
-- orvion_integration only), moves it forward; a rewound cursor re-maps nothing (one source event is one
-- conversion). The plan readers honour is_active: app.platform_activate_subscription,
-- app.platform_issue_license_token, app.redeem_license_token (for a token issued while the plan was
-- active) and app.provision_tenant refuse a deactivated plan; a tenant already on a deactivated plan keeps
-- working (grandfathered). A new customer is refused a deactivated language (the owner's policy of
-- 2026-11-18, slice 59, test 181); an unknown code is the foreign key's. Each is proven after a positive control. No
-- migration: each door held when probed, so this file pins what was measured and was not yet pinned
-- (tests 18, 51, 119, 142 and 169 keep the seeded counts, CUR-1 and the mapper's dedupe and findings).
-- ATTACK-CLASSES: AUTH TENANT DOOR STATE INPUT CONCURRENCY=N/A REPLAY PRIVILEGE BUSINESS OBSERVABILITY=N/A
--   CONCURRENCY=N/A -- only migrations write the plan and language lists; two mapper runs over one source
--     event meet the same unique index on source_event_seq that the REPLAY assertion pins.
--   OBSERVABILITY=N/A -- the member-facing writes are refused before any row or event exists; the mapper's
--     failure findings are tests 119 and 137.
create extension if not exists pgtap with schema extensions;

begin;
select plan(20);

select set_config('t180.totals',
  (select count(*) from public.subscription_plans)::text || '/' || (select count(*) from public.languages), true);

insert into auth.users (id, email) values
  ('18000000-0000-0000-0000-0000000000a1','owner@c180.test'),
  ('18000000-0000-0000-0000-0000000000a2','employee@c180.test'),
  ('18000000-0000-0000-0000-0000000000a5','other@c180.test');
insert into public.tenants (id, name, slug, status) values
  ('18000000-0000-0000-0000-000000000001','Plan Travel','plan-travel-180','active'),
  ('18000000-0000-0000-0000-000000000002','Other Travel','other-travel-180','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code, starts_at)
select v.t, sp.id, 'active', now() - interval '2 days' from public.subscription_plans sp,
  (values ('18000000-0000-0000-0000-000000000001'::uuid), ('18000000-0000-0000-0000-000000000002')) v(t)
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('18000000-0000-0000-0000-0000000000b1','18000000-0000-0000-0000-000000000001','Giza','giza-180');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('18000000-0000-0000-0000-0000000000c1','18000000-0000-0000-0000-000000000001','18000000-0000-0000-0000-0000000000b1','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('18000000-0000-0000-0000-000000000011','18000000-0000-0000-0000-000000000001','Owner','owner@c180.test',true,'18000000-0000-0000-0000-0000000000a1'),
  ('18000000-0000-0000-0000-000000000012','18000000-0000-0000-0000-000000000001','Employee','employee@c180.test',true,'18000000-0000-0000-0000-0000000000a2'),
  ('18000000-0000-0000-0000-000000000015','18000000-0000-0000-0000-000000000002','Other','other@c180.test',true,'18000000-0000-0000-0000-0000000000a5');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('18000000-0000-0000-0000-000000000001','18000000-0000-0000-0000-000000000012','18000000-0000-0000-0000-0000000000b1','18000000-0000-0000-0000-0000000000c1',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values
  ('18000000-0000-0000-0000-000000000001'::uuid, '18000000-0000-0000-0000-000000000011'::uuid, 'owner'),
  ('18000000-0000-0000-0000-000000000001', '18000000-0000-0000-0000-000000000012', 'employee'),
  ('18000000-0000-0000-0000-000000000002', '18000000-0000-0000-0000-000000000015', 'owner')) v(t, u, c)
join public.roles r on r.code = v.c;

-- =============================================================================================
-- 1-3. THE GRANTS: reference data read-only to members, the cursor closed, the mapper integration-only.
-- =============================================================================================
select is(
  (select count(*)::int from unnest(array['anon','orvion_integration']) r,
     unnest(array['public.subscription_plans','public.integration_cursors','public.languages']) t,
     unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
   where has_table_privilege(r, t, p)),
  0, 'anon and orvion_integration hold no privilege of any kind on the three tables');
select is(
  (select string_agg(split_part(t, '.', 2) || ':' || p, ',' order by t, p)
     from unnest(array['public.subscription_plans','public.integration_cursors','public.languages']) t,
          unnest(array['SELECT','INSERT','UPDATE','DELETE','TRUNCATE','REFERENCES','TRIGGER']) p
    where has_table_privilege('authenticated', t, p)),
  'languages:SELECT,subscription_plans:SELECT',
  'authenticated may read the plan and language lists and holds nothing else on the three tables, nothing at all on integration_cursors');
select is(
  (select string_agg(r || '=' || has_function_privilege(r, 'app.map_outcomes_to_conversions(integer)', 'EXECUTE'), ',' order by r)
     from unnest(array['anon','authenticated','orvion_integration','service_role']) r)
    || '/' || has_function_privilege('authenticated', 'app.platform_activate_subscription(uuid,text,text,boolean)', 'EXECUTE')
    || '/' || has_function_privilege('authenticated', 'app.platform_issue_license_token(uuid,text,text,boolean,integer,text)', 'EXECUTE'),
  'anon=false,authenticated=false,orvion_integration=true,service_role=false/false/false',
  'only orvion_integration may run the cursor''s one writer; no member may activate a plan or issue a license token');

-- =============================================================================================
-- 4-9. THE MEMBER DOORS: every member reads all of the reference data, none writes it or touches the cursor.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select is((select count(*) from public.subscription_plans)::text || '/' || (select count(*) from public.languages),
  current_setting('t180.totals'), 'an employee at aal1 reads every plan and every language');
select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a5","aal":"aal2"}', true);
select is((select count(*) from public.subscription_plans)::text || '/' || (select count(*) from public.languages),
  current_setting('t180.totals'), 'another tenant''s owner reads the same lists: reference data, not tenant data');

select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a1","aal":"aal2"}', true);
select throws_ok($$update public.subscription_plans set is_active = false where plan_code = 'starter'$$,
  '42501', 'permission denied for table subscription_plans', 'the owner at aal2 cannot deactivate a plan');
select throws_ok($$insert into public.languages (code, name) values ('zz', 'Forged')$$,
  '42501', 'permission denied for table languages', 'the owner at aal2 cannot add a language');
select throws_ok($$select last_seq from public.integration_cursors$$,
  '42501', 'permission denied for table integration_cursors', 'the owner at aal2 cannot read the mapper cursor');
select throws_ok($$update public.integration_cursors set last_seq = 0$$,
  '42501', 'permission denied for table integration_cursors', 'the owner at aal2 cannot rewind the mapper cursor');
reset role;
select set_config('request.jwt.claims', '', true);

-- =============================================================================================
-- 10-14. THE PLAN READERS honour is_active, after a positive control.
-- =============================================================================================
select lives_ok($$select app.platform_activate_subscription('18000000-0000-0000-0000-000000000002', 'professional', 'monthly')$$,
  'POSITIVE CONTROL: the platform activates an active plan');
select set_config('t180.tok', app.platform_issue_license_token('18000000-0000-0000-0000-000000000002', 'professional', 'monthly'), true) is not null;
update public.subscription_plans set is_active = false where plan_code = 'professional';
select throws_ok($$select app.platform_activate_subscription('18000000-0000-0000-0000-000000000002', 'professional', 'monthly')$$,
  'P0001', 'unknown or inactive plan_code: professional', 'the platform cannot activate a deactivated plan');
select throws_ok($$select app.platform_issue_license_token('18000000-0000-0000-0000-000000000002', 'professional', 'monthly')$$,
  'P0001', 'unknown or inactive plan_code: professional', 'the platform cannot issue a license token for a deactivated plan');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a5","aal":"aal2"}', true);
select throws_ok($$select app.redeem_license_token(current_setting('t180.tok'))$$,
  'P0001', 'unknown or inactive plan_code: professional',
  'a token issued while the plan was active cannot be redeemed after the plan is deactivated');
reset role;
select set_config('request.jwt.claims', '', true);
update public.subscription_plans set is_active = false where plan_code = 'enterprise';
select throws_ok($$select * from app.provision_tenant('New Travel', 'new-travel-180', 'new@c180.test', 'New')$$,
  'P0001', 'enterprise plan is not seeded; cannot start a full-feature trial',
  'no tenant is provisioned onto a deactivated enterprise trial plan');

-- =============================================================================================
-- 15-16. GRANDFATHERED: a tenant already on a deactivated plan keeps working.
-- =============================================================================================
select is(app.subscription_allows_write('18000000-0000-0000-0000-000000000001'), true,
  'the write gate still opens for a tenant whose enterprise plan was deactivated after it subscribed');
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select isnt(app.create_customer('person', 'T180 Grandfathered'), null,
  'BUSINESS: the employee of a grandfathered tenant still creates a customer');
reset role;
select set_config('request.jwt.claims', '', true);
update public.subscription_plans set is_active = true;

-- =============================================================================================
-- 17-18. THE CURSOR moves forward through its one writer; a rewound cursor re-maps nothing.
-- =============================================================================================
select app.map_outcomes_to_conversions(100000);
insert into public.leads (id, tenant_id, branch_id, department_id, lead_source_code, lead_status_code, title) values
  ('18000000-0000-0000-0000-0000000000d1','18000000-0000-0000-0000-000000000001','18000000-0000-0000-0000-0000000000b1',
   '18000000-0000-0000-0000-0000000000c1','google_ads_call','new','T180 call lead');
select app.record_event('18000000-0000-0000-0000-000000000001', 'lead_qualified', 'lead',
  '18000000-0000-0000-0000-0000000000d1', null, null, null, 't180', null) is not null;
-- The mapper runs in its own statement: a subquery in the same statement would read the cursor's old snapshot.
select set_config('t180.mapped', app.map_outcomes_to_conversions(500)::text, true);
select is(current_setting('t180.mapped') || '/'
            || ((select last_seq from public.integration_cursors where name = 'outcome_conversion_mapper')
                = (select max(seq) from public.events where event_type_code = 'lead_qualified'))::text,
  '1/true', 'POSITIVE CONTROL: the mapper maps the qualified call lead once and moves its cursor forward to that event');
update public.integration_cursors set last_seq = 0 where name = 'outcome_conversion_mapper';
select is(app.map_outcomes_to_conversions(500)::text || '/'
            || (select count(*) from public.offline_conversions where lead_id = '18000000-0000-0000-0000-0000000000d1'),
  '0/1', 'REPLAY: with the cursor rewound to zero, a rerun maps nothing new -- one source event is one conversion');

-- =============================================================================================
-- 19-20. LANGUAGES on a customer: a deactivated language and an unknown one are each refused.
-- =============================================================================================
update public.languages set is_active = false where code = 'fr';
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"18000000-0000-0000-0000-0000000000a2","aal":"aal1"}', true);
select throws_ok($$select app.create_customer('person', 'T180 French', p_preferred_language_code => 'fr')$$,
  '23514', 'customers .preferred_language_code : "fr" is not an active value of reference table "languages"',
  'a new customer is refused a deactivated language (the owner''s policy, test 181)');
select throws_ok($$select app.create_customer('person', 'T180 Unknown', p_preferred_language_code => 'zz')$$,
  '23503', 'insert or update on table "customers" violates foreign key constraint "customers_preferred_language_code_fkey"',
  'INPUT: an unknown language code is refused by the foreign key');

select * from finish();
rollback;
