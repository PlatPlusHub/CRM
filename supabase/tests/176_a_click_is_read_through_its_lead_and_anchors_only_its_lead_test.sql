-- pgTAP: Batch 6 slice 55 (attribution_clicks) --
-- ATTR-5: a member reads a click only through a lead their own scope shows them; the marketing
-- dashboard holders read the tenant's clicks. ATTR-6: a member never sets a lead's first touch to a
-- click captured for another lead or for none; the platform capture still anchors it.
-- ATTACK-CLASSES: AUTH=N/A TENANT DOOR STATE INPUT CONCURRENCY=N/A REPLAY=N/A PRIVILEGE BUSINESS=N/A OBSERVABILITY=N/A
--   AUTH=N/A -- reading clicks needs no aal2: the leads that reveal them need none either.
--   CONCURRENCY, REPLAY=N/A -- the guard reads the click row it names; a click's lead never
--     changes (no write grant on clicks), so no race moves it.
--   BUSINESS=N/A -- a click carries no money; the offline conversion is its own surface.
--   OBSERVABILITY=N/A -- a refused write records nothing; the lineage trigger is unchanged.
create extension if not exists pgtap with schema extensions;

begin;
select plan(15);

insert into auth.users (id, email) values
  ('17600000-0000-0000-0000-0000000000a1','emp@c176.test'),
  ('17600000-0000-0000-0000-0000000000a2','bm@c176.test'),
  ('17600000-0000-0000-0000-0000000000a4','owner@c176.test'),
  ('17600000-0000-0000-0000-0000000000a5','other@c176.test');
insert into public.tenants (id, name, slug, status) values
  ('17600000-0000-0000-0000-000000000001','Click Travel','click-travel-176','active'),
  ('17600000-0000-0000-0000-000000000002','Other Travel','other-travel-176','active');
insert into public.subscriptions (tenant_id, subscription_plan_id, subscription_status_code)
select t, sp.id, 'active'
from public.subscription_plans sp,
     unnest(array['17600000-0000-0000-0000-000000000001'::uuid,
                  '17600000-0000-0000-0000-000000000002'::uuid]) t
where sp.plan_code = 'enterprise';
insert into public.branches (id, tenant_id, name, slug) values
  ('17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-000000000001','Cairo','cairo-176'),
  ('17600000-0000-0000-0000-00000000000b','17600000-0000-0000-0000-000000000001','Alexandria','alex-176');
insert into public.departments (id, tenant_id, branch_id, department_type_code, name) values
  ('17600000-0000-0000-0000-0000000000c1','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000a','sales','Cairo Sales'),
  ('17600000-0000-0000-0000-0000000000c2','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000b','sales','Alexandria Sales');
insert into public.users (id, tenant_id, full_name, email, is_active, auth_user_id) values
  ('17600000-0000-0000-0000-000000000011','17600000-0000-0000-0000-000000000001','Handler','emp@c176.test',true,'17600000-0000-0000-0000-0000000000a1'),
  ('17600000-0000-0000-0000-000000000012','17600000-0000-0000-0000-000000000001','Branch Manager','bm@c176.test',true,'17600000-0000-0000-0000-0000000000a2'),
  ('17600000-0000-0000-0000-000000000013','17600000-0000-0000-0000-000000000001','Owner','owner@c176.test',true,'17600000-0000-0000-0000-0000000000a4'),
  ('17600000-0000-0000-0000-000000000014','17600000-0000-0000-0000-000000000002','Other Owner','other@c176.test',true,'17600000-0000-0000-0000-0000000000a5');
insert into public.user_branch_assignments (tenant_id, user_id, branch_id, department_id, is_primary)
select '17600000-0000-0000-0000-000000000001', u,
       '17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-0000000000c1', true
from unnest(array['17600000-0000-0000-0000-000000000011'::uuid,
                  '17600000-0000-0000-0000-000000000012'::uuid]) u;
insert into public.user_role_assignments (tenant_id, user_id, role_id, scope_type)
select v.t, v.u, r.id, 'tenant'
from (values ('17600000-0000-0000-0000-000000000001'::uuid,'17600000-0000-0000-0000-000000000011'::uuid,'employee'),
             ('17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-000000000012','branch_manager'),
             ('17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-000000000013','owner'),
             ('17600000-0000-0000-0000-000000000002','17600000-0000-0000-0000-000000000014','owner')) v(t,u,rc)
join public.roles r on r.code = v.rc;

