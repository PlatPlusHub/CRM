-- pgTAP: ATTR-3 / directive §8 item J -- acquisition lineage survives every change of ownership,
-- and cannot be rewritten by anyone at all.
--
-- Owner business intent, ATTRIBUTION BUSINESS RULE: "Reassignment must never rewrite the original
-- acquisition lineage. Preserve: original source, GCLID, FBCLID, UTM lineage, attribution_click_id,
-- first-touch attribution, acquisition campaign/source. Changing the employee responsible for a
-- lead must not change where the customer originally came from."
--
-- Item J asked whether REASSIGNMENT rewrites attribution. It does not, on either path, and §5-6
-- below assert that instead of trusting the read. But the rule the owner states is stronger than
-- the question, and the stronger half was false: `authenticated` holds UPDATE on public.leads and
-- `scope_isolation` permits updating any lead the caller can see, so an employee could re-anchor a
-- colleague's lead to a different click -- moving a future Google Ads conversion, and the revenue
-- credited with it, from one campaign to another.
--
-- §7 is the other discipline this file exists for: a guard that froze the whole row would satisfy
-- every denial assertion above while breaking reassignment entirely. The lineage must be immovable
-- AND ownership must still move.
create extension if not exists pgtap with schema extensions;

begin;
select plan(21);

insert into auth.users (id, email) values
  ('64000000-0000-0000-0000-0000000000a1','emp@attr.test'),
  ('64000000-0000-0000-0000-0000000000a2','bm@attr.test'),
  ('64000000-0000-0000-0000-0000000000a3','emp2@attr.test'),
  ('64000000-0000-0000-0000-0000000000a4','owner@attr.test');
