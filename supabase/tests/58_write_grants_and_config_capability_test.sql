-- pgTAP: SEC-1 residue -- the thirteen tables closed by evidence, three different ways.
--
-- The point of this file is that the three groups needed three DIFFERENT actions, and each one is
-- proved by the mechanism that actually enforces it:
--
--   * five SYSTEM-OWNED tables lost the `authenticated` write GRANT, because every writer they have
--     is SECURITY DEFINER and none is executable by `authenticated` -- so the grant was a second
--     door nothing legitimate used. Proved at the privilege level, and the system path proved still
--     open, because a revoke that broke the real writer would be a worse defect than the hole.
--
--   * four CONFIGURATION tables gained a capability guard charging what ORVION already charges for
--     the same object. Every denial below is paired with a permit by a role that holds it, on the
--     same table, so the assertions differ in exactly one variable.
--
--   * three AUTH-ARTIFACT tables were left exactly as they are, because canon 34 says ownership by
--     `auth.uid()` IS their authorization model. That is asserted here as behaviour rather than
--     trusted as a comment: a user cannot write another user's authentication state.
--
-- `lead_interactions` is deliberately absent. `app.record_lead_interaction` is SECURITY INVOKER and
-- authorizes nothing, so DML and the RPC charge the same thing -- there is no bypass to prove, only
-- an undecided business question, and a test cannot decide it.
create extension if not exists pgtap with schema extensions;

begin;
select plan(27);

insert into auth.users (id, email) values
  ('58000000-0000-0000-0000-0000000000a1','emp@wg.test'),
  ('58000000-0000-0000-0000-0000000000a2','owner@wg.test'),
  ('58000000-0000-0000-0000-0000000000a3','train@wg.test');