-- e1 Cairo (the handler's), e2 Alexandria (outside the handler's and the Cairo manager's scope),
-- e3 Cairo with no first touch yet.
insert into public.leads (id, tenant_id, branch_id, department_id, lead_source_code, title, lead_status_code) values
  ('17600000-0000-0000-0000-0000000000e1','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-0000000000c1','google_ads_call','Cairo lead','new'),
  ('17600000-0000-0000-0000-0000000000e2','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000b','17600000-0000-0000-0000-0000000000c2','google_ads_call','Alexandria lead','new'),
  ('17600000-0000-0000-0000-0000000000e3','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-0000000000c1','google_ads_call','Untouched lead','new'),
  ('17600000-0000-0000-0000-0000000000e4','17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-0000000000c1','google_ads_call','Legacy lead','new');

select app.capture_attribution_click(p_tenant_id => '17600000-0000-0000-0000-000000000001',
  p_attribution_source_code => 'google_ads', p_gclid => 'GCLID-176-CAIRO',
  p_lead_id => '17600000-0000-0000-0000-0000000000e1');
select app.capture_attribution_click(p_tenant_id => '17600000-0000-0000-0000-000000000001',
  p_attribution_source_code => 'google_ads', p_gclid => 'GCLID-176-ALEX',
  p_lead_id => '17600000-0000-0000-0000-0000000000e2');
select app.capture_attribution_click(p_tenant_id => '17600000-0000-0000-0000-000000000001',
  p_attribution_source_code => 'google_ads', p_gclid => 'GCLID-176-NOLEAD');
-- A legacy row: a platform path (auth.uid() null) anchored e4 to a click not captured for it.
update public.leads set attribution_click_id = (select id from public.attribution_clicks where gclid = 'GCLID-176-NOLEAD')
 where id = '17600000-0000-0000-0000-0000000000e4';

select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a2"}', true);
set local role authenticated;
select app.assign_lead('17600000-0000-0000-0000-0000000000e1','17600000-0000-0000-0000-000000000011','fixture');
select app.assign_lead('17600000-0000-0000-0000-0000000000e3','17600000-0000-0000-0000-000000000011','fixture');

-- ATTR-5: who reads which click.
select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a4"}', true);
select set_eq($$select gclid from public.attribution_clicks$$,
  $$values ('GCLID-176-CAIRO'), ('GCLID-176-ALEX'), ('GCLID-176-NOLEAD')$$,
  'the owner (a marketing dashboard holder) reads every click of the tenant');

select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a2"}', true);
select set_eq($$select gclid from public.attribution_clicks$$, $$values ('GCLID-176-CAIRO')$$,
  'the Cairo branch manager reads only the click of a Cairo lead');

select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a1"}', true);
select set_eq($$select id::text from public.leads$$,
  $$values ('17600000-0000-0000-0000-0000000000e1'), ('17600000-0000-0000-0000-0000000000e3'), ('17600000-0000-0000-0000-0000000000e4')$$,
  'CONTROL: the handler''s scope shows the three Cairo leads and not the Alexandria one');
select set_eq($$select gclid from public.attribution_clicks$$, $$values ('GCLID-176-CAIRO')$$,
  'the handler reads only the click of a lead they see: not Alexandria''s, not the unattached one');
select is((select count(*)::int from public.attribution_clicks where gclid = 'GCLID-176-ALEX'),
  0, 'the handler cannot read another branch''s click even by its gclid');

select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a5"}', true);
select is((select count(*)::int from public.attribution_clicks
            where tenant_id = '17600000-0000-0000-0000-000000000001'), 0,
  'another tenant''s owner reads none of the tenant''s clicks');

-- ATTR-6: the first touch is only the click captured for that lead.
select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a1"}', true);
select throws_ok(
  $$update public.leads set attribution_click_id =
      (select lead_click.id from public.attribution_clicks lead_click where lead_click.gclid = 'GCLID-176-CAIRO')
     where id = '17600000-0000-0000-0000-0000000000e3'$$,
  '42501', null, 'the handler cannot give a lead the first touch of another lead');
select lives_ok(
  $$update public.leads set title = 'Cairo lead, renamed' where id = '17600000-0000-0000-0000-0000000000e1'$$,
  'the handler still edits an anchored lead: the guard reads only a change of the first touch');
select lives_ok(
  $$update public.leads set title = 'Legacy lead, renamed' where id = '17600000-0000-0000-0000-0000000000e4'$$,
  'the handler still edits a legacy lead whose first touch a platform path set before this guard');
select throws_ok(
  $$insert into public.leads (tenant_id, branch_id, department_id, lead_source_code, title, lead_status_code, attribution_click_id)
    values ('17600000-0000-0000-0000-000000000001','17600000-0000-0000-0000-00000000000a','17600000-0000-0000-0000-0000000000c1',
            'google_ads_call','Borrowed touch','new',
            (select c.id from public.attribution_clicks c where c.gclid = 'GCLID-176-CAIRO'))$$,
  '42501', null, 'a member cannot create a lead carrying another lead''s first touch');

select set_config('request.jwt.claims','{"sub":"17600000-0000-0000-0000-0000000000a4"}', true);
select throws_ok(
  $$update public.leads set attribution_click_id =
      (select c.id from public.attribution_clicks c where c.gclid = 'GCLID-176-ALEX')
     where id = '17600000-0000-0000-0000-0000000000e3'$$,
  '42501', null, 'not even the owner moves another lead''s click onto a lead');
select throws_ok(
  $$update public.leads set attribution_click_id =
      (select c.id from public.attribution_clicks c where c.gclid = 'GCLID-176-NOLEAD')
     where id = '17600000-0000-0000-0000-0000000000e3'$$,
  '42501', null, 'not even the owner claims an unattached click as a lead''s first touch');

reset role;
select set_config('request.jwt.claims', '', true);
select is((select attribution_click_id from public.leads where id = '17600000-0000-0000-0000-0000000000e3'),
  null, 'the untouched lead still has no first touch');

select app.capture_attribution_click(p_tenant_id => '17600000-0000-0000-0000-000000000001',
  p_attribution_source_code => 'meta_ads', p_gclid => 'GCLID-176-OWN',
  p_lead_id => '17600000-0000-0000-0000-0000000000e3');
select is((select attribution_click_id from public.leads where id = '17600000-0000-0000-0000-0000000000e3'),
  (select id from public.attribution_clicks where gclid = 'GCLID-176-OWN'),
  'POSITIVE CONTROL: the platform capture anchors the lead to the click captured for it');
select is((select attribution_click_id from public.leads where id = '17600000-0000-0000-0000-0000000000e1'),
  (select id from public.attribution_clicks where gclid = 'GCLID-176-CAIRO'),
  'the handler''s edit left the first lead''s first touch where the capture put it');

select * from finish();
rollback;
