-- pgTAP: Batch 6 exit -- thirteen row triggers that no test removed are proven to refuse, each by its own message.
--
-- EC-5: an invariant held in a database control must be proven by a test that fails when the control is removed. The
--   EC-5 mutation probe at CRM 8a43a53 disabled each of the RAISE-bearing row triggers in turn and ran the pgTAP suite;
--   thirteen survived: the subscription write gate on customer_identity_merges, journal_entries, journal_entry_lines,
--   notifications and attribution_clicks; the write-capability guard on customer_identity_merges; the catalog-code
--   check on journal_entries, notifications, notification_deliveries, attribution_clicks,
--   offline_conversion_deliveries and customer_consents; and the entity-reference check on notifications. Each
--   control already refuses (PROVEN on the local stack before this test was written); no test named its refusal.
--   Every assertion names the exact SQLSTATE and message its trigger raises, so a refusal by any other control (a
--   later trigger, a NOT NULL, a foreign key) fails the assertion. A BEFORE row trigger raises before NOT NULL,
--   CHECK and foreign key checks run, so the refused rows carry only the columns their trigger reads.
--   Assertions 1-5: a tenant whose latest subscription is expired is refused on each gated table, reads unaffected.
--   Assertion 6: a trainee of an active tenant, without MERGE_CUSTOMER_IDENTITY, is refused a merge record.
--   Assertions 7-12: a code that is not an active value of its catalog family is refused on each table.
--   Assertion 13: a notification naming a customer that does not exist in its tenant is refused.
--   No migration: this test pins the controls so a later change cannot drop one unseen.
-- ATTACK-CLASSES: AUTH PRIVILEGE STATE INPUT TENANT BUSINESS DOOR=N/A CONCURRENCY=N/A REPLAY=N/A OBSERVABILITY=N/A
create extension if not exists pgtap with schema extensions;

begin;
select plan(13);

insert into auth.users (id, email, email_confirmed_at) values
  ('c1910000-0000-0000-0000-0000000000a2','trainee@a191.test', now());