insert into public.tenants (id, name, slug, status) values
  ('58000000-0000-0000-0000-000000000001','WG Travel','wg-travel','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select '58000000-0000-0000-0000-000000000001', sp.id, 'active'
from public.subscription_plans sp where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('58000000-0000-0000-0000-00000000000a','58000000-0000-0000-0000-000000000001','Cairo','wg-cairo');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('58000000-0000-0000-0000-0000000000c1','58000000-0000-0000-0000-000000000001','58000000-0000-0000-0000-00000000000a','sales','Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('58000000-0000-0000-0000-000000000011','58000000-0000-0000-0000-000000000001','Emp','emp@wg.test',true,'58000000-0000-0000-0000-0000000000a1'),
  ('58000000-0000-0000-0000-000000000012','58000000-0000-0000-0000-000000000001','Owner','owner@wg.test',true,'58000000-0000-0000-0000-0000000000a2'),
  ('58000000-0000-0000-0000-000000000013','58000000-0000-0000-0000-000000000001','Trainee','train@wg.test',true,'58000000-0000-0000-0000-0000000000a3');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '58000000-0000-0000-0000-000000000001', u, '58000000-0000-0000-0000-00000000000a','58000000-0000-0000-0000-0000000000c1', true
from unnest(array['58000000-0000-0000-0000-000000000011'::uuid,'58000000-0000-0000-0000-000000000012'::uuid,'58000000-0000-0000-0000-000000000013'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '58000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('58000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('58000000-0000-0000-0000-000000000012'::uuid,'owner'),
             ('58000000-0000-0000-0000-000000000013'::uuid,'trainee')) v(u,rc)
join public.roles r on r.code = v.rc;

-- A notification the SYSTEM sent to the employee. Inserted here as postgres, which is exactly the
-- path that survives the revoke below -- `app.process_lead_sla` is SECURITY DEFINER.
insert into public.notifications (id, tenant_id, target_user_id, notification_type_code, title, body)
values ('58000000-0000-0000-0000-0000000000e1','58000000-0000-0000-0000-000000000001',
        '58000000-0000-0000-0000-000000000011','security_alert','A real alert','sent by the system');

-- =============================================================================================
-- 1-9. SYSTEM-OWNED TABLES: the grant now matches the writer.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-0000-0000-0000000000a1"}', true);

select is(
  (select count(*)::int from public.notifications where id = '58000000-0000-0000-0000-0000000000e1'),
  1,
  'POSITIVE CONTROL: the employee still READS their own notification -- the denials below are about writing, not reach');

select throws_ok(
  $$insert into public.notifications (tenant_id, target_user_id, notification_type_code, title, body)
    values ('58000000-0000-0000-0000-000000000001','58000000-0000-0000-0000-000000000011','security_alert','Forged','by hand')$$,
  '42501', null,
  'a user can no longer FORGE a notification -- every writer of this table is SECURITY DEFINER, so the grant was a second door');

select lives_ok(
  $$update public.notifications set is_read = true, read_at = now()
     where id = '58000000-0000-0000-0000-0000000000e1'$$,
  '...but CAN still mark their own notification read -- the column grant kept the one user act that has no RPC');

select throws_ok(
  $$update public.notifications set title = 'Rewritten'
     where id = '58000000-0000-0000-0000-0000000000e1'$$,
  '42501', null,
  '...and CANNOT rewrite what the system said -- UPDATE is granted on is_read/read_at only');

select throws_ok(
  $$insert into public.attribution_clicks (tenant_id, attribution_source_code, gclid)
    values ('58000000-0000-0000-0000-000000000001','google_ads','forged-click')$$,
  '42501', null,
  'attribution_clicks: forging marketing attribution is no longer reachable from a tenant session');

select throws_ok(
  $$insert into public.usage_counters (tenant_id, usage_metric_code, period_start, period_end, used_value)
    values ('58000000-0000-0000-0000-000000000001','bookings', current_date, current_date, 0)$$,
  '42501', null,
  'usage_counters: a tenant cannot hand-edit its own meter (canon 28 -- the table is empty by design)');

select throws_ok(
  $$insert into public.notification_deliveries (tenant_id, notification_id, channel_code, delivery_status_code)
    values ('58000000-0000-0000-0000-000000000001','58000000-0000-0000-0000-0000000000e1','email','sent')$$,
  '42501', null,
  'notification_deliveries: nothing in the database writes it, so nothing authenticated should either');

select throws_ok(
  $$insert into public.offline_conversion_deliveries (tenant_id, offline_conversion_id, delivery_status_code)
    values ('58000000-0000-0000-0000-000000000001','58000000-0000-0000-0000-0000000000e1','pending')$$,
  '42501', null,
  'offline_conversion_deliveries: written only by orvion_integration definer functions');

reset role;
select set_config('request.jwt.claims', null, true);

select lives_ok(
  $$insert into public.attribution_clicks (tenant_id, attribution_source_code, gclid)
    values ('58000000-0000-0000-0000-000000000001','google_ads','system-click')$$,
  'THE SYSTEM PATH SURVIVES -- a revoke that broke the real writer would be worse than the hole it closed');

-- =============================================================================================
-- 10-19. CONFIGURATION TABLES: charged what ORVION already charges for the same object.
--        Denial and permit are on the SAME table, so the pair differs in exactly one variable.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"58000000-0000-0000-0000-0000000000a3"}', true);

select ok(
  not app.has_permission('MANAGE_BRANCHES')
  and not app.has_permission('MANAGE_TENANT_SETTINGS')
  and not app.has_permission('CREATE_JOURNAL_ENTRY'),
  'CONTROL: the trainee holds none of the three permissions these four tables now cost');

select throws_ok(
  $$insert into public.branch_business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at)
    values ('58000000-0000-0000-0000-000000000001','58000000-0000-0000-0000-00000000000a',1,'09:00','17:00')$$,
  '42501', null,
  'a trainee cannot set the branch opening hours -- MANAGE_BRANCHES, the same permission the branch itself costs');

select throws_ok(
  $$insert into public.holidays (tenant_id, name, holiday_date)
    values ('58000000-0000-0000-0000-000000000001','Forged Holiday', current_date)$$,
  '42501', null,
  '...nor declare a company holiday');

select throws_ok(
  $$insert into public.financial_accounts (tenant_id, financial_account_type_code, name, currency_code)
    values ('58000000-0000-0000-0000-000000000001','bank','Forged Account','EGP')$$,
  '42501', null,
  '...nor open a bank account -- CREATE_JOURNAL_ENTRY, what chart_of_accounts already costs');

select throws_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status)
    values ('58000000-0000-0000-0000-000000000001','Forged Car','vehicle','active')$$,
  '42501', null,
  '...nor register a company asset');

reset role;
-- `aal2` because app.requires_mfa() covers owner: this is what a real owner session carries.
select set_config('request.jwt.claims','{"sub":"58000000-0000-0000-0000-0000000000a2","aal":"aal2"}', true);
set local role authenticated;

select lives_ok(
  $$insert into public.branch_business_hours (tenant_id, branch_id, day_of_week, opens_at, closes_at)
    values ('58000000-0000-0000-0000-000000000001','58000000-0000-0000-0000-00000000000a',1,'09:00','17:00')$$,
  'POSITIVE CONTROL: the owner CAN set opening hours -- the guard narrowed the write, it did not close the table');