insert into public.tenants (id, name, slug, status) values
  ('64000000-0000-0000-0000-000000000001','Attr Travel','attr-travel','active'),
  ('64000000-0000-0000-0000-000000000002','Other Travel','attr-other','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active'
from public.subscription_plans sp,
     unnest(array['64000000-0000-0000-0000-000000000001'::uuid,
                  '64000000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('64000000-0000-0000-0000-00000000000a','64000000-0000-0000-0000-000000000001','Cairo','attr-cairo'),
  ('64000000-0000-0000-0000-00000000000b','64000000-0000-0000-0000-000000000002','Giza','attr-giza');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('64000000-0000-0000-0000-0000000000c1','64000000-0000-0000-0000-000000000001','64000000-0000-0000-0000-00000000000a','sales','Cairo Sales'),
  ('64000000-0000-0000-0000-0000000000c2','64000000-0000-0000-0000-000000000002','64000000-0000-0000-0000-00000000000b','sales','Giza Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('64000000-0000-0000-0000-000000000011','64000000-0000-0000-0000-000000000001','Handler','emp@attr.test',true,'64000000-0000-0000-0000-0000000000a1'),
  ('64000000-0000-0000-0000-000000000012','64000000-0000-0000-0000-000000000001','Branch Manager','bm@attr.test',true,'64000000-0000-0000-0000-0000000000a2'),
  ('64000000-0000-0000-0000-000000000010','64000000-0000-0000-0000-000000000001','Colleague','emp2@attr.test',true,'64000000-0000-0000-0000-0000000000a3'),
  ('64000000-0000-0000-0000-000000000013','64000000-0000-0000-0000-000000000001','Owner','owner@attr.test',true,'64000000-0000-0000-0000-0000000000a4');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '64000000-0000-0000-0000-000000000001', u,
       '64000000-0000-0000-0000-00000000000a','64000000-0000-0000-0000-0000000000c1', true
from unnest(array['64000000-0000-0000-0000-000000000011'::uuid,
                  '64000000-0000-0000-0000-000000000012'::uuid,
                  '64000000-0000-0000-0000-000000000010'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select '64000000-0000-0000-0000-000000000001', v.u, r.id, 'tenant'
from (values ('64000000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('64000000-0000-0000-0000-000000000012'::uuid,'branch_manager'),
             ('64000000-0000-0000-0000-000000000010'::uuid,'employee'),
             ('64000000-0000-0000-0000-000000000013'::uuid,'owner')) v(u,rc)
join public.roles r on r.code = v.rc;

insert into public.customers (id, tenant_id, customer_type_code, full_name, primary_phone) values
  ('64000000-0000-0000-0000-0000000000d1','64000000-0000-0000-0000-000000000001','person','Attr Customer','+201000000064');
insert into public.leads (id, tenant_id, branch_id, department_id, customer_id, lead_source_code,
                          title, lead_status_code, source_payload)
values ('64000000-0000-0000-0000-0000000000e1','64000000-0000-0000-0000-000000000001',
        '64000000-0000-0000-0000-00000000000a','64000000-0000-0000-0000-0000000000c1',
        '64000000-0000-0000-0000-0000000000d1','google_ads_call','Attributed lead','new',
        '{"raw":"first touch"}'::jsonb);

-- The acquisition, captured through the real RPC so first-touch is exercised and not simulated.
select app.capture_attribution_click(
    p_tenant_id => '64000000-0000-0000-0000-000000000001',
    p_attribution_source_code => 'google_ads',
    p_gclid => 'GCLID-FIRST-TOUCH',
    p_utm_campaign => 'ramadan-umrah',
    p_lead_id => '64000000-0000-0000-0000-0000000000e1');

-- A SECOND, unrelated click with a known id, so that "re-anchor" below is an act that could have
-- SUCCEEDED. A denial pointed at a row that does not exist proves nothing.
insert into public.attribution_clicks (id, tenant_id, attribution_source_code, gclid, utm_campaign)
values ('64000000-0000-0000-0000-0000000000f2','64000000-0000-0000-0000-000000000001',
        'meta_ads','GCLID-SECOND-TOUCH','summer-europe');

-- =============================================================================================
-- 1-3. FIRST TOUCH WINS. Existing RPC behaviour, asserted first so the trigger below cannot be
--      credited with a property ORVION already had.
-- =============================================================================================
select is(
  (select attribution_click_id from public.leads where id = '64000000-0000-0000-0000-0000000000e1'),
  (select id from public.attribution_clicks
    where tenant_id = '64000000-0000-0000-0000-000000000001' and gclid = 'GCLID-FIRST-TOUCH'),
  'the lead is anchored to the FIRST click captured against it');

select lives_ok(
  $$select app.capture_attribution_click(
      p_tenant_id => '64000000-0000-0000-0000-000000000001',
      p_attribution_source_code => 'meta_ads', p_gclid => 'GCLID-LATER',
      p_lead_id => '64000000-0000-0000-0000-0000000000e1')$$,
  'a LATER click may still be CAPTURED -- the click stream is history and is not closed by the anchor');

select is(
  (select attribution_click_id from public.leads where id = '64000000-0000-0000-0000-0000000000e1'),
  (select id from public.attribution_clicks
    where tenant_id = '64000000-0000-0000-0000-000000000001' and gclid = 'GCLID-FIRST-TOUCH'),
  '...and the lead is STILL anchored to the first -- first-touch, exactly as the RPC states it');

-- Assigned through the real RPC, by the manager, because assignment is supervisory.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"64000000-0000-0000-0000-0000000000a2"}', true);
select app.assign_lead('64000000-0000-0000-0000-0000000000e1',
                       '64000000-0000-0000-0000-000000000011','attribution fixture');

-- =============================================================================================
-- 4-8. THE HOLE. The HANDLER acts by direct DML on their OWN lead, so every refusal below is
--      about the COLUMN and never about reach -- which is what assertion 4 exists to prove.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"64000000-0000-0000-0000-0000000000a1"}', true);

select lives_ok(
  $$update public.leads set title = 'Attributed lead (edited)'
     where id = '64000000-0000-0000-0000-0000000000e1'$$,
  'POSITIVE CONTROL: the handler CAN update this lead -- the refusals below are about the column');

select throws_ok(
  $$update public.leads set attribution_click_id = '64000000-0000-0000-0000-0000000000f2'
     where id = '64000000-0000-0000-0000-0000000000e1'$$,
  '42501',
  null,
  'ATTR-3: re-anchoring the lead to a DIFFERENT click is refused -- this moved ad revenue between campaigns');

select throws_ok(
  $$update public.leads set attribution_click_id = null
     where id = '64000000-0000-0000-0000-0000000000e1'$$,
  '42501',
  null,
  '...and UNHOOKING the attribution is refused too -- erasing lineage is the same defect as moving it');

select throws_ok(
  $$update public.leads set lead_source_code = 'referral'
     where id = '64000000-0000-0000-0000-0000000000e1'$$,
  '42501',
  null,
  'the ORIGINAL SOURCE is fixed at creation -- "where the customer originally came from"');

select throws_ok(
  $$update public.leads set source_payload = '{"raw":"rewritten"}'::jsonb
     where id = '64000000-0000-0000-0000-0000000000e1'$$,
  '42501',
  null,
  'the acquisition PAYLOAD is fixed at creation -- it carries the raw first-touch evidence');

-- =============================================================================================
-- 9-10. §8 ITEM J, THE HUMAN PATH -- app.reassign_lead, by a manager holding REASSIGN_LEAD.
-- =============================================================================================
select set_config('request.jwt.claims','{"sub":"64000000-0000-0000-0000-0000000000a2"}', true);
select app.reassign_lead('64000000-0000-0000-0000-0000000000e1',
                         '64000000-0000-0000-0000-000000000010','manual reassignment');

reset role;
select set_config('request.jwt.claims', null, true);

select is(
  (select assigned_user_id from public.leads where id = '64000000-0000-0000-0000-0000000000e1'),
  '64000000-0000-0000-0000-000000000010'::uuid,
  'POSITIVE CONTROL: the human reassignment actually happened -- ownership DID move');

select is(
  (select l.attribution_click_id::text || '|' || l.lead_source_code
     from public.leads l where l.id = '64000000-0000-0000-0000-0000000000e1'),
  (select ac.id::text || '|google_ads_call' from public.attribution_clicks ac
    where ac.tenant_id = '64000000-0000-0000-0000-000000000001' and ac.gclid = 'GCLID-FIRST-TOUCH'),
  'ITEM J (human path): app.reassign_lead changed the owner and left the acquisition lineage alone');

-- =============================================================================================
-- 11-14. §8 ITEM J, THE AUTOMATIC PATH -- app.process_lead_sla's reassignment branch.
-- =============================================================================================
select is(
  (select count(*)::int from app.process_lead_sla(interval '0 seconds', interval '999 days')
    where lead_id = '64000000-0000-0000-0000-0000000000e1' and action = 'warned'),
  1,
  'the lead is warned, so the reassignment branch below is reachable');

select is(
  (select count(*)::int from app.process_lead_sla(interval '0 seconds', interval '0 seconds')
    where lead_id = '64000000-0000-0000-0000-0000000000e1' and action = 'reassigned'),
  1,
  'POSITIVE CONTROL: the SLA reassignment actually happened');

select is(
  (select l.attribution_click_id::text || '|' || l.lead_source_code || '|' || (l.source_payload->>'raw')
     from public.leads l where l.id = '64000000-0000-0000-0000-0000000000e1'),
  (select ac.id::text || '|google_ads_call|first touch' from public.attribution_clicks ac
    where ac.tenant_id = '64000000-0000-0000-0000-000000000001' and ac.gclid = 'GCLID-FIRST-TOUCH'),
  'ITEM J (automatic path): SLA reassignment left the anchor, the source AND the payload untouched');

select is(
  (select ac.gclid || '|' || ac.utm_campaign || '|' || coalesce(ac.lead_id::text,'-')
     from public.attribution_clicks ac
    where ac.tenant_id = '64000000-0000-0000-0000-000000000001' and ac.gclid = 'GCLID-FIRST-TOUCH'),
  'GCLID-FIRST-TOUCH|ramadan-umrah|64000000-0000-0000-0000-0000000000e1',
  '...and the CLICK RECORD itself -- gclid, campaign and its own lead link -- survived both reassignments');

-- =============================================================================================
-- 15-18. LEAD-2, RESOLVED rather than blocked. canon 25 declares lead_source a "Tenant-Extendable
--        System Catalog" whose "Tenant additions: Allowed with admin permission". An agency with
--        walk-in footfall adds its own value; ORVION need not ship one, and shipping one would be
--        deciding a market's acquisition taxonomy on canon's behalf when canon delegated it to the
--        tenant. Asserted here because a capability canon promises and nobody has ever exercised
--        is a claim, not a capability.
-- =============================================================================================
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"64000000-0000-0000-0000-0000000000a1"}', true);
select throws_ok(
  $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
    values ('64000000-0000-0000-0000-000000000001','lead_source','walk_in','Walk In')$$,
  '42501',
  null,
  'LEAD-2: an EMPLOYEE cannot extend the lead_source catalog -- canon 25 says "with admin permission"');

select set_config('request.jwt.claims','{"sub":"64000000-0000-0000-0000-0000000000a4"}', true);
select lives_ok(
  $$insert into public.catalog_values (tenant_id, catalog_type_code, code, label)
    values ('64000000-0000-0000-0000-000000000001','lead_source','walk_in','Walk In')$$,
  '...and the OWNER, who holds MANAGE_TENANT_SETTINGS, can -- the capability canon promises is real');

reset role;
select set_config('request.jwt.claims', null, true);

select lives_ok(
  $$insert into public.leads (tenant_id, branch_id, department_id, customer_id, lead_source_code, title, lead_status_code)
    values ('64000000-0000-0000-0000-000000000001','64000000-0000-0000-0000-00000000000a',
            '64000000-0000-0000-0000-0000000000c1','64000000-0000-0000-0000-0000000000d1',
            'walk_in','Walked in off the street','new')$$,
  '...and a lead can then be recorded against it -- so footfall is not filed as "manual_entry"');

select throws_ok(
  $$insert into public.leads (tenant_id, branch_id, department_id, lead_source_code, title, lead_status_code)
    values ('64000000-0000-0000-0000-000000000002','64000000-0000-0000-0000-00000000000b',
            '64000000-0000-0000-0000-0000000000c2','walk_in','Other tenant walk-in','new')$$,
  '23514',
  null,
  'NEGATIVE CONTROL: the value is scoped to the tenant that created it -- another tenant cannot use it');

-- =============================================================================================
-- 19-21. THE SIBLING. public.offline_conversions is the REVENUE end of the same chain the owner
--        rule names ("Ad -> Click identifier -> ... -> Revenue") and carries lineage of its own.
--        `authenticated` holds UPDATE on it; `202607056000` added a capability guard
--        (MANAGE_MARKETING_CAMPAIGN) and nothing made the record append-only, so a ceo or owner
--        could re-point an already-recorded conversion at a different click. The actor below HOLDS
--        that permission, so these are refusals of the ACT and not of the role.
-- =============================================================================================
insert into public.offline_conversions
  (id, tenant_id, lead_id, attribution_click_id, conversion_event_type_code, conversion_at)
select '64000000-0000-0000-0000-0000000000f9','64000000-0000-0000-0000-000000000001',
       '64000000-0000-0000-0000-0000000000e1', ac.id, 'qualified_lead', now()
from public.attribution_clicks ac
where ac.tenant_id = '64000000-0000-0000-0000-000000000001' and ac.gclid = 'GCLID-FIRST-TOUCH';

-- aal2, because `guard_write_capability` charges app.authorize (not has_permission) and
-- app.requires_mfa lists `owner`. Without it the refusals below would be MFA refusals wearing an
-- ATTR-3 label -- the exact vacuous-assertion shape this suite exists to catch.
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"64000000-0000-0000-0000-0000000000a4","aal":"aal2"}', true);

-- The currency moves WITH the value. CONV-5 (202607058200) made that pairing a constraint, and
-- this fixture is why it needed to be one: it set an amount with no currency, which
-- `app.record_offline_conversion` has always refused, so the row it produced was a state no legal
-- caller could reach. The assertion's intent is unchanged -- the owner CAN update this conversion --
-- it is now expressed with a row that could actually exist.
select lives_ok(
  $$update public.offline_conversions set conversion_value = 15000, currency_code = 'EGP'
     where id = '64000000-0000-0000-0000-0000000000f9'$$,
  'POSITIVE CONTROL: the owner holds MANAGE_MARKETING_CAMPAIGN and CAN update this conversion');

select throws_ok(
  $$update public.offline_conversions set attribution_click_id = '64000000-0000-0000-0000-0000000000f2'
     where id = '64000000-0000-0000-0000-0000000000f9'$$,
  '42501',
  null,
  'ATTR-3 (sibling): a recorded conversion may not be re-pointed at a different click -- that is the revenue end of the same chain');

select throws_ok(
  $$update public.offline_conversions set lead_id = null
     where id = '64000000-0000-0000-0000-0000000000f9'$$,
  '42501',
  null,
  '...and its link back to the lead may not be cut either');

select finish();
rollback;