insert into public.tenants (id, name, slug, status) values
  ('c1910000-0000-0000-0000-000000000001','A191 Travel','a191-travel','active'),
  ('c1910000-0000-0000-0000-000000000002','L191 Travel','l191-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t.id, sp.id, t.status
  from (values ('c1910000-0000-0000-0000-000000000001'::uuid,'active'),
               ('c1910000-0000-0000-0000-000000000002'::uuid,'expired')) t(id, status)
 cross join public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('c1910000-0000-0000-0000-00000000000a','c1910000-0000-0000-0000-000000000001','Main A','a191-main');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('c1910000-0000-0000-0000-0000000000da','c1910000-0000-0000-0000-000000000001','c1910000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('c1910000-0000-0000-0000-000000000012','c1910000-0000-0000-0000-000000000001','Trainee A','trainee@a191.test',true,'c1910000-0000-0000-0000-0000000000a2');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary) values
  ('c1910000-0000-0000-0000-000000000001','c1910000-0000-0000-0000-000000000012','c1910000-0000-0000-0000-00000000000a','c1910000-0000-0000-0000-0000000000da',true);
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select 'c1910000-0000-0000-0000-000000000001', 'c1910000-0000-0000-0000-000000000012', r.id, 'tenant'
  from public.roles r where r.code = 'trainee';

-- 1-5. STATE: the subscription write gate refuses a tenant whose latest subscription is expired.
select throws_ok(
  $$insert into public.customer_identity_merges (tenant_id) values ('c1910000-0000-0000-0000-000000000002')$$,
  '42501',
  'subscription state "expired" does not permit writes on public.customer_identity_merges (reads remain available so the tenant can inspect and export its own data)',
  'an expired tenant is refused a customer identity merge by the subscription write gate'
);
select throws_ok(
  $$insert into public.journal_entries (tenant_id, source_type_code) values ('c1910000-0000-0000-0000-000000000002', 'manual_entry')$$,
  '42501',
  'subscription state "expired" does not permit writes on public.journal_entries (reads remain available so the tenant can inspect and export its own data)',
  'an expired tenant is refused a journal entry by the subscription write gate'
);
select throws_ok(
  $$insert into public.journal_entry_lines (tenant_id) values ('c1910000-0000-0000-0000-000000000002')$$,
  '42501',
  'subscription state "expired" does not permit writes on public.journal_entry_lines (reads remain available so the tenant can inspect and export its own data)',
  'an expired tenant is refused a journal entry line by the subscription write gate'
);
select throws_ok(
  $$insert into public.notifications (tenant_id, notification_type_code) values ('c1910000-0000-0000-0000-000000000002', 'security_alert')$$,
  '42501',
  'subscription state "expired" does not permit writes on public.notifications (reads remain available so the tenant can inspect and export its own data)',
  'an expired tenant is refused a notification by the subscription write gate'
);
select throws_ok(
  $$insert into public.attribution_clicks (tenant_id, attribution_source_code) values ('c1910000-0000-0000-0000-000000000002', 'manual')$$,
  '42501',
  'subscription state "expired" does not permit writes on public.attribution_clicks (reads remain available so the tenant can inspect and export its own data)',
  'an expired tenant is refused an attribution click by the subscription write gate'
);

-- 6. PRIVILEGE: a trainee of an active tenant does not hold MERGE_CUSTOMER_IDENTITY and is refused a merge record.
select set_config('request.jwt.claims', '{"sub":"c1910000-0000-0000-0000-0000000000a2"}', true);
select throws_ok(
  $$insert into public.customer_identity_merges (tenant_id) values ('c1910000-0000-0000-0000-000000000001')$$,
  '42501',
  'permission denied: one of MERGE_CUSTOMER_IDENTITY is required to write customer_identity_merges',
  'a trainee without MERGE_CUSTOMER_IDENTITY is refused a customer identity merge by the write-capability guard'
);
select set_config('request.jwt.claims', '', true);

-- 7-12. INPUT: a code that is not an active value of its catalog family is refused.
select throws_ok(
  $$insert into public.journal_entries (tenant_id, source_type_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_source')$$,
  '23514',
  'journal_entries .source_type_code : "x191_source" is not an active value of catalog family "journal_entry_source_type"',
  'an unknown journal entry source type is refused by the catalog-code check'
);
select throws_ok(
  $$insert into public.notifications (tenant_id, notification_type_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_type')$$,
  '23514',
  'notifications .notification_type_code : "x191_type" is not an active value of catalog family "notification_type"',
  'an unknown notification type is refused by the catalog-code check'
);
select throws_ok(
  $$insert into public.notification_deliveries (tenant_id, channel_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_channel')$$,
  '23514',
  'notification_deliveries .channel_code : "x191_channel" is not an active value of catalog family "notification_channel"',
  'an unknown notification delivery channel is refused by the catalog-code check'
);
select throws_ok(
  $$insert into public.attribution_clicks (tenant_id, attribution_source_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_source')$$,
  '23514',
  'attribution_clicks .attribution_source_code : "x191_source" is not an active value of catalog family "attribution_source"',
  'an unknown attribution source is refused by the catalog-code check'
);
select throws_ok(
  $$insert into public.offline_conversion_deliveries (tenant_id, platform_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_platform')$$,
  '23514',
  'offline_conversion_deliveries .platform_code : "x191_platform" is not an active value of catalog family "platform_code"',
  'an unknown offline conversion delivery platform is refused by the catalog-code check'
);
select throws_ok(
  $$insert into public.customer_consents (tenant_id, channel_code) values ('c1910000-0000-0000-0000-000000000001', 'x191_channel')$$,
  '23514',
  'customer_consents .channel_code : "x191_channel" is not an active value of catalog family "channel_code"',
  'an unknown consent channel is refused by the catalog-code check'
);

-- 13. TENANT: a notification cannot name a customer that does not exist in its own tenant.
select throws_ok(
  $$insert into public.notifications (tenant_id, notification_type_code, related_entity_type, related_entity_id)
    values ('c1910000-0000-0000-0000-000000000001', 'security_alert', 'customer', 'c1910000-0000-0000-0000-0000000000c9')$$,
  '23503',
  'notifications: related_entity_id "c1910000-0000-0000-0000-0000000000c9" does not identify a customer in this tenant',
  'a notification naming a customer outside its tenant is refused by the entity-reference check'
);

select * from finish();
rollback;