select lives_ok(
  $$insert into public.holidays (tenant_id, name, holiday_date)
    values ('58000000-0000-0000-0000-000000000001','Sham El-Nessim', current_date)$$,
  '...and declare a holiday');

select lives_ok(
  $$insert into public.financial_accounts (tenant_id, financial_account_type_code, name, currency_code)
    values ('58000000-0000-0000-0000-000000000001','bank','CIB Main','EGP')$$,
  '...and open a bank account');

select lives_ok(
  $$insert into public.company_assets (tenant_id, name, asset_type, status)
    values ('58000000-0000-0000-0000-000000000001','Hiace','vehicle','active')$$,
  '...and register an asset');

select is(
  (select count(*)::int from public.branch_business_hours) +
  (select count(*)::int from public.holidays) +
  (select count(*)::int from public.financial_accounts) +
  (select count(*)::int from public.company_assets),
  4,
  '...and all four persisted, so the denials above are not a blanket refusal');

-- =============================================================================================
-- 20-24. AUTH ARTIFACTS: canon 34 says ownership by auth.uid() IS the capability. Asserted as
--        behaviour, because "the policy looks right" is the reasoning this programme keeps refuting.
-- =============================================================================================
reset role;
select set_config('request.jwt.claims','{"sub":"58000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

select lives_ok(
  $$select app.record_trusted_device('wg-own-device')$$,
  'POSITIVE CONTROL: a user CAN record their OWN trusted device -- these tables are genuinely user-written');

select throws_ok(
  $$insert into public.trusted_devices (auth_user_id, device_identifier, status_code)
    values ('58000000-0000-0000-0000-0000000000a2','wg-stolen-device','trusted')$$,
  '42501', null,
  '...but CANNOT trust a device on behalf of another human identity');

select throws_ok(
  $$insert into public.otp_challenges (auth_user_id, status_code, sent_to_email, expires_at)
    values ('58000000-0000-0000-0000-0000000000a2','pending','owner@wg.test', now() + interval '5 minutes')$$,
  '42501', null,
  '...nor open an OTP challenge against another human identity');

select throws_ok(
  $$insert into public.totp_enrollments (auth_user_id, is_active)
    values ('58000000-0000-0000-0000-0000000000a2', true)$$,
  '42501', null,
  '...nor enrol another human identity in TOTP');

reset role;
select set_config('request.jwt.claims', null, true);
insert into public.trusted_devices (id, auth_user_id, device_identifier, status_code)
values ('58000000-0000-0000-0000-0000000000b1','58000000-0000-0000-0000-0000000000a2','wg-owner-device','trusted');
select set_config('request.jwt.claims','{"sub":"58000000-0000-0000-0000-0000000000a1"}', true);
set local role authenticated;

-- A silent no-op, not an error: the policy's USING clause hides the row, so the UPDATE matches
-- nothing. The assertion is on the DATA, because "no exception was raised" would have passed even
-- if the write had gone through.
update public.trusted_devices set device_identifier = 'hijacked'
 where id = '58000000-0000-0000-0000-0000000000b1';

reset role;
select set_config('request.jwt.claims', null, true);
select is(
  (select device_identifier from public.trusted_devices where id = '58000000-0000-0000-0000-0000000000b1'),
  'wg-owner-device',
  '...and an UPDATE aimed at another identity''s device changes nothing -- proved on the row, not on the absence of an error');

-- =============================================================================================
-- 25-27. THE MAP AND THE REVOKE ARE BOTH PINNED.
-- =============================================================================================
select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and t.tgname like '%\_guard\_write\_capability'),
  13,
  'thirteen tables now carry the write-capability guard');

select is(
  (select count(*)::int from pg_trigger t join pg_class c on c.oid = t.tgrelid
    where not t.tgisinternal and t.tgname like '%\_guard\_write\_capability'
      and c.relname not in ('approval_requests','conversation_messages','customer_contact_methods',
                            'customer_identity_signals','customer_identity_merges',
                            'internal_supplier_links','offline_conversions','document_links',
                            'lead_assignments','branch_business_hours','holidays',
                            'financial_accounts','company_assets')),
  0,
  '...and every one of them is on a table the function has a permission mapping for');

select is(
  (select count(*)::int
     from unnest(array['attribution_clicks','notifications','notification_deliveries',
                       'offline_conversion_deliveries','usage_counters']) as t(relname)
    cross join lateral (values ('INSERT'),('UPDATE')) as p(priv)
    where has_table_privilege('authenticated', ('public.'||quote_ident(t.relname))::regclass, p.priv)),
  0,
  'and none of the five system-owned tables grants authenticated INSERT or UPDATE at table level any more');

select finish();
rollback;
